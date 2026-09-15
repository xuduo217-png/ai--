import { Injectable, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { AutoReply } from "./entities/auto-reply.entity";
import { RedisService } from "../redis/redis.service";

/**
 * 自动回复服务
 * 负责管理公共自动回复配置（与医生解耦，所有自动回复的 doctorId 统一为 null）
 *
 * 业务逻辑：
 * - 管理员配置 N 条自动回复（按 sortOrder 排序）
 * - 用户发送消息后，系统按顺序依次发送这 N 条回复
 * - 用户发一条 → 系统回第 1 条
 * - 用户再发 → 系统回第 2 条
 * - ...直到 N 条发完 → 用户再发送一条消息后提示付费
 */
@Injectable()
export class AutoReplyService {
  private readonly logger = new Logger(AutoReplyService.name);

  constructor(
    @InjectRepository(AutoReply)
    private autoReplyRepository: Repository<AutoReply>,
    private redisService: RedisService,
  ) {}

  /**
   * 获取所有启用的公共自动回复
   * 按 sortOrder 升序排列（1, 2, 3...）
   */
  async getActiveReplies(): Promise<AutoReply[]> {
    return this.autoReplyRepository.find({
      where: { doctorId: null, isActive: true },
      order: { sortOrder: "ASC" },
    });
  }

  /**
   * 根据序号获取对应的自动回复
   * @param index 回复序号（从 1 开始）
   * @returns 对应的自动回复，如果不存在则返回 null
   */
  async getReplyByIndex(index: number): Promise<AutoReply | null> {
    const replies = await this.getActiveReplies();
    return replies[index - 1] || null;
  }

  /**
   * 获取所有自动回复（包括未启用的）
   * 用于管理后台展示
   */
  async getAllReplies(): Promise<AutoReply[]> {
    return this.autoReplyRepository.find({
      where: { doctorId: null },
      order: { sortOrder: "ASC" },
    });
  }

  /**
   * 创建自动回复
   * 强制 doctorId 为 null，确保自动回复为公共配置
   */
  async create(dto: any): Promise<AutoReply> {
    const reply = this.autoReplyRepository.create({
      ...dto,
      doctorId: null, // 强制为 null，确保为公共配置
    });
    const results = await this.autoReplyRepository.save(reply);
    return results[0];
  }

  /**
   * 更新自动回复
   */
  async update(id: number, dto: any): Promise<AutoReply> {
    await this.autoReplyRepository.update(id, dto);
    return this.autoReplyRepository.findOne({ where: { id } });
  }

  /**
   * 删除自动回复（硬删除）
   * 直接从数据库中删除记录，不可恢复
   */
  async remove(id: number): Promise<void> {
    await this.autoReplyRepository.delete(id);
  }

  /**
   * 清空自动回复相关的 Redis 缓存
   * 用于修改自动回复配置后，立即生效，无需等待缓存过期
   */
  async clearCache(): Promise<{ deleted: number; details: string }> {
    this.logger.log("[clearCache] 开始清空自动回复相关的 Redis 缓存");

    let deletedCount = 0;
    const patterns = [
      "chat:init:*", // 自动回复初始化标记（格式：chat:init:{conversationId}）
    ];

    const details: string[] = [];

    for (const pattern of patterns) {
      try {
        // 使用 scan 命令查找匹配的 key
        const keys = [];
        let cursor = "0";

        do {
          const [nextCursor, batchKeys] = await this.redisService[
            "client"
          ].scan(cursor, "MATCH", pattern, "COUNT", 100);

          cursor = nextCursor;
          keys.push(...batchKeys);
        } while (cursor !== "0");

        if (keys.length > 0) {
          const deleted = await this.redisService.del(...keys);
          deletedCount += deleted;
          details.push(`模式 ${pattern}: 删除 ${deleted} 个键`);
          this.logger.log(`[clearCache] 模式 ${pattern}: 删除 ${deleted} 个键`);
        } else {
          details.push(`模式 ${pattern}: 未找到匹配的键`);
        }
      } catch (error) {
        this.logger.error(`[clearCache] 清空模式 ${pattern} 失败:`, error);
        details.push(`模式 ${pattern}: 清空失败`);
      }
    }

    this.logger.log(`[clearCache] 清空完成，共删除 ${deletedCount} 个缓存键`);

    return {
      deleted: deletedCount,
      details: details.join("; "),
    };
  }
}
