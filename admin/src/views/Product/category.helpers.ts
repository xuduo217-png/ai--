import type { ProductCategory } from '@/api-new/shop'

export const MISSING_SECOND_LEVEL_CATEGORY_TEXT = '未创建二级分类，无法在新建商品及APP端展示'

type CategoryWarningTarget = {
  parentId?: ProductCategory['parentId'] | null
  children?: Array<unknown>
}

export const shouldShowMissingSecondLevelCategoryWarning = (category: CategoryWarningTarget) => {
  const isTopLevelCategory = category.parentId == null
  const hasSecondLevelCategories = Boolean(category.children?.length)

  return isTopLevelCategory && !hasSecondLevelCategories
}
