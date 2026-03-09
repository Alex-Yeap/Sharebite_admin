import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTheme {
  static const Color midnightBlack = Color(0xFF1A1A1A); // Sidebar & Headers
  static const Color backgroundGrey = Color(0xFFF4F7FC); // Main Content BG

  static const Color merchantOrange = Color(0xFFFF9800);
  static const Color studentGreen = Color(0xFF4CAF50);
  static const Color dangerRed = Color(0xFFE53935);

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static const LinearGradient midnightGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static TextStyle get headerStyle => GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.bold, color: midnightBlack
  );

  static TextStyle get subHeaderStyle => GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w600, color: midnightBlack
  );

  static TextStyle get tableHeader => GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]
  );

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
    ],
  );
}