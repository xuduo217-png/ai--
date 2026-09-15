import 'package:flutter/material.dart';

import '../../../core/network/asset_url_resolver.dart';
import '../../../core/widgets/app_dialog.dart';
import '../domain/community_models.dart';

const communityPrimary = Color(0xFF2196F3);
const communityPrimaryButton = Color(0xFF5B75E5);
const communityText = Color(0xFF1F2937);
const communityTextSecondary = Color(0xFF6B7280);
const communityHint = Color(0xFF999999);
const communityBackground = Color(0xFFF7F8FA);
const communitySurface = Color(0xFFFFFFFF);
const communitySoftSurface = Color(0xFFF7F8FA);
const communityMutedSurface = Color(0xFFF3F4F6);
const communityBorder = Color(0xFFE5E7EB);
const communityError = Color(0xFFF44336);

class CommunityBackground extends StatelessWidget {
  const CommunityBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
          stops: [0, 0.56],
        ),
      ),
      child: child,
    );
  }
}

BoxDecoration communityCardDecoration({
  Color color = communitySurface,
  Color borderColor = communityBorder,
  double radius = 8,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor),
  );
}

class CommunityNetworkImage extends StatelessWidget {
  const CommunityNetworkImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.pets_rounded,
    this.backgroundColor = const Color(0xFF7E97FA),
  });

  final String source;
  final BoxFit fit;
  final IconData placeholderIcon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final localFile = resolveLocalFile(source);
    if (localFile != null) {
      return Image.file(
        localFile,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    final url = resolveAssetUrl(source);
    if (url.isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: fit,
      frameBuilder: (context, child, frame, synchronouslyLoaded) {
        if (synchronouslyLoaded || frame != null) return child;
        return ColoredBox(
          color: const Color(0xFFDBEAFE),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: Icon(placeholderIcon, color: Colors.white, size: 34),
      ),
    );
  }
}

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.user, this.radius = 20});

  final CommunityUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: CommunityNetworkImage(
          source: user.avatarUrl,
          backgroundColor: const Color(0xFFE8F4FF),
        ),
      ),
    );
  }
}

class CommunityPostGrid extends StatelessWidget {
  const CommunityPostGrid({
    super.key,
    required this.posts,
    required this.onOpenPost,
    required this.onOpenUser,
    required this.onLike,
    this.onManagePost,
  });

  final List<CommunityPost> posts;
  final ValueChanged<CommunityPost> onOpenPost;
  final ValueChanged<int> onOpenUser;
  final ValueChanged<int> onLike;
  final ValueChanged<CommunityPost>? onManagePost;

  @override
  Widget build(BuildContext context) {
    final columns = <List<CommunityPost>>[[], []];
    final heights = <double>[0, 0];
    for (final post in posts) {
      final index = heights[0] <= heights[1] ? 0 : 1;
      columns[index].add(post);
      heights[index] += _estimatedHeight(post);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < columns.length; column++) ...[
          Expanded(
            child: Column(
              children: [
                for (final post in columns[column])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CommunityPostCard(
                      post: post,
                      onPressed: () => onOpenPost(post),
                      onOpenUser: () => onOpenUser(post.userId),
                      onLike: () => onLike(post.id),
                      onManage: onManagePost == null
                          ? null
                          : () => onManagePost!(post),
                    ),
                  ),
              ],
            ),
          ),
          if (column == 0) const SizedBox(width: 8),
        ],
      ],
    );
  }

  double _estimatedHeight(CommunityPost post) {
    return 174 + (post.content.length.clamp(0, 60) * 0.65) + 78;
  }
}

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.onPressed,
    required this.onOpenUser,
    required this.onLike,
    this.onManage,
  });

  final CommunityPost post;
  final VoidCallback onPressed;
  final VoidCallback onOpenUser;
  final VoidCallback onLike;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final mediaLabel = post.videoUrl.isNotEmpty
        ? (post.tags.isEmpty ? '视频内容' : _tag(post.tags.first))
        : post.tags.isEmpty
        ? ''
        : _tag(post.tags.first);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('community-post-${post.id}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: communityCardDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _CommunityPostCardCover(
                      postId: post.id,
                      source: post.coverUrl,
                      placeholderIcon: post.videoUrl.isNotEmpty
                          ? Icons.play_arrow_rounded
                          : Icons.pets_rounded,
                      backgroundColor: post.videoUrl.isNotEmpty
                          ? const Color(0xFF1E3A8A)
                          : const Color(0xFF7E97FA),
                    ),
                    if (mediaLabel.isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: _MediaBadge(
                          icon: post.videoUrl.isNotEmpty
                              ? Icons.videocam_rounded
                              : Icons.sell_outlined,
                          label: mediaLabel,
                        ),
                      ),
                    if (post.isPinned || post.isFeatured)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (post.isFeatured)
                              const _MediaBadge(
                                icon: Icons.auto_awesome_rounded,
                                label: '精选',
                              ),
                            if (post.isPinned) ...[
                              if (post.isFeatured) const SizedBox(height: 5),
                              const _MediaBadge(
                                icon: Icons.push_pin_outlined,
                                label: '置顶',
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _postTitle(post),
                        key: const ValueKey('community-post-card-title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: communityText,
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: post.userId > 0 ? onOpenUser : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  CommunityAvatar(
                                    user: post.author,
                                    radius: 11,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      post.author.nickname,
                                      key: const ValueKey(
                                        'community-post-card-author',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: communityTextSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkResponse(
                            key: ValueKey('community-like-${post.id}'),
                            onTap: onLike,
                            radius: 22,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    post.isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 17,
                                    color: post.isLiked
                                        ? const Color(0xFFF15B6C)
                                        : const Color(0xFF9AA4B2),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    compactCount(post.likeCount),
                                    style: TextStyle(
                                      color: post.isLiked
                                          ? communityError
                                          : communityTextSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (onManage != null) ...[
                            const SizedBox(width: 2),
                            InkResponse(
                              key: ValueKey('community-manage-${post.id}'),
                              onTap: onManage,
                              radius: 22,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 19,
                                  color: communityTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityPostCardCover extends StatefulWidget {
  const _CommunityPostCardCover({
    required this.postId,
    required this.source,
    required this.placeholderIcon,
    required this.backgroundColor,
  });

  final int postId;
  final String source;
  final IconData placeholderIcon;
  final Color backgroundColor;

  @override
  State<_CommunityPostCardCover> createState() =>
      _CommunityPostCardCoverState();
}

class _CommunityPostCardCoverState extends State<_CommunityPostCardCover> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double _aspectRatio = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _CommunityPostCardCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _aspectRatio = 1;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final previousListener = _imageListener;
    if (previousListener != null) {
      _imageStream?.removeListener(previousListener);
    }
    _imageStream = null;
    _imageListener = null;

    final localFile = resolveLocalFile(widget.source);
    final ImageProvider<Object>? provider;
    if (localFile != null) {
      provider = FileImage(localFile);
    } else {
      final url = resolveAssetUrl(widget.source);
      provider = url.isEmpty ? null : NetworkImage(url);
    }
    if (provider == null) return;

    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((imageInfo, _) {
      final width = imageInfo.image.width;
      final height = imageInfo.image.height;
      if (!mounted || width <= 0 || height <= 0) return;
      final aspectRatio = width / height;
      if (aspectRatio == _aspectRatio) return;
      setState(() => _aspectRatio = aspectRatio);
    }, onError: (_, _) {});
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    final listener = _imageListener;
    if (listener != null) _imageStream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: ValueKey('community-post-card-cover-${widget.postId}'),
      aspectRatio: _aspectRatio,
      child: CommunityNetworkImage(
        source: widget.source,
        fit: BoxFit.contain,
        placeholderIcon: widget.placeholderIcon,
        backgroundColor: widget.backgroundColor,
      ),
    );
  }
}

Future<bool> confirmCommunityPostDeletion(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AppDialog(
      key: const ValueKey('community-delete-post-dialog'),
      icon: const AppDialogIcon.danger(icon: Icons.delete_outline_rounded),
      title: const Text('删除帖子'),
      content: const Text('删除后无法恢复，确定要删除这条帖子吗？'),
      actions: [
        TextButton(
          key: const ValueKey('community-delete-post-cancel'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('community-delete-post-confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: communityError),
          child: const Text('确认删除'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x66111827),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityEmptyState extends StatelessWidget {
  const CommunityEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.pets_rounded,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: communityCardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: communityTextSecondary, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: communityText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: communityTextSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: communityPrimaryButton,
                minimumSize: const Size(112, 42),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

String compactCount(int count) {
  if (count < 1000) return '$count';
  final value = count / 1000;
  return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}k';
}

String communityRelativeTime(DateTime? value) {
  if (value == null) return '';
  final difference = DateTime.now().difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes}分钟前';
  if (difference.inDays < 1) return '${difference.inHours}小时前';
  if (difference.inDays < 7) return '${difference.inDays}天前';
  return '${value.month}月${value.day}日';
}

String communityDate(DateTime? value) {
  if (value == null) return '刚刚';
  final now = DateTime.now();
  if (value.year == now.year) {
    return '${value.month}月${value.day}日 ${_two(value.hour)}:${_two(value.minute)}';
  }
  return '${value.year}年${value.month}月${value.day}日';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _postTitle(CommunityPost post) {
  final value = post.content.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.isNotEmpty) return value;
  if (post.tags.isNotEmpty) return post.tags.take(2).map(_tag).join(' ');
  return '分享一条宠物动态';
}

String _tag(String value) {
  final normalized = value.replaceFirst(RegExp(r'^#'), '').trim();
  return '#$normalized';
}
