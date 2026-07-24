import 'package:flutter/material.dart';
import '../api_service.dart';
import '../auth_service.dart';
import 'classroom_manage_screen.dart';
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

  /// Running a session against a saved class is what lets students tap their
  /// name and earn XP. Teachers with no saved classes — or who just want a
  /// quick session — go straight through to the original nickname flow.
  Future<void> _startClassSession(
      BuildContext context, String teacherId) async {
    List<Map<String, dynamic>> rooms = const [];
    try {
      rooms = await ApiService.getClassrooms(teacherId);
    } catch (_) {
      // A class list we can't load must never block starting a session.
    }
    if (!context.mounted) return;

    String? classroomId;
    if (rooms.isNotEmpty) {
      // Empty string is the sentinel for "no class", so dismissing the dialog
      // (null) can be told apart from deliberately choosing a quick session.
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('Which class?', style: AppTheme.subheading),
          children: [
            ...rooms.map(
              (r) => SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(ctx, r['classroom_id'] as String? ?? ''),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 20, color: AppTheme.primary),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Text(
                          '${r['name']}  ·  ${r['student_count']} student'
                          '${r['student_count'] == 1 ? '' : 's'}',
                          style: AppTheme.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_outlined,
                        size: 20, color: AppTheme.textLight),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        'Quick session — students type their name',
                        style: AppTheme.body.copyWith(color: AppTheme.textLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      classroomId = choice.isEmpty ? null : choice;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherClassSessionScreen(
          teacherId: teacherId,
          classroomId: classroomId,
        ),
      ),
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
                        Image.asset(
                          'assets/icons/teacher.png',
                          width: 44,
                          height: 44,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person_2_outlined, size: 44);
                          },
                        ),
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
                          iconPath: 'assets/icons/camera.png',
                          title: 'Project Mode',
                          subtitle: 'Scan objects to display for your class',
                          color: AppTheme.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScanObjectScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _ActionCard(
                          iconPath: 'assets/icons/link.png',
                          title: 'Create Class Session',
                          subtitle: 'Generate a code for students to join',
                          color: AppTheme.secondary,
                          onTap: () => _startClassSession(context, teacherId),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _ActionCard(
                          iconPath: 'assets/icons/school.png',
                          title: 'My Classes',
                          subtitle: 'Saved rosters, XP, levels and badges',
                          color: AppTheme.adventure,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClassroomManageScreen(
                                teacherId: teacherId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _ActionCard(
                          iconPath: 'assets/icons/statistic.png',
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
  final String iconPath;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.iconPath,
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
                child: Image.asset(
                  widget.iconPath,
                  width: 28,
                  height: 28,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported, size: 28);
                  },
                ),
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
