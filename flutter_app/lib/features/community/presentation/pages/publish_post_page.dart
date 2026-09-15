import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/media/gallery_media_picker.dart';
import '../../../friends/presentation/pages/friend_video_player_page.dart';
import '../../domain/community_models.dart';
import '../community_design.dart';

class CommunityPublishPostPage extends StatefulWidget {
  const CommunityPublishPostPage({
    super.key,
    required this.gateway,
    this.galleryMediaPicker,
    this.initialPost,
  });

  final CommunityGateway gateway;
  final GalleryMediaPicker? galleryMediaPicker;
  final CommunityPost? initialPost;

  @override
  State<CommunityPublishPostPage> createState() =>
      _CommunityPublishPostPageState();
}

class _CommunityPublishPostPageState extends State<CommunityPublishPostPage> {
  static const _fallbackTags = <String>[
    '#宠物日常',
    '#萌宠',
    '#养宠心得',
    '#健康小知识',
    '#宠物美容',
    '#训练技巧',
  ];

  final TextEditingController _contentController = TextEditingController();
  late final GalleryMediaPicker _galleryMediaPicker;
  List<String> _images = const [];
  String _videoUrl = '';
  String _videoCoverUrl = '';
  List<String> _hotTags = _fallbackTags;
  final Set<String> _selectedTags = <String>{};
  bool _uploading = false;
  bool _submitting = false;

  bool get _editing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    final initialPost = widget.initialPost;
    if (initialPost != null) {
      _contentController.text = initialPost.content;
      _images = initialPost.images;
      _videoUrl = initialPost.videoUrl;
      _videoCoverUrl = initialPost.videoCoverUrl;
      _selectedTags.addAll(initialPost.tags.map(_normalizeTag));
      _hotTags = {..._fallbackTags, ..._selectedTags}.toList(growable: false);
    }
    unawaited(_loadTags());
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      _contentController.text.trim().isNotEmpty && !_uploading && !_submitting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ValueKey(
        _editing ? 'community-edit-post-page' : 'community-publish-page',
      ),
      backgroundColor: Colors.transparent,
      body: CommunityBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _buildComposer(),
                    if (_selectedTags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSelectedTags(),
                    ],
                    const SizedBox(height: 12),
                    _buildMedia(),
                    const SizedBox(height: 12),
                    _buildTags(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Expanded(
            child: Text(
              _editing ? '编辑帖子' : '发布帖子',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: communityText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const ValueKey('community-submit-post'),
              onPressed: _canPublish ? _publish : null,
              style: FilledButton.styleFrom(
                backgroundColor: communityPrimaryButton,
                minimumSize: const Size(68, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_editing ? '保存' : '发布'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      key: const ValueKey('community-composer-card'),
      padding: const EdgeInsets.all(18),
      decoration: communityCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '创作内容',
            style: TextStyle(
              color: communityPrimaryButton,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '分享你的养宠经验或生活片段',
            style: TextStyle(
              color: communityText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: communityCardDecoration(color: communityMutedSurface),
            child: TextField(
              key: const ValueKey('community-post-content-field'),
              controller: _contentController,
              autofocus: true,
              minLines: 7,
              maxLines: 12,
              maxLength: 10000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '记录今天的宠物日常...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ModerationChip(),
              Text(
                '发布后需审核',
                style: TextStyle(color: communityTextSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTags() {
    return _SectionCard(
      title: '已选标签',
      trailing: '${_selectedTags.length}/10',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in _selectedTags)
            InputChip(
              label: Text(tag),
              onDeleted: () => setState(() => _selectedTags.remove(tag)),
              deleteIcon: const Icon(Icons.close_rounded, size: 17),
              backgroundColor: communitySoftSurface,
              side: const BorderSide(color: communityBorder),
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    final mediaCounts = <String>[
      if (_images.isNotEmpty) '${_images.length}/9 张图片',
      if (_videoUrl.isNotEmpty) '1 个视频',
    ];
    final canAddImages = _images.length < 9;
    final canAddVideo = _videoUrl.isEmpty;

    return _SectionCard(
      title: '图片与视频',
      trailing: _uploading ? '上传中...' : mediaCounts.join(' · '),
      child: Column(
        children: [
          if (_images.isNotEmpty) _buildImageGrid(),
          if (_images.isNotEmpty && _videoUrl.isNotEmpty)
            const SizedBox(height: 12),
          if (_videoUrl.isNotEmpty) _buildVideoPreview(),
          if (canAddImages || canAddVideo) ...[
            if (_images.isNotEmpty || _videoUrl.isNotEmpty)
              const SizedBox(height: 12),
            Row(
              children: [
                if (canAddImages)
                  Expanded(
                    child: _MediaAction(
                      key: const ValueKey('community-add-images'),
                      icon: Icons.photo_library_outlined,
                      label: _images.isEmpty ? '添加图片' : '继续添加图片',
                      onPressed: _uploading ? null : _pickImages,
                    ),
                  ),
                if (canAddImages && canAddVideo) const SizedBox(width: 8),
                if (canAddVideo)
                  Expanded(
                    child: _MediaAction(
                      key: const ValueKey('community-add-video'),
                      icon: Icons.videocam_outlined,
                      label: '添加视频',
                      onPressed: _uploading ? null : _pickVideo,
                    ),
                  ),
              ],
            ),
          ],
          if (_uploading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: communityPrimaryButton),
          ],
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CommunityNetworkImage(source: _images[index]),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  tooltip: '移除图片',
                  onPressed: _uploading
                      ? null
                      : () => setState(
                          () => _images = [
                            for (var i = 0; i < _images.length; i++)
                              if (i != index) _images[i],
                          ],
                        ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x99111827),
                    minimumSize: const Size(28, 28),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 17),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPreview() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CommunityNetworkImage(
              source: _videoCoverUrl,
              placeholderIcon: Icons.videocam_rounded,
              backgroundColor: const Color(0xFF0F172A),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
            Center(
              child: IconButton.filled(
                key: const ValueKey('community-preview-video'),
                tooltip: '预览视频',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => FriendVideoPlayerPage(videoUrl: _videoUrl),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 32),
              ),
            ),
            Positioned(
              top: 7,
              right: 7,
              child: IconButton.filled(
                tooltip: '移除视频',
                onPressed: _uploading
                    ? null
                    : () => setState(() {
                        _videoUrl = '';
                        _videoCoverUrl = '';
                      }),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xAA111827),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags() {
    return _SectionCard(
      title: '添加标签',
      trailing: '帮助发现',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in _hotTags)
            FilterChip(
              key: ValueKey('community-tag-$tag'),
              label: Text(tag),
              selected: _selectedTags.contains(tag),
              showCheckmark: false,
              onSelected: (_) => _toggleTag(tag),
              selectedColor: const Color(0xFFE8F4FF),
              side: const BorderSide(color: communityBorder),
              shape: const StadiumBorder(),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('自定义'),
            onPressed: _addCustomTag,
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            shape: const StadiumBorder(),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.gateway.loadCommunityHotTags();
      if (!mounted || tags.isEmpty) return;
      setState(() {
        _hotTags = tags
            .map((tag) => _normalizeTag(tag.name))
            .where((tag) => tag.length > 1)
            .toSet()
            .toList(growable: false);
      });
    } on Object {
      // The local tag set keeps the editor usable when this optional request fails.
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) {
        if (_selectedTags.length >= 10) {
          _showMessage('最多只能选择 10 个标签');
          return;
        }
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _addCustomTag() async {
    final result = await showDialog<String>(
      context: context,
      barrierColor: const Color(0x99111827),
      builder: (dialogContext) => _CustomTagDialog(
        onClose: () => Navigator.of(dialogContext).pop(),
        onAdd: (value) => Navigator.of(dialogContext).pop(value),
      ),
    );
    final tag = _normalizeTag(result ?? '');
    if (tag.length <= 1 || !mounted) return;
    if (!_hotTags.contains(tag)) setState(() => _hotTags = [..._hotTags, tag]);
    _toggleTag(tag);
  }

  Future<void> _pickImages() async {
    try {
      final remaining = 9 - _images.length;
      if (remaining <= 0) return;
      final selected = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.image,
        allowMultiple: true,
        maxCount: remaining,
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (selected.isEmpty || !mounted) return;
      final queue = selected.take(remaining).toList(growable: false);
      setState(() => _uploading = true);
      final uploaded = <String>[];
      var failed = 0;
      Object? firstError;
      for (final file in queue) {
        try {
          final result = await widget.gateway.uploadCommunityImage(
            filePath: file.path,
            filename: file.name,
          );
          if (result.url.isEmpty) {
            failed++;
            firstError ??= '服务器未返回图片地址';
          } else {
            uploaded.add(result.url);
          }
        } on Object catch (error) {
          failed++;
          firstError ??= error;
        }
      }
      if (!mounted) return;
      setState(() {
        _images = [..._images, ...uploaded].take(9).toList(growable: false);
        _uploading = false;
      });
      if (failed > 0) {
        _showMessage(
          uploaded.isEmpty && firstError != null
              ? '图片上传失败：$firstError'
              : '部分图片上传失败，请重试',
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showMessage('选择图片失败：$error');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final selected = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.video,
        maxVideoDuration: const Duration(minutes: 3),
      );
      if (selected.isEmpty || !mounted) return;
      final file = selected.single;
      setState(() => _uploading = true);
      final result = await widget.gateway.uploadCommunityVideo(
        filePath: file.path,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _videoUrl = result.url;
        _videoCoverUrl = result.thumbnailUrl;
        _uploading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showMessage('视频上传失败：$error');
    }
  }

  Future<void> _publish() async {
    final draft = CommunityPostDraft(
      content: _contentController.text,
      images: _images,
      videoUrl: _videoUrl,
      videoCoverUrl: _videoCoverUrl,
      tags: _selectedTags.toList(growable: false),
    );
    final validation = draft.validate();
    if (validation != null) {
      _showMessage(validation);
      return;
    }
    setState(() => _submitting = true);
    try {
      final initialPost = widget.initialPost;
      if (initialPost == null) {
        await widget.gateway.createCommunityPost(draft);
      } else {
        await widget.gateway.updateCommunityPost(initialPost.id, draft);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(initialPost == null ? '发布成功，等待管理员审核' : '帖子已更新')),
      );
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('${_editing ? '保存' : '发布'}失败：$error');
    }
  }

  String _normalizeTag(String value) {
    final normalized = value.replaceFirst(RegExp(r'^#'), '').trim();
    return normalized.isEmpty ? '' : '#$normalized';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CustomTagDialog extends StatefulWidget {
  const _CustomTagDialog({required this.onClose, required this.onAdd});

  final VoidCallback onClose;
  final ValueChanged<String> onAdd;

  @override
  State<_CustomTagDialog> createState() => _CustomTagDialogState();
}

class _CustomTagDialogState extends State<_CustomTagDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('community-custom-tag-dialog'),
      backgroundColor: communitySurface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final canAdd = value.text.trim().isNotEmpty;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.tag_rounded,
                          color: communityPrimaryButton,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '自定义标签',
                          style: TextStyle(
                            color: communityText,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('community-custom-tag-close'),
                        tooltip: '关闭',
                        onPressed: widget.onClose,
                        style: IconButton.styleFrom(
                          foregroundColor: communityTextSecondary,
                          backgroundColor: communityMutedSurface,
                          minimumSize: const Size.square(36),
                          maximumSize: const Size.square(36),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('community-custom-tag-field'),
                    controller: _controller,
                    autofocus: true,
                    maxLength: 20,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.deny('#')],
                    style: const TextStyle(
                      color: communityText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '输入标签名称',
                      hintStyle: const TextStyle(color: communityHint),
                      prefixText: '# ',
                      prefixStyle: const TextStyle(
                        color: communityPrimaryButton,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      suffixText: '${value.text.length}/20',
                      suffixStyle: const TextStyle(
                        color: communityTextSecondary,
                        fontSize: 12,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: communitySoftSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: communityBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: communityPrimaryButton,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (canAdd) widget.onAdd(_controller.text);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('community-custom-tag-add'),
                    onPressed: canAdd
                        ? () => widget.onAdd(_controller.text)
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: communityPrimaryButton,
                      disabledBackgroundColor: const Color(0xFFDCE3F4),
                      disabledForegroundColor: const Color(0xFF96A0B5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('添加标签'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing = '',
  });

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: communityCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: communityText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing.isNotEmpty)
                Text(
                  trailing,
                  style: const TextStyle(
                    color: communityTextSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MediaAction extends StatelessWidget {
  const _MediaAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 112,
          decoration: communityCardDecoration(color: communityMutedSurface),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: communityPrimaryButton),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                style: const TextStyle(
                  color: communityText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModerationChip extends StatelessWidget {
  const _ModerationChip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: communityPrimaryButton,
        ),
        SizedBox(width: 5),
        Text(
          '友善分享',
          style: TextStyle(
            color: communityPrimaryButton,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
