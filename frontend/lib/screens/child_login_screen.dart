import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import 'child_home_screen.dart';

/// Home Mode entry for a child, with no parent login involved.
///
/// Family code → pick your face → (optional) 3-digit child PIN → ChildHome.
/// This replaces the older "type your parent's username" lookup: a code is
/// something a parent hands over deliberately, and it can be regenerated if
/// it leaks, which a username cannot.
///
/// Nothing parent-facing is reachable from here — no reports, no family-code
/// controls, no account settings.
class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

enum _Step { code, profiles, pin }

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final _codeCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  _Step _step = _Step.code;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _selected;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  // ── Step 1: redeem the family code ─────────────────────────────────────────

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'A family code has 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.childAccessByFamilyCode(code);
    if (!mounted) return;

    if (res['status'] != 'ok') {
      setState(() {
        _loading = false;
        _error = (res['message'] as String?) ?? 'Could not find that code';
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
      _step = _Step.profiles;
    });
  }

  // ── Step 2: pick a profile ─────────────────────────────────────────────────

  void _pickChild(Map<String, dynamic> child) {
    _selected = child;
    // Calling verify-pin unconditionally would cost a round trip for the
    // common no-PIN case, and the backend already treats "no PIN" as a pass —
    // so branch here and only prompt when there is something to type.
    if (child['has_pin'] == true) {
      _pinCtrl.clear();
      setState(() {
        _step = _Step.pin;
        _error = null;
      });
      return;
    }
    _enterHome(child);
  }

  // ── Step 3: optional child PIN ─────────────────────────────────────────────

  Future<void> _submitPin() async {
    final child = _selected;
    if (child == null) return;
    final pin = _pinCtrl.text.trim();
    if (pin.length != 3) {
      setState(() => _error = 'Your PIN has 3 numbers');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.verifyChildPin(
      child['child_id'] as String? ?? '',
      pin,
    );
    if (!mounted) return;

    if (res['status'] != 'ok') {
      setState(() {
        _loading = false;
        _error = (res['message'] as String?) ?? 'That PIN is not right';
        _pinCtrl.clear();
      });
      return;
    }

    setState(() => _loading = false);
    _enterHome(child);
  }

  void _enterHome(Map<String, dynamic> child) {
    final childId = child['child_id'] as String? ?? '';
    if (childId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'child_home'),
        builder: (_) => ChildHomeScreen(
          childId: childId,
          nickname: child['nickname'] as String? ?? '',
          avatarId: child['avatar_id'] as String?,
          avatarStage: (child['avatar_stage'] as num?)?.toInt() ?? 1,
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _back() {
    switch (_step) {
      case _Step.code:
        Navigator.pop(context);
      case _Step.profiles:
        setState(() {
          _step = _Step.code;
          _children = [];
          _error = null;
        });
      case _Step.pin:
        setState(() {
          _step = _Step.profiles;
          _selected = null;
          _error = null;
        });
    }
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
                  onPressed: _loading ? null : _back,
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
                    constraints: BoxConstraints(
                      // The profile grid wants room to breathe on a desktop
                      // browser; the two typing steps read better narrow.
                      maxWidth: _step == _Step.profiles ? 720 : 480,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: AppTheme.xxl,
                      ),
                      decoration: AppTheme.cardDecoration.copyWith(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: switch (_step) {
                        _Step.code => _buildCodeStep(),
                        _Step.profiles => _buildProfilesStep(),
                        _Step.pin => _buildPinStep(),
                      },
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

  Widget _buildCodeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🏠', style: TextStyle(fontSize: 52)),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Welcome home!',
          textAlign: TextAlign.center,
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          'Type your family code to start learning',
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(fontSize: 14, color: AppTheme.primary),
        ),
        const SizedBox(height: AppTheme.xl),
        TextField(
          controller: _codeCtrl,
          autofocus: true,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            LengthLimitingTextInputFormatter(6),
            // The backend stores codes uppercase; normalising as they type
            // means the field always shows exactly what will be sent.
            TextInputFormatter.withFunction((old, updated) =>
                updated.copyWith(text: updated.text.toUpperCase())),
          ],
          style: AppTheme.heading.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
          decoration: InputDecoration(
            hintText: 'ABC123',
            hintStyle: AppTheme.heading.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
              color: AppTheme.textLight.withValues(alpha: 0.35),
            ),
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
            contentPadding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
          ),
          onChanged: (_) => _clearError(),
          onSubmitted: (_) => _submitCode(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.sm),
          _ErrorRow(message: _error!),
        ],
        const SizedBox(height: AppTheme.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _submitCode,
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
                : const Text("Let's Go!"),
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

  Widget _buildProfilesStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 44)),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Who is learning today?',
          textAlign: TextAlign.center,
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          'Tap your buddy to start',
          style: AppTheme.caption,
        ),
        const SizedBox(height: AppTheme.xl),
        Wrap(
          spacing: AppTheme.lg,
          runSpacing: AppTheme.lg,
          alignment: WrapAlignment.center,
          children: [
            for (final child in _children)
              _ChildProfileCard(
                child: child,
                onTap: () => _pickChild(child),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    final child = _selected ?? const {};
    final nickname = child['nickname'] as String? ?? '';
    final pinLength = _pinCtrl.text.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChildAvatar(
          avatarId: child['avatar_id'] as String?,
          stage: (child['avatar_stage'] as num?)?.toInt() ?? 1,
          size: 96,
        ),
        const SizedBox(height: AppTheme.lg),
        Text(
          'Hi $nickname!',
          textAlign: TextAlign.center,
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          'Type your 3 secret numbers',
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(fontSize: 14, color: AppTheme.primary),
        ),
        const SizedBox(height: AppTheme.xl),

        // Filled-dot progress above the field, so a child can see how many
        // numbers they've typed without reading the digits themselves.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: i < pinLength
                      ? AppTheme.primary
                      : AppTheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.lg),

        TextField(
          controller: _pinCtrl,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          obscureText: true,
          obscuringCharacter: '•',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          style: AppTheme.heading.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 14,
          ),
          decoration: InputDecoration(
            counterText: '',
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
            contentPadding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
          ),
          onChanged: (value) {
            _clearError();
            // Redraw the dots, and submit as soon as the 3rd number lands so
            // there's no extra button press to find.
            setState(() {});
            if (value.length == 3) _submitPin();
          },
          onSubmitted: (_) => _submitPin(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.sm),
          _ErrorRow(message: _error!),
        ],
        const SizedBox(height: AppTheme.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _submitPin,
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
                : const Text('Start Learning'),
          ),
        ),
      ],
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

/// A big, tappable profile card — the primary target on the picker, sized for
/// imprecise fingers rather than a mouse.
class _ChildProfileCard extends StatefulWidget {
  final Map<String, dynamic> child;
  final VoidCallback onTap;

  const _ChildProfileCard({required this.child, required this.onTap});

  @override
  State<_ChildProfileCard> createState() => _ChildProfileCardState();
}

class _ChildProfileCardState extends State<_ChildProfileCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final nickname = child['nickname'] as String? ?? '';
    final age = (child['age'] as num?)?.toInt();
    final stage = (child['avatar_stage'] as num?)?.toInt() ?? 1;
    final hasPin = child['has_pin'] == true;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 168,
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.xl,
            horizontal: AppTheme.md,
          ),
          transform: _hovering
              ? (Matrix4.identity()..translateByDouble(0.0, -6.0, 0.0, 1.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: _hovering
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.25),
              width: _hovering ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary
                    .withValues(alpha: _hovering ? 0.28 : 0.12),
                blurRadius: _hovering ? 22 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stage-appropriate art: the buddy a child sees here is the one
              // they've actually grown, not a generic starter image.
              ChildAvatar(
                avatarId: child['avatar_id'] as String?,
                stage: stage,
                size: 96,
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTheme.subheading.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (age != null) ...[
                const SizedBox(height: 2),
                Text('$age years old', style: AppTheme.caption),
              ],
              if (hasPin) ...[
                const SizedBox(height: AppTheme.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 13, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text('PIN', style: AppTheme.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: AppTheme.caption.copyWith(
              color: AppTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
