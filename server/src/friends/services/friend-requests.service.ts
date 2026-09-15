import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Cron, CronExpression } from "@nestjs/schedule";
import { Repository } from "typeorm";
import {
  FriendRequest,
  FriendRequestStatus,
} from "../entities/friend-request.entity";
import { User } from "../../users/entities/user.entity";
import {
  SendFriendRequestDto,
  RejectFriendRequestDto,
  QueryFriendRequestsDto,
} from "../dto/friend-request.dto";
import { PaginatedResult } from "../../common/dto/pagination.dto";
import { FriendsService } from "./friends.service";
import { FriendsGateway } from "../gateways/friends.gateway";
import { FriendChatBlocksService } from "./friend-chat-blocks.service";

export type SendFriendRequestStatus =
  | "sent"
  | "self"
  | "already_friends"
  | "incoming_pending"
  | "outgoing_pending";

export interface SendFriendRequestResult {
  success: boolean;
  status: SendFriendRequestStatus;
  message: string;
  requestId?: number;
}

/**
 * 好友申请管理服务
 *
 * 功能：
 * - 发送好友申请
 * - 接受好友申请
 * - 拒绝好友申请
 * - 查询好友申请列表
 * - 处理过期申请
 */
@Injectable()
export class FriendRequestsService {
  private readonly logger = new Logger(FriendRequestsService.name);

  constructor(
    @InjectRepository(FriendRequest)
    private friendRequestRepository: Repository<FriendRequest>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private friendsService: FriendsService,
    private friendsGateway: FriendsGateway,
    private friendChatBlocksService: FriendChatBlocksService,
  ) {}

  /**
   * 发送好友申请
   *
   * @param requesterId 申请人ID
   * @param dto 申请信息
   * @returns 创建或更新的好友申请
   */
  async sendFriendRequest(
    requesterId: number,
    dto: SendFriendRequestDto,
  ): Promise<SendFriendRequestResult> {
    const { receiverId, message } = dto;

    // 验证不能给自己发送好友申请
    if (requesterId === receiverId) {
      return {
        success: false,
        status: "self",
        message: "不能给自己发送好友申请",
      };
    }

    const requester = await this.userRepository.findOne({
      where: { id: requesterId },
    });
    if (!requester) {
      throw new NotFoundException("申请人不存在");
    }

    // 验证接收人是否存在
    const receiver = await this.userRepository.findOne({
      where: { id: receiverId },
    });
    if (!receiver) {
      throw new NotFoundException("接收人不存在");
    }

    await this.friendChatBlocksService.assertUsersCanBecomeFriends(
      requesterId,
      receiverId,
    );

    // 检查是否已经是好友
    const isFriend = await this.friendsService.isFriend(
      requesterId,
      receiverId,
    );
    if (isFriend) {
      return {
        success: false,
        status: "already_friends",
        message: "已经是好友，无需重复申请",
      };
    }

    /**
     * 检查对向是否已有待处理申请
     * 业务规则：双方互相发起申请时，应该引导后发起方直接处理已有申请，而不是制造第二条 pending 记录。
     */
    const reversePendingRequest = await this.friendRequestRepository.findOne({
      where: {
        requesterId: receiverId,
        receiverId: requesterId,
        status: FriendRequestStatus.PENDING,
      },
      order: { updatedAt: "DESC" },
    });

    if (reversePendingRequest) {
      return {
        success: false,
        status: "incoming_pending",
        message: "对方已向你发送好友申请，请直接处理对方申请",
      };
    }

    // 检查是否存在历史申请记录
    const existingRequest = await this.friendRequestRepository.findOne({
      where: {
        requesterId,
        receiverId,
      },
      order: { updatedAt: "DESC" },
    });

    if (
      existingRequest &&
      existingRequest.status === FriendRequestStatus.PENDING &&
      new Date(existingRequest.expiresAt) > new Date()
    ) {
      return {
        success: false,
        status: "outgoing_pending",
        requestId: existingRequest.id,
        message: "好友申请已发送，请耐心等待对方处理",
      };
    }

    // 更新过期时间（7天后）
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    if (existingRequest) {
      existingRequest.message = message || null;
      existingRequest.expiresAt = expiresAt;
      existingRequest.status = FriendRequestStatus.PENDING;
      existingRequest.rejectionReason = null;

      const savedRequest =
        await this.friendRequestRepository.save(existingRequest);

      this.friendsGateway.emitFriendRequestNew(receiverId, {
        id: savedRequest.id,
        requestId: savedRequest.id.toString(),
        requesterId,
        requesterName: requester.username,
        requesterAvatar: requester.avatar,
        requesterPhone: requester.phone,
        message: savedRequest.message,
        status: savedRequest.status,
        createdAt: savedRequest.createdAt,
        expiresAt: savedRequest.expiresAt,
      });

      return {
        success: true,
        status: "sent",
        requestId: savedRequest.id,
        message: "好友申请已发送",
      };
    }

    // 创建新申请
    const friendRequest = this.friendRequestRepository.create({
      requesterId,
      receiverId,
      message: message || null,
      status: FriendRequestStatus.PENDING,
      expiresAt,
    });

    const savedRequest = await this.friendRequestRepository.save(friendRequest);

    this.friendsGateway.emitFriendRequestNew(receiverId, {
      id: savedRequest.id,
      requestId: savedRequest.id.toString(),
      requesterId,
      requesterName: requester.username,
      requesterAvatar: requester.avatar,
      requesterPhone: requester.phone,
      message: savedRequest.message,
      status: savedRequest.status,
      createdAt: savedRequest.createdAt,
      expiresAt: savedRequest.expiresAt,
    });

    return {
      success: true,
      status: "sent",
      requestId: savedRequest.id,
      message: "好友申请已发送",
    };
  }

  /**
   * 接受好友申请
   * 创建双向好友关系
   *
   * @param requestId 申请ID
   * @param receiverId 接收人ID（验证权限）
   * @returns 创建的好友关系
   */
  async acceptFriendRequest(
    requestId: number,
    receiverId: number,
  ): Promise<any> {
    // 查询好友申请
    const friendRequest = await this.friendRequestRepository.findOne({
      where: { id: requestId },
      relations: ["requester", "receiver"],
    });

    if (!friendRequest) {
      throw new NotFoundException("好友申请不存在");
    }

    // 验证权限（只有接收人可以接受申请）
    if (friendRequest.receiverId !== receiverId) {
      throw new BadRequestException("无权操作此申请");
    }

    // 验证申请状态
    if (friendRequest.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException("申请已处理或已过期");
    }

    // 验证申请是否过期
    if (new Date() > friendRequest.expiresAt) {
      // 标记为过期
      friendRequest.status = FriendRequestStatus.EXPIRED;
      await this.friendRequestRepository.save(friendRequest);
      throw new BadRequestException("申请已过期");
    }

    await this.friendChatBlocksService.assertUsersCanBecomeFriends(
      friendRequest.requesterId,
      friendRequest.receiverId,
    );

    // 使用事务处理
    const queryRunner =
      this.friendRequestRepository.manager.connection.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 更新申请状态为已接受
      friendRequest.status = FriendRequestStatus.ACCEPTED;
      await queryRunner.manager.save(friendRequest);

      // 创建双向好友关系
      const friendship = await this.friendsService.createFriendship(
        friendRequest.requesterId,
        friendRequest.receiverId,
        queryRunner.manager,
      );

      await queryRunner.commitTransaction();

      this.friendsGateway.emitFriendRequestAccepted(friendRequest.requesterId, {
        requestId: friendRequest.id.toString(),
        friendId: friendRequest.receiverId,
        friendName: friendRequest.receiver.username,
        acceptedAt: friendRequest.updatedAt,
      });

      return {
        friendRequest,
        friendship,
      };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 拒绝好友申请
   *
   * @param requestId 申请ID
   * @param receiverId 接收人ID（验证权限）
   * @param dto 拒绝原因（兼容旧客户端，可为空）
   */
  async rejectFriendRequest(
    requestId: number,
    receiverId: number,
    dto?: RejectFriendRequestDto,
  ): Promise<void> {
    // 查询好友申请
    const friendRequest = await this.friendRequestRepository.findOne({
      where: { id: requestId },
    });

    if (!friendRequest) {
      throw new NotFoundException("好友申请不存在");
    }

    // 验证权限（只有接收人可以拒绝申请）
    if (friendRequest.receiverId !== receiverId) {
      throw new BadRequestException("无权操作此申请");
    }

    // 验证申请状态
    if (friendRequest.status !== FriendRequestStatus.PENDING) {
      throw new BadRequestException("申请已处理或已过期");
    }

    // 更新申请状态为已拒绝
    friendRequest.status = FriendRequestStatus.REJECTED;
    // 兼容未传请求体的客户端，避免因为可选字段缺失导致拒绝流程中断。
    friendRequest.rejectionReason = dto?.reason || null;
    await this.friendRequestRepository.save(friendRequest);

    const receiver = await this.userRepository.findOne({
      where: { id: receiverId },
    });

    this.friendsGateway.emitFriendRequestRejected(friendRequest.requesterId, {
      requestId: friendRequest.id.toString(),
      receiverId,
      receiverName: receiver?.username,
      reason: friendRequest.rejectionReason,
      rejectedAt: friendRequest.updatedAt,
    });
  }

  /**
   * 定时处理过期申请
   * 业务规则：文档已声明申请会自动过期，因此这里按小时兜底执行一次状态收敛。
   */
  @Cron(CronExpression.EVERY_HOUR)
  async handleExpiredRequestsBySchedule(): Promise<void> {
    const affectedCount = await this.handleExpiredRequests();

    if (affectedCount > 0) {
      this.logger.log(`已自动处理 ${affectedCount} 条过期好友申请`);
    }
  }

  /**
   * 获取好友申请列表（接收到的申请）
   *
   * @param receiverId 接收人ID
   * @param query 查询参数
   * @returns 分页后的申请列表
   */
  async getFriendRequests(
    receiverId: number,
    query: QueryFriendRequestsDto,
  ): Promise<PaginatedResult<any>> {
    const { page = 1, pageSize = 20, status } = query;

    // 构建查询
    const queryBuilder = this.friendRequestRepository
      .createQueryBuilder("request")
      .leftJoinAndSelect("request.requester", "requester")
      .where("request.receiverId = :receiverId", { receiverId });

    // 状态筛选
    if (status) {
      queryBuilder.andWhere("request.status = :status", { status });
    }

    // 排序：待处理的在前，按创建时间倒序
    queryBuilder
      .orderBy("request.status", "ASC")
      .addOrderBy("request.createdAt", "DESC");

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 执行查询
    const [requests, total] = await queryBuilder.getManyAndCount();

    // 格式化返回数据
    const data = requests.map((request) => ({
      id: request.id,
      requestId: request.id.toString(),
      requesterId: request.requesterId,
      requesterName: request.requester.username,
      requesterAvatar: request.requester.avatar,
      requesterPhone: request.requester.phone,
      message: request.message,
      status: request.status,
      rejectionReason: request.rejectionReason,
      expiresAt: request.expiresAt,
      createdAt: request.createdAt,
    }));

    return {
      totalPages: Math.ceil(total / pageSize),
      data,
      total,
      page,
      pageSize,
    };
  }

  /**
   * 获取好友关系摘要
   * 社区主页只需要轻量关系状态，不应该为一个按钮去拉整页好友或申请列表。
   */
  async getRelationshipSummary(
    currentUserId: number,
    targetUserId: number,
  ): Promise<{
    isFriend: boolean;
    outgoingPending: boolean;
    incomingPending: boolean;
    blockedByMe: boolean;
    canSendMessage: boolean;
  }> {
    const [
      isFriend,
      outgoingPending,
      incomingPending,
      blockedByMe,
      hasChatBlock,
    ] = await Promise.all([
      this.friendsService.isFriend(currentUserId, targetUserId),
      this.friendRequestRepository.exist({
        where: {
          requesterId: currentUserId,
          receiverId: targetUserId,
          status: FriendRequestStatus.PENDING,
        },
      }),
      this.friendRequestRepository.exist({
        where: {
          requesterId: targetUserId,
          receiverId: currentUserId,
          status: FriendRequestStatus.PENDING,
        },
      }),
      this.friendChatBlocksService.isBlockedBy(currentUserId, targetUserId),
      this.friendChatBlocksService.hasBlockBetween(currentUserId, targetUserId),
    ]);

    return {
      isFriend,
      outgoingPending,
      incomingPending,
      blockedByMe,
      canSendMessage: isFriend && !hasChatBlock,
    };
  }

  /**
   * 处理过期申请（定时任务调用）
   * 将过期的待处理申请标记为已过期
   */
  async handleExpiredRequests(): Promise<number> {
    const result = await this.friendRequestRepository
      .createQueryBuilder()
      .update(FriendRequest)
      .set({ status: FriendRequestStatus.EXPIRED })
      .where("status = :status", { status: FriendRequestStatus.PENDING })
      .andWhere("expiresAt < :now", { now: new Date() })
      .execute();

    return result.affected || 0;
  }

  /**
   * Admin 查询所有好友申请（分页）
   *
   * @param query 查询参数
   * @returns 分页后的申请列表
   */
  async adminGetFriendRequests(query: any): Promise<any> {
    const { page = 1, pageSize = 20, status, requesterId, receiverId } = query;

    // 构建查询
    const queryBuilder = this.friendRequestRepository
      .createQueryBuilder("request")
      .leftJoinAndSelect("request.requester", "requester")
      .leftJoinAndSelect("request.receiver", "receiver");

    // 筛选条件
    if (status) {
      queryBuilder.andWhere("request.status = :status", { status });
    }

    if (requesterId) {
      queryBuilder.andWhere("request.requesterId = :requesterId", {
        requesterId,
      });
    }

    if (receiverId) {
      queryBuilder.andWhere("request.receiverId = :receiverId", { receiverId });
    }

    // 排序：按创建时间倒序
    queryBuilder.orderBy("request.createdAt", "DESC");

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 执行查询
    const [requests, total] = await queryBuilder.getManyAndCount();

    // 格式化返回数据
    const data = requests.map((request) => ({
      id: request.id,
      requestId: request.id.toString(),
      requesterId: request.requesterId,
      requesterName: request.requester.username,
      requesterAvatar: request.requester.avatar,
      receiverId: request.receiverId,
      receiverName: request.receiver.username,
      receiverAvatar: request.receiver.avatar,
      message: request.message,
      status: request.status,
      rejectionReason: request.rejectionReason,
      expiresAt: request.expiresAt,
      createdAt: request.createdAt,
    }));

    return {
      totalPages: Math.ceil(total / pageSize),
      data,
      total,
      page,
      pageSize,
    };
  }

  /**
   * 获取待处理申请数量
   *
   * @returns 待处理申请数量
   */
  async getPendingRequestsCount(): Promise<number> {
    return this.friendRequestRepository.count({
      where: { status: FriendRequestStatus.PENDING },
    });
  }
}
