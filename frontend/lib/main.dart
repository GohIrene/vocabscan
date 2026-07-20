import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
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
      home: const WelcomeScreen(),
      // The app's font (Nunito) covers Latin only, so the first time Chinese
      // text is rendered (recognition result / quiz / speech screens), the
      // web renderer has to fetch a CJK fallback font on the spot, stalling
      // that render. Laying out (but never painting) a hidden Chinese string
      // here, once, at startup triggers that fetch early so it's cached by
      // the time the user reaches those screens.
      builder: (context, child) => Stack(
        children: [
          ?child,
          const Offstage(
            offstage: true,
            child: Text('中文字体预热'),
          ),
        ],
      ),
    );
  }
}
