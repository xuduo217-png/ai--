import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { LogisticsService } from './logistics.service';
import { CreateLogisticsDto } from './dto/create-logistics.dto';
import { UpdateLogisticsDto } from './dto/update-logistics.dto';

/**
 * 物流管理控制器
 */
@Controller('logistics')
@UseGuards(JwtAuthGuard)
export class LogisticsController {
  constructor(private readonly logisticsService: LogisticsService) {}

  /**
   * 获取物流列表（支持筛选）
   */
  @Get()
  findAll(@Body() body?: { isEnabled?: boolean }) {
    return this.logisticsService.findAll(body?.isEnabled);
  }

  /**
   * 获取启用的物流公司（用于下拉选择）
   */
  @Get('enabled')
  findEnabled() {
    return this.logisticsService.findEnabled();
  }

  /**
   * 获取物流详情
   */
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.logisticsService.findOne(+id);
  }

  /**
   * 创建物流公司
   */
  @Post()
  create(@Body() createDto: CreateLogisticsDto) {
    return this.logisticsService.create(createDto);
  }

  /**
   * 更新物流公司
   */
  @Put(':id')
  update(@Param('id') id: string, @Body() updateDto: UpdateLogisticsDto) {
    return this.logisticsService.update(+id, updateDto);
  }

  /**
   * 切换启用状态
   */
  @Patch(':id/toggle')
  toggle(@Param('id') id: string) {
    return this.logisticsService.toggle(+id);
  }

  /**
   * 删除物流公司
   */
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.logisticsService.remove(+id);
  }
}
