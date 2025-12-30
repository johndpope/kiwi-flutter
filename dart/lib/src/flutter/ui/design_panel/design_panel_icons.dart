/// Design Panel Icons
///
/// Custom icons for the Figma-style design panel sections.
/// Uses Material Icons as base with Figma-appropriate mappings.

import 'package:flutter/material.dart';

/// Icons used in the Figma design panel
class DesignPanelIcons {
  DesignPanelIcons._();

  // Section header icons
  static const IconData fill = Icons.format_color_fill;
  static const IconData stroke = Icons.border_color;
  static const IconData effects = Icons.auto_fix_high;
  static const IconData selectionColors = Icons.colorize;
  static const IconData layoutGuide = Icons.grid_on;
  static const IconData export = Icons.ios_share;
  static const IconData preview = Icons.visibility_outlined;

  // Opacity/radius icons
  static const IconData opacity = Icons.opacity;
  static const IconData cornerRadius = Icons.rounded_corner;
  static const IconData individualCorners = Icons.crop_square;

  // Fill type icons
  static const IconData solidFill = Icons.square_rounded;
  static const IconData gradientLinear = Icons.gradient;
  static const IconData gradientRadial = Icons.blur_circular;
  static const IconData imageFill = Icons.image;

  // Stroke icons
  static const IconData strokeWeight = Icons.line_weight;
  static const IconData strokeAlign = Icons.format_align_center;
  static const IconData strokeDash = Icons.more_horiz;
  static const IconData strokeCap = Icons.horizontal_rule;
  static const IconData strokeJoin = Icons.join_inner;

  // Effect type icons
  static const IconData dropShadow = Icons.filter_drama;
  static const IconData innerShadow = Icons.brightness_low;
  static const IconData layerBlur = Icons.blur_on;
  static const IconData backgroundBlur = Icons.blur_linear;

  // Layout guide icons
  static const IconData gridGuide = Icons.grid_4x4;
  static const IconData columnGuide = Icons.view_column;
  static const IconData rowGuide = Icons.table_rows;

  // Export icons
  static const IconData exportPNG = Icons.image_outlined;
  static const IconData exportSVG = Icons.code;
  static const IconData exportPDF = Icons.picture_as_pdf;
  static const IconData exportJPG = Icons.photo;

  // Action icons
  static const IconData add = Icons.add;
  static const IconData remove = Icons.remove;
  static const IconData delete = Icons.delete_outline;
  static const IconData visible = Icons.visibility;
  static const IconData hidden = Icons.visibility_off;
  static const IconData settings = Icons.settings;
  static const IconData moreOptions = Icons.more_vert;
  static const IconData chevronDown = Icons.expand_more;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData help = Icons.help_outline;
}

/// Custom painted icon for Figma-style section icons
class FigmaSectionIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const FigmaSectionIcon({
    super.key,
    required this.icon,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? Colors.white.withOpacity(0.5),
    );
  }
}

/// Custom painter for fill icon (paint drop)
class FillIconPainter extends CustomPainter {
  final Color color;

  FillIconPainter({this.color = Colors.white54});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw paint drop shape
    path.moveTo(cx, cy - 5);
    path.quadraticBezierTo(cx + 4, cy, cx + 4, cy + 2);
    path.quadraticBezierTo(cx + 4, cy + 5, cx, cy + 5);
    path.quadraticBezierTo(cx - 4, cy + 5, cx - 4, cy + 2);
    path.quadraticBezierTo(cx - 4, cy, cx, cy - 5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for stroke icon (pen/line)
class StrokeIconPainter extends CustomPainter {
  final Color color;

  StrokeIconPainter({this.color = Colors.white54});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw diagonal line with rounded ends
    canvas.drawLine(
      Offset(cx - 4, cy + 4),
      Offset(cx + 4, cy - 4),
      paint,
    );

    // Draw small perpendicular tick
    canvas.drawLine(
      Offset(cx + 2, cy - 2),
      Offset(cx + 4, cy - 4),
      paint..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for effects icon (sparkle/star)
class EffectsIconPainter extends CustomPainter {
  final Color color;

  EffectsIconPainter({this.color = Colors.white54});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw 4-point star
    final path = Path();
    path.moveTo(cx, cy - 5);
    path.lineTo(cx + 1.5, cy - 1.5);
    path.lineTo(cx + 5, cy);
    path.lineTo(cx + 1.5, cy + 1.5);
    path.lineTo(cx, cy + 5);
    path.lineTo(cx - 1.5, cy + 1.5);
    path.lineTo(cx - 5, cy);
    path.lineTo(cx - 1.5, cy - 1.5);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for selection colors icon (eyedropper)
class SelectionColorsIconPainter extends CustomPainter {
  final Color color;

  SelectionColorsIconPainter({this.color = Colors.white54});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw eyedropper shape
    final path = Path();
    // Tip
    path.moveTo(cx - 3, cy + 4);
    path.lineTo(cx - 1, cy + 2);
    // Body
    path.lineTo(cx + 2, cy - 1);
    path.lineTo(cx + 4, cy - 3);
    // Top bulb
    path.quadraticBezierTo(cx + 5, cy - 5, cx + 3, cy - 5);
    path.lineTo(cx + 1, cy - 3);
    path.lineTo(cx - 2, cy);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for layout guide icon (grid)
class LayoutGuideIconPainter extends CustomPainter {
  final Color color;

  LayoutGuideIconPainter({this.color = Colors.white54});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w = size.width;
    final h = size.height;
    final pad = 3.0;

    // Draw 3x3 grid
    // Vertical lines
    canvas.drawLine(Offset(pad + (w - 2*pad)/3, pad), Offset(pad + (w - 2*pad)/3, h - pad), paint);
    canvas.drawLine(Offset(pad + 2*(w - 2*pad)/3, pad), Offset(pad + 2*(w - 2*pad)/3, h - pad), paint);

    // Horizontal lines
    canvas.drawLine(Offset(pad, pad + (h - 2*pad)/3), Offset(w - pad, pad + (h - 2*pad)/3), paint);
    canvas.drawLine(Offset(pad, pad + 2*(h - 2*pad)/3), Offset(w - pad, pad + 2*(h - 2*pad)/3), paint);

    // Border
    canvas.drawRect(
      Rect.fromLTWH(pad, pad, w - 2*pad, h - 2*pad),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for export icon (share/download)
class ExportIconPainter extends CustomPainter {
  final Color color;

  ExportIconPainter({this.color = Colors.white54});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw upward arrow
    canvas.drawLine(Offset(cx, cy + 3), Offset(cx, cy - 3), paint);
    canvas.drawLine(Offset(cx - 3, cy), Offset(cx, cy - 3), paint);
    canvas.drawLine(Offset(cx + 3, cy), Offset(cx, cy - 3), paint);

    // Draw box bottom
    final path = Path();
    path.moveTo(cx - 4, cy + 1);
    path.lineTo(cx - 4, cy + 4);
    path.lineTo(cx + 4, cy + 4);
    path.lineTo(cx + 4, cy + 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for preview icon (eye)
class PreviewIconPainter extends CustomPainter {
  final Color color;

  PreviewIconPainter({this.color = Colors.white54});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw eye shape
    final path = Path();
    path.moveTo(cx - 5, cy);
    path.quadraticBezierTo(cx, cy - 3, cx + 5, cy);
    path.quadraticBezierTo(cx, cy + 3, cx - 5, cy);
    canvas.drawPath(path, paint);

    // Draw pupil
    canvas.drawCircle(Offset(cx, cy), 1.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget that displays a custom painted section icon
class SectionIconWidget extends StatelessWidget {
  final CustomPainter painter;
  final double size;

  const SectionIconWidget({
    super.key,
    required this.painter,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter),
    );
  }
}
