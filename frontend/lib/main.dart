import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';

void main() {
  runApp(const VocabScanApp());
}

class VocabScanApp extends StatelessWidget {
  const VocabScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocabScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C6CF2)),
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const ModeSelectionScreen(),
    );
  }
}
