import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { Roles } from "../auth/decorators/roles.decorator";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { RolesGuard } from "../auth/guards/roles.guard";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import { AfterSaleService } from "./after-sale.service";
import {
  ApplyArbitrationDto,
  QueryAfterSaleDto,
  SellerApproveAfterSaleDto,
  SellerRejectAfterSaleDto,
  SubmitReturnDto,
} from "./dto/after-sale.dto";

@Controller("shop/after-sales")
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles("USER")
export class AfterSaleController {
  constructor(private readonly service: AfterSaleService) {}

  @Get("purchases")
  findPurchases(@CurrentUser() user: any, @Query() query: QueryAfterSaleDto) {
    return this.service.findPurchases(user.id, query);
  }

  @Get("sales")
  findSales(@CurrentUser() user: any, @Query() query: QueryAfterSaleDto) {
    return this.service.findSales(user.id, query);
  }

  @Get(":id")
  findOne(@Param("id", ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.service.findOne(id, user.id, user.role);
  }

  @Post(":id/cancel")
  cancel(@Param("id", ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.service.cancel(id, user.id);
  }

  @Post(":id/seller/approve")
  approve(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: SellerApproveAfterSaleDto,
  ) {
    return this.service.sellerApprove(id, user.id, dto);
  }

  @Post(":id/seller/reject")
  reject(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: SellerRejectAfterSaleDto,
  ) {
    return this.service.sellerReject(id, user.id, dto);
  }

  @Post(":id/return")
  submitReturn(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: SubmitReturnDto,
  ) {
    return this.service.submitReturn(id, user.id, dto);
  }

  @Post(":id/confirm-return")
  confirmReturn(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
  ) {
    return this.service.confirmReturn(id, user.id);
  }

  @Post(":id/arbitration")
  arbitrate(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: ApplyArbitrationDto,
  ) {
    return this.service.applyArbitration(id, user.id, dto);
  }
}
