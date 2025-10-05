import 'package:flutter/material.dart';

/// Tema Dracula para toda la aplicación
class DraculaTheme {
  // Colores principales del tema Dracula
  static const Color background = Color(0xFF282a36);
  static const Color currentLine = Color(0xFF44475a);
  static const Color selection = Color(0xFF44475a);
  static const Color foreground = Color(0xFFf8f8f2);
  static const Color comment = Color(0xFF6272a4);
  static const Color cyan = Color(0xFF8be9fd);
  static const Color green = Color(0xFF50fa7b);
  static const Color orange = Color(0xFFffb86c);
  static const Color pink = Color(0xFFff79c6);
  static const Color purple = Color(0xFFbd93f9);
  static const Color red = Color(0xFFff5555);
  static const Color yellow = Color(0xFFf1fa8c);

  /// Tema principal de la aplicación
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Esquema de colores
      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: pink,
        surface: background,
        surfaceContainerHighest: currentLine,
        onSurface: foreground,
        onPrimary: background,
        error: red,
        onError: background,
        outline: comment,
      ),

      // Scaffold
      scaffoldBackgroundColor: background,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: foreground),
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: currentLine,
        selectedItemColor: purple,
        unselectedItemColor: comment,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: currentLine,
        elevation: 4,
        shadowColor: Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // Chips
      chipTheme: const ChipThemeData(
        backgroundColor: selection,
        labelStyle: TextStyle(color: foreground),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      // Text Styles
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: foreground, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: foreground, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: foreground),
        bodyLarge: TextStyle(color: foreground),
        bodyMedium: TextStyle(color: foreground),
        bodySmall: TextStyle(color: comment),
        labelLarge: TextStyle(color: foreground, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: foreground),
        labelSmall: TextStyle(color: comment),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: purple,
        foregroundColor: background,
        elevation: 6,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        textColor: foreground,
        iconColor: purple,
        tileColor: Colors.transparent,
      ),

      // CircularProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: purple,
        linearTrackColor: selection,
      ),

      // Dialogs
      dialogTheme: const DialogThemeData(
        backgroundColor: currentLine,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: foreground),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: purple,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: purple,
          side: const BorderSide(color: purple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: selection,
        thickness: 1,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: purple,
      ),
    );
  }

  /// Colores para estados específicos
  static const Color activeColor = green;
  static const Color inactiveColor = red;
  static const Color maintenanceColor = orange;
  static const Color warningColor = yellow;
  static const Color infoColor = cyan;
}