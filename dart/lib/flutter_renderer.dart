/// Flutter renderer for Figma nodes
///
/// This library provides Flutter widgets to render Figma documents.
/// Note: This library requires Flutter and is separate from the core kiwi library.
///
/// Example usage:
/// ```dart
/// import 'package:kiwi_schema/kiwi.dart';
/// import 'package:kiwi_schema/flutter_renderer.dart';
///
/// // Parse a Figma file
/// final parsed = parseFigFile(
///   fileData,
///   zstdDecompress: (data) => zstd.decode(data),
///   deflateDecompress: (data) => zlib.ZLibDecoder(raw: true).convert(data),
/// );
///
/// // Create a document from the parsed message
/// final document = FigmaDocument.fromMessage(parsed.message);
///
/// // Use in a widget
/// FigmaCanvasView(document: document)
/// ```
library flutter_renderer;

export 'src/flutter/node_renderer.dart';
export 'src/flutter/figma_canvas.dart';

// Rendering utilities
export 'src/flutter/rendering/paint_renderer.dart';
export 'src/flutter/rendering/effect_renderer.dart';
export 'src/flutter/rendering/blend_modes.dart';

// State management
export 'src/flutter/state/state.dart';

// Editing tools
export 'src/flutter/editing/editing.dart';

// UI panels and widgets
export 'src/flutter/ui/ui.dart';

// Auto layout
export 'src/flutter/auto_layout/auto_layout.dart';

// Assets (components, styles, variables, frame presets)
export 'src/flutter/assets/assets.dart';

// Operations (boolean operations, export)
export 'src/flutter/operations/operations.dart';

// Constraints (layout constraints)
export 'src/flutter/constraints/constraints.dart';

// Shape tools
export 'src/flutter/tools/tools.dart';

// Advanced stroke options
export 'src/flutter/rendering/stroke_options.dart';

// Prototyping (interactions, navigation, player)
export 'src/flutter/prototyping/prototyping.dart';

// Variables (design tokens, collections, modes, import/export)
export 'src/flutter/variables/variables.dart';

// Toolbar (design tools, modes, shortcuts)
export 'src/flutter/toolbar/toolbar_exports.dart';

// Context Menu (right-click actions, submenus)
export 'src/flutter/context_menu/context_menu_exports.dart';

// Assets Panel (components, colors, materials, typography browser)
export 'src/flutter/assets_panel/assets_panel_exports.dart';

// Menu Bar (File, Edit, View, Object, Vector, Text, Arrange menus)
export 'src/flutter/menu_bar/menu_bar_exports.dart';

// Plugins (plugin system, manifest parsing, plugin management)
export 'src/flutter/plugins/plugin_exports.dart';

// Tiles (tile-based rendering for large documents)
export 'src/flutter/tiles/tiles.dart';
