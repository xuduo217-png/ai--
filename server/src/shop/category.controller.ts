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
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CategoryService } from './category.service';
import { CreateProductCategoryDto } from './dto/create-category.dto';
import { UpdateProductCategoryDto } from './dto/update-category.dto';
import { QueryCategoryDto } from './dto/query-category.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

/**
 * 商品分类控制器
 * 提供商品分类的管理接口
 */
@ApiTags('shop/categories')
@Controller('shop/categories')
export class CategoryController {
  constructor(private readonly categoryService: CategoryService) {}

  /**
   * 获取分类列表（支持树形结构）
   * 公开接口，无需登录
   */
  @Get()
  @ApiOperation({ summary: '获取商品分类列表' })
  findAll(@Query() query: QueryCategoryDto) {
    return this.categoryService.findAll(query);
  }

  /**
   * 获取分类详情
   * 公开接口
   */
  @Get(':id')
  @ApiOperation({ summary: '获取商品分类详情' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.categoryService.findOne(id);
  }

  /**
   * 获取分类路径（从根到当前分类）
   * 公开接口
   */
  @Get(':id/path')
  @ApiOperation({ summary: '获取分类路径' })
  getPath(@Param('id', ParseIntPipe) id: number) {
    return this.categoryService.getPath(id);
  }

  /**
   * 创建商品分类（管理员）
   * 需要登录和角色权限
   */
  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建商品分类' })
  create(@Body() createCategoryDto: CreateProductCategoryDto) {
    return this.categoryService.create(createCategoryDto);
  }

  /**
   * 更新商品分类（管理员）
   * 需要登录和角色权限
   */
  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新商品分类' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateCategoryDto: UpdateProductCategoryDto,
  ) {
    return this.categoryService.update(id, updateCategoryDto);
  }

  /**
   * 更新分类排序（管理员）
   * 需要登录和角色权限
   */
  @Put(':id/sort')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新分类排序' })
  updateSort(
    @Param('id', ParseIntPipe) id: number,
    @Body('sortOrder') sortOrder: number,
  ) {
    return this.categoryService.updateSort(id, sortOrder);
  }

  /**
   * 删除商品分类（管理员）
   * 需要登录和角色权限
   */
  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除商品分类' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.categoryService.remove(id);
  }
}
