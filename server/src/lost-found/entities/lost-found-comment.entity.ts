import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { LostFound } from './lost-found.entity';

@Entity('lost_found_comments', { comment: '走失招领评论表' })
@Index('IDX_lost_found_comments_lost_found_id', ['lostFoundId'])
@Index('IDX_lost_found_comments_user_id', ['userId'])
@Index('IDX_lost_found_comments_parent_id', ['parentId'])
export class LostFoundComment {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ type: 'int', comment: '走失招领记录ID' })
  lostFoundId: number;

  @ManyToOne(() => LostFound, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'lostFoundId' })
  lostFound: LostFound;

  @Column({ type: 'int', comment: '评论用户ID' })
  userId: number;

  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'int', nullable: true, comment: '父评论ID（用于回复）' })
  parentId?: number;

  @ManyToOne(() => LostFoundComment, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'parentId' })
  parent?: LostFoundComment;

  @Column({ type: 'text', comment: '评论内容' })
  content: string;

  @Column({ type: 'int', default: 0, comment: '点赞数（预留）' })
  likeCount: number;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @DeleteDateColumn({
    type: 'timestamp',
    nullable: true,
    comment: '删除时间（软删除）',
  })
  deletedAt?: Date;
}
