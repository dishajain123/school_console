//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/widgets/user_detail_card.dart
import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../data/models/registration/registration_request.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_surface_card.dart';

class UserDetailCard extends StatelessWidget {
  const UserDetailCard({super.key, required this.item});

  final RegistrationRequest item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requestedAdmission = item.requestedStudentAdmissionNumber;
    final submittedEntries = (item.submittedData ?? const <String, dynamic>{})
        .entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            item.fullName ?? '-',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: AdminSpacing.md),
          _DetailLine(label: 'Role', value: item.role),
          _DetailLine(label: 'Email', value: item.email ?? '-'),
          _DetailLine(label: 'Phone', value: item.phone ?? '-'),
          _DetailLine(label: 'Status', value: item.status),
          _DetailLine(label: 'Source', value: item.registrationSource),
          if (requestedAdmission != null)
            _DetailLine(
              label: 'Requested student admission no.',
              value: requestedAdmission,
            ),
          if (item.rejectionReason != null)
            _DetailLine(label: 'Rejection', value: item.rejectionReason!),
          if (item.holdReason != null)
            _DetailLine(label: 'Hold', value: item.holdReason!),
          const Divider(height: AdminSpacing.lg, color: AdminColors.borderSubtle),
          _DetailLine(
            label: 'Validation issues',
            value: '${item.validationIssues.length}',
          ),
          _DetailLine(
            label: 'Duplicate matches',
            value: '${item.duplicateMatches.length}',
          ),
          if (item.validationIssues.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.sm),
            Text(
              'Validation findings',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            ...item.validationIssues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '· ${issue.toString()}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
          if (item.duplicateMatches.isNotEmpty) ...[
            const SizedBox(height: AdminSpacing.sm),
            Text(
              'Duplicate matches',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            ...item.duplicateMatches.map(
              (dup) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '· ${dup.toString()}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
          const SizedBox(height: AdminSpacing.md),
          Text(
            'Submitted data',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: AdminSpacing.xs),
          if (submittedEntries.isEmpty)
            SelectableText(
              '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AdminColors.textMuted,
              ),
            )
          else
            ...submittedEntries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SelectableText(
                  '${e.key}: ${e.value}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AdminColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AdminColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
