import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { HealthArticle, ArticleStatus } from './entities/health-article.entity';
import { HealthCategory } from './entities/health-category.entity';
import { CreateArticleDto } from './dto/create-article.dto';
import { UpdateHealthArticleDto } from './dto/update-article.dto';
import { QueryArticleDto } from './dto/query-article.dto';
import { CreateHealthCategoryDto } from './dto/create-category.dto';
import { UpdateHealthCategoryDto } from './dto/update-category.dto';
import { QueryCategoryDto } from './dto/query-category.dto';

/**
 * 健康知识服务类
 * 处理健康文章和分类的业务逻辑
 */
@Injectable()
export class HealthArticlesService {
  constructor(
    @InjectRepository(HealthArticle)
    private articleRepository: Repository<HealthArticle>,
    @InjectRepository(HealthCategory)
    private categoryRepository: Repository<HealthCategory>,
  ) {}

  // ========== 分类管理 ==========

  /**
   * 获取分类列表（分页）
   */
  async findAllCategories(
    query: QueryCategoryDto,
  ): Promise<PaginatedResult<HealthCategory>> {
    const { page = 1, pageSize = 10, name, isActive } = query;

    const queryBuilder = this.categoryRepository
      .createQueryBuilder('category')
      .where('category.deletedAt IS NULL');

    // 按名称模糊搜索
    if (name) {
      queryBuilder.andWhere('category.name LIKE :name', { name: `%${name}%` });
    }

    // 按启用状态筛选
    if (isActive !== undefined) {
      queryBuilder.andWhere('category.isActive = :isActive', { isActive });
    }

    // 排序
    queryBuilder
      .orderBy('category.sortOrder', 'ASC')
      .addOrderBy('category.createdAt', 'DESC');

    // 分页
    queryBuilder.skip((page - 1) * pageSize).take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

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
  async findOneCategory(id: number): Promise<HealthCategory> {
    const category = await this.categoryRepository.findOne({
      where: { id },
    });

    if (!category) {
      throw new NotFoundException('分类不存在');
    }

    return category;
  }

  /**
   * 创建分类
   */
  async createCategory(dto: CreateHealthCategoryDto): Promise<HealthCategory> {
    const category = this.categoryRepository.create({
      ...dto,
      articleCount: 0,
      isActive: dto.isActive ?? true,
      sortOrder: dto.sortOrder ?? 0,
    });

    return await this.categoryRepository.save(category);
  }

  /**
   * 更新分类
   */
  async updateCategory(
    id: number,
    dto: UpdateHealthCategoryDto,
  ): Promise<HealthCategory> {
    await this.findOneCategory(id);
    await this.categoryRepository.update(id, dto);
    return this.findOneCategory(id);
  }

  /**
   * 删除分类（软删除）
   */
  async removeCategory(id: number): Promise<void> {
    const result = await this.categoryRepository.softDelete(id);
    if (result.affected === 0) {
      throw new NotFoundException('分类不存在');
    }
  }

  // ========== 文章管理 ==========

  /**
   * 获取文章列表（分页）
   */
  async findAllArticles(
    query: QueryArticleDto,
  ): Promise<PaginatedResult<HealthArticle>> {
    const {
      page = 1,
      pageSize = 10,
      keyword,
      categoryId,
      status,
      sortBy = 'createdAt',
    } = query;

    const queryBuilder = this.articleRepository
      .createQueryBuilder('article')
      .leftJoinAndSelect('article.category', 'category')
      .where('article.deletedAt IS NULL');

    // 关键词搜索（标题或摘要）
    if (keyword) {
      queryBuilder.andWhere(
        '(article.title LIKE :keyword OR article.summary LIKE :keyword)',
        { keyword: `%${keyword}%` },
      );
    }

    // 按分类筛选
    if (categoryId) {
      queryBuilder.andWhere('article.categoryId = :categoryId', { categoryId });
    }

    // 按状态筛选
    if (status) {
      queryBuilder.andWhere('article.status = :status', { status });
    }

    // 排序
    queryBuilder.orderBy(`article.${sortBy}`, 'DESC');

    // 分页
    queryBuilder.skip((page - 1) * pageSize).take(pageSize);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取文章详情
   */
  async findOneArticle(id: number): Promise<HealthArticle> {
    const article = await this.articleRepository.findOne({
      where: { id },
      relations: ['category'],
    });

    if (!article) {
      throw new NotFoundException('文章不存在');
    }

    // 增加浏览量
    article.viewCount += 1;
    await this.articleRepository.save(article);

    return article;
  }

  /**
   * 创建文章
   */
  async createArticle(
    dto: CreateArticleDto,
    authorId: number,
  ): Promise<HealthArticle> {
    // 验证分类是否存在
    const category = await this.categoryRepository.findOne({
      where: { id: dto.categoryId },
    });

    if (!category) {
      throw new BadRequestException('分类不存在');
    }

    const article = this.articleRepository.create({
      ...dto,
      authorId,
      status: dto.status ?? ArticleStatus.DRAFT,
      viewCount: 0,
      favoriteCount: 0,
      likeCount: 0,
    });

    // 如果状态是已发布，设置发布时间
    if (article.status === ArticleStatus.PUBLISHED) {
      article.publishedAt = new Date();
    }

    const saved = await this.articleRepository.save(article);

    // 更新分类的文章计数
    category.articleCount += 1;
    await this.categoryRepository.save(category);

    return saved;
  }

  /**
   * 更新文章
   */
  async updateArticle(
    id: number,
    dto: UpdateHealthArticleDto,
  ): Promise<HealthArticle> {
    const article = await this.findOneArticle(id);

    // 如果修改了分类，更新原分类和新分类的文章计数
    if (dto.categoryId && dto.categoryId !== article.categoryId) {
      const newCategory = await this.categoryRepository.findOne({
        where: { id: dto.categoryId },
      });

      if (!newCategory) {
        throw new BadRequestException('新分类不存在');
      }

      // 减少原分类计数
      if (article.category) {
        article.category.articleCount -= 1;
        await this.categoryRepository.save(article.category);
      }

      // 增加新分类计数
      newCategory.articleCount += 1;
      await this.categoryRepository.save(newCategory);
    }

    // 如果状态从草稿变为已发布，设置发布时间
    if (
      dto.status === ArticleStatus.PUBLISHED &&
      article.status !== ArticleStatus.PUBLISHED
    ) {
      (dto as any).publishedAt = new Date();
    }

    await this.articleRepository.update(id, dto);
    return this.findOneArticle(id);
  }

  /**
   * 删除文章（软删除）
   */
  async removeArticle(id: number): Promise<void> {
    const article = await this.findOneArticle(id);

    // 更新分类的文章计数
    if (article.category) {
      article.category.articleCount -= 1;
      await this.categoryRepository.save(article.category);
    }

    const result = await this.articleRepository.softDelete(id);
    if (result.affected === 0) {
      throw new NotFoundException('文章不存在');
    }
  }

  /**
   * 发布文章
   */
  async publishArticle(id: number): Promise<HealthArticle> {
    const article = await this.findOneArticle(id);

    if (article.status === ArticleStatus.PUBLISHED) {
      throw new BadRequestException('文章已发布');
    }

    article.status = ArticleStatus.PUBLISHED;
    article.publishedAt = new Date();

    return await this.articleRepository.save(article);
  }

  /**
   * 取消发布文章
   */
  async unpublishArticle(id: number): Promise<HealthArticle> {
    const article = await this.findOneArticle(id);

    if (article.status === ArticleStatus.DRAFT) {
      throw new BadRequestException('文章已是草稿状态');
    }

    article.status = ArticleStatus.DRAFT;
    article.publishedAt = null;

    return await this.articleRepository.save(article);
  }
}
