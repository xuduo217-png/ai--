import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { QueryFailedError, Repository, Like, FindOptionsWhere } from "typeorm";
import {
  PetCategory,
  PetCategoryTreeNode,
} from "./entities/pet-category.entity";
import { Pet } from "../pets/entities/pet.entity";
import { CreatePetCategoryDto } from "./dto/create-pet-category.dto";
import { UpdatePetCategoryDto } from "./dto/update-pet-category.dto";
import { QueryPetCategoriesDto } from "./dto/query-pet-categories.dto";
import {
  createBusinessException,
  ErrorCode,
} from "../common/constants/error-codes";

/**
 * 宠物类别服务类
 * 提供宠物类别的 CRUD 操作和树形结构查询
 */
@Injectable()
export class PetCategoriesService {
  constructor(
    @InjectRepository(PetCategory)
    private petCategoryRepository: Repository<PetCategory>,
    @InjectRepository(Pet)
    private petRepository: Repository<Pet>,
  ) {}

  /**
   * 创建宠物类别
   * @param createPetCategoryDto 类别创建数据
   * @returns 创建的类别对象
   */
  async create(
    createPetCategoryDto: CreatePetCategoryDto,
  ): Promise<PetCategory> {
    try {
      const category = this.petCategoryRepository.create(createPetCategoryDto);
      return this.petCategoryRepository.save(category);
    } catch (error) {
      if (error instanceof QueryFailedError) {
        // 处理唯一键冲突（同一父级下名称重复）
        if (error.message.includes("uk_name_parentId")) {
          throw createBusinessException(
            ErrorCode.BUSINESS_INVALID_PARAM,
            "同一父级下分类名称已存在",
          );
        }
      }
      throw error;
    }
  }

  /**
   * 获取分类树（支持搜索）
   * @param queryDto 查询参数
   * @returns 树形结构的分类列表
   */
  async findTree(
    queryDto?: QueryPetCategoriesDto,
  ): Promise<PetCategoryTreeNode[]> {
    const { name } = queryDto || {};

    // 构建查询条件
    const where: FindOptionsWhere<PetCategory> = {};
    if (name) {
      where.name = Like(`%${name}%`);
    }

    // 查询所有分类（按排序和创建时间排序）
    const categories = await this.petCategoryRepository.find({
      where,
      order: { sortOrder: "ASC", createdAt: "ASC" },
    });

    // 构建树形结构
    return this.buildTree(categories);
  }

  /**
   * 获取分类列表（平铺，非树形）
   * @param queryDto 查询参数
   * @returns 分类列表
   */
  async findAll(queryDto?: QueryPetCategoriesDto): Promise<PetCategory[]> {
    const { name } = queryDto || {};

    const where: FindOptionsWhere<PetCategory> = {};
    if (name) {
      where.name = Like(`%${name}%`);
    }

    return this.petCategoryRepository.find({
      where,
      order: { sortOrder: "ASC", createdAt: "ASC" },
    });
  }

  /**
   * 获取分类详情
   * @param id 分类ID
   * @returns 分类对象
   */
  async findOne(id: number): Promise<PetCategory> {
    const category = await this.petCategoryRepository.findOne({
      where: { id },
    });
    if (!category) {
      throw new NotFoundException("分类不存在");
    }
    return category;
  }

  /**
   * 更新分类信息
   * @param id 分类ID
   * @param updatePetCategoryDto 更新数据
   * @returns 更新后的分类对象
   */
  async update(
    id: number,
    updatePetCategoryDto: UpdatePetCategoryDto,
  ): Promise<PetCategory> {
    // 防止循环引用：不能将分类的 parentId 设置为自己或自己的子分类
    if (updatePetCategoryDto.parentId !== undefined) {
      await this.validateParentId(id, updatePetCategoryDto.parentId);
    }

    try {
      await this.petCategoryRepository.update(id, updatePetCategoryDto);
      return this.findOne(id);
    } catch (error) {
      if (error instanceof QueryFailedError) {
        // 处理唯一键冲突
        if (error.message.includes("uk_name_parentId")) {
          throw createBusinessException(
            ErrorCode.BUSINESS_INVALID_PARAM,
            "同一父级下分类名称已存在",
          );
        }
      }
      throw error;
    }
  }

  /**
   * 删除分类（级联删除子分类）
   * @param id 分类ID
   */
  async remove(id: number): Promise<{ affected: number }> {
    // 先确认分类存在，避免删除不存在的分类时返回含糊的 affected=0
    await this.findOne(id);

    // 先获取所有需要删除的ID（包括子分类）
    const idsToDelete = await this.getAllChildIds(id);

    // 删除前先检查宠物引用，优先返回业务层可读错误，而不是直接暴露数据库外键异常
    await this.validateCategoryDeletionReferences(idsToDelete);

    // 批量删除
    const result = await this.petCategoryRepository.delete(idsToDelete);
    return { affected: result.affected || 0 };
  }

  /**
   * 构建树形结构
   * @param categories 所有分类列表
   * @param parentId 父级ID（用于递归）
   * @returns 树形结构的分类列表
   */
  private buildTree(
    categories: PetCategory[],
    parentId: number | null = null,
  ): PetCategoryTreeNode[] {
    return categories
      .filter((category) => category.parentId === parentId)
      .map((category) => ({
        ...category,
        children: this.buildTree(categories, category.id),
      }));
  }

  /**
   * 获取所有子分类ID（包括子孙分类）
   * @param parentId 父级ID
   * @returns 所有子分类ID列表
   */
  private async getAllChildIds(parentId: number): Promise<number[]> {
    const children = await this.petCategoryRepository.find({
      where: { parentId },
      select: ["id"],
    });

    const ids = [parentId, ...children.map((child) => child.id)];

    // 递归获取子孙分类的ID
    for (const child of children) {
      const childIds = await this.getAllChildIds(child.id);
      ids.push(...childIds.filter((id) => !ids.includes(id)));
    }

    return ids;
  }

  /**
   * 删除分类前校验是否仍有宠物引用
   * 业务原因：当前宠物删除为软删除，数据库外键仍会保留在 pets 表中，
   * 如果不提前校验，前端只能拿到晦涩的数据库外键报错。
   * @param categoryIds 计划删除的分类ID列表（包含子分类）
   */
  private async validateCategoryDeletionReferences(
    categoryIds: number[],
  ): Promise<void> {
    const activeReferenceCount = await this.countPetReferences(categoryIds);
    if (activeReferenceCount > 0) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        `当前分类下仍有 ${activeReferenceCount} 条宠物档案引用，请先调整宠物分类或删除宠物后再删除分类`,
      );
    }

    const deletedReferenceCount = await this.countPetReferences(
      categoryIds,
      true,
    );
    if (deletedReferenceCount > 0) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        `当前分类下存在 ${deletedReferenceCount} 条已删除的宠物档案引用。由于宠物删除为软删除，请先清理相关宠物数据后再删除分类`,
      );
    }
  }

  /**
   * 统计分类被宠物引用的数量
   * @param categoryIds 分类ID列表
   * @param onlyDeleted 是否只统计已软删除宠物
   * @returns 引用数量
   */
  private async countPetReferences(
    categoryIds: number[],
    onlyDeleted: boolean = false,
  ): Promise<number> {
    const queryBuilder = this.petRepository.createQueryBuilder("pet");

    if (onlyDeleted) {
      // 只有启用 withDeleted 才能查到软删除记录，否则 TypeORM 会自动过滤掉
      queryBuilder.withDeleted();
    }

    return queryBuilder
      .where(
        "(pet.categoryId IN (:...categoryIds) OR pet.subCategoryId IN (:...categoryIds))",
        {
          categoryIds,
        },
      )
      .andWhere(
        onlyDeleted ? "pet.deletedAt IS NOT NULL" : "pet.deletedAt IS NULL",
      )
      .getCount();
  }

  /**
   * 验证 parentId 是否有效（防止循环引用）
   * @param id 当前分类ID
   * @param parentId 新的父级ID
   */
  private async validateParentId(
    id: number,
    parentId: number | null,
  ): Promise<void> {
    if (parentId === null) {
      return; // 一级分类，无需验证
    }

    if (parentId === id) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "不能将分类的父级设置为自己",
      );
    }

    // 检查是否是自己的子孙分类
    const childIds = await this.getAllChildIds(id);
    if (childIds.includes(parentId)) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        "不能将分类的父级设置为自己的子分类",
      );
    }
  }
}
