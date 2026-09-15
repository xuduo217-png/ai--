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
  ParseIntPipe,
} from '@nestjs/common';
import { AppointmentsService } from './appointments.service';
import { CreateAppointmentDto } from './dto/create-appointment.dto';
import { UpdateAppointmentDto } from './dto/update-appointment.dto';
import { QueryAppointmentDto } from './dto/query-appointment.dto';
import { ConfirmAppointmentDto } from './dto/confirm-appointment.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import {
  AppointmentStatus,
  AppointmentType,
} from './entities/appointment.entity';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
} from '@nestjs/swagger';

@ApiTags('appointments')
@ApiBearerAuth()
@Controller('appointments')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AppointmentsController {
  constructor(private readonly appointmentsService: AppointmentsService) {}

  @Post()
  @Roles('USER')
  @ApiOperation({ summary: '创建预约（前台）' })
  create(
    @Body() createAppointmentDto: CreateAppointmentDto,
    @CurrentUser() user: any,
  ) {
    return this.appointmentsService.create(createAppointmentDto, user.id);
  }

  @Get()
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '获取预约列表（分页、筛选）' })
  findAll(@Query() query: QueryAppointmentDto, @CurrentUser() user: any) {
    return this.appointmentsService.findAll(query, user.id, user.role);
  }

  @Get('my')
  @Roles('USER')
  @ApiOperation({ summary: '获取我的预约列表' })
  getMyAppointments(@CurrentUser() user: any) {
    return this.appointmentsService.findByUser(user.id);
  }

  @Get('doctor')
  @Roles('DOCTOR')
  @ApiOperation({ summary: '获取医生的预约列表' })
  @ApiQuery({ name: 'status', required: false, enum: AppointmentStatus })
  getDoctorAppointments(
    @CurrentUser() user: any,
    @Query('status') status?: AppointmentStatus,
  ) {
    return this.appointmentsService.findByDoctor(user.id, status);
  }

  @Get('hospital')
  @Roles('HOSPITAL_ADMIN', 'STAFF')
  @ApiOperation({ summary: '获取医院的预约列表' })
  @ApiQuery({ name: 'status', required: false, enum: AppointmentStatus })
  getHospitalAppointments(
    @CurrentUser() user: any,
    @Query('status') status?: AppointmentStatus,
  ) {
    return this.appointmentsService.findByHospital(user.hospitalId, status);
  }

  @Get('statistics')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '获取预约统计信息' })
  getStatistics(
    @CurrentUser() user: any,
    @Query('hospitalId') hospitalId?: number,
  ) {
    return this.appointmentsService.getStatistics(
      user.id,
      user.role,
      hospitalId,
    );
  }

  @Get('my/statistics')
  @Roles('USER')
  @ApiOperation({ summary: '获取我的预约统计' })
  getMyStatistics(@CurrentUser() user: any) {
    return this.appointmentsService.getStatistics(user.id, user.role);
  }

  @Get(':id')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR', 'USER')
  @ApiOperation({ summary: '获取预约详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.appointmentsService.findOne(id, user.id, user.role);
  }

  @Put(':id')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR', 'USER')
  @ApiOperation({ summary: '更新预约' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateAppointmentDto: UpdateAppointmentDto,
    @CurrentUser() user: any,
  ) {
    return this.appointmentsService.update(
      id,
      updateAppointmentDto,
      user.id,
      user.role,
    );
  }

  @Post(':id/confirm')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiOperation({ summary: '确认预约（分配医生、调整时间、设定下次预约）' })
  confirmAppointment(
    @Param('id', ParseIntPipe) id: number,
    @Body() confirmDto: ConfirmAppointmentDto,
    @CurrentUser() user: any,
  ) {
    return this.appointmentsService.confirmAppointment(
      id,
      confirmDto,
      user.id,
      user.role,
    );
  }

  @Delete(':id')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'USER')
  @ApiOperation({ summary: '取消/删除预约（软删除）' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.appointmentsService.remove(id, user.id, user.role);
  }
}
