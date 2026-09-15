/**
 * 金额处理工具
 * 解决 JavaScript 浮点数精度问题
 *
 * 原理：所有金额计算都转换为整数（分）进行，避免浮点数精度问题
 * 例如：0.1 + 0.2 = 0.30000000000000004
 * 使用本工具：add(0.1, 0.2) = 0.3
 */

/**
 * 金额精度：2位小数（分）
 */
const PRECISION = 100;

/**
 * 将金额转换为整数（分）
 * @param amount 金额（元）
 * @returns 整数（分）
 */
export function toCents(amount: number | string): number {
  if (amount === null || amount === undefined) return 0;
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  return Math.round(num * PRECISION);
}

/**
 * 将整数（分）转换为金额（元）
 * @param cents 整数（分）
 * @returns 金额（元）
 */
export function toYuan(cents: number): number {
  return cents / PRECISION;
}

/**
 * 金额加法（避免浮点数精度问题）
 * @param a 金额1
 * @param b 金额2
 * @returns 结果
 */
export function add(a: number | string, b: number | string): number {
  return toYuan(toCents(a) + toCents(b));
}

/**
 * 金额减法（避免浮点数精度问题）
 * @param a 金额1
 * @param b 金额2
 * @returns 结果
 */
export function subtract(a: number | string, b: number | string): number {
  return toYuan(toCents(a) - toCents(b));
}

/**
 * 金额乘法（避免浮点数精度问题）
 * @param amount 金额
 * @param multiplier 乘数
 * @returns 结果
 */
export function multiply(amount: number | string, multiplier: number): number {
  return toYuan(Math.round(toCents(amount) * multiplier));
}

/**
 * 金额除法（避免浮点数精度问题）
 * @param amount 金额
 * @param divisor 除数
 * @returns 结果
 */
export function divide(amount: number | string, divisor: number): number {
  if (divisor === 0) return 0;
  return toYuan(Math.round(toCents(amount) / divisor));
}

/**
 * 比较两个金额是否相等
 * @param a 金额1
 * @param b 金额2
 * @returns 是否相等
 */
export function equals(a: number | string, b: number | string): boolean {
  return toCents(a) === toCents(b);
}

/**
 * 比较金额大小
 * @param a 金额1
 * @param b 金额2
 * @returns a > b 返回 1，a < b 返回 -1，相等返回 0
 */
export function compare(a: number | string, b: number | string): number {
  const centsA = toCents(a);
  const centsB = toCents(b);
  if (centsA > centsB) return 1;
  if (centsA < centsB) return -1;
  return 0;
}

/**
 * 格式化金额显示
 * @param amount 金额
 * @param decimals 小数位数
 * @returns 格式化后的字符串
 */
export function format(amount: number | string, decimals: number = 2): string {
  return toYuan(toCents(amount)).toFixed(decimals);
}

/**
 * 安全转换为数字（处理 decimal 类型返回的字符串）
 * @param value 数据库返回的值
 * @returns 数字
 */
export function toNumber(value: number | string): number {
  if (typeof value === 'number') return value;
  return parseFloat(value) || 0;
}

/**
 * 累加金额数组
 * @param amounts 金额数组
 * @returns 总和
 */
export function sum(amounts: (number | string)[]): number {
  let totalCents = 0;
  for (const amount of amounts) {
    totalCents += toCents(amount);
  }
  return toYuan(totalCents);
}
