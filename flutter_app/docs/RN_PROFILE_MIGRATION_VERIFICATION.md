# RN Profile -> Flutter 迁移验证记录

> 只记录实际执行的验证和观察。不得预填“通过”。  
> 每条证据包含日期、工作包、命令/步骤、退出码/结果和必要备注。

## 1. 最近绿色基线

### RN 定向基线

- 日期：2026-07-25
- 工作包：WP-00
- 命令：

```bash
cd /Users/wujie/Desktop/code/xuduo/pet-hospitals/rnapp
npm test -- --runInBand tests/profile-edit-avatar-picker.test.tsx src/components/NotificationIcon/index.test.tsx src/screens/Home/components/CouponScannerScreen.test.tsx
```

- 退出码：0。
- 结果：通过，3/3 suites、8/8 tests passed，0 snapshots。
- 说明：覆盖 Profile 编辑头像选择器、通知图标和优惠券扫码相关现有测试；RN 尚无宠物、收益、医疗订单和设置页专用测试。

### Flutter 定向基线

- 日期：2026-07-25
- 工作包：计划前审计
- 命令：

```bash
cd /Users/wujie/Desktop/code/xuduo/pet-hospitals/flutter_app
flutter test test/home_page_test.dart test/mall_pages_responsive_test.dart
```

- 结果：通过，14/14 tests passed。
- 说明：当前 Flutter 没有 ProfileMallView 专用测试；该结果只保护首页和已有商城页面基线。

### Flutter 全量基线

- 日期：2026-07-25
- 工作包：WP-00
- 命令：`flutter analyze`
- 退出码：0；结果：No issues found，约 2.6s。
- 命令：`flutter test`
- 退出码：0；结果：174/174 tests passed，约 12s。
- 环境：Flutter 3.38.5 stable，Dart 3.10.4。

### Flutter 当前绿色基线

- 日期：2026-07-25（目标恢复独立复核）
- 工作包：WP-12
- 命令：`flutter analyze`
- 退出码：0；结果：No issues found，约 2.2s。
- 命令：`flutter test`
- 退出码：0；结果：420/420 tests passed，约 19.7s。
- 功能链路定向：Profile/Auth/Wallet/Settings/Pets/Medical/Notifications/Coupons/Mall/Home/App/Friends 共 43 个测试文件，308/308 passed。
- RN 基线：3/3 suites、8/8 tests passed。
- 说明：本轮在未修改业务代码的前提下独立重跑最终门禁；格式检查 220 files、0 changed。308/308 功能链路结果沿用同日 WP-12 专项记录，全量 420/420 已包含该集合。

## 2. CodeGraph 证据

### 2026-07-25 计划建立

- `codegraph status`：索引 up-to-date，约 1554 files、22286 nodes、49131 edges。
- 已执行与“RN 个人中心完整迁移到 Flutter”相关的语义 context 查询。
- 已通过代码搜索核对 ProfileScreen、profileServices、Flutter ProfileMallView、HomePage、AuthController、MallNavigationCoordinator 和关键 endpoints。
- 备注：首次实际实施仍须对 WP-00 和每个共享符号执行更精确的 callers/callees/impact。

### 2026-07-25 / WP-00

- `codegraph status`：索引 up-to-date，1554 files、22330 nodes、49234 edges。
- RN 查询：`ProfileScreen` 的资料、钱包、头像上传、编辑资料 callees；九个 `profileServices` destination 与 `AppNavigator` 登录门禁；通知轮询和直接子页面 API。
- Flutter 查询：`ProfileMallView`、`HomePage`、`AuthController`、`MallNavigationCoordinator` context/query；对后三个共享符号执行 callers/callees/impact。
- 影响面：`ProfileMallView` 当前仅由 `HomePage` 组合；`AuthController` 影响 app/main、home 和 auth/widget 测试；`MallNavigationCoordinator` 影响 HomePage 路由方法、app/main 和商城响应式测试。
- 限制：CodeGraph 对 JSX import caller 未建立边，RN 页面调用方以 `AppNavigator.tsx` 和 route type 文本核对补充；未将 generic `Destination` 搜索结果误当 profile 路由。

### 2026-07-25 / WP-01

- 查询 `AuthController`、`AuthSession`、`SessionStore.saveSession`、`ApiClient.uploadFile`，并对 session/save/upload 与 `_establishSession` 执行 callers/callees/impact。
- `AuthController.session` 影响 app/main、HomePage 和 auth/home 测试；`SessionStore.saveSession` 影响认证恢复/建立流程；`ApiClient.uploadFile` 修改前无业务 caller。
- 新增实现后 `codegraph sync` 返回 Already up to date；`codegraph query UserProfile` 已索引新领域模型。
- `codegraph impact 'AuthController::updateProfile' -d 3` 返回 auth controller 与 auth 测试共 20 个受影响符号；更宽的 `session/saveSession` 影响链包含 app/main/home，全量测试覆盖两层影响面。
- CodeGraph 无法通过 node id 查询，且 `callees` 不接受 `-d`；已按 CLI help 改用 symbol + `-l`，未静默跳过。

### 2026-07-25 / WP-02

- 修改前对 `HomePage`、`AuthPage`、`PetHospitalApp`、`MallNavigationCoordinator::_open/openOrders` 执行 query/callers/callees/impact，并用 `rg` 补足构造参数和 route args 文本核对。
- `MallNavigationCoordinator::_open` 影响 44 个符号，主要覆盖所有 Mall 公开入口、HomePage 既有路由方法及商城响应式测试；`openOrders` 影响 49 个符号并延伸至 app/main。
- `HomePage` 影响自身和 `home_page_test.dart`；`AuthPage` 影响 App 根；`PetHospitalApp` 影响 main。新增公开参数均保持 optional，现有测试调用方无需批量迁移。
- 新增实现后 `codegraph status` 为 up-to-date：1562 files、22507 nodes、49651 edges；`query ProfileNavigationCoordinator` 已索引九入口方法。
- `callers/callees ProfileNavigationCoordinator::openOrders` 确认公开方法只进入统一 `openDestination`；`impact ProfileNavigator -d 4` 覆盖 coordinator 和 Home widget 测试，没有反向导入或依赖环。

### 2026-07-25 / WP-03

- 修改前对 `ProfileMallView`、`ProfileGateway`、`AuthController::updateProfile`、`ProfileDependencies`、`ProfilePageFactory`、`HomePage` 和 `PetHospitalApp` 执行 query/impact；CodeGraph 对精确 `_buildTabContent` 未命中时用文件阅读和 `rg` 补充，没有静默跳过。
- `ProfileMallView` 只由 `HomePage` 组合；`ProfileDependencies` 直接影响导航协调器/测试；`ProfilePageFactory` 影响 22 个 owned route 符号；`AuthController::updateProfile` 宽影响链延伸至 app/main/auth/home 测试。
- 服务端/RN 查询确认 `/users/me`、`/shop/wallet/stats`、ProfileScreen 钱包/编辑/头像行为和九项服务顺序。
- 实现后 `codegraph sync` 返回 Already up to date；`codegraph status` 为 1571 files、22761 nodes、50224 edges，新增 Dart 文件已计入索引。
- `query "ProfileController profile wallet refresh avatar save"` 未命中复合自然语言；此前具体符号 impact 和实现文件/测试精确阅读已完成语义分析，不将该空结果冒充证据。

### 2026-07-25 / WP-04

- 修改前查询 `WalletSummaryGateway`、`ProfilePageFactory`、`OrderRouteArgs` 和 `loadMore`；`WalletSummaryGateway` 影响 29 个符号，`ProfilePageFactory` 初始影响 8 个符号，确认生产接线和测试是主要共享影响面。
- RN/服务端精确阅读确认四种交易类型、三种状态、`relatedType/relatedId` 订单关联、`page/limit` 请求和顶层分页返回；CodeGraph 对 RN API 复合自然语言查询未命中时以精确文件/符号和 `rg` 补足。
- 实现后 `codegraph sync` 返回 Already up to date；`codegraph status` 为 1575 files、22876 nodes、50471 edges，`query WalletController` 命中新控制器。
- `impact ProfilePageFactory -d 4` 返回 26 个受影响符号，覆盖 production factory、coordinator 和导航测试；全量测试覆盖该 contract 变化。`callers WalletRepository::loadTransactions` 未建立接口动态调用边，已以 `WalletGateway` 实现和 controller contract 测试补证。

### 2026-07-25 / WP-05

- 修改前查询 `AuthController logout`、`ProfileGateway::deleteAccount` 和 `ProfileDependencies::production`；`AuthController` logout 影响 72 个符号，`ProfileGateway::deleteAccount` 深度 5 影响 43 个符号，确认 Auth/App/Profile factory 和测试是主要共享影响面。
- `callers AuthController::invalidateLocalSession -l 4` 确认原实现只由 logout 使用；据此由 SettingsController 复用该本地失效入口，并通过测试固定“服务端删除成功后才失效会话”的顺序。
- 实现后对 `SettingsController::deleteAccount` 和 `PetHospitalApp::_handleAuthStateChanged` 执行 impact，分别覆盖 settings/controller/page 测试与 app/main/widget 导航清栈链路。
- `codegraph sync` 后 `codegraph status` 为 up-to-date：1586 files、23098 nodes、51007 edges；Dart/Kotlin/Swift 新文件与符号已进入索引。

### 2026-07-25 / WP-06

- 修改前查询 RN `PetListScreen/PetEditScreen`、服务端 pets/categories/upload contract、Flutter `ProfilePageFactory` 与生产依赖；对共享 factory/navigation 执行 impact，并用 `rg` 精确核对 JSX route、字段和图片参数。
- 服务端审计确认 Pet entity 没有通用状态字段，列表按 createdAt 倒序，分类树为非分页数组，CRUD 使用标准 envelope，图片 multipart 字段为 `file`、category=`pet-avatar`。
- 实现后执行 `codegraph sync`；`codegraph status` 为 up-to-date：1598 files、23381 nodes、51737 edges，`query PetListController` 命中新控制器。
- CodeGraph 对部分 TypeScript/接口动态 caller 未建立边时，以 RN route/service、Dart gateway 实现、生产 factory 和 contract/navigation 测试补证，没有把空查询当作影响分析结果。

### 2026-07-25 / WP-07

- 修改前查询 RN `MedicalServiceOrderListScreen`、服务端 chat orders controller/service/entity、Flutter `ProfilePageFactory`；`callees MedicalServiceOrderListScreen` 命中 `getMedicalServiceOrdersApi`，确认读取 `page/pageSize` 并由 AppNavigator 注册路由。
- 审计确认 `/chat/orders` 使用 JWT USER、按 createdAt 倒序、关联 doctor/serviceItem，并返回内层 `{data,total,page,pageSize,totalPages}`；RN 页面没有详情点击，医疗订单不能复用商城订单模型。
- 对共享 `ProfilePageFactory` 执行深度 4 impact；修改前影响集中在 production factory、dependencies 和导航测试。CodeGraph 未建立 JSX/interface 动态 caller 边时，以 AppNavigator 文本、gateway 实现和生产导航测试补证。
- 实现后 `codegraph sync` 返回 Already up to date；`codegraph status` 为 1606 files、23496 nodes、52059 edges，`query MedicalOrderController` 命中新控制器；`impact ProfilePageFactory -d 4` 返回 7 个直接结构符号。

### 2026-07-25 / WP-09

- 修改前查询 RN `MyCouponsScreen/CouponListItem`、服务端 coupon controller/service/entity、Flutter checkout coupon flow 和 `ProfilePageFactory`；审计确认列表只支持 `status`、直接返回数组，count 返回 available/used/expired，服务端会归档过期券。
- 对共享 `CheckoutCoupon`、`CheckoutRepository` 和 `ProfilePageFactory` 执行 impact；据此保持 `CheckoutCoupon` 公开形状不变，只把 wire 解析收敛到完整 `UserCoupon` 模型，并用相同 fixture 覆盖两个消费者。
- 实现后执行 `codegraph sync`；`codegraph status` 为 up-to-date：1625 files、23870 nodes、53043 edges，`query CouponCenterController` 命中新控制器。`affected` 未发现 CodeGraph 可直接映射的测试文件，已用明确 contract/controller/page/navigation/checkout 定向集和全量测试补足动态接口边。
- CodeGraph 对通用符号名 `UserCoupon` 给出跨语言噪声结果，未将其作为精确影响证据；共享边界以 Dart import、repository/factory impact、精确代码阅读和测试证明。

### 2026-07-25 / WP-10

- 修改前查询 RN `OrderListScreen`、`AddressListScreen`、`MyFavoritesScreen`、`MyPublishedProductsScreen` 与 Flutter 四入口 controller/page/coordinator，并对 `openOrders/openAddresses/openFavorites/openPublishedProducts` 等共享入口执行影响分析。
- 审计确认四入口继续复用同一 `MallNavigationCoordinator` 和既有 Repository；订单 pageSize=20、收藏 pageSize=20、我发布 pageSize=10，地址同时存在管理模式和 checkout 选择模式。
- 修改后 `codegraph sync` 返回 Already up to date；`codegraph status` 为 1625 files、23901 nodes、53144 edges。`impact OrderListController/OrderListPage/FavoriteController/PublishedProductController -d 3` 覆盖对应实现和 controller/page 测试。
- `impact OrderController` 因名称模糊误命中 MedicalOrderController，未采用该结果；改用精确 `OrderListController` 重跑，未将噪声结果作为证据。coordinator 动态回调边以生产导航和全量测试补足。

### 2026-07-25 / WP-11

- 修改前查询 `ProfilePage responsive semantics avatar wallet service notification badge`，并对 `ProfilePage`、`PetHospitalApp`、`NotificationBadgeController` 执行 impact，覆盖个人中心页面、App 生命周期和会话角标共享边界。
- 当时 `codegraph status` 为 up-to-date：1625 files、23901 nodes、53144 edges；宠物/地址响应式符号查询结果不完整时，以页面精确阅读、六视口红灯测试和生产导航回归补证。
- 一次尝试使用不存在的 `impact --direction` 参数失败，未将该命令作为证据；已采用前述有效的精确 impact 输出。WP-11 新符号的最终 `codegraph sync/status/impact` 留到 WP-12 统一执行。

### 2026-07-25 / WP-12

- 恢复后执行 `codegraph query "ProfilePageFactory destination placeholder legacy profile"`，并对 `ProfilePageFactory`、`ProfileNavigationCoordinator`、`NotificationBadgeController`、`AuthController::updateProfile` 执行最终 impact/callers；生产 factory、App/main/Home、Profile 页面和导航测试构成主要影响面。
- 静态资料消费者审计进一步查询 `FriendsFeatureSession::updateCurrentUserAvatar` 和 `FriendChatController`；前者影响 App 会话组装，后者覆盖当前聊天消息、媒体和语音行为。首轮全量红灯证明该影响面不能只靠 Profile 模块测试。
- 修复后执行两次 `codegraph sync`，均为 Already up to date；最终 `codegraph status`：1626 files、23953 nodes、53334 edges，Dart 220 files。
- `codegraph callers ProfileMallView -l 5` 返回 No callers found；按主计划删除授权边界保留该兼容文件，不把它计作生产入口或重复实现。
- CodeGraph 对接口动态调用边仍以 production factory/navigation、contract 和 full regression 补证；没有把空 caller 当成所有运行时行为的唯一证据。
- 目标恢复独立复核再次执行 `codegraph sync`（Already up to date）、Profile factory/destination query，以及 `ProfilePageFactory`、`AuthController::updateProfile`、`NotificationBadgeController` impact 和 `ProfileMallView` callers；结果仍为 production factory 有完整影响链、旧页面无 caller，索引保持 1626/23953/53334。

## 3. API Contract 审计表

以下同时记录服务端 wire envelope 和 Flutter `ApiClient` 解统一外层后的形状。所有错误由全局 filter 以 HTTP 200 返回 `{success:false, code, statusCode, message, error, validationErrors?, timestamp, path, method}`，客户端必须按 business failure 处理。

| 模块 | 方法/路径 | 已确认请求 | 真实响应 envelope / ApiClient 输出 | Contract 测试 | 状态 |
|---|---|---|---|---|---|
| Profile | GET `/users/me` | JWT，无参数 | wire `{code:0,data:User,...}`；输出 User，含 id/username/email/phone/role/avatar/gender/verified/isActive/timestamps，无积分/会员字段 | `profile_repository_contract_test.dart` | 已验证 |
| Profile | PUT `/users/me` | username，可选 gender=0/1/2、avatar | wire `{code:0,data:User,...}`；输出更新后的 User | `profile_repository_contract_test.dart` | 已验证 |
| Upload | POST `/upload/image` | multipart `file`，category=`user-avatar` | wire `{code:0,data:{url,filename,originalName,size,id,width?,height?,thumbnail?},...}`；输出该 map | `profile_repository_contract_test.dart` | 已验证 |
| Delete account | DELETE `/users/me` | JWT，无 body | 匿名化并停用用户；service 返回 void，wire 为成功 envelope 且 JSON 可省略 data；输出 null | `profile_repository_contract_test.dart` | 已验证 |
| Wallet | GET `/shop/wallet/stats` | JWT，无参数 | controller 返回 `{success:true,data:{available,pending,total}}`，全局 envelope 经 ApiClient 后输出三字段 map | `wallet_repository_contract_test.dart` | 已验证 |
| Wallet | GET `/shop/wallet/transactions` | type/status/page/limit | wire `{code:0,data:[...],pagination:{total,page,pageSize,limit,totalPages}}`；输出 `{data,pagination}` | `wallet_repository_contract_test.dart` | 已验证 |
| Pets | GET `/pets/my` | JWT；可选 categoryId | wire 标准 envelope；输出按 createdAt 倒序的 Pet 数组，含 category/subCategory | `pet_repository_contract_test.dart` | 已验证 |
| Pets | GET `/pet-categories/tree` | JWT，无参数 | wire 标准 envelope；输出非分页分类树数组 | `pet_repository_contract_test.dart` | 已验证 |
| Pets | GET/POST/PUT/DELETE `/pets...` | JWT；name、categoryId、可选 subCategoryId；gender=1/2；birthDate/weight 等 | 读写返回标准 Pet；DELETE soft delete 后 void/null | `pet_repository_contract_test.dart` | 已验证 |
| Upload | POST `/upload/image` | multipart `file`，category=`pet-avatar` | wire 标准上传对象；缺失 URL 视为 contract 错误 | `pet_repository_contract_test.dart` | 已验证 |
| Medical orders | GET `/chat/orders` | JWT；page、pageSize（服务端兼容 limit） | controller 直接返回 `{code:0,data:{data,total,page,pageSize,totalPages}}`；输出内层分页 map | `medical_order_repository_contract_test.dart` | 已验证 |
| Notifications | GET `/notifications` | page、pageSize、可选 type | wire data 为数组，pagination 含 total/page/pageSize/limit/totalPages；输出 `{data,pagination}` | WP-08 fixture | 已审计 |
| Notifications | GET `/notifications/unread-count` | JWT，无参数 | wire 标准 envelope；输出 `{count}` | WP-08 fixture | 已审计 |
| Notifications | PUT `/:id/read`、`/read-all` | id 或无参数 | 输出 `{success:true}` / `{success:true,updatedCount}` | WP-08 fixture | 已审计 |
| Coupons | GET `/shop/coupons/my` | 仅 status 生效；RN 发送的 page/pageSize 被后端忽略 | wire 标准 envelope；输出非分页 UserCoupon 数组 | `coupon_repository_contract_test.dart` | 已验证 |
| Coupons | GET `/shop/coupons/my/count` | JWT，无参数 | 输出 `{available,used,expired}`，调用前会归档过期券 | `coupon_repository_contract_test.dart` | 已验证 |
| Settings | GET `/system-configs/contact_info` | public，无参数，不发送 Authorization | 输出 SystemConfig entity；`configValue={hotline,wechatQrCode,workingHours}`；客户端对 null/缺失配置显示安全空态 | `settings_repository_contract_test.dart` | 已验证 |
| Articles | GET `/system-articles/:type` | public；about_us/privacy/user_agreement；不发送 Authorization | 输出 `{id,type,content,createdAt,updatedAt}` 或 null；content 为 HTML | `settings_repository_contract_test.dart` | 已验证 |

## 4. 工作包验证矩阵

| 工作包 | Unit | Contract | Widget | Navigation | Analyze | Manual | 结论 |
|---|---|---|---|---|---|---|---|
| WP-00 | RN 8/8 | 后端实现审计完成 | Flutter before 3 视口 | 九入口映射完成 | 全量通过 | Flutter 截图 + RN 历史运行日志 | 通过 |
| WP-01 | models 6 + auth 7 | repository 4/4 | N/A；无 Widget 直连 | N/A | 全量通过 | N/A | 通过 |
| WP-02 | parser 3/3 | N/A | Home 7/7 | coordinator 3/3 | 全量通过 | 结构走查完成 | 通过 |
| WP-03 | controller 6/6 | profile/wallet 7/7 | page/edit 13/13 + Home 8/8 | 九入口点击及所有 owned 真实工厂目标 | 全量通过 | 结构走查完成；真实设备留 WP-11 | 通过 |
| WP-04 | controller 4 + time 1 | wallet 5/5 | page 7（含 3 宽度）+ Profile 摘要同步 | production factory + 订单参数 | 全量通过 | 结构走查完成；真实设备留 WP-11 | 通过 |
| WP-05 | controller 6 + launcher 2 | settings 5/5 | settings/article 10（含 3 宽度）+ auth/app 回归 | production factory + 清栈 | 全量通过 | 结构走查完成；真实外部 app 留 WP-11 | 通过 |
| WP-06 | models 6 + controller 11 | pets/upload 5/5 | pages 7（含 3 宽度与键盘） | production factory + 编辑结果刷新 | 全量通过 | 结构走查完成；真实相册留 WP-11 | 通过 |
| WP-07 | models 4 + controller 5 | medical orders 3/3 | page 6（含 3 宽度） | production factory + 返回 Profile 根 | 全量通过 | 结构走查完成；真实数据/头像留 WP-11 | 通过 |
| WP-08 | models 6 + controllers 10 | notifications 4/4 | page 5 + lifecycle 1 + Profile 角标 | production factory + action 委托 | 全量通过 | 结构走查完成；真实通知/生命周期留 WP-11 | 通过 |
| WP-09 | models 5 + controller 6 | coupons 3/3 | page 7（含 3 宽度） | production factory + 只读返回语义 | 全量通过 | 结构走查完成；真实数据/视觉留 WP-11 | 通过 |
| WP-10 | controller/action 7 | 既有 Mall contract 回归 | 四入口新增 6 + 既有响应式 | 四个生产入口真实请求/返回 | 全量通过 | RN/Flutter 结构走查完成；视觉留 WP-11 | 通过 |
| WP-11 | lifecycle/controller 26 | N/A；contract 未改 | 六视口矩阵 + 专项 142/142 | route 返回、App pause/resume、logout 清栈 | 通过 | iOS 默认/超大字体/横屏截图 | 通过 |
| WP-12 | RN 8/8 + Flutter 420/420 | endpoint owner/全 contract 回归 | 功能链路 308/308 | 九入口、返回、logout 清栈 | 通过 | 复用 WP-11 iOS 视觉；真实账号动作受限 | 通过 |

## 5. 标准命令

命令须从 `flutter_app` 执行；若工程实际脚本有变化，以仓库配置为准并更新本节。

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

定向命令示例：

```bash
flutter test test/profile_models_test.dart
flutter test test/profile_repository_contract_test.dart
flutter test test/auth_controller_test.dart
flutter test test/profile_page_test.dart
```

不要在文件尚不存在时机械执行示例；每个工作包按实际新增测试更新命令。

## 6. 视觉验证记录

| 日期 | 工作包 | 页面/状态 | 视口/设备 | 截图路径 | 结果/问题 |
|---|---|---|---|---|---|
| 2026-07-25 | WP-00 | Flutter 迁移前个人中心 | 320x568 | `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp00/flutter_profile_before_320x568.png` | 非空、无溢出；四入口和退出按钮紧凑可见；headless 缺中文字体回退 |
| 2026-07-25 | WP-00 | Flutter 迁移前个人中心 | 390x844 | `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp00/flutter_profile_before_390x844.png` | 非空、无重叠/裁切；下半屏空白明显；headless 缺中文字体回退 |
| 2026-07-25 | WP-00 | Flutter 迁移前个人中心 | 402x874 | `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp00/flutter_profile_before_402x874.png` | 非空、无重叠/裁切；headless 缺中文字体回退 |
| 2026-03-31（历史证据，2026-07-25 复核） | WP-00 | RN 个人中心有数据、系统设置 loading/内容 | Android 630x1400 | `rnapp/midscene_run/log/ai-call.log`、`rnapp/midscene_run/log/android-device.log` | 日志证明真实设备截图曾生成并由视觉检查识别个人中心资料/钱包/九入口及设置页；原始临时 PNG 已被运行器删除，不能作为像素基线 |
| 2026-07-25 | WP-11 | Flutter 个人中心有数据，默认字体 | iPhone 17 Simulator / iOS 26.5 / 402x874 | `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp11/profile_ios_402x874_default.png` | 使用真实生产 ProfilePage/Controller 和隔离 fake gateway；中文清晰，资料、钱包和服务区无重叠/裁切 |
| 2026-07-25 | WP-11 | Flutter 个人中心有数据，accessibility-large | iPhone 17 Simulator / iOS 26.5 / 402x874 | `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp11/profile_ios_402x874_accessibility_large.png` | 超大字体下昵称、余额和服务文字无重叠/裁切，页面可继续滚动 |
| 2026-07-25 | WP-11 | Flutter 个人中心有数据，横屏 | iPhone 17 Simulator / iOS 26.5 / 874x402；Widget 精确覆盖 844x390 | `/Users/wujie/.codex/visualizations/2026/07/24/019f9520-90a2-7b81-b83a-0153c5ac318f/wp11/profile_ios_simulator_landscape_874x402.png` | 帧缓冲旋转校正后人工检查非空，资料、钱包和服务首行无重叠/裁切且可滚动 |

Flutter 截图 SHA-256：320=`6b7d33d67db42bec9cfec6fca95af1d21f3e48cc63d18a1d5369a10314511aff`；390=`e709ca3981d34cbfd2f3e103873d048582d043ee64b39bb7be7e032206e9c45f`；402=`5560998882309ebbd9e7b202f37518cd346797f7afec7b353e95c149e49ede5f`。

当前 RN 截图限制：本轮 booted iOS Simulator 仅安装 bundle id `com.gude.cwyy` 的 Flutter app，没有 RN app/可复用认证态；RN 与 Flutter bundle id 相同，直接安装会覆盖现有模拟器 app 数据，且没有测试账号权限。按“在可运行的 RN 环境”条件未重跑截图，不用 mock 或重绘图冒充真实 RN 截图。若后续获得隔离 RN 运行态，再补原始 PNG。

截图应放在不污染产品 assets 的测试证据目录；若不提交截图，仍记录绝对路径和观察结果。

## 7. 人工走查记录

| 日期 | 工作包 | 场景 | 环境 | 结果 | 备注 |
|---|---|---|---|---|---|
| 2026-07-25 | WP-12 | 登录到九入口 | Widget + production factory/fake HTTP | 通过 | 九入口、六 owned 真实页面、四 Mall 委托及返回 Profile Tab 均由导航/Home 测试覆盖；未使用真实账号 |
| 2026-07-25 | WP-12 | 编辑资料并重启恢复 | Controller + SessionStore tests | 通过 | 更新、持久化恢复、失败回滚、好友活动聊天最新头像均通过；未操作真实相册权限 |
| 2026-07-25 | WP-12 | logout 栈清理 | App Widget test | 通过 | 会话失效后 pop 到根且返回键不能恢复受保护页；未注销生产账号 |

## 8. 已知验证缺口

- 当前没有可认证且不覆盖 Flutter 模拟器数据的 RN 运行态；历史 Midscene 日志可证明页面结构，但原始 RN PNG 未保留。
- WP-00 headless Flutter 截图缺少中文字体 fallback，只用于迁移前布局基线；WP-11 已用真实 iOS Simulator 补齐迁移后中文、默认字体、超大字体和横屏证据。
- RN 尚无宠物、收益、医疗订单和设置页专用自动化测试；迁移行为由后端 contract fixture 和 Flutter 新测试保护。
- WP-03 编辑页有 Widget/controller 回归，Profile 主页面有真实 iOS 字形证据；真实 image_picker 权限弹窗和进程重启后的持久化仍因缺少隔离测试账号/设备数据未做端到端操作。
- WP-05 已接入真实设置页并完成 Android/iOS 编译；自动化验证 URI 白名单、确认和失败反馈，但未发起真实拨号/浏览器外部动作。
- WP-06 宠物 CRUD 有 model/contract/controller/page/navigation 和六视口证据；真实设备相册权限及服务端上传未操作。现有 iOS 未声明相机用途，生产 UI 依 D-018 不暴露相机入口。
- WP-07 至 WP-10 的真实服务端数据、网络图片及破坏性/外部动作未在个人设备执行；contract fixture、controller、生产导航和响应式矩阵作为可重复证据。
- 当前 `flutter emulators` 无 Android AVD；发现的无线 iPhone 属于个人设备，未获签名、账号及测试数据隔离授权，因此 WP-11 只形成 iOS Simulator 视觉证据，不声称 Android/真机人工通过。
- WP-03 的钱包及所有 owned 目标已由 WP-04 至 WP-09 接入真实生产 factory，跨包验收完成。
- WP-12 已以 production factory、fake HTTP、contract/controller/Widget/navigation/lifecycle 测试完成可重复功能走查；真实服务端与个人设备操作仍受账号、签名和数据隔离条件限制。该限制不影响自动化 contract 与导航结论，但不能外推为生产环境端到端已人工通过。

## 9. 工作包验证记录

### 2026-07-25 / WP-12 / 目标恢复独立复核

- 范围：完整恢复四份执行文档，重新执行 CodeGraph、生产入口/死入口/endpoint 归属审计和最终自动化门禁；业务代码未修改。
- CodeGraph：`codegraph sync` 退出码 0、Already up to date；生产六个 owned 目标由穷举 factory 构建，四个 Mall 目标统一委托；`ProfileMallView` 仍无 caller。
- 静态审计：Profile owned 模块没有 `pushNamed` 或动态字符串路由；API 路径只命中相应 data repository（既有 chat/friends 独立 data uploader 除外）；可空 factory 的不可用提示不是 production 正常路径。
- 格式：`dart format --output=none --set-exit-if-changed lib test` 退出码 0，220 files、0 changed。
- 静态分析：`flutter analyze` 退出码 0，No issues found，约 2.2s。
- Flutter 全量：`flutter test` 退出码 0，420/420 passed，约 19.7s。
- RN 基线：既有三文件 Jest 命令退出码 0，3/3 suites、8/8 tests、0 snapshots。
- 结构检查：首次 `git diff --check` 因本轮新写进度元数据行末空格退出码 2；移除该空格后复跑退出码 0。根配置差异检查无输出，CodeGraph 仍为 up-to-date。
- 结论：当前工作区仍满足 WP-00 至 WP-12 的计划内交付标准，无 blocker；真实服务端、相册权限、外部 App 与破坏性账号动作的设备边界保持不变。

### 2026-07-25 / WP-12 / 全量回归、缺口审计与交付

- 变更范围：最终 CodeGraph/死入口/重复实现/资料消费者审计，修复 `FriendChatController` 初始化前头像通知窗口，并更新三份外部记忆；Repository 和 API contract 未改。
- 首轮红灯：`flutter test` 退出码 1，419 passed、1 failed；失败为 `friends_messaging_controller_test.dart` 的“资料更新后活动聊天立即使用最新用户头像”，期望 1 次通知、实际 0。定向单测可稳定复现。
- 根因与修复：聊天 controller 原在异步 `initialize()` 内才订阅消息 controller；改为构造完成即监听，未初始化时只通知最新头像，初始化后继续异步重载消息，dispose 仍移除监听。
- 修复定向：消息、好友关系、媒体/语音 Widget 和 App 清栈共 26/26 passed。一次组合命令误含仓库不存在的 `test/friend_chat_page_test.dart`，退出码 1；移除无效路径后的真实定向集退出码 0，未把误命令记作绿灯。
- 功能链路：覆盖 Auth/Profile/Wallet/Settings/Pets/Medical/Notifications/Coupons/Mall/Home/App/Friends 的 43 文件命令退出码 0，308/308 passed。
- 全量：`flutter test` 退出码 0，420/420 passed，约 26s；`flutter analyze` 退出码 0，No issues found，约 2.0s；`dart format --output=none --set-exit-if-changed lib test` 退出码 0，220 files、0 changed。
- RN 复核：既有三项个人中心相关 Jest 命令退出码 0，3/3 suites、8/8 tests、0 snapshots。
- 静态审计：presentation 无 `ApiClient`，Profile 无 `pushNamed`/动态 route/`Map<String,dynamic>`；endpoint 搜索只命中对应 data repository；生产 factory 穷举六 owned 目标并委托四个 Mall 目标；旧 `ProfileMallView` 无 caller，按计划授权边界保留；不可用提示只存在于可空测试/防御分支，production factory 测试证明不是正常用户路径。
- 结构与配置：CodeGraph 最终 1626/23953/53334，up-to-date；`pubspec.yaml`、`pubspec.lock`、AndroidManifest.xml、Info.plist 无差异；未修改后端或 API contract，因此无需更新 `admin/API_DOCUMENT.md`。
- 人工边界：复用 WP-11 的 iOS Simulator 默认/大字体/横屏视觉证据；无 Android AVD、隔离真实账号或获授权个人设备，因此真实数据、相册权限、外部 App、注销动作不声称人工通过。自动化以 fake/contract 覆盖成功、失败、取消和清栈路径。
- 最终 `git diff --check`：目标恢复复核文档写回后执行，退出码 0。
- 结论：WP-00 至 WP-12 的计划内入口、状态、导航、生命周期、自动化和审计证据均已满足；无 blocker，未 commit/push。

### 2026-07-25 / WP-11 / 视觉、响应式、可访问性与生命周期

- 变更范围：Profile/通知/pet/address 页面可访问性和窄屏布局，Profile 及四类 Mall controller 生命周期，统一视口支持和 12 份页面/controller 测试；Repository 与 API contract 未改。
- 红灯阶段：六视口矩阵捕获宠物元信息 4.7px、地址联系人 29px 溢出；新增销毁测试捕获四类 Mall controller 的 `ChangeNotifier was used after being disposed`，Profile 图片选择器测试捕获销毁后仍触发上传。修复后对应红灯全部转绿。
- 视口矩阵：320x568、390x844、402x874、320x568@1.3、390x844@1.5、844x390；Profile、编辑、钱包、设置、文章、宠物、医疗订单、通知、优惠券及四个 Mall 入口均纳入。
- 定向命令：`flutter test test/profile_page_test.dart test/profile_edit_test.dart test/profile_controller_test.dart test/wallet_page_test.dart test/settings_page_test.dart test/system_article_page_test.dart test/pet_pages_test.dart test/medical_order_page_test.dart test/notification_page_test.dart test/notification_app_lifecycle_test.dart test/coupon_center_page_test.dart test/mall_controller_test.dart test/mall_pages_responsive_test.dart test/widget_test.dart`。
- 定向结果：退出码 0，142/142 passed；另有 pet + Mall 响应式修复集 29/29、Mall controller 18/18、Profile controller 7/7 的分步绿灯证据。
- 静态分析：`flutter analyze` 退出码 0，No issues found，约 2.7s；`git diff --check` 退出码 0。
- 人工视觉：iPhone 17 Simulator 默认 402x874、accessibility-large 402x874、横屏 874x402 三张截图已逐张检查；非空、中文可见，无重叠/裁切并可滚动。精确 844x390 由 Widget 测试覆盖。
- 设备边界：`flutter emulators` 无 Android AVD；无线个人 iPhone 未做签名/账号/数据操作。截图 harness 位于外部 visualizations 目录，只复用真实生产页面并注入静态数据，没有改产品路由或 assets。
- API 文档：未修改 Repository、后端接口或 contract，因此无需更新 `admin/API_DOCUMENT.md`。
- 剩余风险：真实服务端数据、相册权限、外部 app 和破坏性动作未在个人设备执行；WP-12 将完成全量自动化、死入口审计和逐项交付映射。

### 2026-07-25 / WP-10 / 商城四入口差异收口

- 变更范围：商城订单/收藏/我发布商品 controllers 与 pages，以及 Mall controller/page、Profile production navigation 测试；地址实现未改，新增既有行为证据。
- 红灯阶段：新测试依次捕获订单旧筛选响应覆盖新筛选、收藏分页重复 ID、我发布商品旧筛选响应覆盖新筛选、订单详情返回不刷新和取消收藏无确认五类缺陷；实现修复后全部转绿。
- 定向命令：`flutter test test/mall_controller_test.dart test/mall_page_test.dart test/mall_pages_responsive_test.dart test/mall_repository_contract_test.dart test/mall_repository_test.dart test/mall_rich_text_test.dart test/payment_controller_test.dart test/profile_navigation_test.dart`。
- 定向结果：退出码 0，61/61 passed；覆盖订单/发布筛选竞态和分页去重、订单动作/详情返回刷新、地址 CRUD/选择模式、收藏确认/SKU 分流、发布/编辑返回刷新、上下架防重复、拒绝原因和四个生产入口。
- 静态分析：`flutter analyze` 退出码 0，No issues found，约 2.6s。
- 格式检查：`dart format --output=none --set-exit-if-changed lib test` 退出码 0，219 files checked，0 changed。
- 全量命令：`flutter test`；退出码 0，376/376 passed。
- 结构检查：`git diff --check` 退出码 0；CodeGraph up-to-date，1625/23901/53144；精确 controller/page impact 与生产导航回归覆盖共享边界。
- API 文档：未修改 Repository、后端接口或 contract，因此无需更新 `admin/API_DOCUMENT.md`。
- 剩余风险：部分既有 Mall controller 尚未统一 dispose 后迟到响应保护，纳入 WP-11 生命周期专项；真实数据、中文视觉、字体缩放和触控体感留 WP-11/12。

### 2026-07-25 / WP-09 / 我的优惠券

- 变更范围：Coupon domain/repository/controller/page、checkout repository 共享 parser 适配、Profile production factory 和六份相关测试。
- 红灯阶段：先新增 model/repository/controller/page 与 production navigation 测试，因 `features/coupons` 尚不存在且生产优惠券目标不可达退出 1；实现后新增竞态用例捕获“首屏 count 未完成时切换状态复用旧统计请求”的问题，改为新状态独立拉取并隔离旧响应后转绿。
- 定向命令：`flutter test test/coupon_models_test.dart test/coupon_repository_contract_test.dart test/coupon_center_controller_test.dart test/coupon_center_page_test.dart test/profile_navigation_test.dart test/mall_repository_contract_test.dart test/mall_controller_test.dart test/mall_pages_responsive_test.dart`。
- 定向结果：退出码 0，53/53 passed；覆盖完整规则快照、同 fixture checkout 一致性、三状态/count、非分页 contract、时间边界、状态/统计竞态、刷新折叠、独立错误、320/390/768、长名称/无门槛/三券型、只读点击和生产 factory。
- 静态分析：`flutter analyze` 退出码 0，No issues found，约 2.1s；实现过程中曾发现 production factory sealed switch 的不可达默认分支，移除后复跑通过。
- 格式检查：`dart format --output=none --set-exit-if-changed lib test` 退出码 0，219 files checked，0 changed。
- 全量命令：`flutter test`；退出码 0，364/364 passed，约 21s。
- 结构检查：`git diff --check` 退出码 0；CodeGraph up-to-date，1625/23870/53043；共享 checkout/factory impact 与动态接口边的定向/full regression 已覆盖；未修改依赖、lockfile、平台根配置、后端或 `admin/API_DOCUMENT.md`。
- API 文档：后端接口与 contract 未修改，现有 `admin/API_DOCUMENT.md` 已包含两个优惠券 endpoint，因此本轮无需更新。
- 剩余风险：真实服务端券数据、中文字体和卡片视觉留 WP-11/12；列表 API 不支持分页，客户端未伪造分页；checkout 最终优惠金额继续信任服务端预览值。

### 2026-07-25 / WP-08 / 通知中心与未读同步

- 变更范围：Notification domain/repository/list+badge controllers/page、Profile 实时角标、生产 factory、Home/App 生命周期和八份相关测试。
- 红灯阶段：先新增 model/repository/controller/page/lifecycle 测试，因 `features/notifications` 尚不存在及生产目标不可达退出 1；随后由竞态测试捕获重复点击误判、账号切换仍复用旧请求、刷新期间 mutation 失败导致角标不回滚三个缺陷并修复。
- 定向命令：`flutter test test/notification_models_test.dart test/notification_repository_contract_test.dart test/notification_badge_controller_test.dart test/notification_controller_test.dart test/notification_page_test.dart test/notification_app_lifecycle_test.dart test/profile_page_test.dart test/profile_navigation_test.dart test/home_page_test.dart test/widget_test.dart`。
- 定向结果：退出码 0，63/63 passed；覆盖 actionData Map/JSON、时间格式、五个 endpoint、60 秒可注入轮询、pause/resume/dispose、跨账号迟到响应、分页/刷新、单条/全部已读乐观回滚、重复点击、320/390/768、角标阈值和生产 action 委托。
- 静态分析：`flutter analyze` 退出码 0，No issues found。
- 格式检查：`dart format --output=none --set-exit-if-changed lib test` 退出码 0，211 files checked，0 changed。
- 全量命令：`flutter test`；退出码 0，343/343 passed，约 21s。
- 结构检查：`git diff --check` 退出码 0；CodeGraph up-to-date，1617/23728/52651；depth 3 impact 覆盖 62 个关联符号；未修改依赖、lockfile、平台根配置、后端或 `admin/API_DOCUMENT.md`。
- API 文档：后端接口与 contract 未修改，因此本轮无需更新 admin API 文档。
- 剩余风险：真实服务端新通知、后台/前台计时器调度、网络图片和中文字体视觉留 WP-11/12；预约、任意 page path 和 url 仍按 D-002 的外部域矩阵明确反馈，不伪造页面。

### 2026-07-25 / WP-07 / 医疗服务订单

- 变更范围：Medical order domain/repository/controller/page、Profile production factory 和五份相关测试。
- 红灯阶段：先新增 model/repository/controller/page 测试，因 `features/medical_orders` 不存在退出 1；生产 factory 测试同时因医疗订单目标页不可达失败，确认测试约束了实现和接线边界。
- 定向命令：`flutter test test/medical_order_models_test.dart test/medical_order_repository_contract_test.dart test/medical_order_controller_test.dart test/medical_order_page_test.dart test/profile_navigation_test.dart`。
- 定向结果：退出码 0，25/25 passed；覆盖五种状态与 unknown、严格分页 contract、首屏/刷新/空错态、分页去重/失败重试/迟到响应、刷新释放旧分页、320/390/768、长医生名、空/失败头像、金额和生产返回行为。
- 静态分析：`flutter analyze` 退出码 0，No issues found，约 2.6s。
- 格式检查：`dart format --output=none --set-exit-if-changed lib test` 退出码 0，200 files checked，0 changed。
- 全量命令：`flutter test`；退出码 0，306/306 passed，约 18s。
- 结构检查：`git diff --check` 退出码 0；CodeGraph up-to-date，1606/23496/52059；未修改依赖、lockfile、平台根配置、后端或 `admin/API_DOCUMENT.md`。
- API 文档：后端接口与 contract 未修改，因此本轮无需更新 admin API 文档。
- 剩余风险：真实服务端数据、网络头像、中文字体和滚动体感留 WP-11/12；RN 无详情入口，依 D-019 保持只读不构成交付缺口。

### 2026-07-25 / WP-06 / 我的宠物

- 变更范围：Pet domain/repository/list+edit controllers/pages、编辑结果 contract、Profile production factory 和六份相关测试。
- 红灯阶段：先新增 pet model/repository 测试，因领域与 data 文件不存在退出 1；再新增 list/edit controller 和 page 测试，分别因目标文件不存在退出 1，确认测试能够约束待实现边界。
- 定向命令：`flutter test test/pet_models_test.dart test/pet_repository_contract_test.dart test/pet_list_controller_test.dart test/pet_edit_controller_test.dart test/pet_pages_test.dart test/profile_navigation_test.dart`。
- 定向结果：退出码 0，36/36 passed；覆盖严格/兼容解析、完整 CRUD/upload contract、刷新折叠、分类竞态、删除去重、失败保留、全字段校验、图片状态、320/390/402、键盘滚动、外部域反馈和生产 factory。
- 静态分析：`flutter analyze` 退出码 0，No issues found。
- 格式检查：`dart format --output=none --set-exit-if-changed lib test` 退出码 0，192 files checked，0 changed。
- 全量命令：`flutter test`；退出码 0，288/288 passed，约 19s。
- 结构检查：`git diff --check` 退出码 0；CodeGraph up-to-date，1598/23381/51737；未修改依赖、lockfile、Manifest、Info.plist、根配置、后端或 `admin/API_DOCUMENT.md`。
- API 文档：后端接口与 contract 未修改，因此本轮无需更新 admin API 文档。
- 剩余风险：真实设备相册权限、服务端真实图片/分类数据和中文视觉留 WP-11/12；相机入口依 D-018 暂不提供，不影响 RN 当前宠物页等价范围。

### 2026-07-25 / WP-05 / 系统设置、系统文章与会话失效

- 变更范围：Settings domain/repository/controller/pages、安全 URI launcher 与 Android/iOS channel、Profile production factory、App 认证失效清栈及相关测试。
- 红灯与实现：先建立 settings repository/controller/page/article/launcher contract；页面与生产接线完成后，新增受保护路由测试真实暴露未认证后 pushed route 仍留栈的问题，App 根增加认证监听和 `popUntil(route.isFirst)` 后转绿。
- 定向命令：`flutter test test/auth_controller_test.dart test/external_uri_launcher_test.dart test/settings_repository_contract_test.dart test/settings_controller_test.dart test/settings_page_test.dart test/system_article_page_test.dart test/profile_navigation_test.dart test/widget_test.dart`。
- 定向结果：退出码 0，41/41 passed；覆盖 public 请求无 token、null/非法 contract、独立状态与重试、三档宽度、二维码空态/预览、电话确认、HTML 图片/表格/链接、退出/注销顺序、失败保留、重复操作、生产 factory 和路由清栈。
- 静态分析：首次 `flutter analyze` 发现测试 fake 一个未使用可选参数，修正后复跑退出码 0，No issues found。
- 格式检查：`dart format --output=none --set-exit-if-changed lib test` 退出码 0，180 files checked，0 changed。
- 原生验证：`./gradlew :app:compileDebugKotlin` 退出码 0，BUILD SUCCESSFUL；`xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` 退出码 0，BUILD SUCCEEDED。仅有既有 Gradle/dependency deprecation、Pods deployment target 和 script phase 警告。
- 全量命令：`flutter test`；退出码 0，259/259 passed，约 17s。
- 结构检查：`git diff --check` 退出码 0；`codegraph status` 为 up-to-date，1586/23098/51007；`pubspec.yaml`、`pubspec.lock`、AndroidManifest.xml、Info.plist 和 `admin/API_DOCUMENT.md` 均无本轮差异。
- 安全边界：测试使用 fake launcher 和 fake gateway，没有拨打真实电话、打开真实 URL 或注销真实账号；后端接口未改，因此无需更新 admin API 文档。
- 剩余风险：真实设备外部 app 跳转、iOS/Android URI 可见性和 HTML/二维码视觉留 WP-11/12；如需平台配置调整，须先取得根配置修改授权。

### 2026-07-25 / WP-04 / 钱包摘要与我的收益

- 变更范围：Wallet domain/repository/controller/page、Profile production factory/coordinator，以及 wallet/profile 三层测试。
- 红灯阶段：新增 `wallet_controller_test.dart` 与扩展 contract 测试后，因缺少 `WalletGateway`、交易分页模型和 `wallet_controller.dart` 无法编译；实现领域/data/controller 后定向 9/9 通过。
- 页面定向：`flutter test test/wallet_repository_contract_test.dart test/wallet_controller_test.dart test/wallet_page_test.dart`；首次实现 16/16 通过，补生产路由和摘要同步后五文件 30/30 通过，补金额符号/筛选断言后最终定向 31/31 通过。
- 静态分析：`flutter analyze` 退出码 0，No issues found；过程中仅出现两处 `use_null_aware_elements` info，按仓库 Dart 新语法修正后清零。
- 全量命令：`flutter test`；退出码 0，235/235 passed，约 15s。
- 结构检查：`git diff --check` 退出码 0；`codegraph status` 为 1575/22876/50471；未修改依赖、lockfile、根配置、后端或 API 文档。
- 覆盖：真实 envelope/token/query、严格金额/ID/时间、unknown enum、统计/流水并发隔离、刷新重置、分页防重复与失败重试、筛选竞态、320/390/402、空/错/多页、正负号、长备注/超大金额、合法/无效/删除订单反馈、生产 factory 和首页摘要返回同步。
- 剩余风险：真实设备中文字体与网络/订单详情视觉留 WP-11/12；当前无交易审核操作 API，因此“交易动作后刷新统计”无适用动作。

### 2026-07-25 / WP-03 / 个人中心主页面与编辑资料

- 变更范围：Profile GET/domain/controller/page/edit、Wallet stats domain/repository、Profile dependencies、Home/App/main 工厂装配和 7 份相关测试。
- controller 红灯命令：`flutter test test/profile_controller_test.dart`
- 红灯退出码：1；缺少 `profile_controller.dart`、`wallet_models.dart` 和新增状态类型，测试按预期无法编译。
- Widget 红灯命令：`flutter test test/profile_page_test.dart test/profile_edit_test.dart`
- 红灯退出码：1；缺少 `ProfilePage/ProfileEditPage`，两份测试按预期无法编译。
- 首次 Widget 实现复跑：生产行为通过，两个测试夹具失败；一处昵称 hint 与 error 同文案导致数量断言过窄，一处同测试替换 `MaterialApp` 时旧 Navigator route 未清除。修正测试隔离后复跑通过。
- 定向命令：`flutter test test/profile_models_test.dart test/profile_repository_contract_test.dart test/wallet_repository_contract_test.dart test/profile_controller_test.dart test/profile_navigation_test.dart test/profile_page_test.dart test/profile_edit_test.dart test/home_page_test.dart`
- 定向结果：退出码 0，46/46 passed。
- 静态分析：首次 `flutter analyze` 退出码 1，仅有 `HomePage` 一处 `unnecessary_non_null_assertion`；移除后复跑退出码 0，No issues found。
- 全量命令：`flutter test`；退出码 0，218/218 passed，约 14s。
- 结构检查：`git diff --check` 退出码 0；`codegraph sync` 已是最新，status 1571/22761/50224。
- 覆盖：并发刷新折叠、资料/钱包局部失败、最后有效值、上传取消/权限映射/文件丢失/失败/重复、差异保存、session store-first、dispose、九项顺序/点击、99+、320/390/402 无 overflow、首页完整页面和游客 gating。
- 剩余风险：真实设备相册权限和字体视觉留 WP-11/12；钱包及五个 owned 服务的生产真实页面由 WP-04 至 WP-09 接入，因此 WP-03 暂为 VERIFYING。

### 2026-07-25 / WP-02 / Profile 强类型导航与根组装

- 变更范围：Profile navigation 三文件、Mall 公开订单详情入口、Home/Auth/App/main 依赖透传、导航与 Home Widget 测试。
- 红灯命令：`flutter test test/profile_navigation_test.dart test/home_page_test.dart`
- 红灯退出码：1；缺少 Profile navigation 文件和 `HomePage.profileNavigation`，两份测试按预期无法编译。
- 首次实现复跑：先因 `RequestMallLogin` 未直接导入而编译失败；补显式 import 后 12 条通过、1 条测试夹具失败。夹具目标页缺少 `AppBar`，`tester.pageBack()` 无返回按钮；补标准返回栏后复跑。
- 绿灯命令：`flutter test test/profile_navigation_test.dart test/home_page_test.dart`
- 绿灯退出码：0；13/13 passed。其中 parser 3 条、coordinator/navigation 3 条，HomePage 累计 7 条。
- 全量命令：`flutter analyze`、`flutter test`。
- 全量结果：退出码均为 0；No issues found；195/195 passed。
- 结构检查：`rg` 确认 Profile navigation 无 `Map<String, dynamic>`；HomePage 原四个 Profile Mall 私有转发方法已删除；`git diff --check` 通过。
- 根组装：`main()` 在 `runApp` 前创建 profile dependencies/coordinator；App/Auth/Home 只透传同一实例，build 内没有重建 repository/coordinator。
- 剩余风险：owned page factory 要由 WP-03 至 WP-09 的真实页面逐步注入；按 D-012，最终验收前不可让 factory 缺失反馈成为正常用户路径。

### 2026-07-25 / WP-01 / Profile 模型、Repository 与 session 原子更新

- 变更范围：Profile domain/data、AuthController session patch、三份测试及外部记忆。
- 红灯命令：`flutter test test/profile_models_test.dart test/profile_repository_contract_test.dart test/auth_controller_test.dart`
- 红灯退出码：1；缺少 Profile 文件和 `AuthController.updateProfile`，三份测试均按预期无法编译。
- 绿灯命令：同上。
- 绿灯退出码：0；17/17 passed（models 6、repository 4、auth controller 7）。
- 全量命令：`flutter analyze`、`flutter test`。
- 全量结果：退出码均为 0；No issues found；187/187 passed。
- 结构检查：`rg -n "(/users/me|/upload/image)" lib --glob '*.dart'` 显示 Profile 路径只由 `ProfileRepository` 构造；其他 `/upload/image` 使用者均为既有 data repository/uploader，没有 Widget 直连。
- 工作区检查：`git diff -- flutter_app/pubspec.yaml flutter_app/pubspec.lock` 无输出；未新增依赖或 lockfile 变化。
- 失败策略：store 保存失败的测试证明内存 session 保持同一对象、store 保持旧值、监听器不通知；错误向调用方传播。
- 剩余风险：真实设备上的编辑资料与头像选取/裁剪属于 WP-03；WP-01 仅交付可复用模型、contract 和 session 状态闭环。

## 10. 验证记录模板

```markdown
### YYYY-MM-DD / WP-XX / 简短标题

- 变更范围：
- 命令：`...`
- 退出码：
- 测试结果：
- 失败详情：
- 修复后复跑：
- 剩余风险：
```
