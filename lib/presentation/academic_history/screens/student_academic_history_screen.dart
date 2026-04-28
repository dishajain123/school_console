// lib/presentation/academic_history/screens/student_academic_history_screen.dart  [Mobile App]
// Phase 7 / 14 — Student Academic History.
// Displays a student's full year-by-year academic record:
//   class, section, roll number, status, joined date, left date, transfers.
//
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
// Navigation: context.push('/academic-history/$studentId')
// The studentId param is passed via go_router path parameter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

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

// ── Screen ────────────────────────────────────────────────────────────────────

class StudentAcademicHistoryScreen extends ConsumerStatefulWidget {
  const StudentAcademicHistoryScreen({
    super.key,
    required this.studentId,
  });

  final String studentId;

  @override
  ConsumerState<StudentAcademicHistoryScreen> createState() =>
      _StudentAcademicHistoryScreenState();
}

class _StudentAcademicHistoryScreenState
    extends ConsumerState<StudentAcademicHistoryScreen> {
  List<_HistoryEntry> _history = [];
  String? _studentName;
  String? _admissionNumber;
  bool _loading = true;
  String? _error;

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
      final dio = ref.read(dioClientProvider);
      final resp = await dio.dio.get<Map<String, dynamic>>(
        '/enrollments/history/${widget.studentId}',
      );
      final data = resp.data!;
      final historyList = (data['history'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _studentName = data['student_name'] as String?;
          _admissionNumber = data['admission_number'] as String?;
          _history = historyList
              .map((e) => _HistoryEntry.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
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

  String _formatAdmissionType(String? t) {
    switch ((t ?? '').toUpperCase()) {
      case 'NEW_ADMISSION':
        return 'New Admission';
      case 'MID_YEAR':
        return 'Mid-Year Join';
      case 'TRANSFER_IN':
        return 'Transfer In';
      case 'READMISSION':
        return 'Re-admission';
      default:
        return t ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade400, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
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
                            style:
                                TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // ── Header card ────────────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                                      backgroundColor: theme
                                          .colorScheme.primaryContainer,
                                      child: Text(
                                        (_studentName ?? '?')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _studentName ?? '—',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                          if (_admissionNumber != null)
                                            Text(
                                              'Adm. No: $_admissionNumber',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: Colors.grey),
                                            ),
                                          Text(
                                            '${_history.length} academic year(s) on record',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── Timeline ───────────────────────────────────────
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final entry = _history[index];
                                final isLast =
                                    index == _history.length - 1;
                                return _TimelineItem(
                                  entry: entry,
                                  isLast: isLast,
                                  statusColor:
                                      _statusColor(entry.status),
                                  formatAdmissionType:
                                      _formatAdmissionType,
                                );
                              },
                              childCount: _history.length,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// ── Timeline Item widget ───────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isLast,
    required this.statusColor,
    required this.formatAdmissionType,
  });

  final _HistoryEntry entry;
  final bool isLast;
  final Color statusColor;
  final String Function(String?) formatAdmissionType;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline line + dot ────────────────────────────────────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Content card ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year + Class
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.academicYearName ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.standardName ?? '—'} ${entry.sectionName != null ? '· Section ${entry.sectionName}' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                      ),

                      // Details row
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (entry.rollNumber != null)
                            _DetailChip(
                              icon: Icons.tag,
                              label: 'Roll ${entry.rollNumber}',
                            ),
                          if (entry.admissionType != null)
                            _DetailChip(
                              icon: Icons.input,
                              label: formatAdmissionType(entry.admissionType),
                            ),
                          if (entry.joinedOn != null)
                            _DetailChip(
                              icon: Icons.login,
                              label: entry.joinedOn!,
                            ),
                          if (entry.leftOn != null)
                            _DetailChip(
                              icon: Icons.logout,
                              label: entry.leftOn!,
                              color: Colors.red,
                            ),
                        ],
                      ),

                      // Exit reason
                      if (entry.exitReason != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: Colors.red),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entry.exitReason!,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black54;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}