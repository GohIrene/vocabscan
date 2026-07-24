import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import '../avatar_config.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';

/// Creating a child profile, as a three-step wizard: details, then buddy,
/// then confirm.
///
/// Split into steps rather than one long form because the buddy picker needs
/// room to show the artwork at a size a child can actually judge — this is
/// the one part of setup a parent is likely to hand over to them.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

/// Wizard steps, in order.
enum _Step { details, avatar, confirm }

class _AddChildScreenState extends State<AddChildScreen> {
  static const List<String> _stepTitles = ['Details', 'Buddy', 'Confirm'];

  final _nicknameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  _Step _step = _Step.details;
  int _age = 5;
  String _avatarId = kDefaultAvatarId;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  String get _nickname => _nicknameCtrl.text.trim();
  String get _pin => _pinCtrl.text.trim();

  /// Only the details step can fail validation; the other two always have a
  /// usable value (the buddy defaults, and confirm just submits).
  String? _validateDetails() {
    if (_nickname.isEmpty) return 'Please enter a nickname';
    // Optional — but if one was typed it has to be complete, or the child
    // would be locked out by a PIN nobody meant to set.
    if (_pin.isNotEmpty && _pin.length != 4) {
      return 'The PIN must be 4 digits, or leave it empty';
    }
    return null;
  }

  void _next() {
    if (_step == _Step.details) {
      final error = _validateDetails();
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    setState(() {
      _error = null;
      _step = _Step.values[_step.index + 1];
    });
  }

  void _back() {
    if (_step == _Step.details) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.values[_step.index - 1];
    });
  }

  Future<void> _createChild() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    final result = await AuthService.instance.addChild(
      user['user_id'] as String,
      _nickname,
      _age,
      avatarId: _avatarId,
      childPin: _pin.isEmpty ? null : _pin,
    );
    if (!mounted) return;

    if (result['status'] != 'ok') {
      setState(() {
        _error = result['message'] as String? ?? 'Failed to add child';
        _loading = false;
        // A rejected nickname is fixed on the details step, so send them back
        // there instead of leaving them stuck on a confirm screen they can't
        // change anything on.
        _step = _Step.details;
      });
      return;
    }
    Navigator.pop(context);
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
                  label: Text(_step == _Step.details ? 'Back' : 'Previous'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
                  child: ConstrainedBox(
                    // Wider than the old single-column form so the buddy grid
                    // can lay out several across on a desktop browser.
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add Child Profile',
                          textAlign: TextAlign.center,
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),
                        _StepIndicator(
                          current: _step.index,
                          titles: _stepTitles,
                        ),
                        const SizedBox(height: AppTheme.xl),
                        switch (_step) {
                          _Step.details => _buildDetailsStep(),
                          _Step.avatar => _buildAvatarStep(),
                          _Step.confirm => _buildConfirmStep(),
                        },
                        if (_error != null) ...[
                          const SizedBox(height: AppTheme.lg),
                          _ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: AppTheme.xl),
                        _buildPrimaryAction(),
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

  Widget _buildPrimaryAction() {
    final isLast = _step == _Step.confirm;
    return FilledButton(
      onPressed: _loading ? null : (isLast ? _createChild : _next),
      style: AppTheme.primaryButton,
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(isLast ? 'Create Profile' : 'Continue'),
    );
  }

  // ── Step 1: details ────────────────────────────────────────────────────────

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel('Nickname'),
        const SizedBox(height: AppTheme.xs),
        TextField(
          controller: _nicknameCtrl,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: _inputDecoration(
            hint: 'e.g. Emma',
            icon: Icons.face_outlined,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: AppTheme.xl),

        _FieldLabel('Age'),
        const SizedBox(height: AppTheme.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cake_outlined,
                  color: AppTheme.textLight, size: 20),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _age,
                    isExpanded: true,
                    // 3-10 only: the app is designed for early learners
                    // (the backend enforces the same range).
                    items: List.generate(
                      8,
                      (i) => DropdownMenuItem(
                        value: i + 3,
                        child: Text('${i + 3} years old'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _age = v ?? _age),
                    style: AppTheme.body,
                    dropdownColor: AppTheme.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.xl),

        Row(
          children: [
            _FieldLabel('Child PIN'),
            const SizedBox(width: AppTheme.sm),
            Text('Optional', style: AppTheme.caption),
          ],
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          'Leave empty and your child just taps their face to start. '
          'Set one and they will type it first.',
          style: AppTheme.caption,
        ),
        const SizedBox(height: AppTheme.sm),
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: _inputDecoration(
            hint: '4 digits, e.g. 1234',
            icon: Icons.lock_outline,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
      ],
    );
  }

  // ── Step 2: buddy ──────────────────────────────────────────────────────────

  Widget _buildAvatarStep() {
    final avatars = kSelectableAvatars;
    return Column(
      children: [
        Text(
          'Choose a buddy',
          style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          'Your buddy grows as you learn new words!',
          textAlign: TextAlign.center,
          style: AppTheme.caption,
        ),
        const SizedBox(height: AppTheme.xl),
        Wrap(
          spacing: AppTheme.md,
          runSpacing: AppTheme.md,
          alignment: WrapAlignment.center,
          children: [
            for (final avatar in avatars)
              _AvatarChoice(
                avatar: avatar,
                selected: avatar.avatarId == _avatarId,
                onTap: () => setState(() => _avatarId = avatar.avatarId),
              ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: confirm ────────────────────────────────────────────────────────

  Widget _buildConfirmStep() {
    final avatar = avatarByIdOrDefault(_avatarId);
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          // Stage 1 only: this is what the buddy looks like on day one, and
          // showing a grown stage here would promise something unearned.
          ChildAvatar(avatarId: _avatarId, stage: 1, size: 128),
          const SizedBox(height: AppTheme.lg),
          Text(
            _nickname,
            textAlign: TextAlign.center,
            style: AppTheme.heading.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          _ConfirmRow(label: 'Age', value: '$_age years old'),
          const SizedBox(height: AppTheme.sm),
          _ConfirmRow(label: 'Buddy', value: avatar.displayName),
          const SizedBox(height: AppTheme.sm),
          _ConfirmRow(
            label: 'Child PIN',
            value: _pin.isEmpty ? 'None — taps to start' : _pin,
          ),
        ],
      ),
    );
  }

  static InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.textLight, size: 20),
      filled: true,
      fillColor: AppTheme.surface,
      counterText: '',
      border: border(AppTheme.primary.withValues(alpha: 0.2), 1),
      enabledBorder: border(AppTheme.primary.withValues(alpha: 0.2), 1),
      focusedBorder: border(AppTheme.primary, 1.5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.lg,
        vertical: AppTheme.lg,
      ),
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
      );
}

/// Progress across the three steps: a filled bar per completed/current step.
class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> titles;

  const _StepIndicator({required this.current, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < titles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${i + 1}. ${titles[i]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(
                    fontSize: 12,
                    fontWeight:
                        i == current ? FontWeight.w700 : FontWeight.w500,
                    color:
                        i <= current ? AppTheme.primary : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One selectable buddy in the picker. Shows stage 1 artwork only — the
/// grown stages are something the child unlocks, not a menu option.
class _AvatarChoice extends StatefulWidget {
  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AvatarChoice> createState() => _AvatarChoiceState();
}

class _AvatarChoiceState extends State<_AvatarChoice> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 132,
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.lg,
            horizontal: AppTheme.sm,
          ),
          transform: _hovering && !selected
              ? (Matrix4.identity()..translateByDouble(0.0, -4.0, 0.0, 1.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.2),
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChildAvatar(
                avatarId: widget.avatar.avatarId,
                stage: 1,
                size: 84,
              ),
              const SizedBox(height: AppTheme.sm),
              Text(
                widget.avatar.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.primary : AppTheme.textDark,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                const Icon(Icons.check_circle,
                    size: 18, color: AppTheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(width: AppTheme.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.lg,
        vertical: AppTheme.md,
      ),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppTheme.error),
          const SizedBox(width: AppTheme.sm),
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
      ),
    );
  }
}
