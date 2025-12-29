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
