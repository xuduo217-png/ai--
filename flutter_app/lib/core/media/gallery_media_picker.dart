import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/app_permission_dialog.dart';

enum GalleryMediaType { image, video, imageAndVideo }

typedef GalleryMediaLimitExceeded =
    void Function(int selectedCount, int maxCount);
typedef GalleryPermissionDialog =
    Future<bool> Function(BuildContext context, GalleryMediaType mediaType);

class GalleryMediaPickerOptions {
  const GalleryMediaPickerOptions({
    required this.mediaType,
    required this.allowMultiple,
    required this.maxCount,
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
    this.maxVideoDuration,
  });

  final GalleryMediaType mediaType;
  final bool allowMultiple;
  final int maxCount;
  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;
  final Duration? maxVideoDuration;
}

abstract interface class GalleryMediaPickerGateway {
  Future<bool> hasPermission(GalleryMediaPickerOptions options);

  Future<List<XFile>> pick(
    BuildContext context,
    GalleryMediaPickerOptions options,
  );
}

class GalleryMediaPicker {
  GalleryMediaPicker({
    GalleryMediaPickerGateway? gateway,
    GalleryPermissionDialog? permissionDialog,
    TargetPlatform? targetPlatform,
  }) : _gateway = gateway ?? WechatGalleryMediaPickerGateway(),
       _permissionDialog = permissionDialog ?? _showPermissionDialog,
       _targetPlatform = targetPlatform;

  static const int _defaultMaxCount = 9;

  final GalleryMediaPickerGateway _gateway;
  final GalleryPermissionDialog _permissionDialog;
  final TargetPlatform? _targetPlatform;

  Future<List<XFile>> pick({
    required BuildContext context,
    required GalleryMediaType mediaType,
    bool allowMultiple = false,
    int? maxCount,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    Duration? maxVideoDuration,
    GalleryMediaLimitExceeded? onLimitExceeded,
  }) async {
    _validateOptions(
      maxCount: maxCount,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      maxVideoDuration: maxVideoDuration,
    );
    final effectiveMaxCount = allowMultiple ? maxCount ?? _defaultMaxCount : 1;
    final options = GalleryMediaPickerOptions(
      mediaType: mediaType,
      allowMultiple: allowMultiple,
      maxCount: effectiveMaxCount,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      maxVideoDuration: maxVideoDuration,
    );

    if ((_targetPlatform ?? defaultTargetPlatform) == TargetPlatform.android) {
      var hasPermission = false;
      try {
        hasPermission = await _gateway.hasPermission(options);
      } on Object {
        // 权限状态读取失败时仍先展示用途说明，避免直接触发系统权限弹窗。
      }
      if (!hasPermission) {
        if (!context.mounted ||
            !await _permissionDialog(context, mediaType) ||
            !context.mounted) {
          return const [];
        }
      }
    }
    if (!context.mounted) return const [];

    final files = await _gateway.pick(context, options);
    if (files.length > effectiveMaxCount) {
      onLimitExceeded?.call(files.length, effectiveMaxCount);
      return List<XFile>.unmodifiable(files.take(effectiveMaxCount));
    }
    return List<XFile>.unmodifiable(files);
  }

  static Future<bool> _showPermissionDialog(
    BuildContext context,
    GalleryMediaType mediaType,
  ) {
    final mediaLabel = switch (mediaType) {
      GalleryMediaType.image => '图片',
      GalleryMediaType.video => '视频',
      GalleryMediaType.imageAndVideo => '图片和视频',
    };
    return showAppPermissionDialog(
      context: context,
      icon: Icons.photo_library_rounded,
      title: '需要相册权限',
      description: '选择$mediaLabel需要读取设备相册。继续后，Android 将询问您允许访问的范围。',
      assurances: const ['只在您主动选择时访问相册', '仅处理您授权并选中的媒体文件'],
      confirmText: '继续选择',
      cancelText: '暂不选择',
      accentColor: AppColors.primary,
      confirmButtonKey: const ValueKey('gallery-permission-confirm'),
      cancelButtonKey: const ValueKey('gallery-permission-cancel'),
    );
  }

  void _validateOptions({
    required int? maxCount,
    required double? maxWidth,
    required double? maxHeight,
    required int? imageQuality,
    required Duration? maxVideoDuration,
  }) {
    if (maxCount != null && maxCount < 1) {
      throw ArgumentError.value(maxCount, 'maxCount', '必须大于 0');
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
    if (maxVideoDuration != null && maxVideoDuration <= Duration.zero) {
      throw ArgumentError.value(maxVideoDuration, 'maxVideoDuration', '必须大于 0');
    }
  }
}

class WechatGalleryMediaPickerGateway implements GalleryMediaPickerGateway {
  WechatGalleryMediaPickerGateway({
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectoryProvider;

  @override
  Future<bool> hasPermission(GalleryMediaPickerOptions options) async {
    final state = await PhotoManager.getPermissionState(
      requestOption: _permissionRequestOption(options.mediaType),
    );
    return state.hasAccess;
  }

  @override
  Future<List<XFile>> pick(
    BuildContext context,
    GalleryMediaPickerOptions options,
  ) async {
    final requestType = _requestType(options.mediaType);
    final filterOptions = options.maxVideoDuration == null
        ? null
        : FilterOptionGroup(
            videoOption: FilterOption(
              durationConstraint: DurationConstraint(
                max: options.maxVideoDuration!,
              ),
            ),
          );
    final List<AssetEntity>? assets;
    try {
      assets = await AssetPicker.pickAssets(
        context,
        permissionRequestOption: _permissionRequestOption(options.mediaType),
        pickerConfig: AssetPickerConfig(
          maxAssets: options.maxCount,
          requestType: requestType,
          filterOptions: filterOptions,
          themeColor: AppColors.primary,
        ),
      );
    } on StateError {
      return const [];
    }
    if (assets == null || assets.isEmpty) return const [];

    final files = <XFile>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;
      final title = await asset.titleAsync;
      final mimeType = await asset.mimeTypeAsync;
      final selected = XFile(
        file.path,
        name: title.isEmpty ? path.basename(file.path) : title,
        mimeType: mimeType,
      );
      files.add(
        asset.type == AssetType.image
            ? await _processImage(selected, asset, options)
            : selected,
      );
    }
    return files;
  }

  Future<XFile> _processImage(
    XFile source,
    AssetEntity asset,
    GalleryMediaPickerOptions options,
  ) async {
    if (options.maxWidth == null &&
        options.maxHeight == null &&
        options.imageQuality == null) {
      return source;
    }
    final directory = await _temporaryDirectoryProvider();
    final outputDirectory = Directory(
      path.join(directory.path, 'gallery_media_picker'),
    );
    await outputDirectory.create(recursive: true);
    final baseName = path.basenameWithoutExtension(source.name).trim();
    final outputName = baseName.isEmpty ? 'image' : baseName;
    final outputPath = path.join(
      outputDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}_$outputName.jpg',
    );
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        source.path,
        outputPath,
        minWidth: math.max(
          1,
          (options.maxWidth ?? asset.width.toDouble()).round(),
        ),
        minHeight: math.max(
          1,
          (options.maxHeight ?? asset.height.toDouble()).round(),
        ),
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

  static PermissionRequestOption _permissionRequestOption(
    GalleryMediaType mediaType,
  ) {
    return PermissionRequestOption(
      androidPermission: AndroidPermission(
        type: _requestType(mediaType),
        mediaLocation: false,
      ),
    );
  }

  static RequestType _requestType(GalleryMediaType mediaType) {
    return switch (mediaType) {
      GalleryMediaType.image => RequestType.image,
      GalleryMediaType.video => RequestType.video,
      GalleryMediaType.imageAndVideo => RequestType.common,
    };
  }
}
