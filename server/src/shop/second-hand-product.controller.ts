import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import { Public } from '../auth/decorators/public.decorator';
import { SecondHandProductService } from './second-hand-product.service';
import { CreateProductPendingDto } from './dto/create-product-pending.dto';
import { UpdateProductStatusDto, QueryMyProductsDto } from './dto/update-product-status.dto';

/**
 * 二手商品前台 API
 */
@Controller('shop/products')
@UseGuards(JwtAuthGuard)
export class SecondHandProductController {
  constructor(private readonly secondHandProductService: SecondHandProductService) {}

  /**
   * 发布二手商品
   */
  @Post('pending')
  async createPendingProduct(@Request() req, @Body() dto: CreateProductPendingDto) {
    const userId = req.user.id;
    const product = await this.secondHandProductService.createPendingProduct(userId, dto);
    return {
      success: true,
      data: { id: product.id },
    };
  }

  /**
   * 编辑二手商品
   */
  @Put('pending/:id')
  async updatePendingProduct(
    @Param('id') id: string,
    @Request() req,
    @Body() dto: CreateProductPendingDto,
  ) {
    const userId = req.user.id;
    await this.secondHandProductService.updatePendingProduct(Number(id), userId, dto);
    return {
      success: true,
    };
  }

  /**
   * 获取待审核商品详情（编辑时使用）
   */
  @Get('pending/:id')
  async getPendingProductDetail(@Param('id') id: string, @Request() req) {
    const userId = req.user.id;
    const product = await this.secondHandProductService.getPendingProductDetail(Number(id), userId);
    return {
      success: true,
      data: product,
    };
  }

  /**
   * 我的商品列表
   */
  @Get('my')
  async getMyProducts(@Request() req, @Query() query: QueryMyProductsDto) {
    const userId = req.user.id;
    return await this.secondHandProductService.getMyProducts(userId, query);
  }

  /**
   * 获取二手商品分类
   * 注意：必须放在 `:id` 路由之前，避免被动态路由拦截
   */
  @Get('categories/list')
  @Public()
  async getSecondHandCategories() {
    const categories = await this.secondHandProductService.getSecondHandCategories();
    return {
      success: true,
      data: categories,
    };
  }

  /**
   * 商品详情
   */
  @Get(':id')
  @Public()
  @UseGuards(OptionalJwtAuthGuard)
  async getProductDetail(@Param('id') id: string, @Request() req) {
    const product = await this.secondHandProductService.getProductDetail(
      Number(id),
      req.user?.id,
    );
    return {
      success: true,
      data: product,
    };
  }

  /**
   * 上架/下架商品
   */
  @Put(':id/status')
  async updateProductStatus(
    @Param('id') id: string,
    @Request() req,
    @Body() dto: UpdateProductStatusDto,
  ) {
    const userId = req.user.id;
    await this.secondHandProductService.updateProductStatus(Number(id), userId, dto);
    return {
      success: true,
    };
  }
}
