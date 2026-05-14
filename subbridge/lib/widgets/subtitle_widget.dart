import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class SubtitleWidget extends StatefulWidget {
  const SubtitleWidget({super.key});

  @override
  State<SubtitleWidget> createState() => _SubtitleWidgetState();
}

class _SubtitleWidgetState extends State<SubtitleWidget>
    with SingleTickerProviderStateMixin {
  String _subtitle = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data != null && data.toString().isNotEmpty) {
        setState(() => _subtitle = data.toString());
        _fadeController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
            color: Colors.black.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.4,
              shadows: [
                Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
