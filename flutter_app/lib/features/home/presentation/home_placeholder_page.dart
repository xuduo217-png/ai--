import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';

class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({
    super.key,
    required this.authController,
    required this.session,
  }) : guest = false;

  const HomePlaceholderPage.guest({super.key})
    : authController = null,
      session = null,
      guest = true;

  final AuthController? authController;
  final AuthSession? session;
  final bool guest;

  @override
  Widget build(BuildContext context) {
    final title = guest
        ? '商城'
        : session!.accountType == AccountType.doctor
        ? '医生工作台'
        : '用户首页';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!guest)
            IconButton(
              tooltip: '退出登录',
              onPressed: authController!.logout,
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      guest
                          ? Icons.storefront_outlined
                          : session!.accountType == AccountType.doctor
                          ? Icons.medical_services_outlined
                          : Icons.pets_outlined,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    guest ? '游客模式已接通' : '登录成功，${session!.displayName}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guest
                        ? '商城页面将在下一阶段迁移。'
                        : '${session!.accountType.label}认证与登录态持久化已完成，业务首页将在后续阶段迁移。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (guest) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('返回登录'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
