import { BadRequestException, Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SensitiveWord, WordSeverity } from './entities/sensitive-word.entity';

/**
 * 检测到的敏感词信息
 */
interface DetectedWord {
  word: string; // 敏感词
  severity: WordSeverity; // 严重等级
  category?: string; // 分类
  replacement?: string; // 替换词
  startIndex: number; // 在文本中的起始位置
  endIndex: number; // 在文本中的结束位置
}

/**
 * 敏感词处理结果
 */
interface ProcessResult {
  action: 'REJECT' | 'REPLACE' | 'REVIEW'; // 操作类型
  text?: string; // 替换后的文本（仅 REPLACE 时有值）
  words: DetectedWord[]; // 检测到的敏感词列表
}

/**
 * 敏感词服务
 * 提供敏感词检测、替换等功能
 */
@Injectable()
export class SensitiveWordService implements OnModuleInit {
  constructor(
    @InjectRepository(SensitiveWord)
    private readonly sensitiveWordRepository: Repository<SensitiveWord>,
  ) {}

  private sensitiveWords: SensitiveWord[] = [];
  private lastCacheUpdate: Date | null = null;
  private readonly CACHE_TTL = 5 * 60 * 1000; // 5 分钟缓存

  /**
   * 模块初始化时加载敏感词
   */
  async onModuleInit() {
    await this.loadWords();
  }

  /**
   * 从数据库加载所有启用的敏感词
   */
  async loadWords() {
    this.sensitiveWords = await this.sensitiveWordRepository.find({
      where: { isActive: true },
    });

    // 按词长降序排序（优先匹配长词）
    this.sensitiveWords.sort((a, b) => b.word.length - a.word.length);

    // 更新缓存时间
    this.lastCacheUpdate = new Date();
  }

  /**
   * 检查缓存是否过期
   */
  private isCacheExpired(): boolean {
    if (!this.lastCacheUpdate) return true;
    const now = new Date();
    return now.getTime() - this.lastCacheUpdate.getTime() > this.CACHE_TTL;
  }

  /**
   * 获取敏感词列表（自动刷新缓存）
   */
  private async getWords(): Promise<SensitiveWord[]> {
    if (this.isCacheExpired() || this.sensitiveWords.length === 0) {
      await this.loadWords();
    }
    return this.sensitiveWords;
  }

  /**
   * 检测文本中的敏感词
   * 时间复杂度：O(n * m)，n 为文本长度，m 为敏感词数量
   * 后续可优化为 AC 自动机算法：O(n)
   */
  async detect(text: string): Promise<DetectedWord[]> {
    const detected: DetectedWord[] = [];
    const lowerText = text.toLowerCase();

    const words = await this.getWords();

    for (const word of words) {
      const lowerWord = word.word.toLowerCase();
      let index = 0;

      // 查找所有出现位置
      while ((index = lowerText.indexOf(lowerWord, index)) !== -1) {
        detected.push({
          word: word.word,
          severity: word.severity,
          category: word.category,
          replacement: word.replacement,
          startIndex: index,
          endIndex: index + word.word.length,
        });

        index += word.word.length;
      }
    }

    // 按起始位置排序
    return detected.sort((a, b) => a.startIndex - b.startIndex);
  }

  /**
   * 处理敏感词
   * 根据严重等级：拒绝/替换/标记
   */
  async process(text: string): Promise<ProcessResult> {
    const detectedWords = await this.detect(text);
    if (detectedWords.length === 0) {
      return { action: 'REVIEW', words: [] };
    }

    // 检查是否有高危敏感词
    const highSeverityWords = detectedWords.filter(
      (w) => w.severity === WordSeverity.HIGH,
    );
    if (highSeverityWords.length > 0) {
      return {
        action: 'REJECT',
        words: highSeverityWords,
      };
    }

    // 检查是否有中危敏感词
    const mediumWords = detectedWords.filter(
      (w) => w.severity === WordSeverity.MEDIUM,
    );
    if (mediumWords.length > 0) {
      const replacedText = this.replaceWords(text, mediumWords);
      return {
        action: 'REPLACE',
        text: replacedText,
        words: mediumWords,
      };
    }

    // 低危敏感词，进入人工审核
    return {
      action: 'REVIEW',
      words: detectedWords,
    };
  }

  /**
   * 校验昵称是否包含任一启用的敏感词。
   * 昵称场景不区分敏感等级，命中后统一拒绝保存。
   */
  async assertNicknameAllowed(nickname: string): Promise<void> {
    const normalizedNickname = this.normalizeForMatch(nickname);
    if (!normalizedNickname) {
      return;
    }

    const words = await this.getWords();
    const containsSensitiveWord = words.some((item) => {
      const normalizedWord = this.normalizeForMatch(item.word);
      return (
        normalizedWord.length > 0 && normalizedNickname.includes(normalizedWord)
      );
    });

    if (containsSensitiveWord) {
      throw new BadRequestException('昵称包含敏感词，请修改后重试');
    }
  }

  private normalizeForMatch(value: string): string {
    return value.normalize('NFKC').toLowerCase();
  }

  /**
   * 替换敏感词
   */
  private replaceWords(text: string, words: DetectedWord[]): string {
    let result = text;

    // 按位置倒序替换（避免索引变化）
    const sortedWords = [...words].sort(
      (a, b) => b.startIndex - a.startIndex,
    );

    for (const word of sortedWords) {
      const replacement = word.replacement || '*'.repeat(word.word.length);
      result =
        result.substring(0, word.startIndex) +
        replacement +
        result.substring(word.endIndex);
    }

    return result;
  }

  /**
   * 创建敏感词
   */
  async create(dto: {
    word: string;
    severity?: WordSeverity;
    replacement?: string;
    category?: string;
    isActive?: boolean;
  }): Promise<SensitiveWord> {
    const word = this.sensitiveWordRepository.create(dto);
    const saved = await this.sensitiveWordRepository.save(word);

    // 重新加载敏感词缓存
    await this.loadWords();

    return saved;
  }

  /**
   * 更新敏感词
   */
  async update(
    id: number,
    dto: {
      word?: string;
      severity?: WordSeverity;
      replacement?: string;
      category?: string;
      isActive?: boolean;
    },
  ): Promise<SensitiveWord> {
    await this.sensitiveWordRepository.update(id, dto);
    const updated = await this.sensitiveWordRepository.findOne({ where: { id } });

    if (updated) {
      // 重新加载敏感词缓存
      await this.loadWords();
    }

    return updated;
  }

  /**
   * 删除敏感词
   */
  async delete(id: number): Promise<void> {
    await this.sensitiveWordRepository.delete(id);

    // 重新加载敏感词缓存
    await this.loadWords();
  }

  /**
   * 批量导入敏感词
   */
  async batchImport(words: string[]): Promise<{ created: number; skipped: number }> {
    let created = 0;
    let skipped = 0;

    for (const word of words) {
      const trimmed = word.trim();
      if (!trimmed) continue;

      // 检查是否已存在
      const exists = await this.sensitiveWordRepository.findOne({
        where: { word: trimmed },
      });

      if (exists) {
        skipped++;
      } else {
        await this.sensitiveWordRepository.save({
          word: trimmed,
          severity: WordSeverity.LOW,
          isActive: true,
        });
        created++;
      }
    }

    // 重新加载敏感词缓存
    await this.loadWords();

    return { created, skipped };
  }

  /**
   * 获取所有敏感词
   */
  async findAll(): Promise<SensitiveWord[]> {
    return this.sensitiveWordRepository.find({
      order: { severity: 'DESC', createdAt: 'DESC' },
    });
  }
}
