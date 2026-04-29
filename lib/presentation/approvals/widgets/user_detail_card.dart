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
            Text(
              item.fullName ?? '-',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Role: ${item.role}'),
            Text('Email: ${item.email ?? '-'}'),
            Text('Phone: ${item.phone ?? '-'}'),
            Text('Status: ${item.status}'),
            Text('Source: ${item.registrationSource}'),
            if (requestedAdmission != null)
              Text('Requested Student Admission No: $requestedAdmission'),
            if (item.rejectionReason != null)
              Text('Rejection: ${item.rejectionReason}'),
            if (item.holdReason != null) Text('Hold: ${item.holdReason}'),
            const Divider(height: 24),
            Text('Validation issues: ${item.validationIssues.length}'),
            Text('Duplicate matches: ${item.duplicateMatches.length}'),
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
              const Text('-')
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
