// lib/presentation/enrollment/screens/promotion_workflow_screen.dart  [Admin Console]
// Phase 7 — Bulk Promotion Workflow Screen.
// PRINCIPAL / SUPERADMIN: preview all students eligible for promotion, assign
// decisions (PROMOTE / REPEAT / GRADUATE / SKIP) and execute in bulk.
// Previous year mappings become read-only terminal states after execution.
// User identity, admission numbers, and parent links are NEVER recreated.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/enrollment_provider.dart';
import '../../../data/repositories/enrollment_repository.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _Decision { promote, repeat, graduate, skip }

extension _DecisionX on _Decision {
  String get apiValue {
    switch (this) {
      case _Decision.promote:
        return 'PROMOTE';
      case _Decision.repeat:
        return 'REPEAT';
      case _Decision.graduate:
        return 'GRADUATE';
      case _Decision.skip:
        return 'SKIP';
    }
  }

  String get label {
    switch (this) {
      case _Decision.promote:
        return 'Promote';
      case _Decision.repeat:
        return 'Repeat Year';
      case _Decision.graduate:
        return 'Graduate';
      case _Decision.skip:
        return 'Skip';
    }
  }

  Color get color {
    switch (this) {
      case _Decision.promote:
        return Colors.green;
      case _Decision.repeat:
        return Colors.orange;
      case _Decision.graduate:
        return Colors.blue;
      case _Decision.skip:
        return Colors.grey;
    }
  }

  static _Decision fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'REPEAT':
        return _Decision.repeat;
      case 'GRADUATE':
        return _Decision.graduate;
      case 'SKIP':
        return _Decision.skip;
      default:
        return _Decision.promote;
    }
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _AcademicYear {
  const _AcademicYear({
    required this.id,
    required this.name,
    required this.isActive,
  });
  final String id;
  final String name;
  final bool isActive;
}

class _Standard {
  const _Standard({required this.id, required this.name, required this.level});
  final String id;
  final String name;
  final int level;
}

class _Section {
  const _Section({required this.id, required this.name});
  final String id;
  final String name;
}

class _PreviewItem {
  _PreviewItem({
    required this.studentId,
    required this.mappingId,
    required this.admissionNumber,
    required this.studentName,
    required this.currentStandardId,
    required this.currentStandardName,
    required this.currentSectionName,
    required this.suggestedDecision,
    required this.suggestedNextStandardId,
    required this.suggestedNextStandardName,
    required this.suggestedNextSectionId,
    required this.suggestedNextSectionName,
    required this.hasWarning,
    required this.warningMessage,
  });

  final String studentId;
  final String mappingId;
  final String? admissionNumber;
  final String? studentName;
  final String currentStandardId;
  final String currentStandardName;
  final String? currentSectionName;
  _Decision suggestedDecision;
  final String? suggestedNextStandardId;
  final String? suggestedNextStandardName;
  final String? suggestedNextSectionId;
  final String? suggestedNextSectionName;
  final bool hasWarning;
  final String? warningMessage;

  // Admin override — starts as suggested, can be changed before execute.
  _Decision decision = _Decision.promote;
  // Row selection for bulk execution (selected by default).
  bool selected = true;
  // Admin override for target standard (used when PROMOTE/REPEAT).
  String? targetStandardId;
  // Target section override (defaults to suggested value from preview).
  String? targetSectionId;

  factory _PreviewItem.fromJson(Map<String, dynamic> json) {
    final item = _PreviewItem(
      studentId: json['student_id']?.toString() ?? '',
      mappingId: json['mapping_id']?.toString() ?? '',
      admissionNumber: json['admission_number'] as String?,
      studentName: json['student_name'] as String?,
      currentStandardId: json['current_standard_id']?.toString() ?? '',
      currentStandardName: json['current_standard_name']?.toString() ?? '',
      currentSectionName: json['current_section_name'] as String?,
      suggestedDecision: _DecisionX.fromString(
        json['suggested_decision'] as String?,
      ),
      suggestedNextStandardId: json['suggested_next_standard_id']?.toString(),
      suggestedNextStandardName:
          json['suggested_next_standard_name'] as String?,
      suggestedNextSectionId: json['suggested_next_section_id']?.toString(),
      suggestedNextSectionName: json['suggested_next_section_name'] as String?,
      hasWarning: json['has_warning'] == true,
      warningMessage: json['warning_message'] as String?,
    );
    // Default: apply suggested decision
    item.decision = item.suggestedDecision;
    item.targetStandardId = item.suggestedNextStandardId;
    item.targetSectionId = item.suggestedNextSectionId;
    return item;
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _PromotionRepository {
  _PromotionRepository(this._api);
  final EnrollmentRepository _api;

  Future<List<_AcademicYear>> listYears(String schoolId) async {
    final items = await _api.listAcademicYears(schoolId: schoolId);
    return items.map((e) {
      final m = e;
      return _AcademicYear(
        id: m['id'].toString(),
        name: m['name'].toString(),
        isActive: m['is_active'] == true,
      );
    }).toList();
  }

  Future<List<_Standard>> listStandards(
    String schoolId,
    String academicYearId,
  ) async {
    final items = await _api.listStandards(
      schoolId: schoolId,
      academicYearId: academicYearId,
    );
    return items.map((e) {
      final m = e;
      return _Standard(
        id: m['id'].toString(),
        name: m['name'].toString(),
        level: (m['level'] as num?)?.toInt() ?? 0,
      );
    }).toList()..sort((a, b) => a.level.compareTo(b.level));
  }

  Future<List<_Section>> listSections({
    required String schoolId,
    required String academicYearId,
    required String standardId,
  }) async {
    final items = await _api.listSections(
      schoolId: schoolId,
      academicYearId: academicYearId,
      standardId: standardId,
    );
    final sections =
        items
            .map(
              (e) =>
                  _Section(id: e['id'].toString(), name: e['name'].toString()),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return sections;
  }

  Future<List<_PreviewItem>> preview({
    required String sourceYearId,
    required String targetYearId,
    String? standardId,
    String? sectionId,
  }) async {
    final data = await _api.previewPromotion(
      sourceYearId: sourceYearId,
      targetYearId: targetYearId,
      standardId: standardId,
      sectionId: sectionId,
    );
    final items = (data['items'] as List?) ?? [];
    return items
        .map((e) => _PreviewItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> execute({
    required String sourceYearId,
    required String targetYearId,
    required List<_PreviewItem> items,
  }) async {
    final payload = items.map((item) {
      final m = <String, dynamic>{
        'student_id': item.studentId,
        'mapping_id': item.mappingId,
        'decision': item.decision.apiValue,
      };
      if (item.decision == _Decision.promote ||
          item.decision == _Decision.repeat) {
        if (item.targetStandardId != null) {
          m['target_standard_id'] = item.targetStandardId;
        }
        if (item.targetSectionId != null) {
          m['target_section_id'] = item.targetSectionId;
        }
      }
      return m;
    }).toList();

    return _api.executePromotion(
      sourceYearId: sourceYearId,
      targetYearId: targetYearId,
      items: payload.cast<Map<String, dynamic>>(),
    );
  }

  Future<Map<String, dynamic>> copyTeacherAssignments({
    required String sourceYearId,
    required String targetYearId,
    bool overwriteExisting = false,
  }) async {
    return _api.copyTeacherAssignments(
      sourceYearId: sourceYearId,
      targetYearId: targetYearId,
      overwriteExisting: overwriteExisting,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PromotionWorkflowScreen extends ConsumerStatefulWidget {
  const PromotionWorkflowScreen({super.key});

  @override
  ConsumerState<PromotionWorkflowScreen> createState() =>
      _PromotionWorkflowScreenState();
}

class _PromotionWorkflowScreenState
    extends ConsumerState<PromotionWorkflowScreen> {
  late final _PromotionRepository _repo;

  List<_AcademicYear> _years = [];
  List<_Standard> _sourceStandards = [];
  List<_Standard> _targetStandards = [];
  List<_Section> _sourceSections = [];
  List<_PreviewItem> _previewItems = [];
  final Map<String, List<_Section>> _targetSectionsByStandard = {};

  String? _sourceYearId;
  String? _targetYearId;
  String? _filterStandardId;
  String? _filterSectionId;
  String? _bulkTargetStandardId;
  String? _bulkTargetSectionId;

  bool _loading = false;
  bool _executing = false;
  bool _copyingAssignments = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _repo = _PromotionRepository(ref.read(enrollmentRepositoryProvider));
    _loadYears();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final years = await _repo.listYears(_schoolId!);
      setState(() => _years = years);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadTargetStandards() async {
    if (_schoolId == null || _targetYearId == null) return;
    try {
      final stds = await _repo.listStandards(_schoolId!, _targetYearId!);
      if (!mounted) return;
      setState(() {
        _targetStandards = stds;
        _targetSectionsByStandard.clear();
      });
    } catch (_) {
      setState(() => _targetStandards = []);
    }
  }

  Future<void> _loadSourceStandards() async {
    if (_schoolId == null || _sourceYearId == null) return;
    try {
      final stds = await _repo.listStandards(_schoolId!, _sourceYearId!);
      setState(() => _sourceStandards = stds);
    } catch (_) {
      setState(() => _sourceStandards = []);
    }
  }

  Future<void> _loadSourceSections() async {
    if (_schoolId == null ||
        _sourceYearId == null ||
        _filterStandardId == null ||
        _filterStandardId!.isEmpty) {
      if (!mounted) return;
      setState(() => _sourceSections = []);
      return;
    }
    try {
      final sections = await _repo.listSections(
        schoolId: _schoolId!,
        academicYearId: _sourceYearId!,
        standardId: _filterStandardId!,
      );
      if (!mounted) return;
      setState(() => _sourceSections = sections);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sourceSections = []);
    }
  }

  Future<void> _ensureTargetSectionsForStandard(String? standardId) async {
    if (_schoolId == null ||
        _targetYearId == null ||
        standardId == null ||
        standardId.isEmpty ||
        _targetSectionsByStandard.containsKey(standardId)) {
      return;
    }
    try {
      final sections = await _repo.listSections(
        schoolId: _schoolId!,
        academicYearId: _targetYearId!,
        standardId: standardId,
      );
      if (!mounted) return;
      setState(() => _targetSectionsByStandard[standardId] = sections);
    } catch (_) {
      if (!mounted) return;
      setState(() => _targetSectionsByStandard[standardId] = const []);
    }
  }

  List<_Section> _sectionsForTargetStandard(String? standardId) {
    if (standardId == null) return const [];
    return _targetSectionsByStandard[standardId] ?? const [];
  }

  int? _sourceLevelForItem(_PreviewItem item) {
    for (final standard in _sourceStandards) {
      if (standard.id == item.currentStandardId) return standard.level;
    }
    return null;
  }

  _Standard? _targetStandardByLevel(int level) {
    for (final standard in _targetStandards) {
      if (standard.level == level) return standard;
    }
    return null;
  }

  List<_Standard> _targetClassOptionsForItem(_PreviewItem item) {
    if (item.decision == _Decision.promote) {
      if (item.suggestedNextStandardId == null) return const [];
      return _targetStandards
          .where((s) => s.id == item.suggestedNextStandardId)
          .toList(growable: false);
    }
    if (item.decision == _Decision.repeat) {
      final currentLevel = _sourceLevelForItem(item);
      if (currentLevel == null) return const [];
      final sameLevel = _targetStandardByLevel(currentLevel);
      if (sameLevel == null) return const [];
      return [sameLevel];
    }
    return const [];
  }

  List<_Standard> _bulkTargetClassOptions() {
    final ids = <String>{};
    for (final item in _previewItems) {
      if (!item.selected) continue;
      if (item.decision == _Decision.promote && item.suggestedNextStandardId != null) {
        ids.add(item.suggestedNextStandardId!);
      } else if (item.decision == _Decision.repeat) {
        final level = _sourceLevelForItem(item);
        if (level == null) continue;
        final sameLevel = _targetStandardByLevel(level);
        if (sameLevel != null) ids.add(sameLevel.id);
      }
    }
    return _targetStandards.where((s) => ids.contains(s.id)).toList(growable: false);
  }

  void _applyBulkTargetSelection() {
    if (_bulkTargetStandardId == null) {
      setState(() => _error = 'Select target class first for bulk update.');
      return;
    }
    setState(() {
      for (final item in _previewItems) {
        if (!item.selected) continue;
        if (item.decision != _Decision.promote &&
            item.decision != _Decision.repeat) {
          continue;
        }
        item.targetStandardId = _bulkTargetStandardId;
        item.targetSectionId = _bulkTargetSectionId;
      }
      _error = null;
    });
  }

  Future<void> _runPreview() async {
    if (_sourceYearId == null || _targetYearId == null) {
      setState(
        () => _error = 'Please select both source and target academic years.',
      );
      return;
    }
    if (_sourceYearId == _targetYearId) {
      setState(
        () => _error = 'Source and target academic years must be different.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final items = await _repo.preview(
        sourceYearId: _sourceYearId!,
        targetYearId: _targetYearId!,
        standardId: _filterStandardId,
        sectionId: _filterSectionId,
      );
      await _loadTargetStandards();
      for (final standard in _targetStandards) {
        await _ensureTargetSectionsForStandard(standard.id);
      }
      items.sort((a, b) {
        final byClass = a.currentStandardName.compareTo(b.currentStandardName);
        if (byClass != 0) return byClass;
        final bySection = (a.currentSectionName ?? '').compareTo(
          b.currentSectionName ?? '',
        );
        if (bySection != 0) return bySection;
        return (a.studentName ?? '').compareTo(b.studentName ?? '');
      });
      setState(() => _previewItems = items);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _executePromotion() async {
    final selectedItems = _previewItems.where((e) => e.selected).toList();
    if (selectedItems.isEmpty) {
      setState(
        () =>
            _error = 'Please select at least one student to execute promotion.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Promotion Execution'),
        content: Text(
          'This will create new academic year mappings for ${selectedItems.length} student(s). '
          'Previous year mappings will become permanent read-only records.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Execute', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _executing = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final result = await _repo.execute(
        sourceYearId: _sourceYearId!,
        targetYearId: _targetYearId!,
        items: selectedItems,
      );
      setState(() {
        _successMessage =
            'Promotion complete. '
            'Promoted: ${result['promoted_count'] ?? 0}, '
            'Repeated: ${result['repeated_count'] ?? 0}, '
            'Graduated: ${result['graduated_count'] ?? 0}, '
            'Skipped: ${result['skipped_count'] ?? 0}, '
            'Errors: ${result['error_count'] ?? 0}.';
        _previewItems = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  Future<void> _copyTeacherAssignments() async {
    if (_sourceYearId == null || _targetYearId == null) {
      setState(
        () => _error = 'Please select both source and target years first.',
      );
      return;
    }
    setState(() {
      _copyingAssignments = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final result = await _repo.copyTeacherAssignments(
        sourceYearId: _sourceYearId!,
        targetYearId: _targetYearId!,
      );
      setState(() {
        _successMessage =
            'Teacher assignments copied. '
            'Copied: ${result['copied_count'] ?? 0}, '
            'Skipped (already exist): ${result['skipped_count'] ?? 0}.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _copyingAssignments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isPrincipalOrSuper =
        user != null &&
        (user.role.toUpperCase() == 'PRINCIPAL' ||
            user.role.toUpperCase() == 'SUPERADMIN');

    return AdminScaffold(
      title: 'Promotion Workflow (Phase 7)',
      child: _loading && _previewItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info Banner ──────────────────────────────────────────
                  _InfoBanner(
                    message:
                        'Select a source year and target year. Preview will show all eligible students '
                        'with the system-suggested decision. You can override per student. '
                        'Execution creates new academic mappings — user accounts and admission numbers are NEVER recreated.',
                  ),
                  const SizedBox(height: 16),

                  // ── Year Selection ────────────────────────────────────────
                  _SectionCard(
                    title: 'Step 1 — Select Academic Years',
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Source Year (promoting FROM)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            value: _sourceYearId,
                            items: _years
                                .map(
                                  (y) => DropdownMenuItem<String>(
                                    value: y.id,
                                    child: Text(
                                      y.name + (y.isActive ? ' (Active)' : ''),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) async {
                              setState(() {
                                _sourceYearId = v;
                                _filterStandardId = null;
                                _filterSectionId = null;
                                _previewItems = [];
                                _sourceStandards = [];
                                _sourceSections = [];
                              });
                              await _loadSourceStandards();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Target Year (promoting TO)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            value: _targetYearId,
                            items: _years
                                .map(
                                  (y) => DropdownMenuItem<String>(
                                    value: y.id,
                                    child: Text(
                                      y.name + (y.isActive ? ' (Active)' : ''),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _targetYearId = v;
                                _previewItems = [];
                                _bulkTargetStandardId = null;
                                _bulkTargetSectionId = null;
                                _targetSectionsByStandard.clear();
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Class (optional filter)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            value: _filterStandardId,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Classes'),
                              ),
                              ..._sourceStandards.map(
                                (s) => DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              ),
                            ],
                            onChanged: (v) async {
                              setState(() {
                                _filterStandardId = v;
                                _filterSectionId = null;
                                _previewItems = [];
                                _sourceSections = [];
                              });
                              await _loadSourceSections();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Section (optional filter)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            value: _filterSectionId,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Sections'),
                              ),
                              ..._sourceSections.map(
                                (s) => DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              ),
                            ],
                            onChanged: _filterStandardId == null
                                ? null
                                : (v) => setState(() {
                                    _filterSectionId = v;
                                    _previewItems = [];
                                  }),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: _loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.preview_outlined),
                          label: const Text('Preview Promotion'),
                          onPressed: _loading ? null : _runPreview,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Error / Success ────────────────────────────────────────
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  if (_successMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),

                  // ── Preview Table ──────────────────────────────────────────
                  if (_previewItems.isNotEmpty) ...[
                    _SectionCard(
                      title:
                          'Step 2 — Review & Override Decisions (${_previewItems.length} students)',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bulk action row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => setState(() {
                                  for (final item in _previewItems) {
                                    item.selected = true;
                                  }
                                }),
                                icon: const Icon(Icons.select_all, size: 16),
                                label: const Text('Select All'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => setState(() {
                                  for (final item in _previewItems) {
                                    item.selected = false;
                                  }
                                }),
                                icon: const Icon(Icons.deselect, size: 16),
                                label: const Text('Clear Selection'),
                              ),
                              const Text(
                                'Set all to:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              ..._Decision.values.map(
                                (d) => OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: d.color,
                                    side: BorderSide(color: d.color),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => setState(() {
                                    for (final item in _previewItems) {
                                      item.decision = d;
                                    }
                                  }),
                                  child: Text(d.label),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Bulk target for selected students:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  value: _bulkTargetClassOptions().any(
                                        (s) => s.id == _bulkTargetStandardId,
                                      )
                                      ? _bulkTargetStandardId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Target Class',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                  items: _bulkTargetClassOptions()
                                      .map(
                                        (s) => DropdownMenuItem<String>(
                                          value: s.id,
                                          child: Text(s.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) async {
                                    setState(() {
                                      _bulkTargetStandardId = v;
                                      _bulkTargetSectionId = null;
                                    });
                                    await _ensureTargetSectionsForStandard(v);
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  value: _bulkTargetSectionId,
                                  decoration: const InputDecoration(
                                    labelText: 'Target Section',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Auto / None'),
                                    ),
                                    ..._sectionsForTargetStandard(
                                      _bulkTargetStandardId,
                                    ).map(
                                      (s) => DropdownMenuItem<String>(
                                        value: s.id,
                                        child: Text(s.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: _bulkTargetStandardId == null
                                      ? null
                                      : (v) => setState(
                                          () => _bulkTargetSectionId = v,
                                        ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _applyBulkTargetSelection,
                                icon: const Icon(Icons.done_all),
                                label: const Text('Apply to Selected'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...(() {
                            final classGroups = <String, List<_PreviewItem>>{};
                            for (final item in _previewItems) {
                              classGroups
                                  .putIfAbsent(
                                    item.currentStandardName,
                                    () => [],
                                  )
                                  .add(item);
                            }
                            return classGroups.entries.map((entry) {
                              final className = entry.key;
                              final classItems = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$className (${classItems.length} students)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              Colors.grey.shade100,
                                            ),
                                        columns: const [
                                          DataColumn(label: Text('Select')),
                                          DataColumn(
                                            label: Text('Admission #'),
                                          ),
                                          DataColumn(
                                            label: Text('Student Name'),
                                          ),
                                          DataColumn(
                                            label: Text('Current Class'),
                                          ),
                                          DataColumn(label: Text('Section')),
                                          DataColumn(
                                            label: Text('Promote To Class'),
                                          ),
                                          DataColumn(
                                            label: Text('Promote To Section'),
                                          ),
                                          DataColumn(label: Text('Decision')),
                                          DataColumn(
                                            label: Text('Target Class'),
                                          ),
                                          DataColumn(
                                            label: Text('Target Section'),
                                          ),
                                        ],
                                        rows: classItems.map((item) {
                                          return DataRow(
                                            color: item.hasWarning
                                                ? WidgetStateProperty.all(
                                                    Colors.amber.shade50,
                                                  )
                                                : null,
                                            cells: [
                                              DataCell(
                                                Checkbox(
                                                  value: item.selected,
                                                  onChanged: (v) =>
                                                      setState(() {
                                                        item.selected =
                                                            v ?? false;
                                                      }),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.admissionNumber ?? '-',
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      item.studentName ?? '-',
                                                    ),
                                                    if (item.hasWarning) ...[
                                                      const SizedBox(width: 4),
                                                      Tooltip(
                                                        message:
                                                            item.warningMessage ??
                                                            'Warning',
                                                        child: Icon(
                                                          Icons
                                                              .warning_amber_rounded,
                                                          size: 14,
                                                          color: Colors
                                                              .amber
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Text(item.currentStandardName),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.currentSectionName ??
                                                      '-',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.suggestedNextStandardName ??
                                                      '—',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.suggestedNextSectionName ??
                                                      '—',
                                                ),
                                              ),
                                              DataCell(
                                                DropdownButton<_Decision>(
                                                  value: item.decision,
                                                  underline:
                                                      const SizedBox.shrink(),
                                                  style: TextStyle(
                                                    color: item.decision.color,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                  items: _Decision.values
                                                      .map(
                                                        (d) => DropdownMenuItem(
                                                          value: d,
                                                          child: Text(
                                                            d.label,
                                                            style: TextStyle(
                                                              color: d.color,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (v) {
                                                    if (v != null) {
                                                      setState(() {
                                                        item.decision = v;
                                                        final options =
                                                            _targetClassOptionsForItem(
                                                          item,
                                                        );
                                                        if (options.isEmpty) {
                                                          item.targetStandardId =
                                                              null;
                                                          item.targetSectionId =
                                                              null;
                                                          return;
                                                        }
                                                        final currentTarget =
                                                            item.targetStandardId;
                                                        final stillValid = options
                                                            .any(
                                                              (s) =>
                                                                  s.id ==
                                                                  currentTarget,
                                                            );
                                                        item.targetStandardId =
                                                            stillValid
                                                            ? currentTarget
                                                            : options.first.id;
                                                        item.targetSectionId =
                                                            null;
                                                      });
                                                      _ensureTargetSectionsForStandard(
                                                        item.targetStandardId,
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                              DataCell(
                                                (item.decision ==
                                                            _Decision.promote ||
                                                        item.decision ==
                                                            _Decision.repeat)
                                                    ? DropdownButton<String?>(
                                                        value: _targetClassOptionsForItem(
                                                                  item,
                                                                ).any(
                                                                  (s) =>
                                                                      s.id ==
                                                                      item.targetStandardId,
                                                                )
                                                            ? item.targetStandardId
                                                            : null,
                                                        underline:
                                                            const SizedBox.shrink(),
                                                        hint: const Text(
                                                          'Select',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        items: _targetClassOptionsForItem(item)
                                                            .map(
                                                              (s) =>
                                                                  DropdownMenuItem<
                                                                    String?
                                                                  >(
                                                                    value: s.id,
                                                                    child: Text(
                                                                      s.name,
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                            )
                                                            .toList(),
                                                        onChanged: (v) async {
                                                          setState(() {
                                                            item.targetStandardId =
                                                                v;
                                                            if (v !=
                                                                item.suggestedNextStandardId) {
                                                              item.targetSectionId =
                                                                  null;
                                                            } else {
                                                              item.targetSectionId =
                                                                  item.suggestedNextSectionId;
                                                            }
                                                          });
                                                          await _ensureTargetSectionsForStandard(
                                                            v,
                                                          );
                                                        },
                                                      )
                                                    : const Text('—'),
                                              ),
                                              DataCell(
                                                (item.decision ==
                                                            _Decision.promote ||
                                                        item.decision ==
                                                            _Decision.repeat)
                                                    ? DropdownButton<String?>(
                                                        value: item
                                                            .targetSectionId,
                                                        underline:
                                                            const SizedBox.shrink(),
                                                        hint: const Text(
                                                          'Auto',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        items: [
                                                          const DropdownMenuItem<
                                                            String?
                                                          >(
                                                            value: null,
                                                            child: Text(
                                                              'Auto / None',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                          ..._sectionsForTargetStandard(
                                                            item.targetStandardId,
                                                          ).map(
                                                            (s) =>
                                                                DropdownMenuItem<
                                                                  String?
                                                                >(
                                                                  value: s.id,
                                                                  child: Text(
                                                                    s.name,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                        onChanged:
                                                            item.targetStandardId ==
                                                                null
                                                            ? null
                                                            : (v) => setState(
                                                                () =>
                                                                    item.targetSectionId =
                                                                        v,
                                                              ),
                                                      )
                                                    : const Text('—'),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          })(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Execute ─────────────────────────────────────────────
                    if (isPrincipalOrSuper)
                      _SectionCard(
                        title: 'Step 3 — Execute Promotion',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Review all decisions above before executing. '
                              'This creates new academic mappings in the target year '
                              'and closes the source year mappings as terminal states.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: _executing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle_outline),
                                  label: const Text('Execute Promotion'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _executing
                                      ? null
                                      : _executePromotion,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_previewItems.where((e) => e.selected).length} selected',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],

                  // ── Copy Teacher Assignments (optional) ─────────────────
                  if (_sourceYearId != null &&
                      _targetYearId != null &&
                      isPrincipalOrSuper) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title:
                          'Optional — Copy Teacher Assignments to Target Year',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Copies all teacher-class-subject assignments from the source year to the target year. '
                            'Existing assignments in the target year are skipped (not overwritten). '
                            'Fresh assignments can always be created manually.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: _copyingAssignments
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.copy_all_outlined),
                            label: const Text('Copy Teacher Assignments'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _copyingAssignments
                                ? null
                                : _copyTeacherAssignments,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
