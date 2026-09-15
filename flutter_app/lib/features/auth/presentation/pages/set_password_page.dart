import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../widgets/auth_widgets.dart';

class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({
    super.key,
    required this.authController,
    required this.phone,
    required this.code,
  });

  final AuthController authController;
  final String phone;
  final String code;

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmationVisible = false;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AuthColors.gradientStart),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 36),
                      const Text(
                        '设置密码',
                        style: TextStyle(
                          color: AuthColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '完成最后一步，创建安全密码',
                        style: TextStyle(
                          color: AuthColors.textSecondary,
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFormCard(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  math.max(MediaQuery.paddingOf(context).bottom, 12.0),
                ),
                child: AuthButton(
                  title: '完成注册',
                  loading: _submitting,
                  disabled: _submitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '账号安全',
            style: TextStyle(
              color: AuthColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '密码将用于后续手机号登录',
            style: TextStyle(
              color: AuthColors.textSecondary,
              fontSize: 13,
              height: 20 / 13,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '手机号',
                  style: TextStyle(
                    color: AuthColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phone,
                  style: const TextStyle(
                    color: AuthColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          ),
          AuthInput(
            controller: _passwordController,
            placeholder: '密码（至少6位）',
            obscureText: !_passwordVisible,
            maxLength: 20,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: _VisibilityButton(
                label: _passwordVisible ? '隐藏密码' : '显示密码',
                onPressed: () => setState(() {
                  _passwordVisible = !_passwordVisible;
                }),
              ),
            ),
          ),
          AuthInput(
            controller: _confirmationController,
            placeholder: '确认密码',
            obscureText: !_confirmationVisible,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            enabled: !_submitting,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: _VisibilityButton(
                label: _confirmationVisible ? '隐藏确认密码' : '显示确认密码',
                onPressed: () => setState(() {
                  _confirmationVisible = !_confirmationVisible;
                }),
              ),
            ),
          ),
          const Text(
            '建议使用 6-20 位字母、数字组合，安全性更高',
            style: TextStyle(
              color: AuthColors.textSecondary,
              fontSize: 12,
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final password = _passwordController.text;
    final confirmation = _confirmationController.text;
    if (password.trim().isEmpty) {
      showAuthMessage(context, '请输入密码', error: true);
      return;
    }
    if (password.length < 6) {
      showAuthMessage(context, '密码长度不能少于6位', error: true);
      return;
    }
    if (confirmation.trim().isEmpty) {
      showAuthMessage(context, '请确认密码', error: true);
      return;
    }
    if (password != confirmation) {
      showAuthMessage(context, '两次输入的密码不一致', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.authController.register(
        phone: widget.phone,
        code: widget.code,
        password: password,
      );
      if (mounted) {
        showAuthMessage(context, '注册成功，欢迎加入谷德E宠');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on Object catch (error) {
      if (mounted) {
        showAuthMessage(context, '$error', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF3B82F6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
      child: Text(label),
    );
  }
}
