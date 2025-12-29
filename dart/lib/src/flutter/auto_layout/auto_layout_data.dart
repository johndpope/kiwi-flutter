/// Auto layout data models for Figma parity
///
/// Maps Figma's auto layout properties to Flutter layout concepts:
/// - VERTICAL → Column
/// - HORIZONTAL → Row (with optional Wrap)
/// - GRID → GridView
///
/// Supports all Figma auto layout properties including:
/// - Flow direction, spacing, padding
/// - Alignment (main axis, cross axis)
/// - Resizing behaviors (hug, fill, fixed)
/// - Absolute positioning
/// - Min/max constraints

import 'package:flutter/material.dart';

/// Auto layout flow direction
enum AutoLayoutFlow {
  /// No auto layout - static positioning
  none,

  /// Children stack vertically (Flutter: Column)
  vertical,

  /// Children stack horizontally (Flutter: Row)
  horizontal,

  /// Multi-row/column grid (Flutter: GridView)
  grid,

  /// Horizontal with wrap (Flutter: Wrap)
  wrap,
}

/// Resizing behavior for auto layout children
enum AutoLayoutSizing {
  /// Fixed dimensions - won't change with content
  fixed,

  /// Shrink to fit content (intrinsic size)
  hug,

  /// Expand to fill available space
  fill,
}

/// Main axis alignment options
enum AutoLayoutMainAxisAlign {
  /// Pack children at start
  start,

  /// Center children
  center,

  /// Pack children at end
  end,

  /// Distribute space between children
  spaceBetween,
}

/// Cross axis alignment options
enum AutoLayoutCrossAxisAlign {
  /// Align to start of cross axis
  start,

  /// Center on cross axis
  center,

  /// Align to end of cross axis
  end,

  /// Stretch to fill cross axis
  stretch,

  /// Align to text baseline
  baseline,
}

/// Padding configuration
class AutoLayoutPadding {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const AutoLayoutPadding({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  /// Uniform padding on all sides
  const AutoLayoutPadding.all(double value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  /// Symmetric padding
  const AutoLayoutPadding.symmetric({
    double horizontal = 0,
    double vertical = 0,
  })  : top = vertical,
        bottom = vertical,
        left = horizontal,
        right = horizontal;

  /// Create from Figma node properties
  factory AutoLayoutPadding.fromNode(Map<String, dynamic> node) {
    return AutoLayoutPadding(
      top: (node['stackPaddingTop'] as num?)?.toDouble() ??
          (node['paddingTop'] as num?)?.toDouble() ??
          0,
      right: (node['stackPaddingRight'] as num?)?.toDouble() ??
          (node['paddingRight'] as num?)?.toDouble() ??
          0,
      bottom: (node['stackPaddingBottom'] as num?)?.toDouble() ??
          (node['paddingBottom'] as num?)?.toDouble() ??
          0,
      left: (node['stackPaddingLeft'] as num?)?.toDouble() ??
          (node['paddingLeft'] as num?)?.toDouble() ??
          0,
    );
  }

  /// Convert to Flutter EdgeInsets
  EdgeInsets toEdgeInsets([double scale = 1.0]) {
    return EdgeInsets.only(
      top: top * scale,
      right: right * scale,
      bottom: bottom * scale,
      left: left * scale,
    );
  }

  /// Check if padding is uniform
  bool get isUniform => top == right && right == bottom && bottom == left;

  /// Check if padding is symmetric
  bool get isSymmetric => top == bottom && left == right;

  /// Check if padding is zero
  bool get isZero => top == 0 && right == 0 && bottom == 0 && left == 0;

  /// Copy with modifications
  AutoLayoutPadding copyWith({
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    return AutoLayoutPadding(
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
    );
  }

  /// Convert to Figma node properties
  Map<String, dynamic> toNodeProperties() {
    return {
      'stackPaddingTop': top,
      'stackPaddingRight': right,
      'stackPaddingBottom': bottom,
      'stackPaddingLeft': left,
    };
  }
}

/// Size constraints for auto layout
class AutoLayoutConstraints {
  /// Minimum width (null = no constraint)
  final double? minWidth;

  /// Maximum width (null = no constraint)
  final double? maxWidth;

  /// Minimum height (null = no constraint)
  final double? minHeight;

  /// Maximum height (null = no constraint)
  final double? maxHeight;

  const AutoLayoutConstraints({
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  /// Create from Figma node properties
  factory AutoLayoutConstraints.fromNode(Map<String, dynamic> node) {
    return AutoLayoutConstraints(
      minWidth: (node['minWidth'] as num?)?.toDouble(),
      maxWidth: (node['maxWidth'] as num?)?.toDouble(),
      minHeight: (node['minHeight'] as num?)?.toDouble(),
      maxHeight: (node['maxHeight'] as num?)?.toDouble(),
    );
  }

  /// Check if there are any constraints
  bool get hasConstraints =>
      minWidth != null ||
      maxWidth != null ||
      minHeight != null ||
      maxHeight != null;

  /// Convert to Flutter BoxConstraints
  BoxConstraints toBoxConstraints([double scale = 1.0]) {
    return BoxConstraints(
      minWidth: minWidth != null ? minWidth! * scale : 0,
      maxWidth: maxWidth != null ? maxWidth! * scale : double.infinity,
      minHeight: minHeight != null ? minHeight! * scale : 0,
      maxHeight: maxHeight != null ? maxHeight! * scale : double.infinity,
    );
  }

  /// Copy with modifications
  AutoLayoutConstraints copyWith({
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
  }) {
    return AutoLayoutConstraints(
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      minHeight: minHeight ?? this.minHeight,
      maxHeight: maxHeight ?? this.maxHeight,
    );
  }

  /// Convert to Figma node properties
  Map<String, dynamic> toNodeProperties() {
    return {
      if (minWidth != null) 'minWidth': minWidth,
      if (maxWidth != null) 'maxWidth': maxWidth,
      if (minHeight != null) 'minHeight': minHeight,
      if (maxHeight != null) 'maxHeight': maxHeight,
    };
  }
}

/// Grid layout configuration
class AutoLayoutGridConfig {
  /// Number of columns (or auto)
  final int? columns;

  /// Number of rows (or auto)
  final int? rows;

  /// Gap between columns
  final double columnGap;

  /// Gap between rows
  final double rowGap;

  /// Column span for specific children
  final Map<String, int> columnSpans;

  /// Row span for specific children
  final Map<String, int> rowSpans;

  const AutoLayoutGridConfig({
    this.columns,
    this.rows,
    this.columnGap = 0,
    this.rowGap = 0,
    this.columnSpans = const {},
    this.rowSpans = const {},
  });

  /// Create from Figma node properties
  factory AutoLayoutGridConfig.fromNode(Map<String, dynamic> node) {
    return AutoLayoutGridConfig(
      columns: node['gridColumns'] as int?,
      rows: node['gridRows'] as int?,
      columnGap: (node['gridColumnGap'] as num?)?.toDouble() ??
          (node['itemSpacing'] as num?)?.toDouble() ??
          0,
      rowGap: (node['gridRowGap'] as num?)?.toDouble() ??
          (node['itemSpacing'] as num?)?.toDouble() ??
          0,
    );
  }

  /// Copy with modifications
  AutoLayoutGridConfig copyWith({
    int? columns,
    int? rows,
    double? columnGap,
    double? rowGap,
  }) {
    return AutoLayoutGridConfig(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      columnGap: columnGap ?? this.columnGap,
      rowGap: rowGap ?? this.rowGap,
      columnSpans: columnSpans,
      rowSpans: rowSpans,
    );
  }
}

/// Complete auto layout configuration
class AutoLayoutConfig {
  /// Flow direction
  final AutoLayoutFlow flow;

  /// Spacing between items (gap)
  final double itemSpacing;

  /// Padding around content
  final AutoLayoutPadding padding;

  /// Main axis alignment
  final AutoLayoutMainAxisAlign mainAxisAlign;

  /// Cross axis alignment
  final AutoLayoutCrossAxisAlign crossAxisAlign;

  /// Width sizing behavior
  final AutoLayoutSizing widthSizing;

  /// Height sizing behavior
  final AutoLayoutSizing heightSizing;

  /// Size constraints
  final AutoLayoutConstraints constraints;

  /// Grid configuration (for grid flow)
  final AutoLayoutGridConfig? gridConfig;

  /// Whether to reverse child order
  final bool reverse;

  /// Wrap mode enabled (for horizontal flow)
  final bool wrapEnabled;

  /// Clip overflow content
  final bool clipContent;

  const AutoLayoutConfig({
    this.flow = AutoLayoutFlow.none,
    this.itemSpacing = 0,
    this.padding = const AutoLayoutPadding(),
    this.mainAxisAlign = AutoLayoutMainAxisAlign.start,
    this.crossAxisAlign = AutoLayoutCrossAxisAlign.start,
    this.widthSizing = AutoLayoutSizing.fixed,
    this.heightSizing = AutoLayoutSizing.fixed,
    this.constraints = const AutoLayoutConstraints(),
    this.gridConfig,
    this.reverse = false,
    this.wrapEnabled = false,
    this.clipContent = true,
  });

  /// Create from Figma node properties
  factory AutoLayoutConfig.fromNode(Map<String, dynamic> node) {
    final layoutMode = node['stackMode'] ?? node['layoutMode'];

    AutoLayoutFlow flow;
    if (layoutMode == 'VERTICAL' || layoutMode == 1) {
      flow = AutoLayoutFlow.vertical;
    } else if (layoutMode == 'HORIZONTAL' || layoutMode == 2) {
      // Check for wrap mode
      final wrap = node['layoutWrap'] == 'WRAP' || node['layoutWrap'] == true;
      flow = wrap ? AutoLayoutFlow.wrap : AutoLayoutFlow.horizontal;
    } else if (layoutMode == 'GRID' || layoutMode == 3) {
      flow = AutoLayoutFlow.grid;
    } else {
      flow = AutoLayoutFlow.none;
    }

    return AutoLayoutConfig(
      flow: flow,
      itemSpacing: (node['itemSpacing'] as num?)?.toDouble() ??
          (node['stackSpacing'] as num?)?.toDouble() ??
          0,
      padding: AutoLayoutPadding.fromNode(node),
      mainAxisAlign: _parseMainAxisAlign(
          node['stackPrimaryAlignItems'] ?? node['primaryAxisAlignItems']),
      crossAxisAlign: _parseCrossAxisAlign(
          node['stackCounterAlignItems'] ?? node['counterAxisAlignItems']),
      widthSizing: _parseSizing(
          node['stackPrimarySizing'] ?? node['primaryAxisSizingMode']),
      heightSizing: _parseSizing(
          node['stackCounterSizing'] ?? node['counterAxisSizingMode']),
      constraints: AutoLayoutConstraints.fromNode(node),
      gridConfig:
          flow == AutoLayoutFlow.grid ? AutoLayoutGridConfig.fromNode(node) : null,
      reverse: node['stackReverse'] == true || node['itemReverseZIndex'] == true,
      wrapEnabled: node['layoutWrap'] == 'WRAP' || node['layoutWrap'] == true,
      clipContent: node['clipsContent'] as bool? ?? true,
    );
  }

  static AutoLayoutMainAxisAlign _parseMainAxisAlign(dynamic value) {
    if (value == 'CENTER' || value == 1) {
      return AutoLayoutMainAxisAlign.center;
    } else if (value == 'MAX' || value == 'END' || value == 2) {
      return AutoLayoutMainAxisAlign.end;
    } else if (value == 'SPACE_BETWEEN' || value == 3) {
      return AutoLayoutMainAxisAlign.spaceBetween;
    }
    return AutoLayoutMainAxisAlign.start;
  }

  static AutoLayoutCrossAxisAlign _parseCrossAxisAlign(dynamic value) {
    if (value == 'CENTER' || value == 1) {
      return AutoLayoutCrossAxisAlign.center;
    } else if (value == 'MAX' || value == 'END' || value == 2) {
      return AutoLayoutCrossAxisAlign.end;
    } else if (value == 'STRETCH' || value == 3) {
      return AutoLayoutCrossAxisAlign.stretch;
    } else if (value == 'BASELINE' || value == 4) {
      return AutoLayoutCrossAxisAlign.baseline;
    }
    return AutoLayoutCrossAxisAlign.start;
  }

  static AutoLayoutSizing _parseSizing(dynamic value) {
    if (value == 'HUG' || value == 'AUTO' || value == 1) {
      return AutoLayoutSizing.hug;
    } else if (value == 'FILL' || value == 2) {
      return AutoLayoutSizing.fill;
    }
    return AutoLayoutSizing.fixed;
  }

  /// Check if auto layout is enabled
  bool get isEnabled => flow != AutoLayoutFlow.none;

  /// Check if this is a vertical layout
  bool get isVertical => flow == AutoLayoutFlow.vertical;

  /// Check if this is a horizontal layout
  bool get isHorizontal =>
      flow == AutoLayoutFlow.horizontal || flow == AutoLayoutFlow.wrap;

  /// Check if this is a grid layout
  bool get isGrid => flow == AutoLayoutFlow.grid;

  /// Get Flutter MainAxisAlignment
  MainAxisAlignment get flutterMainAxisAlignment {
    switch (mainAxisAlign) {
      case AutoLayoutMainAxisAlign.start:
        return MainAxisAlignment.start;
      case AutoLayoutMainAxisAlign.center:
        return MainAxisAlignment.center;
      case AutoLayoutMainAxisAlign.end:
        return MainAxisAlignment.end;
      case AutoLayoutMainAxisAlign.spaceBetween:
        return MainAxisAlignment.spaceBetween;
    }
  }

  /// Get Flutter CrossAxisAlignment
  CrossAxisAlignment get flutterCrossAxisAlignment {
    switch (crossAxisAlign) {
      case AutoLayoutCrossAxisAlign.start:
        return CrossAxisAlignment.start;
      case AutoLayoutCrossAxisAlign.center:
        return CrossAxisAlignment.center;
      case AutoLayoutCrossAxisAlign.end:
        return CrossAxisAlignment.end;
      case AutoLayoutCrossAxisAlign.stretch:
        return CrossAxisAlignment.stretch;
      case AutoLayoutCrossAxisAlign.baseline:
        return CrossAxisAlignment.baseline;
    }
  }

  /// Get Flutter WrapAlignment
  WrapAlignment get flutterWrapAlignment {
    switch (mainAxisAlign) {
      case AutoLayoutMainAxisAlign.start:
        return WrapAlignment.start;
      case AutoLayoutMainAxisAlign.center:
        return WrapAlignment.center;
      case AutoLayoutMainAxisAlign.end:
        return WrapAlignment.end;
      case AutoLayoutMainAxisAlign.spaceBetween:
        return WrapAlignment.spaceBetween;
    }
  }

  /// Get Flutter WrapCrossAlignment
  WrapCrossAlignment get flutterWrapCrossAlignment {
    switch (crossAxisAlign) {
      case AutoLayoutCrossAxisAlign.start:
        return WrapCrossAlignment.start;
      case AutoLayoutCrossAxisAlign.center:
        return WrapCrossAlignment.center;
      case AutoLayoutCrossAxisAlign.end:
        return WrapCrossAlignment.end;
      case AutoLayoutCrossAxisAlign.stretch:
      case AutoLayoutCrossAxisAlign.baseline:
        return WrapCrossAlignment.center;
    }
  }

  /// Copy with modifications
  AutoLayoutConfig copyWith({
    AutoLayoutFlow? flow,
    double? itemSpacing,
    AutoLayoutPadding? padding,
    AutoLayoutMainAxisAlign? mainAxisAlign,
    AutoLayoutCrossAxisAlign? crossAxisAlign,
    AutoLayoutSizing? widthSizing,
    AutoLayoutSizing? heightSizing,
    AutoLayoutConstraints? constraints,
    AutoLayoutGridConfig? gridConfig,
    bool? reverse,
    bool? wrapEnabled,
    bool? clipContent,
  }) {
    return AutoLayoutConfig(
      flow: flow ?? this.flow,
      itemSpacing: itemSpacing ?? this.itemSpacing,
      padding: padding ?? this.padding,
      mainAxisAlign: mainAxisAlign ?? this.mainAxisAlign,
      crossAxisAlign: crossAxisAlign ?? this.crossAxisAlign,
      widthSizing: widthSizing ?? this.widthSizing,
      heightSizing: heightSizing ?? this.heightSizing,
      constraints: constraints ?? this.constraints,
      gridConfig: gridConfig ?? this.gridConfig,
      reverse: reverse ?? this.reverse,
      wrapEnabled: wrapEnabled ?? this.wrapEnabled,
      clipContent: clipContent ?? this.clipContent,
    );
  }

  /// Convert to Figma node properties
  Map<String, dynamic> toNodeProperties() {
    String? layoutMode;
    switch (flow) {
      case AutoLayoutFlow.none:
        layoutMode = 'NONE';
        break;
      case AutoLayoutFlow.vertical:
        layoutMode = 'VERTICAL';
        break;
      case AutoLayoutFlow.horizontal:
      case AutoLayoutFlow.wrap:
        layoutMode = 'HORIZONTAL';
        break;
      case AutoLayoutFlow.grid:
        layoutMode = 'GRID';
        break;
    }

    String primaryAlign;
    switch (mainAxisAlign) {
      case AutoLayoutMainAxisAlign.start:
        primaryAlign = 'MIN';
        break;
      case AutoLayoutMainAxisAlign.center:
        primaryAlign = 'CENTER';
        break;
      case AutoLayoutMainAxisAlign.end:
        primaryAlign = 'MAX';
        break;
      case AutoLayoutMainAxisAlign.spaceBetween:
        primaryAlign = 'SPACE_BETWEEN';
        break;
    }

    String crossAlign;
    switch (crossAxisAlign) {
      case AutoLayoutCrossAxisAlign.start:
        crossAlign = 'MIN';
        break;
      case AutoLayoutCrossAxisAlign.center:
        crossAlign = 'CENTER';
        break;
      case AutoLayoutCrossAxisAlign.end:
        crossAlign = 'MAX';
        break;
      case AutoLayoutCrossAxisAlign.stretch:
        crossAlign = 'STRETCH';
        break;
      case AutoLayoutCrossAxisAlign.baseline:
        crossAlign = 'BASELINE';
        break;
    }

    return {
      'stackMode': layoutMode,
      'layoutMode': layoutMode,
      'itemSpacing': itemSpacing,
      'stackPrimaryAlignItems': primaryAlign,
      'stackCounterAlignItems': crossAlign,
      'layoutWrap': wrapEnabled ? 'WRAP' : 'NO_WRAP',
      'clipsContent': clipContent,
      ...padding.toNodeProperties(),
      ...constraints.toNodeProperties(),
    };
  }
}

/// Child-specific auto layout properties
class AutoLayoutChildConfig {
  /// Whether this child ignores auto layout (absolute position)
  final bool isAbsolute;

  /// Width sizing for this child
  final AutoLayoutSizing widthSizing;

  /// Height sizing for this child
  final AutoLayoutSizing heightSizing;

  /// Flex grow factor (for fill sizing)
  final double flexGrow;

  /// Align self override (null = use parent's cross align)
  final AutoLayoutCrossAxisAlign? alignSelf;

  /// Fixed width (for fixed sizing)
  final double? fixedWidth;

  /// Fixed height (for fixed sizing)
  final double? fixedHeight;

  /// Constraints
  final AutoLayoutConstraints constraints;

  /// Absolute positioning constraints (when isAbsolute)
  final double? absoluteTop;
  final double? absoluteRight;
  final double? absoluteBottom;
  final double? absoluteLeft;

  const AutoLayoutChildConfig({
    this.isAbsolute = false,
    this.widthSizing = AutoLayoutSizing.fixed,
    this.heightSizing = AutoLayoutSizing.fixed,
    this.flexGrow = 1.0,
    this.alignSelf,
    this.fixedWidth,
    this.fixedHeight,
    this.constraints = const AutoLayoutConstraints(),
    this.absoluteTop,
    this.absoluteRight,
    this.absoluteBottom,
    this.absoluteLeft,
  });

  /// Create from Figma node properties
  factory AutoLayoutChildConfig.fromNode(Map<String, dynamic> node) {
    final positioning = node['layoutPositioning'];
    final isAbsolute =
        positioning == 'ABSOLUTE' || node['layoutPositioning'] == 1;

    return AutoLayoutChildConfig(
      isAbsolute: isAbsolute,
      widthSizing:
          _parseSizing(node['layoutSizingHorizontal'] ?? node['layoutGrow']),
      heightSizing:
          _parseSizing(node['layoutSizingVertical'] ?? node['layoutGrow']),
      flexGrow: (node['layoutGrow'] as num?)?.toDouble() ?? 1.0,
      alignSelf: _parseAlignSelf(node['layoutAlign']),
      constraints: AutoLayoutConstraints.fromNode(node),
      absoluteTop: isAbsolute
          ? (node['constraints']?['vertical'] == 'TOP'
              ? node['y'] as double?
              : null)
          : null,
      absoluteLeft: isAbsolute
          ? (node['constraints']?['horizontal'] == 'LEFT'
              ? node['x'] as double?
              : null)
          : null,
    );
  }

  static AutoLayoutSizing _parseSizing(dynamic value) {
    if (value == 'HUG' || value == 'AUTO' || value == 0) {
      return AutoLayoutSizing.hug;
    } else if (value == 'FILL' || value == 1) {
      return AutoLayoutSizing.fill;
    }
    return AutoLayoutSizing.fixed;
  }

  static AutoLayoutCrossAxisAlign? _parseAlignSelf(dynamic value) {
    if (value == 'MIN' || value == 'START' || value == 0) {
      return AutoLayoutCrossAxisAlign.start;
    } else if (value == 'CENTER' || value == 1) {
      return AutoLayoutCrossAxisAlign.center;
    } else if (value == 'MAX' || value == 'END' || value == 2) {
      return AutoLayoutCrossAxisAlign.end;
    } else if (value == 'STRETCH' || value == 3) {
      return AutoLayoutCrossAxisAlign.stretch;
    }
    return null;
  }

  /// Check if this child should fill available space
  bool get isFillWidth => widthSizing == AutoLayoutSizing.fill;
  bool get isFillHeight => heightSizing == AutoLayoutSizing.fill;

  /// Copy with modifications
  AutoLayoutChildConfig copyWith({
    bool? isAbsolute,
    AutoLayoutSizing? widthSizing,
    AutoLayoutSizing? heightSizing,
    double? flexGrow,
    AutoLayoutCrossAxisAlign? alignSelf,
    double? fixedWidth,
    double? fixedHeight,
    AutoLayoutConstraints? constraints,
    double? absoluteTop,
    double? absoluteRight,
    double? absoluteBottom,
    double? absoluteLeft,
  }) {
    return AutoLayoutChildConfig(
      isAbsolute: isAbsolute ?? this.isAbsolute,
      widthSizing: widthSizing ?? this.widthSizing,
      heightSizing: heightSizing ?? this.heightSizing,
      flexGrow: flexGrow ?? this.flexGrow,
      alignSelf: alignSelf ?? this.alignSelf,
      fixedWidth: fixedWidth ?? this.fixedWidth,
      fixedHeight: fixedHeight ?? this.fixedHeight,
      constraints: constraints ?? this.constraints,
      absoluteTop: absoluteTop ?? this.absoluteTop,
      absoluteRight: absoluteRight ?? this.absoluteRight,
      absoluteBottom: absoluteBottom ?? this.absoluteBottom,
      absoluteLeft: absoluteLeft ?? this.absoluteLeft,
    );
  }

  /// Convert to Figma node properties
  Map<String, dynamic> toNodeProperties() {
    String widthMode;
    switch (widthSizing) {
      case AutoLayoutSizing.hug:
        widthMode = 'HUG';
        break;
      case AutoLayoutSizing.fill:
        widthMode = 'FILL';
        break;
      case AutoLayoutSizing.fixed:
        widthMode = 'FIXED';
        break;
    }

    String heightMode;
    switch (heightSizing) {
      case AutoLayoutSizing.hug:
        heightMode = 'HUG';
        break;
      case AutoLayoutSizing.fill:
        heightMode = 'FILL';
        break;
      case AutoLayoutSizing.fixed:
        heightMode = 'FIXED';
        break;
    }

    return {
      'layoutPositioning': isAbsolute ? 'ABSOLUTE' : 'AUTO',
      'layoutSizingHorizontal': widthMode,
      'layoutSizingVertical': heightMode,
      'layoutGrow': flexGrow,
      ...constraints.toNodeProperties(),
    };
  }
}
