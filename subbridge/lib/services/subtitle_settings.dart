import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubtitlePosition { top, center, bottom }

class SubtitleSettings {
  final double opacity;       // 0.0 ~ 1.0
  final double fontSize;      // 12 ~ 32
  final Color textColor;      // 자막 글자색
  final Color bgColor;        // 배경색
  final SubtitlePosition position;

  const SubtitleSettings({
    this.opacity = 0.80,
    this.fontSize = 18.0,
    this.textColor = Colors.white,
    this.bgColor = Colors.black,
    this.position = SubtitlePosition.bottom,
  });

  SubtitleSettings copyWith({
    double? opacity,
    double? fontSize,
    Color? textColor,
    Color? bgColor,
    SubtitlePosition? position,
  }) {
    return SubtitleSettings(
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      bgColor: bgColor ?? this.bgColor,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': 'settings',
    'opacity': opacity,
    'fontSize': fontSize,
    'textColor': textColor.toARGB32(),
    'bgColor': bgColor.toARGB32(),
    'position': position.name,
  };
}

class SubtitleSettingsService extends ChangeNotifier {
  static const _keyOpacity = 'subtitle_opacity';
  static const _keyFontSize = 'subtitle_font_size';
  static const _keyTextColor = 'subtitle_text_color';
  static const _keyBgColor = 'subtitle_bg_color';
  static const _keyPosition = 'subtitle_position';

  SubtitleSettings _settings = const SubtitleSettings();
  SubtitleSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = SubtitleSettings(
      opacity: prefs.getDouble(_keyOpacity) ?? 0.80,
      fontSize: prefs.getDouble(_keyFontSize) ?? 18.0,
      textColor: Color(prefs.getInt(_keyTextColor) ?? Colors.white.toARGB32()),
      bgColor: Color(prefs.getInt(_keyBgColor) ?? Colors.black.toARGB32()),
      position: SubtitlePosition.values.firstWhere(
        (p) => p.name == (prefs.getString(_keyPosition) ?? 'bottom'),
        orElse: () => SubtitlePosition.bottom,
      ),
    );
    notifyListeners();
  }

  Future<void> update(SubtitleSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOpacity, newSettings.opacity);
    await prefs.setDouble(_keyFontSize, newSettings.fontSize);
    await prefs.setInt(_keyTextColor, newSettings.textColor.toARGB32());
    await prefs.setInt(_keyBgColor, newSettings.bgColor.toARGB32());
    await prefs.setString(_keyPosition, newSettings.position.name);
  }
}
