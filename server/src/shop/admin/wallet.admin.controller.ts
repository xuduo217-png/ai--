import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { WalletService } from '../wallet.service';

/**
 * 钱包后台管理 API
 */
@Controller('admin/wallet')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN')
export class WalletAdminController {
  constructor(private readonly walletService: WalletService) {}

  /**
   * 获取钱包交易列表（带关联信息）
   * GET /server-api/admin/wallet/transactions
   */
  @Get('transactions')
  async getTransactions(@Query() query: any) {
    return await this.walletService.getTransactionList(query);
  }

  /**
   * 审核通过
   * POST /server-api/admin/wallet/transactions/:id/approve
   */
  @Post('transactions/:id/approve')
  async approveTransaction(
    @Param('id') id: string,
    @Body() body: { remark?: string },
    @Request() req,
  ) {
    const adminId = req.user.id;
    return await this.walletService.approveTransaction(
      Number(id),
      adminId,
      body.remark,
    );
  }

  /**
   * 审核拒绝
   * POST /server-api/admin/wallet/transactions/:id/reject
   */
  @Post('transactions/:id/reject')
  async rejectTransaction(
    @Param('id') id: string,
    @Body() body: { reason: string },
    @Request() req,
  ) {
    const adminId = req.user.id;
    return await this.walletService.rejectTransaction(
      Number(id),
      adminId,
      body.reason,
    );
  }

}
