import 'package:flutter/material.dart';

import '../../../../core/media/gallery_media_picker.dart';
import '../../domain/community_models.dart';
import '../community_design.dart';

class EditCommunityProfilePage extends StatefulWidget {
  const EditCommunityProfilePage({
    super.key,
    required this.gateway,
    required this.profile,
    this.galleryMediaPicker,
  });

  final CommunityGateway gateway;
  final CommunityProfile profile;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<EditCommunityProfilePage> createState() =>
      _EditCommunityProfilePageState();
}

class _EditCommunityProfilePageState extends State<EditCommunityProfilePage> {
  late final TextEditingController _bioController;
  late final GalleryMediaPicker _galleryMediaPicker;
  late String _coverImageUrl;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.profile.user.bio);
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    _coverImageUrl = widget.profile.user.coverImageUrl;
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('community-edit-profile-page'),
      backgroundColor: Colors.transparent,
      body: CommunityBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  children: [
                    _buildIdentity(),
                    const SizedBox(height: 12),
                    _buildCoverEditor(),
                    const SizedBox(height: 12),
                    _buildBioEditor(),
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
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          const Expanded(
            child: Text(
              '编辑社区资料',
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
              key: const ValueKey('community-save-profile'),
              onPressed: _saving || _uploading ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(68, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: communityPrimaryButton,
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentity() {
    final user = widget.profile.user;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: communityCardDecoration(),
      child: Row(
        children: [
          CommunityAvatar(user: user, radius: 28),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: communityText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '头像和昵称沿用账号资料',
                  style: TextStyle(color: communityTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: communityCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '主页封面',
            style: TextStyle(
              color: communityText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '建议使用 16:9 横向图片',
            style: TextStyle(color: communityTextSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CommunityNetworkImage(
                    source: _coverImageUrl,
                    backgroundColor: const Color(0xFF7186D8),
                  ),
                  const ColoredBox(color: Color(0x33000000)),
                  Center(
                    child: _uploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : FilledButton.icon(
                            key: const ValueKey('community-pick-cover'),
                            onPressed: _pickCover,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xAA111827),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('更换封面'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: communityCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人简介',
            style: TextStyle(
              color: communityText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('community-profile-bio'),
            controller: _bioController,
            minLines: 5,
            maxLines: 7,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '介绍一下你和你的宠物吧',
              filled: true,
              fillColor: communityMutedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCover() async {
    try {
      final files = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.image,
        imageQuality: 90,
        maxWidth: 1920,
      );
      if (files.isEmpty) return;
      final file = files.single;
      setState(() {
        _uploading = true;
        _coverImageUrl = file.path;
      });
      final upload = await widget.gateway.uploadCommunityImage(
        filePath: file.path,
        filename: file.name,
        category: 'community-cover',
      );
      if (mounted) setState(() => _coverImageUrl = upload.url);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _coverImageUrl = widget.profile.user.coverImageUrl);
      _showMessage('封面上传失败：$error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final bio = _bioController.text.trim();
    if (bio.length > 200) {
      _showMessage('个人简介不能超过 200 字');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.gateway.updateCommunityProfile(
        bio: bio,
        coverImageUrl: _coverImageUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) _showMessage('保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
