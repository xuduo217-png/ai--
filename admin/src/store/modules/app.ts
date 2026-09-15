import { defineStore } from 'pinia'
import { store } from '../index'
import { setCssVar, humpToUnderline } from '@/utils'
import { colorIsDark, hexToRGB, lighten, mix } from '@/utils/color'
import { ElMessage, ComponentSize } from 'element-plus'
import { useCssVar } from '@vueuse/core'
import { unref } from 'vue'
import { useDark } from '@vueuse/core'

interface AppState {
  breadcrumb: boolean
  breadcrumbIcon: boolean
  collapse: boolean
  uniqueOpened: boolean
  hamburger: boolean
  screenfull: boolean
  size: boolean
  locale: boolean
  tagsView: boolean
  tagsViewIcon: boolean
  logo: boolean
  fixedHeader: boolean
  greyMode: boolean
  dynamicRouter: boolean
  serverDynamicRouter: boolean
  pageLoading: boolean
  layout: LayoutType
  title: string
  isDark: boolean
  currentSize: ComponentSize
  sizeMap: ComponentSize[]
  mobile: boolean
  footer: boolean
  theme: ThemeTypes
  fixedMenu: boolean
}

export const useAppStore = defineStore('app', {
  state: (): AppState => {
    return {
      // 面包屑
      breadcrumb: true,
      // 面包屑图标
      breadcrumbIcon: true,
      // 菜单折叠状态
      collapse: false,
      // 折叠图标
      hamburger: true,
      // 全屏图标
      screenfull: true,
      // 尺寸图标
      size: false,
      // 多语言图标
      locale: false,
      // 标签页
      tagsView: false,
      // 标签页图标
      tagsViewIcon: false,
      // logo
      logo: true,
      // 菜单手风琴
      uniqueOpened: false,
      // 固定header
      fixedHeader: true,
      // 页脚
      footer: false,
      // 灰色模式
      greyMode: false,
      // 动态路由开关
      dynamicRouter: false,
      // 服务端动态路由开关
      serverDynamicRouter: false,
      // 页面切换加载态
      pageLoading: false,
      // layout布局
      layout: 'classic',
      // 页面标题
      title: 'Pet Hospitals Admin',
      // 暗黑模式
      isDark: false,
      // 组件尺寸
      currentSize: 'default',
      // 允许的组件尺寸列表
      sizeMap: ['default', 'small', 'large'],
      // 移动端布局标记
      mobile: false,
      // 主题相关
      theme: {
        // 主题色
        elColorPrimary: '#409eff',
        // 左侧菜单边框颜色
        leftMenuBorderColor: '#eee',
        // 左侧菜单背景颜色
        leftMenuBgColor: '#ffffff',
        // 左侧菜单浅色背景颜色
        leftMenuBgLightColor: '#ffffff',
        // 左侧菜单选中背景颜色
        leftMenuBgActiveColor: 'RGBA(64,158,255,0.1)',
        // 左侧菜单收起选中背景颜色
        leftMenuCollapseBgActiveColor: 'RGBA(64,158,255,0.1)',
        // 左侧菜单字体颜色
        leftMenuTextColor: '#333',
        // 左侧菜单选中字体颜色
        leftMenuTextActiveColor: 'var(--el-color-primary)',
        // logo字体颜色
        logoTitleTextColor: 'inherit',
        // logo边框颜色
        logoBorderColor: '#eee',
        // 头部背景颜色
        topHeaderBgColor: '#ffffff',
        // 头部字体颜色
        topHeaderTextColor: 'inherit',
        // 头部悬停颜色
        topHeaderHoverColor: '#f6f6f6',
        // 头部边框颜色
        topToolBorderColor: '#eee'
      },
      // 固定菜单
      fixedMenu: false
    }
  },
  getters: {
    getBreadcrumb(): boolean {
      return this.breadcrumb
    },
    getBreadcrumbIcon(): boolean {
      return this.breadcrumbIcon
    },
    getCollapse(): boolean {
      return this.collapse
    },
    getUniqueOpened(): boolean {
      return this.uniqueOpened
    },
    getHamburger(): boolean {
      return this.hamburger
    },
    getScreenfull(): boolean {
      return this.screenfull
    },
    getSize(): boolean {
      return this.size
    },
    getLocale(): boolean {
      return this.locale
    },
    getTagsView(): boolean {
      return this.tagsView
    },
    getTagsViewIcon(): boolean {
      return this.tagsViewIcon
    },
    getLogo(): boolean {
      return this.logo
    },
    getFixedHeader(): boolean {
      return this.fixedHeader
    },
    getGreyMode(): boolean {
      return this.greyMode
    },
    getDynamicRouter(): boolean {
      return this.dynamicRouter
    },
    getServerDynamicRouter(): boolean {
      return this.serverDynamicRouter
    },
    getFixedMenu(): boolean {
      return this.fixedMenu
    },
    getPageLoading(): boolean {
      return this.pageLoading
    },
    getLayout(): LayoutType {
      return this.layout
    },
    getTitle(): string {
      return this.title
    },
    getIsDark(): boolean {
      return this.isDark
    },
    getCurrentSize(): ComponentSize {
      return this.currentSize
    },
    getSizeMap(): ComponentSize[] {
      return this.sizeMap
    },
    getMobile(): boolean {
      return this.mobile
    },
    getTheme(): ThemeTypes {
      return this.theme
    },
    getFooter(): boolean {
      return this.footer
    }
  },
  actions: {
    setBreadcrumb(breadcrumb: boolean) {
      this.breadcrumb = breadcrumb
    },
    setBreadcrumbIcon(breadcrumbIcon: boolean) {
      this.breadcrumbIcon = breadcrumbIcon
    },
    setCollapse(collapse: boolean) {
      this.collapse = collapse
    },
    setUniqueOpened(uniqueOpened: boolean) {
      this.uniqueOpened = uniqueOpened
    },
    setHamburger(hamburger: boolean) {
      this.hamburger = hamburger
    },
    setScreenfull(screenfull: boolean) {
      this.screenfull = screenfull
    },
    setSize(size: boolean) {
      this.size = size
    },
    setLocale(locale: boolean) {
      this.locale = locale
    },
    setTagsView(tagsView: boolean) {
      this.tagsView = tagsView
    },
    setTagsViewIcon(tagsViewIcon: boolean) {
      this.tagsViewIcon = tagsViewIcon
    },
    setLogo(logo: boolean) {
      this.logo = logo
    },
    setFixedHeader(fixedHeader: boolean) {
      this.fixedHeader = fixedHeader
    },
    setGreyMode(greyMode: boolean) {
      this.greyMode = greyMode
    },
    setDynamicRouter(dynamicRouter: boolean) {
      this.dynamicRouter = dynamicRouter
    },
    setServerDynamicRouter(serverDynamicRouter: boolean) {
      this.serverDynamicRouter = serverDynamicRouter
    },
    setFixedMenu(fixedMenu: boolean) {
      this.fixedMenu = fixedMenu
    },
    setPageLoading(pageLoading: boolean) {
      this.pageLoading = pageLoading
    },
    setLayout(layout: LayoutType) {
      if (this.mobile && layout !== 'classic') {
        ElMessage.warning('移动端模式下不支持切换其它布局')
        return
      }
      this.layout = layout
    },
    setTitle(title: string) {
      this.title = title
    },
    setIsDark(isDark: boolean) {
      this.isDark = isDark
      if (this.isDark) {
        document.documentElement.classList.add('dark')
        document.documentElement.classList.remove('light')
      } else {
        document.documentElement.classList.add('light')
        document.documentElement.classList.remove('dark')
      }
      this.setPrimaryLight()
    },
    setCurrentSize(currentSize: ComponentSize) {
      this.currentSize = currentSize
    },
    setMobile(mobile: boolean) {
      this.mobile = mobile
    },
    setTheme(theme: ThemeTypes) {
      this.theme = Object.assign(this.theme, theme)
    },
    setCssVarTheme() {
      for (const key in this.theme) {
        setCssVar(`--${humpToUnderline(key)}`, this.theme[key])
      }
      this.setPrimaryLight()
    },
    setFooter(footer: boolean) {
      this.footer = footer
    },
    setPrimaryLight() {
      if (this.theme.elColorPrimary) {
        const elColorPrimary = this.theme.elColorPrimary
        const color = this.isDark ? '#000000' : '#ffffff'
        const lightList = [3, 5, 7, 8, 9]
        lightList.forEach((v) => {
          setCssVar(`--el-color-primary-light-${v}`, mix(color, elColorPrimary, v / 10))
        })
        setCssVar(`--el-color-primary-dark-2`, mix(color, elColorPrimary, 0.2))
      }
    },
    setMenuTheme(color: string) {
      const primaryColor = useCssVar('--el-color-primary', document.documentElement)
      const isDarkColor = colorIsDark(color)
      const theme: Recordable = {
        // 左侧菜单边框颜色
        leftMenuBorderColor: isDarkColor ? 'inherit' : '#eee',
        // 左侧菜单背景颜色
        leftMenuBgColor: color,
        // 左侧菜单浅色背景颜色
        leftMenuBgLightColor: isDarkColor ? lighten(color!, 6) : color,
        // 左侧菜单选中背景颜色
        leftMenuBgActiveColor: isDarkColor
          ? 'var(--el-color-primary)'
          : hexToRGB(unref(primaryColor) as string, 0.1),
        // 左侧菜单收起选中背景颜色
        leftMenuCollapseBgActiveColor: isDarkColor
          ? 'var(--el-color-primary)'
          : hexToRGB(unref(primaryColor) as string, 0.1),
        // 左侧菜单字体颜色
        leftMenuTextColor: isDarkColor ? '#bfcbd9' : '#333',
        // 左侧菜单选中字体颜色
        leftMenuTextActiveColor: isDarkColor ? '#fff' : 'var(--el-color-primary)',
        // logo字体颜色
        logoTitleTextColor: isDarkColor ? '#fff' : 'inherit',
        // logo边框颜色
        logoBorderColor: isDarkColor ? color : '#eee'
      }
      this.setTheme(theme)
      this.setCssVarTheme()
    },
    setHeaderTheme(color: string) {
      const isDarkColor = colorIsDark(color)
      const textColor = isDarkColor ? '#fff' : 'inherit'
      const textHoverColor = isDarkColor ? lighten(color!, 6) : '#f6f6f6'
      const topToolBorderColor = isDarkColor ? color : '#eee'
      setCssVar('--top-header-bg-color', color)
      setCssVar('--top-header-text-color', textColor)
      setCssVar('--top-header-hover-color', textHoverColor)
      this.setTheme({
        topHeaderBgColor: color,
        topHeaderTextColor: textColor,
        topHeaderHoverColor: textHoverColor,
        topToolBorderColor
      })
      if (this.getLayout === 'top') {
        this.setMenuTheme(color)
      }
    },
    initTheme() {
      const isDark = useDark({
        valueDark: 'dark',
        valueLight: 'light'
      })
      isDark.value = this.getIsDark
      const newTitle = import.meta.env.VITE_APP_TITLE
      newTitle !== this.getTitle && this.setTitle(newTitle)
    }
  },
  persist: true
})

export const useAppStoreWithOut = () => {
  return useAppStore(store)
}
