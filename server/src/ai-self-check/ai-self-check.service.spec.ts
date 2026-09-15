import { NotFoundException } from "@nestjs/common";
import { Test, TestingModule } from "@nestjs/testing";
import { getRepositoryToken } from "@nestjs/typeorm";
import { AiSelfCheckService } from "./ai-self-check.service";
import { SelfCheckList } from "./entities/self-check-list.entity";
import { SelfCheckQuestion } from "./entities/self-check-question.entity";
import { SelfCheckOption } from "./entities/self-check-option.entity";
import { PetsService } from "../pets/pets.service";
import { PetCategoriesService } from "../pet-categories/pet-categories.service";

describe("AiSelfCheckService", () => {
  let service: AiSelfCheckService;

  const transactionManager = {
    delete: jest.fn(),
  };

  const mockListRepository = {
    findOne: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
    create: jest.fn(),
    remove: jest.fn(),
    manager: {
      transaction: jest.fn(),
    },
  };

  const mockQuestionRepository = {
    findOne: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
    create: jest.fn(),
    remove: jest.fn(),
    manager: {
      transaction: jest.fn(),
    },
  };

  const mockOptionRepository = {
    delete: jest.fn(),
    save: jest.fn(),
    create: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AiSelfCheckService,
        {
          provide: getRepositoryToken(SelfCheckList),
          useValue: mockListRepository,
        },
        {
          provide: getRepositoryToken(SelfCheckQuestion),
          useValue: mockQuestionRepository,
        },
        {
          provide: getRepositoryToken(SelfCheckOption),
          useValue: mockOptionRepository,
        },
        {
          provide: PetsService,
          useValue: {},
        },
        {
          provide: PetCategoriesService,
          useValue: {},
        },
      ],
    }).compile();

    service = module.get<AiSelfCheckService>(AiSelfCheckService);

    mockQuestionRepository.manager.transaction.mockImplementation(
      async (handler: (manager: typeof transactionManager) => Promise<void>) =>
        handler(transactionManager),
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("deleteQuestion", () => {
    it("应先删除问题选项，再删除问题本身", async () => {
      mockQuestionRepository.findOne.mockResolvedValue({ id: 1 });

      const result = await service.deleteQuestion(1);

      expect(result).toEqual({ success: true });
      expect(mockQuestionRepository.findOne).toHaveBeenCalledWith({
        where: { id: 1 },
      });
      expect(mockQuestionRepository.manager.transaction).toHaveBeenCalledTimes(
        1,
      );
      expect(transactionManager.delete).toHaveBeenNthCalledWith(
        1,
        SelfCheckOption,
        { questionId: 1 },
      );
      expect(transactionManager.delete).toHaveBeenNthCalledWith(
        2,
        SelfCheckQuestion,
        { id: 1 },
      );
    });

    it("问题不存在时应抛出异常", async () => {
      mockQuestionRepository.findOne.mockResolvedValue(null);

      await expect(service.deleteQuestion(999)).rejects.toThrow(
        NotFoundException,
      );
      expect(mockQuestionRepository.manager.transaction).not.toHaveBeenCalled();
    });
  });
});
