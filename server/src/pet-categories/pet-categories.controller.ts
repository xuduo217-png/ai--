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
import { PetCategoriesService } from './pet-categories.service';
import {
  PetCategory,
  PetCategoryTreeNode,
} from './entities/pet-category.entity';
import { CreatePetCategoryDto } from './dto/create-pet-category.dto';
import { UpdatePetCategoryDto } from './dto/update-pet-category.dto';
import { QueryPetCategoriesDto } from './dto/query-pet-categories.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('pet-categories')
@Controller('pet-categories')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class PetCategoriesController {
  constructor(private readonly petCategoriesService: PetCategoriesService) {}

  @Post()
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiOperation({ summary: '创建宠物类别' })
  create(@Body() createPetCategoryDto: CreatePetCategoryDto) {
    return this.petCategoriesService.create(createPetCategoryDto);
  }

  @Get('tree')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'USER', 'DOCTOR')
  @ApiOperation({ summary: '获取分类树（支持搜索）' })
  findTree(
    @Query() queryDto: QueryPetCategoriesDto,
  ): Promise<PetCategoryTreeNode[]> {
    return this.petCategoriesService.findTree(queryDto);
  }

  @Get()
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'USER', 'DOCTOR')
  @ApiOperation({ summary: '获取分类列表（平铺）' })
  findAll(@Query() queryDto: QueryPetCategoriesDto) {
    return this.petCategoriesService.findAll(queryDto);
  }

  @Get(':id')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF', 'USER', 'DOCTOR')
  @ApiOperation({ summary: '获取分类详情' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.petCategoriesService.findOne(id);
  }

  @Put(':id')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiOperation({ summary: '更新分类信息' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updatePetCategoryDto: UpdatePetCategoryDto,
  ) {
    return this.petCategoriesService.update(id, updatePetCategoryDto);
  }

  @Delete(':id')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiOperation({ summary: '删除分类（级联删除子分类）' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.petCategoriesService.remove(id);
  }
}
