# 工程与验证

这份文档写「怎么把 SmartBud 跑起来、怎么验证它没坏」。功能口径看
[design.md](design.md)，账目规则看 [ledger-rules.md](ledger-rules.md)。

## 环境要求

| 项 | 版本 | 说明 |
|---|---|---|
| macOS | 15 或更新 | 只在 macOS 上编译，Linux / Windows 没有 Xcode |
| Xcode | 26.x | 工程按 Xcode 26.6 维护（`LastUpgradeCheck = 2660`），`IPHONEOS_DEPLOYMENT_TARGET = 26.0`，必须带 iOS 26 SDK |
| Swift | 6.0 | `SWIFT_VERSION = 6.0`，严格并发检查开启 |
| 模拟器 | iPhone 16 | 构建/测试命令与 CI 的 `DESTINATION`；scheme 本身不固定机型 |

依赖只有系统框架（SwiftUI、SwiftData、CloudKit、StoreKit、WidgetKit），
工程里没有 Swift Package 依赖，克隆后不需要 `Resolve Package Versions`。

## 克隆

仓库是私有的，用 SSH：

```bash
git clone git@github.com:Iorest/SmartBud.git
cd SmartBud
```

如果 SSH 走的是 443 端口（公司网络常见），在 `~/.ssh/config` 里加：

```
Host github.com
    Hostname ssh.github.com
    Port 443
    User git
```

## 构建

```bash
xcodebuild build \
  -project app/SmartBud.xcodeproj \
  -scheme SmartBud \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

模拟器构建不需要签名，没有 `DEVELOPMENT_TEAM` 也能过。真机和 TestFlight
需要另外配签名，不在本文范围。

## 测试

```bash
xcodebuild test \
  -project app/SmartBud.xcodeproj \
  -scheme SmartBud \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

现有用例在 `app/SmartBudTests/`，用的是 swift-testing（`@Test`），当前 213 个。
跑完日志里会有 `Test run with 213 tests in 36 suites passed`。要看具体哪一条失败，把结果包存下来：

```bash
xcodebuild test \
  -project app/SmartBud.xcodeproj \
  -scheme SmartBud \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath TestResults.xcresult
open TestResults.xcresult
```

只想跑一组用例时，把最后一行换成 `-only-testing:SmartBudTests/BudgetLogicTests`。

## UI 测试

UI 测试在 `app/SmartBudUITests/`，用的是 XCUITest（`XCTestCase`），当前 8 条冒烟 + 9 条交互 E2E：

| 用例 | 挡住什么 |
|---|---|
| `testCreateExpenseThenUndoDelete` | 记账主链路：金额键盘 → 分类 → 保存 → 上账 → 滑删 → 撤销恢复 |
| `testSaveStaysDisabledWithoutAmount` | 金额为 0 时保存按钮禁用，输入金额后启用 |
| `testEditingAmountUpdatesRow` | 编辑已有记录的金额后，流水行金额随之更新 |
| `testCancelDiscardsDraft` | 取消非空草稿不写入账目行 |
| `testTabsCycleThroughAllFourSections` | 四个 tab 各自还能打开自己的屏 |
| `testSmartEntryOpensAndCancels` | 智能记账弹层的开关，以及弹层关掉后表单还在 |
| `testSettingsOpensProAndBackReturns` | 设置 → Pro → 返回 |
| `testImportPreviewThenCancel` | 导入向导的预览步骤与取消 |

外加 9 条交互 E2E（前缀 `testA<n>_`）。每条的断言都落在数据或文案上（账本行、统计卡、
余额、预算剩余、校验提示）。两条约定让断言不依赖执行顺序：

- **一条用例一个干净库**：`launch()` 带 `-freshStore`，用空的内存 store 启动，
  用例之间不继承数据（否则 A4 的未来日期行会永远排在列表第一，把所有 "最新一行" 断言带偏）。
- **每条记录带唯一备注**（`QA A4b 3F2A`），断言靠备注找行，不靠列表顺序。

| 用例 | 挡住什么 |
|---|---|
| `testA1_addExpense_updatesStats` | 悬浮按钮 → 键盘 12.50 → 分类 → 保存；列表出现该笔，统计支出 +12.50 |
| `testA2_continuousEntry_clearsAmountKeepsCategory` | 勾号长按「Save and Continue」后金额清零、分类与账户保留；第二次保存才关表单 |
| `testA3_invalidInput_isRefusedWithMessage` | 金额 0 时勾号不可用；超过 99,999,999.99 的输入被拒；无分类保存出 `Missing Category` 且不落账 |
| `testA4_discountClaimFutureDate_staysOutOfStats` | 折扣 + 报销标记 + 未来日期：行进 UPCOMING 段、带徽标，且不计入本期支出 |
| `testA5_editAmount_updatesStats_typeSwitchClearsCategory` | 编辑金额后统计同步 +7.50；切到收入时支出分类被清空 |
| `testA6_deleteUndo_restoresFieldsAndBalance` | 滑删 → 撤销：金额、折扣、报销标记、账户余额全部回到删除前 |
| `testA7_sameCurrencyTransfer_movesBalancesOnly` | 同币种转账：两端余额各变 20，支出统计不变 |
| `testA8_crossCurrencyTransfer_feeOnlyInSpend` | 跨币种 + 手续费：到账金额、手续费独立一行；支出只加手续费，转账本体不进 |
| `testA9_budgetRemaining_dropsThenGoesOver` | 分类预算：新建 100 → 花 30 后剩 70 → 再花 100 后显示 `over`，超额数值正确 |

A9 重复跑时会复用上一轮建在同一分类上的预算（分类预算一个分类只允许一个），
断言因此用带符号的剩余额差值。剩余额的**符号**读的是 tile 的 `accessibilityValue`
（`SingleBudgetView.signedRemainingText`，纯带符号数字，亏空为负），不靠解析
「$30.00 over」这句文案：那个数字是无符号量值，解析它只能拼出符号、还会把 tile 上
别的数字一起吃掉。

### 输入金额：两种键盘模式

`ContentViewModel.bootstrap` 把 `numberEntryType` 种成 2（「cent-less」）：键盘左下角是
小数点，`12.50` 就是 `12` `.` `50`，读数显示 `12.50`。老的 1（「pre-dotted」）把每两位
数字当分，同样的金额要敲 `1250`，而且没有小数点键。

用例统一走 `enterAmount(_:_:)`：先按键盘上有没有小数点键判断当前模式，再按模式敲；
清空走 `clearAmount(_:)`，模式 2 下用读数右侧的删除键（`sb.entry.amountDelete`），
模式 1 下用键盘上的退格。用例里不要直接写死 `typeDigits("1250")`——那等于把模拟器当时的
设置写进断言，换个模式就红。

```bash
xcodebuild test \
  -project app/SmartBud.xcodeproj \
  -scheme SmartBud \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SmartBudUITests \
  -resultBundlePath UITestResults.xcresult
```

不带 `-only-testing` 会把 `SmartBudTests` 一起跑掉；CI 里逻辑测试 job 显式加了
`-only-testing:SmartBudTests`。

17 条 UI 用例串行跑一次约 13–14 分钟，超过本项目的 10 分钟预算，所以 CI 把它拆成三个
分片 job（并发跑）：`smoke`（8 条冒烟，按名字 `-skip-testing` 掉全部 E2E 用例）、
`e2e 记账/编辑`（A1–A5）、`e2e 删除/转账/预算`（A6–A9）。**新增用例要同时加进
`.github/workflows/ci.yml` 对应分片的 `tests` 列表**，否则 smoke 分片会把它一起跑掉。
分片用 `-only-testing` / `-skip-testing` 过滤时，标识符必须是 **Target/Class/Method**
（`SmartBudUITests/SmartBudUITests/testA1_…`）：少写一层会静默匹配到 0 条用例，
xcodebuild 仍然返回成功——分片"全绿"但一条都没跑，这种绿是假的。
拆分的另一个约束是 10 分钟预算本身：单条用例再长出 60 秒以上，A6/A8 那个分片就要重新分。

### 元素怎么定位

- 所有查询走 `AccessibilityID`（`app/smartbud/Utilities/AccessibilityID.swift`）。
  这个文件同时编进 app 和 UI 测试 target：改名会编译失败，而不是让用例在运行时静默失效。
- **不用文案当锚点。** app 有 en / zh-Hans / zh-Hant，用例只钉 en，用文案查等于放过另外两种语言。
- 查询走 `app.descendants(matching: .any).matching(identifier:)`：同一个 identifier 在不同
  SwiftUI 容器里可能落在 button、cell 或 staticText 上。
- 两处系统自绘控件拿不到 identifier，只能按位置找，改动时要注意：
  - **底部 tab**：`.tabItem` 由 UITabBar 渲染，Label 上的 identifier 会被丢掉，
    用例按 `HomeView.tabShell` 的固定顺序点第 n 个按钮，点完立刻断言该屏特有的 identifier。
  - **搜索框**：SwiftUI `.searchable` 生成，同样没有 identifier 可挂。
  - Pro 页的购买按钮是 StoreKit 的 `ProductView`，也是系统自绘；identifier 挂在
    `sb.pro.purchaseSection` 容器和 `sb.pro.restore` 上。

### 测试专用启动参数（仅 DEBUG）

用例启动 app 时带这些参数，都只 `#if DEBUG` 生效，Release 行为不变：

| 参数 | 作用 | 代码位置 |
|---|---|---|
| `-skipIntro` | 跳过两页欢迎流程，直接进账本 | `ContentViewModel.bootstrap` |
| `-importSample` | 导入向导直接用 bundle 里的 `sample.csv` 走到预览步，绕开系统文件选择器 | `ImportDataView.body` 的 `onAppear` |
| `-freshStore` | 每次启动一个空的内存 store，不报降级、不弹提示条；UI 用例靠它做到「一条用例一个干净库」 | `DataRepository.freshMemoryContainer` |
| `-skipReviewPrompt` | 不弹 App Store 评分面板。一次 UI 测试会累计跨过第 3/10/25 笔的阈值，系统面板会盖住正在操作的界面 | `ReviewRequester.requestReviewIfAppropriate` |

`XCUITest` 驱动不了系统文件选择器，所以导入用例走的是第二条：验的是「解析出预览 →
返回 → 取消」这条链，不是「文件选择器能不能选到文件」。

### 可访问性审计

目前 5 条用例在末尾调用 `assertAccessible` 跑 `performAccessibilityAudit`
（其余用例尚未接入），发现的问题全部打到日志里
（`AUDIT[屏幕] 类型 描述 [identifier]`），CI job summary 汇总最近 60 条，完整报告在
`UITestResults-<分片>.xcresult` / `xcodebuild-uitest.log` artifact 里。9 条交互 E2E 不跑审计：
它们每条要多走 4–6 个界面，审计本身每次 3–8 秒，加进去就把 E2E 分片顶出 10 分钟预算；
审计的覆盖面由 smoke 用例保证（账本、设置、导入、智能记账四个屏）。

**当前会被显式忽略的类型**（`AccessibilityAuditPolicy.ignoredTypes`），每项都有归属：

| 类型 | 为什么现在不修 |
|---|---|
| `.contrast` | 配色 token 还没做过 AA 对比度核验，属于设计侧整改，不在本次口径内 |
| `.dynamicType` | 数字键盘、图表用的是固定字号（与系统计算器同一取舍），接 Dynamic Type 单独排期 |
| `.textClipped` | 大字号下图表/标签截断，同上，跟着 dynamicType 一起做 |
| `.hitRegion` | 账本徽标、筛选 pill 不足 44pt，需要一次布局整改 |

硬门槛保留 `.trait` 与 `.sufficientElementDescription`：交互元素有没有说明、trait 对不对，
正好是本文件「元素怎么定位」那套 identifier 的地基。新增一个没有可访问性描述或 trait 的控件，
会直接让当次 CI 变红。

要放行某个具体元素（而不是整类问题），把它加进 `ignoredElementIdentifiers` 并写清原因——
按 identifier 放行，不会因为文案改动而意外放宽到别的元素。

## 运行机约束

**Linux 机器不能编译 iOS 目标，也不能跑 UI 测试。** 这条约束是按实际运行写的：

- 这台 Linux 运行机没有 `xcodebuild`、`simctl`、iOS SDK，编不了 app target；
- 完整编译、SwiftData、SwiftUI、CloudKit、StoreKit、解析里的 NaturalLanguage，
  以及全部 XCUITest，仍然只能在 macOS runner 或一台真 Mac 上验证；
- 但 **Foundation-only 的逻辑层可以在 Linux 上真编译真测试**：
  `scripts/linux-tests.sh`（见下节），当前覆盖 69 个用例 / 8 个 suite；
- 不依赖 Xcode 的静态检查也在本地做：`python3 scripts/check_repo.py`（结构与引用）、
  `scripts/check-syntax.sh`（全部 Swift 文件的语法）。


## 离线结构检查

`scripts/check_repo.py` 只用 Python 3 标准库，不需要 Xcode、不需要模拟器，Linux 上也能跑，
覆盖三类「编译前就能发现、不查就要等 CI 变红」的问题：

| 检查 | 挡住什么 |
|---|---|
| `project.pbxproj` 引用 | 文件引用解析不到磁盘上的文件（历史事故：漏写 `smartbud/` 前缀）、磁盘上新增的 `.swift` 没登记进工程、sources 阶段指向不存在的 build file |
| 可访问性 identifier | UI 测试查的 identifier 没有任何 app 源码声明、`AccessibilityID` 常量被改名、`DELIBERATELY-BROKEN` 这类占位值被误合入（历史事故） |
| 文档链接 | `README.md` 与 `docs/*.md` 里指向不存在的相对路径 |

```bash
python3 scripts/check_repo.py          # 0 = 干净，1 = 有问题
```

CI 的 `test` job 第一步就跑它，结构问题几秒内失败，不会先烧掉一次 macOS 构建。
它**不替代** `xcodebuild test`：编译错误、运行行为、UI 流程都查不出来。
接入前用四种真实故障验证过它会报错：漏 `smartbud/` 前缀、占位 identifier、未登记文件、断链。

## 离线语法检查

`scripts/check-syntax.sh` 对 `app/` 下全部 Swift 文件（app、单元测试、UI 测试、Widget、macOS 壳）
跑一次 `swiftc -parse`：只走语法分析，不解析 import、不要 SDK，所以 Linux 上也能跑，
230 个文件约 8 秒。

```bash
export SMARTBUD_SWIFT_HOME=/opt/swift-6.4.2-RELEASE-ubuntu24.04   # 或把 swiftc 放进 PATH
scripts/check-syntax.sh    # 0 = 全部能解析；1 = 有文件解析失败；2 = 没有工具链（跳过，不算失败）
```

挡的是「合进来的文件根本解析不了」这一类：少一个右括号、字符串没闭合、`#if` 没配平。
真正要防的是「作者本地能编，合并后的那一版却从没编过」——这类错误在这里几秒报出来，
不用等 6 分钟的 macOS 构建跑完才看到。

**不挡类型错误**：改签名、把 `Int` 传给 `String`、删掉还在用的符号，都能通过解析，
只有 `xcodebuild` 能发现。所以它是 macOS job 前面的一道便宜闸门，不是替代品。

CI 的 `test` job 在「Select Xcode 26」之后跑它（那时 `swiftc` 一定在 PATH 上）。

## Linux 逻辑测试

`scripts/linux-tests.sh` 把 Foundation-only 的源码和对应测试拼成一个 SwiftPM
测试 target，在 Linux 上真编译、真跑。不需要 Xcode、不需要模拟器、不消耗 macOS 机时。

```bash
# 需要一个 Linux Swift 工具链（6.0+），装机后：
export SMARTBUD_SWIFT_HOME=/opt/swift-6.4.2-RELEASE-ubuntu24.04   # 或把 swift 放进 PATH
scripts/linux-tests.sh
# 输出：✔ Test run with 69 tests in 8 suites passed after 0.014 seconds.
```

覆盖的 suite：`AppPeriod` / `CSVTable` / `DeepLinkRequest` / `LLMProvider` / `Merchant normalisation` /
`MoneyFormatting` / `ProAccess` / `TransactionValidation`。这些是「金额算错就是错账」的那一层。

**不覆盖**：SwiftUI 视图、SwiftData 模型、CloudKit、StoreKit、`ExpenseTextParser` 的
NaturalLanguage 商户抽取、本地化格式化（`AppLocale` / `AppLanguage` 用的是 Apple 专属 API，
harness 用 `scripts/linux-tests/LinuxShims.swift` 顶替了其中三个符号，并已在文件头写明差异），
以及全部 XCUITest。这些仍然只认 macOS。

新增文件要不要进这个子集，看它的 import：只有 `Foundation` 才能进，写进脚本里的
`app_sources` 数组，然后跟一个对应的测试文件。编译不过就是它依赖了 Apple-only 框架。

**在 Arch / Manjaro 上装 swift.org 工具链的两个坑**（官方包按 Ubuntu 打包）：

```bash
ln -sf /usr/lib/libncursesw.so.6 <toolchain>/usr/lib/swift/linux/libncurses.so.6
ln -sf /usr/lib/libxml2.so.16    <toolchain>/usr/lib/swift/linux/libxml2.so.2
```

另外 `TMPDIR` 必须指向一个可写目录，否则 `swift` 会报 `couldNotFindTmpDir`。


## CI

`.github/workflows/ci.yml`，跑在 GitHub Actions 的 `macos-15` 上：

| 项 | 值 |
|---|---|
| 触发 | push 到 `main`、指向 `main` 的 PR、手动 `workflow_dispatch` |
| 运行机 | `macos-15`（镜像自带 Xcode 26.x，job 里 `xcode-select` 到最新的 26.x） |
| job | `test`（逻辑测试，`-only-testing:SmartBudTests`）与 `ui-test` 的三个分片 job（见「UI 测试」一节），全部要绿 |
| 命令 | 与上文「测试」一节相同，另外带 `-resultBundlePath` |
| 超时 | 逻辑测试 45 分钟，UI 测试 60 分钟 |
| 失败产物 | 逻辑测试：`TestResults.xcresult` + 日志，失败时上传；UI 测试：`UITestResults-<分片>.xcresult` + 日志，**每次**上传（审计报告与失败截图在里面） |

没用 `macos-14`：该镜像最高只有 Xcode 16.2（没有 iOS 26 SDK），
且 GitHub 在 2026-11-02 之后不再支持它。

`test` job 的顺序是「便宜的闸门在前」：`check_repo.py`（结构，秒级）→ `Select Xcode 26` →
`check-syntax.sh`（语法，秒级）→ 构建与测试。测试跑完还有一道「确实跑过用例」的校验：
`-only-testing` 过滤不到任何 target 时 xcodebuild 会以 0 退出，
分片 job 因此有过「全绿但一条没跑」的假绿，`test` job 现在也会在日志里找不到
`✔ Test run with N tests`（Swift Testing）或 `Executed N tests`（XCTest）时失败。
注意这个 suite 用的是 Swift Testing，XCTest 自己那行 `Executed 0 tests` 是正常的，不是失败信号。

失败时先看 job summary 里的测试计数行，再下 artifact 里的 `xcodebuild-test.log`
找第一条 `error:` / `failed`；`.xcresult` 里有逐条用例的截图和日志。

## 解析指标

job summary 里另有一段 "Parsing metrics"，是 `ParsingMetricsTests` 在 800 条语料上算出的
金额 / 方向 / 分类 / 一次通过率，带各自门槛；这一段在测试失败时也会输出。
指标定义、当前基线、门槛规则和语料更新方法见 [ai-eval.md](ai-eval.md)。
