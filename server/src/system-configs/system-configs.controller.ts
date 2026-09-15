import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SystemConfigsService } from './system-configs.service';
import { CreateSystemConfigDto } from './dto/create-system-config.dto';
import { UpdateSystemConfigDto } from './dto/update-system-config.dto';
import { QuerySystemConfigDto } from './dto/query-system-config.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

/**
 * 系统配置控制器
 */
@ApiTags('系统配置')
@Controller('system-configs')
export class SystemConfigsController {
  constructor(private readonly systemConfigsService: SystemConfigsService) {}

  /**
   * 获取所有配置列表（管理员）
   */
  @Get()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取所有配置列表（管理员）' })
  async findAll(@Query() queryDto: QuerySystemConfigDto) {
    return await this.systemConfigsService.findAll(queryDto);
  }

  /**
   * 根据 configKey 获取配置（公开/认证）
   */
  @Get(':key')
  @ApiOperation({ summary: '根据 configKey 获取配置' })
  async findOne(@Param('key') key: string) {
    return await this.systemConfigsService.findByKey(key);
  }

  /**
   * 创建新配置（管理员）
   */
  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建新配置（管理员）' })
  async create(@Body() createSystemConfigDto: CreateSystemConfigDto) {
    return await this.systemConfigsService.create(createSystemConfigDto);
  }

  /**
   * 更新配置（管理员）
   */
  @Put(':key')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新配置（管理员）' })
  async update(
    @Param('key') key: string,
    @Body() updateSystemConfigDto: UpdateSystemConfigDto,
  ) {
    return await this.systemConfigsService.update(key, updateSystemConfigDto);
  }

  /**
   * 删除配置（管理员）
   */
  @Delete(':key')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除配置（管理员）' })
  async remove(@Param('key') key: string) {
    await this.systemConfigsService.remove(key);
    return { message: '删除成功' };
  }
}
