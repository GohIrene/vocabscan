import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../theme/app_theme.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _nicknameCtrl = TextEditingController();
  int _age = 5;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addChild() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = 'Please enter a nickname');
      return;
    }
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    final result = await AuthService.instance.addChild(
      user['user_id'] as String,
      nickname,
      _age,
    );
    if (!mounted) return;
    if (result['status'] == 'error') {
      setState(() {
        _error = result['message'] as String? ?? 'Failed to add child';
        _loading = false;
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: AppTheme.backButtonStyle,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('🧒', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: AppTheme.sm),
                        Text(
                          'Add Child Profile',
                          style: AppTheme.heading.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.xxl),

                        Text(
                          'Nickname',
                          style:
                              AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        TextField(
                          controller: _nicknameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. Emma',
                            prefixIcon: const Icon(Icons.face_outlined,
                                color: AppTheme.textLight, size: 20),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: AppTheme.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.lg,
                              vertical: AppTheme.lg,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.xl),

                        Text(
                          'Age',
                          style:
                              AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                        ),
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
                                    items: List.generate(
                                      13,
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

                        if (_error != null) ...[
                          const SizedBox(height: AppTheme.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.lg,
                              vertical: AppTheme.md,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppTheme.xl),
                        FilledButton(
                          onPressed: _loading ? null : _addChild,
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
                              : const Text('Add Child'),
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
