import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

/**
 * 收货地址表
 * 用户收货地址信息
 */
@Entity('addresses', { comment: '收货地址表' })
@Index(['userId']) // 添加索引以优化按用户查询的性能
@Index(['userId', 'isDefault']) // 复合索引，优化默认地址查询
export class Address {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 所属用户ID
   * 关联到用户表
   * 已在类级别通过 @Index(['userId']) 添加索引
   */
  @Column({ name: 'user_id', comment: '所属用户ID' })
  userId: number;

  /**
   * 收货人姓名
   */
  @Column({ name: 'receiver_name', length: 50, comment: '收货人姓名' })
  receiverName: string;

  /**
   * 收货人手机号
   */
  @Column({ name: 'receiver_phone', length: 20, comment: '收货人手机号' })
  receiverPhone: string;

  /**
   * 省份代码（行政区划代码）
   * 例如：110000 表示北京市
   */
  @Column({ name: 'province_code', length: 12, comment: '省份代码' })
  provinceCode: string;

  /**
   * 省份名称
   * 例如：北京市
   */
  @Column({ name: 'province_name', length: 50, comment: '省份名称' })
  provinceName: string;

  /**
   * 城市代码（行政区划代码）
   * 例如：110100 表示北京市市辖区
   */
  @Column({ name: 'city_code', length: 12, comment: '城市代码' })
  cityCode: string;

  /**
   * 城市名称
   * 例如：北京市
   */
  @Column({ name: 'city_name', length: 50, comment: '城市名称' })
  cityName: string;

  /**
   * 区县代码（行政区划代码）
   * 例如：110101 表示东城区
   */
  @Column({ name: 'district_code', length: 12, comment: '区县代码' })
  districtCode: string;

  /**
   * 区县名称
   * 例如：东城区
   */
  @Column({ name: 'district_name', length: 50, comment: '区县名称' })
  districtName: string;

  /**
   * 详细地址
   * 街道、门牌号等详细信息
   */
  @Column({ name: 'detail_address', length: 200, comment: '详细地址' })
  detailAddress: string;

  /**
   * 是否为默认地址
   * 每个用户只能有一个默认地址
   * 已在类级别通过 @Index(['userId', 'isDefault']) 添加索引
   */
  @Column({ name: 'is_default', default: false, comment: '是否为默认地址' })
  isDefault: boolean;

  /**
   * 创建时间
   */
  @CreateDateColumn({ name: 'created_at', comment: '创建时间' })
  createdAt: Date;

  /**
   * 更新时间
   */
  @UpdateDateColumn({ name: 'updated_at', comment: '更新时间' })
  updatedAt: Date;
}
