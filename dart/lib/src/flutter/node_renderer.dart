/// Flutter node renderer for Figma nodes
///
/// This module provides widgets to render Figma nodes as Flutter widgets,
/// following the structure of grida-canvas-react-renderer-dom.

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Base class for node properties extracted from Figma node data
class FigmaNodeProperties {
  final String? id;
  final String? name;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final bool visible;
  final List<Map<String, dynamic>> fills;
  final List<Map<String, dynamic>> strokes;
  final double strokeWeight;
  final List<Map<String, dynamic>> effects;
  final Map<String, dynamic>? constraints;
  final List<double>? cornerRadii;
  final double? cornerRadius;
  final Map<String, dynamic> raw;

  FigmaNodeProperties({
    this.id,
    this.name,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
    this.opacity = 1.0,
    this.visible = true,
    this.fills = const [],
    this.strokes = const [],
    this.strokeWeight = 0,
    this.effects = const [],
    this.constraints,
    this.cornerRadii,
    this.cornerRadius,
    required this.raw,
  });

  /// Create properties from a raw Figma node map
  factory FigmaNodeProperties.fromMap(Map<String, dynamic> node) {
    // Extract transform/position
    double x = 0, y = 0, width = 0, height = 0, rotation = 0;

    // Try to get transform from node
    final transform = node['transform'];
    if (transform is Map) {
      x = (transform['m02'] as num?)?.toDouble() ?? 0;
      y = (transform['m12'] as num?)?.toDouble() ?? 0;
    }

    // Try to get size
    final size = node['size'];
    if (size is Map) {
      width = (size['x'] as num?)?.toDouble() ?? 0;
      height = (size['y'] as num?)?.toDouble() ?? 0;
    }

    // Try boundingBox if transform not available
    final bbox = node['boundingBox'];
    if (bbox is Map) {
      x = x == 0 ? ((bbox['x'] as num?)?.toDouble() ?? 0) : x;
      y = y == 0 ? ((bbox['y'] as num?)?.toDouble() ?? 0) : y;
      width = width == 0 ? ((bbox['width'] as num?)?.toDouble() ?? 0) : width;
      height = height == 0 ? ((bbox['height'] as num?)?.toDouble() ?? 0) : height;
    }

    // Extract fills
    List<Map<String, dynamic>> fills = [];
    final fillsData = node['fillPaints'];
    if (fillsData is List) {
      fills = fillsData.cast<Map<String, dynamic>>();
    }

    // Extract strokes
    List<Map<String, dynamic>> strokes = [];
    final strokesData = node['strokePaints'];
    if (strokesData is List) {
      strokes = strokesData.cast<Map<String, dynamic>>();
    }

    // Extract effects
    List<Map<String, dynamic>> effects = [];
    final effectsData = node['effects'];
    if (effectsData is List) {
      effects = effectsData.cast<Map<String, dynamic>>();
    }

    // Extract corner radii
    List<double>? cornerRadii;
    final radii = node['rectangleCornerRadii'];
    if (radii is List) {
      cornerRadii = radii.map((r) => (r as num).toDouble()).toList();
    }

    double? cornerRadius;
    final cr = node['cornerRadius'];
    if (cr is num) {
      cornerRadius = cr.toDouble();
    }

    return FigmaNodeProperties(
      id: node['guid']?.toString(),
      name: node['name'] as String?,
      type: node['type'] as String? ?? 'UNKNOWN',
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: rotation,
      opacity: (node['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: node['visible'] as bool? ?? true,
      fills: fills,
      strokes: strokes,
      strokeWeight: (node['strokeWeight'] as num?)?.toDouble() ?? 0,
      effects: effects,
      constraints: node['constraints'] as Map<String, dynamic>?,
      cornerRadii: cornerRadii,
      cornerRadius: cornerRadius,
      raw: node,
    );
  }

  /// Get the effective corner radius (single value or average of corners)
  double get effectiveCornerRadius {
    if (cornerRadii != null && cornerRadii!.isNotEmpty) {
      return cornerRadii!.first;
    }
    return cornerRadius ?? 0;
  }

  /// Get all corner radii as BorderRadius
  BorderRadius? get borderRadius {
    if (cornerRadii != null && cornerRadii!.length >= 4) {
      return BorderRadius.only(
        topLeft: Radius.circular(cornerRadii![0]),
        topRight: Radius.circular(cornerRadii![1]),
        bottomRight: Radius.circular(cornerRadii![2]),
        bottomLeft: Radius.circular(cornerRadii![3]),
      );
    }
    if (cornerRadius != null && cornerRadius! > 0) {
      return BorderRadius.circular(cornerRadius!);
    }
    return null;
  }
}

/// Main node renderer widget that routes to specific renderers based on node type
class FigmaNodeWidget extends StatelessWidget {
  final Map<String, dynamic> node;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final double scale;
  final bool showBounds;

  const FigmaNodeWidget({
    super.key,
    required this.node,
    this.nodeMap,
    this.scale = 1.0,
    this.showBounds = false,
  });

  @override
  Widget build(BuildContext context) {
    final props = FigmaNodeProperties.fromMap(node);

    if (!props.visible) {
      return const SizedBox.shrink();
    }

    final type = props.type;

    Widget child;
    switch (type) {
      case 'FRAME':
      case 'GROUP':
      case 'COMPONENT':
      case 'COMPONENT_SET':
      case 'INSTANCE':
        child = FigmaFrameWidget(props: props, nodeMap: nodeMap, scale: scale);
        break;
      case 'RECTANGLE':
        child = FigmaRectangleWidget(props: props);
        break;
      case 'ELLIPSE':
        child = FigmaEllipseWidget(props: props);
        break;
      case 'TEXT':
        child = FigmaTextWidget(props: props);
        break;
      case 'VECTOR':
      case 'LINE':
      case 'STAR':
      case 'POLYGON':
      case 'BOOLEAN_OPERATION':
        child = FigmaVectorWidget(props: props);
        break;
      case 'CANVAS':
        // Canvas is a page - render its children
        child = FigmaCanvasWidget(props: props, nodeMap: nodeMap, scale: scale);
        break;
      case 'DOCUMENT':
        // Document is the root - skip rendering
        child = const SizedBox.shrink();
        break;
      default:
        // Fallback for unknown types
        child = FigmaPlaceholderWidget(props: props);
    }

    // Wrap with transform if needed
    if (props.rotation != 0) {
      child = Transform.rotate(
        angle: props.rotation * 3.14159265359 / 180,
        child: child,
      );
    }

    // Apply opacity
    if (props.opacity < 1.0) {
      child = Opacity(opacity: props.opacity, child: child);
    }

    // Debug bounds
    if (showBounds) {
      child = Stack(
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x80FF0000), width: 1), // red with 0.5 opacity
                ),
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }
}

/// Frame/Group/Component renderer
class FigmaFrameWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final double scale;

  const FigmaFrameWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Get background from fills
    final decoration = _buildDecoration();

    // Build children
    final children = _buildChildren();

    return Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: decoration,
      clipBehavior: props.raw['clipsContent'] == true ? Clip.hardEdge : Clip.none,
      child: children.isEmpty
          ? null
          : Stack(
              clipBehavior: Clip.none,
              children: children,
            ),
    );
  }

  BoxDecoration _buildDecoration() {
    Color? backgroundColor;
    Gradient? gradient;

    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final fillType = fill['type'];
      if (fillType == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          backgroundColor = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
      } else if (fillType == 'GRADIENT_LINEAR' || fillType == 'GRADIENT_RADIAL') {
        gradient = _buildGradient(fill);
      }
    }

    // Build border from strokes
    Border? border;
    if (props.strokes.isNotEmpty && props.strokeWeight > 0) {
      final stroke = props.strokes.first;
      if (stroke['visible'] != false) {
        final color = stroke['color'];
        if (color is Map) {
          border = Border.all(
            color: Color.fromRGBO(
              ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              (color['a'] as num?)?.toDouble() ?? 1.0,
            ),
            width: props.strokeWeight * scale,
          );
        }
      }
    }

    // Build shadow from effects
    List<BoxShadow>? shadows;
    for (final effect in props.effects) {
      if (effect['visible'] == false) continue;
      final effectType = effect['type'];
      if (effectType == 'DROP_SHADOW' || effectType == 'INNER_SHADOW') {
        final color = effect['color'];
        if (color is Map) {
          shadows ??= [];
          shadows.add(BoxShadow(
            color: Color.fromRGBO(
              ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              (color['a'] as num?)?.toDouble() ?? 0.25,
            ),
            blurRadius: ((effect['radius'] as num?)?.toDouble() ?? 0) * scale,
            offset: Offset(
              ((effect['offset']?['x'] as num?)?.toDouble() ?? 0) * scale,
              ((effect['offset']?['y'] as num?)?.toDouble() ?? 0) * scale,
            ),
          ));
        }
      }
    }

    return BoxDecoration(
      color: gradient == null ? backgroundColor : null,
      gradient: gradient,
      border: border,
      borderRadius: props.borderRadius,
      boxShadow: shadows,
    );
  }

  Gradient? _buildGradient(Map<String, dynamic> fill) {
    final stops = fill['gradientStops'] as List?;
    if (stops == null || stops.isEmpty) return null;

    final colors = <Color>[];
    final stopPositions = <double>[];

    for (final stop in stops) {
      final color = stop['color'];
      if (color is Map) {
        colors.add(Color.fromRGBO(
          ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          (color['a'] as num?)?.toDouble() ?? 1.0,
        ));
        stopPositions.add((stop['position'] as num?)?.toDouble() ?? 0);
      }
    }

    if (colors.length < 2) return null;

    final fillType = fill['type'];
    if (fillType == 'GRADIENT_LINEAR') {
      return LinearGradient(colors: colors, stops: stopPositions);
    } else if (fillType == 'GRADIENT_RADIAL') {
      return RadialGradient(colors: colors, stops: stopPositions);
    }
    return null;
  }

  List<Widget> _buildChildren() {
    if (nodeMap == null) return [];

    final childrenIds = props.raw['children'] as List?;
    if (childrenIds == null) return [];

    final children = <Widget>[];
    for (final childId in childrenIds) {
      final childNode = nodeMap![childId.toString()];
      if (childNode != null) {
        final childProps = FigmaNodeProperties.fromMap(childNode);
        children.add(
          Positioned(
            left: childProps.x * scale,
            top: childProps.y * scale,
            child: FigmaNodeWidget(
              node: childNode,
              nodeMap: nodeMap,
              scale: scale,
            ),
          ),
        );
      }
    }
    return children;
  }
}

/// Rectangle renderer
class FigmaRectangleWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaRectangleWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(props.width, props.height),
      painter: _RectanglePainter(props: props),
    );
  }
}

class _RectanglePainter extends CustomPainter {
  final FigmaNodeProperties props;

  _RectanglePainter({required this.props});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    RRect rrect;

    if (props.cornerRadii != null && props.cornerRadii!.length >= 4) {
      rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(props.cornerRadii![0]),
        topRight: Radius.circular(props.cornerRadii![1]),
        bottomRight: Radius.circular(props.cornerRadii![2]),
        bottomLeft: Radius.circular(props.cornerRadii![3]),
      );
    } else {
      rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(props.effectiveCornerRadius),
      );
    }

    // Draw fills
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final paint = Paint();
      final fillType = fill['type'];

      if (fillType == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawRRect(rrect, paint);
      }
    }

    // Draw strokes
    if (props.strokes.isNotEmpty && props.strokeWeight > 0) {
      final stroke = props.strokes.first;
      if (stroke['visible'] != false) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = props.strokeWeight;

        final color = stroke['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ellipse renderer
class FigmaEllipseWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaEllipseWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(props.width, props.height),
      painter: _EllipsePainter(props: props),
    );
  }
}

class _EllipsePainter extends CustomPainter {
  final FigmaNodeProperties props;

  _EllipsePainter({required this.props});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw fills
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final paint = Paint();
      final fillType = fill['type'];

      if (fillType == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawOval(rect, paint);
      }
    }

    // Draw strokes
    if (props.strokes.isNotEmpty && props.strokeWeight > 0) {
      final stroke = props.strokes.first;
      if (stroke['visible'] != false) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = props.strokeWeight;

        final color = stroke['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawOval(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Text renderer
class FigmaTextWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaTextWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    // Extract text content
    final textData = props.raw['textData'];
    String text = '';
    if (textData is Map) {
      text = textData['characters'] as String? ?? '';
    } else {
      text = props.raw['characters'] as String? ?? props.name ?? '';
    }

    // Extract text style
    final style = _buildTextStyle();

    return SizedBox(
      width: props.width,
      height: props.height,
      child: Text(
        text,
        style: style,
        overflow: TextOverflow.clip,
      ),
    );
  }

  TextStyle _buildTextStyle() {
    double fontSize = 14;
    FontWeight fontWeight = FontWeight.normal;
    Color color = Colors.black;
    String? fontFamily;
    double? letterSpacing;
    double? height;

    // Try to get font info from fontMetaData
    final fontMetaData = props.raw['fontMetaData'];
    if (fontMetaData is Map) {
      // Font metadata has keys like "0:6" with font info
      if (fontMetaData.isNotEmpty) {
        final firstMeta = fontMetaData.values.first;
        if (firstMeta is Map) {
          fontFamily = firstMeta['family'] as String?;
        }
      }
    }

    // Get font size from derivedTextData or fontSize field
    final derivedTextData = props.raw['derivedTextData'];
    if (derivedTextData is Map) {
      final baseFontSize = derivedTextData['baseFontSize'];
      if (baseFontSize is num) {
        fontSize = baseFontSize.toDouble();
      }
    }

    final rawFontSize = props.raw['fontSize'];
    if (rawFontSize is num) {
      fontSize = rawFontSize.toDouble();
    }

    // Get font weight
    final rawFontWeight = props.raw['fontWeight'];
    if (rawFontWeight is num) {
      fontWeight = _getFontWeight(rawFontWeight.toInt());
    }

    // Get color from fills
    if (props.fills.isNotEmpty) {
      final fill = props.fills.first;
      if (fill['visible'] != false && fill['type'] == 'SOLID') {
        final fillColor = fill['color'];
        if (fillColor is Map) {
          color = Color.fromRGBO(
            ((fillColor['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((fillColor['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((fillColor['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (fillColor['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
      }
    }

    // Get letter spacing
    final rawLetterSpacing = props.raw['letterSpacing'];
    if (rawLetterSpacing is num) {
      letterSpacing = rawLetterSpacing.toDouble();
    }

    // Get line height
    final rawLineHeight = props.raw['lineHeight'];
    if (rawLineHeight is num && fontSize > 0) {
      height = rawLineHeight.toDouble() / fontSize;
    }

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  FontWeight _getFontWeight(int weight) {
    if (weight <= 100) return FontWeight.w100;
    if (weight <= 200) return FontWeight.w200;
    if (weight <= 300) return FontWeight.w300;
    if (weight <= 400) return FontWeight.w400;
    if (weight <= 500) return FontWeight.w500;
    if (weight <= 600) return FontWeight.w600;
    if (weight <= 700) return FontWeight.w700;
    if (weight <= 800) return FontWeight.w800;
    return FontWeight.w900;
  }
}

/// Vector/path renderer
class FigmaVectorWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaVectorWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(props.width, props.height),
      painter: _VectorPainter(props: props),
    );
  }
}

class _VectorPainter extends CustomPainter {
  final FigmaNodeProperties props;

  _VectorPainter({required this.props});

  @override
  void paint(Canvas canvas, Size size) {
    // Get vector paths from fillGeometry
    final fillGeometry = props.raw['fillGeometry'];
    final strokeGeometry = props.raw['strokeGeometry'];

    // Draw fills
    if (fillGeometry is List) {
      for (final geom in fillGeometry) {
        if (geom is Map) {
          final pathData = geom['path'] as String?;
          if (pathData != null) {
            final path = _parseSvgPath(pathData, size);

            for (final fill in props.fills) {
              if (fill['visible'] == false) continue;

              final paint = Paint();
              if (fill['type'] == 'SOLID') {
                final color = fill['color'];
                if (color is Map) {
                  paint.color = Color.fromRGBO(
                    ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                    ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                    ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                    (color['a'] as num?)?.toDouble() ?? 1.0,
                  );
                  canvas.drawPath(path, paint);
                }
              }
            }
          }
        }
      }
    }

    // Draw strokes
    if (strokeGeometry is List && props.strokeWeight > 0) {
      for (final geom in strokeGeometry) {
        if (geom is Map) {
          final pathData = geom['path'] as String?;
          if (pathData != null) {
            final path = _parseSvgPath(pathData, size);

            for (final stroke in props.strokes) {
              if (stroke['visible'] == false) continue;

              final paint = Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = props.strokeWeight;

              final color = stroke['color'];
              if (color is Map) {
                paint.color = Color.fromRGBO(
                  ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                  ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                  ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                  (color['a'] as num?)?.toDouble() ?? 1.0,
                );
                canvas.drawPath(path, paint);
              }
            }
          }
        }
      }
    }

    // Fallback: draw simple shape if no geometry
    if (fillGeometry == null && strokeGeometry == null) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);

      for (final fill in props.fills) {
        if (fill['visible'] == false) continue;

        final paint = Paint();
        if (fill['type'] == 'SOLID') {
          final color = fill['color'];
          if (color is Map) {
            paint.color = Color.fromRGBO(
              ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              (color['a'] as num?)?.toDouble() ?? 1.0,
            );
            canvas.drawRect(rect, paint);
          }
        }
      }
    }
  }

  ui.Path _parseSvgPath(String pathData, Size size) {
    final path = ui.Path();
    // Basic SVG path parser - handles M, L, C, Z commands
    // This is a simplified implementation
    final commands = pathData.split(RegExp(r'(?=[MLCQZmlcqz])'));

    double x = 0, y = 0;

    for (var cmd in commands) {
      cmd = cmd.trim();
      if (cmd.isEmpty) continue;

      final type = cmd[0];
      final args = cmd.substring(1).trim().split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).map((s) => double.tryParse(s) ?? 0).toList();

      switch (type) {
        case 'M':
          if (args.length >= 2) {
            x = args[0];
            y = args[1];
            path.moveTo(x, y);
          }
          break;
        case 'm':
          if (args.length >= 2) {
            x += args[0];
            y += args[1];
            path.moveTo(x, y);
          }
          break;
        case 'L':
          if (args.length >= 2) {
            x = args[0];
            y = args[1];
            path.lineTo(x, y);
          }
          break;
        case 'l':
          if (args.length >= 2) {
            x += args[0];
            y += args[1];
            path.lineTo(x, y);
          }
          break;
        case 'C':
          if (args.length >= 6) {
            path.cubicTo(args[0], args[1], args[2], args[3], args[4], args[5]);
            x = args[4];
            y = args[5];
          }
          break;
        case 'c':
          if (args.length >= 6) {
            path.cubicTo(x + args[0], y + args[1], x + args[2], y + args[3], x + args[4], y + args[5]);
            x += args[4];
            y += args[5];
          }
          break;
        case 'Q':
          if (args.length >= 4) {
            path.quadraticBezierTo(args[0], args[1], args[2], args[3]);
            x = args[2];
            y = args[3];
          }
          break;
        case 'q':
          if (args.length >= 4) {
            path.quadraticBezierTo(x + args[0], y + args[1], x + args[2], y + args[3]);
            x += args[2];
            y += args[3];
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Canvas (page) renderer
class FigmaCanvasWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final double scale;

  const FigmaCanvasWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Get background color from canvas
    Color? backgroundColor;
    final bgColor = props.raw['backgroundColor'];
    if (bgColor is Map) {
      backgroundColor = Color.fromRGBO(
        ((bgColor['r'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        ((bgColor['g'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        ((bgColor['b'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        (bgColor['a'] as num?)?.toDouble() ?? 1.0,
      );
    }

    final children = _buildChildren();

    return Container(
      color: backgroundColor ?? Colors.white,
      child: children.isEmpty
          ? null
          : Stack(
              clipBehavior: Clip.none,
              children: children,
            ),
    );
  }

  List<Widget> _buildChildren() {
    if (nodeMap == null) return [];

    final childrenIds = props.raw['children'] as List?;
    if (childrenIds == null) return [];

    final children = <Widget>[];
    for (final childId in childrenIds) {
      final childNode = nodeMap![childId.toString()];
      if (childNode != null) {
        final childProps = FigmaNodeProperties.fromMap(childNode);
        children.add(
          Positioned(
            left: childProps.x * scale,
            top: childProps.y * scale,
            child: FigmaNodeWidget(
              node: childNode,
              nodeMap: nodeMap,
              scale: scale,
            ),
          ),
        );
      }
    }
    return children;
  }
}

/// Placeholder for unknown node types
class FigmaPlaceholderWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaPlaceholderWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: props.width,
      height: props.height,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x80808080)), // grey with 0.5 opacity
        color: const Color(0x1A808080), // grey with 0.1 opacity
      ),
      child: Center(
        child: Text(
          props.type,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
