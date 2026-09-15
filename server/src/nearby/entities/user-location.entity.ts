import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  RelationId,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

/**
 * 用户位置信息实体
 *
 * 存储用户的地理位置信息，用于"附近的人"功能
 */
@Entity('user_locations')
export class UserLocation {
  @PrimaryGeneratedColumn()
  id: number;

  /**
   * 关联用户
   */
  @ManyToOne(() => User, { nullable: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  /**
   * 用户 ID（通过 @RelationId 自动从 user 关系获取）
   */
  @RelationId((location: UserLocation) => location.user)
  userId: number;

  /**
   * 纬度
   * 精度：小数点后 7 位（约 1.1cm 精度）
   */
  @Column({ type: 'decimal', precision: 10, scale: 7 })
  latitude: number;

  /**
   * 经度
   * 精度：小数点后 7 位（约 1.1cm 精度）
   */
  @Column({ type: 'decimal', precision: 10, scale: 7 })
  longitude: number;

  /**
   * 城市名称
   * 可选，用于显示"同城"标签
   */
  @Column({ name: 'city', type: 'varchar', length: 100, nullable: true })
  city: string;

  /**
   * 是否允许被附近的人发现
   * 隐私开关：false 时不参与附近的人推荐
   */
  @Column({ name: 'discovery_enabled', type: 'tinyint', width: 1, default: 1 })
  discoveryEnabled: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
