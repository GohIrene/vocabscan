import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'add_child_screen.dart';
import 'scan_object_screen.dart';
import 'parent_dashboard_screen.dart';
import 'welcome_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_confirm_dialog.dart';

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

  Future<void> _addChild() async {
    // A child may be holding the device after the parent logged in, so
    // re-confirm the PIN before allowing this parent-only action.
    final confirmed = await showPinConfirmDialog(
      context,
      message: 'Enter your PIN to add a child profile.',
    );
    if (!confirmed || !mounted) return;
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
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: List.generate(
                              3,
                              (_) => Column(
                                children: [
                                  Container(
                                    width: 150,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 100,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
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
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      settings: const RouteSettings(
                                        name: ScanObjectScreen.routeName,
                                      ),
                                      builder: (_) =>
                                          ScanObjectScreen(childId: childId),
                                    ),
                                  ),
                                  onStatsTap: () {
                                    final user =
                                        AuthService.instance.currentUser;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ParentDashboardScreen(
                                          childId: childId,
                                          childNickname: nickname,
                                          parentUsername: user?['username']
                                              as String?,
                                        ),
                                      ),
                                    );
                                  },
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
  final VoidCallback onStatsTap;

  const _ChildCard({
    required this.emoji,
    required this.nickname,
    required this.age,
    required this.color,
    required this.onTap,
    required this.onStatsTap,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 150,
              constraints: const BoxConstraints(minHeight: 140),
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
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.nickname,
                      textAlign: TextAlign.center,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.surface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to learn! 🎯',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.surface.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: widget.onStatsTap,
          icon: const Text('📊', style: TextStyle(fontSize: 14)),
          label: const Text('View Progress'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textDark,
            textStyle: AppTheme.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
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
          width: 150,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  size: 40, color: AppTheme.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 10),
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
