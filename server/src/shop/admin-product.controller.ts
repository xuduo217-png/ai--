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
import { SecondHandProductService } from './second-hand-product.service';
import { ShopService } from './shop.service';
import { ReviewProductDto, QueryPendingProductsDto } from './dto/review-product.dto';
import {
  UpdateMallHomepageBannersDto,
  UpdateMallHotProductsDto,
} from './dto/homepage-config.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

/**
 * 后台管理 - 商品审核 API
 */
@Controller('admin/shop')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('SUPER_ADMIN', 'STAFF', 'HOSPITAL_ADMIN')
export class AdminProductController {
  constructor(
    private readonly secondHandProductService: SecondHandProductService,
    private readonly shopService: ShopService,
  ) {}

  /**
   * 获取待审核商品列表
   * GET /server-api/admin/shop/pending-products
   */
  @Get('pending-products')
  async getPendingProducts(@Query() query: QueryPendingProductsDto) {
    return await this.secondHandProductService.getPendingProducts(query);
  }

  /**
   * 获取待审核商品详情
   * GET /server-api/admin/shop/pending-products/:id
   */
  @Get('pending-products/:id')
  async getPendingProductDetail(@Param('id') id: string) {
    return await this.secondHandProductService.getPendingProductDetailForAdmin(Number(id));
  }

  /**
   * 审核商品
   * POST /server-api/admin/shop/pending-products/:id/review
   */
  @Post('pending-products/:id/review')
  async reviewProduct(
    @Param('id') id: string,
    @Body() dto: ReviewProductDto,
    @Request() req,
  ) {
    const adminId = req.user.id;
    return await this.secondHandProductService.reviewProduct(
      Number(id),
      dto,
      adminId,
    );
  }

  /**
   * 获取商城首页热门商品配置
   * GET /server-api/admin/shop/homepage-hot-products
   */
  @Get('homepage-hot-products')
  async getMallHomepageHotProductsConfig() {
    return await this.shopService.getMallHomepageHotProductsConfig();
  }

  /**
   * 更新商城首页热门商品配置
   * PUT /server-api/admin/shop/homepage-hot-products
   */
  @Put('homepage-hot-products')
  async updateMallHomepageHotProductsConfig(
    @Body() dto: UpdateMallHotProductsDto,
  ) {
    return await this.shopService.updateMallHomepageHotProductsConfig(
      dto.productIds || [],
    );
  }

  /**
   * 获取商城首页 Banner 配置
   * GET /server-api/admin/shop/homepage-banners
   */
  @Get('homepage-banners')
  async getMallHomepageBannersConfig() {
    return await this.shopService.getMallHomepageBanners();
  }

  /**
   * 更新商城首页 Banner 配置
   * PUT /server-api/admin/shop/homepage-banners
   */
  @Put('homepage-banners')
  async updateMallHomepageBannersConfig(
    @Body() dto: UpdateMallHomepageBannersDto,
  ) {
    return await this.shopService.updateMallHomepageBanners(dto.banners || []);
  }
}
