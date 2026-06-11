import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'add_child_screen.dart';
import 'scan_object_screen.dart';
import 'parent_dashboard_screen.dart';
import 'welcome_screen.dart';
import '../theme/app_theme.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  static const List<Color> _childColors = [
    AppTheme.primary,
    AppTheme.secondary,
    AppTheme.success,
    Color(0xFFEC4899), // pink
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
  ];

  static const List<String> _childEmojis = [
    '😊', '😄', '🌟', '🦋', '🐣', '🌈',
  ];

  List<Map<String, dynamic>> _children = [];
  bool _loadingChildren = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() => _loadingChildren = true);
    final kids =
        await AuthService.instance.getChildren(user['user_id'] as String);
    if (!mounted) return;
    setState(() {
      _children = kids;
      _loadingChildren = false;
    });
  }

  void _goToScan(String childId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanObjectScreen(childId: childId),
      ),
    );
  }

  void _goToDashboard(String childId, String nickname) {
    final user = AuthService.instance.currentUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentDashboardScreen(
          childId: childId,
          childNickname: nickname,
          parentUsername: user?['username'] as String?,
        ),
      ),
    );
  }

  void _onChildTap(String childId, String nickname) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(nickname, style: AppTheme.subheading),
              const SizedBox(height: 4),
              Text(
                'What would you like to do?',
                style: AppTheme.caption,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Text('🎓', style: TextStyle(fontSize: 26)),
                title: const Text('Start Learning'),
                subtitle: const Text('Scan objects and practise quizzes'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                tileColor: AppTheme.primaryLight,
                onTap: () {
                  Navigator.pop(ctx);
                  _goToScan(childId);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Text('📊', style: TextStyle(fontSize: 26)),
                title: const Text('View Progress'),
                subtitle: const Text('See stats, accuracy and reports'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                tileColor: AppTheme.primaryLight,
                onTap: () {
                  Navigator.pop(ctx);
                  _goToDashboard(childId, nickname);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _addChild() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildScreen()),
    ).then((_) => _loadChildren());
  }

  void _logout() {
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
                    onPressed: _logout,
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
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.md),
                        const Text('🏠', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Home Learning',
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.xxl),

                        Text(
                          'Who is learning today?',
                          style: AppTheme.subheading.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        // Children grid
                        if (_loadingChildren)
                          const Center(child: CircularProgressIndicator())
                        else
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              ..._children.asMap().entries.map((e) {
                                final i = e.key;
                                final child = e.value;
                                final color =
                                    _childColors[i % _childColors.length];
                                final emoji =
                                    _childEmojis[i % _childEmojis.length];
                                final nickname =
                                    child['nickname'] as String? ?? '';
                                final childId =
                                    child['child_id'] as String? ?? '';
                                final age = child['age'] as int? ?? 0;
                                return _ChildCard(
                                  emoji: emoji,
                                  nickname: nickname,
                                  age: age,
                                  color: color,
                                  onTap: () => _onChildTap(childId, nickname),
                                );
                              }),
                              _AddChildCard(onTap: _addChild),
                            ],
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

class _ChildCard extends StatefulWidget {
  final String emoji;
  final String nickname;
  final int age;
  final Color color;
  final VoidCallback onTap;

  const _ChildCard({
    required this.emoji,
    required this.nickname,
    required this.age,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
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
          width: 110,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    widget.color.withValues(alpha: _hovering ? 0.50 : 0.25),
                blurRadius: _hovering ? 20 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Column(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 8),
              Text(
                widget.nickname,
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(
                  color: AppTheme.surface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Age ${widget.age}',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.surface.withValues(alpha: 0.80),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChildCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AddChildCard({required this.onTap});

  @override
  State<_AddChildCard> createState() => _AddChildCardState();
}

class _AddChildCardState extends State<_AddChildCard> {
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
          width: 110,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: _hovering
                ? AppTheme.primary.withValues(alpha: 0.08)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 32, color: AppTheme.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 8),
              Text(
                'Add\nChild',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(
                  color: AppTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
