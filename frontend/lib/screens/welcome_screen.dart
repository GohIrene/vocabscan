import 'dart:ui';

import 'package:flutter/material.dart';
import 'child_login_screen.dart';
import 'login_screen.dart';
import 'join_class_screen.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // No background track wired up yet — this just flips the icon for now.
  // Hook up an AudioPlayer loop here once a music asset is added.
  bool _muted = false;

  static const List<Color> _rainbow = [
    AppTheme.primary,
    AppTheme.secondary,
    AppTheme.success,
    AppTheme.treasure,
    AppTheme.adventure,
    AppTheme.blossom,
  ];

  Widget _rainbowTitle(String text, double fontSize) {
    return RichText(
      text: TextSpan(
        children: [
          for (int i = 0; i < text.length; i++)
            TextSpan(
              text: text[i],
              style: AppTheme.heading.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: _rainbow[i % _rainbow.length],
                shadows: const [
                  Shadow(
                    color: Colors.white,
                    offset: Offset(0, 0),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showMascot = screenWidth > 820;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/welcomepage_background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.xl,
                  vertical: AppTheme.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    children: [
                      _rainbowTitle('VocabScan', 56),
                      const SizedBox(height: AppTheme.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.xl,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE3B778), Color(0xFFC08A52)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Scan  •  Learn  •  Play',
                          style: AppTheme.subheading.copyWith(
                            color: const Color(0xFF4A2E12),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.md),
                      Text(
                        '✨ AI-Powered Vocabulary Learning Adventure ✨',
                        textAlign: TextAlign.center,
                        style: AppTheme.subheading.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.xxl + 12),

                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          SizedBox(
                            width: 260,
                            child: _RoleCard(
                              title: "I'm Learning at Home",
                              subtitle:
                                  'Start your adventure and learn new words!',
                              accent: AppTheme.success,
                              tint: AppTheme.successLight,
                              badgeIcon: Icons.home_rounded,
                              imagePath: 'assets/images/student_boy.png',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChildLoginScreen(),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: _RoleCard(
                              title: 'Parent',
                              subtitle:
                                  "Manage your children's learning and progress.",
                              accent: AppTheme.primary,
                              tint: AppTheme.primaryLight,
                              badgeIcon: Icons.groups_rounded,
                              imagePath: 'assets/images/parent.png',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LoginScreen(role: 'parent'),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: _RoleCard(
                              title: 'Teacher',
                              subtitle:
                                  'Create classes, activities and track students.',
                              accent: AppTheme.secondary,
                              tint: AppTheme.secondaryLight,
                              badgeIcon: Icons.school_rounded,
                              imagePath: 'assets/images/teacher.png',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LoginScreen(role: 'teacher'),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (showMascot)
                                  Positioned(
                                    top: -180,
                                    right: 0,
                                    child: Image.asset(
                                      'assets/images/dinosaur.png',
                                      width: 190,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                _RoleCard(
                                  title: 'Join School Quiz',
                                  subtitle: 'Enter class code and join the fun quiz!',
                                  accent: AppTheme.adventure,
                                  tint: AppTheme.adventureLight,
                                  badgeIcon: Icons.quiz_rounded,
                                  imagePath: 'assets/images/backpack.png',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const JoinClassScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.xxl),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.lg,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppTheme.success, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Safe • Fun • Educational',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: AppTheme.sm),
                              child: Text('|'),
                            ),
                            Text(
                              'For kids aged ',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '3-10',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.adventure,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.lg),

                      Text(
                        '© ${DateTime.now().year} VocabScan. All rights reserved.',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textDark,
                          shadows: const [
                            Shadow(
                              color: Colors.white,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: Tooltip(
              message: _muted ? 'Unmute' : 'Mute',
              child: GestureDetector(
                onTap: () => setState(() => _muted = !_muted),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: AppTheme.surface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color tint;
  final IconData badgeIcon;
  final String imagePath;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tint,
    required this.badgeIcon,
    required this.imagePath,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -6.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.lg,
                  vertical: AppTheme.xl,
                ),
                decoration: AppTheme.glassDecoration(widget.tint).copyWith(
                      boxShadow: [
                        BoxShadow(
                          color: widget.accent
                              .withValues(alpha: _hovering ? 0.35 : 0.2),
                          blurRadius: _hovering ? 24 : 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.accent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(widget.badgeIcon,
                            color: AppTheme.surface, size: 18),
                      ),
                    ),
                    const SizedBox(height: AppTheme.sm),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: Image.asset(
                        widget.imagePath,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                    const SizedBox(height: AppTheme.md),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTheme.subheading.copyWith(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textDark,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppTheme.md),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppTheme.sm),
                        decoration: BoxDecoration(
                          color: widget.accent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Go',
                              style: AppTheme.buttonText.copyWith(fontSize: 15),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded,
                                color: AppTheme.surface, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
