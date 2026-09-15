import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_media_content.dart';
import 'package:pet_hospital_flutter/features/friends/presentation/friend_media_controller.dart';

void main() {
  late Directory directory;
  late File image;
  late File video;
  late _FakePicker picker;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('friend-media-test-');
    image = await File('${directory.path}/photo.jpg').writeAsBytes([1, 2, 3]);
    video = await File('${directory.path}/clip.mp4').writeAsBytes([4, 5, 6]);
    picker = _FakePicker();
  });

  tearDown(() => directory.delete(recursive: true));

  test('图片选择应用压缩参数并保留元数据', () async {
    picker.image = XFile(image.path, mimeType: 'image/jpeg', name: 'photo.jpg');
    final controller = FriendMediaController(
      picker: picker,
      imageMetadataReader: (_) async =>
          const FriendMediaMetadata(width: 1200, height: 900),
    );

    final draft = await controller.pickImage(ImageSource.camera);

    expect(picker.imageSource, ImageSource.camera);
    expect(picker.maxWidth, 1200);
    expect(picker.maxHeight, 1200);
    expect(picker.imageQuality, 80);
    expect(draft?.type, FriendMediaType.image);
    expect(draft?.width, 1200);
    expect(draft?.height, 900);
    expect(draft?.size, 3);
    expect(draft?.mimeType, 'image/jpeg');
  });

  test('相机长按录像结果按视频读取元数据并生成预览', () async {
    final thumbnail = await File(
      '${directory.path}/camera-cover.jpg',
    ).writeAsBytes([7, 8, 9]);
    picker.image = XFile(video.path, mimeType: 'video/mp4', name: 'clip.mp4');
    final controller = FriendMediaController(
      picker: picker,
      videoMetadataReader: (_) async =>
          const FriendMediaMetadata(width: 1080, height: 1920, duration: 8),
      videoThumbnailGenerator: (_) async => thumbnail.path,
    );

    final draft = await controller.captureMedia();

    expect(picker.imageSource, ImageSource.camera);
    expect(draft?.type, FriendMediaType.video);
    expect(draft?.duration, 8);
    expect(draft?.localThumbnailPath, thumbnail.path);
  });

  test('视频先读取尺寸时长并允许缩略图生成失败', () async {
    picker.video = XFile(video.path, mimeType: 'video/mp4', name: 'clip.mp4');
    final controller = FriendMediaController(
      picker: picker,
      videoMetadataReader: (_) async =>
          const FriendMediaMetadata(width: 1920, height: 1080, duration: 65),
      videoThumbnailGenerator: (_) async => throw StateError('抽帧失败'),
    );

    final draft = await controller.pickVideo();

    expect(picker.videoSource, ImageSource.gallery);
    expect(draft?.type, FriendMediaType.video);
    expect(draft?.duration, 65);
    expect(draft?.localThumbnailPath, isNull);
    expect(draft?.fileName, 'clip.mp4');
  });

  test('视频选择成功后生成本地缩略图用于预览和上传', () async {
    final thumbnail = await File(
      '${directory.path}/clip-cover.jpg',
    ).writeAsBytes([7, 8, 9]);
    picker.video = XFile(video.path, mimeType: 'video/mp4', name: 'clip.mp4');
    final controller = FriendMediaController(
      picker: picker,
      videoMetadataReader: (_) async =>
          const FriendMediaMetadata(width: 1920, height: 1080, duration: 65),
      videoThumbnailGenerator: (path) async {
        expect(path, video.path);
        return thumbnail.path;
      },
    );

    final draft = await controller.pickVideo();

    expect(draft?.localThumbnailPath, thumbnail.path);
    expect(draft?.width, 1920);
    expect(draft?.height, 1080);
  });

  test('图片和视频混合多选时透传上限并最多准备 9 个媒体', () async {
    picker.multipleMedia = List.generate(
      10,
      (index) => index.isEven
          ? XFile(image.path, mimeType: 'image/jpeg', name: 'photo-$index.jpg')
          : XFile(video.path, mimeType: 'video/mp4', name: 'clip-$index.mp4'),
    );
    final controller = FriendMediaController(
      picker: picker,
      imageMetadataReader: (_) async =>
          const FriendMediaMetadata(width: 1200, height: 900),
      videoMetadataReader: (_) async =>
          const FriendMediaMetadata(width: 1920, height: 1080, duration: 65),
    );

    final drafts = await controller.pickMedia();

    expect(picker.mediaLimit, 9);
    expect(picker.maxWidth, 1200);
    expect(picker.maxHeight, 1200);
    expect(picker.imageQuality, 80);
    expect(drafts, hasLength(9));
    expect(drafts[0].type, FriendMediaType.image);
    expect(drafts[1].type, FriendMediaType.video);
    expect(drafts.last.type, FriendMediaType.image);
  });
}

class _FakePicker implements FriendMediaPickerGateway {
  XFile? image;
  XFile? video;
  List<XFile> multipleMedia = const [];
  ImageSource? imageSource;
  ImageSource? videoSource;
  double? maxWidth;
  double? maxHeight;
  int? imageQuality;
  int? mediaLimit;

  @override
  Future<XFile?> pickImage({
    BuildContext? context,
    required ImageSource source,
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
  }) async {
    imageSource = source;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    this.imageQuality = imageQuality;
    return image;
  }

  @override
  Future<XFile?> pickVideo({
    BuildContext? context,
    required ImageSource source,
  }) async {
    videoSource = source;
    return video;
  }

  @override
  Future<List<XFile>> pickMultipleMedia({
    BuildContext? context,
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
    required int limit,
  }) async {
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    this.imageQuality = imageQuality;
    mediaLimit = limit;
    return multipleMedia;
  }
}
