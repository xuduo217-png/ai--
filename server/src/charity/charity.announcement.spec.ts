import { DataSource, Repository } from 'typeorm';
import { CharityService } from './charity.service';
import { Charity } from './entities/charity.entity';
import {
  CharityDonationEntryType,
  CharityDonationSource,
  CharityRecord,
} from './entities/charity-record.entity';
import { CharityArticle } from './entities/charity-article.entity';
import { User } from '../users/entities/user.entity';
import { PaymentService } from '../payment/payment.service';

describe('首页公益公告', () => {
  function setup(
    records: Partial<CharityRecord>[] = [],
    users: Partial<User>[] = [],
  ) {
    const recordsQuery = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([records, records.length]),
    };
    const usersQuery = {
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue(users),
    };
    const userRepository = {
      createQueryBuilder: jest.fn().mockReturnValue(usersQuery),
    };
    const service = new CharityService(
      {} as Repository<Charity>,
      {
        createQueryBuilder: () => recordsQuery,
      } as unknown as Repository<CharityRecord>,
      {} as Repository<CharityArticle>,
      userRepository as unknown as Repository<User>,
      {} as DataSource,
      {} as PaymentService,
    );
    return { service, recordsQuery, usersQuery, userRepository };
  }

  it('匿名访问只返回展示所需信息，隐藏手机号并区分主动捐款和订单公益', async () => {
    const { service, usersQuery } = setup(
      [
        {
          id: 4,
          userId: 1,
          donationAmount: 20,
          donationSource: CharityDonationSource.MALL_ORDER,
        },
        { id: 3, userId: 2, donationAmount: 8.5 },
        { id: 2, userId: 3, donationAmount: 1 },
        { id: 1, userId: 4, donationAmount: 2 },
      ],
      [
        { id: 1, username: '  爱心用户  ' },
        { id: 2, username: '用户13800138000' },
        { id: 3, username: '', phone: '13900139000' },
      ],
    );

    const result = await service.getLatestDonationRecords();

    expect(result.data.map((item) => item.userName)).toEqual([
      '爱心用户',
      '用户138****8000',
      '爱心人士',
      '爱心人士',
    ]);
    expect(
      result.data.map(
        (item) => (item as Record<string, unknown>).donationSource,
      ),
    ).toEqual([
      CharityDonationSource.MALL_ORDER,
      CharityDonationSource.MANUAL,
      CharityDonationSource.MANUAL,
      CharityDonationSource.MANUAL,
    ]);
    expect(result.data.map((item) => item.donationAmount)).toEqual([
      20, 8.5, 1, 2,
    ]);
    expect(usersQuery.select).toHaveBeenCalledWith([
      'user.id',
      'user.username',
    ]);
    for (const item of result.data) {
      expect(item).not.toHaveProperty('userId');
      expect(item).not.toHaveProperty('phone');
    }
    expect(JSON.stringify(result)).not.toMatch(/13800138000|13900139000/);
  });

  it('查询最近 20 笔正向捐款，排除打卡、零金额和退款冲销', async () => {
    const { service, recordsQuery, userRepository } = setup();
    const result = await service.getLatestDonationRecords();

    expect(recordsQuery.where).toHaveBeenCalledWith(
      'record.taskType IN (:...taskTypes)',
      { taskTypes: ['donation', 'mall_order'] },
    );
    expect(recordsQuery.andWhere).toHaveBeenCalledWith(
      'record.donationAmount > 0',
    );
    expect(recordsQuery.andWhere).toHaveBeenCalledWith(
      'record.donationEntryType = :entryType',
      {
        entryType: CharityDonationEntryType.CREDIT,
      },
    );
    expect(recordsQuery.orderBy).toHaveBeenCalledWith(
      'record.checkInTime',
      'DESC',
    );
    expect(recordsQuery.addOrderBy).toHaveBeenCalledWith('record.id', 'DESC');
    expect(recordsQuery.take).toHaveBeenCalledWith(20);
    expect(userRepository.createQueryBuilder).not.toHaveBeenCalled();
    expect(result).toEqual({
      data: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
    });
  });
});
