import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateProductPendingDto } from './create-product-pending.dto';
import { ProductCondition } from '../entities/product-pending.entity';

const buildPayload = () => ({
  title: '待审核商品',
  description: '商品描述',
  price: 88.5,
  negotiable: false,
  images: ['/uploads/test.jpg'],
  categoryId: 3,
  condition: ProductCondition.NEW,
  shippingFee: 0,
});

describe('CreateProductPendingDto', () => {
  it('defaults stock to 1 when omitted', async () => {
    const dto = plainToInstance(CreateProductPendingDto, buildPayload());
    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
    expect((dto as any).stock).toBe(1);
  });

  it('rejects stock smaller than 1', async () => {
    const dto = plainToInstance(CreateProductPendingDto, {
      ...buildPayload(),
      stock: 0,
    });
    const errors = await validate(dto);
    const stockError = errors.find((error) => error.property === 'stock');

    expect(stockError?.constraints).toEqual(
      expect.objectContaining({
        min: expect.stringContaining('1'),
      }),
    );
  });
});
