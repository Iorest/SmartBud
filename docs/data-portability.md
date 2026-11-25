# 数据导出与恢复

SmartBud 的本地库是唯一的真相来源，iCloud 只负责同步。要换机、重装或搬走数据，
用「设置 → 数据」里的三个入口：

| 入口 | 用途 | 能否导回 |
|---|---|---|
| 导出我的数据 | 完整备份，一个 JSON 文件 | 能，见「从备份恢复」 |
| 导出 CSV | 给 Numbers / Excel 核对账单 | 不能 |
| 从备份恢复 | 选择 JSON 备份，合并进本机 | — |
| 清除数据 | 删除本机全部记录并尝试清空 iCloud 区域 | — |

## JSON 备份格式（schemaVersion 9）

文件形状见 `smartbud/Services/ExportSchema.swift`，字段名就是磁盘上的契约，
改名前要同时改导出和导入，并且**必须**升 `schemaVersion`。

```json
{
  "exportDate": "2026-10-22T05:00:00Z",
  "appVersion": "4.0",
  "schemaVersion": 9,
  "transactions": [ ... ],
  "categories": [ ... ],
  "budgets": [ ... ],
  "mainBudgets": [ ... ],
  "templates": [ ... ],
  "accounts": [ ... ],
  "transfers": [ ... ],
  "rates": [ ... ],
  "settings": {
    "baseCurrency": "CNY",
    "firstDayOfMonth": 1,
    "firstWeekday": 1
  }
}
```

`settings` 缺失时导入端按"旧备份"处理（不校验基准货币）；导出端总是写入它。

约定：

- 金额是**单币种原值**（账户币种），同时另存 `baseAmount`（录入时按当时汇率折算的基准货币金额），
  所以历史统计不会因为之后改汇率而漂移。
- 关系用 id 表示：交易带 `categoryId` / `accountId`，转账带 `sourceId` / `destinationId`。
  为了兼容只存名字的旧文件，导入时会退回到 `categoryName` / `accountName`。
- schema 9 新增 `reimbursedAmount`（报销支出已回款的基准币累计额）。旧备份没有该键时，
  有 `reimbursedAt` 的整笔报销按全额推导、没有日期的按 0 导入，升级前后统计不变。
  导出端始终写该键；多次回款只合并累计额与各自的回款行，不会重复写入。

- `accounts` 可携带 `creditLimit` / `statementDay` / `dueDay`（credit 账户的额度、账单日、
  还款日）；三者可选，导入端按账户类型收敛：非 credit 或非法值一律按 nil 读入。
  导出端始终写这三个键。schema 版本号由统筹按合并顺序分配，本次不自行抢号。
- schema 8 新增 `badDebtOf` / `badDebtReason` / `badDebtAt`（坏账核销：损失行指向原垫付、
  原因原始值、原行的核销日）。三者都可选，旧备份按 `nil` 导入——旧文件里的垫付仍是待报销，
  不会凭空多出一条费用。
- schema 7 新增 `refundOf`（退款行指向原支出）。旧备份没有该键时按 `nil` 导入——
  那些文件里的退款本来就是记成收入的普通行，导入不会改写它们。
- schema 6 新增 `transferFeeOf`（手续费行指向转账）。旧备份里的转账如果带手续费却没有
  对应支出行，导入后会由 `TransferFeeLedger.migrate` 补写，金额与导入前一致。
- schema 5 新增 `reimbursementOf`（回款行指向原报销支出）。schema 4 的文件仍可导入，
  但那时核销只写了日期、没有回款行，导入后那笔报销依然只有一半——不会自动补写，
  因为无法判断用户当时是否已经把回款记成了普通收入。
- schema 4 新增字段（`discount`、`reimbursable`、`reimbursedAt`、`adjustment`、
  `archived`、`destinationAmount`、`fee`）都是可选的；3.x 的文件缺这些键时按默认值导入。
- 每个 `schemaVersion > 0` 的文件才算备份。缺少该键的 JSON 会被拒绝，避免误把别的文件
  导入成"空备份"。
- 备份带 `settings`（基准货币、每月起始日、周起始日）。**基准货币是金额的读法**：
  本机为空时直接采用备份的设置；本机已有数据且基准货币不同则拒绝导入，由用户先
  在「设置 → 货币」里切换（会整体折算）或清空数据，避免把旧金额当新币种读。
- `baseCurrency` **永远非空**：导出走 `ExportSchema.SettingsDTO.current()` → `AppBaseCurrency.code`，
  用户没手动选过货币时用设备 locale 兜底。早期版本直接读原始键，全新安装的备份里这里
  是空的，导入端因此跳过了币种校验。
- 同一条规则也用于 CSV（仅供阅读，不能导入）：没有账户的行金额本身就是基准币，`currency`
  列写基准币代码而不是留空。

## CSV 导入（Views/ImportDataView*）

- 编码：先按 UTF-8 读，失败后试 UTF-16 与 GB18030；都不行才报"编码不受支持"。
- 表头/前言：按"列数少于主表"剔除文件开头与结尾的标题、昵称、筛选条件、汇总行，
  避免它们变成数据行让整批导入失败。
- 金额：`ImportAmount.parse` 统一处理货币符号、千分位、全角数字、括号负数，
  校验时检查**整列**，不是只看 8 行预览；解析不过的行会中止整批并报行号。
- 日期：用 `en_US_POSIX` 解析，避免泰语/日语区域把年份读成佛历/和历。
- 账户：摘要页可以选"导入到哪个账户"（默认上次使用的账户），每一行都写
  `account` 与冻结的 `baseAmount`；否则总额有这笔钱、账户余额没有。
- 失败：错误页提供「返回」与「关闭」两个出口（全屏页在 iOS 上不能下滑关闭）。
- 重复文件：记住最近 20 个成功导入文件的 SHA-256；再次选中同一文件会先警告
  "这个文件在 X 已导入过"，确认后才继续，避免整本账翻倍。
- 收支方向：负数金额一律按支出写入（即使该值被链接到收入分类也拒绝并报行号）；
  正数仍按链接分类的收支类型。
- 成功页不再自动关闭，提供「完成」与「撤销本次导入」：撤销只删除本次写入的行，
  不会碰导入前就存在的记录。

## 支付宝 / 微信账单 CSV（Services/DataImporter.swift）

`DataImporter.previewBill` / `DataImporter.applyBill` 处理两家平台导出的
"账单 / 交易明细" CSV，表头自带列名，不需要在向导里手工选列；`ImportDataView`
仍是其它银行 CSV 的通用兜底路径。

- 编码：UTF-8（含 BOM）→ UTF-16（必须有 BOM，否则 GB18030 会被误读成 UTF-16）→ GB18030；
  超过 20 MB 的文件直接拒绝。表头按列名识别，列顺序变化不影响映射；
  文件开头的昵称 / 筛选条件与结尾的合计行会被跳过。
- 字段：`交易时间` / `交易创建时间` → `date`，`收/支` → `income`，`金额(元)` → `amount`，
  `交易对方` → 商户与备注，`商品名称` → 备注，`支付方式` → 账户。金额取绝对值，
  方向单独存 `income`，不靠正负号猜。
- 去重：秒级时间 + 金额 + 对方（归一化键）+ 收支方向一致视为重复；同一文件第二次
  预览显示"新增 0 / 跳过 N"。写库时复查一次，防止预览后又落了别的导入。
- 账户：`accountMappings(for:accounts:)` 先按支付方式名匹配现有账户（支持
  "招商银行(1234)" ↔ "招行"这类别名）；匹配不到的必须用户选，`applyBill`
  在写库前直接拒绝，不会静默写一条没有账户的账。
- 写库：逐行校验，坏行进失败报告（`BillImportResult.writeReport(to:)`，
  `line,reason,source_row`），不连累其它行；报告里以 `= + - @` 开头的原始值会加前缀，
  避免表格软件把它当公式执行。整批只在最后保存一次，保存失败才回滚。
- 样例：`app/SmartBudTests/Fixtures/wechat_bill_sample.csv`（UTF-8 BOM）与
  `alipay_bill_sample.csv`（GB18030），各 52 行、金额合计 1334.54 元。

这里不改 JSON 备份格式，也不从账单生成转账 / 退款等关联记录：每一行只写成普通交易，
分类取用户现有分类中名字匹配的一个（否则按收支方向取默认分类），与手工记账同一套字段。

## 导入规则：只合并，不覆盖

`smartbud/Services/DataImporter.swift`：

0. 选文件后先预览（备份日期 + 记录条数），用户确认才继续写库。
1. 分类 → 账户 → 汇率 → 交易 → 转账 → 预算 → 总预算 → 模板，顺序固定，保证关系能解析。
2. 有 id 的实体按 id 去重：本机已存在的记录直接跳过，所以**同一个文件导入两次是安全的**。
3. 转账必须两端账户都能解析，否则整条跳过（避免出现一端为空的转账）。
4. 总预算（`MainBudgetModel`）没有 id，按 `金额 + 起始日 + 周期` 三元组去重。
5. 汇率只补本机没有的货币代码；本机已有该代码时保留本机值、不算"数据条数"
   （用旧备份覆盖今天的汇率会悄悄改掉账户余额与转账建议）。
6. 整个导入只在最后 `save()` 一次；失败会 `rollback()`，不会留下半份数据。
7. `schemaVersion` 比当前版本新时直接拒绝：新格式可能换了金额或关系的存法，
   静默导入会把错数字写进账本。
8. 金额做防御性收敛：负数/超上限的金额被夹到 `0...1 亿`，非有限值按 0，
   汇率必须大于 0 否则跳过该条。手工改过的文件不会污染统计。

导入完成后界面会显示「已导入 N 条记录 / 跳过 M 条已存在的记录」。

## CSV 列

```
date,type,amount,currency,base_amount,category,account,note,reimbursable,reimbursed,fee,merchant,merchant_key
```

- `merchant` / `merchant_key` 是追加在末尾的两列，已有列位置不变
- `type`：`expense` / `income` / `refund` / `adjustment` / `transfer`；`refund` 行的金额为正，
  按支出侧的负向冲减来读（不要把 `expense` 与 `refund` 都当支出累加）
- `transfer` 行的 `account` 写成 `转出账户 → 转入账户`，`fee` 只在这一行有值
- 日期是 `yyyy-MM-dd HH:mm:ss`（设备本地时区），金额固定两位小数
- 按 RFC 4180 转义：含逗号、引号或换行的字段加引号，内部引号翻倍

导出的 CSV 不是备份格式，没有"选它就能整份导回"的路径。支付宝 / 微信的原始账单
可以走上面的自动映射导入；其它银行文件继续用 `ImportDataView` 手工映射列。
要能原样导回请用 JSON。

## 导入之后

导入不经过 `DataRepository.save()`（整份文件一次提交），所以要显式刷新：
账户、分类、统计视图模型和小组件时间线。`SettingsImportView` 已经这么做；
新增导入入口时别漏掉这一步。账目口径见 [ledger-rules.md](ledger-rules.md)。

CSV 导入向导在写库前还会检查目标账户的币种有没有可用汇率：没有就整份拒绝、一条也不写，
避免把 1:1 猜测冻结进 `baseAmount`。JSON 的交易行本来就带着导出时冻结的 `baseAmount`，
不受影响；只有旧备份转账缺手续费行时，若该币种仍无汇率就先不补写，等下次启动的
`TransferFeeLedger.migrate` 再按真实汇率补。
