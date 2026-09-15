import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { ProductFavoriteService } from './product-favorite.service';
import { CreateFavoriteDto } from './dto/create-favorite.dto';
import { QueryFavoriteDto } from './dto/query-favorite.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('商城 - 收藏')
@Controller('shop/favorites')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class ProductFavoriteController {
  constructor(private readonly favoriteService: ProductFavoriteService) {}

  /**
   * 收藏/取消收藏商品（Toggle 模式）
   */
  @Post()
  @ApiOperation({ summary: '收藏/取消收藏商品' })
  async toggleFavorite(
    @CurrentUser() user: User,
    @Body() createFavoriteDto: CreateFavoriteDto,
  ) {
    const result = await this.favoriteService.toggleFavorite(
      user.id,
      createFavoriteDto,
    );
    return {
      success: true,
      data: result,
      message: result.isFavorited ? '已收藏' : '已取消收藏',
    };
  }

  /**
   * 获取收藏列表
   */
  @Get()
  @ApiOperation({ summary: '获取收藏列表' })
  async getFavoriteList(
    @CurrentUser() user: User,
    @Query() query: QueryFavoriteDto,
  ) {
    const result = await this.favoriteService.getFavoriteList(user.id, query);
    return {
      success: true,
      ...result,
    };
  }

  /**
   * 检查商品是否已收藏
   */
  @Get('check')
  @ApiOperation({ summary: '检查商品是否已收藏' })
  @ApiQuery({
    name: 'productId',
    description: '商品ID',
    example: 1,
    type: Number,
  })
  async checkFavorite(
    @CurrentUser() user: User,
    @Query('productId') productId: string,
  ) {
    const result = await this.favoriteService.checkFavorite(
      user.id,
      parseInt(productId),
    );
    return {
      success: true,
      data: result,
    };
  }

  /**
   * 获取收藏数量
   */
  @Get('count')
  @ApiOperation({ summary: '获取收藏数量' })
  async getFavoriteCount(@CurrentUser() user: User) {
    const count = await this.favoriteService.getFavoriteCount(user.id);
    return {
      success: true,
      data: { count },
    };
  }

  /**
   * 删除收藏
   */
  @Delete(':id')
  @ApiOperation({ summary: '删除收藏' })
  async deleteFavorite(@CurrentUser() user: User, @Param('id') id: number) {
    await this.favoriteService.deleteFavorite(id, user.id);
    return {
      success: true,
      message: '删除成功',
    };
  }
}
