import 'package:camera/camera.dart';

enum CameraCapturedMediaType { image, video }

class CameraCapturedMedia {
  const CameraCapturedMedia({required this.file, required this.type});

  final XFile file;
  final CameraCapturedMediaType type;
}

class CameraMediaPickerOptions {
  const CameraMediaPickerOptions({
    required this.allowPhoto,
    required this.allowVideo,
    required this.enableAudio,
    required this.maxVideoDuration,
    required this.minVideoDuration,
    required this.resolutionPreset,
    required this.preferredLensDirection,
    this.permissionDescription,
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
  });

  final bool allowPhoto;
  final bool allowVideo;
  final bool enableAudio;
  final Duration maxVideoDuration;
  final Duration minVideoDuration;
  final ResolutionPreset resolutionPreset;
  final CameraLensDirection preferredLensDirection;
  final String? permissionDescription;
  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;

  bool get needsMicrophonePermission => allowVideo && enableAudio;
}
