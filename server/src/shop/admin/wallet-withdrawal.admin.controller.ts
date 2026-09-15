import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  Request,
  UseGuards,
} from "@nestjs/common";
import { Roles } from "../../auth/decorators/roles.decorator";
import { JwtAuthGuard } from "../../auth/guards/jwt-auth.guard";
import { RolesGuard } from "../../auth/guards/roles.guard";
import {
  AdminWalletWithdrawalQueryDto,
  RejectWalletWithdrawalDto,
  UpdateWalletWithdrawalConfigDto,
} from "../dto/wallet-withdrawal.dto";
import { WalletWithdrawalConfigService } from "../wallet-withdrawal-config.service";
import { WalletWithdrawalService } from "../wallet-withdrawal.service";

@Controller("admin/wallet")
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles("SUPER_ADMIN")
export class WalletWithdrawalAdminController {
  constructor(
    private readonly withdrawalService: WalletWithdrawalService,
    private readonly configService: WalletWithdrawalConfigService,
  ) {}

  @Get("withdrawals")
  list(@Query() query: AdminWalletWithdrawalQueryDto) {
    return this.withdrawalService.listForAdmin(query);
  }

  @Get("withdrawals/:id")
  detail(@Param("id", ParseIntPipe) id: number) {
    return this.withdrawalService.getForAdmin(id);
  }

  @Post("withdrawals/:id/approve")
  approve(@Param("id", ParseIntPipe) id: number, @Request() request) {
    return this.withdrawalService.approve(id, request.user.id);
  }

  @Post("withdrawals/:id/reject")
  reject(
    @Param("id", ParseIntPipe) id: number,
    @Body() body: RejectWalletWithdrawalDto,
    @Request() request,
  ) {
    return this.withdrawalService.reject(id, request.user.id, body.reason);
  }

  @Post("withdrawals/:id/reconcile")
  reconcile(@Param("id", ParseIntPipe) id: number, @Request() request) {
    return this.withdrawalService.reconcile(id, request.user.id);
  }

  @Get("withdrawal-config")
  getConfig() {
    return this.configService.getAdminConfig();
  }

  @Put("withdrawal-config")
  updateConfig(@Body() body: UpdateWalletWithdrawalConfigDto) {
    return this.configService.update(body);
  }
}
