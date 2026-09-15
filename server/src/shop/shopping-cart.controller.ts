import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ShoppingCartService } from './shopping-cart.service';
import { AddToCartDto } from './dto/add-to-cart.dto';
import { UpdateCartDto } from './dto/update-cart.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('商城 - 购物车')
@Controller('shop/cart')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class ShoppingCartController {
  constructor(private readonly cartService: ShoppingCartService) {}

  /**
   * 添加到购物车
   */
  @Post()
  @ApiOperation({ summary: '添加到购物车' })
  async addToCart(
    @CurrentUser() user: User,
    @Body() addToCartDto: AddToCartDto,
  ) {
    const cartItem = await this.cartService.addToCart(user.id, addToCartDto);
    return {
      success: true,
      data: cartItem,
      message: '已加入购物车',
    };
  }

  /**
   * 获取购物车列表
   */
  @Get()
  @ApiOperation({ summary: '获取购物车列表' })
  async getCartList(@CurrentUser() user: User) {
    const cartList = await this.cartService.getCartList(user.id);
    return {
      success: true,
      data: cartList,
    };
  }

  /**
   * 获取购物车数量
   */
  @Get('count')
  @ApiOperation({ summary: '获取购物车数量' })
  async getCartCount(@CurrentUser() user: User) {
    const count = await this.cartService.getCartCount(user.id);
    return {
      success: true,
      data: { count },
    };
  }

  /**
   * 更新购物车项数量
   */
  @Put(':id')
  @ApiOperation({ summary: '更新购物车项数量' })
  async updateCartItem(
    @CurrentUser() user: User,
    @Param('id') id: number,
    @Body() updateCartDto: UpdateCartDto,
  ) {
    const cartItem = await this.cartService.updateCartItem(
      id,
      user.id,
      updateCartDto,
    );
    return {
      success: true,
      data: cartItem,
      message: '更新成功',
    };
  }

  /**
   * 删除购物车项
   */
  @Delete(':id')
  @ApiOperation({ summary: '删除购物车项' })
  async deleteCartItem(@CurrentUser() user: User, @Param('id') id: number) {
    await this.cartService.deleteCartItem(id, user.id);
    return {
      success: true,
      message: '删除成功',
    };
  }

  /**
   * 清空购物车
   */
  @Delete()
  @ApiOperation({ summary: '清空购物车' })
  async clearCart(@CurrentUser() user: User) {
    await this.cartService.clearCart(user.id);
    return {
      success: true,
      message: '购物车已清空',
    };
  }
}
