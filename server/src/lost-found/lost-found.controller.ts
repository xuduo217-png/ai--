import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { LostFoundService } from './lost-found.service';
import { LostFoundCommentsService } from './lost-found-comments.service';
import { CreateLostFoundDto } from './dto/create-lost-found.dto';
import { CreateLostFoundCommentDto } from './dto/create-lost-found-comment.dto';
import { QueryLostFoundCommentsDto } from './dto/query-lost-found-comments.dto';
import { UpdateLostFoundDto } from './dto/update-lost-found.dto';
import { QueryLostFoundDto } from './dto/query-lost-found.dto';
import { PublisherType } from './entities/lost-found.entity';
import { User, UserRole } from '../users/entities/user.entity';

/**
 * 走失招领控制器
 *
 * 提供走失/领养信息的 API 接口
 * - 用户端：创建、查看、标记已找回自己的走失信息
 * - 管理员：所有功能 + 置顶设置
 */
@ApiTags('走失招领管理')
@Controller('lost-found')
export class LostFoundController {
  constructor(
    private readonly lostFoundService: LostFoundService,
    private readonly lostFoundCommentsService: LostFoundCommentsService,
  ) {}

  // ==================== 公开接口 ====================

  /**
   * 获取走失信息列表（公开）
   */
  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取走失/领养信息列表' })
  async findAll(@Query() queryDto: QueryLostFoundDto, @Request() req) {
    return await this.lostFoundService.findAll(queryDto, req.user?.id);
  }

  /**
   * 获取走失信息详情（公开）
   */
  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取走失/领养信息详情' })
  async findOne(@Param('id') id: string, @Request() req) {
    return await this.lostFoundService.findOne(+id, req.user?.id);
  }

  /**
   * 获取评论列表（公开）
   */
  @Get(':id/comments')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取走失/领养评论列表' })
  @ApiParam({ name: 'id', description: '走失招领信息 ID' })
  async getComments(
    @Param('id') id: string,
    @Query() queryDto: QueryLostFoundCommentsDto,
    @Request() req,
  ) {
    return await this.lostFoundCommentsService.findByLostFound(
      +id,
      queryDto.page,
      queryDto.pageSize,
      req.user?.id,
    );
  }

  // ==================== 认证接口 ====================

  /**
   * 创建走失信息（用户/管理员）
   */
  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('USER', 'SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建走失/领养信息' })
  async create(
    @Body() createDto: CreateLostFoundDto,
    @CurrentUser() user: User,
  ) {
    const publisherType = user.role === UserRole.USER ? PublisherType.USER : PublisherType.ADMIN;
    return await this.lostFoundService.create(createDto, user.id, publisherType);
  }

  /**
   * 创建评论（用户/管理员）
   */
  @Post(':id/comments')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('USER', 'SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '发表评论/回复' })
  @ApiParam({ name: 'id', description: '走失招领信息 ID' })
  async createComment(
    @Param('id') id: string,
    @Body() createDto: CreateLostFoundCommentDto,
    @CurrentUser() user: User,
  ) {
    return {
      message: '评论成功',
      data: await this.lostFoundCommentsService.create(user.id, +id, createDto),
    };
  }

  /**
   * 更新走失信息
   */
  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('USER', 'SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新走失/领养信息' })
  async update(
    @Param('id') id: string,
    @Body() updateDto: UpdateLostFoundDto,
    @CurrentUser() user: User,
  ) {
    return await this.lostFoundService.update(+id, updateDto, user.id, user.role);
  }

  /**
   * 设置/取消置顶（仅管理员）
   */
  @Patch(':id/pin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '设置/取消置顶' })
  async togglePin(@Param('id') id: string) {
    return await this.lostFoundService.togglePin(+id);
  }

  /**
   * 标记已找回
   */
  @Patch(':id/found')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('USER', 'SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '标记已找回' })
  async markAsFound(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    return await this.lostFoundService.markAsFound(+id, user.id, user.role);
  }

  /**
   * 删除走失信息
   */
  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('USER', 'SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除走失信息' })
  async remove(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ) {
    await this.lostFoundService.remove(+id, user.id, user.role);
    return { message: '删除成功' };
  }
}
