import { getQueueToken } from "@nestjs/bull";
import { ForbiddenException } from "@nestjs/common";
import { Test, TestingModule } from "@nestjs/testing";
import { getRepositoryToken } from "@nestjs/typeorm";
import { Pet } from "./entities/pet.entity";
import { PET_CARE_PLAN_QUEUE } from "./queues";
import { PetsService } from "./pets.service";

describe("PetsService", () => {
  let service: PetsService;

  const queryBuilderMock = {
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue(undefined),
  };

  const transactionManagerMock = {
    createQueryBuilder: jest.fn().mockReturnValue(queryBuilderMock),
    softDelete: jest.fn().mockResolvedValue(undefined),
  };

  const petRepositoryMock = {
    findOne: jest.fn(),
    update: jest.fn(),
    manager: {
      transaction: jest.fn(),
    },
  };

  const carePlanQueueMock = {
    add: jest.fn(),
  };

  /**
   * 重置事务相关 mock，避免不同测试之间互相污染调用次数
   */
  const resetTransactionMocks = () => {
    queryBuilderMock.update.mockClear();
    queryBuilderMock.set.mockClear();
    queryBuilderMock.where.mockClear();
    queryBuilderMock.execute.mockClear();
    transactionManagerMock.createQueryBuilder.mockClear();
    transactionManagerMock.softDelete.mockClear();
    petRepositoryMock.manager.transaction.mockClear();
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PetsService,
        {
          provide: getRepositoryToken(Pet),
          useValue: petRepositoryMock,
        },
        {
          provide: getQueueToken(PET_CARE_PLAN_QUEUE),
          useValue: carePlanQueueMock,
        },
      ],
    }).compile();

    service = module.get<PetsService>(PetsService);

    petRepositoryMock.manager.transaction.mockImplementation(
      async (
        callback: (manager: typeof transactionManagerMock) => Promise<void>,
      ) => callback(transactionManagerMock),
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
    resetTransactionMocks();
  });

  it("should clear category references before soft deleting pet", async () => {
    jest.spyOn(service, "findOne").mockResolvedValue({
      id: 1,
      ownerId: 2,
    } as Pet);

    await service.remove(1, 2, "STAFF");

    expect(petRepositoryMock.manager.transaction).toHaveBeenCalledTimes(1);
    expect(queryBuilderMock.update).toHaveBeenCalledWith(Pet);

    /**
     * 删除前会把分类引用显式置空，避免软删除宠物继续阻塞分类删除
     */
    const setCalls = queryBuilderMock.set.mock.calls as Array<
      [
        {
          categoryId: () => string;
          subCategoryId: () => string;
        },
      ]
    >;
    const setPayload = setCalls[0]?.[0] as {
      categoryId: () => string;
      subCategoryId: () => string;
    };
    expect(typeof setPayload.categoryId).toBe("function");
    expect(typeof setPayload.subCategoryId).toBe("function");
    expect(setPayload.categoryId()).toBe("NULL");
    expect(setPayload.subCategoryId()).toBe("NULL");

    expect(queryBuilderMock.where).toHaveBeenCalledWith("id = :id", { id: 1 });
    expect(queryBuilderMock.execute).toHaveBeenCalledTimes(1);
    expect(transactionManagerMock.softDelete).toHaveBeenCalledWith(Pet, 1);
  });

  it("should reject delete when user does not own the pet", async () => {
    jest.spyOn(service, "findOne").mockResolvedValue({
      id: 1,
      ownerId: 99,
    } as Pet);

    await expect(service.remove(1, 2, "USER")).rejects.toThrow(
      ForbiddenException,
    );
    expect(petRepositoryMock.manager.transaction).not.toHaveBeenCalled();
  });

  it("should compare decimal string weight safely during update", async () => {
    const existingPet = {
      id: 1,
      ownerId: 2,
      weight: "5.00",
      birthDate: new Date("2024-01-01"),
      isNeutered: false,
      gender: 1,
      subCategoryId: 3,
      vaccineCount: 3,
    } as unknown as Pet;

    jest
      .spyOn(service, "findOne")
      .mockResolvedValueOnce(existingPet)
      .mockResolvedValueOnce(existingPet);
    const triggerCarePlanGenerationSpy = jest.spyOn(
      service,
      "triggerCarePlanGeneration",
    );

    await expect(
      service.update(
        1,
        {
          weight: 5,
          birthDate: "2024-01-01",
          vaccineCount: 3,
        },
        2,
        "USER",
      ),
    ).resolves.toEqual(existingPet);

    /**
     * 数据库存储的 decimal 字段可能以字符串返回，
     * 这里要确保比较逻辑不会把它误当成日期字符串并抛出异常。
     */
    expect(petRepositoryMock.update).toHaveBeenCalledWith(1, {
      weight: 5,
      birthDate: "2024-01-01",
      vaccineCount: 3,
    });
    expect(triggerCarePlanGenerationSpy).not.toHaveBeenCalled();
  });
});
