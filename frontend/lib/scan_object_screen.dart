import 'package:flutter/material.dart';
import 'api_service.dart';
import 'recognition_result_screen.dart';
import 'theme/app_theme.dart';

/// Screen 2 – Scan Object
/// Shows a camera placeholder, a "Use Mock Scan" button to call the backend,
/// and a collapsible "What can I scan?" section.
class ScanObjectScreen extends StatefulWidget {
  const ScanObjectScreen({super.key});

  @override
  State<ScanObjectScreen> createState() => _ScanObjectScreenState();
}

class _ScanObjectScreenState extends State<ScanObjectScreen> {
  bool _isScanning = false;
  bool _showObjectList = true;

  /// List of scannable objects matching the design.
  static const List<Map<String, String>> _objects = [
    {'emoji': '📚', 'label': 'Book'},
    {'emoji': '✏️', 'label': 'Pencil'},
    {'emoji': '🖊️', 'label': 'Pen'},
    {'emoji': '📏', 'label': 'Ruler'},
    {'emoji': '🎒', 'label': 'Backpack'},
    {'emoji': '🍼', 'label': 'Bottle'},
    {'emoji': '☕', 'label': 'Cup'},
    {'emoji': '🥄', 'label': 'Spoon'},
    {'emoji': '🍽️', 'label': 'Plate'},
    {'emoji': '📺', 'label': 'Remote Control'},
  ];

  Future<void> _useMockScan() async {
    setState(() => _isScanning = true);
    try {
      final data = await ApiService.predictMock();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecognitionResultScreen(predictionData: data),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        // ── Header ──
                        const Text('📷', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 6),
                        Text(
                          'Scan an Object',
                          style: AppTheme.heading.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Point your camera at an object!',
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: AppTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Camera placeholder ──
                        Container(
                          width: double.infinity,
                          height: 240,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 52,
                                color: AppTheme.textLight,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Camera preview',
                                style: AppTheme.body.copyWith(
                                  color: AppTheme.textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Start Camera (placeholder) ──
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Start Camera'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: AppTheme.textDark,
                            minimumSize: const Size(200, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: AppTheme.buttonText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.md),

                        // ── Use Mock Scan button ──
                        FilledButton.icon(
                          onPressed: _isScanning ? null : _useMockScan,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.surface,
                                  ),
                                )
                              : const Icon(Icons.science, size: 18),
                          label: const Text('Use Mock Scan'),
                          style: AppTheme.primaryButton,
                        ),
                        const SizedBox(height: 28),

                        // ── What can I scan? ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.lg),
                          decoration: AppTheme.cardDecoration,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => setState(
                                  () => _showObjectList = !_showObjectList,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: AppTheme.textLight,
                                    ),
                                    const SizedBox(width: AppTheme.sm),
                                    Expanded(
                                      child: Text(
                                        'What can I scan?',
                                        style: AppTheme.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _showObjectList
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      color: AppTheme.textDark,
                                    ),
                                  ],
                                ),
                              ),
                              if (_showObjectList) ...[
                                const SizedBox(height: AppTheme.md),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: AppTheme.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '⭐ Starter Learning Pack: Home & School Objects ⭐',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.caption.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _objects
                                      .map(
                                        (o) => _ObjectChip(
                                          emoji: o['emoji']!,
                                          label: o['label']!,
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: AppTheme.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '💡 More objects will be added in future versions!',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.caption,
                                  ),
                                ),
                              ],
                            ],
                          ),
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

/// Small chip showing an emoji + label for each scannable object.
class _ObjectChip extends StatelessWidget {
  final String emoji;
  final String label;

  const _ObjectChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: AppTheme.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(
              fontSize: 12,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
