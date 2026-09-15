import { Test, TestingModule } from '@nestjs/testing';
import { ActivitiesController } from './activities.controller';
import { ActivitiesService } from './activities.service';
import { Activity, ActivityType } from './entities/activity.entity';
import { ActivityComment } from './entities/activity-comment.entity';
import { ActivityRegistration } from './entities/activity-registration.entity';
import { ActivityVoteOption } from './entities/activity-vote-option.entity';

describe('ActivitiesController', () => {
  let controller: ActivitiesController;
  const mockRequest = {
    user: { id: 8 },
  };

  const mockActivitiesService = {
    findAll: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
    getRegistrations: jest.fn(),
    getParticipants: jest.fn(),
    findUserActivities: jest.fn(),
    findOneUser: jest.fn(),
    register: jest.fn(),
    vote: jest.fn(),
    findActivityComments: jest.fn(),
    createActivityComment: jest.fn(),
    deleteActivityComment: jest.fn(),
    deleteUserVoteOption: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ActivitiesController],
      providers: [
        {
          provide: ActivitiesService,
          useValue: mockActivitiesService,
        },
      ],
    }).compile();

    controller = module.get<ActivitiesController>(ActivitiesController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should forward optional JWT user id for activities list user state fields', async () => {
    const mockResult = {
      data: [
        {
          id: 1,
          title: '宠物讲座',
          isRegistered: true,
          canRegister: false,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    };

    mockActivitiesService.findUserActivities.mockResolvedValue(mockResult);

    const result = await controller.findUserActivities(
      { page: 1, pageSize: 10 },
      { user: { id: 5 } },
    );

    expect(result).toEqual(mockResult);
    expect(mockActivitiesService.findUserActivities).toHaveBeenCalledWith(
      { page: 1, pageSize: 10 },
      5,
    );
  });

  it('should allow anonymous activities detail access without losing optional JWT behavior', async () => {
    const mockResult = {
      id: 1,
      title: '宠物讲座',
      isRegistered: false,
      canRegister: true,
    };

    mockActivitiesService.findOneUser.mockResolvedValue(mockResult);

    const result = await controller.findOneUser('1', {});

    expect(result).toEqual(mockResult);
    expect(mockActivitiesService.findOneUser).toHaveBeenCalledWith(1, undefined);
  });

  it('should forward online vote requests to the service with the authenticated user id', async () => {
    const mockResult = {
      voteId: 22,
      votedAt: 1770201000000,
    };

    mockActivitiesService.vote.mockResolvedValue(mockResult);

    const result = await controller.vote('1', { optionId: 15 }, mockRequest);

    expect(result).toEqual({
      success: true,
      message: '投票成功',
      data: mockResult,
    });
    expect(mockActivitiesService.vote).toHaveBeenCalledWith(1, 8, 15);
  });

  it('should delete only the authenticated user vote option', async () => {
    mockActivitiesService.deleteUserVoteOption.mockResolvedValue(undefined);

    const result = await controller.deleteUserVoteOption('1', '15', mockRequest);

    expect(result).toEqual({
      success: true,
      message: '删除成功',
    });
    expect(mockActivitiesService.deleteUserVoteOption).toHaveBeenCalledWith(
      1,
      15,
      8,
    );
  });

  it('should expose public activity participants for the app detail page', async () => {
    const mockResult = {
      data: [
        {
          userId: 8,
          userName: '小花',
          userAvatar: '/uploads/avatar.png',
          registeredAt: 1770201000000,
        },
      ],
      total: 1,
      page: 1,
      pageSize: 10,
      totalPages: 1,
    };

    mockActivitiesService.getParticipants.mockResolvedValue(mockResult);

    const result = await controller.getParticipants('1', { page: 1, pageSize: 10 });

    expect(result).toEqual(mockResult);
    expect(mockActivitiesService.getParticipants).toHaveBeenCalledWith(1, 1, 10);
  });

  it('should expose public activity comments for online vote details', async () => {
    const mockResult = {
      data: [
        {
          id: 31,
          activityId: 1,
          userId: 8,
          content: '小白加油',
          likeCount: 0,
          createdAt: new Date('2026-05-30T10:00:00.000Z'),
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    };

    mockActivitiesService.findActivityComments.mockResolvedValue(mockResult);

    const result = await controller.getActivityComments('1', { page: 1, pageSize: 20 });

    expect(result).toEqual(mockResult);
    expect(mockActivitiesService.findActivityComments).toHaveBeenCalledWith(1, 1, 20);
  });

  it('should create activity comments with the authenticated user id', async () => {
    const mockResult = {
      id: 31,
      activityId: 1,
      userId: 8,
      content: '小白加油',
      likeCount: 0,
      createdAt: new Date('2026-05-30T10:00:00.000Z'),
    };

    mockActivitiesService.createActivityComment.mockResolvedValue(mockResult);

    const result = await controller.createActivityComment(
      '1',
      { content: '小白加油' },
      mockRequest,
    );

    expect(result).toEqual({
      message: '评论成功',
      data: mockResult,
    });
    expect(mockActivitiesService.createActivityComment).toHaveBeenCalledWith(
      8,
      1,
      { content: '小白加油' },
    );
  });

  it('should expose vote option comments with option isolation', async () => {
    const mockResult = {
      data: [
        {
          id: 41,
          activityId: 1,
          voteOptionId: 15,
          userId: 8,
          content: '小白加油',
          likeCount: 0,
          createdAt: new Date('2026-05-30T10:00:00.000Z'),
        },
      ],
      total: 1,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    };

    mockActivitiesService.findActivityComments.mockResolvedValue(mockResult);

    const result = await controller.getActivityVoteOptionComments(
      '1',
      '15',
      { page: 1, pageSize: 20 },
    );

    expect(result).toEqual(mockResult);
    expect(mockActivitiesService.findActivityComments).toHaveBeenCalledWith(
      1,
      1,
      20,
      15,
    );
  });

  it('should create vote option comments with the authenticated user id and option id', async () => {
    const mockResult = {
      id: 41,
      activityId: 1,
      voteOptionId: 15,
      userId: 8,
      content: '小白加油',
      likeCount: 0,
      createdAt: new Date('2026-05-30T10:00:00.000Z'),
    };

    mockActivitiesService.createActivityComment.mockResolvedValue(mockResult);

    const result = await controller.createActivityVoteOptionComment(
      '1',
      '15',
      { content: '小白加油' },
      mockRequest,
    );

    expect(result).toEqual({
      message: '评论成功',
      data: mockResult,
    });
    expect(mockActivitiesService.createActivityComment).toHaveBeenCalledWith(
      8,
      1,
      { content: '小白加油' },
      15,
    );
  });

  it('should expose activity comments list for admins', async () => {
    const mockResult = {
      data: [
        {
          id: 31,
          activityId: 1,
          userId: 8,
          content: '小白加油',
          likeCount: 0,
          createdAt: new Date('2026-05-30T10:00:00.000Z'),
        },
      ],
      total: 1,
      page: 2,
      pageSize: 10,
      totalPages: 1,
    };

    mockActivitiesService.findActivityComments.mockResolvedValue(mockResult);

    const result = await controller.getAdminActivityComments('1', '2', '10');

    expect(result).toEqual(mockResult);
    expect(mockActivitiesService.findActivityComments).toHaveBeenCalledWith(1, 2, 10);
  });

  it('should delete activity comments from admin endpoint', async () => {
    mockActivitiesService.deleteActivityComment.mockResolvedValue({
      deletedCount: 3,
    });

    const result = await controller.deleteAdminActivityComment('31');

    expect(result).toEqual({
      message: '删除成功',
      data: {
        deletedCount: 3,
      },
    });
    expect(mockActivitiesService.deleteActivityComment).toHaveBeenCalledWith(31);
  });

  it('should forward vote option filter for admin registration list', async () => {
    const mockResult = {
      data: [],
      total: 0,
      page: 2,
      pageSize: 20,
      totalPages: 0,
    };

    mockActivitiesService.getRegistrations.mockResolvedValue(mockResult);

    const result = await controller.getRegistrations('1', '2', '20', '15');

    expect(result).toEqual(mockResult);
    expect(mockActivitiesService.getRegistrations).toHaveBeenCalledWith(1, 2, 20, 15);
  });
});

describe('ActivitiesService vote option deletion', () => {
  const createService = () => {
    const activityRepository = {
      findOne: jest.fn(),
      update: jest.fn(),
      manager: { transaction: jest.fn() },
    };
    const activityCommentRepository = { softDelete: jest.fn() };
    const registrationRepository = {
      delete: jest.fn(),
      count: jest.fn(),
    };
    const voteOptionRepository = {
      findOne: jest.fn(),
      softDelete: jest.fn(),
    };

    activityRepository.manager.transaction.mockImplementation(
      async (callback: (manager: any) => Promise<unknown>) =>
        callback({
          getRepository: jest.fn((entity: Function) => {
            if (entity === Activity) return activityRepository;
            if (entity === ActivityComment) {
              return activityCommentRepository;
            }
            if (entity === ActivityRegistration) {
              return registrationRepository;
            }
            if (entity === ActivityVoteOption) return voteOptionRepository;
            throw new Error(`Unexpected repository: ${entity.name}`);
          }),
        }),
    );

    return {
      service: new ActivitiesService(
        activityRepository as any,
        activityCommentRepository as any,
        registrationRepository as any,
        voteOptionRepository as any,
        {} as any,
      ),
      activityRepository,
      activityCommentRepository,
      registrationRepository,
      voteOptionRepository,
    };
  };

  it('should atomically delete an owned option and dependent content', async () => {
    const {
      service,
      activityRepository,
      activityCommentRepository,
      registrationRepository,
      voteOptionRepository,
    } = createService();
    const now = Math.floor(Date.now() / 1000);
    activityRepository.findOne.mockResolvedValue({
      id: 100,
      activityType: ActivityType.ONLINE,
      startTime: now - 60,
      endTime: now + 60,
    });
    voteOptionRepository.findOne.mockResolvedValue({
      id: 15,
      activityId: 100,
      ownerUserId: 8,
    });
    registrationRepository.count.mockResolvedValue(4);

    await service.deleteUserVoteOption(100, 15, 8);

    expect(activityCommentRepository.softDelete).toHaveBeenCalledWith({
      activityId: 100,
      voteOptionId: 15,
    });
    expect(registrationRepository.delete).toHaveBeenCalledWith({
      activityId: 100,
      voteOptionId: 15,
    });
    expect(voteOptionRepository.softDelete).toHaveBeenCalledWith({
      id: 15,
      activityId: 100,
    });
    expect(activityRepository.update).toHaveBeenCalledWith(100, {
      registrationCount: 4,
      updatedAt: expect.any(Number),
    });
  });

  it('should reject deleting another user option before mutating data', async () => {
    const {
      service,
      activityRepository,
      activityCommentRepository,
      registrationRepository,
      voteOptionRepository,
    } = createService();
    const now = Math.floor(Date.now() / 1000);
    activityRepository.findOne.mockResolvedValue({
      id: 100,
      activityType: ActivityType.ONLINE,
      startTime: now - 60,
      endTime: now + 60,
    });
    voteOptionRepository.findOne.mockResolvedValue({
      id: 15,
      activityId: 100,
      ownerUserId: 9,
    });

    await expect(service.deleteUserVoteOption(100, 15, 8)).rejects.toThrow(
      '只能删除自己添加的选手',
    );
    expect(activityCommentRepository.softDelete).not.toHaveBeenCalled();
    expect(registrationRepository.delete).not.toHaveBeenCalled();
    expect(voteOptionRepository.softDelete).not.toHaveBeenCalled();
  });
});

describe('ActivitiesService admin online activity creation', () => {
  const createService = () => {
    const activityRepository = {
      create: jest.fn((data) => data),
      save: jest.fn(async (data) => ({ ...data, id: 100 })),
      manager: { transaction: jest.fn() },
    };
    const voteOptionRepository = {
      create: jest.fn((data) => data),
      save: jest.fn(async (data) => data),
      find: jest.fn().mockResolvedValue([]),
    };

    activityRepository.manager.transaction.mockImplementation(
      async (callback: (manager: any) => Promise<unknown>) =>
        callback({
          getRepository: jest.fn((entity: Function) => {
            if (entity === Activity) return activityRepository;
            if (entity === ActivityVoteOption) return voteOptionRepository;
            throw new Error(`Unexpected repository: ${entity.name}`);
          }),
        }),
    );

    return {
      service: new ActivitiesService(
        activityRepository as any,
        {} as any,
        {} as any,
        voteOptionRepository as any,
        {} as any,
      ),
      activityRepository,
      voteOptionRepository,
    };
  };

  const expectOnlineActivityCreation = async (voteOptions?: []) => {
    const { service, activityRepository, voteOptionRepository } = createService();

    const result = await service.create({
      title: '萌宠评选',
      startTime: '2026-08-02',
      endTime: '2026-08-03',
      activityType: ActivityType.ONLINE,
      summary: '活动简介',
      description: '<p>活动详情</p>',
      hospitalId: 1,
      voteOptions,
    });

    expect(activityRepository.save).toHaveBeenCalled();
    expect(voteOptionRepository.save).toHaveBeenCalledWith([]);
    expect(result.voteOptions).toEqual([]);
  };

  it('allows creating an online activity without a vote options field', async () => {
    await expectOnlineActivityCreation();
  });

  it('allows creating an online activity with an empty vote options list', async () => {
    await expectOnlineActivityCreation([]);
  });
});
