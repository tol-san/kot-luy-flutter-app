import 'package:flutter/material.dart';

const ink = Color(0xFF203D30);
const muted = Color(0xFF53604F);
const paper = Color(0xFFFAF9F4);
const line = Color(0xFFE7E9DF);
const green = Color(0xFF35634B);
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoSansKhmer',
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    surface: paper,
    primary: green,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.65),
    bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.65),
    titleLarge: TextStyle(
      color: ink,
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: green,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(
        fontFamily: 'NotoSansKhmer',
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(color: muted),
    labelStyle: const TextStyle(color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: green, width: 1.5),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
