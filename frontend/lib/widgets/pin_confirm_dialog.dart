import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../theme/app_theme.dart';

/// Shows a PIN re-confirmation dialog and returns true only if the parent
/// entered the correct PIN. Used to gate sensitive parent actions (e.g. Add
/// Child) mid-session, since a child may be holding the device after the
/// parent logged in.
Future<bool> showPinConfirmDialog(
  BuildContext context, {
  String title = 'Confirm PIN',
  String message = 'Enter your PIN to continue.',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PinConfirmDialog(title: title, message: message),
  );
  return result ?? false;
}

class _PinConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  const _PinConfirmDialog({required this.title, required this.message});

  @override
  State<_PinConfirmDialog> createState() => _PinConfirmDialogState();
}

class _PinConfirmDialogState extends State<_PinConfirmDialog> {
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Please enter your PIN');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await AuthService.instance.verifyPin(pin);
    if (!mounted) return;
    if (result['status'] == 'ok') {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = result['message'] as String? ?? 'Incorrect PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.lock_outline,
                  color: AppTheme.primary, size: 26),
            ),
            const SizedBox(height: 14),
            Text(widget.title, style: AppTheme.subheading),
            const SizedBox(height: 4),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: AppTheme.caption,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _pinCtrl,
              autofocus: true,
              obscureText: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: AppTheme.heading.copyWith(fontSize: 22, letterSpacing: 6),
              decoration: InputDecoration(
                hintText: '● ● ● ●',
                counterText: '',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppTheme.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _confirm(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: AppTheme.secondaryButton,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _confirm,
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
                        : const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
