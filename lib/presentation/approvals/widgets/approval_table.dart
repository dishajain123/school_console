//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/widgets/approval_table.dart
import 'package:flutter/material.dart';

import '../../../data/models/registration/registration_request.dart';

class ApprovalTable extends StatelessWidget {
  const ApprovalTable({
    super.key,
    required this.items,
    required this.onOpen,
    required this.selectedUserIds,
    required this.onToggleSelect,
    required this.onToggleSelectAll,
  });

  final List<RegistrationRequest> items;
  final void Function(RegistrationRequest item) onOpen;
  final Set<String> selectedUserIds;
  final void Function(String userId, bool selected) onToggleSelect;
  final void Function(bool selected) onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    final allSelected = items.isNotEmpty &&
        items.every((item) => selectedUserIds.contains(item.userId));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
            label: Checkbox(
              value: allSelected,
              onChanged: (v) => onToggleSelectAll(v ?? false),
            ),
          ),
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
                  DataCell(
                    Checkbox(
                      value: selectedUserIds.contains(item.userId),
                      onChanged: (v) =>
                          onToggleSelect(item.userId, v ?? false),
                    ),
                  ),
                  DataCell(SelectableText(item.fullName ?? '-')),
                  DataCell(SelectableText(item.role)),
                  DataCell(
                    SelectableText(item.requestedStudentAdmissionNumber ?? '-'),
                  ),
                  DataCell(SelectableText(item.email ?? item.phone ?? '-')),
                  DataCell(SelectableText(item.registrationSource)),
                  DataCell(SelectableText(item.status)),
                  DataCell(SelectableText(item.createdAt.toIso8601String())),
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
