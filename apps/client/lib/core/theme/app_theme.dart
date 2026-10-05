import 'package:flutter/material.dart';

class AppTheme {
  // Paleta Industrial Precision & Dark Slate
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateSurface = Color(0xFF1E293B);
  static const Color slateCard = Color(0xFF334155);
  static const Color slateBorder = Color(0xFF475569);

  // Acentos de Acción
  static const Color amberSafety = Color(0xFFF59E0B); // Mantenimientos, alertas
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color emeraldSuccess = Color(0xFF10B981); // Finanzas, saldados
  static const Color emeraldLight = Color(0xFFD1FAE5);
  static const Color coralUrgent = Color(0xFFEF4444); // Vencidos, urgente
  static const Color coralLight = Color(0xFFFEE2E2);
  static const Color skyAccent = Color(0xFF0EA5E9); // Obras, proyectos

  // Tema Oscuro (Principal)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: slateDark,
      colorScheme: const ColorScheme.dark(
        primary: amberSafety,
        onPrimary: Color(0xFF0F172A),
        surface: slateSurface,
        onSurface: Colors.white,
        error: coralUrgent,
      ),
      cardTheme: CardThemeData(
        color: slateSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: slateDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: amberSafety, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amberSafety,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}
