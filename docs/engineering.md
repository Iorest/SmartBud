# 工程与验证

这份文档写「怎么把 SmartBud 跑起来、怎么验证它没坏」。功能口径看
[design.md](design.md)，账目规则看 [ledger-rules.md](ledger-rules.md)。

## 环境要求

| 项 | 版本 | 说明 |
|---|---|---|
| macOS | 15 或更新 | 只在 macOS 上编译，Linux / Windows 没有 Xcode |
| Xcode | 26.x | 工程按 Xcode 26.6 维护（`LastUpgradeCheck = 2660`），`IPHONEOS_DEPLOYMENT_TARGET = 26.0`，必须带 iOS 26 SDK |
| Swift | 6.0 | `SWIFT_VERSION = 6.0`，严格并发检查开启 |
| 模拟器 | iPhone 16 | 见 `app/SmartBud.xcodeproj/xcshareddata/xcschemes/SmartBud.xcscheme` |

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

交互回归由 `app/SmartBudUITests/` 的 5 条 XCUITest smoke 覆盖，走单独的 `SmartBudUITests` scheme：

```bash
xcodebuild test \
  -project app/SmartBud.xcodeproj \
  -scheme SmartBudUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath UITestResults.xcresult
```

| 用例 | 覆盖 |
|---|---|
| `testCreateExpenseSaveAndUndo` | 记一笔 → 保存 → 左滑删除 → 撤销条恢复 |
| `testAllTabsSwitch` | 四个 tab 各切一次 |
| `testSmartEntryCancel` | 打开智能记账 → 关闭 → 取消表单 |
| `testSettingsProBack` | 设置 → Pro → 返回 |
| `testImportPreviewCancel` | 设置 → 导入 → 映射预览 → 取消 |

### 定位锚

测试只认 `accessibilityIdentifier`，不拿界面文案当锚。id 集中在
`app/SmartBudUITests/UITestIdentifiers.swift`，对应实现散在视图里（四个 tab、金额键盘、保存 / 取消、
智能记账、搜索、导入、设置各分区入口、Pro 购买、撤销条）。改视图时 grep 一下 id 还有没有引用。

SwiftUI 不一定会把 tab item 的 id 透传到 `UITabBarButton`，所以 `tabButton` 先取 id，取不到时按
`HomeView.tabShell` 的固定顺序用 index 兜底——两条路都不依赖文案。

### 可访问性审计

每条用例跑一次 `performAccessibilityAudit`（iOS 17+）。失败时用例判红，并把当前屏幕截图 attach 进
`.xcresult`。审计类别由 `AccessibilityAuditPolicy.auditedTypes` 决定，默认是 `.all` 减去
`ignoredTypes`；**跳过的类别必须在本节列出原因**。

当前跳过：无。

报告随 `UITestResults` artifact 上传（`UITestResults.xcresult` + `xcodebuild-ui-test.log`），保留 7 天：

```bash
xcrun xcresulttool get test-results summary --path UITestResults.xcresult
```

### 测试专用启动开关（仅 DEBUG）

- `-uiTestSkipIntro`：跳过首次启动的欢迎流程；
- `IMPORT_SAMPLE=1`：导入向导直接读内置 `sample.csv`，绕开系统文件选择器，稳定到达映射预览。

两个开关都在 `#if DEBUG` 内，Release 构建不受影响。

### 证明测试会红

把任一 identifier 改错（例如把保存按钮的 `entry.save` 改成 `entry.saveX`），`ui-test` job 会红在
「The save button is missing」；改回来即绿。改流程或加交互时，先跑这 5 条，再动界面。

## 运行机约束

**Linux 机器不能编译，也不能跑测试。** 这条约束是按实际运行写的：

- 这台 Linux 运行机没有 `xcodebuild`、`simctl`、iOS SDK，`swift build` 也跑不了 iOS 目标；
- 所有验证只能走 CI，不能声称「本地测试通过」；
- 改代码时能做的静态检查只有读代码、`grep` 结构、检查 schema / 迁移版本号这类非编译验证。

## CI

`.github/workflows/ci.yml`，跑在 GitHub Actions 的 `macos-15` 上：

| 项 | 值 |
|---|---|
| 触发 | push 到 `main`、指向 `main` 的 PR、手动 `workflow_dispatch` |
| Job | `test`：单元测试；`ui-test`：5 条 UI smoke + 可访问性审计 |
| 运行机 | `macos-15`（镜像自带 Xcode 26.x，job 里 `xcode-select` 到最新的 26.x） |
| 命令 | 与上文「测试」/「UI 测试」两节相同，另外带 `-resultBundlePath` |
| 超时 | 45 分钟 / job |
| 产物 | `test` 失败时上传 `TestResults`；`ui-test` 每次上传 `UITestResults`（含截图和审计结果），保留 7 天 |

没用 `macos-14`：该镜像最高只有 Xcode 16.2（没有 iOS 26 SDK），
且 GitHub 在 2026-11-02 之后不再支持它。

失败时先看 job summary 里的测试计数行，再下 artifact 里的 `xcodebuild-test.log`
找第一条 `error:` / `failed`；`.xcresult` 里有逐条用例的截图和日志。

## 解析指标

job summary 里另有一段 "Parsing metrics"，是 `ParsingMetricsTests` 在 800 条语料上算出的
金额 / 方向 / 分类 / 一次通过率，带各自门槛；这一段在测试失败时也会输出。
指标定义、当前基线、门槛规则和语料更新方法见 [ai-eval.md](ai-eval.md)。
