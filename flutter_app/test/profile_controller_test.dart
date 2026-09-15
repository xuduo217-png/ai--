import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/auth/domain/auth_models.dart';
import 'package:pet_hospital_flutter/features/auth/presentation/auth_controller.dart';
import 'package:pet_hospital_flutter/features/profile/domain/profile_models.dart';
import 'package:pet_hospital_flutter/features/profile/presentation/profile_controller.dart';
import 'package:pet_hospital_flutter/features/wallet/domain/wallet_models.dart';

void main() {
  test('并发刷新折叠为一次请求并同时更新资料、钱包和持久化会话', () async {
    final auth = await _authenticatedController();
    final profileGateway = _ProfileGateway();
    final walletGateway = _WalletGateway();
    final controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      authController: auth,
      imagePicker: const _ImagePicker(null),
    );

    final first = controller.refresh();
    final second = controller.refresh();
    expect(profileGateway.loadCalls, 1);
    expect(walletGateway.loadCalls, 1);

    profileGateway.loadCompleter.complete(_profile(username: '服务端昵称'));
    walletGateway.loadCompleter.complete(
      const WalletStats(
        availableBalance: 12.3,
        pendingSettlement: 4,
        totalSecondHandIncome: 98.75,
        withdrawalFrozenBalance: 0,
      ),
    );
    await Future.wait([first, second]);

    expect(controller.profile?.displayName, '服务端昵称');
    expect(controller.walletStats?.totalSecondHandIncome, 98.75);
    expect(auth.session?.profile['username'], '服务端昵称');
    expect(controller.profileError, isNull);
    expect(controller.walletError, isNull);
  });

  test('资料和钱包局部失败互不遮挡，并保留最后一次有效数据', () async {
    final auth = await _authenticatedController();
    final profileGateway = _ProfileGateway()
      ..loadCompleter.completeError(StateError('profile failed'));
    final walletGateway = _WalletGateway()
      ..loadCompleter.completeError(StateError('wallet failed'));
    final controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      authController: auth,
      imagePicker: const _ImagePicker(null),
    );

    await controller.refresh();

    expect(controller.profile?.displayName, '原昵称');
    expect(controller.profileError, isNotNull);
    expect(controller.walletStats, isNull);
    expect(controller.walletError, isNotNull);
    expect(controller.isInitialLoading, isFalse);
  });

  test('头像选择取消、文件丢失和上传成功均保持 session 提交前不变', () async {
    final auth = await _authenticatedController();
    final profileGateway = _ProfileGateway();
    final walletGateway = _WalletGateway();

    var controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      authController: auth,
      imagePicker: const _ImagePicker(null),
      fileExists: (_) => true,
    );
    expect(
      (await controller.pickAndUploadAvatar()).status,
      ProfileAvatarUploadStatus.cancelled,
    );

    controller.dispose();
    controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      authController: auth,
      imagePicker: const _ImagePicker(
        PickedProfileImage(path: '/tmp/missing.jpg', filename: 'missing.jpg'),
      ),
      fileExists: (_) => false,
    );
    final missing = await controller.pickAndUploadAvatar();
    expect(missing.status, ProfileAvatarUploadStatus.failed);
    expect(profileGateway.uploadCalls, 0);

    controller.dispose();
    controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      authController: auth,
      imagePicker: const _ImagePicker(
        PickedProfileImage(path: '/tmp/avatar.jpg', filename: 'avatar.jpg'),
      ),
      fileExists: (_) => true,
    );
    final uploaded = await controller.pickAndUploadAvatar();
    expect(uploaded.status, ProfileAvatarUploadStatus.uploaded);
    expect(uploaded.url, '/uploads/new-avatar.jpg');
    expect(auth.session?.profile['avatar'], '/uploads/old-avatar.jpg');
  });

  test('重复上传被拒绝，保存只发送变更字段且成功后更新会话', () async {
    final auth = await _authenticatedController();
    final uploadCompleter = Completer<ProfileImageUpload>();
    final profileGateway = _ProfileGateway(uploadCompleter: uploadCompleter);
    final controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: _WalletGateway(),
      authController: auth,
      imagePicker: const _ImagePicker(
        PickedProfileImage(path: '/tmp/avatar.jpg', filename: 'avatar.jpg'),
      ),
      fileExists: (_) => true,
    );

    final firstUpload = controller.pickAndUploadAvatar();
    final repeatedUpload = await controller.pickAndUploadAvatar();
    expect(repeatedUpload.status, ProfileAvatarUploadStatus.busy);
    uploadCompleter.complete(_upload());
    await firstUpload;

    final noChanges = await controller.saveProfile(
      const ProfileEditDraft(
        nickname: '原昵称',
        gender: UserGender.male,
        avatarUrl: '/uploads/old-avatar.jpg',
      ),
    );
    expect(noChanges, ProfileSaveResult.noChanges);
    expect(profileGateway.updateCalls, 0);

    final saved = await controller.saveProfile(
      const ProfileEditDraft(
        nickname: ' 新昵称 ',
        gender: UserGender.male,
        avatarUrl: '/uploads/old-avatar.jpg',
      ),
    );
    expect(saved, ProfileSaveResult.saved);
    expect(profileGateway.lastUpdate?.toJson(), {'username': '新昵称'});
    expect(auth.session?.profile['username'], '新昵称');
    expect(auth.session?.profile['opaque'], const {'version': 1});
  });

  test('相册返回前页面销毁则取消且不发起上传', () async {
    final auth = await _authenticatedController();
    final picker = _DeferredImagePicker();
    final profileGateway = _ProfileGateway();
    final controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: _WalletGateway(),
      authController: auth,
      imagePicker: picker,
      fileExists: (_) => true,
    );

    final upload = controller.pickAndUploadAvatar();
    controller.dispose();
    picker.result.complete(
      const PickedProfileImage(
        path: '/tmp/late-avatar.jpg',
        filename: 'late-avatar.jpg',
      ),
    );

    final outcome = await upload;
    expect(outcome.status, ProfileAvatarUploadStatus.cancelled);
    expect(profileGateway.uploadCalls, 0);
  });

  test('昵称仅含空白时拒绝保存且保存失败保留当前有效资料', () async {
    final auth = await _authenticatedController();
    final gateway = _ProfileGateway();
    final controller = ProfileController(
      profileGateway: gateway,
      walletGateway: _WalletGateway(),
      authController: auth,
      imagePicker: const _ImagePicker(null),
    );

    await expectLater(
      controller.saveProfile(
        const ProfileEditDraft(
          nickname: '   ',
          gender: UserGender.male,
          avatarUrl: '/uploads/old-avatar.jpg',
        ),
      ),
      throwsA(isA<ProfileValidationException>()),
    );
    expect(gateway.updateCalls, 0);

    gateway.updateError = StateError('save failed');
    await expectLater(
      controller.saveProfile(
        const ProfileEditDraft(
          nickname: '失败后仍在输入框',
          gender: UserGender.female,
          avatarUrl: '/uploads/old-avatar.jpg',
        ),
      ),
      throwsStateError,
    );
    expect(controller.profile?.displayName, '原昵称');
    expect(auth.session?.profile['username'], '原昵称');
  });

  test('dispose 后完成的刷新不通知、不覆盖会话', () async {
    final auth = await _authenticatedController();
    final profileGateway = _ProfileGateway();
    final walletGateway = _WalletGateway();
    final controller = ProfileController(
      profileGateway: profileGateway,
      walletGateway: walletGateway,
      authController: auth,
      imagePicker: const _ImagePicker(null),
    );
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    final refresh = controller.refresh();
    final notificationsBeforeDispose = notifications;
    controller.dispose();
    profileGateway.loadCompleter.complete(_profile(username: '迟到资料'));
    walletGateway.loadCompleter.complete(
      const WalletStats(
        availableBalance: 1,
        pendingSettlement: 2,
        totalSecondHandIncome: 3,
        withdrawalFrozenBalance: 0,
      ),
    );
    await refresh;

    expect(notifications, notificationsBeforeDispose);
    expect(auth.session?.profile['username'], '原昵称');
  });
}

Future<AuthController> _authenticatedController() async {
  final controller = AuthController(
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
          'avatar': '/uploads/old-avatar.jpg',
          'opaque': {'version': 1},
        },
      ),
    ),
  );
  await controller.initialize();
  return controller;
}

UserProfile _profile({required String username}) {
  return UserProfile(
    id: 8,
    username: username,
    displayName: username,
    phone: '13800138000',
    avatarUrl: '/uploads/old-avatar.jpg',
    gender: UserGender.male,
  );
}

ProfileImageUpload _upload() {
  return const ProfileImageUpload(
    id: 9,
    url: '/uploads/new-avatar.jpg',
    filename: 'new-avatar.jpg',
    originalName: 'avatar.jpg',
    size: 123,
  );
}

class _ProfileGateway implements ProfileGateway {
  _ProfileGateway({Completer<ProfileImageUpload>? uploadCompleter})
    : _uploadCompleter = uploadCompleter;

  final Completer<UserProfile> loadCompleter = Completer<UserProfile>();
  final Completer<ProfileImageUpload>? _uploadCompleter;
  int loadCalls = 0;
  int uploadCalls = 0;
  int updateCalls = 0;
  Object? updateError;
  ProfileUpdateInput? lastUpdate;

  @override
  Future<UserProfile> loadProfile() {
    loadCalls += 1;
    return loadCompleter.future;
  }

  @override
  Future<ProfileImageUpload> uploadAvatar({
    required String filePath,
    String? filename,
  }) {
    uploadCalls += 1;
    return _uploadCompleter?.future ?? Future.value(_upload());
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async {
    updateCalls += 1;
    lastUpdate = input;
    if (updateError case final Object error) throw error;
    return _profile(username: input.username ?? '原昵称');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WalletGateway implements WalletSummaryGateway {
  final Completer<WalletStats> loadCompleter = Completer<WalletStats>();
  int loadCalls = 0;

  @override
  Future<WalletStats> loadStats() {
    loadCalls += 1;
    return loadCompleter.future;
  }
}

class _ImagePicker implements ProfileImagePicker {
  const _ImagePicker(this.image);

  final PickedProfileImage? image;

  @override
  Future<PickedProfileImage?> pickAvatar({BuildContext? context}) async =>
      image;
}

class _DeferredImagePicker implements ProfileImagePicker {
  final Completer<PickedProfileImage?> result =
      Completer<PickedProfileImage?>();

  @override
  Future<PickedProfileImage?> pickAvatar({BuildContext? context}) =>
      result.future;
}

class _AuthGateway implements AuthGateway {
  const _AuthGateway();

  @override
  Future<AuthSession> restoreSession(AuthSession savedSession) async {
    return savedSession;
  }

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
