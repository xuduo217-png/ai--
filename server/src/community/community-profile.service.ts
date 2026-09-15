import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { CommunityProfile } from "./entities/community-profile.entity";
import { Post, PostStatus } from "./entities/post.entity";
import { User } from "../users/entities/user.entity";
import { UpdateCommunityProfileDto } from "./dto";
import {
  CommunityFollowService,
  CommunityRelationshipStatus,
} from "./community-follow.service";

/**
 * 社区公开资料响应
 */
export interface CommunityPublicProfileResponse {
  user: {
    id: number;
    username?: string | null;
    nickname: string;
    avatar?: string | null;
    bio?: string | null;
    coverImage?: string | null;
    verified?: boolean;
    createdAt?: Date;
  };
  stats: {
    postCount: number;
    followerCount: number;
    followingCount: number;
  };
  relationship: CommunityRelationshipStatus;
}

/**
 * 社区资料服务
 * 负责社区公开资料的读取与编辑，不再直接复用通用用户资料接口。
 */
@Injectable()
export class CommunityProfileService {
  constructor(
    @InjectRepository(CommunityProfile)
    private readonly communityProfileRepository: Repository<CommunityProfile>,
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly communityFollowService: CommunityFollowService,
  ) {}

  /**
   * 获取有效用户
   */
  private async getActiveUser(userId: number): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id: userId, isActive: true },
      select: [
        "id",
        "username",
        "phone",
        "avatar",
        "verified",
        "isActive",
        "createdAt",
      ],
    });

    if (!user) {
      throw new NotFoundException("用户不存在");
    }

    return user;
  }

  /**
   * 获取或创建社区资料
   */
  private async getOrCreateProfile(userId: number): Promise<CommunityProfile> {
    const existingProfile = await this.communityProfileRepository.findOne({
      where: { userId },
    });

    if (existingProfile) {
      return existingProfile;
    }

    const newProfile = this.communityProfileRepository.create({
      userId,
      bio: null,
      coverImage: null,
    });

    return this.communityProfileRepository.save(newProfile);
  }

  /**
   * 获取帖子数量
   * 自己看自己主页时返回全部帖子数量，其他人只返回公开可见内容数量。
   */
  private async getPostCount(
    targetUserId: number,
    currentUserId: number,
  ): Promise<number> {
    if (targetUserId === currentUserId) {
      return this.postRepository.count({
        where: { userId: targetUserId },
      });
    }

    return this.postRepository.count({
      where: {
        userId: targetUserId,
        status: PostStatus.APPROVED,
      },
    });
  }

  /**
   * 获取社区公开资料
   */
  async getPublicProfile(
    targetUserId: number,
    currentUserId: number,
  ): Promise<CommunityPublicProfileResponse> {
    const [user, profile, postCount, followStats, relationship] =
      await Promise.all([
        this.getActiveUser(targetUserId),
        this.getOrCreateProfile(targetUserId),
        this.getPostCount(targetUserId, currentUserId),
        this.communityFollowService.getFollowStats(targetUserId),
        this.communityFollowService.getRelationshipStatus(
          currentUserId,
          targetUserId,
        ),
      ]);

    return {
      user: {
        id: user.id,
        username: user.username ?? null,
        nickname: user.username || user.phone || `用户${user.id}`,
        avatar: user.avatar ?? null,
        bio: profile.bio ?? null,
        coverImage: profile.coverImage ?? null,
        verified: user.verified,
        createdAt: user.createdAt,
      },
      stats: {
        postCount,
        followerCount: followStats.followerCount,
        followingCount: followStats.followingCount,
      },
      relationship,
    };
  }

  /**
   * 更新我的社区资料
   */
  async updateMyProfile(
    userId: number,
    dto: UpdateCommunityProfileDto,
  ): Promise<CommunityPublicProfileResponse> {
    await this.getActiveUser(userId);

    const profile = await this.getOrCreateProfile(userId);

    profile.bio = dto.bio?.trim() || null;
    profile.coverImage = dto.coverImage?.trim() || null;

    await this.communityProfileRepository.save(profile);

    return this.getPublicProfile(userId, userId);
  }
}
