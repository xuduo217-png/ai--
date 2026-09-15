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
import { PetsService } from './pets.service';
import { CreatePetDto } from './dto/create-pet.dto';
import { UpdatePetDto } from './dto/update-pet.dto';
import { QueryPetDto } from './dto/query-pet.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';

@ApiTags('pets')
@ApiBearerAuth()
@Controller('pets')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PetsController {
  constructor(private readonly petsService: PetsService) {}

  @Post()
  @Roles('SUPER_ADMIN', 'STAFF', 'USER') // 移除 DOCTOR
  @ApiOperation({ summary: '创建宠物档案' })
  create(@Body() createPetDto: CreatePetDto, @CurrentUser() user: any) {
    return this.petsService.create(createPetDto, user.id);
  }

  @Get()
  @Roles('SUPER_ADMIN', 'STAFF', 'DOCTOR') // USER 使用 /my 接口
  @ApiOperation({ summary: '获取宠物列表（分页、搜索、筛选）' })
  findAll(@Query() query: QueryPetDto) {
    return this.petsService.findAll(query);
  }

  @Get('my')
  @Roles('USER')
  @ApiOperation({ summary: '获取我的宠物列表' })
  @ApiQuery({ name: 'categoryId', required: false, description: '一级分类ID' })
  getMyPets(
    @CurrentUser() user: any,
    @Query('categoryId') categoryId?: number,
  ) {
    return this.petsService.findByOwner(user.id, categoryId);
  }

  @Get('search/:keyword')
  @Roles('SUPER_ADMIN', 'STAFF', 'USER', 'DOCTOR')
  @ApiOperation({ summary: '搜索宠物' })
  @ApiParam({ name: 'keyword', description: '搜索关键词' })
  search(@Param('keyword') keyword: string, @CurrentUser() user: any) {
    return this.petsService.search(keyword, user.id, user.role);
  }

  @Get('statistics')
  @Roles('SUPER_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '获取宠物统计信息' })
  getStatistics(@CurrentUser() user: any) {
    return this.petsService.getStatistics(user.id, user.role);
  }

  @Get('my/statistics')
  @Roles('USER')
  @ApiOperation({ summary: '获取我的宠物统计信息' })
  getMyStatistics(@CurrentUser() user: any) {
    return this.petsService.getStatistics(user.id, user.role);
  }

  // ========== 健康管理相关 ==========
  // 注意：':id/health-stats' 必须在 ':id' 之前，否则会被 ':id' 路由拦截

  @Get(':id/health-stats')
  @Roles('USER', 'SUPER_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '获取宠物健康统计（疫苗、驱虫、体检）' })
  @ApiParam({ name: 'id', description: '宠物ID' })
  getHealthStats(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: any,
  ) {
    return this.petsService.getHealthStats(id, user.id);
  }

  @Get(':id')
  @Roles('SUPER_ADMIN', 'STAFF', 'USER', 'DOCTOR')
  @ApiOperation({ summary: '获取宠物详情' })
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.petsService.findOne(id, user.id, user.role);
  }

  // ========== 护理计划相关 ==========

  @Post(':id/care-plan')
  @Roles('USER', 'SUPER_ADMIN', 'STAFF')
  @ApiOperation({ summary: '手动触发生成宠物护理计划' })
  @ApiParam({ name: 'id', description: '宠物ID' })
  triggerCarePlan(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: any,
  ) {
    // 手动触发需要把队列创建失败反馈给客户端，避免用户误以为任务已启动。
    return this.petsService.triggerCarePlanGeneration(id, {
      throwOnFailure: true,
    });
  }

  @Put(':id')
  @Roles('SUPER_ADMIN', 'STAFF', 'USER') // 移除 DOCTOR
  @ApiOperation({ summary: '更新宠物信息' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updatePetDto: UpdatePetDto,
    @CurrentUser() user: any,
  ) {
    return this.petsService.update(id, updatePetDto, user.id, user.role);
  }

  @Delete(':id')
  @Roles('SUPER_ADMIN', 'STAFF', 'USER')
  @ApiOperation({ summary: '删除宠物档案（软删除）' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.petsService.remove(id, user.id, user.role);
  }

  // 为 AI 问诊和医生聊天提供的特殊接口
  @Get('medical/:id')
  @Roles('SUPER_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '获取宠物医疗档案信息（含病史、过敏史）' })
  getMedicalInfo(@Param('id', ParseIntPipe) id: number) {
    return this.petsService.findOne(id);
  }

  @Get('user/:userId/with-medical')
  @Roles('SUPER_ADMIN', 'STAFF', 'DOCTOR')
  @ApiOperation({ summary: '获取用户的所有宠物（含医疗信息）' })
  getUserPetsWithMedical(@Param('userId', ParseIntPipe) userId: number) {
    return this.petsService.findByOwnerWithMedicalHistory(userId);
  }
}
