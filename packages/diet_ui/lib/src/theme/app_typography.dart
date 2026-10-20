import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const pageTitle = TextStyle(
    fontSize: 28,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const secondaryTitle = TextStyle(
    fontSize: 23,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const sectionTitle = TextStyle(
    fontSize: 19,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.ink,
  );
  static const bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
    color: AppColors.ink,
  );
  static const caption = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: AppColors.muted,
  );
  static const small = TextStyle(
    fontSize: 12,
    height: 1.4,
    color: AppColors.muted,
  );
  static const metric = TextStyle(
    fontSize: 39,
    height: 1.15,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
