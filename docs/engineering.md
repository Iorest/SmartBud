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

现有用例在 `app/SmartBudTests/`，用的是 swift-testing（`@Test`），当前 196 个。
跑完日志里会有 `Test run with 196 tests passed`。要看具体哪一条失败，把结果包存下来：

```bash
xcodebuild test \
  -project app/SmartBud.xcodeproj \
  -scheme SmartBud \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath TestResults.xcresult
open TestResults.xcresult
```

只想跑一组用例时，把最后一行换成 `-only-testing:SmartBudTests/BudgetLogicTests`。

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
| 运行机 | `macos-15`（镜像自带 Xcode 26.x，job 里 `xcode-select` 到最新的 26.x） |
| 命令 | 与上文「测试」一节相同，另外带 `-resultBundlePath` |
| 超时 | 45 分钟 |
| 失败产物 | `TestResults.xcresult` 和完整日志，作为 `TestResults` artifact 保留 7 天 |

没用 `macos-14`：该镜像最高只有 Xcode 16.2（没有 iOS 26 SDK），
且 GitHub 在 2026-11-02 之后不再支持它。

失败时先看 job summary 里的测试计数行，再下 artifact 里的 `xcodebuild-test.log`
找第一条 `error:` / `failed`；`.xcresult` 里有逐条用例的截图和日志。

## 解析指标

job summary 里另有一段 "Parsing metrics"，是 `ParsingMetricsTests` 在 800 条语料上算出的
金额 / 方向 / 分类 / 一次通过率，带各自门槛；这一段在测试失败时也会输出。
指标定义、当前基线、门槛规则和语料更新方法见 [ai-eval.md](ai-eval.md)。
