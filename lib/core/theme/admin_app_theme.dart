import 'package:flutter/material.dart';

import 'admin_colors.dart';

/// Premium minimal dashboard theme — logic-free styling only.
ThemeData buildAdminTheme() {
  const radius = 10.0;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AdminColors.primaryAction,
    brightness: Brightness.light,
    surface: AdminColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AdminColors.canvas,
    visualDensity: VisualDensity.standard,
    dividerTheme: const DividerThemeData(
      color: AdminColors.borderSubtle,
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      color: AdminColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AdminColors.border),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide:
            const BorderSide(color: AdminColors.primaryAction, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        side: const BorderSide(color: AdminColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowHeight: 44,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 52,
      dividerThickness: 1,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminColors.borderSubtle),
        ),
      ),
      headingTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AdminColors.textSecondary,
        letterSpacing: 0.2,
      ),
      dataTextStyle: const TextStyle(
        fontSize: 13,
        color: AdminColors.textPrimary,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: AdminColors.border,
      labelColor: AdminColors.primaryAction,
      unselectedLabelColor: AdminColors.textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle:
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AdminColors.textPrimary,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AdminColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: AdminColors.textSecondary, size: 22),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AdminColors.textPrimary,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AdminColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AdminColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: AdminColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AdminColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AdminColors.textPrimary,
      ),
    ),
  );
}
