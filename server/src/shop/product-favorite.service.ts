import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProductFavorite } from './entities/product-favorite.entity';
import { Product } from './entities/product.entity';
import { CreateFavoriteDto } from './dto/create-favorite.dto';
import { QueryFavoriteDto } from './dto/query-favorite.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';

/**
 * 商品收藏服务
 */
@Injectable()
export class ProductFavoriteService {
  constructor(
    @InjectRepository(ProductFavorite)
    private favoriteRepository: Repository<ProductFavorite>,
    @InjectRepository(Product)
    private productRepository: Repository<Product>,
  ) {}

  /**
   * 收藏/取消收藏商品（Toggle 模式）
   * @param userId 用户ID
   * @param createFavoriteDto 创建收藏 DTO
   * @returns 操作结果
   */
  async toggleFavorite(
    userId: number,
    createFavoriteDto: CreateFavoriteDto,
  ): Promise<{ isFavorited: boolean }> {
    const { productId } = createFavoriteDto;

    // 检查商品是否存在
    const product = await this.productRepository.findOne({
      where: { id: productId },
    });

    if (!product) {
      throw new NotFoundException('商品不存在');
    }

    // 检查商品是否已下架
    if (!product.isActive) {
      throw new BadRequestException('商品已下架');
    }

    // 查询是否已收藏
    const existingFavorite = await this.favoriteRepository.findOne({
      where: { userId, productId },
    });

    if (existingFavorite) {
      // 已收藏，执行取消收藏
      await this.favoriteRepository.remove(existingFavorite);
      return { isFavorited: false };
    } else {
      // 未收藏，执行收藏
      const newFavorite = this.favoriteRepository.create({
        userId,
        productId,
      });
      await this.favoriteRepository.save(newFavorite);
      return { isFavorited: true };
    }
  }

  /**
   * 获取收藏列表（带分页）
   * @param userId 用户ID
   * @param query 查询参数
   * @returns 分页的收藏列表
   */
  async getFavoriteList(
    userId: number,
    query: QueryFavoriteDto,
  ): Promise<PaginatedResult<ProductFavorite>> {
    const { page = 1, pageSize = 10 } = query;

    const [favorites, total] = await this.favoriteRepository.findAndCount({
      where: { userId },
      relations: ['product'],
      order: {
        createdAt: 'DESC',
      },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      data: favorites,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 检查商品是否已收藏
   * @param userId 用户ID
   * @param productId 商品ID
   * @returns 是否已收藏
   */
  async checkFavorite(
    userId: number,
    productId: number,
  ): Promise<{ isFavorited: boolean }> {
    const favorite = await this.favoriteRepository.findOne({
      where: { userId, productId },
    });

    return { isFavorited: !!favorite };
  }

  /**
   * 删除收藏
   * @param id 收藏ID
   * @param userId 用户ID
   */
  async deleteFavorite(id: number, userId: number): Promise<void> {
    const favorite = await this.favoriteRepository.findOne({
      where: { id },
    });

    if (!favorite) {
      throw new NotFoundException('收藏不存在');
    }

    // 验证所有权
    if (favorite.userId !== userId) {
      throw new ForbiddenException('无权操作此收藏');
    }

    await this.favoriteRepository.remove(favorite);
  }

  /**
   * 获取用户收藏数量
   * @param userId 用户ID
   * @returns 收藏数量
   */
  async getFavoriteCount(userId: number): Promise<number> {
    return await this.favoriteRepository.count({
      where: { userId },
    });
  }
}
