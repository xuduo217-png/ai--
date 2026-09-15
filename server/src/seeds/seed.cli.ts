import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { Logger } from '@nestjs/common';
import { SeedService } from './seed.service';

async function bootstrap() {
  const logger = new Logger('SeedCLI');

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['log', 'error', 'warn', 'debug'],
  });

  try {
    const seedService = app.get(SeedService);

    await seedService.runSeeds();

    await app.close();
    process.exit(0);
  } catch (error) {
    logger.error('❌ Error seeding data:', error);
    await app.close();
    process.exit(1);
  }
}

bootstrap();
