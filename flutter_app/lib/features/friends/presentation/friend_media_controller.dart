import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';

import '../../../core/media/camera_media_picker.dart';
import '../../../core/media/gallery_media_picker.dart';
import '../../../core/media/local_chat_media.dart';
import '../../../core/media/video_player_view_type.dart';
import '../../../core/media/video_thumbnail_service.dart';
import '../domain/friend_media_content.dart';

class FriendMediaMetadata {
  const FriendMediaMetadata({this.width, this.height, this.duration});

  final int? width;
  final int? height;
  final int? duration;
}

abstract interface class FriendMediaPickerGateway {
  Future<XFile?> pickImage({
    BuildContext? context,
    required ImageSource source,
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
  });

  Future<XFile?> pickVideo({
    BuildContext? context,
    required ImageSource source,
  });

  Future<List<XFile>> pickMultipleMedia({
    BuildContext? context,
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
    required int limit,
  });
}

class ImagePickerFriendMediaGateway implements FriendMediaPickerGateway {
  ImagePickerFriendMediaGateway({
    GalleryMediaPicker? galleryMediaPicker,
    CameraMediaPicker? cameraMediaPicker,
  }) : _galleryMediaPicker = galleryMediaPicker ?? GalleryMediaPicker(),
       _cameraMediaPicker = cameraMediaPicker ?? CameraMediaPicker();

  final GalleryMediaPicker _galleryMediaPicker;
  final CameraMediaPicker _cameraMediaPicker;

  @override
  Future<XFile?> pickImage({
    BuildContext? context,
    required ImageSource source,
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
  }) async {
    if (context == null) {
      throw StateError('选择或拍摄聊天媒体需要 BuildContext');
    }
    if (source == ImageSource.camera) {
      final captured = await _cameraMediaPicker.capture(
        context: context,
        allowPhoto: true,
        allowVideo: true,
        permissionDescription: '在聊天中拍照需要使用相机，长按录像还需要使用麦克风录制声音。',
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      return captured?.file;
    }
    final files = await _galleryMediaPicker.pick(
      context: context,
      mediaType: GalleryMediaType.image,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    return files.isEmpty ? null : files.first;
  }

  @override
  Future<XFile?> pickVideo({
    BuildContext? context,
    required ImageSource source,
  }) async {
    if (context == null) {
      throw StateError('从相册选择聊天视频需要 BuildContext');
    }
    if (source != ImageSource.gallery) {
      throw UnsupportedError('当前仅支持从相册选择视频');
    }
    final files = await _galleryMediaPicker.pick(
      context: context,
      mediaType: GalleryMediaType.video,
    );
    return files.isEmpty ? null : files.first;
  }

  @override
  Future<List<XFile>> pickMultipleMedia({
    BuildContext? context,
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
    required int limit,
  }) {
    if (context == null) {
      throw StateError('从相册选择聊天媒体需要 BuildContext');
    }
    return _galleryMediaPicker.pick(
      context: context,
      mediaType: GalleryMediaType.imageAndVideo,
      allowMultiple: true,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      maxCount: limit,
    );
  }
}

typedef FriendMediaMetadataReader =
    Future<FriendMediaMetadata> Function(String filePath);
typedef FriendVideoThumbnailGenerator =
    Future<String?> Function(String filePath);
typedef FriendTemporaryDirectoryProvider = Future<Directory> Function();

class FriendMediaController {
  FriendMediaController({
    FriendMediaPickerGateway? picker,
    FriendMediaMetadataReader? imageMetadataReader,
    FriendMediaMetadataReader? videoMetadataReader,
    FriendVideoThumbnailGenerator? videoThumbnailGenerator,
    FriendTemporaryDirectoryProvider? temporaryDirectoryProvider,
  }) : _picker = picker ?? ImagePickerFriendMediaGateway(),
       _imageMetadataReader = imageMetadataReader ?? _readImageMetadata,
       _videoMetadataReader = videoMetadataReader ?? _readVideoMetadata,
       _videoThumbnailGenerator =
           videoThumbnailGenerator ?? VideoThumbnailService.generate,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? _systemTemporaryDirectory;

  final FriendMediaPickerGateway _picker;
  final FriendMediaMetadataReader _imageMetadataReader;
  final FriendMediaMetadataReader _videoMetadataReader;
  final FriendVideoThumbnailGenerator _videoThumbnailGenerator;
  final FriendTemporaryDirectoryProvider _temporaryDirectoryProvider;

  Future<FriendMediaSendRequest?> pickImage(
    ImageSource source, {
    BuildContext? context,
  }) async {
    final selected = await _picker.pickImage(
      context: context,
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (selected == null) return null;
    return localChatMediaKindFor(selected) == LocalChatMediaKind.video
        ? prepareVideo(selected)
        : prepareImage(selected);
  }

  Future<FriendMediaSendRequest?> captureMedia({BuildContext? context}) {
    return pickImage(ImageSource.camera, context: context);
  }

  @Deprecated(
    'Use captureMedia because the camera can return photos or videos.',
  )
  Future<FriendMediaSendRequest?> takePhoto({BuildContext? context}) {
    return captureMedia(context: context);
  }

  Future<FriendMediaSendRequest?> pickVideo({BuildContext? context}) async {
    final selected = await _picker.pickVideo(
      context: context,
      source: ImageSource.gallery,
    );
    return selected == null ? null : prepareVideo(selected);
  }

  Future<List<FriendMediaSendRequest>> pickMedia({
    BuildContext? context,
  }) async {
    final selected = limitChatMediaSelection(
      await _picker.pickMultipleMedia(
        context: context,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
        limit: maxChatMediaSelectionCount,
      ),
    );
    final drafts = <FriendMediaSendRequest>[];
    for (final file in selected) {
      drafts.add(
        localChatMediaKindFor(file) == LocalChatMediaKind.video
            ? await prepareVideo(file)
            : await prepareImage(file),
      );
    }
    return drafts;
  }

  Future<FriendMediaSendRequest> prepareImage(XFile selected) async {
    final file = await _normalizeFile(selected);
    final metadata = await _imageMetadataReader(file.path);
    return FriendMediaSendRequest(
      type: FriendMediaType.image,
      localFilePath: file.path,
      fileName: _fileName(selected, file, FriendMediaType.image),
      mimeType:
          selected.mimeType ?? _mimeType(file.path, FriendMediaType.image),
      size: await file.length(),
      width: metadata.width,
      height: metadata.height,
    );
  }

  Future<FriendMediaSendRequest> prepareVideo(XFile selected) async {
    final file = await _normalizeFile(selected);
    final metadata = await _videoMetadataReader(file.path);
    String? thumbnailPath;
    try {
      thumbnailPath = await _videoThumbnailGenerator(file.path);
    } on Object {
      thumbnailPath = null;
    }
    return FriendMediaSendRequest(
      type: FriendMediaType.video,
      localFilePath: file.path,
      localThumbnailPath: thumbnailPath,
      fileName: _fileName(selected, file, FriendMediaType.video),
      mimeType:
          selected.mimeType ?? _mimeType(file.path, FriendMediaType.video),
      size: await file.length(),
      width: metadata.width,
      height: metadata.height,
      duration: metadata.duration,
    );
  }

  Future<File> _normalizeFile(XFile selected) async {
    final rawPath = selected.path.trim();
    final resolvedPath = rawPath.startsWith('file://')
        ? Uri.parse(rawPath).toFilePath()
        : rawPath;
    final directFile = File(resolvedPath);
    if (!rawPath.startsWith('content://') && await directFile.exists()) {
      return directFile;
    }

    final directory = await _temporaryDirectoryProvider();
    await directory.create(recursive: true);
    final selectedName = selected.name.trim();
    final safeName = selectedName.isEmpty
        ? 'friend_media_${DateTime.now().microsecondsSinceEpoch}'
        : path.basename(selectedName);
    final target = File(
      path.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$safeName',
      ),
    );
    await selected.saveTo(target.path);
    return target;
  }
}

Future<Directory> _systemTemporaryDirectory() async {
  return Directory(path.join(Directory.systemTemp.path, 'friend_media'));
}

Future<FriendMediaMetadata> _readImageMetadata(String filePath) async {
  final bytes = await File(filePath).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      return FriendMediaMetadata(
        width: frame.image.width,
        height: frame.image.height,
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Future<FriendMediaMetadata> _readVideoMetadata(String filePath) async {
  final controller = VideoPlayerController.file(
    File(filePath),
    viewType: platformAdaptiveVideoViewType,
  );
  try {
    await controller.initialize();
    final duration = controller.value.duration;
    final size = controller.value.size;
    return FriendMediaMetadata(
      width: size.width > 0 ? size.width.round() : null,
      height: size.height > 0 ? size.height.round() : null,
      duration: duration > Duration.zero
          ? (duration.inMilliseconds / 1000).round().clamp(1, 1 << 31).toInt()
          : null,
    );
  } finally {
    await controller.dispose();
  }
}

String _fileName(XFile selected, File file, FriendMediaType type) {
  final selectedName = selected.name.trim();
  if (selectedName.isNotEmpty && path.extension(selectedName).isNotEmpty) {
    return path.basename(selectedName);
  }
  final extension = path.extension(file.path);
  final fallbackExtension = type == FriendMediaType.video ? '.mp4' : '.jpg';
  return 'friend_media_${DateTime.now().millisecondsSinceEpoch}'
      '${extension.isEmpty ? fallbackExtension : extension}';
}

String _mimeType(String filePath, FriendMediaType type) {
  final extension = path.extension(filePath).toLowerCase();
  return switch (extension) {
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    '.gif' => 'image/gif',
    '.heic' || '.heif' => 'image/heic',
    '.mov' => 'video/quicktime',
    '.webm' => 'video/webm',
    '.avi' => 'video/x-msvideo',
    '.mpeg' || '.mpg' => 'video/mpeg',
    _ => type == FriendMediaType.video ? 'video/mp4' : 'image/jpeg',
  };
}
