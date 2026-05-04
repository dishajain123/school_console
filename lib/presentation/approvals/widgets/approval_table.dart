//Users/dishajain/Desktop/admin_console/lib/presentation/approvals/widgets/approval_table.dart
import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../data/models/registration/registration_request.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';
import '../../common/widgets/admin_layout/admin_table_helpers.dart';

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
    final theme = Theme.of(context);
    final allSelected = items.isNotEmpty &&
        items.every((item) => selectedUserIds.contains(item.userId));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: adminTableHeadingRowColor(),
          horizontalMargin: AdminSpacing.md,
          columnSpacing: AdminSpacing.lg,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          dividerThickness: 1,
          border: TableBorder(
            horizontalInside: BorderSide(color: AdminColors.borderSubtle),
            top: BorderSide(color: AdminColors.borderSubtle),
            bottom: BorderSide(color: AdminColors.borderSubtle),
          ),
          columns: [
            DataColumn(
              label: Checkbox(
                value: allSelected,
                onChanged: (v) => onToggleSelectAll(v ?? false),
              ),
            ),
            DataColumn(
              label: Text('Name', style: theme.dataTableTheme.headingTextStyle),
            ),
            DataColumn(
              label: Text('Role', style: theme.dataTableTheme.headingTextStyle),
            ),
            DataColumn(
              label: Text(
                'Student Adm. No',
                style: theme.dataTableTheme.headingTextStyle,
              ),
            ),
            DataColumn(
              label:
                  Text('Contact', style: theme.dataTableTheme.headingTextStyle),
            ),
            DataColumn(
              label:
                  Text('Source', style: theme.dataTableTheme.headingTextStyle),
            ),
            DataColumn(
              label:
                  Text('Status', style: theme.dataTableTheme.headingTextStyle),
            ),
            DataColumn(
              label:
                  Text('Created', style: theme.dataTableTheme.headingTextStyle),
            ),
            DataColumn(
              label: Text(
                'Actions',
                style: theme.dataTableTheme.headingTextStyle,
              ),
            ),
          ],
          rows: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return DataRow(
              color: adminDataRowColor(index),
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
                  SelectableText(
                    item.requestedStudentAdmissionNumber ?? '-',
                  ),
                ),
                DataCell(SelectableText(item.email ?? item.phone ?? '-')),
                DataCell(SelectableText(item.registrationSource)),
                DataCell(SelectableText(item.status)),
                DataCell(SelectableText(item.createdAt.toIso8601String())),
                DataCell(
                  IconButton(
                    tooltip: 'Open',
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    onPressed: () => onOpen(item),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
