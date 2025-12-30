/// Tile Rasterizer - converts draw commands to ui.Image
///
/// Takes DrawCommand objects from Rust and rasterizes them
/// to Flutter images that can be efficiently painted.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'viewport.dart';

/// Rasterizes draw commands to tile images
class TileRasterizer {
  /// Size of rendered tile images in pixels
  final int tilePixelSize;

  TileRasterizer({this.tilePixelSize = 1024});

  /// Rasterize a list of draw commands to an image
  Future<ui.Image> rasterize(
    List<DrawCommandData> commands,
    TileCoord coord,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill background with transparent
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tilePixelSize.toDouble(), tilePixelSize.toDouble()),
      Paint()..color = Colors.transparent,
    );

    // Calculate world-to-tile transform
    final tileBounds = coord.bounds;
    final scale = tilePixelSize / kTileSize;

    // Translate so tile origin is at (0, 0) in canvas
    canvas.translate(-tileBounds.left * scale, -tileBounds.top * scale);
    canvas.scale(scale);

    // Render each command
    for (final cmd in commands) {
      _renderCommand(canvas, cmd);
    }

    final picture = recorder.endRecording();
    return picture.toImage(tilePixelSize, tilePixelSize);
  }

  /// Create a placeholder tile (for testing/loading state)
  Future<ui.Image> createPlaceholderTile(TileCoord coord) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final size = tilePixelSize.toDouble();

    // Light gray background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFF2A2A2A),
    );

    // Subtle grid pattern
    final gridPaint = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const gridSize = 64.0;
    for (var x = 0.0; x < size; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size), gridPaint);
    }
    for (var y = 0.0; y < size; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size, y), gridPaint);
    }

    // Tile coordinate text
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
    ))
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF555555),
        fontSize: 14,
      ))
      ..addText('Tile (${coord.x}, ${coord.y})\nZoom ${coord.zoomLevel}');

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size));

    canvas.drawParagraph(
      paragraph,
      Offset(0, size / 2 - 20),
    );

    final picture = recorder.endRecording();
    return picture.toImage(tilePixelSize, tilePixelSize);
  }

  /// Render a single draw command
  void _renderCommand(Canvas canvas, DrawCommandData cmd) {
    switch (cmd.type) {
      case DrawCommandType.rect:
        _renderRect(canvas, cmd);
        break;
      case DrawCommandType.ellipse:
        _renderEllipse(canvas, cmd);
        break;
      case DrawCommandType.path:
        _renderPath(canvas, cmd);
        break;
      case DrawCommandType.text:
        _renderText(canvas, cmd);
        break;
      case DrawCommandType.image:
        _renderImage(canvas, cmd);
        break;
    }
  }

  void _renderRect(Canvas canvas, DrawCommandData cmd) {
    final rect = cmd.rect;
    if (rect == null) return;

    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(cmd.cornerRadii?[0] ?? 0),
      topRight: Radius.circular(cmd.cornerRadii?[1] ?? 0),
      bottomRight: Radius.circular(cmd.cornerRadii?[2] ?? 0),
      bottomLeft: Radius.circular(cmd.cornerRadii?[3] ?? 0),
    );

    // Draw fills
    for (final fill in cmd.fills) {
      canvas.drawRRect(rrect, fill.toPaint());
    }

    // Draw strokes
    for (final stroke in cmd.strokes) {
      final paint = stroke.toPaint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cmd.strokeWeight;
      canvas.drawRRect(rrect, paint);
    }
  }

  void _renderEllipse(Canvas canvas, DrawCommandData cmd) {
    final rect = cmd.rect;
    if (rect == null) return;

    // Draw fills
    for (final fill in cmd.fills) {
      canvas.drawOval(rect, fill.toPaint());
    }

    // Draw strokes
    for (final stroke in cmd.strokes) {
      final paint = stroke.toPaint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cmd.strokeWeight;
      canvas.drawOval(rect, paint);
    }
  }

  void _renderPath(Canvas canvas, DrawCommandData cmd) {
    final path = cmd.path;
    if (path == null) return;

    // Draw fills
    for (final fill in cmd.fills) {
      canvas.drawPath(path, fill.toPaint());
    }

    // Draw strokes
    for (final stroke in cmd.strokes) {
      final paint = stroke.toPaint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cmd.strokeWeight;
      canvas.drawPath(path, paint);
    }
  }

  void _renderText(Canvas canvas, DrawCommandData cmd) {
    // Text rendering requires more complex handling
    // For now, draw a placeholder rectangle
    final rect = cmd.rect;
    if (rect == null) return;

    canvas.drawRect(
      rect,
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  void _renderImage(Canvas canvas, DrawCommandData cmd) {
    // Image rendering requires loading the image first
    // For now, draw a placeholder
    final rect = cmd.rect;
    if (rect == null) return;

    canvas.drawRect(
      rect,
      Paint()..color = const Color(0x33888888),
    );

    // Draw image icon
    final iconSize = rect.shortestSide * 0.3;
    final iconRect = Rect.fromCenter(
      center: rect.center,
      width: iconSize,
      height: iconSize,
    );
    canvas.drawRect(
      iconRect,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// Type of draw command
enum DrawCommandType {
  rect,
  ellipse,
  path,
  text,
  image,
}

/// Paint type
enum PaintType {
  solid,
  linearGradient,
  radialGradient,
  image,
}

/// Draw command data (Dart representation of Rust DrawCommand)
class DrawCommandData {
  final DrawCommandType type;
  final Rect? rect;
  final Path? path;
  final List<double>? cornerRadii;
  final List<PaintData> fills;
  final List<PaintData> strokes;
  final double strokeWeight;
  final Matrix4? transform;

  DrawCommandData({
    required this.type,
    this.rect,
    this.path,
    this.cornerRadii,
    this.fills = const [],
    this.strokes = const [],
    this.strokeWeight = 1.0,
    this.transform,
  });

  /// Create from Rust API result
  factory DrawCommandData.fromRust(Map<String, dynamic> data) {
    final commandType = _parseCommandType(data['command_type'] as String?);

    Rect? rect;
    if (data['rect'] is Map) {
      final r = data['rect'] as Map;
      rect = Rect.fromLTWH(
        (r['x'] as num?)?.toDouble() ?? 0,
        (r['y'] as num?)?.toDouble() ?? 0,
        (r['width'] as num?)?.toDouble() ?? 0,
        (r['height'] as num?)?.toDouble() ?? 0,
      );
    }

    Path? path;
    if (data['path'] is Map) {
      path = _parsePath(data['path'] as Map);
    }

    final cornerRadii = (data['corner_radii'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();

    final fills = (data['fills'] as List?)
        ?.map((e) => PaintData.fromRust(e as Map))
        .toList() ?? [];

    final strokes = (data['strokes'] as List?)
        ?.map((e) => PaintData.fromRust(e as Map))
        .toList() ?? [];

    return DrawCommandData(
      type: commandType,
      rect: rect,
      path: path,
      cornerRadii: cornerRadii,
      fills: fills,
      strokes: strokes,
      strokeWeight: (data['stroke_weight'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static DrawCommandType _parseCommandType(String? type) {
    switch (type) {
      case 'rect':
        return DrawCommandType.rect;
      case 'ellipse':
        return DrawCommandType.ellipse;
      case 'path':
        return DrawCommandType.path;
      case 'text':
        return DrawCommandType.text;
      case 'image':
        return DrawCommandType.image;
      default:
        return DrawCommandType.rect;
    }
  }

  static Path _parsePath(Map data) {
    final path = Path();
    final commands = data['commands'] as String? ?? '';

    // Simple SVG path parser (M, L, C, Q, Z)
    final regex = RegExp(r'([MLCQZ])\s*([^MLCQZ]*)');
    for (final match in regex.allMatches(commands.toUpperCase())) {
      final cmd = match.group(1);
      final params = match.group(2)?.trim().split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map(double.parse)
          .toList() ?? [];

      switch (cmd) {
        case 'M':
          if (params.length >= 2) {
            path.moveTo(params[0], params[1]);
          }
          break;
        case 'L':
          if (params.length >= 2) {
            path.lineTo(params[0], params[1]);
          }
          break;
        case 'C':
          if (params.length >= 6) {
            path.cubicTo(
              params[0], params[1],
              params[2], params[3],
              params[4], params[5],
            );
          }
          break;
        case 'Q':
          if (params.length >= 4) {
            path.quadraticBezierTo(
              params[0], params[1],
              params[2], params[3],
            );
          }
          break;
        case 'Z':
          path.close();
          break;
      }
    }

    // Apply fill rule if specified
    if (data['fill_rule'] == 'evenodd') {
      path.fillType = PathFillType.evenOdd;
    }

    return path;
  }
}

/// Paint data (Dart representation of Rust PaintInfo)
class PaintData {
  final PaintType type;
  final Color? color;
  final List<TileGradientStop>? gradientStops;
  final Offset? gradientStart;
  final Offset? gradientEnd;
  final double opacity;
  final BlendMode blendMode;

  PaintData({
    required this.type,
    this.color,
    this.gradientStops,
    this.gradientStart,
    this.gradientEnd,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
  });

  factory PaintData.fromRust(Map data) {
    final paintType = _parsePaintType(data['paint_type'] as String?);

    Color? color;
    if (data['color'] is Map) {
      final c = data['color'] as Map;
      color = Color.fromARGB(
        (c['a'] as int?) ?? 255,
        (c['r'] as int?) ?? 0,
        (c['g'] as int?) ?? 0,
        (c['b'] as int?) ?? 0,
      );
    }

    return PaintData(
      type: paintType,
      color: color,
      opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static PaintType _parsePaintType(String? type) {
    switch (type) {
      case 'solid':
        return PaintType.solid;
      case 'gradient_linear':
        return PaintType.linearGradient;
      case 'gradient_radial':
        return PaintType.radialGradient;
      case 'image':
        return PaintType.image;
      default:
        return PaintType.solid;
    }
  }

  Paint toPaint() {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = blendMode;

    switch (type) {
      case PaintType.solid:
        paint.color = (color ?? Colors.black).withValues(alpha: opacity);
        break;
      case PaintType.linearGradient:
        if (gradientStops != null && gradientStart != null && gradientEnd != null) {
          paint.shader = ui.Gradient.linear(
            gradientStart!,
            gradientEnd!,
            gradientStops!.map((s) => s.color).toList(),
            gradientStops!.map((s) => s.offset).toList(),
          );
        }
        break;
      case PaintType.radialGradient:
        // TODO: Implement radial gradient
        paint.color = (color ?? Colors.black).withValues(alpha: opacity);
        break;
      case PaintType.image:
        // Image paints require special handling
        paint.color = const Color(0x33888888);
        break;
    }

    return paint;
  }
}

/// Gradient stop for tile rendering
class TileGradientStop {
  final double offset;
  final Color color;

  TileGradientStop(this.offset, this.color);
}
