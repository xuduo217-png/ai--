# RN Profile -> Flutter 迁移进度账本

> 此文件是跨会话运行状态，不是设计文档。每轮开始先读，每轮结束必更新。  
> 最后更新：2026-07-25（目标恢复独立复核）
> 总体状态：`DONE`
> 当前工作包：`WP-12 已完成，WP-00 至 WP-12 全部交付`

## 1. 恢复卡片

新会话只需先读取本节即可定位现场，但仍须按主计划要求完整阅读四份文档。

- 主计划：`docs/RN_PROFILE_FULL_MIGRATION_PLAN.md`
- 当前阶段：WP-00 至 WP-12 全部满足计划交付标准；生产九入口、钱包、编辑资料、通知角标及商城委托均有真实实现和自动化证据。
- 当前工作包：`无；WP-12 已完成`
- 当前工作包状态：`DONE`
- 最后完成动作：目标恢复后重新完成 CodeGraph/死入口审计、Flutter 全量 420/420、RN 基线 8/8、220 文件格式门禁和 `flutter analyze`；当前工作区再次证明满足 WP-12 交付门禁。
- 下一动作：当前目标无需继续实施；后续仅在获得隔离测试账号/真机环境后补真实服务端、相册权限和外部 App 的非阻塞人工证据。
- 当前阻塞：无。
- 需要用户确认：无；新增依赖、根配置、后端/contract 修改等出现时再确认。
- 禁止动作：未经授权不删除文件、不改依赖/lockfile、不改后端、不 commit/push。

## 2. 当前工作区事实

建立计划时 `git status --short` 显示：

```text
 M .codegraph/daemon.pid
 M admin/API_DOCUMENT.md
 M server/DEPLOYMENT.md
 M server/nginx.conf
?? flutter_app/
```

这些改动视为用户已有状态。不得回滚、覆盖或清理。由于 `flutter_app/` 整体未跟踪，每轮必须在本文件记录本轮具体改动文件，不能只依赖 Git diff 判断归属。

CodeGraph 建立计划时状态：索引已存在且为 up-to-date；约 1554 files、22286 nodes、49131 edges。执行会话仍须重新运行 `codegraph status`。

2026-07-25 本轮恢复时 `git status --short --branch` 仅显示 `## master...origin/master`，未见未提交改动；`codegraph status` 显示索引 up-to-date（1554 files、22330 nodes、49234 edges）。历史工作区事实保留用于追溯，不据此回滚任何文件。

2026-07-25 目标恢复独立复核时，`git status --short --branch` 显示整套迁移的已跟踪修改与新增 Profile 子模块/测试；这些文件与下方 WP-01 至 WP-12 变更清单一致。本轮未回滚、暂存或覆盖任何现有改动；CodeGraph 为 up-to-date（1626 files、23953 nodes、53334 edges）。

## 3. 工作包状态

| ID | 状态 | 开始时间 | 完成时间 | 备注 |
|---|---|---|---|---|
| WP-00 | DONE | 2026-07-25 | 2026-07-25 | 基线冻结与 contract 审计；RN 原图受条件限制，已有历史运行日志证据 |
| WP-01 | DONE | 2026-07-25 | 2026-07-25 | Profile 模型、Repository、会话同步；定向与全量回归通过 |
| WP-02 | DONE | 2026-07-25 | 2026-07-25 | 九入口强类型导航、商城委托、通知解析、根稳定组装；定向与全量回归通过 |
| WP-03 | DONE | 2026-07-25 | 2026-07-25 | 主页面、编辑资料、九个真实服务目标及钱包入口完成跨包验收 |
| WP-04 | DONE | 2026-07-25 | 2026-07-25 | 钱包与我的收益；contract、竞态分页、3 宽度页面和生产路由验证通过 |
| WP-05 | DONE | 2026-07-25 | 2026-07-25 | 联系配置、系统文章、安全外链、退出/注销、会话清栈和生产路由验证通过 |
| WP-06 | DONE | 2026-07-25 | 2026-07-25 | 宠物列表/编辑 CRUD、分类、头像、并发状态和生产路由验证通过 |
| WP-07 | DONE | 2026-07-25 | 2026-07-25 | 独立医疗订单模型、分页竞态、状态/金额、异常态和生产路由验证通过 |
| WP-08 | DONE | 2026-07-25 | 2026-07-25 | 通知列表、未读同步、会话轮询、生命周期、乐观回滚和安全 action 跳转验证通过 |
| WP-09 | DONE | 2026-07-25 | 2026-07-25 | 共享优惠券模型、列表/count、三状态只读中心、竞态与生产路由验证通过 |
| WP-10 | DONE | 2026-07-25 | 2026-07-25 | 四入口竞态、分页、返回刷新、确认操作及生产路由完成回归 |
| WP-11 | DONE | 2026-07-25 | 2026-07-25 | 六视口/字体矩阵、可访问性、异步销毁与 iOS 模拟器视觉验收完成 |
| WP-12 | DONE | 2026-07-25 | 2026-07-25 | 全量回归、死入口审计、资料消费者修复及逐项交付映射完成 |

状态规则：

- `TODO`：尚未开始。
- `IN_PROGRESS`：当前唯一主要工作包。
- `BLOCKED`：有具体、已记录且无法自行消除的阻塞。
- `VERIFYING`：实现完成，正在完成验收。
- `DONE`：验收条件和证据均完成。

不得把“代码已写但未测试”标为 `DONE`。

## 4. 已确认基线

### RN 主页面

- 用户资料来自 AuthContext；显示头像、昵称、性别和会员文案。
- `integral` 当前硬编码为 0，因此会员文案实际为“普通会员”。
- 编辑资料调用 `PUT /users/me`。
- 头像调用 multipart `POST /upload/image`，category=`user-avatar`。
- 钱包摘要调用 `GET /shop/wallet/stats`。
- 服务项共 9 个。
- 头像大图仅为 TODO，不属于当前等价要求。

### Flutter 当前主页面

- `ProfilePage/ProfileController` 已展示服务端资料、真实钱包摘要、九项服务和可选通知角标。
- 资料与钱包独立失败；钱包失败显示局部错误而不是伪造 `0.00`。
- 编辑页使用全屏表单，支持头像选择/上传、差异 patch、Auth session 持久化和失败重试。
- 登录首页通过稳定 `ProfileControllerFactory` 使用完整个人中心；游客仍在账号 Tab 路由前拦截。
- 退出登录已从完整个人中心移入真实系统设置页；系统设置同时提供联系方式、系统文章和注销账号闭环，退出/注销后受保护导航栈会清空。
- 我的宠物已接入真实列表与编辑页，支持分类筛选、CRUD、头像相册上传和明确的走失寻宠外部域反馈。
- 医疗服务订单已接入真实分页列表，支持下拉刷新、加载更多、五种状态与 unknown fallback、医生/服务/时间/金额展示和明确空错态。
- 通知中心已接入列表、未读角标、前后台轮询、已读操作和安全 action 跳转。
- 我的优惠券已接入真实非分页列表与 count，支持可用、已使用、已过期筛选，并保持只读查看语义。

### Flutter 已有可复用模块

- 商城订单：列表、分页、刷新、取消、支付、确认、详情。
- 地址：CRUD、默认、选择模式。
- 收藏：列表、详情/加购，但 SKU 操作与 RN 存在产品差异。
- 我发布商品：筛选、分页、发布/编辑、上下架、拒绝原因。

## 5. 当前差异摘要

| 功能 | 状态 | 说明 |
|---|---|---|
| 真实资料展示 | 已实现 | GET `/users/me`、session fallback、独立错误、刷新及所有真实目标接线已完成 |
| 编辑资料/头像 | 已实现 | 上传暂存、差异 patch、session 持久化和失败保留已完成 |
| 钱包摘要/收益 | 已实现 | 主页面三项摘要、收益筛选分页、刷新、订单委托和生产路由已完成 |
| 我的宠物 | 已实现 | 列表/筛选、完整 CRUD、头像上传、异常/并发和生产路由已完成 |
| 医疗订单 | 已实现 | 独立读取 `/chat/orders` 内层分页 map；无 RN 详情行为，不臆造跳转 |
| 通知 | 已实现 | 列表、角标、登录会话级轮询、乐观已读回滚和 action 容错已完成 |
| 优惠券中心 | 已实现 | 共享规则快照解析、列表/count、三状态筛选和只读查看已完成 |
| 系统设置/文章 | 已实现 | public 联系配置、HTML 文章、安全外链、退出/注销和生产路由已完成 |
| 商城四入口 | 已实现 | 订单/发布筛选竞态、分页去重、返回刷新、地址选择/管理和收藏确认均已收口；SKU 统一进入商品详情 |

### WP-00 九入口映射

| 入口 | RN 文件/route | Flutter 目标 | Endpoint/委托 |
|---|---|---|---|
| 我的宠物 | `PetListScreen` -> `PetEdit` | `features/pets` | `/pets/my`、`/pets/:id`、`/pet-categories/tree` |
| 商城订单 | `OrderListScreen` -> `OrderDetail` | 复用 mall order | `/shop/orders/my`，委托 `MallNavigationCoordinator` |
| 医疗服务 | `MedicalServiceOrderListScreen` | `features/medical_orders` | `/chat/orders` |
| 收货地址 | `AddressListScreen` -> `AddressEdit` | 复用 mall address | `/addresses...`，委托 mall coordinator |
| 通知消息 | `NotificationScreen` | `features/notifications` | `/notifications...` |
| 我的优惠券 | `MyCouponsScreen` | `features/coupons` | `/shop/coupons/my`、`/count` |
| 我的收藏 | `MyFavoritesScreen` | 复用 mall favorite | `/shop/favorites...`，委托 mall coordinator |
| 我发布商品 | `MyPublishedProductsScreen` | 复用 mall second_hand | `/shop/products/my`，委托 mall coordinator |
| 系统设置 | `SystemConfigScreen` -> `SystemArticle` | `features/settings` | `/system-configs/contact_info`、`/system-articles/:type`、auth logout、`DELETE /users/me` |

钱包卡片是九入口之外的独立入口：`MyIncomeScreen` -> `features/wallet`，使用 `/shop/wallet/stats` 和 `/shop/wallet/transactions`，订单详情委托 mall coordinator。

## 6. 当前工作包执行记录

```text
工作包：WP-12
状态：DONE
目标：完成死入口、重复实现、contract、全链路和遗留风险审计，运行最终全量门禁并形成逐项交付映射。
CodeGraph 查询：目标恢复后重新 sync 并查询 ProfilePageFactory/destination/legacy profile，对 ProfilePageFactory、NotificationBadgeController 和 AuthController.updateProfile 执行 impact，对 ProfileMallView 执行 callers；最终索引 1626 files、23953 nodes、53334 edges，up-to-date。
已读文件：完整主计划、三份外部记忆、Profile factory/coordinator/routes、App/Home/Profile controller、Friends 头像消费者及关联测试。
已修改文件：本轮仅更新三份外部记忆；业务代码未修改。
已完成步骤：生产六个 owned 目标与四个 Mall 委托目标重新审计；旧 ProfileMallView 零 caller；API endpoint 归属 data repository；Flutter 全量 420/420、RN 8/8、220 文件 format、analyze 和最终 git diff 检查通过。
当前失败/阻塞：无。真实服务端数据、相册权限、外部 App 和破坏性账号动作未在个人设备执行，原因和替代证据保留在验证记录中，不影响计划定义的交付。
下一动作：无。
下一条建议命令：无；目标已完成。
```

## 7. 阻塞项

当前无阻塞。

新增阻塞必须包含：

| ID | 首次发现 | 工作包 | 具体事实 | 已尝试 | 需要谁/什么 | 解除条件 |
|---|---|---|---|---|---|---|
| - | - | - | - | - | - | - |

不要把普通测试失败或仍可继续调查的问题写成用户阻塞。

## 8. 外部域缺口

用于记录通知或宠物页面跳往本计划之外、且 Flutter 尚无目标页面的情况。

| 来源 | RN 目标 | Flutter 状态 | 当前降级 | 是否影响本计划完成 |
|---|---|---|---|---|
| 宠物列表 | `LostFoundList(mineOnly: true)` | Flutter 无走失发布页 | WP-06 显示明确“暂不支持该外部域”反馈，不创建空页 | 否，D-002 已接受 |
| 通知 action=`appointment` | `AppointmentDetail(appointmentId)` | Flutter 当前无预约详情页 | WP-08 强类型识别并明确提示 | 否，外部域 |
| 通知 action=`page` | 服务端动态 path；已观察 `UserProfile` 参数兼容 | 仅白名单目标可跳转 | WP-08 未支持 path 明确提示并记录 | 否，外部域 |
| 通知 action=`url` | RN enum 声明但页面未实现 | Flutter 不扩展 RN TODO | 安全忽略并明确反馈 | 否 |

## 9. 本轮变更文件

计划建立轮次只新增：

- `flutter_app/docs/RN_PROFILE_FULL_MIGRATION_PLAN.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_PROGRESS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_DECISIONS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_VERIFICATION.md`

后续每轮追加日期小节，列出该轮实际修改文件。不要把未修改文件列入。

### 2026-07-25 / WP-00

- `flutter_app/docs/RN_PROFILE_MIGRATION_PROGRESS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_DECISIONS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_VERIFICATION.md`
- 业务代码未修改。
- 测试截图与临时 capture harness 位于 `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp00/`，未加入产品 assets。

### 2026-07-25 / WP-01

- `flutter_app/lib/features/auth/domain/auth_models.dart`
- `flutter_app/lib/features/auth/presentation/auth_controller.dart`
- `flutter_app/lib/features/profile/domain/profile_models.dart`
- `flutter_app/lib/features/profile/data/profile_repository.dart`
- `flutter_app/test/auth_controller_test.dart`
- `flutter_app/test/profile_models_test.dart`
- `flutter_app/test/profile_repository_contract_test.dart`
- `flutter_app/docs/RN_PROFILE_MIGRATION_PROGRESS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_DECISIONS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_VERIFICATION.md`
- 未修改依赖、lockfile、根配置、后端或 API 文档。

### 2026-07-25 / WP-02

- `flutter_app/lib/features/profile/navigation/profile_routes.dart`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/lib/features/profile/navigation/profile_navigation_coordinator.dart`
- `flutter_app/lib/features/mall/navigation/mall_navigation_coordinator.dart`
- `flutter_app/lib/features/home/presentation/home_page.dart`
- `flutter_app/lib/features/auth/presentation/pages/auth_page.dart`
- `flutter_app/lib/app.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/test/profile_navigation_test.dart`
- `flutter_app/test/home_page_test.dart`
- `flutter_app/docs/RN_PROFILE_MIGRATION_PROGRESS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_DECISIONS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_VERIFICATION.md`
- 未修改依赖、lockfile、根配置、后端或 API 文档。

### 2026-07-25 / WP-03

- `flutter_app/lib/features/profile/domain/profile_models.dart`
- `flutter_app/lib/features/profile/data/profile_repository.dart`
- `flutter_app/lib/features/profile/presentation/profile_controller.dart`
- `flutter_app/lib/features/profile/presentation/pages/profile_page.dart`
- `flutter_app/lib/features/profile/presentation/pages/profile_edit_page.dart`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/lib/features/wallet/domain/wallet_models.dart`
- `flutter_app/lib/features/wallet/data/wallet_repository.dart`
- `flutter_app/lib/features/home/presentation/home_page.dart`
- `flutter_app/lib/app.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/test/profile_controller_test.dart`
- `flutter_app/test/profile_page_test.dart`
- `flutter_app/test/profile_edit_test.dart`
- `flutter_app/test/profile_repository_contract_test.dart`
- `flutter_app/test/wallet_repository_contract_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- `flutter_app/test/home_page_test.dart`
- 三份外部记忆文件。
- 未修改依赖、lockfile、根配置、后端或 API 文档。

### 2026-07-25 / WP-04

- `flutter_app/lib/features/wallet/domain/wallet_models.dart`
- `flutter_app/lib/features/wallet/data/wallet_repository.dart`
- `flutter_app/lib/features/wallet/presentation/wallet_controller.dart`
- `flutter_app/lib/features/wallet/presentation/pages/wallet_page.dart`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/lib/features/profile/navigation/profile_navigation_coordinator.dart`
- `flutter_app/test/wallet_repository_contract_test.dart`
- `flutter_app/test/wallet_controller_test.dart`
- `flutter_app/test/wallet_page_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- `flutter_app/test/profile_page_test.dart`
- 三份外部记忆文件。
- 未修改依赖、lockfile、根配置、后端或 API 文档。

### 2026-07-25 / WP-05

- `flutter_app/lib/features/settings/domain/settings_models.dart`
- `flutter_app/lib/features/settings/data/settings_repository.dart`
- `flutter_app/lib/features/settings/presentation/settings_controller.dart`
- `flutter_app/lib/features/settings/presentation/pages/settings_page.dart`
- `flutter_app/lib/features/settings/presentation/pages/system_article_page.dart`
- `flutter_app/lib/core/platform/external_uri_launcher.dart`
- `flutter_app/android/app/src/main/kotlin/com/good/pet/hospital/pet_hospital_flutter/MainActivity.kt`
- `flutter_app/ios/Runner/AppDelegate.swift`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/lib/app.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/test/settings_repository_contract_test.dart`
- `flutter_app/test/settings_controller_test.dart`
- `flutter_app/test/settings_page_test.dart`
- `flutter_app/test/system_article_page_test.dart`
- `flutter_app/test/external_uri_launcher_test.dart`
- `flutter_app/test/auth_controller_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- `flutter_app/test/widget_test.dart`
- 三份外部记忆文件。
- 未修改依赖、lockfile、Manifest、Info.plist、根配置、后端或 API 文档。

### 2026-07-25 / WP-06

- `flutter_app/lib/features/pets/domain/pet_models.dart`
- `flutter_app/lib/features/pets/data/pet_repository.dart`
- `flutter_app/lib/features/pets/presentation/pet_editor_result.dart`
- `flutter_app/lib/features/pets/presentation/pet_list_controller.dart`
- `flutter_app/lib/features/pets/presentation/pet_edit_controller.dart`
- `flutter_app/lib/features/pets/presentation/pages/pet_list_page.dart`
- `flutter_app/lib/features/pets/presentation/pages/pet_edit_page.dart`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/test/pet_models_test.dart`
- `flutter_app/test/pet_repository_contract_test.dart`
- `flutter_app/test/pet_list_controller_test.dart`
- `flutter_app/test/pet_edit_controller_test.dart`
- `flutter_app/test/pet_pages_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- 三份外部记忆文件。
- 未修改依赖、lockfile、Manifest、Info.plist、根配置、后端或 API 文档。

### 2026-07-25 / WP-07

- `flutter_app/lib/features/medical_orders/domain/medical_order_models.dart`
- `flutter_app/lib/features/medical_orders/data/medical_order_repository.dart`
- `flutter_app/lib/features/medical_orders/presentation/medical_order_controller.dart`
- `flutter_app/lib/features/medical_orders/presentation/pages/medical_order_page.dart`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/test/medical_order_models_test.dart`
- `flutter_app/test/medical_order_repository_contract_test.dart`
- `flutter_app/test/medical_order_controller_test.dart`
- `flutter_app/test/medical_order_page_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- 三份外部记忆文件。
- 未修改依赖、lockfile、平台根配置、后端或 API 文档。

### 2026-07-25 / WP-08

- `flutter_app/lib/features/notifications/domain/notification_models.dart`
- `flutter_app/lib/features/notifications/data/notification_repository.dart`
- `flutter_app/lib/features/notifications/presentation/notification_badge_controller.dart`
- `flutter_app/lib/features/notifications/presentation/notification_list_controller.dart`
- `flutter_app/lib/features/notifications/presentation/pages/notification_list_page.dart`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/lib/features/profile/presentation/pages/profile_page.dart`
- `flutter_app/lib/features/home/presentation/home_page.dart`
- `flutter_app/lib/app.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/test/notification_models_test.dart`
- `flutter_app/test/notification_repository_contract_test.dart`
- `flutter_app/test/notification_badge_controller_test.dart`
- `flutter_app/test/notification_controller_test.dart`
- `flutter_app/test/notification_page_test.dart`
- `flutter_app/test/notification_app_lifecycle_test.dart`
- `flutter_app/test/profile_page_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- 三份外部记忆文件。
- 未修改依赖、lockfile、平台根配置、后端或 API 文档。

### 2026-07-25 / WP-09

- `flutter_app/lib/features/coupons/domain/coupon_models.dart`
- `flutter_app/lib/features/coupons/data/coupon_repository.dart`
- `flutter_app/lib/features/coupons/presentation/coupon_center_controller.dart`
- `flutter_app/lib/features/coupons/presentation/pages/coupon_center_page.dart`
- `flutter_app/lib/features/mall/checkout/data/checkout_repository.dart`
- `flutter_app/lib/features/profile/navigation/profile_dependencies.dart`
- `flutter_app/test/coupon_models_test.dart`
- `flutter_app/test/coupon_repository_contract_test.dart`
- `flutter_app/test/coupon_center_controller_test.dart`
- `flutter_app/test/coupon_center_page_test.dart`
- `flutter_app/test/mall_repository_contract_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- 三份外部记忆文件。
- 未修改依赖、lockfile、平台根配置、后端或 API 文档。

### 2026-07-25 / WP-10

- `flutter_app/lib/features/mall/order/presentation/order_controller.dart`
- `flutter_app/lib/features/mall/order/presentation/pages/order_list_page.dart`
- `flutter_app/lib/features/mall/favorite/presentation/favorite_controller.dart`
- `flutter_app/lib/features/mall/favorite/presentation/pages/favorite_page.dart`
- `flutter_app/lib/features/mall/second_hand/presentation/second_hand_controller.dart`
- `flutter_app/lib/features/mall/second_hand/presentation/pages/published_product_page.dart`
- `flutter_app/test/mall_controller_test.dart`
- `flutter_app/test/mall_pages_responsive_test.dart`
- `flutter_app/test/profile_navigation_test.dart`
- 三份外部记忆文件。
- 未修改 Repository、API contract、依赖、lockfile、平台根配置、后端或 API 文档。

### 2026-07-25 / WP-11

- `flutter_app/lib/features/profile/presentation/pages/profile_page.dart`
- `flutter_app/lib/features/profile/presentation/pages/profile_edit_page.dart`
- `flutter_app/lib/features/profile/presentation/profile_controller.dart`
- `flutter_app/lib/features/notifications/presentation/pages/notification_list_page.dart`
- `flutter_app/lib/features/pets/presentation/pages/pet_list_page.dart`
- `flutter_app/lib/features/mall/address/presentation/address_controller.dart`
- `flutter_app/lib/features/mall/address/presentation/pages/address_list_page.dart`
- `flutter_app/lib/features/mall/order/presentation/order_controller.dart`
- `flutter_app/lib/features/mall/favorite/presentation/favorite_controller.dart`
- `flutter_app/lib/features/mall/second_hand/presentation/second_hand_controller.dart`
- `flutter_app/test/support/wp11_viewports.dart`
- `flutter_app/test/profile_page_test.dart`
- `flutter_app/test/profile_edit_test.dart`
- `flutter_app/test/profile_controller_test.dart`
- `flutter_app/test/wallet_page_test.dart`
- `flutter_app/test/settings_page_test.dart`
- `flutter_app/test/system_article_page_test.dart`
- `flutter_app/test/pet_pages_test.dart`
- `flutter_app/test/medical_order_page_test.dart`
- `flutter_app/test/notification_page_test.dart`
- `flutter_app/test/coupon_center_page_test.dart`
- `flutter_app/test/mall_controller_test.dart`
- `flutter_app/test/mall_pages_responsive_test.dart`
- `flutter_app/docs/RN_PROFILE_MIGRATION_PROGRESS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_DECISIONS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_VERIFICATION.md`
- 外部视觉 harness 与三张截图位于 `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp11/`，未加入产品代码或 assets。
- 未修改 Repository、API contract、依赖、lockfile、平台根配置、后端或 API 文档。

### 2026-07-25 / WP-12

- `flutter_app/lib/features/friends/presentation/friend_chat_controller.dart`
- `flutter_app/docs/RN_PROFILE_MIGRATION_PROGRESS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_DECISIONS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_VERIFICATION.md`
- 未修改 Repository、API contract、依赖、lockfile、平台根配置、后端或 `admin/API_DOCUMENT.md`。

### 2026-07-25 / WP-12 目标恢复独立复核

- `flutter_app/docs/RN_PROFILE_MIGRATION_PROGRESS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_DECISIONS.md`
- `flutter_app/docs/RN_PROFILE_MIGRATION_VERIFICATION.md`
- 业务代码未修改；未修改依赖、lockfile、平台根配置、后端或 `admin/API_DOCUMENT.md`。

## 10. 候选后续事项

这里只记录不应打断当前工作包的发现。当前无候选项。

## 11. 会话交接日志

### 2026-07-25：目标恢复后的独立最终复核

- 完整重读主计划和三份外部记忆，确认当前唯一状态仍为 WP-00 至 WP-12 全部 DONE、无 blocker。
- CodeGraph sync 为 Already up to date；重新核对生产 Profile factory、强类型 destination、会话资料更新、通知生命周期和旧 ProfileMallView 调用面。
- 静态死入口审计确认六个 owned 页面被生产工厂穷举，四个 Mall 入口统一委托，Profile 页面无动态命名路由，相关 endpoint 仍由 data repository 持有。
- 当前工作区重新通过 Flutter 420/420、RN 8/8、220 文件格式检查、`flutter analyze` 和最终 `git diff --check`；本轮未修改业务代码、依赖、lockfile、后端或 API 文档。
- 下一动作仍为无；仅在具备隔离账号/真机环境后可补非阻塞人工证据。

### 2026-07-25：WP-12 全量回归、缺口审计与交付收口

- 完整恢复四份执行文档并按 CodeGraph 查询/impact 审计生产 factory、九入口 coordinator、Auth session 更新、通知角标和好友头像消费者。
- 静态审计确认 Profile 自有六目标由 production factory 穷举，四个商城目标委托现有 Mall coordinator；旧 `ProfileMallView` 零 caller，按主计划删除授权边界保留；页面层无 `ApiClient`，Profile 无动态命名路由，相关 endpoint 只存在于 data repository。
- 首次全量 419 passed、1 failed，红灯为“资料更新后活动聊天立即使用最新用户头像”；将 `FriendChatController` 的消息监听前移至构造阶段，初始化前只通知最新头像、初始化后继续重载消息，现有回归测试转绿。
- 修复后消息/好友/App 清栈定向 26/26、个人中心完整功能链路 308/308、Flutter 全量 420/420、RN 基线 8/8；220 文件格式检查零变更，`flutter analyze` 无问题，CodeGraph 最终 1626/23953/53334。
- 真实服务端、真实相册权限、外部 App 和注销生产账号仍未在个人设备执行；使用 contract、controller、Widget、导航、生命周期测试和 iOS Simulator 视觉证据替代，未把这些高风险动作伪报为人工通过。
- WP-00 至 WP-12 全部 DONE，目标无 blocker；未 commit、push、修改依赖、lockfile、后端或 API 文档。

### 2026-07-25：WP-11 视觉、响应式、可访问性与生命周期收口

- 建立 320x568、390x844、402x874、320x568@1.3、390x844@1.5 和 844x390 六组统一 Widget 视口矩阵，覆盖 Profile owned 页面及四个复用 Mall 入口。
- 矩阵红灯捕获宠物元信息 4.7px 和地址联系人 29px 窄屏溢出；分别改为可收缩省略和多行 Wrap 后，相关 29/29 回归通过。
- 个人中心头像、性别、编辑入口、钱包金额、九服务及 100+ 通知，编辑保存和通知卡片均补齐可读 Semantics；关键图标具备 tooltip，状态不只依赖颜色，核心触控目标不小于 48dp。
- Profile 图片选择器在页面销毁后不再上传；地址、商城订单、收藏、我发布 controller 对迟到请求统一失效，新增红灯回归后 Mall controller 18/18 转绿。
- WP-11 专项命令 142/142、`flutter analyze` 和 `git diff --check` 通过；最近一次全量仍为 WP-10 的 376/376，最终全量留 WP-12。
- iPhone 17 Simulator 上完成 402x874 默认字体、accessibility-large 和 874x402 横屏截图人工检查；均非空且无重叠/裁切。精确 844x390 由 Widget 矩阵覆盖；Android 环境无 AVD，个人无线设备未做签名或测试数据操作。
- 下一步进入 WP-12，执行死入口/重复实现审计、全功能链路映射、最终 CodeGraph 同步和完整门禁。

### 2026-07-25：WP-10 商城四入口差异收口

- 复用既有 `MallNavigationCoordinator` 和 Repository，没有复制业务层；生产 Profile 四入口的真实请求路径与返回行为由导航测试固定。
- 订单和我发布商品在快速切换筛选时以 revision 隔离迟到响应，分页按业务 ID 去重；订单取消/确认后刷新，详情返回后也重新加载。
- 地址管理的新增、编辑、设默认和删除成功后均刷新；checkout 选择模式只返回所选地址，不暴露编辑/删除操作。
- 收藏取消增加明确二次确认，服务端成功后才移出列表；无 SKU 商品直接加购 1 件，有 SKU 商品按 D-010 进入统一商品详情完成 SKU/数量选择。
- 我发布商品的“在售”严格对应 RN 的 onShelf/offShelf，发布/编辑返回后刷新，上下架提交期间按商品 ID 禁止重复操作，拒绝原因完整展示。
- CodeGraph 同步为 1625/23901/53144；定向 61/61、全量 376/376、219 文件格式检查、`flutter analyze` 和 `git diff --check` 通过。
- 下一步进入 WP-11，执行视觉、响应式、字体缩放、可访问性、键盘和生命周期专项验收。

### 2026-07-25：WP-09 我的优惠券收口

- 新增完整 UserCoupon/CouponRule/CouponCounts 强类型模型和真实 repository，固定鉴权 `GET /shop/coupons/my?status=...` 与 `/count`；严格解析数字字符串、规则快照、有效期和三状态，不在 UI 本地推断过期状态。
- checkout repository 复用同一 UserCoupon parser 后再适配既有 `CheckoutCoupon` 预览模型；相同服务端 fixture 的券中心与 checkout 解析一致，checkout 优惠金额仍以服务端 `discountAmount` 为准。
- controller 并发加载列表/count，覆盖状态快速切换、首屏 count 竞态、刷新折叠、列表/count 独立错误、最后有效值、ID 去重和 dispose 后迟到响应隔离。
- 页面为只读查看中心，支持可用/已使用/已过期三页签及 count、loading/empty/error/refresh，稳定展示满减/折扣/直减、门槛、范围和有效期；卡片点击不会触发 checkout 选择返回。
- 生产 `ProfilePageFactory` 已接入优惠券页，所有 Profile owned 目标均为真实页面；WP-03 因此完成跨包验收。
- CodeGraph 同步为 1625/23870/53043；定向 53/53、全量 364/364、219 文件格式检查、`flutter analyze` 和 `git diff --check` 通过。
- 下一步进入 WP-10，从四个商城入口的 RN/Flutter 差异、共享 Mall coordinator 影响面和 D-010 收藏 SKU 行为定案开始。

### 2026-07-25：WP-08 通知中心与未读同步收口

- 新增严格 Notification/type/action/page 模型和真实 repository，固定列表、未读数、详情、单条/全部已读 contract；兼容 actionData 的 Map/JSON 字符串和秒/毫秒/ISO 时间，非法关键字段明确失败。
- session 级角标 controller 登录首次拉取、默认 60 秒前台轮询，pause/inactive/hidden 停止，resume 立即校准，logout/dispose 清理；generation 隔离跨账号迟到响应。
- 列表 controller 支持首屏、刷新、分页去重，以及单条/全部已读乐观更新；mutation token 与 revision 防止重复点击、失败回滚覆盖刷新结果或污染服务端校准值。
- 页面覆盖 loading/empty/error/refresh/paging、未读视觉、全部已读提交态与 320/390/768；点击通知须先成功标已读再执行强类型 action，订单委托真实商城详情，外部域/未知/缺字段明确反馈。
- Profile 角标实时监听并按 0 隐藏、1..99 原值、100+ 为 99+；生产 factory、Home 和 App 生命周期使用同一 controller，返回页面后保持一致。
- CodeGraph 同步为 1617/23728/52651；定向 63/63、全量 343/343、format、`flutter analyze` 和 `git diff --check` 通过。
- 下一步进入 WP-09，从 MyCoupons、checkout coupon contract 和状态/过期语义的一致性审计开始。

### 2026-07-25：WP-07 医疗服务订单收口

- 独立新增 MedicalServiceOrder/Doctor/ServiceItem/status/query/page 模型，固定五种已知状态与 unknown fallback；关键 ID、金额、时间和关联对象严格校验，不复用商城订单模型。
- Repository 固定鉴权 `GET /chat/orders`、`page/pageSize` 和 ApiClient 解包后的内层分页 map，不递归猜测响应形状。
- Controller 覆盖首屏、刷新折叠、分页防重复/失败重试、ID 去重和 generation 竞态；刷新会立即释放旧分页占用，迟到响应不得污染新列表。
- 页面覆盖 loading、空态、错误重试、下拉刷新、加载更多、320/390/768 宽度和长医生名；展示订单号、医生、服务、时长、时间、金额、状态，头像统一解析相对资源 URL。
- RN 医疗订单页没有详情交互，Flutter 不臆造详情入口；从生产页面返回仍停留个人中心根页面。
- CodeGraph 为 1606/23496/52059；定向 25/25、全量 306/306、format、`flutter analyze` 和 `git diff --check` 通过。
- 下一步进入 WP-08，从通知 action 支持矩阵、会话级未读轮询和 App 生命周期审计开始。

### 2026-07-25：WP-06 我的宠物收口

- 新增强类型 Pet/category/gender/draft/upload 模型与严格 parser；兼容服务端数字字符串、decimal 字符串、可空分类/头像/生日和未知性别，不虚构后端不存在的通用宠物状态。
- 新增真实 pets repository，固定 `/pets/my`、`/pet-categories/tree`、`/pets/:id` CRUD 和 multipart `file` + `pet-avatar` contract，非法关键响应明确失败。
- 列表 controller 覆盖同轮刷新折叠、分类竞态隔离、最后有效列表、删除去重和编辑结果恰好一次刷新；编辑 controller 覆盖详情/分类并发、全字段校验、保存/删除去重、失败保留草稿和图片取消/失败/成功状态。
- 列表与编辑页追平 RN 核心字段、分类筛选、CRUD、生日/性别/体重/绝育/疫苗和窄屏键盘滚动；“我的走失”属于外部域，显示明确暂未迁移反馈。
- 生产头像选择只开放相册：现有 iOS 仅声明照片库用途，没有相机用途声明；未获得根配置修改授权前不暴露会失败的相机入口。
- 生产 `ProfilePageFactory` 已接入真实宠物页；CodeGraph 为 1598/23381/51737，定向 36/36、全量 288/288、format、`flutter analyze` 和 `git diff --check` 通过。
- 下一步进入 WP-07，从医疗订单 wire contract、分页状态和 RN 列表语义审计开始。

### 2026-07-25：WP-05 系统设置与系统文章收口

- 新增联系配置和系统文章强类型模型、public repository 与独立 controller 状态；缺失配置/文章使用安全空态，contract 漂移仍明确失败。
- 新增真实设置页和 HTML 文章页：联系方式、二维码、电话确认、三类文章、空/错/重试、受限图片/表格和安全链接均有自动化覆盖。
- 在不新增依赖和平台配置的边界内增加 Android/iOS URI MethodChannel，只允许 `http/https/tel`，并把 capability 检查与实际 launch 分离，测试不发起真实外部动作。
- 退出复用 `AuthController.logout()`；注销严格先成功调用 `DELETE /users/me` 再失效本地会话，服务端失败保留认证状态；重复破坏性动作被阻止。
- App 监听认证状态，变为未认证时将 Navigator 清到首路由，验证不能通过返回键恢复受保护页面；生产 factory 已接入真实设置页。
- CodeGraph 同步后 1586 files、23098 nodes、51007 edges；WP-05 定向 41/41、全量 259/259、format、`flutter analyze`、Android Kotlin 编译、iOS Simulator build 和 `git diff --check` 通过。
- 下一步进入 WP-06，从宠物 domain/contract/controller 和列表/编辑页状态测试开始。

### 2026-07-25：WP-04 钱包摘要与我的收益收口

- 新增强类型交易类型/状态/关联类型、分页查询与严格 parser；兼容 `ApiClient` 固定的 `{data,pagination}` 输出，非法关键字段直接抛 `FormatException`。
- 新增 `WalletController`：统计与首屏独立并发，刷新重置分页，加载更多防重复/可重试，筛选用 generation 忽略过期响应，dispose 后不通知。
- 新增真实 `WalletPage`：三项统计、四段筛选、空/错/多页、下拉刷新、RN 金额符号/状态/时间语义、长备注/超大金额/未知枚举稳定显示。
- 合法订单关联以 `OrderRouteArgs` 委托现有 Mall 详情；无效 ID 和详情打开失败均有明确反馈。
- 生产 `ProfilePageFactory` 支持分阶段可空结果，本轮只开放真实钱包页；收益页返回后个人中心重新请求钱包摘要。
- CodeGraph status 1575/22876/50471；WP-04 定向 31/31、全量 235/235、`flutter analyze` 和 `git diff --check` 通过。

### 2026-07-25：WP-03 个人中心主页面与编辑资料实现收口

- 新增 `ProfileController`，并发刷新折叠为单次 Profile/Wallet 请求；两区域独立成功/失败，保留最后有效资料，dispose 后不回写会话或通知。
- 新增完整 `ProfilePage`：真实头像/默认图标、昵称 fallback/省略、0/1/2 性别语义、普通会员、三项钱包、九项 RN 顺序服务、通知 `99+` 和局部重试。
- 新增全屏 `ProfileEditPage`：手机号脱敏只读、unknown/male/female、相册取消/权限/文件丢失/上传失败、上传暂存、差异 patch、保存失败保留输入、无变化关闭。
- 新增 GET `/users/me` 与 GET `/shop/wallet/stats` 固定 contract；钱包字段异常抛错，不用 0 掩盖 contract 漂移。
- `main -> PetHospitalApp -> HomePage` 通过稳定 `ProfileControllerFactory` 接入完整页面；游客不创建 controller。
- CodeGraph 同步后 1571 files、22761 nodes、50224 edges；定向 46/46、全量 218/218、`flutter analyze` 和 `git diff --check` 通过。
- 严格验收下 WP-03 暂为 VERIFYING：钱包真实目标由 WP-04 接入，设置/宠物/医疗/通知/优惠券真实目标由 WP-05 至 WP-09 接入；没有用占位页冒充完成。

### 2026-07-25：WP-02 Profile 导航与依赖组装收口

- 新增九个主入口、钱包、商城订单详情、商城商品详情、无动作和不支持目标的强类型 destination；页面间不传 `Map<String, dynamic>`。
- `ProfileNavigationCoordinator` 将订单、地址、收藏、发布商品和订单详情委托 `MallNavigationCoordinator`，通知 raw action 先经纯函数白名单解析。
- App 根在 `main()` 稳定创建 `ProfileDependencies/ProfileNavigationCoordinator`；`HomePage` 只新增一个可选 navigator，并删除四个 Profile 商城私有转发方法。
- 游客链路由 App -> AuthPage -> HomePage.guest 透传同一 navigator，但账号 Tab gating 在路由前拦截；测试证明不能绕过。
- CodeGraph 同步后为 1562 files、22507 nodes、49651 edges；定向 13/13、全量 195/195、`flutter analyze` 通过。
- Owned page factory 按 D-012 分阶段注入；WP-03 至 WP-09 只有在真实页面 factory 接好后才可视为对应入口最终可交付。
- 下一步进入 WP-03，先建立 ProfileController 与页面多区域状态测试。

### 2026-07-25：WP-01 Profile 基础能力收口

- 新增强类型 `UserProfile`、性别/显示名/手机号/会员/头像 URL 纯映射及保留未知字段的 session patch。
- 新增 `ProfileGateway/ProfileRepository`，固定实现 `PUT /users/me`、multipart `POST /upload/image` 和 `DELETE /users/me`，不猜测额外 envelope。
- `AuthController.updateProfile` 采用 store-first：保存成功后才替换内存并通知；保存失败原样传播且不改变状态。
- CodeGraph 已分析 AuthController/session/ApiClient 影响面并同步新符号；Widget 未直接构造 Profile 请求。
- 定向 17/17、全量 187/187、`flutter analyze` 通过；无依赖或 lockfile 变化。
- WP-02 从 HomePage/App/main/MallNavigationCoordinator 影响分析和强类型导航测试开始。

### 2026-07-25：WP-00 基线审计收口

- CodeGraph 索引最新；完成 RN route/API 与 Flutter auth/home/mall 影响面分析。
- 后端 16 组 endpoint 的 wire/ApiClient 输出已写入验证记录；接受 D-011 endpoint-specific 解包策略。
- RN 定向 8/8、Flutter analyze 和全量 174/174 通过。
- Flutter 三档 before 图已生成并人工检查；RN 原图因当前无隔离认证运行态未重跑，仓库历史 Midscene 日志证明曾真实运行并识别页面结构。
- 下一步完成 `git diff --check` 后进入 WP-01，先对 AuthController 精确 impact 并补会话 patch 测试。

### 2026-07-25：建立长期迁移计划

- 完成 CodeGraph status 和相关语义查询。
- 完成 RN ProfileScreen、服务配置与 Flutter ProfileMallView/HomePage 的初步差异审计。
- 确认现有 Flutter 依赖包含 `image_picker` 和 `flutter_html`。
- 未修改业务代码，未运行 commit/push。
- 下一会话从 WP-00 开始。
