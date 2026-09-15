import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import { DoctorsService } from './doctors.service';
import { CreateDoctorDto } from './dto/create-doctor.dto';
import { UpdateDoctorDto } from './dto/update-doctor.dto';
import { QueryDoctorDto } from './dto/query-doctor.dto';
import { CreateServiceItemDto } from './dto/create-service-item.dto';
import { UpdateServiceItemDto } from './dto/update-service-item.dto';
import { BatchCreateServiceItemsDto } from './dto/batch-create-service-items.dto';
import { UpdateOnlineStatusDto } from './dto/update-online-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';

@ApiTags('doctors')
@Controller('doctors')
export class DoctorsController {
  constructor(private readonly doctorsService: DoctorsService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建医生资料' })
  create(@Body() createDoctorDto: CreateDoctorDto, @CurrentUser() user: any) {
    return this.doctorsService.create(createDoctorDto);
  }

  @Get()
  @Public()
  @ApiOperation({ summary: '获取医生列表（分页、搜索、筛选）' })
  findAll(@Query() query: QueryDoctorDto, @CurrentUser() user?: any) {
    return this.doctorsService.findAll(query, user?.role, user?.hospitalId);
  }

  @Get('statistics')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取医生统计信息' })
  getStatistics(
    @CurrentUser() user: any,
    @Query('hospitalId') hospitalId?: number,
  ) {
    if (user.role === 'HOSPITAL_ADMIN' || user.role === 'STAFF') {
      return this.doctorsService.getStatistics(user.hospitalId);
    }
    return this.doctorsService.getStatistics(hospitalId);
  }

  @Get('hospital/:hospitalId')
  @Public()
  @ApiOperation({ summary: '获取医院的医生列表' })
  findByHospital(@Param('hospitalId', ParseIntPipe) hospitalId: number) {
    return this.doctorsService.findByHospital(hospitalId);
  }

  @Get('department/:departmentId')
  @Public()
  @ApiOperation({ summary: '获取科室的医生列表' })
  findByDepartment(@Param('departmentId', ParseIntPipe) departmentId: number) {
    return this.doctorsService.findByDepartment(departmentId);
  }

  @Get('profile')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DOCTOR')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取医生个人资料' })
  getProfile(@CurrentUser() doctor: any) {
    // 使用 findOneWithStats 动态计算统计数据（咨询次数等）
    return this.doctorsService.findOneWithStats(doctor.id);
  }

  @Patch('online-status')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('DOCTOR')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新医生在线状态（上线/下线）' })
  updateOnlineStatus(
    @CurrentUser() doctor: any,
    @Body() updateOnlineStatusDto: UpdateOnlineStatusDto,
  ) {
    return this.doctorsService.updateOnlineStatus(
      doctor.id,
      updateOnlineStatusDto.onlineStatus,
    );
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: '获取医生详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user?: any) {
    return this.doctorsService.findOne(id, user?.role, user?.hospitalId);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'DOCTOR')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新医生信息' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateDoctorDto: UpdateDoctorDto,
    @CurrentUser() user: any,
  ) {
    return this.doctorsService.update(
      id,
      updateDoctorDto,
      user.role,
      user.hospitalId,
    );
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除医生（软删除）' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.doctorsService.remove(id, user.role, user.hospitalId);
  }

  // ========== 收费项管理端点 ==========

  /**
   * 获取医生的收费项列表
   */
  @Get(':id/service-items')
  @Public()
  @ApiOperation({ summary: '获取医生的收费项列表' })
  getServiceItems(@Param('id', ParseIntPipe) doctorId: number) {
    return this.doctorsService.getServiceItems(doctorId);
  }

  /**
   * 添加收费项
   */
  @Post(':id/service-items')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '为医生添加收费项' })
  addServiceItem(
    @Param('id', ParseIntPipe) doctorId: number,
    @Body() createDto: CreateServiceItemDto,
    @CurrentUser() user: any,
  ) {
    return this.doctorsService.addServiceItem(
      doctorId,
      createDto,
      user.role,
      user.hospitalId,
    );
  }

  /**
   * 批量添加收费项
   */
  @Post(':id/service-items/batch')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '批量添加收费项' })
  batchAddServiceItems(
    @Param('id', ParseIntPipe) doctorId: number,
    @Body() batchDto: BatchCreateServiceItemsDto,
    @CurrentUser() user: any,
  ) {
    return this.doctorsService.batchAddServiceItems(
      doctorId,
      batchDto,
      user.role,
      user.hospitalId,
    );
  }

  /**
   * 更新收费项
   */
  @Put(':id/service-items/:itemId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新收费项' })
  updateServiceItem(
    @Param('id', ParseIntPipe) doctorId: number,
    @Param('itemId', ParseIntPipe) itemId: number,
    @Body() updateDto: UpdateServiceItemDto,
    @CurrentUser() user: any,
  ) {
    return this.doctorsService.updateServiceItem(
      doctorId,
      itemId,
      updateDto,
      user.role,
      user.hospitalId,
    );
  }

  /**
   * 删除收费项
   */
  @Delete(':id/service-items/:itemId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除收费项' })
  removeServiceItem(
    @Param('id', ParseIntPipe) doctorId: number,
    @Param('itemId', ParseIntPipe) itemId: number,
    @CurrentUser() user: any,
  ) {
    return this.doctorsService.removeServiceItem(
      doctorId,
      itemId,
      user.role,
      user.hospitalId,
    );
  }
}
