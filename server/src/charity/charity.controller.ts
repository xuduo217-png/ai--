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
  Headers,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';
import { CharityService } from './charity.service';
import { CreateCharityDto } from './dto/create-charity.dto';
import { UpdateCharityDto } from './dto/update-charity.dto';
import { QueryCharityDto } from './dto/query-charity.dto';
import { CheckInDto } from './dto/check-in.dto';
import { DonateCharityDto } from './dto/donate-charity.dto';
import { PublishArticleDto } from './dto/publish-article.dto';
import { UpdateCharityArticleDto } from './dto/update-article.dto';
import { CreateCharityDonationPaymentDto } from './dto/create-charity-donation-payment.dto';

/**
 * 公益(Charity)控制器
 *
 * 提供用户端和管理员的公益管理接口
 * - 用户端：查看公益、签到打卡、查看记录
 * - 管理员：CRUD公益、发布文章、统计数据
 */
@ApiTags('公益管理')
@Controller('charity')
export class CharityController {
  constructor(private readonly charityService: CharityService) {}

  // ==================== 管理员接口 ====================
  // 注意：管理员接口必须放在用户端接口之前，因为路由匹配是从上到下的
  // /admin/list 必须在 /:id 之前，否则 admin 会被当作 id 参数

  /**
   * 获取公益列表（管理员）
   */
  @Get('admin/list')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取公益列表（管理员）' })
  async findAll(@Query() queryDto: QueryCharityDto) {
    return await this.charityService.findAll(queryDto);
  }

  /**
   * 创建公益（管理员）
   */
  @Post('admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建公益' })
  async create(@Body() createCharityDto: CreateCharityDto) {
    return await this.charityService.create(createCharityDto);
  }

  /**
   * 更新公益（管理员）
   */
  @Put('admin/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新公益' })
  async update(
    @Param('id') id: string,
    @Body() updateCharityDto: UpdateCharityDto,
  ) {
    return await this.charityService.update(+id, updateCharityDto);
  }

  /**
   * 删除公益（管理员）
   */
  @Delete('admin/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除公益' })
  async remove(@Param('id') id: string) {
    await this.charityService.remove(+id);
    return { message: '删除成功' };
  }

  /**
   * 获取公益统计数据（管理员）
   */
  @Get('admin/:id/stats')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取公益统计数据' })
  async getStats(@Param('id') id: string) {
    return await this.charityService.getStats(+id);
  }

  /**
   * 获取参与者列表（管理员）
   */
  @Get('admin/:id/participants')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取参与者列表' })
  async getParticipants(
    @Param('id') id: string,
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
  ) {
    return await this.charityService.getParticipants(+id, +page, +pageSize);
  }

  /**
   * 发布文章给参与者（管理员）
   * 规则：
   * 1. 公益必须已结束（状态为 EXPIRED）
   * 2. 每个公益只能发布一篇文章
   */
  @Post('admin/:id/article')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '发布文章给参与者（公益必须已结束）' })
  async publishArticle(
    @Param('id') id: string,
    @Body() publishArticleDto: PublishArticleDto,
    @Request() req,
  ) {
    const publisherId = req.user.id;
    return await this.charityService.publishArticle(+id, publishArticleDto, publisherId);
  }

  /**
   * 更新公益文章（管理员）
   * 只能编辑已发布的文章
   */
  @Put('admin/:id/article/:articleId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新公益文章' })
  async updateArticle(
    @Param('id') id: string,
    @Param('articleId') articleId: string,
    @Body() updateArticleDto: UpdateCharityArticleDto,
    @Request() req,
  ) {
    const publisherId = req.user.id;
    return await this.charityService.updateArticle(+id, +articleId, updateArticleDto, publisherId);
  }

  /**
   * 获取公益已发布的文章（管理员）
   * 用于编辑时获取文章内容
   */
  @Get('admin/:id/article')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取公益已发布的文章' })
  async getPublishedArticle(@Param('id') id: string) {
    return await this.charityService.getPublishedArticle(+id);
  }

  /**
   * 获取公益文章列表（管理员）
   * 返回该公益下全部已发布文章，不按当前登录用户过滤
   */
  @Get('admin/:id/articles')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.SUPER_ADMIN, UserRole.HOSPITAL_ADMIN, UserRole.STAFF)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取公益文章列表（管理员）' })
  async getAdminArticles(@Param('id') id: string) {
    return await this.charityService.getAdminArticles(+id);
  }

  // ==================== 用户端接口 ====================

  /**
   * 获取首页公告使用的最新捐赠记录
   */
  @Get('latest-donations')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取最新捐赠记录（首页公告）' })
  async getLatestDonationRecords() {
    return await this.charityService.getLatestDonationRecords();
  }

  /**
   * 获取公益列表（用户端）
   */
  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取公益列表（用户端，可选登录）' })
  async findUserActivities(@Query() queryDto: QueryCharityDto, @Request() req) {
    const userId = req.user?.id;
    return await this.charityService.findUserActivities(queryDto, userId);
  }

  /**
   * 获取公益详情（用户端）
   */
  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取公益详情（用户端，可选登录）' })
  async findOne(@Param('id') id: string, @Request() req) {
    const userId = req.user?.id;
    return await this.charityService.findOne(+id, userId);
  }

  /**
   * 签到打卡
   */
  @Post(':id/checkin')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '签到打卡' })
  async checkIn(
    @Param('id') id: string,
    @Body() checkInDto: CheckInDto,
    @Request() req,
  ) {
    const userId = req.user.id;
    return await this.charityService.checkIn(userId, +id, checkInDto);
  }

  /**
   * 爱心捐款（当前仅支持余额支付）
   */
  @Post(':id/donate')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '爱心捐款（当前仅支持余额支付）' })
  async donate(
    @Param('id') id: string,
    @Body() donateCharityDto: DonateCharityDto,
    @Request() req,
  ) {
    const userId = req.user.id;
    return await this.charityService.donate(userId, +id, donateCharityDto);
  }

  /**
   * 创建公益支付宝捐款支付单
   */
  @Post(':id/donations/payment')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建公益支付宝捐款支付单' })
  async createDonationPayment(
    @Param('id') id: string,
    @Headers('idempotency-key') idempotencyKey: string,
    @Body() body: CreateCharityDonationPaymentDto,
    @Request() req,
  ) {
    const parsedKey = await new ParseUUIDPipe({ version: '4' }).transform(
      idempotencyKey,
      { type: 'custom' },
    );
    return await this.charityService.createDonationPayment(
      req.user.id,
      +id,
      parsedKey,
      body,
    );
  }

  /**
   * 获取用户的打卡记录
   */
  @Get(':id/records')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取用户的打卡记录' })
  async getUserRecords(
    @Param('id') id: string,
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
    @Request() req,
  ) {
    const userId = req.user.id;
    return await this.charityService.getUserRecords(+id, userId, +page, +pageSize);
  }

  /**
   * 获取公益捐款明细
   */
  @Get(':id/donations')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取公益捐款明细（可选登录）' })
  async getDonationRecords(
    @Param('id') id: string,
    @Query('page') page: string = '1',
    @Query('pageSize') pageSize: string = '10',
  ) {
    return await this.charityService.getDonationRecords(+id, +page, +pageSize);
  }

  /**
   * 获取公益文章列表
   */
  @Get(':id/articles')
  @UseGuards(OptionalJwtAuthGuard)
  @ApiOperation({ summary: '获取公益文章列表（可选登录）' })
  async getArticles(@Param('id') id: string, @Request() req) {
    const userId = req.user?.id;
    return await this.charityService.getArticles(+id, userId);
  }
}
