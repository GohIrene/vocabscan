// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_avatar.dart';
import '../widgets/student_progress.dart';
import 'batch_upload_screen.dart';

/// Teacher: create saved classes and manage who is in them.
///
/// A saved class is what lets children tap their name instead of spelling it,
/// and gives their XP, levels and badges somewhere permanent to live. Sessions
/// can still be run without one — that path is unchanged.
class ClassroomManageScreen extends StatefulWidget {
  final String teacherId;

  const ClassroomManageScreen({super.key, required this.teacherId});

  @override
  State<ClassroomManageScreen> createState() => _ClassroomManageScreenState();
}

class _ClassroomManageScreenState extends State<ClassroomManageScreen> {
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClassroom,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
      ),
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
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Text(_error!,
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(color: AppTheme.error)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: AppTheme.secondaryButton,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: AppTheme.sm),
        Image.asset(
          'assets/icons/school.png',
          width: 44,
          height: 44,
          errorBuilder: (_, _, _) => const Icon(Icons.school, size: 44),
        ),
        const SizedBox(height: 6),
        Text(
          'My Classes',
          style: AppTheme.heading
              .copyWith(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          'Students in a saved class tap their name to join, and keep their '
          'XP and badges between lessons.',
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(fontSize: 14, color: AppTheme.textLight),
        ),
        const SizedBox(height: 20),
        if (_classrooms.isEmpty) _buildEmpty() else ..._classrooms.map(_buildClassroomCard),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          const Text('📚', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppTheme.md),
          Text('No classes yet',
              style: AppTheme.subheading.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Create a class, add your students once, and they can tap their '
            'name to join every lesson after that.',
            textAlign: TextAlign.center,
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomCard(Map<String, dynamic> room) {
    final id = room['classroom_id'] as String? ?? '';
    final name = room['name'] as String? ?? 'Class';
    final students = (room['students'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    final expanded = _expandedId == id;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandedId = expanded ? null : id),
            child: Row(
              children: [
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
                        '${students.length == 1 ? '' : 's'}',
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
                child: Text('No students yet — add your first one below.',
                    style: AppTheme.caption),
              )
            else
              ...students.map((s) => _buildStudentRow(id, s)),
            const SizedBox(height: AppTheme.sm),
            Wrap(
              spacing: AppTheme.sm,
              runSpacing: AppTheme.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addStudent(id),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Add Student'),
                  style: _compactButton,
                ),
                OutlinedButton.icon(
                  onPressed: () => _importCsv(id),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Import Excel (CSV)'),
                  style: _compactButton,
                ),
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Template'),
                  style: _compactButton,
                ),
                OutlinedButton.icon(
                  onPressed: () => _prepPhotos(id),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Prep Photos'),
                  style: _compactButton,
                ),
              ],
            ),
            _buildPreparedWords(id, room),
          ],
        ],
      ),
    );
  }

  /// Roomier default buttons don't fit four-up in a card; this keeps the
  /// same look at a size that wraps nicely.
  static final ButtonStyle _compactButton = OutlinedButton.styleFrom(
    foregroundColor: AppTheme.primary,
    side: const BorderSide(color: AppTheme.primary, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    ),
    textStyle: AppTheme.caption.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  );

  /// Words prepped from photos before class, with per-word remove. These are
  /// seeded into every session run against this class.
  Widget _buildPreparedWords(String classroomId, Map<String, dynamic> room) {
    final words =
        (room['prepared_words'] as List? ?? const []).cast<String>();
    if (words.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prepped words (in every session)',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: words.map((w) {
              return Chip(
                label: Text(w, style: AppTheme.caption.copyWith(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600,
                )),
                backgroundColor: AppTheme.primaryLight,
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removePreparedWord(classroomId, w),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
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
            color: AppTheme.primary,
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
                            ? AppTheme.primary
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
