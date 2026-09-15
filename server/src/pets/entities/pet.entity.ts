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
import { PetCategory } from '../../pet-categories/entities/pet-category.entity';

/**
 * 宠物性别
 * 1=弟弟，2=妹妹
 */
export enum PetGender {
  MALE = 1, // 弟弟
  FEMALE = 2, // 妹妹
}

/**
 * 宠物表
 * 存储宠物档案信息
 */
@Entity('pets', { comment: '宠物表' })
@Index(['ownerId'])
@Index(['categoryId'])
@Index(['subCategoryId'])
@Index(['ownerId', 'deletedAt'])
@Index(['name'])
@Index(['createdAt'])
export class Pet {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  @Column({ comment: '宠物名称' })
  name: string;

  @Column({ nullable: true, comment: '宠物头像' })
  avatar: string;

  @Column({ nullable: true, comment: '一级分类ID（类型）' })
  categoryId: number;

  @Column({ nullable: true, comment: '二级分类ID（种类）' })
  subCategoryId: number;

  @Column({
    type: 'enum',
    enum: PetGender,
    comment: '性别：1=弟弟，2=妹妹',
  })
  gender: PetGender;

  @Column({ type: 'date', nullable: true, comment: '出生日期' })
  birthDate: Date;

  @Column({
    type: 'decimal',
    precision: 5,
    scale: 2,
    default: 0,
    comment: '体重（公斤）',
  })
  weight: number;

  @ManyToOne(() => PetCategory)
  @JoinColumn({ name: 'categoryId' })
  category: PetCategory;

  @ManyToOne(() => PetCategory)
  @JoinColumn({ name: 'subCategoryId' })
  subCategory: PetCategory;

  @ManyToOne(() => User)
  @JoinColumn()
  owner: User;

  @Column({ comment: '主人ID' })
  ownerId: number;

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

  @Column({
    type: 'simple-array',
    nullable: true,
    comment: '标签（如：慢性病、老年犬、术后恢复等）',
  })
  tags?: string[];

  @Column({
    type: 'boolean',
    default: false,
    comment: '是否绝育',
  })
  isNeutered: boolean;

  // ========== 统计相关 ==========

  @Column({ type: 'int', default: 0, comment: '预约次数' })
  appointmentCount: number;

  @Column({ type: 'timestamp', nullable: true, comment: '最后预约时间' })
  lastAppointmentAt?: Date;

  @Column({ type: 'int', default: 0, comment: 'AI问诊次数' })
  consultationCount: number;

  // ========== 健康管理相关 ==========

  @Column({ type: 'date', nullable: true, comment: '上次驱虫时间' })
  lastDewormingAt?: Date;

  @Column({ type: 'date', nullable: true, comment: '下次驱虫时间' })
  nextDewormingAt?: Date;

  @Column({ type: 'date', nullable: true, comment: '上次疫苗时间' })
  lastVaccineAt?: Date;

  @Column({ type: 'date', nullable: true, comment: '下次疫苗时间' })
  nextVaccineAt?: Date;

  @Column({ type: 'date', nullable: true, comment: '上次体检时间' })
  lastCheckupAt?: Date;

  @Column({ type: 'date', nullable: true, comment: '下次体检时间' })
  nextCheckupAt?: Date;

  @Column({ type: 'int', default: 0, comment: '疫苗接种针数' })
  vaccineCount: number;

  @Column({ type: 'int', default: 0, comment: '驱虫次数' })
  dewormingCount: number;

  @Column({ type: 'int', default: 0, comment: '体检次数' })
  checkupCount: number;

  // ========== 智能护理计划相关 ==========

  @Column({
    type: 'json',
    nullable: true,
    comment: '宠物护理计划（包含 nutrition_plan 和 care_plan）',
  })
  carePlan: object;

  @Column({
    type: 'varchar',
    length: 50,
    default: 'NOT_GENERATED',
    comment: '护理计划状态：NOT_GENERATED=未生成，GENERATING=生成中，COMPLETED=已完成，FAILED=失败',
  })
  carePlanStatus: string;

  @Column({
    type: 'varchar',
    length: 255,
    nullable: true,
    comment: '护理计划队列任务 ID',
  })
  carePlanJobId: string;

  @Column({
    type: 'timestamp',
    nullable: true,
    comment: '护理计划最后生成时间',
  })
  carePlanGeneratedAt: Date;

  @Column({
    type: 'text',
    nullable: true,
    comment: '护理计划生成失败的错误信息',
  })
  carePlanError: string;
}
