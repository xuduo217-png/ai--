import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Not, Repository } from 'typeorm';
import { LostFound } from './entities/lost-found.entity';
import { LostFoundComment } from './entities/lost-found-comment.entity';
import { User } from '../users/entities/user.entity';
import { CreateLostFoundCommentDto } from './dto/create-lost-found-comment.dto';
import { PaginatedResult } from '../common/dto/pagination.dto';
import { ModerationService } from '../moderation/moderation.service';

export interface LostFoundCommentResponseUser {
  id: number;
  nickname: string;
  avatar?: string;
}

export interface LostFoundCommentResponse {
  id: number;
  lostFoundId: number;
  userId: number;
  content: string;
  parentId?: number;
  likeCount: number;
  createdAt: Date;
  user?: LostFoundCommentResponseUser;
  replies?: LostFoundCommentResponse[];
}

@Injectable()
export class LostFoundCommentsService {
  private readonly DEFAULT_REPLY_LIMIT = 10;

  constructor(
    @InjectRepository(LostFoundComment)
    private readonly commentRepository: Repository<LostFoundComment>,
    @InjectRepository(LostFound)
    private readonly lostFoundRepository: Repository<LostFound>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @Optional()
    private readonly moderationService?: ModerationService,
  ) {}

  private async ensureLostFoundExists(lostFoundId: number): Promise<LostFound> {
    const record = await this.lostFoundRepository.findOne({
      where: { id: lostFoundId },
      select: ['id', 'publisherId'],
    });

    if (!record) {
      throw new NotFoundException('走失招领信息不存在');
    }

    return record;
  }

  private toCommentResponse(comment: any): LostFoundCommentResponse {
    const response: LostFoundCommentResponse = {
      id: comment.id,
      lostFoundId: comment.lostFoundId,
      userId: comment.userId,
      content: comment.content,
      parentId: comment.parentId ?? undefined,
      likeCount: Number(comment.likeCount ?? 0),
      createdAt: comment.createdAt,
    };

    if (comment.user) {
      response.user = {
        id: comment.user.id,
        nickname:
          comment.user.username || comment.user.phone || `用户${comment.user.id}`,
        avatar: comment.user.avatar,
      };
    }

    if (Array.isArray(comment.replies) && comment.replies.length > 0) {
      response.replies = comment.replies.map((reply: LostFoundComment) =>
        this.toCommentResponse(reply),
      );
    }

    return response;
  }

  async create(
    userId: number,
    lostFoundId: number,
    dto: CreateLostFoundCommentDto,
  ): Promise<LostFoundCommentResponse> {
    const lostFound = await this.ensureLostFoundExists(lostFoundId);
    await this.moderationService?.assertUsersCanInteract(
      userId,
      lostFound.publisherId,
    );

    if (dto.parentId) {
      const parentComment = await this.commentRepository.findOne({
        where: {
          id: dto.parentId,
          lostFoundId,
        },
        select: ['id', 'userId'],
      });

      if (!parentComment) {
        throw new NotFoundException('父评论不存在');
      }

      await this.moderationService?.assertUsersCanInteract(
        userId,
        parentComment.userId,
      );
    }

    const currentUser = await this.userRepository.findOne({
      where: { id: userId },
      select: ['id', 'username', 'phone', 'avatar'],
    });

    if (!currentUser) {
      throw new NotFoundException('用户不存在');
    }

    const comment = this.commentRepository.create({
      lostFoundId,
      userId,
      content: dto.content.trim(),
      parentId: dto.parentId,
    });

    const savedComment = await this.commentRepository.save(comment);

    return this.toCommentResponse({
      ...savedComment,
      user: currentUser,
    });
  }

  async findByLostFound(
    lostFoundId: number,
    page: number = 1,
    pageSize: number = 10,
    currentUserId?: number,
  ): Promise<PaginatedResult<LostFoundCommentResponse>> {
    await this.ensureLostFoundExists(lostFoundId);

    const blockedUserIds =
      await this.moderationService?.getBlockedUserIds(currentUserId);
    const visibleAuthorFilter = blockedUserIds?.length
      ? { userId: Not(In(blockedUserIds)) }
      : {};

    const [comments, total] = await this.commentRepository.findAndCount({
      where: {
        lostFoundId,
        parentId: IsNull(),
        ...visibleAuthorFilter,
      },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: pageSize,
      skip: (page - 1) * pageSize,
    });

    if (comments.length > 0) {
      const parentIds = comments.map((comment) => comment.id);
      const replies = await this.commentRepository.find({
        where: {
          lostFoundId,
          parentId: In(parentIds),
          ...visibleAuthorFilter,
        },
        relations: ['user'],
        order: { createdAt: 'ASC' },
        take: this.DEFAULT_REPLY_LIMIT,
      });

      const repliesMap = new Map<number, LostFoundComment[]>();
      replies.forEach((reply) => {
        if (!reply.parentId) {
          return;
        }

        const existingReplies = repliesMap.get(reply.parentId) || [];
        existingReplies.push(reply);
        repliesMap.set(reply.parentId, existingReplies);
      });

      comments.forEach((comment) => {
        (comment as any).replies = repliesMap.get(comment.id) || [];
      });
    }

    return {
      data: comments.map((comment) => this.toCommentResponse(comment)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }
}
