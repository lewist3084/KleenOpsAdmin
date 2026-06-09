import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to the native Android foreground service that MediaProjection
/// screen capture requires on Android 10+ (mandatory on Android 14+ /
/// API 34+, where `getMediaProjection()` throws without a running
/// `mediaProjection`-typed foreground service). The vendored flutter_webrtc
/// fork does not start one, so the app does it around `getDisplayMedia`.
///
/// No-op on every non-Android platform (web/desktop need nothing; iOS uses
/// in-app ReplayKit capture which manages its own lifecycle).
class ScreenCaptureService {
  ScreenCaptureService._();

  static const MethodChannel _channel = MethodChannel('app/screen_capture');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts the foreground service. Call immediately before
  /// `getDisplayMedia` so the projection token can be acquired.
  static Future<void> start() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('start');
    } catch (err) {
      debugPrint('[ScreenCapture] start service failed: $err');
    }
  }

  /// Stops the foreground service. Call when the share ends (including
  /// failure paths) so the ongoing notification clears.
  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (err) {
      debugPrint('[ScreenCapture] stop service failed: $err');
    }
  }
}
