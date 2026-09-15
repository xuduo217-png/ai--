import {
  Injectable,
  BadRequestException,
  ConflictException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, UserGender, UserRole } from './entities/user.entity';
import { QueryUsersDto } from './dto/query-users.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { Pet } from '../pets/entities/pet.entity';
import * as bcrypt from 'bcryptjs';
import {
  AdjustUserBalanceDto,
  AdjustUserBalanceType,
} from './dto/adjust-user-balance.dto';
import {
  RelatedType,
  WalletTransaction,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../shop/entities/wallet-transaction.entity';
import {
  createBusinessException,
  ErrorCode,
} from '../common/constants/error-codes';
import { add, subtract, toNumber } from '../common/utils/currency.util';
import { SensitiveWordService } from '../community/sensitive-word.service';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Pet)
    private petRepository: Repository<Pet>,
    private readonly sensitiveWordService: SensitiveWordService,
  ) {}

  /**
   * 创建用户
   * 支持通过手机号或邮箱创建用户
   */
  async create(data: {
    username?: string;
    password: string;
    email?: string;
    phone: string;
    role?: UserRole;
    avatar?: string;
    hospitalId?: number;
  }): Promise<User> {
    const {
      username,
      password,
      email,
      phone,
      role = UserRole.USER,
      avatar,
      hospitalId,
    } = data;

    // 检查手机号是否已存在
    const existingPhoneUser = await this.userRepository.findOne({
      where: { phone },
    });

    if (existingPhoneUser) {
      throw new ConflictException('手机号已被注册');
    }

    // 如果提供了用户名，检查用户名是否已存在
    if (username) {
      await this.sensitiveWordService.assertNicknameAllowed(username);

      const existingUsernameUser = await this.userRepository.findOne({
        where: { username },
      });

      if (existingUsernameUser) {
        throw new ConflictException('用户名已存在');
      }
    }

    // 如果提供了邮箱，检查邮箱是否已存在
    if (email) {
      const existingEmailUser = await this.userRepository.findOne({
        where: { email },
      });

      if (existingEmailUser) {
        throw new ConflictException('邮箱已被注册');
      }
    }

    // 加密密码
    const hashedPassword = await bcrypt.hash(password, 10);

    // 创建用户（如果没有提供 username，使用 phone 作为默认 username）
    const user = this.userRepository.create({
      username: username || phone,
      password: hashedPassword,
      email,
      phone,
      role,
      avatar,
      hospitalId,
      verified: false, // 新创建的用户默认未认证
    });

    return this.userRepository.save(user);
  }

  /**
   * 获取用户列表（支持分页和筛选）
   * 自动排除超级管理员用户
   * 默认只返回普通用户（USER 角色），其他角色需要通过 role 参数明确指定
   */
  async findAll(query?: QueryUsersDto): Promise<PaginatedResult<User>> {
    // 默认只查询普通用户，其他角色需要通过 role 参数明确指定
    const {
      page = 1,
      pageSize = 10,
      role = UserRole.USER,
      hospitalId,
      phone,
      isActive,
    } = query || {};

    // 创建查询构建器
    const queryBuilder = this.userRepository.createQueryBuilder('user');

    // 排除超级管理员（系统设置模块中管理）
    queryBuilder.andWhere('user.role != :superAdminRole', {
      superAdminRole: UserRole.SUPER_ADMIN,
    });

    // 角色筛选
    if (role) {
      queryBuilder.andWhere('user.role = :role', { role });
    }

    // 医院ID筛选（用于查询特定医院的用户）
    if (hospitalId) {
      queryBuilder.andWhere('user.hospitalId = :hospitalId', { hospitalId });
    }

    // 手机号筛选（模糊查询）
    if (phone) {
      queryBuilder.andWhere('user.phone LIKE :phone', { phone: `%${phone}%` });
    }

    // 状态筛选
    if (isActive !== undefined) {
      queryBuilder.andWhere('user.isActive = :isActive', { isActive });
    }

    // 获取总数
    const total = await queryBuilder.getCount();

    // 分页查询数据
    const data = await queryBuilder
      .select([
        'user.id',
        'user.username',
        'user.email',
        'user.phone',
        'user.role',
        'user.avatar',
        'user.verified',
        'user.isActive',
        'user.hospitalId',
        'user.balance',
        'user.pendingBalance',
        'user.createdAt',
        'user.updatedAt',
        'user.lastLoginAt',
      ])
      .leftJoin('user.hospital', 'hospital') // 关联医院信息
      .addSelect(['hospital.id', 'hospital.name'])
      .orderBy('user.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getMany();

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async findOne(id: number): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id },
      select: [
        'id',
        'username',
        'email',
        'phone',
        'role',
        'avatar',
        'gender',
        'verified',
        'isActive',
        'createdAt',
        'updatedAt',
      ],
    });
    if (!user) {
      throw new NotFoundException('用户不存在');
    }
    return user;
  }

  async findByUsername(username: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { username } });
  }

  async findByPhone(phone: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { phone } });
  }

  async createWithPhone(
    phone: string,
    password: string,
    role: UserRole = UserRole.USER,
  ): Promise<User> {
    const existingUser = await this.userRepository.findOne({
      where: [{ phone }, { username: phone }],
    });

    if (existingUser) {
      throw new ConflictException('手机号已被注册');
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = this.userRepository.create({
      username: phone, // 使用手机号作为默认用户名
      password: hashedPassword,
      phone,
      role,
      verified: false, // 手机号注册后需要短信验证
    });

    return this.userRepository.save(user);
  }

  async verifyPhone(phone: string): Promise<User> {
    const user = await this.findByPhone(phone);
    if (!user) {
      throw new NotFoundException('用户不存在');
    }

    user.verified = true;
    return this.userRepository.save(user);
  }

  async updateLastLogin(userId: number): Promise<void> {
    await this.userRepository.update(userId, {
      lastLoginAt: new Date(),
    });
  }

  async updateRole(userId: number, role: UserRole): Promise<User> {
    await this.userRepository.update(userId, { role });
    return this.findOne(userId);
  }

  async update(id: number, updateData: Partial<User>): Promise<User> {
    if (typeof updateData.username === 'string') {
      await this.sensitiveWordService.assertNicknameAllowed(
        updateData.username,
      );
    }

    if (updateData.password) {
      updateData.password = await bcrypt.hash(updateData.password, 10);
    }
    await this.userRepository.update(id, updateData);
    return this.findOne(id);
  }

  /**
   * 管理员调整用户可用余额
   * 业务规则：仅调整 available balance，不影响 pending balance，并且必须记录钱包流水。
   */
  async adjustBalance(
    id: number,
    adjustUserBalanceDto: AdjustUserBalanceDto,
    adminId: number,
  ): Promise<User> {
    const { type, amount, remark } = adjustUserBalanceDto;
    const normalizedAmount = toNumber(amount);

    if (normalizedAmount <= 0) {
      throw new BadRequestException('调整金额必须大于 0');
    }

    await this.userRepository.manager.connection.transaction(async (manager) => {
      const user = await manager
        .createQueryBuilder(User, 'user')
        .where('user.id = :id', { id })
        .setLock('pessimistic_write')
        .getOne();

      if (!user) {
        throw new NotFoundException('用户不存在');
      }

      const oldBalance = toNumber(user.balance);
      const isIncrease = type === AdjustUserBalanceType.INCREASE;

      if (!isIncrease && oldBalance < normalizedAmount) {
        throw createBusinessException(
          ErrorCode.INSUFFICIENT_BALANCE,
          '余额不足',
        );
      }

      const newBalance = isIncrease
        ? add(oldBalance, normalizedAmount)
        : subtract(oldBalance, normalizedAmount);

      user.balance = newBalance;
      await manager.save(user);

      const walletTransaction = manager.create(WalletTransaction, {
        userId: user.id,
        type: isIncrease
          ? WalletTransactionType.INCOME
          : WalletTransactionType.EXPENSE,
        amount: normalizedAmount,
        balanceBefore: oldBalance,
        balanceAfter: newBalance,
        relatedType: RelatedType.ADJUSTMENT,
        relatedId: adminId,
        status: WalletTransactionStatus.APPROVED,
        remark:
          remark ||
          (isIncrease ? '管理员手动增加余额' : '管理员手动减少余额'),
        reviewedAt: new Date(),
        reviewedBy: adminId,
        autoProcessed: false,
      });

      await manager.save(WalletTransaction, walletTransaction);

      this.logger.log(
        `User balance adjusted: userId=${id}, adminId=${adminId}, type=${type}, amount=${normalizedAmount}, balance: ${oldBalance} -> ${newBalance}`,
      );
    });

    return this.findById(id);
  }

  /**
   * 获取用户钱包交易明细
   */
  async getUserWalletTransactions(userId: number, query: any) {
    const { page = 1, limit = 10, type, status } = query;

    // 动态导入 WalletTransaction 实体
    const { WalletTransaction } = await import('../shop/entities/wallet-transaction.entity');
    const { Repository } = require('typeorm');
    const dataSource = this.userRepository.manager.connection;

    const walletTransactionRepository: Repository<any> = dataSource.getRepository(WalletTransaction);

    const queryBuilder = walletTransactionRepository
      .createQueryBuilder('transaction')
      .where('transaction.userId = :userId', { userId })
      .orderBy('transaction.createdAt', 'DESC');

    // 类型筛选
    if (type) {
      queryBuilder.andWhere('transaction.type = :type', { type });
    }

    // 状态筛选
    if (status) {
      queryBuilder.andWhere('transaction.status = :status', { status });
    }

    // 分页
    queryBuilder.skip((page - 1) * limit).take(limit);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      total,
      page: Number(page),
      limit: Number(limit),
    };
  }

  /**
   * 删除用户（软删除）
   * 安全修复：检查关联数据，使用 isActive 标记而非物理删除
   * 如果用户有订单、钱包余额等重要数据，禁止删除
   */
  async remove(id: number): Promise<void> {
    // 1. 查找用户
    const user = await this.userRepository.findOne({
      where: { id },
    });

    if (!user) {
      throw new NotFoundException('用户不存在');
    }

    // 2. 检查钱包余额（有余额不能删除）
    if (Number(user.balance) > 0 || Number(user.pendingBalance) > 0) {
      throw new ConflictException(
        '用户有钱包余额，无法删除。请先处理余额后再试。',
      );
    }

    // 3. 检查是否有宠物
    const petCount = await this.petRepository.count({
      where: { ownerId: id },
    });

    if (petCount > 0) {
      throw new ConflictException(
        `用户有 ${petCount} 只宠物，无法删除。请先处理宠物数据。`,
      );
    }

    // 4. 检查是否有订单（动态加载 Order 实体）
    try {
      const dataSource = this.userRepository.manager.connection;
      const orderRepository = dataSource.getRepository('Order');
      const orderCount = await orderRepository.count({
        where: { userId: id },
      });

      if (orderCount > 0) {
        throw new ConflictException(
          `用户有 ${orderCount} 个订单，无法删除。建议使用禁用功能。`,
        );
      }
    } catch (error) {
      // 如果 Order 实体不存在或其他错误，跳过订单检查
      this.logger.warn(`Check orders failed: ${error.message}`);
    }

    // 5. 执行软删除（设置 isActive = false）
    await this.userRepository.update(id, {
      isActive: false,
      remarks: `${user.remarks || ''}\n[系统] 用户已于 ${new Date().toISOString()} 被删除`,
    });

    this.logger.log(`User soft deleted: id=${id}, phone=${user.phone}`);
  }

  /**
   * 用户自助注销账号。
   * 业务规则：订单等法定留存数据保留关联 ID，但会移除可直接识别用户的账号信息，并释放手机号用于重新注册。
   */
  async deleteOwnAccount(id: number): Promise<void> {
    const user = await this.userRepository.findOne({
      where: { id },
    });

    if (!user) {
      throw new NotFoundException('用户不存在');
    }

    if (!user.isActive) {
      return;
    }

    const deletedAt = new Date();
    const deletedToken = `deleted_${id}_${deletedAt.getTime()}`;

    await this.userRepository.update(id, {
      username: deletedToken,
      email: null,
      phone: deletedToken,
      avatar: null,
      gender: UserGender.UNKNOWN,
      verified: false,
      isActive: false,
      remarks: `${user.remarks || ''}\n[系统] 用户已于 ${deletedAt.toISOString()} 自助注销账号`,
    });

    this.logger.log(`User account deleted by owner: id=${id}`);
  }

  async validateUser(username: string, password: string): Promise<User | null> {
    const user = await this.findByUsername(username);
    if (user && (await bcrypt.compare(password, user.password))) {
      return user;
    }
    return null;
  }

  async validateUserByPhone(
    phone: string,
    password: string,
  ): Promise<User | null> {
    const user = await this.findByPhone(phone);
    if (user && (await bcrypt.compare(password, user.password))) {
      return user;
    }
    return null;
  }

  /**
   * 根据 ID 查找用户
   * @param id 用户 ID
   * @returns 用户信息
   * @throws NotFoundException 如果用户不存在
   */
  async findById(id: number): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id },
    });

    if (!user) {
      throw new NotFoundException(`用户 ID ${id} 不存在`);
    }

    return user;
  }

  /**
   * 根据手机号查询用户的宠物列表
   * @param phone 用户手机号
   * @returns 宠物列表
   */
  async getPetsByPhone(phone: string) {
    const user = await this.userRepository.findOne({
      where: { phone },
    });

    if (!user) {
      throw new NotFoundException('用户不存在');
    }

    const pets = await this.petRepository.find({
      where: { ownerId: user.id },
    });

    return pets.map((pet) => ({
      id: pet.id,
      name: pet.name,
      categoryId: pet.categoryId,
      subCategoryId: pet.subCategoryId,
      age: pet.birthDate
        ? Math.floor(
            (new Date().getTime() - new Date(pet.birthDate).getTime()) /
              (1000 * 60 * 60 * 24 * 365),
          )
        : 0,
      gender: pet.gender,
      avatar: pet.avatar,
      userId: user.id,
      userName: user.username,
    }));
  }

  /**
   * 获取医院员工列表
   * @param hospitalId 医院ID
   * @returns 员工列表（仅 STAFF 角色）
   */
  async getHospitalStaff(hospitalId: number) {
    // 查询指定医院的员工（仅 STAFF 角色）
    const staff = await this.userRepository.find({
      where: {
        hospitalId,
        role: UserRole.STAFF,
      },
      select: [
        'id',
        'username',
        'phone',
        'email',
        'role',
        'avatar',
        'gender',
        'isActive',
        'hospitalId',
        'createdAt',
      ],
      order: {
        createdAt: 'DESC',
      },
    });

    return staff;
  }
}
