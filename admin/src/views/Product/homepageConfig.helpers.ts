import type {
  MallHomepageBannerActionType,
  MallHomepageBannerItem,
  ProductCategory
} from '../../api-new/shop'

export interface HotProductSelection {
  productId: number
  sortOrder: number
}

const ACTION_TYPE_PRODUCT: MallHomepageBannerActionType = 'product'

const normalizeProductId = (value: unknown): number | undefined => {
  const productId = Number(value)
  if (!Number.isInteger(productId) || productId <= 0) {
    return undefined
  }

  return productId
}

const normalizeSortOrder = (value: unknown, fallback: number): number => {
  const sortOrder = Number(value)
  if (!Number.isFinite(sortOrder)) {
    return fallback
  }

  return sortOrder
}

export const normalizeSelectedProductIds = (productIds: unknown[]): number[] => {
  const normalizedIds: number[] = []
  const seen = new Set<number>()

  for (const productId of productIds) {
    const normalizedId = normalizeProductId(productId)
    if (!normalizedId || seen.has(normalizedId)) {
      continue
    }

    seen.add(normalizedId)
    normalizedIds.push(normalizedId)
  }

  return normalizedIds
}

export const findCategoryNameById = (
  categories: ProductCategory[],
  categoryId?: number
): string => {
  if (!categoryId) {
    return ''
  }

  for (const category of categories) {
    if (category.id === categoryId) {
      return category.name
    }

    if (Array.isArray(category.children) && category.children.length > 0) {
      const childName = findCategoryNameById(category.children, categoryId)
      if (childName) {
        return childName
      }
    }
  }

  return ''
}

export const createBannerItem = (
  index: number,
  uniqueKey: string | number = index
): MallHomepageBannerItem => {
  return {
    id: `local-banner-${uniqueKey}`,
    imageUrl: '',
    actionType: ACTION_TYPE_PRODUCT,
    productId: undefined,
    sortOrder: index
  }
}

export const normalizeBannerItem = (
  banner: MallHomepageBannerItem,
  index: number
): MallHomepageBannerItem => {
  return {
    id: banner.id || `banner-${index + 1}`,
    imageUrl: banner.imageUrl || '',
    actionType: ACTION_TYPE_PRODUCT,
    productId: normalizeProductId(banner.productId),
    sortOrder: normalizeSortOrder(banner.sortOrder, index)
  }
}

export const createHotProductSelections = (productIds: unknown[]): HotProductSelection[] => {
  return normalizeSelectedProductIds(productIds).map((productId, index) => ({
    productId,
    sortOrder: index + 1
  }))
}

export const mergeHotProductSelections = (
  currentSelections: HotProductSelection[],
  nextProductIds: unknown[]
): HotProductSelection[] => {
  const normalizedIds = normalizeSelectedProductIds(nextProductIds)
  const currentSelectionMap = new Map(
    currentSelections
      .map((selection, index) => {
        const productId = normalizeProductId(selection.productId)
        if (!productId) {
          return null
        }

        return [
          productId,
          {
            productId,
            sortOrder: normalizeSortOrder(selection.sortOrder, index + 1)
          }
        ] as const
      })
      .filter((selection): selection is readonly [number, HotProductSelection] =>
        Boolean(selection)
      )
  )

  let nextSortOrder =
    Math.max(0, ...Array.from(currentSelectionMap.values(), (selection) => selection.sortOrder)) + 1

  return normalizedIds.map((productId) => {
    const existingSelection = currentSelectionMap.get(productId)
    if (existingSelection) {
      return existingSelection
    }

    const selection = {
      productId,
      sortOrder: nextSortOrder
    }
    nextSortOrder += 1
    return selection
  })
}

export const sortHotProductSelections = (
  selections: HotProductSelection[]
): HotProductSelection[] => {
  return selections
    .map((selection, index) => ({
      productId: normalizeProductId(selection.productId),
      sortOrder: normalizeSortOrder(selection.sortOrder, index + 1),
      index
    }))
    .filter(
      (
        selection
      ): selection is {
        productId: number
        sortOrder: number
        index: number
      } => Boolean(selection.productId)
    )
    .sort((left, right) => {
      if (left.sortOrder !== right.sortOrder) {
        return left.sortOrder - right.sortOrder
      }

      return left.index - right.index
    })
    .reduce<HotProductSelection[]>((result, selection) => {
      if (result.some((item) => item.productId === selection.productId)) {
        return result
      }

      result.push({
        productId: selection.productId,
        sortOrder: selection.sortOrder
      })
      return result
    }, [])
}

export const serializeHotProductIds = (selections: HotProductSelection[]): number[] => {
  return sortHotProductSelections(selections).map((selection) => selection.productId)
}
