/// Constraints data models for layout behavior
///
/// Defines how elements resize and position relative to their parent frame.
/// Matches Figma's constraint system.

import 'package:flutter/material.dart';

/// Horizontal constraint types
enum HorizontalConstraint {
  /// Fixed distance from left edge
  left,

  /// Fixed distance from right edge
  right,

  /// Fixed distance from both edges (stretches)
  leftRight,

  /// Centered horizontally
  center,

  /// Scales proportionally with parent width
  scale,
}

/// Vertical constraint types
enum VerticalConstraint {
  /// Fixed distance from top edge
  top,

  /// Fixed distance from bottom edge
  bottom,

  /// Fixed distance from both edges (stretches)
  topBottom,

  /// Centered vertically
  center,

  /// Scales proportionally with parent height
  scale,
}

/// Combined constraints for an element
class LayoutConstraints {
  /// Horizontal constraint
  final HorizontalConstraint horizontal;

  /// Vertical constraint
  final VerticalConstraint vertical;

  const LayoutConstraints({
    this.horizontal = HorizontalConstraint.left,
    this.vertical = VerticalConstraint.top,
  });

  /// Default constraints (top-left fixed)
  static const LayoutConstraints defaultConstraints = LayoutConstraints();

  /// Center both axes
  static const LayoutConstraints centered = LayoutConstraints(
    horizontal: HorizontalConstraint.center,
    vertical: VerticalConstraint.center,
  );

  /// Scale both axes
  static const LayoutConstraints scale = LayoutConstraints(
    horizontal: HorizontalConstraint.scale,
    vertical: VerticalConstraint.scale,
  );

  /// Stretch both axes
  static const LayoutConstraints stretch = LayoutConstraints(
    horizontal: HorizontalConstraint.leftRight,
    vertical: VerticalConstraint.topBottom,
  );

  LayoutConstraints copyWith({
    HorizontalConstraint? horizontal,
    VerticalConstraint? vertical,
  }) {
    return LayoutConstraints(
      horizontal: horizontal ?? this.horizontal,
      vertical: vertical ?? this.vertical,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutConstraints &&
          horizontal == other.horizontal &&
          vertical == other.vertical;

  @override
  int get hashCode => horizontal.hashCode ^ vertical.hashCode;

  @override
  String toString() => 'LayoutConstraints($horizontal, $vertical)';
}

/// Stored position/size values for constraint calculations
class ConstraintValues {
  /// Left offset from parent
  final double left;

  /// Top offset from parent
  final double top;

  /// Right offset from parent right edge
  final double right;

  /// Bottom offset from parent bottom edge
  final double bottom;

  /// Element width
  final double width;

  /// Element height
  final double height;

  /// Parent width (at time of constraint setup)
  final double parentWidth;

  /// Parent height (at time of constraint setup)
  final double parentHeight;

  /// Horizontal center offset
  double get centerX => (parentWidth - width) / 2 - left;

  /// Vertical center offset
  double get centerY => (parentHeight - height) / 2 - top;

  /// Width ratio for scale constraint
  double get widthRatio => width / parentWidth;

  /// Height ratio for scale constraint
  double get heightRatio => height / parentHeight;

  /// Left ratio for scale constraint
  double get leftRatio => left / parentWidth;

  /// Top ratio for scale constraint
  double get topRatio => top / parentHeight;

  const ConstraintValues({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
    required this.parentWidth,
    required this.parentHeight,
  });

  /// Create from element rect and parent size
  factory ConstraintValues.fromRect(Rect elementRect, Size parentSize) {
    return ConstraintValues(
      left: elementRect.left,
      top: elementRect.top,
      right: parentSize.width - elementRect.right,
      bottom: parentSize.height - elementRect.bottom,
      width: elementRect.width,
      height: elementRect.height,
      parentWidth: parentSize.width,
      parentHeight: parentSize.height,
    );
  }

  /// Create from absolute position and size
  factory ConstraintValues.fromPosition({
    required double x,
    required double y,
    required double width,
    required double height,
    required double parentWidth,
    required double parentHeight,
  }) {
    return ConstraintValues(
      left: x,
      top: y,
      right: parentWidth - (x + width),
      bottom: parentHeight - (y + height),
      width: width,
      height: height,
      parentWidth: parentWidth,
      parentHeight: parentHeight,
    );
  }

  @override
  String toString() =>
      'ConstraintValues(l:$left, t:$top, r:$right, b:$bottom, w:$width, h:$height)';
}

/// Engine for applying constraints during parent resize
class ConstraintEngine {
  /// Apply constraints to calculate new position and size
  static Rect applyConstraints({
    required LayoutConstraints constraints,
    required ConstraintValues values,
    required Size newParentSize,
  }) {
    // Calculate new horizontal position and width
    double newLeft;
    double newWidth;

    switch (constraints.horizontal) {
      case HorizontalConstraint.left:
        // Fixed left, fixed width
        newLeft = values.left;
        newWidth = values.width;
        break;

      case HorizontalConstraint.right:
        // Fixed right, fixed width
        newWidth = values.width;
        newLeft = newParentSize.width - values.right - newWidth;
        break;

      case HorizontalConstraint.leftRight:
        // Fixed left and right, stretch width
        newLeft = values.left;
        newWidth = newParentSize.width - values.left - values.right;
        break;

      case HorizontalConstraint.center:
        // Centered, fixed width
        newWidth = values.width;
        newLeft = (newParentSize.width - newWidth) / 2 + values.centerX;
        break;

      case HorizontalConstraint.scale:
        // Scale proportionally
        newLeft = values.leftRatio * newParentSize.width;
        newWidth = values.widthRatio * newParentSize.width;
        break;
    }

    // Calculate new vertical position and height
    double newTop;
    double newHeight;

    switch (constraints.vertical) {
      case VerticalConstraint.top:
        // Fixed top, fixed height
        newTop = values.top;
        newHeight = values.height;
        break;

      case VerticalConstraint.bottom:
        // Fixed bottom, fixed height
        newHeight = values.height;
        newTop = newParentSize.height - values.bottom - newHeight;
        break;

      case VerticalConstraint.topBottom:
        // Fixed top and bottom, stretch height
        newTop = values.top;
        newHeight = newParentSize.height - values.top - values.bottom;
        break;

      case VerticalConstraint.center:
        // Centered, fixed height
        newHeight = values.height;
        newTop = (newParentSize.height - newHeight) / 2 + values.centerY;
        break;

      case VerticalConstraint.scale:
        // Scale proportionally
        newTop = values.topRatio * newParentSize.height;
        newHeight = values.heightRatio * newParentSize.height;
        break;
    }

    // Ensure minimum sizes
    newWidth = newWidth.clamp(1.0, double.infinity);
    newHeight = newHeight.clamp(1.0, double.infinity);

    return Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
  }

  /// Infer constraints from current position relative to parent
  static LayoutConstraints inferConstraints(Rect elementRect, Size parentSize) {
    final left = elementRect.left;
    final right = parentSize.width - elementRect.right;
    final top = elementRect.top;
    final bottom = parentSize.height - elementRect.bottom;

    // Threshold for considering edges "pinned" (in percentage of parent)
    const threshold = 0.1;
    final hThreshold = parentSize.width * threshold;
    final vThreshold = parentSize.height * threshold;

    // Determine horizontal constraint
    HorizontalConstraint horizontal;
    if (left < hThreshold && right < hThreshold) {
      horizontal = HorizontalConstraint.leftRight;
    } else if (left < hThreshold) {
      horizontal = HorizontalConstraint.left;
    } else if (right < hThreshold) {
      horizontal = HorizontalConstraint.right;
    } else {
      // Check if centered
      final centerOffset = (left - right).abs();
      if (centerOffset < hThreshold) {
        horizontal = HorizontalConstraint.center;
      } else {
        horizontal = HorizontalConstraint.left; // Default
      }
    }

    // Determine vertical constraint
    VerticalConstraint vertical;
    if (top < vThreshold && bottom < vThreshold) {
      vertical = VerticalConstraint.topBottom;
    } else if (top < vThreshold) {
      vertical = VerticalConstraint.top;
    } else if (bottom < vThreshold) {
      vertical = VerticalConstraint.bottom;
    } else {
      // Check if centered
      final centerOffset = (top - bottom).abs();
      if (centerOffset < vThreshold) {
        vertical = VerticalConstraint.center;
      } else {
        vertical = VerticalConstraint.top; // Default
      }
    }

    return LayoutConstraints(horizontal: horizontal, vertical: vertical);
  }
}

/// Figma-style constraint names
extension HorizontalConstraintExtension on HorizontalConstraint {
  String get displayName {
    switch (this) {
      case HorizontalConstraint.left:
        return 'Left';
      case HorizontalConstraint.right:
        return 'Right';
      case HorizontalConstraint.leftRight:
        return 'Left & Right';
      case HorizontalConstraint.center:
        return 'Center';
      case HorizontalConstraint.scale:
        return 'Scale';
    }
  }

  IconData get icon {
    switch (this) {
      case HorizontalConstraint.left:
        return Icons.align_horizontal_left;
      case HorizontalConstraint.right:
        return Icons.align_horizontal_right;
      case HorizontalConstraint.leftRight:
        return Icons.swap_horiz;
      case HorizontalConstraint.center:
        return Icons.align_horizontal_center;
      case HorizontalConstraint.scale:
        return Icons.open_in_full;
    }
  }
}

extension VerticalConstraintExtension on VerticalConstraint {
  String get displayName {
    switch (this) {
      case VerticalConstraint.top:
        return 'Top';
      case VerticalConstraint.bottom:
        return 'Bottom';
      case VerticalConstraint.topBottom:
        return 'Top & Bottom';
      case VerticalConstraint.center:
        return 'Center';
      case VerticalConstraint.scale:
        return 'Scale';
    }
  }

  IconData get icon {
    switch (this) {
      case VerticalConstraint.top:
        return Icons.align_vertical_top;
      case VerticalConstraint.bottom:
        return Icons.align_vertical_bottom;
      case VerticalConstraint.topBottom:
        return Icons.swap_vert;
      case VerticalConstraint.center:
        return Icons.align_vertical_center;
      case VerticalConstraint.scale:
        return Icons.open_in_full;
    }
  }
}
