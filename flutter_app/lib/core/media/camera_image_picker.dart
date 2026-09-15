import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../widgets/app_permission_dialog.dart';

typedef CameraPermissionStatusReader = Future<bool> Function();
typedef CameraPermissionDialog =
    Future<bool> Function(BuildContext context, String description);

class CameraImagePicker {
  CameraImagePicker({
    ImagePicker? imagePicker,
    CameraPermissionStatusReader? permissionStatusReader,
    CameraPermissionDialog? permissionDialog,
    TargetPlatform? targetPlatform,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _permissionStatusReader =
           permissionStatusReader ?? _isCameraPermissionGranted,
       _permissionDialog = permissionDialog ?? _showPermissionDialog,
       _targetPlatform = targetPlatform;

  final ImagePicker _imagePicker;
  final CameraPermissionStatusReader _permissionStatusReader;
  final CameraPermissionDialog _permissionDialog;
  final TargetPlatform? _targetPlatform;

  Future<XFile?> takePhoto({
    required BuildContext context,
    String permissionDescription = '拍摄照片需要使用相机，用于上传或发送您拍摄的图片。',
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (maxWidth != null && maxWidth <= 0) {
      throw ArgumentError.value(maxWidth, 'maxWidth', '必须大于 0');
    }
    if (maxHeight != null && maxHeight <= 0) {
      throw ArgumentError.value(maxHeight, 'maxHeight', '必须大于 0');
    }
    if (imageQuality != null && (imageQuality < 0 || imageQuality > 100)) {
      throw ArgumentError.value(imageQuality, 'imageQuality', '必须在 0 到 100 之间');
    }
    if ((_targetPlatform ?? defaultTargetPlatform) == TargetPlatform.android) {
      var hasPermission = false;
      try {
        hasPermission = await _permissionStatusReader();
      } on Object {
        // 权限状态读取失败时仍先展示用途说明，系统权限由 image_picker 继续处理。
      }
      if (!hasPermission) {
        if (!context.mounted ||
            !await _permissionDialog(context, permissionDescription) ||
            !context.mounted) {
          return null;
        }
      }
    }
    if (!context.mounted) return null;
    return _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: preferredCameraDevice,
      requestFullMetadata: requestFullMetadata,
    );
  }

  Future<List<XFile>> retrieveLostPhotos({int? maxCount}) async {
    if (maxCount != null && maxCount < 1) {
      throw ArgumentError.value(maxCount, 'maxCount', '必须大于 0');
    }
    final response = await _imagePicker.retrieveLostData();
    final files =
        response.files ?? <XFile>[if (response.file != null) response.file!];
    return maxCount == null
        ? List<XFile>.unmodifiable(files)
        : List<XFile>.unmodifiable(files.take(maxCount));
  }

  static Future<bool> _isCameraPermissionGranted() async {
    return (await Permission.camera.status).isGranted;
  }

  static Future<bool> _showPermissionDialog(
    BuildContext context,
    String description,
  ) {
    return showAppPermissionDialog(
      context: context,
      icon: Icons.photo_camera_rounded,
      title: '需要相机权限',
      description: description,
      assurances: const ['只在您主动拍照时访问相机', '拍摄内容仅用于当前操作'],
      confirmText: '允许使用相机',
      cancelText: '暂不拍照',
      accentColor: AppColors.primary,
      confirmButtonKey: const ValueKey('camera-permission-confirm'),
      cancelButtonKey: const ValueKey('camera-permission-cancel'),
    );
  }
}
