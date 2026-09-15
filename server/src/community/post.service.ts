import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Optional,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository, In } from "typeorm";
import { Post, PostStatus } from "./entities/post.entity";
import {
  CreatePostDto,
  UpdatePostDto,
  QueryPostsDto,
  PostQueryType,
} from "./dto";
import { SensitiveWordService } from "./sensitive-word.service";
import { Tag } from "./entities/tag.entity";
import { PostTag } from "./entities/post-tag.entity";
import { LikeService } from "./like.service";
import { instanceToPlain } from "class-transformer";
import { CommunityFollowService } from "./community-follow.service";
import { ModerationService } from "../moderation/moderation.service";

/**
 * 帖子服务
 * 提供帖子的增删改查、关注流、推荐流等功能
 */
@Injectable()
export class PostService {
  constructor(
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
    @InjectRepository(Tag)
    private readonly tagRepository: Repository<Tag>,
    @InjectRepository(PostTag)
    private readonly postTagRepository: Repository<PostTag>,
    private readonly sensitiveWordService: SensitiveWordService,
    private readonly likeService: LikeService,
    private readonly communityFollowService: CommunityFollowService,
    @Optional()
    private readonly moderationService?: ModerationService,
  ) {}

  /**
   * 创建帖子
   */
  async create(userId: number, dto: CreatePostDto): Promise<Post> {
    // 1. 敏感词检测和处理
    const processResult = await this.sensitiveWordService.process(dto.content);

    // 2. 根据处理结果设置状态
    let status = PostStatus.PENDING_REVIEW;
    let rejectReason: string | undefined;
    let content = dto.content;

    if (processResult.action === "REJECT") {
      status = PostStatus.REJECTED;
      // 用户看到的通用信息（不暴露具体敏感词）
      rejectReason = "内容包含违规信息，请修改后重新提交";
      // 详细信息保存在 detectedSensitiveWords 字段供管理员查看
    } else if (processResult.action === "REPLACE") {
      content = processResult.text || dto.content;
      // 替换后仍需人工审核
    }

    // 3. 创建帖子
    const post = this.postRepository.create({
      userId,
      content,
      images: dto.images,
      video: dto.video,
      videoCover: dto.videoCover,
      status,
      rejectReason,
      detectedSensitiveWords: processResult.words.map((w) => w.word),
    });

    const saved = await this.postRepository.save(post);

    // 4. 提取并保存标签
    if (dto.tags && dto.tags.length > 0) {
      await this.savePostTags(saved.id, dto.tags);
    }

    // 转换为响应格式
    return await this.toPostResponse(saved);
  }

  /**
   * 更新帖子
   */
  async update(id: number, userId: number, dto: UpdatePostDto): Promise<Post> {
    const post = await this.findOne(id, userId);

    // 权限检查
    if (post.userId !== userId) {
      throw new ForbiddenException("无权编辑此帖子");
    }

    const hasChanges =
      dto.content !== undefined ||
      dto.images !== undefined ||
      dto.video !== undefined ||
      dto.videoCover !== undefined ||
      dto.tags !== undefined;

    // 用户修改帖子后必须重新审核，旧的审核结论不再适用于新内容。
    if (hasChanges) {
      post.status = PostStatus.PENDING_REVIEW;
      post.rejectReason = null;
      post.detectedSensitiveWords = [];
    }

    // 更新字段
    if (dto.content !== undefined) {
      // 重新进行敏感词检测和处理
      const processResult = await this.sensitiveWordService.process(
        dto.content,
      );

      let content = dto.content;

      if (processResult.action === "REJECT") {
        post.status = PostStatus.REJECTED;
        // 用户看到的通用信息（不暴露具体敏感词）
        post.rejectReason = "内容包含违规信息，请修改后重新提交";
      } else if (processResult.action === "REPLACE") {
        content = processResult.text || dto.content;
      }

      post.content = content;
      post.detectedSensitiveWords = processResult.words.map((w) => w.word);
    }

    if (dto.images !== undefined) {
      post.images = dto.images;
    }

    if (dto.video !== undefined) {
      post.video = dto.video;
    }

    if (dto.videoCover !== undefined) {
      post.videoCover = dto.videoCover;
    }

    const updated = await this.postRepository.save(post);

    // 更新标签
    if (dto.tags !== undefined) {
      await this.postTagRepository.delete({ postId: id });
      if (dto.tags.length > 0) {
        await this.savePostTags(id, dto.tags);
      }
    }

    // 转换为响应格式
    return await this.toPostResponse(updated);
  }

  /**
   * 删除帖子（用户只能删除自己的帖子）
   */
  async delete(id: number, userId: number): Promise<void> {
    const post = await this.findOne(id, userId);

    // 权限检查：只能删除自己的帖子
    if (post.userId !== userId) {
      throw new ForbiddenException("无权删除此帖子");
    }

    await this.postRepository.softRemove(post);
  }

  /**
   * 管理员删除帖子（不需要权限检查）
   */
  async adminDelete(id: number): Promise<void> {
    const post = await this.findOne(id);
    await this.postRepository.softRemove(post);
  }

  /**
   * 获取帖子详情
   */
  async findOne(id: number, userId?: number): Promise<Post> {
    const post = await this.postRepository.findOne({
      where: { id },
      relations: ["user"],
    });

    if (!post) {
      throw new NotFoundException("帖子不存在");
    }

    // 权限检查：只有作者和管理员可以查看待审核和已拒绝的帖子
    if (post.status !== PostStatus.APPROVED && post.userId !== userId) {
      throw new NotFoundException("帖子不存在");
    }

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(userId);
    if (blockedUserIds?.includes(post.userId)) {
      throw new NotFoundException("帖子不存在");
    }

    // 增加浏览数（使用原子操作避免并发问题）
    if (post.status === PostStatus.APPROVED) {
      await this.postRepository.increment({ id }, "viewCount", 1);
      // 重新查询以返回更新后的值
      post.viewCount++;
    }

    // 转换为响应格式
    const plainPost = await this.toPostResponse(post);

    // 添加点赞状态（如果提供了 userId）
    if (userId) {
      plainPost.isLiked = await this.likeService.hasLikedPost(userId, id);
    }

    return plainPost;
  }

  /**
   * 获取帖子列表（关注流/推荐流）
   */
  async findAll(
    userId: number,
    dto: QueryPostsDto,
  ): Promise<{ data: Post[]; total: number }> {
    const queryBuilder = this.postRepository
      .createQueryBuilder("post")
      .leftJoinAndSelect("post.user", "user")
      .where("post.status = :status", { status: PostStatus.APPROVED });

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(userId);
    if (blockedUserIds?.length) {
      queryBuilder.andWhere("post.userId NOT IN (:...blockedUserIds)", {
        blockedUserIds,
      });
    }

    // 按标签筛选
    if (dto.tag) {
      queryBuilder
        .innerJoin("community_post_tags", "pt", "pt.postId = post.id")
        .innerJoin("community_tags", "t", "t.id = pt.tagId")
        .andWhere("t.name = :tag", { tag: dto.tag });
    }

    // 关注流：仅展示当前用户已关注对象的帖子
    if (dto.type === PostQueryType.FOLLOWING) {
      const followingUserIds =
        await this.communityFollowService.getFollowingUserIds(userId);

      if (followingUserIds.length === 0) {
        return { data: [], total: 0 };
      }

      queryBuilder
        .andWhere("post.userId IN (:...followingUserIds)", { followingUserIds })
        .orderBy("post.isPinned", "DESC")
        .addOrderBy("post.createdAt", "DESC")
        .take(dto.limit)
        .skip((dto.page - 1) * dto.limit);

      const [followingPosts, followingTotal] =
        await queryBuilder.getManyAndCount();
      const transformedFollowingPosts =
        await this.toPostResponseListWithLikeStatus(followingPosts, userId);

      return { data: transformedFollowingPosts, total: followingTotal };
    }

    // 推荐流：按热度排序
    queryBuilder
      .orderBy("post.isPinned", "DESC")
      .addOrderBy("post.heatScore", "DESC")
      .addOrderBy("post.createdAt", "DESC")
      .take(dto.limit)
      .skip((dto.page - 1) * dto.limit);

    const [data, total] = await queryBuilder.getManyAndCount();

    // 转换数据为响应格式（排除敏感字段，转换 user 对象结构，添加点赞状态）
    const transformedData = await this.toPostResponseListWithLikeStatus(
      data,
      userId,
    );

    return { data: transformedData, total };
  }

  /**
   * 获取用户的所有帖子
   */
  async findByUser(
    targetUserId: number,
    currentUserId?: number,
  ): Promise<Post[]> {
    const queryBuilder = this.postRepository
      .createQueryBuilder("post")
      .leftJoinAndSelect("post.user", "user")
      .where("post.userId = :userId", { userId: targetUserId });

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    if (blockedUserIds?.includes(targetUserId)) {
      return [];
    }

    // 只有作者本人可以查看未审核的帖子
    if (targetUserId !== currentUserId) {
      queryBuilder.andWhere("post.status = :status", {
        status: PostStatus.APPROVED,
      });
    }

    const posts = await queryBuilder
      .orderBy("post.createdAt", "DESC")
      .getMany();

    // 转换为响应格式（添加点赞状态）
    if (currentUserId) {
      return await this.toPostResponseListWithLikeStatus(posts, currentUserId);
    }

    // 如果没有当前用户ID，直接转换
    return this.toPostResponseList(posts);
  }

  /**
   * 保存帖子标签
   */
  private async savePostTags(
    postId: number,
    tagNames: string[],
  ): Promise<void> {
    for (const tagName of tagNames) {
      // 查找或创建标签
      let tag = await this.tagRepository.findOne({ where: { name: tagName } });
      if (!tag) {
        tag = this.tagRepository.create({ name: tagName, usageCount: 0 });
        tag = await this.tagRepository.save(tag);
      }

      // 增加使用次数
      tag.usageCount++;
      await this.tagRepository.save(tag);

      // 创建关联
      const postTag = this.postTagRepository.create({
        postId,
        tagId: tag.id,
      });
      await this.postTagRepository.save(postTag);
    }
  }

  /**
   * 内部方法：查找帖子（不包含权限检查）
   * 用于管理员操作，直接从数据库查询帖子
   */
  private async findById(id: number): Promise<Post> {
    const post = await this.postRepository.findOne({
      where: { id },
    });

    if (!post) {
      throw new NotFoundException("帖子不存在");
    }

    return post;
  }

  /**
   * 审核通过
   */
  async approve(id: number): Promise<Post> {
    const post = await this.findById(id);
    post.status = PostStatus.APPROVED;
    post.rejectReason = null;
    const saved = await this.postRepository.save(post);
    return await this.toPostResponse(saved);
  }

  /**
   * 审核拒绝
   */
  async reject(id: number, reason: string): Promise<Post> {
    const post = await this.findById(id);
    post.status = PostStatus.REJECTED;
    post.rejectReason = reason;
    const saved = await this.postRepository.save(post);
    return await this.toPostResponse(saved);
  }

  /**
   * 置顶/取消置顶
   */
  async togglePin(id: number): Promise<Post> {
    const post = await this.findById(id);
    post.isPinned = !post.isPinned;
    const saved = await this.postRepository.save(post);
    return await this.toPostResponse(saved);
  }

  /**
   * 加精/取消加精
   */
  async toggleFeature(id: number): Promise<Post> {
    const post = await this.findById(id);
    post.isFeatured = !post.isFeatured;
    const saved = await this.postRepository.save(post);
    return await this.toPostResponse(saved);
  }

  /**
   * 获取待审核列表
   */
  async findPending(
    page: number = 1,
    limit: number = 10,
  ): Promise<{ data: Post[]; total: number }> {
    const [data, total] = await this.postRepository.findAndCount({
      where: { status: PostStatus.PENDING_REVIEW },
      relations: ["user"],
      order: { createdAt: "DESC" },
      take: limit,
      skip: (page - 1) * limit,
    });

    // 转换为响应格式
    return { data: await this.toPostResponseList(data), total };
  }

  /**
   * 将 Post 实体转换为响应格式
   * 转换 user 对象为前端期望的格式（username -> nickname）
   * 并使用 instanceToPlain 自动排除 @Exclude() 标记的字段（如 password）
   */
  private async toPostResponse(post: Post): Promise<any> {
    const plainPost = instanceToPlain(post);

    // 转换 user 对象格式
    if (plainPost.user) {
      plainPost.user = {
        id: plainPost.user.id,
        // 使用 username 作为 nickname 显示
        nickname: plainPost.user.username || plainPost.user.phone || "匿名用户",
        avatar: plainPost.user.avatar,
      };
    }

    // 标签作为帖子元数据的一部分统一由服务端补齐，避免 RN/Admin 各自拼装产生漂移。
    plainPost.tags = await this.getTagNamesByPostId(post.id);

    return plainPost;
  }

  /**
   * 批量转换 Post 实体为响应格式（带点赞状态）
   */
  private async toPostResponseListWithLikeStatus(
    posts: Post[],
    userId: number,
  ): Promise<any[]> {
    const postIds = posts.map((post) => post.id);
    const likedPostIds = new Set<number>(
      await this.likeService.findLikedPostIds(userId, postIds),
    );

    // 转换并添加点赞状态
    const plainPosts = await this.toPostResponseList(posts);

    return plainPosts.map((plainPost) => ({
      ...plainPost,
      isLiked: likedPostIds.has(plainPost.id),
    }));
  }

  /**
   * 批量转换 Post 实体为响应格式
   */
  private async toPostResponseList(posts: Post[]): Promise<any[]> {
    const postIds = posts.map((post) => post.id);
    const tagNamesMap = await this.getTagNamesMap(postIds);

    return posts.map((post) => {
      const plainPost = instanceToPlain(post);

      if (plainPost.user) {
        plainPost.user = {
          id: plainPost.user.id,
          nickname:
            plainPost.user.username || plainPost.user.phone || "匿名用户",
          avatar: plainPost.user.avatar,
        };
      }

      plainPost.tags = tagNamesMap.get(post.id) || [];

      return plainPost;
    });
  }

  /**
   * 更新热度分数
   * 热度公式：点赞数 + 评论数 * 2 + 浏览数 * 0.1
   */
  async updateHeatScore(postId: number): Promise<void> {
    const post = await this.postRepository.findOne({ where: { id: postId } });
    if (post) {
      post.heatScore = Math.floor(
        post.likeCount + post.commentCount * 2 + post.viewCount * 0.1,
      );
      await this.postRepository.save(post);
    }
  }

  /**
   * 获取热门标签
   * 按使用次数排序，返回前 20 个
   */
  async findHotTags(limit: number = 20): Promise<Tag[]> {
    return this.tagRepository.find({
      order: { usageCount: "DESC", createdAt: "DESC" },
      take: limit,
    });
  }

  /**
   * 搜索标签
   * 根据关键词模糊查询标签名称
   */
  async searchTags(keyword: string, limit: number = 20): Promise<Tag[]> {
    return this.tagRepository
      .createQueryBuilder("tag")
      .where("tag.name LIKE :keyword", { keyword: `%${keyword}%` })
      .orderBy("tag.usageCount", "DESC")
      .addOrderBy("tag.createdAt", "DESC")
      .take(limit)
      .getMany();
  }

  /**
   * 获取已审核内容列表
   * 支持按状态筛选（APPROVED/REJECTED）
   */
  async findReviewed(
    page: number = 1,
    limit: number = 10,
    status?: PostStatus,
  ): Promise<{ data: Post[]; total: number }> {
    const where: any = {};
    if (status) {
      where.status = status;
    } else {
      // 如果没有指定状态，默认返回已通过和已拒绝的
      where.status = In([PostStatus.APPROVED, PostStatus.REJECTED]);
    }

    const [data, total] = await this.postRepository.findAndCount({
      where,
      relations: ["user"],
      order: { createdAt: "DESC" },
      take: limit,
      skip: (page - 1) * limit,
    });

    // 转换为响应格式
    return { data: await this.toPostResponseList(data), total };
  }

  /**
   * 获取单个帖子的标签名列表
   * 详情接口需要补齐标签，避免页面层再单独请求或手工组装。
   */
  private async getTagNamesByPostId(postId: number): Promise<string[]> {
    const tagNamesMap = await this.getTagNamesMap([postId]);
    return tagNamesMap.get(postId) || [];
  }

  /**
   * 批量获取帖子标签映射
   * 列表接口统一批量查询，避免逐帖查询造成不必要的数据库往返。
   */
  private async getTagNamesMap(
    postIds: number[],
  ): Promise<Map<number, string[]>> {
    const tagNamesMap = new Map<number, string[]>();

    if (postIds.length === 0) {
      return tagNamesMap;
    }

    const postTags = await this.postTagRepository.find({
      where: { postId: In(postIds) },
      relations: ["tag"],
      order: { id: "ASC" },
    });

    postTags.forEach((postTag) => {
      if (!postTag.tag?.name) {
        return;
      }

      const currentTags = tagNamesMap.get(postTag.postId) || [];
      currentTags.push(postTag.tag.name);
      tagNamesMap.set(postTag.postId, currentTags);
    });

    return tagNamesMap;
  }
}
