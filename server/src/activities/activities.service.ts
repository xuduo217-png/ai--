import { Injectable, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Not, Repository } from 'typeorm';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { createBusinessException, ErrorCode } from '../common/constants/error-codes';
import { Activity, ActivityStatus, ActivityType } from './entities/activity.entity';
import { ActivityComment } from './entities/activity-comment.entity';
import { ActivityRegistration } from './entities/activity-registration.entity';
import { ActivityVoteOption } from './entities/activity-vote-option.entity';
import { ActivityVoteOptionDto, CreateActivityDto } from './dto/create-activity.dto';
import { UpdateActivityDto } from './dto/update-activity.dto';
import { QueryActivityDto } from './dto/query-activity.dto';
import { RegisterActivityDto } from './dto/register-activity.dto';
import { CreateActivityCommentDto } from './dto/create-activity-comment.dto';
import { UserVoteOptionDto } from './dto/user-vote-option.dto';
import { User } from '../users/entities/user.entity';
import { ModerationService } from '../moderation/moderation.service';

export interface ActivityParticipant {
  userId: number;
  userName: string;
  userAvatar?: string;
  registeredAt: number;
}

export interface ActivityCommentResponseUser {
  id: number;
  nickname: string;
  avatar?: string;
}

export interface ActivityCommentResponse {
  id: number;
  activityId: number;
  voteOptionId: number | null;
  userId: number;
  content: string;
  parentId?: number;
  likeCount: number;
  createdAt: Date;
  user?: ActivityCommentResponseUser;
  replies?: ActivityCommentResponse[];
}

/**
 * 活动服务
 *
 * 处理活动管理的业务逻辑
 * - 活动管理（创建、编辑、删除）
 * - 用户报名（防重复）
 * - 活动状态实时计算
 */
@Injectable()
export class ActivitiesService {
  private readonly DEFAULT_COMMENT_REPLY_LIMIT = 10;

  constructor(
    @InjectRepository(Activity)
    private activityRepository: Repository<Activity>,
    @InjectRepository(ActivityComment)
    private activityCommentRepository: Repository<ActivityComment>,
    @InjectRepository(ActivityRegistration)
    private registrationRepository: Repository<ActivityRegistration>,
    @InjectRepository(ActivityVoteOption)
    private voteOptionRepository: Repository<ActivityVoteOption>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @Optional()
    private readonly moderationService?: ModerationService,
  ) {}

  // ==================== 活动管理（管理员） ====================

  /**
   * 创建活动
   */
  async create(createActivityDto: CreateActivityDto): Promise<Activity> {
    // 处理时间：将日期字符串转换为时间戳（秒）
    const startDate = new Date(createActivityDto.startTime);
    startDate.setHours(0, 0, 0, 0);
    const startTime = Math.floor(startDate.getTime() / 1000);

    const endDate = new Date(createActivityDto.endTime);
    endDate.setHours(23, 59, 59, 999);
    const endTime = Math.floor(endDate.getTime() / 1000);

    // 验证开始时间不能晚于结束时间
    if (startTime > endTime) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '开始时间不能晚于结束时间');
    }

    const activityType = createActivityDto.activityType ?? ActivityType.OFFLINE;
    const location = this.resolveActivityLocation(activityType, createActivityDto.location);

    const voteOptions = this.normalizeVoteOptions(activityType, createActivityDto.voteOptions);
    const now = Date.now();
    const { voteOptions: _unusedVoteOptions, ...activityData } = createActivityDto;

    return await this.activityRepository.manager.transaction(async (manager) => {
      const activityRepository = manager.getRepository(Activity);
      const voteOptionRepository = manager.getRepository(ActivityVoteOption);

      const activity = activityRepository.create({
        ...activityData,
        activityType,
        location,
        coverImage: createActivityDto.coverImage ?? '',
        sharePosterImage: createActivityDto.sharePosterImage ?? '',
        sharePosterTitle: createActivityDto.sharePosterTitle ?? '',
        sharePosterDescription: createActivityDto.sharePosterDescription ?? '',
        showOnHome: createActivityDto.showOnHome ?? false,
        startTime,
        endTime,
        createdAt: now,
        updatedAt: now,
      });

      const savedActivity = await activityRepository.save(activity);

      if (activityType === ActivityType.ONLINE) {
        await voteOptionRepository.save(
          voteOptions.map((option, index) =>
            voteOptionRepository.create({
              activityId: savedActivity.id,
              image: option.image,
              video: option.video,
              videoCover: option.videoCover,
              title: option.title,
              description: option.description,
              voteCount: option.voteCount ?? 0,
              sortOrder: option.sortOrder ?? index,
              ownerUserId: option.ownerUserId ?? null,
              createdAt: now,
              updatedAt: now,
            }),
          ),
        );
      }

      savedActivity.voteOptions = activityType === ActivityType.ONLINE
        ? await this.loadVoteOptions(savedActivity.id, voteOptionRepository)
        : [];

      return savedActivity;
    });
  }

  /**
   * 获取活动列表（管理员）
   */
  async findAll(queryDto: QueryActivityDto): Promise<PaginatedResult<Activity>> {
    const {
      page = 1,
      pageSize = 10,
      hospitalId,
      startDate,
      status,
      keyword,
      showOnHome,
      deleteStatus = 'active',
    } = queryDto;

    const query = this.activityRepository.createQueryBuilder('activity')
      .leftJoinAndSelect('activity.hospital', 'hospital');

    if (deleteStatus === 'deleted') {
      query.withDeleted().andWhere('activity.deletedAt IS NOT NULL');
    } else if (deleteStatus === 'all') {
      query.withDeleted();
    }

    // 医院筛选
    if (hospitalId) {
      query.andWhere('activity.hospitalId = :hospitalId', { hospitalId });
    }

    // 状态筛选（实时计算）
    const now = Math.floor(Date.now() / 1000);
    if (status === ActivityStatus.UPCOMING) {
      query.andWhere('activity.startTime > :now', { now });
    } else if (status === ActivityStatus.ONGOING) {
      query.andWhere('activity.startTime <= :now', { now })
        .andWhere('activity.endTime > :now', { now });
    } else if (status === ActivityStatus.EXPIRED) {
      query.andWhere('activity.endTime <= :now', { now });
    }

    // 开始日期筛选
    if (startDate) {
      const startTimestamp = Math.floor(new Date(startDate).setHours(0, 0, 0, 0) / 1000);
      query.andWhere('activity.startTime >= :startDate', { startDate: startTimestamp });
    }

    // 关键词搜索
    if (keyword) {
      query.andWhere('activity.title LIKE :keyword', { keyword: `%${keyword}%` });
    }

    // 首页展示筛选
    if (showOnHome !== undefined) {
      query.andWhere('activity.showOnHome = :showOnHome', { showOnHome });
    }

    query.orderBy('activity.createdAt', 'DESC');

    const [data, total] = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    // 为每个活动计算状态和报名人数
    for (const activity of data) {
      this.calculateActivityStatus(activity);
      // 获取报名人数（实时 COUNT）
      activity.registrationCount = await this.registrationRepository.count({
        where: { activityId: activity.id }
      });
      activity.commentCount = activity.activityType === ActivityType.ONLINE
        ? await this.activityCommentRepository.count({
            where: { activityId: activity.id },
          })
        : 0;
      // 添加医院名称
      activity.hospitalName = activity.hospital?.name;
      if (activity.activityType === ActivityType.ONLINE) {
        activity.voteOptions = await this.loadVoteOptions(
          activity.id,
          this.voteOptionRepository,
        );
      } else {
        activity.voteOptions = [];
      }
      // 添加完整的医院信息（用于编辑时回显）
      if (activity.hospital) {
        activity.hospitalData = {
          id: activity.hospital.id,
          name: activity.hospital.name,
          logo: activity.hospital.logo,
          city: activity.hospital.city,
          address: activity.hospital.address,
          phone: activity.hospital.phone
        };
      }
    }

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取活动详情（管理员）
   */
  async findOne(id: number): Promise<Activity> {
    const activity = await this.activityRepository.findOne({
      where: { id },
      relations: ['hospital', 'voteOptions'],
      order: {
        voteOptions: {
          sortOrder: 'ASC',
          id: 'ASC',
        },
      },
    });

    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    // 添加医院名称
    activity.hospitalName = activity.hospital?.name;
    // 添加完整的医院信息（用于编辑时回显）
    if (activity.hospital) {
      activity.hospitalData = {
        id: activity.hospital.id,
        name: activity.hospital.name,
        logo: activity.hospital.logo,
        city: activity.hospital.city,
        address: activity.hospital.address,
        phone: activity.hospital.phone
      };
    }

    return activity;
  }

  /**
   * 更新活动
   */
  async update(id: number, updateActivityDto: UpdateActivityDto): Promise<Activity> {
    const activity = await this.activityRepository.findOne({ where: { id } });
    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    // 处理时间
    let startTime = activity.startTime;
    let endTime = activity.endTime;

    if (updateActivityDto.startTime) {
      const startDate = new Date(updateActivityDto.startTime);
      startDate.setHours(0, 0, 0, 0);
      startTime = Math.floor(startDate.getTime() / 1000);
    }

    if (updateActivityDto.endTime) {
      const endDate = new Date(updateActivityDto.endTime);
      endDate.setHours(23, 59, 59, 999);
      endTime = Math.floor(endDate.getTime() / 1000);
    }

    // 验证时间
    if (startTime > endTime) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '开始时间不能晚于结束时间');
    }

    const nextActivityType = updateActivityDto.activityType ?? activity.activityType ?? ActivityType.OFFLINE;
    const nextLocation =
      updateActivityDto.location !== undefined ? updateActivityDto.location : activity.location;
    const location = this.resolveActivityLocation(nextActivityType, nextLocation);

    let voteOptions: ActivityVoteOptionDto[] | undefined;
    const isSwitchingToOnline =
      activity.activityType !== ActivityType.ONLINE && nextActivityType === ActivityType.ONLINE;
    if (nextActivityType === ActivityType.ONLINE && (updateActivityDto.voteOptions !== undefined || isSwitchingToOnline)) {
      voteOptions = this.normalizeVoteOptions(nextActivityType, updateActivityDto.voteOptions);
    } else if (updateActivityDto.voteOptions !== undefined) {
      voteOptions = this.normalizeVoteOptions(nextActivityType, updateActivityDto.voteOptions);
    }
    const { voteOptions: _unusedVoteOptions, ...activityData } = updateActivityDto;
    const now = Date.now();

    return await this.activityRepository.manager.transaction(async (manager) => {
      const activityRepository = manager.getRepository(Activity);
      const voteOptionRepository = manager.getRepository(ActivityVoteOption);

      Object.assign(activity, activityData, {
        activityType: nextActivityType,
        location,
        startTime,
        endTime,
        coverImage: updateActivityDto.coverImage ?? activity.coverImage ?? '',
        sharePosterImage: updateActivityDto.sharePosterImage ?? activity.sharePosterImage ?? '',
        sharePosterTitle: updateActivityDto.sharePosterTitle ?? activity.sharePosterTitle ?? '',
        sharePosterDescription:
          updateActivityDto.sharePosterDescription ?? activity.sharePosterDescription ?? '',
        updatedAt: now,
      });

      const savedActivity = await activityRepository.save(activity);

      if (voteOptions !== undefined || nextActivityType !== ActivityType.ONLINE) {
        await voteOptionRepository.delete({ activityId: id });
      }

      if (nextActivityType === ActivityType.ONLINE && voteOptions !== undefined) {
        await voteOptionRepository.save(
          voteOptions.map((option, index) =>
            voteOptionRepository.create({
              id: option.id,
              activityId: id,
              image: option.image,
              video: option.video,
              videoCover: option.videoCover,
              title: option.title,
              description: option.description,
              voteCount: option.voteCount ?? 0,
              sortOrder: option.sortOrder ?? index,
              ownerUserId: option.ownerUserId ?? null,
              createdAt: now,
              updatedAt: now,
            }),
          ),
        );
      }

      savedActivity.voteOptions = nextActivityType === ActivityType.ONLINE
        ? await this.loadVoteOptions(id, voteOptionRepository)
        : [];

      return savedActivity;
    });
  }

  /**
   * 删除活动
   */
  async remove(id: number): Promise<void> {
    const activity = await this.activityRepository.findOne({ where: { id } });
    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    await this.activityRepository.softDelete(id);
  }

  /**
   * 获取活动的报名用户列表（管理员）
   */
  async getRegistrations(
    activityId: number,
    page: number = 1,
    pageSize: number = 10,
    voteOptionId?: number,
  ): Promise<PaginatedResult<ActivityRegistration>> {
    const { data, total } = await this.loadParticipantRows(activityId, page, pageSize, voteOptionId);

    // 添加用户信息
    for (const registration of data) {
      registration.userName = registration.user?.username || registration.phone;
      registration.userAvatar = registration.user?.avatar;
    }

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取活动参与者列表（用户端）
   */
  async getParticipants(
    activityId: number,
    page: number = 1,
    pageSize: number = 10,
  ): Promise<PaginatedResult<ActivityParticipant>> {
    const { data, total } = await this.loadParticipantRows(activityId, page, pageSize);

    return {
      data: data.map((registration) => ({
        userId: registration.userId,
        userName: registration.user?.username || '匿名用户',
        userAvatar: registration.user?.avatar,
        registeredAt: registration.registeredAt,
      })),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 创建活动评论
   */
  async createActivityComment(
    userId: number,
    activityId: number,
    dto: CreateActivityCommentDto,
    voteOptionId?: number,
  ): Promise<ActivityCommentResponse> {
    await this.ensureOnlineActivitySupportsComments(activityId);
    await this.ensureVoteOptionBelongsToActivity(activityId, voteOptionId);

    if (voteOptionId !== undefined && voteOptionId !== null) {
      const voteOption = await this.voteOptionRepository.findOne({
        where: { id: voteOptionId, activityId },
        select: ['id', 'ownerUserId'],
      });
      if (voteOption?.ownerUserId) {
        await this.moderationService?.assertUsersCanInteract(
          userId,
          voteOption.ownerUserId,
        );
      }
    }

    const content = String(dto.content ?? '').trim();
    if (!content) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '评论内容不能为空');
    }

    if (dto.parentId !== undefined && dto.parentId !== null) {
      const parentComment = await this.activityCommentRepository.findOne({
        where: {
          id: dto.parentId,
          activityId,
          voteOptionId: voteOptionId ?? IsNull(),
        },
        select: ['id', 'userId'],
      });

      if (!parentComment) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '父评论不存在');
      }

      await this.moderationService?.assertUsersCanInteract(
        userId,
        parentComment.userId,
      );
    }

    const currentUser = await this.userRepository.findOne({
      where: { id: userId },
      select: ['id', 'username', 'phone', 'avatar'],
    });

    if (!currentUser) {
      throw createBusinessException(ErrorCode.USER_NOT_FOUND, '用户不存在');
    }

    const comment = this.activityCommentRepository.create({
      activityId,
      userId,
      content,
      parentId: dto.parentId,
      voteOptionId: voteOptionId ?? null,
    });

    const savedComment = await this.activityCommentRepository.save(comment);

    return this.toActivityCommentResponse({
      ...savedComment,
      user: currentUser,
    });
  }

  /**
   * 获取活动评论列表
   */
  async findActivityComments(
    activityId: number,
    page: number = 1,
    pageSize: number = 20,
    voteOptionId?: number,
    currentUserId?: number,
  ): Promise<PaginatedResult<ActivityCommentResponse>> {
    await this.ensureOnlineActivitySupportsComments(activityId);
    await this.ensureVoteOptionBelongsToActivity(activityId, voteOptionId);

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    const visibleAuthorFilter = blockedUserIds?.length
      ? { userId: Not(In(blockedUserIds)) }
      : {};

    const [comments, total] = await this.activityCommentRepository.findAndCount({
      where: {
        activityId,
        voteOptionId: voteOptionId ?? IsNull(),
        parentId: IsNull(),
        ...visibleAuthorFilter,
      },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: pageSize,
      skip: (page - 1) * pageSize,
    });

    if (comments.length > 0) {
      const parentIds = comments.map((comment) => comment.id);
      const replies = await this.activityCommentRepository.find({
        where: {
          activityId,
          voteOptionId: voteOptionId ?? IsNull(),
          parentId: In(parentIds),
          ...visibleAuthorFilter,
        },
        relations: ['user'],
        order: { createdAt: 'ASC' },
        take: this.DEFAULT_COMMENT_REPLY_LIMIT,
      });

      const repliesMap = new Map<number, ActivityComment[]>();
      replies.forEach((reply) => {
        if (!reply.parentId) {
          return;
        }

        const existingReplies = repliesMap.get(reply.parentId) || [];
        existingReplies.push(reply);
        repliesMap.set(reply.parentId, existingReplies);
      });

      comments.forEach((comment) => {
        (comment as any).replies = repliesMap.get(comment.id) || [];
      });
    }

    return {
      data: comments.map((comment) => this.toActivityCommentResponse(comment)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 删除活动评论及其下级回复
   */
  async deleteActivityComment(commentId: number): Promise<{ deletedCount: number }> {
    const comment = await this.activityCommentRepository.findOne({
      where: { id: commentId },
      select: ['id'],
    });

    if (!comment) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '评论不存在');
    }

    const idsToDelete = await this.collectActivityCommentDescendantIds(commentId);
    const result = await this.activityCommentRepository.softDelete(idsToDelete);

    return {
      deletedCount: result.affected ?? idsToDelete.length,
    };
  }

  // ==================== 用户端接口 ====================

  /**
   * 获取活动列表（用户端）
   */
  async findUserActivities(
    queryDto: QueryActivityDto,
    userId?: number,
  ): Promise<PaginatedResult<Activity>> {
    const { page = 1, pageSize = 10, status, keyword, showOnHome } = queryDto;

    const query = this.activityRepository.createQueryBuilder('activity')
      .leftJoinAndSelect('activity.hospital', 'hospital')
      .where('activity.deletedAt IS NULL');

    // 状态筛选（实时计算）
    const now = Math.floor(Date.now() / 1000);
    if (status === ActivityStatus.UPCOMING) {
      query.andWhere('activity.startTime > :now', { now });
    } else if (status === ActivityStatus.ONGOING) {
      query.andWhere('activity.startTime <= :now', { now })
        .andWhere('activity.endTime > :now', { now });
    } else if (status === ActivityStatus.EXPIRED) {
      query.andWhere('activity.endTime <= :now', { now });
    }

    // 关键词搜索
    if (keyword) {
      query.andWhere('activity.title LIKE :keyword', { keyword: `%${keyword}%` });
    }

    // 首页展示筛选
    if (showOnHome !== undefined) {
      query.andWhere('activity.showOnHome = :showOnHome', { showOnHome });
    }

    query.orderBy('activity.startTime', 'ASC');

    const [data, total] = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    // 为每个活动计算状态和添加用户信息
    for (const activity of data) {
      this.calculateActivityStatus(activity);

      // 获取报名人数（实时 COUNT）
      activity.registrationCount = await this.registrationRepository.count({
        where: { activityId: activity.id }
      });

      // 添加医院名称
      activity.hospitalName = activity.hospital?.name;
      if (activity.activityType === ActivityType.ONLINE) {
        activity.voteOptions = await this.loadVoteOptions(activity.id);
      } else {
        activity.voteOptions = [];
      }

      // 检查用户是否已参与：线下看是否报名过，线上看今天是否投过票
      if (userId) {
        const registration = await this.registrationRepository.findOne({
          where: this.buildParticipationWhere(activity, userId),
        });
        activity.isRegistered = !!registration;
      } else {
        activity.isRegistered = false;
      }

      // 判断是否可以报名
      activity.canRegister = !activity.isRegistered && activity.status !== ActivityStatus.EXPIRED;
    }

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取活动详情（用户端）
   */
  async findOneUser(id: number, userId?: number): Promise<Activity> {
    const activity = await this.activityRepository.findOne({
      where: { id },
      relations: ['hospital', 'voteOptions'],
      order: {
        voteOptions: {
          sortOrder: 'ASC',
          id: 'ASC',
        },
      },
    });

    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    // 计算状态
    this.calculateActivityStatus(activity);

    // 添加医院名称
    activity.hospitalName = activity.hospital?.name;

    // 获取报名人数
    activity.registrationCount = await this.registrationRepository.count({
      where: { activityId: activity.id }
    });

    // 检查用户是否已参与：线下看是否报名过，线上看今天是否投过票
    if (userId) {
      const registration = await this.registrationRepository.findOne({
        where: this.buildParticipationWhere(activity, userId),
      });
      activity.isRegistered = !!registration;
    } else {
      activity.isRegistered = false;
    }

    // 判断是否可以报名
    activity.canRegister = !activity.isRegistered && activity.status !== ActivityStatus.EXPIRED;

    if (activity.activityType === ActivityType.ONLINE) {
      activity.voteOptions = await this.loadVoteOptions(
        activity.id,
        this.voteOptionRepository,
        userId,
      );
    }

    return activity;
  }

  /**
   * 用户报名活动
   */
  async register(
    activityId: number,
    userId: number,
    registerDto: RegisterActivityDto,
  ): Promise<{ registrationId: number; registeredAt: number }> {
    // 检查活动是否存在
    const activity = await this.activityRepository.findOne({ where: { id: activityId } });
    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    // 计算活动状态
    this.calculateActivityStatus(activity);

    // 检查活动是否已结束
    if (activity.status === ActivityStatus.EXPIRED) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '活动已结束，无法报名');
    }

    if (activity.activityType === ActivityType.ONLINE) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '线上活动请使用投票');
    }

    // 检查用户是否已报名（数据库唯一索引会拦截，但这里提供友好提示）
    const existingRegistration = await this.registrationRepository.findOne({
      where: {
        activityId,
        userId,
        participationKey: this.getOfflineParticipationKey(),
      },
    });
    if (existingRegistration) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '您已经报名过该活动');
    }

    // 创建报名记录
    const registration = this.registrationRepository.create({
      activityId,
      userId,
      phone: registerDto.phone,
      participationKey: this.getOfflineParticipationKey(),
      registeredAt: Date.now(),
    });

    const saved = await this.registrationRepository.save(registration);

    // 更新活动报名人数（可选，也可以实时查询）
    activity.registrationCount = await this.registrationRepository.count({
      where: { activityId }
    });
    await this.activityRepository.save(activity);

    return {
      registrationId: saved.id,
      registeredAt: saved.registeredAt,
    };
  }

  /**
   * 用户投票活动
   */
  async vote(
    activityId: number,
    userId: number,
    optionId: number,
  ): Promise<{ voteId: number; votedAt: number; optionId: number }> {
    const activity = await this.activityRepository.findOne({ where: { id: activityId } });
    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    this.calculateActivityStatus(activity);

    if (activity.activityType !== ActivityType.ONLINE) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '线下活动不能投票');
    }

    if (activity.status === ActivityStatus.EXPIRED) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '活动已结束，无法投票');
    }

    const voteOption = await this.voteOptionRepository.findOne({
      where: { id: optionId, activityId },
    });
    if (!voteOption) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '投票选手不存在');
    }

    const participationKey = this.getTodayParticipationKey();
    const existingVote = await this.registrationRepository.findOne({
      where: { activityId, userId, participationKey }
    });
    if (existingVote) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '您今天已经投过票了');
    }

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw createBusinessException(ErrorCode.USER_NOT_FOUND, '用户不存在');
    }

    const vote = this.registrationRepository.create({
      activityId,
      userId,
      phone: user.phone,
      voteOptionId: optionId,
      participationKey,
      registeredAt: Date.now(),
    });

    const saved = await this.registrationRepository.save(vote);
    await this.voteOptionRepository.increment({ id: optionId, activityId }, 'voteCount', 1);

    activity.registrationCount = await this.registrationRepository.count({
      where: { activityId }
    });
    await this.activityRepository.save(activity);

    return {
      voteId: saved.id,
      votedAt: saved.registeredAt,
      optionId,
    };
  }

  /**
   * 用户报名线上投票活动，创建选手
   */
  async createUserVoteOption(
    activityId: number,
    userId: number,
    voteOptionDto: UserVoteOptionDto,
  ): Promise<ActivityVoteOption> {
    const activity = await this.assertOnlineVoteActivityEditable(activityId, '报名');
    const normalizedOption = this.normalizeUserVoteOption(voteOptionDto);
    const maxSortOrderResult = await this.voteOptionRepository
      .createQueryBuilder('option')
      .select('MAX(option.sortOrder)', 'maxSortOrder')
      .where('option.activityId = :activityId', { activityId })
      .getRawOne<{ maxSortOrder: string | number | null }>();
    const maxSortOrder = Number(maxSortOrderResult?.maxSortOrder ?? -1);
    const now = Date.now();

    const voteOption = this.voteOptionRepository.create({
      activityId: activity.id,
      image: normalizedOption.image,
      video: normalizedOption.video,
      videoCover: normalizedOption.videoCover,
      title: normalizedOption.title,
      description: normalizedOption.description,
      voteCount: 0,
      sortOrder: Number.isFinite(maxSortOrder) ? maxSortOrder + 1 : 0,
      ownerUserId: userId,
      createdAt: now,
      updatedAt: now,
    });

    return await this.voteOptionRepository.save(voteOption);
  }

  /**
   * 用户编辑本人添加的线上投票选手
   */
  async updateUserVoteOption(
    activityId: number,
    optionId: number,
    userId: number,
    voteOptionDto: UserVoteOptionDto,
  ): Promise<ActivityVoteOption> {
    await this.assertOnlineVoteActivityEditable(activityId, '编辑选手');

    const voteOption = await this.voteOptionRepository.findOne({
      where: { id: optionId, activityId },
    });
    if (!voteOption) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '投票选手不存在');
    }

    if (voteOption.ownerUserId !== userId) {
      throw createBusinessException(ErrorCode.BUSINESS_PERMISSION_DENIED, '只能编辑自己添加的选手');
    }

    const normalizedOption = this.normalizeUserVoteOption(voteOptionDto);

    Object.assign(voteOption, {
      image: normalizedOption.image,
      video: normalizedOption.video,
      videoCover: normalizedOption.videoCover,
      title: normalizedOption.title,
      description: normalizedOption.description,
      updatedAt: Date.now(),
    });

    return await this.voteOptionRepository.save(voteOption);
  }

  /**
   * 用户删除本人添加的线上投票选手
   */
  async deleteUserVoteOption(
    activityId: number,
    optionId: number,
    userId: number,
  ): Promise<void> {
    await this.assertOnlineVoteActivityEditable(activityId, '删除选手');

    await this.activityRepository.manager.transaction(async (manager) => {
      const activityRepository = manager.getRepository(Activity);
      const activityCommentRepository = manager.getRepository(ActivityComment);
      const registrationRepository = manager.getRepository(ActivityRegistration);
      const voteOptionRepository = manager.getRepository(ActivityVoteOption);

      const voteOption = await voteOptionRepository.findOne({
        where: { id: optionId, activityId },
      });
      if (!voteOption) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '投票选手不存在');
      }

      if (voteOption.ownerUserId !== userId) {
        throw createBusinessException(
          ErrorCode.BUSINESS_PERMISSION_DENIED,
          '只能删除自己添加的选手',
        );
      }

      await activityCommentRepository.softDelete({ activityId, voteOptionId: optionId });
      await registrationRepository.delete({ activityId, voteOptionId: optionId });
      await voteOptionRepository.softDelete({ id: optionId, activityId });

      const registrationCount = await registrationRepository.count({
        where: { activityId },
      });
      await activityRepository.update(activityId, {
        registrationCount,
        updatedAt: Date.now(),
      });
    });
  }

  /**
   * 获取参与记录的原始分页数据
   */
  private async loadParticipantRows(
    activityId: number,
    page: number,
    pageSize: number,
    voteOptionId?: number,
  ): Promise<{ data: ActivityRegistration[]; total: number }> {
    const query = this.registrationRepository
      .createQueryBuilder('registration')
      .leftJoinAndSelect('registration.user', 'user')
      .where('registration.activityId = :activityId', { activityId });

    if (voteOptionId) {
      query.andWhere('registration.voteOptionId = :voteOptionId', { voteOptionId });
    }

    const [data, total] = await query
      .orderBy('registration.registeredAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    return { data, total };
  }

  // ==================== 辅助方法 ====================

  private async ensureOnlineActivitySupportsComments(activityId: number): Promise<void> {
    const activity = await this.activityRepository.findOne({
      where: { id: activityId },
      select: ['id', 'activityType'],
    });

    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    if (activity.activityType !== ActivityType.ONLINE) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '仅投票活动支持评论');
    }
  }

  private async ensureVoteOptionBelongsToActivity(
    activityId: number,
    voteOptionId?: number,
  ): Promise<void> {
    if (voteOptionId === undefined || voteOptionId === null) {
      return;
    }

    const voteOption = await this.voteOptionRepository.findOne({
      where: {
        id: voteOptionId,
        activityId,
      },
      select: ['id'],
    });

    if (!voteOption) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '投票选手不存在');
    }
  }

  private async collectActivityCommentDescendantIds(rootCommentId: number): Promise<number[]> {
    const idsToDelete = [rootCommentId];
    let currentParentIds = [rootCommentId];

    while (currentParentIds.length > 0) {
      const childComments = await this.activityCommentRepository.find({
        where: {
          parentId: In(currentParentIds),
        },
        select: ['id'],
      });

      if (childComments.length === 0) {
        break;
      }

      currentParentIds = childComments.map((comment) => comment.id);
      idsToDelete.push(...currentParentIds);
    }

    return idsToDelete;
  }

  private toActivityCommentResponse(comment: any): ActivityCommentResponse {
    const response: ActivityCommentResponse = {
      id: comment.id,
      activityId: comment.activityId,
      voteOptionId: comment.voteOptionId ?? null,
      userId: comment.userId,
      content: comment.content,
      parentId: comment.parentId ?? undefined,
      likeCount: Number(comment.likeCount ?? 0),
      createdAt: comment.createdAt,
    };

    if (comment.user) {
      response.user = {
        id: comment.user.id,
        nickname:
          comment.user.username || comment.user.phone || `用户${comment.user.id}`,
        avatar: comment.user.avatar,
      };
    }

    if (Array.isArray(comment.replies) && comment.replies.length > 0) {
      response.replies = comment.replies.map((reply: ActivityComment) =>
        this.toActivityCommentResponse(reply),
      );
    }

    return response;
  }

  /**
   * 规范化活动地点
   */
  private resolveActivityLocation(
    activityType: ActivityType,
    location?: string | null,
  ): string {
    if (activityType === ActivityType.ONLINE) {
      return '';
    }

    const normalizedLocation = String(location ?? '').trim();
    if (!normalizedLocation) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '线下活动必须填写活动地点');
    }

    return normalizedLocation;
  }

  /**
   * 规范化线上投票选手列表
   */
  private normalizeVoteOptions(
    activityType: ActivityType,
    voteOptions?: ActivityVoteOptionDto[],
  ): ActivityVoteOptionDto[] {
    if (activityType !== ActivityType.ONLINE) {
      return [];
    }

    const normalizedOptions = (voteOptions ?? [])
      .map((option, index) => ({
        image: String(option.image ?? '').trim(),
        video: String(option.video ?? '').trim(),
        videoCover: String(option.videoCover ?? '').trim(),
        title: String(option.title ?? '').trim(),
        description: option.description ? String(option.description).trim() : '',
        voteCount: Number(option.voteCount ?? 0),
        sortOrder: Number(option.sortOrder ?? index),
        ownerUserId: option.ownerUserId ? Number(option.ownerUserId) : undefined,
      }))
      .filter((option) => option.image || option.video || option.title || option.description);

    for (const option of normalizedOptions) {
      if (!option.image && !option.video) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '请上传选手图片或视频');
      }
      if (!option.title) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '选手标题不能为空');
      }
    }

    return normalizedOptions;
  }

  /**
   * 规范化用户端提交的选手资料
   */
  private normalizeUserVoteOption(voteOptionDto: UserVoteOptionDto): UserVoteOptionDto {
    const normalizedOption = {
      image: String(voteOptionDto.image ?? '').trim(),
      video: String(voteOptionDto.video ?? '').trim(),
      videoCover: String(voteOptionDto.videoCover ?? '').trim(),
      title: String(voteOptionDto.title ?? '').trim(),
      description: String(voteOptionDto.description ?? '').trim(),
    };

    if (!normalizedOption.image && !normalizedOption.video) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '请上传选手图片或视频');
    }

    if (!normalizedOption.title) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '选手标题不能为空');
    }

    return normalizedOption;
  }

  /**
   * 确认活动支持用户端选手报名/编辑
   */
  private async assertOnlineVoteActivityEditable(
    activityId: number,
    actionLabel: string,
  ): Promise<Activity> {
    const activity = await this.activityRepository.findOne({ where: { id: activityId } });
    if (!activity) {
      throw createBusinessException(ErrorCode.ACTIVITY_NOT_FOUND, '活动不存在');
    }

    this.calculateActivityStatus(activity);

    if (activity.activityType !== ActivityType.ONLINE) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '只有线上投票活动支持选手报名');
    }

    if (activity.status === ActivityStatus.EXPIRED) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, `活动已结束，无法${actionLabel}`);
    }

    return activity;
  }

  /**
   * 加载活动投票选手
   */
  private async loadVoteOptions(
    activityId: number,
    repository: Repository<ActivityVoteOption> = this.voteOptionRepository,
    currentUserId?: number,
  ): Promise<ActivityVoteOption[]> {
    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);

    return await repository.find({
      where: blockedUserIds?.length
        ? [
            { activityId, ownerUserId: IsNull() },
            { activityId, ownerUserId: Not(In(blockedUserIds)) },
          ]
        : { activityId },
      order: {
        sortOrder: 'ASC',
        id: 'ASC',
      },
    });
  }

  private buildParticipationWhere(activity: Activity, userId: number): {
    activityId: number;
    userId: number;
    participationKey: string;
  } {
    return {
      activityId: activity.id,
      userId,
      participationKey: activity.activityType === ActivityType.ONLINE
        ? this.getTodayParticipationKey()
        : this.getOfflineParticipationKey(),
    };
  }

  private getOfflineParticipationKey(): string {
    return 'offline';
  }

  private getTodayParticipationKey(): string {
    const now = new Date(Date.now());
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * 计算活动状态（根据当前时间）
   */
  private calculateActivityStatus(activity: Activity): void {
    const now = Math.floor(Date.now() / 1000);

    if (now < activity.startTime) {
      activity.status = ActivityStatus.UPCOMING;
    } else if (now >= activity.startTime && now < activity.endTime) {
      activity.status = ActivityStatus.ONGOING;
    } else {
      activity.status = ActivityStatus.EXPIRED;
    }
  }
}
