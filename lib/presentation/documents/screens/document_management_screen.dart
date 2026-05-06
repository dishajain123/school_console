// lib/presentation/documents/screens/document_management_screen.dart  [Admin Console]
// Phase 13 — Document Management.
// Staff Admin manages all student documents: list, verify/reject, set requirements, upload.
// APIs used:
//   GET  /documents?student_id={id}    — list student documents
//   GET  /documents?status=…          — list documents by DocumentStatus (backend filter)
//   PATCH /documents/{id}/verify       — approve or reject a document
//   GET  /documents/requirements       — get school document requirements
//   PUT  /documents/requirements       — set/update requirements
//   POST /documents/upload             — upload document for a student (multipart)
// Backend: all endpoints fully implemented. This admin console screen was entirely missing.
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/logging/crash_reporter.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../domains/providers/active_year_provider.dart';
import '../../../domains/providers/admin_document_provider.dart';
import '../../common/layout/admin_scaffold.dart';
import '../../common/widgets/admin_layout/admin_empty_state.dart';
import '../../common/widgets/admin_layout/admin_filter_card.dart';
import '../../common/widgets/admin_layout/admin_loading_placeholder.dart';
import '../../common/widgets/admin_layout/admin_page_header.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';
import '../../../data/models/documents/admin_document_models.dart';
import '../../../data/repositories/admin_document_repository.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class DocumentManagementScreen extends ConsumerStatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  ConsumerState<DocumentManagementScreen> createState() =>
      _DocumentManagementScreenState();
}

class _StudentDocumentSummary {
  const _StudentDocumentSummary({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.status,
    required this.updatedAtIso,
    required this.totalDocs,
    required this.approvedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.notUploadedCount,
  });

  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String status;
  final String updatedAtIso;
  final int totalDocs;
  final int approvedCount;
  final int pendingCount;
  final int rejectedCount;
  final int notUploadedCount;
}

class _DocumentManagementScreenState
    extends ConsumerState<DocumentManagementScreen>
    with SingleTickerProviderStateMixin {
  // Cache documents by filter tuple so revisits paint instantly while we refresh.
  static final Map<String, List<AdminDocument>> _documentsCache = {};

  late final TabController _tabController;
  late final AdminDocumentRepository _repo;

  /// Main table: last API load for the selected workflow filter (server-side).
  List<AdminDocument> _allDocumentsRaw = [];
  List<_StudentDocumentSummary> _studentRows = [];
  List<AdminDocRequirement> _requirements = [];
  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  List<String> _sections = [];
  String? _selectedYearId;
  String? _selectedStandardId;
  String? _selectedSection;
  final TextEditingController _studentNameSearchCtrl = TextEditingController();

  /// null = all; otherwise backend `DocumentStatus` value (e.g. PENDING).
  String? _workflowStatusFilter;
  bool _loading = false;
  String? _error;
  String? _success;
  Timer? _filterDebounce;
  int _documentsRequestVersion = 0;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repo = ref.read(adminDocumentRepositoryProvider);
    _bootstrap();
    _loadRequirements();
  }

  Future<void> _bootstrap() async {
    // Resolve metadata first so the first documents call uses selected year/class
    // and avoids a broad initial fetch followed by a second filtered fetch.
    await _loadMeta();
    await _loadDocuments();
  }

  Future<void> _loadMeta() async {
    try {
      final years = await _repo.listYears();
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
      final yearId = selected['id']?.toString();
      List<Map<String, dynamic>> standards = [];
      if (yearId != null && yearId.isNotEmpty) {
        standards = await _repo.listStandards(yearId);
      }
      _setStateIfMounted(() {
        _years = years;
        _selectedYearId = yearId;
        _standards = standards;
      });
      ref.read(activeAcademicYearProvider.notifier).setYear(yearId);
    } catch (e, stack) {
      CrashReporter.log(e, stack);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterDebounce?.cancel();
    _studentNameSearchCtrl.dispose();
    super.dispose();
  }

  void _scheduleLoadDocuments() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 280), _loadDocuments);
  }

  bool _documentMatchesStudentNameSearch(AdminDocument d) {
    final q = _studentNameSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (d.studentName ?? '').toLowerCase().contains(q);
  }

  void _resetUnifiedFilters() {
    setState(() {
      _studentNameSearchCtrl.clear();
      _selectedStandardId = null;
      _selectedSection = null;
      _sections = [];
      _workflowStatusFilter = null;
    });
    _loadDocuments();
  }

  Future<void> _loadSectionsForSelectedClass() async {
    final standardId = _selectedStandardId;
    if (standardId == null || standardId.trim().isEmpty) {
      _setStateIfMounted(() {
        _sections = [];
        _selectedSection = null;
      });
      return;
    }
    try {
      final sections = await _repo.listSections(
        standardId: standardId,
        academicYearId: _selectedYearId,
      );
      _setStateIfMounted(() {
        _sections = sections;
        if (_selectedSection != null && !_sections.contains(_selectedSection)) {
          _selectedSection = null;
        }
      });
    } catch (e, stack) {
      CrashReporter.log(e, stack);
      _setStateIfMounted(() {
        _sections = [];
        _selectedSection = null;
      });
    }
  }

  /// Single roll-up status per student row (matches Status filter values).
  String _deriveStudentStatus(List<AdminDocument> docs) {
    if (docs.isEmpty) return 'NOT_UPLOADED';
    final statuses = docs.map((d) => d.status.toUpperCase()).toSet();
    if (statuses.contains('REJECTED')) return 'REJECTED';
    if (statuses.contains('PENDING')) return 'PENDING';
    if (statuses.contains('NOT_UPLOADED')) return 'NOT_UPLOADED';
    if (statuses.contains('REQUESTED')) return 'REQUESTED';
    if (statuses.every((s) => s == 'APPROVED')) return 'APPROVED';
    return 'PENDING';
  }

  List<_StudentDocumentSummary> _buildStudentSummaries(List<AdminDocument> input) {
    final grouped = <String, List<AdminDocument>>{};
    for (final d in input) {
      final key = d.studentId.trim().isEmpty ? '__unknown_${d.id}' : d.studentId;
      grouped.putIfAbsent(key, () => <AdminDocument>[]).add(d);
    }
    final out = <_StudentDocumentSummary>[];
    for (final entry in grouped.entries) {
      final docs = entry.value;
      docs.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
      final first = docs.first;
      final statuses = docs.map((d) => d.status.toUpperCase()).toList(growable: false);
      out.add(
        _StudentDocumentSummary(
          studentId: first.studentId,
          studentName: (first.studentName ?? '').trim().isEmpty ? '-' : first.studentName!,
          admissionNumber: (first.admissionNumber ?? '').trim().isEmpty ? '-' : first.admissionNumber!,
          status: _deriveStudentStatus(docs),
          updatedAtIso: first.updatedAt ?? first.createdAt,
          totalDocs: docs.length,
          approvedCount: statuses.where((s) => s == 'APPROVED').length,
          pendingCount: statuses.where((s) => s == 'PENDING').length,
          rejectedCount: statuses.where((s) => s == 'REJECTED').length,
          notUploadedCount: statuses.where((s) => s == 'NOT_UPLOADED' || s == 'REQUESTED').length,
        ),
      );
    }
    out.sort((a, b) {
      final byName = a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase());
      if (byName != 0) return byName;
      return a.admissionNumber.toLowerCase().compareTo(b.admissionNumber.toLowerCase());
    });
    return out;
  }

  void _applyDocumentFilters() {
    final filteredDocs = List<AdminDocument>.from(_allDocumentsRaw)
        .where(_documentMatchesStudentNameSearch)
        .toList(growable: false);

    final summaries = _buildStudentSummaries(filteredDocs);
    if (_workflowStatusFilter == null || _workflowStatusFilter!.trim().isEmpty) {
      _studentRows = summaries;
    } else {
      final wf = _workflowStatusFilter!.toUpperCase();
      _studentRows = summaries.where((s) => s.status == wf).toList(growable: false);
    }
  }

  Future<void> _loadDocuments() async {
    _filterDebounce?.cancel();
    // Monotonic request id: stale responses from older requests are ignored.
    final requestVersion = ++_documentsRequestVersion;
    final cacheKey = [
      _selectedYearId ?? '',
      _selectedStandardId ?? '',
      _selectedSection ?? '',
      (_workflowStatusFilter ?? '').trim().toUpperCase(),
    ].join('|');

    final cached = _documentsCache[cacheKey];
    if (cached != null) {
      _allDocumentsRaw = cached;
      _applyDocumentFilters();
      _setStateIfMounted(() {});
    }

    _setStateIfMounted(() {
      _loading = true;
      _error = null;
    });
    try {
      final year = _selectedYearId;
      final std = _selectedStandardId;
      final sec = _selectedSection;
      final statusParam = (_workflowStatusFilter ?? '').trim();
      final all = await _repo.listAllDocuments(
        academicYearId: year,
        standardId: std,
        section: sec,
        status: statusParam.isEmpty ? null : statusParam,
      );
      _documentsCache[cacheKey] = all;
      if (!mounted || requestVersion != _documentsRequestVersion) return;
      _setStateIfMounted(() {
        _allDocumentsRaw = all;
        _applyDocumentFilters();
      });
    } catch (e) {
      if (!mounted || requestVersion != _documentsRequestVersion) return;
      if (e is DioException && e.response?.statusCode == 429) {
        _setStateIfMounted(() => _error =
            'Too many requests in a short time. Please wait a second and try again.');
      } else {
        _setStateIfMounted(() => _error = e.toString());
      }
    } finally {
      if (mounted && requestVersion == _documentsRequestVersion) {
        _setStateIfMounted(() => _loading = false);
      }
    }
  }

  Future<void> _loadRequirements() async {
    try {
      final reqs = await _repo.getRequirements();
      _setStateIfMounted(() => _requirements = reqs);
    } catch (e, stack) {
      CrashReporter.log(e, stack);
    }
  }

  Future<void> _showUploadDialog() async {
    List<Map<String, dynamic>> studentChoices = [];
    try {
      studentChoices = await _repo.listStudents(
        academicYearId: _selectedYearId,
      );
    } catch (e, stack) {
      CrashReporter.log(e, stack);
    }

    final studentIdCtrl = TextEditingController();
    String docType = 'BONAFIDE';
    final otherNameCtrl = TextEditingController();
    String fileNameInput = '';
    Uint8List? fileBytes;
    String contentType = 'application/pdf';
    String? pickedStudentId;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Upload Document for Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (studentChoices.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: pickedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Student (optional)',
                      helperText: 'Or paste student UUID below',
                    ),
                    isExpanded: true,
                    items: studentChoices
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s['id']?.toString(),
                            child: Text(
                              '${s['admission_number'] ?? s['id']} — '
                              '${s['student_name'] ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() {
                      pickedStudentId = v;
                      if (v != null) studentIdCtrl.text = v;
                    }),
                  ),
                if (studentChoices.isNotEmpty) const SizedBox(height: 8),
                TextField(
                  controller: studentIdCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Student ID (UUID)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: docType,
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: const [
                    'ID_CARD',
                    'BONAFIDE',
                    'LEAVING_CERT',
                    'REPORT_CARD',
                    'ID_PROOF',
                    'ADDRESS_PROOF',
                    'ACADEMIC_CERTIFICATE',
                    'TRANSFER_CERTIFICATE',
                    'MEDICAL',
                    'OTHER',
                  ]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => docType = v);
                  },
                ),
                if (docType == 'OTHER') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Other Document Name *',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 14),
                  label: Text(fileNameInput.isEmpty ? 'Choose File' : fileNameInput),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                      withData: true,
                      allowMultiple: false,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final file = result.files.single;
                    final bytes = file.bytes;
                    if (bytes == null || bytes.isEmpty) return;
                    final lower = file.name.toLowerCase();
                    setDialog(() {
                      fileNameInput = file.name;
                      contentType = switch ((file.extension ?? '').toLowerCase()) {
                        'pdf' => 'application/pdf',
                        'png' => 'image/png',
                        'jpg' || 'jpeg' => 'image/jpeg',
                        _ => lower.endsWith('.pdf')
                            ? 'application/pdf'
                            : 'application/octet-stream',
                      };
                      fileBytes = bytes;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (studentIdCtrl.text.trim().isEmpty ||
                    fileNameInput.isEmpty ||
                    fileBytes == null ||
                    fileBytes!.isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop();
                _setStateIfMounted(() => _loading = true);
                try {
                  final note = docType == 'OTHER'
                      ? otherNameCtrl.text.trim()
                      : null;
                  if (docType == 'OTHER' && (note == null || note.isEmpty)) {
                    if (mounted) {
                      _setStateIfMounted(() => _error = 'Please enter Other document name.');
                    }
                    return;
                  }
                  await _repo.uploadDocument(
                    studentId: studentIdCtrl.text.trim(),
                    documentType: docType,
                    note: note,
                    fileName: fileNameInput,
                    fileBytes: fileBytes!,
                    contentType: contentType,
                  );
                  await _loadDocuments();
                  if (mounted) {
                    _setStateIfMounted(() => _success = 'Document uploaded successfully.');
                  }
                } catch (e) {
                  _setStateIfMounted(() => _error = e.toString());
                } finally {
                  _setStateIfMounted(() => _loading = false);
                }
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
    otherNameCtrl.dispose();
  }

  Future<void> _editRequirements() async {
    final docTypes = <String>[
      'ID_CARD',
      'REPORT_CARD',
      'LEAVING_CERT',
      'BONAFIDE',
      'ID_PROOF',
      'ADDRESS_PROOF',
      'ACADEMIC_CERTIFICATE',
      'TRANSFER_CERTIFICATE',
      'MEDICAL',
      'OTHER',
    ];
    final editableItems = _requirements.isEmpty
        ? <Map<String, dynamic>>[
            {
              'document_type': 'ID_CARD',
              'is_mandatory': true,
              'note': '',
              if (_selectedYearId != null && _selectedYearId!.trim().isNotEmpty)
                'academic_year_id': _selectedYearId,
            },
          ]
        : _requirements
            .map(
              (r) => <String, dynamic>{
                'document_type': r.documentType,
                'is_mandatory': r.isMandatory,
                'note': r.note ?? '',
                if (r.academicYearId != null && r.academicYearId!.trim().isNotEmpty)
                  'academic_year_id': r.academicYearId,
                if (r.standardId != null && r.standardId!.trim().isNotEmpty)
                  'standard_id': r.standardId,
              },
            )
            .toList(growable: true);
    String? scopeYearId = _selectedYearId;
    String? scopeStandardId;
    bool allClasses = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Set Document Requirements'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: scopeYearId,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  items: _years
                      .map((y) => DropdownMenuItem<String?>(
                            value: y['id']?.toString(),
                            child: Text(y['name']?.toString() ?? '-'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialog(() => scopeYearId = v),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Apply to all classes'),
                  value: allClasses,
                  onChanged: (v) => setDialog(() => allClasses = v),
                ),
                if (!allClasses)
                  DropdownButtonFormField<String?>(
                    initialValue: scopeStandardId,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: _standards
                        .map((s) => DropdownMenuItem<String?>(
                              value: s['id']?.toString(),
                              child: Text(s['name']?.toString() ?? '-'),
                            ))
                        .toList(),
                    onChanged: (v) => setDialog(() => scopeStandardId = v),
                  ),
                const SizedBox(height: 8),
                ...editableItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final selectedType =
                      (item['document_type']?.toString() ?? 'OTHER').toUpperCase();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: docTypes.contains(selectedType)
                                      ? selectedType
                                      : 'OTHER',
                                  decoration: const InputDecoration(
                                      labelText: 'Document Type'),
                                  items: docTypes
                                      .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t.replaceAll('_', ' ')),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setDialog(() => editableItems[index]['document_type'] = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: editableItems.length <= 1
                                    ? null
                                    : () => setDialog(() => editableItems.removeAt(index)),
                                icon: const Icon(Icons.delete_outline, color: AdminColors.danger),
                              ),
                            ],
                          ),
                          TextFormField(
                            initialValue: item['note']?.toString() ?? '',
                            onChanged: (v) =>
                                editableItems[index]['note'] = v,
                            decoration: InputDecoration(
                              labelText: selectedType == 'OTHER'
                                  ? 'Custom Document Name *'
                                  : 'Instruction (optional)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setDialog(() {
                      editableItems.add({
                        'document_type': 'OTHER',
                        'is_mandatory': true,
                        'note': '',
                        if (scopeYearId != null && scopeYearId!.trim().isNotEmpty)
                          'academic_year_id': scopeYearId,
                        if (!allClasses &&
                            scopeStandardId != null &&
                            scopeStandardId!.trim().isNotEmpty)
                          'standard_id': scopeStandardId,
                      });
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Document'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final payload = <Map<String, dynamic>>[];
                  for (final row in editableItems) {
                    final type =
                        (row['document_type']?.toString() ?? 'OTHER').toUpperCase();
                    final note = (row['note']?.toString() ?? '').trim();
                    if (type == 'OTHER' && note.isEmpty) {
                      if (mounted) {
                        setState(() {
                          _error =
                              'Custom name is required for OTHER document type.';
                        });
                      }
                      return;
                    }
                    final yearVal = row['academic_year_id'] ?? scopeYearId;
                    final stdVal = allClasses
                        ? null
                        : (row['standard_id'] ?? scopeStandardId);
                    payload.add({
                      'document_type': type,
                      'is_mandatory': true,
                      if (note.isNotEmpty) 'note': note,
                      if (yearVal != null &&
                          yearVal.toString().trim().isNotEmpty)
                        'academic_year_id': yearVal.toString().trim(),
                      if (stdVal != null &&
                          stdVal.toString().trim().isNotEmpty)
                        'standard_id': stdVal.toString().trim(),
                    });
                  }
                  await _repo.setRequirements(
                    payload,
                  );
                  await _loadRequirements();
                  if (mounted) {
                    setState(
                        () => _success = 'Document requirements updated.');
                  }
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Documents',
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: _Banner(
                  message: _error!,
                  isError: true,
                  onDismiss: () => setState(() => _error = null),
                ),
              ),
            if (_success != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
                child: _Banner(
                  message: _success!,
                  isError: false,
                  onDismiss: () => setState(() => _success = null),
                ),
              ),
            AdminPageHeader(
              title: 'Documents',
              subtitle:
                  'Click a student name to open their checklist, upload, and approve or reject. '
                  'Requirements apply by academic year and class. All listed types are required.',
              primaryAction: FilledButton.icon(
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Upload document'),
              ),
              iconActions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _loadDocuments,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
              child: AdminFilterCard(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  headerGap: 6,
                  onReset: _resetUnifiedFilters,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final stack = w < 720;
                      double fieldW(double preferred) =>
                          stack ? w.clamp(120.0, double.infinity) : preferred;
                      final decoTheme = Theme.of(context).copyWith(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        inputDecorationTheme:
                            const InputDecorationTheme(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      );
                      return Theme(
                        data: decoTheme,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            SizedBox(
                              width: fieldW(200),
                              child: TextField(
                                controller: _studentNameSearchCtrl,
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search name (optional)',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 40,
                                    maxHeight: 36,
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (_) {
                                  setState(() => _applyDocumentFilters());
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldW(152),
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedYearId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Year',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All'),
                                  ),
                                  ..._years.map(
                                    (y) => DropdownMenuItem<String?>(
                                      value: y['id']?.toString(),
                                      child: Text(y['name']?.toString() ?? '-'),
                                    ),
                                  ),
                                ],
                                onChanged: (v) async {
                                  setState(() {
                                    _selectedYearId = v;
                                    _selectedStandardId = null;
                                    _selectedSection = null;
                                    _standards = [];
                                    _sections = [];
                                  });
                                  ref
                                      .read(activeAcademicYearProvider.notifier)
                                      .setYear(v);
                                  if (v != null && v.isNotEmpty) {
                                    final standards =
                                        await _repo.listStandards(v);
                                    if (!mounted) return;
                                    setState(() => _standards = standards);
                                  }
                                  await _loadSectionsForSelectedClass();
                                  _scheduleLoadDocuments();
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldW(140),
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedStandardId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Class',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All'),
                                  ),
                                  ..._standards.map(
                                    (s) => DropdownMenuItem<String?>(
                                      value: s['id']?.toString(),
                                      child: Text(s['name']?.toString() ?? '-'),
                                    ),
                                  ),
                                ],
                                onChanged: (v) async {
                                  setState(() {
                                    _selectedStandardId = v;
                                    _selectedSection = null;
                                    _sections = [];
                                  });
                                  await _loadSectionsForSelectedClass();
                                  _scheduleLoadDocuments();
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldW(130),
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedSection,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Section',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All'),
                                  ),
                                  ..._sections.map(
                                    (sec) => DropdownMenuItem<String?>(
                                      value: sec,
                                      child: Text(sec),
                                    ),
                                  ),
                                ],
                                onChanged: _selectedStandardId == null
                                    ? null
                                    : (v) {
                                        setState(() => _selectedSection = v);
                                        _scheduleLoadDocuments();
                                      },
                              ),
                            ),
                            SizedBox(
                              width: fieldW(148),
                              child: DropdownButtonFormField<String?>(
                                initialValue: _workflowStatusFilter,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'NOT_UPLOADED',
                                    child: Text('Not Uploaded'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'REQUESTED',
                                    child: Text('Requested'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'PENDING',
                                    child: Text('Pending'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'APPROVED',
                                    child: Text('Approved'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'REJECTED',
                                    child: Text('Rejected'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _workflowStatusFilter = v);
                                  _scheduleLoadDocuments();
                                },
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _loadDocuments,
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ),
            ),
            Expanded(
              child: AdminSurfaceCard(
                padding: EdgeInsets.zero,
                clipScroll: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: AdminColors.surface,
                      child: TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'All documents'),
                          Tab(text: 'Requirements'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAllDocumentsTab(),
                          _buildRequirementsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 0: All Documents ────────────────────────────────────────────────────

  Widget _buildAllDocumentsTab() {
    if (_loading && _studentRows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          AdminSpacing.md,
          AdminSpacing.sm,
          AdminSpacing.md,
          AdminSpacing.md,
        ),
        child: AdminLoadingPlaceholder(message: 'Loading documents…'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.md,
        AdminSpacing.sm,
        AdminSpacing.md,
        AdminSpacing.md,
      ),
      child: _buildStudentTable(_studentRows),
    );
  }

  Widget _buildStudentTable(List<_StudentDocumentSummary> rowsData) {
    if (rowsData.isEmpty) {
      return const AdminEmptyState(
        title: 'No students match these filters',
        message: 'Adjust filters or refresh to reload.',
      );
    }
    final rows = rowsData.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;
      final statusLabel = row.status.replaceAll('_', ' ');
      return DataRow(
        color: adminDataRowColor(index),
        cells: [
          DataCell(
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: row.studentId.trim().isEmpty
                    ? null
                    : () => context.push('/documents/student/${row.studentId}'),
                child: Text(
                  row.studentName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: row.studentId.trim().isEmpty
                            ? AdminColors.textPrimary
                            : AdminColors.primaryAction,
                        fontWeight: FontWeight.w500,
                        decoration: row.studentId.trim().isEmpty
                            ? TextDecoration.none
                            : TextDecoration.underline,
                        decorationColor: AdminColors.primaryAction,
                      ),
                ),
              ),
            ),
          ),
          DataCell(Text(row.admissionNumber)),
          DataCell(Text('${row.approvedCount}/${row.totalDocs} approved')),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              decoration: BoxDecoration(
                color: AdminColors.borderSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AdminColors.border),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AdminColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
          ),
          DataCell(Text(_fmtDate(row.updatedAtIso))),
          DataCell(
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 30),
                side: BorderSide(color: AdminColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                foregroundColor: AdminColors.primaryAction,
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              onPressed: row.studentId.trim().isEmpty
                  ? null
                  : () => context.push('/documents/student/${row.studentId}'),
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              label: const Text('View'),
            ),
          ),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: adminTableHeadingRowColor(),
          border: TableBorder(
            horizontalInside: BorderSide(color: AdminColors.border),
            top: BorderSide(color: AdminColors.border),
            bottom: BorderSide(color: AdminColors.border),
          ),
          dataRowMinHeight: 38,
          dataRowMaxHeight: 44,
          columns: [
            const DataColumn(label: Text('Student')),
            const DataColumn(label: Text('Adm. No.')),
            const DataColumn(label: Text('Checklist')),
            const DataColumn(label: Text('Overall status')),
            const DataColumn(label: Text('Updated At')),
            const DataColumn(label: Text('Details')),
          ],
          rows: rows,
        ),
      ),
    );
  }

  // ── Tab 1: Requirements ─────────────────────────────────────────────────────

  Widget _buildRequirementsTab() {
    if (_loading && _requirements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          AdminSpacing.md,
          AdminSpacing.md,
          AdminSpacing.md,
          AdminSpacing.md,
        ),
        child: AdminLoadingPlaceholder(message: 'Loading requirements…'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.md,
            AdminSpacing.md,
            AdminSpacing.md,
            AdminSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Document types students must submit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AdminColors.textSecondary,
                        fontSize: 13,
                      ),
                ),
              ),
              FilledButton.tonal(
                onPressed: _editRequirements,
                child: const Text('Edit requirements'),
              ),
            ],
          ),
        ),
        if (_requirements.isEmpty)
          const Expanded(
            child: AdminEmptyState(
              title: 'No requirements configured',
              message: 'Add document types to match your school’s policy.',
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.md,
                0,
                AdminSpacing.md,
                AdminSpacing.md,
              ),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: adminTableHeadingRowColor(),
                    border: TableBorder(
                      horizontalInside:
                          BorderSide(color: AdminColors.border),
                      top: BorderSide(color: AdminColors.border),
                      bottom: BorderSide(color: AdminColors.border),
                    ),
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 48,
                    columns: const [
                      DataColumn(label: Text('Document type')),
                      DataColumn(label: Text('Year scope')),
                      DataColumn(label: Text('Class scope')),
                      DataColumn(label: Text('Note')),
                    ],
                    rows: _requirements.asMap().entries.map((entry) {
                      final index = entry.key;
                      final req = entry.value;
                      return DataRow(
                        color: adminDataRowColor(index),
                        cells: [
                          DataCell(Text(req.documentType.replaceAll('_', ' '))),
                          DataCell(Text(req.academicYearId ?? 'All years')),
                          DataCell(Text(req.standardId ?? 'All classes')),
                          DataCell(Text(req.note ?? '-')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e, stack) {
      CrashReporter.log(e, stack);
      return iso;
    }
  }
}

// ── Banner Widget ─────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner(
      {required this.message,
      required this.isError,
      required this.onDismiss});
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isError
          ? AdminColors.dangerSurface
          : AdminColors.success.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: AdminSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isError ? AdminColors.danger : AdminColors.success,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: AdminColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
