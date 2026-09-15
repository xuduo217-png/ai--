import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';

const projectRoot = join(__dirname, '..');
const productionEntry = 'dist/src/main.js';

const readProjectFile = (fileName: string) =>
  readFileSync(join(projectRoot, fileName), 'utf8');

describe('AppController', () => {
  let appController: AppController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [AppService],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(appController.getHello()).toBe('Hello World!');
    });
  });
});

describe('production entry configuration', () => {
  it('keeps npm, PM2, and deploy script aligned to the built main file', () => {
    const packageJson = JSON.parse(readProjectFile('package.json'));
    const ecosystemConfig = readProjectFile('ecosystem.config.js');
    const deployScript = readProjectFile('deploy.sh');

    expect(packageJson.scripts['start:prod']).toBe(`node ${productionEntry}`);
    expect(ecosystemConfig).toContain(`script: './${productionEntry}'`);
    expect(deployScript).toContain(`if [ ! -f "${productionEntry}" ]; then`);
    expect(deployScript).toContain(`构建产物: ${productionEntry}`);
  });
});
