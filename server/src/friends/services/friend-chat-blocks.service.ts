import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { PaginatedResult } from "../../common/dto/pagination.dto";
import { QueryFriendChatBlocksDto } from "../dto/friend-chat-block.dto";
import { FriendChatBlock } from "../entities/friend-chat-block.entity";
import { FriendsService } from "./friends.service";

export interface FriendChatBlockItem {
  id: number;
  blockedUserId: number;
  blockedAt: Date;
  blockedUser: {
    id: number;
    username: string | null;
    avatar: string | null;
  };
}

/** 好友私聊维度的拉黑服务，不影响社区、商城等公开业务。 */
@Injectable()
export class FriendChatBlocksService {
  constructor(
    @InjectRepository(FriendChatBlock)
    private readonly friendChatBlockRepository: Repository<FriendChatBlock>,
    private readonly friendsService: FriendsService,
  ) {}

  async blockUser(
    blockerUserId: number,
    blockedUserId: number,
  ): Promise<FriendChatBlock> {
    if (blockerUserId === blockedUserId) {
      throw new BadRequestException("不能拉黑自己");
    }

    const existingBlock = await this.friendChatBlockRepository.findOne({
      where: { blockerUserId, blockedUserId },
    });
    if (existingBlock) {
      return existingBlock;
    }

    const isFriend = await this.friendsService.isFriend(
      blockerUserId,
      blockedUserId,
    );
    if (!isFriend) {
      throw new BadRequestException("只能拉黑当前好友");
    }

    return this.friendChatBlockRepository.save(
      this.friendChatBlockRepository.create({
        blockerUserId,
        blockedUserId,
      }),
    );
  }

  async unblockUser(
    blockerUserId: number,
    blockedUserId: number,
  ): Promise<void> {
    await this.friendChatBlockRepository.delete({
      blockerUserId,
      blockedUserId,
    });
  }

  async getBlockedUsers(
    blockerUserId: number,
    query: QueryFriendChatBlocksDto,
  ): Promise<PaginatedResult<FriendChatBlockItem>> {
    const { page = 1, pageSize = 20 } = query;
    const [blocks, total] = await this.friendChatBlockRepository.findAndCount({
      where: { blockerUserId },
      relations: ["blockedUser"],
      order: { createdAt: "DESC" },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      data: blocks.map((block) => ({
        id: block.id,
        blockedUserId: block.blockedUserId,
        blockedAt: block.createdAt,
        blockedUser: {
          id: block.blockedUser?.id ?? block.blockedUserId,
          username: block.blockedUser?.username ?? null,
          avatar: block.blockedUser?.avatar ?? null,
        },
      })),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async isBlockedBy(
    blockerUserId: number,
    blockedUserId: number,
  ): Promise<boolean> {
    return this.friendChatBlockRepository.exist({
      where: { blockerUserId, blockedUserId },
    });
  }

  async hasBlockBetween(
    firstUserId: number,
    secondUserId: number,
  ): Promise<boolean> {
    const [firstBlockedSecond, secondBlockedFirst] = await Promise.all([
      this.isBlockedBy(firstUserId, secondUserId),
      this.isBlockedBy(secondUserId, firstUserId),
    ]);
    return firstBlockedSecond || secondBlockedFirst;
  }

  async assertUsersCanChat(
    firstUserId: number,
    secondUserId: number,
  ): Promise<void> {
    if (await this.hasBlockBetween(firstUserId, secondUserId)) {
      throw new ForbiddenException("当前无法发送好友消息");
    }
  }

  async assertUsersCanBecomeFriends(
    firstUserId: number,
    secondUserId: number,
  ): Promise<void> {
    if (await this.hasBlockBetween(firstUserId, secondUserId)) {
      throw new ForbiddenException("当前无法进行好友申请操作");
    }
  }
}
