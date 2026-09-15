import { Controller, Get, UseGuards } from '@nestjs/common';
import { StatisticsService } from './statistics.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';

/**
 * 统计数据控制器
 * 提供首页全局统计数据接口
 */
@ApiTags('statistics')
@ApiBearerAuth()
@Controller('statistics')
@UseGuards(JwtAuthGuard, RolesGuard)
export class StatisticsController {
  constructor(private readonly statisticsService: StatisticsService) {}

  /**
   * 获取首页统计数据
   * 包含医院、医生、用户、宠物等核心指标的总数
   */
  @Get('dashboard')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'DOCTOR')
  @ApiOperation({ summary: '获取首页统计数据' })
  getDashboardStats() {
    return this.statisticsService.getDashboardStats();
  }
}
