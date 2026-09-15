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
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam, ApiResponse } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/entities/user.entity';
import { Roles } from '../auth/decorators/roles.decorator';
import { PostService } from './post.service';
import { SensitiveWordService } from './sensitive-word.service';
import { CreateSensitiveWordDto, UpdateSensitiveWordDto, BatchImportSensitiveWordsDto, RejectPostDto } from './dto';
import { PostStatus } from './entities/post.entity';

/**
 * 社区管理 API
 * 面向 Admin 端
 */
@ApiTags('社区管理')
@Controller('admin/community')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN)
@ApiBearerAuth()
export class AdminCommunityController {
  constructor(
    private readonly postService: PostService,
    private readonly sensitiveWordService: SensitiveWordService,
  ) {}

  /**
   * 验证并解析 ID 参数
   */
  private parseId(id: string, fieldName: string = 'ID'): number {
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
   * 获取待审核列表
   */
  @Get('posts/pending')
  @ApiOperation({ summary: '获取待审核列表' })
  async getPendingPosts(
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
  ) {
    const pageNum = parseInt(page, 10);
    const pageSizeNum = parseInt(pageSize, 10);

    if (isNaN(pageNum) || isNaN(pageSizeNum)) {
      throw new BadRequestException('页码和每页数量必须为有效整数');
    }

    if (pageNum < 1 || pageSizeNum < 1 || pageSizeNum > 100) {
      throw new BadRequestException('页码必须>=1，每页数量必须在1-100之间');
    }

    const result = await this.postService.findPending(pageNum, pageSizeNum);
    return {
      code: 0,
      message: '获取成功',
      data: result.data,
      meta: {
        total: result.total,
        page: pageNum,
        pageSize: pageSizeNum,
      },
    };
  }

  /**
   * 审核通过
   */
  @Post('posts/:id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '审核通过' })
  @ApiParam({ name: 'id', description: '帖子ID' })
  async approvePost(@Param('id') id: string) {
    const postId = this.parseId(id, '帖子ID');
    const post = await this.postService.approve(postId);
    return {
      code: 0,
      message: '审核通过',
      data: post,
    };
  }

  /**
   * 审核拒绝
   */
  @Post('posts/:id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '审核拒绝' })
  @ApiParam({ name: 'id', description: '帖子ID' })
  async rejectPost(
    @Param('id') id: string,
    @Body() dto: RejectPostDto,
  ) {
    const postId = this.parseId(id, '帖子ID');
    const post = await this.postService.reject(postId, dto.rejectReason);
    return {
      code: 0,
      message: '已拒绝',
      data: post,
    };
  }

  /**
   * 获取已审核内容列表
   */
  @Get('posts')
  @ApiOperation({ summary: '获取已审核内容列表' })
  async getReviewedPosts(
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
    @Query('status') status?: string,
  ) {
    const pageNum = parseInt(page, 10);
    const pageSizeNum = parseInt(pageSize, 10);

    if (isNaN(pageNum) || isNaN(pageSizeNum)) {
      throw new BadRequestException('页码和每页数量必须为有效整数');
    }

    if (pageNum < 1 || pageSizeNum < 1 || pageSizeNum > 100) {
      throw new BadRequestException('页码必须>=1，每页数量必须在1-100之间');
    }

    // 解析状态参数
    let statusFilter: PostStatus | undefined;
    if (status === 'APPROVED' || status === 'REJECTED') {
      statusFilter = status as PostStatus;
    }

    const result = await this.postService.findReviewed(pageNum, pageSizeNum, statusFilter);
    return {
      code: 0,
      message: '获取成功',
      data: result.data,
      meta: {
        total: result.total,
        page: pageNum,
        pageSize: pageSizeNum,
      },
    };
  }

  /**
   * 删除帖子（管理员专用）
   */
  @Delete('posts/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '删除帖子' })
  @ApiParam({ name: 'id', description: '帖子ID' })
  async deletePost(@Param('id') id: string) {
    const postId = this.parseId(id, '帖子ID');
    await this.postService.adminDelete(postId);
    return {
      code: 0,
      message: '删除成功',
    };
  }

  /**
   * 置顶/取消置顶
   */
  @Put('posts/:id/pin')
  @ApiOperation({ summary: '置顶/取消置顶' })
  @ApiParam({ name: 'id', description: '帖子ID' })
  async togglePin(@Param('id') id: string) {
    const postId = this.parseId(id, '帖子ID');
    const post = await this.postService.togglePin(postId);
    return {
      code: 0,
      message: post.isPinned ? '已置顶' : '已取消置顶',
      data: post,
    };
  }

  /**
   * 加精/取消加精
   */
  @Put('posts/:id/feature')
  @ApiOperation({ summary: '加精/取消加精' })
  @ApiParam({ name: 'id', description: '帖子ID' })
  async toggleFeature(@Param('id') id: string) {
    const postId = this.parseId(id, '帖子ID');
    const post = await this.postService.toggleFeature(postId);
    return {
      code: 0,
      message: post.isFeatured ? '已加精' : '已取消加精',
      data: post,
    };
  }

  /**
   * 获取敏感词列表
   */
  @Get('sensitive-words')
  @ApiOperation({ summary: '获取敏感词列表' })
  async getSensitiveWords() {
    const words = await this.sensitiveWordService.findAll();
    return {
      code: 0,
      message: '获取成功',
      data: words,
    };
  }

  /**
   * 添加敏感词
   */
  @Post('sensitive-words')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: '添加敏感词' })
  async createSensitiveWord(@Body() dto: CreateSensitiveWordDto) {
    const word = await this.sensitiveWordService.create(dto);
    return {
      code: 0,
      message: '添加成功',
      data: word,
    };
  }

  /**
   * 更新敏感词
   */
  @Put('sensitive-words/:id')
  @ApiOperation({ summary: '更新敏感词' })
  @ApiParam({ name: 'id', description: '敏感词ID' })
  async updateSensitiveWord(
    @Param('id') id: string,
    @Body() dto: UpdateSensitiveWordDto,
  ) {
    const wordId = this.parseId(id, '敏感词ID');
    const word = await this.sensitiveWordService.update(wordId, dto);
    return {
      code: 0,
      message: '更新成功',
      data: word,
    };
  }

  /**
   * 删除敏感词
   */
  @Delete('sensitive-words/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '删除敏感词' })
  @ApiParam({ name: 'id', description: '敏感词ID' })
  async deleteSensitiveWord(@Param('id') id: string) {
    const wordId = this.parseId(id, '敏感词ID');
    await this.sensitiveWordService.delete(wordId);
    return {
      code: 0,
      message: '删除成功',
    };
  }

  /**
   * 批量导入敏感词
   */
  @Post('sensitive-words/batch')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: '批量导入敏感词' })
  async batchImportSensitiveWords(@Body() dto: BatchImportSensitiveWordsDto) {
    const result = await this.sensitiveWordService.batchImport(dto.words);
    return {
      code: 0,
      message: `成功导入 ${result.created} 个敏感词，跳过 ${result.skipped} 个`,
      data: result,
    };
  }
}
