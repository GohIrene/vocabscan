import 'package:flutter/material.dart';
// Clipboard/ClipboardData live here, not in material.dart.
import 'package:flutter/services.dart';
import '../api_service.dart';
import '../auth_service.dart';
import '../avatar_config.dart';
import '../widgets/child_avatar.dart';
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
    AppTheme.blossom,
    AppTheme.treasure,
    AppTheme.adventure,
  ];

  static const List<String> _childIcons = [
    'assets/icons/smiley.png',
    'assets/icons/happy.png',
    'assets/icons/star.png',
    'assets/icons/butterfly.png',
    'assets/icons/egg.png',
    'assets/icons/rainbow.png',
  ];

  List<Map<String, dynamic>> _children = [];
  bool _loadingChildren = true;

  /// The code a child types to reach Home Mode. Assigned by the backend on
  /// first view, so a parent who has never opened this screen still gets one.
  String? _familyCode;
  bool _loadingCode = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _loadFamilyCode();
  }

  Future<void> _loadFamilyCode() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() => _loadingCode = true);
    final res = await ApiService.getFamilyCode(user['user_id'] as String);
    if (!mounted) return;
    setState(() {
      _familyCode = res['status'] == 'ok' ? res['family_code'] as String? : null;
      _loadingCode = false;
    });
  }

  Future<void> _regenerateFamilyCode() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // Destructive from a child's point of view: anyone still holding the old
    // code is locked out the moment this succeeds. Confirm the parent is the
    // one asking, then say plainly what will happen.
    final confirmed = await showPinConfirmDialog(
      context,
      message: 'Enter your PIN to create a new family code.',
    );
    if (!confirmed || !mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New family code?'),
        content: const Text(
          'Your current code will stop working straight away. '
          'Anyone using it will need the new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create new code'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() => _loadingCode = true);
    final res =
        await ApiService.regenerateFamilyCode(user['user_id'] as String);
    if (!mounted) return;
    setState(() {
      if (res['status'] == 'ok') _familyCode = res['family_code'] as String?;
      _loadingCode = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['status'] == 'ok'
            ? 'New family code created'
            : 'Could not create a new code — please try again'),
      ),
    );
  }

  Future<void> _copyFamilyCode() async {
    final code = _familyCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Family code copied')),
    );
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
                        const SizedBox(height: AppTheme.xl),

                        _FamilyCodeCard(
                          code: _familyCode,
                          loading: _loadingCode,
                          onCopy: _copyFamilyCode,
                          onRegenerate: _regenerateFamilyCode,
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
                                // The icon the parent picked when adding the
                                // child; children added before icons were
                                // stored fall back to the old rotation.
                                final chosenIcon =
                                    (child['icon'] as String?) ?? '';
                                final iconPath = chosenIcon.isNotEmpty
                                    ? 'assets/icons/$chosenIcon.png'
                                    : _childIcons[i % _childIcons.length];
                                // A stored `icon` wins over the animal buddy:
                                // every profile now reads back with an
                                // avatar_id (the backend defaults it), so
                                // preferring the buddy would silently replace
                                // the face a parent chose under the old
                                // screen. Only profiles created by the new
                                // wizard have a blank icon, and those show
                                // their buddy. When Phase 7 lets a parent
                                // change a legacy child's buddy, it must
                                // clear `icon` for the new choice to show.
                                final avatarId = chosenIcon.isEmpty
                                    ? child['avatar_id'] as String?
                                    : null;
                                final avatarStage =
                                    (child['avatar_stage'] as num?)?.toInt() ??
                                        1;
                                final nickname =
                                    child['nickname'] as String? ?? '';
                                final childId =
                                    child['child_id'] as String? ?? '';
                                final age = child['age'] as int? ?? 0;
                                return _ChildCard(
                                  iconPath: iconPath,
                                  avatarId: avatarId,
                                  avatarStage: avatarStage,
                                  nickname: nickname,
                                  age: age,
                                  color: color,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
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

/// The family code, shown so a parent can read it out to their child.
///
/// PHASE 2 SCOPE — Phase 7 folds this into the full Parent Dashboard. The
/// regenerate action is PIN-gated by the caller.
class _FamilyCodeCard extends StatelessWidget {
  final String? code;
  final bool loading;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;

  const _FamilyCodeCard({
    required this.code,
    required this.loading,
    required this.onCopy,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.secondaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded,
                  size: 18, color: AppTheme.secondary),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  'Family Code',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Your child types this to start learning at home.',
            style: AppTheme.caption,
          ),
          const SizedBox(height: AppTheme.md),
          // Wrap rather than Row: on a narrow browser the code and its two
          // actions would otherwise overflow.
          Wrap(
            spacing: AppTheme.md,
            runSpacing: AppTheme.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.lg,
                  vertical: AppTheme.sm,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.4),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        code ?? 'Unavailable',
                        style: AppTheme.heading.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: code == null
                              ? AppTheme.textLight
                              : AppTheme.textDark,
                        ),
                      ),
              ),
              if (!loading && code != null)
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                  ),
                ),
              TextButton.icon(
                onPressed: loading ? null : onRegenerate,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('New Code'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatefulWidget {
  /// Fallback face, used when the child has no animal buddy to show.
  final String iconPath;

  /// The child's animal buddy, or null to fall back to [iconPath].
  final String? avatarId;
  final int avatarStage;

  final String nickname;
  final int age;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onStatsTap;

  const _ChildCard({
    required this.iconPath,
    required this.avatarId,
    required this.avatarStage,
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
                    if (avatarById(widget.avatarId) != null)
                      ChildAvatar(
                        avatarId: widget.avatarId,
                        stage: widget.avatarStage,
                        size: 56,
                      )
                    else
                      Image.asset(
                        widget.iconPath,
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image_not_supported,
                              size: 40);
                        },
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tap to learn! ',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.surface.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                        Image.asset(
                          'assets/icons/target.png',
                          width: 12,
                          height: 12,
                          color: AppTheme.surface.withValues(alpha: 0.85),
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(width: 12, height: 12);
                          },
                        ),
                      ],
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
          icon: Image.asset(
            'assets/icons/statistic.png',
            width: 14,
            height: 14,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.bar_chart, size: 14);
            },
          ),
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
