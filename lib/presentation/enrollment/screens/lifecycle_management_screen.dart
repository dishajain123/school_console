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
//   GET  /role-profiles?role={STUDENT|TEACHER|PARENT|PRINCIPAL|TRUSTEE}&search={q}&…
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

import '../../../core/logging/crash_reporter.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../data/models/lifecycle/lifecycle_models.dart';
import '../../../data/repositories/lifecycle_admin_repository.dart';
import '../../../domains/providers/enrollment_provider.dart';
import '../../../domains/providers/lifecycle_management_providers.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class LifecycleManagementScreen extends ConsumerStatefulWidget {
  const LifecycleManagementScreen({super.key});

  @override
  ConsumerState<LifecycleManagementScreen> createState() =>
      _LifecycleManagementScreenState();
}

class _LifecycleManagementScreenState
    extends ConsumerState<LifecycleManagementScreen> {
  late final LifecycleAdminRepository _repo;
  ProviderSubscription<AsyncValue<LifecycleMetaBundle>>? _metaSubscription;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  int _searchRequestSeq = 0;

  List<LifecycleStudentSummary> _searchResults = [];
  LifecycleStudentSummary? _selected;
  List<LifecycleHistoryEntry> _history = [];
  List<LifecycleAcademicYear> _years = [];
  List<LifecycleStandard> _standards = [];
  List<LifecycleSection> _filterSections = [];
  String? _filterYearId;
  String? _filterStandardId;
  String? _filterSectionName;

  /// Role filter for /role-profiles (students vs teachers vs parents, etc.).
  String _profileRole = 'STUDENT';

  bool _searchLoading = false;
  bool _historyLoading = false;
  bool _actionLoading = false;
  String? _error;
  String? _successMsg;

  LifecycleHistoryEntry? _currentActionableMapping() {
    for (final item in _history) {
      if (item.status == 'ACTIVE' || item.status == 'HOLD') return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _repo = LifecycleAdminRepository(ref.read(enrollmentRepositoryProvider));
    _metaSubscription = ref.listenManual(lifecycleMetaProvider, (previous, next) {
      next.when(
        data: (bundle) {
          if (!mounted || _years.isNotEmpty) return;
          setState(() {
            _years = bundle.years;
            _standards = bundle.standards;
            final activeYear = bundle.years
                .where((y) => y.isActive)
                .cast<LifecycleAcademicYear?>()
                .firstWhere(
                  (y) => y != null,
                  orElse: () =>
                      bundle.years.isNotEmpty ? bundle.years.first : null,
                );
            _filterYearId = activeYear?.id;
          });
          _loadFilterSections().then((_) => _search());
        },
        loading: () {},
        error: (_, errorStack) {},
      );
    });
  }

  @override
  void dispose() {
    _metaSubscription?.close();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFilterSections() async {
    final yearId = _filterYearId;
    final standardId = _filterStandardId;
    if (yearId == null || yearId.isEmpty || standardId == null || standardId.isEmpty) {
      if (mounted) {
        setState(() {
          _filterSections = [];
          _filterSectionName = null;
        });
      }
      return;
    }
    try {
      final sections = await _repo.getSections(
        standardId: standardId,
        academicYearId: yearId,
      );
      if (!mounted) return;
      setState(() {
        _filterSections = sections;
        if (_filterSectionName != null &&
            !_filterSections.any((s) => s.name == _filterSectionName)) {
          _filterSectionName = null;
        }
      });
    } catch (e, stack) {
      CrashReporter.log(e, stack);
      if (mounted) {
        setState(() {
          _filterSections = [];
          _filterSectionName = null;
        });
      }
    }
  }

  String? _selectedYearName() {
    final id = _filterYearId;
    if (id == null) return null;
    final year = _years.where((y) => y.id == id).cast<LifecycleAcademicYear?>().firstWhere(
          (y) => y != null,
          orElse: () => null,
        );
    return year?.name;
  }

  String? _selectedStandardName() {
    final id = _filterStandardId;
    if (id == null) return null;
    final standard = _standards.where((s) => s.id == id).cast<LifecycleStandard?>().firstWhere(
          (s) => s != null,
          orElse: () => null,
        );
    return standard?.name;
  }

  List<LifecycleStudentSummary> _filteredSearchResults() {
    final selectedStandardName = _selectedStandardName();
    final q = _searchCtrl.text.trim().toLowerCase();
    return _searchResults.where((s) {
      final matchesQuery = q.isEmpty ||
          (s.fullName ?? '').toLowerCase().contains(q) ||
          (s.admissionNumber ?? '').toLowerCase().contains(q) ||
          (s.email ?? '').toLowerCase().contains(q);
      final yearOk = _filterYearId == null ||
          _filterYearId!.isEmpty ||
          (s.currentAcademicYearId == null || s.currentAcademicYearId!.isEmpty) ||
          (s.currentAcademicYearId ?? '') == _filterYearId;
      final classOk = _filterStandardId == null ||
          _filterStandardId!.isEmpty ||
          (s.currentStandardId == null || s.currentStandardId!.isEmpty) ||
          (s.currentStandardId ?? '') == _filterStandardId ||
          ((selectedStandardName ?? '').isNotEmpty &&
              (s.currentStandardName ?? '').trim().toLowerCase() ==
                  selectedStandardName!.trim().toLowerCase());
      final sectionOk = _filterSectionName == null ||
          _filterSectionName!.isEmpty ||
          (s.currentSectionName == null || s.currentSectionName!.isEmpty) ||
          (s.currentSectionName ?? '').trim().toLowerCase() ==
              _filterSectionName!.trim().toLowerCase();
      return matchesQuery && yearOk && classOk && sectionOk;
    }).toList(growable: false);
  }

  List<LifecycleHistoryEntry> _filteredHistory() {
    final selectedYearName = _selectedYearName();
    final selectedStandardName = _selectedStandardName();
    return _history.where((h) {
      final yearOk = selectedYearName == null ||
          selectedYearName.isEmpty ||
          (h.academicYearName ?? '').trim().toLowerCase() ==
              selectedYearName.trim().toLowerCase();
      final classOk = selectedStandardName == null ||
          selectedStandardName.isEmpty ||
          (h.standardName ?? '').trim().toLowerCase() ==
              selectedStandardName.trim().toLowerCase();
      final sectionOk = _filterSectionName == null ||
          _filterSectionName!.isEmpty ||
          (h.sectionName ?? '').trim().toLowerCase() ==
              _filterSectionName!.trim().toLowerCase();
      return yearOk && classOk && sectionOk;
    }).toList(growable: false);
  }

  void _onSearchChanged(String raw) {
    _searchDebounce?.cancel();
    // Keep UI responsive while typing; filter current in-memory results instantly.
    if (mounted) setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: 280), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    final requestId = ++_searchRequestSeq;
    setState(() {
      _searchLoading = true;
      _error = null;
      _selected = null;
      _history = [];
    });
    try {
      late final List<LifecycleStudentSummary> results;
      final yearId = _filterYearId;
      final standardId = _filterStandardId;
      final sectionName = _filterSectionName;
      final sectionId = (sectionName == null || sectionName.isEmpty)
          ? null
          : _filterSections
              .where((s) => s.name.trim().toLowerCase() == sectionName.trim().toLowerCase())
              .map((s) => s.id)
              .cast<String?>()
              .firstWhere((id) => id != null && id.isNotEmpty, orElse: () => null);

      // Filter-first mode (students only): class+year selected and search empty → roster.
      if (_profileRole == 'STUDENT' &&
          q.isEmpty &&
          yearId != null &&
          yearId.isNotEmpty &&
          standardId != null &&
          standardId.isNotEmpty) {
        results = await _repo.listStudentsByClassFilters(
          standardId: standardId,
          academicYearId: yearId,
          sectionId: sectionId,
        );
      } else {
        results = await _repo.searchRoleProfiles(
          role: _profileRole,
          search: q.isEmpty ? null : q,
          academicYearId: _profileRole == 'STUDENT' ? yearId : null,
          standardId: _profileRole == 'STUDENT' ? standardId : null,
          section: _profileRole == 'STUDENT' ? sectionName : null,
        );
      }
      if (!mounted || requestId != _searchRequestSeq) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted || requestId != _searchRequestSeq) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && requestId == _searchRequestSeq) {
        setState(() => _searchLoading = false);
      }
    }
  }

  Future<void> _selectStudent(LifecycleStudentSummary s) async {
    setState(() {
      _selected = s;
      _searchResults = [];
      _history = [];
      _error = null;
      _successMsg = null;
    });
    if (!s.isEnrollmentLifecycleTarget) {
      if (mounted) setState(() => _historyLoading = false);
      return;
    }
    setState(() => _historyLoading = true);
    try {
      final h = await _repo.getHistory(s.studentId);
      if (mounted) {
        final current = h.where((e) => e.status == 'ACTIVE' || e.status == 'HOLD').cast<LifecycleHistoryEntry?>().firstWhere(
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
    } catch (e, stack) {
      CrashReporter.log(e, stack);
    } finally {
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
    List<LifecycleSection> sections = [];
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
            } catch (e, stack) {
              CrashReporter.log(e, stack);
            } finally {
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
                            orElse: () => _years.isNotEmpty ? _years.first : const LifecycleAcademicYear(id: '', name: '', isActive: false),
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
                              orElse: () => const LifecycleStandard(id: '', name: '', level: 0),
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
    List<LifecycleSection> sections = [];
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
            } catch (e, stack) {
              CrashReporter.log(e, stack);
            } finally {
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
    final theme = Theme.of(context);
    ref.watch(lifecycleMetaProvider);

    return AdminScaffold(
      title: 'Student lifecycle',
      child: _actionLoading
          ? const Padding(
              padding: EdgeInsets.all(AdminSpacing.pagePadding),
              child: AdminLoadingPlaceholder(
                message: 'Applying enrollment change…',
                height: 320,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AdminSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AdminPageHeader(
                    title: 'Student lifecycle',
                    subtitle:
                        'Search a person, view enrollment, transfer, withdraw, '
                        'complete year, or re-enroll. Changes sync to the mobile app.',
                  ),
                  // ── Info banner ──────────────────────────────────────────
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AdminColors.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AdminColors.primaryAction.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AdminSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AdminColors.primaryAction,
                            size: 20,
                          ),
                          const SizedBox(width: AdminSpacing.sm),
                          Expanded(
                            child: Text(
                              'Admin is the single source of truth. All actions here '
                              'are immediately reflected in the mobile app.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AdminColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AdminSpacing.md),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                      child: Material(
                        color: AdminColors.dangerSurface,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(AdminSpacing.md),
                          child: SelectableText(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AdminColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_successMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                      child: Material(
                        color: AdminColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(AdminSpacing.md),
                          child: SelectableText(
                            _successMsg!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AdminColors.success,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Search ───────────────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AdminSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profileRole == 'STUDENT'
                                ? 'Step 1 — Find student'
                                : 'Step 1 — Find person',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: 200,
                                child: DropdownButtonFormField<String>(
                                  value: _profileRole,
                                  decoration: const InputDecoration(
                                    labelText: 'Role',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'STUDENT',
                                      child: Text('Students'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'TEACHER',
                                      child: Text('Teachers'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'PARENT',
                                      child: Text('Parents'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'PRINCIPAL',
                                      child: Text('Principals'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'TRUSTEE',
                                      child: Text('Trustees'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _profileRole = v;
                                      _selected = null;
                                      _history = [];
                                    });
                                    _search();
                                  },
                                ),
                              ),
                              Opacity(
                                opacity: _profileRole == 'STUDENT' ? 1 : 0.45,
                                child: SizedBox(
                                  width: 240,
                                  child: DropdownButtonFormField<String>(
                                    value: _filterYearId,
                                    decoration: const InputDecoration(
                                      labelText: 'Academic Year',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    items: _years
                                        .map(
                                          (y) => DropdownMenuItem<String>(
                                            value: y.id,
                                            child: Text(
                                              '${y.name}${y.isActive ? ' (Active)' : ''}',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _profileRole == 'STUDENT'
                                        ? (v) {
                                            setState(() {
                                              _filterYearId = v;
                                              _filterSectionName = null;
                                            });
                                            _loadFilterSections()
                                                .then((_) => _search());
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: _profileRole == 'STUDENT' ? 1 : 0.45,
                                child: SizedBox(
                                  width: 220,
                                  child: DropdownButtonFormField<String>(
                                    value: _filterStandardId,
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    items: _standards
                                        .map((st) => DropdownMenuItem<String>(
                                              value: st.id,
                                              child: Text(st.name),
                                            ))
                                        .toList(),
                                    onChanged: _profileRole == 'STUDENT'
                                        ? (v) {
                                            setState(() {
                                              _filterStandardId = v;
                                              _filterSectionName = null;
                                            });
                                            _loadFilterSections()
                                                .then((_) => _search());
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: _profileRole == 'STUDENT' ? 1 : 0.45,
                                child: SizedBox(
                                  width: 180,
                                  child: DropdownButtonFormField<String?>(
                                    value: _filterSectionName,
                                    decoration: const InputDecoration(
                                      labelText: 'Section',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('All Sections'),
                                      ),
                                      ..._filterSections.map(
                                        (s) => DropdownMenuItem<String>(
                                          value: s.name,
                                          child: Text(s.name),
                                        ),
                                      ),
                                    ],
                                    onChanged: _profileRole == 'STUDENT'
                                        ? (v) {
                                            setState(() => _filterSectionName = v);
                                            _search();
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _filterStandardId = null;
                                    _filterSectionName = null;
                                    final activeYear = _years
                                        .where((y) => y.isActive)
                                        .cast<LifecycleAcademicYear?>()
                                        .firstWhere(
                                          (y) => y != null,
                                          orElse: () =>
                                              _years.isNotEmpty ? _years.first : null,
                                        );
                                    _filterYearId = activeYear?.id;
                                    _filterSections = [];
                                  });
                                  _search();
                                },
                                icon: const Icon(Icons.filter_alt_off_outlined),
                                label: const Text('Reset Filters'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  decoration: InputDecoration(
                                    hintText: _profileRole == 'STUDENT'
                                        ? 'Type name or admission no. (optional)'
                                        : 'Search name, email, phone, or ID (optional)',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (_) => _search(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AdminColors.textPrimary,
                                  side: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: _searchLoading ? null : _search,
                                child: _searchLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AdminColors.primaryAction,
                                        ),
                                      )
                                    : Icon(
                                        Icons.search,
                                        size: 22,
                                        color: AdminColors.primaryAction,
                                      ),
                              ),
                            ],
                          ),
                          if (_filteredSearchResults().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: _filteredSearchResults().map((s) {
                                  return ListTile(
                                    dense: true,
                                    title: Text(s.fullName ?? '—'),
                                    subtitle: Text(_searchResultSubtitle(s)),
                                    trailing: Text(
                                      _searchResultTrailing(s),
                                      style: TextStyle(
                                        color: s.profileRole == 'STUDENT'
                                            ? _statusColor(s.currentStatus)
                                            : Colors.blueGrey,
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

                  // ── Student lifecycle actions (students with profile only) ─
                  if (_selected != null && _selected!.isEnrollmentLifecycleTarget) ...[
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
                            if (_filteredHistory().isEmpty && !_historyLoading)
                              const Text('No history records found.',
                                  style: TextStyle(color: Colors.grey))
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredHistory().length,
                                separatorBuilder: (_, ignored) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final h = _filteredHistory()[i];
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

                  // ── Non-student or pending student (browse-only) ─────────
                  if (_selected != null &&
                      !_selected!.isEnrollmentLifecycleTarget) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selected!.profileRole == 'STUDENT'
                                  ? 'Student profile pending'
                                  : 'Browse-only (${_selected!.profileRole})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            if (_selected!.profileRole == 'STUDENT')
                              const Text(
                                'This account does not have a student record yet. '
                                'Finish enrollment (student profile) before using transfers, '
                                'withdrawal, or academic history here.',
                                style: TextStyle(fontSize: 13),
                              )
                            else
                              const Text(
                                'Transfer, withdrawal, year completion, and re-enrollment '
                                'apply to enrolled students only. Switch Role to “Students” '
                                'to manage class lifecycle; use this list to look up staff '
                                'and parents by name or ID.',
                                style: TextStyle(fontSize: 13),
                              ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
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
                                  Chip(
                                    label: Text(_selected!.profileRole),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (_selected!.email != null &&
                                      _selected!.email!.isNotEmpty)
                                    Text('Email: ${_selected!.email}'),
                                  if (_selected!.admissionNumber != null &&
                                      _selected!.admissionNumber!.isNotEmpty)
                                    Text(_idLineForSelected(_selected!)),
                                ],
                              ),
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

  String _searchResultSubtitle(LifecycleStudentSummary s) {
    switch (s.profileRole) {
      case 'TEACHER':
        final id = s.admissionNumber ?? '—';
        final em = s.email;
        if (em != null && em.isNotEmpty) return 'Employee ID: $id · $em';
        return 'Employee ID: $id';
      case 'PARENT':
        final code = s.admissionNumber ?? '—';
        final em = s.email;
        if (em != null && em.isNotEmpty) return 'Code: $code · $em';
        return 'Code: $code';
      case 'PRINCIPAL':
      case 'TRUSTEE':
        return s.email ?? '—';
      default:
        return 'Adm: ${s.admissionNumber ?? '—'} | ${s.currentStandardName ?? ''} ${s.currentSectionName ?? ''}'
            .trim();
    }
  }

  String _searchResultTrailing(LifecycleStudentSummary s) {
    if (s.profileRole == 'STUDENT') {
      return s.currentStatus ?? '—';
    }
    return s.profileRole;
  }

  String _idLineForSelected(LifecycleStudentSummary s) {
    switch (s.profileRole) {
      case 'TEACHER':
        return 'Employee ID: ${s.admissionNumber ?? '—'}';
      case 'PARENT':
        return 'Parent code: ${s.admissionNumber ?? '—'}';
      case 'PRINCIPAL':
      case 'TRUSTEE':
        return 'Identifier: ${s.admissionNumber ?? '—'}';
      default:
        return 'Admission: ${s.admissionNumber ?? '—'}';
    }
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
