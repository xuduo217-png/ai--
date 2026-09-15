import { Injectable } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { SystemArticle, ArticleType } from './entities/system-article.entity'
import { UpdateSystemArticleDto } from './dto/update-article.dto'

/**
 * 系统文章服务
 */
@Injectable()
export class SystemArticlesService {
  constructor(
    @InjectRepository(SystemArticle)
    private articleRepository: Repository<SystemArticle>
  ) {}

  /**
   * 获取所有文章
   */
  async findAll(): Promise<SystemArticle[]> {
    return await this.articleRepository.find({
      order: { id: 'ASC' }
    })
  }

  /**
   * 根据类型获取文章
   * 如果文章不存在，返回 null
   */
  async findByType(type: ArticleType): Promise<SystemArticle | null> {
    const article = await this.articleRepository.findOne({
      where: { type }
    })

    return article || null
  }

  /**
   * 更新文章内容
   * 如果文章不存在，则创建新文章
   */
  async update(type: ArticleType, updateDto: UpdateSystemArticleDto): Promise<SystemArticle> {
    let article = await this.articleRepository.findOne({
      where: { type }
    })

    // 如果文章不存在，创建新文章
    if (!article) {
      article = this.articleRepository.create({
        type,
        content: updateDto.content
      })
    } else {
      // 更新现有文章
      article.content = updateDto.content
    }

    return await this.articleRepository.save(article)
  }

  /**
   * 初始化文章（种子数据）
   */
  async initializeArticles(): Promise<SystemArticle[]> {
    // 检查是否已初始化
    const existingCount = await this.articleRepository.count()
    if (existingCount > 0) {
      return await this.findAll()
    }

    // 创建三条默认文章
    const articles = [
      {
        type: ArticleType.ABOUT_US,
        content: '<h1>关于我们</h1><p>请在此填写关于我们内容...</p>'
      },
      {
        type: ArticleType.PRIVACY,
        content: '<h1>隐私协议</h1><p>请在此填写隐私协议内容...</p>'
      },
      {
        type: ArticleType.USER_AGREEMENT,
        content: '<h1>用户协议</h1><p>请在此填写用户协议内容...</p>'
      }
    ]

    return await this.articleRepository.save(articles)
  }
}
