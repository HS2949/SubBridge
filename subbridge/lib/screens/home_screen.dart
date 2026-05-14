import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_channel.dart';
import '../services/subtitle_settings.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRunning = false;
  String _status = '대기 중';
  String _lastSubtitle = '';
  int _downloadProgress = -1;   // -1: 다운로드 없음, 0~100: 진행 중
  StreamSubscription? _subtitleSub;
  Timer? _pollTimer;

  final _settingsService = SubtitleSettingsService();

  @override
  void initState() {
    super.initState();
    _settingsService.load();
    _subtitleSub = AudioCaptureChannel.subtitleStream.listen((sub) {
      setState(() => _lastSubtitle = sub);
      FlutterOverlayWindow.shareData(sub);
    });
  }

  @override
  void dispose() {
    _subtitleSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // 서비스 상태를 1초마다 폴링 — EventChannel 타이밍 버그 우회
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final status = await AudioCaptureChannel.getStatus();
      final progress = await AudioCaptureChannel.getDownloadProgress();
      if (mounted) {
        setState(() {
          if (status.isNotEmpty) _status = status;
          _downloadProgress = progress;
        });
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<bool> _requestAllPermissions() async {
    final notif = await Permission.notification.request();
    if (notif.isPermanentlyDenied && mounted) {
      _showPermissionDialog('알림 권한');
      return false;
    }
    final overlay = await FlutterOverlayWindow.requestPermission();
    if (overlay != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오버레이 권한이 필요합니다. 설정에서 허용해 주세요.')),
      );
      return false;
    }
    return true;
  }

  void _showPermissionDialog(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name 필요'),
        content: Text('앱 설정에서 $name을 허용해 주세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  OverlayAlignment _overlayAlignment(SubtitlePosition pos) => switch (pos) {
    SubtitlePosition.top => OverlayAlignment.topCenter,
    SubtitlePosition.center => OverlayAlignment.center,
    SubtitlePosition.bottom => OverlayAlignment.bottomCenter,
  };

  Future<void> _showOverlay() async {
    final settings = _settingsService.settings;
    await FlutterOverlayWindow.showOverlay(
      height: 130,
      width: WindowSize.matchParent,
      alignment: _overlayAlignment(settings.position),
      enableDrag: true,
      overlayTitle: 'SubBridge',
      overlayContent: '일본어 자막 실행 중',
      flag: OverlayFlag.defaultFlag,
      positionGravity: PositionGravity.none,
    );
    // 현재 설정을 오버레이로 전달
    await FlutterOverlayWindow.shareData(settings.toMap());
  }

  Future<void> _toggleCapture() async {
    if (_isRunning) {
      await AudioCaptureChannel.stopCapture();
      await FlutterOverlayWindow.closeOverlay();
      _stopPolling();
      setState(() {
        _isRunning = false;
        _status = '중지됨';
        _lastSubtitle = '';
        _downloadProgress = -1;
      });
    } else {
      final granted = await _requestAllPermissions();
      if (!granted) return;

      setState(() => _status = '서비스 시작 중...');
      final started = await AudioCaptureChannel.startCapture();

      if (started && mounted) {
        await _showOverlay();
        setState(() {
          _isRunning = true;
          _status = '초기화 중...';
        });
        _startPolling();
      } else if (!started && mounted) {
        setState(() => _status = 'MediaProjection 권한이 거부되었습니다');
      }
    }
  }

  Future<void> _openSettings() async {
    final wasRunning = _isRunning;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          service: _settingsService,
          isOverlayActive: wasRunning,
        ),
      ),
    );

    // 자막 위치가 변경되었을 때 오버레이를 재시작
    if (wasRunning && mounted) {
      await FlutterOverlayWindow.closeOverlay();
      await _showOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SubBridge'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '자막 설정',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusIcon(isRunning: _isRunning),
            const SizedBox(height: 20),
            Text(
              _status,
              style: TextStyle(
                fontSize: 15,
                color: _isRunning ? Colors.greenAccent : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            // 다운로드 진행률 바
            if (_downloadProgress >= 0) ...[
              const SizedBox(height: 12),
              Column(children: [
                LinearProgressIndicator(
                  value: _downloadProgress / 100,
                  backgroundColor: Colors.white12,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 4),
                Text(
                  '모델 다운로드 $_downloadProgress%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ]),
            ],

            // 마지막 자막 미리보기
            if (_lastSubtitle.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lastSubtitle,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _toggleCapture,
              icon: Icon(_isRunning ? Icons.stop_circle : Icons.play_circle),
              label: Text(
                _isRunning ? '자막 중지' : '자막 시작',
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 56),
                backgroundColor: _isRunning ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 28),
            const _InfoCard(),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isRunning;
  const _StatusIcon({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRunning
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.1),
        border: Border.all(
          color: isRunning ? Colors.greenAccent : Colors.grey,
          width: 2,
        ),
      ),
      child: Icon(
        isRunning ? Icons.subtitles : Icons.subtitles_off,
        size: 48,
        color: isRunning ? Colors.greenAccent : Colors.grey,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blue),
            SizedBox(width: 8),
            Text('사용 방법', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 8),
          Text('1. [자막 시작] → 화면 캡처 권한 허용', style: TextStyle(fontSize: 13, color: Colors.grey)),
          SizedBox(height: 4),
          Text('2. 미디어 플레이어에서 일본어 콘텐츠 재생', style: TextStyle(fontSize: 13, color: Colors.grey)),
          SizedBox(height: 4),
          Text('3. 화면에 한국어 자막이 자동 표시됨', style: TextStyle(fontSize: 13, color: Colors.grey)),
          SizedBox(height: 4),
          Text('* 첫 실행 시 Vosk 모델 다운로드 (~50MB)', style: TextStyle(fontSize: 12, color: Colors.orange)),
          SizedBox(height: 4),
          Text('* 우측 상단 설정(≡) 버튼으로 자막 조정 가능', style: TextStyle(fontSize: 12, color: Colors.orange)),
        ],
      ),
    );
  }
}
