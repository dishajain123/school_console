import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/documents/admin_document_models.dart';
import '../../data/models/documents/student_documents_overview.dart';
import 'repository_providers.dart';

final studentDocumentsOverviewProvider = FutureProvider.autoDispose
    .family<StudentDocumentsOverview, String>((ref, studentId) async {
  final repo = ref.watch(adminDocumentRepositoryProvider);
  final results = await Future.wait([
    repo.listRequirementStatus(studentId),
    repo.listStudentDocuments(studentId),
  ]);
  final checklist = results[0] as List<AdminRequirementStatus>;
  final docs = results[1] as List<AdminDocument>;
  var title = 'Student';
  if (docs.isNotEmpty) {
    final name = docs.first.studentName?.trim();
    if (name != null && name.isNotEmpty) title = name;
  }
  return StudentDocumentsOverview(
    checklist: checklist,
    documents: docs,
    studentTitle: title,
  );
});
