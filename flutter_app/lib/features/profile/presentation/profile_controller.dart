import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/media/gallery_media_picker.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../wallet/domain/wallet_models.dart';
import '../domain/profile_models.dart';

typedef ProfileFileExists = bool Function(String path);
typedef ProfileControllerFactory =
    ProfileController Function(AuthController authController);

class PickedProfileImage {
  const PickedProfileImage({required this.path, this.filename});

  final String path;
  final String? filename;
}

abstract interface class ProfileImagePicker {
  Future<PickedProfileImage?> pickAvatar({BuildContext? context});
}

class GalleryProfileImagePicker implements ProfileImagePicker {
  GalleryProfileImagePicker({GalleryMediaPicker? galleryMediaPicker})
    : _galleryMediaPicker = galleryMediaPicker ?? GalleryMediaPicker();

  final GalleryMediaPicker _galleryMediaPicker;

  @override
  Future<PickedProfileImage?> pickAvatar({BuildContext? context}) async {
    if (context == null) {
      throw StateError('从相册选择头像需要 BuildContext');
    }
    final images = await _galleryMediaPicker.pick(
      context: context,
      mediaType: GalleryMediaType.image,
      imageQuality: 85,
    );
    if (images.isEmpty) return null;
    final image = images.single;
    return PickedProfileImage(path: image.path, filename: image.name);
  }
}

enum ProfileAvatarUploadStatus { cancelled, uploaded, failed, busy }

class ProfileAvatarUploadOutcome {
  const ProfileAvatarUploadOutcome._(this.status, {this.url, this.message});

  const ProfileAvatarUploadOutcome.cancelled()
    : this._(ProfileAvatarUploadStatus.cancelled);

  const ProfileAvatarUploadOutcome.uploaded(String url)
    : this._(ProfileAvatarUploadStatus.uploaded, url: url);

  const ProfileAvatarUploadOutcome.failed(String message)
    : this._(ProfileAvatarUploadStatus.failed, message: message);

  const ProfileAvatarUploadOutcome.busy()
    : this._(ProfileAvatarUploadStatus.busy, message: '头像正在上传，请稍候');

  final ProfileAvatarUploadStatus status;
  final String? url;
  final String? message;
}

enum ProfileSaveResult { saved, noChanges }

class ProfileController extends ChangeNotifier {
  ProfileController({
    required ProfileGateway profileGateway,
    required WalletSummaryGateway walletGateway,
    required AuthController authController,
    ProfileImagePicker? imagePicker,
    ProfileFileExists? fileExists,
    this.notificationUnreadCount = 0,
  }) : _profileGateway = profileGateway,
       _walletGateway = walletGateway,
       _authController = authController,
       _imagePicker = imagePicker ?? GalleryProfileImagePicker(),
       _fileExists = fileExists ?? _defaultFileExists,
       _profile = authController.session == null
           ? null
           : userProfileFromSessionProfile(
               authController.session!.profile.cast<String, Object?>(),
             ),
       _isInitialLoading = authController.session == null;

  final ProfileGateway _profileGateway;
  final WalletSummaryGateway _walletGateway;
  final AuthController _authController;
  final ProfileImagePicker _imagePicker;
  final ProfileFileExists _fileExists;
  final int notificationUnreadCount;

  UserProfile? _profile;
  WalletStats? _walletStats;
  String? _profileError;
  String? _walletError;
  bool _isInitialLoading;
  bool _isRefreshing = false;
  bool _isUploading = false;
  bool _isSaving = false;
  bool _disposed = false;
  Future<void>? _refreshFuture;
  Future<ProfileSaveResult>? _saveFuture;

  UserProfile? get profile => _profile;
  WalletStats? get walletStats => _walletStats;
  String? get profileError => _profileError;
  String? get walletError => _walletError;
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isUploading => _isUploading;
  bool get isSaving => _isSaving;
  bool get isBusy => _isUploading || _isSaving;

  Future<void> load() => refresh();

  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) return activeRefresh;
    final refresh = _runRefresh();
    _refreshFuture = refresh;
    return refresh;
  }

  Future<void> _runRefresh() async {
    _isRefreshing = true;
    _notify();

    final results = await Future.wait<Object>([
      _loadProfileResult(),
      _loadWalletResult(),
    ]);
    if (_disposed) return;

    final profileResult = results[0] as _ProfileLoadResult;
    final walletResult = results[1] as _WalletLoadResult;

    if (profileResult.profile case final UserProfile loadedProfile) {
      try {
        await _authController.updateProfile(loadedProfile.toSessionPatch());
        if (_disposed) return;
        _profile = loadedProfile;
        _profileError = null;
      } on Object {
        if (_disposed) return;
        _profileError = '个人资料刷新失败，请稍后重试';
      }
    } else {
      _profileError = '个人资料刷新失败，请稍后重试';
    }

    if (walletResult.stats case final WalletStats loadedStats) {
      _walletStats = loadedStats;
      _walletError = null;
    } else {
      _walletError = '钱包数据加载失败，请稍后重试';
    }

    _isInitialLoading = false;
    _isRefreshing = false;
    _refreshFuture = null;
    _notify();
  }

  Future<_ProfileLoadResult> _loadProfileResult() async {
    try {
      return _ProfileLoadResult(profile: await _profileGateway.loadProfile());
    } on Object catch (error) {
      return _ProfileLoadResult(error: error);
    }
  }

  Future<_WalletLoadResult> _loadWalletResult() async {
    try {
      return _WalletLoadResult(stats: await _walletGateway.loadStats());
    } on Object catch (error) {
      return _WalletLoadResult(error: error);
    }
  }

  Future<ProfileAvatarUploadOutcome> pickAndUploadAvatar({
    BuildContext? context,
  }) {
    if (_disposed) {
      return Future.value(
        const ProfileAvatarUploadOutcome.failed('页面已关闭，请重新进入后操作'),
      );
    }
    if (_isUploading) {
      return Future.value(const ProfileAvatarUploadOutcome.busy());
    }
    _isUploading = true;
    _notify();
    return _runAvatarUpload(context);
  }

  Future<ProfileAvatarUploadOutcome> _runAvatarUpload(
    BuildContext? context,
  ) async {
    try {
      final PickedProfileImage? image;
      try {
        image = await _imagePicker.pickAvatar(context: context);
      } on Object {
        return const ProfileAvatarUploadOutcome.failed('无法访问相册，请检查权限后重试');
      }
      if (_disposed) return const ProfileAvatarUploadOutcome.cancelled();
      if (image == null) return const ProfileAvatarUploadOutcome.cancelled();
      if (!_fileExists(image.path)) {
        return const ProfileAvatarUploadOutcome.failed('所选图片不存在，请重新选择');
      }

      try {
        final upload = await _profileGateway.uploadAvatar(
          filePath: image.path,
          filename: image.filename,
        );
        if (_disposed) {
          return const ProfileAvatarUploadOutcome.cancelled();
        }
        return ProfileAvatarUploadOutcome.uploaded(upload.url);
      } on Object {
        return const ProfileAvatarUploadOutcome.failed('头像上传失败，请稍后重试');
      }
    } finally {
      _isUploading = false;
      _notify();
    }
  }

  Future<ProfileSaveResult> saveProfile(ProfileEditDraft draft) {
    if (_disposed) {
      return Future.error(StateError('个人中心控制器已释放'));
    }
    final activeSave = _saveFuture;
    if (activeSave != null) return activeSave;
    final nickname = draft.nickname.trim();
    if (nickname.isEmpty) {
      return Future.error(const ProfileValidationException('请输入昵称'));
    }
    final currentProfile = _profile;
    if (currentProfile == null) {
      return Future.error(StateError('个人资料尚未加载完成'));
    }
    final input = ProfileEditDraft(
      nickname: nickname,
      gender: draft.gender,
      avatarUrl: draft.avatarUrl,
    ).changesFrom(currentProfile);
    if (input.isEmpty) return Future.value(ProfileSaveResult.noChanges);

    _isSaving = true;
    _notify();
    final save = _runSave(input);
    _saveFuture = save;
    return save;
  }

  Future<ProfileSaveResult> _runSave(ProfileUpdateInput input) async {
    try {
      final updatedProfile = await _profileGateway.updateProfile(input);
      if (_disposed) throw StateError('个人中心控制器已释放');
      await _authController.updateProfile(updatedProfile.toSessionPatch());
      if (_disposed) throw StateError('个人中心控制器已释放');
      _profile = updatedProfile;
      _profileError = null;
      return ProfileSaveResult.saved;
    } finally {
      _isSaving = false;
      _saveFuture = null;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static bool _defaultFileExists(String path) => File(path).existsSync();
}

class _ProfileLoadResult {
  const _ProfileLoadResult({this.profile, this.error});

  final UserProfile? profile;
  final Object? error;
}

class _WalletLoadResult {
  const _WalletLoadResult({this.stats, this.error});

  final WalletStats? stats;
  final Object? error;
}
