import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 文件类型
 */
export enum FileType {
  IMAGE = 'image', // 图片
  PDF = 'pdf', // PDF文档
  DOCUMENT = 'document', // 其他文档
}

/**
 * 文件状态
 */
export enum FileStatus {
  ACTIVE = 'active', // 正常
  DELETED = 'deleted', // 已删除
}

/**
 * 文件记录表
 * 记录所有上传的文件信息
 */
@Entity('file_records', { comment: '文件记录表' })
@Index(['userId'])
@Index(['mimeType'])
@Index(['uploadedAt'])
@Index(['fileType'])
@Index(['isDeleted'])
export class FileRecord {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '上传用户ID（可能是普通用户或医生）' })
  userId: number;

  // 移除外键关联，因为 userId 可能来自 users 表或 doctors 表
  // 如果需要关联查询，请在 Service 层手动处理
  // @ManyToOne(() => User)
  // @JoinColumn({ name: 'userId' })
  // user: User;

  @Column({ comment: '服务器文件名' })
  filename: string;

  @Column({ comment: '原始文件名' })
  originalName: string;

  @Column({ type: 'bigint', comment: '文件大小（字节）' })
  size: number;

  @Column({ comment: 'MIME类型' })
  mimeType: string;

  @Column({
    type: 'enum',
    enum: FileType,
    nullable: true,
    comment: '文件类型',
  })
  fileType: FileType;

  @Column({ nullable: true, comment: '文件路径' })
  path: string;

  @Column({
    type: 'enum',
    enum: FileStatus,
    default: FileStatus.ACTIVE,
    comment: '是否已删除',
  })
  isDeleted: boolean;

  @Column({ type: 'timestamp', nullable: true, comment: '删除时间' })
  deletedAt?: Date;

  @Column({ nullable: true, comment: '文件分类（便于管理）' })
  category?: string;

  @Column({ type: 'text', nullable: true, comment: '文件描述' })
  description?: string;

  @Column({ type: 'text', nullable: true, comment: '文件标签（逗号分隔）' })
  tags?: string;

  @Column({ nullable: true, comment: '缩略图路径' })
  thumbnailPath?: string;

  @Column({ nullable: true, comment: '图片宽度（像素）' })
  width?: number;

  @Column({ nullable: true, comment: '图片高度（像素）' })
  height?: number;

  @Column({ type: 'boolean', default: false, comment: '是否已压缩' })
  isCompressed?: boolean;

  @CreateDateColumn({ name: 'uploadedAt', comment: '上传时间' })
  uploadedAt: Date;
}
