import 'package:flutter/material.dart';

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
    final total = totalItems ?? rows.length;
    final totalPages = total <= 0 ? 1 : (total / pageSize).ceil();

    return Column(
      children: [
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
                rows: rows,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Page $currentPage of $totalPages'),
            const SizedBox(width: 8),
            IconButton(
              onPressed: currentPage > 1 && onPageChanged != null
                  ? () => onPageChanged!(currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: currentPage < totalPages && onPageChanged != null
                  ? () => onPageChanged!(currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
