import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Not, Repository } from 'typeorm';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { createBusinessException, ErrorCode } from '../common/constants/error-codes';
import { add, subtract, toNumber } from '../common/utils/currency.util';
import { Charity, CharityStatus, ParticipantType } from './entities/charity.entity';
import {
  CharityDonationEntryType,
  CharityDonationSource,
  CharityRecord,
} from './entities/charity-record.entity';
import { CharityArticle } from './entities/charity-article.entity';
import { CreateCharityDto } from './dto/create-charity.dto';
import { UpdateCharityDto } from './dto/update-charity.dto';
import { QueryCharityDto } from './dto/query-charity.dto';
import { CheckInDto } from './dto/check-in.dto';
import { CharityDonationPaymentMethod, DonateCharityDto } from './dto/donate-charity.dto';
import { PublishArticleDto } from './dto/publish-article.dto';
import { CreateCharityDonationPaymentDto } from './dto/create-charity-donation-payment.dto';
import { User } from '../users/entities/user.entity';
import {
  RelatedType,
  WalletTransaction,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../shop/entities/wallet-transaction.entity';
import { PaymentService } from '../payment/payment.service';
import {
  BusinessType,
  PaymentChannel,
  PaymentMethod,
} from '../payment/entities/payment.entity';

/**
 * 公益服务
 *
 * 处理用户运营公益的业务逻辑
 * - 公益管理（创建、编辑、删除）
 * - 签到打卡（每日限制一次）
 * - 公益状态自动更新
 * - 文章发布给参与者
 */
@Injectable()
export class CharityService {
  constructor(
    @InjectRepository(Charity)
    private charityRepository: Repository<Charity>,
    @InjectRepository(CharityRecord)
    private charityRecordRepository: Repository<CharityRecord>,
    @InjectRepository(CharityArticle)
    private charityArticleRepository: Repository<CharityArticle>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectDataSource()
    private dataSource: DataSource,
    private paymentService: PaymentService,
  ) {}

  // ==================== 公益管理 ====================

  /**
   * 创建公益
   */
  async create(createCharityDto: CreateCharityDto): Promise<Charity> {
    const payload = this.normalizeCharityPayload(createCharityDto);

    if (payload.isMallAutoDonation) {
      await this.ensureMallAutoDonationIsUnique();
    }

    // 验证开始时间不能晚于结束时间
    if (payload.startTime && payload.endTime) {
      if (payload.startTime >= payload.endTime) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '开始时间不能晚于或等于结束时间');
      }
    }

    const charity = this.charityRepository.create(payload);

    // 如果设置了开始时间且开始时间在未来，状态设为草稿
    if (charity.startTime && charity.startTime > new Date()) {
      charity.status = CharityStatus.DRAFT;
    }

    return await this.charityRepository.save(charity);
  }

  /**
   * 获取公益列表（管理员）
   */
  async findAll(queryDto: QueryCharityDto): Promise<PaginatedResult<Charity>> {
    const { page = 1, pageSize = 10, status, keyword, deleteStatus = 'active' } = queryDto;
    const query = this.charityRepository.createQueryBuilder('charity');

    if (deleteStatus === 'deleted') {
      query.withDeleted().andWhere('charity.deletedAt IS NOT NULL');
    } else if (deleteStatus === 'all') {
      query.withDeleted();
    }

    // 状态筛选
    if (status) {
      query.andWhere('charity.status = :status', { status });
    }

    // 关键词搜索
    if (keyword) {
      query.andWhere('charity.title LIKE :keyword', { keyword: `%${keyword}%` });
    }

    query.orderBy('charity.isPinned', 'DESC').addOrderBy('charity.createdAt', 'DESC');

    const [data, total] = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    // 为每条公益添加参与人数和检查公益状态
    for (const charity of data) {
      // 获取参与人数（去重后的用户数）
      const participants = await this.charityRecordRepository
        .createQueryBuilder('record')
        .select('DISTINCT record.userId', 'userId')
        .where('record.charityId = :charityId', { charityId: charity.id })
        .getRawMany();
      charity.participantCount = participants.length;

      if (this.isDonationCharity(charity)) {
        charity.donatedAmount = await this.getDonationAmount(charity.id);
      }

      // 检查公益状态：进行中且未删除的公益检查是否应该结束
      if (!charity.deletedAt) {
        await this.checkAndUpdateCharityStatus(charity);
      }
    }

    // 自动更新过期公益状态
    await this.updateExpiredActivities(data.filter((charity) => !charity.deletedAt));

    return {
      data,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取公益列表（用户端）
   * 自动更新公益状态，并追加用户打卡信息
   * 检查签到打卡类型的公益是否达到目标并自动完成
   */
  async findUserActivities(queryDto: QueryCharityDto, userId?: number): Promise<PaginatedResult<Charity>> {
    const { page = 1, pageSize = 10, status, keyword } = queryDto;
    const query = this.charityRepository
      .createQueryBuilder('charity')
      .where('charity.deletedAt IS NULL');

    // 用户端默认只显示进行中和已结束的公益，不显示草稿
    if (status && status !== CharityStatus.DRAFT) {
      query.andWhere('charity.status = :status', { status });
    } else if (!status) {
      query.andWhere('charity.status IN (:...statuses)', { statuses: [CharityStatus.ACTIVE, CharityStatus.EXPIRED] });
    }

    // 关键词搜索
    if (keyword) {
      query.andWhere('charity.title LIKE :keyword', { keyword: `%${keyword}%` });
    }

    query.orderBy('charity.isPinned', 'DESC').addOrderBy('charity.createdAt', 'DESC');

    const [data, total] = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getManyAndCount();

    // 检查公益状态并更新
    for (const charity of data) {
      await this.checkAndUpdateCharityStatus(charity);
    }

    // 自动更新过期公益状态
    await this.updateExpiredActivities(data);

    // 如果有 userId，追加用户打卡信息
    for (const charity of data) {
      if (this.isDonationCharity(charity)) {
        charity.donatedAmount = await this.getDonationAmount(charity.id);
        continue;
      }

      if (userId) {
        const userCheckIns = await this.charityRecordRepository.count({
          where: { charityId: charity.id, userId },
        });

        const today = new Date().toISOString().split('T')[0];
        const checkedToday = await this.charityRecordRepository.findOne({
          where: { charityId: charity.id, userId, checkInDate: today },
        });

        // 动态添加用户打卡信息（虚拟字段，不保存到数据库）
        charity.userCheckInCount = userCheckIns;
        charity.hasCheckedToday = !!checkedToday;
      }
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
   * 获取公益详情
   */
  async findOne(id: number, userId?: number): Promise<Charity> {
    const charity = await this.charityRepository.findOne({
      where: { id },
    });

    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    // 检查并更新公益状态
    await this.checkAndUpdateCharityStatus(charity);

    if (this.isDonationCharity(charity)) {
      charity.donatedAmount = await this.getDonationAmount(charity.id);
      return charity;
    }

    // 如果有 userId，追加用户打卡信息
    if (userId) {
      const userCheckIns = await this.charityRecordRepository.count({
        where: { charityId: charity.id, userId },
      });

      const today = new Date().toISOString().split('T')[0];
      const checkedToday = await this.charityRecordRepository.findOne({
        where: { charityId: charity.id, userId, checkInDate: today },
      });

      // 动态添加用户打卡信息（虚拟字段，不保存到数据库）
      charity.userCheckInCount = userCheckIns;
      charity.hasCheckedToday = !!checkedToday;
    }

    return charity;
  }

  /**
   * 更新公益
   */
  async update(id: number, updateCharityDto: UpdateCharityDto): Promise<Charity> {
    const charity = await this.charityRepository.findOne({ where: { id } });

    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    const payload = this.normalizeCharityPayload(updateCharityDto, charity);
    if (payload.isMallAutoDonation) {
      await this.ensureMallAutoDonationIsUnique(id);
    }

    // 验证开始时间不能晚于结束时间
    const startTime = payload.startTime === undefined ? charity.startTime : payload.startTime;
    const endTime = payload.endTime === undefined ? charity.endTime : payload.endTime;

    if (startTime && endTime && startTime >= endTime) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '开始时间不能晚于或等于结束时间');
    }

    Object.assign(charity, payload);

    return await this.charityRepository.save(charity);
  }

  /**
   * 删除公益
   */
  async remove(id: number): Promise<void> {
    const charity = await this.charityRepository.findOne({ where: { id } });

    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    await this.charityRepository.softDelete(id);
  }

  // ==================== 签到打卡 ====================

  /**
   * 签到打卡
   */
  async checkIn(userId: number, charityId: number, checkInDto: CheckInDto) {
    // 1. 检查公益是否存在
    const charity = await this.charityRepository.findOne({ where: { id: charityId } });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (this.isMallAutoDonation(charity)) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '商城自动公益由订单自动生成，不支持主动捐款');
    }
    if (this.isDonationCharity(charity)) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '捐款类型公益不支持打卡');
    }

    // 2. 检查公益状态
    if (charity.status !== CharityStatus.ACTIVE) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_ACTIVE);
    }

    // 3. 检查公益是否过期
    if (!this.isMallAutoDonation(charity) && charity.endTime && new Date() > charity.endTime) {
      charity.status = CharityStatus.EXPIRED;
      await this.charityRepository.save(charity);
      throw createBusinessException(ErrorCode.CHARITY_EXPIRED);
    }

    // 4. 检查今日是否已打卡（每日限制一次）
    const today = new Date().toISOString().split('T')[0];
    const existingRecord = await this.charityRecordRepository.findOne({
      where: { charityId, userId, checkInDate: today },
    });

    if (existingRecord) {
      // 4.1 今日已打卡，返回用户总打卡次数（不抛出异常）
      const totalCheckIns = await this.charityRecordRepository.count({
        where: { charityId, userId },
      });

      return {
        success: false,
        alreadyChecked: true,
        totalCheckIns,
        message: '您今天已经打过卡了，明天再来吧！',
        isCompleted: totalCheckIns >= (charity.targetCheckIns || 0),
      };
    }

    // 5. 创建打卡记录
    const record = this.charityRecordRepository.create({
      charityId,
      userId,
      checkInDate: today,
      checkInTime: new Date(),
      taskType: checkInDto.taskType || 'checkin',
      taskEvidence: checkInDto.taskEvidence,
    });
    await this.charityRecordRepository.save(record);

    // 6. 更新公益的已完成打卡次数
    charity.completedCheckIns = (charity.completedCheckIns || 0) + 1;
    await this.charityRepository.save(charity);

    // 7. 检查是否达到目标打卡次数，如果达到则将公益状态设为已结束
    const targetCheckIns = charity.targetCheckIns || 0; // 处理 NULL 情况
    if (targetCheckIns > 0 && charity.completedCheckIns >= targetCheckIns) {
      charity.status = CharityStatus.EXPIRED;
      await this.charityRepository.save(charity);
    }

    // 8. 获取用户总打卡次数
    const totalCheckIns = await this.charityRecordRepository.count({
      where: { charityId, userId },
    });

    return {
      success: true,
      totalCheckIns,
      message: targetCheckIns > 0 && charity.completedCheckIns >= targetCheckIns ? '恭喜完成目标！' : '签到成功',
      isCompleted: targetCheckIns > 0 && totalCheckIns >= targetCheckIns,
    };
  }

  /**
   * 爱心捐款（当前仅支持余额支付）
   */
  async donate(userId: number, charityId: number, donateCharityDto: DonateCharityDto) {
    const charity = await this.requireActiveDonationCharity(charityId);

    const normalizedAmount = toNumber(donateCharityDto.amount);
    if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '捐款金额必须大于0');
    }

    if (
      donateCharityDto.paymentMethod &&
      donateCharityDto.paymentMethod !== CharityDonationPaymentMethod.BALANCE
    ) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '微信/支付宝支付暂未开放，请使用余额支付');
    }

    const currentDonatedAmount = await this.getDonationAmount(charityId);

    return await this.dataSource.transaction(async (manager) => {
      const user = await manager
        .createQueryBuilder(User, 'user')
        .where('user.id = :id', { id: userId })
        .setLock('pessimistic_write')
        .getOne();

      if (!user) {
        throw createBusinessException(ErrorCode.USER_NOT_FOUND);
      }

      const oldBalance = toNumber(user.balance);
      if (oldBalance < normalizedAmount) {
        throw createBusinessException(ErrorCode.INSUFFICIENT_BALANCE, '余额不足');
      }

      const newBalance = subtract(oldBalance, normalizedAmount);
      const paidAt = new Date();

      user.balance = newBalance;
      await manager.save(user);

      const donationRecord = manager.create(CharityRecord, {
        charityId,
        userId,
        checkInDate: null,
        checkInTime: paidAt,
        taskType: 'donation',
        donationAmount: normalizedAmount,
      });
      await manager.save(donationRecord);

      const walletTransaction = manager.create(WalletTransaction, {
        userId,
        type: WalletTransactionType.EXPENSE,
        amount: normalizedAmount,
        balanceBefore: oldBalance,
        balanceAfter: newBalance,
        relatedType: RelatedType.CHARITY,
        relatedId: charityId,
        status: WalletTransactionStatus.APPROVED,
        remark: `公益捐款：${charity.title}`,
        reviewedAt: paidAt,
        reviewedBy: userId,
        autoProcessed: false,
      });
      await manager.save(walletTransaction);

      return {
        success: true,
        message: '捐款成功',
        donationAmount: normalizedAmount,
        donatedAmount: add(currentDonatedAmount, normalizedAmount),
        balanceBefore: oldBalance,
        balanceAfter: newBalance,
      };
    });
  }

  /**
   * 创建支付宝公益捐款支付单。支付到账由 PaymentService 在回调事务中落公益记录。
   */
  async createDonationPayment(
    userId: number,
    charityId: number,
    idempotencyKey: string,
    body: CreateCharityDonationPaymentDto,
  ) {
    const charity = await this.requireActiveDonationCharity(charityId);
    const amount = toNumber(body.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '捐款金额必须大于0');
    }

    return await this.paymentService.createPayment({
      channel: PaymentChannel.ALIPAY,
      method: PaymentMethod.APP,
      amount,
      userId,
      businessType: BusinessType.CHARITY_DONATION,
      businessId: charity.id,
      subject: `公益捐款 - ${charity.title}`,
      body: `向“${charity.title}”捐款 ¥${amount.toFixed(2)}`,
      description: `公益捐款：${charity.title}`,
      expireIn: 900,
      metadata: { charityId: charity.id, idempotencyKey },
      outTradeNo: `charity_${userId}_${charity.id}_${idempotencyKey.replace(/-/g, '')}`,
    });
  }

  /**
   * 获取用户的打卡记录
   */
  async getUserRecords(charityId: number, userId: number, page: number = 1, pageSize: number = 10) {
    // 验证公益是否存在
    const charity = await this.charityRepository.findOne({ where: { id: charityId } });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (this.isDonationCharity(charity)) {
      return {
        data: [],
        total: 0,
        page,
        pageSize,
        totalPages: 0,
      };
    }

    const query = this.charityRecordRepository.createQueryBuilder('record')
      .where('record.charityId = :charityId', { charityId })
      .andWhere('record.userId = :userId', { userId })
      .orderBy('record.checkInTime', 'DESC');

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
   * 获取公益捐款明细
   */
  async getDonationRecords(charityId: number, page: number = 1, pageSize: number = 10) {
    const charity = await this.charityRepository.findOne({ where: { id: charityId } });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (!this.isDonationCharity(charity)) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '打卡类型公益不支持捐款明细');
    }

    const query = this.charityRecordRepository
      .createQueryBuilder('record')
      .where('record.charityId = :charityId', { charityId })
      .orderBy('record.checkInTime', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [data, total] = await query.getManyAndCount();

    const userIds = Array.from(
      new Set(
        data
          .map((item: any) => Number(item.userId))
          .filter((value) => Number.isFinite(value) && value > 0),
      ),
    );

    let users: User[] = [];
    if (userIds.length > 0) {
      users = await this.userRepository
        .createQueryBuilder('user')
        .select(['user.id', 'user.username', 'user.avatar'])
        .where('user.id IN (:...userIds)', { userIds })
        .getMany();
    }

    const userMap = new Map<number, { userName: string; userAvatar: string | null }>();
    users.forEach((user: User) => {
      userMap.set(user.id, {
        userName: user.username,
        userAvatar: user.avatar || null,
      });
    });

    return {
      data: data.map((item: any) => {
        const userInfo = userMap.get(Number(item.userId)) || {
          userName: '-',
          userAvatar: null,
        };

        return {
          id: item.id,
          charityId: item.charityId,
          userId: item.userId,
          userName: userInfo.userName,
          userAvatar: userInfo.userAvatar,
          checkInDate: item.checkInDate ?? null,
          checkInTime: item.checkInTime,
          donationAmount: toNumber(item.donationAmount),
          donationSource: item.donationSource || CharityDonationSource.MANUAL,
          donationEntryType: item.donationEntryType || CharityDonationEntryType.CREDIT,
          orderId: item.orderId ?? null,
          orderNo: item.orderNo ?? null,
          donationBaseAmount: item.donationBaseAmount == null ? null : toNumber(item.donationBaseAmount),
          donationRate: item.donationRate == null ? null : toNumber(item.donationRate),
          sourceReference: item.sourceReference ?? null,
          createdAt: item.createdAt,
        };
      }),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 获取首页公告使用的最新捐赠记录
   * 不按公益项目过滤，只返回最近 20 笔正向捐赠流水。
   */
  async getLatestDonationRecords() {
    const pageSize = 20;
    const query = this.charityRecordRepository
      .createQueryBuilder('record')
      .where('record.taskType IN (:...taskTypes)', {
        taskTypes: ['donation', 'mall_order'],
      })
      .andWhere('record.donationAmount > 0')
      .andWhere('record.donationEntryType = :entryType', {
        entryType: CharityDonationEntryType.CREDIT,
      })
      .orderBy('record.checkInTime', 'DESC')
      .addOrderBy('record.id', 'DESC')
      .take(pageSize);

    const [data, total] = await query.getManyAndCount();
    const userIds = Array.from(
      new Set(
        data
          .map((item: CharityRecord) => Number(item.userId))
          .filter((value) => Number.isFinite(value) && value > 0),
      ),
    );

    let users: User[] = [];
    if (userIds.length > 0) {
      users = await this.userRepository
        .createQueryBuilder('user')
        .select(['user.id', 'user.username'])
        .where('user.id IN (:...userIds)', { userIds })
        .getMany();
    }

    const userMap = new Map<number, string>();
    users.forEach((user) => {
      // 公告允许匿名访问，不以手机号兜底；昵称中的手机号也需脱敏。
      const displayName = (user.username || '')
        .replace(/\s+/g, ' ')
        .trim()
        .replace(/(1[3-9]\d)\d{4}(\d{4})/g, '$1****$2');
      userMap.set(user.id, displayName || '爱心人士');
    });

    return {
      data: data.map((item: CharityRecord) => ({
        id: item.id,
        charityId: item.charityId,
        userName: userMap.get(Number(item.userId)) || '爱心人士',
        checkInTime: item.checkInTime,
        donationAmount: toNumber(item.donationAmount),
        donationSource: item.donationSource || CharityDonationSource.MANUAL,
        createdAt: item.createdAt,
      })),
      total,
      page: 1,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  // ==================== 文章发布 ====================

  /**
   * 发布文章给公益参与者
   * 规则：
   * 1. 公益必须已结束（状态为 EXPIRED）
   * 2. 每个公益只能发布一篇文章
   */
  async publishArticle(charityId: number, publishArticleDto: PublishArticleDto, publisherId: number) {
    // 1. 检查公益是否存在
    const charity = await this.charityRepository.findOne({ where: { id: charityId } });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (this.isDonationCharity(charity)) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '捐款类型公益不支持发布文章');
    }

    // 2. 检查公益状态：只有已结束的公益才能发布文章
    // 先更新公益状态（确保结束的公益被标记为 EXPIRED）
    if (charity.endTime && new Date() > charity.endTime) {
      charity.status = CharityStatus.EXPIRED;
      await this.charityRepository.save(charity);
    }

    if (charity.status !== CharityStatus.EXPIRED) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '只有已结束的公益才能发布文章');
    }

    // 3. 检查该公益是否已发布过文章
    const existingArticle = await this.charityArticleRepository.findOne({
      where: { charityId, isPublished: true },
    });

    if (existingArticle) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '该公益已发布过文章，请编辑已有文章');
    }

    // 4. 获取所有参与者用户 ID
    const participantIds = await this.charityRecordRepository
      .createQueryBuilder('record')
      .select('DISTINCT record.userId', 'userId')
      .where('record.charityId = :charityId', { charityId })
      .getRawMany();

    if (participantIds.length === 0) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '该公益暂无参与者');
    }

    const userIds = participantIds.map((p: any) => p.userId);

    // 5. 创建公益文章
    const article = this.charityArticleRepository.create({
      charityId,
      title: publishArticleDto.title,
      content: publishArticleDto.content,
      publisherId,
      targetUserIds: publishArticleDto.targetUserIds || userIds,
      sendNotification: publishArticleDto.sendNotification ?? true,
      isPublished: true,
    });
    await this.charityArticleRepository.save(article);

    // 6. TODO: 如果需要发送通知，触发推送通知逻辑
    // if (article.sendNotification) {
    //   await this.notificationService.sendToUsers(article.targetUserIds, {
    //     title: '公益文章发布',
    //     body: article.title,
    //     data: { articleId: article.id, charityId },
    //   });
    // }

    return {
      success: true,
      articleId: article.id,
      message: '文章发布成功',
    };
  }

  /**
   * 更新公益文章
   * 规则：只能编辑已发布的文章
   */
  async updateArticle(
    charityId: number,
    articleId: number,
    updateData: { title?: string; content?: string; sendNotification?: boolean },
    publisherId: number,
  ) {
    const charity = await this.charityRepository.findOne({ where: { id: charityId } });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (this.isDonationCharity(charity)) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '捐款类型公益不支持文章功能');
    }

    // 1. 检查文章是否存在
    const article = await this.charityArticleRepository.findOne({ where: { id: articleId, charityId } });
    if (!article) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '文章不存在');
    }

    // 2. 检查文章是否已发布
    if (!article.isPublished) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '只能编辑已发布的文章');
    }

    // 3. 更新文章
    if (updateData.title !== undefined) {
      article.title = updateData.title;
    }
    if (updateData.content !== undefined) {
      article.content = updateData.content;
    }
    if (updateData.sendNotification !== undefined) {
      article.sendNotification = updateData.sendNotification;
    }

    await this.charityArticleRepository.save(article);

    return {
      success: true,
      message: '文章更新成功',
    };
  }

  /**
   * 获取公益已发布的文章（用于编辑）
   * 返回文章对象或 null（没有文章时）
   */
  async getPublishedArticle(charityId: number) {
    // 1. 检查公益是否存在
    const charity = await this.charityRepository.findOne({ where: { id: charityId } });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (this.isDonationCharity(charity)) {
      return null;
    }

    // 2. 获取已发布的文章（没有找到时返回 null，而不是抛出异常）
    const article = await this.charityArticleRepository.findOne({
      where: { charityId, isPublished: true },
    });

    return article || null;
  }

  /**
   * 获取公益文章列表（管理员）
   * 返回该公益下全部已发布文章，不按当前登录用户过滤
   */
  async getAdminArticles(charityId: number): Promise<CharityArticle[]> {
    return await this.getArticles(charityId, undefined, true);
  }

  /**
   * 获取公益文章列表
   */
  async getArticles(
    charityId: number,
    userId?: number,
    includeDeleted: boolean = false,
  ): Promise<CharityArticle[]> {
    // 验证公益是否存在
    const charity = await this.charityRepository.findOne({
      where: { id: charityId },
      withDeleted: includeDeleted,
    });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (this.isDonationCharity(charity)) {
      return [];
    }

    const query = this.charityArticleRepository.createQueryBuilder('article')
      .where('article.charityId = :charityId', { charityId })
      .andWhere('article.isPublished = :isPublished', { isPublished: true })
      .orderBy('article.createdAt', 'DESC');

    // 如果有 userId，只返回推送给该用户的文章或推送给所有人的文章
    if (userId) {
      query.andWhere('(article.targetUserIds IS NULL OR JSON_CONTAINS(article.targetUserIds, :userId))', {
        userId: JSON.stringify(userId),
      });
    }

    return await query.getMany();
  }

  // ==================== 统计数据 ====================

  /**
   * 获取公益统计数据
   */
  async getStats(charityId: number) {
    // 验证公益是否存在
    const charity = await this.charityRepository.findOne({ where: { id: charityId } });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    // 总参与人数（去重）
    const totalParticipants = await this.charityRecordRepository
      .createQueryBuilder('record')
      .select('DISTINCT record.userId', 'userId')
      .where('record.charityId = :charityId', { charityId })
      .getRawMany();

    if (this.isDonationCharity(charity)) {
      const donatedAmount = await this.getDonationAmount(charityId);
      return {
        charityId: charity.id,
        charityTitle: charity.title,
        participantType: '爱心捐款',
        participantCount: totalParticipants.length,
        donatedAmount,
        targetCheckIns: 0,
        totalCheckIns: 0,
        completedCount: 0,
        completionRate: 0,
        averageCheckIns: 0,
      };
    }

    // 总打卡次数
    const totalCheckIns = await this.charityRecordRepository.count({
      where: { charityId },
    });

    // 完成目标的人数
    const targetCheckIns = charity.targetCheckIns || 0; // 处理 NULL 情况
    const completedUsers = targetCheckIns > 0 ? await this.charityRecordRepository
      .createQueryBuilder('record')
      .select('record.userId', 'userId')
      .addSelect('COUNT(record.id)', 'checkInCount')
      .where('record.charityId = :charityId', { charityId })
      .groupBy('record.userId')
      .having('checkInCount >= :targetCheckIns', { targetCheckIns })
      .getRawMany() : [];

    // 计算平均签到次数
    const averageCheckIns = totalParticipants.length > 0
      ? totalCheckIns / totalParticipants.length
      : 0;

    // 参与类型文本
    const participantTypeMap = {
      checkin: '签到打卡',
      task: '任务完成',
      donation: '爱心捐款',
    };

    return {
      charityId: charity.id,
      charityTitle: charity.title,
      participantType: participantTypeMap[charity.participantType] || charity.participantType,
      participantCount: totalParticipants.length,
      targetCheckIns: targetCheckIns, // 使用处理过的值
      totalCheckIns,
      completedCount: completedUsers.length,
      completionRate: totalParticipants.length > 0
        ? (completedUsers.length / totalParticipants.length) * 100
        : 0,
      averageCheckIns,
    };
  }

  /**
   * 获取参与者列表（分页）
   */
  async getParticipants(charityId: number, page: number = 1, pageSize: number = 10) {
    // 验证公益是否存在
    const charity = await this.charityRepository.findOne({
      where: { id: charityId },
      withDeleted: true,
    });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }

    if (this.isDonationCharity(charity)) {
      return await this.getDonationRecords(charityId, page, pageSize);
    }

    // 查询每个用户的首次和最后一次签到时间
    const query = this.charityRecordRepository
      .createQueryBuilder('record')
      .select('record.userId', 'userId')
      .addSelect('COUNT(record.id)', 'checkInCount')
      .addSelect('MIN(record.checkInTime)', 'firstCheckInTime')
      .addSelect('MAX(record.checkInTime)', 'lastCheckInTime')
      .where('record.charityId = :charityId', { charityId })
      .groupBy('record.userId')
      .orderBy('checkInCount', 'DESC')
      .addOrderBy('lastCheckInTime', 'DESC');

    // 先获取总数（不能使用 getRawMany 获取总数，需要单独查询）
    const countQuery = this.charityRecordRepository
      .createQueryBuilder('record')
      .select('DISTINCT record.userId', 'userId')
      .where('record.charityId = :charityId', { charityId });

    const countResult = await countQuery.getRawMany();
    const total = countResult.length;

    // 获取分页数据
    const data = await query
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getRawMany();

    // 获取所有用户ID
    const userIds = data.map((item: any) => item.userId);

    // 查询用户信息（如果有用户ID）
    let users: User[] = [];
    if (userIds.length > 0) {
      users = await this.userRepository
        .createQueryBuilder('user')
        .select(['user.id', 'user.username', 'user.avatar'])
        .where('user.id IN (:...userIds)', { userIds })
        .getMany();
    }

    // 创建用户信息映射
    const userMap = new Map();
    users.forEach((user: User) => {
      userMap.set(user.id, {
        userName: user.username,
        userAvatar: user.avatar
      });
    });

    return {
      data: data.map((item: any) => {
        const userInfo = userMap.get(item.userId) || { userName: '-', userAvatar: null };
        return {
          userId: item.userId,
          userName: userInfo.userName,
          userAvatar: userInfo.userAvatar,
          checkInCount: parseInt(item.checkInCount) || 0,
          firstCheckInTime: item.firstCheckInTime,
          lastCheckInTime: item.lastCheckInTime,
        };
      }),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  // ==================== 内部辅助方法 ====================

  private async requireActiveDonationCharity(charityId: number): Promise<Charity> {
    const charity = await this.charityRepository.findOne({
      where: { id: charityId },
    });
    if (!charity) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_FOUND);
    }
    if (!this.isDonationCharity(charity)) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '打卡类型公益不支持捐款');
    }
    if (this.isMallAutoDonation(charity)) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '商城自动公益由订单自动生成，不支持主动捐款');
    }

    await this.checkAndUpdateCharityStatus(charity);
    if (charity.endTime && new Date() > charity.endTime) {
      throw createBusinessException(ErrorCode.CHARITY_EXPIRED);
    }
    if (charity.status !== CharityStatus.ACTIVE) {
      throw createBusinessException(ErrorCode.CHARITY_NOT_ACTIVE);
    }
    return charity;
  }

  /**
   * 检查并更新公益状态（内部方法）
   * 规则：
   * 1. 如果是进行中的公益，检查截止时间是否已过
   * 2. 如果是进行中的公益，检查已完成打卡次数是否达到目标
   * 3. 如果满足上述任一条件，将公益状态更新为已结束
   */
  private async checkAndUpdateCharityStatus(charity: Charity): Promise<void> {
    // 只有进行中的公益才需要检查
    if (charity.status !== CharityStatus.ACTIVE) {
      return;
    }

    let shouldUpdate = false;

    // 检查截止时间是否已过
    if (!this.isMallAutoDonation(charity) && charity.endTime && new Date() > charity.endTime) {
      shouldUpdate = true;
    }

    // 检查已完成打卡次数是否达到目标
    const targetCheckIns = charity.targetCheckIns || 0; // 处理 NULL 情况
    if (!this.isDonationCharity(charity) && targetCheckIns > 0 && charity.completedCheckIns >= targetCheckIns) {
      shouldUpdate = true;
    }

    // 更新公益状态
    if (shouldUpdate) {
      charity.status = CharityStatus.EXPIRED;
      await this.charityRepository.save(charity);
    }
  }

  /**
   * 自动更新过期公益状态（内部方法）
   */
  private async updateExpiredActivities(activities: Charity[]): Promise<void> {
    const now = new Date();
    for (const charity of activities) {
      if (
        !this.isMallAutoDonation(charity) &&
        charity.endTime &&
        now > charity.endTime &&
        charity.status === CharityStatus.ACTIVE
      ) {
        charity.status = CharityStatus.EXPIRED;
        await this.charityRepository.save(charity);
      }
    }
  }

  private normalizeCharityPayload(
    payload: CreateCharityDto | UpdateCharityDto,
    existingCharity?: Charity,
  ): CreateCharityDto | UpdateCharityDto {
    const resolvedParticipantType = payload.participantType || existingCharity?.participantType || ParticipantType.CHECKIN;
    const normalizedPayload: CreateCharityDto | UpdateCharityDto = {
      ...payload,
      participantType: resolvedParticipantType,
    };

    const isMallAutoDonation = payload.isMallAutoDonation ?? existingCharity?.isMallAutoDonation ?? false;
    normalizedPayload.isMallAutoDonation = isMallAutoDonation;
    normalizedPayload.isPinned = isMallAutoDonation
      ? true
      : payload.isPinned ?? existingCharity?.isPinned ?? false;

    if (isMallAutoDonation) {
      if (resolvedParticipantType !== ParticipantType.DONATION) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '商城自动公益必须选择捐款类型');
      }
      const donationRate = Number(payload.donationRate ?? existingCharity?.donationRate ?? 0);
      if (!Number.isFinite(donationRate) || donationRate <= 0 || donationRate > 100) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '商城自动公益比例必须在 0 到 100 之间');
      }
      normalizedPayload.donationRate = donationRate;
      normalizedPayload.startTime = null;
      normalizedPayload.endTime = null;
    } else if (payload.donationRate !== undefined) {
      const donationRate = Number(payload.donationRate);
      if (!Number.isFinite(donationRate) || donationRate < 0 || donationRate > 100) {
        throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '公益比例必须在 0 到 100 之间');
      }
      normalizedPayload.donationRate = donationRate;
    }

    if (resolvedParticipantType === ParticipantType.DONATION) {
      normalizedPayload.targetCheckIns = 0;
      if ('completedCheckIns' in (existingCharity || {})) {
        (normalizedPayload as any).completedCheckIns = 0;
      }
      return normalizedPayload;
    }

    const targetCheckIns = payload.targetCheckIns ?? existingCharity?.targetCheckIns ?? 0;
    if (targetCheckIns < 1) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '打卡类型公益必须填写目标打卡天数');
    }

    normalizedPayload.targetCheckIns = targetCheckIns;
    return normalizedPayload;
  }

  private isDonationCharity(charity: Pick<Charity, 'participantType'>): boolean {
    return charity.participantType === ParticipantType.DONATION;
  }

  private isMallAutoDonation(charity: Pick<Charity, 'isMallAutoDonation'>): boolean {
    return Boolean(charity.isMallAutoDonation);
  }

  private async ensureMallAutoDonationIsUnique(excludeId?: number): Promise<void> {
    const existing = await this.charityRepository.findOne({
      where: {
        isMallAutoDonation: true,
        ...(excludeId === undefined ? {} : { id: Not(excludeId) }),
      },
      select: { id: true },
    });

    if (existing) {
      throw createBusinessException(ErrorCode.BUSINESS_INVALID_PARAM, '商城公益活动只能有一个，请编辑现有活动');
    }
  }

  private async getDonationAmount(charityId: number): Promise<number> {
    const result = await this.charityRecordRepository
      .createQueryBuilder('record')
      .select('COALESCE(SUM(record.donationAmount), 0)', 'donatedAmount')
      .where('record.charityId = :charityId', { charityId })
      .getRawOne();

    return Number(result?.donatedAmount || 0);
  }
}
