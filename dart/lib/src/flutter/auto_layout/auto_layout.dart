/// Auto layout module for Figma-style responsive layouts
///
/// This module provides complete auto layout functionality:
/// - Data models for all auto layout properties
/// - Renderer that maps to Flutter Row/Column/Wrap/GridView
/// - Properties panel for editing layouts
/// - Absolute positioning support
///
/// Usage:
/// ```dart
/// import 'package:kiwi_schema/flutter_renderer.dart';
///
/// // Check if a node has auto layout
/// if (node.hasAutoLayout) {
///   final config = node.autoLayoutConfig;
///
///   // Build layout
///   final renderer = AutoLayoutRenderer(config: config);
///   final widget = renderer.build(
///     flowChildren: children,
///     absoluteChildren: absoluteChildren,
///   );
/// }
/// ```

library;

export 'auto_layout_data.dart';
export 'auto_layout_renderer.dart';
export 'auto_layout_panel.dart';
