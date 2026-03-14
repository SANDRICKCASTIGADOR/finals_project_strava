import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? valueColor;
  final Color? iconColor;

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: iconColor ?? AppTheme.textSecondary),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 3),
          RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppTheme.textPrimary,
                  height: 1,
                ),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    height: 1,
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}