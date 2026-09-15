import { Exclude } from 'class-transformer'
import { serializeShopResponse } from './shop.serialization'

describe('serializeShopResponse', () => {
  it('removes excluded password fields from nested shop relations', () => {
    class SerializableUser {
      id!: number
      username!: string
      @Exclude()
      password!: string
    }

    const payload = {
      product: {
        id: 1,
        name: '测试商品',
        publisher: Object.assign(new SerializableUser(), {
          id: 8,
          username: 'publisher',
          password: 'hashed-password',
        }),
      },
      order: {
        id: 2,
        orderNo: 'ORD-1',
        user: Object.assign(new SerializableUser(), {
          id: 9,
          username: 'buyer',
          password: 'hashed-password',
        }),
      },
    }

    const result = serializeShopResponse(payload)

    expect(result).toEqual({
      product: {
        id: 1,
        name: '测试商品',
        publisher: {
          id: 8,
          username: 'publisher',
        },
      },
      order: {
        id: 2,
        orderNo: 'ORD-1',
        user: {
          id: 9,
          username: 'buyer',
        },
      },
    })
  })
})
