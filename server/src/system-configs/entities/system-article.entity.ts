import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm'

/**
 * 文章类型枚举
 */
export enum ArticleType {
  ABOUT_US = 'about_us',          // 关于我们
  PRIVACY = 'privacy',            // 隐私协议
  USER_AGREEMENT = 'user_agreement'  // 用户协议
}

/**
 * 系统文章实体
 * 用于存储系统级文章内容（关于我们、隐私协议、用户协议等）
 */
@Entity('system_articles', { comment: '系统文章表' })
export class SystemArticle {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number

  @Column({
    type: 'enum',
    enum: ArticleType,
    unique: true,
    comment: '文章类型'
  })
  type: ArticleType

  @Column({
    type: 'text',
    comment: '文章内容(HTML格式)'
  })
  content: string

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date
}
