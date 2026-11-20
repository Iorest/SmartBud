# SmartBud 完整设计

> 这份文档定义"系统应该是什么样"，不是"代码现在是什么样"。实现与设计的差距见第 12 节。
> 任何新功能先改这里，再改代码；口径相关的改动同时改 [ledger-rules.md](ledger-rules.md)。

目录
1. 设计原则
2. 领域模型
3. 金额与货币
4. 账目口径
5. 时间与周期
6. 功能契约
7. 状态与缓存
8. 多设备与同步
9. 交互与导航
10. 版本与迁移
11. 未实现功能的模型影响
12. 现状 vs 设计（差距与优先级）
13. 待拍板的三个决定

---

## 1. 设计原则

1. **一个真相源**：SwiftData 本地库。iCloud 只做同步，任何"为了显示"的缓存都必须可丢弃、可重建。
2. **派生优于存储**：余额、统计、预算剩余、待报销，全部由记录推导。只有"历史汇率折算结果"允许冻结存储（`baseAmount`），因为汇率会变，历史不能变。
3. **口径只有一处**：一笔记录算不算支出，由模型上的三个判定决定，不允许各页面各写一套。
4. **破坏性操作可撤销或二次确认**：交易删除有 6 秒撤销；账户/分类/清空有确认弹窗且说明后果。
5. **数据可带走**：导出必须能被自己导回，且跨版本可读；不能导回的文件要明确标注。
6. **离线优先**：没有 iCloud 也能完整使用，降级时明确告知，不阻断。
7. **原生优先**：`List`/`Form`/`alert`/`fileImporter`/`ShareLink`/`NavigationSplitView`，不造中间件。

## 2. 领域模型

```
CategoryModel 1 ──< TransactionModel >── 1 AccountModel
    │                    │
    │                    └── (adjustment / reimbursable 标记)
    └── 1 BudgetModel

AccountModel 1 ──< TransferModel >── 1 AccountModel   (source / destination)

CurrencyRate (code, rate, updatedAt)     基准货币 = AppStorage "currency"（首次启动落盘）
MainBudgetModel                          全局预算
TemplateTransactionModel                 快捷记账模板
```

字段与不变量：

| 实体 | 关键字段 | 不变量 |
|---|---|---|
| `TransactionModel` | `amount`, `baseAmount?`, `income`, `date`, `day?`, `month?`, `discount`, `reimbursable`, `reimbursedAt?`, `reimbursementOf?`, `refundOf?`, `transferFeeOf?`, `adjustment`, `recurringType/Coefficient`, `onceRecurring`, `merchant?`, `merchantKey?` | `amount >= 0`；`baseAmount` 写入后不再变；`reimbursable` 只对支出成立；`adjustment` 行无分类、不进统计；`merchantKey == nil` 当且仅当 `merchant == nil` |
| `CategoryModel` | `name`, `emoji`, `colour`, `income`, `order` | `income` 决定它能挂在哪类记录上 |
| `AccountModel` | `kind`, `currencyCode`, `openingBalance`, `hidden`, `archived`, `order` | `archived ⇒ 不出现在默认列表/总资产/转账端点` |
| `TransferModel` | `amount`, `destinationAmount`, `fee`, `source`, `destination` | `amount > 0`；`fee >= 0`；跨币种时 `destinationAmount > 0`；`source != destination` |
| `BudgetModel` | `amount`, `startDate`, `type`, `category` | 无分类的预算是脏数据，统计时按"不匹配任何交易"处理 |
| `MainBudgetModel` | `amount`, `startDate`, `type` | 同上，全局 |
| `CurrencyRate` | `code`, `rate` | `rate > 0`；基准货币本身不需要行 |

删除规则（当前实现，也是设计要求）：

- 删交易 → 走 `TransactionSnapshot` 暂存，6 秒内可撤销；撤销必须恢复到"和删除前一模一样"（账户、baseAmount、折扣、报销、调整、商户都在快照里）。
- 删分类 → 交易保留、`category = nil`、备注若是分类名副本则保留原样；关联 `BudgetModel` 一并删除。
- 删账户 → 交易保留、`account = nil`；两端涉及它的转账一并删除。
- 删转账 → 只需它自己，两端余额自动回滚。

商户（`merchant` / `merchantKey`）：

- 没有商户实体，也没有商户主数据表。两个字段就是商户数据的全部：随交易一起删除（删交易、清空库），
  改商户名就是改行本身，没有别处指向它。
- 默认值都是 `nil`，含义是"未识别"：本功能之前写入的旧行、备注里没有商户名的行、
  以及记账页之外写入的调整/手续费/报销行。`merchantKey == nil` 当且仅当 `merchant == nil`。
- 派生规则见 `Logic/MerchantNormalizer.swift`：去掉平台前缀后的店铺细节
  （"美团-张亮麻辣烫" → 美团）、公司/门店后缀、门店编号；全角与大小写折叠；
  纯数字不算商户（否则两家店的编号会合并）；别名表可编辑（`MerchantAliasTable`）。
- 写入时机：记账/改备注时按备注派生（`TransactionViewModel.create/update`）；
  旧库在启动时由 `MerchantMigration` 一次性回填（只填 `merchantKey == nil` 的行，可重入），
  JSON 导入后同样再跑一次回填。

## 3. 金额与货币

三层结构：

| 层 | 字段 | 用途 |
|---|---|---|
| 账户币种金额 | `TransactionModel.amount` | 录入、行内显示（带该账户的货币符号） |
| 基准币种金额 | `TransactionModel.baseAmount` | 所有跨账户/跨期合计；记账当时按汇率折算后**冻结** |
| 汇率表 | `CurrencyRate.code → rate` | 1 单位外币 = ? 基准币 |

规则：
- 汇总一律 `wrappedBaseAmount`（`baseAmount ?? amount`，兼容多币种之前的老数据）。
- 改汇率不改历史 `baseAmount`；因此"历史统计"与"今天重新折算"必然有差，这是刻意选择。
- 展示口径：行内金额用账户币种，合计/图表用基准币种，需要时在行尾标 `· USD`。
- 舍入与尾差见 [accounting-conventions.md](accounting-conventions.md) 第 6 节：折算四舍五入到分、
  多币种先折算后求和、尾差挂金额最大的一项。切换基准币是**一次性重述**，必须留审计记录
  （时间、旧/新基准、汇率、影响行数）——当前只折算不记账，属实现缺口。

**切换基准货币（已实现：`CurrencyRebase` + `CurrencyRateStore.rebase`）**

1. 用户选择新基准币 `N`、旧基准币 `O`。
2. 取 `r = rate(O → N)`（即 `rate_new(N)/…`，从现有汇率表推导）；缺少 `O` 的汇率时先要求"从网络更新"或手填，不允许盲切。
3. 金额转换分两类：
   - 账户没有币种（= 跟随基准币）或交易没有账户：`amount` 本身就是旧基准币金额，
     `amount` 与 `baseAmount` 一起乘 r（否则流水行与账户余额会停在旧刻度）；
   - 账户有明确币种：`amount` 是该币种金额，只把 `baseAmount` 乘 r。
   汇率表按 `rate / rate[N]` 重整，新增旧基准币的行、删除新基准币的行。
4. 整个过程一次提交，失败回滚；界面上说明"历史金额按当前汇率折算，之后不再变"。
5. 基准币是**设备本地**设置：`ContentViewModel.bootstrap()` 启动时把生效值写进 App Group 的
   `currency`（`AppBaseCurrency.pin`），此后只有显式切换才改。iCloud KVS 只用来给全新安装播种，
   不会被别的设备静默改写——否则那台设备的 `baseAmount` 会在没有折算的情况下被重新解读。
   读取一律走 `AppBaseCurrency.code`（原始键 → 设备 locale 兜底），不要自己拼默认值。

## 4. 账目口径

矩阵见 [ledger-rules.md](ledger-rules.md)，会计基础（收付实现制、现金流/费用/净资产三口径、
退款与坏账的目标规则）见 [accounting-conventions.md](accounting-conventions.md)。设计约束：

- 模型上只允许三个判定：`countsAsSpend` / `countsAsIncome` / `signedBaseAmount`。
- SwiftData `#Predicate` 无法调用计算属性，谓词里必须写全 `!income && !adjustment && !reimbursable`，改动模型标记时同步 `FilteredBudgetViews`。
- 报销、调整、转账都不进支出；转账手续费只影响余额。
- 账户余额永远包含全部记录（含报销与调整），因为钱确实动了。

## 5. 时间与周期

| 概念 | 归属 | 规则 |
|---|---|---|
| 记账日 `date` | 交易 | 用户可选过去/未来；未来记录进"待发生"分区 |
| `day` / `month` | 交易派生 | 写入时按 `date` 计算，用于快速筛选 |
| 周期交易 | 交易 | `recurringType` 1=天 2=周 3=月；打开 App 时补齐到期的，单次最多补 `Recurrence.maxCatchUp` 条，补完把源记录 `recurringType` 归零 |
| 每月起始日 `firstDayOfMonth` | 设置 | **设计上应统一用于 Log 月度筛选、Insights 月度区间**；预算保留自己的锚点（预算可以 6 月 15 日开始） |
| 周起始 `firstWeekday` | 设置 | Log 周区间、Insights 周区间、小组件一致 |
| 预算周期 | `BudgetModel.type` + `startDate` | 到期自动滚动到下一周期；剩余 = 预算金额 − 该周期内 `countsAsSpend` 的合计 |

## 6. 功能契约

### 6.1 记账

- 必填：金额 > 0、分类（收入分类挂收入，支出分类挂支出）。
- 记账账户的币种没有汇率时拒绝保存（`TransactionValidationError.missingExchangeRate`）：
  写下1:1 的猜测会把错数字冻结进 `baseAmount` 和所有合计；提示条指向「设置 → 货币 → 汇率」。
- 可选：备注、日期、账户、重复、折扣、报销。
- 金额上限 `Money.maxAmount`（1 亿）；非有限值一律拒绝。
- 保存后：写库 → 刷新小组件 → 3/10/25 笔时请求评价；连续记账模式下保留分类/日期/收支类型，清空金额、备注、折扣、报销。
- 编辑：同一套校验；改分类会同步 `income`；改收支类型会清空不匹配的分类与报销标记。
- 校验被拒时提示条**不自动消失**：留在原位直到用户输入数字、改日期、切收支类型或点它一下。
  2 秒的提示读屏软件（VoiceOver）读不完，CI 上的 UI 用例也会因为快照卡顿错过窗口；
  成功提示（「已保存」）仍然是 2 秒。
- 删除：暂存 + 撤销条；重复交易"停止重复"而不是删除。

### 6.2 折扣

- 语义：`amount` 是**实付净额**，`discount` 只是"原价减了多少"，用于展示"优惠 ¥20"。
- 不参与任何统计计算——统计永远用 `amount`（及其 `baseAmount`）。
- 只有支出有意义；收入不显示折扣入口。
- 跨币种账户里折扣与金额同币种。

### 6.3 报销

- 状态机：`普通支出 → 待报销（reimbursable=true, reimbursedAt=nil） → 已报销（reimbursedAt 有值） → 可撤销回待报销`。
- 待报销/已报销都**不计入**支出、预算、分类占比、净收入；账户余额照常扣减。
- 「待报销」列表跨期：三个月前没回款的仍然要出现（这是钱，不是当期消费）。
- 后续扩展（未实现）：部分报销需要 `reimbursedAmount`，否则 8 折报销的自付部分会从统计里消失；关联回款收入交易需要 `reimbursedByID` 才能对账。**在实现部分报销前，规则是"整笔报销"，自付部分另记一笔普通支出。**
- 坏账（已实现）：垫付满 90 天可"核销为支出"——写一条带原因的**费用行**而不是删原行，
  原行只记 `badDebtAt` 退出待报销列表。核销行没有账户（钱当天没动），所以账户余额一分不变，
  但支出、分类占比与预算按核销当期计入损失。规则见
  [accounting-conventions.md](accounting-conventions.md) §3，实现在 `BadDebtPolicy` / `BadDebtLedger`。

### 6.4 账户

- 类型只影响图标与文案，不影响计算。
- 期初余额是"记账之前就有多少钱"，余额 = 期初 + 收入 − 支出 + 转入 − 转出（含手续费）。
- 隐藏：留在列表（半透明），不进总资产。
- 归档：移出默认列表与总资产，不能作为新记账默认账户或转账端点，历史照常解析。
  **设计缺口**：余额非零时归档会让这笔钱从净资产里消失，应先提示"还有 ¥X，建议先转出或调整到 0"。
- 余额调整：不碰期初，写一条 `adjustment` 交易把余额改成用户看到的样子；可追溯、可删除。
  调整应带原因（记错/漏记/手续费/其他），当前没有该字段。
- 负债：`kind = credit` 的余额为**负**表示欠款；**还款是转账不是支出**，
  否则还款会被算成两次消费。额度 `creditLimit` 与账单日 `statementDay` 尚未建模。
- 净资产 = Σ资产余额 − Σ|负债余额|；待报销应收单独展示，不计入净资产
  （钱没回来，净资产不该先变好）。

### 6.5 转账

- 账户间移动，永不计入收支。
- 同币种：只记 `amount`；`destinationAmount = 0` 表示"按同额到账"。
- 跨币种：`amount`（转出）与 `destinationAmount`（实际到账）都存，隐含汇率随记录冻结。
- 手续费 `fee`：源币种，额外从转出账户扣除；流水与账户页显示 `转出 + 手续费`。
- 删除转账 = 两端余额同时回滚。

### 6.6 预算

- 分类预算统计该分类的 `spendBaseAmount`（退款为负）；总预算统计全部 `spendBaseAmount`。
- 报销与调整不计入；转账不计入；退款冲减到账当期。
- 周期到期自动滚动；历史周期不保留快照（按记录实时算）。
- 无分类的预算视为脏数据：剩余显示为全额，不匹配任何交易。

### 6.7 统计

- 周期：周 / 月 / 年；区间受 `firstDayOfMonth`、`firstWeekday` 影响。
- 支出 = `spendBaseAmount` 合计（退款为负，冲减到账当期）；收入 = `countsAsIncome` 的
  `baseAmount` 合计；净 = 收入 − 支出。
- 分类占比只到支出分类；柱状图按周期分桶。
- 商户维度按 `merchantKey` 聚合（`MerchantSummary`，最多 6 行，金额降序）：同一商户的多种写法是一行，未识别的行不进榜。
- 待报销单独成卡，跨期统计，永不混入支出。
- 今日/昨日列表只展示 `countsInTotals` 的行，头部合计与列表同口径。

### 6.8 快捷记账 / 小组件 / 快捷指令

- 模板：分类 + 金额 + 收支类型 + 重复；记账时一键套用（账户取默认账户）。
- 小组件只读，口径与 App 完全一致（`countsAsSpend` 等），写操作走 App Intents。
- 快捷指令："记一笔"复用 `TransactionViewModel.create`；"取统计"复用同一套统计函数。

### 6.9 导入 / 导出 / 清除

- 导出：JSON（完整、可导回，`schemaVersion` 8）+ CSV（单向，给人看）。CSV 末尾两列 `merchant` / `merchant_key` 是追加的，已有列位置不变。
- 导入：按 id 合并、重复跳过、关系按 id 再按名字兜底、整份文件一次提交、失败回滚；拒绝更高版本、拒绝非备份、金额与汇率做防御性收敛。
- 导入后必须刷新：账户、分类、预算、统计、小组件时间线。
- 清除：本地全删（含账户/转账/汇率）+ 尝试删除 CloudKit zone，之后刷新所有缓存。
- 备份携带 `settings`（基准货币、每月起始日、周起始日）：空库直接采用，已有数据且基准币不同则拒绝，避免把旧金额当新币种读。

### 6.10 深链

- `smartbud://add`：金额必需；分类/账户按名称或 UUID 匹配，匹配不到退化为无分类/默认账户；支持 `reimbursable`、`discount`、`date`。
- 加锁未解锁时拒绝写入（`x-error=app_locked`）。
- `x-success` 回 `id / amount / date`，`x-error` 回稳定错误码。
- 应用内不改路由语义：`search` 切到记录页并聚焦搜索，`open?tab=` 切 Tab。

## 7. 状态与缓存

真相源是 SwiftData，但多个视图模型缓存了 fetch 结果：

| 缓存 | 位置 | 失效时机 |
|---|---|---|
| 账户/转账列表 | `AccountViewModel.accounts/transfers` | 账户或转账的增删改、导入、清除、**远端同步** |
| 分类列表 | `CategoryViewModel` | 分类增删改、导入、清除、远端同步 |
| 预算列表 | `BudgetViewModel` | 预算增删改、周期滚动、清除、远端同步 |
| 统计快照 | `InsightsViewModel`（`refreshAll`） | 任何交易变化、周期切换、导入、清除、深链记账、远端同步 |
| 汇率 | `CurrencyRateStore` | 汇率增删改、网络更新、导入、清除 |
| 列表页 | `@Query`（LogView 等） | 自动 |

设计要求：**任何写入路径都必须显式刷新受影响的缓存**，不能依赖"用户会切页面回来"。
统一入口是 `DataRefreshCenter`（`Services/DataRefreshCenter.swift`）：它监听
`NSPersistentStoreRemoteChange` 与 CloudKit 导入事件，回到前台、本地保存、导入、清除、
切换基准币也都走 `refreshAll()`，覆盖上表全部缓存。新增写入路径仍然必须显式调用它。

## 7.1 存储异常与数据保护

启动时记录 `StorageMode`，四种情况对应四种处理，绝不"看起来恢复了、其实写进了另一个库"：

| 模式 | 场景 | 行为 | 提示 |
|---|---|---|---|
| `cloud` | App Group + CloudKit | 正常运行 | 无 |
| `appGroup` | App Group 可用、CloudKit 不可用（macOS/未登录） | 写共享库，恢复后同步 | 离线横幅 |
| `device` | App Group 完全不可达（缺少 entitlement） | 写设备本地库 | 「仅保存在本机」横幅 |
| `memory` | App Group 可用但库打不开（损坏/迁移失败） | **不创建旁路库、不写盘**，仅内存 | 「本次修改不会保存」 |

关键约束：

- App Group 可达但 store 打不开时，不发生任何磁盘写入；原库保持原样等待恢复/升级，
  避免"新数据写进临时库、永远不合并"的假恢复。
- `DataRepository.save()` 失败即 `context.rollback()`，并让写入口返回失败：记账/编辑
  不关闭表单、模板不显示「已记账」、深链回 `save_failed`、快捷指令抛错。
- 清除数据按结果分类：`complete` / `iCloudRetryable`（需重新执行，不会自动删除）/
  `iCloudAccountMismatch`（换了 Apple ID）/ `localFailed` / `storageUnavailable`
  （本地库打不开时拒绝删除 iCloud，避免毁掉唯一副本）。成功后提示重启以重置同步。
- App Lock 通过 App Group 的 `appSessionUnlocked` 同步到 Intents：锁定期间快捷指令
  读写都被拒绝，而不是只挡住 UI。

调试钩子（仅 DEBUG）：`-memoryStore` 强制内存模式，用来验收「本次修改不会保存」
横幅与擦除拒绝；`-proEnforced` 关闭限免验收 Pro 闸门。

## 8. 多设备与同步

- CloudKit 私有库 + App Group 共享容器；小组件只读同一容器。
- 冲突：CloudKit 按字段最后写入者获胜；金额类字段不做合并，冲突时以时间戳较晚者为准（SwiftData 默认行为）。
- 新字段/新实体必须先在 Development 建表，再 Deploy 到 Production，否则老客户端/生产环境同步失败。
- 无 iCloud 账号或容器不可用时降级为本地库并横幅提示，功能不降级。
- 通知权限 ≠ 用户同意：系统权限恢复只影响可投递性，不会自动打开提醒开关。
- 导入后先刷新汇率缓存，再补写旧备份缺失的手续费行，否则手续费按 1:1 冻结。
- 基准货币是设备本地设置（首次启动落盘，见 3），不随 iCloud 悄悄变化；切换只在当前设备折算当前库。
- 因此两台设备可以各自用不同基准币：备份导入时按 `settings.baseCurrency` 校验，不一致就拒绝。

## 9. 交互与导航

- iPhone：TabView（记录 / 统计 / 预算 / 设置）+ 悬浮记账按钮。
- iPad 常规宽度、Mac：`NavigationSplitView` 侧栏，详情列限宽 860。
- 记账页是全屏计算器式布局；键盘避让由系统 safa area 负责；`dynamicType` 上限 accessibility1（Apple 计算器式例外，已注释）。
- 破坏性操作：交易用 6 秒撤销条；账户/分类/清空/导入用 alert 说明后果。
- 空态：`SBEmptyState`（`ContentUnavailableView`）+ 一个明确动作。
- 流水搜索叠加当前筛选（不是只对"全部"生效）；UPCOMING 是独立分区，空态判断同时看两边。
- 账户的隐藏与归档都有可展开分组，任何隐藏操作都必须能撤回；默认账户排除两者。
- App Lock 期间所有「新建」入口（悬浮按钮、`⌘N`、`smartbud://newExpense`）排队，
  解锁后重放；解锁允许设备密码，避免生物识别锁定后无路可走。
- 无障碍：所有图标按钮有 `accessibilityLabel`；金额行 `accessibilityElement(children: .combine)`。
- 动态字体：Log / 记账 / 设置 / 预算在 `accessibility-extra-large` 下实测无截断；
  记账页按计算器布局把字号上限压在 accessibility1。
- RTL：App 只支持 en / zh-Hans / zh-Hant 三种 LTR 语言，界面不提供 RTL 布局；
  若以后加入阿拉伯语等 RTL 语言，需要重新过一遍图表、金额符号与返回箭头方向。
- 本地化：`String.appLocalized` + String Catalog（en / zh-Hans / zh-Hant），新增文案必须同时补三语。

### 9.0 人体工学（可测的硬指标）

不是审美偏好，是每次改动都要守的数值门槛：

| 指标 | 要求 | 为什么 |
|---|---|---|
| 命中区 | ≥ 44×44pt；数字键盘键高 ≥ 64pt | 单手拇指误触的主要来源是 40pt 左右的按钮 |
| 主路径 | 悬浮按钮 → 金额 → 保存 ≤ 3 次点击 | 记账是高频动作，多一次点击就多一批漏记 |
| 默认值 | 分类默认上次、账户默认主账户 | 80% 的账是重复类型，默认值比智能推荐更可靠 |
| 首屏 | iPhone SE（667pt 高）不滚动可见今日支出、本月支出、预算剩余 | 打开 App 的第一眼要能回答"我还剩多少" |
| 拇指区 | 主操作在屏幕下 1/3；顶部只放标题与入口 | 6.1 寸以上机型顶部单手不可达 |
| 金额字号 | 记账页金额 ≥ 34pt | 输错一位的代价远大于版面留白 |
| 方向编码 | 颜色 + 符号/文字双编码 | 红绿色盲约 8% 男性，只靠颜色等于没编码 |
| 对比度 | 深色模式正文 ≥ 4.5:1（WCAG AA） | 夜间使用是记账高峰 |
| 触感 | 只在成功、失败、删除三类事件触发 | 每个点击都震会让人关掉触感 |
| 动效 | 开启"减弱动态效果"时去掉位移/缩放 | 前庭敏感用户会眩晕 |

## 9.1 Pro 功能与闸门

Pro 只拦三个有真实实现、且在付费墙上一一对应的能力：

| 功能 | 闸门 | 免费部分 |
|---|---|---|
| AI 账单分析 | `ProFeature.aiAnalysis` | 其余统计、图表、分类占比 |
| 额外应用图标（6 款） | `ProFeature.customAppIcons` | 默认图标、深/浅色主题 |
| 自定义每日提醒时间 | `ProFeature.customReminderTime` | 早上 8 点 / 晚上 8 点提醒 |

永久免费：记账、账户、转账、预算、基础统计、模板、小组件、通知开关、**导入导出与备份**、
iCloud 同步。导出属于数据可携性（GDPR 20 条），付费会被审核与合规同时质疑。

- 判定唯一入口：`ProAccess.isUnlocked(_:promo:entitled:)`；`SubscriptionManager.isUnlocked`
  传入 `isLimitedTimeFree` 与 `hasActualProEntitlement`。
- 发布期限免：`isLimitedTimeFree` 默认 `true`，到点把它（App Group 的
  `limitedTimeFree`）置 `false` 即生效，功能代码不需要改。
- 验收：DEBUG 构建加启动参数 `-proEnforced` 可强制关闭限免，逐个点 AI / 图标 / 提醒
  确认弹出 Pro 页且不会越过闸门写数据。
- StoreKit：启动时起 `Transaction.updates` 常驻监听，verified 后 `finish()` 并刷新权益，
  跨设备续订、退款、Ask to Buy 批准都不再需要重启。
- 付费墙条目必须与 `ProAccess` 一一对应；不把没有拦截的功能写进付费清单（3.1.1）。

## 10. 版本与迁移

- 导出格式 `ExportSchema.version`（当前 8，schema 8 新增 `badDebtOf` / `badDebtReason` / `badDebtAt`）。加字段必须可选并有默认值；改语义必须升版本，导入端拒绝更高版本。
- App 内数据迁移：新字段一律带默认值，依赖 SwiftData 轻量迁移；不允许"改字段类型"。
- 商户字段（`merchant` / `merchantKey`）是可选普通字段：轻量迁移后为 `nil`，由 `MerchantMigration` 在启动与导入后从备注回填，可重入。JSON 备份不携带这两个字段（避免为一个可推导值升 schemaVersion），恢复后同样靠回填补齐。
- 废弃策略：字段先保留、停止写入，至少一个大版本后再删（CloudKit 上删字段同样要部署）。

## 11. 未实现功能的模型影响

| 功能 | 模型改动 | 影响面 |
|---|---|---|
| 多账本 | `bookID` 贯穿交易/分类/账户/预算/模板 + 当前账本设置 | 所有查询、统计、小组件、导入导出；属于结构性改动 |
| 存钱目标 | 新实体 `SavingsGoalModel`（目标额、截止日、关联账户或独立余额） | 账户页/统计页新增区块；不影响现有口径 |
| 分期 | 新实体 `InstallmentPlanModel` + 生成计划交易（本金/手续费拆分） | 与报销类似，需要"计划支出"这种新身份，先改口径表 |
| Apple Watch | 新 target + App Group 只读 + 极简记账 Intent | 不改变模型，但要同步 schema 与本地化 |

## 12. 现状 vs 设计（差距与优先级）

| 优先级 | 差距 | 状态 |
|---|---|---|
| ~~P0~~ | 切换基准货币整体折算 | ✅ 已实现：`CurrencyRebase` 纯计算 + `CurrencyRateStore.rebase` 一次提交；缺汇率时拒绝并提示；基准币改为设备本地设置（不再从 iCloud KVS 静默改写） |
| ~~P0~~ | 备份携带设置 | ✅ 已实现：导出写入 `settings`；空库直接采用备份设置，已有数据且基准币不同则拒绝并说明 |
| ~~P0~~ | 每月起始日统一 | ✅ 已实现：`AppPeriod` 统一 Log / Insights / 小组件，含 12 个月连续覆盖测试 |
| ~~P1~~ | 远端同步刷新缓存 | ✅ 已实现：`DataRefreshCenter` 监听远端变更与 CloudKit 导入，回前台也会刷新 |
| ~~P1~~ | 归档余额非零 | ✅ 已实现：余额非零时先弹窗说明，再允许归档 |
| **P1（暂缓）** | 部分报销 | 仍未实现：需要 `reimbursedAmount` 与"结算后计自付"口径，按第 13 节第 3 条与分期一起做 |
| ~~P2~~ | 收入行显示折扣入口 | ✅ 收入不再显示折扣，切到收入会清空折扣 |
| ~~P2~~ | 类型筛选包含余额调整 | ✅ 类型筛选排除 `adjustment` |
| ~~P2~~ | 导入无预览 | ✅ 选文件后先显示"备份日期 + N 条记录"，确认后才写库 |
| ~~P2~~ | 本地化无校验 | ✅ `LocalizationCoverageTests` 扫描源码字面量与 SettingsKeys 常量，并校验三语齐全 |
| ~~P1~~ | 退款身份缺失 | ✅ 已实现：`refundOf` 退款行 + `spendBaseAmount` 负向冲减 + 导出 schema 7；退款不计收入 |
| ~~P1~~ | 坏账核销 | ✅ 已实现：`BadDebtPolicy`（90 天门槛、原因枚举）+ `BadDebtLedger`；写一条无账户的 `badDebtOf` 费用行，原行留 `badDebtAt`；导出 schema 8 |
| **P1** | 净资产与信用卡 | 未实现：`kind = credit` 只影响图标，没有额度、账单日与净资产口径 |
| **P2** | 基准币重述无审计 | 未实现：切换基准币折算历史后没有记录，半年后无法解释数字差异 |

## 13. 待拍板的三个决定

1. **切换基准货币**：按当前汇率把所有历史 `baseAmount` 折算过去（推荐），还是禁止有数据后切换？
   - 推荐折算：可用性最好；代价是历史金额会随切换那一刻的汇率轻微变化一次。
2. **归档非零余额账户**：提示后允许（推荐），还是必须余额为 0 才能归档？
   - 推荐提示后允许：账户可能只是不再使用，强制清零会逼用户造假账。
3. **部分报销**：已按推荐决定——本轮保持整笔报销，自付部分另记一笔；`reimbursedAmount` 与"结算后计自付"留到分期功能一起做（两者都需要"分摊"这种新身份）。
