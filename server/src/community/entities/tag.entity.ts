import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

/**
 * 话题标签实体
 * 存储社区帖子的话题标签（如 #宠物医疗 #养猫心得）
 */
@Entity('community_tags')
@Index('IDX_community_tags_usage_count', ['usageCount']) // 按使用次数排序
export class Tag {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 标签名（如 #宠物医疗）
   * 唯一索引，确保标签不重复
   */
  @Column({ type: 'varchar', length: 50, unique: true, comment: '标签名（如 #宠物医疗）' })
  name: string;

  /**
   * 使用次数
   * 用于统计热门标签
   */
  @Column({ type: 'int', default: 0, comment: '使用次数' })
  usageCount: number;

  /**
   * 标签描述
   */
  @Column({ type: 'varchar', length: 200, nullable: true, comment: '标签描述' })
  description?: string;

  /**
   * 创建时间
   */
  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;
}
