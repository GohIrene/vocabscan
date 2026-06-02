import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.themeData,
      home: const ModeSelectionScreen(),
    );
  }
}
