/// Flutter renderer for Figma nodes
///
/// This library provides Flutter widgets to render Figma documents.
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

export 'node_renderer.dart';
export 'figma_canvas.dart';
