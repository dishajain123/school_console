// lib/core/theme/admin_colors.dart  [Admin Console]
import 'package:flutter/material.dart';

/// Calm SaaS palette (Stripe / Linear–adjacent). Use with [buildAdminTheme].
/// Add tokens here instead of hardcoding Color(0x…) in screens.
abstract final class AdminColors {
  // ── Surfaces ───────────────────────────────────────────────────────────
  static const Color canvas = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color sidebarBg = Color(0xFFF9FAFB);

  // ── Borders & dividers ─────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSubtle = Color(0xFFF0F2F5);
  static const Color sidebarDivider = Color(0xFFE8EAEE);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Brand / actions (single accent) ─────────────────────────────────────
  static const Color primaryAction = Color(0xFF4F46E5);
  static const Color primaryHover = Color(0xFF5B54E8);
  static const Color primaryPressed = Color(0xFF4338CA);
  static const Color primarySubtle = Color(0xFFEEF2FF);

  // ── Tables ─────────────────────────────────────────────────────────────
  static const Color rowHover = Color(0xFFF4F6F8);
  static const Color rowStripe = Color(0xFFFAFBFC);

  // ── Semantic (sparingly) ───────────────────────────────────────────────
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFEF2F2);
  static const Color success = Color(0xFF059669);
  static const Color focusRing = Color(0x664F46E5);
}
