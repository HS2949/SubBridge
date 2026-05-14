package com.subbridge.subbridge

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val MEDIA_PROJECTION_REQUEST = 1001
        const val METHOD_CHANNEL = "com.subbridge/audio_capture"
        const val SUBTITLE_EVENT = "com.subbridge/subtitle_stream"
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCapture" -> {
                        pendingResult = result
                        requestMediaProjection()
                    }
                    "stopCapture" -> {
                        stopService(Intent(this, AudioCaptureService::class.java))
                        AudioCaptureService.lastStatus = "중지됨"
                        AudioCaptureService.downloadProgress = -1
                        result.success(null)
                    }
                    // Flutter 폴링용 — EventChannel 타이밍 문제 없이 항상 최신 상태 반환
                    "getStatus" -> result.success(AudioCaptureService.lastStatus)
                    "getDownloadProgress" -> result.success(AudioCaptureService.downloadProgress)
                    else -> result.notImplemented()
                }
            }

        // 자막 EventChannel: AudioCaptureService → Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SUBTITLE_EVENT)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    AudioCaptureService.subtitleSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    AudioCaptureService.subtitleSink = null
                }
            })
    }

    private fun requestMediaProjection() {
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(manager.createScreenCaptureIntent(), MEDIA_PROJECTION_REQUEST)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == MEDIA_PROJECTION_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val intent = Intent(this, AudioCaptureService::class.java).apply {
                    putExtra(AudioCaptureService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(AudioCaptureService.EXTRA_DATA, data)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }
}
