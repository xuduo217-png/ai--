import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  UseGuards,
  Request,
  Query,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NearbyService } from './nearby.service';
import {
  GetNearbyUsersDto,
  UpdateLocationDto,
  ToggleDiscoveryDto,
} from './dto/nearby.dto';

/**
 * 附近的人 API 控制器
 *
 * 路由前缀：/api/nearby
 * 认证方式：JWT Bearer Token
 */
@ApiTags('附近的人')
@Controller('nearby')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class NearbyController {
  constructor(private readonly nearbyService: NearbyService) {}

  /**
   * 获取附近的人列表
   *
   * GET /api/nearby/users
   */
  @Get('users')
  @ApiOperation({ summary: '获取附近的人列表' })
  async getNearbyUsers(@Request() req, @Query() dto: GetNearbyUsersDto) {
    const userId = req.user.id;
    return this.nearbyService.getNearbyUsers(userId, dto);
  }

  /**
   * 更新用户位置
   *
   * POST /api/nearby/location
   */
  @Post('location')
  @ApiOperation({ summary: '更新用户位置' })
  async updateLocation(@Request() req, @Body() dto: UpdateLocationDto) {
    const userId = req.user.id;
    return this.nearbyService.updateLocation(userId, dto);
  }

  /**
   * 获取用户位置设置
   *
   * GET /api/nearby/settings
   */
  @Get('settings')
  @ApiOperation({ summary: '获取用户位置设置' })
  async getLocationSettings(@Request() req) {
    const userId = req.user.id;
    return this.nearbyService.getLocationSettings(userId);
  }

  /**
   * 切换发现开关
   *
   * PUT /api/nearby/settings/discovery
   */
  @Put('settings/discovery')
  @ApiOperation({ summary: '切换发现开关' })
  async toggleDiscovery(@Request() req, @Body() dto: ToggleDiscoveryDto) {
    const userId = req.user.id;
    return this.nearbyService.toggleDiscovery(userId, dto);
  }
}
