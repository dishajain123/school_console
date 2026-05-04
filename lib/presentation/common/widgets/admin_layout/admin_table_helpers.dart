import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';

/// Zebra striping + hover for [DataRow] — pass to [DataRow.color].
///
/// ```dart
/// DataRow(
///   color: adminDataRowColor(index),
///   cells: [...],
/// )
/// ```
WidgetStateColor adminDataRowColor(int index) {
  return WidgetStateColor.resolveWith((states) {
    if (states.contains(WidgetState.hovered)) {
      return AdminColors.rowHover;
    }
    if (states.contains(WidgetState.selected)) {
      return AdminColors.primarySubtle.withValues(alpha: 0.65);
    }
    return index.isEven ? AdminColors.surface : AdminColors.rowStripe;
  });
}

/// Optional solid color for the table heading row (use with [DataTable.headingRowColor]).
WidgetStateProperty<Color?> adminTableHeadingRowColor() {
  return const WidgetStatePropertyAll<Color>(AdminColors.borderSubtle);
}
