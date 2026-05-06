import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import 'admin_layout/admin_spacing.dart';

/// Admin table with **virtualized body** ([ListView.builder]) so only visible rows
/// are built. Header + rows share one horizontal scroll (wide tables stay aligned).
class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.totalItems,
    this.currentPage = 1,
    this.pageSize = 10,
    this.onPageChanged,
    this.showPagination = true,
  });

  final List<String> columns;
  final List<DataRow> rows;
  final int? totalItems;
  final int currentPage;
  final int pageSize;
  final ValueChanged<int>? onPageChanged;
  /// When false, shows all [rows] in a vertically scrollable table (no page controls).
  final bool showPagination;

  static const double _minColumnWidth = 96;
  static const double _rowVerticalPadding = 10;
  static const double _headerHeight = 44;

  TextStyle? _headingTextStyle(ThemeData theme) {
    return theme.dataTableTheme.headingTextStyle ??
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
  }

  Color _dataRowBackground(DataRow row, int index, ThemeData theme) {
    final prop = row.color;
    if (prop != null) {
      final states = <WidgetState>{
        if (row.selected) WidgetState.selected,
      };
      var c = prop.resolve(states);
      c ??= prop.resolve({});
      if (c != null) return c;
    }

    final themeDefault = theme.dataTableTheme.dataRowColor;
    if (themeDefault != null) {
      final wStates = <WidgetState>{
        if (row.selected) WidgetState.selected,
      };
      final c = themeDefault.resolve(wStates);
      if (c != null) return c;
    }

    return index.isEven ? AdminColors.surface : AdminColors.rowStripe;
  }

  /// Single horizontal scroll containing header + virtualized rows.
  Widget _virtualTable(ThemeData theme, BoxConstraints constraints) {
    final maxRowCells = rows.fold<int>(
      0,
      (prev, row) => row.cells.length > prev ? row.cells.length : prev,
    );
    final columnCount = math.max(columns.length, maxRowCells);
    if (columnCount == 0) {
      return Center(
        child: Text(
          'No columns',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AdminColors.textSecondary),
        ),
      );
    }

    final tableWidth = math.max(
      constraints.maxWidth,
      columnCount * _minColumnWidth,
    );
    final contentWidth = math.max(0.0, tableWidth - (AdminSpacing.md * 2));
    final colWidth = contentWidth / columnCount;

    final borderSide = BorderSide(color: AdminColors.borderSubtle);
    final headingStyle = _headingTextStyle(theme);

    Widget header() {
      return Container(
        width: tableWidth,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: _rowVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: AdminColors.borderSubtle,
          border: Border(
            top: borderSide,
            bottom: borderSide,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < columnCount; i++)
              SizedBox(
                width: colWidth,
                child: Text(
                  i < columns.length ? columns[i] : '',
                  style: headingStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      );
    }

    Widget rowWidget(int index) {
      final row = rows[index];
      return Container(
        width: tableWidth,
        constraints: const BoxConstraints(
          minHeight: 40,
          maxHeight: 52,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: _dataRowBackground(row, index, theme),
          border: Border(bottom: borderSide),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < columnCount; i++)
              SizedBox(
                width: colWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: i < row.cells.length ? row.cells[i].child : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      );
    }

    final maxH = constraints.maxHeight;
    if (!maxH.isFinite || maxH <= 0) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            header(),
            ...List.generate(rows.length, rowWidget),
          ],
        ),
      );
    }

    final bodyHeight =
        math.max(0.0, maxH - _headerHeight - 8); // small slack for rounding

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(),
            SizedBox(
              height: bodyHeight,
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'No rows',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      itemBuilder: (context, index) => rowWidget(index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalItems ?? rows.length;
    final totalPages = total <= 0 ? 1 : (total / pageSize).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: RepaintBoundary(
                child: _virtualTable(theme, constraints),
              ),
            ),
          ),
        ),
        if (showPagination) ...[
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
        ] else ...[
          SizedBox(height: AdminSpacing.sm),
          Text(
            '${rows.length} ${rows.length == 1 ? 'row' : 'rows'}'
            '${total != rows.length ? ' · $total total' : ''}',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AdminColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
