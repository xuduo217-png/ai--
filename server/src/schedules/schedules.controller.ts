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
import { SchedulesService } from './schedules.service';
import { CreateScheduleDto } from './dto/create-schedule.dto';
import { UpdateScheduleDto } from './dto/update-schedule.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('schedules')
@Controller('schedules')
export class SchedulesController {
  constructor(private readonly schedulesService: SchedulesService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建排班' })
  create(@Body() createScheduleDto: CreateScheduleDto) {
    return this.schedulesService.create(createScheduleDto);
  }

  @Get()
  @Public()
  @ApiOperation({ summary: '获取排班列表' })
  findAll(
    @Query('doctorId', new ParseIntPipe({ optional: true })) doctorId?: number,
  ) {
    return this.schedulesService.findAll(doctorId);
  }

  @Get('doctor/:doctorId')
  @Public()
  @ApiOperation({ summary: '获取医生排班' })
  findByDoctor(@Param('doctorId', ParseIntPipe) doctorId: number) {
    return this.schedulesService.findByDoctor(doctorId);
  }

  @Get('available/:doctorId/:date')
  @Public()
  @ApiOperation({ summary: '获取医生某天可用时段' })
  findAvailableSlots(
    @Param('doctorId', ParseIntPipe) doctorId: number,
    @Param('date') date: string,
  ) {
    return this.schedulesService.findAvailableSlots(doctorId, date);
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: '获取排班详情' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.schedulesService.findOne(id);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新排班' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateScheduleDto: UpdateScheduleDto,
  ) {
    return this.schedulesService.update(id, updateScheduleDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除排班' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.schedulesService.remove(id);
  }
}
