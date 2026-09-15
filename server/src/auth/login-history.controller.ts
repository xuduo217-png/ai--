import {
  Controller,
  Get,
  Query,
  UseGuards,
  Request,
  Param,
} from '@nestjs/common';
import { LoginHistoryService } from './login-history.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';

@ApiTags('login-history')
@ApiBearerAuth()
@Controller('login-history')
@UseGuards(JwtAuthGuard)
export class LoginHistoryController {
  constructor(private readonly loginHistoryService: LoginHistoryService) {}

  @Get()
  @ApiOperation({ summary: '获取当前用户登录历史' })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    description: '返回记录数量，默认20',
  })
  async getMyLoginHistory(@Request() req, @Query('limit') limit?: number) {
    const history = await this.loginHistoryService.getUserLoginHistory(
      req.user.id,
      limit ? parseInt(limit.toString()) : 20,
    );
    return { data: history, total: history.length };
  }

  @Get(':userId')
  @ApiOperation({ summary: '获取指定用户登录历史（管理员）' })
  async getUserLoginHistory(
    @Param('userId') userId: string,
    @Query('limit') limit?: number,
  ) {
    const history = await this.loginHistoryService.getUserLoginHistory(
      parseInt(userId),
      limit ? parseInt(limit.toString()) : 20,
    );
    return { data: history, total: history.length };
  }
}
