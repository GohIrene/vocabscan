import 'package:flutter/material.dart';
import 'api_service.dart';
import 'recognition_result_screen.dart';

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
          backgroundColor: const Color(0xFFE85D5D),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1ECFF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF17234D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
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
                        const Text(
                          'Scan an Object',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17234D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Point your camera at an object!',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF65708C),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Camera placeholder ──
                        Container(
                          width: double.infinity,
                          height: 240,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E4F0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD5D0E3),
                              width: 2,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 52,
                                color: Color(0xFFADA6C0),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Camera preview',
                                style: TextStyle(
                                  color: Color(0xFFADA6C0),
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
                            backgroundColor: const Color(0xFF80DFA7),
                            foregroundColor: const Color(0xFF17234D),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Use Mock Scan button ──
                        FilledButton.icon(
                          onPressed: _isScanning ? null : _useMockScan,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.science, size: 18),
                          label: const Text('Use Mock Scan'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF9B8CF2),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFC4BCEE),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── What can I scan? ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x15000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => setState(
                                  () => _showObjectList = !_showObjectList,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: Color(0xFF65708C),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'What can I scan?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF17234D),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _showObjectList
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      color: const Color(0xFF17234D),
                                    ),
                                  ],
                                ),
                              ),
                              if (_showObjectList) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3CD),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    '⭐ Starter Learning Pack: Home & School Objects ⭐',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7A6B30),
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
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1ECFF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    '💡 More objects will be added in future versions!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF65708C),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0DCF0)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF17234D)),
          ),
        ],
      ),
    );
  }
}
