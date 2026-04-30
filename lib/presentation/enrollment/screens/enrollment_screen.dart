// lib/presentation/enrollment/screens/enrollment_screen.dart  [Admin Console]
// Phase 4: Assign students to class/section per academic year, view class roster.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../../../core/constants/route_constants.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../../domains/providers/enrollment_provider.dart';
import '../../../data/repositories/enrollment_repository.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class _EnrollmentRepository {
  _EnrollmentRepository(this._api);
  final EnrollmentRepository _api;

  Future<void> createMapping({
    required String studentId,
    required String standardId,
    required String academicYearId,
    String? sectionId,
    String? rollNumber,
  }) async {
    await _api.createMapping(
      studentId: studentId,
      standardId: standardId,
      academicYearId: academicYearId,
      sectionId: sectionId,
      rollNumber: rollNumber,
    );
  }

  Future<List<Map<String, dynamic>>> listStandards(String schoolId, String academicYearId) async {
    return _api.listStandards(
      schoolId: schoolId,
      academicYearId: academicYearId,
    );
  }

  Future<List<Map<String, dynamic>>> listSections(String schoolId, String standardId, String academicYearId) async {
    return _api.listSections(
      schoolId: schoolId,
      standardId: standardId,
      academicYearId: academicYearId,
    );
  }

  Future<List<Map<String, dynamic>>> listAcademicYears(String schoolId) async {
    return _api.listAcademicYears(schoolId: schoolId);
  }

  Future<List<Map<String, dynamic>>> onboardingQueue({
    String? role,
    bool pendingOnly = true,
    String? academicYearId,
  }) async {
    return _api.onboardingQueue(
      role: role,
      pendingOnly: pendingOnly,
      academicYearId: academicYearId,
    );
  }

  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    return _api.searchStudents(query);
  }

  Future<Map<String, dynamic>> getRoleProfileByUserId(String userId) async {
    final resp = await _api.getRoleProfile(userId);
    return resp;
  }

  Future<List<Map<String, dynamic>>> listParentProfiles({String? search}) async {
    return _api.listParentProfiles(search: search);
  }

  Future<Map<String, dynamic>> createStudentProfile({
    required String userId,
    required String parentId,
    String? customAdmissionNumber,
  }) async {
    return _api.createStudentProfile(
      userId: userId,
      parentId: parentId,
      customAdmissionNumber: customAdmissionNumber,
    );
  }

  Future<Map<String, dynamic>> createParentProfile({
    required String userId,
    String relation = 'GUARDIAN',
    String? occupation,
  }) async {
    return _api.createParentProfile(
      userId: userId,
      relation: relation,
      occupation: occupation,
    );
  }

  Future<List<Map<String, dynamic>>> listStudentProfiles({
    String? search,
    int pageSize = 300,
  }) async {
    return _api.listStudentProfiles(search: search, pageSize: pageSize);
  }

  Future<List<String>> getParentChildIds(String parentId) async {
    return _api.getParentChildIds(parentId);
  }

  Future<void> assignParentChildren({
    required String parentId,
    required List<String> studentIds,
  }) async {
    return _api.assignParentChildren(parentId: parentId, studentIds: studentIds);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class EnrollmentScreen extends ConsumerStatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  ConsumerState<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends ConsumerState<EnrollmentScreen> {
  late final _EnrollmentRepository _repo;

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _onboarding = [];

  String? _selectedYearId;

  bool _loading = false;
  String? _error;
  String? _onboardingRole;
  String _onboardingStatus = 'PENDING';
  Timer? _queueAutoRefresh;
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
    _repo = _EnrollmentRepository(ref.read(enrollmentRepositoryProvider));
    _loadYears();
    _queueAutoRefresh = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (_selectedYearId != null && _selectedYearId!.trim().isNotEmpty) {
          _loadOnboardingQueue(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _queueAutoRefresh?.cancel();
    super.dispose();
  }

  String? get _schoolId => ref.read(authControllerProvider).valueOrNull?.schoolId;

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

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() => _loading = true);
    try {
      final years = await _repo.listAcademicYears(_schoolId!);
      final active = years.firstWhere((y) => y['is_active'] == true, orElse: () => years.isNotEmpty ? years.first : {});
      setState(() {
        _years = years;
        _selectedYearId = active['id']?.toString();
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
        setState(() => _onboarding = const []);
      }
      return;
    }
    if (!silent) setState(() => _loading = true);
    try {
      final items = await _repo.onboardingQueue(
        role: _onboardingRole,
        pendingOnly: _onboardingStatus == 'PENDING',
        academicYearId: _selectedYearId,
      );
      setState(() => _onboarding = _applyOnboardingStatusFilter(items));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (!silent) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _applyOnboardingStatusFilter(
    List<Map<String, dynamic>> input,
  ) {
    if (_onboardingStatus == 'ENROLLED') {
      return input
          .where((u) => u['enrollment_completed'] == true)
          .toList(growable: false);
    }
    if (_onboardingStatus == 'ALL') return input;
    return input.where((u) => u['enrollment_pending'] == true).toList(growable: false);
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
              Text(
                userName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                      if ((resolvedStudentId == null || resolvedStudentId.isEmpty) &&
                          userId.isNotEmpty) {
                        try {
                          final profile = await _repo.getRoleProfileByUserId(userId);
                          final sid = profile['student_id']?.toString();
                          if (sid != null && sid.isNotEmpty) {
                            resolvedStudentId = sid;
                          }
                        } catch (_) {}
                      }
                      if (resolvedStudentId == null || resolvedStudentId.isEmpty) {
                        await _showEnrollDialog(
                          initialStudentId: null,
                          pendingStudentUserId: userId.isEmpty ? null : userId,
                          suggestedAdmissionNumber:
                              user['suggested_identifier']?.toString(),
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
                          SnackBar(content: Text('Unable to open enrollment: $e')),
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
                  subtitle: const Text('Select one or multiple children'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final userId = user['user_id']?.toString() ?? '';
                      String? parentId = _isValidUuid(profileId) ? profileId!.trim() : null;

                      // If queue row has no profile_id, try resolving by user id first.
                      if (parentId == null && _isValidUuid(userId)) {
                        try {
                          final profile = await _repo.getRoleProfileByUserId(userId);
                          final resolved = profile['parent_id']?.toString();
                          if (_isValidUuid(resolved)) {
                            parentId = resolved!.trim();
                          }
                        } catch (_) {}
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
                        final created = await _repo.createParentProfile(userId: userId);
                        final createdParentId = created['parent_id']?.toString();
                        if (!_isValidUuid(createdParentId)) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Parent profile could not be created.'),
                              ),
                            );
                          }
                          return;
                        }
                        parentId = createdParentId!.trim();
                      }
                      if (!mounted) return;
                      // Let the bottom sheet close completely before opening dialog.
                      await Future<void>.delayed(const Duration(milliseconds: 120));
                      await _showParentChildLinkDialog(
                        parentId: parentId,
                        parentName: userName,
                      );
                      await _loadOnboardingQueue();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to open child linking: $e')),
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
        standards = await _repo.listStandards(_schoolId!, _selectedYearId!);
      } catch (_) {
        standards = [];
      }
    }
    if (selectedStudentId == null && pendingStudentUserId != null) {
      try {
        parents = await _repo.listParentProfiles();
      } catch (_) {
        parents = [];
      }
    }
    if (standards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No classes found for selected academic year. Create class/section first.'),
          ),
        );
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Enroll Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStandardId,
                decoration: const InputDecoration(labelText: 'Class *'),
                items: standards
                    .map((s) => DropdownMenuItem<String>(
                          value: s['id']?.toString(),
                          child: Text(s['name']?.toString() ?? ''),
                        ))
                    .toList(),
                onChanged: (v) async {
                  selectedStandardId = v;
                  selectedSectionId = null;
                  if (_schoolId != null && _selectedYearId != null && v != null) {
                    sections = await _repo.listSections(_schoolId!, v, _selectedYearId!);
                  } else {
                    sections = [];
                  }
                  setLocal(() {});
                },
              ),
              const SizedBox(height: 8),
              if (selectedStudentId == null && pendingStudentUserId != null) ...[
                if (parents.isEmpty)
                  const Text(
                    'No parent profiles found. Create parent profile first.',
                    style: TextStyle(color: Colors.redAccent),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedParentId,
                    decoration: const InputDecoration(labelText: 'Parent *'),
                    items: parents
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p['parent_id']?.toString(),
                            child: Text(
                              p['full_name']?.toString().trim().isNotEmpty == true
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
                value: selectedSectionId,
                decoration: const InputDecoration(labelText: 'Section (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All Sections')),
                  ...sections.map((s) => DropdownMenuItem<String?>(
                        value: s['id']?.toString(),
                        child: Text('Section ${s['name']?.toString() ?? ''}'),
                      )),
                ],
                onChanged: (v) => setLocal(() => selectedSectionId = v),
              ),
              const SizedBox(height: 8),
              TextField(controller: rollCtrl, decoration: const InputDecoration(labelText: 'Roll Number (optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
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
                        content: Text('Select parent to create profile, then enroll.'),
                      ),
                    );
                  }
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await _repo.createMapping(
                    studentId: studentId,
                    standardId: standardId,
                    academicYearId: academicYearId,
                    sectionId: selectedSectionId,
                    rollNumber: rollCtrl.text.trim().isEmpty ? null : rollCtrl.text.trim(),
                  );
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student enrolled successfully')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
        candidates = await _repo.listStudentProfiles(
          search: searchCtrl.text,
          pageSize: 300,
        );
      } finally {
        setLocal(() => loading = false);
      }
    }

    try {
      final existingIds = await _repo.getParentChildIds(parentId);
      selected.addAll(existingIds);
      candidates = await _repo.listStudentProfiles(pageSize: 300);
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
                          labelText: 'Search student by name or admission number',
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
                            if (sid.isNotEmpty) {
                              selected.add(sid);
                            } else {
                              final uid = (s['user_id'] ?? '').toString();
                              if (uid.isNotEmpty) selected.add('user:$uid');
                            }
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
                              child: Text('No students found.'),
                            )
                          : ListView.builder(
                              itemCount: candidates.length,
                              itemBuilder: (context, index) {
                                final s = candidates[index];
                                final studentId = (s['student_id'] ?? '').toString();
                                final userId = (s['user_id'] ?? '').toString();
                                final key = studentId.isNotEmpty
                                    ? studentId
                                    : (userId.isNotEmpty ? 'user:$userId' : '');
                                if (key.isEmpty) return const SizedBox.shrink();
                                final checked = selected.contains(key);
                                final name = (s['full_name'] ?? '-').toString();
                                final identifier = (s['admission_number'] ??
                                        s['identifier'] ??
                                        '-')
                                    .toString();
                                final hasProfile = studentId.isNotEmpty;
                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(name),
                                  subtitle: Text(
                                    hasProfile
                                        ? identifier
                                        : '$identifier • Profile will be created on save',
                                  ),
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
                            const SnackBar(content: Text('Select at least one child.')),
                          );
                        }
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        final resolvedStudentIds = <String>{};
                        for (final id in selected) {
                          if (!id.startsWith('user:')) {
                            resolvedStudentIds.add(id);
                            continue;
                          }
                          final userId = id.substring(5);
                          if (userId.isEmpty) continue;
                          Map<String, dynamic>? selectedUser;
                          for (final c in candidates) {
                            final uid = (c['user_id'] ?? '').toString();
                            if (uid == userId) {
                              selectedUser = c;
                              break;
                            }
                          }
                          final suggestedIdentifier =
                              selectedUser?['identifier']?.toString() ??
                                  selectedUser?['suggested_identifier']?.toString();
                          try {
                            final created = await _repo.createStudentProfile(
                              userId: userId,
                              parentId: parentId,
                              customAdmissionNumber: suggestedIdentifier,
                            );
                            final studentId = (created['student_id'] ?? '').toString();
                            if (studentId.isNotEmpty) {
                              resolvedStudentIds.add(studentId);
                            }
                          } catch (createErr) {
                            // If profile already exists, resolve and continue.
                            try {
                              final profile = await _repo.getRoleProfileByUserId(userId);
                              final existingStudentId =
                                  (profile['student_id'] ?? '').toString();
                              if (existingStudentId.isNotEmpty) {
                                resolvedStudentIds.add(existingStudentId);
                                continue;
                              }
                            } catch (_) {
                              // Ignore fallback lookup errors and preserve original create error.
                            }
                            throw Exception(_friendlyError(createErr));
                          }
                        }
                        if (resolvedStudentIds.isEmpty) {
                          throw Exception('No valid students could be resolved for linking.');
                        }
                        await _repo.assignParentChildren(
                          parentId: parentId,
                          studentIds: resolvedStudentIds.toList(),
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Children linked successfully.')),
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save child links: ${_friendlyError(e)}')),
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
    return AdminScaffold(
      title: 'Enrollment',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Approved Users Onboarding',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              DropdownButton<String>(
                                value: _selectedYearId,
                                hint: const Text('Academic Year'),
                                items: _years
                                    .map(
                                      (y) => DropdownMenuItem<String>(
                                        value: y['id']?.toString(),
                                        child: Text(y['name']?.toString() ?? ''),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) async {
                                  setState(() => _selectedYearId = v);
                                  await _loadOnboardingQueue();
                                },
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String?>(
                                value: _onboardingRole,
                                hint: const Text('Role'),
                                items: const [
                                  DropdownMenuItem<String?>(
                                      value: null, child: Text('All')),
                                  DropdownMenuItem<String?>(
                                      value: 'STUDENT', child: Text('Student')),
                                  DropdownMenuItem<String?>(
                                      value: 'TEACHER', child: Text('Teacher')),
                                  DropdownMenuItem<String?>(
                                      value: 'PARENT', child: Text('Parent')),
                                ],
                                onChanged: (v) async {
                                  setState(() => _onboardingRole = v);
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
                                onChanged: (v) async {
                                  setState(() => _onboardingStatus = v ?? 'PENDING');
                                  await _loadOnboardingQueue();
                                },
                              ),
                              IconButton(
                                tooltip: 'Refresh onboarding queue',
                                onPressed: _loadOnboardingQueue,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_onboarding.isEmpty)
                            const Text('No users in this onboarding view.')
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Identifier')),
                                  DataColumn(label: Text('Contact')),
                                  DataColumn(label: Text('Profile')),
                                  DataColumn(label: Text('Enrollment')),
                                  DataColumn(label: Text('Pending Reason')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _onboarding.map((u) {
                                  final contact =
                                      (u['email']?.toString().isNotEmpty ?? false)
                                          ? u['email'].toString()
                                          : (u['phone']?.toString() ?? '-');
                                  return DataRow(
                                    onSelectChanged: (_) => _onTapOnboardingUser(u),
                                    cells: [
                                    DataCell(Text(u['role']?.toString() ?? '-')),
                                    DataCell(Text(u['full_name']?.toString() ?? '-')),
                                    DataCell(Text(u['suggested_identifier']?.toString() ?? '-')),
                                    DataCell(Text(contact)),
                                    DataCell(Text((u['profile_created'] == true) ? 'Done' : 'Pending')),
                                    DataCell(Text((u['enrollment_completed'] == true) ? 'Done' : 'Pending')),
                                    DataCell(Text(u['pending_reason']?.toString() ?? '-')),
                                    const DataCell(Text('Click row')),
                                  ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
    );
  }
}
