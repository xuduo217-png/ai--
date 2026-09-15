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
  ParseBoolPipe,
} from '@nestjs/common';
import { DepartmentsService } from './departments.service';
import { CreateDepartmentDto } from './dto/create-department.dto';
import { UpdateDepartmentDto } from './dto/update-department.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Public } from '../auth/decorators/public.decorator';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';

@ApiTags('departments')
@Controller('departments')
export class DepartmentsController {
  constructor(private readonly departmentsService: DepartmentsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建科室' })
  create(@Body() createDepartmentDto: CreateDepartmentDto) {
    return this.departmentsService.create(createDepartmentDto);
  }

  @Get()
  @Public()
  @ApiOperation({ summary: '获取科室列表' })
  @ApiQuery({
    name: 'hospitalId',
    required: false,
    type: Number,
    description: '按医院ID筛选',
  })
  @ApiQuery({
    name: 'activeOnly',
    required: false,
    type: Boolean,
    description: '只获取启用的科室',
  })
  findAll(
    @Query('hospitalId', new ParseIntPipe({ optional: true }))
    hospitalId?: number,
    @Query('activeOnly', new ParseBoolPipe({ optional: true }))
    activeOnly?: boolean,
  ) {
    return this.departmentsService.findAll(hospitalId, activeOnly);
  }

  @Get('hospital/:hospitalId')
  @Public()
  @ApiOperation({ summary: '获取指定医院的科室列表' })
  findByHospital(
    @Param('hospitalId', ParseIntPipe) hospitalId: number,
    @Query('activeOnly', new ParseBoolPipe({ optional: true }))
    activeOnly?: boolean,
  ) {
    return this.departmentsService.findAll(hospitalId, activeOnly);
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: '获取科室详情' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.departmentsService.findOne(id);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新科室信息' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateDepartmentDto: UpdateDepartmentDto,
  ) {
    return this.departmentsService.update(id, updateDepartmentDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除科室' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.departmentsService.remove(id);
  }
}
