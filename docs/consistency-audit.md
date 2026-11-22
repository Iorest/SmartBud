# 文档与代码一致性审计

> 审计日期：2026-10-31 · 基线：`main` @ `71ac8d9`（TELE-36 合并后）
> 范围：`design.md`、`ledger-rules.md`、`accounting-conventions.md`、`data-portability.md`、
> `url-scheme.md`、`cloudkit-schema.md`、`storekit.md`、`engineering.md`、`ai-eval.md`，
> 外加 README 与 docs 索引的链接可达性。
>
> 方法：逐条读文档主张 → 在代码里找对应实现（证据写 `文件:符号` 或 `文件:行号`）→ 给结论。
> 数值类主张另用 `gh run view` 核对 CI 记录、`validate_corpus.py` 核对语料；
> 链接用脚本遍历 README 与 `docs/*.md` 的相对链接。
>
> 结论四档：**一致** · **文档错（本轮已改）** · **代码缺（见文末建议任务）** ·
> **不适用（流程/人工步骤，无法由代码判定）**。

## 结论摘要

| 结论 | 条数 |
|---|---|
| 一致 | 131 |
| 文档错（本轮已改） | 16 |
| 代码缺（建议任务） | 5（去重后 3 项：T1 / T3 / T4，另两行是同一缺口在会计基础与设计文档里的重复主张） |
| 不适用（流程/人工） | 2 |
| 合计 | 154 |

16 处文档错全部在本 PR 修掉，逐条 diff 摘要在 PR 描述里；“代码缺”的 3 项独立缺口见
[建议任务](#建议任务代码缺口)，另有两项产品口径已有任务（TELE-32 / TELE-33），不重复开。
附录另核对了 README 索引里的 `qa-checklist` / `privacypolicy` / `TERMS`（不计入 154 条）：
`qa-checklist` 的 3 处自动化引用已修；隐私政策 5 处事实错误、条款 1 处不完整，
属对外法务文本，留给 owner 确认后再改。

> 2026-11-20 复核：T1 已收口，详见下方 [建议任务](#建议任务代码缺口)。
> 2026-11-22 复核：PR #29 给 `SmartBudUITests.swift` 净增 218 行，§8 里的 `:行号` 引用
> 是 2026-10-31 的快照，已改写为符号名；T7 的缺口按当时 16 条 A/B E2E 重算。
> 2026-11-22 复核（PR #31）：10 条 C 用例合入后 UI 用例 24 → 34、分片 5 → 6
> （新增 `e2e 布局/iPad`）；§8 的 ci.yml 行号引用改写为符号名；T7 缺口按 26 条 A/B/C E2E 重算。
> 上面的摘要是 2026-10-31 的审计快照，历史计数未回改。

## 1. design.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| §2 八个实体与关系（Category/Transaction/Account/Transfer/Budget/MainBudget/Template/CurrencyRate） | `app/smartbud/Data/SwiftDataCore.swift:80` 的 `Schema([...])` 与 `Helper.swift` 的 `@Model` 一一对应 | 一致 | — |
| §2 `TransactionModel` 字段表与不变量（含 `merchantKey == nil` 当且仅当 `merchant == nil`） | `app/smartbud/Data/Helper.swift:18-68`、`Helper.swift:139-155` | 一致 | — |
| §2 删交易走快照、6 秒撤销、快照含全部编辑字段 | `app/smartbud/ViewModels/TransactionViewModel.swift:358`（`undoWindow = 6s`）、`app/smartbud/Logic/TransactionSnapshot.swift:20-35` | 一致 | — |
| §2 删分类：交易保留、`category = nil`、备注原样、预算删除 | `app/smartbud/ViewModels/CategoryViewModel.swift:95-122`（只清 `transaction.category`，未动 `note`） | 一致 | — |
| §2 删账户：交易保留、转账与其手续费行删除 | `app/smartbud/ViewModels/AccountViewModel.swift:187-201` | 一致 | — |
| §3 汇总一律 `wrappedBaseAmount` | `app/smartbud/Data/Helper.swift:116` | 一致 | — |
| §3 切换基准币：一次提交、失败回滚、汇率表重整 | `app/smartbud/Logic/CurrencyRebase.swift:43-71`、`app/smartbud/Services/CurrencyRebaseService.swift:50-91` | 一致 | — |
| §3 切换时缺汇率拒绝并提示 | `CurrencyRebase.plan` 返回 `.missingRate`（`CurrencyRebase.swift:52`），错误文案在 `CurrencyRebaseService.swift:25-29` | 一致 | — |
| §3/会计基础 6“缺汇率时拒绝折算，不允许 1:1 猜” | 记账/编辑：`Views/TransactionView.swift` 的 `submit()` 查 `CurrencyRateStore.needsRate` 后由 `TransactionValidation.error(needsExchangeRate:)` 拒绝；调余额：`AccountViewModel.adjustBalance` 直接 return nil；深链：`HomeView+DeepLink.swift` 回 `missing_rate`；CSV 导入：`ImportDataView+Importing.swift` 的 `importSelectionIsValid()` 整批拒绝；JSON 旧备份手续费行缺汇率时跳过、下次启动补写。判定统一在 `CurrencyConversion.needsRate`，`fallbackRate = 1` 只用于只读合计 | 一致 | — |
| §3 基准币重述必须留审计记录 | 未找到重述记录类型/写入；文档已自认是缺口（`design.md` §3、§12 P2） | 代码缺 | T3 |
| §4 只允许三个判定 `countsAsSpend/countsAsIncome/signedBaseAmount` | `app/smartbud/Data/Helper.swift:139-155` | 一致 | — |
| §5 `Recurrence.maxCatchUp` 限制单次补齐 | `app/smartbud/Logic/BudgetLogic.swift:82-85`（值 366） | 一致 | — |
| §5 `firstDayOfMonth` 统一 Log / Insights / 小组件 | `app/smartbud/Logic/AppPeriod.swift`、`app/SmartBudTests/AppPeriodTests.swift:102-106`、`app/ExpenditureWidget/InsightsWidget.swift:147` | 一致 | — |
| §6.1 金额上限 `Money.maxAmount`（1 亿） | `app/smartbud/Logic/Money.swift:15` | 一致 | — |
| §6.1 第 3/10/25 笔请求评价 | `app/smartbud/Utilities/ReviewRequester.swift:46` | 一致 | — |
| §6.1 连续记账保留分类/日期/收支/重复，清空金额/备注/折扣/报销 | `app/smartbud/Views/TransactionView.swift:286-305` | 一致 | — |
| §6.2 折扣只展示、不进统计 | `discount` 只出现在录入/导出（`Services/DataExporter.swift:121`），Insights/Budget/Widget 均不引用 | 一致 | — |
| §6.3 整笔报销状态机、回款行由 `ReimbursementLedger` 维护 | `app/smartbud/Services/ReimbursementLedger.swift:31-104` | 一致 | — |
| §6.4 隐藏留在列表、归档余额非零先提示 | `app/smartbud/ViewModels/AccountViewModel.swift:69-83`、`Views/Accounts/AccountListView+Sections.swift:137-147` | 一致 | — |
| §6.4 净资产 / 信用卡额度与账单日 | 未找到 `creditLimit` / `statementDay` / 净资产计算；文档 §12 已登记为未实现 | 一致 | 已有任务 TELE-33 |
| §6.5 手续费是独立支出行、`outgoingTotal` 只含 `amount` | `app/smartbud/Services/TransferFeeLedger.swift:40-98`、`Data/Helper.swift:342` | 一致 | — |
| §6.6 预算只统计 `countsAsSpend`；无分类预算不匹配任何交易 | `app/smartbud/ViewModels/BudgetViewModel.swift:101-133`、`Views/Budget/FilteredBudgetViews.swift:70-76` | 一致 | — |
| §6.7 商户榜按 `merchantKey` 聚合、最多 6 行、金额降序 | `app/smartbud/Logic/MerchantSummary.swift:25-66` | 一致 | — |
| §6.9 导出 JSON `schemaVersion` 4 | `ExportSchema.version = 7`（`Services/ExportSchema.swift:16`） | 文档错 | 已改：4 → 6，随后 schema 7 加 `refundOf` |
| §6.9 CSV 末尾追加 `merchant` / `merchant_key` | `app/smartbud/Services/DataExporter+CSV.swift:21-25` | 一致 | — |
| §6.10 深链 `add` 参数、错误码、成功回参 | `app/smartbud/Utilities/DeepLink.swift:47-157`、`Views/HomeView+DeepLink.swift:47-122` | 一致 | — |
| §7 “远端同步没有观察者，建议加 DataChangeCenter” | `app/smartbud/Services/DataRefreshCenter.swift:27-57` 已监听 `NSPersistentStoreRemoteChange` 与 CloudKit 导入，`SmartBudApp.swift:33` 启动 | 文档错 | 已改：改为描述现有 `DataRefreshCenter` |
| §7.1 `StorageMode` 四态与横幅 | `app/smartbud/Data/SwiftDataCore.swift:28-40`、`ContentView.swift:161-183` | 一致 | — |
| §7.1 `save()` 失败即 `rollback()` 并返回失败 | `app/smartbud/Data/SwiftDataCore.swift:214-231` | 一致 | — |
| §7.1 清除结果五分类 | `app/smartbud/Logic/WipeOutcome.swift:10-24`、`Data/SwiftDataCore.swift:298-306` | 一致 | — |
| §9 iPhone 四个 Tab、iPad/Mac 详情列 860 | `app/smartbud/Views/HomeView.swift:174-216`、`HomeView.swift:122` | 一致 | — |
| §9 记账页字号上限 accessibility1 | `app/smartbud/Views/TransactionView+Subviews.swift:78` | 一致 | — |
| §9.1 Pro 只拦三项、额外图标 6 款 | `app/smartbud/Utilities/ProAccess.swift:16-45`、`Views/Settings/Settings Subviews/SettingsAppIconView.swift:32-60`（默认 + 6 款） | 一致 | — |
| §10 导出格式“当前 4” | `ExportSchema.version = 7` | 文档错 | 已改：4 → 6 → 7 |
| §12 表格开头重复两行表头，列数不一致 | 仅文档问题 | 文档错 | 已改：删掉多余表头 |
| §12 已标 ✅ 的九项（对应折算/备份设置/月度/远端刷新/归档/折扣/筛选/预览/本地化） | 逐项抽查：`CurrencyRebaseService.swift:50`、`DataImporter.swift:168-185`、`AppPeriod.swift`、`DataRefreshCenter.swift:27`、`AccountListView+Sections.swift:137`、`TransactionView+Body.swift:332`、`Views/LogView.swift:268`、`SettingsImportView.swift:170`、`LocalizationCoverageTests.swift:109-117` | 一致 | — |
| §12 未实现项：退款、净资产与信用卡、基准币重述审计 | 退款已实现（`Services/RefundLedger.swift`）；`creditLimit` 与重述记录仍未建模，由 TELE-33 与本审计 T3 承接 | 部分过时 | 已改：退款一项标为完成 |

## 2. ledger-rules.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| 三个判定是唯一口径，统计不得手写 `!income` | `app/smartbud/Data/Helper.swift:139-155`；Budget 谓词显式写全三标记（`FilteredBudgetViews.swift:70-76`） | 一致 | — |
| 影响面矩阵：报销垫付/回款、调整、转账不进收支；手续费行进支出 | `Helper.swift:128-155`、`TransferFeeLedger.swift:40-70`、`ExpenditureWidget/InsightsWidget.swift:114` | 一致 | — |
| 报销是一对两行，核销/撤销/编辑/删除都由 `ReimbursementLedger` 维护 | `app/smartbud/Services/ReimbursementLedger.swift:31-104` | 一致 | — |
| 报销回款 `income = true` 但不计收入 | `Helper.swift:135,142` | 一致 | — |
| `baseAmount` 冻结、改汇率不影响历史 | `Helper.swift:116`；`CurrencyRebaseService` 只改 `baseAmount`/`amount` 两处 | 一致 | — |
| 手续费行由 `transferFeeOf` 指回转账，删除后 `fee` 归零 | `app/smartbud/Services/TransferFeeLedger.swift:40-80` | 一致 | — |
| 未来记录不计统计（`date <= now`） | `app/smartbud/ViewModels/InsightsViewModel.swift:99,190,222`、`ViewModels/InsightsViewModel+Log.swift:65` | 一致 | — |
| 未来记录不提前扣减账户余额 | `AccountBalance.current` 汇总账户下全部交易，不按日期过滤（`app/smartbud/Logic/AccountBalance.swift:14-29`、`ViewModels/AccountViewModel.swift:95`） | 文档错 | 已改：写明余额含未来记录 |
| 删分类同时清空备注里的分类名副本 | `CategoryViewModel.delete` 只清 `transaction.category`，`note` 未动（`ViewModels/CategoryViewModel.swift:100-107`） | 文档错 | 已改：改为“备注保留原样” |
| 隐藏账户不进列表 | `AccountViewModel.hiddenAccounts` 与 `AccountListView.hiddenSection` 提供「已隐藏」分组（`ViewModels/AccountViewModel.swift:81-83`、`Views/Accounts/AccountListView.swift:194-208`） | 文档错 | 已改：改为“不进默认列表” |
| 归档不进默认列表/总资产、不能当默认账户、历史照常 | `AccountViewModel.swift:69-77,243-249` | 一致 | — |
| 撤销快照必须含 `reimbursementOf` / `transferFeeOf` 等全部字段 | `app/smartbud/Logic/TransactionSnapshot.swift:20-35` | 一致 | — |
| 导入后刷新账户、分类、统计、小组件 | `Views/Settings/Settings Subviews/SettingsImportView.swift:233-237`（`DataRefreshCenter.refreshAll()` + `WidgetCenter.reloadAllTimelines()`） | 一致 | — |

## 3. accounting-conventions.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| 收付实现制，无应计/账期模型 | 模型无应收应付字段；`TransactionModel` 只有收付事实 | 一致 | — |
| 六种身份判定与现金流/费用归属（含退款） | `Helper.swift` 的 `countsAsSpend` / `isRefund` / `spendBaseAmount` | 一致 | — |
| 退款、坏账、分期未实现（审计当时） | 退款与坏账均已实现（`refundOf` + `RefundPolicy`、`badDebtOf` + `BadDebtPolicy`）；`Installment` 仍无结果 | 退款/坏账已过时 | 已改；分期由 TELE-29 承接 |
| 信用卡：还款是转账、余额为负表示欠款、额度/账单日未建模 | `AccountViewModel.createTransfer`；无 `creditLimit` / `statementDay` | 一致 | 已有任务 TELE-33 |
| 预算信封法、周期结束不结转 | `BudgetViewModel.leftover` 只累计当前周期（`ViewModels/BudgetViewModel.swift:101-133`） | 一致 | — |
| 金额最小单位分，折算四舍五入 | `Money.cents` 用 `NSDecimalRound(..., .plain)`（`Logic/Money.swift:20-44`） | 一致 | — |
| 多币种先折算后求和 | 每行 `baseAmount` 录入时冻结（`Helper.swift:116`），统计按 `Money.sum` 累加（`InsightsViewModel.swift:101`） | 一致 | — |
| 尾差挂当期金额最大项 | 未找到尾差分配逻辑；逐行折算即冻结，不存在汇总层再分配 | 代码缺 | T4 |
| 缺汇率时拒绝折算，不允许 1:1 | 写入口（记账/编辑/调余额/深链/CSV 导入）全部在 `CurrencyRateStore.needsRate` 为真时拒绝；JSON 交易行读文件里冻结的 `baseAmount`，旧备份手续费行缺汇率则留到下次启动补写。`CurrencyConversion.fallbackRate = 1` 只用于只读合计与转账建议 | 一致 | — |
| 切换基准币是一次性重述，必须留审计记录 | 未找到重述记录写入 | 代码缺 | T3 |
| 调整应带原因；当前无原因字段 | `AccountViewModel.adjustBalance` 只写金额/账户/日期，无 reason（`ViewModels/AccountViewModel.swift:219-238`） | 一致 | 已有缺口，见 T6 |
| 调整后余额必须相等（有测试） | 测试目录无 `adjustBalance` 相关用例 | 文档错 | 已改：删掉“（有测试）”，注明现状 |
| §8 每个口径至少一条测试 | 现金流/舍入/重述已有 `ReimbursementLedgerTests`、`CurrencyRebaseTests`、`AppPeriodTests`；退款有 `RefundPolicyTests` / `RefundLedgerTests`；坏账有 `BadDebtPolicyTests` / `BadDebtLedgerTests` | 一致 | — |

## 4. data-portability.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| 设置 → 数据 三个入口（导出 JSON / 导出 CSV / 从备份恢复 / 清除） | `Views/Settings/SettingsView.swift:358`、`Views/Settings/Settings Subviews/SettingsImportView.swift` | 一致 | — |
| JSON 当前 `schemaVersion` 7 | `Services/ExportSchema.swift:16` | 一致 | — |
| JSON 文件含 `settings` | 实际 `Payload.settings` 存在且导出时写入（`ExportSchema.swift:32,99-105`），文档示例漏了该键 | 文档错 | 已改：示例补 `settings` |
| 金额是账户币种原值 + 冻结 `baseAmount` | `ExportSchema.swift:108-134`、`DataExporter.swift` | 一致 | — |
| 关系以 id 为主、`categoryName` / `accountName` 兜底 | `Services/DataImporter+Merger.swift` 的 `resolveAccount` / 分类解析 | 一致 | — |
| schema 7 加 `refundOf`、schema 6 加 `transferFeeOf`、schema 5 加 `reimbursementOf`、schema 4 加字段 | `git log -S` 确认：`2a21687` 4→5、`11b401b` 5→6；schema 7 的 `refundOf` 新增于本次退款实现；DTO 字段均可选 | 一致 | — |
| 只有 `schemaVersion > 0` 的文件算备份 | `Services/DataImporter.swift:120-123` | 一致 | — |
| `settings` 校验：空库采用、有数据且基准币不同则拒绝 | `DataImporter.resolveSettings`（`Services/DataImporter.swift:168-185`） | 一致 | — |
| `baseCurrency` 永远非空 | `ExportSchema.SettingsDTO.current` 走 `AppBaseCurrency.code`（`ExportSchema.swift:99-105`） | 一致 | — |
| CSV 无账户行写基准币代码 | `Services/DataExporter+CSV.swift:74` | 一致 | — |
| CSV 导入编码 UTF-8 → UTF-16 → GB18030 | `Views/ImportDataView+Chrome.swift:16-20` | 一致 | — |
| 表头/前言按列数少于主表剔除 | `Views/ImportDataView+Importing.swift:52-62` | 一致 | — |
| 金额校验整列，不只 8 行预览 | `Views/ImportDataView+Importing.swift:30-34` | 一致 | — |
| 日期用 `en_US_POSIX` | `Views/ImportDataView+Importing.swift:111` | 一致 | — |
| 导入账户与冻结 `baseAmount` | `Views/ImportDataView+Importing.swift:170-183` | 一致 | — |
| 失败页提供「返回」与「关闭」 | `Views/ImportDataView+Chrome.swift:370-375` | 一致 | — |
| 记住最近 20 个文件的 SHA-256 | `Views/ImportDataView.swift:259`、`Views/ImportDataView+Importing.swift:147-157` | 一致 | — |
| 负数金额一律按支出，链接收入分类则报行号 | `Views/ImportDataView+Importing.swift:244-247` | 一致 | — |
| 成功页可撤销本次导入 | `Views/ImportDataView+Chrome.swift:347,387` | 一致 | — |
| 导入顺序：分类→账户→汇率→交易→转账→预算→总预算→模板 | `Services/DataImporter.swift:143-150` | 一致 | — |
| 有 id 的按 id 去重，重复文件安全 | `Services/DataImporter+Merger.swift` 各 `import*` 先查已有 id | 一致 | — |
| 转账两端解析不到则整条跳过 | `Services/DataImporter+Merger.swift:150-156` | 一致 | — |
| 总预算按金额+起始日+周期去重 | `Services/DataImporter+Merger.swift:197-202` | 一致 | — |
| 汇率按代码“更新本机值” | `importRates` 遇到已存在的代码直接 skip，保留本机值（`Services/DataImporter+Merger.swift:86-102`） | 文档错 | 已改：改为“只补缺失、已有保留” |
| 整个导入一次 `save()`，失败 `rollback()` | `Services/DataImporter.swift:152-157` | 一致 | — |
| 拒绝更高 `schemaVersion` | `Services/DataImporter.swift:120-123` | 一致 | — |
| 金额夹到 `0...1 亿`、非有限按 0、汇率须 > 0 | `Services/DataImporter+Merger.swift:261-264`、`:87-89` | 一致 | — |
| CSV 列共 11 列，止于 `fee` | 实际 13 列，末尾还有 `merchant` / `merchant_key`（`Services/DataExporter+CSV.swift:21-25`） | 文档错 | 已改：补两列 |
| “CSV 是单向的，没有导入实现” | 本文上一节就描述了 CSV 导入向导，代码在 `Views/ImportDataView*.swift`；导出的 CSV 只是没有“一键整份导回” | 文档错 | 已改：改写为“导出 CSV 不是备份格式” |
| 导入后显式刷新账户/分类/统计/小组件 | `SettingsImportView.swift:233-237` | 一致 | — |

## 5. url-scheme.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| 注册 `smartbud://` | `app/smartbud/Info.plist:33-37` | 一致 | — |
| `add` 参数：amount/type/category/account/note/date/reimbursable/discount | `Utilities/DeepLink.swift:78-114` | 一致 | — |
| 路由：search / open?tab / insights / budget / newExpense | `DeepLink.swift:47-56`、`Views/HomeView.swift:331-337` | 一致 | — |
| 成功回 `id/amount/date` | `Views/HomeView+DeepLink.swift:118-122` | 一致 | — |
| 失败错误码 `invalid_amount/invalid_date/save_failed/app_locked/missing_rate` | `HomeView+DeepLink.swift:47-51,70-80,105-116` | 一致 | — |
| `add` 支持 `x-cancel` 并会打开对应 URL | `DeepLink.swift:73` 只解析、不保存以外的使用；`HomeView+DeepLink` 只触发 success/error | 文档错 | 已改：注明 `x-cancel` 没有触发点 |
| 锁定时 `add` 返回 `app_locked`，不写数据 | `HomeView+DeepLink.swift:47-51`、`Utilities/AppLockGate.swift:18` | 一致 | — |
| `add` 不做重复检测 | 无去重逻辑 | 一致 | — |
| 金额支持逗号小数点、超过 1 亿截断 | `DeepLink.swift:79-85` | 一致 | — |

## 6. cloudkit-schema.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| 主库容器 `iCloud.com.iorest.smartbud`，小组件同一个容器 | `app/smartbud/SmartBud.entitlements:5-10`、`app/ExpenditureWidgetExtension.entitlements` | 一致 | — |
| 当前 schema 八个实体 | `Data/SwiftDataCore.swift:80-89` | 一致 | — |
| 1.3 新增字段清单（`discount`/报销/`transferFeeOf`/`adjustment`/`merchant*`/`archived`/`fee`） | `Data/Helper.swift:33-68,233,295` | 一致 | — |
| `currencyCode`、`baseAmount`、`destinationAmount` 是普通字段 | `Helper.swift:33,226,290` | 一致 | — |
| 每次改 schema 的四步部署流程 | 人工/CloudKit Dashboard 流程 | 不适用 | — |
| 降级路径：本地库 + 橙色横幅 | `Data/SwiftDataCore.swift:28-40`、`ContentView.swift:161-183` | 一致 | — |
| 删账户保留交易、删相关转账 | `ViewModels/AccountViewModel.swift:187-201` | 一致 | — |
| 汇率启动时 `load()`，可从 Frankfurter/ECB 更新 | `SmartBudApp.swift:31`、`Services/ExchangeRateService.swift:15` | 一致 | — |
| 跨币种转账保存转出与到账金额，汇率随记录冻结 | `Data/Helper.swift:284-338`、`AccountViewModel.createTransfer` | 一致 | — |
| 手续费由独立支出行承担，删行把 `fee` 归零 | `Services/TransferFeeLedger.swift:72-80` | 一致 | — |
| 归档/隐藏可恢复、不计总资产、不做默认账户 | `ViewModels/AccountViewModel.swift:69-83,243-249` | 一致 | — |
| 余额调整不改 `openingBalance` | `ViewModels/AccountViewModel.swift:219-238` | 一致 | — |
| macOS 目标没有 CloudKit entitlement | `app/SmartBudMac/SmartBud-macOS.entitlements` 无 iCloud 键 | 一致 | — |

## 7. storekit.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| 四个 Product ID 与 `SubscriptionManager.productIDs` 完全一致 | `Services/SubscriptionManager.swift:123-128` | 一致 | — |
| 价格 $2.99 / $12.99 / $19.99 / $39.99，订阅组 `SmartBud Pro` | `app/SmartBud.storekit`（products + subscriptionGroups） | 一致 | — |
| scheme 的 Run → Options 指向 `SmartBud.storekit` | `app/SmartBud.xcodeproj/xcshareddata/xcschemes/SmartBud.xcscheme:66-68` | 一致 | — |
| `-proEnforced` 关闭限免 | `Services/SubscriptionManager.swift:63` | 一致 | — |
| 6 款额外图标 | `Views/Settings/Settings Subviews/SettingsAppIconView.swift:32-60` | 一致 | — |
| `Transaction.updates` 常驻监听、verified 后 `finish()` | `Services/SubscriptionManager.swift:244-249` | 一致 | — |
| 退款按 `revocationDate != nil` 过滤 | `Services/SubscriptionManager.swift:267` | 一致 | — |
| 恢复购买走 `AppStore.sync()` | `Services/SubscriptionManager.swift:353` | 一致 | — |
| 法务链接走 `resolveLegalURL`，可用 `SMARTBUD_LEGAL_URL_BASE` 覆盖 | `Services/SubscriptionManager.swift:179-192` | 一致 | — |
| App Store Connect 配置与上线清单 | 人工流程 | 不适用 | — |

## 8. engineering.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| macOS 15+ / Xcode 26.x / `LastUpgradeCheck = 2660` / iOS 26.0 / Swift 6.0 | `app/SmartBud.xcodeproj/project.pbxproj:1411,2119,2230` | 一致 | — |
| 模拟器 iPhone 16 “见 SmartBud.xcscheme” | scheme 不含 destination/机型；iPhone 16 只出现在文档命令与 `jobs.test` / `jobs.ui-test` 的 `env.DESTINATION` | 文档错 | 已改：改为“命令与 CI 的 destination” |
| 工程无 Swift Package 依赖 | 仓库无 `Package.resolved` / `Package.swift` | 一致 | — |
| 构建/测试命令（iPhone 16、`-project app/...`） | `jobs.test` 的 `env` 与 xcodebuild 步骤和文档一致 | 一致 | — |
| 当前 213 个逻辑测试、36 个 suite | `grep -r "@Test"` = 213、`@Suite` = 36 | 一致 | — |
| “当前 5 条 smoke”及用例表 | TELE-36 合并后有 8 条（`app/SmartBudUITests/SmartBudUITests.swift` 的 8 条 smoke 用例，从 `testCreateExpenseThenUndoDelete` 起） | 文档错 | 已改：补 3 条并改为 8 条 |
| “每条用例末尾都跑 `performAccessibilityAudit`” | `assertAccessible(app, screen:)` 只在 smoke 段调用 5 处（`screen` 值 `log` / `tabs` / `smart-entry` / `settings` / `settings-after-import`），A/B E2E 未接入 | 文档错 | 已改：写明 5/8；同步改测试文件头注释；剩余缺口见 T7 |
| `AccessibilityID.swift` 同时编进 app 与 UI 测试 target | `project.pbxproj:514-516` 三处 target membership（app/tests/UI tests） | 一致 | — |
| 用例不用文案当锚点，全部走 identifier | `SmartBudUITests.swift` 查询均走 `AccessibilityID` | 一致 | — |
| `-skipIntro` / `-importSample` 仅 DEBUG 生效 | `ViewModels/ContentViewModel.swift:71-78`、`Views/ImportDataView.swift:224-234` | 一致 | — |
| audit 忽略四类 `.contrast/.dynamicType/.textClipped/.hitRegion` | `app/SmartBudUITests/SmartBudUITests.swift` 的 `AccessibilityAuditPolicy.ignoredTypes` | 一致 | — |
| Linux 运行机不能编译/跑测试 | 本机无 `xcodebuild`/iOS SDK；本轮只做静态核对与 Python 校验 | 一致 | — |
| CI：macos-15、45/60 分钟、两个 job、artifact 策略 | `jobs.test` / `jobs.ui-test` 的 `runs-on`、`timeout-minutes` 与 `Upload test artifacts` / `Upload UI test artifacts` 步骤 | 一致 | — |
| Parsing metrics step `if: always()` 写 job summary | `jobs.test` 的 `Parsing metrics` 步骤 | 一致 | — |

## 9. ai-eval.md

| 文档主张 | 代码事实 | 结论 | 处理 |
|---|---|---|---|
| 实现与语料/基线路径存在 | `app/SmartBudTests/ParsingMetricsTests.swift`、`Fixtures/corpus_text.json`（600）、`corpus_receipts.json`（200）、`metrics_baseline.json`、`Fixtures/README.md` | 一致 | — |
| 五个指标的判定方式 | `app/SmartBudTests/ParsingMetricsTests.swift:108-171` | 一致 | — |
| 分类先过 `resolveCategory`，10 个桶按播种顺序恒等映射 | `ParsingMetricsTests.swift:71-74,92-95` | 一致 | — |
| 金额按分比较（`Money.cents`） | `ParsingMetricsTests.swift:122-126` | 一致 | — |
| 当前基线 88.50 / 87.67 / 47–48.67 / 42.67–44.33 / 70.00，门槛 88.50 / 87.66 / 43.50 / 39.00 / 70.00 | `Fixtures/metrics_baseline.json` 的 `floors` 与 `targets` 逐项一致 | 一致 | — |
| 三条 CI run 链接（绿/红/绿） | `gh run view`：41052863196 success、41053085880 failure、41053718423 success | 一致 | — |
| 43/600 文本返回 nil、60/200 小票算错、字典顺序噪声 | `ExpenseTextParser.swift:106` 仍是 `range(of:options:.regularExpression)`；`matchBucket` 遍历字典（`:142-149`）；小票解析只认平台文案 | 一致 | 数值未在 Linux 复跑，结构证据成立 |
| 语料更新流程（先跑 `validate_corpus.py`） | `python3 app/SmartBudTests/Fixtures/validate_corpus.py` 退出码 0（600/200，PII 0） | 一致 | — |
| 降低门槛必须同 PR 改 `metrics_baseline.json` | 测试比较 `floors` + `sample`（`ParsingMetricsTests.swift:175-181`） | 一致 | — |

## 10. README 与 docs 链接

| 文档主张 | 代码/文件事实 | 结论 | 处理 |
|---|---|---|---|
| Documentation 索引 14 篇全部可达 | 脚本遍历 README + `docs/*.md` 相对链接：0 个断链 | 一致 | — |
| 预览图 7 张存在 | `docs/assets/3.png`…`9.png` 均存在 | 一致 | — |
| “run the 213 tests” | 逻辑测试静态计数 213 | 一致 | — |
| 核心功能免费、Pro 只含 AI 分析/图标/提醒，限免期全开 | `ProAccess.swift:39-45`、`SubscriptionManager.isLimitedTimeFree` | 一致 | — |
| 快捷动作、生物识别、语音/截图记账、小组件 | `Info.plist:46-64`、`Utilities/Authentication.swift:99`、`Views/Transaction/SmartEntrySheet.swift:25,183,199`、`app/ExpenditureWidget/`（14 个 Swift 文件） | 一致 | — |
| iPhone/iPad/Mac 三个构建目标 | `app/smartbud`、`app/SmartBudMac`、`app/ExpenditureWidget` | 一致 | — |

## 本轮文档修正（16 条，对应上表的“文档错”行）

按文档顺序：

1. `design.md` §6.9：导出 `schemaVersion` 4 → 6。
2. `design.md` §10：导出格式“当前 4” → “当前 6”。
3. `design.md` §7：删掉“远端同步没有观察者 / 建议加 DataChangeCenter”的过期缺口，改为描述现有 `DataRefreshCenter`。
4. `design.md` §12：删掉重复、列数不一致的表头两行。
5. `ledger-rules.md`：删分类改为“备注保留原样”，与 `CategoryViewModel.delete` 一致。
6. `ledger-rules.md`：隐藏账户改为“不进默认列表”，与「已隐藏」分组一致。
7. `ledger-rules.md`：未来记录改为“账户余额计入全部记录（含未来日期）”，与 `AccountBalance.current` 一致。
8. `accounting-conventions.md` §7：删掉无对应测试的“（有测试）”，改为现状说明。
9. `data-portability.md`：JSON 示例补 `settings` 及缺失时的处理。
10. `data-portability.md`：导入规则 5 改为“只补缺失汇率、已有保留本机值”。
11. `data-portability.md`：CSV 列表补 `merchant` / `merchant_key`（11 → 13 列）。
12. `data-portability.md`：改写“CSV 没有导入实现”，区分“导出 CSV 不是备份格式”与现有 CSV 导入向导。
13. `url-scheme.md`：注明 `x-cancel` 没有触发点。
14. `engineering.md`：模拟器来源改为“构建/测试命令与 CI 的 destination”，不再指向不包含该信息的 scheme。
15. `engineering.md`：UI 用例 5 → 8，补齐 TELE-36 新增的三条。
16. `engineering.md`：可访问性审计覆盖写明 5/8；同步 `app/SmartBudUITests/SmartBudUITests.swift` 的文件头注释。

相邻文档（不在 9 份范围内，但 README 索引指向，顺带修正，不计入上表）：

- `icost-parity.md`：退款计划由“未建任务”改为 TELE-32。
- `icost-parity.md`：第三方账单导入现状改为“通用 CSV 导入（手工映射列），微信/支付宝专用格式未做”。
- `qa-checklist.md`：3 处 TELE-35 / “每天全量跑”的过期引用（见附录 A）。

## 建议任务（代码缺口）

| 编号 | 标题 | 优先级 | 依赖 | 证据 / 范围 |
|---|---|---|---|---|
| ~~T1~~ | ~~录入/导入缺汇率时不得静默按 1:1 折算~~ | ~~P1~~ | 无 | ✅ 已收口：CSV 导入在 `ImportDataView+Importing.swift` 的 `importSelectionIsValid()` 整批拒绝；JSON 交易行本来带冻结的 `baseAmount`，旧备份手续费补写在缺汇率时跳过、下次启动再补；`CurrencyConversion.needsRate` 与 `CurrencyRateStore.needsRate` 共用同一判定，0/负/非有限汇率也拦。口径测试在 `SmartBudTests/TransactionValidationTests.swift` 的 `CurrencyRateGateTests`；`accounting-conventions.md` §6 |
| T2 | 明确并统一“未来记录是否计入账户余额” | P2 | 需产品确认口径 | `Logic/AccountBalance.swift:14-29` 计入全部记录，与统计的 `date <= now` 不一致；文档已按现状描述，需决定是否改实现 |
| T3 | 基准币重述写审计记录 | P2 | 无 | `Services/CurrencyRebaseService.swift:50-91` 只折算不记录；`design.md` §12 P2、会计基础 §6 |
| T4 | 多币种尾差归属 | P3 | 无（T1 口径已定） | `accounting-conventions.md` §6 要求尾差挂当期最大项，代码逐行折算后直接求和，无尾差分配 |
| T5 | 余额调整不变量测试 | P3 | 无 | `ViewModels/AccountViewModel.swift:219-238`；补“调整后 `balance == target`”的用例（可用内存 container，参照现有 `MerchantMigrationTests`） |
| T6 | 余额调整原因字段 | P2 | 需先定枚举与迁移方案 | `design.md` §6.4、会计基础 §7 都标注缺失；新增可选字段 + 迁移说明 |
| T7 | 26 条 A/B/C E2E 接入可访问性审计 | P3 | 无 | `app/SmartBudUITests/SmartBudUITests.swift` 中 `testA1_`–`testA10_`、`testB1_`–`testB6_` 与 10 条 `testC` 用例均未调用 `assertAccessible(app, screen:)`（PR #29 新增 6 条 B 用例，PR #31 又新增 10 条 C 用例）；只有 5 条 smoke 接入。逐条接入或写明豁免理由 |

## 附录：README 索引内其余文档（不计入上表 154 条）

### A. qa-checklist.md（内部文档，已修）

| 文档主张 | 代码/平台事实 | 结论 | 处理 |
|---|---|---|---|
| “XCUITest（见 TELE-35 的 20 条流程）” | TELE-35 已取消；20 条流程拆在 TELE-36/37/38 | 文档错 | 已改：引用 TELE-36/37/38 |
| “TELE-35 定义 20 条流程……CI 每次 PR 跑” | CI 每次 PR 只跑 TELE-24 的 8 条 smoke（`.github/workflows/ci.yml`）；20 条流程尚未全部落地 | 文档错 | 已改：写明当前覆盖与剩余任务 |
| 回归频率“每天｜全量 UI 流程（TELE-35）” | 没有定时工作流；CI 只在 push / PR / 手动触发 | 文档错 | 已改：标注“尚无定时任务” |

### B. privacypolicy.md（对外法务文本，未改，待 owner 确认）

| 文档主张 | 代码事实 | 结论 | 建议 |
|---|---|---|---|
| §2 交易包含“optional photo” | `TransactionModel` 无图片字段（`Data/Helper.swift:18-68`），导出 schema 也没有；截图只用于 OCR，不落库 | 文档错 | 删除“optional photo” |
| §2 设备数据清单只列交易/分类/预算/偏好 | 实际还有账户、转账、汇率、模板、商户字段；LLM 配置（含 API Key）存 Keychain（`Utilities/KeychainStore.swift:12`、`Services/LLM/LLMClient.swift:24-50`） | 文档错 | 补齐类别并说明 Keychain |
| §3 “iCloud sync 是 end-to-end” | 数据在私有 CloudKit 数据库（`SmartBud.entitlements:5-10`），并非端到端加密；项目不运营服务器属实 | 文档错 | 改为“私有 CloudKit 数据库，仅你的 Apple ID 可访问” |
| §4 只列 CloudKit / StoreKit / UserNotifications / LocalAuthentication | 还使用 Speech（`Services/Parsing/SpeechService.swift:19-45`，未设 `requiresOnDeviceRecognition`，识别可能经 Apple 服务）、Vision（端侧 OCR）、Frankfurter 汇率请求（`Services/ExchangeRateService.swift:15`）、用户自配的 LLM endpoint（`Views/InsightsAIAnalysisView.swift:123-145`，仅汇总数字） | 文档错 | 补“Apple 语音识别/端侧 OCR”与“网络请求”两节 |
| §5 权限只列 Face ID 与 Photo Library Add | 工程还声明并使用麦克风与语音识别（`project.pbxproj:2210-2211`）；没有写相册的代码，截图走 `PhotosPicker` 读用户选中的一张（`Views/Transaction/SmartEntrySheet.swift:108`） | 文档错 | 换成麦克风 / 语音识别 / 相册选择器，删“保存截图到相册” |
| §1/§4 无第三方分析、无崩溃 SDK | 仓库无 SPM 依赖、无分析 SDK | 一致 | — |
| §7 导出 JSON、擦除本地 + CloudKit zone | `Views/Settings/.../SettingsExportView.swift`、`Data/SwiftDataCore.swift:298`、`Logic/WipeOutcome.swift:10-24` | 一致 | — |

### C. TERMS.md（对外法务文本，未改，待 owner 确认）

| 文档主张 | 代码事实 | 结论 | 建议 |
|---|---|---|---|
| §1 Pro 三项：AI 分析、6 款图标、自定义提醒时间 | `Utilities/ProAccess.swift:16-45` | 一致 | — |
| §3a 管理订阅入口仅订阅用户可见、终身用户没有 | `Views/Settings/Settings Subviews/SettingsProView.swift:112-121`（终身用户只给恢复购买）、`SettingsProView+Sections.swift:64` | 一致 | — |
| §3b 恢复购买 | `Services/SubscriptionManager.swift:353`（`AppStore.sync()`） | 一致 | — |
| §5 源码 GPL v3 | `LICENSE`、README | 一致 | — |
| §6 仅列 CloudKit / StoreKit / UserNotifications | 同上，未提语音识别与自配 LLM endpoint；属不完整而非错误 | 文档错（次要） | 与隐私政策同步补第三方/网络说明 |
| 其余条款（退款、免责、管辖） | 法务表述，无法由代码判定 | 不适用 | — |

## 相邻问题（未改）

- 文档内联路径存在两种写法（`smartbud/...` 与 `Logic/...`），均能按 `app/` 前缀解析，但不如 `app/smartbud/...` 明确；本轮不做全量改写。
