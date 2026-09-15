import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Delete,
  UseGuards,
  ParseIntPipe,
  Query,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { QueryUsersDto } from './dto/query-users.dto';
import {
  AdjustUserBalanceDto,
} from './dto/adjust-user-balance.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
  ApiResponse,
} from '@nestjs/swagger';
import { PetsService } from '../pets/pets.service';
import { Pet } from '../pets/entities/pet.entity';
import { UserRole } from './entities/user.entity';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly petsService: PetsService,
  ) {}

  @Post()
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiOperation({
    summary: '创建用户',
    description: '管理员创建新用户，支持手机号和邮箱',
  })
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }

  @Get()
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiOperation({
    summary: '获取用户列表（分页）',
    description: '支持分页和筛选，自动排除超级管理员',
  })
  findAll(@Query() query: QueryUsersDto) {
    return this.usersService.findAll(query);
  }

  @Get('me')
  @ApiOperation({ summary: '获取当前用户信息' })
  getProfile(@CurrentUser() user: any) {
    return this.usersService.findOne(user.id);
  }

  @Put('me')
  @ApiOperation({ summary: '更新当前用户信息' })
  updateProfile(
    @CurrentUser() user: any,
    @Body() updateUserDto: UpdateUserDto,
  ) {
    return this.usersService.update(user.id, updateUserDto);
  }

  // 更具体的路由必须放在 :id 之前，避免被通配符拦截
  @Get('me/pets')
  @ApiOperation({ summary: '获取当前用户的宠物列表' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getCurrentUserPets(@CurrentUser() user: any) {
    const pets = await this.petsService.findByUserId(user.id);
    return {
      code: 0,
      data: pets.map((pet: Pet) => ({
        id: pet.id,
        name: pet.name,
        categoryId: pet.categoryId,
        subCategoryId: pet.subCategoryId,
        age: pet.birthDate
          ? Math.floor(
              (new Date().getTime() - new Date(pet.birthDate).getTime()) /
                (1000 * 60 * 60 * 24 * 365),
            )
          : 0,
        gender: pet.gender,
        avatar: pet.avatar,
        userId: pet.ownerId,
        userName: user.username,
      })),
    };
  }

  @Get('phone/:phone/pets')
  @Roles('SUPER_ADMIN', 'DOCTOR')
  @ApiOperation({ summary: '根据手机号查询宠物列表' })
  @ApiResponse({ status: 200, description: '查询成功' })
  async getPetsByPhone(@Param('phone') phone: string) {
    const pets = await this.usersService.getPetsByPhone(phone);
    return {
      code: 0,
      data: pets,
    };
  }

  @Get('hospital/:hospitalId/staff')
  @Roles('SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  @ApiOperation({
    summary: '获取医院员工列表',
    description: '获取指定医院的员工列表（仅 STAFF 角色）',
  })
  @ApiParam({ name: 'hospitalId', description: '医院ID', example: 1 })
  @ApiResponse({ status: 200, description: '查询成功' })
  @ApiResponse({ status: 401, description: '未授权' })
  @ApiResponse({ status: 403, description: '无权限' })
  async getHospitalStaff(@Param('hospitalId', ParseIntPipe) hospitalId: number) {
    return this.usersService.getHospitalStaff(hospitalId);
  }

  @Get(':id/with-pets')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: '获取用户信息和宠物列表',
    description: '医生端专用，获取用户基本信息和关联的宠物档案',
  })
  @ApiParam({ name: 'id', description: '用户ID', example: 1 })
  @ApiResponse({ status: 200, description: '成功返回用户和宠物信息' })
  @ApiResponse({ status: 401, description: '未授权' })
  @ApiResponse({ status: 404, description: '用户不存在' })
  @Roles('DOCTOR', 'SUPER_ADMIN', 'HOSPITAL_ADMIN', 'STAFF')
  async getUserWithPets(@Param('id', ParseIntPipe) id: number) {
    // 1. 获取用户信息
    const user = await this.usersService.findById(id);

    // 2. 获取用户的宠物列表
    const pets = await this.petsService.findByUserId(id);

    // 3. 返回格式化数据
    return {
      user: {
        id: user.id,
        username: user.username,
        phone: user.phone,
        avatar: user.avatar,
      },
      pets: pets.map((pet: Pet) => ({
        id: pet.id,
        name: pet.name,
        categoryId: pet.categoryId,
        subCategoryId: pet.subCategoryId,
        category: pet.category,
        subCategory: pet.subCategory,
        // 根据出生日期计算年龄
        age: pet.birthDate
          ? Math.floor(
              (new Date().getTime() - new Date(pet.birthDate).getTime()) /
                (1000 * 60 * 60 * 24 * 365),
            )
          : 0,
        gender: pet.gender,
        avatar: pet.avatar,
      })),
    };
  }

  @Get(':id')
  @ApiOperation({ summary: '获取用户详情' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.findOne(id);
  }

  @Put(':id')
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiOperation({ summary: '更新用户信息 (管理员)' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateUserDto: UpdateUserDto,
  ) {
    return this.usersService.update(id, updateUserDto);
  }

  @Post(':id/balance/adjust')
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiOperation({ summary: '调整用户可用余额' })
  adjustBalance(
    @Param('id', ParseIntPipe) id: number,
    @Body() adjustUserBalanceDto: AdjustUserBalanceDto,
    @CurrentUser() user: any,
  ) {
    return this.usersService.adjustBalance(id, adjustUserBalanceDto, user.id);
  }

  // 移除 upgrade-doctor 接口 - 医生使用独立的认证系统（doctors 模块）

  @Get(':id/wallet-transactions')
  @Roles('SUPER_ADMIN', 'STAFF')
  @ApiOperation({ summary: '获取用户钱包明细' })
  getUserWalletTransactions(
    @Param('id', ParseIntPipe) id: number,
    @Query() query: any,
  ) {
    return this.usersService.getUserWalletTransactions(id, query);
  }

  @Delete('me')
  @ApiOperation({
    summary: '注销当前用户账号',
    description: '用户端自助注销当前登录账号，注销后账号身份信息会被匿名化并停用。',
  })
  deleteCurrentUser(@CurrentUser() user: any) {
    return this.usersService.deleteOwnAccount(user.id);
  }

  @Delete(':id')
  @Roles('SUPER_ADMIN')
  @ApiOperation({ summary: '删除用户' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.remove(id);
  }
}
