import 'reflect-metadata';

jest.mock('uuid', () => ({
  v4: () => 'MOCK-ORDER-UUID',
}));

import { AdminProductController } from './admin-product.controller';
import { IS_PUBLIC_KEY } from '../auth/decorators/public.decorator';
import { SecondHandProductController } from './second-hand-product.controller';
import { ShopController } from './shop.controller';

describe('AdminProductController roles metadata', () => {
  it('allows hospital admins on the legacy admin/shop pending-products endpoints', () => {
    const roles = Reflect.getMetadata('roles', AdminProductController);

    expect(roles).toContain('SUPER_ADMIN');
    expect(roles).toContain('STAFF');
    expect(roles).toContain('HOSPITAL_ADMIN');
  });
});

describe('Shop guest access metadata', () => {
  it.each([
    ['product list', ShopController.prototype, 'findAllProducts'],
    ['popular products', ShopController.prototype, 'getPopularProducts'],
    ['product detail', ShopController.prototype, 'findOneProduct'],
    ['legacy product detail', ShopController.prototype, 'findOneProductDetail'],
    ['product skus', ShopController.prototype, 'getProductSkus'],
    [
      'second-hand categories',
      SecondHandProductController.prototype,
      'getSecondHandCategories',
    ],
    [
      'second-hand product detail',
      SecondHandProductController.prototype,
      'getProductDetail',
    ],
  ])('marks %s as public', (_label, controller, methodName) => {
    const handler = (controller as unknown as Record<string, object>)[methodName];

    expect(Reflect.getMetadata(IS_PUBLIC_KEY, handler)).toBe(true);
  });
});
