import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NearbyService } from './nearby.service';

/**
 * 附近的人定时任务
 *
 * 负责清理过期的位置数据
 */
@Injectable()
export class NearbyScheduler {
  private readonly logger = new Logger(NearbyScheduler.name);

  constructor(private readonly nearbyService: NearbyService) {}

  /**
   * 清理过期位置数据
   *
   * 每天凌晨 2 点执行
   * 删除超过 24 小时未更新的位置数据
   */
  @Cron('0 0 2 * * *', {
    name: 'cleanupExpiredLocations',
    timeZone: 'Asia/Shanghai',
  })
  async handleCleanupExpiredLocations() {
    this.logger.log('[定时任务] 开始清理过期位置数据...');
    try {
      const affected = await this.nearbyService.cleanupExpiredLocations();
      this.logger.log(`[定时任务] 清理完成，删除 ${affected} 条过期数据`);
    } catch (error) {
      this.logger.error('[定时任务] 清理失败:', error);
    }
  }
}
