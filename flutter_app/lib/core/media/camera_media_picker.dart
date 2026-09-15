import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../widgets/app_permission_dialog.dart';
import 'camera_capture_page.dart';
import 'camera_media_models.dart';

export 'camera_media_models.dart';

class CameraMediaPermissionState {
  const CameraMediaPermissionState({
    required this.cameraGranted,
    required this.microphoneGranted,
  });

  final bool cameraGranted;
  final bool microphoneGranted;

  bool hasRequiredPermissions(CameraMediaPickerOptions options) {
    return cameraGranted &&
        (!options.needsMicrophonePermission || microphoneGranted);
  }
}

typedef CameraMediaPermissionStatusReader =
    Future<CameraMediaPermissionState> Function(
      CameraMediaPickerOptions options,
    );
typedef CameraMediaPermissionDialog =
    Future<bool> Function(
      BuildContext context,
      CameraMediaPickerOptions options,
    );
typedef CameraCaptureLauncher =
    Future<CameraCapturedMedia?> Function(
      BuildContext context,
      CameraMediaPickerOptions options,
    );

class CameraMediaPicker {
  CameraMediaPicker({
    CameraMediaPermissionStatusReader? permissionStatusReader,
    CameraMediaPermissionDialog? permissionDialog,
    CameraCaptureLauncher? captureLauncher,
    Future<Directory> Function()? temporaryDirectoryProvider,
    TargetPlatform? targetPlatform,
  }) : _permissionStatusReader = permissionStatusReader ?? _readPermissionState,
       _permissionDialog = permissionDialog ?? _showPermissionDialog,
       _captureLauncher = captureLauncher ?? _openCapturePage,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _targetPlatform = targetPlatform;

  static const Duration defaultMaxVideoDuration = Duration(seconds: 15);
  static const Duration defaultMinVideoDuration = Duration(seconds: 1);

  final CameraMediaPermissionStatusReader _permissionStatusReader;
  final CameraMediaPermissionDialog _permissionDialog;
  final CameraCaptureLauncher _captureLauncher;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final TargetPlatform? _targetPlatform;

  Future<CameraCapturedMedia?> capture({
    required BuildContext context,
    bool allowPhoto = true,
    bool allowVideo = false,
    bool enableAudio = true,
    Duration maxVideoDuration = defaultMaxVideoDuration,
    Duration minVideoDuration = defaultMinVideoDuration,
    ResolutionPreset resolutionPreset = ResolutionPreset.high,
    CameraLensDirection preferredLensDirection = CameraLensDirection.back,
    String? permissionDescription,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    _validateOptions(
      allowPhoto: allowPhoto,
      allowVideo: allowVideo,
      maxVideoDuration: maxVideoDuration,
      minVideoDuration: minVideoDuration,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    final options = CameraMediaPickerOptions(
      allowPhoto: allowPhoto,
      allowVideo: allowVideo,
      enableAudio: enableAudio,
      maxVideoDuration: maxVideoDuration,
      minVideoDuration: minVideoDuration,
      resolutionPreset: resolutionPreset,
      preferredLensDirection: preferredLensDirection,
      permissionDescription: permissionDescription,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    if ((_targetPlatform ?? defaultTargetPlatform) == TargetPlatform.android) {
      var hasPermission = false;
      try {
        final state = await _permissionStatusReader(options);
        hasPermission = state.hasRequiredPermissions(options);
      } on Object {
        // 状态读取失败时仍展示用途说明，系统权限由 camera 插件继续处理。
      }
      if (!hasPermission) {
        if (!context.mounted ||
            !await _permissionDialog(context, options) ||
            !context.mounted) {
          return null;
        }
      }
    }
    if (!context.mounted) return null;

    final captured = await _captureLauncher(context, options);
    if (captured == null || captured.type == CameraCapturedMediaType.video) {
      return captured;
    }
    return CameraCapturedMedia(
      file: await _processImage(captured.file, options),
      type: CameraCapturedMediaType.image,
    );
  }

  Future<XFile> _processImage(
    XFile source,
    CameraMediaPickerOptions options,
  ) async {
    if (options.maxWidth == null &&
        options.maxHeight == null &&
        options.imageQuality == null) {
      return source;
    }
    try {
      final dimensions = await _readImageDimensions(source.path);
      final target = _targetDimensions(
        width: dimensions.$1,
        height: dimensions.$2,
        maxWidth: options.maxWidth,
        maxHeight: options.maxHeight,
      );
      final directory = await _temporaryDirectoryProvider();
      final outputDirectory = Directory(
        path.join(directory.path, 'camera_media_picker'),
      );
      await outputDirectory.create(recursive: true);
      final sourceName = path.basenameWithoutExtension(source.name).trim();
      final outputName = sourceName.isEmpty ? 'photo' : sourceName;
      final outputPath = path.join(
        outputDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$outputName.jpg',
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        outputPath,
        minWidth: target.$1,
        minHeight: target.$2,
        quality: options.imageQuality ?? 95,
        format: CompressFormat.jpeg,
      );
      if (result == null) return source;
      return XFile(
        result.path,
        name: '$outputName.jpg',
        mimeType: 'image/jpeg',
      );
    } on Object {
      return source;
    }
  }

  static Future<(int, int)> _readImageDimensions(String filePath) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(filePath);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return (descriptor.width, descriptor.height);
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  static (int, int) _targetDimensions({
    required int width,
    required int height,
    required double? maxWidth,
    required double? maxHeight,
  }) {
    var scale = 1.0;
    if (maxWidth != null) scale = math.min(scale, maxWidth / width);
    if (maxHeight != null) scale = math.min(scale, maxHeight / height);
    return (
      math.max(1, (width * scale).round()),
      math.max(1, (height * scale).round()),
    );
  }

  static Future<CameraMediaPermissionState> _readPermissionState(
    CameraMediaPickerOptions options,
  ) async {
    final cameraGranted = (await Permission.camera.status).isGranted;
    final microphoneGranted =
        !options.needsMicrophonePermission ||
        (await Permission.microphone.status).isGranted;
    return CameraMediaPermissionState(
      cameraGranted: cameraGranted,
      microphoneGranted: microphoneGranted,
    );
  }

  static Future<bool> _showPermissionDialog(
    BuildContext context,
    CameraMediaPickerOptions options,
  ) {
    final needsMicrophone = options.needsMicrophonePermission;
    final title = needsMicrophone ? '需要相机和麦克风权限' : '需要相机权限';
    final description =
        options.permissionDescription ??
        (needsMicrophone
            ? '拍照需要使用相机，长按录像还需要使用麦克风录制声音。'
            : '拍摄照片需要使用相机，用于上传或发送您拍摄的图片。');
    return showAppPermissionDialog(
      context: context,
      icon: Icons.photo_camera_rounded,
      title: title,
      description: description,
      assurances: needsMicrophone
          ? const ['只在相机页面访问摄像头和麦克风', '拍摄内容仅用于当前操作']
          : const ['只在您主动拍照时访问相机', '拍摄内容仅用于当前操作'],
      confirmText: '继续使用',
      cancelText: '暂不使用',
      accentColor: AppColors.primary,
      confirmButtonKey: const ValueKey('camera-media-permission-confirm'),
      cancelButtonKey: const ValueKey('camera-media-permission-cancel'),
    );
  }

  static Future<CameraCapturedMedia?> _openCapturePage(
    BuildContext context,
    CameraMediaPickerOptions options,
  ) {
    return Navigator.of(context).push<CameraCapturedMedia>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraCapturePage(options: options),
      ),
    );
  }

  static void _validateOptions({
    required bool allowPhoto,
    required bool allowVideo,
    required Duration maxVideoDuration,
    required Duration minVideoDuration,
    required double? maxWidth,
    required double? maxHeight,
    required int? imageQuality,
  }) {
    if (!allowPhoto && !allowVideo) {
      throw ArgumentError('allowPhoto 和 allowVideo 至少需要启用一个');
    }
    if (maxVideoDuration <= Duration.zero) {
      throw ArgumentError.value(maxVideoDuration, 'maxVideoDuration', '必须大于 0');
    }
    if (minVideoDuration < Duration.zero ||
        minVideoDuration > maxVideoDuration) {
      throw ArgumentError.value(
        minVideoDuration,
        'minVideoDuration',
        '必须大于等于 0 且不超过 maxVideoDuration',
      );
    }
    if (maxWidth != null && maxWidth <= 0) {
      throw ArgumentError.value(maxWidth, 'maxWidth', '必须大于 0');
    }
    if (maxHeight != null && maxHeight <= 0) {
      throw ArgumentError.value(maxHeight, 'maxHeight', '必须大于 0');
    }
    if (imageQuality != null && (imageQuality < 0 || imageQuality > 100)) {
      throw ArgumentError.value(imageQuality, 'imageQuality', '必须在 0 到 100 之间');
    }
  }
}
