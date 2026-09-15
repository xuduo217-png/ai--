# RN Profile -> Flutter 迁移决策记录

> 记录会影响多个工作包或后续会话理解的决定。  
> 状态：`Proposed`、`Accepted`、`Superseded`、`Rejected`。  
> 修改 Accepted 决策时，不覆盖旧内容；新增一条 Superseded 关系。
> 最近复核：2026-07-25；目标恢复独立复核未发现需要新增、变更或替代的长期决策。

## 决策索引

| ID | 状态 | 决策 |
|---|---|---|
| D-001 | Accepted | RN 当前实际行为是业务基线，Flutter 采用原生架构实现 |
| D-002 | Accepted | 个人中心主计划限定直接拥有页面，跨域目标按支持矩阵闭环 |
| D-003 | Accepted | 使用 ProfileNavigationCoordinator 统一九入口导航 |
| D-004 | Accepted | 通过 AuthController 单一入口 store-first 更新并持久化资料 |
| D-005 | Accepted | 钱包局部请求失败不伪装为 0 元 |
| D-006 | Accepted | 不实现 RN 尚为 TODO 的头像大图查看器 |
| D-007 | Accepted | 优先使用现有 image_picker 和 flutter_html，不新增依赖 |
| D-008 | Accepted | 通知未读轮询为登录会话级 controller，默认 60 秒 |
| D-009 | Accepted | 会员等级默认普通会员，不迁移虚构积分算法数据源 |
| D-010 | Accepted | 收藏商品有 SKU 时进入统一商品详情完成规格与数量选择 |
| D-011 | Accepted | Repository 按已审计 endpoint 解包，不递归猜测响应层级 |
| D-012 | Accepted | Owned page factory 随工作包分阶段注入，最终交付前不得保留不可用入口 |
| D-013 | Accepted | Profile 刷新局部隔离，头像上传结果只在编辑草稿中暂存 |
| D-014 | Accepted | 钱包金额展示由交易类型决定符号，分页筛选使用代次隔离 |
| D-015 | Accepted | 系统文章使用结构化 HTML 渲染，外部 URI 采用双层白名单 MethodChannel |
| D-016 | Accepted | 注销先确认服务端成功再清本地会话，所有失效路径统一清受保护路由栈 |
| D-017 | Accepted | 宠物领域不虚构后端不存在的通用状态，未知性别采用稳定 fallback |
| D-018 | Accepted | 宠物头像生产入口暂只开放相册，新增相机能力须先补平台用途声明 |
| D-019 | Accepted | 医疗订单使用独立只读模型，按计划展示金额但不臆造详情行为 |
| D-020 | Accepted | 券中心与 checkout 共享完整 UserCoupon 解析，但保持只读与选择语义隔离 |
| D-021 | Accepted | 页面销毁后迟到的异步结果统一失效 |
| D-022 | Accepted | Profile 会话资料更新必须同步所有活动消费者，聊天头像从控制器创建起监听 |

---

## D-001：RN 实际行为作为业务基线

- 状态：Accepted
- 日期：2026-07-25
- 背景：用户要求以 RN 已有页面指导 Flutter 移植；RN ProfileScreen 注释又称其来自历史 Flutter 页面。
- 决策：以当前 RN 实际渲染、service 调用、路由和测试为业务基线；Flutter 使用现有 `data/domain/presentation`、coordinator 和 controller 模式实现，不逐行翻译 React state 或样式。
- 后果：RN 的 bug/TODO 不自动复制；任何有意差异必须在本文件记录。

## D-002：范围采用“直接拥有页面 + 跨域安全闭环”

- 状态：Accepted
- 日期：2026-07-25
- 背景：通知 action、钱包交易和宠物页面可能跳入商城、预约、社区、走失等其他业务域，全部传递性展开会变成完整 App 重写。
- 决策：个人中心主页面及其直接拥有的宠物、医疗订单、通知、优惠券、钱包、设置必须真实实现；已有商城目标必须真实复用；其他尚不存在的跨域目标必须安全识别、明确反馈并登记外部域缺口。
- 完成影响：不会因外部域缺页崩溃或制造死入口，但这些缺口不伪装成已迁移页面。

## D-003：使用 ProfileNavigationCoordinator

- 状态：Accepted
- 日期：2026-07-25
- 背景：当前 HomePage 已接入 MallNavigationCoordinator。若为九个 profile 服务逐一添加 callback，HomePage 会持续膨胀。
- 决策：新增 `ProfileNavigator/ProfileNavigationCoordinator`；九入口、钱包和通知 action 统一转换为 sealed destination。订单、地址、收藏、发布商品、钱包订单详情和通知商城目标委托 `MallNavigationCoordinator`，Profile 自有页面交给强类型 `ProfilePageFactory`。
- 根组装：`main()` 创建一次 `ProfileDependencies/ProfileNavigationCoordinator` 并通过 App/Auth/Home 透传；Widget build 不创建 repository/coordinator。
- HomePage 边界：只接收一个可选 `profileNavigation`，现有四个 Profile 商城私有转发方法已删除，不增加九个 callback。
- 通知边界：raw action 只在纯解析函数入口出现；路由层使用强类型目标。未知、格式错误和外部域目标不抛异常，统一反馈。
- 验证：WP-02 CodeGraph 未发现依赖环；定向测试覆盖九入口、商城委托参数、钱包订单详情、未知通知、游客 gating 和返回保持 Profile Tab。

## D-004：AuthController 是资料更新的唯一会话入口

- 状态：Accepted
- 日期：2026-07-25
- 背景：RN 在更新成功后同步 AuthContext。Flutter session 当前由 AuthController 和 SessionStore 管理。
- 决策：ProfileController 调后端成功后调用 `AuthController.updateProfile`；controller 合并 patch 并保留未知字段，先 `SessionStore.saveSession`，成功后才替换内存 session 并通知监听者。
- 失败策略：持久化异常原样传播；内存 session 和监听器保持不变，不向 UI 伪报更新成功。
- 禁止方案：页面直接写 SharedPreferences；只改 ProfileController 临时状态；丢弃 session.profile 未知字段。
- 验证：WP-01 已完成 AuthController/SessionStore 影响分析；测试覆盖内存更新、持久化恢复、监听通知、未知字段保留、未登录拒绝和保存失败回滚。

## D-005：局部错误不显示虚假零值

- 状态：Accepted
- 日期：2026-07-25
- 背景：RN 钱包失败后静默并可能显示 fallback 0；用户无法区分真实 0 与请求失败。
- 决策：Flutter 保持资料区域可用，但钱包区域显示局部失败和重试，不将失败渲染成真实 `0.00`。
- 性质：这是有意的可靠性改进，不是业务 contract 变化。

## D-006：不实现头像大图查看器

- 状态：Accepted
- 日期：2026-07-25
- 背景：RN `showAvatarViewer` 仅有 TODO 和 console log。
- 决策：它不属于 RN 已有可用能力，不作为本迁移交付要求。头像点击行为在 WP-03 可保持无动作或进入编辑，但不能声称已迁移查看器。

## D-007：不新增头像/HTML依赖

- 状态：Accepted
- 日期：2026-07-25
- 背景：Flutter `pubspec.yaml` 已包含 `image_picker` 和 `flutter_html`，ApiClient 已支持 multipart。
- 决策：头像选择/上传和系统文章基于现有能力实现，不新增包，不改 lockfile。
- 例外：发现现有包无法满足真实 contract 时先记录证据并请求用户确认。

## D-008：通知轮询属于登录会话生命周期

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-08
- 背景：RN NotificationContext 约每 60 秒轮询；Flutter 主页面不应自己长期持有跨页面 Timer。
- 决策：创建可注入 interval/poll factory 的 session-scoped `NotificationBadgeController`；登录后立即拉取，前台按默认 60 秒轮询，paused/inactive/hidden 停止，resumed 立即校准，登出、账号切换和 dispose 清理。Profile、通知列表和 App 根只共享同一实例，不各自建立观察者。
- 一致性：单条/全部已读使用 mutation token 立即调整角标，失败按 token 回滚；后续服务端刷新通过 revision 覆盖本地估算。所有异步请求带 owner/generation，旧账号迟到响应不得更新新会话。
- 影响：生命周期只在 `PetHospitalApp` 统一转发；页面返回后 Profile 角标继续监听同一 `ValueListenable`。未知、格式错误和未实现外部域 action 不参与轮询状态，仍由强类型 coordinator 明确反馈。
- 验证：fake poll、pause/resume/deactivate/dispose、跨账号迟到响应、单条/全部回滚、刷新竞态、App 生命周期和 Profile 角标阈值测试通过；WP-08 定向 63/63、全量 343/343。

## D-009：会员等级默认普通会员

- 状态：Accepted
- 日期：2026-07-25
- 背景：RN 虽包含积分阈值算法，但实际 `integral` 固定为 0，没有真实积分读取。
- 决策：Flutter 显示“普通会员”，不复制没有数据源的伪动态算法。WP-00 已核对 `User` entity、`GET /users/me` 选择字段和 Profile RN 实现，均不存在会员或积分数据源。
- 变更条件：后端存在并确认真实会员/积分字段后，新增 contract 和测试再升级。

## D-010：收藏 SKU 使用统一商品详情流程

- 状态：Accepted
- 日期：2026-07-25
- 背景：RN 收藏列表支持选择 SKU/数量；Flutter 当前有 SKU 时进入商品详情，无 SKU 时直接加购 1 件。
- 决策：保留并测试 Flutter 的统一购买流程。有可售 SKU 时，收藏页提示“请先选择商品规格”并进入既有商品详情，由详情页负责规格、数量和库存边界；无 SKU 时收藏页直接加购 1 件。
- 原因：同一商品的 SKU、数量和库存选择应只有一个交互与校验来源；在收藏页复制一套选择器会形成第二份状态机，并与既有详情页、购物车反馈产生漂移。该差异不削弱 RN 的用户能力，仍能从收藏入口完成同样购买任务。
- 边界：取消收藏必须二次确认且仅在服务端成功后移出；进入详情不自动加购，用户仍需明确选择并提交。若后续产品明确要求列表内快捷规格选择，应以共享 SKU 组件实现，不复制详情页规则。
- 验证：Widget 测试固定无 SKU 以 `{productId, skuId:null, quantity:1}` 加购，有 SKU 只委托详情且不调用加购；商城定向 61/61、全量 376/376 通过。

## D-011：Repository 只解已审计的响应层级

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-00
- 背景：后端统一拦截器会包装普通返回、提升分页字段，并保留 `{success, data}` 业务载荷；`/chat/orders` 又会自行返回标准 `{code, data}`。因此不同 endpoint 经 `ApiClient` 后的形状并不完全相同。
- 决策：Flutter `ApiClient` 继续只处理统一外层；各 Repository 根据验证记录中的固定 contract 解析自身业务层。钱包允许再解一次已确认的 `{success, data}`，医疗订单读取已确认的分页 map，通知读取 `data + pagination`，优惠券读取数组。禁止递归 `unwrapData` 或同时猜测多种未见过的层级。
- 原因：失败应尽早暴露为 contract 错误，避免服务端字段漂移被无限兼容掩盖。
- 验证：每个 Repository 使用真实 wire fixture 建 contract test；服务端 envelope 变化时先更新审计和 fixture。

## D-012：Profile owned page factory 分阶段注入

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-02
- 背景：WP-02 必须先冻结九入口和跨域委托 contract，但宠物、医疗订单、通知、优惠券、钱包和设置的真实页面分别在 WP-04 至 WP-09 实现。
- 决策：`ProfileDependencies` 允许在迁移中暂不提供 `ProfilePageFactory`；当前可见的四个商城入口均为真实委托。后续页面工作包实现真实页面后，把同一个生产 factory 注入根组装，再开放相应入口。
- 禁止方案：用空白页、静态“开发中”页或假数据页面冒充目标；用动态 route 字符串或 `Map<String, dynamic>` 绕过类型 contract。
- 完成约束：此决定只允许分阶段开发，不放宽最终交付标准。WP-12 前九个服务入口及钱包必须全部绑定真实页面，`profileDestinationUnavailableMessage` 不得成为正常用户路径。
- 验证：WP-02 测试 factory 证明九入口的目标映射和回调 contract；每个 owned 工作包须再用生产 factory/widget 测试替换测试 factory 证据。

## D-013：Profile 刷新局部隔离，头像上传只进入编辑草稿

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-03
- 背景：资料、钱包和头像上传的失败边界不同；上传成功不等于用户确认保存，且页面可能在异步请求完成前销毁。
- 决策：`ProfileController` 并发请求资料与钱包但分别记录结果，重复刷新折叠为同一轮；资料失败保留 session 派生的最后有效数据，钱包失败保留最后统计或显示局部错误。头像上传 URL 只返回给编辑页草稿，不能在上传阶段写入 controller 主资料或 Auth session。
- 保存顺序：编辑页先做 trim/校验和差异计算，Repository 成功后经 `AuthController.updateProfile` store-first 持久化，再更新 ProfileController 当前资料；任一步失败都不向页面报告成功。
- 生命周期：controller/page 在 await 后检查 dispose/mounted；上传和保存期间禁用重复入口。
- UI 选择：编辑资料使用全屏页面，保证 320/390/402 宽和键盘场景下有稳定空间；不实现 RN TODO 头像查看器。
- 验证：controller 测试覆盖并发、局部失败、取消/丢失/重复上传、差异保存和 dispose；页面/编辑测试覆盖三档宽度、错误、暂存与 session 一致性。

## D-014：钱包交易展示和并发分页语义

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-04
- 背景：服务端交易金额为 decimal 数值，RN 使用 `income/unfreeze` 显示正号、`expense/freeze` 显示负号；筛选切换和分页请求可能乱序返回。
- 决策：领域模型保留四种已知交易类型、三种状态和 unknown fallback；UI 对金额先取绝对值，再由类型决定正负号，避免服务端负值造成双符号。筛选/刷新递增交易请求 generation，旧筛选或旧分页响应不得覆盖当前状态。
- 错误边界：统计、首屏流水和加载更多分别记录错误；统计失败不伪造 0，加载更多失败保留已有列表与 `hasMore` 以允许重试。未知 enum 稳定显示，不作为 contract 致命错误；金额、ID、时间等关键字段非法仍抛格式错误。
- 导航：只有 `relatedType=order && relatedId>0` 才委托现有 Mall 订单详情；无效/已删除关联显示明确反馈。
- 分阶段 factory：依 D-012，`ProfilePageFactory.buildPage` 可对尚未迁移的 owned destination 返回 null；WP-04 生产 factory 只注册真实钱包页，未注册目标继续统一反馈而不压入空白路由。
- 验证：contract/controller/page/navigation 测试覆盖 envelope、分页、重复加载、竞态、正负号、未知状态、三档宽度、订单参数及生产 factory。

## D-015：系统文章渲染与外部 URI 安全边界

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-05
- 背景：系统文章内容是服务端 HTML，可能包含相对图片、宽表格和链接；工程已有 `flutter_html`，但没有 `url_launcher`，且本轮无修改依赖、lockfile 或平台根配置的授权。
- 决策：文章直接交给 `flutter_html` 结构化渲染，不用正则或字符串替换解析 HTML；图片 URL 只把安全相对路径解析到服务端 origin，并约束展示宽度，表格在窄屏横向滚动。链接仅接受 `http/https`，电话仅接受 `tel`。
- 平台实现：使用 Android/iOS 自有 MethodChannel 提供 `canLaunchUri` 与 `launchUri`，Dart 和 native 两层都校验 `http/https/tel` 白名单；能力检查与启动动作分离，测试 fake 不触发真实电话、浏览器或外部 URL。
- 取舍：没有为规避授权边界偷偷新增包或修改 Manifest/Info.plist；若后续真实设备证明平台可见性配置不足，应记录设备证据并请求根配置变更授权。
- 验证：repository/page/launcher 测试覆盖 public 请求无 Authorization、null 文章、相对图片、宽表格、安全/不安全链接、能力失败；Android Kotlin 编译和 iOS Simulator build 均通过。

## D-016：注销顺序与认证失效后的导航清栈

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-05
- 背景：注销账号是不可逆服务端动作；普通退出或注销成功后，若 Navigator 仍保留受保护子页面，用户可通过返回栈看到旧页面。服务端退出失败又不应阻止本地退出。
- 决策：注销账号必须经过高风险二次确认，并严格执行 `DELETE /users/me` 成功后再调用 `AuthController.invalidateLocalSession()`；删除失败保留认证状态和当前页面。普通退出复用 `AuthController.logout()`，远端 logout 失败仍执行本地会话清理。
- 路由策略：App 根监听认证状态；任何路径进入 unauthenticated 后，在下一帧将 Navigator 清到首路由，由根页面切换到 AuthPage，不能通过返回键恢复受保护页面。
- 并发与错误：退出/注销进行中禁用重复操作；controller 不吞掉删除失败，也不在失败时伪报成功。
- 验证：controller/widget/app 测试覆盖删除成功顺序、删除失败保持认证、重复操作、远端 logout 失败仍清本地状态和受保护路由清栈。

## D-017：宠物模型遵循真实服务端字段边界

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-06
- 背景：RN 列表/编辑页和服务端 Pet entity 有性别、生日、分类、绝育与疫苗字段，但没有通用宠物 `status`；服务端仅有不属于本页面的 `carePlanStatus`。
- 决策：Flutter 不为满足抽象形式虚构 `PetStatus`，也不把 `carePlanStatus` 混入当前列表/编辑 contract。`PetGender` 固定 male/female/unknown，未知 wire 值稳定回退而不是导致整个列表失败；ID、名称等关键字段仍严格校验。
- 影响：后续若迁移照护计划，应建立独立模型和 contract，不修改当前宠物 CRUD 的业务含义。
- 验证：模型、repository、controller 和页面测试覆盖数字/字符串 ID、decimal 字符串、可空字段、未知性别、缺失必需字段和完整 CRUD payload。

## D-018：宠物头像生产入口暂只开放相册

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-06
- 背景：工程已有 `image_picker`，iOS `Info.plist` 已声明照片库用途但没有相机用途声明；新增相机入口需要修改受授权保护的平台根配置。
- 决策：WP-06 生产 UI 只开放相册选取，继续使用统一图片状态与 multipart `file`、category=`pet-avatar` 上传 contract。未补齐 iOS/Android 平台声明和真实设备验证前，不展示可能在运行时失败的相机入口。
- 影响：头像选择、取消、文件丢失、权限失败、上传失败和成功闭环均可交付；相机能力不是当前 RN 宠物页等价交付的阻塞项。如后续明确要求相机，须先取得根配置修改授权并补平台测试。
- 验证：controller/widget 测试覆盖图片状态与成功回填；真实相册权限弹窗、字体和图片视觉留 WP-11/12。

## D-019：医疗订单保持独立只读 contract

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-07
- 背景：`/chat/orders` 返回医生、服务项、咨询时长和独立状态分页，语义不同于商城订单；RN `MedicalServiceOrderListScreen` 没有卡片点击或详情路由。主计划要求 Flutter 可见金额，而 RN 当前类型和服务端 entity 均有 `amount`，只是 RN 卡片遗漏展示。
- 决策：Flutter 建立独立 MedicalServiceOrder 模型和 repository，不复用商城 Order；页面展示订单号、医生、服务、时长、创建时间、金额和状态。没有经审计的详情行为，因此卡片保持只读，不委托商城详情或虚构聊天详情。
- 状态与错误：固定 `PENDING/PAID/REFUNDED/EXPIRED/CANCELLED` 及 unknown fallback；关键 ID、金额、时间、doctor/serviceItem 缺失仍视为 contract 错误。分页严格读取 ApiClient 输出的 `{data,total,page,pageSize,totalPages}`。
- 影响：后续若服务端增加明确医疗订单详情 contract，须新增路由参数、contract 测试和外部域判断后再开放；不能仅凭相同的“订单”名称复用商城页面。
- 验证：模型测试覆盖全部状态和非法关键字段；contract/controller/widget/navigation 测试覆盖 endpoint/query、并发分页、空错态、长名称/空头像/相对资源 URL、金额与生产返回行为。

## D-020：共享优惠券 wire 模型并隔离使用场景

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-09
- 背景：券中心和 checkout 都消费 `/shop/coupons/my` 的完整 UserCoupon + CouponRuleSnapshot，但 checkout 现有 `CheckoutCoupon` 还包含服务端按当前订单计算的 `isApplicable/discountAmount`；RN 券中心只有查看行为，后端列表不支持分页且会在查询期间归档过期券。
- 决策：在 `features/coupons` 建立完整、严格的 UserCoupon/CouponRule parser，券中心直接使用；checkout 复用该 parser 后适配为既有预览模型，不扩大共享 presentation contract。优惠券状态以服务端返回为准，客户端不按本地时钟重新分类；列表只发送真实支持的 `status`，不伪造分页。
- 展示与交互：券中心展示服务端规则快照中的满减、折扣、直减、门槛、范围和有效期，不自行估算订单优惠；checkout 继续以服务端 `discountAmount` 为最终金额来源。券中心卡片保持只读，不复用“选择并返回”回调。
- 影响：共享 wire contract 漂移会同时在券中心和 checkout contract 测试中暴露；若后端未来增加分页或客户端选择模式，须先扩展 endpoint 审计和强类型 API，不能靠可选回调隐式改变当前页面语义。
- 验证：相同 fixture 一致性测试、三状态/count contract、时间边界、竞态 controller、320/390/768 长名称与券型 Widget、生产 factory 和 checkout 回归均通过；WP-09 定向 53/53、全量 364/364。

## D-021：页面销毁后迟到的异步结果统一失效

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-11
- 背景：Profile 会启动资料/钱包并发请求和系统图片选择器，复用 Mall 页面还会启动列表、详情、分页及 mutation 请求；页面返回或会话清栈后，这些 Future 可能继续完成。仅避免 `notifyListeners()` 不足以阻止销毁后上传、状态回写或后续刷新。
- 决策：Profile 图片选择器返回后先检查 controller 是否已销毁，销毁时按取消处理且不上传；地址、商城订单/详情、收藏、我发布 controller 使用 `_disposed` 与 request revision 共同判定结果是否仍属于当前实例和当前请求，所有通知经受控入口发出，dispose 同时使在途 revision 失效。
- 边界：不为现有 Repository 引入取消依赖，也不把业务失败吞成成功；网络请求本身可完成，但迟到结果不得改变状态、发通知、启动上传或串联下一次请求。正常页面存活时的刷新、分页和 mutation 行为保持不变。
- 影响：以后为这些 controller 新增异步分支时，必须沿用同一结果归属检查；只写 `if (!mounted)` 的页面级保护不能替代 controller 生命周期约束。
- 验证：新增测试先稳定复现销毁后 `ChangeNotifier was used after being disposed` 和 Profile 销毁后仍上传，修复后 `mall_controller_test.dart` 18/18、`profile_controller_test.dart` 7/7，WP-11 专项 142/142 通过。

## D-022：Profile 会话资料更新同步所有活动消费者

- 状态：Accepted
- 日期：2026-07-25
- 工作包：WP-12
- 背景：Profile 编辑与刷新已通过 `AuthController.updateProfile` 更新持久会话，App 会把最新头像同步给好友会话；最终全量回归发现，已创建但尚未完成异步初始化的 `FriendChatController` 尚未监听消息控制器，因而不会立即通知聊天 UI 使用新头像。
- 决策：`FriendChatController` 从构造完成起订阅 `FriendsMessagingController`；初始化前的变化只触发轻量 UI 通知，不读取尚未打开的本地消息库；初始化完成后仍按原行为刷新消息列表。dispose 继续统一移除监听器。
- 原因：Profile 资料是会话级共享状态，创建中的活动页面也不能保留旧头像；同时不能为了提前监听而在本地 store 未初始化时触发查询。
- 影响：头像更新后当前聊天气泡可立即读取最新头像；重复相同头像不通知，空白头像稳定归一为 null；消息刷新、分页和数据库生命周期不变。
- 验证：原有红灯“资料更新后活动聊天立即使用最新用户头像”由 0 次通知转为通过；好友/消息/App 清栈定向 26/26、个人中心功能链路 308/308、Flutter 全量 420/420 通过。

---

## 决策新增模板

```markdown
## D-XXX：标题

- 状态：Proposed
- 日期：YYYY-MM-DD
- 工作包：WP-XX
- 背景：
- 选项：
- 决策：
- 原因：
- 影响：
- 验证：
```
