import { instanceToPlain } from 'class-transformer'

/**
 * 将商城接口返回值转换为 plain object，确保实体上的 @Exclude() 在嵌套关系里生效。
 */
export const serializeShopResponse = <T>(value: T): T => {
  return instanceToPlain(value) as T
}
