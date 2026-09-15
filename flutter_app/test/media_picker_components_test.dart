import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/media/camera_capture_page.dart';
import 'package:pet_hospital_flutter/core/media/camera_image_picker.dart';
import 'package:pet_hospital_flutter/core/media/camera_media_picker.dart';
import 'package:pet_hospital_flutter/core/media/gallery_media_picker.dart';

void main() {
  group('GalleryMediaPicker', () {
    testWidgets('透传媒体类型、单多选和限制参数', (tester) async {
      final context = await _pumpContext(tester);
      final gateway = _RecordingGalleryGateway();
      final picker = GalleryMediaPicker(
        gateway: gateway,
        targetPlatform: TargetPlatform.iOS,
      );

      await picker.pick(
        context: context,
        mediaType: GalleryMediaType.imageAndVideo,
        allowMultiple: true,
        maxCount: 6,
        maxWidth: 1200,
        maxHeight: 900,
        imageQuality: 80,
        maxVideoDuration: const Duration(minutes: 3),
      );

      expect(gateway.pickCalls, 1);
      expect(gateway.lastOptions?.mediaType, GalleryMediaType.imageAndVideo);
      expect(gateway.lastOptions?.allowMultiple, isTrue);
      expect(gateway.lastOptions?.maxCount, 6);
      expect(gateway.lastOptions?.maxWidth, 1200);
      expect(gateway.lastOptions?.maxHeight, 900);
      expect(gateway.lastOptions?.imageQuality, 80);
      expect(gateway.lastOptions?.maxVideoDuration, const Duration(minutes: 3));
    });

    testWidgets('单选固定最多返回一个文件', (tester) async {
      final context = await _pumpContext(tester);
      final gateway = _RecordingGalleryGateway(
        result: List.generate(3, (index) => XFile('/tmp/$index.jpg')),
      );
      final picker = GalleryMediaPicker(
        gateway: gateway,
        targetPlatform: TargetPlatform.iOS,
      );

      final result = await picker.pick(
        context: context,
        mediaType: GalleryMediaType.image,
      );

      expect(gateway.lastOptions?.maxCount, 1);
      expect(result, hasLength(1));
    });

    testWidgets('Android 未授权时先展示用途说明，取消后不打开选择器', (tester) async {
      final context = await _pumpContext(tester);
      final gateway = _RecordingGalleryGateway(permissionGranted: false);
      final picker = GalleryMediaPicker(
        gateway: gateway,
        targetPlatform: TargetPlatform.android,
      );

      final resultFuture = picker.pick(
        context: context,
        mediaType: GalleryMediaType.video,
      );
      await tester.pumpAndSettle();

      expect(find.text('需要相册权限'), findsOneWidget);
      expect(find.textContaining('选择视频需要读取设备相册'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gallery-permission-cancel')));
      await tester.pumpAndSettle();

      expect(await resultFuture, isEmpty);
      expect(gateway.permissionChecks, 1);
      expect(gateway.pickCalls, 0);
    });

    testWidgets('Android 已授权时不展示用途说明', (tester) async {
      final context = await _pumpContext(tester);
      var dialogCalls = 0;
      final gateway = _RecordingGalleryGateway(permissionGranted: true);
      final picker = GalleryMediaPicker(
        gateway: gateway,
        targetPlatform: TargetPlatform.android,
        permissionDialog: (_, _) async {
          dialogCalls += 1;
          return true;
        },
      );

      await picker.pick(context: context, mediaType: GalleryMediaType.image);

      expect(gateway.permissionChecks, 1);
      expect(dialogCalls, 0);
      expect(gateway.pickCalls, 1);
    });

    testWidgets('iOS 不读取权限状态且不展示自定义前置弹窗', (tester) async {
      final context = await _pumpContext(tester);
      var dialogCalls = 0;
      final gateway = _RecordingGalleryGateway(permissionGranted: false);
      final picker = GalleryMediaPicker(
        gateway: gateway,
        targetPlatform: TargetPlatform.iOS,
        permissionDialog: (_, _) async {
          dialogCalls += 1;
          return true;
        },
      );

      await picker.pick(
        context: context,
        mediaType: GalleryMediaType.imageAndVideo,
      );

      expect(gateway.permissionChecks, 0);
      expect(dialogCalls, 0);
      expect(gateway.pickCalls, 1);
    });
  });

  group('CameraImagePicker', () {
    testWidgets('拒绝非正数的拍照尺寸限制', (tester) async {
      final context = await _pumpContext(tester);
      final imagePicker = _RecordingImagePicker();
      final picker = CameraImagePicker(
        imagePicker: imagePicker,
        targetPlatform: TargetPlatform.iOS,
      );

      await expectLater(
        picker.takePhoto(context: context, maxWidth: 0),
        throwsArgumentError,
      );
      await expectLater(
        picker.takePhoto(context: context, maxHeight: -1),
        throwsArgumentError,
      );
      expect(imagePicker.pickImageCalls, 0);
    });

    testWidgets('Android 未授权时先展示相机用途说明', (tester) async {
      final context = await _pumpContext(tester);
      final imagePicker = _RecordingImagePicker();
      final picker = CameraImagePicker(
        imagePicker: imagePicker,
        targetPlatform: TargetPlatform.android,
        permissionStatusReader: () async => false,
      );

      final resultFuture = picker.takePhoto(
        context: context,
        permissionDescription: '用于测试拍照权限说明。',
      );
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsOneWidget);
      expect(find.text('用于测试拍照权限说明。'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('camera-permission-cancel')));
      await tester.pumpAndSettle();

      expect(await resultFuture, isNull);
      expect(imagePicker.pickImageCalls, 0);
    });

    testWidgets('Android 已授权时直接拍照并透传图片参数', (tester) async {
      final context = await _pumpContext(tester);
      final imagePicker = _RecordingImagePicker();
      final picker = CameraImagePicker(
        imagePicker: imagePicker,
        targetPlatform: TargetPlatform.android,
        permissionStatusReader: () async => true,
        permissionDialog: (_, _) async => throw StateError('不应展示弹窗'),
      );

      await picker.takePhoto(
        context: context,
        maxWidth: 1200,
        maxHeight: 900,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );

      expect(imagePicker.pickImageCalls, 1);
      expect(imagePicker.lastSource, ImageSource.camera);
      expect(imagePicker.lastMaxWidth, 1200);
      expect(imagePicker.lastMaxHeight, 900);
      expect(imagePicker.lastImageQuality, 80);
      expect(imagePicker.lastCameraDevice, CameraDevice.front);
    });

    testWidgets('iOS 不读取权限状态且不展示自定义前置弹窗', (tester) async {
      final context = await _pumpContext(tester);
      var permissionChecks = 0;
      var dialogCalls = 0;
      final imagePicker = _RecordingImagePicker();
      final picker = CameraImagePicker(
        imagePicker: imagePicker,
        targetPlatform: TargetPlatform.iOS,
        permissionStatusReader: () async {
          permissionChecks += 1;
          return false;
        },
        permissionDialog: (_, _) async {
          dialogCalls += 1;
          return true;
        },
      );

      await picker.takePhoto(context: context);

      expect(permissionChecks, 0);
      expect(dialogCalls, 0);
      expect(imagePicker.pickImageCalls, 1);
    });

    testWidgets('恢复 Android 丢失的拍照结果时应用数量限制', (tester) async {
      final imagePicker = _RecordingImagePicker(
        lostFiles: List.generate(4, (index) => XFile('/tmp/lost-$index.jpg')),
      );
      final picker = CameraImagePicker(imagePicker: imagePicker);

      final result = await picker.retrieveLostPhotos(maxCount: 2);

      expect(result, hasLength(2));
    });
  });

  group('CameraMediaPicker', () {
    testWidgets('Android 照片和视频未授权时先说明相机与麦克风用途', (tester) async {
      final context = await _pumpContext(tester);
      CameraMediaPickerOptions? launchedOptions;
      final picker = CameraMediaPicker(
        targetPlatform: TargetPlatform.android,
        permissionStatusReader: (_) async => const CameraMediaPermissionState(
          cameraGranted: false,
          microphoneGranted: false,
        ),
        captureLauncher: (_, options) async {
          launchedOptions = options;
          return CameraCapturedMedia(
            file: XFile('/tmp/captured.mp4'),
            type: CameraCapturedMediaType.video,
          );
        },
      );

      final resultFuture = picker.capture(
        context: context,
        allowPhoto: true,
        allowVideo: true,
        permissionDescription: '用于测试聊天相机权限。',
      );
      await tester.pumpAndSettle();

      expect(find.text('需要相机和麦克风权限'), findsOneWidget);
      expect(find.text('用于测试聊天相机权限。'), findsOneWidget);
      expect(launchedOptions, isNull);
      await tester.tap(
        find.byKey(const ValueKey('camera-media-permission-confirm')),
      );
      await tester.pumpAndSettle();

      expect((await resultFuture)?.type, CameraCapturedMediaType.video);
      expect(launchedOptions?.allowPhoto, isTrue);
      expect(launchedOptions?.allowVideo, isTrue);
      expect(launchedOptions?.needsMicrophonePermission, isTrue);
    });

    testWidgets('Android 仅拍照时不要求麦克风权限', (tester) async {
      final context = await _pumpContext(tester);
      CameraMediaPickerOptions? checkedOptions;
      var launchCalls = 0;
      final picker = CameraMediaPicker(
        targetPlatform: TargetPlatform.android,
        permissionStatusReader: (options) async {
          checkedOptions = options;
          return const CameraMediaPermissionState(
            cameraGranted: false,
            microphoneGranted: false,
          );
        },
        captureLauncher: (_, _) async {
          launchCalls += 1;
          return null;
        },
      );

      final resultFuture = picker.capture(
        context: context,
        allowPhoto: true,
        allowVideo: false,
        enableAudio: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('需要相机权限'), findsOneWidget);
      expect(find.text('需要相机和麦克风权限'), findsNothing);
      expect(checkedOptions?.needsMicrophonePermission, isFalse);
      await tester.tap(
        find.byKey(const ValueKey('camera-media-permission-cancel')),
      );
      await tester.pumpAndSettle();
      expect(await resultFuture, isNull);
      expect(launchCalls, 0);
    });

    testWidgets('iOS 跳过权限预读和自绘用途弹窗', (tester) async {
      final context = await _pumpContext(tester);
      var launchCalls = 0;
      final picker = CameraMediaPicker(
        targetPlatform: TargetPlatform.iOS,
        permissionStatusReader: (_) async => throw StateError('iOS 不应预读权限'),
        permissionDialog: (_, _) async => throw StateError('iOS 不应显示自绘权限弹窗'),
        captureLauncher: (_, _) async {
          launchCalls += 1;
          return CameraCapturedMedia(
            file: XFile('/tmp/captured.mp4'),
            type: CameraCapturedMediaType.video,
          );
        },
      );

      final result = await picker.capture(
        context: context,
        allowPhoto: true,
        allowVideo: true,
      );

      expect(result?.type, CameraCapturedMediaType.video);
      expect(launchCalls, 1);
      expect(find.textContaining('需要相机'), findsNothing);
    });

    testWidgets('透传相机模式、镜头、画质和录像时长参数', (tester) async {
      final context = await _pumpContext(tester);
      CameraMediaPickerOptions? launchedOptions;
      final picker = CameraMediaPicker(
        targetPlatform: TargetPlatform.iOS,
        captureLauncher: (_, options) async {
          launchedOptions = options;
          return null;
        },
      );

      await picker.capture(
        context: context,
        allowPhoto: false,
        allowVideo: true,
        enableAudio: false,
        maxVideoDuration: const Duration(seconds: 30),
        minVideoDuration: const Duration(seconds: 2),
        resolutionPreset: ResolutionPreset.medium,
        preferredLensDirection: CameraLensDirection.front,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 76,
      );

      expect(launchedOptions?.allowPhoto, isFalse);
      expect(launchedOptions?.allowVideo, isTrue);
      expect(launchedOptions?.enableAudio, isFalse);
      expect(launchedOptions?.maxVideoDuration, const Duration(seconds: 30));
      expect(launchedOptions?.minVideoDuration, const Duration(seconds: 2));
      expect(launchedOptions?.resolutionPreset, ResolutionPreset.medium);
      expect(
        launchedOptions?.preferredLensDirection,
        CameraLensDirection.front,
      );
      expect(launchedOptions?.maxWidth, 1600);
      expect(launchedOptions?.maxHeight, 900);
      expect(launchedOptions?.imageQuality, 76);
      expect(launchedOptions?.needsMicrophonePermission, isFalse);
    });

    testWidgets('拒绝空模式和无效录像时长', (tester) async {
      final context = await _pumpContext(tester);
      final picker = CameraMediaPicker(targetPlatform: TargetPlatform.iOS);

      expect(
        picker.capture(context: context, allowPhoto: false, allowVideo: false),
        throwsArgumentError,
      );
      expect(
        picker.capture(
          context: context,
          allowVideo: true,
          minVideoDuration: const Duration(seconds: 3),
          maxVideoDuration: const Duration(seconds: 2),
        ),
        throwsArgumentError,
      );
    });
  });

  group('CameraCaptureShutter', () {
    testWidgets('轻触只拍照', (tester) async {
      var photoCalls = 0;
      var videoStartCalls = 0;
      var videoEndCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CameraCaptureShutter(
                allowPhoto: true,
                allowVideo: true,
                busy: false,
                recording: false,
                recordingProgress: 0,
                onTakePhoto: () async => photoCalls += 1,
                onVideoStart: () async => videoStartCalls += 1,
                onVideoEnd: () async => videoEndCalls += 1,
                onVideoCancel: () async {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('camera-shutter')));
      await tester.pump();

      expect(photoCalls, 1);
      expect(videoStartCalls, 0);
      expect(videoEndCalls, 0);
    });

    testWidgets('长按开始并在松手时结束录像且不拍照', (tester) async {
      var photoCalls = 0;
      var videoStartCalls = 0;
      var videoEndCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CameraCaptureShutter(
                allowPhoto: true,
                allowVideo: true,
                busy: false,
                recording: false,
                recordingProgress: 0,
                onTakePhoto: () async => photoCalls += 1,
                onVideoStart: () async => videoStartCalls += 1,
                onVideoEnd: () async => videoEndCalls += 1,
                onVideoCancel: () async {},
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const ValueKey('camera-shutter')));
      await tester.pump();

      expect(photoCalls, 0);
      expect(videoStartCalls, 1);
      expect(videoEndCalls, 1);
    });
  });

  group('CameraCapturePage', () {
    testWidgets('Android 首次授权恢复后会等待旧初始化并自动打开相机', (tester) async {
      final firstInitialization = Completer<void>();
      final controllers = <_TestCameraController>[];
      const camera = CameraDescription(
        name: 'back-camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CameraCapturePage(
            options: const CameraMediaPickerOptions(
              allowPhoto: true,
              allowVideo: true,
              enableAudio: true,
              maxVideoDuration: Duration(seconds: 15),
              minVideoDuration: Duration(seconds: 1),
              resolutionPreset: ResolutionPreset.medium,
              preferredLensDirection: CameraLensDirection.back,
            ),
            availableCamerasProvider: () async => const [camera],
            cameraControllerFactory:
                (description, resolutionPreset, {required enableAudio}) {
                  final controller = _TestCameraController(
                    description,
                    resolutionPreset,
                    initialization: controllers.isEmpty
                        ? firstInitialization.future.then<void>(
                            (_) => throw CameraException(
                              'CameraAccessDenied',
                              '旧初始化已因权限弹窗失效',
                            ),
                          )
                        : Future<void>.value(),
                    enableAudio: enableAudio,
                  );
                  controllers.add(controller);
                  return controller;
                },
          ),
        ),
      );
      await tester.pump();
      expect(controllers, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controllers, hasLength(1));

      firstInitialization.complete();
      await tester.pumpAndSettle();

      expect(controllers, hasLength(2));
      expect(controllers.first.disposed, isTrue);
      expect(controllers.last.disposed, isFalse);
      expect(find.text('相机启动失败，请稍后重试'), findsNothing);
      expect(find.byKey(const ValueKey('camera-shutter')), findsOneWidget);
    });

    testWidgets('连续进入后台状态时会等待相机完全释放再恢复', (tester) async {
      final firstDisposal = Completer<void>();
      final controllers = <_TestCameraController>[];
      const camera = CameraDescription(
        name: 'back-camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CameraCapturePage(
            options: const CameraMediaPickerOptions(
              allowPhoto: true,
              allowVideo: false,
              enableAudio: false,
              maxVideoDuration: Duration(seconds: 15),
              minVideoDuration: Duration(seconds: 1),
              resolutionPreset: ResolutionPreset.medium,
              preferredLensDirection: CameraLensDirection.back,
            ),
            availableCamerasProvider: () async => const [camera],
            cameraControllerFactory:
                (description, resolutionPreset, {required enableAudio}) {
                  final controller = _TestCameraController(
                    description,
                    resolutionPreset,
                    initialization: Future<void>.value(),
                    disposal: controllers.isEmpty
                        ? firstDisposal.future
                        : Future<void>.value(),
                    enableAudio: enableAudio,
                  );
                  controllers.add(controller);
                  return controller;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controllers, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controllers, hasLength(1));

      firstDisposal.complete();
      await tester.pumpAndSettle();

      expect(controllers, hasLength(2));
      expect(controllers.first.disposed, isTrue);
      expect(find.byKey(const ValueKey('camera-shutter')), findsOneWidget);
    });
  });
}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (builderContext) {
          context = builderContext;
          return const Scaffold();
        },
      ),
    ),
  );
  return context;
}

class _RecordingGalleryGateway implements GalleryMediaPickerGateway {
  _RecordingGalleryGateway({
    this.permissionGranted = true,
    this.result = const [],
  });

  final bool permissionGranted;
  final List<XFile> result;
  int permissionChecks = 0;
  int pickCalls = 0;
  GalleryMediaPickerOptions? lastOptions;

  @override
  Future<bool> hasPermission(GalleryMediaPickerOptions options) async {
    permissionChecks += 1;
    lastOptions = options;
    return permissionGranted;
  }

  @override
  Future<List<XFile>> pick(
    BuildContext context,
    GalleryMediaPickerOptions options,
  ) async {
    pickCalls += 1;
    lastOptions = options;
    return result;
  }
}

class _RecordingImagePicker extends ImagePicker {
  _RecordingImagePicker({this.lostFiles = const []});

  final List<XFile> lostFiles;
  int pickImageCalls = 0;
  ImageSource? lastSource;
  double? lastMaxWidth;
  double? lastMaxHeight;
  int? lastImageQuality;
  CameraDevice? lastCameraDevice;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickImageCalls += 1;
    lastSource = source;
    lastMaxWidth = maxWidth;
    lastMaxHeight = maxHeight;
    lastImageQuality = imageQuality;
    lastCameraDevice = preferredCameraDevice;
    return XFile('/tmp/image.jpg');
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    return LostDataResponse(files: lostFiles);
  }
}

class _TestCameraController extends CameraController {
  _TestCameraController(
    super.description,
    super.resolutionPreset, {
    required this.initialization,
    this.disposal,
    required super.enableAudio,
  });

  final Future<void> initialization;
  final Future<void>? disposal;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    await initialization;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
    );
  }

  @override
  Future<void> prepareForVideoRecording() async {}

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    value = value.copyWith(flashMode: mode);
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);

  @override
  Future<void> dispose() async {
    disposed = true;
    await disposal;
    await super.dispose();
  }
}
