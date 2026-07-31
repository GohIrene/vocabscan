import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../avatar_config.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';

/// Editing an existing child: name, age, buddy and PIN.
///
/// Separate from the add-child wizard because editing is a single reviewable
/// form — a parent changing one field shouldn't be walked through three steps.
/// Changing the buddy clears the legacy `icon` server-side, otherwise the old
/// face would keep winning when the card renders.
class ParentEditChildScreen extends StatefulWidget {
  final Map<String, dynamic> child;

  const ParentEditChildScreen({super.key, required this.child});

  @override
  State<ParentEditChildScreen> createState() => _ParentEditChildScreenState();
}

class _ParentEditChildScreenState extends State<ParentEditChildScreen> {
  late final TextEditingController _nicknameCtrl;
  final _pinCtrl = TextEditingController();

  late int _age;
  late String _avatarId;
  late bool _hadPin;

  /// Null until the parent touches the PIN controls, so an untouched form
  /// leaves the existing PIN exactly as it was.
  bool? _pinAction; // true = set new, false = remove

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl =
        TextEditingController(text: widget.child['nickname'] as String? ?? '');
    _age = (widget.child['age'] as num?)?.toInt() ?? 5;
    _avatarId = widget.child['avatar_id'] as String? ?? kDefaultAvatarId;
    _hadPin = widget.child['has_pin'] == true;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  String get _childId => widget.child['child_id'] as String? ?? '';

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = 'Please enter a nickname');
      return;
    }
    final pin = _pinCtrl.text.trim();
    if (_pinAction == true && pin.length != 3) {
      setState(() => _error = 'The PIN must be exactly 3 digits');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final result = await ApiService.updateChild(
      _childId,
      nickname: nickname,
      age: _age,
      avatarId: _avatarId,
      childPin: _pinAction == true ? pin : null,
      clearPin: _pinAction == false,
    );
    if (!mounted) return;

    if (result['status'] != 'ok') {
      setState(() {
        _error = result['message'] as String? ?? 'Could not save changes';
        _saving = false;
      });
      return;
    }
    Navigator.pop(context, true);
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
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Cancel'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.xl),

                        _label('Nickname'),
                        const SizedBox(height: AppTheme.xs),
                        TextField(
                          controller: _nicknameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                              hint: 'e.g. Emma', icon: Icons.face_outlined),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _label('Age'),
                        const SizedBox(height: AppTheme.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.lg),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2)),
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
                                    items: List.generate(
                                      8,
                                      (i) => DropdownMenuItem(
                                        value: i + 3,
                                        child: Text('${i + 3} years old'),
                                      ),
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _age = v ?? _age),
                                    style: AppTheme.body,
                                    dropdownColor: AppTheme.surface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _label('Learning Buddy'),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          "Changing the buddy keeps all of your child's "
                          'progress — only the picture changes.',
                          style: AppTheme.caption,
                        ),
                        const SizedBox(height: AppTheme.md),
                        Wrap(
                          spacing: AppTheme.sm,
                          runSpacing: AppTheme.sm,
                          children: [
                            for (final avatar in kSelectableAvatars)
                              _BuddyOption(
                                avatar: avatar,
                                selected: avatar.avatarId == _avatarId,
                                onTap: () => setState(
                                    () => _avatarId = avatar.avatarId),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.lg),

                        _label('Child PIN'),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          _hadPin
                              ? 'This child currently uses a PIN to open '
                                  'their profile.'
                              : 'This child has no PIN — they tap their face '
                                  'to start.',
                          style: AppTheme.caption,
                        ),
                        const SizedBox(height: AppTheme.sm),
                        Wrap(
                          spacing: AppTheme.sm,
                          runSpacing: AppTheme.sm,
                          children: [
                            _PinChoice(
                              label: _hadPin ? 'Keep current PIN' : 'No PIN',
                              selected: _pinAction == null,
                              onTap: () => setState(() {
                                _pinAction = null;
                                _pinCtrl.clear();
                              }),
                            ),
                            _PinChoice(
                              label: _hadPin ? 'Set a new PIN' : 'Add a PIN',
                              selected: _pinAction == true,
                              onTap: () => setState(() => _pinAction = true),
                            ),
                            if (_hadPin)
                              _PinChoice(
                                label: 'Remove PIN',
                                selected: _pinAction == false,
                                onTap: () => setState(() {
                                  _pinAction = false;
                                  _pinCtrl.clear();
                                }),
                              ),
                          ],
                        ),
                        if (_pinAction == true) ...[
                          const SizedBox(height: AppTheme.sm),
                          TextField(
                            controller: _pinCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: _decoration(
                                hint: '3 digits, e.g. 123',
                                icon: Icons.lock_outline),
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: AppTheme.lg),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.lg, vertical: AppTheme.md),
                            decoration: BoxDecoration(
                              color: AppTheme.errorLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 18, color: AppTheme.error),
                                const SizedBox(width: AppTheme.sm),
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
                          ),
                        ],

                        const SizedBox(height: AppTheme.xl),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          style: AppTheme.primaryButton,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Changes'),
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

  static Widget _label(String text) => Text(
        text,
        style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
      );

  static InputDecoration _decoration(
      {required String hint, required IconData icon}) {
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
          horizontal: AppTheme.lg, vertical: AppTheme.lg),
    );
  }
}

class _BuddyOption extends StatelessWidget {
  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  const _BuddyOption({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 104,
          padding: const EdgeInsets.symmetric(
              vertical: AppTheme.md, horizontal: AppTheme.sm),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.2),
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChildAvatar(avatarId: avatar.avatarId, stage: 1, size: 58),
              const SizedBox(height: 6),
              Text(
                avatar.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.primary : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PinChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg, vertical: AppTheme.sm),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
