// lib/presentation/results/screens/exams_results_screen.dart  [Admin Console]
// Phase 10 — Examination Screen.
// STAFF ADMIN: list/create/delete exams and manage result upload/reupload.
// Includes roster-based pending/uploaded tracking by class + section.
import 'dart:async';

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Exam {
  const _Exam({
    required this.id,
    required this.name,
    required this.standardName,
    required this.standardId,
    required this.startDate,
    required this.endDate,
    required this.isPublished,
    required this.academicYearId,
    required this.examType,
  });

  final String id;
  final String name;
  final String? standardName;
  final String? standardId;
  final String? startDate;
  final String? endDate;
  final bool isPublished;
  final String? academicYearId;
  final String? examType;

  factory _Exam.fromJson(Map<String, dynamic> json) {
    final nestedStd = json['standard'];
    return _Exam(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      standardName: json['standard']?['name'] as String? ??
          json['standard_name'] as String?,
      standardId: json['standard_id']?.toString() ??
          (nestedStd is Map ? nestedStd['id']?.toString() : null),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      isPublished: json['is_published'] == true,
      academicYearId: json['academic_year_id']?.toString(),
      examType: json['exam_type']?.toString(),
    );
  }
}

class _ResultStudent {
  const _ResultStudent({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.section,
    required this.totalObtained,
    required this.totalMax,
    required this.overallPercentage,
    required this.subjects,
    required this.hasReportCard,
    this.reportCardUrl,
  });

  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String? section;
  final double totalObtained;
  final double totalMax;
  final double overallPercentage;
  final List<Map<String, dynamic>> subjects;
  final bool hasReportCard;
  final String? reportCardUrl;

  factory _ResultStudent.fromJson(Map<String, dynamic> json) => _ResultStudent(
        studentId: json['student_id']?.toString() ?? '',
        studentName: json['student_name']?.toString() ?? '',
        admissionNumber: json['admission_number']?.toString() ?? '',
        section: json['section']?.toString(),
        totalObtained: _readDouble(json['total_obtained']),
        totalMax: _readDouble(json['total_max']),
        overallPercentage: _readDouble(json['overall_percentage']),
        subjects: _parseSubjectMaps(json['subjects']),
        hasReportCard: json['has_report_card'] == true,
        reportCardUrl: json['report_card_url']?.toString(),
      );

  static double _readDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static List<Map<String, dynamic>> _parseSubjectMaps(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  Color get percentageColor {
    if (overallPercentage >= 75) return AdminColors.success;
    if (overallPercentage >= 50) return const Color(0xFFEA580C);
    return AdminColors.danger;
  }

  String get uploadedByLabel {
    final names = <String>{};
    for (final s in subjects) {
      final raw = s['entered_by_name']?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        names.add(raw);
      }
    }
    if (names.isEmpty) return 'Uploaded';
    if (names.length == 1) return 'Uploaded by ${names.first}';
    return 'Uploaded by multiple';
  }
}

class _StudentLite {
  const _StudentLite({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    this.section,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String? section;

  factory _StudentLite.fromJson(Map<String, dynamic> json) => _StudentLite(
        id: json['id']?.toString() ?? '',
        studentName: json['student_name']?.toString().trim().isNotEmpty == true
            ? json['student_name']!.toString()
            : (json['admission_number']?.toString() ?? 'Student'),
        admissionNumber: json['admission_number']?.toString() ?? '',
        section: json['section']?.toString(),
      );
}

class _TimetableStatus {
  const _TimetableStatus({
    required this.isUploaded,
    this.uploadedByName,
    this.fileUrl,
  });

  final bool isUploaded;
  final String? uploadedByName;
  final String? fileUrl;
}

class _SubjectLite {
  const _SubjectLite({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory _SubjectLite.fromJson(Map<String, dynamic> json) => _SubjectLite(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Subject',
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class _ResultsRepository {
  _ResultsRepository(this._dio);
  final DioClient _dio;

  Future<List<Map<String, dynamic>>> listYears(String schoolId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.academicYears,
      queryParameters: {'school_id': schoolId},
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listStandards(
      String schoolId, String academicYearId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
      },
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<String>> listSections({
    required String standardId,
    String? academicYearId,
  }) async {
    final resp = await _dio.dio.get<dynamic>(
      '${ApiConstants.results}/sections',
      queryParameters: {
        'standard_id': standardId,
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId,
      },
    );
    final raw = resp.data;
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return const [];
  }

  Future<List<_StudentLite>> listStudents({
    required String standardId,
    String? academicYearId,
    String? section,
  }) async {
    // API caps page_size at 100; larger values fail validation and return no rows.
    const pageSize = 100;
    final all = <_StudentLite>[];
    for (var page = 1; page <= 50; page++) {
      final resp = await _dio.dio.get<Map<String, dynamic>>(
        ApiConstants.students,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          'standard_id': standardId,
          if (academicYearId != null && academicYearId.trim().isNotEmpty)
            'academic_year_id': academicYearId.trim(),
          if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
        },
      );
      final batch = ((resp.data?['items'] as List?) ?? [])
          .map((e) => _StudentLite.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      all.addAll(batch);
      if (batch.length < pageSize) break;
    }
    return all;
  }

  Future<List<_SubjectLite>> listSubjects({
    required String standardId,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.subjects,
      queryParameters: {'standard_id': standardId},
    );
    return ((resp.data?['items'] as List?) ?? [])
        .map((e) => _SubjectLite.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Set<String>> listUploadedExamIds({
    String? academicYearId,
    String? standardId,
    String? section,
  }) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.resultsEntries,
      queryParameters: {
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId,
        if (standardId != null && standardId.trim().isNotEmpty)
          'standard_id': standardId,
        if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
      },
    );
    final raw = (resp.data?['items'] as List?) ?? const [];
    final ids = <String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final examId = map['exam_id']?.toString() ?? '';
      if (examId.trim().isNotEmpty) ids.add(examId);
    }
    return ids;
  }

  // GET /results/exams — list all exams (principal sees all)
  Future<List<_Exam>> listExams({
    String? academicYearId,
    String? standardId,
  }) async {
    final resp = await _dio.dio.get<dynamic>(
      ApiConstants.resultsExams,
      queryParameters: {
        if (academicYearId != null) 'academic_year_id': academicYearId,
        if (standardId != null) 'standard_id': standardId,
      },
    );
    final raw = resp.data is List
        ? resp.data as List
        : ((resp.data as Map?)?['items'] as List? ?? []);
    return raw
        .map((e) => _Exam.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> createExamForAllClasses({
    required String name,
    required String startDate,
    required String endDate,
    String? academicYearId,
  }) async {
    final resp = await _dio.dio.post<Map<String, dynamic>>(
      ApiConstants.resultsExamsBulk,
      data: {
        'name': name,
        'apply_to_all_standards': true,
        if (academicYearId != null) 'academic_year_id': academicYearId,
        'start_date': startDate,
        'end_date': endDate,
      },
    );
    return resp.data ?? <String, dynamic>{};
  }

  // GET /results/exams/{id}/distribution — class result distribution
  Future<List<_ResultStudent>> getDistribution(
    String examId, {
    String? section,
  }) async {
    final resp = await _dio.dio.get<dynamic>(
      ApiConstants.resultsExamDistribution(examId),
      queryParameters: {
        if (section != null && section.trim().isNotEmpty) 'section': section,
      },
    );
    final data = resp.data;
    if (data is! Map) {
      throw FormatException('Unexpected distribution response shape');
    }
    final map = Map<String, dynamic>.from(data);
    final rawItems = map['items'];
    if (rawItems == null) return const [];
    if (rawItems is! List) {
      throw FormatException('distribution.items is not a list');
    }
    final out = <_ResultStudent>[];
    for (final e in rawItems) {
      if (e is! Map) continue;
      try {
        out.add(_ResultStudent.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<void> deleteExam(String examId) async {
    await _dio.dio.delete<dynamic>(ApiConstants.resultsExamDelete(examId));
  }

  Future<void> upsertResults({
    required String examId,
    required List<Map<String, dynamic>> entries,
  }) async {
    await _dio.dio.post<dynamic>(
      '${ApiConstants.results}/entries',
      data: {
        'exam_id': examId,
        'entries': entries,
      },
    );
  }

  Future<void> uploadSchedule({
    required String standardId,
    required String examId,
    String? academicYearId,
    String? section,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final normalizedSection = section?.trim();
    final sectionParam = (normalizedSection == null || normalizedSection.isEmpty)
        ? null
        : normalizedSection.toUpperCase();
    final formData = FormData.fromMap({
      'standard_id': standardId,
      'exam_id': examId,
      if (academicYearId != null && academicYearId.trim().isNotEmpty)
        'academic_year_id': academicYearId,
      if (sectionParam != null) 'section': sectionParam,
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    await _dio.dio.post<dynamic>(
      ApiConstants.timetable,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> uploadReportCard({
    required String studentId,
    required String examId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final formData = FormData.fromMap({
      'student_id': studentId,
      'exam_id': examId,
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    await _dio.dio.post<dynamic>(
      ApiConstants.resultsReportCardUpload,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<_TimetableStatus> getTimetableStatus({
    required String standardId,
    required String examId,
    String? academicYearId,
    String? section,
  }) async {
    try {
      final resp = await _dio.dio.get<Map<String, dynamic>>(
        ApiConstants.timetableByStandard(standardId),
        queryParameters: {
          'exam_id': examId,
          if (academicYearId != null && academicYearId.trim().isNotEmpty)
            'academic_year_id': academicYearId,
          if (section != null && section.trim().isNotEmpty)
            'section': section.trim().toUpperCase(),
        },
      );
      final data = resp.data ?? const <String, dynamic>{};
      final uploadedBy = data['uploaded_by_name']?.toString();
      return _TimetableStatus(
        isUploaded: true,
        uploadedByName: (uploadedBy != null && uploadedBy.trim().isNotEmpty)
            ? uploadedBy.trim()
            : null,
        fileUrl: data['file_url']?.toString(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const _TimetableStatus(isUploaded: false);
      }
      rethrow;
    }
  }

  Future<void> deleteTimetable({
    required String standardId,
    required String examId,
    String? academicYearId,
    String? section,
  }) async {
    await _dio.dio.delete<void>(
      ApiConstants.timetableByStandard(standardId),
      queryParameters: {
        'exam_id': examId,
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId.trim(),
        if (section != null && section.trim().isNotEmpty)
          'section': section.trim().toUpperCase(),
      },
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ExamsResultsScreen extends ConsumerStatefulWidget {
  const ExamsResultsScreen({super.key});

  @override
  ConsumerState<ExamsResultsScreen> createState() =>
      _ExamsResultsScreenState();
}

class _ExamsResultsScreenState extends ConsumerState<ExamsResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _ResultsRepository _repo;

  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  List<String> _sections = [];
  List<_StudentLite> _students = [];
  List<_Exam> _exams = [];
  List<_ResultStudent> _distribution = [];
  Map<String, bool> _examHasUploadedResults = {};
  Map<String, _TimetableStatus> _examTimetableStatus = {};
  bool _examStatusLoading = false;
  bool _distributionLoading = false;
  String? _distributionError;

  _Exam? _selectedExam;
  String? _selectedYearId;
  String? _selectedStandardId;
  String? _selectedSection;
  String? _uploadStatusFilter;
  String? _timetableStatusFilter;

  bool _loading = false;
  String? _error;
  String? _success;
  Timer? _successDismissTimer;

  void _cancelSuccessDismiss() {
    _successDismissTimer?.cancel();
    _successDismissTimer = null;
  }

  /// Green banner auto-clears so it does not sit on screen indefinitely.
  void _scheduleSuccessDismiss({Duration after = const Duration(seconds: 4)}) {
    _successDismissTimer?.cancel();
    _successDismissTimer = Timer(after, () {
      if (!mounted) return;
      setState(() => _success = null);
      _successDismissTimer = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = _ResultsRepository(ref.read(dioClientProvider));
    _loadYears();
  }

  @override
  void dispose() {
    _cancelSuccessDismiss();
    _tabController.dispose();
    super.dispose();
  }

  String? get _schoolId =>
      ref.read(authControllerProvider).valueOrNull?.schoolId;

  void _resetExamFilters() {
    setState(() {
      _selectedStandardId = null;
      _selectedExam = null;
      _selectedSection = null;
      _uploadStatusFilter = null;
      _timetableStatusFilter = null;
      _sections = [];
      _students = [];
      _distribution = [];
      _examHasUploadedResults = {};
      _examTimetableStatus = {};
      _distributionError = null;
      _error = null;
      _success = null;
    });
    _cancelSuccessDismiss();
  }

  bool get _canCreateExam {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return role == 'PRINCIPAL' ||
        role == 'STAFF_ADMIN' ||
        user.permissions.contains('result:create');
  }

  Future<void> _loadYears() async {
    if (_schoolId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final years = await _repo.listYears(_schoolId!);
      setState(() => _years = years);
      final preferredYearId = ref.read(activeAcademicYearProvider);
      final preferred = years.firstWhere(
        (y) => y['id']?.toString() == preferredYearId,
        orElse: () => <String, dynamic>{},
      );
      final active = years.firstWhere(
        (y) => y['is_active'] == true,
        orElse: () => years.isNotEmpty ? years.first : <String, dynamic>{},
      );
      final selected = preferred.isNotEmpty ? preferred : active;
      if (selected.isNotEmpty) {
        _selectedYearId = selected['id']?.toString();
        ref.read(activeAcademicYearProvider.notifier).setYear(_selectedYearId);
        await _loadStandards();
        await _loadExams();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStandards() async {
    if (_schoolId == null || _selectedYearId == null) return;
    try {
      final stds = await _repo.listStandards(_schoolId!, _selectedYearId!);
      setState(() => _standards = stds);
    } catch (_) {}
  }

  Future<void> _loadSections({String? academicYearId}) async {
    if (_selectedStandardId == null || _selectedStandardId!.trim().isEmpty) {
      setState(() {
        _sections = [];
        _selectedSection = null;
      });
      return;
    }
    try {
      final sections = await _repo.listSections(
        standardId: _selectedStandardId!,
        academicYearId: academicYearId ?? _selectedYearId,
      );
      if (!mounted) return;
      setState(() {
        _sections = sections;
        if (_selectedSection != null && !_sections.contains(_selectedSection)) {
          _selectedSection = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadExams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exams = await _repo.listExams(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
      );
      setState(() {
        _exams = exams;
        _selectedExam = null;
        _students = [];
        _distribution = [];
        _examHasUploadedResults = {};
        _examTimetableStatus = {};
        _distributionError = null;
      });
      await _loadExamStatusSummaries();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDistribution(_Exam exam,
      {bool switchToResultsTab = true}) async {
    setState(() {
      _selectedExam = exam;
      _distributionLoading = true;
      _distributionError = null;
      _distribution = [];
    });
    if (switchToResultsTab) {
      _tabController.animateTo(1);
    }
    try {
      final dist = await _repo.getDistribution(
        exam.id,
        section: _selectedSection,
      );
      if (!mounted) return;
      setState(() {
        _distribution = dist;
        _distributionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _distributionError = e.toString();
        _distribution = [];
      });
    } finally {
      if (mounted) setState(() => _distributionLoading = false);
    }
  }

  Future<void> _loadExamStatusSummaries() async {
    if (_exams.isEmpty) {
      if (!mounted) return;
      setState(() {
        _examHasUploadedResults = {};
      });
      return;
    }
    setState(() => _examStatusLoading = true);
    try {
      final uploadedExamIds = await _repo.listUploadedExamIds(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
        section: _selectedSection,
      );
      final hasUploadedMap = <String, bool>{
        for (final exam in _exams) exam.id: uploadedExamIds.contains(exam.id),
      };
      final timetableMap = <String, _TimetableStatus>{};
      for (final exam in _exams) {
        final stdId = exam.standardId;
        if (stdId != null && stdId.trim().isNotEmpty) {
          timetableMap[exam.id] = await _repo.getTimetableStatus(
                standardId: stdId,
                examId: exam.id,
                academicYearId: exam.academicYearId ?? _selectedYearId,
                section: _selectedSection,
              );
        }
      }
      if (!mounted) return;
      setState(() {
        _examHasUploadedResults = hasUploadedMap;
        _examTimetableStatus = timetableMap;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _examStatusLoading = false);
    }
  }

  /// Academic year for roster API calls: the selected exam's year when set, else UI year.
  String? _academicYearIdForSelectedExamRoster() {
    final e = _selectedExam;
    final fromExam = e?.academicYearId?.trim();
    if (fromExam != null && fromExam.isNotEmpty) return fromExam;
    return _selectedYearId;
  }

  Future<void> _loadStudentsForExam() async {
    final exam = _selectedExam;
    final standardId = exam?.standardId ?? _selectedStandardId;
    if (standardId == null || standardId.trim().isEmpty) {
      setState(() => _students = []);
      return;
    }
    final academicYearId = _academicYearIdForSelectedExamRoster();
    try {
      final students = await _repo.listStudents(
        standardId: standardId,
        academicYearId: academicYearId,
        section: _selectedSection,
      );
      if (!mounted) return;
      setState(() => _students = students);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _students = [];
        _error =
            'Could not load students for this class: ${e.toString()}';
      });
    }
  }

  Future<void> _openResultUploadWorkbench(_Exam exam) async {
    setState(() {
      _selectedExam = exam;
      _selectedStandardId = exam.standardId ?? _selectedStandardId;
      _distributionError = null;
      _error = null;
      // Workbench should list the full class roster; global result/timetable
      // filters apply to the exam list, not to hiding this table.
      _uploadStatusFilter = null;
      _timetableStatusFilter = null;
    });
    final rosterYear = exam.academicYearId?.trim().isNotEmpty == true
        ? exam.academicYearId!.trim()
        : _selectedYearId;
    await _loadSections(academicYearId: rosterYear);
    await _loadStudentsForExam();
    await _loadDistribution(exam, switchToResultsTab: true);
  }

  Future<void> _reloadWorkbench() async {
    final exam = _selectedExam;
    if (exam == null) return;
    await _loadStudentsForExam();
    await _loadDistribution(exam, switchToResultsTab: false);
  }

  /// Full roster for the upload tab: class list plus any students only present in distribution.
  List<_StudentLite> _mergedRosterForWorkbench() {
    final byId = <String, _StudentLite>{};
    for (final s in _students) {
      byId[s.id] = s;
    }
    for (final d in _distribution) {
      byId.putIfAbsent(
        d.studentId,
        () => _StudentLite(
          id: d.studentId,
          studentName: d.studentName,
          admissionNumber: d.admissionNumber,
          section: d.section,
        ),
      );
    }
    return byId.values.toList();
  }

  /// True when distribution includes entered marks (totals or subject lines).
  bool _hasEnteredMarks(_ResultStudent? u) {
    if (u == null) return false;
    if (u.totalMax > 0) return true;
    return u.subjects.isNotEmpty;
  }

  bool _hasAttachedReportFile(_ResultStudent? u) => u?.hasReportCard == true;

  /// Marks and/or report PDF counts as uploaded for filters and summary chips.
  bool _hasUploadedResultWork(_ResultStudent? u) =>
      _hasEnteredMarks(u) || _hasAttachedReportFile(u);

  /// Both marks entered and report PDF attached.
  bool _hasCompleteResultUpload(_ResultStudent? u) =>
      _hasEnteredMarks(u) && _hasAttachedReportFile(u);

  /// Exactly one of marks or report PDF (not both, not neither).
  bool _hasPartialResultUpload(_ResultStudent? u) {
    if (u == null) return false;
    final m = _hasEnteredMarks(u);
    final p = _hasAttachedReportFile(u);
    return (m || p) && !(m && p);
  }

  /// Exams visible under current academic year, class, result status, and timetable status filters.
  List<_Exam> _examsMatchingFilters() {
    return _exams.where((exam) {
      if (_selectedStandardId != null &&
          _selectedStandardId!.trim().isNotEmpty &&
          exam.standardId != _selectedStandardId) {
        return false;
      }
      final hasUploadedResults = _examHasUploadedResults[exam.id] ?? false;
      if (_uploadStatusFilter == 'UPLOADED' && !hasUploadedResults) return false;
      if (_uploadStatusFilter == 'PENDING' && hasUploadedResults) return false;
      // PARTIAL: no reliable exam-level signal without loading distribution per exam.

      final timetableUploaded = _examTimetableStatus[exam.id]?.isUploaded;
      if (_timetableStatusFilter == 'UPLOADED') return timetableUploaded == true;
      if (_timetableStatusFilter == 'PENDING') return timetableUploaded != true;
      return true;
    }).toList();
  }

  /// Keeps Upload Results in sync: clears selection if the exam no longer matches filters; otherwise reloads roster.
  Future<void> _reconcileWorkbenchWithFilters() async {
    if (_exams.isEmpty || !mounted) return;
    final matchingIds =
        _examsMatchingFilters().map((e) => e.id).toSet();
    if (_selectedExam != null && !matchingIds.contains(_selectedExam!.id)) {
      setState(() {
        _selectedExam = null;
        _students = [];
        _distribution = [];
        _distributionError = null;
      });
      return;
    }
    if (_selectedExam != null) {
      await _loadStudentsForExam();
      await _loadDistribution(_selectedExam!, switchToResultsTab: false);
    }
  }

  Future<void> _deleteExam(_Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exam'),
        content: Text(
          'Delete "${exam.name}" for ${exam.standardName ?? 'selected class'}?\n\n'
          'This deletes associated entered results for this exam as well.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.danger,
              foregroundColor: AdminColors.textOnPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    _cancelSuccessDismiss();
    try {
      await _repo.deleteExam(exam.id);
      await _loadExams();
      if (mounted) {
        setState(() => _success = 'Exam "${exam.name}" deleted successfully.');
        _scheduleSuccessDismiss();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateExamDialog() async {
    if (!_canCreateExam) return;
    final nameCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool submitting = false;

    Future<void> pickDate(bool isStart, StateSetter setLocal) async {
      final now = DateTime.now();
      final initial = (isStart ? startDate : endDate) ?? now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(2035, 12, 31),
      );
      if (picked == null) return;
      setLocal(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
        }
      });
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create Exam (All Classes)'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Exam Name',
                    hintText: 'e.g. Unit Test 1 / Semester / Finals',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickDate(true, setLocal),
                        child: Text(
                          startDate == null
                              ? 'Start Date'
                              : '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickDate(false, setLocal),
                        child: Text(
                          endDate == null
                              ? 'End Date'
                              : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Creates this exam for all classes in the selected academic year.',
                    style: TextStyle(
                        fontSize: 12, color: AdminColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      var dialogClosed = false;
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty || startDate == null || endDate == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please fill all fields')),
                          );
                        }
                        return;
                      }
                      if (endDate!.isBefore(startDate!)) {
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('End date must be on or after start date'),
                            ),
                          );
                        }
                        return;
                      }
                      setLocal(() => submitting = true);
                      try {
                        final payload = await _repo.createExamForAllClasses(
                          name: name,
                          startDate:
                              '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                          endDate:
                              '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                          academicYearId: _selectedYearId,
                        );
                        final createdCount =
                            (payload['created_count'] as num?)?.toInt() ?? 0;
                        final skippedCount =
                            (payload['skipped_count'] as num?)?.toInt() ?? 0;
                        if (mounted) {
                          dialogClosed = true;
                          Navigator.of(ctx).pop();
                          setState(() {
                            _success =
                                'Exam "$name" created for $createdCount class(es). '
                                'Skipped: $skippedCount.';
                            _error = null;
                          });
                          _scheduleSuccessDismiss();
                        }
                        await _loadExams();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                        if (ctx.mounted) {
                          setLocal(() => submitting = false);
                        }
                      } finally {
                        if (!dialogClosed && ctx.mounted) {
                          setLocal(() => submitting = false);
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _openEditResultDialog(_Exam exam, _ResultStudent student) async {
    final subjects = student.subjects;
    if (subjects.isEmpty) return;
    final marksCtrls = <TextEditingController>[];
    final maxCtrls = <TextEditingController>[];
    for (final s in subjects) {
      marksCtrls.add(TextEditingController(text: (s['marks_obtained'] ?? '').toString()));
      maxCtrls.add(TextEditingController(text: (s['max_marks'] ?? '').toString()));
    }
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Edit Results: ${student.studentName}'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(subjects.length, (i) {
                  final item = subjects[i];
                  final subjectName = item['subject_name']?.toString() ?? 'Subject';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(subjectName)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: marksCtrls[i],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Obtained',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCtrls[i],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Max',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final payload = <Map<String, dynamic>>[];
                      for (var i = 0; i < subjects.length; i++) {
                        final subj = subjects[i];
                        final marks = double.tryParse(marksCtrls[i].text.trim());
                        final max = double.tryParse(maxCtrls[i].text.trim());
                        if (marks == null || max == null || max <= 0 || marks < 0 || marks > max) {
                          if (mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please enter valid marks for all subjects')),
                            );
                          }
                          return;
                        }
                        payload.add({
                          'student_id': student.studentId,
                          'subject_id': subj['subject_id']?.toString() ?? '',
                          'marks_obtained': marks,
                          'max_marks': max,
                        });
                      }
                      setLocal(() => saving = true);
                      try {
                        await _repo.upsertResults(examId: exam.id, entries: payload);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (!mounted) return;
                        setState(() {
                          _success = 'Results updated for ${student.studentName}.';
                          _error = null;
                        });
                        _scheduleSuccessDismiss();
                        await _loadDistribution(exam, switchToResultsTab: false);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                        if (ctx.mounted) setLocal(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    for (final c in marksCtrls) {
      c.dispose();
    }
    for (final c in maxCtrls) {
      c.dispose();
    }
  }

  Future<void> _openUploadResultDialog(_Exam exam, _StudentLite student) async {
    final standardId = exam.standardId;
    if (standardId == null || standardId.trim().isEmpty) {
      setState(() => _error = 'Exam class is missing. Cannot upload results.');
      return;
    }

    List<_SubjectLite> subjects = const [];
    try {
      subjects = await _repo.listSubjects(standardId: standardId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      return;
    }
    if (subjects.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'No subjects found for this class.');
      return;
    }

    final marksCtrls = <TextEditingController>[];
    final maxCtrls = <TextEditingController>[];
    for (final _ in subjects) {
      marksCtrls.add(TextEditingController());
      maxCtrls.add(TextEditingController(text: '100'));
    }

    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Upload Results: ${student.studentName}'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(subjects.length, (i) {
                  final subject = subjects[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(subject.name)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: marksCtrls[i],
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Obtained',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCtrls[i],
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Max',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final payload = <Map<String, dynamic>>[];
                      for (var i = 0; i < subjects.length; i++) {
                        final marks = double.tryParse(marksCtrls[i].text.trim());
                        final max = double.tryParse(maxCtrls[i].text.trim());
                        if (marks == null ||
                            max == null ||
                            max <= 0 ||
                            marks < 0 ||
                            marks > max) {
                          if (mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter valid marks for all subjects'),
                              ),
                            );
                          }
                          return;
                        }
                        payload.add({
                          'student_id': student.id,
                          'subject_id': subjects[i].id,
                          'marks_obtained': marks,
                          'max_marks': max,
                        });
                      }
                      setLocal(() => saving = true);
                      try {
                        await _repo.upsertResults(examId: exam.id, entries: payload);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (!mounted) return;
                        setState(() {
                          _success = 'Results uploaded for ${student.studentName}.';
                          _error = null;
                        });
                        _scheduleSuccessDismiss();
                        await _reloadWorkbench();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                        if (ctx.mounted) setLocal(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
    for (final c in marksCtrls) {
      c.dispose();
    }
    for (final c in maxCtrls) {
      c.dispose();
    }
  }

  /// Same as document management / mobile: `file_picker` + in-memory bytes.
  /// Raw `dart:html` file inputs are unreliable inside Flutter web.
  Future<({String name, Uint8List bytes, String contentType})?>
      _pickFileBytesDocumentStyle({
    required List<String> allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final fileName = f.name;
    final ext = (f.extension ?? '').toLowerCase();
    final String contentType;
    switch (ext) {
      case 'pdf':
        contentType = 'application/pdf';
        break;
      case 'png':
        contentType = 'image/png';
        break;
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'doc':
        contentType = 'application/msword';
        break;
      case 'docx':
        contentType =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        break;
      default:
        final lower = fileName.toLowerCase();
        if (lower.endsWith('.pdf')) {
          contentType = 'application/pdf';
        } else if (lower.endsWith('.png')) {
          contentType = 'image/png';
        } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
          contentType = 'image/jpeg';
        } else if (lower.endsWith('.doc')) {
          contentType = 'application/msword';
        } else if (lower.endsWith('.docx')) {
          contentType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        } else {
          contentType = 'application/octet-stream';
        }
    }

    return (name: fileName, bytes: bytes, contentType: contentType);
  }

  Future<void> _attachResultFile({
    required _Exam exam,
    required _StudentLite student,
  }) async {
    final picked = await _pickFileBytesDocumentStyle(
      allowedExtensions: const ['pdf'],
    );
    if (picked == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No file selected, or the file could not be read. '
            'Choose a PDF under the size limit.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    _cancelSuccessDismiss();
    try {
      await _repo.uploadReportCard(
        studentId: student.id,
        examId: exam.id,
        fileName: picked.name,
        fileBytes: picked.bytes,
        contentType: picked.contentType,
      );
      if (!mounted) return;
      setState(() {
        _success = 'Result file attached for ${student.studentName}.';
      });
      _scheduleSuccessDismiss();
      await _reloadWorkbench();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUploadScheduleDialog({_Exam? preferredExam}) async {
    final prefStd = preferredExam?.standardId?.trim();
    String? localStandardId =
        (prefStd != null && prefStd.isNotEmpty) ? prefStd : _selectedStandardId;
    String? localSection = _selectedSection;
    String? localExamId = preferredExam?.id ?? _selectedExam?.id;
    List<String> localSections = List<String>.from(_sections);
    if (preferredExam != null &&
        prefStd != null &&
        prefStd.isNotEmpty) {
      try {
        localSections = await _repo.listSections(
          standardId: prefStd,
          academicYearId: _selectedYearId,
        );
      } catch (_) {}
    }
    List<_Exam> localExamOptions = _exams;
    String fileName = '';
    Uint8List? fileBytes;
    String contentType = 'application/pdf';
    bool uploading = false;

    if (localStandardId != null && localStandardId.trim().isNotEmpty) {
      localExamOptions = _exams
          .where((e) => e.standardId == localStandardId)
          .toList();
      if (localExamId != null &&
          !localExamOptions.any((e) => e.id == localExamId)) {
        localExamId = null;
      }
    } else {
      localExamOptions = const [];
      localExamId = null;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Upload Exam Schedule'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String?>(
                  value: localStandardId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Select class'),
                    ),
                    ..._standards.map((s) => DropdownMenuItem<String?>(
                          value: s['id']?.toString(),
                          child: Text(s['name']?.toString() ?? '-'),
                        )),
                  ],
                  onChanged: uploading
                      ? null
                      : (v) async {
                          setLocal(() {
                            localStandardId = v;
                            localSection = null;
                            localSections = [];
                            localExamId = null;
                            localExamOptions = _exams
                                .where((e) => e.standardId == localStandardId)
                                .toList();
                          });
                          if (v != null && v.trim().isNotEmpty) {
                            try {
                              final sections = await _repo.listSections(
                                standardId: v,
                                academicYearId: _selectedYearId,
                              );
                              if (ctx.mounted) {
                                setLocal(() => localSections = sections);
                              }
                            } catch (_) {}
                          }
                        },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: localSection,
                  decoration: const InputDecoration(
                    labelText: 'Section (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Sections'),
                    ),
                    ...localSections.map((s) => DropdownMenuItem<String?>(
                          value: s,
                          child: Text(s),
                        )),
                  ],
                  onChanged: uploading
                      ? null
                      : (v) => setLocal(() => localSection = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: localExamId,
                  decoration: const InputDecoration(
                    labelText: 'Exam',
                    helperText:
                        'Each exam has its own schedule file (class daily timetable is separate).',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Select exam'),
                    ),
                    ...localExamOptions.map((e) => DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(e.name),
                        )),
                  ],
                  onChanged: uploading
                      ? null
                      : (v) => setLocal(() => localExamId = v),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 14),
                  label: Text(fileName.isEmpty ? 'Choose File' : fileName),
                  onPressed: uploading
                      ? null
                      : () async {
                          final picked = await _pickFileBytesDocumentStyle(
                            allowedExtensions: const [
                              'pdf',
                              'doc',
                              'docx',
                              'jpg',
                              'jpeg',
                              'png',
                            ],
                          );
                          if (!ctx.mounted) return;
                          if (picked == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No file selected, or the file could not be read. '
                                  'Try a PDF or image under the size limit.',
                                ),
                              ),
                            );
                            return;
                          }
                          setLocal(() {
                            fileName = picked.name;
                            contentType = picked.contentType;
                            fileBytes = picked.bytes;
                          });
                        },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: uploading
                  ? null
                  : () async {
                      if (localStandardId == null || localStandardId!.trim().isEmpty) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please select class')),
                          );
                        }
                        return;
                      }
                      if (fileBytes == null || fileBytes!.isEmpty) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Choose a schedule file (PDF, Word, or image) first.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      if (localExamId == null || localExamId!.trim().isEmpty) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Select which exam this schedule file belongs to.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      setLocal(() => uploading = true);
                      try {
                        String? examYear;
                        for (final ex in _exams) {
                          if (ex.id == localExamId) {
                            examYear = ex.academicYearId;
                            break;
                          }
                        }
                        await _repo.uploadSchedule(
                          standardId: localStandardId!,
                          examId: localExamId!,
                          academicYearId: examYear ?? _selectedYearId,
                          section: localSection,
                          fileName: fileName,
                          fileBytes: fileBytes!,
                          contentType: contentType,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (!mounted) return;
                        setState(() {
                          _success = 'Exam schedule file uploaded successfully.';
                          _error = null;
                          _selectedStandardId = localStandardId;
                          _selectedSection = localSection;
                        });
                        _scheduleSuccessDismiss();
                        await _loadSections();
                        await _loadExams();
                        await _loadExamStatusSummaries();
                      } catch (e) {
                        if (ctx.mounted) {
                          setLocal(() => uploading = false);
                        }
                        if (mounted) {
                          setState(() => _error = e.toString());
                        }
                      }
                    },
              child: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Examination',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.pagePadding,
              AdminSpacing.pagePadding,
              AdminSpacing.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            const AdminPageHeader(
              title: 'Examination',
              subtitle:
                  'Manage exam-wise result uploads by class, section, and pending/uploaded status.',
            ),
            AdminFilterCard(
              onReset: _resetExamFilters,
              child: Wrap(
                spacing: AdminSpacing.sm,
                runSpacing: AdminSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    value: _selectedYearId,
                    items: _years
                        .map((y) => DropdownMenuItem<String>(
                            value: y['id']?.toString(),
                            child: Text(y['name']?.toString() ?? '')))
                        .toList(),
                    onChanged: (v) async {
                      setState(() {
                        _selectedYearId = v;
                        _selectedExam = null;
                        _selectedSection = null;
                        _uploadStatusFilter = null;
                        _timetableStatusFilter = null;
                        _sections = [];
                        _students = [];
                        _distribution = [];
                        _examHasUploadedResults = {};
                        _examTimetableStatus = {};
                        _distributionError = null;
                      });
                      ref.read(activeAcademicYearProvider.notifier).setYear(v);
                      await _loadStandards();
                      if (_selectedStandardId != null &&
                          _selectedStandardId!.trim().isNotEmpty) {
                        await _loadSections();
                      }
                      await _loadExams();
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Class (optional)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    value: _selectedStandardId,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All Classes')),
                      ..._standards.map((s) => DropdownMenuItem<String?>(
                          value: s['id']?.toString(),
                          child: Text(s['name']?.toString() ?? ''))),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _selectedStandardId = v;
                        _selectedSection = null;
                        _uploadStatusFilter = null;
                        _timetableStatusFilter = null;
                        _selectedExam = null;
                        _students = [];
                        _distribution = [];
                        _examHasUploadedResults = {};
                        _distributionError = null;
                      });
                      await _loadSections();
                      await _loadExams();
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Section (optional)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    value: _selectedSection,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All Sections')),
                      ..._sections.map((s) => DropdownMenuItem<String?>(
                          value: s, child: Text(s))),
                    ],
                    onChanged: (v) async {
                      setState(() => _selectedSection = v);
                      await _loadExamStatusSummaries();
                      await _loadStudentsForExam();
                      if (_selectedExam != null) {
                        await _loadDistribution(_selectedExam!,
                            switchToResultsTab: false);
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Result Status',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    value: _uploadStatusFilter,
                    items: const [
                      DropdownMenuItem<String?>(
                          value: null, child: Text('All')),
                      DropdownMenuItem<String?>(
                          value: 'UPLOADED', child: Text('Uploaded Results')),
                      DropdownMenuItem<String?>(
                          value: 'PARTIAL',
                          child: Text('Partial')),
                      DropdownMenuItem<String?>(
                          value: 'PENDING', child: Text('Pending Upload')),
                    ],
                    onChanged: (v) async {
                      setState(() => _uploadStatusFilter = v);
                      await _reconcileWorkbenchWithFilters();
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Exam schedule status',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    value: _timetableStatusFilter,
                    items: const [
                      DropdownMenuItem<String?>(
                          value: null, child: Text('All')),
                      DropdownMenuItem<String?>(
                          value: 'UPLOADED', child: Text('Uploaded')),
                      DropdownMenuItem<String?>(
                          value: 'PENDING', child: Text('Pending')),
                    ],
                    onChanged: (v) async {
                      setState(() => _timetableStatusFilter = v);
                      await _reconcileWorkbenchWithFilters();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AdminColors.textPrimary,
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  icon: _loading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AdminColors.primaryAction,
                          ),
                        )
                      : Icon(
                          Icons.search,
                          size: 18,
                          color: AdminColors.primaryAction,
                        ),
                  label: const Text('Load exams'),
                  onPressed: _loading
                      ? null
                      : () async {
                          await _loadSections();
                          await _loadExams();
                          await _loadStudentsForExam();
                          if (_selectedExam != null) {
                            await _loadDistribution(_selectedExam!,
                                switchToResultsTab: false);
                          }
                        },
                ),
                if (_canCreateExam)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Create Exam (All Classes)'),
                    onPressed: _openCreateExamDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AdminSpacing.sm),

            // ── Status messages ──────────────────────────────────────────
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
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
            if (_success != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: Material(
                  color: AdminColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: SelectableText(
                      _success!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AdminColors.success,
                      ),
                    ),
                  ),
                ),
              ),
            if (_examStatusLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: AdminSpacing.sm),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            // ── Tabs ─────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: const Color(0x00000000),
              tabs: [
                const Tab(text: 'Exam List'),
                Tab(
                    text: _selectedExam != null
                        ? 'Upload Results: ${_selectedExam!.name}'
                        : 'Upload Results'),
                const Tab(text: 'Exam Schedule'),
              ],
            ),
            const SizedBox(height: AdminSpacing.xs),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AdminSpacing.pagePadding,
                    0,
                    AdminSpacing.pagePadding,
                    AdminSpacing.pagePadding,
                  ),
                  child: _buildExamListTab(),
                ),
                _buildDistributionTab(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AdminSpacing.pagePadding,
                    0,
                    AdminSpacing.pagePadding,
                    AdminSpacing.pagePadding,
                  ),
                  child: _buildTimetableTab(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Exam List Tab ───────────────────────────────────────────────────────────

  Widget _buildExamListTab() {
    final filteredExams = _examsMatchingFilters();

    if (filteredExams.isEmpty && !_loading) {
      return const AdminEmptyState(
        icon: Icons.quiz_outlined,
        title: 'No exams loaded',
        message:
            'Try changing academic year/class/section or result/exam schedule filters.',
      );
    }
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
        headingRowColor: adminTableHeadingRowColor(),
        horizontalMargin: AdminSpacing.md,
        columnSpacing: AdminSpacing.lg,
        columns: [
          const DataColumn(label: Text('Exam Name')),
          const DataColumn(label: Text('Class')),
          const DataColumn(label: Text('Start')),
          const DataColumn(label: Text('End')),
          const DataColumn(label: Text('Results')),
          const DataColumn(label: Text('Exam schedule')),
          const DataColumn(label: Text('Uploaded by')),
          const DataColumn(label: Text('Upload Results')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: filteredExams.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final exam = entry.value;
          final hasResults = _examHasUploadedResults[exam.id] ?? false;
          final tt = _examTimetableStatus[exam.id];
          final timetableUploaded = tt?.isUploaded == true;
          final stdOk = exam.standardId != null &&
              exam.standardId!.trim().isNotEmpty;
          return DataRow(
            color: adminDataRowColor(rowIndex),
            cells: [
              DataCell(Text(exam.name,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(exam.standardName ?? '-')),
              DataCell(Text(exam.startDate ?? '-')),
              DataCell(Text(exam.endDate ?? '-')),
              DataCell(
                Chip(
                  label: Text(hasResults ? 'Uploaded' : 'Pending'),
                  backgroundColor: hasResults
                      ? AdminColors.success.withValues(alpha: 0.12)
                      : const Color(0xFFEA580C).withValues(alpha: 0.12),
                ),
              ),
              DataCell(
                Chip(
                  label: Text(timetableUploaded ? 'Uploaded' : 'Pending'),
                  backgroundColor: timetableUploaded
                      ? AdminColors.success.withValues(alpha: 0.12)
                      : const Color(0xFFEA580C).withValues(alpha: 0.12),
                ),
              ),
              DataCell(
                Builder(
                  builder: (ctx) {
                    final name = (tt?.uploadedByName ?? '').trim();
                    return Text(
                      timetableUploaded && name.isNotEmpty ? name : '—',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: AdminColors.textSecondary,
                          ),
                    );
                  },
                ),
              ),
              DataCell(
                _canCreateExam && stdOk
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        icon: const Icon(Icons.upload_outlined, size: 18),
                        label: const Text('Upload Results'),
                        onPressed: () => _openResultUploadWorkbench(exam),
                      )
                    : const Text('—'),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_canCreateExam)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AdminColors.danger),
                        tooltip: 'Delete exam',
                        onPressed: () => _deleteExam(exam),
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
        ),
      ),
    );
  }

  /// Opens the presigned timetable URL in a new browser tab (no copy/paste dialog).
  void _viewTimetableLink(String url) {
    final u = url.trim();
    if (u.isEmpty) return;
    html.window.open(u, '_blank');
  }

  Future<void> _deleteTimetableForExam(_Exam exam) async {
    final stdId = exam.standardId?.trim();
    if (stdId == null || stdId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exam schedule file'),
        content: Text(
          'Remove the uploaded exam schedule for "${exam.name}" '
          '(${exam.standardName ?? 'this class'})? Other exams are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteTimetable(
        standardId: stdId,
        examId: exam.id,
        academicYearId: exam.academicYearId ?? _selectedYearId,
        section: _selectedSection,
      );
      if (!mounted) return;
      setState(() {
        _success = 'Exam schedule file removed.';
        _error = null;
      });
      _scheduleSuccessDismiss();
      await _loadExamStatusSummaries();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _buildTimetableTab() {
    final rows = _examsMatchingFilters();

    if (rows.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.schedule_outlined,
        title: 'No exam schedule rows',
        message: 'Try changing class/section filters or load exams.',
      );
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
        headingRowColor: adminTableHeadingRowColor(),
        horizontalMargin: AdminSpacing.md,
        columnSpacing: AdminSpacing.lg,
        columns: const [
          DataColumn(label: Text('Exam')),
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Section')),
          DataColumn(label: Text('Exam schedule')),
          DataColumn(label: Text('Uploaded by')),
          DataColumn(label: Text('Upload')),
          DataColumn(label: Text('Actions')),
        ],
        dataRowMinHeight: 52,
        dataRowMaxHeight: 80,
        rows: rows.asMap().entries.map((entry) {
          final exam = entry.value;
          final tt = _examTimetableStatus[exam.id];
          final uploaded = tt?.isUploaded == true;
          final stdId = exam.standardId?.trim();
          final hasStd = stdId != null && stdId.isNotEmpty;
          final byName = (tt?.uploadedByName ?? '').trim();
          return DataRow(
            color: adminDataRowColor(entry.key),
            cells: [
              DataCell(Text(exam.name)),
              DataCell(Text(exam.standardName ?? '-')),
              DataCell(Text(_selectedSection ?? 'All')),
              DataCell(
                Chip(
                  label: Text(uploaded ? 'Uploaded' : 'Pending'),
                  backgroundColor: uploaded
                      ? AdminColors.success.withValues(alpha: 0.12)
                      : const Color(0xFFEA580C).withValues(alpha: 0.12),
                ),
              ),
              DataCell(
                Text(
                  uploaded && byName.isNotEmpty ? byName : '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AdminColors.textSecondary,
                  ),
                ),
              ),
              DataCell(
                hasStd
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onPressed: () => _openUploadScheduleDialog(
                            preferredExam: exam,
                          ),
                          icon: Icon(
                            uploaded
                                ? Icons.refresh_outlined
                                : Icons.upload_file_outlined,
                            size: 18,
                          ),
                          label: Text(uploaded ? 'Re-upload' : 'Upload'),
                        ),
                      )
                    : const Text('—'),
              ),
              DataCell(
                hasStd
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                              ),
                              onPressed: uploaded &&
                                      (tt?.fileUrl ?? '').isNotEmpty
                                  ? () => _viewTimetableLink(tt!.fileUrl!)
                                  : null,
                              icon: const Icon(
                                Icons.open_in_new_outlined,
                                size: 18,
                              ),
                              label: const Text('View'),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: uploaded
                                  ? 'Re-upload schedule'
                                  : 'Upload schedule',
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () => _openUploadScheduleDialog(
                                preferredExam: exam,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: uploaded
                                  ? 'Delete schedule file'
                                  : 'No file to delete',
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: uploaded
                                    ? AdminColors.danger
                                    : AdminColors.textSecondary
                                        .withValues(alpha: 0.35),
                              ),
                              onPressed: uploaded
                                  ? () => _deleteTimetableForExam(exam)
                                  : null,
                            ),
                          ],
                        ),
                      )
                    : const Text('—'),
              ),
            ],
          );
        }).toList(),
        ),
      ),
    );
  }

  // ── Distribution Tab ────────────────────────────────────────────────────────

  Widget _buildDistributionTab() {
    if (_selectedExam == null) {
      return const AdminEmptyState(
        icon: Icons.upload_file_outlined,
        title: 'No exam selected',
        message:
            'Open the Exam List tab and use the Upload Results action for an exam.',
      );
    }
    if (_distributionLoading) {
      return const AdminLoadingPlaceholder(
        message: 'Loading upload workbench…',
        height: 280,
      );
    }
    if (_distributionError != null) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: AdminColors.danger.withValues(alpha: 0.85)),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                'Could not load upload status',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AdminSpacing.xs),
              SelectableText(
                _distributionError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AdminColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AdminSpacing.md),
              FilledButton.icon(
                onPressed: () => _loadDistribution(_selectedExam!,
                    switchToResultsTab: false),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final uploadedByStudentId = <String, _ResultStudent>{
      for (final item in _distribution) item.studentId: item,
    };
    final roster = _mergedRosterForWorkbench();

    final rows = roster.where((student) {
      final u = uploadedByStudentId[student.id];
      final hasWork = _hasUploadedResultWork(u);
      if (_uploadStatusFilter == 'UPLOADED') return hasWork;
      if (_uploadStatusFilter == 'PENDING') return !hasWork;
      if (_uploadStatusFilter == 'PARTIAL') return _hasPartialResultUpload(u);
      return true;
    }).toList()
      ..sort((a, b) => a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

    if (rows.isEmpty) {
      final fullRoster = _mergedRosterForWorkbench();
      if (fullRoster.isEmpty &&
          _uploadStatusFilter == null &&
          _selectedExam != null) {
        return AdminEmptyState(
          icon: Icons.groups_outlined,
          title: 'No students in this roster',
          message:
              'No students were returned for ${_selectedExam!.standardName ?? "this class"}'
              '${_selectedSection != null && _selectedSection!.trim().isNotEmpty ? ", section $_selectedSection" : ""}'
              ' in the selected academic year. Adjust the Section filter (try “All Sections”) '
              'or academic year if this exam belongs to a different year.',
        );
      }
      return const AdminEmptyState(
        icon: Icons.edit_note_outlined,
        title: 'No rows for selected filters',
        message: 'Try changing class, section, or result status filters.',
      );
    }

    final completeRows = rows
        .where((r) =>
            _hasCompleteResultUpload(uploadedByStudentId[r.id]))
        .length;
    final partialRows = rows
        .where((r) => _hasPartialResultUpload(uploadedByStudentId[r.id]))
        .length;
    final pendingRows = rows
        .where((r) =>
            !_hasUploadedResultWork(uploadedByStudentId[r.id]))
        .length;

    final uploadedDistributionRows = <_ResultStudent>[
      for (final student in rows)
        if (_hasEnteredMarks(uploadedByStudentId[student.id]))
          uploadedByStudentId[student.id]!,
    ];

    final avg = uploadedDistributionRows.isEmpty
        ? 0.0
        : uploadedDistributionRows
                .map((s) => s.overallPercentage)
                .reduce((a, b) => a + b) /
            uploadedDistributionRows.length;
    final passCount =
        uploadedDistributionRows.where((s) => s.overallPercentage >= 35).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.sm,
              0,
              AdminSpacing.sm,
              AdminSpacing.sm,
            ),
            child: Wrap(
              spacing: AdminSpacing.sm,
              children: [
                Chip(
                    label: Text('Total: ${rows.length}'),
                    backgroundColor: AdminColors.borderSubtle),
                Chip(
                    label: Text('Complete (marks + PDF): $completeRows'),
                    backgroundColor:
                        AdminColors.success.withValues(alpha: 0.18)),
                Chip(
                    label: Text('Uploaded partially: $partialRows'),
                    backgroundColor:
                        const Color(0xFFCA8A04).withValues(alpha: 0.14)),
                Chip(
                    label: Text('Pending: $pendingRows'),
                    backgroundColor:
                        const Color(0xFFEA580C).withValues(alpha: 0.12)),
                Chip(
                    label: Text('Avg (uploaded): ${avg.toStringAsFixed(1)}%'),
                    backgroundColor: avg >= 60
                        ? AdminColors.success.withValues(alpha: 0.12)
                        : const Color(0xFFEA580C).withValues(alpha: 0.12)),
                Chip(
                    label: Text('Passed (uploaded): $passCount'),
                    backgroundColor:
                        AdminColors.success.withValues(alpha: 0.12)),
                Chip(
                    label: Text(
                        'Failed (uploaded): ${uploadedDistributionRows.length - passCount}'),
                    backgroundColor: AdminColors.dangerSurface),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: DataTable(
                      headingRowColor: adminTableHeadingRowColor(),
                      horizontalMargin: 12,
                      columnSpacing: 16,
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 88,
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Adm. No.')),
                        DataColumn(label: Text('Student')),
                        DataColumn(label: Text('Section')),
                        DataColumn(label: Text('Result status')),
                        DataColumn(label: Text('Result File')),
                        DataColumn(label: Text('Upload Results')),
                        DataColumn(label: Text('Attach file')),
                      ],
                      rows: rows.asMap().entries.map((entry) {
                        final rank = entry.key + 1;
                        final student = entry.value;
                        final uploaded = uploadedByStudentId[student.id];
                        final hasMarks = _hasEnteredMarks(uploaded);
                        final hasResultFile =
                            uploaded?.hasReportCard == true;
                        final hasWork = hasMarks || hasResultFile;
                        final bothDone = hasMarks && hasResultFile;
                        final uploadStyle = TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                        return DataRow(
                          color: adminDataRowColor(entry.key),
                          cells: [
                            DataCell(Text('$rank',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.textMuted))),
                            DataCell(Text(student.admissionNumber)),
                            DataCell(Text(student.studentName)),
                            DataCell(Text(student.section ?? '-')),
                            DataCell(
                              Tooltip(
                                message: !hasWork
                                    ? 'Enter marks (Upload) and/or attach a PDF report when ready.'
                                    : bothDone
                                        ? 'Marks and report file are both on file.'
                                        : hasMarks
                                            ? '${uploaded!.uploadedByLabel} You can still attach a PDF.'
                                            : 'Report PDF on file. Add marks with Upload when ready.',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasWork
                                            ? AdminColors.success
                                                .withValues(alpha: 0.1)
                                            : const Color(0xFFEA580C)
                                                .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        !hasWork
                                            ? 'Pending upload'
                                            : bothDone
                                                ? 'Uploaded'
                                                : 'Uploaded (partial)',
                                        style: TextStyle(
                                          color: hasWork
                                              ? AdminColors.success
                                              : const Color(0xFFEA580C),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Marks: ${hasMarks ? "Yes" : "No"} · '
                                      'PDF: ${hasResultFile ? "Yes" : "No"}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: AdminColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (hasMarks && uploaded != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        uploaded.uploadedByLabel,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: AdminColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    label: Text(hasResultFile
                                        ? 'Attached'
                                        : 'Pending'),
                                    backgroundColor: hasResultFile
                                        ? AdminColors.success
                                            .withValues(alpha: 0.12)
                                        : const Color(0xFFEA580C)
                                            .withValues(alpha: 0.12),
                                  ),
                                  if ((uploaded?.reportCardUrl ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    IconButton(
                                      tooltip: 'View report PDF',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      icon: Icon(
                                        Icons.open_in_new_outlined,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      onPressed: () {
                                        final u = uploaded!.reportCardUrl!
                                            .trim();
                                        if (u.isNotEmpty) {
                                          html.window.open(u, '_blank');
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  style: uploadStyle,
                                  icon: Icon(
                                    hasMarks
                                        ? Icons.refresh_outlined
                                        : Icons.upload_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    hasMarks ? 'Reupload' : 'Upload',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: _canCreateExam
                                      ? () => hasMarks
                                          ? _openEditResultDialog(
                                              _selectedExam!, uploaded!)
                                          : _openUploadResultDialog(
                                              _selectedExam!, student)
                                      : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  style: uploadStyle,
                                  icon: Icon(
                                    hasResultFile
                                        ? Icons.attach_file_outlined
                                        : Icons.upload_file_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    hasResultFile ? 'Replace' : 'Attach',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: _canCreateExam
                                      ? () => _attachResultFile(
                                            exam: _selectedExam!,
                                            student: student,
                                          )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
