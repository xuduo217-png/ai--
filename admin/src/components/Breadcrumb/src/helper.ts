import { pathResolve } from '@/utils/routerHelper'

export const filterBreadcrumb = (
  routes: AppRouteRecordRaw[],
  parentPath = ''
): AppRouteRecordRaw[] => {
  const res: AppRouteRecordRaw[] = []

  for (const route of routes) {
    const meta = route?.meta
    // 修复：当 meta 为 undefined 时跳过检查，避免访问 undefined.hidden 报错
    if (meta?.hidden && !meta?.canTo) {
      continue
    }

    const data: AppRouteRecordRaw =
      !meta?.alwaysShow && route.children?.length === 1
        ? { ...route.children[0], path: pathResolve(route.path, route.children[0].path) }
        : { ...route }

    data.path = pathResolve(parentPath, data.path)

    if (data.children) {
      data.children = filterBreadcrumb(data.children, data.path)
    }
    if (data) {
      res.push(data)
    }
  }
  return res
}
