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
import { Roles } from "../../auth/decorators/roles.decorator";
import { JwtAuthGuard } from "../../auth/guards/jwt-auth.guard";
import { RolesGuard } from "../../auth/guards/roles.guard";
import { CurrentUser } from "../../common/decorators/current-user.decorator";
import { AfterSaleService } from "../after-sale.service";
import {
  AdminConfirmReturnDto,
  AdminArbitrateAfterSaleDto,
  AdminReviewAfterSaleDto,
  QueryAfterSaleDto,
} from "../dto/after-sale.dto";

@Controller("shop/admin/after-sales")
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles("SUPER_ADMIN", "STAFF")
export class AfterSaleAdminController {
  constructor(private readonly service: AfterSaleService) {}

  @Get()
  findAll(@Query() query: QueryAfterSaleDto) {
    return this.service.findAdmin(query);
  }

  @Get(":id")
  findOne(@Param("id", ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.service.findOne(id, user.id, user.role);
  }

  @Post(":id/arbitrate")
  arbitrate(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: AdminArbitrateAfterSaleDto,
  ) {
    return this.service.arbitrate(id, user.id, dto);
  }

  @Post(":id/review")
  review(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: AdminReviewAfterSaleDto,
  ) {
    return this.service.adminReview(id, user.id, dto);
  }

  @Post(":id/confirm-return")
  confirmReturn(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: AdminConfirmReturnDto,
  ) {
    return this.service.adminConfirmReturn(id, user.id, dto);
  }

  @Post(":id/refund/retry")
  retryRefund(@Param("id", ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.service.retryRefund(id, user.id);
  }
}
