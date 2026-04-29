import 'package:flutter/material.dart';

import '../../../data/models/registration/registration_request.dart';

class ApprovalTable extends StatelessWidget {
  const ApprovalTable({super.key, required this.items, required this.onOpen});

  final List<RegistrationRequest> items;
  final void Function(RegistrationRequest item) onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Student Adm. No')),
          DataColumn(label: Text('Contact')),
          DataColumn(label: Text('Source')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Created')),
          DataColumn(label: Text('Action')),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.fullName ?? '-')),
                  DataCell(Text(item.role)),
                  DataCell(Text(item.requestedStudentAdmissionNumber ?? '-')),
                  DataCell(Text(item.email ?? item.phone ?? '-')),
                  DataCell(Text(item.registrationSource)),
                  DataCell(Text(item.status)),
                  DataCell(Text(item.createdAt.toIso8601String())),
                  DataCell(
                    TextButton(
                      onPressed: () => onOpen(item),
                      child: const Text('Open'),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
