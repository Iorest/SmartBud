# 解析指标与回归门槛

`ExpenseTextParser.parse` / `AlipayWechatParser.parse` 的输出会直接填进记账表单，
金额错一位就是错账。这份文档定义这些解析器的语料指标、当前基线、门槛规则，
以及语料该怎么更新。

- 实现：`app/SmartBudTests/ParsingMetricsTests.swift`
- 语料：`app/SmartBudTests/Fixtures/corpus_text.json`（600 条）、`corpus_receipts.json`（200 条）
- 门槛：`app/SmartBudTests/Fixtures/metrics_baseline.json`
- 语料口径：`app/SmartBudTests/Fixtures/README.md`

## 指标定义

指标在 CI 里每次都全量跑一遍语料，逐条比对，分母固定为语料条数 —— 解析返回
`nil` 一律算错（用户看到的是「没认出来」，和填错一样要重来）。

| 指标 | 键 | 判定 |
| --- | --- | --- |
| 金额准确率（文本） | `text_amount` | `parse(text)?.amount == 语料 amount`，按分精确比较 |
| 方向准确率（文本） | `text_direction` | `isIncome` 与语料 `direction` 一致 |
| 分类 top-1（文本） | `text_category` | `resolveCategory(categoryHint)` 得到的桶名与语料 `category` 相同 |
| 端到端一次通过率 | `text_end_to_end` | 金额、方向、分类三项全对 |
| 金额准确率（小票） | `receipt_amount` | `AlipayWechatParser().parse(lines:)?.amount == 语料 amount` |

分类这一项不是直接拿 `categoryHint` 比，而是先过 `resolveCategory`：提示词是内部桶名，
最终落到用户真实分类上，中间那层映射错了也要算错。测试里用 10 个内置桶名按应用播种
顺序建一份内存 SwiftData 分类表，所以 `resolveCategory` 对每个桶都是恒等映射。

金额按分比较：语料里的 JSON 数字先过 `Money.cents(_:)` 转成两位小数的 `Decimal`，
再和 `Decimal(string:)` 解析出的金额比，避免二进制浮点的尾巴参与判定。

## 当前基线

2026-11-24，TELE-18 分支按同一份 600 条语料复算（CI 的 `METRICS` /
`METRICS_SMART` 行是同一口径；具体 run 见交付评论）：

| 指标 | 实测 | 门槛（不得低于） | 与 99.5% 目标的差 |
| --- | --- | --- | --- |
| 金额准确率（文本） | 100.00% | 99.50% | 达标 |
| 方向准确率（文本） | 87.67% | 87.66% | — |
| 分类 top-1（文本） | 47.00%–48.67% | 43.50% | — |
| 端到端一次通过率 | 50.17% | 47.00% | — |
| 金额准确率（小票） | 70.00% | 70.00% | — |

金额提取的正则兜底从 `String.range(of:options:)` 换成 `NSRegularExpression`
后，原先 43 条解析失败的句子全部恢复；「实付/花了/元/块」标签、日期与
计数器噪声规则补上后，600 条金额全部命中。分类仍受字典迭代顺序影响，
一次通过率门槛按最低观测留 3 pp 余量。


## 门槛规则

- **硬门槛**：五个数字都不低于 `metrics_baseline.json` 里的 `floors`。任何一项掉下来都是
  红色 CI，失败信息里带前 5 条错例（id、原话、期望、实得），便于直接定位。
- **棘轮**：`floors` 只升不降。要降低门槛，必须在同一个 PR 里改 `metrics_baseline.json`，
  让倒退出现在 diff 里，而不是被悄悄"重新录制"掉。提升了解析能力也请在同一个 PR 里抬高门槛，
  否则提升会在下一次改动里被吃掉。
- **语料条数校验**：语料条数和 `metrics_baseline.json` 里的 `sample` 不一致时测试失败。
  加语料必然改变分母，强制更新基线就是强制重新看一遍数字。
- **99.5% 已转为硬门槛**：金额准确率实测 100%，`floors.text_amount` 已抬到
  99.5%。E3 记录的「目标值而非硬门槛」偏离至此关闭，后续任何回退都会让 CI 变红。


## 已知差距

1. ~~43/600 条文本解析直接返回 `nil`~~ — 已修复：`String.range(of:options:.regularExpression)`
   对中文返回错误 range，改用 `NSRegularExpression` 并补上日期/计数器噪声规则。
   现在 600/600 条金额命中；规则本身仍是确定性的，不依赖模型。


2. **纸质小票 60/200 条永远算错**。`AlipayWechatParser` 只识别支付宝/微信的账单文案，
   纸质小票没有平台关键词，`parse` 返回 `nil`，所以小票金额准确率的理论天花板是 70%。
   这 70% 记的是「当前解析范围」，不是「小票解析质量」。等纸质小票有独立解析路径，
   要么拆成两个指标，要么把这个门槛抬到 100%。
3. **分类指标有 ±0.5–3 pp 的固有噪声**。`matchBucket` 遍历
   `bucketKeywords: [String: [String]]`，Swift 字典的迭代顺序每个进程都不同，
   语料里有 20 条同时命中多个桶。规则层的 bucket 顺序尚未定死，门槛保留 3 pp
   余量；学习层用用户自己的分类名，不受这个噪声影响。

## 智能记账三层链（规则 → 学习 → LLM）

`ParsingMetricsTests.smartChainMetrics` 在**同一次 CI 运行、同一份语料**里
打印前后对比，避免拿不同时间的旧 run 硬比：

```
METRICS_SMART e2e_before=… e2e_after=… delta_pp=… amount_before=… amount_after=…
```

- `before` 是规则层单独解析的端到端一次通过率；`after` 再叠加「同商户 +
  同收支方向的历史多数分类」。语料里的 `merchant` / `category` 充当用户
  已确认的历史，分歧时返回 nil，不猜分类。
- LLM 不进 CI 指标：它依赖用户自配服务、网络与显式隐私授权，离线指标里
  `llm = nil`。应验收的是离线层提升 ≥ 10 pp 且金额一字不改。
- 当前本地复算：一次通过率 50.17% → 75.33%（+25.17 pp），金额 100% → 100%。
  CI 实测数字以 PR 中的 `METRICS_SMART` 行为准。
- LLM 回包的 JSON schema、金额出处与 `TransactionValidation` 校验在
  `SmartEntryParsingTests` 里用 10 条畸形/恶意回包覆盖；无 Key、断网、3 秒
  超时都退回「请手动填写」的可读提示，不写库。

## 更新语料

语料是 E2 的产物，口径写在其 README 里。改语料时按顺序走：

1. 改 `corpus_text.json` / `corpus_receipts.json`，保持字段与标注规则不变；
2. 跑 `python3 app/SmartBudTests/Fixtures/validate_corpus.py`（字段、类型、金额、分类、PII 全部校验，退出码 0）；
3. 推上去让 CI 跑一次指标测试：条数校验会先失败，日志和 job summary 里有实测数字；
4. 用实测值更新 `metrics_baseline.json` 的 `sample` 与 `floors`（金额/方向/小票按实测截断到 4 位小数，
   分类与一次通过率让 3.5 pp），同步更新本文件「当前基线」表格与日期；
5. PR 里说明「为什么加这些语料、数字怎么动」，不要只贴新数字。

降门槛、删语料、放宽断言都要在 PR 里单独讲清楚理由 —— 这些动作等于降低产品的准确率要求。

## 怎么跑

CI（推荐，也是本仓库唯一能证明"测试通过"的地方）：

```bash
# PR / push 到 main 都会跑；job summary 的 "Parsing metrics" 段落就是指标表
gh pr checks
```

本地 macOS（这台 Linux 运行机没有 Xcode，不能编译）：

```bash
xcodebuild test -project app/SmartBud.xcodeproj -scheme SmartBud \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SmartBudTests/ParsingMetricsTests
```

测试把结果打进日志：`METRICS …` 一行是机器读的数字（`当前/门槛`），
`METRICS_MISS` 行是每条错例，`METRICS_DETAIL` 是语料条数与基线日期。
CI 的 `Parsing metrics` step（`if: always()`）把 `METRICS` 行转成 job summary 里的表格，
测试失败时也照常输出，所以红的那次同样能看到数字。

## 门槛真的会响吗

验过。把 `corpus_text.json` 里一条的期望金额改错，金额准确率掉 0.17 pp，
低于门槛，CI 变红：

| 状态 | run | 结果 |
| --- | --- | --- |
| 绿（基线） | <https://github.com/Iorest/SmartBud/actions/runs/41052863196> | 88.50% / 门槛 88.50%，pass |
| 红（把 `text-0001` 的期望金额 15 改成 16） | <https://github.com/Iorest/SmartBud/actions/runs/41053085880> | 88.33% < 88.50%，fail |
| 绿（还原那条语料） | <https://github.com/Iorest/SmartBud/actions/runs/41053718423> | 恢复 pass |

红的那次失败信息里直接给出 `text-0xxx 「…」期望 X 实得 Y`，不用翻日志找是哪个 case。
