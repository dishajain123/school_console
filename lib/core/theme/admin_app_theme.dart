// lib/core/theme/admin_app_theme.dart  [Admin Console]
import 'package:flutter/material.dart';

import 'admin_colors.dart';

/// Premium minimal dashboard theme — logic-free styling only.
ThemeData buildAdminTheme() {
  const radius = 10.0;
  const radiusSm = 8.0;

  final baseScheme = ColorScheme.fromSeed(
    seedColor: AdminColors.primaryAction,
    brightness: Brightness.light,
    surface: AdminColors.surface,
    primary: AdminColors.primaryAction,
    onPrimary: AdminColors.textOnPrimary,
    error: AdminColors.danger,
    onError: AdminColors.textOnPrimary,
  );

  final colorScheme = baseScheme.copyWith(
    surface: AdminColors.surface,
    onSurface: AdminColors.textPrimary,
    onSurfaceVariant: AdminColors.textSecondary,
    outline: AdminColors.border,
    outlineVariant: AdminColors.borderSubtle,
    surfaceContainerHighest: AdminColors.rowHover,
  );

  final filledButtonStyle = ButtonStyle(
    elevation: const WidgetStatePropertyAll<double>(0),
    shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
    ),
    foregroundColor: const WidgetStatePropertyAll(AdminColors.textOnPrimary),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AdminColors.border;
      }
      if (states.contains(WidgetState.pressed)) {
        return AdminColors.primaryPressed;
      }
      if (states.contains(WidgetState.hovered)) {
        return AdminColors.primaryHover;
      }
      return AdminColors.primaryAction;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.black.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.hovered)) {
        return Colors.white.withValues(alpha: 0.10);
      }
      return null;
    }),
  );

  final outlinedButtonStyle = ButtonStyle(
    elevation: const WidgetStatePropertyAll<double>(0),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
    ),
    foregroundColor: const WidgetStatePropertyAll(AdminColors.textPrimary),
    side: WidgetStateProperty.resolveWith((states) {
      final hovered = states.contains(WidgetState.hovered);
      final pressed = states.contains(WidgetState.pressed);
      return BorderSide(
        color: (hovered || pressed)
            ? AdminColors.textMuted
            : AdminColors.border,
        width: 1,
      );
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return AdminColors.rowHover;
      }
      return Colors.transparent;
    }),
  );

  final textButtonStyle = ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AdminColors.textMuted;
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed)) {
        return AdminColors.primaryPressed;
      }
      return AdminColors.primaryAction;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return AdminColors.primarySubtle.withValues(alpha: 0.6);
      }
      return null;
    }),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AdminColors.canvas,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
    dividerTheme: const DividerThemeData(
      color: AdminColors.borderSubtle,
      thickness: 1,
      space: 1,
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
      hoverColor: AdminColors.rowHover,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AdminColors.textMuted,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AdminColors.textSecondary,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AdminColors.primaryAction,
      ),
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
        borderSide: const BorderSide(
          color: AdminColors.primaryAction,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AdminColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AdminColors.danger, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filledButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
    textButtonTheme: TextButtonThemeData(style: textButtonStyle),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AdminColors.textSecondary,
        hoverColor: AdminColors.rowHover,
        highlightColor: AdminColors.primarySubtle.withValues(alpha: 0.5),
        focusColor: AdminColors.focusRing,
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(40, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 4),
      decoration: BoxDecoration(
        color: AdminColors.textPrimary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      textStyle: const TextStyle(
        color: AdminColors.textOnPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(8),
      thickness: WidgetStateProperty.all(6),
      thumbColor: WidgetStateProperty.all(
        AdminColors.textMuted.withValues(alpha: 0.45),
      ),
      crossAxisMargin: 2,
      mainAxisMargin: 4,
    ),
    dataTableTheme: DataTableThemeData(
      headingRowHeight: 44,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      dividerThickness: 1,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminColors.borderSubtle),
        ),
      ),
      headingTextStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AdminColors.textSecondary,
        letterSpacing: 0.35,
      ),
      dataTextStyle: const TextStyle(
        fontSize: 13,
        height: 1.35,
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w400,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: AdminColors.border,
      labelColor: AdminColors.primaryAction,
      unselectedLabelColor: AdminColors.textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: UnderlineTabIndicator(
        borderSide: const BorderSide(
          color: AdminColors.primaryAction,
          width: 2,
        ),
        insets: const EdgeInsets.symmetric(horizontal: 8),
      ),
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
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AdminColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: AdminColors.textSecondary, size: 22),
      shape: Border(
        bottom: BorderSide(color: AdminColors.borderSubtle, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AdminColors.border),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AdminColors.textPrimary,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        height: 1.45,
        color: AdminColors.textSecondary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AdminColors.borderSubtle,
      deleteIconColor: AdminColors.textSecondary,
      disabledColor: AdminColors.borderSubtle,
      selectedColor: AdminColors.primarySubtle,
      secondarySelectedColor: AdminColors.primarySubtle,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AdminColors.textPrimary,
      ),
      side: const BorderSide(color: AdminColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AdminColors.primaryAction;
        }
        if (states.contains(WidgetState.disabled)) {
          return AdminColors.border;
        }
        return null;
      }),
      side: const BorderSide(color: AdminColors.border, width: 1.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AdminColors.textOnPrimary;
        }
        return AdminColors.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AdminColors.primaryAction;
        }
        return AdminColors.border;
      }),
      trackOutlineColor: WidgetStateProperty.all(AdminColors.border),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.15,
        color: AdminColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
        height: 1.25,
        color: AdminColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: AdminColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
        color: AdminColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AdminColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AdminColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: AdminColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: AdminColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AdminColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AdminColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        color: AdminColors.textMuted,
      ),
    ),
  );
}
