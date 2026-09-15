import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
} from 'typeorm';

/**
 * 公益文章(CharityArticle)实体
 *
 * 用于发布公益相关文章给参与者
 * 支持定向推送（只推送给特定公益的参与者）
 */
@Entity('charity_articles', { comment: '公益文章表' })
export class CharityArticle {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'int', comment: '关联的公益ID' })
  charityId: number;

  @Column({ length: 200, comment: '文章标题' })
  title: string;

  @Column({ type: 'text', comment: '文章内容(支持HTML或Markdown)' })
  content: string;

  @Column({ type: 'int', nullable: true, comment: '发布者ID(管理员)' })
  publisherId: number;

  @Column({ type: 'json', nullable: true, comment: '目标用户ID列表(留空表示推送给所有参与者)' })
  targetUserIds: number[];

  @Column({ type: 'boolean', default: false, comment: '是否发送系统通知' })
  sendNotification: boolean;

  @Column({ type: 'boolean', default: true, comment: '是否已发布' })
  isPublished: boolean;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;
}
