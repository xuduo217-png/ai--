import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Category, CategoryStatus } from './entities/category.entity';
import { Product } from './entities/product.entity';
import { CreateProductCategoryDto } from './dto/create-category.dto';
import { UpdateProductCategoryDto } from './dto/update-category.dto';
import { QueryCategoryDto } from './dto/query-category.dto';

/**
 * 商品分类服务
 * 提供商品分类的 CRUD 操作和树形结构管理
 */
@Injectable()
export class CategoryService {
  constructor(
    @InjectRepository(Category)
    private categoryRepository: Repository<Category>,
    @InjectRepository(Product)
    private productRepository: Repository<Product>,
  ) {}

  /**
   * 创建商品分类
   * @param createCategoryDto 创建分类 DTO
   * @returns 创建的分类对象
   */
  async create(createCategoryDto: CreateProductCategoryDto): Promise<Category> {
    // 如果有父分类，验证父分类是否存在
    if (createCategoryDto.parentId) {
      const parent = await this.categoryRepository.findOne({
        where: { id: createCategoryDto.parentId },
      });
      if (!parent) {
        throw new NotFoundException('父分类不存在');
      }
    }

    const category = this.categoryRepository.create(createCategoryDto);
    return await this.categoryRepository.save(category);
  }

  /**
   * 获取分类树形列表（支持分页和筛选）
   * @param query 查询参数
   * @returns 分类列表或树形结构
   */
  async findAll(
    query: QueryCategoryDto,
  ): Promise<Category[] | { data: Category[]; total: number }> {
    const {
      status,
      parentId,
      includeChildren,
      page = 1,
      pageSize = 10,
    } = query;

    // 统一父级 ID：字符串 "0"/空字符串/undefined/null 都视为根分类
    const parentIdStr =
      parentId === undefined || parentId === null ? null : String(parentId).trim();
    const isRootQuery = !parentIdStr || parentIdStr === '0';
    const normalizedParentId = isRootQuery ? null : Number(parentIdStr);

    // 如果需要树形结构，使用递归查询获取完整的三级分类
    if (includeChildren) {
      return this.findTree(status);
    }

    // 构建查询条件
    const queryBuilder = this.categoryRepository.createQueryBuilder('category');

    if (status) {
      queryBuilder.andWhere('category.status = :status', { status });
    }

    // 处理 parentId 查询
    // 前端会传 parentId=0（字符串或数字）表示根分类，这里兼容 0/NULL 两种存储方式
    if (isRootQuery) { // 查询根分类
      queryBuilder.andWhere('(category.parentId IS NULL OR category.parentId = 0)');
    } else {
      queryBuilder.andWhere('category.parentId = :parentId', {
        parentId: normalizedParentId,
      });
    }

    // 排序
    queryBuilder
      .orderBy('category.sortOrder', 'ASC')
      .addOrderBy('category.createdAt', 'DESC');

    // 分页查询
    if (page && pageSize) {
      const [data, total] = await queryBuilder
        .skip((page - 1) * pageSize)
        .take(pageSize)
        .getManyAndCount();

      return { data, total };
    }

    return await queryBuilder.getMany();
  }

  /**
   * 获取完整的分类树形结构（支持三级分类）
   * @param status 分类状态筛选
   * @returns 完整的三级分类树形结构
   */
  async findTree(status?: CategoryStatus): Promise<Category[]> {
    // 查询所有符合状态条件的分类（包括子分类）
    const allCategories = await this.categoryRepository.find({
      where: status ? { status } : undefined,
      order: {
        sortOrder: 'ASC',
        createdAt: 'DESC',
      },
    });

    // 使用递归方法构建树形结构
    return this.buildTree(allCategories);
  }

  /**
   * 获取单个分类详情
   * @param id 分类ID
   * @returns 分类对象
   */
  async findOne(id: number): Promise<Category> {
    const category = await this.categoryRepository.findOne({
      where: { id },
      relations: ['parent', 'children'], // 加载父分类和子分类关系
    });

    if (!category) {
      throw new NotFoundException('分类不存在');
    }

    return category;
  }

  /**
   * 获取分类的完整路径（从根到当前分类）
   * @param id 分类ID
   * @returns 分类路径数组
   */
  async getPath(id: number): Promise<Category[]> {
    const category = await this.findOne(id);
    const path: Category[] = [];
    let current: Category | null = category;

    while (current) {
      path.unshift(current);
      current = current.parentId ? await this.findOne(current.parentId) : null;
    }

    return path;
  }

  /**
   * 更新商品分类
   * @param id 分类ID
   * @param updateCategoryDto 更新 DTO
   * @returns 更新后的分类对象
   */
  async update(
    id: number,
    updateCategoryDto: UpdateProductCategoryDto,
  ): Promise<Category> {
    const category = await this.findOne(id);

    // 如果修改了父分类，验证新父分类是否存在且不能是自己
    if (updateCategoryDto.parentId !== undefined) {
      if (updateCategoryDto.parentId === id) {
        throw new BadRequestException('不能将父分类设置为自己');
      }

      if (updateCategoryDto.parentId !== null) {
        const parent = await this.categoryRepository.findOne({
          where: { id: updateCategoryDto.parentId },
        });
        if (!parent) {
          throw new NotFoundException('父分类不存在');
        }
      }
    }

    // 合并更新
    Object.assign(category, updateCategoryDto);
    return await this.categoryRepository.save(category);
  }

  /**
   * 删除商品分类（级联删除子分类）
   * @param id 分类ID
   */
  async remove(id: number): Promise<void> {
    const category = await this.findOne(id);

    // 检查是否有子分类
    const childCount = await this.categoryRepository.count({
      where: { parentId: id },
    });

    if (childCount > 0) {
      throw new BadRequestException('该分类下有子分类，无法删除');
    }

    // 检查是否有商品关联到此分类
    const productCount = await this.productRepository.count({
      where: { categoryId: id },
    });

    if (productCount > 0) {
      throw new BadRequestException(`该分类下还有 ${productCount} 个商品，无法删除`);
    }

    await this.categoryRepository.remove(category);
  }

  /**
   * 更新分类排序
   * @param id 分类ID
   * @param sortOrder 新排序值
   */
  async updateSort(id: number, sortOrder: number): Promise<Category> {
    const category = await this.findOne(id);
    category.sortOrder = sortOrder;
    return await this.categoryRepository.save(category);
  }

  /**
   * 构建树形结构
   * @param categories 所有分类列表
   * @param parentId 父分类ID
   * @returns 树形结构的分类数组
   */
  private buildTree(
    categories: Category[],
    parentId: number | null = null,
  ): Category[] {
    return categories
      .filter((cat) => cat.parentId === parentId)
      .map((cat) => ({
        ...cat,
        children: this.buildTree(categories, cat.id),
      }));
  }
}
