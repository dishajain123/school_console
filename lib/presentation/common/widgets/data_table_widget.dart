import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import 'admin_layout/admin_spacing.dart';
import 'admin_layout/admin_table_helpers.dart';

class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.totalItems,
    this.currentPage = 1,
    this.pageSize = 10,
    this.onPageChanged,
  });

  final List<String> columns;
  final List<DataRow> rows;
  final int? totalItems;
  final int currentPage;
  final int pageSize;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalItems ?? rows.length;
    final totalPages = total <= 0 ? 1 : (total / pageSize).ceil();

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: adminTableHeadingRowColor(),
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 48,
                    horizontalMargin: AdminSpacing.md,
                    columnSpacing: AdminSpacing.lg,
                    dividerThickness: 1,
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: AdminColors.borderSubtle,
                      ),
                      top: BorderSide(color: AdminColors.borderSubtle),
                      bottom: BorderSide(color: AdminColors.borderSubtle),
                    ),
                    columns: columns
                        .map(
                          (c) => DataColumn(
                            label: Text(
                              c,
                              style: theme.dataTableTheme.headingTextStyle,
                            ),
                          ),
                        )
                        .toList(),
                    rows: rows,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: AdminSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Page $currentPage of $totalPages',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AdminColors.textSecondary,
              ),
            ),
            const SizedBox(width: AdminSpacing.xs),
            IconButton(
              tooltip: 'Previous page',
              onPressed: currentPage > 1 && onPageChanged != null
                  ? () => onPageChanged!(currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: currentPage < totalPages && onPageChanged != null
                  ? () => onPageChanged!(currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
