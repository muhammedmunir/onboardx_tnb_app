// TODO Implement this library.

// lib/services/theme_service.dart
import 'package:flutter/material.dart';

/// A simple global ValueNotifier that controls the app ThemeMode.
/// Default is system; change to ThemeMode.light or ThemeMode.dark to force a mode.
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

/// Set a specific theme mode
void setThemeMode(ThemeMode mode) {
  themeNotifier.value = mode;
}

/// Toggle between light and dark
void toggleThemeMode() {
  themeNotifier.value =
      themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}