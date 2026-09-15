import {
  Controller,
  Get,
  Put,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { PlatformFeeService } from '../platform-fee.service';
import { IsNumber, Min, Max } from 'class-validator';
import { plainToClass } from 'class-transformer';

/**
 * 更新手续费率 DTO
 */
class UpdatePlatformFeeDto {
  @IsNumber({}, { message: '手续费率必须是数字' })
  @Min(0, { message: '手续费率不能小于0' })
  @Max(100, { message: '手续费率不能大于100' })
  feeRate: number;
}

/**
 * 平台手续费配置后台管理 API
 */
@Controller('admin/system/config/platform-fee')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN')
export class PlatformFeeAdminController {
  constructor(private readonly platformFeeService: PlatformFeeService) {}

  /**
   * 获取手续费配置
   */
  @Get()
  async getPlatformFeeConfig() {
    const config = await this.platformFeeService.getPlatformFeeConfig();
    return {
      success: true,
      data: config,
    };
  }

  /**
   * 更新手续费配置
   */
  @Put()
  async updatePlatformFeeConfig(@Request() req, @Body() body: any) {
    const dto = plainToClass(UpdatePlatformFeeDto, body);
    const adminId = req.user.id;
    return await this.platformFeeService.updatePlatformFeeRate(
      dto.feeRate,
      adminId,
    );
  }
}
