/// Text editor for inline text editing in the Figma canvas
///
/// Supports:
/// - Double-click to enter edit mode
/// - Rich text editing with multiple styles
/// - Character-level styling
/// - Text alignment and spacing
/// - ESC or click outside to exit edit mode

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text editing state
enum TextEditState {
  /// Not editing - text is display only
  viewing,

  /// Editing the text content
  editing,

  /// Selecting text (click and drag)
  selecting,
}

/// Text style segment
class TextStyleSegment {
  /// Start index in the text
  final int start;

  /// End index in the text (exclusive)
  final int end;

  /// Font family
  final String? fontFamily;

  /// Font size
  final double? fontSize;

  /// Font weight
  final FontWeight? fontWeight;

  /// Font style (normal, italic)
  final FontStyle? fontStyle;

  /// Text decoration (underline, strikethrough)
  final TextDecoration? decoration;

  /// Text color
  final Color? color;

  /// Letter spacing
  final double? letterSpacing;

  /// Line height multiplier
  final double? lineHeight;

  const TextStyleSegment({
    required this.start,
    required this.end,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.color,
    this.letterSpacing,
    this.lineHeight,
  });

  /// Create a copy with different range
  TextStyleSegment copyWithRange(int newStart, int newEnd) {
    return TextStyleSegment(
      start: newStart,
      end: newEnd,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      color: color,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
    );
  }

  /// Convert to Flutter TextStyle
  TextStyle toTextStyle() {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      color: color,
      letterSpacing: letterSpacing,
      height: lineHeight,
    );
  }
}

/// Text alignment options
enum FigmaTextAlign {
  left,
  center,
  right,
  justified,
}

/// Vertical alignment options
enum FigmaTextVerticalAlign {
  top,
  center,
  bottom,
}

/// Text auto-resize mode
enum TextAutoResize {
  /// Fixed width and height
  none,

  /// Height adjusts to content
  height,

  /// Width and height adjust to content
  widthAndHeight,

  /// Text truncates with ellipsis
  truncate,
}

/// Text node data for editing
class TextNodeData {
  /// The text content
  String text;

  /// Style segments for rich text
  List<TextStyleSegment> styleSegments;

  /// Default text style
  TextStyle defaultStyle;

  /// Text alignment
  FigmaTextAlign textAlign;

  /// Vertical alignment
  FigmaTextVerticalAlign verticalAlign;

  /// Auto-resize mode
  TextAutoResize autoResize;

  /// Paragraph spacing
  double paragraphSpacing;

  /// Text box bounds
  Rect bounds;

  TextNodeData({
    required this.text,
    this.styleSegments = const [],
    this.defaultStyle = const TextStyle(
      fontSize: 14,
      color: Colors.black,
    ),
    this.textAlign = FigmaTextAlign.left,
    this.verticalAlign = FigmaTextVerticalAlign.top,
    this.autoResize = TextAutoResize.height,
    this.paragraphSpacing = 0,
    this.bounds = Rect.zero,
  });

  /// Create from Figma node properties
  factory TextNodeData.fromNode(Map<String, dynamic> node) {
    final textData = node['textData'] as Map<String, dynamic>? ?? {};
    final characters = textData['characters'] as String? ?? node['name'] as String? ?? '';

    // Parse style overrides
    final styleOverrides = <TextStyleSegment>[];
    final glyphs = textData['glyphs'] as List?;
    if (glyphs != null) {
      // Group consecutive glyphs with same style
      int currentStart = 0;
      Map<String, dynamic>? currentStyle;

      for (int i = 0; i < glyphs.length; i++) {
        final glyph = glyphs[i] as Map<String, dynamic>?;
        if (glyph == null) continue;

        final style = glyph['styleOverride'] as Map<String, dynamic>?;
        if (style != currentStyle && currentStyle != null) {
          // End previous segment
          styleOverrides.add(_parseStyleSegment(currentStart, i, currentStyle));
          currentStart = i;
        }
        currentStyle = style;
      }

      // Add final segment
      if (currentStyle != null && currentStart < glyphs.length) {
        styleOverrides.add(_parseStyleSegment(currentStart, glyphs.length, currentStyle));
      }
    }

    // Parse default style from fontMetaData
    final fontMeta = textData['fontMetaData'] as Map<String, dynamic>? ?? {};
    final firstFont = fontMeta.isNotEmpty ? fontMeta.values.first as Map<String, dynamic>? : null;

    return TextNodeData(
      text: characters,
      styleSegments: styleOverrides,
      defaultStyle: TextStyle(
        fontFamily: firstFont?['fontFamily'] as String?,
        fontSize: (textData['fontSize'] as num?)?.toDouble() ?? 14,
        fontWeight: _parseFontWeight(firstFont?['fontWeight'] as num?),
        color: _parseColor(node['fillPaints']),
      ),
      textAlign: _parseTextAlign(textData['textAlignHorizontal'] as String?),
      verticalAlign: _parseVerticalAlign(textData['textAlignVertical'] as String?),
    );
  }

  static TextStyleSegment _parseStyleSegment(int start, int end, Map<String, dynamic> style) {
    return TextStyleSegment(
      start: start,
      end: end,
      fontSize: (style['fontSize'] as num?)?.toDouble(),
      fontWeight: _parseFontWeight(style['fontWeight'] as num?),
      fontStyle: style['italic'] == true ? FontStyle.italic : null,
      color: _parseColorFromStyle(style),
    );
  }

  static FontWeight _parseFontWeight(num? weight) {
    if (weight == null) return FontWeight.normal;
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

  static Color? _parseColor(dynamic fillPaints) {
    if (fillPaints is! List || fillPaints.isEmpty) return null;
    final firstFill = fillPaints.first as Map<String, dynamic>?;
    if (firstFill == null || firstFill['type'] != 'SOLID') return null;
    return _parseColorFromStyle(firstFill);
  }

  static Color? _parseColorFromStyle(Map<String, dynamic> style) {
    final color = style['color'] as Map<String, dynamic>?;
    if (color == null) return null;
    return Color.fromRGBO(
      ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
      ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
      ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
      (color['a'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static FigmaTextAlign _parseTextAlign(String? align) {
    switch (align) {
      case 'CENTER':
        return FigmaTextAlign.center;
      case 'RIGHT':
        return FigmaTextAlign.right;
      case 'JUSTIFIED':
        return FigmaTextAlign.justified;
      default:
        return FigmaTextAlign.left;
    }
  }

  static FigmaTextVerticalAlign _parseVerticalAlign(String? align) {
    switch (align) {
      case 'CENTER':
        return FigmaTextVerticalAlign.center;
      case 'BOTTOM':
        return FigmaTextVerticalAlign.bottom;
      default:
        return FigmaTextVerticalAlign.top;
    }
  }

  /// Get Flutter TextAlign
  TextAlign get flutterTextAlign {
    switch (textAlign) {
      case FigmaTextAlign.center:
        return TextAlign.center;
      case FigmaTextAlign.right:
        return TextAlign.right;
      case FigmaTextAlign.justified:
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }
}

/// Inline text editor widget
class InlineTextEditor extends StatefulWidget {
  /// The text node data
  final TextNodeData data;

  /// Bounds for positioning
  final Rect bounds;

  /// Zoom level of the canvas
  final double zoom;

  /// Callback when editing is complete
  final void Function(String newText, List<TextStyleSegment> newStyles)? onComplete;

  /// Callback when editing is cancelled
  final VoidCallback? onCancel;

  /// Callback when text changes
  final void Function(String text)? onTextChanged;

  const InlineTextEditor({
    super.key,
    required this.data,
    required this.bounds,
    this.zoom = 1.0,
    this.onComplete,
    this.onCancel,
    this.onTextChanged,
  });

  @override
  State<InlineTextEditor> createState() => _InlineTextEditorState();
}

class _InlineTextEditorState extends State<InlineTextEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.data.text);
    _focusNode = FocusNode();

    // Auto-focus when created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleComplete() {
    if (!_isEditing) return;
    _isEditing = false;

    widget.onComplete?.call(
      _controller.text,
      widget.data.styleSegments,
    );
  }

  void _handleCancel() {
    if (!_isEditing) return;
    _isEditing = false;

    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.bounds.left,
      top: widget.bounds.top,
      width: widget.bounds.width,
      height: widget.bounds.height,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _handleCancel();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTapDown: (_) {}, // Prevent tap from propagating
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 1),
              color: Colors.white,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: widget.data.defaultStyle.copyWith(
                fontSize: (widget.data.defaultStyle.fontSize ?? 14) * widget.zoom,
              ),
              textAlign: widget.data.flutterTextAlign,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onTextChanged,
              onSubmitted: (_) => _handleComplete(),
              onTapOutside: (_) => _handleComplete(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text editor overlay for the canvas
class TextEditorOverlay extends StatefulWidget {
  /// The node being edited
  final Map<String, dynamic> node;

  /// Node properties
  final Rect bounds;

  /// Canvas transform matrix
  final Matrix4 transform;

  /// Callback when editing is complete
  final void Function(Map<String, dynamic> updatedNode)? onComplete;

  /// Callback when editing is cancelled
  final VoidCallback? onCancel;

  const TextEditorOverlay({
    super.key,
    required this.node,
    required this.bounds,
    required this.transform,
    this.onComplete,
    this.onCancel,
  });

  @override
  State<TextEditorOverlay> createState() => _TextEditorOverlayState();
}

class _TextEditorOverlayState extends State<TextEditorOverlay> {
  late TextNodeData _textData;

  @override
  void initState() {
    super.initState();
    _textData = TextNodeData.fromNode(widget.node);
  }

  void _handleComplete(String newText, List<TextStyleSegment> newStyles) {
    // Update the node with new text
    final updatedNode = Map<String, dynamic>.from(widget.node);
    final textData = (updatedNode['textData'] as Map<String, dynamic>?) ?? {};
    textData['characters'] = newText;
    updatedNode['textData'] = textData;

    widget.onComplete?.call(updatedNode);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate screen position from canvas transform
    final scale = widget.transform.getMaxScaleOnAxis();
    final translation = widget.transform.getTranslation();

    final screenBounds = Rect.fromLTWH(
      widget.bounds.left * scale + translation.x,
      widget.bounds.top * scale + translation.y,
      widget.bounds.width * scale,
      widget.bounds.height * scale,
    );

    return InlineTextEditor(
      data: _textData,
      bounds: screenBounds,
      zoom: scale,
      onComplete: _handleComplete,
      onCancel: widget.onCancel,
    );
  }
}

/// Controller for managing text editing state
class TextEditorController extends ChangeNotifier {
  /// The node currently being edited
  Map<String, dynamic>? _editingNode;

  /// Bounds of the editing node
  Rect? _editingBounds;

  /// Whether text editing is active
  bool get isEditing => _editingNode != null;

  /// The node being edited
  Map<String, dynamic>? get editingNode => _editingNode;

  /// Bounds of the editing node
  Rect? get editingBounds => _editingBounds;

  /// Start editing a text node
  void startEditing(Map<String, dynamic> node, Rect bounds) {
    final type = node['type'] as String?;
    if (type != 'TEXT') return;

    _editingNode = node;
    _editingBounds = bounds;
    notifyListeners();
  }

  /// Stop editing
  void stopEditing() {
    if (_editingNode == null) return;

    _editingNode = null;
    _editingBounds = null;
    notifyListeners();
  }

  /// Check if a specific node is being edited
  bool isEditingNode(String nodeId) {
    return _editingNode?['_guidKey'] == nodeId;
  }
}
