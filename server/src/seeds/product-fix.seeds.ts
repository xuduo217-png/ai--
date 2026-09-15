import { DataSource } from 'typeorm';
import { Logger } from '@nestjs/common';
import { Product } from '../shop/entities/product.entity';
import { ProductSku, SkuStatus } from '../shop/entities/product-sku.entity';

/**
 * 修复单规格商品数据：为没有 SKU 的商品创建默认 SKU
 *
 * 使用方法：
 * 1. 将此函数添加到 seed.service.ts 的 runSeeds() 方法中
 * 2. 运行 npm run seed
 * 3. 或者直接调用这个函数
 */
export const fixSingleSkuProducts = async (dataSource: DataSource) => {
  const logger = new Logger('ProductFix');

  try {
    logger.log('🔧 开始修复单规格商品数据...');

    // 查询所有商品
    const productRepository = dataSource.getRepository(Product);
    const skuRepository = dataSource.getRepository(ProductSku);

    const products = await productRepository.find();
    logger.log(`找到 ${products.length} 个商品`);

    let fixedCount = 0;
    let skippedCount = 0;

    for (const product of products) {
      // 查询商品的 SKU
      const skus = await skuRepository.find({
        where: { productId: product.id },
      });

      if (skus.length === 0) {
        // 没有 SKU，创建默认 SKU
        const defaultSku = skuRepository.create({
          name: '默认规格',
          specs: {},
          price: product.price,
          originalPrice: null,
          stock: product.stock,
          status: SkuStatus.ACTIVE,
          image: product.image || null,
          skuCode: null,
          productId: product.id,
        });

        await skuRepository.save(defaultSku);
        fixedCount++;
        logger.log(`✅ 商品 "${product.name}" (ID: ${product.id}) 已创建默认 SKU`);
      } else {
        skippedCount++;
      }
    }

    logger.log(`\n✅ 修复完成！`);
    logger.log(`   - 修复的商品数量: ${fixedCount}`);
    logger.log(`   - 跳过的商品数量: ${skippedCount}`);
  } catch (error) {
    logger.error('❌ 修复失败:', error);
    throw error;
  }
};
