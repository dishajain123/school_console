//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/widgets/user_detail_card.dart
import 'package:flutter/material.dart';

import '../../../data/models/registration/registration_request.dart';

class UserDetailCard extends StatelessWidget {
  const UserDetailCard({super.key, required this.item});

  final RegistrationRequest item;

  @override
  Widget build(BuildContext context) {
    final requestedAdmission = item.requestedStudentAdmissionNumber;
    final submittedEntries = (item.submittedData ?? const <String, dynamic>{})
        .entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              item.fullName ?? '-',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SelectableText('Role: ${item.role}'),
            SelectableText('Email: ${item.email ?? '-'}'),
            SelectableText('Phone: ${item.phone ?? '-'}'),
            SelectableText('Status: ${item.status}'),
            SelectableText('Source: ${item.registrationSource}'),
            if (requestedAdmission != null)
              SelectableText('Requested Student Admission No: $requestedAdmission'),
            if (item.rejectionReason != null)
              SelectableText('Rejection: ${item.rejectionReason}'),
            if (item.holdReason != null) SelectableText('Hold: ${item.holdReason}'),
            const Divider(height: 24),
            SelectableText('Validation issues: ${item.validationIssues.length}'),
            SelectableText('Duplicate matches: ${item.duplicateMatches.length}'),
            if (item.validationIssues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Validation Findings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              ...item.validationIssues.map(
                (issue) => SelectableText('- ${issue.toString()}'),
              ),
            ],
            if (item.duplicateMatches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Duplicate Matches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              ...item.duplicateMatches.map(
                (dup) => SelectableText('- ${dup.toString()}'),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Submitted data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            if (submittedEntries.isEmpty)
              const SelectableText('-')
            else
              ...submittedEntries.map(
                (entry) => SelectableText('${entry.key}: ${entry.value}'),
              ),
          ],
        ),
      ),
    );
  }
}
