/// Opacity and corner radius row for Design Panel
///
/// Dedicated row for opacity and corner radius with individual corners button.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../widgets/icon_input.dart';

/// Opacity and corner radius row (matches Figma screenshot)
class OpacityRadiusRow extends StatefulWidget {
  final double opacity; // 0.0 - 1.0
  final double cornerRadius;
  final List<double>? individualCorners; // [topLeft, topRight, bottomRight, bottomLeft]
  final ValueChanged<double>? onOpacityChanged;
  final ValueChanged<double>? onCornerRadiusChanged;
  final ValueChanged<List<double>>? onIndividualCornersChanged;

  const OpacityRadiusRow({
    super.key,
    this.opacity = 1.0,
    this.cornerRadius = 0,
    this.individualCorners,
    this.onOpacityChanged,
    this.onCornerRadiusChanged,
    this.onIndividualCornersChanged,
  });

  @override
  State<OpacityRadiusRow> createState() => _OpacityRadiusRowState();
}

class _OpacityRadiusRowState extends State<OpacityRadiusRow> {
  bool _showIndividualCorners = false;

  bool get _hasIndividualCorners {
    if (widget.individualCorners == null) return false;
    final corners = widget.individualCorners!;
    if (corners.length != 4) return false;
    return corners.any((c) => c != corners.first);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Labels row
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignPanelSpacing.panelPadding,
            DesignPanelSpacing.sm,
            DesignPanelSpacing.panelPadding,
            DesignPanelSpacing.xs,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Opacity',
                  style: DesignPanelTypography.labelStyle,
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              const Expanded(
                child: Text(
                  'Corner radius',
                  style: DesignPanelTypography.labelStyle,
                ),
              ),
              const SizedBox(width: DesignPanelDimensions.buttonSize),
            ],
          ),
        ),
        // Input row
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignPanelSpacing.panelPadding,
            0,
            DesignPanelSpacing.panelPadding,
            DesignPanelSpacing.sm,
          ),
          child: Row(
            children: [
              // Opacity input
              Expanded(
                child: _OpacityInput(
                  value: widget.opacity,
                  onChanged: widget.onOpacityChanged,
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              // Corner radius input
              Expanded(
                child: _CornerRadiusInput(
                  value: widget.cornerRadius,
                  onChanged: widget.onCornerRadiusChanged,
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              // Individual corners button
              _IndividualCornersButton(
                isActive: _showIndividualCorners || _hasIndividualCorners,
                onTap: () {
                  setState(() {
                    _showIndividualCorners = !_showIndividualCorners;
                  });
                },
              ),
            ],
          ),
        ),
        // Individual corners row (when expanded)
        if (_showIndividualCorners)
          _IndividualCornersEditor(
            corners: widget.individualCorners ?? [
              widget.cornerRadius,
              widget.cornerRadius,
              widget.cornerRadius,
              widget.cornerRadius,
            ],
            onChanged: widget.onIndividualCornersChanged,
          ),
      ],
    );
  }
}

/// Opacity input with grid icon
class _OpacityInput extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const _OpacityInput({
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesignPanelDimensions.inputHeight,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: Row(
        children: [
          // Grid icon (Figma uses this for opacity)
          Container(
            width: 28,
            alignment: Alignment.center,
            child: const Icon(
              Icons.grid_4x4,
              size: DesignPanelDimensions.smallIconSize,
              color: DesignPanelColors.text3,
            ),
          ),
          // Value
          Expanded(
            child: TextField(
              controller: TextEditingController(
                text: '${(value * 100).round()}%',
              ),
              style: DesignPanelTypography.valueStyle,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
                isDense: true,
              ),
              onSubmitted: (text) {
                final num = int.tryParse(text.replaceAll('%', ''));
                if (num != null) {
                  onChanged?.call((num / 100).clamp(0, 1));
                }
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Corner radius input with bracket icon
class _CornerRadiusInput extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const _CornerRadiusInput({
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesignPanelDimensions.inputHeight,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: Row(
        children: [
          // Corner bracket icon
          Container(
            width: 28,
            alignment: Alignment.center,
            child: const Icon(
              Icons.rounded_corner,
              size: DesignPanelDimensions.smallIconSize,
              color: DesignPanelColors.text3,
            ),
          ),
          // Value
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value.toInt().toString()),
              style: DesignPanelTypography.valueStyle,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
                isDense: true,
              ),
              onSubmitted: (text) {
                final num = double.tryParse(text);
                if (num != null) {
                  onChanged?.call(num.clamp(0, 1000));
                }
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Individual corners toggle button
class _IndividualCornersButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onTap;

  const _IndividualCornersButton({
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Individual corners',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: DesignPanelDimensions.buttonSize,
          height: DesignPanelDimensions.buttonSize,
          decoration: BoxDecoration(
            color: isActive
                ? DesignPanelColors.accentWithOpacity(0.2)
                : DesignPanelColors.bg1,
            borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
            border: Border.all(
              color: isActive
                  ? DesignPanelColors.accent
                  : DesignPanelColors.border,
            ),
          ),
          child: CustomPaint(
            painter: _CornerIconPainter(
              color: isActive ? DesignPanelColors.accent : DesignPanelColors.text3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for corner icon
class _CornerIconPainter extends CustomPainter {
  final Color color;

  _CornerIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = 6.0;

    // Draw 4 corner marks
    // Top-left
    canvas.drawLine(Offset(cx - r, cy - r + 2), Offset(cx - r, cy - r), paint);
    canvas.drawLine(Offset(cx - r, cy - r), Offset(cx - r + 2, cy - r), paint);

    // Top-right
    canvas.drawLine(Offset(cx + r, cy - r + 2), Offset(cx + r, cy - r), paint);
    canvas.drawLine(Offset(cx + r, cy - r), Offset(cx + r - 2, cy - r), paint);

    // Bottom-right
    canvas.drawLine(Offset(cx + r, cy + r - 2), Offset(cx + r, cy + r), paint);
    canvas.drawLine(Offset(cx + r, cy + r), Offset(cx + r - 2, cy + r), paint);

    // Bottom-left
    canvas.drawLine(Offset(cx - r, cy + r - 2), Offset(cx - r, cy + r), paint);
    canvas.drawLine(Offset(cx - r, cy + r), Offset(cx - r + 2, cy + r), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Individual corners editor (4 inputs)
class _IndividualCornersEditor extends StatelessWidget {
  final List<double> corners; // [TL, TR, BR, BL]
  final ValueChanged<List<double>>? onChanged;

  const _IndividualCornersEditor({
    required this.corners,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignPanelSpacing.panelPadding,
        0,
        DesignPanelSpacing.panelPadding,
        DesignPanelSpacing.sm,
      ),
      child: Row(
        children: [
          _CornerInput(
            label: 'TL',
            value: corners.isNotEmpty ? corners[0] : 0,
            onChanged: (v) => _updateCorner(0, v),
          ),
          const SizedBox(width: DesignPanelSpacing.xs),
          _CornerInput(
            label: 'TR',
            value: corners.length > 1 ? corners[1] : 0,
            onChanged: (v) => _updateCorner(1, v),
          ),
          const SizedBox(width: DesignPanelSpacing.xs),
          _CornerInput(
            label: 'BR',
            value: corners.length > 2 ? corners[2] : 0,
            onChanged: (v) => _updateCorner(2, v),
          ),
          const SizedBox(width: DesignPanelSpacing.xs),
          _CornerInput(
            label: 'BL',
            value: corners.length > 3 ? corners[3] : 0,
            onChanged: (v) => _updateCorner(3, v),
          ),
        ],
      ),
    );
  }

  void _updateCorner(int index, double value) {
    final newCorners = List<double>.from(corners);
    while (newCorners.length <= index) {
      newCorners.add(0);
    }
    newCorners[index] = value;
    onChanged?.call(newCorners);
  }
}

/// Single corner input
class _CornerInput extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;

  const _CornerInput({
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: NumericInput(
        label: label,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
