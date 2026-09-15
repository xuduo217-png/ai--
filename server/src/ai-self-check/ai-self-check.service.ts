import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { SelfCheckList } from './entities/self-check-list.entity';
import { SelfCheckQuestion } from './entities/self-check-question.entity';
import { SelfCheckOption } from './entities/self-check-option.entity';
import {
  CreateListDto,
  UpdateListDto,
  CreateQuestionDto,
  UpdateQuestionDto,
} from './dto';
import { PetsService } from '../pets/pets.service';
import { PetCategoriesService } from '../pet-categories/pet-categories.service';
import {
  createBusinessException,
  ErrorCode,
} from '../common/constants/error-codes';

/**
 * AI 自查表服务
 */
@Injectable()
export class AiSelfCheckService {
  constructor(
    @InjectRepository(SelfCheckList)
    private listRepository: Repository<SelfCheckList>,
    @InjectRepository(SelfCheckQuestion)
    private questionRepository: Repository<SelfCheckQuestion>,
    @InjectRepository(SelfCheckOption)
    private optionRepository: Repository<SelfCheckOption>,
    @Inject(forwardRef(() => PetsService))
    private petsService: PetsService,
    @Inject(forwardRef(() => PetCategoriesService))
    private petCategoriesService: PetCategoriesService,
  ) {}

  /**
   * 获取自查表列表（分页）
   */
  async getLists(query: any) {
    const {
      type,
      categoryId,
      status,
      keyword,
      page = 1,
      pageSize = 10,
    } = query;

    const queryBuilder = this.listRepository.createQueryBuilder('list');

    // 左连接查询问题数量，避免加载完整的 questions 关联数据
    queryBuilder
      .leftJoin('list.questions', 'questions')
      .addSelect('COUNT(questions.id)', 'questionCount');

    if (type) queryBuilder.andWhere('list.type = :type', { type });
    if (categoryId)
      queryBuilder.andWhere('list.categoryId = :categoryId', { categoryId });
    if (status) queryBuilder.andWhere('list.status = :status', { status });
    if (keyword)
      queryBuilder.andWhere('list.title LIKE :keyword', {
        keyword: `%${keyword}%`,
      });

    // 添加分组以正确计数
    queryBuilder.groupBy('list.id');

    const result = await queryBuilder
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .orderBy('list.sortOrder', 'ASC')
      .getRawAndEntities();

    // 组合实体和计算出的数量
    const data = result.entities.map((list, index) => ({
      ...list,
      questionCount: parseInt(result.raw[index].questionCount) || 0,
    }));

    // 获取总数（使用单独的查询）
    const totalQuery = this.listRepository.createQueryBuilder('list');
    if (type) totalQuery.andWhere('list.type = :type', { type });
    if (categoryId)
      totalQuery.andWhere('list.categoryId = :categoryId', { categoryId });
    if (status) totalQuery.andWhere('list.status = :status', { status });
    if (keyword)
      totalQuery.andWhere('list.title LIKE :keyword', {
        keyword: `%${keyword}%`,
      });
    const totalCount = await totalQuery.getCount();

    return {
      data,
      pagination: {
        total: totalCount,
        page,
        pageSize,
        totalPages: Math.ceil(totalCount / pageSize),
      },
    };
  }

  /**
   * 获取自查表详情
   */
  async getListDetail(id: number) {
    const list = await this.listRepository.findOne({
      where: { id },
      relations: ['questions', 'questions.options'],
    });

    if (!list) {
      throw new NotFoundException('自查表不存在');
    }

    return list;
  }

  /**
   * 创建自查表
   */
  async createList(dto: CreateListDto) {
    // 验证：特定项必须选择分类
    if (dto.type === 'SPECIFIC' && !dto.categoryId) {
      throw new BadRequestException('特定项必须选择关联的分类');
    }

    // 验证：公共项不能选择分类
    if (dto.type === 'PUBLIC' && dto.categoryId) {
      throw new BadRequestException('公共项不能关联分类');
    }

    const list = this.listRepository.create(dto);
    return await this.listRepository.save(list);
  }

  /**
   * 更新自查表
   */
  async updateList(id: number, dto: UpdateListDto) {
    const list = await this.listRepository.findOne({ where: { id } });
    if (!list) {
      throw new NotFoundException('自查表不存在');
    }

    // UpdateListDto 已排除 type 字段，所以不需要检查
    Object.assign(list, dto);
    return await this.listRepository.save(list);
  }

  /**
   * 更新状态
   */
  async updateStatus(id: number, status: 'ACTIVE' | 'INACTIVE') {
    const list = await this.listRepository.findOne({ where: { id } });
    if (!list) {
      throw new NotFoundException('自查表不存在');
    }

    list.status = status;
    return await this.listRepository.save(list);
  }

  /**
   * 删除自查表
   */
  async deleteList(id: number) {
    const list = await this.listRepository.findOne({ where: { id } });
    if (!list) {
      throw new NotFoundException('自查表不存在');
    }

    await this.listRepository.remove(list);
    return { success: true };
  }

  /**
   * 获取问题列表
   */
  async getQuestions(listId: number) {
    const questions = await this.questionRepository.find({
      where: { listId },
      relations: ['options'],
      order: { sortOrder: 'ASC' },
    });

    return questions;
  }

  /**
   * 创建问题
   */
  async createQuestion(dto: CreateQuestionDto) {
    // 验证自查表是否存在
    const list = await this.listRepository.findOne({
      where: { id: dto.listId },
    });
    if (!list) {
      throw new NotFoundException('自查表不存在');
    }

    // 验证：选择题必须有选项
    if (
      dto.questionType !== 'TEXT' &&
      (!dto.options || dto.options.length === 0)
    ) {
      throw new BadRequestException('选择题至少需要一个选项');
    }

    // 验证：填空题不能有选项
    if (dto.questionType === 'TEXT' && dto.options && dto.options.length > 0) {
      throw new BadRequestException('填空题不能包含选项');
    }

    // 创建问题
    const question = this.questionRepository.create({
      listId: dto.listId,
      questionText: dto.questionText,
      questionType: dto.questionType,
      required: dto.required,
      sortOrder: dto.sortOrder,
    });

    const savedQuestion = await this.questionRepository.save(question);

    // 如果有选项，创建选项
    if (dto.options && dto.options.length > 0) {
      const options = dto.options.map((opt) =>
        this.optionRepository.create({
          questionId: savedQuestion.id,
          optionText: opt.optionText,
          optionImage: opt.optionImage,
          sortOrder: opt.sortOrder,
        }),
      );
      await this.optionRepository.save(options);
      savedQuestion.options = options;
    }

    return savedQuestion;
  }

  /**
   * 更新问题
   */
  async updateQuestion(id: number, dto: UpdateQuestionDto) {
    const question = await this.questionRepository.findOne({
      where: { id },
      relations: ['options'],
    });

    if (!question) {
      throw new NotFoundException('问题不存在');
    }

    // 验证：选择题必须有选项
    if (dto.questionType && dto.questionType !== 'TEXT') {
      const optionsToUse = dto.options || question.options;
      if (!optionsToUse || optionsToUse.length === 0) {
        throw new BadRequestException('选择题至少需要一个选项');
      }
    }

    // 验证：填空题不能有选项
    if (dto.questionType === 'TEXT') {
      if (
        (dto.options && dto.options.length > 0) ||
        (question.options && question.options.length > 0)
      ) {
        throw new BadRequestException('填空题不能包含选项');
      }
    }

    // 更新问题字段
    Object.assign(question, {
      questionText: dto.questionText ?? question.questionText,
      questionType: dto.questionType ?? question.questionType,
      required: dto.required ?? question.required,
      sortOrder: dto.sortOrder ?? question.sortOrder,
    });

    const savedQuestion = await this.questionRepository.save(question);

    // 更新选项
    if (dto.options && dto.questionType !== 'TEXT') {
      // 删除旧选项
      await this.optionRepository.delete({ questionId: id });

      // 创建新选项
      const options = dto.options.map((opt) =>
        this.optionRepository.create({
          questionId: id,
          optionText: opt.optionText,
          optionImage: opt.optionImage,
          sortOrder: opt.sortOrder,
        }),
      );
      await this.optionRepository.save(options);
      savedQuestion.options = options;
    }

    return savedQuestion;
  }

  /**
   * 删除问题
   * 业务规则：数据库当前未为选项表配置级联删除，必须先清理子选项再删除问题，
   * 否则会触发外键约束导致后台管理无法删除题目。
   */
  async deleteQuestion(id: number) {
    const question = await this.questionRepository.findOne({ where: { id } });
    if (!question) {
      throw new NotFoundException('问题不存在');
    }

    await this.questionRepository.manager.transaction(async (manager) => {
      await manager.delete(SelfCheckOption, { questionId: id });
      await manager.delete(SelfCheckQuestion, { id });
    });

    return { success: true };
  }

  /**
   * 根据宠物ID获取自查表列表
   * 返回公共项 + 匹配的特定项
   */
  async getListsByPetId(petId: number) {
    // 1. 查询宠物信息
    const pet = await this.petsService.findOne(petId);
    if (!pet) {
      throw new NotFoundException('宠物不存在');
    }

    // 2. 查询宠物的分类，追溯到一级分类
    const category = await this.petCategoriesService.findOne(pet.categoryId);
    if (!category) {
      throw new NotFoundException('宠物分类不存在');
    }

    // 获取一级分类ID（如果是二级分类，取父分类ID）
    const topLevelCategoryId = category.parentId || category.id;

    // 3. 查询所有启用的自查表
    const lists = await this.listRepository.find({
      where: { status: 'ACTIVE' },
      relations: ['questions', 'questions.options'],
      order: { sortOrder: 'ASC' },
    });

    // 4. 筛选并排序：公共项在前，特定项在后，按 sortOrder 排序
    return lists
      .filter(
        (list) =>
          list.type === 'PUBLIC' || list.categoryId === topLevelCategoryId,
      )
      .sort((a, b) => {
        // 先按类型排序：公共项在前
        if (a.type === 'PUBLIC' && b.type === 'SPECIFIC') return -1;
        if (a.type === 'SPECIFIC' && b.type === 'PUBLIC') return 1;
        // 同类型按 sortOrder 排序
        return a.sortOrder - b.sortOrder;
      });
  }

  /**
   * 批量更新自查表排序
   * @param listIds 按新顺序排列的自查表 ID 数组
   * @returns 操作结果
   */
  async reorderLists(listIds: number[]): Promise<{ message: string }> {
    // 验证所有 ID 是否存在
    const lists = await this.listRepository.findBy({
      id: In(listIds),
    });

    if (lists.length !== listIds.length) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        '部分 ID 不存在',
      );
    }

    // 使用事务批量更新排序
    await this.listRepository.manager.transaction(async (manager) => {
      for (let i = 0; i < listIds.length; i++) {
        await manager.update(SelfCheckList, listIds[i], {
          sortOrder: i,
        });
      }
    });

    return { message: '排序更新成功' };
  }

  /**
   * 批量更新问题排序
   * @param questionIds 按新顺序排列的问题 ID 数组
   * @returns 操作结果
   */
  async reorderQuestions(questionIds: number[]): Promise<{ message: string }> {
    // 验证所有 ID 是否存在
    const questions = await this.questionRepository.findBy({
      id: In(questionIds),
    });

    if (questions.length !== questionIds.length) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        '部分 ID 不存在',
      );
    }

    // 使用事务批量更新排序
    await this.questionRepository.manager.transaction(async (manager) => {
      for (let i = 0; i < questionIds.length; i++) {
        await manager.update(SelfCheckQuestion, questionIds[i], {
          sortOrder: i,
        });
      }
    });

    return { message: '排序更新成功' };
  }

  /**
   * 批量更新选项排序
   * @param questionId 问题 ID
   * @param optionIds 按新顺序排列的选项 ID 数组
   * @returns 操作结果
   */
  async reorderOptions(
    questionId: number,
    optionIds: number[],
  ): Promise<{ message: string }> {
    // 验证问题是否存在
    const question = await this.questionRepository.findOne({
      where: { id: questionId },
      relations: ['options'],
    });

    if (!question) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        '问题不存在',
      );
    }

    // 验证所有选项 ID 是否属于该问题
    const questionOptionIds = question.options.map((opt) => opt.id);
    const invalidIds = optionIds.filter(
      (id) => !questionOptionIds.includes(id),
    );

    if (invalidIds.length > 0) {
      throw createBusinessException(
        ErrorCode.BUSINESS_INVALID_PARAM,
        '部分选项不属于该问题',
      );
    }

    // 使用事务批量更新排序
    await this.optionRepository.manager.transaction(async (manager) => {
      for (let i = 0; i < optionIds.length; i++) {
        await manager.update(SelfCheckOption, optionIds[i], {
          sortOrder: i,
        });
      }
    });

    return { message: '排序更新成功' };
  }
}
