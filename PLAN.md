# 会话级 ConversationId 重构与历史分段回溯

## Summary
- 采用“会话级唯一 `conversationId`”重构聊天链路，不再使用 `userId_doctorId` 这种固定会话标识。
- 规则锁定为：只有“付费会话到期”后再次进入，才创建一个新的 FREE 会话并立即走首条系统自动回复；“免费次数已耗尽”时仍停留在原会话并继续展示付费入口，不能靠反复进出来重置免费次数。
- 聊天页首屏只加载当前活跃会话；倒序列表触顶时，按一次一段的方式回捞上一段会话，并在本地插入分段提示消息。
- 发布采用一次性清空旧聊天数据方案：保留订单等非聊天业务数据，清空旧聊天消息、会话和聊天 Redis 数据，不做旧数据兼容。
- 后端 API 变更后同步更新 `admin/API_DOCUMENT.md`。

## Public APIs / Interfaces
- `ChatSession.conversationId` 改为数据库持久化字段，值为会话级唯一字符串；前端和网关都只能透传/查表使用，不能再本地拼接。
- `GET /chat/session/:doctorId` 保留，但“旧付费会话过期后重新进入”时返回新的 FREE 会话 `conversationId`。
- `GET /chat/messages` 与 `GET /chat/messages/sync` 的 `conversationId` 参数改为会话级标识，不再代表某个用户和医生的长期固定房间。
- 新增 `GET /chat/previous-session/:doctorId?beforeConversationId=...`，返回当前用户与该医生在指定会话之前的最近一段历史会话元数据；前端再用现有 `GET /chat/messages?conversationId=` 拉该段消息。
- WebSocket `join` / `leave` 负载从 `{ userId, doctorId }` 改为 `{ conversationId }`，服务端按 `conversationId` 反查参与者并校验权限。

## Implementation Changes
- 后端 `chat_sessions` 增加持久化 `conversationId` 和唯一索引；创建 FREE 会话或创建 PAID 会话时一次生成并永久绑定，升级 FREE→PAID 时保持不变。
- `ChatSessionService` 重构为四类职责：按参与者取活跃会话、按 `conversationId` 取会话、为到期 PAID 会话创建新的 FREE 会话、查询上一段历史会话。
- `ChatService`、`ChatGateway`、自动回复、支付成功消息、消息查询、增量同步全部改为基于 session 查找，不再从 `conversationId` 反推 `userId/doctorId`。
- 首条自动回复只在“新 FREE 会话首次进入”时触发一次；免费次数耗尽时继续停留在当前 FREE 会话并展示付费提示。
- 用户端 `ChatScreen` 初始化改成：先获取/创建当前活跃会话，再按该会话 `conversationId` 拉首屏消息；不再在前端任何地方拼聊天 `conversationId`。
- `useChatSocket`、`useChatMessageSync`、聊天页发送与补同步逻辑统一围绕当前会话 `conversationId` 工作。
- 聊天页增加历史分段状态：`oldestLoadedConversationId`、`loadingPreviousSession`、`hasPreviousSession`、`loadedHistoryConversationIds`；倒序列表触顶时按段加载上一会话，并插入本地 `SYSTEM` 分隔消息“以下为上一段会话记录”。
- 历史咨询入口继续按 `orderId` 打开只读历史；它与当前活跃会话完全分离，避免误回到新会话。
- 发布前提供一条手动脚本放在 `server/migrations/`：新增 `chat_sessions.conversationId` 字段和唯一索引，清空 `messages`、`chat_sessions`，并清理聊天相关 Redis key；`chat_orders` 等非聊天业务表不动。

## Test Plan
- 服务端用例：付费会话到期后二次进入会新建 FREE 会话且 `conversationId` 变更。
- 服务端用例：免费次数耗尽后二次进入不会新建会话。
- 服务端用例：FREE→PAID 升级时 `conversationId` 保持不变。
- 服务端用例：`previous-session` 只返回当前会话之前的最近一段，且权限校验正确。
- 服务端用例：`messages` / `messages/sync` / WebSocket `join` / `sendMessage` 在会话级 `conversationId` 下工作正常。
- RN 用例：聊天页首屏仅显示当前会话；触顶后按段插入上一段历史且不会重复插入。
- RN 用例：前后台切换补同步只补当前会话，不覆盖已插入的历史分段。
- RN 用例：不同会话中内容相同的消息不会因去重策略被误删。
- 手工验收：完成 FREE→PAID→到期流程后重新进入，应看到新的自动回复开场，而不是旧记录加付费按钮首屏直出。

## Assumptions
- 旧聊天历史允许全部丢弃，因此不做任何旧 `conversationId` 回填、桥接或兼容读取。
- “上一段历史”按会话维度逐段回溯，每次触顶只加载一段。
- 订单数据、支付记录、医生收入统计必须保留；清理范围仅限聊天消息、聊天会话和聊天 Redis 临时态。
