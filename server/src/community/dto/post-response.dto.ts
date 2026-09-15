import { PostStatus } from "../entities/post.entity";

/**
 * 帖子响应 DTO
 * 定义返回给前端的帖子数据结构
 */
export class PostResponseDto {
  id: number;

  userId: number;

  /**
   * 用户信息（简化版，只包含必要字段）
   */
  user: {
    id: number;
    nickname: string; // 使用 username 作为 nickname 显示
    avatar?: string;
  };

  content: string;

  images?: string[];

  video?: string;

  /**
   * 视频封面图
   * 前端在发帖时生成并上传，用于列表和详情页的稳定预览。
   */
  videoCover?: string;

  /**
   * 标签列表
   * 直接返回带 `#` 前缀的原始标签名，避免各端重复拼接导致展示失真
   */
  tags?: string[];

  status: PostStatus;

  likeCount: number;

  commentCount: number;

  viewCount: number;

  heatScore: number;

  isPinned: boolean;

  isFeatured: boolean;

  rejectReason?: string;

  detectedSensitiveWords?: string[];

  createdAt: Date;

  updatedAt: Date;
}

/**
 * 评论响应 DTO
 * 定义返回给前端的评论数据结构
 */
export class CommentResponseDto {
  id: number;

  userId: number;

  postId: number;

  content: string;

  parentId?: number;

  likeCount: number;

  createdAt: Date;

  /**
   * 用户信息（简化版，只包含必要字段）
   */
  user?: {
    id: number;
    nickname: string; // 使用 username 作为 nickname 显示
    avatar?: string;
  };

  replies?: CommentResponseDto[];
}
