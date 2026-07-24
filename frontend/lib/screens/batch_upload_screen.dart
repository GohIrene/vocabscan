// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../image_upload_utils.dart';
import '../socket_service.dart';
import '../theme/app_theme.dart';

/// Teacher batch-upload flow.
///
/// The teacher picks several photos at once; each is recognised via /predict.
/// In a live session ([classSession] set) the recognised words can be sent to
/// the class as one multi-question quiz ("Send Now") or added to the session's
/// word pool ("Add to Pool"). In prep mode ([prepClassroomId] set, no session
/// needed) they're saved onto the classroom itself, and every future session
/// run against that class starts with them — how a teacher preps the night
/// before.
class BatchUploadScreen extends StatefulWidget {
  final ClassSessionContext? classSession;

  /// Classroom to stage words onto when there's no live session (prep mode).
  final String? prepClassroomId;

  const BatchUploadScreen({super.key, this.classSession, this.prepClassroomId})
      : assert((classSession != null) != (prepClassroomId != null),
            'Provide exactly one of classSession or prepClassroomId');

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
  // Set for a rejected/unreadable file, so the row can explain why instead
  // of the generic "try a clearer photo" that fits an actual low-confidence
  // scan.
  final String? failReason;
  bool included;

  _BatchItem({
    required this.thumb,
    required this.ok,
    required this.englishKey,
    required this.label,
    required this.confidence,
    this.failReason,
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
      ..accept = kAllowedImageAccept
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
      final item = await _processOne(file);
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _done += 1;
      });
    }

    if (mounted) setState(() => _processing = false);
  }

  Future<_BatchItem> _processOne(html.File file) async {
    // Checked before the file is even read, so an unsupported format or an
    // oversized photo fails instantly instead of spending a network round
    // trip (or, before this existed, hanging the whole batch — see
    // cropCenterSquareFromDataUrl's doc comment).
    final validationError = validateImageFile(file);
    if (validationError != null) {
      return _BatchItem(
        thumb: Uint8List(0),
        ok: false,
        englishKey: null,
        label: file.name,
        confidence: 0,
        failReason: validationError,
        included: false,
      );
    }

    try {
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoadEnd.first;
      final dataUrl = reader.result as String;
      final bytes = await cropCenterSquareFromDataUrl(dataUrl);

      final data = await ApiService.predictObject(bytes);
      final ok = data['success'] == true;
      return _BatchItem(
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
      return _BatchItem(
        thumb: Uint8List(0),
        ok: false,
        englishKey: null,
        label: file.name,
        confidence: 0,
        failReason: 'Could not read that photo.',
        included: false,
      );
    }
  }

  void _sendNow() {
    final cs = widget.classSession;
    final keys = _includedKeys.take(_maxQuizWords).toList();
    if (cs == null || keys.isEmpty) return;
    cs.socket.pushBatchQuiz(cs.sessionId, keys);
    Navigator.pop(context);
  }

  void _addToPool() {
    final cs = widget.classSession;
    final keys = _includedKeys;
    if (cs == null || keys.isEmpty) return;
    cs.socket.stageBatchWords(cs.sessionId, keys);
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

  /// Prep mode: stage the words onto the classroom itself, no session needed.
  Future<void> _saveForClass() async {
    final classroomId = widget.prepClassroomId;
    final keys = _includedKeys;
    if (classroomId == null || keys.isEmpty) return;

    final res = await ApiService.prepareClassroomWords(classroomId, keys);
    if (!mounted) return;
    if (res['prepared_words'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              (res['message'] as String?) ?? 'Could not save the words'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${keys.length} word${keys.length == 1 ? '' : 's'} saved — '
          'they will be in your next session',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final includedCount = _includedKeys.length;
    // The 10-question cap only limits "Send Now" (a live quiz); prep mode
    // saves every word, so the warning would just confuse.
    final overCap =
        includedCount > _maxQuizWords && widget.prepClassroomId == null;

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
                          widget.prepClassroomId != null
                              ? 'Prep before class: pick photos now and the '
                                  'words will be ready in your next session.'
                              : 'Pick several photos — we\'ll recognise each '
                                  'one, then you send them as a quiz.',
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
                      : (item.failReason ?? 'Try a clearer photo'),
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
    final prepMode = widget.prepClassroomId != null;
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
      child: prepMode
          ? FilledButton.icon(
              onPressed: canSend ? _saveForClass : null,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Save for Class'),
              style: AppTheme.primaryButton,
            )
          : Row(
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
