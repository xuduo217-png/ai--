import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { AidGuide, GuideStatus } from './entities/aid-guide.entity';
import { AidCategory } from './entities/aid-category.entity';
import { CreateGuideDto } from './dto/create-guide.dto';
import { UpdateGuideDto } from './dto/update-guide.dto';
import { QueryGuideDto } from './dto/query-guide.dto';
import { CreateAidGuideCategoryDto } from './dto/create-category.dto';
import { UpdateAidGuideCategoryDto } from './dto/update-category.dto';
import { QueryCategoryDto } from './dto/query-category.dto';

/**
 * 急救指南服务
 * 处理指南和分类的业务逻辑
 */
@Injectable()
export class AidGuidesService {
  constructor(
    @InjectRepository(AidGuide)
    private guideRepository: Repository<AidGuide>,
    @InjectRepository(AidCategory)
    private categoryRepository: Repository<AidCategory>,
  ) {}

  // ==================== 分类管理 ====================

  /**
   * 创建分类
   */
  async createCategory(createCategoryDto: CreateAidGuideCategoryDto): Promise<AidCategory> {
    const category = this.categoryRepository.create(createCategoryDto);
    return await this.categoryRepository.save(category);
  }

  /**
   * 获取分类列表
   */
  async findCategories(queryDto: QueryCategoryDto): Promise<PaginatedResult<AidCategory>> {
    const { page = 1, pageSize = 10, isActive, keyword } = queryDto;
    const query = this.categoryRepository.createQueryBuilder('category');

    if (isActive !== undefined) {
      query.andWhere('category.isActive = :isActive', { isActive });
    }

    if (keyword) {
      query.andWhere('category.name LIKE :keyword', { keyword: `%${keyword}%` });
    }

    query.orderBy('category.sortOrder', 'ASC').addOrderBy('category.id', 'DESC');

    const [data, total] = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取分类详情
   */
  async findCategoryById(id: number): Promise<AidCategory> {
    const category = await this.categoryRepository.findOne({
      where: { id },
    });
    if (!category) {
      throw new NotFoundException(`分类 ID ${id} 不存在`);
    }
    return category;
  }

  /**
   * 更新分类
   */
  async updateCategory(id: number, updateCategoryDto: UpdateAidGuideCategoryDto): Promise<AidCategory> {
    const category = await this.findCategoryById(id);
    Object.assign(category, updateCategoryDto);
    return await this.categoryRepository.save(category);
  }

  /**
   * 切换分类启用状态
   */
  async toggleCategoryStatus(id: number): Promise<AidCategory> {
    const category = await this.findCategoryById(id);
    category.isActive = !category.isActive;
    return await this.categoryRepository.save(category);
  }

  /**
   * 删除分类（软删除）
   */
  async deleteCategory(id: number): Promise<void> {
    const category = await this.findCategoryById(id);

    // 检查是否有指南关联
    const guideCount = await this.guideRepository.count({
      where: { categoryId: id },
    });

    if (guideCount > 0) {
      throw new BadRequestException(`该分类下还有 ${guideCount} 个指南，无法删除`);
    }

    await this.categoryRepository.softRemove(category);
  }

  // ==================== 指南管理 ====================

  /**
   * 创建指南
   */
  async createGuide(createGuideDto: CreateGuideDto, authorId: number): Promise<AidGuide> {
    // 验证分类是否存在
    await this.findCategoryById(createGuideDto.categoryId);

    const guide = this.guideRepository.create({
      ...createGuideDto,
      authorId,
    });

    // 如果是发布状态，设置发布时间
    if (guide.status === GuideStatus.PUBLISHED) {
      guide.publishedAt = new Date();
    }

    const savedGuide = await this.guideRepository.save(guide);

    // 更新分类的指南计数
    await this.updateCategoryGuideCount(createGuideDto.categoryId);

    return savedGuide;
  }

  /**
   * 获取指南列表
   */
  async findGuides(queryDto: QueryGuideDto): Promise<PaginatedResult<AidGuide>> {
    const { page = 1, pageSize = 10, categoryId, status, keyword } = queryDto;
    const query = this.guideRepository.createQueryBuilder('guide')
      .leftJoinAndSelect('guide.category', 'category');

    if (categoryId) {
      query.andWhere('guide.categoryId = :categoryId', { categoryId });
    }

    if (status) {
      query.andWhere('guide.status = :status', { status });
    }

    if (keyword) {
      query.andWhere('(guide.title LIKE :keyword OR guide.content LIKE :keyword)', {
        keyword: `%${keyword}%`,
      });
    }

    query.orderBy('guide.sortOrder', 'ASC').addOrderBy('guide.id', 'DESC');

    const [data, total] = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取指南详情
   */
  async findGuideById(id: number): Promise<AidGuide> {
    const guide = await this.guideRepository.findOne({
      where: { id },
      relations: ['category'],
    });
    if (!guide) {
      throw new NotFoundException(`指南 ID ${id} 不存在`);
    }
    return guide;
  }

  /**
   * 更新指南
   */
  async updateGuide(id: number, updateGuideDto: UpdateGuideDto): Promise<AidGuide> {
    const guide = await this.findGuideById(id);
    const oldCategoryId = guide.categoryId;

    Object.assign(guide, updateGuideDto);

    // 如果状态从草稿变为发布，设置发布时间
    if (updateGuideDto.status === GuideStatus.PUBLISHED && !guide.publishedAt) {
      guide.publishedAt = new Date();
    }

    // 如果状态从发布变为草稿，清除发布时间
    if (updateGuideDto.status === GuideStatus.DRAFT) {
      guide.publishedAt = null;
    }

    const savedGuide = await this.guideRepository.save(guide);

    // 更新分类的指南计数
    if (updateGuideDto.categoryId && updateGuideDto.categoryId !== oldCategoryId) {
      await this.updateCategoryGuideCount(oldCategoryId);
      await this.updateCategoryGuideCount(updateGuideDto.categoryId);
    }

    return savedGuide;
  }

  /**
   * 切换指南发布状态
   */
  async toggleGuideStatus(id: number): Promise<AidGuide> {
    const guide = await this.findGuideById(id);

    if (guide.status === GuideStatus.PUBLISHED) {
      guide.status = GuideStatus.DRAFT;
      guide.publishedAt = null;
    } else {
      guide.status = GuideStatus.PUBLISHED;
      guide.publishedAt = new Date();
    }

    return await this.guideRepository.save(guide);
  }

  /**
   * 删除指南（软删除）
   */
  async deleteGuide(id: number): Promise<void> {
    const guide = await this.findGuideById(id);
    const categoryId = guide.categoryId;

    await this.guideRepository.softRemove(guide);

    // 更新分类的指南计数
    await this.updateCategoryGuideCount(categoryId);
  }

  /**
   * 获取指定分类下的指南
   */
  async findGuidesByCategory(categoryId: number): Promise<AidGuide[]> {
    return await this.guideRepository.find({
      where: {
        categoryId,
        status: GuideStatus.PUBLISHED,
      },
      relations: ['category'],
      order: {
        sortOrder: 'ASC',
        id: 'DESC',
      },
    });
  }

  /**
   * 更新分类的指南计数（内部方法）
   */
  private async updateCategoryGuideCount(categoryId: number): Promise<void> {
    const count = await this.guideRepository.count({
      where: { categoryId },
    });
    await this.categoryRepository.update(categoryId, { guideCount: count });
  }
}
