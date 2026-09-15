import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Pet } from '../../pets/entities/pet.entity';
import { PetSnapshot } from '../interfaces/pet-snapshot.interface';

/**
 * AI 问诊报告实体
 * 用于存储用户的 AI 问诊记录和诊断结果
 */
@Entity('ai_diagnosis_reports', { comment: 'AI问诊报告表' })
@Index(['userId', 'status'])
@Index(['petId', 'status'])
@Index(['status'])
@Index(['createdAt'])
@Index(['isDeleted'])
export class AiDiagnosisReport {
  @PrimaryGeneratedColumn({ comment: '主键' })
  id: number;

  /**
   * 用户 ID（外键）
   */
  @Column({ name: 'user_id', comment: '用户 ID' })
  userId: number;

  /**
   * 宠物 ID（外键）
   */
  @Column({ name: 'pet_id', comment: '宠物 ID' })
  petId: number;

  /**
   * 报告状态
   * PENDING - 待生成
   * PROCESSING - 生成中
   * COMPLETED - 已完成
   * FAILED - 生成失败
   * TIMEOUT - 超时失败
   */
  @Column({
    type: 'enum',
    enum: ['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'TIMEOUT'],
    default: 'PENDING',
    comment: '报告状态',
  })
  status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED' | 'TIMEOUT';

  /**
   * 用户输入的症状描述
   */
  @Column({ type: 'text', comment: '用户输入的症状描述' })
  symptoms: string;

  /**
   * 自查表答案快照（JSON 格式）
   * 保存用户勾选的自查表问题和答案
   */
  @Column({ type: 'json', nullable: true, comment: '自查表答案快照' })
  selfCheckSnapshot: any;

  /**
   * 诊断图片URL列表（JSON 格式）
   * 用户上传的患处照片
   */
  @Column({ type: 'json', nullable: true, comment: '诊断图片URL列表' })
  diagnosisImages: string[];

  /**
   * 基础信息（JSON 格式）
   * 体温、心率、呼吸频率等生理指标
   */
  @Column({ type: 'json', nullable: true, comment: '基础信息（体温、心率、呼吸）' })
  basicInfo: {
    bodyTemperature?: string;
    heartRate?: string;
    breathe?: string;
  };

  /**
   * 西医诊断结果（JSON 格式）
   * 完整保存第三方接口返回的数据
   */
  @Column({ type: 'json', nullable: true, comment: '西医诊断结果' })
  westernDiagnosis: any;

  /**
   * 中医诊断结果（JSON 格式）
   * 完整保存第三方接口返回的数据
   */
  @Column({ type: 'json', nullable: true, comment: '中医诊断结果' })
  tcmDiagnosis: any;

  /**
   * 西医诊断任务 ID（Bull Job ID）
   */
  @Column({ nullable: true, length: 255, comment: '西医诊断任务 ID' })
  westernJobId: string;

  /**
   * 中医诊断任务 ID（Bull Job ID）
   */
  @Column({ nullable: true, length: 255, comment: '中医诊断任务 ID' })
  tcmJobId: string;

  /**
   * 宠物信息快照（JSON 格式）
   * 保存问诊发起时的完整宠物数据，避免后续宠物信息变更影响历史记录
   */
  @Column({
    type: 'json',
    nullable: true,
    comment: '宠物信息快照（保存问诊发起时的完整宠物数据）',
  })
  petSnapshot: PetSnapshot;

  /**
   * 当前重试次数（0-3）
   */
  @Column({ default: 0, comment: '当前重试次数' })
  retryCount: number;

  /**
   * 错误信息（失败时记录）
   */
  @Column({ type: 'text', nullable: true, comment: '错误信息' })
  errorMessage: string;

  /**
   * 失败原因
   * WESTERN_FAILED - 西医诊断失败
   * TCM_FAILED - 中医诊断失败
   * BOTH_FAILED - 两个诊断都失败
   * TIMEOUT - 超时
   */
  @Column({
    nullable: true,
    type: 'enum',
    enum: ['WESTERN_FAILED', 'TCM_FAILED', 'BOTH_FAILED', 'TIMEOUT'],
    comment: '失败原因',
  })
  failureReason: 'WESTERN_FAILED' | 'TCM_FAILED' | 'BOTH_FAILED' | 'TIMEOUT';

  /**
   * 完成时间
   */
  @Column({ type: 'datetime', nullable: true, comment: '完成时间' })
  completedAt: Date;

  /**
   * 是否删除（软删除）
   */
  @Column({ default: false, comment: '是否删除' })
  isDeleted: boolean;

  @CreateDateColumn({ comment: '创建时间' })
  createdAt: Date;

  @UpdateDateColumn({ comment: '更新时间' })
  updatedAt: Date;

  /**
   * 关联的用户
   */
  @ManyToOne(() => User, { eager: false })
  @JoinColumn({ name: 'user_id' })
  user: User;

  /**
   * 关联的宠物
   */
  @ManyToOne(() => Pet, { eager: false })
  @JoinColumn({ name: 'pet_id' })
  pet: Pet;
}
