// Per-student document review: requirements checklist, upload, verify/reject.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/browser_actions.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/admin_document_provider.dart';
import '../../../domains/providers/student_documents_overview_provider.dart';
import '../../../data/models/documents/student_documents_overview.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';
import '../../../data/models/documents/admin_document_models.dart';

class DocumentStudentDetailScreen extends ConsumerStatefulWidget {
  const DocumentStudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<DocumentStudentDetailScreen> createState() =>
      _DocumentStudentDetailScreenState();
}

class _DocumentStudentDetailScreenState
    extends ConsumerState<DocumentStudentDetailScreen> {
  void _invalidateOverview() {
    ref.invalidate(studentDocumentsOverviewProvider(widget.studentId));
  }

  static bool _allPendingReview(List<AdminRequirementStatus> checklist) {
    if (checklist.isEmpty) return false;
    for (final r in checklist) {
      if (r.isCompleted) continue;
      if (!r.hasPendingFile) return false;
    }
    return true;
  }

  bool _canVerify(AdminDocument d) =>
      d.hasFile && d.status.toUpperCase() == 'PENDING';

  Future<void> _verify(AdminDocument d, bool approve, {String? reason}) async {
    if (!_canVerify(d)) return;
    final repo = ref.read(adminDocumentRepositoryProvider);
    try {
      await repo.verifyDocument(d.id, approve: approve, reason: reason);
      _invalidateOverview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Document approved.' : 'Document rejected.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _openFile(String docId) async {
    final repo = ref.read(adminDocumentRepositoryProvider);
    try {
      final url = await repo.getDownloadUrl(docId);
      if (url != null && mounted) openUrlInNewTab(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  /// Same approach as the school mobile app (`file_picker` + in-memory bytes).
  /// Raw `dart:html` file inputs are unreliable inside Flutter web.
  Future<({String name, Uint8List bytes, String contentType})?>
      _pickFileBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final fileName = f.name;
    final ext = (f.extension ?? '').toLowerCase();
    final contentType = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => fileName.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : 'application/octet-stream',
    };

    return (name: fileName, bytes: bytes, contentType: contentType);
  }

  Future<void> _uploadForType(
    String documentType, {
    String? academicYearId,
  }) async {
    String? otherNote;
    if (documentType == 'OTHER') {
      final otherCtrl = TextEditingController();
      final submitted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Document label'),
          content: TextField(
            controller: otherCtrl,
            decoration: const InputDecoration(
              labelText: 'Document label *',
              hintText: 'e.g. Fee receipt, medical form',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Choose file'),
            ),
          ],
        ),
      );
      otherNote = otherCtrl.text.trim();
      otherCtrl.dispose();
      if (submitted != true) return;
      if (otherNote.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a document label first.')),
          );
        }
        return;
      }
    }

    final picked = await _pickFileBytes();
    if (picked == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No file selected, or the file could not be read. '
              'Try again or use a PDF or image under the size limit.',
            ),
          ),
        );
      }
      return;
    }

    final repo = ref.read(adminDocumentRepositoryProvider);
    try {
      await repo.uploadDocument(
        studentId: widget.studentId,
        documentType: documentType,
        fileName: picked.name,
        fileBytes: picked.bytes,
        contentType: picked.contentType,
        note: documentType == 'OTHER' ? otherNote : null,
        academicYearId: academicYearId,
      );
      _invalidateOverview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  static List<AdminDocument> _requestedDocs(List<AdminDocument> documents) {
    final list = documents
        .where((d) => !d.isSynthetic && d.status.toUpperCase() == 'REQUESTED')
        .toList();
    int key(AdminDocument d) {
      final t = d.updatedAt ?? d.createdAt;
      return DateTime.tryParse(t)?.millisecondsSinceEpoch ?? 0;
    }

    list.sort((a, b) => key(b).compareTo(key(a)));
    return list;
  }

  static Set<String> _requestedDocIds(List<AdminDocument> requestedDocs) =>
      requestedDocs.map((d) => d.id).toSet();

  static List<AdminDocument> _otherDocumentRecords(
    List<AdminDocument> documents,
    Set<String> requestedDocIds,
  ) =>
      (documents.where((d) => !requestedDocIds.contains(d.id)).toList()
        ..sort((a, b) {
          final ta = DateTime.tryParse(a.updatedAt ?? a.createdAt)
                  ?.millisecondsSinceEpoch ??
              0;
          final tb = DateTime.tryParse(b.updatedAt ?? b.createdAt)
                  ?.millisecondsSinceEpoch ??
              0;
          return tb.compareTo(ta);
        }));

  static AdminDocument? _docById(List<AdminDocument> documents, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overviewAsync =
        ref.watch(studentDocumentsOverviewProvider(widget.studentId));

    return AdminScaffold(
      title: 'Student documents',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    'Documents',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AdminColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: overviewAsync.when(
                loading: () =>
                    const AdminLoadingPlaceholder(message: 'Loading…'),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.lg),
                    child: Material(
                      color: AdminColors.dangerSurface,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(AdminSpacing.md),
                        child: SelectableText(
                          e.toString(),
                          style: const TextStyle(
                            color: AdminColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                data: (StudentDocumentsOverview overview) {
                  final requested = _requestedDocs(overview.documents);
                  return RefreshIndicator(
                    color: AdminColors.primaryAction,
                    onRefresh: () async {
                      _invalidateOverview();
                      await ref.read(
                        studentDocumentsOverviewProvider(widget.studentId)
                            .future,
                      );
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: AdminSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStudentHeroCard(
                            theme,
                            overview.studentTitle,
                            overviewAsync.isLoading,
                          ),
                          if (_allPendingReview(overview.checklist) &&
                              overview.checklist.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AdminSpacing.md,
                                bottom: AdminSpacing.sm,
                              ),
                              child: Material(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(AdminSpacing.md),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.task_alt_rounded,
                                        color: AdminColors.success,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Required items have files uploaded and are waiting for your review. '
                                          'Use Approve or Reject in the checklist below.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: AdminColors.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (requested.isNotEmpty) ...[
                            _buildSectionTitle(
                              theme,
                              title: 'Requested',
                              subtitle:
                                  'These were requested from the school. Upload the official file here — it will move to review when attached.',
                            ),
                            const SizedBox(height: AdminSpacing.sm),
                            ...requested.map(
                              (d) => _buildRequestedCard(theme, d),
                            ),
                            const SizedBox(height: AdminSpacing.lg),
                          ],
                          _buildSectionTitle(
                            theme,
                            title: 'Required checklist',
                            subtitle:
                                'Program requirements for this class and academic year.',
                          ),
                          const SizedBox(height: AdminSpacing.sm),
                          _buildChecklistSection(theme, overview),
                          const SizedBox(height: AdminSpacing.lg),
                          _buildSectionTitle(
                            theme,
                            title: 'All other document records',
                            subtitle: requested.isEmpty
                                ? 'Complete history for this student.'
                                : 'Other statuses (requested items are listed above).',
                          ),
                          const SizedBox(height: AdminSpacing.sm),
                          _buildRecordsTable(theme, overview),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentHeroCard(
    ThemeData theme,
    String studentTitle,
    bool reloadBusy,
  ) {
    return AdminSurfaceCard(
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: AdminSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              studentTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Refresh',
            onPressed: reloadBusy ? null : _invalidateOverview,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: AdminColors.primaryAction,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AdminColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestedCard(ThemeData theme, AdminDocument d) {
    final label = _formatDocTypeLabel(d.documentType);
    final hint = (d.reviewNote ?? '').trim().isNotEmpty
        ? d.reviewNote!.trim()
        : (d.adminComment ?? '').trim();

    return AdminSurfaceCard(
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      padding: const EdgeInsets.all(AdminSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AdminColors.primaryAction.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconForDocumentType(d.documentType),
              color: AdminColors.primaryAction,
              size: 24,
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Chip(
                      label: const Text('REQUESTED'),
                      backgroundColor:
                          AdminColors.primaryAction.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: AdminColors.primaryAction,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AdminColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => _uploadForType(
                    d.documentType,
                    academicYearId: d.academicYearId,
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  label: const Text('Upload school copy'),
                ),
                const SizedBox(height: 6),
                Text(
                  'PDF or image · Replaces any empty placeholder for this type',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AdminColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection(
    ThemeData theme,
    StudentDocumentsOverview overview,
  ) {
    final checklist = overview.checklist;
    final documents = overview.documents;
    if (checklist.isEmpty) {
      return AdminSurfaceCard(
        child: Text(
          'No document requirements apply to this student’s class and year. '
          'Configure requirements under Documents → Requirements.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AdminColors.textSecondary,
            height: 1.4,
          ),
        ),
      );
    }

    return Column(
      children: checklist.map((r) {
        final rowDoc = _docById(documents, r.latestDocumentId);
        final status = (r.latestStatus ?? '—').toUpperCase();
        final borderColor = rowDoc?.statusColor ??
            AdminColors.borderSubtle;

        return AdminSurfaceCard(
          margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
          padding: EdgeInsets.zero,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDocTypeLabel(r.documentType),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((r.note ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              r.note!.trim(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Chip(
                              label: Text(status),
                              backgroundColor:
                                  (rowDoc?.statusColor ?? AdminColors.textMuted)
                                      .withValues(alpha: 0.12),
                              labelStyle: TextStyle(
                                color: rowDoc?.statusColor ??
                                    AdminColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                            if (r.isMandatory) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: const Text('Required'),
                                backgroundColor: const Color(0xFFEA580C)
                                    .withValues(alpha: 0.14),
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (rowDoc != null && rowDoc.hasFile)
                              OutlinedButton.icon(
                                onPressed: () => _openFile(rowDoc.id),
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('Open file'),
                              ),
                            if (rowDoc != null && _canVerify(rowDoc)) ...[
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AdminColors.success,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _verify(rowDoc, true),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text('Approve'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final reasonCtrl = TextEditingController();
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Reject document'),
                                      content: TextField(
                                        controller: reasonCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Reason for rejection',
                                          border: OutlineInputBorder(),
                                        ),
                                        maxLines: 3,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true &&
                                      reasonCtrl.text.trim().isNotEmpty) {
                                    await _verify(
                                      rowDoc,
                                      false,
                                      reason: reasonCtrl.text.trim(),
                                    );
                                  }
                                  reasonCtrl.dispose();
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Reject'),
                              ),
                            ],
                            if (r.latestDocumentId == null ||
                                status == 'NOT_UPLOADED' ||
                                status == 'REQUESTED' ||
                                r.needsReupload)
                              FilledButton.tonalIcon(
                                onPressed: () => _uploadForType(
                                  r.documentType,
                                  academicYearId: r.academicYearId,
                                ),
                                icon: const Icon(Icons.attach_file, size: 18),
                                label: const Text('Attach file'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecordsTable(
    ThemeData theme,
    StudentDocumentsOverview overview,
  ) {
    final requested = _requestedDocs(overview.documents);
    final rows = _otherDocumentRecords(
      overview.documents,
      _requestedDocIds(requested),
    );
    if (rows.isEmpty) {
      return AdminSurfaceCard(
        child: Text(
          'No additional document rows.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AdminColors.textSecondary,
          ),
        ),
      );
    }

    return AdminSurfaceCard(
      padding: EdgeInsets.zero,
      clipScroll: true,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 720),
            child: DataTable(
              headingRowColor: adminTableHeadingRowColor(),
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Document')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Updated')),
                DataColumn(label: Text('Actions')),
              ],
              rows: rows.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                final st = d.status.toUpperCase();
                return DataRow(
                  color: adminDataRowColor(i),
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconForDocumentType(d.documentType),
                              size: 18, color: AdminColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(_formatDocTypeLabel(d.documentType)),
                        ],
                      ),
                    ),
                    DataCell(
                      Chip(
                        label: Text(st),
                        backgroundColor:
                            d.statusColor.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: d.statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    DataCell(Text(
                      d.updatedAt ?? d.createdAt,
                      style: theme.textTheme.bodySmall,
                    )),
                    DataCell(
                      Wrap(
                        spacing: 8,
                        children: [
                          if (d.hasFile)
                            TextButton.icon(
                              onPressed: () => _openFile(d.id),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open'),
                            ),
                          if (_canVerify(d))
                            TextButton.icon(
                              onPressed: () => _verify(d, true),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve'),
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
    );
  }

  static String _formatDocTypeLabel(String raw) {
    final parts = raw.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
    return parts
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static IconData _iconForDocumentType(String t) {
    switch (t.toUpperCase()) {
      case 'ID_CARD':
        return Icons.badge_outlined;
      case 'REPORT_CARD':
        return Icons.grading_outlined;
      case 'BONAFIDE':
        return Icons.verified_outlined;
      case 'LEAVING_CERT':
      case 'TRANSFER_CERTIFICATE':
        return Icons.logout_rounded;
      case 'ADDRESS_PROOF':
        return Icons.home_outlined;
      case 'MEDICAL':
        return Icons.medical_information_outlined;
      case 'OTHER':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
