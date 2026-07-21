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
      // text is rendered (recognition result / quiz / speech screens), the web
      // renderer has to fetch and rasterize a CJK fallback font on the spot,
      // stalling that render. Warm it once at startup by *painting* a tiny,
      // near-transparent Chinese sample — glyph rasterization on web happens at
      // paint time, so an Offstage widget (never painted) wouldn't trigger it.
      // Kept 2px, ~1/255 alpha, and non-interactive so the user never sees it.
      builder: (context, child) => Stack(
        children: [
          ?child,
          const Positioned(
            left: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Text(
                '中文字体预热 苹果 书 桌子 椅子 香蕉 眼镜',
                style: TextStyle(fontSize: 2, color: Color(0x01000000)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
