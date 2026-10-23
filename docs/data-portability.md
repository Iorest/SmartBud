# 数据导出与恢复

SmartBud 的本地库是唯一的真相来源，iCloud 只负责同步。要换机、重装或搬走数据，
用「设置 → 数据」里的三个入口：

| 入口 | 用途 | 能否导回 |
|---|---|---|
| 导出我的数据 | 完整备份，一个 JSON 文件 | 能，见「从备份恢复」 |
| 导出 CSV | 给 Numbers / Excel 核对账单 | 不能 |
| 从备份恢复 | 选择 JSON 备份，合并进本机 | — |
| 清除数据 | 删除本机全部记录并尝试清空 iCloud 区域 | — |

## JSON 备份格式（schemaVersion 6）

文件形状见 `smartbud/Services/ExportSchema.swift`，字段名就是磁盘上的契约，
改名前要同时改导出和导入，并且**必须**升 `schemaVersion`。

```json
{
  "exportDate": "2026-10-22T05:00:00Z",
  "appVersion": "4.0",
  "schemaVersion": 6,
  "transactions": [ ... ],
  "categories": [ ... ],
  "budgets": [ ... ],
  "mainBudgets": [ ... ],
  "templates": [ ... ],
  "accounts": [ ... ],
  "transfers": [ ... ],
  "rates": [ ... ]
}
```

约定：

- 金额是**单币种原值**（账户币种），同时另存 `baseAmount`（录入时按当时汇率折算的基准货币金额），
  所以历史统计不会因为之后改汇率而漂移。
- 关系用 id 表示：交易带 `categoryId` / `accountId`，转账带 `sourceId` / `destinationId`。
  为了兼容只存名字的旧文件，导入时会退回到 `categoryName` / `accountName`。
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

## 导入规则：只合并，不覆盖

`smartbud/Services/DataImporter.swift`：

0. 选文件后先预览（备份日期 + 记录条数），用户确认才继续写库。
1. 分类 → 账户 → 汇率 → 交易 → 转账 → 预算 → 总预算 → 模板，顺序固定，保证关系能解析。
2. 有 id 的实体按 id 去重：本机已存在的记录直接跳过，所以**同一个文件导入两次是安全的**。
3. 转账必须两端账户都能解析，否则整条跳过（避免出现一端为空的转账）。
4. 总预算（`MainBudgetModel`）没有 id，按 `金额 + 起始日 + 周期` 三元组去重。
5. 汇率按货币代码更新本机值（属于配置，不算"数据条数"）。
6. 整个导入只在最后 `save()` 一次；失败会 `rollback()`，不会留下半份数据。
7. `schemaVersion` 比当前版本新时直接拒绝：新格式可能换了金额或关系的存法，
   静默导入会把错数字写进账本。
8. 金额做防御性收敛：负数/超上限的金额被夹到 `0...1 亿`，非有限值按 0，
   汇率必须大于 0 否则跳过该条。手工改过的文件不会污染统计。

导入完成后界面会显示「已导入 N 条记录 / 跳过 M 条已存在的记录」。

## CSV 列

```
date,type,amount,currency,base_amount,category,account,note,reimbursable,reimbursed,fee
```

- `type`：`expense` / `income` / `adjustment` / `transfer`
- `transfer` 行的 `account` 写成 `转出账户 → 转入账户`，`fee` 只在这一行有值
- 日期是 `yyyy-MM-dd HH:mm:ss`（设备本地时区），金额固定两位小数
- 按 RFC 4180 转义：含逗号、引号或换行的字段加引号，内部引号翻倍

CSV 是单向的，没有导入实现 —— 需要能导回的场合请用 JSON。

## 导入之后

导入不经过 `DataRepository.save()`（整份文件一次提交），所以要显式刷新：
账户、分类、统计视图模型和小组件时间线。`SettingsImportView` 已经这么做；
新增导入入口时别漏掉这一步。账目口径见 [ledger-rules.md](ledger-rules.md)。
