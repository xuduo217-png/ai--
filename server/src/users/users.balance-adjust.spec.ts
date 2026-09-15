import { UsersService } from './users.service';
import { User } from './entities/user.entity';
import {
  RelatedType,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../shop/entities/wallet-transaction.entity';
import { ErrorCode } from '../common/constants/error-codes';
import { AdjustUserBalanceType } from './dto/adjust-user-balance.dto';

describe('UsersService.adjustBalance', () => {
  let service: UsersService;
  let currentUser: User;
  let savedWalletTransactions: Array<Record<string, any>>;

  const petRepository = {} as any;
  const sensitiveWordService = {
    assertNicknameAllowed: jest.fn(),
  } as any;

  const createLockedUserQuery = () => ({
    where: jest.fn().mockReturnThis(),
    setLock: jest.fn().mockReturnThis(),
    getOne: jest.fn(async () => currentUser),
  });

  const userRepository = {
    manager: {
      connection: {
        transaction: jest.fn(async (callback: (manager: any) => Promise<any>) => {
          const manager = {
            createQueryBuilder: jest.fn((entity: any) => {
              if (entity === User) {
                return createLockedUserQuery();
              }

              throw new Error(`Unexpected entity: ${entity?.name || entity}`);
            }),
            create: jest.fn((_entity: any, payload: Record<string, any>) => payload),
            save: jest.fn(async (_entity: any, payload?: Record<string, any>) => {
              const entityToSave = payload ?? _entity;

              if ('type' in entityToSave && 'relatedType' in entityToSave) {
                savedWalletTransactions.push(entityToSave);
                return entityToSave;
              }

              if ('balance' in entityToSave) {
                currentUser = {
                  ...currentUser,
                  ...entityToSave,
                };
                return currentUser;
              }

              return entityToSave;
            }),
          };

          return callback(manager);
        }),
      },
    },
  } as any;

  beforeEach(() => {
    currentUser = {
      id: 11,
      username: 'wallet-user',
      phone: '13800138000',
      balance: 50,
      pendingBalance: 0,
    } as User;
    savedWalletTransactions = [];
    service = new UsersService(
      userRepository,
      petRepository,
      sensitiveWordService,
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('increases available balance and writes an approved wallet income transaction', async () => {
    jest.spyOn(service, 'findById').mockResolvedValue({
      ...currentUser,
      balance: 80,
    } as User);

    const updatedUser = await service.adjustBalance(
        11,
        {
          type: AdjustUserBalanceType.INCREASE,
          amount: 30,
          remark: '后台补偿',
        },
      99,
    );

    expect(currentUser.balance).toBe(80);
    expect(savedWalletTransactions).toEqual([
      expect.objectContaining({
        userId: 11,
        type: WalletTransactionType.INCOME,
        amount: 30,
        balanceBefore: 50,
        balanceAfter: 80,
        relatedType: RelatedType.ADJUSTMENT,
        status: WalletTransactionStatus.APPROVED,
        reviewedBy: 99,
        remark: '后台补偿',
      }),
    ]);
    expect(updatedUser.balance).toBe(80);
  });

  it('rejects balance deduction when the available balance is insufficient', async () => {
    await expect(
      service.adjustBalance(
        11,
        {
          type: AdjustUserBalanceType.DECREASE,
          amount: 60,
          remark: '后台扣减',
        },
        99,
      ),
    ).rejects.toMatchObject({
      code: ErrorCode.INSUFFICIENT_BALANCE,
    });

    expect(currentUser.balance).toBe(50);
    expect(savedWalletTransactions).toHaveLength(0);
  });
});
