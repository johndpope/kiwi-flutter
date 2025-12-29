/// Auto layout renderer for building Flutter widgets from Figma auto layout
///
/// Converts auto layout configuration to:
/// - Column for vertical flow
/// - Row for horizontal flow
/// - Wrap for horizontal with wrapping
/// - GridView for grid flow
/// - Stack overlay for absolute positioned children

import 'package:flutter/material.dart';
import 'auto_layout_data.dart';

/// Builds Flutter widgets for auto layout frames
class AutoLayoutRenderer {
  /// The auto layout configuration
  final AutoLayoutConfig config;

  /// Scale factor for dimensions
  final double scale;

  const AutoLayoutRenderer({
    required this.config,
    this.scale = 1.0,
  });

  /// Build the layout widget containing children
  Widget build({
    required List<Widget> flowChildren,
    List<Widget> absoluteChildren = const [],
    Size? frameSize,
  }) {
    if (!config.isEnabled) {
      // No auto layout - use Stack for positioning
      return Stack(children: [...flowChildren, ...absoluteChildren]);
    }

    Widget layout;

    // Build the flow layout
    switch (config.flow) {
      case AutoLayoutFlow.vertical:
        layout = _buildColumn(flowChildren);
        break;
      case AutoLayoutFlow.horizontal:
        layout = _buildRow(flowChildren);
        break;
      case AutoLayoutFlow.wrap:
        layout = _buildWrap(flowChildren);
        break;
      case AutoLayoutFlow.grid:
        layout = _buildGrid(flowChildren, frameSize);
        break;
      case AutoLayoutFlow.none:
        layout = Stack(children: flowChildren);
        break;
    }

    // Add padding
    if (!config.padding.isZero) {
      layout = Padding(
        padding: config.padding.toEdgeInsets(scale),
        child: layout,
      );
    }

    // Add constraints if needed
    if (config.constraints.hasConstraints) {
      layout = ConstrainedBox(
        constraints: config.constraints.toBoxConstraints(scale),
        child: layout,
      );
    }

    // Handle sizing behaviors
    layout = _applySizing(layout, frameSize);

    // Clip content if enabled
    if (config.clipContent) {
      layout = ClipRect(child: layout);
    }

    // Overlay absolute positioned children
    if (absoluteChildren.isNotEmpty) {
      layout = Stack(
        children: [
          layout,
          ...absoluteChildren,
        ],
      );
    }

    return layout;
  }

  /// Build a Column layout
  Widget _buildColumn(List<Widget> children) {
    if (config.reverse) {
      children = children.reversed.toList();
    }

    // Add spacing between children
    final spacedChildren = _addSpacing(children, isVertical: true);

    return Column(
      mainAxisSize: _getMainAxisSize(),
      mainAxisAlignment: config.flutterMainAxisAlignment,
      crossAxisAlignment: config.flutterCrossAxisAlignment,
      textBaseline:
          config.crossAxisAlign == AutoLayoutCrossAxisAlign.baseline
              ? TextBaseline.alphabetic
              : null,
      children: spacedChildren,
    );
  }

  /// Build a Row layout
  Widget _buildRow(List<Widget> children) {
    if (config.reverse) {
      children = children.reversed.toList();
    }

    // Add spacing between children
    final spacedChildren = _addSpacing(children, isVertical: false);

    return Row(
      mainAxisSize: _getMainAxisSize(),
      mainAxisAlignment: config.flutterMainAxisAlignment,
      crossAxisAlignment: config.flutterCrossAxisAlignment,
      textBaseline:
          config.crossAxisAlign == AutoLayoutCrossAxisAlign.baseline
              ? TextBaseline.alphabetic
              : null,
      children: spacedChildren,
    );
  }

  /// Build a Wrap layout
  Widget _buildWrap(List<Widget> children) {
    if (config.reverse) {
      children = children.reversed.toList();
    }

    return Wrap(
      direction: Axis.horizontal,
      spacing: config.itemSpacing * scale,
      runSpacing: config.itemSpacing * scale,
      alignment: config.flutterWrapAlignment,
      crossAxisAlignment: config.flutterWrapCrossAlignment,
      children: children,
    );
  }

  /// Build a Grid layout
  Widget _buildGrid(List<Widget> children, Size? frameSize) {
    final gridConfig = config.gridConfig ?? const AutoLayoutGridConfig();

    if (config.reverse) {
      children = children.reversed.toList();
    }

    // Determine column count
    int crossAxisCount = gridConfig.columns ?? 2;
    if (frameSize != null && gridConfig.columns == null) {
      // Auto-calculate columns based on child width
      // This is a simplified heuristic
      crossAxisCount =
          (frameSize.width / 100).clamp(1, children.length).toInt();
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: (gridConfig.rowGap) * scale,
      crossAxisSpacing: (gridConfig.columnGap) * scale,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }

  /// Add spacing SizedBoxes between children
  List<Widget> _addSpacing(List<Widget> children, {required bool isVertical}) {
    if (config.itemSpacing <= 0 ||
        config.mainAxisAlign == AutoLayoutMainAxisAlign.spaceBetween) {
      return children;
    }

    final spacing = config.itemSpacing * scale;
    final spacedChildren = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(
          width: isVertical ? 0 : spacing,
          height: isVertical ? spacing : 0,
        ));
      }
    }

    return spacedChildren;
  }

  /// Get MainAxisSize based on sizing config
  MainAxisSize _getMainAxisSize() {
    final sizing =
        config.isVertical ? config.heightSizing : config.widthSizing;
    return sizing == AutoLayoutSizing.hug
        ? MainAxisSize.min
        : MainAxisSize.max;
  }

  /// Apply sizing behaviors to the layout
  Widget _applySizing(Widget layout, Size? frameSize) {
    // Handle width sizing
    if (config.widthSizing == AutoLayoutSizing.fill) {
      layout = SizedBox(
        width: double.infinity,
        child: layout,
      );
    } else if (config.widthSizing == AutoLayoutSizing.fixed &&
        frameSize != null) {
      layout = SizedBox(
        width: frameSize.width * scale,
        child: layout,
      );
    }

    // Handle height sizing
    if (config.heightSizing == AutoLayoutSizing.fill) {
      layout = SizedBox(
        height: double.infinity,
        child: layout,
      );
    } else if (config.heightSizing == AutoLayoutSizing.fixed &&
        frameSize != null) {
      layout = SizedBox(
        height: frameSize.height * scale,
        child: layout,
      );
    }

    return layout;
  }

  /// Wrap a child with appropriate sizing wrapper
  static Widget wrapChild({
    required Widget child,
    required AutoLayoutChildConfig childConfig,
    required AutoLayoutConfig parentConfig,
    double scale = 1.0,
  }) {
    Widget wrapped = child;

    // Apply constraints
    if (childConfig.constraints.hasConstraints) {
      wrapped = ConstrainedBox(
        constraints: childConfig.constraints.toBoxConstraints(scale),
        child: wrapped,
      );
    }

    // Apply fixed sizing
    double? width;
    double? height;

    if (childConfig.widthSizing == AutoLayoutSizing.fixed &&
        childConfig.fixedWidth != null) {
      width = childConfig.fixedWidth! * scale;
    }

    if (childConfig.heightSizing == AutoLayoutSizing.fixed &&
        childConfig.fixedHeight != null) {
      height = childConfig.fixedHeight! * scale;
    }

    if (width != null || height != null) {
      wrapped = SizedBox(
        width: width,
        height: height,
        child: wrapped,
      );
    }

    // Apply fill sizing with Expanded/Flexible
    if (childConfig.widthSizing == AutoLayoutSizing.fill &&
        parentConfig.isHorizontal) {
      wrapped = Expanded(
        flex: childConfig.flexGrow.toInt().clamp(1, 100),
        child: wrapped,
      );
    } else if (childConfig.heightSizing == AutoLayoutSizing.fill &&
        parentConfig.isVertical) {
      wrapped = Expanded(
        flex: childConfig.flexGrow.toInt().clamp(1, 100),
        child: wrapped,
      );
    }

    // Apply align self
    if (childConfig.alignSelf != null) {
      Alignment alignment;
      switch (childConfig.alignSelf!) {
        case AutoLayoutCrossAxisAlign.start:
          alignment = parentConfig.isVertical
              ? Alignment.centerLeft
              : Alignment.topCenter;
          break;
        case AutoLayoutCrossAxisAlign.center:
          alignment = Alignment.center;
          break;
        case AutoLayoutCrossAxisAlign.end:
          alignment = parentConfig.isVertical
              ? Alignment.centerRight
              : Alignment.bottomCenter;
          break;
        case AutoLayoutCrossAxisAlign.stretch:
        case AutoLayoutCrossAxisAlign.baseline:
          alignment = Alignment.center;
          break;
      }
      wrapped = Align(alignment: alignment, child: wrapped);
    }

    return wrapped;
  }

  /// Build a positioned widget for absolute children
  static Widget buildAbsoluteChild({
    required Widget child,
    required AutoLayoutChildConfig childConfig,
    double scale = 1.0,
  }) {
    return Positioned(
      top: childConfig.absoluteTop != null
          ? childConfig.absoluteTop! * scale
          : null,
      right: childConfig.absoluteRight != null
          ? childConfig.absoluteRight! * scale
          : null,
      bottom: childConfig.absoluteBottom != null
          ? childConfig.absoluteBottom! * scale
          : null,
      left: childConfig.absoluteLeft != null
          ? childConfig.absoluteLeft! * scale
          : null,
      child: child,
    );
  }
}

/// Widget that renders an auto layout frame
class AutoLayoutWidget extends StatelessWidget {
  /// The auto layout configuration
  final AutoLayoutConfig config;

  /// Children that participate in the flow
  final List<Widget> flowChildren;

  /// Children with absolute positioning
  final List<Widget> absoluteChildren;

  /// Frame size (optional, for fixed sizing)
  final Size? frameSize;

  /// Scale factor
  final double scale;

  /// Background decoration
  final BoxDecoration? decoration;

  const AutoLayoutWidget({
    super.key,
    required this.config,
    required this.flowChildren,
    this.absoluteChildren = const [],
    this.frameSize,
    this.scale = 1.0,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final renderer = AutoLayoutRenderer(config: config, scale: scale);

    Widget layout = renderer.build(
      flowChildren: flowChildren,
      absoluteChildren: absoluteChildren,
      frameSize: frameSize,
    );

    if (decoration != null) {
      layout = DecoratedBox(
        decoration: decoration!,
        child: layout,
      );
    }

    return layout;
  }
}

/// Extension to easily detect and apply auto layout to nodes
extension AutoLayoutNodeExtension on Map<String, dynamic> {
  /// Check if this node has auto layout enabled
  bool get hasAutoLayout {
    final layoutMode = this['stackMode'] ?? this['layoutMode'];
    return layoutMode != null && layoutMode != 'NONE' && layoutMode != 0;
  }

  /// Get the auto layout configuration
  AutoLayoutConfig get autoLayoutConfig {
    return AutoLayoutConfig.fromNode(this);
  }

  /// Get child-specific auto layout config
  AutoLayoutChildConfig get autoLayoutChildConfig {
    return AutoLayoutChildConfig.fromNode(this);
  }
}

/// Mixin for widgets that need auto layout support
mixin AutoLayoutMixin {
  /// Check if a node uses auto layout
  bool isAutoLayoutNode(Map<String, dynamic> node) {
    return node.hasAutoLayout;
  }

  /// Build children for an auto layout node
  Widget buildAutoLayoutChildren({
    required Map<String, dynamic> node,
    required Map<String, Map<String, dynamic>> nodeMap,
    required Widget Function(Map<String, dynamic> childNode) childBuilder,
    double scale = 1.0,
  }) {
    final config = node.autoLayoutConfig;
    final childrenKeys = node['children'] as List?;

    if (childrenKeys == null || childrenKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    final flowChildren = <Widget>[];
    final absoluteChildren = <Widget>[];

    for (final childKey in childrenKeys) {
      final childNode = nodeMap[childKey.toString()];
      if (childNode == null) continue;

      // Check visibility
      final visible = childNode['visible'] as bool? ?? true;
      if (!visible) continue;

      final childConfig = childNode.autoLayoutChildConfig;
      Widget childWidget = childBuilder(childNode);

      if (childConfig.isAbsolute) {
        // Absolute positioned child
        absoluteChildren.add(
          AutoLayoutRenderer.buildAbsoluteChild(
            child: childWidget,
            childConfig: childConfig,
            scale: scale,
          ),
        );
      } else {
        // Flow child - apply sizing wrappers
        childWidget = AutoLayoutRenderer.wrapChild(
          child: childWidget,
          childConfig: childConfig,
          parentConfig: config,
          scale: scale,
        );
        flowChildren.add(childWidget);
      }
    }

    // Get frame size if available
    final sizeData = node['size'] as Map<String, dynamic>?;
    Size? frameSize;
    if (sizeData != null) {
      frameSize = Size(
        (sizeData['x'] as num?)?.toDouble() ?? 0,
        (sizeData['y'] as num?)?.toDouble() ?? 0,
      );
    }

    return AutoLayoutWidget(
      config: config,
      flowChildren: flowChildren,
      absoluteChildren: absoluteChildren,
      frameSize: frameSize,
      scale: scale,
    );
  }
}
