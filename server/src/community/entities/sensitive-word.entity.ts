import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

/**
 * 敏感词等级枚举
 */
export enum WordSeverity {
  LOW = 1, // 低危：仅标记，人工审核
  MEDIUM = 2, // 中危：替换词
  HIGH = 3, // 高危：直接拒绝
}

/**
 * 敏感词实体
 * 存储敏感词配置，用于内容审核
 */
@Entity('community_sensitive_words')
@Index('IDX_community_sensitive_words_word', ['word'], { unique: true })
@Index('IDX_community_sensitive_words_severity', ['severity'])
@Index('IDX_community_sensitive_words_is_active', ['isActive'])
export class SensitiveWord {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 敏感词
   * 唯一索引，确保敏感词不重复
   */
  @Column({ type: 'varchar', length: 100, unique: true, comment: '敏感词' })
  word: string;

  /**
   * 敏感等级
   * LOW(1): 低危，仅标记，进入人工审核
   * MEDIUM(2): 中危，自动替换为替换词
   * HIGH(3): 高危，直接拒绝发布
   */
  @Column({
    type: 'enum',
    enum: WordSeverity,
    default: WordSeverity.LOW,
    comment: '敏感等级'
  })
  severity: WordSeverity;

  /**
   * 替换词
   * 当 severity 为 MEDIUM 时，将敏感词替换为该词
   * 如果为空，则不替换，进入人工审核
   */
  @Column({ type: 'varchar', length: 100, nullable: true, comment: '替换词（为空则拒绝发布）' })
  replacement?: string;

  /**
   * 分类（政治、色情、广告、暴力等）
   */
  @Column({ type: 'varchar', length: 50, nullable: true, comment: '分类（政治、色情、广告等）' })
  category?: string;

  /**
   * 是否启用
   */
  @Column({ type: 'bool', default: true, comment: '是否启用' })
  isActive: boolean;

  /**
   * 创建时间
   */
  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  /**
   * 更新时间
   */
  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;
}
