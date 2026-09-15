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
  ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiResponse,
} from '@nestjs/swagger';
import { HealthArticlesService } from './health-articles.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateArticleDto } from './dto/create-article.dto';
import { UpdateHealthArticleDto } from './dto/update-article.dto';
import { QueryArticleDto } from './dto/query-article.dto';
import { CreateHealthCategoryDto } from './dto/create-category.dto';
import { UpdateHealthCategoryDto } from './dto/update-category.dto';
import { QueryCategoryDto } from './dto/query-category.dto';

@ApiTags('health-articles')
@ApiBearerAuth()
@Controller('health-articles')
@UseGuards(JwtAuthGuard, RolesGuard)
export class HealthArticlesController {
  constructor(private readonly healthArticlesService: HealthArticlesService) {}

  // ========== 分类管理接口 ==========

  /**
   * 获取分类列表
   * 所有登录用户可访问
   */
  @Get('categories')
  @ApiOperation({ summary: '获取分类列表' })
  @ApiResponse({ status: 200, description: '成功返回分类列表' })
  findAllCategories(@Query() query: QueryCategoryDto) {
    return this.healthArticlesService.findAllCategories(query);
  }

  /**
   * 获取分类详情
   * 所有登录用户可访问
   */
  @Get('categories/:id')
  @ApiOperation({ summary: '获取分类详情' })
  @ApiResponse({ status: 200, description: '成功返回分类详情' })
  @ApiResponse({ status: 404, description: '分类不存在' })
  findOneCategory(@Param('id', ParseIntPipe) id: number) {
    return this.healthArticlesService.findOneCategory(id);
  }

  /**
   * 创建分类
   * 仅超级管理员可访问
   */
  @Post('categories')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '创建分类（管理员）' })
  @ApiResponse({ status: 201, description: '分类创建成功' })
  @ApiResponse({ status: 400, description: '请求参数错误' })
  createCategory(@Body() dto: CreateHealthCategoryDto) {
    return this.healthArticlesService.createCategory(dto);
  }

  /**
   * 更新分类
   * 仅超级管理员可访问
   */
  @Put('categories/:id')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '更新分类（管理员）' })
  @ApiResponse({ status: 200, description: '分类更新成功' })
  @ApiResponse({ status: 404, description: '分类不存在' })
  updateCategory(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateHealthCategoryDto,
  ) {
    return this.healthArticlesService.updateCategory(id, dto);
  }

  /**
   * 删除分类
   * 仅超级管理员可访问
   */
  @Delete('categories/:id')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '删除分类（管理员）' })
  @ApiResponse({ status: 200, description: '分类删除成功' })
  @ApiResponse({ status: 404, description: '分类不存在' })
  removeCategory(@Param('id', ParseIntPipe) id: number) {
    return this.healthArticlesService.removeCategory(id);
  }

  // ========== 文章查询接口（所有登录用户可访问） ==========

  /**
   * 获取文章列表
   * 所有登录用户可访问
   */
  @Get()
  @ApiOperation({ summary: '获取文章列表' })
  @ApiResponse({ status: 200, description: '成功返回文章列表' })
  findAllArticles(@Query() query: QueryArticleDto) {
    return this.healthArticlesService.findAllArticles(query);
  }

  /**
   * 获取文章详情
   * 所有登录用户可访问
   */
  @Get(':id')
  @ApiOperation({ summary: '获取文章详情' })
  @ApiResponse({ status: 200, description: '成功返回文章详情' })
  @ApiResponse({ status: 404, description: '文章不存在' })
  findOneArticle(@Param('id', ParseIntPipe) id: number) {
    return this.healthArticlesService.findOneArticle(id);
  }

  // ========== 文章管理接口（仅超级管理员可访问） ==========

  /**
   * 创建文章
   * 仅超级管理员可访问
   */
  @Post()
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '创建文章（管理员）' })
  @ApiResponse({ status: 201, description: '文章创建成功' })
  @ApiResponse({ status: 400, description: '请求参数错误' })
  createArticle(@Body() dto: CreateArticleDto, @CurrentUser() user: any) {
    return this.healthArticlesService.createArticle(dto, user.id);
  }

  /**
   * 更新文章
   * 仅超级管理员可访问
   */
  @Put(':id')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '更新文章（管理员）' })
  @ApiResponse({ status: 200, description: '文章更新成功' })
  @ApiResponse({ status: 404, description: '文章不存在' })
  updateArticle(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateHealthArticleDto,
  ) {
    return this.healthArticlesService.updateArticle(id, dto);
  }

  /**
   * 删除文章
   * 仅超级管理员可访问
   */
  @Delete(':id')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '删除文章（管理员）' })
  @ApiResponse({ status: 200, description: '文章删除成功' })
  @ApiResponse({ status: 404, description: '文章不存在' })
  removeArticle(@Param('id', ParseIntPipe) id: number) {
    return this.healthArticlesService.removeArticle(id);
  }

  /**
   * 发布文章
   * 仅超级管理员可访问
   */
  @Post(':id/publish')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '发布文章（管理员）' })
  @ApiResponse({ status: 200, description: '文章发布成功' })
  @ApiResponse({ status: 400, description: '文章已发布' })
  @ApiResponse({ status: 404, description: '文章不存在' })
  publishArticle(@Param('id', ParseIntPipe) id: number) {
    return this.healthArticlesService.publishArticle(id);
  }

  /**
   * 取消发布文章
   * 仅超级管理员可访问
   */
  @Post(':id/unpublish')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '取消发布文章（管理员）' })
  @ApiResponse({ status: 200, description: '文章已取消发布' })
  @ApiResponse({ status: 400, description: '文章已是草稿状态' })
  @ApiResponse({ status: 404, description: '文章不存在' })
  unpublishArticle(@Param('id', ParseIntPipe) id: number) {
    return this.healthArticlesService.unpublishArticle(id);
  }
}
