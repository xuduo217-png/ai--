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
  ForbiddenException,
} from '@nestjs/common';
import { HospitalsService } from './hospitals.service';
import { CreateHospitalDto } from './dto/create-hospital.dto';
import { UpdateHospitalDto } from './dto/update-hospital.dto';
import { QueryHospitalDto } from './dto/query-hospital.dto';
import { QueryNearbyHospitalsDto } from './dto/query-nearby-hospitals.dto';
import { NearbyHospitalResponseDto } from './dto/nearby-hospital-response.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('hospitals')
@ApiBearerAuth()
@Controller('hospitals')
@UseGuards(JwtAuthGuard, RolesGuard)
export class HospitalsController {
  constructor(private readonly hospitalsService: HospitalsService) {}

  @Post()
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '创建医院' })
  create(@Body() createHospitalDto: CreateHospitalDto) {
    return this.hospitalsService.create(createHospitalDto);
  }

  @Get()
  @Public()
  @ApiOperation({ summary: '获取医院列表（分页、搜索、筛选）' })
  findAll(@Query() query: QueryHospitalDto) {
    return this.hospitalsService.findAll(query);
  }

  @Get('nearby')
  @Public()
  @ApiOperation({ summary: '获取附近的医院（按距离排序）' })
  findNearby(@Query() query: QueryNearbyHospitalsDto) {
    return this.hospitalsService.getNearbyHospitals(query);
  }

  @Get('statistics')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN')
  @ApiOperation({ summary: '获取医院统计信息' })
  getStatistics(
    @CurrentUser() user: any,
    @Query('hospitalId') hospitalId?: number,
  ) {
    if (user.role === 'HOSPITAL_ADMIN') {
      return this.hospitalsService.getStatistics(user.hospitalId);
    }
    return this.hospitalsService.getStatistics(hospitalId);
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: '获取医院详情' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.hospitalsService.findOne(id);
  }

  @Put(':id')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN')
  @ApiOperation({ summary: '更新医院信息' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateHospitalDto: UpdateHospitalDto,
    @CurrentUser() user: any,
  ) {
    if (user.role === 'HOSPITAL_ADMIN' && user.hospitalId !== id) {
      throw new ForbiddenException('无权修改其他医院信息');
    }
    return this.hospitalsService.update(id, updateHospitalDto);
  }

  @Delete(':id')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '删除医院（软删除）' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.hospitalsService.remove(id);
  }
}
