import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/media/gallery_media_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_permission_dialog.dart';
import '../domain/scan_payload.dart';

typedef CouponScanHandler = Future<void> Function(String claimCode);
typedef ActivityScanHandler = Future<void> Function(int activityId);

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    super.key,
    required this.onCouponScanned,
    required this.onActivityScanned,
    this.galleryMediaPicker,
  });

  final CouponScanHandler onCouponScanned;
  final ActivityScanHandler onActivityScanned;
  final GalleryMediaPicker? galleryMediaPicker;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  late final GalleryMediaPicker _galleryMediaPicker;

  bool _cameraRequested = false;
  bool _cameraStarting = false;
  bool _scanLocked = false;
  bool _galleryBusy = false;
  bool _permissionRationaleShown = false;
  bool _requiresSystemSettings = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _galleryMediaPicker = widget.galleryMediaPicker ?? GalleryMediaPicker();
    _scannerController = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareCamera());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_cameraRequested && !_scanLocked && !_galleryBusy) {
          unawaited(_startCamera());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_scannerController.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  Future<void> _prepareCamera() async {
    if (kIsWeb) {
      setState(() => _cameraError = '当前设备暂不支持扫一扫');
      return;
    }
    final status = await _cameraPermissionStatus();
    if (!mounted) return;
    if (status == null) {
      setState(() => _cameraError = '无法检查相机权限，请稍后重试');
      return;
    }
    if (status.isGranted) {
      _cameraRequested = true;
      await _startCamera();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _showPermissionRationale();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _cameraRequested = true;
      await _startCamera();
    }
  }

  Future<void> _showPermissionRationale() async {
    if (!mounted || _permissionRationaleShown) return;
    _permissionRationaleShown = true;
    final confirmed = await showAppPermissionDialog(
      context: context,
      icon: Icons.qr_code_scanner_rounded,
      title: '需要相机权限',
      description: '扫一扫需要使用相机识别优惠券和活动二维码。',
      assurances: const ['只在扫码页面访问相机', '不会保存或上传相机画面'],
      confirmText: '允许使用相机',
      cancelText: '暂不使用',
      confirmButtonKey: const ValueKey('scanner-permission-confirm'),
      cancelButtonKey: const ValueKey('scanner-permission-cancel'),
    );
    if (!mounted || !confirmed) return;
    _cameraRequested = true;
    await _startCamera();
  }

  Future<void> _handleCameraAction() async {
    final status = await _cameraPermissionStatus();
    if (!mounted) return;
    if (status?.isPermanentlyDenied == true || status?.isRestricted == true) {
      await openAppSettings();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        !_permissionRationaleShown) {
      await _showPermissionRationale();
      return;
    }
    _cameraRequested = true;
    await _startCamera();
  }

  Future<void> _startCamera() async {
    if (!mounted || _cameraStarting || _scannerController.value.isRunning) {
      return;
    }
    setState(() {
      _cameraStarting = true;
      _cameraError = null;
    });
    try {
      await _scannerController.start();
      if (!mounted) return;
      final scannerError = _scannerController.value.error;
      final permissionStatus = await _cameraPermissionStatus();
      if (!mounted) return;
      setState(() {
        _requiresSystemSettings =
            permissionStatus?.isPermanentlyDenied == true ||
            permissionStatus?.isRestricted == true;
        if (scannerError == null && _scannerController.value.isRunning) {
          _cameraError = null;
        } else if (_requiresSystemSettings) {
          _cameraError = '相机权限已关闭，请前往系统设置开启';
        } else if (scannerError?.errorCode ==
            MobileScannerErrorCode.permissionDenied) {
          _cameraError = '请允许相机权限后再开始扫码';
        } else if (scannerError?.errorCode ==
            MobileScannerErrorCode.unsupported) {
          _cameraError = '当前设备没有可用相机';
        } else {
          _cameraError = '相机启动失败，请稍后重试';
        }
      });
    } on Object {
      if (mounted) {
        setState(() => _cameraError = '相机启动失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _cameraStarting = false);
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_scanLocked || _galleryBusy) return;
    final rawValue = _firstRawValue(capture);
    if (rawValue == null) return;
    await _handleRawValue(rawValue);
  }

  Future<void> _handleRawValue(String rawValue) async {
    if (_scanLocked) return;
    setState(() => _scanLocked = true);
    await _scannerController.stop();
    var failed = false;
    try {
      final payload = parseScanPayload(rawValue);
      switch (payload) {
        case CouponScanPayload(:final claimCode):
          await widget.onCouponScanned(claimCode);
        case ActivityScanPayload(:final activityId):
          await widget.onActivityScanned(activityId);
      }
    } on ScanPayloadException catch (error) {
      failed = true;
      _showMessage(error.message);
    } on Object {
      failed = true;
      _showMessage('识别失败，请稍后重试');
    } finally {
      if (failed) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      if (mounted) {
        setState(() => _scanLocked = false);
        await _resumeCameraIfAllowed();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_galleryBusy || _scanLocked) return;
    setState(() => _galleryBusy = true);
    await _scannerController.stop();
    if (!mounted) return;
    try {
      final images = await _galleryMediaPicker.pick(
        context: context,
        mediaType: GalleryMediaType.image,
      );
      if (images.isEmpty) return;
      final image = images.single;
      final capture = await _scannerController.analyzeImage(image.path);
      final rawValue = capture == null ? null : _firstRawValue(capture);
      if (rawValue == null) {
        _showMessage('未识别到可用二维码，请更换清晰图片重试');
        return;
      }
      await _handleRawValue(rawValue);
    } on UnsupportedError {
      _showMessage('当前设备暂不支持相册二维码识别');
    } on Object {
      _showMessage('图片识别失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _galleryBusy = false);
        await _resumeCameraIfAllowed();
      }
    }
  }

  Future<void> _resumeCameraIfAllowed() async {
    if (!_cameraRequested || _scanLocked || _galleryBusy || !mounted) return;
    final status = await _cameraPermissionStatus();
    if (status?.isGranted == true && mounted) await _startCamera();
  }

  Future<PermissionStatus?> _cameraPermissionStatus() async {
    try {
      return await Permission.camera.status;
    } on Object {
      return null;
    }
  }

  Future<void> _toggleTorch() async {
    if (!_scannerController.value.isRunning) return;
    try {
      await _scannerController.toggleTorch();
    } on Object {
      _showMessage('补光灯切换失败');
    }
  }

  String? _firstRawValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDEE9FF), Color(0xFFFAFBFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('扫一扫'),
          foregroundColor: AppColors.ink,
          backgroundColor: const Color(0xFFDEE9FF),
          surfaceTintColor: const Color(0xFFDEE9FF),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 38,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCameraCard(context),
                    const SizedBox(height: 14),
                    _buildGuidePanel(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCard(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final height = width.clamp(280.0, 430.0);
    return Container(
      key: const ValueKey('scanner-camera-card'),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1E3A8A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) => unawaited(_handleDetection(capture)),
            errorBuilder: (_, _) => const ColoredBox(color: Color(0xFF111827)),
            placeholderBuilder: (_) =>
                const ColoredBox(color: Color(0xFF111827)),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, _) {
              if (!state.isRunning) return _buildCameraUnavailable(state);
              return _buildScanOverlay();
            },
          ),
          if (_scanLocked)
            const ColoredBox(
              color: Color(0x52000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraUnavailable(MobileScannerState state) {
    return ColoredBox(
      color: const Color(0xFFF4F7FF),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_camera_rounded,
              size: 42,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              _cameraError == null ? '扫描二维码' : '无法使用相机',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraError ?? '使用相机识别优惠券和活动二维码',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('scanner-camera-action'),
              onPressed: _cameraStarting ? null : _handleCameraAction,
              icon: _cameraStarting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                _cameraStarting
                    ? '正在开启...'
                    : _requiresSystemSettings
                    ? '前往系统设置'
                    : '开始扫码',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          const ColoredBox(color: Color(0x14000000)),
          Container(
            width: 228,
            height: 228,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Text(
              '将优惠券或活动二维码放入框内',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '扫码说明',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '支持识别优惠券和活动二维码，识别后自动进入对应详情页。',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('scanner-gallery-action'),
                  onPressed: _galleryBusy ? null : _pickFromGallery,
                  icon: _galleryBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(_galleryBusy ? '识别中...' : '从相册选择'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _scannerController,
                  builder: (context, state, _) => FilledButton.icon(
                    key: const ValueKey('scanner-torch-action'),
                    onPressed: state.isRunning ? _toggleTorch : null,
                    icon: Icon(
                      state.torchState == TorchState.on
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                    ),
                    label: Text(
                      state.torchState == TorchState.on ? '关闭补光' : '打开补光',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
