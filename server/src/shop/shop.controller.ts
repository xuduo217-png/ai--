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
  ParseIntPipe,
  Request,
} from "@nestjs/common";
import { ShopService } from "./shop.service";
import { SecondHandProductService } from "./second-hand-product.service";
import { CreateProductDto } from "./dto/create-product.dto";
import { UpdateProductDto } from "./dto/update-product.dto";
import { CreateOrderDto } from "./dto/create-order.dto";
import { UpdateOrderStatusDto } from "./dto/update-order-status.dto";
import { UpdateShippingDto } from "./dto/update-shipping.dto";
import { QueryProductDto } from "./dto/query-product.dto";
import { QueryOrderDto } from "./dto/query-order.dto";
import { BatchGetProductsDto } from "./dto/batch-get-products.dto";
import { PreviewOrderDto } from "./dto/preview-order.dto";
import {
  CreateProductSkuDto,
  CreateProductSkuBatchDto,
} from "./dto/create-product-sku.dto";
import { UpdateProductSkuDto } from "./dto/update-product-sku.dto";
import { PayOrderDto } from "./dto/pay-order.dto";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { OptionalJwtAuthGuard } from "../auth/guards/optional-jwt-auth.guard";
import { RolesGuard } from "../auth/guards/roles.guard";
import { Roles } from "../auth/decorators/roles.decorator";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import { Public } from "../auth/decorators/public.decorator";
import { QueryMyProductsDto } from "./dto/update-product-status.dto";
import { ProductFavoriteService } from "./product-favorite.service";
import { AfterSaleService } from "./after-sale.service";
import { CreateAfterSaleDto } from "./dto/after-sale.dto";
import { SecondHandOrderService } from "./second-hand-order.service";

@Controller("shop")
export class ShopController {
  constructor(
    private readonly shopService: ShopService,
    private readonly secondHandProductService: SecondHandProductService,
    private readonly productFavoriteService: ProductFavoriteService,
    private readonly afterSaleService: AfterSaleService,
    private readonly secondHandOrderService: SecondHandOrderService,
  ) {}

  // Products
  // 商品列表（支持分页和筛选）
  @Get("products")
  @Public()
  @UseGuards(OptionalJwtAuthGuard)
  findAllProducts(@Query() query: QueryProductDto, @Request() req: any) {
    return this.shopService.findAllProducts(query, req.user?.id);
  }

  /**
   * 批量获取商品（完整分类树版本）
   * 注意：此路由必须定义在 @Get('products/:id') 之前，否则 'batch' 会被解析为 ID
   *
   * 返回所有一级分类、二级分类及商品，前端自行处理展示逻辑
   */
  @Get("products/batch")
  @Public()
  batchGetProducts(@Query() dto: BatchGetProductsDto) {
    return this.shopService.batchGetProducts(dto);
  }

  /**
   * 获取热门商品列表
   * 注意：此路由必须定义在 @Get('products/:id') 之前，否则 'popular' 会被解析为 ID
   */
  @Get("products/popular")
  @Public()
  @UseGuards(OptionalJwtAuthGuard)
  getPopularProducts(@Query() query: QueryProductDto, @Request() req: any) {
    return this.shopService.getPopularProducts(query, req.user?.id);
  }

  @Get("homepage-banners")
  @Public()
  getMallHomepageBanners() {
    return this.shopService.getMallHomepageBanners();
  }

  /**
   * 获取所有商品（用于选择器）
   * 注意：此路由必须定义在 @Get('products/:id') 之前，否则 'all' 会被解析为 ID
   */
  @Get("products/all")
  @Public()
  getAllProducts() {
    return this.shopService.getAllProducts();
  }

  /**
   * 获取我发布的商品（用户）
   * 注意：此路由必须定义在 @Get('products/:id') 之前，否则 'my' 会被解析为 ID
   * 委托给 SecondHandProductService 处理
   */
  @Get("products/my")
  @UseGuards(JwtAuthGuard)
  getMyProducts(@Request() req: any, @Query() query: QueryMyProductsDto) {
    return this.secondHandProductService.getMyProducts(req.user?.id, query);
  }

  @Get("products/:id")
  @Public()
  @UseGuards(OptionalJwtAuthGuard)
  findOneProduct(@Param("id", ParseIntPipe) id: number, @Request() req: any) {
    return this.shopService.findOneProduct(id, req.user?.id);
  }

  /**
   * 获取商品详情（附带收藏状态）
   * 为兼容 RN 端 `/shop/products/:id/detail` 旧调用而保留
   */
  @Get("products/:id/detail")
  @Public()
  @UseGuards(OptionalJwtAuthGuard)
  async findOneProductDetail(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user?: any,
  ) {
    const product = await this.shopService.findOneProduct(id, user?.id);

    if (!user?.id) {
      return {
        ...product,
        isFavorited: false,
      };
    }

    const favoriteResult = await this.productFavoriteService.checkFavorite(
      user.id,
      id,
    );
    return {
      ...product,
      isFavorited: favoriteResult.isFavorited,
    };
  }

  // 创建商品（根据用户角色自动设置发布来源）
  @Post("products")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER")
  createProduct(
    @Body() createProductDto: CreateProductDto,
    @CurrentUser() user: any,
  ) {
    return this.shopService.createProduct(createProductDto, user);
  }

  // 更新商品
  @Put("products/:id")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER")
  updateProduct(
    @Param("id", ParseIntPipe) id: number,
    @Body() updateProductDto: UpdateProductDto,
    @CurrentUser() user: any,
  ) {
    return this.shopService.updateProduct(
      id,
      updateProductDto,
      user.id,
      user.role,
    );
  }

  // 删除商品
  @Delete("products/:id")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER")
  removeProduct(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
  ) {
    return this.shopService.removeProduct(id, user.id, user.role);
  }

  // Orders
  @Get("orders")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  findAllOrders(
    @Query("search") search?: string,
    @Query("status") status?: string,
    @Query("orderType") orderType?: string,
    @Query("afterSaleStatus") afterSaleStatus?: string,
    @Query("settlementStatus") settlementStatus?: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    return this.shopService.findAllOrdersAdmin(
      search,
      status as any,
      orderType as any,
      afterSaleStatus,
      settlementStatus as any,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 10,
    );
  }

  @Get("orders/my")
  @UseGuards(JwtAuthGuard)
  @Roles("USER")
  getMyOrders(@Query() query: QueryOrderDto, @CurrentUser() user: any) {
    return this.shopService.findMyOrdersPaginated(user.id, query);
  }

  @Get("orders/purchases")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("USER")
  getPurchases(@Query() query: QueryOrderDto, @CurrentUser() user: any) {
    return this.shopService.findMyOrdersPaginated(user.id, query, "buyer");
  }

  @Get("orders/sales")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("USER")
  getSales(@Query() query: QueryOrderDto, @CurrentUser() user: any) {
    return this.secondHandOrderService.findSales(user.id, query);
  }

  @Get("orders/action-summary")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("USER")
  getOrderActionSummary(@CurrentUser() user: any) {
    return this.shopService.getOrderActionSummary(user.id);
  }

  @Get("orders/:id")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER", "DOCTOR")
  findOneOrder(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
  ) {
    return this.shopService.findOneOrder(id, user.id, user.role);
  }

  @Post("orders/:id/after-sales")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("USER")
  createAfterSale(
    @Param("id", ParseIntPipe) id: number,
    @Body() dto: CreateAfterSaleDto,
    @CurrentUser() user: any,
  ) {
    return this.afterSaleService.create(id, user.id, dto);
  }

  @Post("orders")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER", "DOCTOR")
  createOrder(
    @Body() createOrderDto: CreateOrderDto,
    @CurrentUser() user: any,
  ) {
    return this.shopService.createOrder(createOrderDto, user.id);
  }

  @Post("orders/preview")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER", "DOCTOR")
  previewOrder(
    @Body() previewOrderDto: PreviewOrderDto,
    @CurrentUser() user: any,
  ) {
    return this.shopService.previewOrder(previewOrderDto, user.id);
  }

  @Put("orders/:id/status")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  updateOrderStatus(
    @Param("id", ParseIntPipe) id: number,
    @Body() updateOrderStatusDto: UpdateOrderStatusDto,
  ) {
    return this.shopService.updateOrderStatus(id, updateOrderStatusDto);
  }

  @Post("orders/:id/cancel")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("USER")
  cancelOrder(
    @Param("id", ParseIntPipe) id: number,
    @Body() body: { reason?: string },
    @CurrentUser() user: any,
  ) {
    return this.shopService.cancelOrder(id, user.id, body.reason);
  }

  @Post("orders/:id/pay")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("USER", "DOCTOR")
  payOrder(
    @Param("id", ParseIntPipe) id: number,
    @Body() payOrderDto: PayOrderDto,
    @CurrentUser() user: any,
  ) {
    return this.shopService.payOrder(id, user.id, payOrderDto.paymentChannel);
  }

  @Post("orders/:id/confirm-receipt")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("USER")
  confirmOrder(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
  ) {
    return this.shopService.confirmOrder(id, user.id);
  }

  @Patch("orders/:id/shipping")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  setShipping(
    @Param("id", ParseIntPipe) id: number,
    @Body() updateShippingDto: UpdateShippingDto,
  ) {
    return this.shopService.setShipping(id, updateShippingDto);
  }

  // ========== SKU 相关接口 ==========

  /**
   * 获取商品的所有 SKU
   */
  @Get("products/:id/skus")
  @Public()
  getProductSkus(@Param("id", ParseIntPipe) productId: number) {
    return this.shopService.getProductSkus(productId);
  }

  /**
   * 创建单个 SKU
   */
  @Post("products/:id/skus")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER")
  createSku(
    @Param("id", ParseIntPipe) productId: number,
    @Body() createSkuDto: CreateProductSkuDto,
  ) {
    return this.shopService.createSku(productId, createSkuDto);
  }

  /**
   * 批量创建 SKU
   */
  @Post("products/:id/skus/batch")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER")
  createSkuBatch(
    @Param("id", ParseIntPipe) productId: number,
    @Body() createSkuBatchDto: CreateProductSkuBatchDto,
  ) {
    return this.shopService.createSkuBatch(productId, createSkuBatchDto);
  }

  /**
   * 更新 SKU
   */
  @Put("products/:productId/skus/:skuId")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER")
  updateSku(
    @Param("productId", ParseIntPipe) productId: number,
    @Param("skuId", ParseIntPipe) skuId: number,
    @Body() updateSkuDto: UpdateProductSkuDto,
  ) {
    return this.shopService.updateSku(productId, skuId, updateSkuDto);
  }

  /**
   * 删除 SKU
   */
  @Delete("products/:productId/skus/:skuId")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF", "USER")
  removeSku(
    @Param("productId", ParseIntPipe) productId: number,
    @Param("skuId", ParseIntPipe) skuId: number,
  ) {
    return this.shopService.removeSku(productId, skuId);
  }
}
