import { BusinessException } from '../filters/business-exception';

/**
 * 统一错误码体系
 * 错误码格式: 分类码(1位) + 具体错误码(3位)
 *
 * 分类码:
 * - 1xxx: 认证相关
 * - 2xxx: 资源相关
 * - 3xxx: 业务逻辑
 * - 4xxx: 文件相关
 * - 5xxx: 系统错误
 */
export enum ErrorCode {
  // ========== 认证相关 (1xxx) ==========
  UNAUTHORIZED = '1001',
  TOKEN_EXPIRED = '1002',
  INVALID_CREDENTIALS = '1003',
  PHONE_VERIFICATION_FAILED = '1004',
  SMS_CODE_EXPIRED = '1005',
  SMS_CODE_INVALID = '1006',
  PERMISSION_DENIED = '1007',
  ACCOUNT_LOCKED = '1008',
  ACCOUNT_DISABLED = '1009',

  // ========== 资源相关 (2xxx) ==========
  USER_NOT_FOUND = '2001',
  PET_NOT_FOUND = '2002',
  APPOINTMENT_NOT_FOUND = '2003',
  DOCTOR_NOT_FOUND = '2004',
  HOSPITAL_NOT_FOUND = '2005',
  DEPARTMENT_NOT_FOUND = '2006',
  SCHEDULE_NOT_FOUND = '2007',
  CHAT_SESSION_NOT_FOUND = '2008',
  PRODUCT_NOT_FOUND = '2009',
  ORDER_NOT_FOUND = '2010',

  // ========== 业务逻辑 (3xxx) ==========
  BUSINESS_INVALID_PARAM = '3000', // 通用参数无效错误
  APPOINTMENT_CONFLICT = '3001',
  INSUFFICIENT_BALANCE = '3002',
  EXCEED_FREE_MESSAGE_LIMIT = '3003',
  CHAT_SESSION_EXPIRED = '3004',
  INVALID_APPOINTMENT_TIME = '3005',
  DOCTOR_NOT_AVAILABLE = '3006',
  APPOINTMENT_CANNOT_CANCEL = '3007',
  APPOINTMENT_CANNOT_MODIFY = '3008',
  PRODUCT_OUT_OF_STOCK = '3009',
  INVALID_ORDER_STATUS = '3010',
  PRODUCT_NOT_ACTIVE = '3012',
  PRODUCT_ALREADY_AUDITED = '3013', // 商品已审核
  BUSINESS_PERMISSION_DENIED = '3014', // 业务权限不足（通用）
  COUPON_NOT_FOUND = '3015', // 优惠券不存在
  COUPON_EXPIRED = '3016', // 优惠券已过期
  COUPON_ALREADY_USED = '3017', // 优惠券已使用
  COUPON_NOT_APPLICABLE = '3018', // 优惠券不适用
  COUPON_LIMIT_EXCEEDED = '3019', // 领取数量已达上限
  ORDER_AMOUNT_TOO_LOW = '3020', // 订单金额未达到优惠券使用门槛
  COUPON_OUT_OF_STOCK = '3021', // 优惠券已领完
  WITHDRAWAL_DISABLED = '3030',
  WITHDRAWAL_AMOUNT_INVALID = '3031',
  WITHDRAWAL_LIMIT_EXCEEDED = '3032',
  WITHDRAWAL_ACTIVE_EXISTS = '3033',
  WITHDRAWAL_NOT_FOUND = '3034',
  WITHDRAWAL_STATUS_INVALID = '3035',

  // 公益相关 (33xx)
  CHARITY_NOT_FOUND = '3301', // 公益不存在
  CHARITY_NOT_ACTIVE = '3302', // 公益未开始或已结束
  CHARITY_EXPIRED = '3303', // 公益已过期
  ALREADY_CHECKED_IN_TODAY = '3304', // 今日已打卡
  CHARITY_ALREADY_ENDED = '3305', // 公益已结束
  CHARITY_HAS_PARTICIPANTS = '3306', // 历史错误码：公益已有参与者

  // 活动相关 (37xx)
  ACTIVITY_NOT_FOUND = '3701', // 活动不存在
  ACTIVITY_ALREADY_ENDED = '3702', // 活动已结束
  ACTIVITY_ALREADY_REGISTERED = '3703', // 已报名该活动

  // 走失招领相关 (36xx)
  LOST_FOUND_001 = '3601', // 宠物不存在
  LOST_FOUND_002 = '3602', // 无权操作
  LOST_FOUND_003 = '3603', // 已标记找回
  LOST_FOUND_004 = '3604', // 描述过长
  LOST_FOUND_005 = '3605', // 手机号格式错误
  LOST_FOUND_006 = '3606', // 领养信息不支持标记找回

  // 支付相关 (34xx-35xx)
  PAYMENT_NOT_FOUND = '3101',
  PAYMENT_ALREADY_PAID = '3102',
  PAYMENT_STATUS_INVALID = '3103',
  PAYMENT_EXPIRED = '3104',
  PAYMENT_AMOUNT_INVALID = '3105',
  PAYMENT_CHANNEL_NOT_SUPPORTED = '3106',
  PAYMENT_SIGNATURE_VERIFICATION_FAILED = '3107',
  PAYMENT_CALLBACK_PROCESSING_FAILED = '3108',
  PAYMENT_CREATION_FAILED = '3109',
  PAYMENT_QUERY_FAILED = '3110',
  PAYMENT_CLOSE_FAILED = '3111',

  // 退款相关 (32xx)
  REFUND_AMOUNT_EXCEEDS = '3201',
  REFUND_FAILED = '3202',
  REFUND_STATUS_INVALID = '3203',
  REFUND_NOT_FOUND = '3204',
  REFUND_AMOUNT_INVALID = '3205',

  // ========== 文件相关 (4xxx) ==========
  FILE_NOT_FOUND = '4001',
  FILE_SIZE_EXCEEDED = '4002',
  INVALID_FILE_TYPE = '4003',
  FILE_UPLOAD_FAILED = '4004',
  FILE_DELETE_FAILED = '4005',

  // ========== 系统错误 (5xxx) ==========
  DATABASE_ERROR = '5001',
  SMS_SEND_FAILED = '5002',
  AI_SERVICE_ERROR = '5003',
  EMAIL_SEND_FAILED = '5004',
  NETWORK_ERROR = '5005',
  CONFIGURATION_ERROR = '5006',
}

/**
 * 错误消息映射
 * 提供中文错误消息
 */
export const ErrorMessages: Record<ErrorCode, string> = {
  // 认证相关
  [ErrorCode.UNAUTHORIZED]: '未授权访问',
  [ErrorCode.TOKEN_EXPIRED]: '登录已过期，请重新登录',
  [ErrorCode.INVALID_CREDENTIALS]: '用户名或密码错误',
  [ErrorCode.PHONE_VERIFICATION_FAILED]: '手机验证失败',
  [ErrorCode.SMS_CODE_EXPIRED]: '验证码已过期',
  [ErrorCode.SMS_CODE_INVALID]: '验证码错误',
  [ErrorCode.PERMISSION_DENIED]: '权限不足',
  [ErrorCode.ACCOUNT_LOCKED]: '账户已被锁定',
  [ErrorCode.ACCOUNT_DISABLED]: '账户已被禁用',

  // 资源相关
  [ErrorCode.USER_NOT_FOUND]: '用户不存在',
  [ErrorCode.PET_NOT_FOUND]: '宠物不存在',
  [ErrorCode.APPOINTMENT_NOT_FOUND]: '预约不存在',
  [ErrorCode.DOCTOR_NOT_FOUND]: '医生不存在',
  [ErrorCode.HOSPITAL_NOT_FOUND]: '医院不存在',
  [ErrorCode.DEPARTMENT_NOT_FOUND]: '科室不存在',
  [ErrorCode.SCHEDULE_NOT_FOUND]: '排班不存在',
  [ErrorCode.CHAT_SESSION_NOT_FOUND]: '聊天会话不存在',
  [ErrorCode.PRODUCT_NOT_FOUND]: '商品不存在',
  [ErrorCode.ORDER_NOT_FOUND]: '订单不存在',

  // 业务逻辑
  [ErrorCode.BUSINESS_INVALID_PARAM]: '参数无效',
  [ErrorCode.APPOINTMENT_CONFLICT]: '预约时间冲突',
  [ErrorCode.INSUFFICIENT_BALANCE]: '余额不足',
  [ErrorCode.EXCEED_FREE_MESSAGE_LIMIT]: '已超过免费消息次数',
  [ErrorCode.CHAT_SESSION_EXPIRED]: '聊天会话已过期',
  [ErrorCode.INVALID_APPOINTMENT_TIME]: '预约时间无效',
  [ErrorCode.DOCTOR_NOT_AVAILABLE]: '医生当前不可预约',
  [ErrorCode.APPOINTMENT_CANNOT_CANCEL]: '此预约无法取消',
  [ErrorCode.APPOINTMENT_CANNOT_MODIFY]: '此预约无法修改',
  [ErrorCode.PRODUCT_OUT_OF_STOCK]: '商品库存不足',
  [ErrorCode.INVALID_ORDER_STATUS]: '订单状态无效',
  [ErrorCode.PRODUCT_NOT_ACTIVE]: '商品已下架',
  [ErrorCode.PRODUCT_ALREADY_AUDITED]: '商品已审核，无法重复审核',
  [ErrorCode.BUSINESS_PERMISSION_DENIED]: '权限不足',
  [ErrorCode.COUPON_NOT_FOUND]: '优惠券不存在',
  [ErrorCode.COUPON_EXPIRED]: '优惠券已过期',
  [ErrorCode.COUPON_ALREADY_USED]: '优惠券已使用',
  [ErrorCode.COUPON_NOT_APPLICABLE]: '优惠券不适用',
  [ErrorCode.COUPON_LIMIT_EXCEEDED]: '领取数量已达上限',
  [ErrorCode.ORDER_AMOUNT_TOO_LOW]: '订单金额未达到优惠券使用门槛',
  [ErrorCode.COUPON_OUT_OF_STOCK]: '优惠券已领完',
  [ErrorCode.WITHDRAWAL_DISABLED]: '支付宝提现服务暂不可用',
  [ErrorCode.WITHDRAWAL_AMOUNT_INVALID]: '提现金额无效',
  [ErrorCode.WITHDRAWAL_LIMIT_EXCEEDED]: '提现金额超过限额',
  [ErrorCode.WITHDRAWAL_ACTIVE_EXISTS]: '已有一笔提现正在处理中',
  [ErrorCode.WITHDRAWAL_NOT_FOUND]: '提现记录不存在',
  [ErrorCode.WITHDRAWAL_STATUS_INVALID]: '提现状态不允许当前操作',

  // 公益相关
  [ErrorCode.CHARITY_NOT_FOUND]: '公益不存在',
  [ErrorCode.CHARITY_NOT_ACTIVE]: '公益当前不可参与',
  [ErrorCode.CHARITY_EXPIRED]: '公益已结束',
  [ErrorCode.ALREADY_CHECKED_IN_TODAY]: '您今天已经打过卡了，明天再来吧！',
  [ErrorCode.CHARITY_ALREADY_ENDED]: '公益已结束，无法打卡',
  [ErrorCode.CHARITY_HAS_PARTICIPANTS]: '该公益已有参与者',

  // 活动相关
  [ErrorCode.ACTIVITY_NOT_FOUND]: '活动不存在',
  [ErrorCode.ACTIVITY_ALREADY_ENDED]: '活动已结束',
  [ErrorCode.ACTIVITY_ALREADY_REGISTERED]: '您已报名该活动',

  // 走失招领相关
  [ErrorCode.LOST_FOUND_001]: '宠物不存在或已被删除',
  [ErrorCode.LOST_FOUND_002]: '您没有权限操作此信息',
  [ErrorCode.LOST_FOUND_003]: '该信息已标记为找回，无需重复操作',
  [ErrorCode.LOST_FOUND_004]: '描述信息不能超过500个字符',
  [ErrorCode.LOST_FOUND_005]: '请输入正确的手机号码',
  [ErrorCode.LOST_FOUND_006]: '领养信息不支持标记已找回',

  // 支付相关
  [ErrorCode.PAYMENT_NOT_FOUND]: '支付记录不存在',
  [ErrorCode.PAYMENT_ALREADY_PAID]: '订单已支付',
  [ErrorCode.PAYMENT_STATUS_INVALID]: '支付状态无效',
  [ErrorCode.PAYMENT_EXPIRED]: '支付已过期',
  [ErrorCode.PAYMENT_AMOUNT_INVALID]: '支付金额无效',
  [ErrorCode.PAYMENT_CHANNEL_NOT_SUPPORTED]: '不支持的支付渠道',
  [ErrorCode.PAYMENT_SIGNATURE_VERIFICATION_FAILED]: '支付签名验证失败',
  [ErrorCode.PAYMENT_CALLBACK_PROCESSING_FAILED]: '支付回调处理失败',
  [ErrorCode.PAYMENT_CREATION_FAILED]: '创建支付失败',
  [ErrorCode.PAYMENT_QUERY_FAILED]: '查询支付失败',
  [ErrorCode.PAYMENT_CLOSE_FAILED]: '关闭支付失败',

  // 退款相关
  [ErrorCode.REFUND_AMOUNT_EXCEEDS]: '退款金额超过可退款金额',
  [ErrorCode.REFUND_FAILED]: '退款失败',
  [ErrorCode.REFUND_STATUS_INVALID]: '退款状态无效',
  [ErrorCode.REFUND_NOT_FOUND]: '退款记录不存在',
  [ErrorCode.REFUND_AMOUNT_INVALID]: '退款金额无效',

  // 文件相关
  [ErrorCode.FILE_NOT_FOUND]: '文件不存在',
  [ErrorCode.FILE_SIZE_EXCEEDED]: '文件大小超过限制',
  [ErrorCode.INVALID_FILE_TYPE]: '不支持的文件类型',
  [ErrorCode.FILE_UPLOAD_FAILED]: '文件上传失败',
  [ErrorCode.FILE_DELETE_FAILED]: '文件删除失败',

  // 系统错误
  [ErrorCode.DATABASE_ERROR]: '数据库操作失败',
  [ErrorCode.SMS_SEND_FAILED]: '短信发送失败',
  [ErrorCode.AI_SERVICE_ERROR]: 'AI服务异常',
  [ErrorCode.EMAIL_SEND_FAILED]: '邮件发送失败',
  [ErrorCode.NETWORK_ERROR]: '网络错误',
  [ErrorCode.CONFIGURATION_ERROR]: '系统配置错误',
};

/**
 * 根据错误码获取错误消息
 * @param code 错误码
 * @returns 错误消息
 */
export function getErrorMessage(code: ErrorCode): string {
  return ErrorMessages[code] || '未知错误';
}

/**
 * 创建业务异常的快捷方法
 * @param code 错误码
 * @param customMessage 自定义错误消息（可选）
 * @returns BusinessException
 */
export function createBusinessException(
  code: ErrorCode,
  customMessage?: string,
): BusinessException {
  const message = customMessage || ErrorMessages[code];

  // 根据错误码分类确定 HTTP 状态码
  let status = 400;
  const codePrefix = code.substring(0, 1);

  switch (codePrefix) {
    case '1':
      // 认证错误
      status =
        code === ErrorCode.UNAUTHORIZED || code === ErrorCode.TOKEN_EXPIRED
          ? 401
          : 403;
      break;
    case '2':
      // 资源不存在
      status = 404;
      break;
    case '3':
      // 业务逻辑错误
      status = 400;
      break;
    case '4':
      // 文件错误
      status = 400;
      break;
    case '5':
      // 系统错误
      status = 500;
      break;
  }

  return new BusinessException(message, code, status);
}
