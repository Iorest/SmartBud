# CloudKit 上架前检查清单

SmartBud 用 SwiftData + CloudKit 私有库同步。**代码里的 schema 变了，云端不会自动跟着变**：
开发环境（Development）会在首次写入时自动建表，但生产环境（Production）必须手动部署，否则老用户升级后
同步会失败（本地数据仍在，只是不进 iCloud）。

## 涉及的两个 CloudKit 容器

| 用途 | Container | 说明 |
|---|---|---|
| App 主库 | `iCloud.com.iorest.smartbud` | 见 `smartbud/SmartBud.entitlements` |
| 小组件 | 同一个容器 | 小组件只读，不需要单独部署 |

## 当前 schema（`smartbud/Data/SwiftDataCore.swift` 的 `Schema([...])`）

| 实体 | 首次引入版本 | 备注 |
|---|---|---|
| `TransactionModel` | 1.0 | |
| `CategoryModel` | 1.0 | |
| `BudgetModel` | 1.0 | |
| `MainBudgetModel` | 1.0 | |
| `TemplateTransactionModel` | 1.0 | |
| `AccountModel` | 1.1 | 新增实体，`transactions` / `outgoingTransfers` / `incomingTransfers` 必须是可选数组（CloudKit 限制 to-many 可空） |
| `TransferModel` | 1.1 | 新增实体，`source` / `destination` 指向 `AccountModel` |
| `CurrencyRate` | 1.2 | 新增实体，每个外币一行（code / rate / updatedAt） |

### 1.3 新增的普通字段（同样需要部署）

| 实体 | 字段 | 说明 |
|---|---|---|
| `TransactionModel` | `discount` | 录入时的优惠金额。`amount` 始终是实付净额，`discount` 只用于展示"原价" |
| `TransactionModel` | `reimbursable` / `reimbursedAt` | 报销标记与收到回款的时间。标记为报销的支出不计入支出统计与预算 |
| `TransactionModel` | `reimbursementOf`（UUID，可空） | 回款行指向原报销支出的 id。回款行 `income = true` 且不计入收入统计，核销时自动写入 |
| `TransactionModel` | `transferFeeOf`（UUID，可空） | 手续费行指向转账的 id。转账手续费现在是一条支出行，计入支出与预算 |
| `TransactionModel` | `adjustment` | 「余额调整」写入的更正行，只改账户余额，不进收支统计 |
| `TransactionModel` | `merchant` / `merchantKey`（可空） | 商户展示名与归一化分组键，由备注派生。无商户实体，两个字段随交易一起删除 |
| `AccountModel` | `archived` | 归档账户：不在默认列表、不计入总资产，但历史记录照常可查 |
| `TransferModel` | `fee` | 转账手续费，从转出账户额外扣除 |

`AccountModel.currencyCode`、`TransactionModel.baseAmount`、`TransferModel.destinationAmount` 都是普通字段（非关系），CloudKit 可直接兼容。

## 每次改 schema 后要做的四步

1. **本机跑一遍真实写入**
   在模拟器或真机上：新建账户、记一笔、做一次转账、改一次分类。目的不是测 UI，而是让 CloudKit
   在 Development 环境把新表/新字段建出来。
2. **CloudKit Dashboard → Schema → Deploy Schema Changes**
   逐条确认 `AccountModel`、`TransferModel` 及其 `CD_*` 字段、关系都被列出，然后 Deploy 到 Production。
3. **验证生产环境**
   用 TestFlight 包（不是 Debug 包）在已登录 iCloud 的设备上记一笔，确认 Dashboard → Data →
   Records 能看到新记录。
4. **旧版本兼容**
   已发布版本的客户端不认识新实体，CloudKit 会忽略未知 record type，因此**不需要**强制升级；
   但反向（新客户端写、旧客户端读）会出现"看不到账户"的现象，发布说明里要写清楚。

## 已知限制

- 本地降级路径：`SwiftDataCore` 在 CloudKit 初始化失败时会退回本地库并显示"离线模式"横幅
  （截图里橙色横幅）。这是设计内行为，不是崩溃。
- 无 iCloud 账号的模拟器一定走降级路径，做同步相关验证必须用登录了 iCloud 的真机。
- 删除账户会连带删除与它相关的转账（转账需要两头都有账户才有意义）；交易本身保留，只清空归属。
- 汇率在启动时由 `CurrencyRateStore.load()` 读入，记账时用它把金额折算到基准货币写进 `baseAmount`。
  改汇率不会改写历史交易的 `baseAmount`，所以统计口径稳定。
- 汇率可由用户在「设置 → 货币 → 汇率」手动填写，也可点「从网络更新」拉取欧洲央行参考汇率
  （`ExchangeRateService`，Frankfurter 公开接口，无需密钥）。接口未收录的货币保留手动值。
- 跨币种转账会把「转出金额」与「到账金额」都写进 `TransferModel`，汇率随记录保存，
  之后改汇率不会影响这笔转账。
- 转账手续费的金额由一条独立支出行承担（`TransactionModel.transferFeeOf` 指向转账）；
  `TransferModel.fee` 只用于展示。删掉手续费行会把 `fee` 归零，避免迁移逻辑再次补行。
- 归档与隐藏账户都不删除交易或转账。归档、隐藏各有可展开分组可以恢复；
  两者都不会作为新记账的默认账户，也不计入总资产。
- 「余额调整」不修改 `openingBalance`，而是写一条 `adjustment = true` 的交易，
  这样历史可以追溯，也不会把期初金额改成看起来"对不上"的数字。

## 上线前：Production 部署与新字段核对

Development 环境只要在本机跑一遍写入就会自动建表；**Production 不会自动跟进**，必须手动 Deploy，
否则 TestFlight/正式包在已登录 iCloud 的设备上会看不到新数据。

1. 用 Debug 包在登录 iCloud 的真机上各做一次：新建账户、跨币种转账（带手续费）、
   标记报销并核销、调整余额、归档账户、编辑预算、保存模板、切换一次基准货币。
2. CloudKit Dashboard → Schema → **Deploy Schema Changes**，逐项核对：

   | Record Type | 必须存在的字段 |
   |---|---|
   | `CD_TransactionModel` | `baseAmount`、`discount`、`reimbursable`、`reimbursedAt`、`reimbursementOf`、`transferFeeOf`、`adjustment`、`merchant`、`merchantKey` |
   | `CD_AccountModel` | `currencyCode`、`archived` |
   | `CD_TransferModel` | `destinationAmount`、`fee` |
   | `CD_CurrencyRate` | `code`、`rate`、`updatedAt` |
   | `CD_TemplateTransactionModel` | 整个实体（小组件与主 App 共用 schema） |

3. Deploy 后用 **TestFlight 包**（不是 Debug）在已登录 iCloud 的机器上记一笔，
   Dashboard → Data → Records 应能看到记录。
4. 多设备验证：
   - 设备 A 记一笔 → 设备 B 前台停留 10 秒内应自动出现（`DataRefreshCenter` 监听远端变更）
   - 设备 A 删除 → B 同步消失
   - 两台设备同时改同一笔金额 → CloudKit 字段级最后写入者获胜，不合并
   - 断网写入 → 恢复网络后自动上传，另一台设备可见
5. 擦除数据后建议重启 App：CloudKit zone 被删除时 mirroring 仍持有旧 zone 元数据，
   重启会重新建立 zone，避免之后的新记录导出失败。

> macOS 目标没有 CloudKit entitlement（启用会因缺少容器在 PFCloudKit 内 SIGTRAP），
> 因此 Mac 数据只保存在该 Mac 的 App Group 容器里，不参与多设备同步。
> 加入 App Group 之前的 Mac 构建把库放在应用沙盒的 Application Support 下，
> 切换后不会自动迁移；如需保留旧数据，先在旧构建导出 JSON，再在新构建导入。
>
