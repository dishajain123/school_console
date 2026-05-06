import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';

/// Parsed announcement row for admin Communication UI.
class AdminAnnouncementItem {
  const AdminAnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isActive,
    required this.createdAt,
    this.targetRole,
    this.targetStandardId,
    this.attachmentKey,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isActive;
  final String createdAt;
  final String? targetRole;
  final String? targetStandardId;
  final String? attachmentKey;

  factory AdminAnnouncementItem.fromJson(Map<String, dynamic> j) =>
      AdminAnnouncementItem(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        type: j['type']?.toString() ?? 'GENERAL',
        isActive: j['is_active'] != false,
        createdAt: j['created_at']?.toString() ?? '',
        targetRole: j['target_role'] as String?,
        targetStandardId: j['target_standard_id']?.toString(),
        attachmentKey: j['attachment_key'] as String?,
      );

  Color get typeColor {
    switch (type.toUpperCase()) {
      case 'URGENT':
        return AdminColors.danger;
      case 'FEE':
        return const Color(0xFFEA580C);
      case 'EXAM':
        return AdminColors.primaryAction;
      case 'EVENT':
        return const Color(0xFF7C3AED);
      default:
        return AdminColors.success;
    }
  }
}

class AdminStandardOption {
  const AdminStandardOption({required this.id, required this.name});

  final String id;
  final String name;
}
