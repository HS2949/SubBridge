import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/subtitle_settings.dart';

class SubtitleWidget extends StatefulWidget {
  const SubtitleWidget({super.key});

  @override
  State<SubtitleWidget> createState() => _SubtitleWidgetState();
}

class _SubtitleWidgetState extends State<SubtitleWidget>
    with SingleTickerProviderStateMixin {
  String _subtitle = '';
  late AnimationController _fade;
  late Animation<double> _fadeAnim;

  // 설정 기본값 (HomeScreen이 보내기 전 표시될 값)
  double _opacity = 0.80;
  double _fontSize = 18.0;
  Color _textColor = Colors.white;
  Color _bgColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeIn);

    _loadSavedSettings();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == null) return;

      if (data is String) {
        // 자막 텍스트
        setState(() => _subtitle = data);
        _fade.forward(from: 0);
      } else if (data is Map) {
        // 설정 업데이트 패킷
        _applySettings(Map<String, dynamic>.from(data));
      }
    });
  }

  Future<void> _loadSavedSettings() async {
    final svc = SubtitleSettingsService();
    await svc.load();
    final s = svc.settings;
    if (mounted) {
      setState(() {
        _opacity = s.opacity;
        _fontSize = s.fontSize;
        _textColor = s.textColor;
        _bgColor = s.bgColor;
      });
    }
  }

  void _applySettings(Map<String, dynamic> map) {
    if (map['type'] != 'settings') return;
    setState(() {
      _opacity = (map['opacity'] as num?)?.toDouble() ?? _opacity;
      _fontSize = (map['fontSize'] as num?)?.toDouble() ?? _fontSize;
      if (map['textColor'] != null) {
        _textColor = Color(map['textColor'] as int);
      }
      if (map['bgColor'] != null) {
        _bgColor = Color(map['bgColor'] as int);
      }
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_subtitle.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _bgColor.withValues(alpha: _opacity),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: _fontSize,
              fontWeight: FontWeight.w500,
              height: 1.4,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
