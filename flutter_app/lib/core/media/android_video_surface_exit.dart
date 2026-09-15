import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Coordinates Android [SurfaceView] teardown before a Flutter route starts
/// its exit transition.
class AndroidVideoSurfaceExit {
  AndroidVideoSurfaceExit._();

  static const MethodChannel _channel = MethodChannel(
    'com.good.pet.hospital/video_surface_exit',
  );
  static const Duration _methodTimeout = Duration(milliseconds: 450);

  static Future<void>? _preparationInFlight;

  @visibleForTesting
  static bool? debugPlatformIsAndroid;

  static bool get isSupported => debugPlatformIsAndroid ?? Platform.isAndroid;

  static Future<void> prepareForRouteExit() {
    if (!isSupported) {
      return Future<void>.value();
    }
    final current = _preparationInFlight;
    if (current != null) return current;

    final preparation = _invokePrepare();
    _preparationInFlight = preparation;
    preparation.whenComplete(() {
      if (identical(_preparationInFlight, preparation)) {
        _preparationInFlight = null;
      }
    });
    return preparation;
  }

  static Future<void> restoreAfterCanceledExit() async {
    if (!isSupported) return;
    try {
      await _channel
          .invokeMethod<void>('restoreAfterCanceledExit')
          .timeout(_methodTimeout);
    } on MissingPluginException {
      // Non-Android tests and older app binaries do not install the bridge.
    } on PlatformException {
      // A restore failure must not make route navigation fail.
    } on TimeoutException {
      // Keep predictive-back cancellation responsive on vendor Android builds.
    }
  }

  static Future<void> _invokePrepare() async {
    try {
      await _channel
          .invokeMethod<Object?>('prepareForExit')
          .timeout(_methodTimeout);
    } on MissingPluginException {
      // Non-Android tests and older app binaries do not install the bridge.
    } on PlatformException {
      // Flutter still replaces the PlatformView with its placeholder below.
    } on TimeoutException {
      // Native also has a timeout; this is the final deadlock guard.
    }
  }
}
