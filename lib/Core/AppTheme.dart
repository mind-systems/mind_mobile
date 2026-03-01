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

// ── Button ──────────────────────────────────────────────────
// Filled buttons and bordered interactive containers (login, onboarding).
// Access via: theme.colorScheme.secondaryContainer
const _kButtonDark  = Color(0xFF083752); // muted teal-blue
const _kButtonLight = Color(0xFF3686D0); // medium blue

// ── Accent ──────────────────────────────────────────────────
// Primary interactive color: FAB, active icons, progress indicators.
// Access via: theme.colorScheme.primary
const _kAccent = Color(0xFF00D9FF); // cyan — shared between both themes

// ── Error ────────────────────────────────────────────────────
// Destructive actions, error snackbars, validation messages.
// Access via: theme.colorScheme.error
const _kError = Color(0xFFD90000); // pure red — shared between both themes

abstract class AppTheme {
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _kBackgroundDark,
        cardColor: _kCardDark,
        colorScheme: const ColorScheme.dark(
          primary: _kAccent,
          secondaryContainer: _kButtonDark,
          surface: _kBackgroundDark,
          error: _kError,
        ),
      );

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _kBackgroundLight,
        cardColor: _kCardLight,
        colorScheme: const ColorScheme.light(
          primary: _kAccent,
          secondaryContainer: _kButtonLight,
          surface: _kBackgroundLight,
          error: _kError,
        ),
      );
}
