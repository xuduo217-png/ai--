import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { In, Repository } from "typeorm";
import { CommunityFollow } from "./entities/community-follow.entity";
import { CommunityProfile } from "./entities/community-profile.entity";
import { User } from "../users/entities/user.entity";
import { QueryCommunityUsersDto } from "./dto";
import { NotificationSenderService } from "../notifications/notification-sender.service";

/**
 * 社区关系状态
 * 关注体系是单向关系，互相关注由双向记录推导得出。
 */
export interface CommunityRelationshipStatus {
  isSelf: boolean;
  isFollowing: boolean;
  isFollowedBy: boolean;
  isMutualFollow: boolean;
}

/**
 * 社区关系列表项
 */
export interface CommunityUserListItem {
  id: number;
  nickname: string;
  avatar?: string | null;
  bio?: string | null;
  verified?: boolean;
  followedAt: Date;
  relationship: CommunityRelationshipStatus;
}

/**
 * 社区关注服务
 * 负责关注、取消关注、互相关注判断以及关注/粉丝列表查询。
 */
@Injectable()
export class CommunityFollowService {
  constructor(
    @InjectRepository(CommunityFollow)
    private readonly communityFollowRepository: Repository<CommunityFollow>,
    @InjectRepository(CommunityProfile)
    private readonly communityProfileRepository: Repository<CommunityProfile>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly notificationSender: NotificationSenderService,
  ) {}

  /**
   * 校验目标用户是否存在且可见
   */
  private async ensureActiveUser(userId: number): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id: userId, isActive: true },
      select: ["id", "username", "phone", "avatar", "verified", "isActive"],
    });

    if (!user) {
      throw new NotFoundException("用户不存在");
    }

    return user;
  }

  /**
   * 构建社区关系状态
   */
  async getRelationshipStatus(
    currentUserId: number,
    targetUserId: number,
  ): Promise<CommunityRelationshipStatus> {
    if (currentUserId === targetUserId) {
      return {
        isSelf: true,
        isFollowing: false,
        isFollowedBy: false,
        isMutualFollow: false,
      };
    }

    const [isFollowing, isFollowedBy] = await Promise.all([
      this.communityFollowRepository.exist({
        where: { followerId: currentUserId, followingId: targetUserId },
      }),
      this.communityFollowRepository.exist({
        where: { followerId: targetUserId, followingId: currentUserId },
      }),
    ]);

    return {
      isSelf: false,
      isFollowing,
      isFollowedBy,
      isMutualFollow: isFollowing && isFollowedBy,
    };
  }

  /**
   * 获取关注统计
   */
  async getFollowStats(userId: number): Promise<{
    followerCount: number;
    followingCount: number;
  }> {
    const [followerCount, followingCount] = await Promise.all([
      this.communityFollowRepository.count({
        where: { followingId: userId },
      }),
      this.communityFollowRepository.count({
        where: { followerId: userId },
      }),
    ]);

    return {
      followerCount,
      followingCount,
    };
  }

  /**
   * 关注用户
   * 幂等处理：重复关注直接返回当前关系状态。
   */
  async followUser(
    followerId: number,
    followingId: number,
  ): Promise<CommunityRelationshipStatus> {
    if (followerId === followingId) {
      throw new BadRequestException("不能关注自己");
    }

    const [follower] = await Promise.all([
      this.ensureActiveUser(followerId),
      this.ensureActiveUser(followingId),
    ]);

    const existingFollow = await this.communityFollowRepository.findOne({
      where: {
        followerId,
        followingId,
      },
    });

    if (!existingFollow) {
      const followRecord = this.communityFollowRepository.create({
        followerId,
        followingId,
      });
      await this.communityFollowRepository.save(followRecord);

      await this.notificationSender.followerNew(followingId, {
        followerId: follower.id,
        followerName:
          follower.username || follower.phone || `用户${follower.id}`,
      });
    }

    return this.getRelationshipStatus(followerId, followingId);
  }

  /**
   * 取消关注用户
   * 幂等处理：未关注也直接返回当前关系状态。
   */
  async unfollowUser(
    followerId: number,
    followingId: number,
  ): Promise<CommunityRelationshipStatus> {
    if (followerId === followingId) {
      throw new BadRequestException("不能取消关注自己");
    }

    await this.communityFollowRepository.delete({
      followerId,
      followingId,
    });

    return this.getRelationshipStatus(followerId, followingId);
  }

  /**
   * 获取用户关注的目标用户ID列表
   * 用于关注流查询。
   */
  async getFollowingUserIds(userId: number): Promise<number[]> {
    const followRecords = await this.communityFollowRepository.find({
      where: { followerId: userId },
      select: ["followingId"],
      order: { createdAt: "DESC" },
    });

    return followRecords.map((record) => record.followingId);
  }

  /**
   * 批量构建关系状态
   * 关注/粉丝列表需要一次性为多个用户补齐“我是否关注 ta / ta 是否关注我”。
   */
  private async buildRelationshipStatusMap(
    currentUserId: number,
    targetUserIds: number[],
  ): Promise<Map<number, CommunityRelationshipStatus>> {
    const statusMap = new Map<number, CommunityRelationshipStatus>();

    if (targetUserIds.length === 0) {
      return statusMap;
    }

    const sanitizedUserIds = Array.from(new Set(targetUserIds));

    const [followingRecords, followedByRecords] = await Promise.all([
      this.communityFollowRepository.find({
        where: {
          followerId: currentUserId,
          followingId: In(sanitizedUserIds),
        },
        select: ["followingId"],
      }),
      this.communityFollowRepository.find({
        where: {
          followerId: In(sanitizedUserIds),
          followingId: currentUserId,
        },
        select: ["followerId"],
      }),
    ]);

    const followingSet = new Set(
      followingRecords.map((record) => record.followingId),
    );
    const followedBySet = new Set(
      followedByRecords.map((record) => record.followerId),
    );

    sanitizedUserIds.forEach((targetUserId) => {
      const isSelf = currentUserId === targetUserId;
      const isFollowing = !isSelf && followingSet.has(targetUserId);
      const isFollowedBy = !isSelf && followedBySet.has(targetUserId);

      statusMap.set(targetUserId, {
        isSelf,
        isFollowing,
        isFollowedBy,
        isMutualFollow: isFollowing && isFollowedBy,
      });
    });

    return statusMap;
  }

  /**
   * 通用列表查询
   * 关注列表与粉丝列表的差异只在 join 字段，其余组装逻辑保持一致。
   */
  private async getCommunityUserRelationList(
    currentUserId: number,
    targetUserId: number,
    query: QueryCommunityUsersDto,
    mode: "followers" | "following",
  ): Promise<{
    data: CommunityUserListItem[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    await this.ensureActiveUser(targetUserId);

    const { page = 1, limit = 20, keyword } = query;
    const relationField = mode === "followers" ? "followerId" : "followingId";
    const joinField = mode === "followers" ? "follower" : "following";

    const queryBuilder = this.communityFollowRepository
      .createQueryBuilder("follow")
      .innerJoin(`follow.${joinField}`, "targetUser")
      .leftJoin(CommunityProfile, "profile", "profile.userId = targetUser.id")
      .where(
        mode === "followers"
          ? "follow.followingId = :targetUserId"
          : "follow.followerId = :targetUserId",
        { targetUserId },
      )
      .andWhere("targetUser.isActive = :isActive", { isActive: true });

    if (keyword) {
      queryBuilder.andWhere("targetUser.username LIKE :keyword", {
        keyword: `%${keyword}%`,
      });
    }

    queryBuilder
      .select([
        "follow.createdAt AS followedAt",
        "targetUser.id AS userId",
        "targetUser.username AS username",
        "targetUser.phone AS phone",
        "targetUser.avatar AS avatar",
        "targetUser.verified AS verified",
        "profile.bio AS bio",
      ])
      .orderBy("follow.createdAt", "DESC");

    const [rows, total] = await Promise.all([
      queryBuilder
        .clone()
        .offset((page - 1) * limit)
        .limit(limit)
        .getRawMany(),
      queryBuilder.clone().getCount(),
    ]);

    const userIds = rows.map((row) => Number(row.userId));
    const relationshipMap = await this.buildRelationshipStatusMap(
      currentUserId,
      userIds,
    );

    const data = rows.map((row) => {
      const targetId = Number(row.userId);
      const relationship = relationshipMap.get(targetId) || {
        isSelf: currentUserId === targetId,
        isFollowing: false,
        isFollowedBy: false,
        isMutualFollow: false,
      };

      return {
        id: targetId,
        nickname: row.username || row.phone || `用户${targetId}`,
        avatar: row.avatar ?? null,
        bio: row.bio ?? null,
        verified: Boolean(row.verified),
        followedAt: new Date(row.followedAt),
        relationship,
      };
    });

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * 获取粉丝列表
   */
  async getFollowers(
    currentUserId: number,
    targetUserId: number,
    query: QueryCommunityUsersDto,
  ) {
    return this.getCommunityUserRelationList(
      currentUserId,
      targetUserId,
      query,
      "followers",
    );
  }

  /**
   * 获取关注列表
   */
  async getFollowings(
    currentUserId: number,
    targetUserId: number,
    query: QueryCommunityUsersDto,
  ) {
    return this.getCommunityUserRelationList(
      currentUserId,
      targetUserId,
      query,
      "following",
    );
  }
}
