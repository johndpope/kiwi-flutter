/// Figma Design Panel color constants
///
/// Matches Figma's dark theme design system for visual parity.

import 'package:flutter/material.dart';

/// Color constants for the Figma Design Panel
class DesignPanelColors {
  // Background colors (darker to lighter)
  static const bg1 = Color(0xFF1E1E1E); // Darkest - input backgrounds
  static const bg2 = Color(0xFF2C2C2C); // Panel background
  static const bg3 = Color(0xFF383838); // Hover/selected state

  // Border colors
  static const border = Color(0xFF444444); // Standard borders
  static const borderLight = Color(0xFF4A4A4A); // Divider lines
  static const borderFocus = Color(0xFF0D99FF); // Focused input border

  // Text colors (white to gray)
  static const text1 = Color(0xFFFFFFFF); // Primary white text
  static const text2 = Color(0xFFB3B3B3); // Secondary gray text
  static const text3 = Color(0xFF7A7A7A); // Tertiary/labels/disabled
  static const textDisabled = Color(0xFF5C5C5C); // Disabled text

  // Accent colors
  static const accent = Color(0xFF0D99FF); // Figma blue
  static const accentHover = Color(0xFF0A7FD4); // Hover state
  static const accentLight = Color(0xFF0D99FF); // With opacity for backgrounds

  // Semantic colors
  static const error = Color(0xFFE03E3E);
  static const success = Color(0xFF1BC47D);
  static const warning = Color(0xFFF5A623);

  // Layer type colors (for visual identification)
  static const frameColor = Color(0xFF6B7AFF);
  static const groupColor = Color(0xFFAA7AFF);
  static const componentColor = Color(0xFF9747FF);
  static const textColor = Color(0xFFFF7262);
  static const vectorColor = Color(0xFF18A0FB);

  // Transparency helpers
  static Color accentWithOpacity(double opacity) => accent.withOpacity(opacity);
  static Color bg3WithOpacity(double opacity) => bg3.withOpacity(opacity);
}

/// Spacing constants for consistent layout
class DesignPanelSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;

  // Panel-specific
  static const double panelPadding = 12.0;
  static const double sectionPadding = 8.0;
  static const double rowGap = 8.0;
  static const double fieldGap = 8.0;
}

/// Typography constants
class DesignPanelTypography {
  static const double fontSizeXs = 9.0;
  static const double fontSizeSm = 10.0;
  static const double fontSizeMd = 11.0;
  static const double fontSizeLg = 12.0;

  static const labelStyle = TextStyle(
    color: DesignPanelColors.text3,
    fontSize: fontSizeSm,
    fontWeight: FontWeight.w400,
  );

  static const valueStyle = TextStyle(
    color: DesignPanelColors.text1,
    fontSize: fontSizeMd,
    fontWeight: FontWeight.w400,
  );

  static const headerStyle = TextStyle(
    color: DesignPanelColors.text1,
    fontSize: fontSizeMd,
    fontWeight: FontWeight.w500,
  );

  static const tabStyle = TextStyle(
    color: DesignPanelColors.text1,
    fontSize: fontSizeLg,
    fontWeight: FontWeight.w500,
  );

  static const tabInactiveStyle = TextStyle(
    color: DesignPanelColors.text2,
    fontSize: fontSizeLg,
    fontWeight: FontWeight.w400,
  );
}

/// Dimension constants
class DesignPanelDimensions {
  static const double panelWidth = 300.0;
  static const double inputHeight = 28.0;
  static const double smallInputHeight = 24.0;
  static const double buttonSize = 28.0;
  static const double iconSize = 16.0;
  static const double smallIconSize = 14.0;
  static const double borderRadius = 4.0;
  static const double colorSwatchSize = 24.0;
  static const double tabHeight = 40.0;
}
