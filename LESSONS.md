# LESSONS

复盘教训台账，由夜间复盘（研究与运营项目，博闻）维护，合并由 owner 审。

条目格式：`规则一句话｜原因｜证据｜Seen`。规则：
- 已有条目只追加 Seen 日期，不新开重复条目。
- 同一条在 3 个不同日子出现 → 在该条目下提议升级为检查脚本或仓库规则。
- 60 天未再出现的条目移入「归档」。
- 活跃条目上限 40，超出先归档再新增。

## 活跃

### L1 「本地门禁全绿」不含 app target 编译，交付前必须补编译证据

Linux harness（`scripts/linux-tests.sh`）只覆盖 Foundation 子集，不编译 SwiftUI app target；`#Predicate`、作用域、访问级别错误只能被 macOS CI 拦截。2026-11-24~25 四个 PR（#40/#42/#43/#44）首轮合计 8 次编译失败往返（TELE-21 两轮、TELE-22 一轮、TELE-29 三轮、TELE-33 两轮），每轮多耗一次 CI、一次审查和一次状态流转。交付记录写「本地门禁全绿」但未把「app target 编译」列入未运行清单，属验证声明与实际覆盖不符。

证据：TELE-22 审查打回「app target 编译不过，SwiftData 调用点从未被编译过」（PR #43 head `aba4e9e`）；TELE-29 首轮 CI 两处编译错误、第二轮 `DataExporter.swift:289`（PR #42）；TELE-33 `e36ca66` Build 编译失败（PR #44）；TELE-21 `DataImporterTests.swift:62` 编译失败（PR #40）；TELE-81 首轮 CI 编译错误 `TransactionSnapshot.swift:118:13: argument 'adjustmentReason' must precede argument 'merchant'`（PR #51，run `45815181005`）——同一类又一日再现。

Seen: 2026-11-26、2026-11-27

升级提议：push 前对 app target 做一次仅编译的预检（`xcodebuild build` 或等价 typecheck），或 CI 增加「编译优先」快速 job 作为首个 gate。

### L2 修一个缺陷时改动相邻行，导致同一处 24 小时内改两次

为审查阻塞项打补丁前，先看全函数再改：补丁替换/删除相邻行，下一轮 CI 立刻暴露。TELE-21 修 `TransactionSnapshot` 漏 `bookID` 时把 `let id: UUID` 整行替换掉，`01cc389` 引入编译错误、`cd3a248` 再修（PR #40）；TELE-33 修净资产口径时把记账页「超额提示」阈值弄宽，被明镜二次打回后 `e36ca66` 重修（PR #44）。

证据：TELE-21 评论「01cc389 加 bookID 时误把 `let id: UUID` 那一行替换掉了」；TELE-33 评论「新 head 的改动把记账页『超额提示』的阈值弄宽了，这一条阻塞」（01a21207）。

Seen: 2026-11-26

### L3 CI 红灯先读 job 注解分类：runner 容量失败不派代码修复

macOS arm64 hosted runner 容量不足在 11-24~25 反复制造红灯：run `45360723418` 两分片红（同 head 重跑全绿，TELE-77 判 flake 收口）后，次日 run `45642149966` 又有两个分片因 `The job was not acquired by Runner` 失败；TELE-21 一天内多次因模拟器/容量转 blocked。以重跑收口不解决根因，红灯次日重现——同一处「修」了两次。处置规则：注解为 not-acquired/capacity 时定向重跑即可，不建代码修复任务；只有真实测试失败才派修复。

证据：TELE-77（run `45360723418`，attempt 2 全绿）；run `45642149966` 删除/转账与记账/校验分片注解；TELE-21 blocked 记录（01a20c59、01a20f23）；run `45813437889`（docs-only PR #48 合并提交）「UI e2e 删除/转账」job failure——文档改动不可能破坏 UI 测试，runner 类；TELE-81 两轮 CI 被 runner 队列取消（run `45830579549` job `139946357820`）转 blocked（评论 01a2184c）。本日 main 最新 run `45839577357` 全绿，未建修复任务，符合 L3 处置。

Seen: 2026-11-26、2026-11-27

升级提议：若再出现在 3 个不同日子，向 owner 提议自托管 runner 或削减 UI 分片并发。

### L4 存在未解阻塞评审的 PR 不得合并；合并前阻塞清零，豁免须留痕

PR #48（TELE-75，docs-only）于 2026-11-26 11:45:27Z 被合并，而明镜的评审在 11:42:30Z 已给出 4 项阻塞（文档事实错误），合并使 main 携带这 4 处错误；修复因 PR 已合并无法进入原分支，被迫另开独立 delta PR #49（同一处 parity 文档 24 小时内改两次）。合并前的一手证据（评审评论）本可以拦住这次合并。

证据：TELE-75 评审评论 01a217aa（11:42:30Z，4 项阻塞）vs PR #48 mergedAt 11:45:27Z；PR #49 正文「main 目前仍含这 4 处错误」；TELE-75 评论 01a217ae（修复推到原分支时 PR 已 MERGED）。

Seen: 2026-11-27

## 归档

（空）
