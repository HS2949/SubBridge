import 'dart:async';
import 'package:flutter/services.dart';

class AudioCaptureChannel {
  static const _method = MethodChannel('com.subbridge/audio_capture');
  static const _subtitleEvent = EventChannel('com.subbridge/subtitle_stream');
  static const _statusEvent = EventChannel('com.subbridge/status_stream');

  static Stream<String> get subtitleStream => _subtitleEvent
      .receiveBroadcastStream()
      .map((e) => e.toString());

  static Stream<String> get statusStream => _statusEvent
      .receiveBroadcastStream()
      .map((e) => e.toString());

  // MediaProjection 권한 요청 후 캡처 서비스 시작
  static Future<bool> startCapture() async {
    try {
      final result = await _method.invokeMethod<bool>('startCapture');
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('startCapture error: $e');
      return false;
    }
  }

  static Future<void> stopCapture() async {
    try {
      await _method.invokeMethod('stopCapture');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('stopCapture error: $e');
    }
  }
}
