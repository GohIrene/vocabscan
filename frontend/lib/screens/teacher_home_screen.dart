import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'scan_object_screen.dart';
import 'teacher_class_session_screen.dart';
import 'teacher_projection_screen.dart';
import 'welcome_screen.dart';
import '../theme/app_theme.dart';

class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  void _logout(BuildContext context) {
    AuthService.instance.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser!;
    final teacherId =
        (user['user_id'] ?? user['username'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.lg,
                vertical: AppTheme.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hi, ${user['username']}!',
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log Out'),
                    style: AppTheme.backButtonStyle,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.md),
                        const Text('👩‍🏫', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Teacher Panel',
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.xxl),

                        _ActionCard(
                          emoji: '📽️',
                          title: 'Project Mode',
                          subtitle: 'Scan objects to display for your class',
                          color: AppTheme.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: ScanObjectScreen.routeName,
                              ),
                              builder: (_) => const ScanObjectScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _ActionCard(
                          emoji: '🔗',
                          title: 'Create Class Session',
                          subtitle: 'Generate a code for students to join',
                          color: AppTheme.secondary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeacherClassSessionScreen(
                                teacherId: teacherId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _ActionCard(
                          emoji: '📊',
                          title: 'Class Reports',
                          subtitle: 'View session summaries and progress',
                          color: AppTheme.success,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeacherProjectionScreen(
                                teacherId: teacherId,
                                teacherName: user['username'] as String?,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
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
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.xl),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color
                    .withValues(alpha: _hovering ? 0.50 : 0.25),
                blurRadius: _hovering ? 24 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -3.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(widget.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: AppTheme.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.surface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.surface.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.surface.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
