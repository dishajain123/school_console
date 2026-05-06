// lib/presentation/enrollment/screens/enrollment_screen.dart  [Admin Console]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../../core/constants/route_constants.dart';
import '../../../core/logging/crash_reporter.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/enrollment_provider.dart';
import '../../../domains/providers/enrollment_screen_providers.dart';
import '../../../data/repositories/enrollment_repository.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class EnrollmentScreen extends ConsumerStatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  ConsumerState<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends ConsumerState<EnrollmentScreen> {
  EnrollmentRepository get _repo =>
      ref.read(enrollmentRepositoryProvider);

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _onboardingRaw = [];
  List<Map<String, dynamic>> _onboarding = [];

  String? _selectedYearId;

  bool _loading = false;
  String? _error;
  String? _onboardingRole;
  String _onboardingStatus = 'PENDING';
  String _onboardingSearch = '';
  final TextEditingController _onboardingSearchCtrl = TextEditingController();
  Timer? _queueAutoRefresh;
  int _queueRequestVersion = 0;
  final Set<String> _selectedOnboardingUserIds = <String>{};
  static const int _rowsPerPage = 100;
  int _currentPage = 0;
  final ScrollController _verticalTableScrollController = ScrollController();
  final ScrollController _horizontalTableScrollController = ScrollController();
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadYears();
      _queueAutoRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_selectedYearId != null && _selectedYearId!.trim().isNotEmpty) {
          _loadOnboardingQueue(silent: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _queueAutoRefresh?.cancel();
    _verticalTableScrollController.dispose();
    _horizontalTableScrollController.dispose();
    _onboardingSearchCtrl.dispose();
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  bool _isValidUuid(String? value) {
    if (value == null) return false;
    final v = value.trim();
    if (v.isEmpty) return false;
    return _uuidRegex.hasMatch(v);
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) return msg;
        final detail = data['detail']?.toString();
        if (detail != null && detail.trim().isNotEmpty) return detail;
        final err = data['error'];
        if (err is Map) {
          final d = err['details']?.toString();
          if (d != null && d.trim().isNotEmpty) return d;
        }
      }
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }

  List<String> _requestedAdmissions(Map<String, dynamic> user) {
    final values = <String>[];
    final first = user['requested_student_admission_number']?.toString().trim();
    if (first != null && first.isNotEmpty) {
      values.add(first);
    }
    final list = user['requested_child_admission_numbers'];
    if (list is List) {
      values.addAll(
        list
            .map((e) => e.toString().trim())
            .where((v) => v.isNotEmpty)
            .toList(),
      );
    }
    // Backward compatibility with older queue payloads.
    final fallback = user['suggested_identifier']?.toString().trim();
    if (values.isEmpty && fallback != null && fallback.isNotEmpty) {
      values.add(fallback);
    }
    final deduped = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final key = value.toUpperCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      deduped.add(value);
    }
    return deduped;
  }

  Future<int> _autoLinkParentByAdmissions({
    required String parentId,
    required List<String> admissions,
  }) async {
    if (admissions.isEmpty) return 0;
    final existingIds = await _repo.getParentChildIds(parentId);
    final selected = <String>{...existingIds};

    for (final admission in admissions) {
      final matches = await _repo.listStudentProfiles(
        search: admission,
        pageSize: 100,
      );
      for (final row in matches) {
        final sid = (row['student_id'] ?? '').toString().trim();
        final adm = (row['admission_number'] ?? row['identifier'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        final isEnrolled = row['enrollment_completed'] == true;
        if (sid.isEmpty || !isEnrolled) continue;
        if (adm == admission.toUpperCase()) {
          selected.add(sid);
        }
      }
    }
    if (selected.isEmpty) return 0;
    await _repo.assignParentChildren(
      parentId: parentId,
      studentIds: selected.toList(),
    );
    return selected.length;
  }

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() => _loading = true);
    try {
      ref.invalidate(schoolEnrollmentYearsProvider);
      final years = await ref.read(schoolEnrollmentYearsProvider.future);
      final active = years.firstWhere(
        (y) => y['is_active'] == true,
        orElse: () => years.isNotEmpty ? years.first : {},
      );
      setState(() {
        _years = years;
        _selectedYearId = active['id']?.toString();
        _onboardingSearch = '';
        _onboardingSearchCtrl.text = '';
      });
      await _loadOnboardingQueue(silent: true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadOnboardingQueue({bool silent = false}) async {
    if (_selectedYearId == null || _selectedYearId!.trim().isEmpty) {
      if (!silent && mounted) {
        setState(() {
          _onboardingRaw = const [];
          _onboarding = const [];
        });
      }
      return;
    }
    final requestVersion = ++_queueRequestVersion;
    if (!silent) setState(() => _loading = true);
    try {
      ref.invalidate(
        onboardingQueueProvider(
          OnboardingQueueKey(
            academicYearId: _selectedYearId!,
            role: _onboardingRole,
          ),
        ),
      );
      final items = await ref.read(
        onboardingQueueProvider(
          OnboardingQueueKey(
            academicYearId: _selectedYearId!,
            role: _onboardingRole,
          ),
        ).future,
      );
      if (!mounted || requestVersion != _queueRequestVersion) return;
      setState(() {
        _onboardingRaw = items;
        _onboarding = _applyOnboardingFilters(_onboardingRaw);
        _currentPage = 0;
        _selectedOnboardingUserIds.clear();
      });
    } catch (e) {
      if (!mounted || requestVersion != _queueRequestVersion) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && requestVersion == _queueRequestVersion && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _applyOnboardingFilters(
    List<Map<String, dynamic>> input,
  ) {
    final enrollable = input
        .where((u) {
          final role = (u['role'] ?? '').toString().trim().toUpperCase();
          return role == 'STUDENT' ||
              role == 'TEACHER' ||
              role == 'PARENT' ||
              role == 'PRINCIPAL' ||
              role == 'TRUSTEE';
        })
        .toList(growable: false);

    final statusFiltered = _onboardingStatus == 'ENROLLED'
        ? enrollable
              .where((u) => u['enrollment_completed'] == true)
              .toList(growable: false)
        : _onboardingStatus == 'ALL'
        ? enrollable
        : enrollable
              .where((u) => u['enrollment_pending'] == true)
              .toList(growable: false);

    final q = _onboardingSearch.trim().toLowerCase();
    if (q.isEmpty) return statusFiltered;
    return statusFiltered
        .where((u) {
          final role = (u['role'] ?? '').toString().toLowerCase();
          final name = (u['full_name'] ?? '').toString().toLowerCase();
          final email = (u['email'] ?? '').toString().toLowerCase();
          final phone = (u['phone'] ?? '').toString().toLowerCase();
          final identifier = _rowIdentifierText(u).toLowerCase();
          final reason = (u['pending_reason'] ?? '').toString().toLowerCase();
          return role.contains(q) ||
              name.contains(q) ||
              email.contains(q) ||
              phone.contains(q) ||
              identifier.contains(q) ||
              reason.contains(q);
        })
        .toList(growable: false);
  }

  void _recomputeOnboardingView() {
    setState(() {
      _onboarding = _applyOnboardingFilters(_onboardingRaw);
      _currentPage = 0;
      _selectedOnboardingUserIds.clear();
    });
  }

  void _toggleOnboardingUserSelection(String userId, bool selected) {
    setState(() {
      if (selected) {
        _selectedOnboardingUserIds.add(userId);
      } else {
        _selectedOnboardingUserIds.remove(userId);
      }
    });
  }

  void _toggleSelectAllOnPage(List<Map<String, dynamic>> pageRows, bool selected) {
    setState(() {
      for (final row in pageRows) {
        final userId = (row['user_id'] ?? '').toString().trim();
        if (userId.isEmpty) continue;
        if (selected) {
          _selectedOnboardingUserIds.add(userId);
        } else {
          _selectedOnboardingUserIds.remove(userId);
        }
      }
    });
  }

  void _setPage(int page, int totalPages) {
    final safePage = page.clamp(0, totalPages - 1).toInt();
    if (_currentPage == safePage) return;
    setState(() => _currentPage = safePage);
  }

  String _rowIdentifierText(Map<String, dynamic> u) {
    final parentAdmissions = _requestedAdmissions(u).join(', ');
    if (u['role']?.toString() == 'PARENT' && parentAdmissions.isNotEmpty) {
      return parentAdmissions;
    }
    return u['suggested_identifier']?.toString() ?? '-';
  }

  String _rowContactText(Map<String, dynamic> u) {
    final email = u['email']?.toString() ?? '';
    if (email.isNotEmpty) return email;
    return u['phone']?.toString() ?? '-';
  }

  String _onboardingRowToClipboardText(Map<String, dynamic> u) {
    return [
      u['role']?.toString() ?? '-',
      u['full_name']?.toString() ?? '-',
      _rowIdentifierText(u),
      _rowContactText(u),
      (u['profile_created'] == true) ? 'Done' : 'Pending',
      (u['reenrollment_completed'] == true) ? 'Done' : 'Pending',
      (u['enrollment_completed'] == true) ? 'Done' : 'Pending',
      u['pending_reason']?.toString() ?? '-',
    ].join('\t');
  }

  Future<void> _copyOnboardingRow(Map<String, dynamic> u) async {
    await Clipboard.setData(
      ClipboardData(text: _onboardingRowToClipboardText(u)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Row copied to clipboard')));
  }

  Future<void> _copyOnboardingTable() async {
    const header =
        'Role\tName\tIdentifier\tContact\tProfile\tRe-enroll\tEnrollment\tPending Reason';
    final lines = <String>[
      header,
      ..._onboarding.map(_onboardingRowToClipboardText),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Onboarding table copied to clipboard')),
    );
  }

  Future<void> _reenrollQueueUser(Map<String, dynamic> user) async {
    final userId = (user['user_id'] ?? '').toString();
    if (userId.isEmpty) {
      setState(() => _error = 'Cannot re-enroll: missing user id.');
      return;
    }
    if (_selectedYearId == null || _selectedYearId!.isEmpty) {
      setState(() => _error = 'Select an academic year first.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-enroll User'),
        content: Text(
          'Mark ${user['full_name'] ?? 'this user'} for academic year re-enrollment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Re-enroll'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.annualReenrollUser(
        userId: userId,
        academicYearId: _selectedYearId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Year re-enrollment updated for user.')),
      );
      await _loadOnboardingQueue();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _reenrollSelectedUsers() async {
    if (_selectedYearId == null || _selectedYearId!.isEmpty) {
      setState(() => _error = 'Select an academic year first.');
      return;
    }
    final selectedRows = _onboarding
        .where((u) => _selectedOnboardingUserIds.contains((u['user_id'] ?? '').toString()))
        .toList(growable: false);
    if (selectedRows.isEmpty) {
      setState(() => _error = 'Select at least one user for bulk re-enrollment.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Re-enroll'),
        content: Text(
          'Re-enroll ${selectedRows.length} selected users for the chosen academic year?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Re-enroll All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    var successCount = 0;
    for (final user in selectedRows) {
      final userId = (user['user_id'] ?? '').toString().trim();
      if (userId.isEmpty) continue;
      try {
        await _repo.annualReenrollUser(
          userId: userId,
          academicYearId: _selectedYearId!,
        );
        successCount += 1;
      } catch (e, stack) {
        CrashReporter.log(e, stack);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bulk re-enroll complete: $successCount/${selectedRows.length} users updated.'),
      ),
    );
    await _loadOnboardingQueue();
  }

  Future<void> _onTapOnboardingUser(Map<String, dynamic> user) async {
    final role = user['role']?.toString() ?? '';
    final userName = user['full_name']?.toString() ?? 'User';
    final profileId = user['profile_id']?.toString();

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Role: $role'),
              const SizedBox(height: 12),
              if (role == 'STUDENT')
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Assign Class / Section'),
                  subtitle: const Text('Complete student enrollment mapping'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    if (_selectedYearId == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Select Academic Year first, then assign class/section.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    try {
                      final userId = user['user_id']?.toString() ?? '';
                      String? resolvedStudentId =
                          (profileId != null && profileId.trim().isNotEmpty)
                          ? profileId
                          : null;
                      if ((resolvedStudentId == null ||
                              resolvedStudentId.isEmpty) &&
                          userId.isNotEmpty) {
                        try {
                          final profile = await _repo.getRoleProfile(
                            userId,
                          );
                          final sid = profile['student_id']?.toString();
                          if (sid != null && sid.isNotEmpty) {
                            resolvedStudentId = sid;
                          }
                        } catch (e, stack) {
                          CrashReporter.log(e, stack);
                        }
                      }
                      if (resolvedStudentId == null ||
                          resolvedStudentId.isEmpty) {
                        await _showEnrollDialog(
                          initialStudentId: null,
                          pendingStudentUserId: userId.isEmpty ? null : userId,
                          suggestedAdmissionNumber: user['suggested_identifier']
                              ?.toString(),
                        );
                        await _loadOnboardingQueue();
                        return;
                      }
                      await _showEnrollDialog(
                        initialStudentId: resolvedStudentId,
                      );
                      await _loadOnboardingQueue();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to open enrollment: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
              if (role == 'TEACHER')
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Assign Class / Section / Subject'),
                  subtitle: const Text('Open Teacher Assignments'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context.push(RouteNames.teacherAssignments);
                    await _loadOnboardingQueue();
                  },
                ),
              if (role == 'PARENT')
                ListTile(
                  leading: const Icon(Icons.family_restroom_outlined),
                  title: const Text('Link Child / Children'),
                  subtitle: const Text(
                    'Auto-link from requested admission number(s)',
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final userId = user['user_id']?.toString() ?? '';
                      String? parentId = _isValidUuid(profileId)
                          ? profileId!.trim()
                          : null;

                      // If queue row has no profile_id, try resolving by user id first.
                      if (parentId == null && _isValidUuid(userId)) {
                        try {
                          final profile = await _repo.getRoleProfile(
                            userId,
                          );
                          final resolved = profile['parent_id']?.toString();
                          if (_isValidUuid(resolved)) {
                            parentId = resolved!.trim();
                          }
                        } catch (e, stack) {
                          CrashReporter.log(e, stack);
                        }
                      }

                      // Create profile only when it truly does not exist.
                      if (parentId == null) {
                        if (!_isValidUuid(userId)) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parent user is invalid. Please refresh and try again.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        final created = await _repo.createParentProfile(
                          userId: userId,
                        );
                        final createdParentId = created['parent_id']
                            ?.toString();
                        if (!_isValidUuid(createdParentId)) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parent profile could not be created.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        parentId = createdParentId!.trim();
                      }
                      if (!mounted) return;
                      final admissions = _requestedAdmissions(user);
                      var autoLinked = 0;
                      if (admissions.isNotEmpty) {
                        try {
                          autoLinked = await _autoLinkParentByAdmissions(
                            parentId: parentId,
                            admissions: admissions,
                          );
                        } catch (e, stack) {
                          CrashReporter.log(e, stack);
                          autoLinked = 0;
                        }
                      }

                      if (autoLinked > 0) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Auto-linked child admission(s): ${admissions.join(', ')}. '
                                'Parent onboarding is completed.',
                              ),
                            ),
                          );
                        }
                      } else {
                        // Fallback to manual selection when no exact enrolled match found.
                        await Future<void>.delayed(
                          const Duration(milliseconds: 120),
                        );
                        await _showParentChildLinkDialog(
                          parentId: parentId,
                          parentName: userName,
                        );
                      }
                      await _loadOnboardingQueue();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unable to open child linking: $e'),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEnrollDialog({
    String? initialStudentId,
    String? pendingStudentUserId,
    String? suggestedAdmissionNumber,
  }) async {
    final rollCtrl = TextEditingController();
    String? selectedStandardId;
    String? selectedSectionId;
    String? selectedStudentId = initialStudentId;
    String? selectedParentId;
    List<Map<String, dynamic>> parents = [];
    List<Map<String, dynamic>> standards = [];
    List<Map<String, dynamic>> sections = [];
    if (_schoolId != null && _selectedYearId != null) {
      try {
        standards = await _repo.listStandards(
          schoolId: _schoolId,
          academicYearId: _selectedYearId,
        );
      } catch (e, stack) {
        CrashReporter.log(e, stack);
        standards = [];
      }
    }
    if (selectedStudentId == null && pendingStudentUserId != null) {
      try {
        parents = await _repo.listParentProfiles();
      } catch (e, stack) {
        CrashReporter.log(e, stack);
        parents = [];
      }
    }
    if (standards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No classes found for selected academic year. Create class/section first.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Enroll Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStandardId,
                decoration: const InputDecoration(labelText: 'Class *'),
                items: standards
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s['id']?.toString(),
                        child: Text(s['name']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  selectedStandardId = v;
                  selectedSectionId = null;
                  if (_schoolId != null &&
                      _selectedYearId != null &&
                      v != null) {
                    sections = await _repo.listSections(
                      schoolId: _schoolId,
                      standardId: v,
                      academicYearId: _selectedYearId,
                    );
                  } else {
                    sections = [];
                  }
                  setLocal(() {});
                },
              ),
              const SizedBox(height: 8),
              if (selectedStudentId == null &&
                  pendingStudentUserId != null) ...[
                if (parents.isEmpty)
                  const Text(
                    'No parent profiles found. Create parent profile first.',
                    style: TextStyle(color: Colors.redAccent),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedParentId,
                    decoration: const InputDecoration(labelText: 'Parent *'),
                    items: parents
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p['parent_id']?.toString(),
                            child: Text(
                              p['full_name']?.toString().trim().isNotEmpty ==
                                      true
                                  ? '${p['full_name']} (${p['identifier'] ?? '-'})'
                                  : (p['identifier']?.toString() ?? '-'),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => selectedParentId = v),
                  ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String?>(
                initialValue: selectedSectionId,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Sections'),
                  ),
                  ...sections.map(
                    (s) => DropdownMenuItem<String?>(
                      value: s['id']?.toString(),
                      child: Text('Section ${s['name']?.toString() ?? ''}'),
                    ),
                  ),
                ],
                onChanged: (v) => setLocal(() => selectedSectionId = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rollCtrl,
                decoration: const InputDecoration(
                  labelText: 'Roll Number (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String? studentId = selectedStudentId;
                final standardId = selectedStandardId;
                final academicYearId = _selectedYearId;
                if (standardId == null || academicYearId == null) return;
                if (studentId == null &&
                    pendingStudentUserId != null &&
                    selectedParentId != null) {
                  final profile = await _repo.createStudentProfile(
                    userId: pendingStudentUserId,
                    parentId: selectedParentId!,
                    customAdmissionNumber: suggestedAdmissionNumber,
                  );
                  studentId = profile['student_id']?.toString();
                }
                if (studentId == null || studentId.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Select parent to create profile, then enroll.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                try {
                  await _repo.createMapping(
                    studentId: studentId,
                    standardId: standardId,
                    academicYearId: academicYearId,
                    sectionId: selectedSectionId,
                    rollNumber: rollCtrl.text.trim().isEmpty
                        ? null
                        : rollCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          selectedSectionId == null
                              ? 'Class assigned. Section is pending, so student remains in pending.'
                              : 'Student enrolled successfully',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Enroll'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showParentChildLinkDialog({
    required String parentId,
    required String parentName,
  }) async {
    final selected = <String>{};
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> candidates = [];
    bool loading = false;
    bool saving = false;

    Future<void> loadCandidates(StateSetter setLocal) async {
      setLocal(() => loading = true);
      try {
        final all = await _repo.listStudentProfiles(
          search: searchCtrl.text,
          pageSize: 300,
        );
        candidates = all.where((s) {
          final sid = (s['student_id'] ?? '').toString();
          final enrolled = s['enrollment_completed'] == true;
          return sid.isNotEmpty && enrolled;
        }).toList();
      } finally {
        setLocal(() => loading = false);
      }
    }

    try {
      final existingIds = await _repo.getParentChildIds(parentId);
      selected.addAll(existingIds);
      final all = await _repo.listStudentProfiles(pageSize: 300);
      candidates = all.where((s) {
        final sid = (s['student_id'] ?? '').toString();
        final enrolled = s['enrollment_completed'] == true;
        return sid.isNotEmpty && enrolled;
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load students for linking: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Link Children: $parentName'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Search student by name or admission number',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => loadCandidates(setLocal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => loadCandidates(setLocal),
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Selected: ${selected.length}'),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setLocal(() {
                          for (final s in candidates) {
                            final sid = (s['student_id'] ?? '').toString();
                            if (sid.isNotEmpty) selected.add(sid);
                          }
                        });
                      },
                      child: const Text('Select all shown'),
                    ),
                    TextButton(
                      onPressed: () => setLocal(() => selected.clear()),
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : candidates.isEmpty
                      ? const Center(
                          child: Text(
                            'No enrolled students found. Complete student profile + enrollment first.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: candidates.length,
                          itemBuilder: (context, index) {
                            final s = candidates[index];
                            final studentId = (s['student_id'] ?? '')
                                .toString();
                            final key = studentId;
                            if (key.isEmpty) return const SizedBox.shrink();
                            final checked = selected.contains(key);
                            final name = (s['full_name'] ?? '-').toString();
                            final identifier =
                                (s['admission_number'] ??
                                        s['identifier'] ??
                                        '-')
                                    .toString();
                            return CheckboxListTile(
                              value: checked,
                              title: Text(name),
                              subtitle: Text(identifier),
                              onChanged: (v) {
                                setLocal(() {
                                  if (v == true) {
                                    selected.add(key);
                                  } else {
                                    selected.remove(key);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (selected.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Select at least one child.'),
                            ),
                          );
                        }
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        final resolvedStudentIds = selected;
                        if (resolvedStudentIds.isEmpty) {
                          throw Exception(
                            'No valid students could be resolved for linking.',
                          );
                        }
                        await _repo.assignParentChildren(
                          parentId: parentId,
                          studentIds: resolvedStudentIds.toList(),
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Children linked successfully.'),
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to save child links: ${_friendlyError(e)}',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setLocal(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(schoolEnrollmentYearsProvider);

    final totalRows = _onboarding.length;
    final totalPages = totalRows == 0 ? 1 : (totalRows / _rowsPerPage).ceil();
    final activePage = _currentPage.clamp(0, totalPages - 1);
    final start = totalRows == 0 ? 0 : activePage * _rowsPerPage;
    final end = totalRows == 0
        ? 0
        : ((start + _rowsPerPage) > totalRows
              ? totalRows
              : (start + _rowsPerPage));
    final pagedRows = totalRows == 0
        ? const <Map<String, dynamic>>[]
        : _onboarding.sublist(start, end);
    final enableRichSelection = pagedRows.length <= 180;
    final selectablePageUserIds = pagedRows
        .map((u) => (u['user_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final allSelectedOnPage =
        selectablePageUserIds.isNotEmpty &&
        selectablePageUserIds.every(_selectedOnboardingUserIds.contains);

    return AdminScaffold(
      title: 'Enrollment',
      child: _loading
          ? const AdminLoadingPlaceholder(message: 'Loading enrollment…')
          : Padding(
              padding: const EdgeInsets.all(AdminSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminPageHeader(
                    title: 'Enrollment workspace',
                    subtitle:
                        'Onboarding queue and related tools. Queue auto-refreshes every 15s when a year is selected.',
                    iconActions: [
                      IconButton(
                        tooltip: 'Refresh onboarding queue',
                        onPressed: (_selectedYearId == null ||
                                _selectedYearId!.trim().isEmpty)
                            ? null
                            : () => _loadOnboardingQueue(),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Approved Users Onboarding',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          DropdownButton<String>(
                                            value: _selectedYearId,
                                            hint: const Text('Academic Year'),
                                            items: _years
                                                .map(
                                                  (y) =>
                                                      DropdownMenuItem<String>(
                                                    value: y['id']?.toString(),
                                                    child: Text(
                                                      y['name']?.toString() ??
                                                          '',
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) async {
                                              setState(() {
                                                _selectedYearId = v;
                                                _onboardingSearch = '';
                                                _onboardingSearchCtrl.text =
                                                    '';
                                                _onboardingRaw = const [];
                                                _onboarding = const [];
                                                _currentPage = 0;
                                                _selectedOnboardingUserIds
                                                    .clear();
                                              });
                                              await _loadOnboardingQueue();
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          DropdownButton<String?>(
                                            value: _onboardingRole,
                                            hint: const Text('Role'),
                                            items: const [
                                              DropdownMenuItem<String?>(
                                                value: null,
                                                child: Text('All'),
                                              ),
                                              DropdownMenuItem<String?>(
                                                value: 'STUDENT',
                                                child: Text('Student'),
                                              ),
                                              DropdownMenuItem<String?>(
                                                value: 'TEACHER',
                                                child: Text('Teacher'),
                                              ),
                                              DropdownMenuItem<String?>(
                                                value: 'PARENT',
                                                child: Text('Parent'),
                                              ),
                                              DropdownMenuItem<String?>(
                                                value: 'PRINCIPAL',
                                                child: Text('Principal'),
                                              ),
                                              DropdownMenuItem<String?>(
                                                value: 'TRUSTEE',
                                                child: Text('Trustee'),
                                              ),
                                            ],
                                            onChanged: (v) async {
                                              setState(
                                                () => _onboardingRole = v,
                                              );
                                              await _loadOnboardingQueue();
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          DropdownButton<String>(
                                            value: _onboardingStatus,
                                            items: const [
                                              DropdownMenuItem<String>(
                                                value: 'PENDING',
                                                child: Text('Pending'),
                                              ),
                                              DropdownMenuItem<String>(
                                                value: 'ENROLLED',
                                                child: Text('Enrolled'),
                                              ),
                                              DropdownMenuItem<String>(
                                                value: 'ALL',
                                                child: Text('All'),
                                              ),
                                            ],
                                            onChanged: (v) {
                                              setState(
                                                () => _onboardingStatus =
                                                    v ?? 'PENDING',
                                              );
                                              _recomputeOnboardingView();
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 240,
                                            child: TextFormField(
                                              controller:
                                                  _onboardingSearchCtrl,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                hintText:
                                                    'Search name, contact, identifier',
                                                border:
                                                    const OutlineInputBorder(),
                                                prefixIcon: const Icon(
                                                  Icons.search,
                                                  size: 18,
                                                ),
                                                suffixIcon: _onboardingSearch
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : IconButton(
                                                        tooltip: 'Clear search',
                                                        icon: const Icon(
                                                          Icons.clear,
                                                          size: 16,
                                                        ),
                                                        onPressed: () {
                                                          _onboardingSearchCtrl
                                                              .clear();
                                                          _onboardingSearch =
                                                              '';
                                                          _recomputeOnboardingView();
                                                        },
                                                      ),
                                              ),
                                              onChanged: (v) {
                                                _onboardingSearch = v;
                                                _recomputeOnboardingView();
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Refresh onboarding queue',
                                            onPressed: _loadOnboardingQueue,
                                            icon: const Icon(Icons.refresh),
                                          ),
                                          IconButton(
                                            tooltip: 'Copy table',
                                            onPressed: _onboarding.isEmpty
                                                ? null
                                                : _copyOnboardingTable,
                                            icon: const Icon(
                                              Icons.copy_all_outlined,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed:
                                                _selectedOnboardingUserIds
                                                    .isEmpty
                                                ? null
                                                : _reenrollSelectedUsers,
                                            icon: const Icon(
                                              Icons.autorenew_outlined,
                                              size: 16,
                                            ),
                                            label: Text(
                                              'Re-enroll Selected (${_selectedOnboardingUserIds.length})',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_onboarding.isNotEmpty)
                              Row(
                                children: [
                                  Checkbox(
                                    value: allSelectedOnPage,
                                    onChanged: (v) => _toggleSelectAllOnPage(
                                      pagedRows,
                                      v == true,
                                    ),
                                  ),
                                  const Text('Select all on this page'),
                                ],
                              ),
                            if (_onboarding.isNotEmpty)
                              const SizedBox(height: 8),
                            if (_onboarding.isEmpty)
                              const Expanded(
                                child: AdminEmptyState(
                                  icon: Icons.inbox_outlined,
                                  title: 'No users in this view',
                                  message:
                                      'Choose an academic year or adjust role, status, and search.',
                                ),
                              )
                            else
                              Expanded(
                                child: Scrollbar(
                                  controller: _verticalTableScrollController,
                                  thumbVisibility: true,
                                  interactive: true,
                                  child: SingleChildScrollView(
                                    controller: _verticalTableScrollController,
                                    child: Scrollbar(
                                      controller:
                                          _horizontalTableScrollController,
                                      thumbVisibility: true,
                                      interactive: true,
                                      notificationPredicate:
                                          (notification) =>
                                              notification.metrics.axis ==
                                              Axis.horizontal,
                                      child: SingleChildScrollView(
                                        controller:
                                            _horizontalTableScrollController,
                                        scrollDirection: Axis.horizontal,
                                        physics:
                                            const ClampingScrollPhysics(),
                                        child: enableRichSelection
                                            ? SelectionArea(
                                              child: DataTable(
                                                columns: const [
                                                  DataColumn(
                                                    label: Text('Select'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Role'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Name'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Identifier'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Contact'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Profile'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Re-enroll'),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Enrollment'),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Pending Reason',
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text('Actions'),
                                                  ),
                                                ],
                                                rows: pagedRows
                                                    .asMap()
                                                    .entries
                                                    .map((entry) {
                                                  final u = entry.value;
                                                  final rowIndex =
                                                      start + entry.key;
                                                  final contact =
                                                      _rowContactText(u);
                                                  final identifierText =
                                                      _rowIdentifierText(u);
                                                  final userId =
                                                      (u['user_id'] ?? '').toString().trim();
                                                  final isSelected =
                                                      userId.isNotEmpty &&
                                                      _selectedOnboardingUserIds.contains(userId);
                                                  return DataRow(
                                                    color: adminDataRowColor(
                                                        rowIndex),
                                                    cells: [
                                                      DataCell(
                                                        Checkbox(
                                                          value: isSelected,
                                                          onChanged: userId.isEmpty
                                                              ? null
                                                              : (v) => _toggleOnboardingUserSelection(
                                                                    userId,
                                                                    v == true,
                                                                  ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SelectableText(
                                                          u['role']
                                                                  ?.toString() ??
                                                              '-',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SelectableText(
                                                          u['full_name']
                                                                  ?.toString() ??
                                                              '-',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SelectableText(
                                                          identifierText,
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SelectableText(contact),
                                                      ),
                                                      DataCell(
                                                        SelectableText(
                                                          (u['profile_created'] ==
                                                                  true)
                                                              ? 'Done'
                                                              : 'Pending',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SelectableText(
                                                          (u['reenrollment_completed'] ==
                                                                  true)
                                                              ? 'Done'
                                                              : 'Pending',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SelectableText(
                                                          (u['enrollment_completed'] ==
                                                                  true)
                                                              ? 'Done'
                                                              : 'Pending',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SelectableText(
                                                          u['pending_reason']
                                                                  ?.toString() ??
                                                              '-',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Row(
                                                          children: [
                                                            IconButton(
                                                              tooltip:
                                                                  'Copy row',
                                                              icon: const Icon(
                                                                Icons
                                                                    .copy_outlined,
                                                                size: 18,
                                                              ),
                                                              onPressed: () =>
                                                                  _copyOnboardingRow(
                                                                    u,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  _reenrollQueueUser(
                                                                    u,
                                                                  ),
                                                              child: const Text(
                                                                'Re-enroll',
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  _onTapOnboardingUser(
                                                                    u,
                                                                  ),
                                                              child: const Text(
                                                                'Open',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            )
                                          : DataTable(
                                              columns: const [
                                                DataColumn(label: Text('Select')),
                                                DataColumn(label: Text('Role')),
                                                DataColumn(label: Text('Name')),
                                                DataColumn(
                                                  label: Text('Identifier'),
                                                ),
                                                DataColumn(
                                                  label: Text('Contact'),
                                                ),
                                                DataColumn(
                                                  label: Text('Profile'),
                                                ),
                                                DataColumn(
                                                  label: Text('Re-enroll'),
                                                ),
                                                DataColumn(
                                                  label: Text('Enrollment'),
                                                ),
                                                DataColumn(
                                                  label: Text('Pending Reason'),
                                                ),
                                                DataColumn(
                                                  label: Text('Actions'),
                                                ),
                                              ],
                                              rows: pagedRows
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                final u = entry.value;
                                                final rowIndex =
                                                    start + entry.key;
                                                final contact = _rowContactText(
                                                  u,
                                                );
                                                final identifierText =
                                                    _rowIdentifierText(u);
                                                final userId =
                                                    (u['user_id'] ?? '').toString().trim();
                                                final isSelected =
                                                    userId.isNotEmpty &&
                                                    _selectedOnboardingUserIds.contains(userId);
                                                return DataRow(
                                                  color: adminDataRowColor(
                                                      rowIndex),
                                                  cells: [
                                                    DataCell(
                                                      Checkbox(
                                                        value: isSelected,
                                                        onChanged: userId.isEmpty
                                                            ? null
                                                            : (v) => _toggleOnboardingUserSelection(
                                                                  userId,
                                                                  v == true,
                                                                ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        u['role']?.toString() ??
                                                            '-',
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        u['full_name']
                                                                ?.toString() ??
                                                            '-',
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(identifierText),
                                                    ),
                                                    DataCell(Text(contact)),
                                                    DataCell(
                                                      Text(
                                                        (u['profile_created'] ==
                                                                true)
                                                            ? 'Done'
                                                            : 'Pending',
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        (u['reenrollment_completed'] ==
                                                                true)
                                                            ? 'Done'
                                                            : 'Pending',
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        (u['enrollment_completed'] ==
                                                                true)
                                                            ? 'Done'
                                                            : 'Pending',
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        u['pending_reason']
                                                                ?.toString() ??
                                                            '-',
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Row(
                                                        children: [
                                                          IconButton(
                                                            tooltip: 'Copy row',
                                                            icon: const Icon(
                                                              Icons
                                                                  .copy_outlined,
                                                              size: 18,
                                                            ),
                                                            onPressed: () =>
                                                                _copyOnboardingRow(
                                                                  u,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                _reenrollQueueUser(
                                                                  u,
                                                                ),
                                                            child: const Text(
                                                              'Re-enroll',
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                _onTapOnboardingUser(
                                                                  u,
                                                                ),
                                                            child: const Text(
                                                              'Open',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_onboarding.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      'Showing ${start + 1}-$end of $totalRows',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Previous page',
                                      onPressed: activePage > 0
                                          ? () => _setPage(
                                              activePage - 1,
                                              totalPages,
                                            )
                                          : null,
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    Text(
                                      'Page ${activePage + 1} / $totalPages',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    IconButton(
                                      tooltip: 'Next page',
                                      onPressed: activePage < totalPages - 1
                                          ? () => _setPage(
                                              activePage + 1,
                                              totalPages,
                                            )
                                          : null,
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Tip: Drag-select text in table cells and press Ctrl/Cmd + C to copy.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AdminSpacing.sm),
                      child: Material(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(AdminSpacing.md),
                          child: SelectableText(
                            _error!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
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
}
