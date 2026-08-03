import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'student_session_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';

/// Screen 9 – Join Class
///
/// Two steps: enter the teacher's code, then say who you are. When the teacher
/// started the session against a saved class, the second step is a grid of
/// names and avatars to tap — far kinder to a six-year-old than spelling their
/// own name. Sessions with no saved class fall back to the original typed
/// name, and a child who isn't on the roster can always type theirs too.
class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

enum _JoinStep { code, identity }

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  _JoinStep _step = _JoinStep.code;
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _roster = const [];
  bool _hasRoster = false;
  String? _classroomName;

  /// Set when a child on a roster class chooses to type their name anyway.
  bool _typeInstead = false;

  bool get _showGrid => _hasRoster && !_typeInstead;

  /// Looks up who's in the class behind this code, then moves to step two.
  Future<void> _lookUpCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a class code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.getRosterByCode(code);
    if (!mounted) return;

    // A bad or ended code is worth catching here rather than letting the child
    // pick a name and only then be told the class doesn't exist.
    if (res['status'] == 'error') {
      setState(() {
        _loading = false;
        _error = (res['message'] as String?) ?? 'Could not find that class';
      });
      return;
    }

    final students = (res['students'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    setState(() {
      _loading = false;
      _roster = students;
      _hasRoster = res['has_roster'] == true && students.isNotEmpty;
      _classroomName = res['classroom_name'] as String?;
      _typeInstead = false;
      _step = _JoinStep.identity;
    });
  }

  Future<void> _join(String name) async {
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.joinClassSession(code, name);
    if (!mounted) return;
    setState(() => _loading = false);

    final sessionId = res['session_id'] as String?;
    if (res['joined'] == true && sessionId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentSessionScreen(
            sessionId: sessionId,
            code: code,
            nickname: name,
          ),
        ),
      );
    } else {
      setState(() =>
          _error = (res['message'] as String?) ?? 'Could not join the class');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
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
                    // Step two backs up to the code, not out of the screen.
                    if (_step == _JoinStep.identity) {
                      setState(() {
                        _step = _JoinStep.code;
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Center inside a scroll view has no bounded height to
                  // center within, so it collapses to the top — giving it a
                  // minHeight matching the viewport is what actually lets the
                  // card sit in the middle of the screen.
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _showGrid ? 560 : 440,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: AppTheme.xxl,
                            ),
                            decoration: AppTheme.cardDecoration.copyWith(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: _step == _JoinStep.code
                                ? _buildCodeStep()
                                : _buildIdentityStep(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: the class code ────────────────────────────────────────────────

  Widget _buildCodeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          title: 'Join a Class',
          subtitle: "Enter your teacher's code",
        ),
        const SizedBox(height: AppTheme.xl),
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            UpperCaseTextFormatter(),
          ],
          style: AppTheme.heading.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: 'ABC123',
            hintStyle: AppTheme.heading.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: AppTheme.textDark.withValues(alpha: 0.25),
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
            counterText: '',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _lookUpCode(),
        ),
        _errorText(),
        const SizedBox(height: AppTheme.lg),
        _bigButton(label: 'Next', onPressed: _loading ? null : _lookUpCode),
        const SizedBox(height: AppTheme.xl),
        _tip('Ask your teacher for the class code!'),
      ],
    );
  }

  // ── Step 2: who are you? ──────────────────────────────────────────────────

  Widget _buildIdentityStep() {
    if (_showGrid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            title: 'Tap your name',
            subtitle: _classroomName ?? 'Find yourself below',
          ),
          const SizedBox(height: AppTheme.xl),
          Wrap(
            spacing: AppTheme.md,
            runSpacing: AppTheme.md,
            alignment: WrapAlignment.center,
            children: _roster.map(_buildRosterTile).toList(),
          ),
          _errorText(),
          const SizedBox(height: AppTheme.xl),
          TextButton.icon(
            onPressed: () => setState(() {
              _typeInstead = true;
              _error = null;
            }),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text("My name isn't here"),
          ),
        ],
      );
    }

    // No saved class, or the child chose to type — the original flow.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(title: 'What is your name?', subtitle: 'Type your name below'),
        const SizedBox(height: AppTheme.xl),
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 20,
          style: AppTheme.subheading.copyWith(fontSize: 18),
          decoration: InputDecoration(
            hintText: 'e.g. Ali',
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
            counterText: '',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (v) => _join(v.trim()),
        ),
        _errorText(),
        const SizedBox(height: AppTheme.lg),
        _bigButton(
          label: 'Join Class',
          onPressed:
              _loading ? null : () => _join(_nameController.text.trim()),
        ),
        if (_hasRoster) ...[
          const SizedBox(height: AppTheme.md),
          TextButton.icon(
            onPressed: () => setState(() {
              _typeInstead = false;
              _error = null;
            }),
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: const Text('Show the name list'),
          ),
        ],
      ],
    );
  }

  Widget _buildRosterTile(Map<String, dynamic> s) {
    final name = s['name'] as String? ?? '';
    final avatar = (s['avatar'] as num? ?? 0).toInt();
    final level = (s['level'] as num? ?? 1).toInt();
    // Someone is already connected under this name — almost always this child
    // on another device, so it's blocked rather than silently duplicated.
    final taken = s['taken'] == true;

    return Opacity(
      opacity: taken ? 0.5 : 1,
      child: SizedBox(
        width: 104,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: (taken || _loading) ? null : () => _join(name),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.md, horizontal: AppTheme.sm),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: avatarColor(avatar).withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StudentAvatar(avatar: avatar, size: 54, dimmed: taken),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTheme.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.treasure,
                      borderRadius: BorderRadius.circular(AppTheme.sm),
                    ),
                    child: Text(
                      taken ? 'Joined' : 'Lv $level',
                      style: AppTheme.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────────────

  Widget _header({required String title, required String subtitle}) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppTheme.adventure,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/icons/Group_Tutoring.png',
            width: 40,
            height: 40,
            errorBuilder: (_, _, _) => const Icon(Icons.people, size: 40),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTheme.heading
              .copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(fontSize: 14, color: AppTheme.primary),
        ),
      ],
    );
  }

  Widget _errorText() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.sm),
      child: Row(
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
    );
  }

  Widget _bigButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
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
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }

  Widget _tip(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/icons/lightbulb.png',
            width: 24,
            height: 24,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.lightbulb_outline, size: 24),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Forces input to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
