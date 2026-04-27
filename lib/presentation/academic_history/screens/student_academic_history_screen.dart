// lib/presentation/academic_history/screens/student_academic_history_screen.dart  [Mobile App]
// Phase 7 — Student Academic History.
// Displays a student's full year-by-year academic record:
//   class, section, roll number, status, joined date, left date.
// Access rules enforced by backend:
//   STUDENT: own history only.
//   PARENT:  their linked child.
//   TEACHER / PRINCIPAL: any student in their school.
//
// API: GET /enrollments/history/{studentId}
//      Returns StudentAcademicHistoryResponse:
//        { student_id, admission_number, student_name,
//          history: [ { id, standard_name, section_name, roll_number,
//                       status, joined_on, left_on, exit_reason,
//                       academic_year_name, admission_type } ] }
//
// This screen is navigated to from the student profile screen.
// Call: context.push('/academic-history/$studentId');

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

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
        status: j['status']?.toString() ?? '',
        admissionType: j['admission_type'] as String?,
        joinedOn: j['joined_on'] as String?,
        leftOn: j['left_on'] as String?,
        exitReason: j['exit_reason'] as String?,
      );

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'PROMOTED':
        return Colors.blue;
      case 'GRADUATED':
      case 'COMPLETED':
        return Colors.teal;
      case 'REPEATED':
        return Colors.orange;
      case 'LEFT':
      case 'TRANSFERRED':
        return Colors.red;
      case 'HOLD':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Icons.check_circle_outline;
      case 'PROMOTED':
        return Icons.trending_up;
      case 'GRADUATED':
      case 'COMPLETED':
        return Icons.school_outlined;
      case 'REPEATED':
        return Icons.replay_outlined;
      case 'LEFT':
        return Icons.exit_to_app_outlined;
      case 'TRANSFERRED':
        return Icons.swap_horiz_outlined;
      case 'HOLD':
        return Icons.pause_circle_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  String get admissionTypeLabel {
    switch ((admissionType ?? '').toUpperCase()) {
      case 'NEW_ADMISSION':
        return 'New Admission';
      case 'MID_YEAR':
        return 'Mid-Year Join';
      case 'TRANSFER_IN':
        return 'Transfer In';
      case 'READMISSION':
        return 'Readmission';
      default:
        return admissionType ?? '-';
    }
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class _HistoryRepository {
  _HistoryRepository(this._dio);
  final DioClient _dio;

  Future<Map<String, dynamic>> fetchHistory(String studentId) async {
    final resp = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.enrollmentHistory(studentId),
    );
    return resp.data ?? {};
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class StudentAcademicHistoryScreen extends ConsumerStatefulWidget {
  const StudentAcademicHistoryScreen({required this.studentId, super.key});

  final String studentId;

  @override
  ConsumerState<StudentAcademicHistoryScreen> createState() =>
      _StudentAcademicHistoryScreenState();
}

class _StudentAcademicHistoryScreenState
    extends ConsumerState<StudentAcademicHistoryScreen> {
  late final _HistoryRepository _repo;

  bool _loading = true;
  String? _error;
  String? _studentName;
  String? _admissionNumber;
  List<_HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _repo = _HistoryRepository(ref.read(dioClientProvider));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchHistory(widget.studentId);
      final raw = ((data['history'] as List?) ?? []);
      setState(() {
        _studentName = data['student_name'] as String?;
        _admissionNumber = data['admission_number'] as String?;
        _history = raw
            .map((e) =>
                _HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _studentName != null
              ? 'Academic History — $_studentName'
              : 'Academic History',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _history.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_edu_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No academic history found.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // Header card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      child: Text(
                                        (_studentName ?? '?')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _studentName ?? '-',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Admission No.: ${_admissionNumber ?? '-'}',
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13),
                                        ),
                                        Text(
                                          '${_history.length} academic year(s) on record',
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Timeline header
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Text(
                              'Year-by-Year Record',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),

                        // Timeline entries
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final entry = _history[index];
                              final isLast = index == _history.length - 1;
                              return _TimelineCard(
                                entry: entry,
                                isLast: isLast,
                                fmt: _fmt,
                              );
                            },
                            childCount: _history.length,
                          ),
                        ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 32),
                        ),
                      ],
                    ),
    );
  }
}

// ── Timeline Card ─────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.entry,
    required this.isLast,
    required this.fmt,
  });

  final _HistoryEntry entry;
  final bool isLast;
  final String Function(String?) fmt;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 48,
            child: Column(
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      entry.statusColor.withOpacity(0.15),
                  child: Icon(entry.statusIcon,
                      size: 16, color: entry.statusColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                      margin:
                          const EdgeInsets.only(top: 4, bottom: 0),
                    ),
                  ),
              ],
            ),
          ),

          // Card content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: 16, bottom: isLast ? 16 : 8, top: 8),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year & Status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.academicYearName ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: entry.statusColor
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: entry.statusColor
                                      .withOpacity(0.4)),
                            ),
                            child: Text(
                              entry.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: entry.statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Class & Section
                      _InfoRow(
                        icon: Icons.class_outlined,
                        label: 'Class',
                        value:
                            '${entry.standardName ?? '-'} — Section ${entry.sectionName ?? '-'}',
                      ),
                      if (entry.rollNumber != null)
                        _InfoRow(
                          icon: Icons.numbers_outlined,
                          label: 'Roll No.',
                          value: entry.rollNumber!,
                        ),
                      _InfoRow(
                        icon: Icons.login_outlined,
                        label: 'Joined',
                        value: fmt(entry.joinedOn),
                      ),
                      if (entry.admissionType != null)
                        _InfoRow(
                          icon: Icons.info_outline,
                          label: 'Admission Type',
                          value: entry.admissionTypeLabel,
                        ),
                      if (entry.leftOn != null)
                        _InfoRow(
                          icon: Icons.logout_outlined,
                          label: 'Left On',
                          value: fmt(entry.leftOn),
                        ),
                      if (entry.exitReason != null &&
                          entry.exitReason!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.notes_outlined,
                          label: 'Reason',
                          value: entry.exitReason!,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}