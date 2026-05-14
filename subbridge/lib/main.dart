import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'widgets/subtitle_widget.dart';

// 오버레이용 별도 Flutter 엔진 진입점
@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SubtitleWidget(),
  ));
}

void main() {
  runApp(const SubBridgeApp());
}

class SubBridgeApp extends StatelessWidget {
  const SubBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubBridge',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
