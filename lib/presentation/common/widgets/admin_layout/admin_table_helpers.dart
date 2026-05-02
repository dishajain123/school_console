import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';

/// Zebra + hover for [DataTable] rows (index 0-based).
WidgetStateColor adminDataRowColor(int index) {
  return WidgetStateColor.resolveWith((states) {
    if (states.contains(WidgetState.hovered)) {
      return AdminColors.rowHover;
    }
    return index.isEven ? AdminColors.surface : AdminColors.rowStripe;
  });
}
