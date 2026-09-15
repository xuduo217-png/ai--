import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { BusinessException } from '../common/filters/business-exception';
import { ErrorCode } from '../common/constants/error-codes';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ShoppingCart } from './entities/shopping-cart.entity';
import { ProductSku, SkuStatus } from './entities/product-sku.entity';
import { Product } from './entities/product.entity';
import { AddToCartDto } from './dto/add-to-cart.dto';
import { UpdateCartDto } from './dto/update-cart.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';

/**
 * 购物车服务
 */
@Injectable()
export class ShoppingCartService {
  constructor(
    @InjectRepository(ShoppingCart)
    private cartRepository: Repository<ShoppingCart>,
    @InjectRepository(ProductSku)
    private skuRepository: Repository<ProductSku>,
    @InjectRepository(Product)
    private productRepository: Repository<Product>,
  ) {}

  /**
   * 添加到购物车（已存在则增加数量）
   * @param userId 用户ID
   * @param addToCartDto 添加到购物车 DTO
   * @returns 购物车项
   */
  async addToCart(
    userId: number,
    addToCartDto: AddToCartDto,
  ): Promise<ShoppingCart> {
    const { productId, skuId, quantity } = addToCartDto;

    // 先查商品
    const product = await this.productRepository.findOne({
      where: { id: productId },
    });
    if (!product) {
      throw new NotFoundException('商品不存在');
    }
    if (!product.isActive) {
      throw new BadRequestException('商品已下架');
    }

    // 若传入 SKU，则校验 SKU（不验证库存）
    let sku: ProductSku | null = null;
    if (skuId) {
      sku = await this.skuRepository.findOne({
        where: { id: skuId, productId },
      });
      if (!sku) {
        throw new NotFoundException('SKU 不存在');
      }
    } else {
      // 未传 SKU：要求商品为单规格（hasSku=false）
      if (product.hasSku) {
        throw new BadRequestException('请先选择规格');
      }
    }

    // 查询是否已存在同商品+sku 购物车项
    const cartItem = await this.cartRepository.findOne({
      where: { userId, productId, skuId: skuId ?? null },
      relations: ['sku', 'sku.product', 'product'],
    });

    if (cartItem) {
      const newQuantity = cartItem.quantity + quantity;
      cartItem.quantity = newQuantity;
      return await this.cartRepository.save(cartItem);
    }

    // 不存在，创建新购物车项
    const newCartItem = this.cartRepository.create({
      userId,
      productId,
      skuId: skuId ?? null,
      quantity,
    });
    return await this.cartRepository.save(newCartItem);
  }

  /**
   * 获取购物车列表
   * @param userId 用户ID
   * @returns 购物车列表
   */
  async getCartList(userId: number): Promise<ShoppingCart[]> {
    return await this.cartRepository.find({
      where: { userId },
      relations: ['product', 'sku', 'sku.product'],
      order: {
        createdAt: 'DESC',
      },
    });
  }

  /**
   * 更新购物车项数量
   * @param id 购物车项ID
   * @param userId 用户ID
   * @param updateCartDto 更新 DTO
   * @returns 更新后的购物车项
   */
  async updateCartItem(
    id: number,
    userId: number,
    updateCartDto: UpdateCartDto,
  ): Promise<ShoppingCart> {
    const cartItem = await this.cartRepository.findOne({
      where: { id },
    });

    if (!cartItem) {
      throw new NotFoundException('购物车项不存在');
    }

    // 验证所有权
    if (cartItem.userId !== userId) {
      throw new ForbiddenException('无权操作此购物车项');
    }

    // 不验证库存，只在下单时验证
    cartItem.quantity = updateCartDto.quantity;
    return await this.cartRepository.save(cartItem);
  }

  /**
   * 删除购物车项
   * @param id 购物车项ID
   * @param userId 用户ID
   */
  async deleteCartItem(id: number, userId: number): Promise<void> {
    const cartItem = await this.cartRepository.findOne({
      where: { id },
    });

    if (!cartItem) {
      throw new NotFoundException('购物车项不存在');
    }

    // 验证所有权
    if (cartItem.userId !== userId) {
      throw new ForbiddenException('无权操作此购物车项');
    }

    await this.cartRepository.remove(cartItem);
  }

  /**
   * 清空购物车
   * @param userId 用户ID
   */
  async clearCart(userId: number): Promise<void> {
    await this.cartRepository.delete({ userId });
  }

  /**
   * 获取购物车项数量（用于显示购物车图标上的数字）
   * @param userId 用户ID
   * @returns 购物车项总数量
   */
  async getCartCount(userId: number): Promise<number> {
    const result = await this.cartRepository
      .createQueryBuilder('cart')
      .select('SUM(cart.quantity)', 'total')
      .where('cart.userId = :userId', { userId })
      .getRawOne();

    return result?.total || 0;
  }
}
