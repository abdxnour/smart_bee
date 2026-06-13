import 'package:flutter/material.dart';

/// Centralized color palette for the application.
/// Ensures visual consistency across Light and Dark modes.
class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFFFFA000); // Honey Orange
  static const Color secondary = Color(0xFFFFD54F);
  static const Color accent = Color(0xFFFF6F00);
  
  // Backgrounds
  static const Color backgroundLight = Color(0xFFFFF8E1);
  static const Color backgroundDark = Color(0xFF121212);
  
  // Status Colors
  static const Color temp = Color(0xFFE53935); // Red for temperature
  static const Color hum = Color(0xFF1E88E5); // Blue for humidity
  static const Color online = Color(0xFF4CAF50); // Green for active status
  static const Color offline = Color(0xFFF44336); // Red for inactive status
  static const Color warning = Color(0xFFFF9800); // Amber for warnings
}
