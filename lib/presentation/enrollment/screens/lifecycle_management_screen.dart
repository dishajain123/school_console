// lib/presentation/enrollment/screens/lifecycle_management_screen.dart  [Admin Console]
// Phase 14/15 — Student Lifecycle Management Screen.
// Single unified screen for all lifecycle actions on a student's enrollment:
//   • Search student by name or admission number
//   • View current active enrollment mapping
//   • Transfer to different section within same class
//   • Transfer to different class (mid-year class change)
//   • Withdraw (LEFT / TRANSFERRED to another school)
//   • Mark year COMPLETED (eligible for promotion)
//   • Re-enroll (for readmissions or SKIP decisions)
//   • View full academic history
//
// Admin is the SINGLE SOURCE OF TRUTH. Mobile app reflects changes automatically.
//
// APIs used:
//   GET  /role-profiles?role=STUDENT&search={q}
//   GET  /enrollments/history/{studentId}
//   POST /enrollments/mappings/{id}/transfer
//   POST /enrollments/mappings/{id}/exit
//   POST /enrollments/mappings/{id}/complete
//   POST /promotions/reenroll/{studentId}
//   GET  /masters/standards
//   GET  /masters/sections
//   GET  /academic-years

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/enrollment_provider.dart';
import '../../../data/repositories/enrollment_repository.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Local models ──────────────────────────────────────────────────────────────

class _StudentSummary {
  const _StudentSummary({
    required this.studentId,
    required this.userId,
    required this.fullName,
    required this.admissionNumber,
    required this.currentStandardName,
    required this.currentSectionName,
    required this.currentStatus,
    required this.currentMappingId,
    required this.currentAcademicYearId,
    required this.currentStandardId,
  });

  final String studentId;
  final String userId;
  final String? fullName;
  final String? admissionNumber;
  final String? currentStandardName;
  final String? currentSectionName;
  final String? currentStatus;
  final String? currentMappingId;
  final String? currentAcademicYearId;
  final String? currentStandardId;

  factory _StudentSummary.fromJson(Map<String, dynamic> j) {
    return _StudentSummary(
      studentId: j['student_id']?.toString() ?? j['id']?.toString() ?? '',
      userId: j['user_id']?.toString() ?? '',
      fullName: j['full_name'] as String?,
      admissionNumber: j['admission_number'] as String?,
      currentStandardName: j['standard_name'] as String?,
      currentSectionName: j['section'] as String?,
      currentStatus: j['enrollment_status'] as String?,
      currentMappingId: j['mapping_id'] as String?,
      currentAcademicYearId: j['academic_year_id'] as String?,
      currentStandardId: j['standard_id'] as String?,
    );
  }

  _StudentSummary copyWith({
    String? currentStandardName,
    String? currentSectionName,
    String? currentStatus,
    String? currentMappingId,
    String? currentAcademicYearId,
    String? currentStandardId,
  }) {
    return _StudentSummary(
      studentId: studentId,
      userId: userId,
      fullName: fullName,
      admissionNumber: admissionNumber,
      currentStandardName: currentStandardName ?? this.currentStandardName,
      currentSectionName: currentSectionName ?? this.currentSectionName,
      currentStatus: currentStatus ?? this.currentStatus,
      currentMappingId: currentMappingId ?? this.currentMappingId,
      currentAcademicYearId: currentAcademicYearId ?? this.currentAcademicYearId,
      currentStandardId: currentStandardId ?? this.currentStandardId,
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.id,
    required this.academicYearName,
    required this.standardName,
    required this.sectionName,
    required this.rollNumber,
    required this.status,
    required this.admissionType,
    required this.joinedOn,
    this.leftOn,
    this.exitReason,
  });

  final String id;
  final String? academicYearName;
  final String? standardName;
  final String? sectionName;
  final String? rollNumber;
  final String status;
  final String? admissionType;
  final String? joinedOn;
  final String? leftOn;
  final String? exitReason;

  factory _HistoryEntry.fromJson(Map<String, dynamic> j) => _HistoryEntry(
        id: j['id']?.toString() ?? '',
        academicYearName: j['academic_year_name'] as String?,
        standardName: j['standard_name'] as String?,
        sectionName: j['section_name'] as String?,
        rollNumber: j['roll_number'] as String?,
        status: j['status']?.toString() ?? 'UNKNOWN',
        admissionType: j['admission_type'] as String?,
        joinedOn: j['joined_on'] as String?,
        leftOn: j['left_on'] as String?,
        exitReason: j['exit_reason'] as String?,
      );
}

class _AcademicYear {
  const _AcademicYear({required this.id, required this.name, required this.isActive});
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

// ── Repository ────────────────────────────────────────────────────────────────

class _LifecycleRepository {
  _LifecycleRepository(this._api);
  final EnrollmentRepository _api;

  Future<List<_StudentSummary>> searchStudents(
    String query,
  ) async {
    final items = await _api.searchStudents(query);
    return items
        .map((e) => _StudentSummary.fromJson(e))
        .toList();
  }

  Future<List<_HistoryEntry>> getHistory(String studentId) async {
    final data = await _api.getStudentHistory(studentId);
    final history = (data['history'] as List?) ?? [];
    return history
        .map((e) => _HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> transferStudent({
    required String mappingId,
    required String newStandardId,
    String? newSectionId,
    String? newRollNumber,
    required String transferReason,
    String? effectiveDate,
  }) async {
    await _api.transferStudent(
      mappingId: mappingId,
      newStandardId: newStandardId,
      newSectionId: newSectionId,
      newRollNumber: newRollNumber,
      transferReason: transferReason,
      effectiveDate: effectiveDate,
    );
  }

  Future<void> exitStudent({
    required String mappingId,
    required String status,
    required String leftOn,
    required String exitReason,
  }) async {
    await _api.exitStudent(
      mappingId: mappingId,
      status: status,
      leftOn: leftOn,
      exitReason: exitReason,
    );
  }

  Future<void> completeMapping(String mappingId) async {
    await _api.completeMapping(mappingId);
  }

  Future<void> reenrollStudent({
    required String studentId,
    required String targetYearId,
    required String standardId,
    String? sectionId,
    String? rollNumber,
    String admissionType = 'READMISSION',
  }) async {
    await _api.reenrollStudent(
      studentId: studentId,
      targetYearId: targetYearId,
      standardId: standardId,
      sectionId: sectionId,
      rollNumber: rollNumber,
      admissionType: admissionType,
    );
  }

  Future<List<_AcademicYear>> getAcademicYears() async {
    final items = await _api.listAcademicYears();
    return items.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _AcademicYear(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        isActive: m['is_active'] == true,
      );
    }).toList();
  }

  Future<List<_Standard>> getStandards() async {
    final items = await _api.listStandards();
    return items.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _Standard(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        level: (m['level'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<_Section>> getSections({
    required String standardId,
    required String academicYearId,
  }) async {
    final items = await _api.listSections(
      standardId: standardId,
      academicYearId: academicYearId,
    );
    return items.map((e) {
      final m = e;
      return _Section(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
      );
    }).toList();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LifecycleManagementScreen extends ConsumerStatefulWidget {
  const LifecycleManagementScreen({super.key});

  @override
  ConsumerState<LifecycleManagementScreen> createState() =>
      _LifecycleManagementScreenState();
}

class _LifecycleManagementScreenState
    extends ConsumerState<LifecycleManagementScreen> {
  late final _LifecycleRepository _repo;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<_StudentSummary> _searchResults = [];
  _StudentSummary? _selected;
  List<_HistoryEntry> _history = [];
  List<_AcademicYear> _years = [];
  List<_Standard> _standards = [];

  bool _searchLoading = false;
  bool _historyLoading = false;
  bool _actionLoading = false;
  String? _error;
  String? _successMsg;

  _HistoryEntry? _currentActionableMapping() {
    for (final item in _history) {
      if (item.status == 'ACTIVE' || item.status == 'HOLD') return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _repo = _LifecycleRepository(ref.read(enrollmentRepositoryProvider));
    _loadMeta();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    try {
      final results = await Future.wait([
        _repo.getAcademicYears(),
        _repo.getStandards(),
      ]);
      if (mounted) {
        setState(() {
          _years = results[0] as List<_AcademicYear>;
          _standards = results[1] as List<_Standard>;
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String raw) {
    _searchDebounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 280), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    setState(() {
      _searchLoading = true;
      _error = null;
      _selected = null;
      _history = [];
    });
    try {
      final results = await _repo.searchStudents(q);
      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _selectStudent(_StudentSummary s) async {
    setState(() {
      _selected = s;
      _searchResults = [];
      _historyLoading = true;
      _history = [];
      _error = null;
      _successMsg = null;
    });
    try {
      final h = await _repo.getHistory(s.studentId);
      if (mounted) {
        final current = h.where((e) => e.status == 'ACTIVE' || e.status == 'HOLD').cast<_HistoryEntry?>().firstWhere(
              (e) => e != null,
              orElse: () => h.isNotEmpty ? h.first : null,
            );
        setState(() {
          _history = h;
          if (current != null) {
            _selected = s.copyWith(
              currentStandardName: current.standardName,
              currentSectionName: current.sectionName,
              currentStatus: current.status,
              currentMappingId: current.id,
              currentAcademicYearId: null,
              currentStandardId: null,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _refreshHistory() async {
    if (_selected == null) return;
    setState(() => _historyLoading = true);
    try {
      final h = await _repo.getHistory(_selected!.studentId);
      if (mounted) {
        setState(() {
          _history = h;
          final current = _currentActionableMapping();
          if (current != null && _selected != null) {
            _selected = _selected!.copyWith(
              currentStandardName: current.standardName,
              currentSectionName: current.sectionName,
              currentStatus: current.status,
              currentMappingId: current.id,
            );
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  // ── Action: Section / Class Transfer ─────────────────────────────────────

  void _showTransferDialog() {
    final s = _selected;
    final current = _currentActionableMapping();
    if (s == null || current == null) return;

    String? targetStandardId;
    String? targetSectionId;
    List<_Section> sections = [];
    bool loadingSections = false;
    final reasonCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> loadSections(String stdId, String yearId) async {
            setDlgState(() => loadingSections = true);
            try {
              final secs = await _repo.getSections(
                standardId: stdId,
                academicYearId: yearId,
              );
              setDlgState(() => sections = secs);
            } catch (_) {} finally {
              setDlgState(() => loadingSections = false);
            }
          }

          return AlertDialog(
            title: const Text('Transfer Student'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current: ${current.standardName ?? ''} ${current.sectionName ?? ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    const Text('Target Class',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: targetStandardId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _standards
                          .map((st) => DropdownMenuItem<String>(
                                value: st.id,
                                child: Text(st.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDlgState(() {
                            targetStandardId = v;
                            targetSectionId = null;
                            sections = [];
                          });
                          final activeYear = _years.firstWhere(
                            (y) => y.isActive,
                            orElse: () => _years.isNotEmpty ? _years.first : const _AcademicYear(id: '', name: '', isActive: false),
                          );
                          if (activeYear.id.isNotEmpty) loadSections(v, activeYear.id);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Target Section (optional)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    loadingSections
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String?>(
                            value: targetSectionId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            hint: const Text('No section change'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('— No section —'),
                              ),
                              ...sections.map(
                                (sec) => DropdownMenuItem<String?>(
                                  value: sec.id,
                                  child: Text(sec.name),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setDlgState(() => targetSectionId = v),
                          ),
                    const SizedBox(height: 12),
                    const Text('Reason *',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Reason for transfer',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  reasonCtrl.dispose();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (targetStandardId == null) return;
                  if (reasonCtrl.text.trim().length < 3) return;
                  Navigator.of(ctx).pop();
                  reasonCtrl.dispose();
                  setState(() {
                    _actionLoading = true;
                    _error = null;
                    _successMsg = null;
                  });
                  try {
                    await _repo.transferStudent(
                      mappingId: current.id,
                      newStandardId: targetStandardId!,
                      newSectionId: targetSectionId,
                      transferReason: reasonCtrl.text.trim(),
                    );
                    final isClassChange =
                        targetStandardId != null &&
                        (current.standardName ?? '') !=
                            (_standards.firstWhere(
                              (st) => st.id == targetStandardId,
                              orElse: () => const _Standard(id: '', name: '', level: 0),
                            ).name);
                    if (mounted) {
                      setState(() => _successMsg = isClassChange
                          ? 'Student class transfer completed.'
                          : 'Student section transfer completed.');
                    }
                    await _refreshHistory();
                  } catch (e) {
                    if (mounted) setState(() => _error = e.toString());
                  } finally {
                    if (mounted) setState(() => _actionLoading = false);
                  }
                },
                child: const Text('Transfer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Action: Withdraw ──────────────────────────────────────────────────────

  void _showWithdrawDialog() {
    final s = _selected;
    final current = _currentActionableMapping();
    if (s == null || current == null) return;

    String exitStatus = 'LEFT';
    DateTime exitDate = DateTime.now();
    final reasonCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Withdraw / Exit Student'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exit Type',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: exitStatus,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LEFT', child: Text('Left (Withdrawal)')),
                    DropdownMenuItem(
                        value: 'TRANSFERRED',
                        child: Text('Transferred to another school')),
                  ],
                  onChanged: (v) =>
                      setDlgState(() => exitStatus = v ?? 'LEFT'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    'Exit Date: ${exitDate.year}-${exitDate.month.toString().padLeft(2, '0')}-${exitDate.day.toString().padLeft(2, '0')}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: exitDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDlgState(() => exitDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text('Reason *',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Reason for withdrawal',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                reasonCtrl.dispose();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (reasonCtrl.text.trim().length < 3) return;
                Navigator.of(ctx).pop();
                final leftOnStr =
                    '${exitDate.year}-${exitDate.month.toString().padLeft(2, '0')}-${exitDate.day.toString().padLeft(2, '0')}';
                final reason = reasonCtrl.text.trim();
                reasonCtrl.dispose();
                setState(() {
                  _actionLoading = true;
                  _error = null;
                  _successMsg = null;
                });
                try {
                  await _repo.exitStudent(
                    mappingId: current.id,
                    status: exitStatus,
                    leftOn: leftOnStr,
                    exitReason: reason,
                  );
                  if (mounted) {
                    setState(() => _successMsg =
                        'Student marked as $exitStatus. Record preserved.');
                  }
                  await _refreshHistory();
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                } finally {
                  if (mounted) setState(() => _actionLoading = false);
                }
              },
              child: const Text('Confirm Withdrawal'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action: Mark Completed ────────────────────────────────────────────────

  Future<void> _markCompleted() async {
    final s = _selected;
    final current = _currentActionableMapping();
    if (s == null || current == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Year as Completed'),
        content: Text(
          'Mark ${s.fullName ?? 'this student'}\'s current year as COMPLETED?\n\n'
          'This makes them eligible for the promotion workflow.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Mark Complete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _actionLoading = true;
      _error = null;
      _successMsg = null;
    });
    try {
      await _repo.completeMapping(current.id);
      if (mounted) {
        setState(() =>
            _successMsg = 'Marked COMPLETED. Student is eligible for promotion.');
      }
      await _refreshHistory();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Action: Re-enroll ────────────────────────────────────────────────────

  void _showReenrollDialog() {
    final s = _selected;
    if (s == null) return;

    String? targetYearId;
    String? targetStandardId;
    String? targetSectionId;
    List<_Section> sections = [];
    bool loadingSections = false;
    String admissionType = 'READMISSION';
    final rollCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> loadSections(String stdId, String yearId) async {
            setDlgState(() => loadingSections = true);
            try {
              final secs = await _repo.getSections(
                standardId: stdId,
                academicYearId: yearId,
              );
              setDlgState(() => sections = secs);
            } catch (_) {} finally {
              setDlgState(() => loadingSections = false);
            }
          }

          return AlertDialog(
            title: const Text('Re-enroll Student'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target Academic Year *',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: targetYearId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      hint: const Text('Select year'),
                      items: _years
                          .map((y) => DropdownMenuItem<String>(
                                value: y.id,
                                child: Text(
                                    '${y.name}${y.isActive ? ' (Active)' : ''}'),
                              ))
                          .toList(),
                      onChanged: (v) => setDlgState(() {
                        targetYearId = v;
                        targetSectionId = null;
                        sections = [];
                        if (v != null && targetStandardId != null) {
                          loadSections(targetStandardId!, v);
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    const Text('Target Class *',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: targetStandardId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      hint: const Text('Select class'),
                      items: _standards
                          .map((st) => DropdownMenuItem<String>(
                                value: st.id,
                                child: Text(st.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDlgState(() {
                          targetStandardId = v;
                          targetSectionId = null;
                          sections = [];
                        });
                        if (v != null && targetYearId != null) {
                          loadSections(v, targetYearId!);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Section (optional)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    loadingSections
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String?>(
                            value: targetSectionId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            hint: const Text('No section'),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('— No section —')),
                              ...sections.map(
                                (sec) => DropdownMenuItem<String?>(
                                  value: sec.id,
                                  child: Text(sec.name),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setDlgState(() => targetSectionId = v),
                          ),
                    const SizedBox(height: 12),
                    const Text('Admission Type',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: admissionType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'READMISSION', child: Text('Re-admission')),
                        DropdownMenuItem(
                            value: 'MID_YEAR', child: Text('Mid-Year Join')),
                        DropdownMenuItem(
                            value: 'TRANSFER_IN',
                            child: Text('Transfer In from another school')),
                        DropdownMenuItem(
                            value: 'NEW_ADMISSION',
                            child: Text('New Admission')),
                      ],
                      onChanged: (v) =>
                          setDlgState(() => admissionType = v ?? 'READMISSION'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rollCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Roll Number (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  rollCtrl.dispose();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (targetYearId == null || targetStandardId == null) return;
                  final roll = rollCtrl.text.trim();
                  rollCtrl.dispose();
                  Navigator.of(ctx).pop();
                  setState(() {
                    _actionLoading = true;
                    _error = null;
                    _successMsg = null;
                  });
                  try {
                    await _repo.reenrollStudent(
                      studentId: s.studentId,
                      targetYearId: targetYearId!,
                      standardId: targetStandardId!,
                      sectionId: targetSectionId,
                      rollNumber: roll.isNotEmpty ? roll : null,
                      admissionType: admissionType,
                    );
                    if (mounted) {
                      setState(() =>
                          _successMsg = 'Student re-enrolled successfully.');
                    }
                    await _refreshHistory();
                  } catch (e) {
                    if (mounted) setState(() => _error = e.toString());
                  } finally {
                    if (mounted) setState(() => _actionLoading = false);
                  }
                },
                child: const Text('Re-enroll'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Student Lifecycle Management',
      child: _actionLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info banner ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin is the single source of truth. All actions here '
                            'are immediately reflected in the mobile app.',
                            style: TextStyle(fontSize: 13, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!,
                          style:
                              TextStyle(color: Colors.red.shade700)),
                    ),

                  if (_successMsg != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(_successMsg!,
                          style: TextStyle(color: Colors.green.shade700)),
                    ),

                  // ── Search ───────────────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Step 1 — Find Student',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Search by name or admission number...',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.search),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (_) => _search(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _searchLoading ? null : _search,
                                child: _searchLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Search'),
                              ),
                            ],
                          ),
                          if (_searchResults.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: _searchResults.map((s) {
                                  return ListTile(
                                    dense: true,
                                    title: Text(s.fullName ?? '—'),
                                    subtitle: Text(
                                        'Adm: ${s.admissionNumber ?? '—'} | ${s.currentStandardName ?? ''} ${s.currentSectionName ?? ''}'),
                                    trailing: Text(
                                      s.currentStatus ?? '—',
                                      style: TextStyle(
                                        color: _statusColor(s.currentStatus),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onTap: () => _selectStudent(s),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Student actions ──────────────────────────────────────
                  if (_selected != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Step 2 — Lifecycle Actions',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            // Student summary
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selected!.fullName ?? '—',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Admission No: ${_selected!.admissionNumber ?? '—'}'),
                                  Text(
                                      'Class: ${_selected!.currentStandardName ?? '—'} '
                                      '${_selected!.currentSectionName ?? ''}'),
                                  const SizedBox(height: 4),
                                  Chip(
                                    label: Text(
                                        _selected!.currentStatus ?? 'NO ACTIVE ENROLLMENT'),
                                    backgroundColor: _statusColor(
                                            _selected!.currentStatus)
                                        .withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                      color: _statusColor(
                                          _selected!.currentStatus),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Action buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ActionButton(
                                  icon: Icons.swap_horiz,
                                  label: 'Transfer Section/Class',
                                  color: Colors.blue,
                                  enabled: _selected!.currentMappingId != null &&
                                      (_selected!.currentStatus == 'ACTIVE' ||
                                          _selected!.currentStatus == 'HOLD'),
                                  onPressed: _showTransferDialog,
                                ),
                                _ActionButton(
                                  icon: Icons.exit_to_app,
                                  label: 'Withdraw / Exit',
                                  color: Colors.red,
                                  enabled: _selected!.currentMappingId != null &&
                                      (_selected!.currentStatus == 'ACTIVE' ||
                                          _selected!.currentStatus == 'HOLD'),
                                  onPressed: _showWithdrawDialog,
                                ),
                                _ActionButton(
                                  icon: Icons.check_circle_outline,
                                  label: 'Mark Year Complete',
                                  color: Colors.green,
                                  enabled: _selected!.currentMappingId != null &&
                                      _selected!.currentStatus == 'ACTIVE',
                                  onPressed: _markCompleted,
                                ),
                                _ActionButton(
                                  icon: Icons.person_add_alt_1,
                                  label: 'Re-enroll',
                                  color: Colors.purple,
                                  enabled: true,
                                  onPressed: _showReenrollDialog,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Academic History ─────────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Academic History',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                if (_historyLoading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_history.isEmpty && !_historyLoading)
                              const Text('No history records found.',
                                  style: TextStyle(color: Colors.grey))
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _history.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final h = _history[i];
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _statusColor(h.status)
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        (i + 1).toString(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _statusColor(h.status),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      '${h.academicYearName ?? '—'} — ${h.standardName ?? '—'} ${h.sectionName ?? ''}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (h.rollNumber != null)
                                          Text('Roll: ${h.rollNumber}',
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                        if (h.admissionType != null)
                                          Text(
                                              'Type: ${_formatAdmissionType(h.admissionType!)}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54)),
                                        if (h.joinedOn != null)
                                          Text('Joined: ${h.joinedOn}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54)),
                                        if (h.leftOn != null)
                                          Text('Left: ${h.leftOn}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.red)),
                                        if (h.exitReason != null)
                                          Text('Reason: ${h.exitReason}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black45)),
                                      ],
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        h.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _statusColor(h.status),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: _statusColor(h.status)
                                          .withValues(alpha: 0.1),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'HOLD':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      case 'PROMOTED':
        return Colors.indigo;
      case 'REPEATED':
        return Colors.amber.shade700;
      case 'GRADUATED':
        return Colors.teal;
      case 'LEFT':
        return Colors.red;
      case 'TRANSFERRED':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _formatAdmissionType(String t) {
    switch (t.toUpperCase()) {
      case 'NEW_ADMISSION':
        return 'New Admission';
      case 'MID_YEAR':
        return 'Mid-Year';
      case 'TRANSFER_IN':
        return 'Transfer In';
      case 'READMISSION':
        return 'Re-admission';
      default:
        return t;
    }
  }
}

// ── Action Button widget ───────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        foregroundColor: enabled ? Colors.white : Colors.grey,
        backgroundColor: enabled ? color : Colors.grey.shade200,
        disabledForegroundColor: Colors.grey,
        disabledBackgroundColor: Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: enabled ? onPressed : null,
    );
  }
}
