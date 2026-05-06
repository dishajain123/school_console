import 'admin_document_models.dart';

/// Aggregated fetch for the per-student document admin screen.
class StudentDocumentsOverview {
  const StudentDocumentsOverview({
    required this.checklist,
    required this.documents,
    required this.studentTitle,
  });

  final List<AdminRequirementStatus> checklist;
  final List<AdminDocument> documents;
  final String studentTitle;
}
