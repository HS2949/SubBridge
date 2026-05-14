package com.subbridge.subbridge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class AudioCaptureService : Service() {

    companion object {
        const val TAG = "AudioCaptureService"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "subbridge_channel"
        const val SAMPLE_RATE = 16000
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        const val MODEL_DIR_NAME = "vosk-model-small-ja-0.22"
        // AlphaModel 소형 일본어 모델 다운로드 URL
        const val MODEL_URL = "https://alphacephei.com/vosk/models/vosk-model-small-ja-0.22.zip"

        // Flutter EventChannel 싱크 (MainActivity에서 연결)
        @Volatile var subtitleSink: EventChannel.EventSink? = null
        @Volatile var statusSink: EventChannel.EventSink? = null
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var captureJob: Job? = null
    private var voskModel: Model? = null
    private var recognizer: Recognizer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, -1) ?: return START_NOT_STICKY
        @Suppress("DEPRECATION")
        val projectionData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        } else {
            intent.getParcelableExtra(EXTRA_DATA)
        } ?: return START_NOT_STICKY

        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = manager.getMediaProjection(resultCode, projectionData)

        scope.launch {
            emitStatus("Vosk 모델 초기화 중...")
            val modelReady = initVosk()
            if (modelReady) {
                emitStatus("오디오 캡처 시작")
                startAudioCapture()
            } else {
                emitStatus("모델 초기화 실패 — 재시작 필요")
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    // ──────────────────────────────────────────────
    // Vosk 모델 초기화 (없으면 다운로드)
    // ──────────────────────────────────────────────
    private suspend fun initVosk(): Boolean = withContext(Dispatchers.IO) {
        try {
            val modelPath = File(filesDir, MODEL_DIR_NAME)
            if (!modelPath.exists() || !modelPath.isDirectory) {
                emitStatus("일본어 모델 다운로드 중 (~50MB)...")
                val downloaded = downloadAndUnzipModel(modelPath)
                if (!downloaded) return@withContext false
            }
            emitStatus("Vosk 모델 로딩...")
            voskModel = Model(modelPath.absolutePath)
            recognizer = Recognizer(voskModel, SAMPLE_RATE.toFloat())
            true
        } catch (e: Exception) {
            Log.e(TAG, "Vosk init failed", e)
            false
        }
    }

    private suspend fun downloadAndUnzipModel(targetDir: File): Boolean =
        withContext(Dispatchers.IO) {
            try {
                val zipFile = File(cacheDir, "vosk-model-ja.zip")
                // 다운로드
                val conn = URL(MODEL_URL).openConnection() as HttpURLConnection
                conn.connect()
                conn.inputStream.use { input ->
                    zipFile.outputStream().use { out -> input.copyTo(out) }
                }
                // 압축 해제
                java.util.zip.ZipInputStream(zipFile.inputStream()).use { zip ->
                    var entry = zip.nextEntry
                    while (entry != null) {
                        val outFile = File(filesDir, entry.name)
                        if (entry.isDirectory) {
                            outFile.mkdirs()
                        } else {
                            outFile.parentFile?.mkdirs()
                            outFile.outputStream().use { zip.copyTo(it) }
                        }
                        zip.closeEntry()
                        entry = zip.nextEntry
                    }
                }
                zipFile.delete()
                true
            } catch (e: Exception) {
                Log.e(TAG, "Model download failed", e)
                false
            }
        }

    // ──────────────────────────────────────────────
    // AudioPlaybackCapture → Vosk STT → 번역 → 자막
    // ──────────────────────────────────────────────
    private fun startAudioCapture() {
        val projection = mediaProjection ?: return
        val rec = recognizer ?: return

        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .build()

        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufSize = maxOf(minBuf, SAMPLE_RATE / 2) * 2   // 0.5초 버퍼

        audioRecord = AudioRecord.Builder()
            .setAudioPlaybackCaptureConfig(config)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufSize)
            .build()

        audioRecord?.startRecording()
        Log.d(TAG, "AudioRecord started, bufSize=$bufSize")

        captureJob = scope.launch {
            val buffer = ShortArray(bufSize / 2)
            var pendingText = StringBuilder()

            while (isActive) {
                val readCount = audioRecord?.read(buffer, 0, buffer.size) ?: break
                if (readCount <= 0) continue

                val bytes = shortsToBytes(buffer, readCount)
                val accepted = rec.acceptWaveForm(bytes, bytes.size)

                val json = if (accepted) rec.result else rec.partialResult
                val text = extractText(json, accepted)

                if (accepted && text.isNotBlank()) {
                    // 확정된 텍스트를 번역
                    pendingText.append(text)
                    val toTranslate = pendingText.toString().trim()
                    pendingText.clear()

                    val translated = translateToKorean(toTranslate)
                    if (translated.isNotBlank()) {
                        emitSubtitle(translated)
                    }
                } else if (!accepted && text.isNotBlank()) {
                    // 부분 결과는 무조건 번역하지 않고 UI에 일본어 원문만 표시 (선택)
                    // 필요 시 여기서 emitSubtitle("[$text]") 등으로 표시 가능
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    // Google Translate 비공식 무료 API
    // ──────────────────────────────────────────────
    private fun translateToKorean(text: String): String {
        return try {
            val encoded = URLEncoder.encode(text, "UTF-8")
            val url = URL(
                "https://translate.googleapis.com/translate_a/single" +
                "?client=gtx&sl=ja&tl=ko&dt=t&q=$encoded"
            )
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 5_000
            conn.readTimeout = 5_000
            conn.setRequestProperty("User-Agent", "Mozilla/5.0")

            if (conn.responseCode != 200) return text

            val raw = BufferedReader(InputStreamReader(conn.inputStream)).readText()
            parseTranslation(raw)
        } catch (e: Exception) {
            Log.w(TAG, "Translation failed: ${e.message}")
            text
        }
    }

    // 응답: [[["번역결과","원문",...],...],...] — 첫 배열의 첫 요소들을 이어 붙임
    private fun parseTranslation(raw: String): String {
        return try {
            val outer = JSONArray(raw)
            val sentences = outer.getJSONArray(0)
            val sb = StringBuilder()
            for (i in 0 until sentences.length()) {
                val segment = sentences.getJSONArray(i)
                val translated = segment.optString(0)
                if (translated.isNotBlank() && translated != "null") {
                    sb.append(translated)
                }
            }
            sb.toString().trim()
        } catch (e: Exception) {
            raw
        }
    }

    // ──────────────────────────────────────────────
    // 유틸리티
    // ──────────────────────────────────────────────
    private fun extractText(json: String, isFinal: Boolean): String {
        return try {
            val obj = JSONObject(json)
            if (isFinal) obj.optString("text", "") else obj.optString("partial", "")
        } catch (_: Exception) { "" }
    }

    private fun shortsToBytes(shorts: ShortArray, count: Int): ByteArray {
        val bytes = ByteArray(count * 2)
        for (i in 0 until count) {
            bytes[i * 2] = (shorts[i].toInt() and 0xFF).toByte()
            bytes[i * 2 + 1] = (shorts[i].toInt() ushr 8).toByte()
        }
        return bytes
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private fun emitSubtitle(text: String) {
        mainHandler.post { subtitleSink?.success(text) }
    }

    private fun emitStatus(msg: String) {
        Log.d(TAG, msg)
        mainHandler.post { statusSink?.success(msg) }
    }

    // ──────────────────────────────────────────────
    // 알림
    // ──────────────────────────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                CHANNEL_ID,
                "SubBridge 자막",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "일본어 오디오 실시간 번역" }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(chan)
        }
    }

    private fun buildNotification(): Notification {
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("SubBridge 실행 중")
            .setContentText("일본어 오디오를 실시간으로 번역합니다")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        captureJob?.cancel()
        scope.cancel()
        audioRecord?.apply { stop(); release() }
        mediaProjection?.stop()
        recognizer?.close()
        voskModel?.close()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
