import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/media/gallery_media_picker.dart';
import '../../domain/activity_models.dart';
import '../activity_controller.dart';
import '../activity_design.dart';
import '../activity_interactions.dart';

class ActivityVoteOptionEditorPage extends StatefulWidget {
  const ActivityVoteOptionEditorPage({
    super.key,
    required this.controller,
    this.initialOption,
    this.galleryMediaPicker,
  });

  final ActivityDetailController controller;
  final ActivityVoteOption? initialOption;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<ActivityVoteOptionEditorPage> createState() =>
      _ActivityVoteOptionEditorPageState();
}

class _ActivityVoteOptionEditorPageState
    extends State<ActivityVoteOptionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final GalleryMediaPicker _galleryMediaPicker;
  late String _imageUrl;
  late String _videoUrl;
  late String _videoCoverUrl;
  bool _uploading = false;
  bool _submitting = false;

  bool get _editing => widget.initialOption != null;
  bool get _hasMedia => _imageUrl.isNotEmpty || _videoUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final option = widget.initialOption;
    _titleController = TextEditingController(text: option?.title);
    _descriptionController = TextEditingController(text: option?.description);
    _imageUrl = option?.imageUrl ?? '';
    _videoUrl = option?.videoUrl ?? '';
    _videoCoverUrl = option?.videoCoverUrl ?? '';
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickMedia() async {
    if (_uploading || _submitting) return;
    final type = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择参赛媒体',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: activityPrimary),
              title: const Text('上传图片'),
              onTap: () => Navigator.of(sheetContext).pop('image'),
            ),
            ListTile(
              leading: const Icon(
                Icons.video_library_rounded,
                color: activityIndigo,
              ),
              title: const Text('上传视频'),
              onTap: () => Navigator.of(sheetContext).pop('video'),
            ),
          ],
        ),
      ),
    );
    if (type == null) return;
    if (!mounted) return;
    try {
      final files = await _galleryMediaPicker.pick(
        context: context,
        mediaType: type == 'image'
            ? GalleryMediaType.image
            : GalleryMediaType.video,
        imageQuality: type == 'image' ? 90 : null,
      );
      if (files.isEmpty || !mounted) return;
      final file = files.single;
      setState(() => _uploading = true);
      final upload = type == 'image'
          ? await widget.controller.uploadImage(
              filePath: file.path,
              filename: file.name,
            )
          : await widget.controller.uploadVideo(
              filePath: file.path,
              filename: file.name,
            );
      if (!mounted) return;
      setState(() {
        if (type == 'image') {
          _imageUrl = upload.url;
          _videoUrl = '';
          _videoCoverUrl = '';
        } else {
          _videoUrl = upload.url;
          _videoCoverUrl = upload.thumbnailUrl;
          _imageUrl = '';
        }
      });
      _message('上传成功');
    } on Object catch (error) {
      _message(activityErrorMessage(error, '上传失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_uploading || _submitting) return;
    final activity = widget.controller.activity;
    if (activity == null) {
      _message('活动信息加载中，请稍后重试');
      return;
    }
    if (activity.isExpired) {
      _message(_editing ? '活动已结束，无法编辑' : '活动已结束，无法报名');
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    if (!_hasMedia) {
      _message('请上传参赛图片或视频');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await widget.controller.saveVoteOption(
        ActivityVoteOptionDraft(
          title: _titleController.text,
          description: _descriptionController.text,
          imageUrl: _imageUrl,
          videoUrl: _videoUrl,
          videoCoverUrl: _videoCoverUrl,
        ),
        optionId: widget.initialOption?.id,
      );
      if (!mounted) return;
      if (!result.success) {
        _message(result.message.isEmpty ? '保存失败，请稍后重试' : result.message);
        return;
      }
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      _message(activityErrorMessage(error, '保存失败，请稍后重试'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ActivityGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ActivityAppBar(
                title: _editing ? '编辑参赛信息' : '报名参加',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _EditorLabel(text: '参赛作品'),
                            const SizedBox(height: 10),
                            _buildMediaPicker(),
                            const SizedBox(height: 20),
                            const _EditorLabel(text: '作品名称'),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const ValueKey('activity-option-title'),
                              controller: _titleController,
                              maxLength: 40,
                              decoration: _inputDecoration('请输入作品名称'),
                              validator: (value) =>
                                  value?.trim().isEmpty == true
                                  ? '请输入作品名称'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            const _EditorLabel(text: '作品介绍'),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const ValueKey(
                                'activity-option-description',
                              ),
                              controller: _descriptionController,
                              minLines: 4,
                              maxLines: 7,
                              maxLength: 300,
                              decoration: _inputDecoration('介绍一下你的参赛作品'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const ValueKey('activity-option-submit'),
                          onPressed: _submitting || _uploading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: activityPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_editing ? '保存修改' : '确认报名'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPicker() {
    if (_uploading) {
      return const AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: activityPrimary),
                SizedBox(height: 10),
                Text('正在上传...', style: TextStyle(color: activityMuted)),
              ],
            ),
          ),
        ),
      );
    }
    if (!_hasMedia) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: InkWell(
          key: const ValueKey('activity-option-media-picker'),
          onTap: _pickMedia,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: activityBorder),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_rounded,
                  color: activityPrimary,
                  size: 50,
                ),
                SizedBox(height: 10),
                Text(
                  '上传图片或视频',
                  style: TextStyle(
                    color: activityMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final preview = _imageUrl.isNotEmpty ? _imageUrl : _videoCoverUrl;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: preview.isEmpty
                ? const ColoredBox(
                    color: Color(0xFF111827),
                    child: Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  )
                : Image.network(
                    preview,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFF111827),
                      child: Center(
                        child: Icon(
                          Icons.video_library_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ),
          if (_videoUrl.isNotEmpty)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 58,
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '更换媒体',
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.sync_rounded),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: '删除媒体',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xCC111827),
                  ),
                  onPressed: () => setState(() {
                    _imageUrl = '';
                    _videoUrl = '';
                    _videoCoverUrl = '';
                  }),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: activityInk,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: activityHint, letterSpacing: 0),
  filled: true,
  fillColor: const Color(0xFFF7F8FA),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: activityBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: activityPrimary, width: 1.5),
  ),
);
