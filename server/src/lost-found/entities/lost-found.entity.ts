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
import { Pet } from '../../pets/entities/pet.entity';
import { User } from '../../users/entities/user.entity';

/**
 * 发布者类型枚举
 */
export enum PublisherType {
  USER = 'USER', // 用户
  ADMIN = 'ADMIN', // 管理员
}

/**
 * 信息类型枚举
 */
export enum LostFoundRecordType {
  LOST = 'LOST', // 走失
  ADOPTION = 'ADOPTION', // 领养
}

/**
 * 宠物走失/领养记录表
 * 存储宠物走失和领养信息
 */
@Entity('lost_found_records', { comment: '宠物走失招领记录表' })
@Index(['petId'])
@Index(['publisherId'])
@Index(['isPinned'])
@Index(['isFound'])
@Index(['recordType'])
@Index(['createdAt'])
@Index(['publisherType'])
@Index(['isFound', 'isPinned', 'createdAt'])
@Index(['recordType', 'isPinned', 'createdAt'])
export class LostFound {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ nullable: true, comment: '关联宠物ID（手动填写时为空）' })
  petId: number | null;

  @Column({
    type: 'varchar',
    length: 50,
    nullable: true,
    comment: '宠物名称快照',
  })
  petName?: string | null;

  @Column({
    type: 'varchar',
    length: 50,
    nullable: true,
    comment: '宠物类别快照',
  })
  petCategory?: string | null;

  @Column({
    type: 'varchar',
    length: 100,
    nullable: true,
    comment: '宠物品种快照',
  })
  petBreed?: string | null;

  @Column({ comment: '发布者ID' })
  publisherId: number;

  @Column({
    type: 'enum',
    enum: PublisherType,
    default: PublisherType.USER,
    comment: '发布者类型：USER=用户，ADMIN=管理员',
  })
  publisherType: PublisherType;

  @Column({
    type: 'enum',
    enum: LostFoundRecordType,
    default: LostFoundRecordType.LOST,
    comment: '记录类型：LOST=走失，ADOPTION=领养',
  })
  recordType: LostFoundRecordType;

  @Column({ type: 'varchar', length: 50, comment: '联系人姓名' })
  contactName: string;

  @Column({ type: 'varchar', length: 20, comment: '联系电话' })
  contactPhone: string;

  @Column({ type: 'text', comment: '描述信息' })
  description: string;

  @Column({ type: 'json', nullable: true, comment: '图片列表（最多 9 张）' })
  images?: string[];

  @Column({ type: 'varchar', length: 500, nullable: true, comment: '视频 URL' })
  video?: string;

  @Column({
    type: 'varchar',
    length: 500,
    nullable: true,
    comment: '视频封面图 URL',
  })
  videoCover?: string;

  @Column({
    type: 'boolean',
    default: false,
    comment: '是否置顶',
  })
  isPinned: boolean;

  @Column({
    type: 'boolean',
    default: false,
    comment: '是否已找回',
  })
  isFound: boolean;

  @Column({ type: 'timestamp', nullable: true, comment: '找回时间' })
  foundAt?: Date;

  @ManyToOne(() => Pet)
  @JoinColumn({ name: 'petId' })
  pet?: Pet | null;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'publisherId' })
  publisher: User;

  /** 当前请求用户是否为发布者，不持久化到数据库。 */
  isOwner?: boolean;

  @CreateDateColumn({ comment: '发布时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  @DeleteDateColumn({
    type: 'timestamp',
    nullable: true,
    comment: '软删除时间',
  })
  deletedAt?: Date;
}
