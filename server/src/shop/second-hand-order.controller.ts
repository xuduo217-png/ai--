import {
  Body,
  Controller,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { RolesGuard } from "../auth/guards/roles.guard";
import { Roles } from "../auth/decorators/roles.decorator";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import {
  ShipSecondHandOrderDto,
  UpdateSecondHandTrackingDto,
} from "./dto/after-sale.dto";
import { SecondHandOrderService } from "./second-hand-order.service";

@Controller("shop/orders")
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles("USER")
export class SecondHandOrderController {
  constructor(private readonly service: SecondHandOrderService) {}

  @Post(":id/ship")
  ship(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: ShipSecondHandOrderDto,
  ) {
    return this.service.ship(id, user.id, dto);
  }

  @Patch(":id/tracking")
  updateTracking(
    @Param("id", ParseIntPipe) id: number,
    @CurrentUser() user: any,
    @Body() dto: UpdateSecondHandTrackingDto,
  ) {
    return this.service.updateTracking(id, user.id, dto);
  }
}
