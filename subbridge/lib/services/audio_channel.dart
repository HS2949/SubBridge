import 'dart:async';
import 'package:flutter/services.dart';

class AudioCaptureChannel {
  static const _method = MethodChannel('com.subbridge/audio_capture');
  static const _subtitleEvent = EventChannel('com.subbridge/subtitle_stream');

  // 자막 스트림 (EventChannel — 확정 자막 전달용)
  static Stream<String> get subtitleStream => _subtitleEvent
      .receiveBroadcastStream()
      .map((e) => e.toString());

  // MediaProjection 권한 요청 후 캡처 서비스 시작
  static Future<bool> startCapture() async {
    try {
      final result = await _method.invokeMethod<bool>('startCapture');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> stopCapture() async {
    try {
      await _method.invokeMethod('stopCapture');
    } on PlatformException {
      // 무시
    }
  }

  // 서비스 현재 상태 문자열 조회 (폴링용)
  static Future<String> getStatus() async {
    try {
      final result = await _method.invokeMethod<String>('getStatus');
      return result ?? '';
    } on PlatformException {
      return '';
    }
  }

  // 다운로드 진행률 0~100, -1이면 진행 중 아님
  static Future<int> getDownloadProgress() async {
    try {
      final result = await _method.invokeMethod<int>('getDownloadProgress');
      return result ?? -1;
    } on PlatformException {
      return -1;
    }
  }
}
