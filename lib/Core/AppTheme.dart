import 'package:flutter/material.dart';

// ── Background ──────────────────────────────────────────────
// Scaffold background — applied automatically to every Scaffold.
// Access via: theme.scaffoldBackgroundColor or theme.colorScheme.surface
const _kBackgroundDark  = Color(0xFF0A0E27); // deep navy
const _kBackgroundLight = Color(0xFFF0F4FC); // cool ice-white

// ── Card / Surface ──────────────────────────────────────────
// Elevated surfaces: cards, dialogs, bottom sheets, overlays.
// Access via: theme.cardColor
// Semi-transparent variants: theme.cardColor.withValues(alpha: 0.5–0.8)
const _kCardDark  = Color(0xFF1A2433); // dark slate-blue
const _kCardLight = Color(0xFFE8EDF5); // pale lavender-grey

// ── Shimmer highlight ────────────────────────────────────────
// Shimmer sweep colour — slightly lighter/darker than the card surface.
// Access via: theme.highlightColor
const _kShimmerHighlightDark  = Color(0xFF2A3A50); // lighter than card dark
const _kShimmerHighlightLight = Color(0xFFD0D8E8); // darker than card light

// ── Button ──────────────────────────────────────────────────
// Filled buttons and bordered interactive containers (login, onboarding).
// Access via: theme.colorScheme.secondaryContainer
const _kButtonDark  = Color(0xFF083752); // muted teal-blue
const _kButtonLight = Color(0xFF3686D0); // medium blue

// ── Accent ──────────────────────────────────────────────────
// Primary interactive color: FAB, active icons, progress indicators.
// Access via: theme.colorScheme.primary
const _kAccent = Color(0xFF00D9FF); // cyan — shared between both themes

// ── Warm Accent ─────────────────────────────────────────────
// Secondary accent color (gold): stars, highlights, badges.
// Access via: theme.colorScheme.tertiary
const _kWarmAccentDark  = Color(0xFFF4BA40); // warm gold
const _kWarmAccentLight = Color(0xFFF1A139); // amber gold

// ── Error ────────────────────────────────────────────────────
// Destructive actions, error snackbars, validation messages.
// Access via: theme.colorScheme.error
const _kError = Color(0xFFD90000); // pure red — shared between both themes

abstract class AppTheme {
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _kBackgroundDark,
        cardColor: _kCardDark,
        highlightColor: _kShimmerHighlightDark,
        colorScheme: const ColorScheme.dark(
          primary: _kAccent,
          secondaryContainer: _kButtonDark,
          tertiary: _kWarmAccentDark,
          surface: _kBackgroundDark,
          error: _kError,
        ),
      );

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _kBackgroundLight,
        cardColor: _kCardLight,
        highlightColor: _kShimmerHighlightLight,
        colorScheme: const ColorScheme.light(
          primary: _kAccent,
          secondaryContainer: _kButtonLight,
          tertiary: _kWarmAccentLight,
          surface: _kBackgroundLight,
          error: _kError,
        ),
      );
}
