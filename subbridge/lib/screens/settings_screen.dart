import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/subtitle_settings.dart';

class SettingsScreen extends StatefulWidget {
  final SubtitleSettingsService service;
  final bool isOverlayActive;

  const SettingsScreen({
    super.key,
    required this.service,
    required this.isOverlayActive,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SubtitleSettings _s;

  static const _textColors = [
    (label: '흰색', color: Colors.white),
    (label: '노란색', color: Color(0xFFFFEB3B)),
    (label: '시안', color: Color(0xFF00E5FF)),
    (label: '연두', color: Color(0xFF69F0AE)),
  ];

  static const _bgColors = [
    (label: '검정', color: Colors.black),
    (label: '남색', color: Color(0xFF1A237E)),
    (label: '짙은 회색', color: Color(0xFF212121)),
    (label: '없음', color: Colors.transparent),
  ];

  @override
  void initState() {
    super.initState();
    _s = widget.service.settings;
  }

  Future<void> _apply(SubtitleSettings updated) async {
    setState(() => _s = updated);
    await widget.service.update(updated);

    // 오버레이가 실행 중이면 실시간 반영
    if (widget.isOverlayActive) {
      await FlutterOverlayWindow.shareData(updated.toMap());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자막 설정'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 미리보기 ──────────────────────────────────────
          _sectionLabel('미리보기'),
          const SizedBox(height: 8),
          _SubtitlePreview(settings: _s),
          const SizedBox(height: 24),

          // ── 자막 위치 ─────────────────────────────────────
          _sectionLabel('자막 위치'),
          const SizedBox(height: 8),
          SegmentedButton<SubtitlePosition>(
            segments: const [
              ButtonSegment(value: SubtitlePosition.top, label: Text('상단'), icon: Icon(Icons.vertical_align_top)),
              ButtonSegment(value: SubtitlePosition.center, label: Text('중단'), icon: Icon(Icons.vertical_align_center)),
              ButtonSegment(value: SubtitlePosition.bottom, label: Text('하단'), icon: Icon(Icons.vertical_align_bottom)),
            ],
            selected: {_s.position},
            onSelectionChanged: (sel) => _apply(_s.copyWith(position: sel.first)),
          ),
          const SizedBox(height: 24),

          // ── 배경 투명도 ───────────────────────────────────
          _sectionLabel('배경 투명도  ${(_s.opacity * 100).round()}%'),
          Slider(
            value: _s.opacity,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            label: '${(_s.opacity * 100).round()}%',
            onChanged: (v) => _apply(_s.copyWith(opacity: v)),
          ),
          const SizedBox(height: 16),

          // ── 폰트 크기 ─────────────────────────────────────
          _sectionLabel('폰트 크기  ${_s.fontSize.round()}sp'),
          Slider(
            value: _s.fontSize,
            min: 12,
            max: 32,
            divisions: 20,
            label: '${_s.fontSize.round()}',
            onChanged: (v) => _apply(_s.copyWith(fontSize: v)),
          ),
          const SizedBox(height: 24),

          // ── 글자 색상 ─────────────────────────────────────
          _sectionLabel('글자 색상'),
          const SizedBox(height: 8),
          _ColorPicker(
            colors: _textColors,
            selected: _s.textColor,
            onSelect: (c) => _apply(_s.copyWith(textColor: c)),
          ),
          const SizedBox(height: 24),

          // ── 배경 색상 ─────────────────────────────────────
          _sectionLabel('배경 색상'),
          const SizedBox(height: 8),
          _ColorPicker(
            colors: _bgColors,
            selected: _s.bgColor,
            onSelect: (c) => _apply(_s.copyWith(bgColor: c)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      );
}

// ── 미리보기 위젯 ────────────────────────────────────────────────
class _SubtitlePreview extends StatelessWidget {
  final SubtitleSettings settings;
  const _SubtitlePreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: _alignment(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: settings.bgColor.withValues(alpha: settings.opacity),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          '日本語の字幕サンプル → 자막 미리보기 샘플',
          style: TextStyle(
            color: settings.textColor,
            fontSize: settings.fontSize * 0.6,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Alignment _alignment() => switch (settings.position) {
    SubtitlePosition.top => Alignment.topCenter,
    SubtitlePosition.center => Alignment.center,
    SubtitlePosition.bottom => Alignment.bottomCenter,
  };
}

// ── 색상 선택기 ──────────────────────────────────────────────────
class _ColorPicker extends StatelessWidget {
  final List<({String label, Color color})> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;

  const _ColorPicker({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((item) {
        final isSelected = item.color.toARGB32() == selected.toARGB32();
        return GestureDetector(
          onTap: () => onSelect(item.color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: item.color == Colors.transparent
                  ? Colors.transparent
                  : item.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.white30,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                color: item.color == Colors.white || item.color == Colors.transparent
                    ? Colors.black87
                    : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
