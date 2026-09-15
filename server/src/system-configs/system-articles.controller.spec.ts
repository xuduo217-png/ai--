import 'reflect-metadata'

import { IS_PUBLIC_KEY } from '../auth/decorators/public.decorator'
import { SystemArticlesController } from './system-articles.controller'

describe('SystemArticlesController public metadata', () => {
  /**
   * 新用户首次进入 APP 时需要先读取隐私协议，因此按类型读取接口必须是公开路由。
   */
  it('marks findByType as public for guest privacy agreement access', () => {
    const isPublic = Reflect.getMetadata(
      IS_PUBLIC_KEY,
      SystemArticlesController.prototype.findByType
    )

    expect(isPublic).toBe(true)
  })

  /**
   * 列表读取同样属于系统基础内容，不应要求用户先完成登录。
   */
  it('marks findAll as public for guest system article bootstrap', () => {
    const isPublic = Reflect.getMetadata(
      IS_PUBLIC_KEY,
      SystemArticlesController.prototype.findAll
    )

    expect(isPublic).toBe(true)
  })
})
