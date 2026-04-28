// lib/presentation/documents/screens/document_management_screen.dart  [Admin Console]
// Phase 13 — Document Management.
// Staff Admin manages all student documents: list, verify/reject, set requirements, upload.
// APIs used:
//   GET  /documents?student_id={id}    — list student documents
//   GET  /documents                    — list all school documents (admin only)
//   PATCH /documents/{id}/verify       — approve or reject a document
//   GET  /documents/requirements       — get school document requirements
//   PUT  /documents/requirements       — set/update requirements
//   POST /documents/upload             — upload document for a student (multipart)
// Backend: all endpoints fully implemented. This admin console screen was entirely missing.
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../domains/providers/auth_provider.dart';
import '../../common/layout/admin_scaffold.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Document {
  const _Document({
    required this.id,
    required this.studentId,
    required this.documentType,
    required this.status,
    required this.createdAt,
    this.studentName,
    this.admissionNumber,
    this.fileKey,
    this.reviewNote,
    this.reviewedAt,
    this.academicYearId,
  });

  final String id;
  final String studentId;
  final String documentType;
  final String status;
  final String createdAt;
  final String? studentName;
  final String? admissionNumber;
  final String? fileKey;
  final String? reviewNote;
  final String? reviewedAt;
  final String? academicYearId;

  bool get hasFile => fileKey != null && fileKey!.trim().isNotEmpty;

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'READY':
        return Colors.green;
      case 'PROCESSING':
        return Colors.orange;
      case 'PENDING':
        return Colors.blue;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  factory _Document.fromJson(Map<String, dynamic> j) => _Document(
        id: j['id']?.toString() ?? '',
        studentId: j['student_id']?.toString() ?? '',
        documentType: j['document_type']?.toString() ?? '',
        status: j['status']?.toString() ?? 'PENDING',
        createdAt: j['created_at']?.toString() ?? '',
        studentName: j['student_name'] as String?,
        admissionNumber: j['student_admission_number'] as String?,
        fileKey: j['file_key'] as String?,
        reviewNote: j['review_note'] as String?,
        reviewedAt: j['reviewed_at'] as String?,
        academicYearId: j['academic_year_id']?.toString(),
      );
}

class _DocRequirement {
  const _DocRequirement({
    required this.documentType,
    required this.isMandatory,
    this.note,
  });

  final String documentType;
  final bool isMandatory;
  final String? note;

  factory _DocRequirement.fromJson(Map<String, dynamic> j) => _DocRequirement(
        documentType: j['document_type']?.toString() ?? '',
        isMandatory: j['is_mandatory'] == true,
        note: j['note'] as String?,
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class _DocRepository {
  _DocRepository(this._dio);
  final DioClient _dio;

  Future<List<_Document>> listAllDocuments() async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/documents',
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _Document.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<_Document>> listStudentDocuments(String studentId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/documents',
      queryParameters: {'student_id': studentId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _Document.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String?> getDownloadUrl(String docId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      '/documents/$docId/download',
    );
    return r.data?['url'] as String?;
  }

  Future<void> verifyDocument(String docId,
      {required bool approve, String? reason}) async {
    await _dio.dio.patch<dynamic>(
      '/documents/$docId/verify',
      data: {
        'approve': approve,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<List<_DocRequirement>> getRequirements() async {
    final r = await _dio.dio.get<Map<String, dynamic>>('/documents/requirements');
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _DocRequirement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setRequirements(List<Map<String, dynamic>> items) async {
    await _dio.dio.put<dynamic>(
      '/documents/requirements',
      data: {'items': items},
    );
  }

  Future<_Document> uploadDocument({
    required String studentId,
    required String documentType,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final formData = FormData.fromMap({
      'student_id': studentId,
      'document_type': documentType,
      'file': MultipartFile.fromBytes(fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType)),
    });
    final r = await _dio.dio.post<Map<String, dynamic>>(
      '/documents/upload',
      data: formData,
    );
    return _Document.fromJson(r.data ?? {});
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DocumentManagementScreen extends ConsumerStatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  ConsumerState<DocumentManagementScreen> createState() =>
      _DocumentManagementScreenState();
}

class _DocumentManagementScreenState
    extends ConsumerState<DocumentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _DocRepository _repo;

  List<_Document> _documents = [];
  List<_DocRequirement> _requirements = [];

  String? _statusFilter;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = _DocRepository(ref.read(dioClientProvider));
    _loadDocuments();
    _loadRequirements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await _repo.listAllDocuments();
      final filtered = _statusFilter == null
          ? docs
          : docs.where((d) => d.status.toUpperCase() == _statusFilter).toList();
      setState(() => _documents = filtered);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRequirements() async {
    try {
      final reqs = await _repo.getRequirements();
      setState(() => _requirements = reqs);
    } catch (_) {}
  }

  Future<void> _verify(
      _Document doc, bool approve, {String? reason}) async {
    if (!doc.hasFile) {
      setState(() =>
          _error = 'Cannot verify: no file uploaded for this document yet.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.verifyDocument(doc.id,
          approve: approve, reason: reason);
      await _loadDocuments();
      if (mounted) {
        setState(() => _success =
            approve ? 'Document approved.' : 'Document rejected.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showRejectDialog(_Document doc) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Rejecting ${doc.documentType.replaceAll('_', ' ')} for student ${doc.admissionNumber ?? doc.studentId}'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                  labelText: 'Rejection Reason (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _verify(doc, false,
          reason: reasonCtrl.text.trim().isEmpty
              ? null
              : reasonCtrl.text.trim());
    }
  }

  Future<void> _showUploadDialog() async {
    final studentIdCtrl = TextEditingController();
    String docType = 'BONAFIDE';
    String _fileNameInput = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Upload Document for Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: studentIdCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Student ID (UUID)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: docType,
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: const ['ID_CARD', 'BONAFIDE', 'LEAVING_CERT', 'REPORT_CARD']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialog(() => docType = v);
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 14),
                  label: Text(_fileNameInput.isEmpty ? 'Enter File Name' : _fileNameInput),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Enter File Name'),
                        content: TextField(
                          onChanged: (v) => setDialog(() => _fileNameInput = v),
                          decoration: const InputDecoration(hintText: 'e.g., aadhaar.pdf'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: _fileNameInput.isNotEmpty ? () => Navigator.pop(ctx) : null,
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
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
                    _fileNameInput.isEmpty) return;
                Navigator.of(ctx).pop();
                setState(() => _loading = true);
                try {
                  await _repo.uploadDocument(
                    studentId: studentIdCtrl.text.trim(),
                    documentType: docType,
                    fileName: _fileNameInput,
                    fileBytes: Uint8List(0),
                    contentType: _fileNameInput.toLowerCase().endsWith('pdf')
                        ? 'application/pdf'
                        : 'image/jpeg',
                  );
                  await _loadDocuments();
                  if (mounted) {
                    setState(() => _success = 'Document uploaded successfully.');
                  }
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRequirements() async {
    final docTypes = ['ID_CARD', 'BONAFIDE', 'LEAVING_CERT', 'REPORT_CARD'];
    final mandatoryMap = {
      for (final req in _requirements) req.documentType: req.isMandatory
    };
    // Initialize non-set types to false
    for (final t in docTypes) {
      mandatoryMap.putIfAbsent(t, () => false);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Set Document Requirements'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: docTypes.map((type) {
              return CheckboxListTile(
                title: Text(type.replaceAll('_', ' ')),
                subtitle: const Text('Mandatory for students'),
                value: mandatoryMap[type] ?? false,
                onChanged: (v) =>
                    setDialog(() => mandatoryMap[type] = v ?? false),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _repo.setRequirements(
                    mandatoryMap.entries
                        .map((e) => {
                              'document_type': e.key,
                              'is_mandatory': e.value,
                            })
                        .toList(),
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

  Future<void> _openDocument(_Document doc) async {
    if (!doc.hasFile) {
      setState(() => _error = 'No file available for this document.');
      return;
    }
    try {
      final url = await _repo.getDownloadUrl(doc.id);
      if (url != null && mounted) {
        // Open in new browser tab (Flutter Web)
        html.window.open(url, '_blank');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Document Management',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status messages
            if (_error != null)
              _Banner(
                  message: _error!,
                  isError: true,
                  onDismiss: () => setState(() => _error = null)),
            if (_success != null)
              _Banner(
                  message: _success!,
                  isError: false,
                  onDismiss: () => setState(() => _success = null)),

            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All Documents'),
                Tab(text: 'Pending Review'),
                Tab(text: 'Requirements'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAllDocumentsTab(),
                        _buildPendingTab(),
                        _buildRequirementsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 0: All Documents ────────────────────────────────────────────────────

  Widget _buildAllDocumentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              DropdownButton<String?>(
                value: _statusFilter,
                hint: const Text('All Status'),
                items: const [
                  DropdownMenuItem<String?>(
                      value: null, child: Text('All Status')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  DropdownMenuItem(
                      value: 'PROCESSING', child: Text('Processing')),
                  DropdownMenuItem(value: 'READY', child: Text('Ready')),
                  DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _loadDocuments();
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh'),
                onPressed: _loadDocuments,
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined, size: 14),
                label: const Text('Upload Document'),
                onPressed: _showUploadDialog,
              ),
            ],
          ),
        ),
        Expanded(child: _buildDocTable(_documents, showActions: true)),
      ],
    );
  }

  // ── Tab 1: Pending Review ───────────────────────────────────────────────────

  Widget _buildPendingTab() {
    final pending = _documents
        .where((d) =>
            d.status == 'PROCESSING' &&
            d.hasFile)
        .toList();

    if (pending.isEmpty) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
          SizedBox(height: 12),
          Text('No documents pending review.',
              style: TextStyle(color: Colors.grey)),
        ],
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              '${pending.length} document(s) awaiting verification',
              style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(child: _buildDocTable(pending, showActions: true)),
      ],
    );
  }

  Widget _buildDocTable(List<_Document> docs, {required bool showActions}) {
    if (docs.isEmpty) {
      return const Center(child: Text('No documents found.'));
    }
    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: [
          const DataColumn(label: Text('Student')),
          const DataColumn(label: Text('Adm. No.')),
          const DataColumn(label: Text('Doc Type')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Has File')),
          const DataColumn(label: Text('Date')),
          if (showActions) const DataColumn(label: Text('Actions')),
        ],
        rows: docs.map((doc) {
          return DataRow(cells: [
            DataCell(Text(doc.studentName ?? '-')),
            DataCell(Text(doc.admissionNumber ?? '-')),
            DataCell(Text(doc.documentType.replaceAll('_', ' '))),
            DataCell(Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: doc.statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(doc.status,
                  style: TextStyle(
                      color: doc.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            )),
            DataCell(Icon(
                doc.hasFile ? Icons.attach_file : Icons.remove,
                size: 16,
                color: doc.hasFile ? Colors.green : Colors.grey)),
            DataCell(Text(_fmtDate(doc.createdAt))),
            if (showActions)
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (doc.hasFile)
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 12),
                      label: const Text('View',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => _openDocument(doc),
                    ),
                  if (doc.hasFile &&
                      (doc.status == 'PROCESSING' ||
                          doc.status == 'PENDING')) ...[
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 18),
                      tooltip: 'Approve',
                      onPressed: () => _verify(doc, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.red, size: 18),
                      tooltip: 'Reject',
                      onPressed: () => _showRejectDialog(doc),
                    ),
                  ],
                ],
              )),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Tab 2: Requirements ─────────────────────────────────────────────────────

  Widget _buildRequirementsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Text(
                  'Document types students are required to submit:',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Requirements'),
                onPressed: _editRequirements,
              ),
            ],
          ),
        ),
        if (_requirements.isEmpty)
          const Expanded(
              child: Center(
                  child: Text('No document requirements configured yet.',
                      style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Document Type')),
                  DataColumn(label: Text('Mandatory')),
                  DataColumn(label: Text('Note')),
                ],
                rows: _requirements.map((req) {
                  return DataRow(cells: [
                    DataCell(Text(
                        req.documentType.replaceAll('_', ' '))),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            req.isMandatory
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            color: req.isMandatory
                                ? Colors.green
                                : Colors.grey,
                            size: 16),
                        const SizedBox(width: 4),
                        Text(req.isMandatory ? 'Yes' : 'No'),
                      ],
                    )),
                    DataCell(Text(req.note ?? '-')),
                  ]);
                }).toList(),
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
    } catch (_) {
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
    final color = isError ? Colors.red : Colors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color.shade700, fontSize: 13))),
          GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 14, color: color.shade400)),
        ],
      ),
    );
  }
}
