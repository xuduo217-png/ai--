import { Test, TestingModule } from "@nestjs/testing";
import { getRepositoryToken } from "@nestjs/typeorm";
import { PetCategoriesService } from "./pet-categories.service";
import { PetCategory } from "./entities/pet-category.entity";
import { Pet } from "../pets/entities/pet.entity";
import { CreatePetCategoryDto } from "./dto/create-pet-category.dto";
import { UpdatePetCategoryDto } from "./dto/update-pet-category.dto";
import { NotFoundException } from "@nestjs/common";

describe("PetCategoriesService", () => {
  let service: PetCategoriesService;

  const mockRepository = {
    create: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
    findOne: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  const mockPetRepository = {
    createQueryBuilder: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PetCategoriesService,
        {
          provide: getRepositoryToken(PetCategory),
          useValue: mockRepository,
        },
        {
          provide: getRepositoryToken(Pet),
          useValue: mockPetRepository,
        },
      ],
    }).compile();

    service = module.get<PetCategoriesService>(PetCategoriesService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  /**
   * 创建宠物引用统计查询构建器 mock
   * 用于模拟有效宠物和软删除宠物两类引用统计
   */
  const createPetCountQueryBuilderMock = (count: number) => {
    return {
      withDeleted: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn().mockResolvedValue(count),
    };
  };

  it("should be defined", () => {
    expect(service).toBeDefined();
  });

  describe("create", () => {
    it("should successfully create a category", async () => {
      const createDto: CreatePetCategoryDto = {
        name: "金毛",
        parentId: null,
        sortOrder: 1,
      };

      const mockCategory = { id: 1, ...createDto } as PetCategory;

      mockRepository.create.mockReturnValue(mockCategory);
      mockRepository.save.mockResolvedValue(mockCategory);

      const result = await service.create(createDto);

      expect(result).toEqual(mockCategory);
      expect(mockRepository.create).toHaveBeenCalledWith(createDto);
      expect(mockRepository.save).toHaveBeenCalledWith(mockCategory);
    });
  });

  describe("findAll", () => {
    it("should return an array of categories", async () => {
      const mockCategories = [
        { id: 1, name: "狗", parentId: null, sortOrder: 1 },
        { id: 2, name: "金毛", parentId: 1, sortOrder: 1 },
      ] as PetCategory[];

      mockRepository.find.mockResolvedValue(mockCategories);

      const result = await service.findAll();

      expect(result).toEqual(mockCategories);
      expect(mockRepository.find).toHaveBeenCalledWith({
        where: {},
        order: { sortOrder: "ASC", createdAt: "ASC" },
      });
    });
  });

  describe("findOne", () => {
    it("should return a category by id", async () => {
      const mockCategory = {
        id: 1,
        name: "狗",
        parentId: null,
        sortOrder: 1,
      } as PetCategory;

      mockRepository.findOne.mockResolvedValue(mockCategory);

      const result = await service.findOne(1);

      expect(result).toEqual(mockCategory);
      expect(mockRepository.findOne).toHaveBeenCalledWith({
        where: { id: 1 },
      });
    });

    it("should throw NotFoundException if category not found", async () => {
      mockRepository.findOne.mockResolvedValue(null);

      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe("update", () => {
    it("should successfully update a category", async () => {
      const updateDto: UpdatePetCategoryDto = {
        name: "哈士奇",
      };

      const mockCategory = {
        id: 1,
        name: "哈士奇",
        parentId: null,
        sortOrder: 1,
      } as PetCategory;

      mockRepository.update.mockResolvedValue({ affected: 1 });
      mockRepository.findOne.mockResolvedValue(mockCategory);

      jest.spyOn(service, "findOne").mockResolvedValue(mockCategory);

      const result = await service.update(1, updateDto);

      expect(result).toEqual(mockCategory);
    });
  });

  describe("remove", () => {
    it("should successfully delete a category", async () => {
      mockRepository.findOne.mockResolvedValue({
        id: 1,
        name: "狗",
        parentId: null,
        sortOrder: 1,
      } as PetCategory);
      mockRepository.find.mockResolvedValue([]); // No children
      mockRepository.delete.mockResolvedValue({ affected: 1 });
      mockPetRepository.createQueryBuilder
        .mockReturnValueOnce(createPetCountQueryBuilderMock(0))
        .mockReturnValueOnce(createPetCountQueryBuilderMock(0));

      const result = await service.remove(1);

      expect(result).toEqual({ affected: 1 });
    });

    it("should throw business exception when active pets still reference categories", async () => {
      mockRepository.findOne.mockResolvedValue({
        id: 1,
        name: "猫",
        parentId: null,
        sortOrder: 1,
      } as PetCategory);
      mockRepository.find.mockResolvedValue([]);
      mockPetRepository.createQueryBuilder.mockReturnValueOnce(
        createPetCountQueryBuilderMock(2),
      );

      await expect(service.remove(1)).rejects.toThrow(
        "当前分类下仍有 2 条宠物档案引用，请先调整宠物分类或删除宠物后再删除分类",
      );
      expect(mockRepository.delete).not.toHaveBeenCalled();
    });

    it("should throw business exception when only soft-deleted pets still reference categories", async () => {
      mockRepository.findOne.mockResolvedValue({
        id: 1,
        name: "猫",
        parentId: null,
        sortOrder: 1,
      } as PetCategory);
      mockRepository.find.mockResolvedValue([]);
      mockPetRepository.createQueryBuilder
        .mockReturnValueOnce(createPetCountQueryBuilderMock(0))
        .mockReturnValueOnce(createPetCountQueryBuilderMock(1));

      await expect(service.remove(1)).rejects.toThrow(
        "当前分类下存在 1 条已删除的宠物档案引用。由于宠物删除为软删除，请先清理相关宠物数据后再删除分类",
      );
      expect(mockRepository.delete).not.toHaveBeenCalled();
    });
  });

  describe("findTree", () => {
    it("should return categories in tree structure", async () => {
      const mockCategories = [
        { id: 1, name: "狗", parentId: null, sortOrder: 1 },
        { id: 2, name: "金毛", parentId: 1, sortOrder: 1 },
        { id: 3, name: "猫", parentId: null, sortOrder: 2 },
      ] as PetCategory[];

      mockRepository.find.mockResolvedValue(mockCategories);

      const result = await service.findTree();

      expect(result).toHaveLength(2); // 2 root categories
      expect(result[0].children).toHaveLength(1); // 1 child for '狗'
      expect(result[1].children).toHaveLength(0); // 0 children for '猫'
    });
  });
});
