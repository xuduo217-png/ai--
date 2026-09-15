import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PaginatedResult } from '../common/dto/pagination.dto';
import {
  createBusinessException,
  ErrorCode,
} from '../common/constants/error-codes';
import {
  LostFound,
  LostFoundRecordType,
  PublisherType,
} from './entities/lost-found.entity';
import { CreateLostFoundDto } from './dto/create-lost-found.dto';
import { UpdateLostFoundDto } from './dto/update-lost-found.dto';
import { QueryLostFoundDto } from './dto/query-lost-found.dto';
import { Pet } from '../pets/entities/pet.entity';
import { User, UserRole } from '../users/entities/user.entity';
import { ModerationService } from '../moderation/moderation.service';

/**
 * 走失招领服务
 *
 * 处理宠物走失和招领信息的业务逻辑
 * - 创建走失信息
 * - 查询列表（支持分页和筛选）
 * - 标记已找回
 * - 设置置顶
 * - 删除信息
 */
@Injectable()
export class LostFoundService {
  constructor(
    @InjectRepository(LostFound)
    private readonly lostFoundRepository: Repository<LostFound>,
    @InjectRepository(Pet)
    private readonly petRepository: Repository<Pet>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @Optional()
    private readonly moderationService?: ModerationService,
  ) {}

  /**
   * 归一化记录状态。
   * 领养信息不支持“已找回”，走失信息允许通过 isFound 控制状态。
   */
  private normalizeRecordState(
    recordType: LostFoundRecordType,
    isFound?: boolean,
  ) {
    if (recordType !== LostFoundRecordType.LOST) {
      return {
        isFound: false,
        foundAt: null,
      };
    }

    const resolvedIsFound = Boolean(isFound);

    return {
      isFound: resolvedIsFound,
      foundAt: resolvedIsFound ? new Date() : null,
    };
  }

  private async loadPetSnapshot(
    petId: number,
    userId: number,
    canUseAnyPet: boolean,
    forbiddenMessage: string,
  ) {
    const pet = await this.petRepository.findOne({
      where: { id: petId },
      relations: ['category', 'subCategory'],
    });

    if (!pet) {
      throw createBusinessException(
        ErrorCode.LOST_FOUND_001,
        '宠物不存在或已被删除',
      );
    }

    if (!canUseAnyPet && pet.ownerId !== userId) {
      throw createBusinessException(ErrorCode.LOST_FOUND_002, forbiddenMessage);
    }

    return {
      petId: pet.id,
      petName: pet.name.trim(),
      petCategory: pet.category?.name?.trim() || '',
      petBreed: pet.subCategory?.name?.trim() || '',
    };
  }

  private normalizeManualPetSnapshot(
    petName?: string | null,
    petCategory?: string | null,
    petBreed?: string | null,
  ) {
    const snapshot = {
      petId: null,
      petName: petName?.trim() || '',
      petCategory: petCategory?.trim() || '',
      petBreed: petBreed?.trim() || '',
    };
    if (!snapshot.petName || !snapshot.petCategory || !snapshot.petBreed) {
      throw createBusinessException(
        ErrorCode.LOST_FOUND_001,
        '请完整填写宠物名称、类别和品种',
      );
    }
    return snapshot;
  }

  /**
   * 创建走失信息
   */
  async create(
    createDto: CreateLostFoundDto,
    publisherId: number,
    publisherType: PublisherType = PublisherType.USER,
  ): Promise<LostFound> {
    const recordType = createDto.recordType || LostFoundRecordType.LOST;
    const petSnapshot =
      createDto.petId != null
        ? await this.loadPetSnapshot(
            createDto.petId,
            publisherId,
            publisherType !== PublisherType.USER,
            '您只能发布自己的宠物信息',
          )
        : this.normalizeManualPetSnapshot(
            createDto.petName,
            createDto.petCategory,
            createDto.petBreed,
          );

    const normalizedState = this.normalizeRecordState(
      recordType,
      createDto.isFound,
    );

    // 创建走失信息
    const lostFound = this.lostFoundRepository.create({
      ...createDto,
      ...petSnapshot,
      recordType,
      ...normalizedState,
      publisherId,
      publisherType,
    });

    return await this.lostFoundRepository.save(lostFound);
  }

  /**
   * 获取走失信息列表（分页+筛选）
   */
  async findAll(
    queryDto: QueryLostFoundDto,
    currentUserId?: number,
  ): Promise<PaginatedResult<LostFound>> {
    const {
      page = 1,
      pageSize = 10,
      recordType,
      isFound,
      isPinned,
      petId,
      publisherId,
      keyword,
    } = queryDto;

    const query = this.lostFoundRepository
      .createQueryBuilder('lostFound')
      .leftJoinAndSelect('lostFound.pet', 'pet')
      .leftJoin('lostFound.publisher', 'publisher')
      .addSelect(['publisher.id', 'publisher.username', 'publisher.avatar'])
      .leftJoinAndSelect('pet.category', 'category')
      .leftJoinAndSelect('pet.subCategory', 'subCategory');

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    if (blockedUserIds?.length) {
      query.andWhere('lostFound.publisherId NOT IN (:...blockedUserIds)', {
        blockedUserIds,
      });
    }

    if (recordType) {
      query.andWhere('lostFound.recordType = :recordType', { recordType });
    }

    // 筛选是否已找回（isFound 已经是数字 0/1，直接使用）
    if (isFound !== undefined) {
      query.andWhere('lostFound.isFound = :isFound', { isFound });
    }

    // 筛选是否置顶（isPinned 已经是数字 0/1，直接使用）
    if (isPinned !== undefined) {
      query.andWhere('lostFound.isPinned = :isPinned', { isPinned });
    }

    // 筛选宠物ID
    if (petId) {
      query.andWhere('lostFound.petId = :petId', { petId });
    }

    // 筛选发布者ID
    if (publisherId) {
      query.andWhere('lostFound.publisherId = :publisherId', { publisherId });
    }

    // 关键词搜索（描述、联系人姓名）
    if (keyword) {
      query.andWhere(
        '(lostFound.description LIKE :keyword OR lostFound.contactName LIKE :keyword OR lostFound.petName LIKE :keyword OR lostFound.petCategory LIKE :keyword OR lostFound.petBreed LIKE :keyword)',
        { keyword: `%${keyword}%` },
      );
    }

    // 排序：置顶优先，然后按创建时间降序
    query
      .orderBy('lostFound.isPinned', 'DESC')
      .addOrderBy('lostFound.createdAt', 'DESC');

    const [data, total] = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    for (const record of data) {
      record.isOwner =
        currentUserId !== undefined && record.publisherId === currentUserId;
    }

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取走失信息详情
   */
  async findOne(id: number, currentUserId?: number): Promise<LostFound> {
    const lostFound = await this.lostFoundRepository
      .createQueryBuilder('lostFound')
      .leftJoinAndSelect('lostFound.pet', 'pet')
      .leftJoin('lostFound.publisher', 'publisher')
      .addSelect(['publisher.id', 'publisher.username', 'publisher.avatar'])
      .leftJoinAndSelect('pet.category', 'category')
      .leftJoinAndSelect('pet.subCategory', 'subCategory')
      .where('lostFound.id = :id', { id })
      .getOne();

    if (!lostFound) {
      throw new NotFoundException('走失信息不存在');
    }

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    if (blockedUserIds?.includes(lostFound.publisherId)) {
      throw new NotFoundException('走失信息不存在');
    }

    lostFound.isOwner =
      currentUserId !== undefined && lostFound.publisherId === currentUserId;

    return lostFound;
  }

  /**
   * 更新走失信息
   */
  async update(
    id: number,
    updateDto: UpdateLostFoundDto,
    userId: number,
    userRole: UserRole,
  ): Promise<LostFound> {
    const lostFound = await this.findOne(id);

    // 验证权限：只有发布者或管理员可以更新
    if (lostFound.publisherId !== userId && userRole !== UserRole.SUPER_ADMIN) {
      throw createBusinessException(
        ErrorCode.LOST_FOUND_002,
        '您没有权限操作此信息',
      );
    }

    let petSnapshot: ReturnType<
      LostFoundService['normalizeManualPetSnapshot']
    > | null = null;
    const petChanged =
      updateDto.petId !== undefined && updateDto.petId !== lostFound.petId;
    if (petChanged) {
      petSnapshot =
        updateDto.petId != null
          ? await this.loadPetSnapshot(
              updateDto.petId,
              userId,
              userRole === UserRole.SUPER_ADMIN,
              '您只能选择自己的宠物',
            )
          : this.normalizeManualPetSnapshot(
              updateDto.petName,
              updateDto.petCategory,
              updateDto.petBreed,
            );
    } else if (
      lostFound.petId === null &&
      (updateDto.petName !== undefined ||
        updateDto.petCategory !== undefined ||
        updateDto.petBreed !== undefined)
    ) {
      petSnapshot = this.normalizeManualPetSnapshot(
        updateDto.petName ?? lostFound.petName,
        updateDto.petCategory ?? lostFound.petCategory,
        updateDto.petBreed ?? lostFound.petBreed,
      );
    }

    const nextRecordType = updateDto.recordType || lostFound.recordType;
    const normalizedState =
      updateDto.recordType !== undefined || updateDto.isFound !== undefined
        ? this.normalizeRecordState(
            nextRecordType,
            updateDto.isFound ?? lostFound.isFound,
          )
        : null;

    const safeUpdate = { ...updateDto };
    delete safeUpdate.petName;
    delete safeUpdate.petCategory;
    delete safeUpdate.petBreed;

    // 更新信息
    Object.assign(lostFound, safeUpdate);

    if (petSnapshot) {
      Object.assign(lostFound, petSnapshot);
    }

    if (normalizedState) {
      Object.assign(lostFound, normalizedState);
    }

    return await this.lostFoundRepository.save(lostFound);
  }

  /**
   * 设置/取消置顶
   */
  async togglePin(id: number): Promise<LostFound> {
    const lostFound = await this.findOne(id);

    // 切换置顶状态
    lostFound.isPinned = !lostFound.isPinned;

    return await this.lostFoundRepository.save(lostFound);
  }

  /**
   * 标记已找回
   */
  async markAsFound(
    id: number,
    userId: number,
    userRole: UserRole,
  ): Promise<LostFound> {
    const lostFound = await this.findOne(id);

    // 验证权限：只有发布者或管理员可以标记
    if (lostFound.publisherId !== userId && userRole !== UserRole.SUPER_ADMIN) {
      throw createBusinessException(
        ErrorCode.LOST_FOUND_002,
        '您没有权限操作此信息',
      );
    }

    if (lostFound.recordType !== LostFoundRecordType.LOST) {
      throw createBusinessException(
        ErrorCode.LOST_FOUND_006,
        '领养信息不支持标记已找回',
      );
    }

    // 检查是否已标记
    if (lostFound.isFound) {
      throw createBusinessException(
        ErrorCode.LOST_FOUND_003,
        '该信息已标记为找回，无需重复操作',
      );
    }

    // 标记为已找回
    lostFound.isFound = true;
    lostFound.foundAt = new Date();

    return await this.lostFoundRepository.save(lostFound);
  }

  /**
   * 删除走失信息
   */
  async remove(id: number, userId: number, userRole: UserRole): Promise<void> {
    const lostFound = await this.findOne(id);

    // 验证权限：只有发布者或管理员可以删除
    if (lostFound.publisherId !== userId && userRole !== UserRole.SUPER_ADMIN) {
      throw createBusinessException(
        ErrorCode.LOST_FOUND_002,
        '您没有权限操作此信息',
      );
    }

    await this.lostFoundRepository.softRemove(lostFound);
  }
}
