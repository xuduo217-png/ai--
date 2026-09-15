import { PostService } from "./post.service";
import { PostStatus } from "./entities/post.entity";

function createQueryBuilder(posts: any[]) {
  return {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue(posts),
  };
}

function createService(posts: any[]) {
  const queryBuilder = createQueryBuilder(posts);

  const postRepository = {
    createQueryBuilder: jest.fn(() => queryBuilder),
    findOne: jest.fn(),
    increment: jest.fn().mockResolvedValue(undefined),
    save: jest.fn((post: object): Promise<object> => Promise.resolve(post)),
  };

  const tagRepository = {};
  const postTagRepository = {
    find: jest.fn().mockResolvedValue([]),
    delete: jest.fn().mockResolvedValue(undefined),
  };
  const sensitiveWordService = {
    process: jest.fn(),
  };
  const likeService = {
    findLikedPostIds: jest.fn().mockResolvedValue([11]),
    hasLikedPost: jest.fn(),
  };
  const communityFollowService = {};

  const service = new PostService(
    postRepository as any,
    tagRepository as any,
    postTagRepository as any,
    sensitiveWordService as any,
    likeService as any,
    communityFollowService as any,
  );

  return {
    service,
    likeService,
    postRepository,
    postTagRepository,
    sensitiveWordService,
    queryBuilder,
  };
}

describe("PostService", () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it("should batch load liked post ids when fetching a user post list", async () => {
    const posts = [
      {
        id: 11,
        userId: 15,
        status: PostStatus.APPROVED,
        content: "post-1",
        user: {
          id: 15,
          username: "作者",
          phone: "13800000000",
          avatar: null,
        },
      },
      {
        id: 12,
        userId: 15,
        status: PostStatus.APPROVED,
        content: "post-2",
        user: {
          id: 15,
          username: "作者",
          phone: "13800000000",
          avatar: null,
        },
      },
    ];

    const { service, likeService, queryBuilder } = createService(posts);

    const result = await service.findByUser(15, 24);

    expect(queryBuilder.andWhere).toHaveBeenCalledWith(
      "post.status = :status",
      {
        status: PostStatus.APPROVED,
      },
    );
    expect(likeService.findLikedPostIds).toHaveBeenCalledWith(24, [11, 12]);
    expect(likeService.hasLikedPost).not.toHaveBeenCalled();
    expect(
      (result as unknown as Array<{ id: number; isLiked: boolean }>).map(
        (post) => ({
          id: post.id,
          isLiked: post.isLiked,
        }),
      ),
    ).toEqual([
      { id: 11, isLiked: true },
      { id: 12, isLiked: false },
    ]);
  });

  it("should move an approved post back to pending review after editing content", async () => {
    const approvedPost = {
      id: 7,
      userId: 15,
      content: "原内容",
      status: PostStatus.APPROVED,
      rejectReason: undefined,
      detectedSensitiveWords: [],
      viewCount: 3,
    };
    const { service, postRepository, sensitiveWordService } = createService([]);
    postRepository.findOne.mockResolvedValue(approvedPost);
    sensitiveWordService.process.mockResolvedValue({
      action: "PASS",
      text: "编辑后的内容",
      words: [],
    });

    const result = await service.update(7, 15, {
      content: "编辑后的内容",
    });

    expect(postRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        content: "编辑后的内容",
        status: PostStatus.PENDING_REVIEW,
        rejectReason: null,
      }),
    );
    expect(result.status).toBe(PostStatus.PENDING_REVIEW);
  });

  it("should also re-review an approved post after a media-only edit", async () => {
    const approvedPost = {
      id: 8,
      userId: 15,
      content: "原内容",
      images: ["/uploads/old.jpg"],
      status: PostStatus.APPROVED,
      rejectReason: undefined,
      detectedSensitiveWords: [],
      viewCount: 1,
    };
    const { service, postRepository, sensitiveWordService } = createService([]);
    postRepository.findOne.mockResolvedValue(approvedPost);

    const result = await service.update(8, 15, {
      images: ["/uploads/new.jpg"],
    });

    expect(sensitiveWordService.process).not.toHaveBeenCalled();
    expect(postRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        images: ["/uploads/new.jpg"],
        status: PostStatus.PENDING_REVIEW,
      }),
    );
    expect(result.status).toBe(PostStatus.PENDING_REVIEW);
  });
});
