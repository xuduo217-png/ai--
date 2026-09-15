import { DataSource } from 'typeorm'
import { ArticleType, SystemArticle } from '../entities/system-article.entity'

/**
 * 初始化系统文章种子数据
 */
export const seedSystemArticles = async (dataSource: DataSource) => {
  const articleRepository = dataSource.getRepository(SystemArticle)

  // 检查是否已初始化
  const existingCount = await articleRepository.count()
  if (existingCount > 0) {
    console.log('✅ 系统文章已初始化，跳过')
    return
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

  await articleRepository.save(articles)
  console.log('✅ 系统文章初始化完成（3条记录）')
}
