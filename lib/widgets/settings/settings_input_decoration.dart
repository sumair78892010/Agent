import 'package:flutter/material.dart';

InputDecoration settingsInputDecoration({
  required BuildContext context,
  required String labelText,
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    labelStyle: TextStyle(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: TextStyle(
      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
      fontSize: 13,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        width: 1.2,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.8,
      ),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
  );
}
