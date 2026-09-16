import 'package:flutter/material.dart';

class AppTheme {
  // ඔබ පෙන්වූ මෝස්තරවල ඇති ප්‍රධාන Deep Purple වර්ණය
  static const Color primaryPurple = Color(0xFF4A148C);
  static const Color secondaryPurple = Color(0xFF6A1B9A);
  static const Color surfaceColor = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.light,
        primary: primaryPurple,
        secondary: secondaryPurple,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: surfaceColor,
      
      // AppBar මෝස්තරය
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20, 
          fontWeight: FontWeight.bold, 
          color: Colors.white,
        ),
      ),

      // කාඩ් (Cards) සඳහා පොදු මෝස්තරය (Rounded & Clean)
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // බොත්තම් (Buttons) සඳහා පොදු මෝස්තරය
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
