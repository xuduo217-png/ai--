# RN 用户端“我的/个人中心”到 Flutter 完整迁移计划

> 计划版本：1.0  
> 建立日期：2026-07-25  
> 执行状态：待开始  
> 计划负责人：目标模式中的当前 Codex 会话  
> 执行入口：`plan2go=/Users/wujie/Desktop/code/xuduo/pet-hospitals/flutter_app/docs/RN_PROFILE_FULL_MIGRATION_PLAN.md`

## 1. 文档定位

本文件是这次长期迁移的唯一主执行源（source of truth）。执行代理必须按任务编号推进，不得仅凭聊天上下文判断完成度。

外部记忆文件：

- `docs/RN_PROFILE_MIGRATION_PROGRESS.md`：当前焦点、工作包状态、阻塞项、变更文件和下一步。
- `docs/RN_PROFILE_MIGRATION_DECISIONS.md`：已接受、待确认和被替代的产品/架构决策。
- `docs/RN_PROFILE_MIGRATION_VERIFICATION.md`：每轮实际执行的测试、静态检查、截图和人工验收证据。

四份文件的职责边界：

| 文件 | 记录什么 | 不记录什么 |
|---|---|---|
| 本计划 | 稳定目标、范围、工作分解、验收标准 | 每次运行的临时状态 |
| 进度账本 | 当前状态、下一动作、阻塞和变更文件 | 大段设计论证 |
| 决策记录 | 有长期影响的取舍及原因 | 普通实现细节 |
| 验证记录 | 真实命令、退出码、测试数量、截图结果 | 未实际执行的“预计通过” |

除非需求或代码事实发生变化，不要频繁改写本计划。执行过程中的状态变化优先写入进度账本；设计变化先写决策记录，再同步本计划受影响部分。

---

## 2. 新会话恢复协议

每个新会话、目标模式自动续跑会话或上下文压缩后的首次动作都必须执行以下步骤。

- [ ] 完整阅读仓库根目录 `AGENTS.md` 或当前会话注入的等价规则。
- [ ] 完整阅读本计划，不只读取当前阶段。
- [ ] 阅读进度账本中的“恢复卡片”“当前工作包”“阻塞项”“下一动作”。
- [ ] 阅读决策记录中所有 `Accepted` 和 `Proposed` 条目。
- [ ] 阅读验证记录的“最近一次绿色基线”和当前工作包证据。
- [ ] 在仓库根目录运行 `git status --short`，识别用户已有改动；不得回滚或覆盖无关改动。
- [ ] 运行 `codegraph status`；索引过期时运行 `codegraph sync`。
- [ ] 对当前工作包执行至少一次相关的 CodeGraph `context/query/trace/callers/callees/impact` 查询。
- [ ] 只将一个工作包标为 `IN_PROGRESS`，继续其“下一动作”；不要重新实现已经验收的工作包。
- [ ] 修改前核对目标文件当前 diff，修改后更新进度账本和验证记录。

如果 CodeGraph 不可用或查询失败，必须在进度账本记录失败原因，并使用 `rg`、代码阅读和测试降级分析；不得静默跳过。

### 2.1 每轮工作结束协议

每次准备结束当前会话前：

- [ ] 当前工作包若未完成，写清最后完成的最小步骤和下一条可执行命令。
- [ ] 更新工作包状态，不允许用模糊的“基本完成”。
- [ ] 将本轮所有修改文件写入进度账本。
- [ ] 将实际执行的命令和结果写入验证记录。
- [ ] 新增或改变长期决策时更新决策记录。
- [ ] 检查 `git diff --check`；有代码修改时检查相关 diff。
- [ ] 不得未经用户明确授权执行 commit、push、merge、rebase、删除文件或修改依赖。

---

## 3. 迁移目标

将 RN 用户端“我的/个人中心”页面及其直接拥有的功能页面完整迁移到 `flutter_app`，使 Flutter 版本在业务能力、数据真实性、关键交互、异常处理和导航闭环上达到 RN 当前实现的等价水平，同时遵循 Flutter 工程已经建立的分层、导航和测试模式。

这里的“完整迁移”不是逐行翻译，也不是像素机械复制，而是：

1. RN 当前可工作的业务能力在 Flutter 中有可用实现。
2. RN 的明显占位或 TODO 不被误判为必需能力。
3. Flutter 已经优于 RN 的能力不回退。
4. 页面入口不能指向空白页、SnackBar 占位或崩溃路径。
5. 页面离开后返回、应用恢复、登录态变化后，数据能按明确策略刷新。
6. 网络错误、空数据、加载、提交中、权限拒绝和重复操作都有可观察状态。
7. iOS/Android 手机尺寸下布局无溢出，文字缩放和系统安全区可用。

### 3.1 行为基线

RN 行为基线文件：

- `rnapp/src/screens/Home/components/ProfileScreen.tsx`
- `rnapp/src/screens/Home/config/profileServices.ts`
- `rnapp/src/screens/Profile/MyIncomeScreen.tsx`
- `rnapp/src/screens/Profile/SystemConfigScreen.tsx`
- `rnapp/src/screens/Common/SystemArticleScreen.tsx`
- `rnapp/src/screens/Profile/MyCouponsScreen.tsx`
- `rnapp/src/screens/Pet/PetListScreen.tsx`
- `rnapp/src/screens/Pet/PetEditScreen.tsx`
- `rnapp/src/screens/Notifications/NotificationScreen.tsx`
- `rnapp/src/screens/Order/MedicalServiceOrderListScreen.tsx`
- 商城订单、地址、收藏、我发布商品相关 RN 页面

Flutter 当前基线文件：

- `flutter_app/lib/features/home/presentation/profile_mall_view.dart`
- `flutter_app/lib/features/home/presentation/home_page.dart`
- `flutter_app/lib/features/auth/presentation/auth_controller.dart`
- `flutter_app/lib/features/mall/navigation/mall_navigation_coordinator.dart`
- `flutter_app/lib/features/mall/navigation/mall_dependencies.dart`
- 已有商城订单、地址、收藏、发布商品模块

如果 RN 注释与实际运行代码冲突，以实际代码和测试为准；如果后端响应与前端类型冲突，以真实 API contract 和后端实现为准，并在决策记录中说明。

---

## 4. 范围边界

### 4.1 必须完成的主页面能力

- 真实用户头像、昵称、性别和会员文案展示。
- 编辑头像、昵称和性别。
- 头像选择、上传和更新后的会话持久化。
- 脱敏手机号只读展示。
- 钱包/收益摘要：可用金额、待入账、累计收益。
- 点击钱包进入收益明细。
- 下拉刷新或等价刷新，覆盖资料、钱包和通知未读数。
- 九个服务入口：我的宠物、商城订单、医疗服务、收货地址、通知消息、我的优惠券、我的收藏、我发布商品、系统设置。
- 系统设置中的退出登录必须二次确认。

### 4.2 必须完成的直接子页面

- 我的宠物列表。
- 宠物新增/编辑/删除。
- 商城订单列表、订单详情及已有操作链路。
- 医疗服务订单列表。
- 收货地址列表、新增、编辑、删除、设默认和选择模式。
- 通知列表、未读数、单条已读、全部已读和支持的业务跳转。
- 我的优惠券列表、状态筛选及可用券展示。
- 我的收藏列表和加购/商品详情行为。
- 我发布商品列表、筛选、上下架、拒绝原因、发布与编辑。
- 我的收益统计、交易明细、分页/刷新及关联订单跳转。
- 系统设置、联系方式、隐私政策、用户协议、关于我们。
- 注销账号确认和后端调用。

### 4.3 复用而非重写的 Flutter 能力

以下 Flutter 流程已经存在，原则上只补差异、测试和导航整合，不重新实现：

- `features/mall/order`：订单列表、详情、取消、支付、确认收货。
- `features/mall/address`：地址 CRUD、默认地址、选择模式。
- `features/mall/favorite`：收藏列表和商品跳转/加购。
- `features/mall/second_hand`：我发布商品、发布/编辑和上下架。
- `features/mall/checkout`：优惠券选择能力已经存在，可复用其模型/解析逻辑。
- `core/network/api_client.dart`：GET/POST/PUT/PATCH/DELETE 和 multipart 上传。
- `flutter_html`：系统文章富文本。
- `image_picker`：头像和宠物图片选择。

### 4.4 不在本计划直接范围内

- 医生端个人中心。
- 社区用户主页、好友资料和社区资料编辑。
- RN 中尚未实现的头像大图查看器 TODO。
- 积分系统本身；RN 当前把 `integral` 固定为 `0`，因此本计划默认展示“普通会员”。只有存在真实积分 API 时才单独扩展。
- 后端接口新增或修改。发现 contract 缺失时先记录阻塞，修改后端需用户确认，并同步 `admin/API_DOCUMENT.md`。
- 无关模块重构、根配置变更、依赖升级和 lockfile 改动。

### 4.5 跨域跳转的完成定义

通知、宠物和收益页面可能跳转到其他业务域。为防止个人中心迁移演变为全 App 重写，按以下规则验收：

- 目标 Flutter 页面已存在：必须完成真实跳转并传递正确参数。
- 目标属于本计划直接子页面：必须实现，不允许降级。
- 目标属于其他业务域且 Flutter 尚不存在：必须安全识别并给出明确提示，不得崩溃或静默无响应；在进度账本登记“外部域缺口”。
- 如果用户后续明确要求所有传递性目标也达到 RN 等价，再为缺口新增独立扩展工作包，不把它伪装成本工作包已完成。

---

## 5. 当前差异基线

### 5.1 主页面差异

| 能力 | RN 当前状态 | Flutter 当前状态 | 迁移动作 |
|---|---|---|---|
| 页面标题 | “个人中心” | 无等价标题 | 按 RN 信息层级补齐 |
| 头像 | 真实 URL + 默认图 | 静态 person icon | 使用会话头像和统一 URL resolver |
| 昵称 | `username` 或手机号后四位 | `displayName` | 建立统一展示名映射 |
| 性别 | 男女图标和颜色 | 缺失 | 增加 0/1/2 映射 |
| 会员等级 | 固定积分 0 推导普通会员 | “商城服务” | 展示普通会员，避免虚构积分 |
| 编辑资料 | 弹窗，可上传头像/改昵称/性别 | 缺失 | 实现可测试编辑流程 |
| 手机号 | 脱敏只读 | 缺失 | `138****1234` 类规则及边界测试 |
| 钱包摘要 | 三项统计，可进入收益页 | 缺失 | 新增 wallet 模块和摘要卡 |
| 刷新 | focus 刷新资料和钱包；下拉只刷新资料 | 缺失 | 统一刷新资料/钱包/未读数 |
| 服务入口 | 9 个 | 4 个 | 补齐 5 个并复用已有 4 个 |
| 退出登录 | 系统设置内确认退出 | 主页面直接退出、无确认 | 移入设置，确认后退出 |
| 错误状态 | 多数静默或 Toast | 无对应数据加载 | 增加局部错误与重试，不把失败显示成真实 0 |

### 5.2 子页面差异

| 模块 | Flutter 状态 | 主要差异/动作 |
|---|---|---|
| 商城订单 | 已有，接近 RN | 保持分页、筛选、详情、支付、取消、确认；补个人中心导航回归测试 |
| 收货地址 | 已有，接近 RN | 保持 CRUD/默认/选择模式；补入口和返回刷新测试 |
| 我的收藏 | 已有 | RN 可在列表选 SKU/数量；Flutter 有 SKU 时转详情、无 SKU 加 1 件。决定是否严格追平并测试 |
| 我发布商品 | 已有，接近 RN | 保持筛选、分页、上下架、拒绝原因、发布/编辑 |
| 我的宠物 | 缺失 | 新增完整列表和编辑模块 |
| 医疗服务订单 | 缺失 | 新增只读订单列表，映射状态和分页/刷新 |
| 通知消息 | 缺失 | 新增列表、未读、已读、全部已读、轮询和业务跳转 |
| 我的优惠券 | 独立页面缺失 | 复用 checkout coupon 模型或抽取共享模型，新增个人券中心 |
| 我的收益 | 缺失 | 新增统计与交易明细，复用商城订单详情跳转 |
| 系统设置 | 缺失 | 新增联系方式、文章、退出、注销账号 |

---

## 6. 目标架构

### 6.1 原则

- 沿用现有 `data/domain/presentation` 目录结构。
- Repository 负责 HTTP contract 和 JSON 映射；Controller 负责可观察状态和用户动作；Widget 不直接解析后端 payload。
- 页面依赖通过构造参数或集中 dependencies 组装，不在 Widget 内创建全局网络客户端。
- 主页面只组合个人中心状态和导航，不承载每个子模块业务逻辑。
- 能复用商城模块时通过公开 gateway/coordinator 复用，不复制 repository。
- 公共模型只在确有两个以上消费者时抽取，避免提前制造 shared 大杂烩。

### 6.2 推荐目录

实施前通过 CodeGraph 和现有模式再次核对，默认采用：

```text
lib/features/profile/
  data/profile_repository.dart
  domain/profile_models.dart
  presentation/profile_controller.dart
  presentation/pages/profile_page.dart
  presentation/pages/profile_edit_page.dart 或 widgets/profile_edit_dialog.dart
  presentation/widgets/profile_identity_card.dart
  presentation/widgets/profile_wallet_card.dart
  presentation/widgets/profile_service_list.dart
  navigation/profile_dependencies.dart
  navigation/profile_navigation_coordinator.dart

lib/features/wallet/
  data/wallet_repository.dart
  domain/wallet_models.dart
  presentation/wallet_controller.dart
  presentation/pages/income_page.dart

lib/features/pets/
  data/pet_repository.dart
  domain/pet_models.dart
  presentation/pet_list_controller.dart
  presentation/pet_edit_controller.dart
  presentation/pages/pet_list_page.dart
  presentation/pages/pet_edit_page.dart
  presentation/widgets/...

lib/features/medical_orders/
  data/medical_order_repository.dart
  domain/medical_order_models.dart
  presentation/medical_order_controller.dart
  presentation/pages/medical_order_list_page.dart

lib/features/notifications/
  data/notification_repository.dart
  domain/notification_models.dart
  presentation/notification_controller.dart
  presentation/notification_badge_controller.dart
  presentation/pages/notification_list_page.dart

lib/features/coupons/
  data/coupon_repository.dart
  domain/coupon_models.dart
  presentation/coupon_controller.dart
  presentation/pages/my_coupon_page.dart

lib/features/settings/
  data/settings_repository.dart
  domain/settings_models.dart
  presentation/settings_controller.dart
  presentation/pages/settings_page.dart
  presentation/pages/system_article_page.dart
```

如果现有 checkout coupon 模型足够通用，优先迁移到明确的共享位置并保持兼容；若抽取会造成大范围回归，则 coupon center 独立映射相同 contract，记录后续合并机会。

### 6.3 导航结构

新增 `ProfileNavigationCoordinator`，职责类似现有 `MallNavigationCoordinator`：

- 打开宠物、医疗订单、通知、优惠券、钱包、设置页面。
- 将订单、地址、收藏、发布商品委托给 `MallNavigationCoordinator`。
- 系统文章由 settings 页面进入。
- 钱包交易的订单跳转委托商城订单详情。
- 通知 action 先解析为强类型 destination，再路由到支持页面。
- coordinator 不保存页面业务数据，只保存必要的待恢复导航意图。

`HomePage` 最终只接收一个可选的 `profileNavigation` 和 profile dependencies/controller factory，不扩展为十几个回调参数。

### 6.4 登录会话一致性

编辑资料成功后必须同时更新：

1. 后端 `/users/me`。
2. `AuthController.session.profile` 的内存状态。
3. `SessionStore` 中持久化的 session。
4. ProfileController 当前展示状态。
5. 依赖昵称/头像的其他监听页面。

推荐为 `AuthController` 增加受控方法，例如 `updateProfile(Map<String, Object?> patch)` 或 `replaceSession(AuthSession session)`，由 controller 内部持久化并 `notifyListeners()`。不得让 profile 页面直接写 `SharedPreferences`。

因为这是共享状态入口，实施前必须执行 CodeGraph callers/impact 分析，并先补 `auth_controller_test.dart`。

### 6.5 主页面聚合状态

ProfileController 建议分别跟踪：

- identity：用户资料。
- wallet：钱包摘要。
- unreadNotifications：通知未读数。
- initialLoading：首次是否尚无可展示数据。
- refreshing：用户主动刷新。
- identityError、walletError、notificationError：局部错误。
- editSubmitting、avatarUploading：提交互斥状态。

资料成功、钱包失败时仍展示资料；钱包区域显示失败/重试，不用 `0.00` 冒充真实余额。刷新必须并发加载，但分项落状态，避免一个请求失败吞掉其他结果。

---

## 7. API Contract 清单

实施每个 Repository 前，必须核对 RN service、后端路由/DTO 和真实响应 envelope。以下是已确认的前端调用基线，不代表可以跳过后端核验。

### 7.1 用户资料和文件

| 用途 | 方法 | 路径 | 请求 | 关键响应/行为 |
|---|---|---|---|---|
| 更新本人资料 | PUT | `/users/me` | `username`, 可选 `gender`, 可选 `avatar` | 成功后同步 AuthSession |
| 上传头像 | POST multipart | `/upload/image` | file=`file`, category=`user-avatar` | `{url, filename, originalName, size, id}` 或 envelope 中的 data |
| 注销本人账号 | DELETE | `/users/me` | 以后端实际 contract 为准 | 成功后清除本地会话并回登录页 |
| 退出登录 | POST/现有 gateway | `/auth/logout` | 现有 AuthGateway | 无论远端结果策略如何，按现有 AuthController 约定清本地态 |

资料读取默认来自登录恢复后的 `AuthSession.profile`。如果后端存在 `GET /users/me` 且 RN/Flutter 实际使用需要刷新，应在实施时核对后纳入 repository；不得臆造接口。

### 7.2 钱包/收益

| 用途 | 方法 | 路径 | 参数 |
|---|---|---|---|
| 钱包摘要 | GET | `/shop/wallet/stats` | 无 |
| 收益交易明细 | GET | `/shop/wallet/transactions` | page、limit/pageSize、类型筛选（以 RN 为准） |
| 钱包余额 | GET | `/shop/wallet/balance` | 已被 checkout 使用，可复用但不要与 stats 混淆 |
| 关联订单详情 | GET | `/shop/orders/:id` | 委托已有 order repository/coordinator |

模型至少覆盖可用金额、待入账、累计收益、交易金额、交易类型、状态、说明、关联订单 ID、发生时间和分页元数据。金额使用一致的安全解析/格式化策略，禁止直接依赖动态类型 `toStringAsFixed`。

### 7.3 宠物

| 用途 | 方法 | 路径 |
|---|---|---|
| 本人宠物列表 | GET | `/pets/my` |
| 宠物分类树 | GET | `/pet-categories/tree` |
| 宠物详情 | GET | `/pets/:id` |
| 新增宠物 | POST | `/pets` |
| 更新宠物 | PUT | `/pets/:id` |
| 删除宠物 | DELETE | `/pets/:id` |
| 健康统计 | GET | `/pets/:id/health-stats` |
| 生成照护计划 | POST | `/pets/:id/care-plan` |

本计划核心要求是列表与新增/编辑/删除。健康统计、照护计划只有在 RN 的个人中心宠物链路当前可进入且有可见 UI 时才纳入对应工作包；否则记录为外部能力，不虚构入口。

### 7.4 医疗服务订单

| 用途 | 方法 | 路径 | 参数 |
|---|---|---|---|
| 本人医疗/问诊订单 | GET | `/chat/orders` | 状态、页码等以 RN 页面为准 |

复用已有 chat/order 模型前先核对字段语义。医疗订单与商城订单不是同一 contract，不得共用错误的商城 Order 模型。

### 7.5 通知

| 用途 | 方法 | 路径 |
|---|---|---|
| 列表 | GET | `/notifications` |
| 未读数 | GET | `/notifications/unread-count` |
| 详情 | GET | `/notifications/:id` |
| 单条已读 | PUT | `/notifications/:id/read` |
| 全部已读 | PUT | `/notifications/read-all` |

通知 action data 必须经过容错解析；未知类型、字段缺失和目标页面不存在都不能导致强制类型转换崩溃。

### 7.6 优惠券

| 用途 | 方法 | 路径 |
|---|---|---|
| 我的优惠券 | GET | `/shop/coupons/my` |
| 优惠券数量 | GET | `/shop/coupons/my/count` |

筛选状态、过期判断、门槛、折扣/减免展示和有效期格式，以 RN 页面和 checkout 现有 contract 双重核对。

### 7.7 系统设置

| 用途 | 方法 | 路径/键 |
|---|---|---|
| 联系方式 | GET | `/system-configs/contact_info` |
| 关于我们 | GET | `/system-articles/about_us` |
| 隐私政策 | GET | `/system-articles/privacy` |
| 用户协议 | GET | `/system-articles/user_agreement` |

系统文章使用 `flutter_html` 渲染。外部链接、图片 URL、空内容和服务端 HTML 异常需有安全策略；不得将文章 HTML 当普通 Text 原样显示。

---

## 8. 工作包总览

状态只允许：`TODO`、`IN_PROGRESS`、`BLOCKED`、`VERIFYING`、`DONE`。

| ID | 工作包 | 依赖 | 完成标志 |
|---|---|---|---|
| WP-00 | 基线冻结与 contract 审计 | 无 | 差异、API、截图/测试基线可追溯 |
| WP-01 | Profile 基础模型、Repository 与会话同步 | WP-00 | 资料更新可持久化且有单测 |
| WP-02 | Profile 导航与依赖组装 | WP-01 | 九入口有强类型目标，无占位 |
| WP-03 | 个人中心主页面与编辑资料 | WP-01、WP-02 | 主页面真实数据和编辑完整可用 |
| WP-04 | 钱包摘要与我的收益 | WP-02、WP-03 | 统计、明细、分页、订单跳转可用 |
| WP-05 | 系统设置与系统文章 | WP-01、WP-02 | 联系、文章、退出、注销完整可用 |
| WP-06 | 我的宠物 | WP-02 | 列表和 CRUD 完整可用 |
| WP-07 | 医疗服务订单 | WP-02 | 列表、状态、刷新和异常可用 |
| WP-08 | 通知中心与未读同步 | WP-02、WP-03 | 未读、已读、列表和安全跳转可用 |
| WP-09 | 我的优惠券 | WP-02 | 独立券中心与 checkout contract 一致 |
| WP-10 | 已有商城四入口差异收口 | WP-02 | 订单/地址/收藏/发布无回归 |
| WP-11 | 视觉、响应式、可访问性和生命周期 | WP-03 至 WP-10 | 多尺寸、多状态和恢复刷新通过 |
| WP-12 | 全量回归、缺口审计与交付 | 全部 | 无死入口、全量验证有证据 |

工作包应按依赖推进。允许在不冲突的情况下调整 WP-04 至 WP-10 的先后顺序，但同一时间只保留一个主要 `IN_PROGRESS` 工作包。

---

## 9. WP-00：基线冻结与 Contract 审计

### 9.1 目标

在修改功能前建立可复查的 RN/Flutter 行为基线，确认后端 contract，避免按界面猜数据。

### 9.2 步骤

- [ ] 用 CodeGraph 查询 RN ProfileScreen、服务配置、所有 route destination 和 API 调用链。
- [ ] 用 CodeGraph 查询 Flutter ProfileMallView、HomePage、App 依赖组装、AuthController 和 MallNavigationCoordinator 影响面。
- [ ] 用 `rg` 核对路由名、endpoint、字段名、图片资源、已有测试和 TODO。
- [ ] 阅读后端用户、钱包、宠物、聊天订单、通知、优惠券、系统配置/文章路由和 DTO。
- [ ] 在验证记录写入每个 endpoint 的真实响应 envelope、分页字段、空值和错误格式。
- [ ] 运行 RN 个人中心相关现有测试，记录命令、退出码和数量。
- [ ] 运行 Flutter 当前 `flutter analyze`、`flutter test` 或至少个人中心/商城相关测试，记录绿色基线和已有失败。
- [ ] 在可运行的 RN 环境采集个人中心和直接子页面截图；至少覆盖有数据、空数据和一个错误/加载状态。
- [ ] 在 Flutter 采集当前个人中心 320x568、390x844、402x874 或等价视口截图，作为 before 基线。
- [ ] 将发现的 contract 差异写入决策记录，不在 Repository 中通过多层猜测无限兼容。

### 9.3 验收

- [ ] 进度账本中的基线矩阵已更新。
- [ ] 所有必需入口都能映射到 RN 文件、Flutter 目标模块和 endpoint。
- [ ] 不确定的 contract 被标记为 BLOCKED/待确认，而不是被假定。
- [ ] 验证记录含真实命令与结果。

---

## 10. WP-01：Profile 基础模型、Repository 与会话同步

### 10.1 目标模型

建立强类型 `UserProfile`，至少包含：

- id
- username/displayName
- phone
- avatarUrl
- gender（unknown/male/female）
- membershipLabel（当前默认普通会员，除非有真实数据源）

定义纯函数：

- AuthSession profile map -> UserProfile。
- 显示名 fallback。
- 手机号脱敏。
- 性别图标/颜色语义（颜色留在 presentation）。
- profile patch 合并，保留未知 session 字段。

### 10.2 Repository

- [ ] 定义 `ProfileGateway` 接口。
- [ ] 实现更新用户 `PUT /users/me`。
- [ ] 实现头像上传 `POST /upload/image`，字段名 `file`、category=`user-avatar`。
- [ ] 根据真实响应解析 URL，不依赖 RN Axios 已解 envelope 的假设。
- [ ] 实现注销账号 `DELETE /users/me`，但 UI 动作留到 WP-05。
- [ ] URL 展示复用 `AssetUrlResolver` 或项目现有图片解析器。

### 10.3 AuthController 共享状态

- [ ] 修改前执行 `AuthController` callers/impact 分析。
- [ ] 先添加测试：patch 后内存 session 更新、store 保存、监听器通知、未知字段保留。
- [ ] 添加受控 profile 更新方法。
- [ ] 确保写持久化失败时不会伪装成功；明确回滚或错误传播策略。
- [ ] 检查登录恢复仍可读取更新后的 session。
- [ ] 检查 logout、初始化失败和本地失效逻辑无回归。

### 10.4 测试

- [ ] `profile_models_test.dart`：字段类型、null、数字字符串、显示名和手机号脱敏。
- [ ] `profile_repository_contract_test.dart`：方法、路径、鉴权、JSON body、multipart fields、异常。
- [ ] `auth_controller_test.dart`：会话更新和持久化回归。

### 10.5 验收

- [ ] Widget 不直接构造 `/users/me` 或 `/upload/image` 请求。
- [ ] 更新成功后杀进程/恢复 session 仍显示新资料（至少用 store 单测证明）。
- [ ] 没有新增依赖或 lockfile 变化。
- [ ] 定向测试、`dart analyze` 相关文件通过。

---

## 11. WP-02：Profile 导航与依赖组装

### 11.1 目标

建立个人中心专用 coordinator，避免 `HomePage` 继续膨胀，并复用商城 coordinator。

### 11.2 步骤

- [ ] CodeGraph 分析 `HomePage` 构造调用方、App 根依赖组装、`MallNavigationCoordinator` callers/callees。
- [ ] 定义 `ProfileDependencies`，只包含各 gateway/factory 和已有 `MallNavigationCoordinator`。
- [ ] 定义强类型 destination/route args，禁止 `Map<String, dynamic>` 在页面间随意传递。
- [ ] 实现九个主入口的方法。
- [ ] 将订单、地址、收藏、发布商品委托现有 Mall coordinator。
- [ ] 实现 wallet -> order detail 委托。
- [ ] 实现 notification action -> destination 的纯解析函数。
- [ ] 为不支持的外部域 destination 定义统一反馈，而不是抛异常。
- [ ] 在 App 根组装 dependency，避免每次 build 重建 repository/coordinator。
- [ ] `HomePage.guest` 保持游客无法进入个人中心，且登录提示行为不回退。

### 11.3 测试

- [ ] coordinator 单元/Widget 测试覆盖九入口目标。
- [ ] 验证商城委托参数正确。
- [ ] 验证未知通知 action 安全失败。
- [ ] 验证游客 gating 不被绕过。

### 11.4 验收

- [ ] 个人中心入口不再依赖 SnackBar 占位。
- [ ] `HomePage` 没有十几个新增页面回调。
- [ ] 返回个人中心后保持当前底部 Tab。
- [ ] 所有路由参数均为强类型。

---

## 12. WP-03：个人中心主页面与编辑资料

### 12.1 页面状态

- [ ] 首次加载骨架/进度状态。
- [ ] 资料可展示、钱包局部失败。
- [ ] 资料失败但保留上次有效数据。
- [ ] 下拉刷新。
- [ ] 页面重新可见后的刷新策略。
- [ ] 头像上传中。
- [ ] 编辑保存中。
- [ ] 无变更提交。
- [ ] 表单校验错误。

### 12.2 用户信息卡

- [ ] 标题“个人中心”。
- [ ] 真实头像；空头像使用 Flutter 现有风格的默认图/图标。
- [ ] 昵称单行省略；空昵称按 RN fallback。
- [ ] 性别 0/1/2 容错，未知性别不误标女性。
- [ ] 会员文案默认“普通会员”，不展示虚构积分。
- [ ] 编辑资料按钮有稳定点击区域和语义标签。
- [ ] 不实现 RN 尚为 TODO 的头像查看器；头像点击可无动作或进入编辑，须在决策记录明确。

### 12.3 编辑资料

- [ ] 根据小屏键盘空间决定使用全屏/底部 sheet/对话框；390 宽行为必须稳定。
- [ ] 初始化昵称、性别、头像。
- [ ] 手机号脱敏且只读。
- [ ] 昵称 trim 后不能为空，长度和字符限制以后端/RN 规则为准。
- [ ] 性别选择支持 unknown/male/female；若保持 RN UI 仅男/女，模型仍需容错 unknown。
- [ ] 使用 `image_picker`，处理取消、权限拒绝、文件不存在和上传失败。
- [ ] 上传期间禁止重复选择/保存。
- [ ] 用户关闭编辑而未保存时，不将上传 URL写入 session。
- [ ] 保存时只发送发生变化的字段。
- [ ] 无变化时提示并关闭或保留，行为与 RN 一致。
- [ ] 保存成功调用 AuthController 会话更新，再更新当前页面。
- [ ] 保存失败保留用户输入以便重试。
- [ ] 防止页面 dispose 后 `setState`/通知。

### 12.4 钱包摘要和服务列表

- [ ] 三项钱包数值使用统一金额格式。
- [ ] 钱包点击进入 WP-04 页面。
- [ ] 九个服务项顺序、标题、描述与 RN 配置一致。
- [ ] 通知项可显示未读角标，超过 99 显示 `99+`。
- [ ] 每个列表项高度稳定、点击区域完整、长文本不溢出。
- [ ] 退出登录不再直接放在主页面；移至系统设置。

### 12.5 测试

- [ ] `profile_controller_test.dart`：并发刷新、局部失败、上传/保存、重复提交、dispose。
- [ ] `profile_page_test.dart`：真实资料、默认值、九入口、钱包、未读角标、错误和刷新。
- [ ] `profile_edit_test.dart`：手机号脱敏、校验、取消选择、上传失败、保存成功/失败、无变化。
- [ ] 320、390、402 宽 Widget 测试无 overflow。
- [ ] 更新 `home_page_test.dart` 验证登录用户显示完整个人中心。

### 12.6 验收

- [ ] 主页面不再显示“商城服务”占位身份。
- [ ] 九入口可点击且目标真实。
- [ ] 编辑成功后主页面、底层 session 和重启恢复一致。
- [ ] 钱包失败不会把余额显示为真实 `0.00`。
- [ ] 页面刷新不会产生重复并发请求或 loading 闪烁。

---

## 13. WP-04：钱包摘要与我的收益

### 13.1 模型与 Repository

- [ ] 定义 WalletStats、WalletTransaction、TransactionStatus/Type、分页模型。
- [ ] 核对 RN 金额正负号、状态标签、时间和订单关联字段。
- [ ] 实现 stats 和 transactions 请求。
- [ ] 处理列表 envelope 和分页字段差异，contract 测试锁定真实形态。

### 13.2 Controller

- [ ] 首屏统计与第一页明细可并发加载并局部失败。
- [ ] 下拉刷新重置分页。
- [ ] 上拉加载防重复、无更多和错误重试。
- [ ] 筛选变化取消/忽略过期响应。
- [ ] 交易动作后刷新统计（若页面存在相关动作）。

### 13.3 页面

- [ ] 顶部金额摘要。
- [ ] 交易筛选、明细列表、空状态、错误重试。
- [ ] 金额颜色/符号遵循交易语义，不仅按字符串前缀。
- [ ] 有关联商城订单 ID 时跳转已有订单详情。
- [ ] 无效/已删除订单给出明确反馈。
- [ ] 长说明、极大金额和未知状态不溢出。

### 13.4 测试与验收

- [ ] Repository contract 测试。
- [ ] Controller 分页和竞态测试。
- [ ] 页面三种宽度、空/错/多页状态测试。
- [ ] 主页面钱包摘要与收益页刷新后数据一致。
- [ ] 订单跳转参数正确。

---

## 14. WP-05：系统设置、系统文章和账号动作

### 14.1 系统设置首页

- [ ] 联系客服区读取 `contact_info`，展示二维码/热线/工作时间中后端实际提供的字段。
- [ ] 空配置时不展示破损图片或 `null` 文本。
- [ ] 电话操作前确认并检查设备能力；Widget 测试不依赖真实拨号。
- [ ] 隐私政策、用户协议、关于我们入口。
- [ ] 退出登录入口。
- [ ] 注销账号入口，与退出登录视觉/文案明确区分。

### 14.2 系统文章

- [ ] 定义 article type 强类型枚举。
- [ ] 使用 `flutter_html` 展示后台 HTML。
- [ ] 覆盖 loading、empty、error、retry。
- [ ] 处理相对图片 URL、超宽图片/表格和外链。
- [ ] 外链策略须明确；不能由任意 scheme 直接启动敏感应用。

### 14.3 退出登录

- [ ] 显示确认对话框。
- [ ] 取消后不调用 gateway。
- [ ] 确认后禁用重复操作。
- [ ] 调用现有 `AuthController.logout()`，完成本地 session/friends 等清理。
- [ ] 退出后返回登录/游客根状态，导航栈不允许回到受保护页。

### 14.4 注销账号

- [ ] 使用高风险二次确认文案，说明不可恢复影响。
- [ ] 只有明确确认后调用 `DELETE /users/me`。
- [ ] 成功后清除本地 session 和本地用户数据，返回未登录状态。
- [ ] 失败时保持登录，不提前清本地数据，并显示可操作错误。
- [ ] 不在测试/实施中使用真实生产账号执行注销；Repository contract + mock flow 验证。

### 14.5 测试与验收

- [ ] Settings repository contract 测试。
- [ ] 文章类型路径测试。
- [ ] HTML、空、失败和相对图片 Widget 测试。
- [ ] 退出确认的取消/确认测试。
- [ ] 注销的取消/失败/成功测试。
- [ ] 导航栈清理测试。

---

## 15. WP-06：我的宠物

### 15.1 审计范围

先确认 RN PetList 的可见功能和所有直接跳转。至少包含列表、空态、新增、编辑、删除和返回刷新。若存在“我的走失”等跨域入口，按 4.5 规则处理并登记。

### 15.2 模型/Repository

- [ ] Pet、PetCategory、PetGender、PetStatus 等强类型模型。
- [ ] 数字/字符串 ID、日期、可空头像和分类容错。
- [ ] 列表、分类树、详情、创建、更新、删除 contract。
- [ ] 宠物头像上传复用 ApiClient multipart，category 以 RN/后端为准。

### 15.3 列表

- [ ] 首屏、刷新、空态、失败重试。
- [ ] 每个宠物卡展示 RN 现有核心字段。
- [ ] 新增入口。
- [ ] 编辑入口。
- [ ] 删除二次确认和防重复。
- [ ] 编辑/新增返回后只刷新一次。

### 15.4 编辑

- [ ] 新增和编辑共享表单但状态独立可测试。
- [ ] 编辑模式按 pet ID 读取详情，不只依赖列表对象。
- [ ] 宠物类型/品种选择基于分类树。
- [ ] 姓名、性别、生日/年龄、头像等字段与 RN 当前表单一致。
- [ ] 日期边界、未来日期、空字段、数字输入校验。
- [ ] 图片取消/失败/成功。
- [ ] 保存中禁重复；失败保留输入。
- [ ] 若后端 create/update 字段不同，Repository 显式映射。

### 15.5 测试与验收

- [ ] Model 和 Repository contract 测试。
- [ ] 列表 Controller 的刷新、删除、返回刷新测试。
- [ ] 编辑 Controller 的新增/编辑、校验和图片状态测试。
- [ ] 页面三种宽度和键盘测试。
- [ ] 新建后可见、编辑后更新、删除后消失。
- [ ] 不支持的跨域入口有明确提示和账本记录。

---

## 16. WP-07：医疗服务订单

### 16.1 步骤

- [ ] 审计 RN 医疗服务订单页面、`/chat/orders` 参数和响应。
- [ ] 区分商城订单与医疗/咨询订单模型。
- [ ] 定义状态枚举和未知状态 fallback。
- [ ] 实现 Repository、Controller、列表页面。
- [ ] 覆盖 loading、refresh、empty、error、分页（如果 API 支持）。
- [ ] 展示医生、服务类型、时间、金额、状态等 RN 可见字段。
- [ ] 如果 RN 页面没有详情跳转，Flutter 不臆造；如果有，则复用当前 chat history 能力或登记外部缺口。

### 16.2 测试与验收

- [ ] Contract 测试锁定 endpoint 和 query。
- [ ] 状态映射测试覆盖全部已知值和未知值。
- [ ] 列表 Widget 测试覆盖长医生名、空头像、空列表和错误。
- [ ] 个人中心入口可达，返回仍停留“我的”Tab。

---

## 17. WP-08：通知中心与未读同步

### 17.1 Repository/模型

- [ ] Notification、NotificationType、NotificationAction、分页模型。
- [ ] 列表、未读数、详情、单条已读、全部已读 contract。
- [ ] 时间、已读布尔值、actionData JSON/Map 容错。

### 17.2 未读控制

- [ ] App/登录会话级 badge controller，不把 60 秒 Timer 塞进 ListTile。
- [ ] 登录后首次获取未读数。
- [ ] 前台周期刷新；默认参考 RN 60 秒，写成可测试配置。
- [ ] app paused/inactive 时停止或暂停轮询，resumed 立即刷新。
- [ ] logout/dispose 取消 timer，防止跨账号污染。
- [ ] 打开通知、单条已读、全部已读后本地角标立即一致，再用服务端刷新校准。

### 17.3 列表与动作

- [ ] 分页/刷新/加载更多。
- [ ] 未读视觉区分。
- [ ] 点击先标已读，再执行支持的 destination。
- [ ] 全部已读有提交中状态和失败恢复策略。
- [ ] action 缺字段、未知类型、外部域页面缺失时不崩溃。
- [ ] orderId 跳商城订单详情；其他已存在目标按 coordinator 复用。

### 17.4 测试与验收

- [ ] fake clock/timer 测试轮询、pause/resume/dispose。
- [ ] contract 和 action parser 测试。
- [ ] 单条/全部已读乐观更新失败回滚测试。
- [ ] 角标 `0` 隐藏、`1..99` 原值、`>=100` 为 `99+`。
- [ ] 页面返回后主页面角标一致。

---

## 18. WP-09：我的优惠券

### 18.1 步骤

- [ ] 审计 RN MyCoupons 页面和 checkout 当前 coupon contract。
- [ ] 决定复用/抽取模型，记录决策和影响面。
- [ ] 实现列表和 count 请求。
- [ ] 支持 RN 当前状态筛选（可用、已使用、已过期等，以代码为准）。
- [ ] 正确计算/展示满减、折扣、门槛和有效期，不用 UI 猜测可用性。
- [ ] loading、empty、error、refresh、分页（如果 API 支持）。
- [ ] 券中心是查看模式，不误触 checkout 的“选择并返回”语义。

### 18.2 测试与验收

- [ ] 与 checkout 对相同 fixture 的解析结果一致。
- [ ] 状态筛选和过期边界测试。
- [ ] 金额、折扣、长名称和无门槛券 Widget 测试。
- [ ] 个人中心入口和未使用数量（如果展示）与接口一致。

---

## 19. WP-10：已有商城四入口差异收口

### 19.1 商城订单

- [ ] 个人中心跳转订单列表。
- [ ] 筛选、分页、下拉刷新。
- [ ] 取消、支付、确认收货、详情返回后的列表刷新。
- [ ] 入口集成测试，不重写已有页面。

### 19.2 收货地址

- [ ] 管理模式跳转。
- [ ] 新增、编辑、删除、设默认。
- [ ] checkout 选择模式不被个人中心改动破坏。

### 19.3 我的收藏

- [ ] 对比 RN 的列表内 SKU/数量交互与 Flutter 当前行为。
- [ ] 在决策记录明确：严格追平列表选择，或保留 Flutter 跳详情的产品差异。
- [ ] 无 SKU 商品加购数量、成功反馈和购物车状态正确。
- [ ] 取消收藏后列表状态正确。

### 19.4 我发布商品

- [ ] 筛选、分页和状态展示。
- [ ] 发布、编辑返回刷新。
- [ ] 上下架操作防重复。
- [ ] 拒绝原因完整可读。

### 19.5 验收

- [ ] 现有 `mall_pages_responsive_test.dart` 全部通过。
- [ ] 新增 profile -> 四入口的导航测试。
- [ ] 已有商城测试无回归。
- [ ] 不复制现有 Mall Repository 或 Coordinator。

---

## 20. WP-11：视觉、响应式、可访问性和生命周期

### 20.1 视觉对齐

- [ ] 以 RN 信息层级、间距、卡片结构、颜色语义和图标语义为基线。
- [ ] 遵循 Flutter 项目现有 Material 风格，不复制 RN 平台私有实现。
- [ ] 卡片圆角不超过现有设计系统惯例。
- [ ] 不使用嵌套卡片、无意义渐变或装饰性背景。
- [ ] 默认图必须来自现有资源或清晰的系统图标；若新增资源，登记来源和 pubspec 影响。

### 20.2 响应式矩阵

至少检查：

| 环境 | 视口 | 重点 |
|---|---:|---|
| 小屏 Android | 320x568 | 长文案、编辑键盘、按钮宽度 |
| 常规 iPhone | 390x844 | 主设计基线、安全区 |
| 常规 Android | 402x874 | 列表和卡片比例 |
| 大字体 | text scale 1.3/1.5 | 标题、金额、按钮不重叠 |
| 横屏（若 App 支持） | 844x390 | 不崩溃、不出现无界约束 |

页面固定 UI 元素使用稳定约束，动态文本允许换行或省略；不得按 viewport width 线性缩放字体。

### 20.3 可访问性

- [ ] 头像、编辑、服务入口、金额、未读角标有合理 semantics。
- [ ] 图标按钮有 tooltip/语义名称。
- [ ] 点击区域至少符合平台可用尺寸。
- [ ] 不只用颜色表达性别、状态、收入/支出和已读状态。
- [ ] loading 状态不会永久屏蔽返回操作。

### 20.4 生命周期

- [ ] 页面返回后按需要刷新，不重复创建 controller。
- [ ] app resume 刷新需要时的数据。
- [ ] notification timer 正确暂停/恢复/销毁。
- [ ] 图片选择返回和系统权限弹窗后状态一致。
- [ ] logout 后不残留旧用户缓存、timer 或 navigation pending destination。

### 20.5 验收

- [ ] Widget 测试覆盖上述视口且 `tester.takeException()` 为 null。
- [ ] 真机/模拟器至少各检查一个平台；无法执行时记录剩余风险。
- [ ] 截图写入验证记录，明确页面和状态。

---

## 21. WP-12：全量回归、缺口审计与交付

### 21.1 静态与自动化验证

- [ ] `dart format --output=none --set-exit-if-changed lib test`
- [ ] `flutter analyze`
- [ ] 所有新增定向测试。
- [ ] `flutter test`
- [ ] 必要时运行 RN 个人中心基线测试，确认基线没有被误读。
- [ ] `git diff --check`
- [ ] CodeGraph `sync` 后对共享符号执行最终 impact/callers 核对。

### 21.2 功能走查

- [ ] 登录 -> 我的 -> 九入口逐一打开。
- [ ] 编辑昵称/性别/头像 -> 返回 -> 重启恢复。
- [ ] 钱包统计 -> 明细 -> 关联订单。
- [ ] 宠物新增 -> 编辑 -> 删除。
- [ ] 医疗订单有数据/空/错。
- [ ] 通知未读 -> 单条已读 -> 全部已读 -> 角标一致。
- [ ] 优惠券筛选和过期展示。
- [ ] 商城订单/地址/收藏/发布商品无回归。
- [ ] 系统文章三种类型和联系方式。
- [ ] 退出取消/确认。
- [ ] 注销取消/模拟失败/契约成功流程；禁止用生产账号真删。
- [ ] logout 后返回键无法进入受保护页面。

### 21.3 死入口审计

逐项搜索并确认：

- [ ] 无“TODO 页面”“暂未开放”或只显示 label 的占位入口。
- [ ] 无未使用的 profile 回调。
- [ ] 无动态字符串路由和 unchecked cast。
- [ ] 无页面直接拼后端 base URL。
- [ ] 无 Widget 直接调用 ApiClient。
- [ ] 无 timer/stream/controller 未 dispose。
- [ ] 无仍从静态 session 参数读取旧头像/昵称而忽略 AuthController 更新的页面。

### 21.4 交付标准

只有同时满足以下条件，才可把目标标记完成：

- [ ] WP-00 至 WP-12 全部为 `DONE`，或明确记录经用户接受的范围变更。
- [ ] 所有“必须完成”入口均为真实页面。
- [ ] 自动化验证实际通过并写入验证记录。
- [ ] 所有已知剩余风险有原因、影响和后续动作。
- [ ] 进度账本没有未解决 blocker。
- [ ] 用户未授权时未执行 commit/push。

---

## 22. 测试策略总表

| 层级 | 测什么 | 方法 |
|---|---|---|
| Domain | JSON/type 容错、金额、日期、状态、手机号脱敏 | 纯 Dart unit test |
| Repository | HTTP 方法、路径、query/body、鉴权、envelope、异常 | fake HTTP client contract test |
| Controller | 加载/刷新/分页、竞态、重复提交、失败恢复、dispose | fake gateway unit test |
| Widget | 状态渲染、点击、表单、响应式、semantics | `WidgetTester` |
| Navigation | 九入口、委托商城、参数、返回刷新、登录 gating | `NavigatorObserver`/集成 Widget test |
| Lifecycle | resume/pause、timer、图片选择返回、logout 清理 | 可注入 clock/lifecycle 测试 |
| End-to-end | 登录至各页面的关键路径 | Flutter integration test 或人工真机走查 |

每个 bug 修复必须至少新增一个能在修复前失败、修复后通过的回归测试，除非无法自动化；无法自动化时在验证记录说明人工步骤。

---

## 23. 风险清单与处理策略

| 风险 | 影响 | 处理 |
|---|---|---|
| `flutter_app/` 当前在 Git 中整体显示未跟踪 | 难以区分迁移前后差异 | 每轮用文件清单和局部 diff/哈希记录，不擅自 git add |
| RN 注释称来自旧 Flutter 页面 | 可能把历史实现当当前 contract | 以当前 RN 实际代码、后端和测试为准 |
| RN `integral` 固定为 0 | 会员等级不真实 | 默认普通会员，不臆造积分 |
| API envelope 不一致 | Repository 解析失败 | WP-00 锁 fixture，contract test |
| 资料更新后 session 仍旧 | 多页面显示不一致 | AuthController 单一更新入口并持久化 |
| 上传成功但编辑取消产生孤立文件 | 服务端残留 | 与 RN 保持行为；记录后端清理风险，不擅自新增删除接口 |
| 通知 action 指向未迁移域 | 死入口/崩溃 | 强类型解析，支持目标真实跳转，其余明确提示并登记 |
| 通知轮询跨账号残留 | 隐私和数据串号 | session scoped controller，logout/dispose 取消 |
| 注销账号不可逆 | 真实数据损失 | 不用生产账号实测，mock/contract 验证，强确认 |
| 收藏 SKU 交互不一致 | 用户操作路径变化 | WP-10 明确产品决策并测试 |
| 小屏键盘遮挡编辑表单 | 无法保存 | 可滚动表单、SafeArea、320 宽测试 |
| 共享 AuthController 修改回归 | 登录/恢复/登出受影响 | 先测试，CodeGraph impact，全 auth tests |
| 新增依赖/资源影响构建 | lockfile 和平台配置变化 | 优先现有 `image_picker`/`flutter_html`，新增需用户确认 |

---

## 24. 变更纪律

- 一次工作包只处理其范围；发现无关问题写入进度账本“候选后续”，不顺手重构。
- 修改共享 API、类型、根配置、依赖、lockfile、构建系统或后端前，必须获得用户确认。
- 新增资源前检查能否使用 Material icon 或现有 assets；需要新增 assets 时同步 `pubspec.yaml` 属于根配置修改，先确认。
- 不删除旧 `profile_mall_view.dart`，除非迁移完成、调用方切换、测试通过且用户授权删除；可以先保留兼容包装。
- 不运行 destructive Git 命令，不清理用户工作区。
- 任何后端 API 修改必须同步 `admin/API_DOCUMENT.md`。
- 未经授权不 commit、不 push、不创建 PR。

---

## 25. 目标模式执行提示词

在新会话中粘贴以下内容：

```text
plan2go=/Users/wujie/Desktop/code/xuduo/pet-hospitals/flutter_app/docs/RN_PROFILE_FULL_MIGRATION_PLAN.md

请进入目标模式，长期执行 RN 用户端“我的/个人中心”到 Flutter 的完整迁移。

执行要求：
1. 将 plan2go 文件视为唯一主计划，并完整阅读同目录下的：
   - RN_PROFILE_MIGRATION_PROGRESS.md
   - RN_PROFILE_MIGRATION_DECISIONS.md
   - RN_PROFILE_MIGRATION_VERIFICATION.md
2. 每次新会话或上下文恢复时严格执行计划中的“新会话恢复协议”。
3. 从进度账本的“下一动作”继续，不重复已完成工作；同一时间只推进一个主要工作包。
4. 每个工作包必须完成 CodeGraph 分析、实现、定向测试、状态更新和验证记录后，才能标记 DONE。
5. 遇到可以从代码、后端或测试确认的信息时自行查证并继续；只有会显著改变范围、公共 contract、依赖、根配置、后端或数据安全时才请求我确认。
6. 不得回滚现有用户改动，不得未经授权删除文件、修改依赖/lockfile、修改后端、commit、push、merge 或创建 PR。
7. 持续执行到 WP-00 至 WP-12 全部满足交付标准；不要在只有分析或半成品时提前结束目标。
8. 每轮结束前更新外部记忆文件，确保下一会话可以无损恢复。
```

---

## 26. 首次执行的明确下一动作

首次目标会话不要直接写 UI。按以下顺序启动：

1. 执行恢复协议。
2. 在进度账本将 `WP-00` 标为 `IN_PROGRESS`。
3. 使用 CodeGraph 分别建立 RN profile 路由图和 Flutter profile/auth/mall 依赖图。
4. 阅读后端七组 contract，补全验证记录中的 API 审计表。
5. 运行并记录完整 Flutter 分析/测试基线；如已有失败，先区分是否与迁移相关。
6. 完成 WP-00 验收后再进入 WP-01。
