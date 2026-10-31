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

UI 测试在 `app/SmartBudUITests/`，用的是 XCUITest（`XCTestCase`），当前 8 条：

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

```bash
xcodebuild test \
  -project app/SmartBud.xcodeproj \
  -scheme SmartBud \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SmartBudUITests \
  -resultBundlePath UITestResults.xcresult
```

不带 `-only-testing` 会把 `SmartBudTests` 一起跑掉；CI 里两个 job 分开跑，
逻辑测试 job 显式加了 `-only-testing:SmartBudTests`。

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

`XCUITest` 驱动不了系统文件选择器，所以导入用例走的是第二条：验的是「解析出预览 →
返回 → 取消」这条链，不是「文件选择器能不能选到文件」。

### 可访问性审计

目前 5 条用例在末尾调用 `assertAccessible` 跑 `performAccessibilityAudit`
（TELE-36 新增的 3 条纯交互用例尚未接入），发现的问题全部打到日志里
（`AUDIT[屏幕] 类型 描述 [identifier]`），CI job summary 汇总最近 60 条，完整报告在
`UITestResults.xcresult` / `xcodebuild-uitest.log` artifact 里。

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

**Linux 机器不能编译，也不能跑测试。** 这条约束是按实际运行写的：

- 这台 Linux 运行机没有 `xcodebuild`、`simctl`、iOS SDK，`swift build` 也跑不了 iOS 目标；
- 编译与运行验证只能走 CI，不能声称「本地测试通过」；
- 不依赖 Xcode 的静态检查可以本地做：`python3 scripts/check_repo.py`（见下节），
  再加读代码、`grep` 结构、检查 schema / 迁移版本号这类非编译验证。

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

## CI

`.github/workflows/ci.yml`，跑在 GitHub Actions 的 `macos-15` 上：

| 项 | 值 |
|---|---|
| 触发 | push 到 `main`、指向 `main` 的 PR、手动 `workflow_dispatch` |
| 运行机 | `macos-15`（镜像自带 Xcode 26.x，job 里 `xcode-select` 到最新的 26.x） |
| job | `test`（逻辑测试，`-only-testing:SmartBudTests`）与 `ui-test`（`-only-testing:SmartBudUITests`），两个都要绿 |
| 命令 | 与上文「测试」一节相同，另外带 `-resultBundlePath` |
| 超时 | 逻辑测试 45 分钟，UI 测试 60 分钟 |
| 失败产物 | 逻辑测试：`TestResults.xcresult` + 日志，失败时上传；UI 测试：`UITestResults.xcresult` + 日志，**每次**上传（审计报告在里面） |

没用 `macos-14`：该镜像最高只有 Xcode 16.2（没有 iOS 26 SDK），
且 GitHub 在 2026-11-02 之后不再支持它。

失败时先看 job summary 里的测试计数行，再下 artifact 里的 `xcodebuild-test.log`
找第一条 `error:` / `failed`；`.xcresult` 里有逐条用例的截图和日志。

## 解析指标

job summary 里另有一段 "Parsing metrics"，是 `ParsingMetricsTests` 在 800 条语料上算出的
金额 / 方向 / 分类 / 一次通过率，带各自门槛；这一段在测试失败时也会输出。
指标定义、当前基线、门槛规则和语料更新方法见 [ai-eval.md](ai-eval.md)。
