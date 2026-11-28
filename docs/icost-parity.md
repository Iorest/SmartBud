# 与 iCost 的能力对照

> 复核：2026-11-27 · 基线：`main` @ `5a66eb2`（TELE-81 合并后）
> 来源：iCost 官方英文帮助站导航全部页面（见覆盖表）+ iOS 更新日志（最新 `4.7.2` / 2026-11-19，全部为修复项）。
> 下表 `guide/...` 均为 `https://help.icostapp.com/en/` 下的页面；代码路径相对仓库根。
> 状态口径：✅ 用户可用 · 🚧 未完成（括号内为任务号）· ⏸ 暂缓 · ❌ 不做。
> ✅ 以**用户能用**为准：核心逻辑已合并但缺入口的仍记 🚧，并在现状栏注明。

## 先澄清一件事

iCost 是**闭源**产品，没有公开代码仓库。能参考的只有官方帮助文档和 App 行为，
社区里的第三方导入/MCP 工具逆向的是它的数据文件，不是实现。所以本文对标的是
**能力与交互结果**，不涉及代码结构，也不复制界面。iCost 开启自动识别时会把截图 OCR/文本交给
第三方 AI 模型（`guide/law/privacy.html` §2「How We Use AI」第 1 节 1.2），快捷指令方案还要求开启定位权限
（`guide/ai/ai_faq.html` 第 4/5 项）；我们坚持端侧 OCR、不取定位，这是项目非目标，不是待补的功能。

## 覆盖的 iCost 文档

| 帮助站分组 | 页面（路径前缀 `guide/`） | 对应本文 |
|---|---|---|
| 首页、反馈、FAQ | `/en/`、`ask/ask.html`、`faq/net_price.html`、`faq/asset_price_wrong.html`、`faq/widget.html`、`faq/watch.html` | 统计、资产、Widget、平台行 |
| 会员与账号 | `pro/pro.html`、`pro/recover.html`、`other/account.html`、`other/migrate_ios_purchase.html` | 平台与账号行、明确不跟 |
| 同步与备份 | `cloud/sync.html`、`cloud/error.html`、`cloud/fix.html`、`cloud/fix_mac.html`、`cloud/backup.html`、`cloud/recover.html`、`cloud/recover_android.html` | 数据与同步行 |
| 导入/截图/导出 | `import/import.html`、`import/template.html`、`import/wechat.html`、`import/alibao.html`、`snapshot/snapshot.html`、`snapshot/screenshot.html`、`export/export.html` | 数据与同步行 |
| 快捷记账 | `fast/quick.html`、`fast/loop.html`、`fast/template.html`、`fast/url.html` | 记账入口行 |
| 智能记账 | `ai/ai_photo.html`、`ai/ai_text.html`、`ai/ai_audio.html`、`ai/ai_faq.html`、`ai/ai_android.html`、`ai/ai_harmony.html` | 智能记账行、明确不跟 |
| 资产与债权债务 | `asset/hide.html`、`asset/archive.html`、`asset/family.html`、`loan/loan.html`、`loan/installment.html`、`loan/bill_installment.html` | 钱的身份与资产行 |
| 报销/退款、Widget、存钱 | `claim/claim.html`、`claim/refund.html`、`widget/main.html`、`widget/lock.html`、`save/save.html` | 钱的身份、Widget、存钱行 |
| 多账本、基础功能 | `book/book.html`、`book/archive.html`、`book/copy.html`、`more/transfer_fee.html`、`more/discount.html`、`more/batch.html` | 账本、记账入口、批量编辑行 |
| 更新日志与法务 | `other/update.html`、`other/update_android.html`、`other/update_harmony.html`、`law/term.html`、`law/privacy.html`、`law/sdk.html` | 本页口径与主动差异；法务文本不属 parity |

## 能力矩阵

每条四列：iCost 行为 → SmartBud 现状（含代码证据）→ 结论/任务。任务号是本仓库的任务，
「未排期」表示确认有缺口但当前没有对应任务。

### 记账入口与自动化

| 能力（iCost 页面） | iCost 行为 | SmartBud 现状（代码证据） | 结论 / 任务 |
|---|---|---|---|
| 收支/转账（`more/transfer_fee.html`） | 转账可带手续费或折扣，自动生成独立费用/收入行并可换入账账户 | `app/smartbud/Services/TransferFeeLedger.swift:40-98`；`app/smartbud/Data/Helper.swift:127,130` | ✅ — |
| 消费折扣（`more/discount.html`） | 记录优惠额，按折后金额入账 | `app/smartbud/Views/TransactionView+Subviews.swift:182-188,235-240`；`discount` 只展示不进统计，`docs/ledger-rules.md` | ✅ — |
| 秒开（`fast/quick.html`） | 设置后打开 App 直达记账页 | `app/smartbud/Views/Settings/Settings Subviews/SettingsNumberEntryView.swift:19-21,46-47` 的 `launchIntoEntry` | ✅ — |
| 周期记账（`fast/loop.html`） | 按自定义周期自动生成 | `app/smartbud/Data/TemplateTransactionModel.swift:14-25`；`app/smartbud/Logic/BudgetLogic.swift:78-98`（单次最多补 366 期） | ✅ — |
| 模板记账（`fast/template.html`） | 长按/模板页一键记常用账 | `app/smartbud/Views/Templates/TemplatesView.swift:12-25,280-332` | ✅ — |
| URL / x-callback-url（`fast/url.html`） | 深链预填并回传结果 | `app/smartbud/Utilities/DeepLink.swift:71-73,96-99`；`app/smartbud/Views/HomeView+DeepLink.swift:40-70` | ✅ — |
| 文本记账（`ai/ai_text.html`） | 要求「金额 + 描述」 | `app/smartbud/Services/Parsing/SmartEntryParsing.swift:5-7,193-213` | ✅ — |
| 语音记账（`ai/ai_audio.html`，4.6.0 快速语音） | 语音转文字后按同样规则解析 | `app/smartbud/Services/Parsing/SpeechService.swift:15-126` | ✅ — |
| 规则/历史/LLM 三层候选（4.4.x–4.7.1 智能记账改进） | 不命中规则时用同商户历史与模型候选 | `app/smartbud/Services/Parsing/SmartEntryParsing.swift:247-315,336-365`；模型只出候选，金额由代码校验，密钥留 Keychain | ✅ TELE-18 |
| 截图记账（`ai/ai_photo.html`、`snapshot/snapshot.html`） | 截图识别金额/商户/分类 | `app/smartbud/Services/Parsing/OCRService.swift:17-103` 端侧 Vision；`AlipayWechatParser.swift:12-72`；`SmartEntrySheet.swift:344-386` | ✅ — |
| 批量票据识别（4.4.6 起） | 多张票据批量预览确认 | `app/smartbud/Logic/BatchRecognition.swift:87-155`（上限 10 张）；闸门 `SmartEntrySheet.swift:179-186,346-348`、`app/smartbud/Utilities/ProAccess.swift:23,42-45` | ✅ TELE-23（Pro） |
| 批量编辑账单（`more/batch.html`；4.3.0 导入时批量改账本、4.4.7 批量编辑面板、4.7.1 批量改分类） | 长按多选，批量改账户/账本/分类/备注/日期/标签/币种及预算收支标记；不支持报销/退款关联行 | `app/smartbud/Views/LogView.swift:303-325` 多选面板；`app/smartbud/ViewModels/TransactionViewModel.swift:415-522` 逐行应用与结果；`app/smartbud/Logic/BatchEdit.swift` 保护关联行；退款/报销/坏账/计划生成/真实余额调整行按原因跳过。币种不同时拒绝改账户（金额与冻结汇率不能静默改写）；两种「排除」标记在 SmartBud 共用一个 `adjustment` 身份，不新增 schema | ✅ TELE-83（币种批量转换与两种独立排除标记不做） |
| 搜索条件保留（4.6.2） | 可开启缓存搜索条件 | `app/smartbud/Views/LogView.swift:63` 仅 `@State`，切账本即清空（`:203-211`） | ⏸ 低价值，未排期（主动差异） |

### 钱的身份与资产

| 能力（iCost 页面） | iCost 行为 | SmartBud 现状（代码证据） | 结论 / 任务 |
|---|---|---|---|
| 报销管理和部分核销（`claim/claim.html`） | 标待报销，核销可小于原额：留在待报销或生成差额费用行 | `app/smartbud/Data/Helper.swift:140-149`；`app/smartbud/Logic/ReimbursementPolicy.swift:46,63,108`；`app/smartbud/Services/ReimbursementLedger.swift` | ✅ TELE-17 |
| 退款（`claim/refund.html`） | 金额/到账时间/到账账户三要素；时间不早于原账单 | `app/smartbud/Logic/RefundPolicy.swift`；`app/smartbud/Services/RefundLedger.swift:30-125`；`app/smartbud/Views/Transaction/RefundSheet.swift:23` | ✅ TELE-32 |
| 坏账核销 | 长期未回款垫付核销为带原因的费用 | `app/smartbud/Logic/BadDebtPolicy.swift:25-29`（90 天）；`app/smartbud/Services/BadDebtLedger.swift:41-86` | ✅ TELE-32 |
| 分期基础（`loan/installment.html`、`loan/bill_installment.html`） | 账单日自动出账，已执行期数可补录，本金不算当期支出、额度随还款恢复 | 模型/政策/账本/备份已在 `app/smartbud/Data/Helper.swift:621-663`、`Logic/InstallmentPolicy.swift:22-102`、`Services/InstallmentLedger.swift:19-144`；`app/smartbud/Views/` 下无分期录入与计划管理界面 | 🚧 TELE-29 已合并逻辑层；入口未排期 |
| 分期高级口径（同上，4.7.1 前后文档） | 利息按期/首期、未还负债逐期/创建时计入、尾差首期/末期可选 | `InstallmentPolicy.Options` 三项口径（默认按期/创建时/末期）在 `app/smartbud/Logic/InstallmentPolicy.swift:26-63`；`InstallmentPlanModel.options`（`app/smartbud/Data/Helper.swift:639`）、`InstallmentLedger` 生成与额度方向按选项计算；备份 schema 14 往返保留（`app/smartbud/Services/ExportSchema.swift:345`） | ✅ TELE-84 逻辑层；录入入口同 TELE-29 未排期 |
| 贷款记录（`loan/loan.html`） | 独立贷款账户与还款计划 | 代码中无贷款实体或入口 | ⏸ 利率与合规文案成本高 |
| 信用卡负债与净资产（`asset/...`、4.4.0 资产分组） | 账单日/额度/负债计入净资产，还款走转账 | `app/smartbud/Data/Helper.swift:487-489`；`app/smartbud/Logic/AccountBalance.swift:156-193`；`app/smartbud/Views/InsightsView.swift:363-393` | ✅ TELE-33 |
| 资产隐藏/归档（`asset/hide.html`、`asset/archive.html`） | 隐藏留在列表分组，归档退出总资产，非零余额先提示 | `app/smartbud/ViewModels/AccountViewModel.swift:69-83`；`app/smartbud/Views/Accounts/AccountListView+Sections.swift:137-147` | ✅ — |
| 亲属卡/附加支付账户（`asset/family.html`） | 只显示剩余/总额度，不进默认资产，月账单日重置额度 | 账户模型只有 `kind: Int`（`app/smartbud/Data/Helper.swift:473`），无该账户类型和重置规则 | ⏸ 低价值，未排期 |
| 余额调整原因（`faq/asset_price_wrong.html`、4.7.0 批量改账户） | 调整可追溯并带原因 | `app/smartbud/Logic/AccountBalance.swift:38-53`（四类原因）；`app/smartbud/Views/Accounts/AccountListView.swift:330-341`（弹窗选项）；`app/smartbud/Views/Log/LogTransactionRow.swift:100-101`（流水显示）；备份 schema 13 往返保留 | ✅ TELE-81 |
| 存钱目标（`save/save.html`、4.7.1） | 定额周期/灵活起止两种模式，点卡片「再次存入」记转账，图标支持自定义图片 | 两种模式与进度/通知见 `app/smartbud/Logic/SavingsGoal.swift:19-83`、`app/smartbud/Views/SavingsGoalView.swift:13-22`；再次存入写转账见 `app/smartbud/ViewModels/SavingsGoalViewModel.swift:121-128`；图标为 SF Symbol，不上传图片 | ✅ TELE-28；自定义图片 ⏸ |

### 账本、看账与组织

| 能力（iCost 页面） | iCost 行为 | SmartBud 现状（代码证据） | 结论 / 任务 |
|---|---|---|---|
| 多账本（`book/book.html`） | 每笔属一个账本，创建/切换/删除，默认账本只能归档 | `app/smartbud/Views/Settings/SettingsView.swift:460-641`；`app/smartbud/Views/HomeView.swift:29-49`；`app/smartbud/Data/Helper.swift:1001-1020` | ✅ TELE-20/21 |
| 账本归档/复制（`book/archive.html`、`book/copy.html`） | 复制只带名称/图标/类型，不带账单 | `app/smartbud/Data/Helper.swift:1017-1056`（`copy` 复制结构与账户，不复制账单） | ✅ TELE-21 |
| 账户归属多账本（4.6.1） | 一个账户可属于多个账本 | `app/smartbud/Data/Helper.swift:491-492` 的 `AccountModel.bookID` 是**单值**；复制账本时把账户复制成新行（`:1046-1051`），不是同一账户多归属 | 🚧 未排期（需模型改动，不属 TELE-20/21） |
| 分类归档（4.3.0） | 分类可归档不删除 | `CategoryModel` 无 `archived` 字段（`app/smartbud/Data/Helper.swift:417-430`）；`archived` 只属于 `BookModel`/`AccountModel` | 🚧 未排期（低优先级） |
| 统计与趋势（`faq/net_price.html`） | 按时间范围看收支/分类占比，累计切「全部」 | `app/smartbud/Views/InsightsView.swift:39,171` | ✅ — |
| 预算与预测/订阅建议（4.6.2–4.7.1） | 分类预算、超支提醒；4.5.0 起支持预算结转 | 分类/全局预算、预测卡、超支通知与订阅识别见 `app/smartbud/Logic/BudgetLogic.swift:19-33,98-169,216`、`app/smartbud/Views/InsightsView.swift:70-72,536-560`；信封不结转 | ✅ 预算/预测；预算结转见主动差异 |
| 收支日历（4.4.0 账本切换、4.4.5 流畅度修复） | 月历聚合每日收支，可切月/账本 | `app/smartbud/Views/InsightsView.swift:221-273` 的 `calendarSection`；日聚合 `app/smartbud/Logic/AppPeriod.swift:105-125`，快照在 `app/smartbud/ViewModels/InsightsViewModel.swift:366-372` | ✅ TELE-82 |
| 记账地图/定位 | 位置相关看账入口 | 无 MapKit/定位；项目非目标（TELE-31 已取消） | ❌ 不做（定位非目标） |
| 年度总结（4.4.7） | 年末生成年度总结 | `app/smartbud/Views/InsightsView.swift` 仅有「年」统计周期，无总结视图 | ⏸ 低优先级，未排期（主动差异） |
| 标签（`ai_photo.html`、4.4.6 排序） | 记账打标签并按标签筛选 | `app/smartbud/Logic/TagFilter.swift:17,42-54`；`app/smartbud/Views/LogView.swift:477-547` | ✅ TELE-30 |
| 票据附件（`export/export.html` 内嵌图片） | 票据照片随账本导出/同步 | `app/smartbud/Logic/ReceiptAttachment.swift:16-37`（每笔最多 3 张）；CKAsset 同步 `app/smartbud/Services/ReceiptAttachmentSync.swift:24-53` | ✅ TELE-30；XLSX 内嵌图片 ⏸ |

### 数据、同步与自动化

| 能力（iCost 页面） | iCost 行为 | SmartBud 现状（代码证据） | 结论 / 任务 |
|---|---|---|---|
| iCloud 同步/备份恢复（`cloud/*.html`） | 私有云同步、自动备份与迁移 | `app/smartbud/Data/SwiftDataCore.swift:28-44,194-226`；`docs/cloudkit-schema.md`；macOS 目标无 CloudKit entitlement（`SwiftDataCore.swift:198-199`） | ✅ iPhone/iPad；Mac 本地库 |
| JSON 备份与回导 | 带设置与账本的整包备份 | `app/smartbud/Services/ExportSchema.swift:21` 当前 `schemaVersion = 13`（含 `adjustmentReason`）；导入兼容旧版本 | ✅ — |
| Excel 导出（`export/export.html`） | 按时间/账本/账户导出 xlsx，图片内嵌 | `app/smartbud/Services/DataExporter+CSV.swift:21-25` 的 `csvHeader` 为 14 列（含 `tags`），仅 CSV、不可整份导回；JSON 才是备份格式 | ⏸ XLSX 与图片导出低价值 |
| 通用 CSV 导入（`import/import.html`） | 模板/预览/确认写库 | `app/smartbud/Views/ImportDataView+Importing.swift:36` | ✅ — |
| 微信/支付宝账单导入（`import/wechat.html`、`import/alibao.html`） | 导出账单 CSV 后专用解析、去重、预览确认 | 专用解析/去重已实现并测试（`app/smartbud/Services/DataImporter.swift:337,453`；`app/SmartBudTests/DataImporterTests.swift:682-868`）；`DataImporter.swift:224-228` 明确通用 `ImportDataView` 不处理这类文件，`previewBill`/`applyBill` 仅测试调用，无 UI 入口 | 🚧 TELE-19 已合并解析；入口未排期 |
| 模板导入（`import/template.html`） | 下载固定列模板（csv/xls/xlsx）填写后导入 | `app/smartbud/Views/ImportDataView+Importing.swift:36` 的通用 CSV 向导按列名映射并预览，覆盖同样的固定列导入；不提供模板下载与 45 个币种符号表 | ✅ 固定列导入；模板下载 ⏸ |
| 更多导入来源（4.5.0） | 官方持续增加可导入平台 | 仅微信/支付宝专用解析（见上）与通用 CSV，没有其他平台专用适配器 | ⏸ 低价值，未排期 |
| 账单列表截图导入（`snapshot/snapshot.html`、`snapshot/screenshot.html`） | 截支付宝/微信/云闪付账单列表，一次导入多笔 | 有单张票据 OCR（`OCRService.swift:17-103`）与批量票据识别（`BatchRecognition.swift:87-155`），但没有「账单列表截图 → 多笔账」的专用解析流程 | 🚧 未排期 |
| 票据分享（4.4.3） | 分享单张票据 | 票据附件可留存与同步（`ReceiptAttachment.swift:16-37`），无分享入口 | ⏸ 低价值，未排期 |
| 主屏/锁屏小组件（`widget/main.html`、`widget/lock.html`） | 余额、预算、快捷记账 | `app/ExpenditureWidget/ExpenditureWidget.swift:20-27` 注册 6 类（源码 14 个 Swift 文件）；跟随当前账本 `app/ExpenditureWidget/InsightsWidget.swift:118-125` | ✅ — |
| 本地认证、提醒、主题 | 锁屏、自定义提醒、多主题 | `app/smartbud/Utilities/Authentication.swift:81-99`；`AppLockGate.swift`；`ProAccess.swift:15-45` | ✅ — |

### 平台与账号

| 能力（iCost 页面） | iCost 行为 | SmartBud 现状（代码证据） | 结论 / 任务 |
|---|---|---|---|
| Pro 会员（`pro/pro.html`、`pro/recover.html`） | 订阅/买断、恢复购买 | `app/smartbud/Utilities/ProAccess.swift:15-45` 四项 Pro 能力；`app/smartbud/Services/SubscriptionManager.swift:123-140,353` 产品与恢复；限免期全部开放 | ✅ — |
| 账号登录/家庭共享（`other/account.html`、4.7.0 微信/邮箱登录） | 账号体系、会员共享 | 无账号或共享模型；本地库 + 私有 CloudKit | ❌ 不做（无账号体系，隐私与合规成本） |
| Apple Watch（`faq/watch.html`） | 手表端独立入口 | 工程无 watch target | ⏸ 新 target，收益低 |
| Android / HarmonyOS（`other/update_android.html`、`update_harmony.html`、`ai_android.html`） | 跨端 App 与无障碍抓账单 | 仅 Apple 平台；无障碍抓取是项目非目标 | ❌ 不做（跨端等于第二个产品；抓取违反非目标） |
| 购买信息绑定（Android/HarmonyOS） | 跨端复用 iOS 购买 | 无对应端与账号 | ❌ 不做（依赖上一行） |
| 法务与第三方清单（`law/*.html`） | 条款、隐私、SDK 列表 | 仓库有 `docs/TERMS.md`、`docs/privacypolicy.md`；不逐条对标法务内容 | 不适用 |

## 值得借鉴的交互

这些是 iCost 文档写明的行为，判断有用才拿：

1. **智能记账的输入约束**：必须有金额 + 事项描述；我们照做，避免「什么都猜」。
2. **按卡尾号/关键词预填账户**：截图出现「招商银行(4132)」优先选尾号 4132 的账户。
   我们目前靠用户手选；TELE-76 已取消，作为 UX 优化暂不排期。
3. **秒开模式**：`launchIntoEntry` 已实现，打开即记账页。
4. **模板 + URL Scheme**：外部触发记账，已实现；账本可用 `book` 参数指定。
5. **退款三要素**：金额、到账时间、到账账户，且时间不得早于原账单——直接采纳。
6. **分期账单日生成 + 已执行期数**：逻辑层已实现，录入 UI 仍缺（见矩阵）。
7. **报销与退款分离**：钱会回来 vs 交易取消，是两种身份；我们不合并。
8. **存钱「再次存入」记转账**：TELE-28 已按此实现，不记成新收入。

## 明确不跟的地方

| iCost 做法 | 我们不做的理由 |
|---|---|
| 用无障碍服务在后台识别第三方 App 账单页 | 隐私风险高，iOS 上也无法实现同等机制 |
| 识别走服务端并要求定位权限 | 账单截图含姓名、卡号；坚持端侧 OCR，不取定位 |
| 账号登录 / 家庭共享 / 跨端购买绑定 | 引入账号体系与共享数据合规成本；本地 + 私有 CloudKit 已满足单机备份 |
| 会员分层到「多账本/导出」 | 导出属数据可携性（GDPR 20 条），收费会招致审核与合规质疑 |
| 无广告、无社区的买断承诺 | 与我们的 Pro 订阅模型不同，不照抄承诺 |

## 主动差异（不是遗漏）

以下能力在 iCost 更新日志里出现过，我们核对过代码后选择暂缓/不做，不是忘了：

| 能力 | 决定 | 理由 / 重新评估条件 |
|---|---|---|
| 预算结转（4.5.0） | 不做 | 预算按信封法，周期结束不结转（`app/smartbud/Logic/BudgetLogic.swift:19-33`）；结转会改变支出口径 |
| 年度总结（4.4.7） | ⏸ 低优先级 | 现有「年」统计周期可查累计；等有用户反馈再做独立总结页 |
| 搜索条件保留（4.6.2） | ⏸ 低优先级 | 当前切账本清筛选，避免串账；若做需按账本存储 |
| XLSX/图片导出、模板下载与更多导入来源 | ⏸ 低优先级 | CSV + JSON 已覆盖数据进出与固定列导入；图片与多平台模板投入产出比低 |
| 亲属卡账户、贷款记录 | ⏸ 低优先级 | 前者仅展示额度，后者有利率与合规文案成本 |
| Apple Watch、Android/HarmonyOS | ⏸/❌ | 新 target 或第二个产品；与「Apple 平台单机账本」定位不符 |
| 分期高级口径、批量编辑 | 🚧 仅剩 TELE-84 分期高级口径 | TELE-83 批量编辑已上线；见上方能力矩阵 |
| 账单 CSV 导入入口、分期录入 UI | 🚧 未排期 | 解析/政策已合并，缺入口属于交付缺口；应先补入口再算完成 |
| 账户归属多账本（4.6.1）、分类归档（4.3.0） | 🚧 未排期 | `AccountModel.bookID` 是单值，分类无归档字段；需要模型/迁移改动，当前复制账本能满足主要使用场景 |

## 演进顺序（与任务表一致）

1. **钱的身份**：退款/坏账/部分报销/存钱/净资产信用卡/调整原因已 ✅；分期逻辑 ✅ 但入口与高级口径仍 🚧（TELE-84）。
2. **看账入口**：标签/票据附件/多账本/收支日历/批量编辑已 ✅；地图/定位 ❌。
3. **最后才是跨端与可穿戴**：⏸/❌，见主动差异。

理由：身份不全会让统计长期不可信，入口只是便利性；先修账，再加窗。

## 结论

能力矩阵的 ✅ 集中在基础记账、钱的身份、多账本、端侧智能录入、Widget 与数据进出；
剩余差距是**分期高级口径与录入入口**、
**账单 CSV 导入入口**，以及几项明确不做的平台能力。AI 录入比 iCost 更靠前（自带 Key
的三层候选），但准确率基线仍低（见 [ai-eval.md](ai-eval.md)），不能当卖点吹。
