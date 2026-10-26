# URL Scheme 与 X-Callback-URL

SmartBud 注册了 `smartbud://` scheme（`smartbud/Info.plist`），可以给快捷指令、
Launcher、脚本或其它 App 调用。解析在 `smartbud/Utilities/DeepLink.swift`，
写入逻辑在 `smartbud/Views/HomeView+DeepLink.swift`。

## 记一笔：`smartbud://add`

```
smartbud://add?amount=12.5&type=expense&category=餐饮&note=午饭
```

| 参数 | 必填 | 说明 |
|---|---|---|
| `amount` | 是 | 金额，正数。支持 `12,5` 这种逗号小数点；超过 1 亿会被截断 |
| `type` | 否 | `expense`（默认）或 `income` |
| `category` | 否 | 分类名。先精确匹配（忽略大小写），再按包含匹配；匹配不到就记成无分类 |
| `account` | 否 | 账户名或账户 UUID。匹配不到时用默认账户 |
| `note` | 否 | 备注；留空时用分类名 |
| `date` | 否 | `yyyy-MM-dd`、完整 ISO 8601，或无时区的 `yyyy-MM-ddTHH:mm[:ss]`（按设备时区解释）；缺省为现在，给了但解析失败会回 `invalid_date` |
| `reimbursable` | 否 | `1` / `true` 表示这是待报销支出 |
| `discount` | 否 | 优惠金额，只作展示（`amount` 仍是你实际付的钱） |

## 其它路由

| URL | 行为 |
|---|---|
| `smartbud://search?q=咖啡` | 切到「记录」、聚焦搜索并把 `q` 填进搜索框 |
| `smartbud://open?tab=insights` | 切到指定 Tab：`log` / `insights` / `budget` / `settings` |
| `smartbud://insights` | 等价于 `open?tab=insights` |
| `smartbud://budget` | 等价于 `open?tab=budget` |
| `smartbud://newExpense` | 打开记账页（旧版快捷指令仍在用）；host 大小写不敏感 |

## 回调：x-callback-url

在 `add` 上带 `x-success` / `x-error` / `x-cancel`，SmartBud 处理完会打开对应 URL
并在查询串里追加结果：

```
smartbud://add?amount=12.5&note=午饭
  &x-success=shortcuts://x-callback-url/success
  &x-error=shortcuts://x-callback-url/error
```

- 成功：`...?id=<UUID>&amount=12.50&date=<ISO 8601>`
- 失败：`...?error=invalid_amount`（金额缺失、为 0 或不是数字）、
  `...?error=invalid_date`（日期无法解析）、
  `...?error=save_failed`（写入失败，已回滚）、
  `...?error=app_locked`（App 密码锁未解锁，拒绝写入）

回调 URL 原有的查询参数会保留，SmartBud 只往后追加。

## 注意事项

- 密码锁开启且未解锁时，`add` 直接回 `x-error=app_locked`，不会写任何数据：
  锁屏状态下系统不会把 URL 交给 App，但应用在后台被锁定时仍可能收到。
- `add` 不做重复检测：同一秒内调用两次会新增两条记录，需要幂等请由调用方负责。
- 从别的 App 或 `simctl openurl` 触发时，iOS 会先弹一次"在 SmartBud 中打开？"确认，
  这是系统行为，App 无法绕过。
