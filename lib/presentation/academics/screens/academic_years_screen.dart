// lib/presentation/academics/screens/academic_years_screen.dart  [Admin Console]
// Phase 3: Academic Years and Structure management.
// Displays the school's academic year structure:
//   years, classes, sections, subjects.
// Only PRINCIPAL and STAFF_ADMIN can create/edit; STAFF with settings:manage can view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/academics/academic_year_item.dart';
import '../../../data/models/academics/section_item.dart';
import '../../../data/models/academics/standard_item.dart';
import '../../../data/models/academics/subject_item.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/academic_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../core/theme/admin_colors.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

class AcademicYearsScreen extends ConsumerStatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  ConsumerState<AcademicYearsScreen> createState() =>
      _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends ConsumerState<AcademicYearsScreen>
    with SingleTickerProviderStateMixin {
  int _reloadSeed = 0;
  String? _previewYearId;
  late TabController _sectionTabController;

  @override
  void initState() {
    super.initState();
    _sectionTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _sectionTabController.dispose();
    super.dispose();
  }

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
    final yearId = (_previewYearId != null &&
            years.any((y) => y.id == _previewYearId))
        ? _previewYearId
        : active?.id;
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
      title: 'Academic years',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: FutureBuilder<_Phase3Data>(
          key: ValueKey(_reloadSeed),
          future: _loadAll(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AdminLoadingPlaceholder(
                message: 'Loading academic structure…',
                height: 360,
              );
            }
            if (snapshot.hasError) {
              final theme = Theme.of(context);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AdminSpacing.lg),
                  child: Material(
                    color: AdminColors.dangerSurface,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(AdminSpacing.md),
                      child: SelectableText(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AdminColors.danger,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            final data = snapshot.data!;
            final activeYear = data.activeYearId == null
                ? null
                : data.years.where((y) => y.id == data.activeYearId).firstOrNull;
            final previewYear = (_previewYearId != null
                    ? data.years.where((y) => y.id == _previewYearId).firstOrNull
                    : null) ??
                activeYear;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageHeader(
                  title: 'Academic years & structure',
                  subtitle:
                      'Configure the active year, classes, sections, and subjects.',
                  primaryAction: FilledButton.icon(
                    onPressed: () => _createAcademicYear(data.schoolId),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Create year'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.primaryAction,
                      foregroundColor: AdminColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                _buildHeroStrip(data, activeYear, previewYear),
                const SizedBox(height: AdminSpacing.sm),
                Material(
                  color: AdminColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AdminColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TabBar(
                    controller: _sectionTabController,
                    isScrollable: true,
                    indicatorColor: AdminColors.primaryAction,
                    labelColor: AdminColors.primaryAction,
                    unselectedLabelColor: AdminColors.textSecondary,
                    dividerColor: const Color(0x00000000),
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: 'Years (${data.years.length})'),
                      Tab(text: 'Classes (${data.standards.length})'),
                      Tab(text: 'Sections (${data.sections.length})'),
                      Tab(text: 'Subjects (${data.subjects.length})'),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AdminColors.border),
                Expanded(
                  child: TabBarView(
                    controller: _sectionTabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _tabScroll(_buildYears(data)),
                      _tabScroll(_buildStandards(data)),
                      _tabScroll(_buildSections(data)),
                      _tabScroll(_buildSubjects(data)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabScroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: AdminSpacing.md),
      child: child,
    );
  }

  Widget _buildHeroStrip(
    _Phase3Data data,
    AcademicYearItem? activeYear,
    AcademicYearItem? previewYear,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AdminColors.border),
      ),
      color: AdminColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeYear == null
                  ? 'No active academic year. Create and activate one to continue setup.'
                  : 'Active year · ${activeYear.name} · ${_fmt(activeYear.startDate)} – ${_fmt(activeYear.endDate)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AdminColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AdminSpacing.md),
            Wrap(
              spacing: AdminSpacing.sm,
              runSpacing: AdminSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Preview data for',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AdminColors.textSecondary,
                      ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'preview_year_${previewYear?.id ?? 'none'}_${data.years.length}',
                    ),
                    initialValue: previewYear?.id,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: data.years
                        .map(
                          (y) => DropdownMenuItem<String>(
                            value: y.id,
                            child: Text(
                              '${y.name}${y.isActive ? ' · Active' : ''}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _previewYearId = v;
                        _reloadSeed++;
                      });
                    },
                  ),
                ),
                OutlinedButton(
                  onPressed: activeYear == null
                      ? null
                      : () {
                          setState(() {
                            _previewYearId = activeYear.id;
                            _reloadSeed++;
                          });
                        },
                  child: const Text('Match active year'),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.md),
            Wrap(
              spacing: AdminSpacing.sm,
              runSpacing: AdminSpacing.sm,
              children: [
                _StatBadge(
                  label: 'Years',
                  value: data.years.length.toString(),
                  icon: Icons.calendar_month_outlined,
                ),
                _StatBadge(
                  label: 'Classes',
                  value: data.standards.length.toString(),
                  icon: Icons.class_outlined,
                ),
                _StatBadge(
                  label: 'Sections',
                  value: data.sections.length.toString(),
                  icon: Icons.grid_view_rounded,
                ),
                _StatBadge(
                  label: 'Subjects',
                  value: data.subjects.length.toString(),
                  icon: Icons.menu_book_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYears(_Phase3Data data) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: AdminColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Academic years',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _createAcademicYear(data.schoolId),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add year'),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            if (data.years.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AdminSpacing.sm),
                child: AdminEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No academic years yet',
                  message: 'Use Create year in the header to add your first year.',
                ),
              )
            else
              ...data.years.map(
                (y) => Container(
                  margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: y.isActive
                          ? AdminColors.primaryAction.withValues(alpha: 0.35)
                          : AdminColors.border,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: y.isActive
                        ? AdminColors.primaryAction.withValues(alpha: 0.06)
                        : AdminColors.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        y.isActive
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        color: y.isActive
                            ? AdminColors.primaryAction
                            : AdminColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              y.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_fmt(y.startDate)} to ${_fmt(y.endDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      y.isActive
                          ? Chip(
                              label: const Text('Active'),
                              backgroundColor:
                                  AdminColors.primaryAction.withValues(alpha: 0.12),
                              side: BorderSide(
                                color: AdminColors.primaryAction.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: AdminColors.primaryAction,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              visualDensity: VisualDensity.compact,
                            )
                          : OutlinedButton(
                              onPressed: () =>
                                  _activateYear(data.schoolId, y.id),
                              child: const Text('Activate'),
                            ),
                    ],
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
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Classes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: data.activeYearId == null
                      ? null
                      : () =>
                            _createStandard(data.schoolId, data.activeYearId!),
                  child: const Text('Add class'),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            if (data.standards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
                child: AdminEmptyState(
                  icon: Icons.class_outlined,
                  title: data.activeYearId == null
                      ? 'Activate a year first'
                      : 'No classes for this preview',
                  message: data.activeYearId == null
                      ? 'Create and activate an academic year, then add classes.'
                      : 'Add classes for the selected preview year, or switch year above.',
                ),
              )
            else
              Wrap(
                spacing: AdminSpacing.sm,
                runSpacing: AdminSpacing.sm,
                children: data.standards
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AdminColors.borderSubtle,
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Text(
                          '${s.name} · Level ${s.level}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSections(_Phase3Data data) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sections',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: data.activeYearId == null || data.standards.isEmpty
                      ? null
                      : () => _createSection(data),
                  child: const Text('Add section'),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            if (data.sections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
                child: AdminEmptyState(
                  icon: Icons.grid_view_outlined,
                  title: data.standards.isEmpty
                      ? 'Add classes first'
                      : 'No sections for this preview',
                  message: data.standards.isEmpty
                      ? 'Sections are created per class after classes exist.'
                      : 'Use Add section or pick another preview year.',
                ),
              )
            else
              ...data.sections.map((sec) {
                final std = data.standards
                    .where((s) => s.id == sec.standardId)
                    .firstWhere(
                      (s) => true,
                      orElse: () => StandardItem(
                        id: sec.standardId,
                        name: 'Unknown class',
                        level: 0,
                        schoolId: data.schoolId,
                      ),
                    );
                return Container(
                  margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border.all(color: AdminColors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: AdminColors.surface,
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '${std.name} · Section ${sec.name}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      sec.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      sec.isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                      color: sec.isActive
                          ? AdminColors.primaryAction
                          : AdminColors.textMuted,
                      size: 20,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjects(_Phase3Data data) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subjects',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => _createSubject(data),
                  child: const Text('Add subject'),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.sm),
            if (data.subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AdminSpacing.sm),
                child: AdminEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No subjects yet',
                  message: 'Add subjects with Add subject — they can be school-wide or class-linked.',
                ),
              )
            else
              ...data.subjects.map(
                (subj) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AdminColors.borderSubtle,
                    foregroundColor: AdminColors.textPrimary,
                    child: Text(
                      subj.code.isNotEmpty ? subj.code.characters.first : 'S',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    '${subj.name} (${subj.code})',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    subj.standardId == null || subj.standardId!.isEmpty
                        ? 'School-wide'
                        : 'Class-linked',
                    style: TextStyle(
                      color: AdminColors.textSecondary,
                      fontSize: 12,
                    ),
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
    ref.read(activeAcademicYearProvider.notifier).setYear(yearId);
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

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AdminColors.textSecondary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AdminColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
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
