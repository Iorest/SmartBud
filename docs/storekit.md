# SmartBud Pro：SKU、测试与上线

## 1. 商品定义

| 类型 | Product ID | 建议价格 | 说明 |
|---|---|---|---|
| 自动续期（1 个月） | `com.iorest.smartbud.pro.monthly` | ¥18 / $2.99 | 同一订阅组 |
| 自动续期（6 个月） | `com.iorest.smartbud.pro.halfyearly` | ¥68 / $12.99 | 同一订阅组 |
| 自动续期（1 年） | `com.iorest.smartbud.pro.yearly` | ¥98 / $19.99 | 同一订阅组 |
| 非消耗型 | `com.iorest.smartbud.pro.lifetime` | ¥198 / $39.99 | 一次性买断 |

订阅组名：`SmartBud Pro`。四个 ID 必须与 `SubscriptionManager.productIDs` 完全一致。

## 2. 本地（模拟器）测试

仓库自带 `app/SmartBud.storekit`，`SmartBud` scheme 的 Run → Options 已指向它。
用 Xcode 运行时（不是 `simctl launch`）可以直接走系统购买弹窗，无需沙盒账号：

1. Xcode 打开 `SmartBud.xcodeproj`，Scheme → Edit Scheme → Run → Options，
   确认 **StoreKit Configuration** 是 `SmartBud.storekit`。
2. 以 `-proEnforced` 启动参数运行（Scheme → Arguments），关闭限免，露出三个闸门。
3. 进「设置 → 智账 Pro」，应能看到 3 个订阅 + 终身价；购买后：
   - AI 按钮的锁消失
   - 6 款额外图标可选、不再弹 Pro 页
   - 通知页「自定义时间」可用
4. 恢复购买：Xcode → Debug → StoreKit → Manage Transactions，删掉本地交易后再进
   Pro 页点「恢复购买」，应重新解锁（StoreKit Testing 的 `AppStore.sync()` 会回放本地交易）。
5. 退款：Manage Transactions 里对交易选 Refund；App 下次启动/收到
   `Transaction.updates` 后应回到未解锁状态（`revocationDate != nil` 被过滤）。

## 3. App Store Connect 配置

1. **App 内购买项目** → 创建订阅组 `SmartBud Pro`，再创建三个自动续期项目，
   填入上表 Product ID、价格、各语言显示名与描述、审核截图。
2. 创建非消耗型 `com.iorest.smartbud.pro.lifetime`，价格与描述同上。
3. 每个商品至少提交一次审核；订阅组需要填写订阅说明与隐私政策/服务条款 URL
   （`SubscriptionManager.resolveLegalURL` 默认指向仓库 docs，正式发布前建议用
   `SMARTBUD_LEGAL_URL_BASE` 指到稳定域名）。
4. 税务与收款信息、协议（Paid Apps）必须已完成，否则商品不会返回。

## 4. 真机验收

- 用沙盒账号（设置 → App Store → 沙盒账户）在真机购买月订阅：确认购买成功、闸门解锁。
- 删除 App 重装 → 「恢复购买」→ 权益恢复。
- 换一台设备同一 Apple ID 登录 → 启动后 `Transaction.currentEntitlements` 命中，无需手动恢复。
- 在 App Store Connect → 用户与访问 → 沙盒测试员里创建账号用于退款测试；
  退款到账后 App 在下一次启动或收到 `Transaction.updates` 时自动降级。
- 到期/降级：把沙盒订阅的续期速度调到最快，等待过期，确认闸门重新出现且数据不受影响。

## 5. 上线前检查

- [ ] 四个 SKU 状态均为「准备提交/已批准」，价格与本地化齐全
- [ ] `limitedTimeFree` 置为 `false`（App Group 键，或发版时改默认值）
- [ ] 付费墙只列 `ProAccess` 真实拦截的三项
- [ ] 购买/恢复/退款三条路径在真机各跑一次
- [ ] 订阅组本地化名称、条款链接可打开
- [ ] 审核备注里说明「AI 分析需要用户自备 API Key」这一前提
