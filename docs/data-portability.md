# 数据导出与恢复

SmartBud 的本地库是唯一的真相来源，iCloud 只负责同步。要换机、重装或搬走数据，
用「设置 → 数据」里的三个入口：

| 入口 | 用途 | 能否导回 |
|---|---|---|
| 导出我的数据 | 完整备份，一个 JSON 文件 | 能，见「从备份恢复」 |
| 导出 CSV | 给 Numbers / Excel 核对账单 | 不能 |
| 从备份恢复 | 选择 JSON 备份，合并进本机 | — |
| 清除数据 | 删除本机全部记录并尝试清空 iCloud 区域 | — |

## JSON 备份格式（schemaVersion 4）

文件形状见 `smartbud/Services/ExportSchema.swift`，字段名就是磁盘上的契约，
改名前要同时改导出和导入，并且**必须**升 `schemaVersion`。

```json
{
  "exportDate": "2026-10-22T05:00:00Z",
  "appVersion": "4.0",
  "schemaVersion": 4,
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
- schema 4 新增字段（`discount`、`reimbursable`、`reimbursedAt`、`adjustment`、
  `archived`、`destinationAmount`、`fee`）都是可选的；3.x 的文件缺这些键时按默认值导入。
- 每个 `schemaVersion > 0` 的文件才算备份。缺少该键的 JSON 会被拒绝，避免误把别的文件
  导入成"空备份"。

## 导入规则：只合并，不覆盖

`smartbud/Services/DataImporter.swift`：

1. 分类 → 账户 → 汇率 → 交易 → 转账 → 预算 → 总预算 → 模板，顺序固定，保证关系能解析。
2. 有 id 的实体按 id 去重：本机已存在的记录直接跳过，所以**同一个文件导入两次是安全的**。
3. 转账必须两端账户都能解析，否则整条跳过（避免出现一端为空的转账）。
4. 总预算（`MainBudgetModel`）没有 id，按 `金额 + 起始日 + 周期` 三元组去重。
5. 汇率按货币代码更新本机值（属于配置，不算"数据条数"）。
6. 整个导入只在最后 `save()` 一次；失败会 `rollback()`，不会留下半份数据。

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
