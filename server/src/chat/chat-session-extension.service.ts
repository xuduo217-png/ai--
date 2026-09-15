import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { QueryFailedError, Repository } from "typeorm";
import { ChatOrder, OrderStatus } from "./entities/chat-order.entity";
import { ChatSession, SessionStatus } from "./entities/chat-session.entity";
import { ChatSessionExtension } from "./entities/chat-session-extension.entity";
import {
  CHAT_SESSION_EXTENSION_MINUTES,
  ChatSessionExtensionMinutes,
} from "./dto/extend-chat-session.dto";

export interface ChatSessionExtensionResult {
  extensionId: number;
  conversationId: string;
  userId: number;
  doctorId: number;
  orderId: number;
  extensionMinutes: ChatSessionExtensionMinutes;
  previousServiceEndAt: Date;
  serviceEndAt: Date;
  status: SessionStatus;
  extendedAt: Date;
}

@Injectable()
export class ChatSessionExtensionService {
  constructor(
    @InjectRepository(ChatSession)
    private readonly sessionRepository: Repository<ChatSession>,
    @InjectRepository(ChatSessionExtension)
    private readonly extensionRepository: Repository<ChatSessionExtension>,
  ) {}

  async extend(options: {
    conversationId: string;
    doctorId: number;
    minutes: ChatSessionExtensionMinutes;
    reason?: string;
    idempotencyKey: string;
  }): Promise<ChatSessionExtensionResult> {
    if (!CHAT_SESSION_EXTENSION_MINUTES.includes(options.minutes)) {
      throw new BadRequestException("延长时长仅支持 5、10、15 或 30 分钟");
    }

    try {
      return await this.sessionRepository.manager.transaction(
        async (manager) => {
          const existing = await manager.findOne(ChatSessionExtension, {
            where: { idempotencyKey: options.idempotencyKey },
          });
          if (existing) {
            this.assertIdempotentReplay(existing, options);
            return this.toResult(existing);
          }

          const session = await manager.findOne(ChatSession, {
            where: { conversationId: options.conversationId },
            lock: { mode: "pessimistic_write" },
          });
          if (!session) {
            throw new NotFoundException("咨询会话不存在");
          }
          if (session.doctorId !== options.doctorId) {
            throw new ForbiddenException("您无权延长该咨询会话");
          }
          const now = new Date();
          if (
            session.status !== SessionStatus.PAID ||
            !session.serviceEndAt ||
            session.serviceEndAt <= now
          ) {
            throw new BadRequestException("已结束的咨询不能重新开启或延长");
          }
          if (!session.orderId) {
            throw new BadRequestException("当前会话缺少有效订单");
          }

          const order = await manager.findOne(ChatOrder, {
            where: { id: session.orderId },
            lock: { mode: "pessimistic_write" },
          });
          if (!order || order.doctorId !== options.doctorId) {
            throw new BadRequestException("当前会话订单无效");
          }
          if (order.status !== OrderStatus.PAID) {
            throw new BadRequestException("当前订单状态不支持延长咨询");
          }

          const previousServiceEndAt = new Date(session.serviceEndAt);
          const serviceEndAt = new Date(
            previousServiceEndAt.getTime() + options.minutes * 60 * 1000,
          );
          session.serviceEndAt = serviceEndAt;
          order.serviceEndAt = serviceEndAt;
          await manager.save(ChatSession, session);
          await manager.save(ChatOrder, order);

          const extension = manager.create(ChatSessionExtension, {
            sessionId: session.id,
            conversationId: session.conversationId,
            orderId: order.id,
            doctorId: options.doctorId,
            userId: session.userId,
            extensionMinutes: options.minutes,
            beforeServiceEndAt: previousServiceEndAt,
            afterServiceEndAt: serviceEndAt,
            reason: options.reason?.trim() || undefined,
            idempotencyKey: options.idempotencyKey,
          });
          const saved = await manager.save(ChatSessionExtension, extension);
          return {
            extensionId: saved.id,
            conversationId: saved.conversationId,
            doctorId: saved.doctorId,
            userId: saved.userId,
            orderId: saved.orderId,
            extensionMinutes:
              saved.extensionMinutes as ChatSessionExtensionMinutes,
            previousServiceEndAt: saved.beforeServiceEndAt,
            serviceEndAt: saved.afterServiceEndAt,
            status: session.status,
            extendedAt: saved.createdAt,
          };
        },
      );
    } catch (error) {
      if (this.isDuplicateIdempotencyError(error)) {
        const existing = await this.extensionRepository.findOne({
          where: { idempotencyKey: options.idempotencyKey },
        });
        if (existing) {
          this.assertIdempotentReplay(existing, options);
          return this.toResult(existing);
        }
      }
      throw error;
    }
  }

  private assertIdempotentReplay(
    existing: ChatSessionExtension,
    options: { conversationId: string; doctorId: number; minutes: number },
  ): void {
    if (
      existing.conversationId !== options.conversationId ||
      existing.doctorId !== options.doctorId ||
      existing.extensionMinutes !== options.minutes
    ) {
      throw new ConflictException("幂等键已用于另一笔延长操作");
    }
  }

  private toResult(
    extension: ChatSessionExtension,
  ): ChatSessionExtensionResult {
    return {
      extensionId: extension.id,
      conversationId: extension.conversationId,
      userId: extension.userId,
      doctorId: extension.doctorId,
      orderId: extension.orderId,
      extensionMinutes:
        extension.extensionMinutes as ChatSessionExtensionMinutes,
      previousServiceEndAt: extension.beforeServiceEndAt,
      serviceEndAt: extension.afterServiceEndAt,
      status: SessionStatus.PAID,
      extendedAt: extension.createdAt,
    };
  }

  private isDuplicateIdempotencyError(error: unknown): boolean {
    if (!(error instanceof QueryFailedError)) return false;
    const driverError = error.driverError as { code?: string; errno?: number };
    return driverError?.code === "ER_DUP_ENTRY" || driverError?.errno === 1062;
  }
}
