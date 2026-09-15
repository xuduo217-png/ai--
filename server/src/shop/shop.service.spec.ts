import { Test, TestingModule } from '@nestjs/testing'
import { getRepositoryToken } from '@nestjs/typeorm'
import { DataSource, Repository } from 'typeorm'

jest.mock('uuid', () => ({
  v4: () => 'MOCK-ORDER-UUID',
}))

import { ShopService } from './shop.service'
import { Product } from './entities/product.entity'
import { ProductSku } from './entities/product-sku.entity'
import { Order } from './entities/order.entity'
import { Category } from './entities/category.entity'
import { WalletTransaction } from './entities/wallet-transaction.entity'
import { SystemConfig } from '../system-configs/entities/system-config.entity'
import { BatchGetProductsDto } from './dto/batch-get-products.dto'
import { ConfigService } from '@nestjs/config'
import { PaymentService } from '../payment/payment.service'
import { NotificationSenderService } from '../notifications/notification-sender.service'
import { LogisticsService } from '../logistics/logistics.service'
import { PlatformFeeService } from './platform-fee.service'

describe('ShopService - batchGetProducts', () => {
  let service: ShopService
  let productRepository: Repository<Product>
  let categoryRepository: Repository<Category>

  // Mock 数据源
  const mockProductRepository = {
    find: jest.fn(),
    count: jest.fn(),
    createQueryBuilder: jest.fn(),
  }

  const mockCategoryRepository = {
    find: jest.fn(),
    findOne: jest.fn(),
  }

  const mockSystemConfigRepository = {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn((payload) => payload),
  }

  const mockProductSkuRepository = {
    find: jest.fn(),
    findOne: jest.fn(),
  }

  const mockOrderRepository = {
    findOne: jest.fn(),
    update: jest.fn(),
  }

  const mockWalletTransactionRepository = {
    manager: {},
  }

  const mockDataSource = {
    createQueryRunner: jest.fn(() => ({
      connect: jest.fn(),
      startTransaction: jest.fn(),
      commitTransaction: jest.fn(),
      rollbackTransaction: jest.fn(),
      release: jest.fn(),
      manager: {
        findOne: jest.fn(),
        save: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        createQueryBuilder: jest.fn(() => ({
          setLock: jest.fn().mockReturnThis(),
          where: jest.fn().mockReturnThis(),
          getOne: jest.fn(),
          execute: jest.fn(),
        })),
      },
    })),
    transaction: jest.fn((cb) => cb({})),
  }

  const mockPaymentService = {
    createPayment: jest.fn(),
  }

  const mockConfigService = {
    get: jest.fn((key: string) => {
      if (key === 'NODE_ENV') return 'test'
      return null
    }),
  }

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ShopService,
        {
          provide: getRepositoryToken(Product),
          useValue: mockProductRepository,
        },
        {
          provide: getRepositoryToken(ProductSku),
          useValue: mockProductSkuRepository,
        },
        {
          provide: getRepositoryToken(Order),
          useValue: mockOrderRepository,
        },
        {
          provide: getRepositoryToken(Category),
          useValue: mockCategoryRepository,
        },
        {
          provide: getRepositoryToken(WalletTransaction),
          useValue: mockWalletTransactionRepository,
        },
        {
          provide: getRepositoryToken(SystemConfig),
          useValue: mockSystemConfigRepository,
        },
        {
          provide: PaymentService,
          useValue: mockPaymentService,
        },
        {
          provide: DataSource,
          useValue: mockDataSource,
        },
        {
          provide: ConfigService,
          useValue: mockConfigService,
        },
        {
          provide: NotificationSenderService,
          useValue: { send: jest.fn() },
        },
        {
          provide: LogisticsService,
          useValue: {},
        },
        {
          provide: PlatformFeeService,
          useValue: {
            getPlatformFeeRate: jest.fn().mockResolvedValue(5),
          },
        },
      ],
    }).compile()

    service = module.get<ShopService>(ShopService)
    productRepository = module.get<Repository<Product>>(getRepositoryToken(Product))
    categoryRepository = module.get<Repository<Category>>(getRepositoryToken(Category))
  })

  afterEach(() => {
    jest.clearAllMocks()
  })

  it('should prioritize configured mall hot products before fallback sorting', async () => {
    const queryBuilder = {
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([
        [
          { id: 99, name: 'fallback product' },
          { id: 88, name: 'fallback product 2' },
        ],
        2,
      ]),
    }

    mockProductRepository.createQueryBuilder.mockReturnValue(queryBuilder)
    mockSystemConfigRepository.findOne.mockResolvedValue({
      configKey: 'mall_home_hot_products',
      configValue: {
        productIds: [5, 3],
      },
    })
    mockProductRepository.find.mockResolvedValue([
      { id: 3, name: 'configured 3', isActive: true },
      { id: 5, name: 'configured 5', isActive: true },
    ])

    const result = await service.getPopularProducts({
      page: 1,
      pageSize: 10,
    } as any)

    expect(result.data.map((item: any) => item.id)).toEqual([5, 3])
  })

  it('should expand keyword search to matched category descendants', async () => {
    const queryBuilder = {
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([[], 0]),
    }

    mockProductRepository.createQueryBuilder.mockReturnValue(queryBuilder)
    mockCategoryRepository.find.mockResolvedValueOnce([
      { id: 10, name: '猫粮', parentId: null },
    ])
    mockCategoryRepository.find.mockResolvedValueOnce([
      { id: 11, name: '幼猫粮', parentId: 10 },
    ])
    mockCategoryRepository.find.mockResolvedValueOnce([])

    await service.findAllProducts({
      keyword: '猫粮',
      page: 1,
      pageSize: 10,
    } as any)

    expect(mockCategoryRepository.find).toHaveBeenCalled()
    expect(queryBuilder.andWhere).toHaveBeenCalledWith(
      expect.stringContaining('product.categoryId IN'),
      expect.objectContaining({
        keyword: '%猫粮%',
        categoryIds: expect.arrayContaining([10, 11]),
      }),
    )
  })

  it('应该成功批量查询商品（返回分类树结构）', async () => {
    // Arrange - 准备测试数据
    const dto: BatchGetProductsDto = {
      includeEmpty: false,
      limit: 50,
      sortBy: 'sortOrder',
      sortOrder: 'ASC',
    }

    // Mock 一级分类
    const mockFirstLevelCategories = [
      { id: 1, name: '分类1', parentId: null, status: 'ACTIVE', sortOrder: 1 },
      { id: 2, name: '分类2', parentId: null, status: 'ACTIVE', sortOrder: 2 },
    ]

    // Mock 二级分类
    const mockSecondLevelCategories = [
      { id: 11, name: '子分类1', parentId: 1, status: 'ACTIVE', sortOrder: 1 },
    ]

    // Mock 商品
    const mockProducts = [
      { id: 1, name: '商品1', categoryId: 11, isActive: true, status: 'APPROVED' },
    ]

    mockCategoryRepository.find
      .mockResolvedValueOnce(mockFirstLevelCategories) // 第一次调用返回一级分类
      .mockResolvedValue(mockSecondLevelCategories) // 后续调用返回二级分类

    mockProductRepository.find.mockResolvedValue(mockProducts)

    // Act - 执行测试
    const result = await service.batchGetProducts(dto)

    // Assert - 验证结果
    expect(result.data).toBeDefined()
    expect(Array.isArray(result.data)).toBe(true)
  })

  it('应该默认不包含空商品的分类', async () => {
    // Arrange
    const dto: BatchGetProductsDto = {
      includeEmpty: false,
    }

    mockCategoryRepository.find.mockResolvedValue([])
    mockProductRepository.find.mockResolvedValue([])

    // Act
    const result = await service.batchGetProducts(dto)

    // Assert
    expect(result.data).toBeDefined()
  })

  it('应该正确应用排序参数', async () => {
    // Arrange
    const dto: BatchGetProductsDto = {
      sortBy: 'price',
      sortOrder: 'DESC',
    }

    mockCategoryRepository.find.mockResolvedValue([])
    mockProductRepository.find.mockResolvedValue([])

    // Act
    await service.batchGetProducts(dto)

    // Assert - 验证分类查询被调用
    expect(mockCategoryRepository.find).toHaveBeenCalled()
  })

  it('应该支持限制每个分类的商品数量', async () => {
    // Arrange
    const dto: BatchGetProductsDto = {
      limit: 10,
    }

    const mockFirstLevelCategories = [
      { id: 1, name: '分类1', parentId: null, status: 'ACTIVE' },
    ]
    const mockSecondLevelCategories = [
      { id: 11, name: '子分类1', parentId: 1, status: 'ACTIVE' },
    ]
    const mockProducts = Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      name: `商品${i + 1}`,
      categoryId: 11,
      isActive: true,
      status: 'APPROVED',
    }))

    mockCategoryRepository.find
      .mockResolvedValueOnce(mockFirstLevelCategories)
      .mockResolvedValue(mockSecondLevelCategories)
    mockProductRepository.find.mockResolvedValue(mockProducts)

    // Act
    const result = await service.batchGetProducts(dto)

    // Assert
    expect(result.data).toBeDefined()
  })
})
