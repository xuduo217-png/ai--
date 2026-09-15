import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:pet_hospital_flutter/features/profile/presentation/profile_controller.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';

import 'support/wp11_viewports.dart';

void main() {
  testWidgets('编辑页初始化资料、手机号脱敏并阻止空白昵称', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('138****8000'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('profile-edit-nickname')),
          )
          .controller
          ?.text,
      '原昵称',
    );

    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-nickname')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('profile-edit-save')));
    await tester.pump();

    expect(find.text('请输入昵称'), findsNWidgets(2));
    expect(harness.profileGateway.updateCalls, 0);
  });

  testWidgets('头像先暂存，保存成功后才同步资料页和持久化 session', (tester) async {
    final harness = await _Harness.create(
      pickedImage: const PickedProfileImage(
        path: '/tmp/avatar.jpg',
        filename: 'avatar.jpg',
      ),
    );
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-edit-avatar')));
    await tester.pumpAndSettle();
    expect(harness.profileGateway.uploadCalls, 1);
    expect(harness.auth.session?.profile['avatar'], '/uploads/old.jpg');

    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-nickname')),
      ' 新昵称 ',
    );
    await tester.tap(find.byKey(const ValueKey('profile-edit-gender-female')));
    await tester.tap(find.byKey(const ValueKey('profile-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('result:saved'), findsOneWidget);
    expect(harness.profileGateway.lastUpdate?.toJson(), {
      'username': '新昵称',
      'avatar': '/uploads/new.jpg',
      'gender': 2,
    });
    expect(harness.auth.session?.profile['username'], '新昵称');
    expect(harness.auth.session?.profile['avatar'], '/uploads/new.jpg');
    expect(harness.auth.session?.profile['gender'], 2);
  });

  testWidgets('选择取消不报错，上传失败和保存失败保留编辑输入', (tester) async {
    final cancelled = await _Harness.create();
    addTearDown(cancelled.dispose);
    await tester.pumpWidget(cancelled.app());
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-edit-avatar')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(cancelled.profileGateway.uploadCalls, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final failed = await _Harness.create(
      pickedImage: const PickedProfileImage(path: '/tmp/avatar.jpg'),
      uploadFails: true,
      saveFails: true,
    );
    addTearDown(failed.dispose);
    await tester.pumpWidget(failed.app());
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-edit-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('头像上传失败，请稍后重试'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-nickname')),
      '保留的输入',
    );
    await tester.tap(find.byKey(const ValueKey('profile-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('资料保存失败，请稍后重试'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('profile-edit-nickname')),
          )
          .controller
          ?.text,
      '保留的输入',
    );
  });

  testWidgets('没有修改时返回 noChanges 并关闭编辑页', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('result:noChanges'), findsOneWidget);
    expect(find.text('编辑资料'), findsNothing);
    expect(harness.profileGateway.updateCalls, 0);
  });

  for (final viewport in wp11Viewports) {
    testWidgets('${viewport.label} 下编辑页无布局溢出', (tester) async {
      configureWp11Viewport(tester, viewport);
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app(textScale: viewport.textScale));
      await tester.tap(find.text('打开编辑'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('编辑头像和保存操作具有语义名称与最小触控面积', (tester) async {
    final semantics = tester.ensureSemantics();
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('选择头像'), findsOneWidget);
    expect(find.bySemanticsLabel('保存个人资料'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('profile-edit-avatar'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('profile-edit-save'))).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });
}

class _Harness {
  _Harness({
    required this.auth,
    required this.controller,
    required this.profileGateway,
  });

  final AuthController auth;
  final ProfileController controller;
  final _ProfileGateway profileGateway;

  static Future<_Harness> create({
    PickedProfileImage? pickedImage,
    bool uploadFails = false,
    bool saveFails = false,
  }) async {
    final auth = AuthController(
      gateway: const _AuthGateway(),
      sessionStore: _SessionStore(
        const AuthSession(
          accessToken: 'token',
          accountType: AccountType.user,
          profile: {
            'id': 8,
            'phone': '13800138000',
            'username': '原昵称',
            'gender': 1,
            'avatar': '/uploads/old.jpg',
            'opaque': {'version': 1},
          },
        ),
      ),
    );
    await auth.initialize();
    final gateway = _ProfileGateway(
      uploadFails: uploadFails,
      saveFails: saveFails,
    );
    return _Harness(
      auth: auth,
      profileGateway: gateway,
      controller: ProfileController(
        profileGateway: gateway,
        walletGateway: const _WalletGateway(),
        authController: auth,
        imagePicker: _Picker(pickedImage),
        fileExists: (_) => true,
      ),
    );
  }

  Widget app({double textScale = 1}) => MaterialApp(
    builder: wp11TextScaleBuilder(textScale),
    home: _EditLauncher(controller: controller),
  );

  void dispose() => controller.dispose();
}

class _EditLauncher extends StatefulWidget {
  const _EditLauncher({required this.controller});

  final ProfileController controller;

  @override
  State<_EditLauncher> createState() => _EditLauncherState();
}

class _EditLauncherState extends State<_EditLauncher> {
  ProfileEditCompletion? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('result:${_result?.name ?? '-'}'),
            FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute<ProfileEditCompletion>(
                    builder: (_) =>
                        ProfileEditPage(controller: widget.controller),
                  ),
                );
                if (mounted) setState(() => _result = result);
              },
              child: const Text('打开编辑'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileGateway implements ProfileGateway {
  _ProfileGateway({required this.uploadFails, required this.saveFails});

  final bool uploadFails;
  final bool saveFails;
  int uploadCalls = 0;
  int updateCalls = 0;
  ProfileUpdateInput? lastUpdate;

  @override
  Future<UserProfile> loadProfile() async => _profile();

  @override
  Future<ProfileImageUpload> uploadAvatar({
    required String filePath,
    String? filename,
  }) async {
    uploadCalls += 1;
    if (uploadFails) throw StateError('upload failed');
    return const ProfileImageUpload(
      id: 9,
      url: '/uploads/new.jpg',
      filename: 'new.jpg',
      originalName: 'avatar.jpg',
      size: 100,
    );
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async {
    updateCalls += 1;
    lastUpdate = input;
    if (saveFails) throw StateError('save failed');
    return UserProfile(
      id: 8,
      username: input.username ?? '原昵称',
      displayName: input.username ?? '原昵称',
      phone: '13800138000',
      avatarUrl: input.avatarUrl ?? '/uploads/old.jpg',
      gender: input.gender ?? UserGender.male,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _profile() {
  return const UserProfile(
    id: 8,
    username: '原昵称',
    displayName: '原昵称',
    phone: '13800138000',
    avatarUrl: '/uploads/old.jpg',
    gender: UserGender.male,
  );
}

class _WalletGateway implements WalletSummaryGateway {
  const _WalletGateway();

  @override
  Future<WalletStats> loadStats() async => const WalletStats(
    availableBalance: 1,
    pendingSettlement: 2,
    totalSecondHandIncome: 3,
    withdrawalFrozenBalance: 0,
  );
}

class _Picker implements ProfileImagePicker {
  const _Picker(this.image);

  final PickedProfileImage? image;

  @override
  Future<PickedProfileImage?> pickAvatar({BuildContext? context}) async =>
      image;
}

class _AuthGateway implements AuthGateway {
  const _AuthGateway();

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async =>
      savedSession;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionStore implements SessionStore {
  _SessionStore(this.session);

  AuthSession? session;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session?.accessToken;

  @override
  Future<void> saveSession(AuthSession session) async => this.session = session;
}
