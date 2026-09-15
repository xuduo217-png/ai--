import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Post } from './post.entity';
import { Tag } from './tag.entity';

/**
 * 帖子标签关联实体
 * 多对多关系表，连接帖子和标签
 */
@Entity('community_post_tags')
@Index('IDX_community_post_tags_post_id', ['postId'])
@Index('IDX_community_post_tags_tag_id', ['tagId'])
@Index('IDX_community_post_tags_post_tag', ['postId', 'tagId'], { unique: true }) // 防止重复关联
export class PostTag {
  @PrimaryGeneratedColumn({ comment: '主键ID' })
  id: number;

  /**
   * 帖子ID
   */
  @Column({ type: 'int', comment: '帖子ID' })
  postId: number;

  /**
   * 标签ID
   */
  @Column({ type: 'int', comment: '标签ID' })
  tagId: number;

  /**
   * 关联的帖子实体
   */
  @ManyToOne(() => Post, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'postId' })
  post: Post;

  /**
   * 关联的标签实体
   */
  @ManyToOne(() => Tag, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tagId' })
  tag: Tag;
}
