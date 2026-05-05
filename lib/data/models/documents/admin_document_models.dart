import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';

/// Mirrors backend document row for admin lists.
class AdminDocument {
  const AdminDocument({
    required this.id,
    required this.studentId,
    required this.documentType,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.studentName,
    this.admissionNumber,
    this.fileKey,
    this.reviewNote,
    this.adminComment,
    this.reviewedAt,
    this.academicYearId,
    this.isSynthetic = false,
  });

  final String id;
  final String studentId;
  final String documentType;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final String? studentName;
  final String? admissionNumber;
  final String? fileKey;
  final String? reviewNote;
  final String? adminComment;
  final String? reviewedAt;
  final String? academicYearId;
  final bool isSynthetic;

  bool get hasFile => fileKey != null && fileKey!.trim().isNotEmpty;

  String get combinedComment =>
      (adminComment ?? '').trim().isNotEmpty
          ? adminComment!.trim()
          : (reviewNote ?? '').trim();

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AdminColors.success;
      case 'PENDING':
        return const Color(0xFFEA580C);
      case 'NOT_UPLOADED':
        return AdminColors.textMuted;
      case 'REQUESTED':
        return AdminColors.primaryAction;
      case 'REJECTED':
        return AdminColors.danger;
      default:
        return AdminColors.textMuted;
    }
  }

  factory AdminDocument.fromJson(Map<String, dynamic> j) => AdminDocument(
        id: j['id']?.toString() ?? '',
        studentId: j['student_id']?.toString() ?? '',
        documentType: j['document_type']?.toString() ?? '',
        status: j['status']?.toString() ?? 'NOT_UPLOADED',
        createdAt: j['created_at']?.toString() ?? '',
        updatedAt: j['updated_at']?.toString(),
        studentName: j['student_name'] as String?,
        admissionNumber: j['student_admission_number'] as String?,
        fileKey: j['file_key'] as String?,
        reviewNote: j['review_note'] as String?,
        adminComment: j['admin_comment'] as String?,
        reviewedAt: j['reviewed_at']?.toString(),
        academicYearId: j['academic_year_id']?.toString(),
        isSynthetic: j['is_synthetic'] == true,
      );
}

class AdminDocRequirement {
  const AdminDocRequirement({
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

  factory AdminDocRequirement.fromJson(Map<String, dynamic> j) =>
      AdminDocRequirement(
        documentType: j['document_type']?.toString() ?? '',
        isMandatory: j['is_mandatory'] == true,
        note: j['note'] as String?,
        academicYearId: j['academic_year_id']?.toString(),
        standardId: j['standard_id']?.toString(),
      );
}

/// Row from GET /documents/requirements/status
class AdminRequirementStatus {
  const AdminRequirementStatus({
    required this.documentType,
    required this.isMandatory,
    this.note,
    this.latestDocumentId,
    this.latestStatus,
    this.uploadedAt,
    this.reviewNote,
    this.reviewedAt,
    this.needsReupload = false,
    this.isCompleted = false,
    this.academicYearId,
    this.standardId,
  });

  final String documentType;
  final bool isMandatory;
  final String? note;
  final String? latestDocumentId;
  final String? latestStatus;
  final String? uploadedAt;
  final String? reviewNote;
  final String? reviewedAt;
  final bool needsReupload;
  final bool isCompleted;
  final String? academicYearId;
  final String? standardId;

  bool get hasPendingFile =>
      latestStatus != null &&
      latestStatus!.toUpperCase() == 'PENDING' &&
      (latestDocumentId != null && latestDocumentId!.trim().isNotEmpty);

  factory AdminRequirementStatus.fromJson(Map<String, dynamic> j) =>
      AdminRequirementStatus(
        documentType: j['document_type']?.toString() ?? '',
        isMandatory: j['is_mandatory'] as bool? ?? true,
        note: j['note'] as String?,
        latestDocumentId: j['latest_document_id']?.toString(),
        latestStatus: j['latest_status']?.toString(),
        uploadedAt: j['uploaded_at']?.toString(),
        reviewNote: j['review_note'] as String?,
        reviewedAt: j['reviewed_at']?.toString(),
        needsReupload: j['needs_reupload'] as bool? ?? false,
        isCompleted: j['is_completed'] as bool? ?? false,
        academicYearId: j['academic_year_id']?.toString(),
        standardId: j['standard_id']?.toString(),
      );
}
