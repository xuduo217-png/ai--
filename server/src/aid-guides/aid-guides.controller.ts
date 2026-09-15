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
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { AidGuidesService } from './aid-guides.service';
import { CreateGuideDto } from './dto/create-guide.dto';
import { UpdateGuideDto } from './dto/update-guide.dto';
import { QueryGuideDto } from './dto/query-guide.dto';
import { CreateAidGuideCategoryDto } from './dto/create-category.dto';
import { UpdateAidGuideCategoryDto } from './dto/update-category.dto';
import { QueryCategoryDto } from './dto/query-category.dto';

@ApiTags('急救指南管理')
@Controller('aid-guides')
export class AidGuidesController {
  constructor(private readonly aidGuidesService: AidGuidesService) {}

  // ==================== 分类管理 ====================

  /**
   * 获取分类列表
   */
  @Get('categories')
  @ApiOperation({ summary: '获取急救指南分类列表' })
  async findCategories(@Query() queryDto: QueryCategoryDto) {
    return await this.aidGuidesService.findCategories(queryDto);
  }

  /**
   * 获取分类详情
   */
  @Get('categories/:id')
  @ApiOperation({ summary: '获取分类详情' })
  async findCategoryById(@Param('id') id: string) {
    return await this.aidGuidesService.findCategoryById(+id);
  }

  /**
   * 创建分类（管理员）
   */
  @Post('categories')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建急救指南分类' })
  async createCategory(@Body() createCategoryDto: CreateAidGuideCategoryDto) {
    return await this.aidGuidesService.createCategory(createCategoryDto);
  }

  /**
   * 更新分类（管理员）
   */
  @Put('categories/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新急救指南分类' })
  async updateCategory(
    @Param('id') id: string,
    @Body() updateCategoryDto: UpdateAidGuideCategoryDto,
  ) {
    return await this.aidGuidesService.updateCategory(+id, updateCategoryDto);
  }

  /**
   * 切换分类启用状态（管理员）
   */
  @Patch('categories/:id/status')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '启用/禁用分类' })
  async toggleCategoryStatus(@Param('id') id: string) {
    return await this.aidGuidesService.toggleCategoryStatus(+id);
  }

  /**
   * 删除分类（管理员）
   */
  @Delete('categories/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除急救指南分类' })
  async deleteCategory(@Param('id') id: string) {
    await this.aidGuidesService.deleteCategory(+id);
    return { message: '删除成功' };
  }

  // ==================== 指南管理 ====================

  /**
   * 获取指南列表
   */
  @Get()
  @ApiOperation({ summary: '获取急救指南列表' })
  async findGuides(@Query() queryDto: QueryGuideDto) {
    return await this.aidGuidesService.findGuides(queryDto);
  }

  /**
   * 获取指南详情
   */
  @Get(':id')
  @ApiOperation({ summary: '获取急救指南详情' })
  async findGuideById(@Param('id') id: string) {
    return await this.aidGuidesService.findGuideById(+id);
  }

  /**
   * 创建指南（管理员）
   */
  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建急救指南' })
  async createGuide(
    @Body() createGuideDto: CreateGuideDto,
    @Request() req,
  ) {
    const authorId = req.user.id;
    return await this.aidGuidesService.createGuide(createGuideDto, authorId);
  }

  /**
   * 更新指南（管理员）
   */
  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新急救指南' })
  async updateGuide(
    @Param('id') id: string,
    @Body() updateGuideDto: UpdateGuideDto,
  ) {
    return await this.aidGuidesService.updateGuide(+id, updateGuideDto);
  }

  /**
   * 切换指南发布状态（管理员）
   */
  @Patch(':id/status')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '发布/下架指南' })
  async toggleGuideStatus(@Param('id') id: string) {
    return await this.aidGuidesService.toggleGuideStatus(+id);
  }

  /**
   * 删除指南（管理员）
   */
  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除急救指南' })
  async deleteGuide(@Param('id') id: string) {
    await this.aidGuidesService.deleteGuide(+id);
    return { message: '删除成功' };
  }

  /**
   * 获取指定分类下的指南
   */
  @Get('category/:categoryId')
  @ApiOperation({ summary: '获取指定分类下的急救指南' })
  async findGuidesByCategory(@Param('categoryId') categoryId: string) {
    return await this.aidGuidesService.findGuidesByCategory(+categoryId);
  }
}
