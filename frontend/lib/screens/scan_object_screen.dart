// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../recognition_result_screen.dart';
import '../theme/app_theme.dart';

const double _focusW = 0.70;
const double _focusH = 0.50;

class ScanObjectScreen extends StatefulWidget {
  const ScanObjectScreen({super.key});

  @override
  State<ScanObjectScreen> createState() => _ScanObjectScreenState();
}

enum _CamState { idle, starting, running, error }

class _ScanObjectScreenState extends State<ScanObjectScreen> {
  late final String _viewType;
  late final html.VideoElement _video;

  _CamState _camState = _CamState.idle;
  String _camError = '';
  bool _isScanning = false;
  bool _showObjectList = true;

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

  @override
  void initState() {
    super.initState();
    // Unique view type per screen instance so re-navigation works cleanly.
    _viewType = 'vocabscan-webcam-${DateTime.now().millisecondsSinceEpoch}';
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', '')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) => _video,
    );
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  void _stopCamera() {
    final stream = _video.srcObject;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      _video.srcObject = null;
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _camState = _CamState.starting;
      _camError = '';
    });
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });
      _video.srcObject = stream;
      await _video.play();
      if (mounted) setState(() => _camState = _CamState.running);
    } catch (e) {
      if (mounted) {
        setState(() {
          _camState = _CamState.error;
          _camError = e.toString();
        });
      }
    }
  }

  // Draws the current video frame to a canvas and crops to the focus box,
  // returning JPEG bytes.
  Future<Uint8List?> _captureFrame() async {
    final vw = _video.videoWidth;
    final vh = _video.videoHeight;
    if (vw == 0 || vh == 0) return null;

    final full = html.CanvasElement(width: vw, height: vh);
    full.context2D.drawImage(_video, 0, 0);

    final cw = (vw * _focusW).round();
    final ch = (vh * _focusH).round();
    final cx = ((vw - cw) / 2).round();
    final cy = ((vh - ch) / 2).round();

    final crop = html.CanvasElement(width: cw, height: ch);
    crop.context2D
        .drawImageScaledFromSource(full, cx, cy, cw, ch, 0, 0, cw, ch);
    return _canvasToBytes(crop);
  }

  Uint8List _canvasToBytes(html.CanvasElement canvas) {
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
    return base64Decode(dataUrl.split(',')[1]);
  }

  Future<void> _scanObject() async {
    final bytes = await _captureFrame();
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not ready — please wait a moment.')),
      );
      return;
    }
    await _previewAndNavigate(bytes);
  }

  Future<void> _uploadPhoto() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    html.document.body!.append(input);
    input.click();
    await input.onChange.first;
    input.remove();
    final file = input.files?.first;
    if (file == null) return;

    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoadEnd.first;
    final dataUrl = reader.result as String;

    final bytes = await _cropCenterFromDataUrl(dataUrl);
    await _previewAndNavigate(bytes);
  }

  // Center-crops an image (from a data URL) to a 224×224 square.
  Future<Uint8List> _cropCenterFromDataUrl(String dataUrl) async {
    final img = html.ImageElement(src: dataUrl);
    await img.onLoad.first;

    const outSize = 224;
    final iw = img.naturalWidth;
    final ih = img.naturalHeight;
    final side = math.min(iw, ih);
    final sx = (iw - side) ~/ 2;
    final sy = (ih - side) ~/ 2;

    final canvas = html.CanvasElement(width: outSize, height: outSize);
    canvas.context2D.drawImageScaledFromSource(
        img, sx, sy, side, side, 0, 0, outSize, outSize);
    return _canvasToBytes(canvas);
  }

  Future<void> _previewAndNavigate(Uint8List bytes) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PreviewDialog(imageBytes: bytes),
    );
    if (confirmed != true || !mounted) return;

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
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Back button
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
                        // Header
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

                        // Camera preview
                        _buildCameraArea(),
                        const SizedBox(height: 18),

                        // Action buttons
                        _buildActionButtons(),
                        const SizedBox(height: 28),

                        // What can I scan?
                        _buildObjectList(),
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

  Widget _buildCameraArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_camState == _CamState.running)
              HtmlElementView(viewType: _viewType)
            else
              _buildCameraPlaceholder(),
            if (_camState == _CamState.running)
              CustomPaint(painter: _FocusBoxPainter()),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    if (_camState == _CamState.starting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Starting camera…',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_camState == _CamState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
              const SizedBox(height: 8),
              const Text(
                'Camera access denied',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Allow camera access in your browser settings and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
              ),
              if (_camError.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _camError,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      );
    }
    // Idle state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 52, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(height: 10),
          Text(
            'Camera preview',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Start Camera" below',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Start Camera / Scan Object (toggles based on camera state)
        if (_camState != _CamState.running)
          FilledButton.icon(
            onPressed: _camState == _CamState.starting ? null : _startCamera,
            icon: _camState == _CamState.starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt, size: 18),
            label: Text(
              _camState == _CamState.error ? 'Retry Camera' : 'Start Camera',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: AppTheme.textDark,
              minimumSize: const Size(200, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: AppTheme.buttonText,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _isScanning ? null : _scanObject,
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.center_focus_strong, size: 20),
            label: const Text('Scan Object'),
            style: AppTheme.primaryButton,
          ),

        const SizedBox(height: AppTheme.md),

        // Upload Photo fallback
        OutlinedButton.icon(
          onPressed: _isScanning ? null : _uploadPhoto,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Upload Photo'),
          style: AppTheme.secondaryButton,
        ),
      ],
    );
  }

  Widget _buildObjectList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showObjectList = !_showObjectList),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: AppTheme.textLight),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Text(
                    'What can I scan?',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  _showObjectList ? Icons.arrow_drop_up : Icons.arrow_drop_down,
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
                  .map((o) => _ObjectChip(emoji: o['emoji']!, label: o['label']!))
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
    );
  }
}

// ── Focus-box overlay ──────────────────────────────────────────────────────

class _FocusBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boxW = size.width * _focusW;
    final boxH = size.height * _focusH;
    final left = (size.width - boxW) / 2;
    final top = (size.height - boxH) / 2;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);

    // Dim everything outside the focus box
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8))),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Dashed white border
    _drawDashedRect(
      canvas,
      rect,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
      10,
      5,
    );

    // Purple L-shaped corner accents
    final corner = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cl = 22.0;

    // Top-left
    canvas.drawLine(Offset(left, top + cl), Offset(left, top), corner);
    canvas.drawLine(Offset(left, top), Offset(left + cl, top), corner);
    // Top-right
    canvas.drawLine(Offset(left + boxW - cl, top), Offset(left + boxW, top), corner);
    canvas.drawLine(Offset(left + boxW, top), Offset(left + boxW, top + cl), corner);
    // Bottom-left
    canvas.drawLine(Offset(left, top + boxH - cl), Offset(left, top + boxH), corner);
    canvas.drawLine(Offset(left, top + boxH), Offset(left + cl, top + boxH), corner);
    // Bottom-right
    canvas.drawLine(
        Offset(left + boxW - cl, top + boxH), Offset(left + boxW, top + boxH), corner);
    canvas.drawLine(
        Offset(left + boxW, top + boxH), Offset(left + boxW, top + boxH - cl), corner);

    // Hint label below the box
    final tp = TextPainter(
      text: TextSpan(
        text: 'Place object inside the box',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.80),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(left + (boxW - tp.width) / 2, top + boxH + 7),
    );
  }

  void _drawDashedRect(
      Canvas canvas, Rect rect, Paint paint, double dash, double gap) {
    _line(canvas, rect.topLeft, rect.topRight, paint, dash, gap);
    _line(canvas, rect.topRight, rect.bottomRight, paint, dash, gap);
    _line(canvas, rect.bottomRight, rect.bottomLeft, paint, dash, gap);
    _line(canvas, rect.bottomLeft, rect.topLeft, paint, dash, gap);
  }

  void _line(Canvas canvas, Offset from, Offset to, Paint paint, double dash,
      double gap) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final nx = dx / len;
    final ny = dy / len;
    double d = 0;
    bool drawing = true;
    while (d < len) {
      final step = drawing ? dash : gap;
      final end = math.min(d + step, len);
      if (drawing) {
        canvas.drawLine(
          Offset(from.dx + d * nx, from.dy + d * ny),
          Offset(from.dx + end * nx, from.dy + end * ny),
          paint,
        );
      }
      d = end;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Capture preview dialog ─────────────────────────────────────────────────

class _PreviewDialog extends StatelessWidget {
  final Uint8List imageBytes;
  const _PreviewDialog({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Captured Image', style: AppTheme.subheading),
            const SizedBox(height: 4),
            Text(
              'Does this look good?',
              style: AppTheme.body.copyWith(color: AppTheme.textLight, fontSize: 14),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                height: 200,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 80),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retake'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textLight,
                    side: BorderSide(color: AppTheme.textLight.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Scan This'),
                  style: AppTheme.smallButton,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scannable-object chip ──────────────────────────────────────────────────

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
