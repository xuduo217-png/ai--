import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../home/domain/home_models.dart';
import '../../../home/presentation/home_page.dart';
import '../../../mall/domain/mall_models.dart';
import '../../../mall/navigation/mall_navigation_coordinator.dart';
import '../../../profile/navigation/profile_navigation_coordinator.dart';
import '../../domain/auth_models.dart';
import '../auth_controller.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_page.dart';
import 'set_password_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.authController,
    required this.homeGateway,
    required this.mallGateway,
    this.mallNavigation,
    this.profileNavigation,
  });

  final AuthController authController;
  final HomeGateway homeGateway;
  final MallGateway mallGateway;
  final MallNavigationCoordinator? mallNavigation;
  final ProfileNavigator? profileNavigation;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerCodeController = TextEditingController();

  Timer? _countdownTimer;
  AccountType _accountType = AccountType.user;
  int _currentTab = 0;
  bool _passwordVisible = false;
  bool _submitting = false;
  bool _sendingCode = false;
  int _countdown = 0;

  bool get _isDoctorMode => _accountType == AccountType.doctor;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _registerPhoneController.dispose();
    _registerCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 32),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(),
                        _buildTabBar(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: _currentTab == 0 || _isDoctorMode
                                ? _buildLoginContent()
                                : _buildRegisterContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildStickyFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: _submitting ? null : _toggleAccountType,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _isDoctorMode ? '登录用户端' : '登录医生端',
              style: const TextStyle(
                color: AuthColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Row(
        children: [
          _AuthTabButton(
            text: '登录',
            selected: _isDoctorMode || _currentTab == 0,
            onPressed: () => _switchTab(0),
          ),
          if (!_isDoctorMode) ...[
            const SizedBox(width: 32),
            _AuthTabButton(
              text: '注册',
              selected: _currentTab == 1,
              onPressed: () => _switchTab(1),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginContent() {
    return Column(
      key: const ValueKey('login-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        Text(
          _isDoctorMode ? '医生您好' : '谷德E宠',
          style: const TextStyle(
            color: AuthColors.text,
            fontSize: 32,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isDoctorMode ? '专业宠物医生' : '开启智慧养宠生活',
          style: const TextStyle(
            color: AuthColors.text,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 40),
        AuthInput(
          key: const ValueKey('login-phone-input'),
          controller: _loginPhoneController,
          placeholder: '手机号',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          enabled: !_submitting,
        ),
        const SizedBox(height: 20),
        AuthInput(
          key: const ValueKey('login-password-input'),
          controller: _loginPasswordController,
          placeholder: '密码',
          obscureText: !_passwordVisible,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submitLogin(),
          enabled: !_submitting,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        _passwordVisible = !_passwordVisible;
                      }),
                style: TextButton.styleFrom(
                  foregroundColor: AuthColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_passwordVisible ? '隐藏密码' : '显示密码'),
              ),
              TextButton(
                onPressed: _submitting ? null : _openForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: AuthColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('忘记密码?'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterContent() {
    return Column(
      key: const ValueKey('register-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        const Text(
          '欢迎加入!',
          style: TextStyle(
            color: AuthColors.text,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '注册请继续',
          style: TextStyle(
            color: Color(0x99000000),
            fontSize: 18,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 40),
        AuthInput(
          key: const ValueKey('register-phone-input'),
          controller: _registerPhoneController,
          placeholder: '手机号',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          enabled: !_submitting,
        ),
        const SizedBox(height: 20),
        AuthInput(
          key: const ValueKey('register-code-input'),
          controller: _registerCodeController,
          placeholder: '验证码',
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitRegisterCode(),
          enabled: !_submitting,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _countdown > 0 || _sendingCode || _submitting
                ? null
                : _sendRegisterCode,
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.primary,
              disabledForegroundColor: const Color(0xFF9CA3AF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 16, letterSpacing: 0),
            ),
            child: Text(_countdown > 0 ? '${_countdown}s' : '发送验证码'),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyFooter() {
    final isRegister = !_isDoctorMode && _currentTab == 1;
    final title = _isDoctorMode ? '医生登录' : (isRegister ? '下一步' : '登陆');

    final bottomPadding = math.max(MediaQuery.paddingOf(context).bottom, 12.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(32, 12, 32, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthButton(
            title: title,
            loading: _submitting,
            disabled: _submitting,
            onPressed: isRegister ? _submitRegisterCode : _submitLogin,
          ),
          if (!_isDoctorMode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(
                key: const ValueKey('continue-as-guest-button'),
                onPressed: _submitting ? null : _continueAsGuest,
                style: TextButton.styleFrom(
                  foregroundColor: AuthColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('暂不登录，继续浏览'),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleAccountType() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _accountType = _isDoctorMode ? AccountType.user : AccountType.doctor;
      if (_isDoctorMode) {
        _currentTab = 0;
      }
    });
  }

  void _switchTab(int index) {
    if (_isDoctorMode || _submitting) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentTab = index);
  }

  Future<void> _submitLogin() async {
    if (_submitting) {
      return;
    }

    final phone = _loginPhoneController.text;
    final password = _loginPasswordController.text;
    if (phone.trim().isEmpty) {
      showAuthMessage(context, '请输入手机号', error: true);
      return;
    }
    if (phone.length != 11) {
      showAuthMessage(context, '请输入11位手机号', error: true);
      return;
    }
    if (password.trim().isEmpty) {
      showAuthMessage(context, '请输入密码', error: true);
      return;
    }
    if (password.length < 6) {
      showAuthMessage(context, '密码长度不能少于6位', error: true);
      return;
    }

    TextInput.finishAutofillContext();
    setState(() => _submitting = true);
    try {
      await widget.authController.login(
        phone: phone,
        password: password,
        accountType: _accountType,
      );
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

  Future<void> _sendRegisterCode() async {
    final phone = _registerPhoneController.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      showAuthMessage(context, '请输入正确的11位手机号', error: true);
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final seconds = await widget.authController.sendRegisterCode(phone);
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

  Future<void> _submitRegisterCode() async {
    if (_submitting) {
      return;
    }

    final phone = _registerPhoneController.text.trim();
    final code = _registerCodeController.text.trim();
    if (phone.isEmpty) {
      showAuthMessage(context, '请输入手机号', error: true);
      return;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      showAuthMessage(context, '请输入正确的11位手机号', error: true);
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
      await widget.authController.verifyRegisterCode(phone: phone, code: code);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SetPasswordPage(
            authController: widget.authController,
            phone: phone,
            code: code,
          ),
        ),
      );
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

  Future<void> _openForgotPassword() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(
          authController: widget.authController,
          initialPhone: _loginPhoneController.text.trim(),
          accountType: _accountType,
        ),
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HomePage.guest(
          gateway: widget.homeGateway,
          mallGateway: widget.mallGateway,
          mallNavigation: widget.mallNavigation,
          profileNavigation: widget.profileNavigation,
        ),
      ),
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  const _AuthTabButton({
    required this.text,
    required this.selected,
    required this.onPressed,
  });

  final String text;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              color: selected ? Colors.black : const Color(0x99000000),
              fontSize: 28,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 64,
            height: 4,
            decoration: BoxDecoration(
              color: selected ? AuthColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
