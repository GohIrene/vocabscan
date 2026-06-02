import 'package:flutter/material.dart';
import 'scan_object_screen.dart';
import 'parent_dashboard_screen.dart';
import 'teacher_projection_screen.dart';
import 'join_class_screen.dart';
import 'theme/app_theme.dart';

/// Screen 1 – Mode Selection
/// Three big colourful cards: Home Mode, Teacher Mode, Join Class.
/// A bottom button leads to the Parent Dashboard.
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.xl,
              vertical: AppTheme.xxl,
            ),
            child: Column(
              children: [
                // ── Rainbow + Title ──
                const Text('🌈', style: TextStyle(fontSize: 56)),
                const SizedBox(height: AppTheme.sm),
                Text(
                  'VocabScan',
                  style: AppTheme.heading.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Let's learn together!",
                  style: AppTheme.body.copyWith(
                    fontSize: 17,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: AppTheme.xxl + 4),

                // ── Mode cards row ──
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _ModeCard(
                      emoji: '🏠',
                      title: 'Home Mode',
                      subtitle: 'Learn at home with family',
                      color: AppTheme.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanObjectScreen(),
                        ),
                      ),
                    ),
                    _ModeCard(
                      emoji: '👩‍🏫',
                      title: 'Teacher Mode',
                      subtitle: 'Classroom activities',
                      color: AppTheme.secondary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherProjectionScreen(
                            classCode: 'Class 2A',
                          ),
                        ),
                      ),
                    ),
                    _ModeCard(
                      emoji: '🎓',
                      title: 'Join Class',
                      subtitle: 'Connect with your class',
                      color: AppTheme.success,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JoinClassScreen(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.xxl + 4),

                // ── Parent Dashboard button ──
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentDashboardScreen(),
                    ),
                  ),
                  icon: const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 20)),
                  label: const Text('Parent Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textDark,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable coloured card for each mode.
class _ModeCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
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
          width: 220,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: AppTheme.lg),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _hovering ? 0.55 : 0.30),
                blurRadius: _hovering ? 24 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Column(
            children: [
              // Circular emoji icon
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(
                  color: AppTheme.surface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.surface.withValues(alpha: 0.88),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
