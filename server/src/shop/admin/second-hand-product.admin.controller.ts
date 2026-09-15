import {
  Controller,
  Get,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { SecondHandProductService } from '../second-hand-product.service';
import { ReviewProductDto, QueryPendingProductsDto } from '../dto/review-product.dto';

/**
 * 二手商品后台管理 API
 */
@Controller('admin/products/second-hand')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN')
export class SecondHandProductAdminController {
  constructor(private readonly secondHandProductService: SecondHandProductService) {}

  /**
   * 获取待审核商品列表
   */
  @Get('pending')
  async getPendingProducts(@Query() query: QueryPendingProductsDto) {
    return await this.secondHandProductService.getPendingProducts(query);
  }

  /**
   * 审核商品
   */
  @Put('pending/:id/review')
  async reviewProduct(
    @Param('id') id: string,
    @Request() req,
    @Body() dto: ReviewProductDto,
  ) {
    const adminId = req.user.id;
    return await this.secondHandProductService.reviewProduct(Number(id), dto, adminId);
  }

  /**
   * 获取正式商品列表
   */
  @Get('formal')
  async getFormalProducts(@Query() query: QueryPendingProductsDto) {
    return await this.secondHandProductService.getFormalProducts(query);
  }

  /**
   * 强制下架商品
   */
  @Put(':id/delist')
  async forceDelistProduct(@Param('id') id: string) {
    return await this.secondHandProductService.forceDelistProduct(Number(id));
  }
}
