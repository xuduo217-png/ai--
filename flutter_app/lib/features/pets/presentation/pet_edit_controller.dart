import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/media/camera_media_picker.dart';
import '../../../core/media/gallery_media_picker.dart';
import '../domain/pet_models.dart';
import 'pet_editor_result.dart';

export 'pet_editor_result.dart';

typedef PetFileExists = bool Function(String path);
typedef PetNow = DateTime Function();

enum PetImageSource { gallery, camera }

class PickedPetImage {
  const PickedPetImage({required this.path, this.filename});

  final String path;
  final String? filename;
}

abstract interface class PetImagePicker {
  Future<PickedPetImage?> pickAvatar(
    PetImageSource source, {
    BuildContext? context,
  });
}

class MediaPetImagePicker implements PetImagePicker {
  MediaPetImagePicker({
    GalleryMediaPicker? galleryMediaPicker,
    CameraMediaPicker? cameraMediaPicker,
  }) : _galleryMediaPicker = galleryMediaPicker ?? GalleryMediaPicker(),
       _cameraMediaPicker = cameraMediaPicker ?? CameraMediaPicker();

  final GalleryMediaPicker _galleryMediaPicker;
  final CameraMediaPicker _cameraMediaPicker;

  @override
  Future<PickedPetImage?> pickAvatar(
    PetImageSource source, {
    BuildContext? context,
  }) async {
    if (context == null) {
      throw StateError('选择或拍摄宠物头像需要 BuildContext');
    }
    if (source == PetImageSource.gallery) {
      final images = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.image,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (images.isEmpty) return null;
      final image = images.single;
      return PickedPetImage(path: image.path, filename: image.name);
    }

    final captured = await _cameraMediaPicker.capture(
      context: context,
      allowPhoto: true,
      allowVideo: false,
      enableAudio: false,
      permissionDescription: '拍照需要使用相机，用于设置宠物头像。',
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    final image = captured?.file;
    if (image == null) return null;
    return PickedPetImage(path: image.path, filename: image.name);
  }
}

enum PetAvatarUploadStatus { cancelled, uploaded, failed, busy }

class PetAvatarUploadOutcome {
  const PetAvatarUploadOutcome._(this.status, {this.url, this.message});

  const PetAvatarUploadOutcome.cancelled()
    : this._(PetAvatarUploadStatus.cancelled);

  const PetAvatarUploadOutcome.uploaded(String url)
    : this._(PetAvatarUploadStatus.uploaded, url: url);

  const PetAvatarUploadOutcome.failed(String message)
    : this._(PetAvatarUploadStatus.failed, message: message);

  const PetAvatarUploadOutcome.busy()
    : this._(PetAvatarUploadStatus.busy, message: '头像正在上传，请稍候');

  final PetAvatarUploadStatus status;
  final String? url;
  final String? message;
}

class PetValidationException implements Exception {
  const PetValidationException(this.message, {this.field});

  final String message;
  final String? field;

  @override
  String toString() => message;
}

class PetEditController extends ChangeNotifier {
  PetEditController({
    required PetGateway gateway,
    this.petId,
    PetImagePicker? imagePicker,
    PetFileExists? fileExists,
    PetNow? now,
  }) : _gateway = gateway,
       _imagePicker = imagePicker ?? MediaPetImagePicker(),
       _fileExists = fileExists ?? _defaultFileExists,
       _now = now ?? DateTime.now;

  final PetGateway _gateway;
  final PetImagePicker _imagePicker;
  final PetFileExists _fileExists;
  final PetNow _now;
  final int? petId;

  PetDraft _draft = PetDraft.empty();
  List<PetCategory> _categories = const [];
  String? _loadError;
  String? _categoryError;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isDeleting = false;
  bool _disposed = false;
  Future<void>? _loadFuture;
  Future<PetEditorResult>? _saveFuture;
  Future<PetEditorResult>? _deleteFuture;

  PetDraft get draft => _draft;
  List<PetCategory> get categories => _categories;
  String? get loadError => _loadError;
  String? get categoryError => _categoryError;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploading => _isUploading;
  bool get isDeleting => _isDeleting;
  bool get isBusy => _isSaving || _isUploading || _isDeleting;
  bool get isEditing => petId != null;

  Future<void> load() {
    if (_disposed) return Future<void>.value();
    final active = _loadFuture;
    if (active != null) return active;
    final load = _runLoad();
    _loadFuture = load;
    return load;
  }

  Future<void> _runLoad() async {
    _isLoading = true;
    _notify();
    final futures = <Future<void>>[_loadCategories()];
    if (petId case final int id) futures.add(_loadDetail(id));
    await Future.wait(futures);
    if (_disposed) return;
    _isLoading = false;
    _loadFuture = null;
    _notify();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _gateway.loadCategoryTree();
      if (_disposed) return;
      _categories = categories;
      _categoryError = null;
    } on Object {
      if (_disposed) return;
      _categoryError = '宠物类型加载失败，请稍后重试';
    }
  }

  Future<void> _loadDetail(int id) async {
    try {
      final pet = await _gateway.loadPet(id);
      if (_disposed) return;
      _draft = PetDraft.fromPet(pet);
      _loadError = null;
    } on Object {
      if (_disposed) return;
      _loadError = '宠物资料加载失败，请稍后重试';
    }
  }

  Future<void> retry() => load();

  void updateName(String value) => _updateDraft(_draft.copyWith(name: value));

  void updateAvatarUrl(String value) {
    _updateDraft(_draft.copyWith(avatarUrl: value));
  }

  void updateCategory(int? value) {
    final changed = value != _draft.categoryId;
    _updateDraft(
      _draft.copyWith(
        categoryId: value,
        clearCategoryId: value == null,
        clearSubCategoryId: changed,
      ),
    );
  }

  void updateSubCategory(int? value) {
    _updateDraft(
      _draft.copyWith(subCategoryId: value, clearSubCategoryId: value == null),
    );
  }

  void updateGender(PetGender value) {
    _updateDraft(_draft.copyWith(gender: value));
  }

  void updateBirthDate(DateTime? value) {
    _updateDraft(
      _draft.copyWith(birthDate: value, clearBirthDate: value == null),
    );
  }

  void updateWeight(String value) {
    _updateDraft(_draft.copyWith(weightText: value));
  }

  void updateNeutered(bool value) {
    _updateDraft(_draft.copyWith(isNeutered: value));
  }

  void updateVaccineCount(String value) {
    _updateDraft(_draft.copyWith(vaccineCountText: value));
  }

  void _updateDraft(PetDraft value) {
    if (_disposed) return;
    _draft = value;
    _notify();
  }

  Future<PetAvatarUploadOutcome> pickAndUploadAvatar(
    PetImageSource source, {
    BuildContext? context,
  }) {
    if (_disposed) {
      return Future.value(
        const PetAvatarUploadOutcome.failed('页面已关闭，请重新进入后操作'),
      );
    }
    if (_isUploading) {
      return Future.value(const PetAvatarUploadOutcome.busy());
    }
    _isUploading = true;
    _notify();
    return _runAvatarUpload(source, context);
  }

  Future<PetAvatarUploadOutcome> _runAvatarUpload(
    PetImageSource source,
    BuildContext? context,
  ) async {
    try {
      final PickedPetImage? image;
      try {
        image = await _imagePicker.pickAvatar(source, context: context);
      } on Object {
        final sourceLabel = source == PetImageSource.camera ? '相机' : '相册';
        return PetAvatarUploadOutcome.failed('无法访问$sourceLabel，请检查权限后重试');
      }
      if (image == null) return const PetAvatarUploadOutcome.cancelled();
      if (!_fileExists(image.path)) {
        return const PetAvatarUploadOutcome.failed('所选图片不存在，请重新选择');
      }

      try {
        final upload = await _gateway.uploadAvatar(
          filePath: image.path,
          filename: image.filename,
        );
        if (_disposed) return const PetAvatarUploadOutcome.cancelled();
        _draft = _draft.copyWith(avatarUrl: upload.url);
        return PetAvatarUploadOutcome.uploaded(upload.url);
      } on Object {
        return const PetAvatarUploadOutcome.failed('头像上传失败，请稍后重试');
      }
    } finally {
      _isUploading = false;
      _notify();
    }
  }

  Future<PetEditorResult> save() {
    if (_disposed) return Future.error(StateError('宠物编辑控制器已释放'));
    final active = _saveFuture;
    if (active != null) return active;
    final validationError = _validate(_draft, now: _now());
    if (validationError != null) return Future.error(validationError);

    _isSaving = true;
    _notify();
    late final Future<PetEditorResult> save;
    save = _runSave().whenComplete(() {
      if (_saveFuture == save) _saveFuture = null;
      _isSaving = false;
      _notify();
    });
    _saveFuture = save;
    return save;
  }

  Future<PetEditorResult> _runSave() async {
    if (petId case final int id) {
      await _gateway.updatePet(id, _draft);
      if (_disposed) throw StateError('宠物编辑控制器已释放');
      return PetEditorResult.updated;
    }
    await _gateway.createPet(_draft);
    if (_disposed) throw StateError('宠物编辑控制器已释放');
    return PetEditorResult.created;
  }

  Future<PetEditorResult> delete() {
    if (_disposed) return Future.error(StateError('宠物编辑控制器已释放'));
    final id = petId;
    if (id == null) return Future.error(StateError('新建宠物不能删除'));
    final active = _deleteFuture;
    if (active != null) return active;

    _isDeleting = true;
    _notify();
    late final Future<PetEditorResult> deletion;
    deletion = _runDelete(id).whenComplete(() {
      if (_deleteFuture == deletion) _deleteFuture = null;
      _isDeleting = false;
      _notify();
    });
    _deleteFuture = deletion;
    return deletion;
  }

  Future<PetEditorResult> _runDelete(int id) async {
    await _gateway.deletePet(id);
    if (_disposed) throw StateError('宠物编辑控制器已释放');
    return PetEditorResult.deleted;
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

PetValidationException? _validate(PetDraft draft, {required DateTime now}) {
  final name = draft.name.trim();
  if (name.isEmpty) {
    return const PetValidationException('请输入宠物名称', field: 'name');
  }
  if (name.length > 50) {
    return const PetValidationException('宠物名称不能超过 50 个字符', field: 'name');
  }
  if (draft.categoryId == null) {
    return const PetValidationException('请选择宠物类型', field: 'categoryId');
  }
  final birthDate = draft.birthDate;
  if (birthDate == null) {
    return const PetValidationException('请选择出生日期', field: 'birthDate');
  }
  final today = DateTime(now.year, now.month, now.day);
  final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
  if (!birth.isBefore(today)) {
    return const PetValidationException('出生日期必须早于今天', field: 'birthDate');
  }
  if (draft.gender == PetGender.unknown) {
    return const PetValidationException('请选择宠物性别', field: 'gender');
  }
  final weight = double.tryParse(draft.weightText.trim());
  if (weight == null || !weight.isFinite) {
    return const PetValidationException('请输入有效体重', field: 'weight');
  }
  if (weight <= 0) {
    return const PetValidationException('体重必须大于 0', field: 'weight');
  }
  if (weight > 999.99) {
    return const PetValidationException('体重不能超过 999.99 公斤', field: 'weight');
  }
  final vaccineText = draft.vaccineCountText.trim();
  final vaccineCount = int.tryParse(vaccineText);
  if (vaccineCount == null) {
    return const PetValidationException('疫苗针数必须是整数', field: 'vaccineCount');
  }
  if (vaccineCount < 0) {
    return const PetValidationException('疫苗针数不能小于 0', field: 'vaccineCount');
  }
  return null;
}
