// lib/presentation/academic_history/screens/student_academic_history_screen.dart  [Admin Console]
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

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
        ApiConstants.enrollmentHistory(widget.studentId),
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
        return AdminColors.success;
      case 'HOLD':
        return const Color(0xFFEA580C);
      case 'COMPLETED':
        return AdminColors.primaryAction;
      case 'PROMOTED':
        return AdminColors.primaryPressed;
      case 'REPEATED':
        return const Color(0xFFD97706);
      case 'GRADUATED':
        return const Color(0xFF0D9488);
      case 'LEFT':
        return AdminColors.danger;
      case 'TRANSFERRED':
        return const Color(0xFFEA580C);
      default:
        return AdminColors.textMuted;
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
    final title = _studentName?.trim().isNotEmpty == true
        ? _studentName!.trim()
        : 'Academic history';
    final headerSubtitle = [
      if (_admissionNumber != null && _admissionNumber!.trim().isNotEmpty)
        'Admission no. ${_admissionNumber!.trim()}',
      if (!_loading && _error == null)
        '${_history.length} academic year(s) on record',
    ].join(' · ');

    return AdminScaffold(
      title: 'Academic history',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
              title: title,
              subtitle: headerSubtitle.isEmpty
                  ? 'Enrollment timeline by year, class, and status.'
                  : headerSubtitle,
              iconActions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const AdminLoadingPlaceholder(
                      message: 'Loading academic history…',
                      height: 320,
                    )
                  : _error != null
                      ? _HistoryErrorPanel(
                          message: _error!,
                          onRetry: _load,
                        )
                      : _history.isEmpty
                          ? const AdminEmptyState(
                              icon: Icons.history_edu_outlined,
                              title: 'No academic history',
                              message:
                                  'No enrollment years are on file for this student yet.',
                            )
                          : CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: AdminColors.border,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AdminSpacing.md,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor:
                                                AdminColors.primarySubtle,
                                            child: Text(
                                              (_studentName != null &&
                                                      _studentName!
                                                          .trim()
                                                          .isNotEmpty)
                                                  ? _studentName!
                                                      .trim()
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    AdminColors.primaryPressed,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AdminSpacing.md,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _studentName?.trim()
                                                              .isNotEmpty ==
                                                          true
                                                      ? _studentName!.trim()
                                                      : '—',
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AdminColors.textPrimary,
                                                  ),
                                                ),
                                                if (_admissionNumber != null)
                                                  Text(
                                                    'Admission no.: $_admissionNumber',
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: AdminColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                Text(
                                                  '${_history.length} academic year(s) on record',
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color:
                                                        AdminColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.only(
                                    top: AdminSpacing.md,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorPanel extends StatelessWidget {
  const _HistoryErrorPanel({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: AdminColors.dangerSurface,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(AdminSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AdminColors.danger,
                        size: 28,
                      ),
                      const SizedBox(width: AdminSpacing.sm),
                      Text(
                        'Could not load history',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AdminColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.sm),
                  SelectableText(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AdminColors.danger,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                    border: Border.all(
                      color: AdminColors.surface,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.35),
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
                      color: AdminColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AdminSpacing.md,
              ),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AdminColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AdminSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.academicYearName ?? '—',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
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
                          fontSize: 13,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AdminSpacing.sm,
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
                              color: AdminColors.danger,
                            ),
                        ],
                      ),
                      if (entry.exitReason != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(AdminSpacing.sm),
                          decoration: BoxDecoration(
                            color: AdminColors.dangerSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AdminColors.danger.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AdminColors.danger,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entry.exitReason!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AdminColors.danger,
                                    height: 1.35,
                                  ),
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
    final c = color ?? AdminColors.textSecondary;
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
