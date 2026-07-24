// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';

/// Teacher batch-upload flow (Class Code mode).
///
/// The teacher picks several photos at once; each is recognised via /predict,
/// then the recognised words can be sent to the class as one multi-question
/// quiz ("Send Now") or added to the session's word pool for later ("Add to
/// Pool"). Reuses the existing summary-quiz delivery, so the student app is
/// unchanged.
class BatchUploadScreen extends StatefulWidget {
  final ClassSessionContext classSession;

  const BatchUploadScreen({super.key, required this.classSession});

  @override
  State<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

// Mirror of the server's _MAX_SUMMARY_QUESTIONS: a quiz of more than this many
// words is too long for young children, so "Send Now" quizzes only the first N.
const int _maxQuizWords = 10;

class _BatchItem {
  final Uint8List thumb;
  final bool ok;
  final String? englishKey;
  final String label;
  final double confidence;
  bool included;

  _BatchItem({
    required this.thumb,
    required this.ok,
    required this.englishKey,
    required this.label,
    required this.confidence,
    this.included = true,
  });
}

class _BatchUploadScreenState extends State<BatchUploadScreen> {
  final List<_BatchItem> _items = [];
  bool _processing = false;
  int _done = 0;
  int _total = 0;

  List<String> get _includedKeys => _items
      .where((it) => it.ok && it.included && it.englishKey != null)
      .map((it) => it.englishKey!)
      .toList();

  Future<void> _pickPhotos() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    html.document.body!.append(input);
    input.click();
    await input.onChange.first;
    input.remove();
    final files = input.files;
    if (files == null || files.isEmpty) return;

    setState(() {
      _processing = true;
      _done = 0;
      _total = files.length;
    });

    // Sequential rather than parallel: the model serves one prediction at a
    // time, and this keeps the progress count honest for the teacher.
    for (final file in files) {
      _BatchItem item;
      try {
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        await reader.onLoadEnd.first;
        final dataUrl = reader.result as String;
        final bytes = await _cropCenterFromDataUrl(dataUrl);

        final data = await ApiService.predictObject(bytes);
        final ok = data['success'] == true;
        item = _BatchItem(
          thumb: bytes,
          ok: ok,
          englishKey: ok ? data['english_key'] as String? : null,
          label: ok
              ? (data['english_word'] as String? ??
                  data['english_key'] as String? ??
                  'Word')
              : file.name,
          confidence: (data['confidence'] as num? ?? 0).toDouble(),
          included: ok,
        );
      } catch (_) {
        item = _BatchItem(
          thumb: Uint8List(0),
          ok: false,
          englishKey: null,
          label: file.name,
          confidence: 0,
          included: false,
        );
      }
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _done += 1;
      });
    }

    if (mounted) setState(() => _processing = false);
  }

  // Center-crops the image at [dataUrl] to a 224×224 square (matches the
  // single-scan flow so recognition behaves identically).
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
    final url = canvas.toDataUrl('image/jpeg', 0.92);
    return base64Decode(url.split(',')[1]);
  }

  void _sendNow() {
    final keys = _includedKeys.take(_maxQuizWords).toList();
    if (keys.isEmpty) return;
    widget.classSession.socket
        .pushBatchQuiz(widget.classSession.sessionId, keys);
    Navigator.pop(context);
  }

  void _addToPool() {
    final keys = _includedKeys;
    if (keys.isEmpty) return;
    widget.classSession.socket
        .stageBatchWords(widget.classSession.sessionId, keys);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${keys.length} word${keys.length == 1 ? '' : 's'} added to the pool',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final includedCount = _includedKeys.length;
    final overCap = includedCount > _maxQuizWords;

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        const SizedBox(height: AppTheme.sm),
                        Image.asset(
                          'assets/icons/camera.png',
                          width: 44,
                          height: 44,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.photo_library, size: 44),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Upload Photos',
                          style: AppTheme.heading
                              .copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Pick several photos — we\'ll recognise each one, '
                          'then you send them as a quiz.',
                          textAlign: TextAlign.center,
                          style: AppTheme.body
                              .copyWith(fontSize: 15, color: AppTheme.textLight),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _processing ? null : _pickPhotos,
                          icon: const Icon(Icons.add_photo_alternate, size: 20),
                          label: Text(
                            _items.isEmpty ? 'Choose Photos' : 'Add More Photos',
                          ),
                          style: AppTheme.primaryButton,
                        ),
                        const SizedBox(height: 20),
                        if (_processing) _buildProgress(),
                        if (_items.isNotEmpty) ...[
                          _buildResultsHeader(includedCount, overCap),
                          const SizedBox(height: 12),
                          ..._items.asMap().entries.map(
                                (e) => _buildItemRow(e.key, e.value),
                              ),
                        ],
                        const SizedBox(height: AppTheme.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_items.isNotEmpty) _buildActionBar(includedCount),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 12),
          Text('Recognising $_done of $_total…', style: AppTheme.body),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(int includedCount, bool overCap) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Review ($includedCount selected)',
            style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (overCap) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Only the first $_maxQuizWords will be quizzed with "Send Now". '
              'Use "Add to Pool" to keep them all for later.',
              style: AppTheme.caption
                  .copyWith(fontSize: 13, color: AppTheme.textDark),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemRow(int index, _BatchItem item) {
    // The first _maxQuizWords included items are the ones "Send Now" will use.
    final includedBefore = _items
        .take(index)
        .where((it) => it.ok && it.included)
        .length;
    final inSendNow =
        item.ok && item.included && includedBefore < _maxQuizWords;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.ok
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.thumb.isEmpty
                ? Container(
                    width: 52,
                    height: 52,
                    color: AppTheme.background,
                    child: const Icon(Icons.broken_image, size: 24),
                  )
                : Image.memory(item.thumb,
                    width: 52, height: 52, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ok ? item.label : 'Not recognised',
                  style: AppTheme.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.ok ? AppTheme.textDark : AppTheme.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.ok
                      ? '${(item.confidence * 100).toStringAsFixed(0)}% sure'
                          '${inSendNow ? '' : item.included ? ' · beyond first $_maxQuizWords' : ''}'
                      : 'Try a clearer photo',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          if (item.ok)
            Checkbox(
              value: item.included,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() => item.included = v ?? false),
            ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.textLight,
            onPressed: () => setState(() => _items.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(int includedCount) {
    final canSend = includedCount > 0 && !_processing;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canSend ? _addToPool : null,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Add to Pool'),
              style: AppTheme.secondaryButton,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: canSend ? _sendNow : null,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send Now'),
              style: AppTheme.primaryButton,
            ),
          ),
        ],
      ),
    );
  }
}
