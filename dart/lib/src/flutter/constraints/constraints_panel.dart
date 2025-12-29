/// Constraints panel for editing layout constraints
///
/// Provides visual constraint picker matching Figma's UI

import 'package:flutter/material.dart';
import 'constraints_data.dart';

/// Visual constraint picker widget
class ConstraintsPanel extends StatelessWidget {
  /// Current constraints
  final LayoutConstraints constraints;

  /// Callback when constraints change
  final void Function(LayoutConstraints constraints)? onConstraintsChanged;

  /// Element bounds for visualization
  final Rect? elementBounds;

  /// Parent bounds for visualization
  final Rect? parentBounds;

  const ConstraintsPanel({
    super.key,
    required this.constraints,
    this.onConstraintsChanged,
    this.elementBounds,
    this.parentBounds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section title
          const Text(
            'Constraints',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Visual picker
          Row(
            children: [
              // Visual representation
              _ConstraintVisualizer(
                constraints: constraints,
                size: const Size(80, 60),
              ),
              const SizedBox(width: 16),

              // Dropdowns
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Horizontal constraint
                    _ConstraintDropdown<HorizontalConstraint>(
                      label: 'Horizontal',
                      value: constraints.horizontal,
                      items: HorizontalConstraint.values,
                      onChanged: (value) {
                        if (value != null) {
                          onConstraintsChanged?.call(
                            constraints.copyWith(horizontal: value),
                          );
                        }
                      },
                      itemBuilder: (item) => Row(
                        children: [
                          Icon(item.icon, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(item.displayName),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Vertical constraint
                    _ConstraintDropdown<VerticalConstraint>(
                      label: 'Vertical',
                      value: constraints.vertical,
                      items: VerticalConstraint.values,
                      onChanged: (value) {
                        if (value != null) {
                          onConstraintsChanged?.call(
                            constraints.copyWith(vertical: value),
                          );
                        }
                      },
                      itemBuilder: (item) => Row(
                        children: [
                          Icon(item.icon, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(item.displayName),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick presets
          Row(
            children: [
              _PresetButton(
                label: 'TL',
                tooltip: 'Top Left (Fixed)',
                isSelected: constraints == LayoutConstraints.defaultConstraints,
                onTap: () => onConstraintsChanged?.call(
                  LayoutConstraints.defaultConstraints,
                ),
              ),
              _PresetButton(
                label: 'C',
                tooltip: 'Center',
                isSelected: constraints == LayoutConstraints.centered,
                onTap: () => onConstraintsChanged?.call(
                  LayoutConstraints.centered,
                ),
              ),
              _PresetButton(
                label: 'S',
                tooltip: 'Scale',
                isSelected: constraints == LayoutConstraints.scale,
                onTap: () => onConstraintsChanged?.call(
                  LayoutConstraints.scale,
                ),
              ),
              _PresetButton(
                label: 'F',
                tooltip: 'Fill (Stretch)',
                isSelected: constraints == LayoutConstraints.stretch,
                onTap: () => onConstraintsChanged?.call(
                  LayoutConstraints.stretch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConstraintDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final void Function(T?) onChanged;
  final Widget Function(T) itemBuilder;

  const _ConstraintDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ),
        Expanded(
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white, fontSize: 12),
                icon: Icon(Icons.expand_more, size: 16, color: Colors.grey[500]),
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: DefaultTextStyle(
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      child: itemBuilder(item),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual representation of constraints
class _ConstraintVisualizer extends StatelessWidget {
  final LayoutConstraints constraints;
  final Size size;

  const _ConstraintVisualizer({
    required this.constraints,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _ConstraintVisualizerPainter(constraints),
    );
  }
}

class _ConstraintVisualizerPainter extends CustomPainter {
  final LayoutConstraints constraints;

  _ConstraintVisualizerPainter(this.constraints);

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final elementPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final elementStrokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final constraintPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dashPaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw frame
    canvas.drawRect(Offset.zero & size, framePaint);

    // Calculate element position based on constraints
    final elementWidth = size.width * 0.4;
    final elementHeight = size.height * 0.4;
    double elementX = (size.width - elementWidth) / 2;
    double elementY = (size.height - elementHeight) / 2;

    // Adjust position based on constraints for visualization
    switch (constraints.horizontal) {
      case HorizontalConstraint.left:
        elementX = 8;
        break;
      case HorizontalConstraint.right:
        elementX = size.width - elementWidth - 8;
        break;
      case HorizontalConstraint.leftRight:
      case HorizontalConstraint.center:
      case HorizontalConstraint.scale:
        elementX = (size.width - elementWidth) / 2;
        break;
    }

    switch (constraints.vertical) {
      case VerticalConstraint.top:
        elementY = 8;
        break;
      case VerticalConstraint.bottom:
        elementY = size.height - elementHeight - 8;
        break;
      case VerticalConstraint.topBottom:
      case VerticalConstraint.center:
      case VerticalConstraint.scale:
        elementY = (size.height - elementHeight) / 2;
        break;
    }

    final elementRect = Rect.fromLTWH(elementX, elementY, elementWidth, elementHeight);

    // Draw element
    canvas.drawRect(elementRect, elementPaint);
    canvas.drawRect(elementRect, elementStrokePaint);

    // Draw constraint indicators
    _drawHorizontalConstraint(canvas, size, elementRect, constraintPaint, dashPaint);
    _drawVerticalConstraint(canvas, size, elementRect, constraintPaint, dashPaint);
  }

  void _drawHorizontalConstraint(
    Canvas canvas,
    Size size,
    Rect elementRect,
    Paint solidPaint,
    Paint dashPaint,
  ) {
    final centerY = elementRect.center.dy;

    switch (constraints.horizontal) {
      case HorizontalConstraint.left:
        // Draw line from left edge to element
        canvas.drawLine(
          Offset(0, centerY),
          Offset(elementRect.left, centerY),
          solidPaint,
        );
        break;

      case HorizontalConstraint.right:
        // Draw line from element to right edge
        canvas.drawLine(
          Offset(elementRect.right, centerY),
          Offset(size.width, centerY),
          solidPaint,
        );
        break;

      case HorizontalConstraint.leftRight:
        // Draw lines to both edges
        canvas.drawLine(
          Offset(0, centerY),
          Offset(elementRect.left, centerY),
          solidPaint,
        );
        canvas.drawLine(
          Offset(elementRect.right, centerY),
          Offset(size.width, centerY),
          solidPaint,
        );
        break;

      case HorizontalConstraint.center:
        // Draw center alignment indicator
        _drawDashedLine(
          canvas,
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          dashPaint,
        );
        break;

      case HorizontalConstraint.scale:
        // Draw scale indicators
        canvas.drawLine(
          Offset(0, centerY - 2),
          Offset(size.width, centerY - 2),
          dashPaint,
        );
        canvas.drawLine(
          Offset(0, centerY + 2),
          Offset(size.width, centerY + 2),
          dashPaint,
        );
        break;
    }
  }

  void _drawVerticalConstraint(
    Canvas canvas,
    Size size,
    Rect elementRect,
    Paint solidPaint,
    Paint dashPaint,
  ) {
    final centerX = elementRect.center.dx;

    switch (constraints.vertical) {
      case VerticalConstraint.top:
        canvas.drawLine(
          Offset(centerX, 0),
          Offset(centerX, elementRect.top),
          solidPaint,
        );
        break;

      case VerticalConstraint.bottom:
        canvas.drawLine(
          Offset(centerX, elementRect.bottom),
          Offset(centerX, size.height),
          solidPaint,
        );
        break;

      case VerticalConstraint.topBottom:
        canvas.drawLine(
          Offset(centerX, 0),
          Offset(centerX, elementRect.top),
          solidPaint,
        );
        canvas.drawLine(
          Offset(centerX, elementRect.bottom),
          Offset(centerX, size.height),
          solidPaint,
        );
        break;

      case VerticalConstraint.center:
        _drawDashedLine(
          canvas,
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          dashPaint,
        );
        break;

      case VerticalConstraint.scale:
        canvas.drawLine(
          Offset(centerX - 2, 0),
          Offset(centerX - 2, size.height),
          dashPaint,
        );
        canvas.drawLine(
          Offset(centerX + 2, 0),
          Offset(centerX + 2, size.height),
          dashPaint,
        );
        break;
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final distance = (end - start).distance;
    final direction = (end - start) / distance;

    double drawn = 0;
    while (drawn < distance) {
      final dashEnd = (drawn + dashWidth).clamp(0.0, distance);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * dashEnd,
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _ConstraintVisualizerPainter oldDelegate) {
    return constraints != oldDelegate.constraints;
  }
}

/// Compact inline constraint indicator
class ConstraintIndicator extends StatelessWidget {
  final LayoutConstraints constraints;
  final double size;

  const ConstraintIndicator({
    super.key,
    required this.constraints,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2,
      height: size,
      child: CustomPaint(
        painter: _ConstraintIndicatorPainter(constraints),
      ),
    );
  }
}

class _ConstraintIndicatorPainter extends CustomPainter {
  final LayoutConstraints constraints;

  _ConstraintIndicatorPainter(this.constraints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;

    final activePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final dotRadius = 2.0;
    final hSpacing = size.width / 4;
    final vSpacing = size.height / 3;

    // Draw 3x2 grid of dots
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 3; col++) {
        final x = hSpacing + col * hSpacing;
        final y = vSpacing + row * vSpacing;

        bool isActive = false;

        // Determine if this dot should be active
        if (col == 0 &&
            (constraints.horizontal == HorizontalConstraint.left ||
                constraints.horizontal == HorizontalConstraint.leftRight)) {
          isActive = true;
        }
        if (col == 1 && constraints.horizontal == HorizontalConstraint.center) {
          isActive = true;
        }
        if (col == 2 &&
            (constraints.horizontal == HorizontalConstraint.right ||
                constraints.horizontal == HorizontalConstraint.leftRight)) {
          isActive = true;
        }
        if (row == 0 &&
            (constraints.vertical == VerticalConstraint.top ||
                constraints.vertical == VerticalConstraint.topBottom)) {
          isActive = isActive || col == 1;
        }
        if (row == 1 &&
            (constraints.vertical == VerticalConstraint.bottom ||
                constraints.vertical == VerticalConstraint.topBottom)) {
          isActive = isActive || col == 1;
        }

        canvas.drawCircle(
          Offset(x, y),
          dotRadius,
          isActive ? activePaint : paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConstraintIndicatorPainter oldDelegate) {
    return constraints != oldDelegate.constraints;
  }
}
