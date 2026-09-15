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
  HttpCode,
  HttpStatus,
  BadRequestException,
} from "@nestjs/common";
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
  ApiResponse,
  ApiQuery,
} from "@nestjs/swagger";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import { User } from "../users/entities/user.entity";
import { PostService } from "./post.service";
import { CommentService } from "./comment.service";
import { LikeService } from "./like.service";
import {
  CreatePostDto,
  UpdatePostDto,
  QueryPostsDto,
  CreateCommentDto,
  QueryCommunityUsersDto,
  UpdateCommunityProfileDto,
} from "./dto";
import { PostOwnerGuard } from "./guards";
import { CommunityProfileService } from "./community-profile.service";
import { CommunityFollowService } from "./community-follow.service";

/**
 * 社区模块 API
 * 面向 RN App 端
 */
@ApiTags("社区")
@Controller("community")
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class CommunityController {
  constructor(
    private readonly postService: PostService,
    private readonly commentService: CommentService,
    private readonly likeService: LikeService,
    private readonly communityProfileService: CommunityProfileService,
    private readonly communityFollowService: CommunityFollowService,
  ) {}

  /**
   * 验证并解析 ID 参数
   * @param id ID 字符串
   * @param fieldName 字段名称（用于错误提示）
   * @returns 解析后的数字
   */
  private parseId(id: string, fieldName: string = "ID"): number {
    const parsed = parseInt(id, 10);
    if (isNaN(parsed)) {
      throw new BadRequestException(`无效的${fieldName}格式`);
    }
    if (parsed <= 0) {
      throw new BadRequestException(`${fieldName}必须为正整数`);
    }
    return parsed;
  }

  /**
   * 发布帖子
   */
  @Post("posts")
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: "发布帖子" })
  @ApiResponse({ status: 201, description: "发布成功" })
  async createPost(@CurrentUser() user: User, @Body() dto: CreatePostDto) {
    const post = await this.postService.create(user.id, dto);
    return {
      code: 0,
      message: "发布成功",
      data: post,
    };
  }

  /**
   * 获取帖子列表（关注流/推荐流）
   */
  @Get("posts")
  @ApiOperation({ summary: "获取帖子列表" })
  async getPosts(@CurrentUser() user: User, @Query() dto: QueryPostsDto) {
    const result = await this.postService.findAll(user.id, dto);
    return {
      code: 0,
      message: "获取成功",
      data: result.data,
      meta: {
        total: result.total,
        page: dto.page,
        limit: dto.limit,
      },
    };
  }

  /**
   * 获取帖子详情
   */
  @Get("posts/:id")
  @ApiOperation({ summary: "获取帖子详情" })
  @ApiParam({ name: "id", description: "帖子ID" })
  async getPostDetail(@CurrentUser() user: User, @Param("id") id: string) {
    const postId = this.parseId(id, "帖子ID");
    const post = await this.postService.findOne(postId, user.id);
    return {
      code: 0,
      message: "获取成功",
      data: post,
    };
  }

  /**
   * 获取用户的所有帖子
   */
  @Get("posts/user/:userId")
  @ApiOperation({ summary: "获取用户的所有帖子" })
  @ApiParam({ name: "userId", description: "用户ID" })
  async getUserPosts(
    @CurrentUser() user: User,
    @Param("userId") userId: string,
  ) {
    const targetUserId = this.parseId(userId, "用户ID");
    const posts = await this.postService.findByUser(targetUserId, user.id);
    return {
      code: 0,
      message: "获取成功",
      data: posts,
    };
  }

  /**
   * 获取社区公开资料
   */
  @Get("users/:userId/profile")
  @ApiOperation({ summary: "获取社区公开资料" })
  @ApiParam({ name: "userId", description: "用户ID" })
  async getCommunityUserProfile(
    @CurrentUser() user: User,
    @Param("userId") userId: string,
  ) {
    const targetUserId = this.parseId(userId, "用户ID");
    const profile = await this.communityProfileService.getPublicProfile(
      targetUserId,
      user.id,
    );

    return {
      code: 0,
      message: "获取成功",
      data: profile,
    };
  }

  /**
   * 更新我的社区资料
   */
  @Put("profile")
  @ApiOperation({ summary: "更新我的社区资料" })
  async updateMyCommunityProfile(
    @CurrentUser() user: User,
    @Body() dto: UpdateCommunityProfileDto,
  ) {
    const profile = await this.communityProfileService.updateMyProfile(
      user.id,
      dto,
    );

    return {
      code: 0,
      message: "更新成功",
      data: profile,
    };
  }

  /**
   * 关注用户
   */
  @Post("users/:userId/follow")
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: "关注用户" })
  @ApiParam({ name: "userId", description: "用户ID" })
  async followUser(@CurrentUser() user: User, @Param("userId") userId: string) {
    const targetUserId = this.parseId(userId, "用户ID");
    const relationship = await this.communityFollowService.followUser(
      user.id,
      targetUserId,
    );

    return {
      code: 0,
      message: "关注成功",
      data: relationship,
    };
  }

  /**
   * 取消关注用户
   */
  @Delete("users/:userId/follow")
  @ApiOperation({ summary: "取消关注用户" })
  @ApiParam({ name: "userId", description: "用户ID" })
  async unfollowUser(
    @CurrentUser() user: User,
    @Param("userId") userId: string,
  ) {
    const targetUserId = this.parseId(userId, "用户ID");
    const relationship = await this.communityFollowService.unfollowUser(
      user.id,
      targetUserId,
    );

    return {
      code: 0,
      message: "取消关注成功",
      data: relationship,
    };
  }

  /**
   * 获取粉丝列表
   */
  @Get("users/:userId/followers")
  @ApiOperation({ summary: "获取粉丝列表" })
  @ApiParam({ name: "userId", description: "用户ID" })
  async getFollowers(
    @CurrentUser() user: User,
    @Param("userId") userId: string,
    @Query() query: QueryCommunityUsersDto,
  ) {
    const targetUserId = this.parseId(userId, "用户ID");
    const result = await this.communityFollowService.getFollowers(
      user.id,
      targetUserId,
      query,
    );

    return {
      code: 0,
      message: "获取成功",
      data: result.data,
      meta: {
        total: result.total,
        page: result.page,
        limit: result.limit,
        totalPages: result.totalPages,
      },
    };
  }

  /**
   * 获取关注列表
   */
  @Get("users/:userId/followings")
  @ApiOperation({ summary: "获取关注列表" })
  @ApiParam({ name: "userId", description: "用户ID" })
  async getFollowings(
    @CurrentUser() user: User,
    @Param("userId") userId: string,
    @Query() query: QueryCommunityUsersDto,
  ) {
    const targetUserId = this.parseId(userId, "用户ID");
    const result = await this.communityFollowService.getFollowings(
      user.id,
      targetUserId,
      query,
    );

    return {
      code: 0,
      message: "获取成功",
      data: result.data,
      meta: {
        total: result.total,
        page: result.page,
        limit: result.limit,
        totalPages: result.totalPages,
      },
    };
  }

  /**
   * 编辑帖子
   */
  @Put("posts/:id")
  @ApiOperation({ summary: "编辑帖子" })
  @ApiParam({ name: "id", description: "帖子ID" })
  @UseGuards(PostOwnerGuard)
  async updatePost(
    @Param("id") id: string,
    @CurrentUser() user: User,
    @Body() dto: UpdatePostDto,
  ) {
    const post = await this.postService.update(
      this.parseId(id, "帖子ID"),
      user.id,
      dto,
    );
    return {
      code: 0,
      message: "更新成功",
      data: post,
    };
  }

  /**
   * 删除帖子
   */
  @Delete("posts/:id")
  @ApiOperation({ summary: "删除帖子" })
  @ApiParam({ name: "id", description: "帖子ID" })
  @UseGuards(PostOwnerGuard)
  async deletePost(@Param("id") id: string, @CurrentUser() user: User) {
    const postId = this.parseId(id, "帖子ID");
    await this.postService.delete(postId, user.id);
    return {
      code: 0,
      message: "删除成功",
    };
  }

  /**
   * 点赞帖子
   */
  @Post("posts/:id/like")
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: "点赞帖子" })
  @ApiParam({ name: "id", description: "帖子ID" })
  async likePost(@CurrentUser() user: User, @Param("id") id: string) {
    await this.likeService.likePost(user.id, this.parseId(id, "帖子ID"));
    return {
      code: 0,
      message: "点赞成功",
    };
  }

  /**
   * 取消点赞帖子
   */
  @Delete("posts/:id/like")
  @ApiOperation({ summary: "取消点赞帖子" })
  @ApiParam({ name: "id", description: "帖子ID" })
  async unlikePost(@CurrentUser() user: User, @Param("id") id: string) {
    await this.likeService.unlikePost(user.id, this.parseId(id, "帖子ID"));
    return {
      code: 0,
      message: "取消点赞成功",
    };
  }

  /**
   * 发表评论
   */
  @Post("posts/:id/comments")
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: "发表评论" })
  @ApiParam({ name: "id", description: "帖子ID" })
  async createComment(
    @CurrentUser() user: User,
    @Param("id") id: string,
    @Body() dto: CreateCommentDto,
  ) {
    const postId = this.parseId(id, "帖子ID");
    const comment = await this.commentService.create(user.id, postId, dto);
    return {
      code: 0,
      message: "评论成功",
      data: comment,
    };
  }

  /**
   * 获取评论列表
   */
  @Get("posts/:id/comments")
  @ApiOperation({ summary: "获取评论列表" })
  @ApiParam({ name: "id", description: "帖子ID" })
  async getComments(
    @CurrentUser() user: User,
    @Param("id") id: string,
    @Query("page") page: string = "1",
    @Query("limit") limit: string = "10",
  ) {
    const postId = this.parseId(id, "帖子ID");
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    if (isNaN(pageNum) || pageNum < 1) {
      throw new BadRequestException("页码必须为正整数");
    }
    if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
      throw new BadRequestException("每页数量必须为1-100之间的整数");
    }

    const result = await this.commentService.findByPost(
      postId,
      pageNum,
      limitNum,
      user.id,
    );
    return {
      code: 0,
      message: "获取成功",
      data: result.data,
      meta: {
        total: result.total,
        page: pageNum,
        limit: limitNum,
      },
    };
  }

  /**
   * 点赞评论
   */
  @Post("comments/:id/like")
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: "点赞评论" })
  @ApiParam({ name: "id", description: "评论ID" })
  async likeComment(@CurrentUser() user: User, @Param("id") id: string) {
    await this.likeService.likeComment(user.id, this.parseId(id, "评论ID"));
    return {
      code: 0,
      message: "点赞成功",
    };
  }

  /**
   * 取消点赞评论
   */
  @Delete("comments/:id/like")
  @ApiOperation({ summary: "取消点赞评论" })
  @ApiParam({ name: "id", description: "评论ID" })
  async unlikeComment(@CurrentUser() user: User, @Param("id") id: string) {
    await this.likeService.unlikeComment(user.id, this.parseId(id, "评论ID"));
    return {
      code: 0,
      message: "取消点赞成功",
    };
  }

  /**
   * 删除评论
   */
  @Delete("comments/:id")
  @ApiOperation({ summary: "删除评论" })
  @ApiParam({ name: "id", description: "评论ID" })
  async deleteComment(@CurrentUser() user: User, @Param("id") id: string) {
    const commentId = this.parseId(id, "评论ID");
    await this.commentService.delete(commentId, user.id);
    return {
      code: 0,
      message: "删除成功",
    };
  }

  /**
   * 获取热门标签
   */
  @Get("tags/hot")
  @ApiOperation({ summary: "获取热门标签" })
  async getHotTags() {
    const tags = await this.postService.findHotTags(20);
    return {
      code: 0,
      message: "获取成功",
      data: tags,
    };
  }

  /**
   * 搜索标签
   */
  @Get("tags/search")
  @ApiOperation({ summary: "搜索标签" })
  @ApiQuery({ name: "keyword", description: "搜索关键词", required: true })
  async searchTags(@Query("keyword") keyword: string) {
    if (!keyword || keyword.trim().length === 0) {
      return {
        code: 0,
        message: "获取成功",
        data: [],
      };
    }

    const trimmed = keyword.trim();
    if (trimmed.length > 50) {
      throw new BadRequestException("搜索关键词不能超过 50 字符");
    }

    const tags = await this.postService.searchTags(trimmed, 20);
    return {
      code: 0,
      message: "获取成功",
      data: tags,
    };
  }
}
