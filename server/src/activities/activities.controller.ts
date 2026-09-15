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
  Request,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';
import { ActivitiesService } from './activities.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { UpdateActivityDto } from './dto/update-activity.dto';
import { QueryActivityDto } from './dto/query-activity.dto';
import { CreateActivityCommentDto } from './dto/create-activity-comment.dto';
import { QueryActivityCommentsDto } from './dto/query-activity-comments.dto';
import { RegisterActivityDto } from './dto/register-activity.dto';
import { VoteActivityDto } from './dto/vote-activity.dto';
import { UserVoteOptionDto } from './dto/user-vote-option.dto';

/**
 * 活动(Activity)控制器
 *
 * 提供用户端和管理员的活动管理接口
 * - 用户端：查看活动、报名活动
 * - 管理员：CRUD活动、查看报名列表
 */
@ApiTags('活动管理')
@Controller('activities')
export class ActivitiesController {
  constructor(private readonly activitiesService: ActivitiesService) {}

  // ==================== 管理员接口 ====================
  // 注意：管理员接口必须放在用户端接口之前，因为路由匹配是从上到下的
  // /admin/list 必须在 /:id 之前，否则 admin 会被当作 id 参数

  /**
   * 获取活动列表（管理员）
   */
  @Get('admin/list')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取活动列表（管理员）' })
  async findAll(@Query() queryDto: QueryActivityDto) {
    return await this.activitiesService.findAll(queryDto);
  }

  /**
   * 创建活动（管理员）
   */
  @Post('admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建活动' })
  async create(@Body() createActivityDto: CreateActivityDto) {
    return await this.activitiesService.create(createActivityDto);
  }

  /**
   * 更新活动（管理员）
   */
  @Put('admin/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新活动' })
  async update(
    @Param('id') id: string,
    @Body() updateActivityDto: UpdateActivityDto,
  ) {
    return await this.activitiesService.update(+id, updateActivityDto);
  }

  /**
   * 删除活动（管理员）
   */
  @Delete('admin/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除活动' })
  async remove(@Param('id') id: string) {
    await this.activitiesService.remove(+id);
    return { message: '删除成功' };
  }

  /**
   * 获取活动的报名用户列表（管理员）
   */
  @Get('admin/:id/registrations')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取活动的报名用户列表' })
  async getRegistrations(
    @Param('id') id: string,
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
    @Query('voteOptionId') voteOptionId?: string,
  ) {
    return await this.activitiesService.getRegistrations(
      +id,
      +page,
      +pageSize,
      voteOptionId ? +voteOptionId : undefined,
    );
  }

  /**
   * 获取活动评论列表（管理员）
   */
  @Get('admin/:id/comments')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取活动评论列表（管理员）' })
  async getAdminActivityComments(
    @Param('id') id: string,
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
  ) {
    return await this.activitiesService.findActivityComments(
      +id,
      +page,
      +pageSize,
    );
  }

  /**
   * 删除活动评论（管理员）
   */
  @Delete('admin/comments/:commentId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除活动评论（管理员）' })
  async deleteAdminActivityComment(@Param('commentId') commentId: string) {
    return {
      message: '删除成功',
      data: await this.activitiesService.deleteActivityComment(+commentId),
    };
  }

  // ==================== 用户端接口 ====================

  /**
   * 获取活动列表（用户端）
   * 路径: /server-api/activities/app
   * 可选认证：未登录用户可以查看，登录用户会显示是否已报名
   */
  @Get('app')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取活动列表（用户端）' })
  async findUserActivities(@Query() queryDto: QueryActivityDto, @Request() req) {
    const userId = req.user?.id;
    return await this.activitiesService.findUserActivities(queryDto, userId);
  }

  /**
   * 获取活动详情（用户端）
   * 路径: /server-api/activities/app/:id
   * 可选认证：未登录用户可以查看，登录用户会显示是否已报名
   */
  @Get('app/:id')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取活动详情（用户端）' })
  async findOneUser(@Param('id') id: string, @Request() req) {
    const userId = req.user?.id;
    return await this.activitiesService.findOneUser(+id, userId);
  }

  /**
   * 获取活动参与者列表（用户端，线上活动用于展示投票人）
   * 路径: /server-api/activities/app/:id/participants
   */
  @Get('app/:id/participants')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取活动参与者列表（用户端）' })
  async getParticipants(
    @Param('id') id: string,
    @Query() query: QueryActivityDto,
  ) {
    return await this.activitiesService.getParticipants(
      +id,
      query.page ?? 1,
      query.pageSize ?? 10,
    );
  }

  /**
   * 获取活动评论列表（用户端，仅线上投票活动）
   * 路径: /server-api/activities/app/:id/comments
   */
  @Get('app/:id/comments')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取活动评论列表（用户端）' })
  async getActivityComments(
    @Param('id') id: string,
    @Query() query: QueryActivityCommentsDto,
    @Request() req?: any,
  ) {
    const userId = req?.user?.id;
    if (userId) {
      return await this.activitiesService.findActivityComments(
        +id,
        query.page ?? 1,
        query.pageSize ?? 20,
        undefined,
        userId,
      );
    }

    return await this.activitiesService.findActivityComments(
      +id,
      query.page ?? 1,
      query.pageSize ?? 20,
    );
  }

  /**
   * 创建活动评论（用户端，仅线上投票活动）
   * 路径: /server-api/activities/app/:id/comments
   */
  @Post('app/:id/comments')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '发表评论/回复活动评论' })
  async createActivityComment(
    @Param('id') id: string,
    @Body() createDto: CreateActivityCommentDto,
    @Request() req,
  ) {
    return {
      message: '评论成功',
      data: await this.activitiesService.createActivityComment(
        req.user.id,
        +id,
        createDto,
      ),
    };
  }

  /**
   * 获取选手评论列表（用户端，仅线上投票活动）
   * 路径: /server-api/activities/app/:id/vote-options/:optionId/comments
   */
  @Get('app/:id/vote-options/:optionId/comments')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取选手评论列表（用户端）' })
  async getActivityVoteOptionComments(
    @Param('id') id: string,
    @Param('optionId') optionId: string,
    @Query() query: QueryActivityCommentsDto,
    @Request() req?: any,
  ) {
    const userId = req?.user?.id;
    if (userId) {
      return await this.activitiesService.findActivityComments(
        +id,
        query.page ?? 1,
        query.pageSize ?? 20,
        +optionId,
        userId,
      );
    }

    return await this.activitiesService.findActivityComments(
      +id,
      query.page ?? 1,
      query.pageSize ?? 20,
      +optionId,
    );
  }

  /**
   * 创建选手评论（用户端，仅线上投票活动）
   * 路径: /server-api/activities/app/:id/vote-options/:optionId/comments
   */
  @Post('app/:id/vote-options/:optionId/comments')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '发表/回复选手评论' })
  async createActivityVoteOptionComment(
    @Param('id') id: string,
    @Param('optionId') optionId: string,
    @Body() createDto: CreateActivityCommentDto,
    @Request() req,
  ) {
    return {
      message: '评论成功',
      data: await this.activitiesService.createActivityComment(
        req.user.id,
        +id,
        createDto,
        +optionId,
      ),
    };
  }

  /**
   * 用户投票活动（线上活动）
   * 路径: /server-api/activities/app/:id/vote
   */
  @Post('app/:id/vote')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '用户投票活动' })
  async vote(
    @Param('id') id: string,
    @Body() voteDto: VoteActivityDto,
    @Request() req,
  ) {
    const userId = req.user.id;
    const result = await this.activitiesService.vote(+id, userId, voteDto.optionId);
    return {
      success: true,
      message: '投票成功',
      data: result,
    };
  }

  /**
   * 用户报名线上投票活动，创建选手
   * 路径: /server-api/activities/app/:id/vote-options
   */
  @Post('app/:id/vote-options')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '用户报名线上投票活动，创建选手' })
  async createUserVoteOption(
    @Param('id') id: string,
    @Body() voteOptionDto: UserVoteOptionDto,
    @Request() req,
  ) {
    const userId = req.user.id;
    const result = await this.activitiesService.createUserVoteOption(+id, userId, voteOptionDto);
    return {
      success: true,
      message: '报名成功',
      data: result,
    };
  }

  /**
   * 用户编辑本人添加的线上投票选手
   * 路径: /server-api/activities/app/:id/vote-options/:optionId
   */
  @Put('app/:id/vote-options/:optionId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '用户编辑本人添加的线上投票选手' })
  async updateUserVoteOption(
    @Param('id') id: string,
    @Param('optionId') optionId: string,
    @Body() voteOptionDto: UserVoteOptionDto,
    @Request() req,
  ) {
    const userId = req.user.id;
    const result = await this.activitiesService.updateUserVoteOption(
      +id,
      +optionId,
      userId,
      voteOptionDto,
    );
    return {
      success: true,
      message: '保存成功',
      data: result,
    };
  }

  /**
   * 用户删除本人添加的线上投票选手
   * 路径: /server-api/activities/app/:id/vote-options/:optionId
   */
  @Delete('app/:id/vote-options/:optionId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '用户删除本人添加的线上投票选手' })
  async deleteUserVoteOption(
    @Param('id') id: string,
    @Param('optionId') optionId: string,
    @Request() req,
  ) {
    const userId = req.user.id;
    await this.activitiesService.deleteUserVoteOption(+id, +optionId, userId);
    return {
      success: true,
      message: '删除成功',
    };
  }

  /**
   * 用户报名活动
   * 路径: /server-api/activities/app/:id/register
   */
  @Post('app/:id/register')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '用户报名活动' })
  async register(
    @Param('id') id: string,
    @Body() registerDto: RegisterActivityDto,
    @Request() req,
  ) {
    const userId = req.user.id;
    const result = await this.activitiesService.register(+id, userId, registerDto);
    return {
      success: true,
      message: '报名成功',
      data: result,
    };
  }
}
