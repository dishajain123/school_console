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
import '../../common/widgets/admin_layout/admin_surface_card.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';

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
        reviewedAt: j['reviewed_at']?.toString(),
        academicYearId: j['academic_year_id']?.toString(),
      );
}

class _DocRequirement {
  const _DocRequirement({
    required this.documentType,
    required this.isMandatory,
    this.note,
    this.academicYearId,
    this.standardId,
  });

  final String documentType;
  final bool isMandatory;
  final String? note;
  final String? academicYearId;
  final String? standardId;

  factory _DocRequirement.fromJson(Map<String, dynamic> j) => _DocRequirement(
        documentType: j['document_type']?.toString() ?? '',
        isMandatory: j['is_mandatory'] == true,
        note: j['note'] as String?,
        academicYearId: j['academic_year_id']?.toString(),
        standardId: j['standard_id']?.toString(),
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class _DocRepository {
  _DocRepository(this._dio);
  final DioClient _dio;

  Future<List<Map<String, dynamic>>> listYears() async {
    final r =
        await _dio.dio.get<Map<String, dynamic>>(ApiConstants.academicYears);
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listStandards(String yearId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.standards,
      queryParameters: {'academic_year_id': yearId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<_Document>> listAllDocuments({
    String? academicYearId,
    String? standardId,
    String? section,
  }) async {
    final query = <String, dynamic>{
      if (academicYearId != null && academicYearId.trim().isNotEmpty) 'academic_year_id': academicYearId,
      if (standardId != null && standardId.trim().isNotEmpty) 'standard_id': standardId,
      if (section != null && section.trim().isNotEmpty) 'section': section.trim(),
    };
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.documents,
      queryParameters: query.isEmpty ? null : query,
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _Document.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<_Document>> listStudentDocuments(String studentId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.documents,
      queryParameters: {'student_id': studentId},
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _Document.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String?> getDownloadUrl(String docId) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.documentDownload(docId),
    );
    return r.data?['url'] as String?;
  }

  Future<void> verifyDocument(String docId,
      {required bool approve, String? reason}) async {
    await _dio.dio.patch<dynamic>(
      ApiConstants.documentVerify(docId),
      data: {
        'approve': approve,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<List<_DocRequirement>> getRequirements() async {
    final r = await _dio.dio
        .get<Map<String, dynamic>>(ApiConstants.documentRequirements);
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => _DocRequirement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setRequirements(List<Map<String, dynamic>> items) async {
    await _dio.dio.put<dynamic>(
      ApiConstants.documentRequirements,
      data: {'items': items},
    );
  }

  Future<_Document> uploadDocument({
    required String studentId,
    required String documentType,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
    String? note,
  }) async {
    final formData = FormData.fromMap({
      'student_id': studentId,
      'document_type': documentType,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'file': MultipartFile.fromBytes(fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType)),
    });
    final r = await _dio.dio.post<Map<String, dynamic>>(
      ApiConstants.documentUpload,
      data: formData,
    );
    return _Document.fromJson(r.data ?? {});
  }

  Future<Map<String, dynamic>> listSchoolUsers({
    int page = 1,
    int pageSize = 100,
  }) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.users,
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  Future<List<Map<String, dynamic>>> listStudents({
    String? academicYearId,
    int page = 1,
    int pageSize = 200,
  }) async {
    final r = await _dio.dio.get<Map<String, dynamic>>(
      ApiConstants.students,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (academicYearId != null && academicYearId.trim().isNotEmpty)
          'academic_year_id': academicYearId.trim(),
      },
    );
    return ((r.data?['items'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  /// Full list from last API load (unfiltered). Used for Pending Review + student filter.
  List<_Document> _allDocumentsRaw = [];
  List<_Document> _documents = [];
  List<_DocRequirement> _requirements = [];
  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _standards = [];
  String? _selectedYearId;
  String? _selectedStandardId;

  List<Map<String, dynamic>> _directoryUsers = [];
  bool _usersLoading = false;
  String? _usersListError;
  int _usersPage = 1;
  int _usersTotalPages = 1;
  final TextEditingController _sectionCtrl = TextEditingController();
  final TextEditingController _studentNameSearchCtrl = TextEditingController();

  String? _statusFilter;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _repo = _DocRepository(ref.read(dioClientProvider));
    _loadMeta();
    _loadDocuments();
    _loadRequirements();
    _loadDirectoryUsers();
  }

  Future<void> _loadDirectoryUsers({int page = 1}) async {
    setState(() {
      _usersLoading = true;
      _usersListError = null;
    });
    try {
      final raw = await _repo.listSchoolUsers(page: page, pageSize: 100);
      final items = ((raw['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final totalPages = raw['total_pages'];
      if (!mounted) return;
      setState(() {
        _directoryUsers = items;
        _usersPage = page;
        _usersTotalPages = totalPages is int ? totalPages : int.tryParse('$totalPages') ?? 1;
      });
    } catch (e) {
      if (mounted) setState(() => _usersListError = e.toString());
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
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
      if (!mounted) return;
      setState(() {
        _years = years;
        _selectedYearId = yearId;
        _standards = standards;
      });
      ref.read(activeAcademicYearProvider.notifier).setYear(yearId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sectionCtrl.dispose();
    _studentNameSearchCtrl.dispose();
    super.dispose();
  }

  bool _documentMatchesStudentNameSearch(_Document d) {
    final q = _studentNameSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (d.studentName ?? '').toLowerCase().contains(q);
  }

  void _resetUnifiedFilters() {
    setState(() {
      _studentNameSearchCtrl.clear();
      _selectedStandardId = null;
      _sectionCtrl.clear();
      _statusFilter = null;
    });
    _loadDocuments();
  }

  void _applyDocumentFilters() {
    var list = List<_Document>.from(_allDocumentsRaw);
    list = list.where(_documentMatchesStudentNameSearch).toList(growable: false);
    if (_statusFilter == null) {
      _documents = list;
    } else if (_statusFilter == 'AWAITING_ADMIN') {
      _documents = list
          .where((d) =>
              d.status.toUpperCase() == 'PENDING' && !d.hasFile)
          .toList(growable: false);
    } else {
      _documents = list
          .where((d) => d.status.toUpperCase() == _statusFilter)
          .toList(growable: false);
    }
  }

  bool _canVerifyInUi(_Document doc) {
    if (!doc.hasFile) return false;
    final reviewed = (doc.reviewedAt ?? '').trim().isNotEmpty;
    if (reviewed) return false;
    return doc.status.toUpperCase() == 'PROCESSING';
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await _repo.listAllDocuments(
        academicYearId: _selectedYearId,
        standardId: _selectedStandardId,
        section: _sectionCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _allDocumentsRaw = docs;
        _applyDocumentFilters();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
    List<Map<String, dynamic>> studentChoices = [];
    try {
      studentChoices = await _repo.listStudents(
        academicYearId: _selectedYearId,
      );
    } catch (_) {}

    final studentIdCtrl = TextEditingController();
    String docType = 'BONAFIDE';
    final otherNameCtrl = TextEditingController();
    String _fileNameInput = '';
    Uint8List? _fileBytes;
    String _contentType = 'application/pdf';
    String? pickedStudentId;

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
                    value: pickedStudentId,
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
                  value: docType,
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
                  label: Text(_fileNameInput.isEmpty ? 'Choose File' : _fileNameInput),
                  onPressed: () {
                    final input = html.FileUploadInputElement()
                      ..accept = '.pdf,.jpg,.jpeg,.png'
                      ..click();
                    input.onChange.listen((_) {
                      final files = input.files;
                      if (files == null || files.isEmpty) return;
                      final file = files.first;
                      final reader = html.FileReader();
                      reader.readAsArrayBuffer(file);
                      reader.onLoadEnd.listen((_) {
                        final result = reader.result;
                        if (result is ByteBuffer) {
                          setDialog(() {
                            _fileNameInput = file.name;
                            _contentType = file.type.isNotEmpty
                                ? file.type
                                : (_fileNameInput.toLowerCase().endsWith('.pdf')
                                    ? 'application/pdf'
                                    : 'image/jpeg');
                            _fileBytes = Uint8List.view(result);
                          });
                        }
                      });
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
                    _fileNameInput.isEmpty ||
                    _fileBytes == null ||
                    _fileBytes!.isEmpty) return;
                Navigator.of(ctx).pop();
                setState(() => _loading = true);
                try {
                  final note = docType == 'OTHER'
                      ? otherNameCtrl.text.trim()
                      : null;
                  if (docType == 'OTHER' && (note == null || note.isEmpty)) {
                    if (mounted) {
                      setState(() => _error = 'Please enter Other document name.');
                    }
                    return;
                  }
                  await _repo.uploadDocument(
                    studentId: studentIdCtrl.text.trim(),
                    documentType: docType,
                    note: note,
                    fileName: _fileNameInput,
                    fileBytes: _fileBytes!,
                    contentType: _contentType,
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
                  value: scopeYearId,
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
                    value: scopeStandardId,
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
                                  value: docTypes.contains(selectedType)
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
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                            ],
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Mandatory'),
                            value: item['is_mandatory'] == true,
                            onChanged: (v) => setDialog(
                                () => editableItems[index]['is_mandatory'] = v ?? true),
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
                    final mandatory = row['is_mandatory'] == true;
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
                      'is_mandatory': mandatory,
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

  Future<void> _showDocumentReviewDialog(_Document doc) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Review document'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc.studentName ?? 'Student',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text('Admission: ${doc.admissionNumber ?? '—'}'),
                Text('Student ID: ${doc.studentId}'),
                const SizedBox(height: 8),
                Text(
                  'Document: ${doc.documentType.replaceAll('_', ' ')}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('Status: ${doc.status}'),
                if ((doc.reviewNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Previous note: ${doc.reviewNote}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                if (!doc.hasFile)
                  const Text(
                    'No file attached yet. Upload a file from “Upload Document” or wait for the family to upload.',
                    style: TextStyle(color: Colors.orange),
                  )
                else if (!_canVerifyInUi(doc) &&
                    doc.status.toUpperCase() == 'READY')
                  const Text(
                    'This document is already verified.',
                    style: TextStyle(color: Colors.green),
                  )
                else if (!_canVerifyInUi(doc) &&
                    doc.status.toUpperCase() == 'FAILED')
                  const Text(
                    'This document was rejected. The family may upload again.',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (doc.hasFile)
            OutlinedButton.icon(
              onPressed: () async {
                await _openDocument(doc);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View file'),
            ),
          if (_canVerifyInUi(doc)) ...[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(ctx).pop();
                _showRejectDialog(doc);
              },
              child: const Text('Reject'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _verify(doc, true);
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Verify (approve)'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: '',
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
                  'Review uploads, verify submissions, and manage requirements.',
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
            if (!_loading)
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
                                value: _selectedYearId,
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
                                    _standards = [];
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
                                  _loadDocuments();
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldW(140),
                              child: DropdownButtonFormField<String?>(
                                value: _selectedStandardId,
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
                                onChanged: (v) {
                                  setState(() => _selectedStandardId = v);
                                  _loadDocuments();
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldW(88),
                              child: TextField(
                                controller: _sectionCtrl,
                                style: const TextStyle(fontSize: 14),
                                decoration: const InputDecoration(
                                  labelText: 'Sec.',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (_) => _loadDocuments(),
                              ),
                            ),
                            SizedBox(
                              width: fieldW(148),
                              child: DropdownButtonFormField<String?>(
                                value: _statusFilter,
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
                                  DropdownMenuItem(
                                    value: 'AWAITING_ADMIN',
                                    child: Text('Awaiting admin'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'PENDING',
                                    child: Text('Pending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'PROCESSING',
                                    child: Text('Processing'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'READY',
                                    child: Text('Ready'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'FAILED',
                                    child: Text('Failed'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _statusFilter = v;
                                    _applyDocumentFilters();
                                  });
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
                          Tab(text: 'Pending review'),
                          Tab(text: 'Requirements'),
                          Tab(text: 'Users'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _loading
                          ? const AdminLoadingPlaceholder()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildAllDocumentsTab(),
                                _buildPendingTab(),
                                _buildRequirementsTab(),
                                _buildUsersTab(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.md,
        AdminSpacing.sm,
        AdminSpacing.md,
        AdminSpacing.md,
      ),
      child: _buildDocTable(_documents, showActions: true),
    );
  }

  // ── Tab 1: Pending Review ───────────────────────────────────────────────────

  Widget _buildPendingTab() {
    // Same raw load as “All documents”, not the status-filtered `_documents` list.
    var base = List<_Document>.from(_allDocumentsRaw)
        .where(_documentMatchesStudentNameSearch)
        .toList(growable: false);
    // Awaiting admin verification: uploaded (PROCESSING), not yet reviewed.
    final pending = base
        .where((d) =>
            d.hasFile &&
            (d.reviewedAt == null || d.reviewedAt!.trim().isEmpty) &&
            d.status.toUpperCase() == 'PROCESSING')
        .toList(growable: false);

    if (pending.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No documents pending review',
        message: 'Everything in this queue is up to date.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.md,
            AdminSpacing.sm,
            AdminSpacing.md,
            AdminSpacing.sm,
          ),
          child: Text(
            '${pending.length} awaiting verification',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AdminColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.md,
              0,
              AdminSpacing.md,
              AdminSpacing.md,
            ),
            child: _buildDocTable(pending, showActions: true),
          ),
        ),
      ],
    );
  }

  Widget _buildDocTable(List<_Document> docs, {required bool showActions}) {
    if (docs.isEmpty) {
      return const AdminEmptyState(
        title: 'No documents match these filters',
        message: 'Adjust filters or refresh to reload.',
      );
    }
    final rows = docs.asMap().entries.map((entry) {
      final index = entry.key;
      final doc = entry.value;
      final statusLabel = doc.status.toUpperCase() == 'READY'
          ? 'VERIFIED'
          : (doc.status.toUpperCase() == 'FAILED'
              ? 'REJECTED'
              : doc.status);
      return DataRow(
        color: adminDataRowColor(index),
        cells: [
          DataCell(Text(doc.studentName ?? '-')),
          DataCell(Text(doc.admissionNumber ?? '-')),
          DataCell(Text(doc.documentType.replaceAll('_', ' '))),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          DataCell(
            Icon(
              doc.hasFile ? Icons.attach_file_outlined : Icons.remove_outlined,
              size: 18,
              color: doc.hasFile
                  ? AdminColors.textSecondary
                  : AdminColors.textMuted,
            ),
          ),
          DataCell(Text(_fmtDate(doc.createdAt))),
          if (showActions)
            DataCell(
              IconButton(
                tooltip:
                    _canVerifyInUi(doc) ? 'Review document' : 'View details',
                icon: Icon(
                  _canVerifyInUi(doc)
                      ? Icons.fact_check_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AdminColors.textSecondary,
                ),
                onPressed: () => _showDocumentReviewDialog(doc),
              ),
            ),
          if (showActions)
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (doc.hasFile)
                    IconButton(
                      tooltip: 'Open file',
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        size: 20,
                        color: AdminColors.textSecondary,
                      ),
                      onPressed: () => _openDocument(doc),
                    ),
                  if (_canVerifyInUi(doc)) ...[
                    IconButton(
                      tooltip: 'Approve',
                      icon: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: AdminColors.primaryAction,
                      ),
                      onPressed: () => _verify(doc, true),
                    ),
                    IconButton(
                      tooltip: 'Reject',
                      icon: Icon(
                        Icons.cancel_outlined,
                        size: 20,
                        color: AdminColors.textSecondary,
                      ),
                      onPressed: () => _showRejectDialog(doc),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AdminColors.borderSubtle),
          border: TableBorder(
            horizontalInside: BorderSide(color: AdminColors.border),
            top: BorderSide(color: AdminColors.border),
            bottom: BorderSide(color: AdminColors.border),
          ),
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            const DataColumn(label: Text('Student')),
            const DataColumn(label: Text('Adm. No.')),
            const DataColumn(label: Text('Doc type')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('File')),
            const DataColumn(label: Text('Date')),
            if (showActions) const DataColumn(label: Text('Review')),
            if (showActions) const DataColumn(label: Text('')),
          ],
          rows: rows,
        ),
      ),
    );
  }

  // ── Tab 2: Requirements ─────────────────────────────────────────────────────

  Widget _buildRequirementsTab() {
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
                    headingRowColor:
                        WidgetStateProperty.all(AdminColors.borderSubtle),
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
                      DataColumn(label: Text('Mandatory')),
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
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  req.isMandatory
                                      ? Icons.check_circle_outline
                                      : Icons.radio_button_unchecked,
                                  color: req.isMandatory
                                      ? AdminColors.primaryAction
                                      : AdminColors.textMuted,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  req.isMandatory ? 'Yes' : 'No',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AdminColors.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildUsersTab() {
    if (_usersListError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: Text(
            _usersListError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      );
    }
    if (_usersLoading) {
      return const AdminLoadingPlaceholder();
    }
    if (_directoryUsers.isEmpty) {
      return const AdminEmptyState(
        title: 'No users in this page',
        message: 'Try another page or confirm your account can list school users.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.md,
            AdminSpacing.sm,
            AdminSpacing.md,
            AdminSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                'Page $_usersPage / $_usersTotalPages · ${_directoryUsers.length} rows',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdminColors.textSecondary,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _usersLoading
                    ? null
                    : () => _loadDirectoryUsers(page: _usersPage > 1 ? _usersPage - 1 : 1),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Prev'),
              ),
              TextButton.icon(
                onPressed: _usersLoading || _usersPage >= _usersTotalPages
                    ? null
                    : () => _loadDirectoryUsers(page: _usersPage + 1),
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Next'),
              ),
              FilledButton.tonal(
                onPressed: _usersLoading ? null : () => _loadDirectoryUsers(page: _usersPage),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.md,
              0,
              AdminSpacing.md,
              AdminSpacing.md,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AdminColors.borderSubtle),
                  border: TableBorder(
                    horizontalInside: BorderSide(color: AdminColors.border),
                    top: BorderSide(color: AdminColors.border),
                    bottom: BorderSide(color: AdminColors.border),
                  ),
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Active')),
                  ],
                  rows: _directoryUsers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final u = entry.value;
                    final name = u['full_name']?.toString() ?? '—';
                    final email = u['email']?.toString() ?? '—';
                    final phone = u['phone']?.toString() ?? '—';
                    final role = u['role']?.toString() ?? '—';
                    final active = u['is_active'] == true;
                    return DataRow(
                      color: adminDataRowColor(i),
                      cells: [
                        DataCell(SelectableText(name)),
                        DataCell(SelectableText(email)),
                        DataCell(SelectableText(phone)),
                        DataCell(Text(role)),
                        DataCell(
                          Icon(
                            active ? Icons.check_circle_outline : Icons.cancel_outlined,
                            size: 16,
                            color: active ? Colors.green : AdminColors.textMuted,
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
