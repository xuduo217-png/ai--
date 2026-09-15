import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pet_hospital_flutter/core/widgets/app_dialog.dart';

import '../../../../core/platform/external_uri_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../profile/domain/profile_models.dart';
import '../../domain/settings_models.dart';
import '../settings_controller.dart';
import 'system_article_page.dart';

const _settingsHeaderBackgroundColor = Color(0xFFDEE9FF);

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settingsGateway,
    required this.accountGateway,
    required this.authController,
    required this.uriLauncher,
    required this.contentBaseUrl,
  });

  final SettingsGateway settingsGateway;
  final ProfileGateway accountGateway;
  final AuthController authController;
  final ExternalUriLauncher uriLauncher;
  final String contentBaseUrl;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController(
      settingsGateway: widget.settingsGateway,
      accountGateway: widget.accountGateway,
      authController: widget.authController,
    );
    unawaited(_controller.loadContactInfo());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _settingsHeaderBackgroundColor,
        surfaceTintColor: _settingsHeaderBackgroundColor,
        foregroundColor: AppColors.ink,
        title: const Text('系统设置'),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => ListView(
          key: const ValueKey('settings-list'),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContactSection(),
                    const SizedBox(height: 12),
                    _buildArticleSection(),
                    const SizedBox(height: 20),
                    _buildDeleteAccountButton(),
                    const SizedBox(height: 8),
                    const Text(
                      '注销后账号身份信息将被删除或匿名化',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF7B8490)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('settings-logout'),
                        onPressed: _controller.accountActionInProgress
                            ? null
                            : _confirmLogout,
                        icon: _controller.loggingOut
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.logout_rounded),
                        label: Text(_controller.loggingOut ? '退出中...' : '退出登录'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8ED)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '联系客服',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (_controller.loadingContact)
              const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Center(child: _buildQrCode()),
              const SizedBox(height: 12),
              if (_controller.contactInfo.isEmpty)
                const Text(
                  '暂未配置联系方式',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF7B8490)),
                )
              else ...[
                if (_controller.contactInfo.hasHotline)
                  _ContactRow(
                    key: const ValueKey('settings-phone'),
                    icon: Icons.phone_in_talk_outlined,
                    label: '客服热线',
                    value: _controller.contactInfo.hotline,
                    onTap: _confirmPhoneCall,
                  ),
                if (_controller.contactInfo.hasWorkingHours) ...[
                  const Divider(height: 18),
                  _ContactRow(
                    icon: Icons.schedule_rounded,
                    label: '工作时间',
                    value: _controller.contactInfo.workingHours,
                  ),
                ],
              ],
              if (_controller.contactError != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Flexible(
                      child: Text(
                        '联系方式加载失败',
                        style: TextStyle(color: Color(0xFFB42318)),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('settings-contact-retry'),
                      tooltip: '重试联系方式',
                      onPressed: _controller.loadContactInfo,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQrCode() {
    final rawUrl = _controller.contactInfo.wechatQrCode;
    final uri = resolveSafeWebUri(rawUrl, baseUrl: widget.contentBaseUrl);
    if (uri == null) {
      return Container(
        key: const ValueKey('settings-contact-qr-placeholder'),
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.qr_code_2_rounded,
          size: 64,
          color: Color(0xFF8B95A1),
        ),
      );
    }
    return InkWell(
      key: const ValueKey('settings-contact-qr'),
      onTap: () => _showQrCode(uri),
      child: SizedBox.square(
        dimension: 112,
        child: Image.network(
          uri.toString(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFFF1F3F5),
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleSection() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8ED)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _ArticleRow(
            key: const ValueKey('settings-article-privacy'),
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF356AA0),
            type: SystemArticleType.privacy,
            onTap: _openArticle,
          ),
          const Divider(height: 1, indent: 60),
          _ArticleRow(
            key: const ValueKey('settings-article-user-agreement'),
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF16845B),
            type: SystemArticleType.userAgreement,
            onTap: _openArticle,
          ),
          const Divider(height: 1, indent: 60),
          _ArticleRow(
            key: const ValueKey('settings-article-about-us'),
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF7A4FA3),
            type: SystemArticleType.aboutUs,
            onTap: _openArticle,
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        key: const ValueKey('settings-delete-account'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB42318),
          side: const BorderSide(color: Color(0xFFD5A09B)),
        ),
        onPressed: _controller.accountActionInProgress
            ? null
            : _confirmDeleteAccount,
        icon: _controller.deletingAccount
            ? const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_off_outlined),
        label: Text(_controller.deletingAccount ? '注销中...' : '注销账号'),
      ),
    );
  }

  Future<void> _confirmPhoneCall() async {
    final hotline = _controller.contactInfo.hotline;
    if (hotline.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.phone_rounded),
        title: const Text('拨打客服热线'),
        content: Text('是否拨打 $hotline？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('拨打'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uri = Uri(scheme: 'tel', path: hotline);
    if (!await widget.uriLauncher.launch(uri)) {
      _showMessage('无法打开拨号界面');
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon(icon: Icons.logout_rounded),
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await _controller.logout();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _showMessage('退出登录失败，请稍后重试');
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: const AppDialogIcon.danger(icon: Icons.person_off_rounded),
        title: const Text('注销账号'),
        content: const Text(
          '注销后账号将停用，手机号、邮箱、头像等身份信息会被删除或匿名化。'
          '订单等依法需要保留的记录可能继续保存。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await _controller.deleteAccount();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _showMessage('注销失败，请稍后重试');
    }
  }

  void _openArticle(SystemArticleType type) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SystemArticlePage(
            gateway: widget.settingsGateway,
            type: type,
            uriLauncher: widget.uriLauncher,
            contentBaseUrl: widget.contentBaseUrl,
          ),
        ),
      ),
    );
  }

  Future<void> _showQrCode(Uri uri) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        maxWidth: 360,
        icon: const AppDialogIcon(icon: Icons.qr_code_2_rounded),
        title: const Text('微信二维码'),
        content: AspectRatio(
          aspectRatio: 1,
          child: Image.network(uri.toString(), fit: BoxFit.contain),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF426B91)),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF66717D)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: onTap == null
                      ? const Color(0xFF26313D)
                      : const Color(0xFF2563A6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.type,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final SystemArticleType type;
  final ValueChanged<SystemArticleType> onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => onTap(type),
      leading: Icon(icon, color: iconColor),
      title: Text(type.title),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
