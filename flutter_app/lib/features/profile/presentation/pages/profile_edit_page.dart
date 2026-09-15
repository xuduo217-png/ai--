import 'package:flutter/material.dart';

import '../../domain/profile_models.dart';
import '../profile_controller.dart';

enum ProfileEditCompletion { saved, noChanges }

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.controller});

  final ProfileController controller;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late UserGender _gender;
  late String _avatarUrl;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _nicknameController = TextEditingController(text: profile?.username ?? '');
    _gender = profile?.gender ?? UserGender.unknown;
    _avatarUrl = profile?.avatarUrl ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.profile;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.isBusy;
        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F9),
          appBar: AppBar(
            title: const Text('编辑资料'),
            centerTitle: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          body: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  Center(
                    child: Semantics(
                      button: true,
                      label: '选择头像',
                      child: InkWell(
                        key: const ValueKey('profile-edit-avatar'),
                        customBorder: const CircleBorder(),
                        onTap: busy ? null : _pickAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _ProfileAvatar(url: _avatarUrl, size: 96),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2F855A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.photo_camera_outlined,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.controller.isUploading)
                              const Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0x66000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: SizedBox.square(
                                      dimension: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _FieldBand(
                    children: [
                      TextFormField(
                        key: const ValueKey('profile-edit-nickname'),
                        controller: _nicknameController,
                        enabled: !busy,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: '昵称',
                          hintText: '请输入昵称',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            value?.trim().isEmpty ?? true ? '请输入昵称' : null,
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        '性别',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5E6673),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<UserGender>(
                          segments: const [
                            ButtonSegment(
                              value: UserGender.unknown,
                              label: Text(
                                '未设置',
                                key: ValueKey('profile-edit-gender-unknown'),
                              ),
                            ),
                            ButtonSegment(
                              value: UserGender.male,
                              label: Text(
                                '男',
                                key: ValueKey('profile-edit-gender-male'),
                              ),
                            ),
                            ButtonSegment(
                              value: UserGender.female,
                              label: Text(
                                '女',
                                key: ValueKey('profile-edit-gender-female'),
                              ),
                            ),
                          ],
                          selected: {_gender},
                          showSelectedIcon: false,
                          onSelectionChanged: busy
                              ? null
                              : (selection) {
                                  setState(() => _gender = selection.single);
                                },
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        key: const ValueKey('profile-edit-phone'),
                        initialValue: maskProfilePhone(profile?.phone),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: '手机号',
                          prefixIcon: Icon(Icons.phone_outlined),
                          helperText: '手机号不可在此修改',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Semantics(
                button: true,
                label: widget.controller.isSaving ? '正在保存个人资料' : '保存个人资料',
                excludeSemantics: true,
                child: FilledButton.icon(
                  key: const ValueKey('profile-edit-save'),
                  onPressed: busy ? null : _save,
                  icon: widget.controller.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(widget.controller.isSaving ? '保存中' : '保存'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar() async {
    final result = await widget.controller.pickAndUploadAvatar(
      context: context,
    );
    if (!mounted) return;
    switch (result.status) {
      case ProfileAvatarUploadStatus.uploaded:
        setState(() => _avatarUrl = result.url!);
      case ProfileAvatarUploadStatus.failed:
      case ProfileAvatarUploadStatus.busy:
        _showMessage(result.message ?? '头像上传失败，请稍后重试');
      case ProfileAvatarUploadStatus.cancelled:
        return;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      final result = await widget.controller.saveProfile(
        ProfileEditDraft(
          nickname: _nicknameController.text,
          gender: _gender,
          avatarUrl: _avatarUrl,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        result == ProfileSaveResult.saved
            ? ProfileEditCompletion.saved
            : ProfileEditCompletion.noChanges,
      );
    } on ProfileValidationException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('资料保存失败，请稍后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FieldBand extends StatelessWidget {
  const _FieldBand({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFFE8F1EC),
                child: Icon(
                  Icons.person_rounded,
                  size: 50,
                  color: Color(0xFF2F855A),
                ),
              )
            : Image.network(
                UserProfile(
                  id: null,
                  username: '',
                  displayName: '',
                  phone: '',
                  avatarUrl: url,
                  gender: UserGender.unknown,
                ).resolvedAvatarUrl(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFE8F1EC),
                  child: Icon(
                    Icons.person_rounded,
                    size: 50,
                    color: Color(0xFF2F855A),
                  ),
                ),
              ),
      ),
    );
  }
}
