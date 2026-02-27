import 'package:flutter/material.dart';

const _kBackground = Color(0xFF0A0E27);
const _kCardDark = Color(0xFF1A2433);
const _kAccent = Color(0xFF00D9FF);
const _kCardLight = Color(0xFFE8EDF5);
const _kBackgroundLight = Color(0xFFF0F4FC);

abstract class AppTheme {
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _kBackground,
        cardColor: _kCardDark,
        colorScheme: const ColorScheme.dark(
          primary: _kAccent,
          surface: _kBackground,
        ),
      );

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _kBackgroundLight,
        cardColor: _kCardLight,
        colorScheme: const ColorScheme.light(
          primary: _kAccent,
          surface: _kBackgroundLight,
        ),
      );
}
