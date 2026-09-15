import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
  Inject,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from "@nestjs/common";
import { ChatService } from "./chat.service";
import { CreateChatOrderDto } from "./dto/order.dto";
import { OrderService } from "./order.service";
import { AutoReplyService } from "./auto-reply.service";
import { DoctorsService } from "../doctors/doctors.service";
import { PaymentConfigService } from "./payment-config.service";
import { CreateAutoReplyDto, UpdateAutoReplyDto } from "./dto/auto-reply.dto";
import { QueryPreviousSessionDto } from "./dto/query-previous-session.dto";
import { SyncMessagesDto } from "./dto/sync-messages.dto";
import { UpdatePaymentConfigDto } from "./dto/payment-config.dto";
import { QueryDoctorIncomeDto } from "./dto/doctor-income.dto";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { RolesGuard } from "../auth/guards/roles.guard";
import { Roles } from "../auth/decorators/roles.decorator";
import {
  CurrentUser,
  CurrentUserData,
} from "../common/decorators/current-user.decorator";
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
  ApiResponse,
  ApiParam,
} from "@nestjs/swagger";
import { ChatGateway } from "./chat.gateway";
import { DoctorPatientRecordService } from "./doctor-patient-record.service";
import { RevokeChatMessageDto } from "./dto/revoke-message.dto";
import { ExtendChatSessionDto } from "./dto/extend-chat-session.dto";
import { ChatSessionExtensionService } from "./chat-session-extension.service";

@ApiTags("chat - 聊天与咨询管理")
@ApiBearerAuth()
@Controller("chat")
@UseGuards(JwtAuthGuard, RolesGuard)
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly orderService: OrderService,
    private readonly doctorsService: DoctorsService,
    private readonly autoReplyService: AutoReplyService,
    private readonly paymentConfigService: PaymentConfigService,
    private readonly chatGateway: ChatGateway,
    private readonly doctorPatientRecordService: DoctorPatientRecordService,
    private readonly chatSessionExtensionService: ChatSessionExtensionService,
  ) {}

  // ========== 会话管理 ==========

  @Get("session/:doctorId")
  @ApiOperation({
    summary: "获取会话状态",
    description:
      "点击医生聊天时调用，获取或创建会话，返回会话状态、可用套餐等信息",
  })
  @ApiParam({ name: "doctorId", description: "医生ID", example: 1 })
  @ApiResponse({ status: 200, description: "成功返回会话信息" })
  @ApiResponse({ status: 401, description: "未授权" })
  async getSession(
    @Param("doctorId", ParseIntPipe) doctorId: number,
    @CurrentUser() user: any,
  ) {
    return this.chatService.getOrCreateSession(user.id, doctorId);
  }

  @Get("check-can-send/:doctorId")
  @ApiOperation({
    summary: "检查是否可以发送消息",
    description: "检查用户是否可以向指定医生发送消息，返回会话状态和可用套餐",
  })
  @ApiParam({ name: "doctorId", description: "医生ID", example: 1 })
  @ApiResponse({ status: 200, description: "成功返回检查结果" })
  @ApiResponse({ status: 401, description: "未授权" })
  async checkCanSend(
    @Param("doctorId", ParseIntPipe) doctorId: number,
    @CurrentUser() user: any,
  ) {
    return this.chatService.canSendMessage(user.id, doctorId);
  }

  // ========== 消息查询 ==========

  @Get("messages")
  @ApiOperation({
    summary: "获取消息历史",
    description: "HTTP 方式获取指定会话的消息历史记录，支持分页",
  })
  @ApiQuery({
    name: "conversationId",
    required: true,
    description: "会话级持久化标识（opaque session id）",
    example: "550e8400-e29b-41d4-a716-446655440000",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 50,
  })
  @ApiResponse({ status: 200, description: "成功返回消息列表" })
  @ApiResponse({ status: 403, description: "无权访问该会话的消息" })
  @Roles("USER", "DOCTOR", "SUPER_ADMIN", "HOSPITAL_ADMIN", "STAFF")
  async getMessages(
    @CurrentUser() user: CurrentUserData,
    @Query("conversationId") conversationId: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
    @Query("orderId") orderId?: string, // 🔑 新增：按订单筛选消息
  ) {
    if (user.type === "doctor" || user.role === "USER") {
      await this.chatService.assertConversationParticipant(
        conversationId,
        user.id,
        user.type,
      );
    }
    return this.chatService.getMessagesByConversation(
      conversationId,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 50,
      orderId ? parseInt(orderId) : undefined, // 传递 orderId 参数
      user.type === "doctor" || user.role === "USER",
    );
  }

  @Post("messages/:id/revoke")
  @ApiOperation({ summary: "撤回两分钟内发送的医患消息" })
  @ApiParam({ name: "id", description: "消息ID" })
  @Roles("USER", "DOCTOR")
  async revokeMessage(
    @CurrentUser() user: CurrentUserData,
    @Param("id", ParseIntPipe) id: number,
    @Body() dto: RevokeChatMessageDto,
  ) {
    const message = await this.chatService.revokeMessage(
      dto.conversationId,
      id,
      user.id,
      user.type,
    );
    this.chatGateway.emitRevokedMessage(message);
    return { success: true, data: { message } };
  }

  @Get("messages/sync")
  @ApiOperation({
    summary: "增量同步消息",
    description:
      "支持按时间戳增量拉取消息，用户和医生都可以使用。用于前后台切换时同步新消息。",
  })
  @ApiQuery({
    name: "conversationId",
    required: true,
    description: "会话级持久化标识（opaque session id）",
  })
  @ApiQuery({
    name: "since",
    required: false,
    description: "起始时间戳（ISO 8601 格式）",
    example: "2026-01-22T10:00:00.000Z",
  })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "最大返回数量（默认50，最大100）",
    example: 50,
  })
  @ApiResponse({ status: 200, description: "成功返回消息列表" })
  @ApiResponse({ status: 400, description: "参数错误" })
  @ApiResponse({ status: 401, description: "未授权" })
  @ApiResponse({ status: 403, description: "无权访问该会话的消息" })
  @ApiResponse({ status: 404, description: "会话不存在" })
  @Roles("USER", "DOCTOR") // 允许用户和医生访问
  async syncMessages(
    @CurrentUser() user: CurrentUserData,
    @Query() query: SyncMessagesDto,
  ) {
    const session = await this.chatService.assertConversationParticipant(
      query.conversationId,
      user.id,
      user.type,
    );

    // ✅ 调用 Service 方法（DTO 已自动验证参数格式和范围）
    return this.chatService.syncMessagesBySession(
      session,
      query.since ? new Date(query.since) : undefined,
      query.limit || 50,
    );
  }

  @Get("message/:id")
  @ApiOperation({
    summary: "获取消息详情",
    description: "根据消息ID获取单条消息的详细信息",
  })
  @ApiParam({ name: "id", description: "消息ID", example: 1 })
  @ApiResponse({ status: 200, description: "成功返回消息详情" })
  @ApiResponse({ status: 404, description: "消息不存在" })
  async getMessage(@Param("id", ParseIntPipe) id: number) {
    return this.chatService.getMessageById(id);
  }

  @Get("ai-consultations/:petId")
  @ApiOperation({
    summary: "获取宠物的 AI 问诊记录列表",
    description: "获取指定宠物的所有 AI 问诊记录，支持分页",
  })
  @ApiParam({ name: "petId", description: "宠物ID", example: 1 })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 10,
  })
  @ApiResponse({ status: 200, description: "成功返回 AI 问诊记录列表" })
  async getPetAiConsultations(
    @Param("petId", ParseIntPipe) petId: number,
    @CurrentUser() user: any,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    return this.chatService.getPetAiConsultations(
      petId,
      user.id,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 10,
    );
  }

  @Get("ai-consultations/:petId/:id")
  @ApiOperation({
    summary: "获取 AI 问诊记录详情",
    description: "获取指定 AI 问诊记录的完整详情",
  })
  @ApiParam({ name: "petId", description: "宠物ID", example: 1 })
  @ApiParam({ name: "id", description: "问诊记录ID", example: 1 })
  @ApiResponse({ status: 200, description: "成功返回问诊详情" })
  @ApiResponse({ status: 404, description: "问诊记录不存在" })
  async getAiConsultationDetail(
    @Param("petId") petId: number,
    @Param("id", ParseIntPipe) id: number,
  ) {
    return this.chatService.getAiConsultationDetail(id);
  }

  @Get("statistics")
  @ApiOperation({
    summary: "获取聊天统计",
    description: "获取消息统计信息（管理员/医生专用）",
  })
  @ApiResponse({ status: 200, description: "成功返回统计数据" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("SUPER_ADMIN", "HOSPITAL_ADMIN", "STAFF", "DOCTOR")
  async getStatistics(@CurrentUser() user: any) {
    return this.chatService.getStatistics(user.id);
  }

  // ========== 订单管理 ==========

  @Get("packages/:doctorId")
  @ApiOperation({
    summary: "获取可用套餐列表",
    description: "获取指定医生的可用收费项列表（聊天套餐）",
  })
  @ApiParam({ name: "doctorId", description: "医生ID", example: 1 })
  @ApiResponse({ status: 200, description: "成功返回套餐列表" })
  async getDoctorPackages(@Param("doctorId", ParseIntPipe) doctorId: number) {
    const serviceItems = await this.doctorsService.getServiceItems(doctorId);

    // 转换为前端需要的格式（保持兼容性）
    return serviceItems.map((item) => ({
      id: item.id,
      name: item.name,
      duration: item.duration, // 分钟
      durationDays: Math.floor(item.duration / 1440), // 转换为天（用于显示）
      price: item.price,
      description: item.description,
      isActive: item.isActive,
    }));
  }

  @Post("orders")
  @ApiOperation({
    summary: "创建订单（购买套餐）",
    description: "创建待支付咨询订单；仅在支付成功后激活付费服务",
  })
  @ApiResponse({ status: 201, description: "订单创建成功" })
  @ApiResponse({ status: 400, description: "收费项不存在或已下架/重复购买" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("USER")
  async createOrder(
    @Body() body: CreateChatOrderDto,
    @CurrentUser() user: any,
  ) {
    return this.orderService.create(
      user.id,
      body.doctorId,
      body.serviceItemId,
      body.paymentChannel,
      body.idempotencyKey,
      body.conversationId,
    );
  }

  @Get("orders")
  @ApiOperation({
    summary: "我的订单列表",
    description: "获取当前用户的所有订单，支持分页",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 10,
  })
  @ApiQuery({
    name: "pageSize",
    required: false,
    description: "每页数量（兼容 RN 端参数）",
    example: 10,
  })
  @ApiResponse({ status: 200, description: "成功返回订单列表" })
  @Roles("USER")
  async getMyOrders(
    @CurrentUser() user: any,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
    @Query("pageSize") pageSize?: string,
  ) {
    const parsedPage = page ? parseInt(page, 10) : 1;
    const parsedLimit = pageSize
      ? parseInt(pageSize, 10)
      : limit
        ? parseInt(limit, 10)
        : 10;

    const result = await this.orderService.getUserOrders(
      user.id,
      parsedPage,
      parsedLimit,
    );

    // 显式返回 code/data，避免被全局响应拦截器二次转换成 pagination 包装
    // 兼容 RN 端当前对 { data, page, totalPages } 的读取方式
    return {
      code: 0,
      data: result,
      message: "Success",
    };
  }

  @Get("doctor/orders")
  @ApiOperation({
    summary: "医生订单列表",
    description: "获取当前医生的咨询订单，支持分页（兼容 RN 医生端旧接口）",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 10,
  })
  @ApiQuery({
    name: "pageSize",
    required: false,
    description: "每页数量（兼容 RN 端参数）",
    example: 10,
  })
  @ApiResponse({ status: 200, description: "成功返回医生订单列表" })
  @Roles("DOCTOR")
  async getDoctorOrders(
    @CurrentUser() user: any,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
    @Query("pageSize") pageSize?: string,
  ) {
    const parsedPage = page ? parseInt(page, 10) : 1;
    const parsedLimit = pageSize
      ? parseInt(pageSize, 10)
      : limit
        ? parseInt(limit, 10)
        : 10;

    const result = await this.orderService.getDoctorOrders(
      user.id,
      parsedPage,
      parsedLimit,
    );

    return {
      code: 0,
      data: result,
      message: "Success",
    };
  }

  @Get("orders/:orderNo")
  @ApiOperation({
    summary: "订单详情",
    description: "根据订单号获取订单详细信息",
  })
  @ApiParam({
    name: "orderNo",
    description: "订单号",
    example: "CO17379284601234",
  })
  @ApiResponse({ status: 200, description: "成功返回订单详情" })
  @ApiResponse({ status: 404, description: "订单不存在" })
  async getOrderDetail(@Param("orderNo") orderNo: string) {
    return this.orderService.findByOrderNo(orderNo);
  }

  // ========== 医生收入统计 ==========

  @Get("doctor/income-stats")
  @ApiOperation({
    summary: "获取医生收入统计",
    description: "获取当前医生的收入统计数据（今日、本周、本月、总收入）",
  })
  @ApiResponse({ status: 200, description: "成功返回收入统计" })
  @ApiResponse({ status: 401, description: "未授权" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("DOCTOR")
  async getDoctorIncomeStats(@CurrentUser() user: any) {
    return this.orderService.getDoctorIncomeStats(user.id);
  }

  @Get("doctor/income-list")
  @ApiOperation({
    summary: "获取医生收入明细列表",
    description: "获取当前医生的收入明细记录，支持分页",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 10,
  })
  @ApiResponse({ status: 200, description: "成功返回收入明细列表" })
  @ApiResponse({ status: 401, description: "未授权" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("DOCTOR")
  async getDoctorIncomeList(
    @CurrentUser() user: any,
    @Query() query: QueryDoctorIncomeDto,
  ) {
    return this.orderService.getDoctorIncomeList(
      user.id,
      query.page,
      query.limit,
    );
  }

  // ========== 自动回复管理 ==========

  @Post("auto-replies")
  @ApiOperation({
    summary: "创建自动回复",
    description: "创建新的自动回复规则（超级管理员专用）",
  })
  @ApiResponse({ status: 201, description: "自动回复创建成功" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("SUPER_ADMIN")
  async createAutoReply(@Body() dto: CreateAutoReplyDto) {
    return this.autoReplyService.create(dto);
  }

  @Put("auto-replies/:id")
  @ApiOperation({
    summary: "更新自动回复",
    description: "更新指定的自动回复规则",
  })
  @ApiParam({ name: "id", description: "自动回复ID", example: 1 })
  @ApiResponse({ status: 200, description: "更新成功" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @ApiResponse({ status: 404, description: "自动回复不存在" })
  @Roles("SUPER_ADMIN")
  async updateAutoReply(
    @Param("id", ParseIntPipe) id: number,
    @Body() dto: UpdateAutoReplyDto,
  ) {
    return this.autoReplyService.update(id, dto);
  }

  @Delete("auto-replies/:id")
  @ApiOperation({
    summary: "删除自动回复",
    description: "删除指定的自动回复规则",
  })
  @ApiParam({ name: "id", description: "自动回复ID", example: 1 })
  @ApiResponse({ status: 200, description: "删除成功" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("SUPER_ADMIN")
  async deleteAutoReply(@Param("id", ParseIntPipe) id: number) {
    return this.autoReplyService.remove(id);
  }

  @Get("auto-replies")
  @ApiOperation({
    summary: "获取自动回复列表",
    description: "获取所有公共自动回复列表（与医生解耦）",
  })
  @ApiResponse({ status: 200, description: "成功返回自动回复列表" })
  async getAutoReplies() {
    return this.autoReplyService.getAllReplies();
  }

  // ========== 自动回复缓存管理 ==========

  @Post("auto-replies/clear-cache")
  @ApiOperation({
    summary: "清空自动回复缓存",
    description:
      "清空所有自动回复相关的 Redis 缓存，修改自动回复配置后调用此接口使更改立即生效",
  })
  @ApiResponse({ status: 200, description: "清空成功" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("SUPER_ADMIN")
  async clearAutoReplyCache() {
    return this.autoReplyService.clearCache();
  }

  // ========== 套餐管理 ==========
  // 注意：套餐管理功能已移至 DoctorsController
  // 请使用 POST/PUT/DELETE /doctors/:doctorId/service-items 来管理医生收费项

  @Get("packages-list/:doctorId")
  @ApiOperation({
    summary: "获取套餐列表",
    description: "获取指定医生的可用套餐列表（同 GET /packages/:doctorId）",
  })
  @ApiParam({ name: "doctorId", description: "医生ID", example: 1 })
  @ApiResponse({ status: 200, description: "成功返回套餐列表" })
  async getPackagesList(@Param("doctorId", ParseIntPipe) doctorId: number) {
    // 委托给 getDoctorPackages 方法
    return this.getDoctorPackages(doctorId);
  }

  // ========== 付费配置管理 ==========

  @Get("payment-config")
  @ApiOperation({
    summary: "获取全局付费配置",
    description: "获取全局默认付费配置",
  })
  @ApiResponse({ status: 200, description: "成功返回付费配置" })
  async getGlobalPaymentConfig() {
    return this.paymentConfigService.getConfig();
  }

  @Get("payment-config/:doctorId")
  @ApiOperation({
    summary: "获取医生付费配置",
    description: "获取指定医生的付费配置",
  })
  @ApiParam({ name: "doctorId", description: "医生ID", example: 1 })
  @ApiResponse({ status: 200, description: "成功返回付费配置" })
  async getDoctorPaymentConfig(
    @Param("doctorId", ParseIntPipe) doctorId: number,
  ) {
    return this.paymentConfigService.getConfig(doctorId);
  }

  @Put("payment-config/:doctorId")
  @ApiOperation({
    summary: "更新付费配置",
    description: "更新指定医生的付费配置（超级管理员专用）",
  })
  @ApiParam({ name: "doctorId", description: "医生ID", example: 1 })
  @ApiResponse({ status: 200, description: "更新成功" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("SUPER_ADMIN")
  async updatePaymentConfig(
    @Param("doctorId", ParseIntPipe) doctorId: number,
    @Body() dto: UpdatePaymentConfigDto,
  ) {
    return this.paymentConfigService.updateConfig(doctorId, dto);
  }

  // ========== 基础接口 ==========

  @Get("unread-count")
  @ApiOperation({
    summary: "获取未读消息数",
    description: "获取当前用户的未读消息总数",
  })
  @ApiResponse({ status: 200, description: "成功返回未读消息数" })
  async getUnreadCount(@CurrentUser() user: CurrentUserData) {
    return this.chatService.getUnreadCount(user.id, user.type);
  }

  @Get("conversations")
  @ApiOperation({
    summary: "获取咨询会话列表",
    description:
      "获取当前用户的医生咨询会话，合并免费临时会话和付费/历史会话，并返回最后消息及逐会话未读数",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量，最大100",
    example: 20,
  })
  @ApiResponse({ status: 200, description: "成功返回咨询会话列表" })
  @Roles("USER")
  async getConversationList(
    @CurrentUser() user: CurrentUserData,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const normalizedPage = Math.max(1, parseInt(page || "1", 10) || 1);
    const normalizedLimit = Math.min(
      100,
      Math.max(1, parseInt(limit || "20", 10) || 20),
    );
    return this.chatService.getConversationList(
      user.id,
      normalizedPage,
      normalizedLimit,
    );
  }

  @Put("conversations/:conversationId/read")
  @ApiOperation({
    summary: "标记咨询会话已读",
    description: "将当前用户在指定咨询会话中收到的全部消息标记为已读",
  })
  @ApiParam({
    name: "conversationId",
    description: "会话级持久化标识（opaque session id）",
  })
  @ApiResponse({ status: 200, description: "标记成功" })
  @ApiResponse({ status: 403, description: "当前账号不是该会话参与者" })
  @Roles("USER", "DOCTOR")
  async markConversationAsRead(
    @Param("conversationId") conversationId: string,
    @CurrentUser() user: CurrentUserData,
  ) {
    await this.chatService.markConversationAsRead(
      conversationId,
      user.id,
      user.type,
    );
    return { success: true };
  }

  @Get("conversation-id")
  @ApiOperation({
    summary: "解析当前会话ID",
    description:
      "兼容接口：返回当前用户与指定医生当前会话的真实持久化 conversationId，不再本地拼接 userId_doctorId",
  })
  @ApiQuery({
    name: "doctorId",
    required: true,
    description: "医生ID",
    example: 1,
  })
  @ApiQuery({
    name: "userId",
    required: true,
    description: "用户ID（兼容旧客户端保留参数）",
    example: 2,
  })
  @ApiResponse({ status: 200, description: "成功返回会话ID" })
  async resolveConversationId(
    @Query("doctorId", ParseIntPipe) doctorId: number,
    @Query("userId", ParseIntPipe) userId: number,
  ) {
    return this.chatService.resolveConversationId(userId, doctorId);
  }

  @Get("previous-session/:doctorId")
  @ApiOperation({
    summary: "获取上一段历史会话",
    description:
      "根据当前会话的 conversationId 查询当前用户与该医生之前最近一段历史会话元数据，不返回消息列表",
  })
  @ApiParam({ name: "doctorId", description: "医生ID", example: 1 })
  @ApiQuery({
    name: "beforeConversationId",
    required: true,
    description: "当前会话的持久化 conversationId",
    example: "550e8400-e29b-41d4-a716-446655440000",
  })
  @ApiResponse({ status: 200, description: "成功返回上一段会话元数据或 null" })
  @ApiResponse({
    status: 400,
    description: "beforeConversationId 无效或 doctorId 不匹配",
  })
  @ApiResponse({ status: 403, description: "当前用户不是该会话参与者" })
  @Roles("USER", "DOCTOR")
  async getPreviousSession(
    @Param("doctorId", ParseIntPipe) doctorId: number,
    @Query() query: QueryPreviousSessionDto,
    @CurrentUser() user: CurrentUserData,
  ) {
    return this.chatService.getPreviousSession(
      user.id,
      user.type,
      doctorId,
      query.beforeConversationId,
    );
  }

  // ========== 历史咨询查询 ==========

  @Get("history-consultations")
  @ApiOperation({
    summary: "获取历史咨询列表",
    description:
      "获取当前普通用户的历史咨询记录（已支付的订单），支持分页。医生端使用 doctor/sessions/:conversationId/history。",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 3,
  })
  @ApiQuery({
    name: "doctorId",
    required: false,
    description: "按医生ID筛选，仅返回当前用户与该医生的已支付订单",
    example: 1,
  })
  @ApiResponse({ status: 200, description: "成功返回历史咨询列表" })
  @ApiResponse({ status: 401, description: "未授权" })
  @Roles("USER")
  async getHistoryConsultations(
    @CurrentUser() user: any,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
    @Query("doctorId") doctorId?: string,
  ) {
    const parsedDoctorId =
      doctorId === undefined ? undefined : Number(doctorId);
    if (parsedDoctorId !== undefined && !Number.isInteger(parsedDoctorId)) {
      throw new BadRequestException("doctorId必须是有效的整数");
    }
    return this.chatService.getHistoryConsultations(
      user.id,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 3,
      parsedDoctorId,
    );
  }

  @Get("messages-by-order/:orderId")
  @ApiOperation({
    summary: "获取订单的聊天记录",
    description: "获取指定订单的聊天记录，只显示该订单支付后的消息",
  })
  @ApiParam({ name: "orderId", description: "订单ID", example: 1 })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 50,
  })
  @ApiResponse({ status: 200, description: "成功返回消息列表" })
  @ApiResponse({ status: 401, description: "未授权" })
  @ApiResponse({ status: 404, description: "订单不存在或无权访问" })
  @Roles("USER")
  async getMessagesByOrder(
    @Param("orderId", ParseIntPipe) orderId: number,
    @CurrentUser() user: any,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    return this.chatService.getMessagesByOrder(
      orderId,
      user.id,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 50,
    );
  }

  // ========== 会话列表查询（管理后台专用）==========

  @Get("sessions")
  @ApiOperation({
    summary: "获取会话列表",
    description: "获取聊天会话列表，支持分页和多维度筛选（管理员和医生可用）",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 20,
  })
  @ApiQuery({ name: "doctorId", required: false, description: "医生ID筛选" })
  @ApiQuery({ name: "userId", required: false, description: "用户ID筛选" })
  @ApiQuery({
    name: "status",
    required: false,
    description: "状态筛选 (FREE/PAID/EXPIRED)",
  })
  @ApiResponse({ status: 200, description: "成功返回会话列表" })
  @ApiResponse({ status: 403, description: "权限不足" })
  @Roles("SUPER_ADMIN", "HOSPITAL_ADMIN", "STAFF", "DOCTOR")
  async getSessions(
    @CurrentUser() currentUser: CurrentUserData,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
    @Query("doctorId") doctorId?: string,
    @Query("userId") userId?: string,
    @Query("status") status?: string,
  ) {
    const isDoctor = currentUser.role === "DOCTOR";
    if (isDoctor && currentUser.type !== "doctor") {
      throw new ForbiddenException("医生账号身份异常");
    }
    return this.chatService.getSessions({
      page: page ? parseInt(page) : 1,
      limit: limit ? parseInt(limit) : 20,
      doctorId: isDoctor
        ? currentUser.id
        : doctorId
          ? parseInt(doctorId)
          : undefined,
      userId: userId ? parseInt(userId) : undefined,
      status: status as any,
    });
  }

  @Get("doctor/sessions")
  @ApiOperation({
    summary: "医生活跃会话列表",
    description: "兼容 RN 医生端旧接口，返回 sessions 和 unreadCount",
  })
  @ApiQuery({ name: "page", required: false, description: "页码", example: 1 })
  @ApiQuery({
    name: "limit",
    required: false,
    description: "每页数量",
    example: 20,
  })
  @ApiQuery({
    name: "status",
    required: false,
    description: "状态筛选 (FREE/PAID/EXPIRED)",
  })
  @ApiResponse({ status: 200, description: "成功返回医生会话列表" })
  @Roles("DOCTOR")
  async getDoctorSessions(
    @CurrentUser() user: any,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
    @Query("status") status?: string,
  ) {
    const sessionsResult = await this.chatService.getDoctorSessions({
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
      doctorId: user.id,
      status: status as any,
    });

    const unreadCount = await this.chatService.getUnreadCount(
      user.id,
      "doctor",
    );

    return {
      code: 0,
      data: {
        sessions: sessionsResult.data || [],
        unreadCount,
        pagination: {
          total: sessionsResult.total || 0,
          page: sessionsResult.page || 1,
          pageSize: sessionsResult.limit || 20,
          totalPages: sessionsResult.totalPages || 0,
        },
      },
      message: "Success",
    };
  }

  @Post("doctor/sessions/:conversationId/extensions")
  @ApiOperation({
    summary: "医生主动延长咨询时间",
    description:
      "仅允许当前医生延长本人仍在服务中的付费会话；已过期会话不会重新开启，单次可延长 5/10/15/30 分钟，累计不设上限",
  })
  @ApiParam({ name: "conversationId", description: "咨询会话唯一标识" })
  @ApiResponse({ status: 201, description: "咨询时间延长成功" })
  @ApiResponse({ status: 400, description: "会话已结束或延长时长无效" })
  @ApiResponse({ status: 403, description: "当前医生无权操作该会话" })
  @Roles("DOCTOR")
  async extendDoctorSession(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Body() dto: ExtendChatSessionDto,
  ) {
    const result = await this.chatSessionExtensionService.extend({
      conversationId,
      doctorId: user.id,
      minutes: dto.minutes,
      reason: dto.reason,
      idempotencyKey: dto.idempotencyKey,
    });
    this.chatGateway.emitSessionExtended(result);
    return result;
  }

  // ========== 医生查看咨询用户健康档案 ==========

  @Get("doctor/sessions/:conversationId/patient")
  @ApiOperation({
    summary: "获取咨询用户健康档案",
    description: "医生只读查看本人咨询会话中的用户及宠物概览",
  })
  @ApiParam({ name: "conversationId", description: "咨询会话唯一标识" })
  @ApiResponse({ status: 200, description: "成功返回用户及宠物档案" })
  @ApiResponse({ status: 403, description: "该会话不属于当前医生" })
  @Roles("DOCTOR")
  async getDoctorPatient(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
  ) {
    return this.doctorPatientRecordService.getPatient(conversationId, user.id);
  }

  @Get("doctor/sessions/:conversationId/history")
  @ApiOperation({
    summary: "获取咨询用户与当前医生的历史咨询",
    description: "按咨询会话分页返回当前会话之前的已持久化聊天记录摘要",
  })
  @ApiParam({ name: "conversationId", description: "当前咨询会话唯一标识" })
  @ApiQuery({ name: "page", required: false, description: "页码" })
  @ApiQuery({ name: "pageSize", required: false, description: "每页数量" })
  @ApiResponse({ status: 200, description: "成功返回历史咨询列表" })
  @ApiResponse({ status: 403, description: "当前会话不属于登录医生" })
  @Roles("DOCTOR")
  async getDoctorPatientHistory(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
  ) {
    return this.doctorPatientRecordService.getHistory(
      conversationId,
      user.id,
      this.parsePage(page),
      this.parsePageSize(pageSize),
    );
  }

  @Get(
    "doctor/sessions/:conversationId/history/:historyConversationId/messages",
  )
  @ApiOperation({ summary: "获取历史咨询的只读聊天消息" })
  @ApiParam({ name: "conversationId", description: "当前咨询会话唯一标识" })
  @ApiParam({
    name: "historyConversationId",
    description: "历史咨询会话唯一标识",
  })
  @ApiQuery({ name: "page", required: false, description: "页码" })
  @ApiQuery({ name: "pageSize", required: false, description: "每页数量" })
  @ApiResponse({ status: 200, description: "成功返回历史消息" })
  @ApiResponse({ status: 404, description: "历史咨询不存在或不匹配" })
  @Roles("DOCTOR")
  async getDoctorPatientHistoryMessages(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Param("historyConversationId") historyConversationId: string,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
  ) {
    return this.doctorPatientRecordService.getHistoryMessages(
      conversationId,
      historyConversationId,
      user.id,
      this.parsePage(page),
      this.parseHistoryMessagePageSize(pageSize),
    );
  }

  @Get("doctor/sessions/:conversationId/pets/:petId/ai-reports")
  @ApiOperation({ summary: "获取咨询用户指定宠物的 AI 问诊报告" })
  @ApiParam({ name: "conversationId", description: "咨询会话唯一标识" })
  @ApiParam({ name: "petId", description: "宠物 ID" })
  @ApiQuery({ name: "page", required: false, description: "页码" })
  @ApiQuery({ name: "pageSize", required: false, description: "每页数量" })
  @Roles("DOCTOR")
  async getDoctorPatientAiReports(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Param("petId", ParseIntPipe) petId: number,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
  ) {
    return this.doctorPatientRecordService.getAiReports(
      conversationId,
      user.id,
      petId,
      this.parsePage(page),
      this.parsePageSize(pageSize),
    );
  }

  @Get("doctor/sessions/:conversationId/ai-reports/:reportId")
  @ApiOperation({ summary: "获取咨询用户的 AI 问诊报告详情" })
  @Roles("DOCTOR")
  async getDoctorPatientAiReport(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Param("reportId", ParseIntPipe) reportId: number,
  ) {
    return this.doctorPatientRecordService.getAiReport(
      conversationId,
      user.id,
      reportId,
    );
  }

  @Get("doctor/sessions/:conversationId/pets/:petId/care-plan")
  @ApiOperation({ summary: "获取咨询用户指定宠物的护理建议" })
  @ApiParam({ name: "conversationId", description: "咨询会话唯一标识" })
  @ApiParam({ name: "petId", description: "宠物 ID" })
  @ApiResponse({ status: 200, description: "成功返回只读护理建议" })
  @ApiResponse({ status: 404, description: "宠物不存在或不属于会话用户" })
  @Roles("DOCTOR")
  async getDoctorPatientCarePlan(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Param("petId", ParseIntPipe) petId: number,
  ) {
    return this.doctorPatientRecordService.getCarePlan(
      conversationId,
      user.id,
      petId,
    );
  }

  @Get("doctor/sessions/:conversationId/pets/:petId/appointments")
  @ApiOperation({
    summary: "获取咨询用户指定宠物的健康档案",
    description: "健康档案复用现有疫苗、驱虫和体检预约记录",
  })
  @ApiParam({ name: "conversationId", description: "咨询会话唯一标识" })
  @ApiParam({ name: "petId", description: "宠物 ID" })
  @ApiQuery({ name: "page", required: false, description: "页码" })
  @ApiQuery({ name: "pageSize", required: false, description: "每页数量" })
  @Roles("DOCTOR")
  async getDoctorPatientAppointments(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Param("petId", ParseIntPipe) petId: number,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
  ) {
    return this.doctorPatientRecordService.getAppointments(
      conversationId,
      user.id,
      petId,
      this.parsePage(page),
      this.parsePageSize(pageSize),
    );
  }

  @Get("doctor/sessions/:conversationId/appointments/:appointmentId")
  @ApiOperation({
    summary: "获取咨询用户的健康档案详情",
    description: "使用现有健康预约 ID 读取档案详情",
  })
  @Roles("DOCTOR")
  async getDoctorPatientAppointment(
    @CurrentUser() user: CurrentUserData,
    @Param("conversationId") conversationId: string,
    @Param("appointmentId", ParseIntPipe) appointmentId: number,
  ) {
    return this.doctorPatientRecordService.getAppointment(
      conversationId,
      user.id,
      appointmentId,
    );
  }

  private parsePage(value?: string): number {
    return Math.max(1, Number.parseInt(value || "1", 10) || 1);
  }

  private parsePageSize(value?: string): number {
    return Math.min(50, Math.max(1, Number.parseInt(value || "20", 10) || 20));
  }

  private parseHistoryMessagePageSize(value?: string): number {
    return Math.min(100, Math.max(1, Number.parseInt(value || "50", 10) || 50));
  }

  // ========== 调试工具 ==========

  @Get("debug/room-state")
  @ApiOperation({
    summary: "🔍 调试：查看房间状态",
    description: "查看指定会话房间中的客户端信息，用于诊断消息广播问题",
  })
  @ApiQuery({
    name: "conversationId",
    required: true,
    description: "会话ID",
    example: "1_2",
  })
  @ApiResponse({ status: 200, description: "成功返回房间状态" })
  @ApiResponse({ status: 401, description: "未授权" })
  @Roles("SUPER_ADMIN")
  async debugRoomState(@Query("conversationId") conversationId: string) {
    if (process.env.NODE_ENV === "production") {
      throw new NotFoundException("调试接口未开放");
    }

    return this.chatGateway.debugRoomState(conversationId);
  }
}
