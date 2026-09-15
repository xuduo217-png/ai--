import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import 'camera_media_models.dart';

typedef AvailableCamerasProvider = Future<List<CameraDescription>> Function();
typedef CameraControllerFactory =
    CameraController Function(
      CameraDescription description,
      ResolutionPreset resolutionPreset, {
      required bool enableAudio,
    });

CameraController _createCameraController(
  CameraDescription description,
  ResolutionPreset resolutionPreset, {
  required bool enableAudio,
}) {
  return CameraController(
    description,
    resolutionPreset,
    enableAudio: enableAudio,
  );
}

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({
    super.key,
    required this.options,
    this.availableCamerasProvider = availableCameras,
    this.cameraControllerFactory = _createCameraController,
  });

  final CameraMediaPickerOptions options;
  final AvailableCamerasProvider availableCamerasProvider;
  final CameraControllerFactory cameraControllerFactory;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraCapturedMedia? _captured;
  VideoPlayerController? _videoPreviewController;
  Timer? _recordingTimer;
  DateTime? _recordingStartedAt;
  Duration _recordingElapsed = Duration.zero;
  FlashMode _flashMode = FlashMode.off;
  bool _initializing = true;
  bool _busy = false;
  bool _startingRecording = false;
  bool _recording = false;
  bool _stoppingRecording = false;
  bool _releaseRequested = false;
  bool _discardRequested = false;
  bool _lifecycleInactive = false;
  bool _permissionError = false;
  String? _error;
  int _cameraGeneration = 0;
  Completer<void>? _recordingStartCompleter;
  Future<void>? _cameraInitialization;
  Future<void>? _cameraDeactivation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _lifecycleInactive = true;
      unawaited(_deactivateCamera());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _lifecycleInactive = false;
      if (_captured == null) unawaited(_initializeCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _videoPreviewController?.dispose();
    final controller = _controller;
    final recordingStart = _recordingStartCompleter?.future;
    _controller = null;
    _cameraGeneration += 1;
    if (controller != null) {
      unawaited(_releaseController(controller, recordingStart));
    }
    super.dispose();
  }

  Future<void> _initializeCamera({CameraLensDirection? lensDirection}) {
    final generation = ++_cameraGeneration;
    final previousInitialization = _cameraInitialization;
    final previousDeactivation = _cameraDeactivation;
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
        _permissionError = false;
      });
    }
    final initialization = _runCameraInitialization(
      generation: generation,
      lensDirection: lensDirection,
      previousInitialization: previousInitialization,
      previousDeactivation: previousDeactivation,
    );
    _cameraInitialization = initialization;
    return initialization.whenComplete(() {
      if (identical(_cameraInitialization, initialization)) {
        _cameraInitialization = null;
      }
    });
  }

  Future<void> _runCameraInitialization({
    required int generation,
    required CameraLensDirection? lensDirection,
    required Future<void>? previousInitialization,
    required Future<void>? previousDeactivation,
  }) async {
    CameraController? newController;

    try {
      await previousInitialization;
      await previousDeactivation;
      if (!mounted || _lifecycleInactive || generation != _cameraGeneration) {
        return;
      }

      final previousController = _controller;
      _controller = null;
      if (previousController != null) {
        await _disposeControllerQuietly(previousController);
      }
      if (!mounted || _lifecycleInactive || generation != _cameraGeneration) {
        return;
      }

      final cameras = _cameras.isEmpty
          ? await widget.availableCamerasProvider()
          : _cameras;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', '当前设备没有可用相机');
      }
      final requestedLens =
          lensDirection ?? widget.options.preferredLensDirection;
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == requestedLens,
        orElse: () => cameras.first,
      );
      newController = widget.cameraControllerFactory(
        description,
        widget.options.resolutionPreset,
        enableAudio: widget.options.needsMicrophonePermission,
      );
      await newController.initialize();
      if (widget.options.allowVideo) {
        await newController.prepareForVideoRecording();
      }
      await newController.setFlashMode(_flashMode);
      if (!mounted || _lifecycleInactive || generation != _cameraGeneration) {
        await _disposeControllerQuietly(newController);
        return;
      }
      setState(() {
        _cameras = cameras;
        _controller = newController;
        _initializing = false;
      });
      newController = null;
    } on CameraException catch (error) {
      if (newController != null) {
        await _disposeControllerQuietly(newController);
      }
      if (!mounted || _lifecycleInactive || generation != _cameraGeneration) {
        return;
      }
      _setCameraError(error);
    } on Object {
      if (newController != null) {
        await _disposeControllerQuietly(newController);
      }
      if (!mounted || _lifecycleInactive || generation != _cameraGeneration) {
        return;
      }
      _setError('相机启动失败，请稍后重试');
    }
  }

  Future<void> _deactivateCamera() {
    _cameraGeneration += 1;
    _recordingTimer?.cancel();
    final previousDeactivation = _cameraDeactivation;
    final controller = _controller;
    final recordingStart = _recordingStartCompleter?.future;
    _releaseRequested = true;
    _discardRequested = true;
    _controller = null;
    if (mounted) setState(() => _initializing = true);
    final deactivation = _releaseCameraForLifecycle(
      previousDeactivation,
      controller,
      recordingStart,
    );
    _cameraDeactivation = deactivation;
    return deactivation.whenComplete(() {
      if (identical(_cameraDeactivation, deactivation)) {
        _cameraDeactivation = null;
      }
    });
  }

  Future<void> _releaseCameraForLifecycle(
    Future<void>? previousDeactivation,
    CameraController? controller,
    Future<void>? recordingStart,
  ) async {
    await previousDeactivation;
    if (controller != null) {
      await _releaseController(controller, recordingStart);
    }
    _resetRecordingState(notify: mounted);
  }

  void _setCameraError(CameraException error) {
    final permissionError = const {
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
      'AudioAccessDenied',
      'AudioAccessDeniedWithoutPrompt',
      'AudioAccessRestricted',
    }.contains(error.code);
    final message = switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' => '相机权限未开启，请在系统设置中允许访问相机',
      'AudioAccessDenied' ||
      'AudioAccessDeniedWithoutPrompt' ||
      'AudioAccessRestricted' => '麦克风权限未开启，请在系统设置中允许录制声音',
      'NoCamera' => '当前设备没有可用相机',
      _ => error.description ?? '相机启动失败，请稍后重试',
    };
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _permissionError = permissionError;
      _error = message;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _error = message;
    });
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (!widget.options.allowPhoto ||
        controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _recording ||
        _startingRecording) {
      return;
    }
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) {
        await _deleteFile(file.path);
        return;
      }
      setState(() {
        _captured = CameraCapturedMedia(
          file: file,
          type: CameraCapturedMediaType.image,
        );
        _busy = false;
      });
    } on CameraException catch (error) {
      _showCaptureError(error.description ?? '拍照失败，请重试');
    } on Object {
      _showCaptureError('拍照失败，请重试');
    }
  }

  Future<void> _startVideoRecording() async {
    final controller = _controller;
    if (!widget.options.allowVideo ||
        controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _recording ||
        _startingRecording) {
      return;
    }
    setState(() {
      _startingRecording = true;
      _releaseRequested = false;
      _discardRequested = false;
    });
    final startCompleter = Completer<void>();
    _recordingStartCompleter = startCompleter;
    try {
      await controller.startVideoRecording(enablePersistentRecording: false);
      if (!mounted || !identical(controller, _controller)) {
        if (controller.value.isRecordingVideo) {
          final file = await controller.stopVideoRecording();
          await _deleteFile(file.path);
        }
        return;
      }
      _recordingStartedAt = DateTime.now();
      setState(() {
        _startingRecording = false;
        _recording = true;
        _recordingElapsed = Duration.zero;
      });
      _recordingTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _updateRecordingElapsed(),
      );
      if (_releaseRequested) {
        await _stopVideoRecording(discard: _discardRequested);
      }
    } on CameraException catch (error) {
      _resetRecordingState(notify: mounted);
      _showCaptureError(error.description ?? '录像启动失败，请重试');
    } on Object {
      _resetRecordingState(notify: mounted);
      _showCaptureError('录像启动失败，请重试');
    } finally {
      if (!startCompleter.isCompleted) startCompleter.complete();
      if (identical(_recordingStartCompleter, startCompleter)) {
        _recordingStartCompleter = null;
      }
    }
  }

  void _updateRecordingElapsed() {
    final startedAt = _recordingStartedAt;
    if (!_recording || startedAt == null) return;
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed >= widget.options.maxVideoDuration) {
      _recordingElapsed = widget.options.maxVideoDuration;
      unawaited(_stopVideoRecording());
      return;
    }
    if (mounted) setState(() => _recordingElapsed = elapsed);
  }

  Future<void> _finishVideoRecording() async {
    _releaseRequested = true;
    final recordingStart = _recordingStartCompleter?.future;
    if (recordingStart != null) await recordingStart;
    await _stopVideoRecording();
  }

  Future<void> _cancelVideoRecording() async {
    _releaseRequested = true;
    _discardRequested = true;
    final recordingStart = _recordingStartCompleter?.future;
    if (recordingStart != null) await recordingStart;
    await _stopVideoRecording(discard: true);
  }

  Future<void> _stopVideoRecording({bool discard = false}) async {
    if (_stoppingRecording || (!_recording && !_startingRecording)) return;
    if (_startingRecording) {
      _releaseRequested = true;
      _discardRequested = _discardRequested || discard;
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    _stoppingRecording = true;
    _recordingTimer?.cancel();
    final duration = _recordingStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_recordingStartedAt!);
    try {
      final file = await controller.stopVideoRecording();
      final shouldDiscard =
          discard ||
          _discardRequested ||
          duration < widget.options.minVideoDuration;
      _resetRecordingState(notify: false);
      if (shouldDiscard) {
        await _deleteFile(file.path);
        if (!discard && mounted) _showCaptureError('录像时间太短');
        return;
      }
      await _showVideoPreview(file);
    } on CameraException catch (error) {
      _resetRecordingState(notify: mounted);
      _showCaptureError(error.description ?? '录像保存失败，请重试');
    } on Object {
      _resetRecordingState(notify: mounted);
      _showCaptureError('录像保存失败，请重试');
    } finally {
      _stoppingRecording = false;
    }
  }

  Future<void> _showVideoPreview(XFile file) async {
    final previewController = VideoPlayerController.file(File(file.path));
    try {
      await previewController.initialize();
      await previewController.setLooping(true);
      await previewController.play();
    } on Object {
      await previewController.dispose();
      await _deleteFile(file.path);
      _showCaptureError('视频预览失败，请重新拍摄');
      return;
    }
    if (!mounted) {
      await previewController.dispose();
      await _deleteFile(file.path);
      return;
    }
    setState(() {
      _videoPreviewController = previewController;
      _captured = CameraCapturedMedia(
        file: file,
        type: CameraCapturedMediaType.video,
      );
    });
  }

  void _resetRecordingState({required bool notify}) {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStartedAt = null;
    _recordingElapsed = Duration.zero;
    _startingRecording = false;
    _recording = false;
    _releaseRequested = false;
    _discardRequested = false;
    if (notify && mounted) setState(() {});
  }

  void _showCaptureError(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _startingRecording = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _switchCamera() async {
    final current = _controller?.description;
    if (_cameras.length < 2 || current == null || _busy || _recording) return;
    final currentIndex = _cameras.indexWhere((camera) => camera == current);
    final next = _cameras[(currentIndex + 1) % _cameras.length];
    await _initializeCamera(lensDirection: next.lensDirection);
  }

  Future<void> _cycleFlashMode() async {
    final controller = _controller;
    if (controller == null || _busy || _recording) return;
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      FlashMode.always || FlashMode.torch => FlashMode.off,
    };
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException {
      _showCaptureError('当前相机不支持该闪光灯模式');
    }
  }

  Future<void> _retake() async {
    final captured = _captured;
    if (captured == null) return;
    final previewController = _videoPreviewController;
    _videoPreviewController = null;
    await previewController?.dispose();
    await _deleteFile(captured.file.path);
    if (mounted) setState(() => _captured = null);
  }

  Future<void> _acceptCapture() async {
    final captured = _captured;
    if (captured == null) return;
    final previewController = _videoPreviewController;
    _videoPreviewController = null;
    await previewController?.dispose();
    await _disposeCameraController();
    if (mounted) Navigator.of(context).pop(captured);
  }

  Future<void> _close() async {
    if (_startingRecording || _recording) {
      await _cancelVideoRecording();
    }
    final captured = _captured;
    final previewController = _videoPreviewController;
    _videoPreviewController = null;
    await previewController?.dispose();
    if (captured != null) await _deleteFile(captured.file.path);
    await _disposeCameraController();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _disposeCameraController() async {
    _cameraGeneration += 1;
    final controller = _controller;
    final recordingStart = _recordingStartCompleter?.future;
    _controller = null;
    if (controller != null) {
      await _releaseController(controller, recordingStart);
    }
  }

  static Future<void> _releaseController(
    CameraController controller,
    Future<void>? recordingStart,
  ) async {
    try {
      await recordingStart;
      if (controller.value.isRecordingVideo) {
        final file = await controller.stopVideoRecording();
        await _deleteFile(file.path);
      }
    } on Object {
      // 页面退出或生命周期切换时只需尽力清理录像文件和相机资源。
    } finally {
      await controller.dispose();
    }
  }

  static Future<void> _disposeControllerQuietly(
    CameraController controller,
  ) async {
    try {
      await controller.dispose();
    } on Object {
      // 初始化失败或任务过期时只需尽力释放底层相机。
    }
  }

  static Future<void> _deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } on Object {
      // 临时文件清理失败不影响相机主流程。
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<CameraCapturedMedia>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _captured != null
            ? _buildCapturedPreview()
            : _buildCameraContent(),
      ),
    );
  }

  Widget _buildCameraContent() {
    final controller = _controller;
    if (_error != null) return _buildError();
    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraPreview(controller),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0x99000000),
              ],
              stops: [0, 0.22, 0.62, 1],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildTopControls(),
              const Spacer(),
              if (_recording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    _formatDuration(_recordingElapsed),
                    key: const ValueKey('camera-recording-duration'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              CameraCaptureShutter(
                allowPhoto: widget.options.allowPhoto,
                allowVideo: widget.options.allowVideo,
                busy: _busy || _startingRecording || _stoppingRecording,
                recording: _recording,
                recordingProgress:
                    _recordingElapsed.inMilliseconds /
                    widget.options.maxVideoDuration.inMilliseconds,
                onTakePhoto: _takePhoto,
                onVideoStart: _startVideoRecording,
                onVideoEnd: _finishVideoRecording,
                onVideoCancel: _cancelVideoRecording,
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final width = portrait ? previewSize.height : previewSize.width;
    final height = portrait ? previewSize.width : previewSize.height;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _CameraIconButton(
            key: const ValueKey('camera-close'),
            tooltip: '关闭相机',
            icon: Icons.close_rounded,
            onPressed: _close,
          ),
          const Spacer(),
          _CameraIconButton(
            key: const ValueKey('camera-flash'),
            tooltip: '切换闪光灯',
            icon: switch (_flashMode) {
              FlashMode.off => Icons.flash_off_rounded,
              FlashMode.auto => Icons.flash_auto_rounded,
              FlashMode.always || FlashMode.torch => Icons.flash_on_rounded,
            },
            onPressed: _cycleFlashMode,
          ),
          if (_cameras.length > 1) ...[
            const SizedBox(width: 8),
            _CameraIconButton(
              key: const ValueKey('camera-switch'),
              tooltip: '切换摄像头',
              icon: Icons.cameraswitch_rounded,
              onPressed: _switchCamera,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCapturedPreview() {
    final captured = _captured!;
    final preview = captured.type == CameraCapturedMediaType.image
        ? Image.file(
            File(captured.file.path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 56,
            ),
          )
        : _buildVideoPreview();
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Center(child: preview),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(44, 20, 44, 34),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PreviewActionButton(
                    key: const ValueKey('camera-retake'),
                    tooltip: '重新拍摄',
                    icon: Icons.replay_rounded,
                    onPressed: _retake,
                  ),
                  _PreviewActionButton(
                    key: const ValueKey('camera-use-media'),
                    tooltip: '使用此媒体',
                    icon: Icons.check_rounded,
                    backgroundColor: const Color(0xFF22C55E),
                    onPressed: _acceptCapture,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoPreviewController;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 12,
            child: _CameraIconButton(
              tooltip: '关闭相机',
              icon: Icons.close_rounded,
              onPressed: _close,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    color: Colors.white70,
                    size: 58,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_permissionError)
                    FilledButton.icon(
                      onPressed: openAppSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('前往设置'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _initializeCamera,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final tenths = (duration.inMilliseconds % 1000) ~/ 100;
    return '00:${seconds.toString().padLeft(2, '0')}.$tenths';
  }
}

class CameraCaptureShutter extends StatefulWidget {
  const CameraCaptureShutter({
    super.key,
    required this.allowPhoto,
    required this.allowVideo,
    required this.busy,
    required this.recording,
    required this.recordingProgress,
    required this.onTakePhoto,
    required this.onVideoStart,
    required this.onVideoEnd,
    required this.onVideoCancel,
  });

  final bool allowPhoto;
  final bool allowVideo;
  final bool busy;
  final bool recording;
  final double recordingProgress;
  final Future<void> Function() onTakePhoto;
  final Future<void> Function() onVideoStart;
  final Future<void> Function() onVideoEnd;
  final Future<void> Function() onVideoCancel;

  @override
  State<CameraCaptureShutter> createState() => _CameraCaptureShutterState();
}

class _CameraCaptureShutterState extends State<CameraCaptureShutter> {
  bool _videoGestureActive = false;

  @override
  Widget build(BuildContext context) {
    final progress = widget.recordingProgress.clamp(0.0, 1.0);
    final enabled = !widget.busy || widget.recording;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.allowPhoto && widget.allowVideo
          ? '轻触拍照，长按录像'
          : widget.allowVideo
          ? '长按录像'
          : '拍照',
      child: GestureDetector(
        key: const ValueKey('camera-shutter'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.allowPhoto && !widget.busy
            ? () => unawaited(widget.onTakePhoto())
            : null,
        onLongPressStart: widget.allowVideo && !widget.busy
            ? (_) {
                _videoGestureActive = true;
                unawaited(widget.onVideoStart());
              }
            : null,
        onLongPressEnd: widget.allowVideo
            ? (_) {
                if (!_videoGestureActive) return;
                _videoGestureActive = false;
                unawaited(widget.onVideoEnd());
              }
            : null,
        onLongPressCancel: widget.allowVideo
            ? () {
                if (!_videoGestureActive) return;
                _videoGestureActive = false;
                unawaited(widget.onVideoCancel());
              }
            : null,
        child: SizedBox.square(
          dimension: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 94,
                child: CircularProgressIndicator(
                  value: widget.recording ? progress : 0,
                  strokeWidth: 4,
                  color: const Color(0xFFEF4444),
                  backgroundColor: const Color(0x66FFFFFF),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: widget.recording ? 62 : 72,
                height: widget.recording ? 62 : 72,
                decoration: BoxDecoration(
                  color: widget.recording
                      ? const Color(0xFFEF4444)
                      : enabled
                      ? Colors.white
                      : Colors.white54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: () => unawaited(onPressed()),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0x66000000),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
    );
  }
}

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = const Color(0xCCFFFFFF),
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 64,
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: () => unawaited(onPressed()),
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: backgroundColor.computeLuminance() > 0.7
              ? Colors.black87
              : Colors.white,
        ),
        icon: Icon(icon, size: 34),
      ),
    );
  }
}
