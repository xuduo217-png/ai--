import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, EntityManager } from 'typeorm';
import { Friendship, FriendshipDirection } from '../entities/friendship.entity';
import { User } from '../../users/entities/user.entity';
import { QueryFriendsDto, UpdateFriendRemarkDto } from '../dto/friend-request.dto';
import { PaginatedResult } from '../../common/dto/pagination.dto';

/**
 * 好友关系管理服务
 *
 * 功能：
 * - 创建好友关系（双向）
 * - 删除好友关系（双向）
 * - 查询好友列表（支持分页和搜索）
 * - 修改好友备注
 * - 更新最后聊天时间
 */
@Injectable()
export class FriendsService {
  constructor(
    @InjectRepository(Friendship)
    private friendshipRepository: Repository<Friendship>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  /**
   * 创建好友关系（双向）
   * 同时创建两条记录：A→B 和 B→A
   *
   * @param userId 用户ID
   * @param friendId 好友ID
   * @returns 创建的好友关系
   */
  async createFriendship(
    userId: number,
    friendId: number,
    manager?: EntityManager,
  ): Promise<Friendship> {
    // 验证用户不能添加自己为好友
    if (userId === friendId) {
      throw new BadRequestException('不能添加自己为好友');
    }

    const friendshipRepository = manager
      ? manager.getRepository(Friendship)
      : this.friendshipRepository;

    // 检查好友关系是否已存在
    const existingFriendship = await friendshipRepository.findOne({
      where: { userId, friendId },
    });

    if (existingFriendship) {
      throw new ConflictException('好友关系已存在');
    }

    // 验证好友用户是否存在
    const friend = await this.userRepository.findOne({ where: { id: friendId } });
    if (!friend) {
      throw new NotFoundException('好友用户不存在');
    }

    const saveWithManager = async (transactionManager: EntityManager) => {
      const transactionFriendshipRepository = transactionManager.getRepository(Friendship);

      const friendship1 = transactionFriendshipRepository.create({
        userId,
        friendId,
        direction: FriendshipDirection.SENT,
        remark: null,
        lastChatAt: null,
      });
      await transactionManager.save(friendship1);

      const friendship2 = transactionFriendshipRepository.create({
        userId: friendId,
        friendId: userId,
        direction: FriendshipDirection.RECEIVED,
        remark: null,
        lastChatAt: null,
      });
      await transactionManager.save(friendship2);

      return friendship1;
    };

    if (manager) {
      return saveWithManager(manager);
    }

    // 使用事务创建双向好友关系
    const queryRunner = this.friendshipRepository.manager.connection.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const friendship = await saveWithManager(queryRunner.manager);

      await queryRunner.commitTransaction();

      return friendship;
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 删除好友关系（双向）
   * 同时删除两条记录：A→B 和 B→A
   *
   * @param userId 用户ID
   * @param friendId 好友ID
   */
  async deleteFriendship(userId: number, friendId: number): Promise<void> {
    // 检查好友关系是否存在
    const friendship = await this.friendshipRepository.findOne({
      where: { userId, friendId },
    });

    if (!friendship) {
      throw new NotFoundException('好友关系不存在');
    }

    // 使用事务删除双向好友关系
    const queryRunner = this.friendshipRepository.manager.connection.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // 删除 A→B 关系
      await queryRunner.manager.delete(Friendship, { userId, friendId });

      // 删除 B→A 关系
      await queryRunner.manager.delete(Friendship, { userId: friendId, friendId: userId });

      await queryRunner.commitTransaction();
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  /**
   * 获取好友列表（支持分页和搜索）
   *
   * @param userId 用户ID
   * @param query 查询参数
   * @returns 分页后的好友列表
   */
  async getFriendsList(
    userId: number,
    query: QueryFriendsDto,
  ): Promise<PaginatedResult<any>> {
    const { page = 1, pageSize = 20, search } = query;

    const friendshipCount = await this.friendshipRepository.count({
      where: { userId },
    });
    if (friendshipCount === 0) {
      return {
        data: [],
        total: 0,
        page,
        pageSize,
        totalPages: 0,
      };
    }

    // 构建查询
    const queryBuilder = this.friendshipRepository
      .createQueryBuilder('friendship')
      .innerJoinAndSelect('friendship.friend', 'friend')
      .where('friendship.userId = :userId', { userId });

    // 搜索条件（昵称或备注）
    if (search) {
      queryBuilder.andWhere(
        '(friend.username LIKE :search OR friendship.remark LIKE :search)',
        { search: `%${search}%` },
      );
    }

    // 排序：按拼音首字母排序
    queryBuilder.orderBy('friend.username', 'ASC');

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 执行查询
    const [friendships, total] = await queryBuilder.getManyAndCount();

    // 格式化返回数据
    const data = friendships.map((friendship) => ({
      id: friendship.id,
      userId: friendship.userId,
      friendId: friendship.friendId,
      friendName: friendship.friend.username,
      friendAvatar: friendship.friend.avatar,
      friendPhone: friendship.friend.phone,
      remark: friendship.remark,
      direction: friendship.direction,
      lastChatAt: friendship.lastChatAt,
      createdAt: friendship.createdAt,
    }));

    return {
      totalPages: Math.ceil(total / pageSize),
      data,
      total,
      page,
      pageSize,
    };
  }

  /**
   * 修改好友备注
   *
   * @param userId 用户ID
   * @param friendId 好友ID
   * @param dto 备注信息
   */
  async updateFriendRemark(
    userId: number,
    friendId: number,
    dto: UpdateFriendRemarkDto,
  ): Promise<void> {
    // 检查好友关系是否存在
    const friendship = await this.friendshipRepository.findOne({
      where: { userId, friendId },
    });

    if (!friendship) {
      throw new NotFoundException('好友关系不存在');
    }

    // 更新备注
    friendship.remark = dto.remark;
    await this.friendshipRepository.save(friendship);
  }

  /**
   * 更新最后聊天时间
   * 用于会话列表排序
   *
   * @param userId 用户ID
   * @param friendId 好友ID
   */
  async updateLastChatTime(userId: number, friendId: number): Promise<void> {
    // 更新双向的最后聊天时间
    await this.friendshipRepository.update(
      { userId, friendId },
      { lastChatAt: new Date() },
    );

    await this.friendshipRepository.update(
      { userId: friendId, friendId: userId },
      { lastChatAt: new Date() },
    );
  }

  /**
   * 检查好友关系是否存在
   *
   * @param userId 用户ID
   * @param friendId 好友ID
   * @returns 是否为好友
   */
  async isFriend(userId: number, friendId: number): Promise<boolean> {
    const friendship = await this.friendshipRepository.findOne({
      where: { userId, friendId },
    });

    return !!friendship;
  }

  /**
   * 获取用户的好友数量
   *
   * @param userId 用户ID
   * @returns 好友数量
   */
  async getFriendsCount(userId: number): Promise<number> {
    return this.friendshipRepository.count({ where: { userId } });
  }

  /**
   * Admin 查询所有好友关系（分页）
   *
   * @param query 查询参数
   * @returns 分页后的好友关系列表
   */
  async adminGetFriendships(query: any): Promise<any> {
    const { page = 1, pageSize = 20, userId, friendId } = query;

    // 构建查询
    const queryBuilder = this.friendshipRepository
      .createQueryBuilder('friendship')
      .leftJoinAndSelect('friendship.user', 'user')
      .leftJoinAndSelect('friendship.friend', 'friend');

    // 筛选条件
    if (userId) {
      queryBuilder.andWhere('friendship.userId = :userId', { userId });
    }

    if (friendId) {
      queryBuilder.andWhere('friendship.friendId = :friendId', { friendId });
    }

    // 排序：按创建时间倒序
    queryBuilder.orderBy('friendship.createdAt', 'DESC');

    // 分页
    const skip = (page - 1) * pageSize;
    queryBuilder.skip(skip).take(pageSize);

    // 执行查询
    const [friendships, total] = await queryBuilder.getManyAndCount();

    // 格式化返回数据
    const data = friendships.map((friendship) => ({
      id: friendship.id,
      userId: friendship.userId,
      userName: friendship.user.username,
      userAvatar: friendship.user.avatar,
      friendId: friendship.friendId,
      friendName: friendship.friend.username,
      friendAvatar: friendship.friend.avatar,
      direction: friendship.direction,
      remark: friendship.remark,
      lastChatAt: friendship.lastChatAt,
      createdAt: friendship.createdAt,
    }));

    return {
      totalPages: Math.ceil(total / pageSize),
      data,
      total,
      page,
      pageSize,
    };
  }

  /**
   * 获取总好友对数（用于统计）
   * 每对好友关系有两条记录，所以除以2
   *
   * @returns 总好友对数
   */
  async getTotalFriendshipPairs(): Promise<number> {
    const total = await this.friendshipRepository.count();
    return Math.floor(total / 2);
  }

  /**
   * 获取今日新增好友数
   *
   * @returns 今日新增好友对数
   */
  async getTodayNewFriendships(): Promise<number> {
    const count = await this.friendshipRepository
      .createQueryBuilder('friendship')
      .where('DATE(friendship.createdAt) = CURDATE()')
      .getCount();

    return Math.floor(count / 2);
  }

  /**
   * 获取平均每个用户的好友数
   *
   * @returns 平均好友数
   */
  async getAvgFriendsPerUser(): Promise<number> {
    const result = await this.friendshipRepository
      .createQueryBuilder('friendship')
      .select('AVG(friend_count)', 'avg')
      .from((subQuery) => {
        return subQuery
          .select('friendship.userId', 'userId')
          .addSelect('COUNT(*)', 'friend_count')
          .from(Friendship, 'friendship')
          .groupBy('friendship.userId');
      }, 'user_friend_counts')
      .getRawOne();

    return parseFloat(result?.avg || '0');
  }
}
