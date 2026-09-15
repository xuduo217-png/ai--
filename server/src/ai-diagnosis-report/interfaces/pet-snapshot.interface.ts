/**
 * 宠物信息快照接口
 * 保存问诊发起时的完整宠物数据（扁平化结构）
 */
export interface PetSnapshot {
  // ========== 基础信息 ==========
  /** 宠物 ID */
  id: number;

  /** 宠物名称 */
  name: string;

  /** 宠物头像 URL */
  avatar: string;

  /** 性别：1=弟弟，2=妹妹 */
  gender: number;

  /** 出生日期（ISO 格式字符串） */
  birthDate: string;

  /** 体重（公斤） */
  weight: number;

  // ========== 分类信息（扁平化） ==========
  /** 一级分类 ID（类型） */
  categoryId: number;

  /** 一级分类名称 */
  categoryName: string;

  /** 二级分类 ID（品种） */
  subCategoryId: number;

  /** 二级分类名称 */
  subCategoryName: string;

  // ========== 标签和绝育 ==========
  /** 标签列表（如：慢性病、老年犬、术后恢复等） */
  tags: string[];

  /** 是否绝育 */
  isNeutered: boolean;

  // ========== 统计信息 ==========
  /** 预约次数 */
  appointmentCount: number;

  /** 最后预约时间（ISO 格式） */
  lastAppointmentAt: string;

  /** AI 问诊次数 */
  consultationCount: number;

  // ========== 健康管理 ==========
  /** 上次驱虫时间（ISO 格式） */
  lastDewormingAt: string;

  /** 下次驱虫时间（ISO 格式） */
  nextDewormingAt: string;

  /** 上次疫苗时间（ISO 格式） */
  lastVaccineAt: string;

  /** 下次疫苗时间（ISO 格式） */
  nextVaccineAt: string;

  /** 上次体检时间（ISO 格式） */
  lastCheckupAt: string;

  /** 下次体检时间（ISO 格式） */
  nextCheckupAt: string;

  /** 疫苗接种针数 */
  vaccineCount: number;

  /** 驱虫次数 */
  dewormingCount: number;

  /** 体检次数 */
  checkupCount: number;

  // ========== 护理计划 ==========
  /** 护理计划对象（包含 nutrition_plan 和 care_plan） */
  carePlan: object;

  /** 护理计划状态 */
  carePlanStatus: string;

  /** 护理计划队列任务 ID */
  carePlanJobId: string;

  /** 护理计划最后生成时间（ISO 格式） */
  carePlanGeneratedAt: string;

  /** 护理计划生成失败的错误信息 */
  carePlanError: string;
}
