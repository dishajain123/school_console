import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/academics/academic_year_item.dart';
import '../../../data/models/academics/section_item.dart';
import '../../../data/models/academics/standard_item.dart';
import '../../../data/models/academics/subject_item.dart';
import '../../../domain/providers/academic_provider.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

class AcademicYearsScreen extends ConsumerStatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  ConsumerState<AcademicYearsScreen> createState() =>
      _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends ConsumerState<AcademicYearsScreen> {
  int _reloadSeed = 0;

  Future<_Phase3Data> _loadAll() async {
    final auth = ref.read(authControllerProvider).valueOrNull;
    final repo = ref.read(academicRepositoryProvider);
    final schoolId = await repo.resolveSchoolId(auth?.schoolId);
    final years = await repo.listYears(schoolId: schoolId);
    final active = years
        .where((y) => y.isActive)
        .cast<AcademicYearItem?>()
        .firstWhere(
          (y) => y != null,
          orElse: () => years.isNotEmpty ? years.first : null,
        );
    final yearId = active?.id;
    final standards = await repo.listStandards(
      schoolId: schoolId,
      academicYearId: yearId,
    );
    final sections = await repo.listSections(
      schoolId: schoolId,
      academicYearId: yearId,
    );
    final subjects = await repo.listSubjects(schoolId: schoolId);
    return _Phase3Data(
      schoolId: schoolId,
      years: years,
      activeYearId: yearId,
      standards: standards,
      sections: sections,
      subjects: subjects,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Academic Structure Setup',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<_Phase3Data>(
          key: ValueKey(_reloadSeed),
          future: _loadAll(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final data = snapshot.data!;
            return ListView(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Phase 3 status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _createAcademicYear(data.schoolId),
                      icon: const Icon(Icons.add),
                      label: const Text('New Year'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data.activeYearId == null
                      ? 'No active academic year'
                      : 'Active year: ${data.years.firstWhere((y) => y.id == data.activeYearId).name}',
                ),
                const SizedBox(height: 16),
                _buildYears(data),
                const SizedBox(height: 16),
                _buildStandards(data),
                const SizedBox(height: 16),
                _buildSections(data),
                const SizedBox(height: 16),
                _buildSubjects(data),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildYears(_Phase3Data data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1) Academic Years',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (data.years.isEmpty) const Text('No years created yet.'),
            ...data.years.map(
              (y) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${y.name} (${_fmt(y.startDate)} to ${_fmt(y.endDate)})',
                ),
                subtitle: Text(y.isActive ? 'ACTIVE' : 'INACTIVE'),
                trailing: y.isActive
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : TextButton(
                        onPressed: () => _activateYear(data.schoolId, y.id),
                        child: const Text('Activate'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandards(_Phase3Data data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '2) Classes (Standards)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton(
                  onPressed: data.activeYearId == null
                      ? null
                      : () =>
                            _createStandard(data.schoolId, data.activeYearId!),
                  child: const Text('Add Class'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.standards.isEmpty)
              const Text('No classes defined for active year.'),
            ...data.standards.map(
              (s) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.name),
                subtitle: Text('Level ${s.level}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSections(_Phase3Data data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '3) Sections',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton(
                  onPressed: data.activeYearId == null || data.standards.isEmpty
                      ? null
                      : () => _createSection(data),
                  child: const Text('Add Section'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.sections.isEmpty)
              const Text('No sections defined for active year.'),
            ...data.sections.map((sec) {
              final std = data.standards
                  .where((s) => s.id == sec.standardId)
                  .firstWhere(
                    (s) => true,
                    orElse: () => StandardItem(
                      id: sec.standardId,
                      name: 'Unknown Class',
                      level: 0,
                      schoolId: data.schoolId,
                    ),
                  );
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${std.name} - ${sec.name}'),
                subtitle: Text(sec.isActive ? 'ACTIVE' : 'INACTIVE'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjects(_Phase3Data data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '4) Subject Master (Independent)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _createSubject(data),
                  child: const Text('Add Subject'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.subjects.isEmpty) const Text('No subjects added yet.'),
            ...data.subjects.map(
              (subj) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${subj.name} (${subj.code})'),
                subtitle: Text(
                  subj.standardId == null || subj.standardId!.isEmpty
                      ? 'Global Subject'
                      : 'Class-linked',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAcademicYear(String schoolId) async {
    final nameCtrl = TextEditingController();
    DateTime? start;
    DateTime? end;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Create Academic Year'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name (e.g. 2026-2027)',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setLocalState(() => start = picked);
                    }
                  },
                  child: Text(
                    start == null
                        ? 'Select Start Date'
                        : 'Start: ${_fmt(start!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: DateTime.now().add(
                        const Duration(days: 300),
                      ),
                    );
                    if (picked != null) {
                      setLocalState(() => end = picked);
                    }
                  },
                  child: Text(
                    end == null ? 'Select End Date' : 'End: ${_fmt(end!)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (start == null || end == null) return;
                await ref
                    .read(academicRepositoryProvider)
                    .createYear(
                      schoolId: schoolId,
                      name: nameCtrl.text.trim(),
                      startDate: start!,
                      endDate: end!,
                    );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _refresh();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateYear(String schoolId, String yearId) async {
    await ref
        .read(academicRepositoryProvider)
        .activateYear(schoolId: schoolId, yearId: yearId);
    _refresh();
  }

  Future<void> _createStandard(String schoolId, String academicYearId) async {
    final nameCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Class'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Class Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: levelCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Level (1-12)'),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Invalid level' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await ref
                  .read(academicRepositoryProvider)
                  .createStandard(
                    schoolId: schoolId,
                    name: nameCtrl.text.trim(),
                    level: int.parse(levelCtrl.text.trim()),
                    academicYearId: academicYearId,
                  );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _refresh();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSection(_Phase3Data data) async {
    final secCtrl = TextEditingController();
    StandardItem? selected = data.standards.isNotEmpty
        ? data.standards.first
        : null;
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Create Section'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected?.id,
                  items: data.standards
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    setLocalState(() {
                      selected = data.standards
                          .where((s) => s.id == v)
                          .firstOrNull;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Class'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: secCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Section (A/B/C)',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (selected == null || data.activeYearId == null) return;
                await ref
                    .read(academicRepositoryProvider)
                    .createSection(
                      schoolId: data.schoolId,
                      standardId: selected!.id,
                      academicYearId: data.activeYearId!,
                      sectionName: secCtrl.text.trim(),
                    );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _refresh();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSubject(_Phase3Data data) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? selectedStandardId;
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Create Subject'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Code'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: selectedStandardId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Global (Independent)'),
                    ),
                    ...data.standards.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text('Class-linked: ${s.name}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocalState(() => selectedStandardId = v),
                  decoration: const InputDecoration(
                    labelText: 'Optional Class Link',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                await ref
                    .read(academicRepositoryProvider)
                    .createSubject(
                      schoolId: data.schoolId,
                      name: nameCtrl.text.trim(),
                      code: codeCtrl.text.trim(),
                      standardId: selectedStandardId,
                    );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _refresh();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _refresh() {
    setState(() {
      _reloadSeed++;
    });
  }

  String _fmt(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _Phase3Data {
  _Phase3Data({
    required this.schoolId,
    required this.years,
    required this.activeYearId,
    required this.standards,
    required this.sections,
    required this.subjects,
  });

  final String schoolId;
  final List<AcademicYearItem> years;
  final String? activeYearId;
  final List<StandardItem> standards;
  final List<SectionItem> sections;
  final List<SubjectItem> subjects;
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
