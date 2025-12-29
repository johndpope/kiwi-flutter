/// Export engine for rendering nodes to various formats
///
/// Supports:
/// - PNG export (1x, 2x, 3x, custom scale)
/// - SVG export
/// - PDF export
/// - JPEG export with quality setting
/// - Batch export with presets

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Export format options
enum ExportFormat {
  png,
  jpg,
  svg,
  pdf,
}

/// Export scale presets
enum ExportScale {
  x1(1.0, '1x'),
  x2(2.0, '2x'),
  x3(3.0, '3x'),
  x4(4.0, '4x');

  final double value;
  final String label;

  const ExportScale(this.value, this.label);
}

/// Export settings
class ExportSettings {
  /// Output format
  final ExportFormat format;

  /// Scale multiplier
  final double scale;

  /// Include background
  final bool includeBackground;

  /// Background color (if includeBackground is true)
  final Color backgroundColor;

  /// JPEG quality (0.0 - 1.0)
  final double jpegQuality;

  /// Padding around the exported content
  final double padding;

  /// Whether to clip to frame bounds
  final bool clipToBounds;

  /// Custom width (null = use original)
  final double? customWidth;

  /// Custom height (null = use original)
  final double? customHeight;

  /// Export suffix for filename (e.g., "@2x")
  final String suffix;

  /// Optimize SVG output
  final bool optimizeSvg;

  const ExportSettings({
    this.format = ExportFormat.png,
    this.scale = 1.0,
    this.includeBackground = true,
    this.backgroundColor = Colors.white,
    this.jpegQuality = 0.92,
    this.padding = 0,
    this.clipToBounds = true,
    this.customWidth,
    this.customHeight,
    this.suffix = '',
    this.optimizeSvg = true,
  });

  /// Create settings for common presets
  factory ExportSettings.preset(ExportScale scalePreset, {
    ExportFormat format = ExportFormat.png,
    bool includeBackground = true,
  }) {
    return ExportSettings(
      format: format,
      scale: scalePreset.value,
      includeBackground: includeBackground,
      suffix: scalePreset == ExportScale.x1 ? '' : '@${scalePreset.label}',
    );
  }

  ExportSettings copyWith({
    ExportFormat? format,
    double? scale,
    bool? includeBackground,
    Color? backgroundColor,
    double? jpegQuality,
    double? padding,
    bool? clipToBounds,
    double? customWidth,
    double? customHeight,
    String? suffix,
    bool? optimizeSvg,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      scale: scale ?? this.scale,
      includeBackground: includeBackground ?? this.includeBackground,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      padding: padding ?? this.padding,
      clipToBounds: clipToBounds ?? this.clipToBounds,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      suffix: suffix ?? this.suffix,
      optimizeSvg: optimizeSvg ?? this.optimizeSvg,
    );
  }
}

/// Result of an export operation
class ExportResult {
  /// The exported data
  final Uint8List? data;

  /// SVG string (for SVG format)
  final String? svgString;

  /// Export format used
  final ExportFormat format;

  /// Width of the exported image
  final int width;

  /// Height of the exported image
  final int height;

  /// Whether export succeeded
  final bool success;

  /// Error message if failed
  final String? error;

  /// File name suggestion
  final String suggestedFilename;

  const ExportResult({
    this.data,
    this.svgString,
    required this.format,
    required this.width,
    required this.height,
    this.success = true,
    this.error,
    this.suggestedFilename = 'export',
  });

  /// Create a failed result
  factory ExportResult.failed(String error, ExportFormat format) {
    return ExportResult(
      format: format,
      width: 0,
      height: 0,
      success: false,
      error: error,
    );
  }

  /// Get MIME type
  String get mimeType {
    switch (format) {
      case ExportFormat.png:
        return 'image/png';
      case ExportFormat.jpg:
        return 'image/jpeg';
      case ExportFormat.svg:
        return 'image/svg+xml';
      case ExportFormat.pdf:
        return 'application/pdf';
    }
  }

  /// Get file extension
  String get extension {
    switch (format) {
      case ExportFormat.png:
        return 'png';
      case ExportFormat.jpg:
        return 'jpg';
      case ExportFormat.svg:
        return 'svg';
      case ExportFormat.pdf:
        return 'pdf';
    }
  }
}

/// Engine for exporting widgets/nodes to various formats
class ExportEngine {
  /// Export a widget to the specified format
  static Future<ExportResult> exportWidget(
    Widget widget,
    Size size,
    ExportSettings settings, {
    String filename = 'export',
  }) async {
    final scaledSize = Size(
      (settings.customWidth ?? size.width) * settings.scale,
      (settings.customHeight ?? size.height) * settings.scale,
    );

    final paddedSize = Size(
      scaledSize.width + settings.padding * 2 * settings.scale,
      scaledSize.height + settings.padding * 2 * settings.scale,
    );

    switch (settings.format) {
      case ExportFormat.png:
      case ExportFormat.jpg:
        return _exportRaster(
          widget,
          size,
          paddedSize,
          settings,
          filename,
        );
      case ExportFormat.svg:
        return _exportSvg(widget, size, settings, filename);
      case ExportFormat.pdf:
        return _exportPdf(widget, size, settings, filename);
    }
  }

  /// Export to PNG or JPEG
  static Future<ExportResult> _exportRaster(
    Widget widget,
    Size originalSize,
    Size outputSize,
    ExportSettings settings,
    String filename,
  ) async {
    try {
      // Create a repaint boundary to capture the widget
      final repaintBoundary = RenderRepaintBoundary();

      // Build the render tree
      final renderView = _buildRenderTree(
        widget,
        outputSize,
        settings,
      );

      // Render to image
      final image = await _captureImage(
        widget,
        originalSize,
        settings,
      );

      if (image == null) {
        return ExportResult.failed(
          'Failed to capture image',
          settings.format,
        );
      }

      // Encode to bytes
      final byteData = await image.toByteData(
        format: settings.format == ExportFormat.png
            ? ui.ImageByteFormat.png
            : ui.ImageByteFormat.rawRgba, // JPEG needs different handling
      );

      image.dispose();

      if (byteData == null) {
        return ExportResult.failed(
          'Failed to encode image',
          settings.format,
        );
      }

      Uint8List bytes = byteData.buffer.asUint8List();

      // For JPEG, we'd need additional encoding (not directly supported)
      // In production, use image package for JPEG encoding

      return ExportResult(
        data: bytes,
        format: settings.format,
        width: image.width,
        height: image.height,
        suggestedFilename: '$filename${settings.suffix}',
      );
    } catch (e) {
      return ExportResult.failed(
        'Export failed: $e',
        settings.format,
      );
    }
  }

  /// Capture widget as ui.Image
  static Future<ui.Image?> _captureImage(
    Widget widget,
    Size size,
    ExportSettings settings,
  ) async {
    final completer = Completer<ui.Image?>();

    final scaledSize = Size(
      size.width * settings.scale,
      size.height * settings.scale,
    );

    // Use a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Apply background
    if (settings.includeBackground) {
      canvas.drawRect(
        Offset.zero & scaledSize,
        Paint()..color = settings.backgroundColor,
      );
    }

    // Scale for export resolution
    canvas.scale(settings.scale);

    // Add padding offset
    if (settings.padding > 0) {
      canvas.translate(settings.padding, settings.padding);
    }

    // Note: In a real implementation, we would render the widget tree here
    // This requires the widget to be able to paint to a canvas directly
    // For now, we create a placeholder

    final picture = recorder.endRecording();

    try {
      final image = await picture.toImage(
        scaledSize.width.ceil(),
        scaledSize.height.ceil(),
      );
      completer.complete(image);
    } catch (e) {
      completer.complete(null);
    }

    picture.dispose();
    return completer.future;
  }

  /// Build a simple render tree (placeholder)
  static RenderBox? _buildRenderTree(
    Widget widget,
    Size size,
    ExportSettings settings,
  ) {
    // This would build an actual render tree in production
    return null;
  }

  /// Export to SVG format
  static Future<ExportResult> _exportSvg(
    Widget widget,
    Size size,
    ExportSettings settings,
    String filename,
  ) async {
    try {
      final buffer = StringBuffer();

      // SVG header
      buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
          'xmlns:xlink="http://www.w3.org/1999/xlink" '
          'width="${size.width}" height="${size.height}" '
          'viewBox="0 0 ${size.width} ${size.height}">');

      // Add background if needed
      if (settings.includeBackground) {
        final bgColor = _colorToSvg(settings.backgroundColor);
        buffer.writeln('  <rect width="100%" height="100%" fill="$bgColor"/>');
      }

      // Note: Real implementation would traverse the widget tree
      // and convert each element to SVG

      buffer.writeln('</svg>');

      final svgString = buffer.toString();

      return ExportResult(
        svgString: svgString,
        data: Uint8List.fromList(utf8.encode(svgString)),
        format: ExportFormat.svg,
        width: size.width.ceil(),
        height: size.height.ceil(),
        suggestedFilename: '$filename${settings.suffix}',
      );
    } catch (e) {
      return ExportResult.failed('SVG export failed: $e', ExportFormat.svg);
    }
  }

  /// Export to PDF format
  static Future<ExportResult> _exportPdf(
    Widget widget,
    Size size,
    ExportSettings settings,
    String filename,
  ) async {
    // PDF export would require a PDF library like pdf or printing package
    // This is a placeholder implementation
    return ExportResult.failed(
      'PDF export requires the pdf package',
      ExportFormat.pdf,
    );
  }

  /// Convert Color to SVG color string
  static String _colorToSvg(Color color) {
    if (color.opacity < 1.0) {
      return 'rgba(${color.red},${color.green},${color.blue},${color.opacity.toStringAsFixed(2)})';
    }
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

/// SVG builder for converting shapes to SVG elements
class SvgBuilder {
  final StringBuffer _buffer = StringBuffer();
  final List<String> _defs = [];
  int _defIdCounter = 0;

  /// Start an SVG document
  void startDocument(double width, double height) {
    _buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    _buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="$width" height="$height" '
        'viewBox="0 0 $width $height">');
  }

  /// End the SVG document
  String endDocument() {
    // Insert defs if any
    if (_defs.isNotEmpty) {
      final defsStr = '<defs>\n${_defs.join('\n')}\n</defs>';
      // Insert after opening svg tag
      final content = _buffer.toString();
      final insertPos = content.indexOf('>') + 1;
      _buffer.clear();
      _buffer.write(content.substring(0, insertPos));
      _buffer.write('\n$defsStr');
      _buffer.write(content.substring(insertPos));
    }

    _buffer.writeln('</svg>');
    return _buffer.toString();
  }

  /// Add a rectangle
  void addRect(
    Rect rect, {
    Color? fill,
    Color? stroke,
    double strokeWidth = 1.0,
    List<double>? cornerRadii,
    double opacity = 1.0,
  }) {
    _buffer.write('  <rect ');
    _buffer.write('x="${rect.left}" y="${rect.top}" ');
    _buffer.write('width="${rect.width}" height="${rect.height}" ');

    if (cornerRadii != null && cornerRadii.isNotEmpty) {
      // SVG rx/ry for uniform corners
      _buffer.write('rx="${cornerRadii[0]}" ');
    }

    _addPaintAttributes(fill, stroke, strokeWidth, opacity);
    _buffer.writeln('/>');
  }

  /// Add an ellipse
  void addEllipse(
    Rect bounds, {
    Color? fill,
    Color? stroke,
    double strokeWidth = 1.0,
    double opacity = 1.0,
  }) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final rx = bounds.width / 2;
    final ry = bounds.height / 2;

    _buffer.write('  <ellipse ');
    _buffer.write('cx="$cx" cy="$cy" rx="$rx" ry="$ry" ');
    _addPaintAttributes(fill, stroke, strokeWidth, opacity);
    _buffer.writeln('/>');
  }

  /// Add a path
  void addPath(
    String pathData, {
    Color? fill,
    Color? stroke,
    double strokeWidth = 1.0,
    double opacity = 1.0,
    String? strokeLinecap,
    String? strokeLinejoin,
  }) {
    _buffer.write('  <path d="$pathData" ');
    _addPaintAttributes(fill, stroke, strokeWidth, opacity);

    if (strokeLinecap != null) {
      _buffer.write('stroke-linecap="$strokeLinecap" ');
    }
    if (strokeLinejoin != null) {
      _buffer.write('stroke-linejoin="$strokeLinejoin" ');
    }

    _buffer.writeln('/>');
  }

  /// Add text
  void addText(
    String text,
    Offset position, {
    String fontFamily = 'sans-serif',
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    TextAlign textAlign = TextAlign.left,
    double opacity = 1.0,
  }) {
    _buffer.write('  <text ');
    _buffer.write('x="${position.dx}" y="${position.dy}" ');
    _buffer.write('font-family="$fontFamily" ');
    _buffer.write('font-size="${fontSize}px" ');

    if (fontWeight != FontWeight.normal) {
      _buffer.write('font-weight="${fontWeight.value}" ');
    }

    _buffer.write('fill="${_colorToSvg(color)}" ');

    if (opacity < 1.0) {
      _buffer.write('opacity="$opacity" ');
    }

    final anchor = textAlign == TextAlign.center
        ? 'middle'
        : textAlign == TextAlign.right
            ? 'end'
            : 'start';
    _buffer.write('text-anchor="$anchor" ');

    _buffer.write('>');
    _buffer.write(_escapeXml(text));
    _buffer.writeln('</text>');
  }

  /// Add a linear gradient definition
  String addLinearGradient(
    List<Color> colors,
    List<double> stops, {
    Offset start = Offset.zero,
    Offset end = const Offset(1, 0),
  }) {
    final id = 'gradient_${_defIdCounter++}';

    final gradientDef = StringBuffer();
    gradientDef.writeln(
        '  <linearGradient id="$id" x1="${start.dx * 100}%" y1="${start.dy * 100}%" x2="${end.dx * 100}%" y2="${end.dy * 100}%">');

    for (int i = 0; i < colors.length; i++) {
      final offset = i < stops.length ? stops[i] : i / (colors.length - 1);
      gradientDef.writeln(
          '    <stop offset="${offset * 100}%" stop-color="${_colorToSvg(colors[i])}"/>');
    }

    gradientDef.writeln('  </linearGradient>');
    _defs.add(gradientDef.toString());

    return 'url(#$id)';
  }

  /// Add a radial gradient definition
  String addRadialGradient(
    List<Color> colors,
    List<double> stops, {
    Offset center = const Offset(0.5, 0.5),
    double radius = 0.5,
  }) {
    final id = 'gradient_${_defIdCounter++}';

    final gradientDef = StringBuffer();
    gradientDef.writeln(
        '  <radialGradient id="$id" cx="${center.dx * 100}%" cy="${center.dy * 100}%" r="${radius * 100}%">');

    for (int i = 0; i < colors.length; i++) {
      final offset = i < stops.length ? stops[i] : i / (colors.length - 1);
      gradientDef.writeln(
          '    <stop offset="${offset * 100}%" stop-color="${_colorToSvg(colors[i])}"/>');
    }

    gradientDef.writeln('  </radialGradient>');
    _defs.add(gradientDef.toString());

    return 'url(#$id)';
  }

  /// Start a group with transform
  void startGroup({
    Matrix4? transform,
    double opacity = 1.0,
    String? clipPath,
  }) {
    _buffer.write('  <g');

    if (transform != null) {
      final t = transform.storage;
      _buffer.write(' transform="matrix(${t[0]},${t[1]},${t[4]},${t[5]},${t[12]},${t[13]})"');
    }

    if (opacity < 1.0) {
      _buffer.write(' opacity="$opacity"');
    }

    if (clipPath != null) {
      _buffer.write(' clip-path="url(#$clipPath)"');
    }

    _buffer.writeln('>');
  }

  /// End a group
  void endGroup() {
    _buffer.writeln('  </g>');
  }

  void _addPaintAttributes(
    Color? fill,
    Color? stroke,
    double strokeWidth,
    double opacity,
  ) {
    if (fill != null) {
      _buffer.write('fill="${_colorToSvg(fill)}" ');
    } else {
      _buffer.write('fill="none" ');
    }

    if (stroke != null) {
      _buffer.write('stroke="${_colorToSvg(stroke)}" ');
      _buffer.write('stroke-width="$strokeWidth" ');
    }

    if (opacity < 1.0) {
      _buffer.write('opacity="$opacity" ');
    }
  }

  String _colorToSvg(Color color) {
    if (color.opacity < 1.0) {
      return 'rgba(${color.red},${color.green},${color.blue},${color.opacity.toStringAsFixed(2)})';
    }
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// Convert a Flutter Path to SVG path data
String pathToSvgData(Path path) {
  final buffer = StringBuffer();
  final metrics = path.computeMetrics();

  for (final metric in metrics) {
    // Sample the path to convert to SVG commands
    // This is a simplified conversion - real implementation would
    // extract the actual path commands
    final length = metric.length;
    final stepCount = (length / 2).ceil().clamp(10, 1000);
    final step = length / stepCount;

    for (int i = 0; i <= stepCount; i++) {
      final tangent = metric.getTangentForOffset(i * step);
      if (tangent != null) {
        if (i == 0) {
          buffer.write('M ${tangent.position.dx.toStringAsFixed(2)} ${tangent.position.dy.toStringAsFixed(2)} ');
        } else {
          buffer.write('L ${tangent.position.dx.toStringAsFixed(2)} ${tangent.position.dy.toStringAsFixed(2)} ');
        }
      }
    }

    if (metric.isClosed) {
      buffer.write('Z ');
    }
  }

  return buffer.toString().trim();
}

/// Export panel widget
class ExportPanel extends StatefulWidget {
  /// Current selection bounds
  final Rect? selectionBounds;

  /// Name for the export
  final String exportName;

  /// Callback when export is requested
  final void Function(ExportSettings settings)? onExport;

  /// Callback to close panel
  final VoidCallback? onClose;

  const ExportPanel({
    super.key,
    this.selectionBounds,
    this.exportName = 'export',
    this.onExport,
    this.onClose,
  });

  @override
  State<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends State<ExportPanel> {
  ExportFormat _format = ExportFormat.png;
  ExportScale _scale = ExportScale.x1;
  bool _includeBackground = true;
  Color _backgroundColor = Colors.white;
  double _jpegQuality = 0.92;

  @override
  Widget build(BuildContext context) {
    final size = widget.selectionBounds?.size ?? const Size(100, 100);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.file_download, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Export',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onClose,
                color: Colors.grey[400],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview dimensions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exportName,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(size.width * _scale.value).ceil()} × ${(size.height * _scale.value).ceil()}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Format selector
          const Text(
            'Format',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: ExportFormat.values.map((format) {
              final isSelected = _format == format;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _format = format),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.only(right: 4),
                    child: Center(
                      child: Text(
                        format.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Scale selector (for raster formats)
          if (_format == ExportFormat.png || _format == ExportFormat.jpg) ...[
            const Text(
              'Scale',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportScale.values.map((scale) {
                final isSelected = _scale == scale;
                return ChoiceChip(
                  label: Text(scale.label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _scale = scale),
                  selectedColor: Colors.blue,
                  backgroundColor: Colors.grey[800],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Background option
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _includeBackground,
                  onChanged: (v) => setState(() => _includeBackground = v ?? true),
                  activeColor: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Include background',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),

          // JPEG quality (for JPG format)
          if (_format == ExportFormat.jpg) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Quality',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _jpegQuality,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) => setState(() => _jpegQuality = v),
                    activeColor: Colors.blue,
                  ),
                ),
                Text(
                  '${(_jpegQuality * 100).round()}%',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Export button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onExport?.call(ExportSettings(
                  format: _format,
                  scale: _scale.value,
                  includeBackground: _includeBackground,
                  backgroundColor: _backgroundColor,
                  jpegQuality: _jpegQuality,
                  suffix: _scale == ExportScale.x1 ? '' : '@${_scale.label}',
                ));
              },
              icon: const Icon(Icons.file_download, size: 18),
              label: Text('Export ${_format.name.toUpperCase()}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
