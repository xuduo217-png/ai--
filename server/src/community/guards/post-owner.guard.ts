import { Injectable, CanActivate, ExecutionContext, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Post } from '../entities/post.entity';

/**
 * 帖子所有者守卫
 * 确保只有帖子作者才能执行某些操作
 */
@Injectable()
export class PostOwnerGuard implements CanActivate {
  constructor(
    @InjectRepository(Post)
    private readonly postRepository: Repository<Post>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const postId = parseInt(request.params.id, 10);
    const userId = request.user.id;

    if (!postId || !userId) {
      return false;
    }

    const post = await this.postRepository.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException('帖子不存在');
    }

    if (post.userId !== userId) {
      throw new ForbiddenException('无权操作此帖子');
    }

    return true;
  }
}
