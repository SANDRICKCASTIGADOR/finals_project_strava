// ─────────────────────────────────────────────────────────────────────────────
// stat_card.dart
// Reusable metric display card widget used on the tracking screen and
// activity detail screen. Shows a label, large value, optional unit,
// and optional leading icon. Supports custom value color for highlighting
// active states (e.g. orange timer when tracking is running).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;       // Top label e.g. "DISTANCE"
  final String value;       // Main value e.g. "2.45"
  final String? unit;       // Optional unit e.g. "km"
  final IconData? icon;     // Optional leading icon next to label
  final Color? valueColor;  // Override value text color (default: textPrimary)
  final Color? iconColor;   // Override icon color (default: textSecondary)

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.valueColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 1), // Subtle border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Label Row (icon + uppercase label) ──────────────────────────
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: iconColor ?? AppTheme.textSecondary),
                const SizedBox(width: 5),
              ],
              Text(
                label.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Value + Unit ─────────────────────────────────────────────────
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppTheme.textPrimary,
                    height: 1,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}