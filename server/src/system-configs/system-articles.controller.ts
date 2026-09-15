import { Controller, Get, Post, Put, Param, Body, UseGuards } from '@nestjs/common'
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger'
import { Public } from '../auth/decorators/public.decorator'
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'
import { SystemArticlesService } from './system-articles.service'
import { UpdateSystemArticleDto } from './dto/update-article.dto'
import { SystemArticle, ArticleType } from './entities/system-article.entity'

/**
 * 系统文章控制器
 */
@Controller('system-articles')
@ApiTags('系统文章管理')
@UseGuards(JwtAuthGuard)
export class SystemArticlesController {
  constructor(private readonly systemArticlesService: SystemArticlesService) {}

  /**
   * 获取所有文章列表
   * 业务说明：关于我们、隐私协议、用户协议需要在未登录场景下展示，因此读取接口必须允许游客访问
   */
  @Get()
  @Public()
  @ApiOperation({ summary: '获取所有系统文章' })
  @ApiResponse({ status: 200, description: '成功', type: [SystemArticle] })
  async findAll() {
    return await this.systemArticlesService.findAll()
  }

  /**
   * 根据类型获取文章
   * 业务说明：APP 首次启动会在未登录状态拉取隐私协议，因此这里不能要求 JWT
   */
  @Get(':type')
  @Public()
  @ApiOperation({ summary: '根据类型获取文章内容' })
  @ApiResponse({ status: 200, description: '成功', type: SystemArticle })
  async findByType(@Param('type') type: ArticleType) {
    return await this.systemArticlesService.findByType(type)
  }

  /**
   * 更新文章内容
   */
  @Put(':type')
  @ApiOperation({ summary: '更新文章内容' })
  @ApiResponse({ status: 200, description: '更新成功' })
  async update(
    @Param('type') type: ArticleType,
    @Body() updateDto: UpdateSystemArticleDto
  ) {
    return await this.systemArticlesService.update(type, updateDto)
  }

  /**
   * 初始化文章（仅开发/首次部署使用）
   */
  @Post('init')
  @ApiOperation({ summary: '初始化系统文章' })
  @ApiResponse({ status: 201, description: '初始化成功' })
  async initialize() {
    return await this.systemArticlesService.initializeArticles()
  }
}
