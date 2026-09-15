import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Patch,
  Body,
  Param,
  UseGuards,
  Req,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AddressesService } from './addresses.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiResponse,
} from '@nestjs/swagger';

@ApiTags('addresses')
@Controller('addresses')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class AddressesController {
  constructor(private readonly addressesService: AddressesService) {}

  /**
   * 获取当前用户的所有地址
   */
  @Get()
  @ApiOperation({ summary: '获取当前用户的所有地址' })
  @ApiResponse({ status: 200, description: '成功返回地址列表' })
  findAll(@Req() req) {
    return this.addressesService.findAll(req.user.id);
  }

  /**
   * 获取单个地址详情
   */
  @Get(':id')
  @ApiOperation({ summary: '获取单个地址详情' })
  @ApiResponse({ status: 200, description: '成功返回地址详情' })
  @ApiResponse({ status: 404, description: '地址不存在' })
  findOne(@Req() req, @Param('id') id: string) {
    return this.addressesService.findOne(req.user.id, +id);
  }

  /**
   * 创建新地址
   */
  @Post()
  @ApiOperation({ summary: '创建新地址' })
  @ApiResponse({ status: 201, description: '成功创建地址' })
  @ApiResponse({ status: 400, description: '请求参数错误' })
  create(@Req() req, @Body() createAddressDto: CreateAddressDto) {
    return this.addressesService.create(req.user.id, createAddressDto);
  }

  /**
   * 更新地址
   */
  @Put(':id')
  @ApiOperation({ summary: '更新地址' })
  @ApiResponse({ status: 200, description: '成功更新地址' })
  @ApiResponse({ status: 404, description: '地址不存在' })
  update(
    @Req() req,
    @Param('id') id: string,
    @Body() updateAddressDto: UpdateAddressDto,
  ) {
    return this.addressesService.update(req.user.id, +id, updateAddressDto);
  }

  /**
   * 删除地址
   */
  @Delete(':id')
  @ApiOperation({ summary: '删除地址' })
  @ApiResponse({ status: 200, description: '成功删除地址' })
  @ApiResponse({ status: 404, description: '地址不存在' })
  remove(@Req() req, @Param('id') id: string) {
    return this.addressesService.remove(req.user.id, +id);
  }

  /**
   * 设置默认地址
   */
  @Patch(':id/default')
  @ApiOperation({ summary: '设置默认地址' })
  @ApiResponse({ status: 200, description: '成功设置默认地址' })
  @ApiResponse({ status: 404, description: '地址不存在' })
  setDefault(@Req() req, @Param('id') id: string) {
    return this.addressesService.setDefaultAddress(req.user.id, +id);
  }
}
