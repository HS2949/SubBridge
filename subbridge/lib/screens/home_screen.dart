import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_channel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRunning = false;
  String _status = '대기 중';
  String _lastSubtitle = '';

  @override
  void initState() {
    super.initState();
    _listenToSubtitles();
    _listenToStatus();
  }

  void _listenToSubtitles() {
    AudioCaptureChannel.subtitleStream.listen((subtitle) {
      setState(() => _lastSubtitle = subtitle);
      FlutterOverlayWindow.shareData(subtitle);
    });
  }

  void _listenToStatus() {
    AudioCaptureChannel.statusStream.listen((status) {
      setState(() => _status = status);
    });
  }

  Future<bool> _requestAllPermissions() async {
    final notif = await Permission.notification.request();
    if (notif.isPermanentlyDenied) {
      _showPermissionDialog('알림 권한');
      return false;
    }

    final overlay = await FlutterOverlayWindow.requestPermission();
    if (overlay != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오버레이 권한이 필요합니다. 설정에서 허용해 주세요.')),
        );
      }
      return false;
    }
    return true;
  }

  void _showPermissionDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$permissionName 필요'),
        content: Text('앱 설정에서 $permissionName을 허용해 주세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCapture() async {
    if (_isRunning) {
      await AudioCaptureChannel.stopCapture();
      await FlutterOverlayWindow.closeOverlay();
      setState(() {
        _isRunning = false;
        _status = '중지됨';
        _lastSubtitle = '';
      });
    } else {
      final granted = await _requestAllPermissions();
      if (!granted) return;

      setState(() => _status = '시작 중...');
      final started = await AudioCaptureChannel.startCapture();

      if (started && mounted) {
        await FlutterOverlayWindow.showOverlay(
          height: 130,
          width: WindowSize.matchParent,
          alignment: OverlayAlignment.bottomCenter,
          enableDrag: true,
          overlayTitle: 'SubBridge',
          overlayContent: '일본어 오디오 실시간 번역',
          flag: OverlayFlag.defaultFlag,
          positionGravity: PositionGravity.none,
        );
        setState(() {
          _isRunning = true;
          _status = '실행 중 — 오디오 감지 대기';
        });
      } else if (!started && mounted) {
        setState(() => _status = 'MediaProjection 권한 거부됨');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SubBridge'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
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
                fontSize: 16,
                color: _isRunning ? Colors.greenAccent : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
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
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 48),
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
            const SizedBox(height: 32),
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
        color: isRunning ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
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
          Text('3. 화면 하단에 한국어 자막이 자동 표시됨', style: TextStyle(fontSize: 13, color: Colors.grey)),
          SizedBox(height: 4),
          Text('* 첫 실행 시 Vosk 모델 다운로드 (~50MB)', style: TextStyle(fontSize: 12, color: Colors.orange)),
        ],
      ),
    );
  }
}
