import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { HealthAppointmentsService } from './health-appointments.service';
import { CreateHealthAppointmentDto } from './dto/create-health-appointment.dto';
import { QueryHealthAppointmentDto } from './dto/query-health-appointment.dto';
import { UpdateHealthAppointmentStatusDto } from './dto/update-health-appointment-status.dto';
import { CompleteAppointmentDto } from './dto/complete-appointment.dto';
import {
  HealthAppointmentType,
  HealthAppointmentStatus,
} from './entities/health-appointment.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
} from '@nestjs/swagger';

/**
 * 健康预约控制器
 * 提供健康预约（疫苗、驱虫、体检）的 API 接口
 */
@ApiTags('health-appointments')
@ApiBearerAuth()
@Controller('health-appointments')
@UseGuards(JwtAuthGuard, RolesGuard)
export class HealthAppointmentsController {
  constructor(
    private readonly healthAppointmentsService: HealthAppointmentsService,
  ) {}

  /**
   * 创建健康预约
   * 用户可以为自己的宠物创建健康预约
   */
  @Post()
  @Roles('USER')
  @ApiOperation({ summary: '创建健康预约' })
  create(
    @Body() createHealthAppointmentDto: CreateHealthAppointmentDto,
    @CurrentUser() user: any,
  ) {
    return this.healthAppointmentsService.create(
      createHealthAppointmentDto,
      user.id,
    );
  }

  /**
   * 获取健康预约列表
   * 管理员和医生可以查看所有预约，普通用户只能查看自己的预约
   */
  @Get()
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR', 'USER')
  @ApiOperation({ summary: '获取健康预约列表（分页、筛选）' })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'pageSize', required: false })
  @ApiQuery({ name: 'petId', required: false })
  @ApiQuery({ name: 'type', required: false, enum: HealthAppointmentType })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: HealthAppointmentStatus,
    description:
      '预约状态（可传单个状态，也可以传多个状态，用逗号分隔，如：pending,confirmed）',
  })
  @ApiQuery({ name: 'hospitalId', required: false })
  findAll(@Query() query: QueryHealthAppointmentDto, @CurrentUser() user: any) {
    return this.healthAppointmentsService.findAll(query, user.id, user.role);
  }

  /**
   * 获取指定宠物的健康预约列表
   * 管理员和医生可以查看所有宠物的预约，普通用户只能查看自己的宠物
   */
  @Get('pet/:petId')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR', 'USER')
  @ApiOperation({ summary: '获取指定宠物的健康预约' })
  @ApiParam({ name: 'petId', description: '宠物ID' })
  findByPet(
    @Param('petId', ParseIntPipe) petId: number,
    @Query() query: QueryHealthAppointmentDto,
    @CurrentUser() user: any,
  ) {
    return this.healthAppointmentsService.findAll(
      { ...query, petId },
      user.id,
      user.role,
    );
  }

  /**
   * 获取单个健康预约详情
   */
  @Get(':id')
  @Roles('USER', 'SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '获取健康预约详情' })
  @ApiParam({ name: 'id', description: '预约ID' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    // 普通用户只能查看自己的预约
    if (user.role === 'USER') {
      return this.healthAppointmentsService.findOne(id, user.id);
    }
    // 管理员和医生可以查看所有预约
    return this.healthAppointmentsService.findOne(id);
  }

  /**
   * 更新健康预约状态
   * 仅管理员和医生可以更新预约状态
   */
  @Patch(':id/status')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '更新健康预约状态' })
  @ApiParam({ name: 'id', description: '预约ID' })
  updateStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateHealthAppointmentStatusDto: UpdateHealthAppointmentStatusDto,
  ) {
    return this.healthAppointmentsService.updateStatus(
      id,
      updateHealthAppointmentStatusDto,
    );
  }

  /**
   * 取消健康预约
   * 用户可以取消自己的预约（不能取消已完成的预约）
   * 管理员和医生也可以取消预约
   */
  @Patch(':id/cancel')
  @Roles('USER', 'SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '取消健康预约' })
  @ApiParam({ name: 'id', description: '预约ID' })
  cancel(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    // 普通用户只能取消自己的预约
    if (user.role === 'USER') {
      return this.healthAppointmentsService.cancel(id, user.id);
    }
    // 管理员和医生可以取消任何预约
    return this.healthAppointmentsService.cancel(id);
  }

  /**
   * 完成健康预约
   * 管理员和医生可以完成预约，并可选地设置下次预约日期
   */
  @Patch(':id/complete')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '完成健康预约（可设置下次预约时间）' })
  @ApiParam({ name: 'id', description: '预约ID' })
  completeAppointment(
    @Param('id', ParseIntPipe) id: number,
    @Body() completeAppointmentDto: CompleteAppointmentDto,
  ) {
    return this.healthAppointmentsService.completeAppointment(
      id,
      completeAppointmentDto,
    );
  }

  /**
   * 删除健康预约（软删除）
   * 用户只能删除自己的未确认预约
   */
  @Delete(':id')
  @Roles('USER')
  @ApiOperation({ summary: '删除健康预约' })
  @ApiParam({ name: 'id', description: '预约ID' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.healthAppointmentsService.remove(id, user.id);
  }
}
