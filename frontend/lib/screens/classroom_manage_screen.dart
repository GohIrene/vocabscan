// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';
import '../widgets/student_progress.dart';
import '../widgets/teacher_shell.dart';
import '../widgets/teacher_ui.dart';
import 'batch_upload_screen.dart';

/// Teacher: create saved classes and manage who is in them.
///
/// A saved class is what lets children tap their name instead of spelling it,
/// and gives their XP, levels and badges somewhere permanent to live. Sessions
/// can still be run without one — that path is unchanged.
///
/// [ClassroomManageView] is the embeddable body used inside `TeacherShell`;
/// [ClassroomManageScreen] is a thin standalone wrapper around it.
class ClassroomManageScreen extends StatelessWidget {
  final String teacherId;

  const ClassroomManageScreen({super.key, required this.teacherId});

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
            Expanded(child: ClassroomManageView(teacherId: teacherId)),
          ],
        ),
      ),
    );
  }
}

/// Embeddable "My Classes" body — no Scaffold, scrolls inside its host.
class ClassroomManageView extends StatefulWidget {
  final String teacherId;

  /// Called after any change that affects roster or class counts, so a host
  /// dashboard can refresh its stat tiles.
  final VoidCallback? onChanged;

  const ClassroomManageView({
    super.key,
    required this.teacherId,
    this.onChanged,
  });

  @override
  State<ClassroomManageView> createState() => _ClassroomManageViewState();
}

class _ClassroomManageViewState extends State<ClassroomManageView> {
  List<Map<String, dynamic>> _classrooms = [];
  bool _loading = true;
  String? _error;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await ApiService.getClassrooms(widget.teacherId);
      if (!mounted) return;
      setState(() {
        _classrooms = rooms;
        _loading = false;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your classes. Please try again.';
      });
    }
  }

  Future<void> _createClassroom() async {
    final name = await _promptForText(
      title: 'New Class',
      hint: 'e.g. Year 2 Melur',
      confirmLabel: 'Create',
    );
    if (name == null || name.isEmpty) return;

    final res = await ApiService.createClassroom(widget.teacherId, name);
    if (!mounted) return;
    if (res['classroom_id'] == null) {
      _toast((res['message'] as String?) ?? 'Could not create the class');
      return;
    }
    _load();
  }

  Future<void> _addStudent(String classroomId) async {
    final result = await showDialog<({String name, int avatar})>(
      context: context,
      builder: (_) => const _AddStudentDialog(),
    );
    if (result == null || !mounted) return;

    final res = await ApiService.addClassroomStudent(
        classroomId, result.name, result.avatar);
    if (!mounted) return;
    if (res['student_id'] == null) {
      _toast((res['message'] as String?) ?? 'Could not add that student');
      return;
    }
    _load();
  }

  /// Downloads a one-column CSV that opens directly in Excel — fill in one
  /// name per row, save, and import it back.
  void _downloadTemplate() {
    const template = 'name\nAli\nSiti\nMei Ling\n';
    final blob = html.Blob([utf8.encode(template)], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'students_template.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Imports student names from a CSV/Excel export (one name per row).
  Future<void> _importCsv(String classroomId) async {
    final input = html.FileUploadInputElement()..accept = '.csv,.txt';
    html.document.body!.append(input);
    input.click();
    await input.onChange.first;
    input.remove();
    final file = input.files?.first;
    if (file == null) return;

    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoadEnd.first;
    final text = (reader.result as String?) ?? '';

    // One name per line; a leading "name" header row (from the template) is
    // skipped, as are quotes Excel sometimes adds around cells.
    final names = <String>[];
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.split(',').first.replaceAll('"', '').trim();
      if (line.isEmpty) continue;
      if (names.isEmpty && line.toLowerCase() == 'name') continue;
      names.add(line);
    }
    if (names.isEmpty) {
      _toast('No names found in that file — one name per row.');
      return;
    }

    final res = await ApiService.importClassroomStudents(classroomId, names);
    if (!mounted) return;
    final added = (res['added'] as num? ?? 0).toInt();
    final skipped = (res['skipped'] as List? ?? const []).length;
    if (added == 0 && skipped == 0) {
      _toast((res['message'] as String?) ?? 'Could not import that file');
      return;
    }
    _toast('Imported $added student${added == 1 ? '' : 's'}'
        '${skipped > 0 ? ' · $skipped skipped (duplicate or class full)' : ''}');
    _load();
  }

  /// Pre-class photo prep: recognised words are saved on the class and seeded
  /// into every future session.
  Future<void> _prepPhotos(String classroomId) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchUploadScreen(prepClassroomId: classroomId),
      ),
    );
    if (saved == true) _load();
  }

  /// Reuse an item from the words this teacher has already covered — no new
  /// scan, no duplicated translations/audio (only the key is stored on the
  /// class; the vocabulary item itself is shared).
  Future<void> _addExistingVocab(
      String classroomId, List<String> alreadyPrepared) async {
    List<Map<String, dynamic>> catalog;
    try {
      catalog = await ApiService.getTeacherRevisionWords(widget.teacherId);
    } catch (e) {
      if (!mounted) return;
      _toast('Could not load your vocabulary: $e');
      return;
    }
    if (!mounted) return;

    if (catalog.isEmpty) {
      _toast('No past vocabulary yet — run a session or prep photos first.');
      return;
    }

    final keys = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AddExistingVocabDialog(
        catalog: catalog,
        alreadyPrepared: alreadyPrepared.toSet(),
      ),
    );
    if (keys == null || keys.isEmpty || !mounted) return;

    final res = await ApiService.prepareClassroomWords(classroomId, keys);
    if (!mounted) return;
    if (res['prepared_words'] == null) {
      _toast((res['message'] as String?) ?? 'Could not add those words');
      return;
    }
    _toast('Added ${keys.length} word${keys.length == 1 ? '' : 's'} '
        'to this class');
    _load();
  }

  /// Copy another saved class's prepared words into this one. Reuses the same
  /// vocabulary items (keys only), so the two classes share definitions while
  /// their session results and student progress stay entirely separate.
  Future<void> _copyFromClass(
      String classroomId, List<String> alreadyPrepared) async {
    final others = _classrooms
        .where((c) => (c['classroom_id'] as String?) != classroomId)
        .where((c) =>
            ((c['prepared_words'] as List?) ?? const []).isNotEmpty)
        .toList();

    if (others.isEmpty) {
      _toast('No other class has prepared words to copy yet.');
      return;
    }

    final source = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CopyFromClassDialog(sources: others),
    );
    if (source == null || !mounted) return;

    final sourceKeys =
        ((source['prepared_words'] as List?) ?? const []).cast<String>();
    final have = alreadyPrepared.toSet();
    final newKeys = sourceKeys.where((k) => !have.contains(k)).toList();
    if (newKeys.isEmpty) {
      _toast('This class already has all of those words.');
      return;
    }

    final res = await ApiService.prepareClassroomWords(classroomId, newKeys);
    if (!mounted) return;
    if (res['prepared_words'] == null) {
      _toast((res['message'] as String?) ?? 'Could not copy those words');
      return;
    }
    _toast('Copied ${newKeys.length} word${newKeys.length == 1 ? '' : 's'} '
        'from ${source['name']}');
    _load();
  }

  Future<void> _removePreparedWord(String classroomId, String key) async {
    final res = await ApiService.removePreparedWord(classroomId, key);
    if (!mounted) return;
    if (res['prepared_words'] == null) {
      _toast((res['message'] as String?) ?? 'Could not remove that word');
      return;
    }
    _load();
  }

  /// Teacher gives or takes points by hand (participation, behaviour…).
  Future<void> _adjustPoints(
      String classroomId, String studentId, String name) async {
    final amountCtrl = TextEditingController(text: '10');
    final delta = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Points for $name', style: AppTheme.subheading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'How many points?',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              final n = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (n > 0) Navigator.pop(ctx, -n);
            },
            icon: const Icon(Icons.remove, size: 16),
            label: const Text('Deduct'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
          ),
          FilledButton.icon(
            onPressed: () {
              final n = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (n > 0) Navigator.pop(ctx, n);
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            style: AppTheme.smallButton,
          ),
        ],
      ),
    );
    if (delta == null || delta == 0 || !mounted) return;

    final res =
        await ApiService.adjustStudentPoints(classroomId, studentId, delta);
    if (!mounted) return;
    if (res['student_id'] == null) {
      _toast((res['message'] as String?) ?? 'Could not update points');
      return;
    }
    _toast(delta > 0
        ? 'Added $delta XP to $name'
        : 'Deducted ${-delta} XP from $name');
    _load();
  }

  Future<void> _removeStudent(
      String classroomId, String studentId, String name) async {
    final confirmed = await _confirm(
      'Remove $name?',
      'Their XP, level and badges will be deleted too.',
    );
    if (confirmed != true) return;

    final ok = await ApiService.removeClassroomStudent(classroomId, studentId);
    if (!mounted) return;
    if (!ok) {
      _toast('Could not remove that student');
      return;
    }
    _load();
  }

  Future<void> _deleteClassroom(String classroomId, String name) async {
    final confirmed = await _confirm(
      'Delete $name?',
      'Every student in this class and all their progress will be deleted. '
          'This cannot be undone.',
    );
    if (confirmed != true) return;

    final ok = await ApiService.deleteClassroom(classroomId);
    if (!mounted) return;
    if (!ok) {
      _toast('Could not delete the class');
      return;
    }
    _load();
  }

  // ── Small dialog helpers ───────────────────────────────────────────────────

  Future<String?> _promptForText({
    required String title,
    required String hint,
    required String confirmLabel,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTheme.subheading),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: InputDecoration(hintText: hint, counterText: ''),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: AppTheme.smallButton,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTheme.subheading),
        content: Text(message, style: AppTheme.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(AppTheme.xl, 0, AppTheme.xl, AppTheme.xxl),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: AppTheme.body.copyWith(color: AppTheme.error)),
              const SizedBox(height: 20),
              TeacherSecondaryButton(
                label: 'Try Again',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Students in a saved class tap their name to join, and keep '
                'their XP and badges between lessons.',
                style: AppTheme.caption,
              ),
            ),
            const SizedBox(width: AppTheme.md),
            TeacherPrimaryButton(
              label: 'New Class',
              icon: Icons.add_rounded,
              onPressed: _createClassroom,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.lg),
        if (_classrooms.isEmpty)
          TeacherEmptyState(
            emoji: '📚',
            title: 'No classes yet',
            message:
                'Create a class, add your students once, and they can tap '
                'their name to join every lesson after that.',
            action: TeacherPrimaryButton(
              label: 'New Class',
              icon: Icons.add_rounded,
              onPressed: _createClassroom,
            ),
          )
        else
          ..._classrooms.map(_buildClassroomCard),
      ],
    );
  }

  Widget _buildClassroomCard(Map<String, dynamic> room) {
    final id = room['classroom_id'] as String? ?? '';
    final name = room['name'] as String? ?? 'Class';
    final students = (room['students'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    final prepared =
        (room['prepared_words'] as List? ?? const []).cast<String>();
    final expanded = _expandedId == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: TeacherSectionCard(
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              onTap: () => setState(() => _expandedId = expanded ? null : id),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TeacherShell.accentLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.school_rounded,
                        size: 22, color: TeacherShell.accent),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTheme.subheading
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          '${students.length} student'
                          '${students.length == 1 ? '' : 's'}'
                          '${prepared.isEmpty ? '' : ' · ${prepared.length} '
                              'prepared word${prepared.length == 1 ? '' : 's'}'}',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete class',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppTheme.error,
                    onPressed: () => _deleteClassroom(id, name),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.textDark),
                ],
              ),
            ),
            if (expanded) ...[
              const Divider(height: AppTheme.xl),
              if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No students yet — add your first one below.',
                        style: AppTheme.caption),
                  ),
                )
              else
                ...students.map((s) => _buildStudentRow(id, s)),
              const SizedBox(height: AppTheme.sm),
              Wrap(
                spacing: AppTheme.sm,
                runSpacing: AppTheme.sm,
                children: [
                  _chipButton(Icons.person_add_alt, 'Add Student',
                      () => _addStudent(id)),
                  _chipButton(Icons.upload_file, 'Import Excel (CSV)',
                      () => _importCsv(id)),
                  _chipButton(
                      Icons.download, 'Template', _downloadTemplate),
                ],
              ),
              const SizedBox(height: AppTheme.md),
              _buildVocabSection(id, room, prepared),
            ],
          ],
        ),
      ),
    );
  }

  /// Prepared-vocabulary block: the words seeded into every session for this
  /// class, plus the three ways to add more — a new photo, an item already in
  /// the teacher's vocabulary, or a copy from another class.
  Widget _buildVocabSection(
      String classroomId, Map<String, dynamic> room, List<String> prepared) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 16, color: TeacherShell.accent),
              const SizedBox(width: 6),
              Text(
                'Prepared vocabulary',
                style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w800, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Seeded into every session for this class. Reusing a word shares '
            'the same definition and audio — each class keeps its own results.',
            style: AppTheme.caption.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: AppTheme.md),
          if (prepared.isEmpty)
            Text('No prepared words yet.',
                style: AppTheme.caption.copyWith(fontStyle: FontStyle.italic))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: prepared.map((w) {
                return Chip(
                  label: Text(w,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w600,
                      )),
                  backgroundColor: TeacherShell.accentLight,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removePreparedWord(classroomId, w),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          const SizedBox(height: AppTheme.md),
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.sm,
            children: [
              _chipButton(Icons.photo_library_outlined, 'Prep Photos',
                  () => _prepPhotos(classroomId)),
              _chipButton(Icons.library_add_outlined, 'Add Vocabulary',
                  () => _addExistingVocab(classroomId, prepared)),
              _chipButton(Icons.copy_all_outlined, 'Copy From Class',
                  () => _copyFromClass(classroomId, prepared)),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact outlined action used inside the class card.
  Widget _chipButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: TeacherShell.accent,
        side: BorderSide(
            color: TeacherShell.accent.withValues(alpha: 0.45), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        textStyle: AppTheme.caption.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
    );
  }

  Widget _buildStudentRow(String classroomId, Map<String, dynamic> s) {
    final studentId = s['student_id'] as String? ?? '';
    final name = s['name'] as String? ?? '';
    final badges = (s['badges'] as List? ?? const []).cast<String>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudentAvatar(avatar: (s['avatar'] as num? ?? 0).toInt(), size: 44),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                LevelBar(
                  level: (s['level'] as num? ?? 1).toInt(),
                  xpIntoLevel: (s['xp_into_level'] as num? ?? 0).toInt(),
                  xpPerLevel: (s['xp_per_level'] as num? ?? 100).toInt(),
                  compact: true,
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  BadgeStrip(badgeIds: badges, size: 11),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add / deduct points',
            icon: const Icon(Icons.exposure, size: 18),
            color: TeacherShell.accent,
            onPressed: () => _adjustPoints(classroomId, studentId, name),
          ),
          IconButton(
            tooltip: 'Remove student',
            icon: const Icon(Icons.close, size: 18),
            color: AppTheme.textLight,
            onPressed: () => _removeStudent(classroomId, studentId, name),
          ),
        ],
      ),
    );
  }
}

/// Name + avatar picker for adding a student to a roster.
class _AddStudentDialog extends StatefulWidget {
  const _AddStudentDialog();

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final _controller = TextEditingController();
  int _avatar = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, avatar: _avatar));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Student', style: AppTheme.subheading),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 20,
              decoration: const InputDecoration(
                hintText: "Student's name",
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppTheme.md),
            Text('Pick an avatar',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppTheme.sm),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(kAvatarAssets.length, (i) {
                final selected = i == _avatar;
                return GestureDetector(
                  onTap: () => setState(() => _avatar = i),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? TeacherShell.accent
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: StudentAvatar(avatar: i, size: 46),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: AppTheme.smallButton,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Multi-select picker over the teacher's existing vocabulary (words already
/// covered in past sessions or prep). Selecting reuses the shared item — no
/// new translations, audio or metadata are created.
class _AddExistingVocabDialog extends StatefulWidget {
  final List<Map<String, dynamic>> catalog;
  final Set<String> alreadyPrepared;

  const _AddExistingVocabDialog({
    required this.catalog,
    required this.alreadyPrepared,
  });

  @override
  State<_AddExistingVocabDialog> createState() =>
      _AddExistingVocabDialogState();
}

class _AddExistingVocabDialogState extends State<_AddExistingVocabDialog> {
  final Set<String> _selected = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = widget.catalog.where((w) {
      if (q.isEmpty) return true;
      final en = (w['english_word'] as String? ?? '').toLowerCase();
      final ms = (w['malay_word'] as String? ?? '').toLowerCase();
      final zh = (w['chinese_word'] as String? ?? '');
      final key = (w['english_key'] as String? ?? '').toLowerCase();
      return en.contains(q) ||
          ms.contains(q) ||
          zh.contains(_query.trim()) ||
          key.contains(q);
    }).toList();

    return AlertDialog(
      title: Text('Add Vocabulary', style: AppTheme.subheading),
      content: SizedBox(
        width: 400,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search your words…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppTheme.sm),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text('No matching words.',
                          style: AppTheme.caption),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final w = items[i];
                        final key = w['english_key'] as String? ?? '';
                        final english = w['english_word'] as String? ?? key;
                        final malay = w['malay_word'] as String? ?? '';
                        final chinese = w['chinese_word'] as String? ?? '';
                        final owned = widget.alreadyPrepared.contains(key);
                        final checked = _selected.contains(key);
                        return CheckboxListTile(
                          value: owned || checked,
                          onChanged: owned
                              ? null
                              : (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(key);
                                    } else {
                                      _selected.remove(key);
                                    }
                                  }),
                          activeColor: TeacherShell.accent,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          title: Text(
                            english,
                            style: AppTheme.body
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (malay.isNotEmpty) malay,
                              if (chinese.isNotEmpty) chinese,
                              if (owned) 'already added',
                            ].join('  ·  '),
                            style: AppTheme.caption,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          style: AppTheme.smallButton,
          child: Text(_selected.isEmpty
              ? 'Add'
              : 'Add ${_selected.length}'),
        ),
      ],
    );
  }
}

/// Picks another saved class to copy prepared words from.
class _CopyFromClassDialog extends StatelessWidget {
  final List<Map<String, dynamic>> sources;

  const _CopyFromClassDialog({required this.sources});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Copy From Class', style: AppTheme.subheading),
      content: SizedBox(
        width: 380,
        height: 360,
        child: ListView.builder(
          itemCount: sources.length,
          itemBuilder: (_, i) {
            final c = sources[i];
            final count =
                ((c['prepared_words'] as List?) ?? const []).length;
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: TeacherShell.accentLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.school_rounded,
                    size: 20, color: TeacherShell.accent),
              ),
              title: Text(c['name'] as String? ?? 'Class',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '$count prepared word${count == 1 ? '' : 's'}',
                style: AppTheme.caption,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, c),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
