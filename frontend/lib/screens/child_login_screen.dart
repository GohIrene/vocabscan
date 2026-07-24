import 'package:flutter/material.dart';

import '../api_service.dart';
import 'scan_object_screen.dart';
import '../theme/app_theme.dart';

/// Welcome-page Child entry: a child starts learning without the parent
/// logging in. They type the parent's username (the one thing worth asking a
/// grown-up for), then tap their own face — no PIN, no password. Parent-only
/// actions (adding children, dashboards) stay behind the parent login.
class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final _usernameCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>>? _children;

  // Same fallback rotation the parent home screen uses for children added
  // before icons were stored.
  static const List<String> _fallbackIcons = [
    'assets/icons/smiley.png',
    'assets/icons/happy.png',
    'assets/icons/star.png',
    'assets/icons/butterfly.png',
    'assets/icons/egg.png',
    'assets/icons/rainbow.png',
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _error = "Please type your parent's username");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.getChildrenByUsername(username);
    if (!mounted) return;

    if (res['status'] == 'error') {
      setState(() {
        _loading = false;
        _error = (res['message'] as String?) ?? 'Could not find that account';
      });
      return;
    }

    final kids = (res['children'] as List? ?? const [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();

    setState(() {
      _loading = false;
      _children = kids;
      if (kids.isEmpty) {
        _error = 'No children on this account yet — '
            'ask your parent to add you first!';
        _children = null;
      }
    });
  }

  void _enterAsChild(Map<String, dynamic> child) {
    final childId = child['child_id'] as String? ?? '';
    if (childId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanObjectScreen(childId: childId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: TextButton.icon(
                  onPressed: () {
                    // The child list backs up to the username step, not out.
                    if (_children != null) {
                      setState(() {
                        _children = null;
                        _error = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: AppTheme.xxl,
                      ),
                      decoration: AppTheme.cardDecoration.copyWith(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: _children == null
                          ? _buildUsernameStep()
                          : _buildChildGrid(),
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

  Widget _buildUsernameStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🧒', style: TextStyle(fontSize: 52)),
        const SizedBox(height: AppTheme.sm),
        Text(
          "Hi! Who's learning?",
          textAlign: TextAlign.center,
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          "Type your parent's username to find your profile",
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(fontSize: 14, color: AppTheme.primary),
        ),
        const SizedBox(height: AppTheme.xl),
        TextField(
          controller: _usernameCtrl,
          autofocus: true,
          style: AppTheme.subheading.copyWith(fontSize: 18),
          decoration: InputDecoration(
            hintText: "Parent's username",
            prefixIcon: const Icon(Icons.person_outline,
                color: AppTheme.textLight, size: 20),
            filled: true,
            fillColor: AppTheme.primaryLight,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _lookUp(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.sm),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppTheme.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _lookUp,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.adventure,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              textStyle: AppTheme.buttonText.copyWith(fontSize: 17),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Find Me!'),
          ),
        ),
        const SizedBox(height: AppTheme.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warningLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Text(
            "Don't know it? Ask a grown-up to help!",
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildGrid() {
    final kids = _children!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 44)),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Tap your face!',
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTheme.xl),
        Wrap(
          spacing: AppTheme.md,
          runSpacing: AppTheme.md,
          alignment: WrapAlignment.center,
          children: kids.asMap().entries.map((e) {
            final i = e.key;
            final child = e.value;
            final nickname = child['nickname'] as String? ?? '';
            final chosenIcon = (child['icon'] as String?) ?? '';
            final iconPath = chosenIcon.isNotEmpty
                ? 'assets/icons/$chosenIcon.png'
                : _fallbackIcons[i % _fallbackIcons.length];
            return SizedBox(
              width: 120,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  onTap: () => _enterAsChild(child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.lg, horizontal: AppTheme.sm),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          iconPath,
                          width: 56,
                          height: 56,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.face, size: 56),
                        ),
                        const SizedBox(height: AppTheme.sm),
                        Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
