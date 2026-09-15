import type { App } from 'vue'
import { Icon } from './Icon'
import { Permission } from './Permission'
import { BaseButton } from './Button'
import { ImageUpload } from './ImageUpload'

export const setupGlobCom = (app: App<Element>): void => {
  app.component('Icon', Icon)
  app.component('Permission', Permission)
  app.component('BaseButton', BaseButton)
  app.component('ImageUpload', ImageUpload)
}
