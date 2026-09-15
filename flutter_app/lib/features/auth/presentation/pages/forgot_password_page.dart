import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/auth_models.dart';
import '../auth_controller.dart';
import '../widgets/auth_widgets.dart';

enum _ResetStep { code, password }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.authController,
    required this.accountType,
    this.initialPhone = '',
  });

  final AuthController authController;
  final AccountType accountType;
  final String initialPhone;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _phoneController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  Timer? _countdownTimer;
  _ResetStep _step = _ResetStep.code;
  int _countdown = 0;
  bool _sendingCode = false;
  bool _submitting = false;
  bool _passwordVisible = false;
  bool _confirmationVisible = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCodeStep = _step == _ResetStep.code;
    final accountLabel = widget.accountType == AccountType.doctor
        ? '医生账号'
        : '用户账号';

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFDFE8FF)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SimpleAuthAppBar(title: isCodeStep ? '找回密码' : '设置新密码'),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double scale(double value) => rnDesignPx(context, value);
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        scale(32),
                        scale(12),
                        scale(32),
                        scale(40),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: scale(20)),
                            Text(
                              accountLabel,
                              style: TextStyle(
                                color: const Color(0xFF333333),
                                fontSize: scale(32),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(height: scale(8)),
                            Text(
                              isCodeStep ? '通过手机号验证码重置密码' : '请设置新的登录密码',
                              style: TextStyle(
                                color: const Color(0xFF333333),
                                fontSize: scale(36),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(height: scale(40)),
                            if (isCodeStep)
                              _buildCodeStep(scale)
                            else
                              _buildPasswordStep(scale),
                            SizedBox(height: scale(120)),
                            AuthButton(
                              title: isCodeStep ? '下一步' : '重置密码',
                              loading: _submitting,
                              disabled: _submitting,
                              onPressed: isCodeStep
                                  ? _verifyCode
                                  : _resetPassword,
                            ),
                            SizedBox(height: scale(40)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStep(double Function(double) scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthInput(
          controller: _phoneController,
          placeholder: '手机号',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          enabled: !_submitting,
        ),
        SizedBox(height: scale(20)),
        Row(
          children: [
            Expanded(
              child: AuthInput(
                controller: _codeController,
                placeholder: '验证码',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verifyCode(),
                enabled: !_submitting,
              ),
            ),
            SizedBox(width: scale(12)),
            _buildSendCodeButton(scale),
          ],
        ),
      ],
    );
  }

  Widget _buildSendCodeButton(double Function(double) scale) {
    final disabled = _countdown > 0 || _sendingCode || _submitting;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: '发送验证码',
      child: Material(
        color: disabled ? const Color(0xFFB0B0B0) : AuthColors.primary,
        borderRadius: BorderRadius.circular(scale(40)),
        child: InkWell(
          onTap: disabled ? null : _sendCode,
          borderRadius: BorderRadius.circular(scale(40)),
          child: Container(
            constraints: BoxConstraints(
              minWidth: scale(180),
              minHeight: scale(104),
            ),
            padding: EdgeInsets.symmetric(horizontal: scale(28)),
            alignment: Alignment.center,
            child: Text(
              _countdown > 0 ? '$_countdown秒' : '发送验证码',
              style: TextStyle(
                color: Colors.white.withValues(alpha: disabled ? 0.6 : 1),
                fontSize: scale(26),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStep(double Function(double) scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: scale(104),
          padding: EdgeInsets.symmetric(horizontal: scale(36)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(scale(40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '手机号',
                style: TextStyle(
                  color: const Color(0xFF666666),
                  fontSize: scale(26),
                  letterSpacing: 0,
                ),
              ),
              Text(
                _phoneController.text,
                style: TextStyle(
                  color: const Color(0xFF333333),
                  fontSize: scale(30),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: scale(20)),
        AuthInput(
          controller: _passwordController,
          placeholder: '新密码（至少6位）',
          obscureText: !_passwordVisible,
          maxLength: 20,
          textInputAction: TextInputAction.next,
          enabled: !_submitting,
        ),
        _buildVisibilityButton(
          scale,
          label: _passwordVisible ? '隐藏密码' : '显示密码',
          onPressed: () => setState(() {
            _passwordVisible = !_passwordVisible;
          }),
        ),
        AuthInput(
          controller: _confirmationController,
          placeholder: '确认新密码',
          obscureText: !_confirmationVisible,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _resetPassword(),
          enabled: !_submitting,
        ),
        _buildVisibilityButton(
          scale,
          label: _confirmationVisible ? '隐藏确认密码' : '显示确认密码',
          onPressed: () => setState(() {
            _confirmationVisible = !_confirmationVisible;
          }),
        ),
      ],
    );
  }

  Widget _buildVisibilityButton(
    double Function(double) scale, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Transform.translate(
        offset: Offset(0, -scale(14)),
        child: Padding(
          padding: EdgeInsets.only(bottom: scale(4)),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.primary,
              minimumSize: Size(0, scale(48)),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: TextStyle(
                fontSize: scale(26),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  String? _validatedPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showAuthMessage(context, '请输入手机号', error: true);
      return null;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      showAuthMessage(context, '请输入正确的11位手机号', error: true);
      return null;
    }
    return phone;
  }

  Future<void> _sendCode() async {
    final phone = _validatedPhone();
    if (phone == null || _sendingCode || _countdown > 0) {
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final seconds = await widget.authController.sendResetPasswordCode(
        phone,
        widget.accountType,
      );
      _startCountdown(seconds);
      if (mounted) {
        showAuthMessage(context, '验证码已发送');
      }
    } on Object catch (error) {
      if (mounted) {
        showAuthMessage(context, '$error', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final phone = _validatedPhone();
    final code = _codeController.text.trim();
    if (phone == null) {
      return;
    }
    if (code.isEmpty) {
      showAuthMessage(context, '请输入验证码', error: true);
      return;
    }
    if (code.length != 6) {
      showAuthMessage(context, '请输入6位验证码', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.authController.verifyResetPasswordCode(
        phone: phone,
        code: code,
        accountType: widget.accountType,
      );
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _step = _ResetStep.password);
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

  Future<void> _resetPassword() async {
    final phone = _validatedPhone();
    final password = _passwordController.text;
    final confirmation = _confirmationController.text;
    if (phone == null) {
      return;
    }
    if (password.trim().isEmpty) {
      showAuthMessage(context, '请输入新密码', error: true);
      return;
    }
    if (password.length < 6) {
      showAuthMessage(context, '密码长度不能少于6位', error: true);
      return;
    }
    if (confirmation.trim().isEmpty) {
      showAuthMessage(context, '请确认新密码', error: true);
      return;
    }
    if (password != confirmation) {
      showAuthMessage(context, '两次输入的密码不一致', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.authController.resetPassword(
        phone: phone,
        code: _codeController.text.trim(),
        newPassword: password,
        accountType: widget.accountType,
      );
      if (mounted) {
        showAuthMessage(context, '密码重置成功，请使用新密码登录');
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

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _countdown = seconds > 0 ? seconds : 120);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _countdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _countdown = 0);
        }
        return;
      }
      setState(() => _countdown -= 1);
    });
  }
}
