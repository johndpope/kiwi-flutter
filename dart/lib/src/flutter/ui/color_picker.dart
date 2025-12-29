/// Figma-style color picker widget
///
/// Supports:
/// - HSB/RGB/HEX input modes
/// - Color history
/// - Eyedropper tool
/// - Opacity slider
/// - Document colors

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Color picker result
class ColorPickerResult {
  final Color color;
  final double opacity;

  const ColorPickerResult({
    required this.color,
    this.opacity = 1.0,
  });

  Color get colorWithOpacity => color.withValues(alpha: opacity);
}

/// Color picker widget matching Figma's design
class FigmaColorPicker extends StatefulWidget {
  /// Initial color
  final Color initialColor;

  /// Initial opacity (0-1)
  final double initialOpacity;

  /// Callback when color changes
  final ValueChanged<ColorPickerResult>? onColorChanged;

  /// Callback when picker is closed
  final VoidCallback? onClose;

  /// Recent/document colors to show
  final List<Color> recentColors;

  /// Whether to show opacity slider
  final bool showOpacity;

  const FigmaColorPicker({
    super.key,
    this.initialColor = Colors.blue,
    this.initialOpacity = 1.0,
    this.onColorChanged,
    this.onClose,
    this.recentColors = const [],
    this.showOpacity = true,
  });

  @override
  State<FigmaColorPicker> createState() => _FigmaColorPickerState();
}

class _FigmaColorPickerState extends State<FigmaColorPicker> {
  late HSVColor _hsvColor;
  late double _opacity;
  int _inputMode = 0; // 0=HEX, 1=RGB, 2=HSB

  final _hexController = TextEditingController();
  final _rController = TextEditingController();
  final _gController = TextEditingController();
  final _bController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _opacity = widget.initialOpacity;
    _updateTextControllers();
  }

  @override
  void dispose() {
    _hexController.dispose();
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    super.dispose();
  }

  void _updateTextControllers() {
    final color = _hsvColor.toColor();
    _hexController.text = _colorToHex(color);
    _rController.text = color.red.toString();
    _gController.text = color.green.toString();
    _bController.text = color.blue.toString();
  }

  String _colorToHex(Color color) {
    return '${color.red.toRadixString(16).padLeft(2, '0')}'
        '${color.green.toRadixString(16).padLeft(2, '0')}'
        '${color.blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  void _onColorChanged() {
    widget.onColorChanged?.call(ColorPickerResult(
      color: _hsvColor.toColor(),
      opacity: _opacity,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Saturation/Brightness picker
          _buildSaturationBrightnessPicker(),

          // Hue slider
          _buildHueSlider(),

          // Opacity slider
          if (widget.showOpacity) _buildOpacitySlider(),

          // Input fields
          _buildInputFields(),

          // Recent colors
          if (widget.recentColors.isNotEmpty) _buildRecentColors(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSaturationBrightnessPicker() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onPanStart: _onSatBrightPanStart,
          onPanUpdate: _onSatBrightPanUpdate,
          child: CustomPaint(
            painter: _SaturationBrightnessPainter(
              hue: _hsvColor.hue,
              saturation: _hsvColor.saturation,
              value: _hsvColor.value,
            ),
          ),
        ),
      ),
    );
  }

  void _onSatBrightPanStart(DragStartDetails details) {
    _updateSatBright(details.localPosition);
  }

  void _onSatBrightPanUpdate(DragUpdateDetails details) {
    _updateSatBright(details.localPosition);
  }

  void _updateSatBright(Offset position) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size.width - 24; // Account for padding

    final saturation = (position.dx / size).clamp(0.0, 1.0);
    final value = 1.0 - (position.dy / size).clamp(0.0, 1.0);

    setState(() {
      _hsvColor = HSVColor.fromAHSV(1.0, _hsvColor.hue, saturation, value);
      _updateTextControllers();
    });
    _onColorChanged();
  }

  Widget _buildHueSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 16,
        child: GestureDetector(
          onPanStart: (d) => _updateHue(d.localPosition),
          onPanUpdate: (d) => _updateHue(d.localPosition),
          child: CustomPaint(
            painter: _HueSliderPainter(hue: _hsvColor.hue),
            size: const Size(double.infinity, 16),
          ),
        ),
      ),
    );
  }

  void _updateHue(Offset position) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final width = box.size.width - 24;
    final hue = ((position.dx / width) * 360).clamp(0.0, 360.0);

    setState(() {
      _hsvColor = HSVColor.fromAHSV(1.0, hue, _hsvColor.saturation, _hsvColor.value);
      _updateTextControllers();
    });
    _onColorChanged();
  }

  Widget _buildOpacitySlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          const Text('Opacity', style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 16,
              child: GestureDetector(
                onPanStart: (d) => _updateOpacity(d.localPosition),
                onPanUpdate: (d) => _updateOpacity(d.localPosition),
                child: CustomPaint(
                  painter: _OpacitySliderPainter(
                    color: _hsvColor.toColor(),
                    opacity: _opacity,
                  ),
                  size: const Size(double.infinity, 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${(_opacity * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _updateOpacity(Offset position) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final width = box.size.width - 100; // Account for label and value

    setState(() {
      _opacity = (position.dx / width).clamp(0.0, 1.0);
    });
    _onColorChanged();
  }

  Widget _buildInputFields() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Mode selector
          Row(
            children: [
              _buildModeButton('HEX', 0),
              _buildModeButton('RGB', 1),
              _buildModeButton('HSB', 2),
            ],
          ),
          const SizedBox(height: 8),

          // Input fields based on mode
          if (_inputMode == 0) _buildHexInput(),
          if (_inputMode == 1) _buildRgbInput(),
          if (_inputMode == 2) _buildHsbInput(),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, int mode) {
    final isSelected = _inputMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _inputMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF383838) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF7A7A7A),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHexInput() {
    return Row(
      children: [
        const Text('#', style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 12)),
        const SizedBox(width: 4),
        Expanded(
          child: _buildTextField(
            controller: _hexController,
            onSubmitted: (value) {
              final color = _hexToColor(value);
              if (color != null) {
                setState(() {
                  _hsvColor = HSVColor.fromColor(color);
                  _updateTextControllers();
                });
                _onColorChanged();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRgbInput() {
    return Row(
      children: [
        Expanded(child: _buildLabeledField('R', _rController, 255)),
        const SizedBox(width: 8),
        Expanded(child: _buildLabeledField('G', _gController, 255)),
        const SizedBox(width: 8),
        Expanded(child: _buildLabeledField('B', _bController, 255)),
      ],
    );
  }

  Widget _buildHsbInput() {
    return Row(
      children: [
        Expanded(
          child: _buildLabeledFieldDouble('H', _hsvColor.hue, 360, (v) {
            setState(() {
              _hsvColor = HSVColor.fromAHSV(1.0, v, _hsvColor.saturation, _hsvColor.value);
              _updateTextControllers();
            });
            _onColorChanged();
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildLabeledFieldDouble('S', _hsvColor.saturation * 100, 100, (v) {
            setState(() {
              _hsvColor = HSVColor.fromAHSV(1.0, _hsvColor.hue, v / 100, _hsvColor.value);
              _updateTextControllers();
            });
            _onColorChanged();
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildLabeledFieldDouble('B', _hsvColor.value * 100, 100, (v) {
            setState(() {
              _hsvColor = HSVColor.fromAHSV(1.0, _hsvColor.hue, _hsvColor.saturation, v / 100);
              _updateTextControllers();
            });
            _onColorChanged();
          }),
        ),
      ],
    );
  }

  Widget _buildLabeledField(String label, TextEditingController controller, int max) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF7A7A7A), fontSize: 10)),
        const SizedBox(height: 2),
        _buildTextField(
          controller: controller,
          onSubmitted: (value) {
            final intValue = int.tryParse(value)?.clamp(0, max);
            if (intValue != null) {
              final r = label == 'R' ? intValue : int.parse(_rController.text);
              final g = label == 'G' ? intValue : int.parse(_gController.text);
              final b = label == 'B' ? intValue : int.parse(_bController.text);
              setState(() {
                _hsvColor = HSVColor.fromColor(Color.fromRGBO(r, g, b, 1.0));
                _updateTextControllers();
              });
              _onColorChanged();
            }
          },
        ),
      ],
    );
  }

  Widget _buildLabeledFieldDouble(String label, double value, double max, ValueChanged<double> onChanged) {
    final controller = TextEditingController(text: value.round().toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF7A7A7A), fontSize: 10)),
        const SizedBox(height: 2),
        _buildTextField(
          controller: controller,
          onSubmitted: (text) {
            final doubleValue = double.tryParse(text)?.clamp(0.0, max);
            if (doubleValue != null) {
              onChanged(doubleValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required ValueChanged<String> onSubmitted,
  }) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF444444)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          isDense: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
        ],
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _buildRecentColors() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document colors',
            style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 10),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: widget.recentColors.take(10).map((color) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _hsvColor = HSVColor.fromColor(color);
                    _updateTextControllers();
                  });
                  _onColorChanged();
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF444444)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Painter for saturation/brightness picker
class _SaturationBrightnessPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _SaturationBrightnessPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Draw base color
    final baseColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // White to color gradient (horizontal)
    final satGradient = LinearGradient(
      colors: [Colors.white, baseColor],
    );
    canvas.drawRect(rect, Paint()..shader = satGradient.createShader(rect));

    // Transparent to black gradient (vertical)
    final valGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    );
    canvas.drawRect(rect, Paint()..shader = valGradient.createShader(rect));

    // Draw selector
    final selectorX = saturation * size.width;
    final selectorY = (1 - value) * size.height;
    final selectorCenter = Offset(selectorX, selectorY);

    canvas.drawCircle(
      selectorCenter,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      selectorCenter,
      6,
      Paint()..color = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor(),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationBrightnessPainter oldDelegate) {
    return hue != oldDelegate.hue ||
        saturation != oldDelegate.saturation ||
        value != oldDelegate.value;
  }
}

/// Painter for hue slider
class _HueSliderPainter extends CustomPainter {
  final double hue;

  _HueSliderPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );

    // Draw hue gradient
    final gradient = LinearGradient(
      colors: List.generate(7, (i) {
        return HSVColor.fromAHSV(1.0, i * 60.0, 1.0, 1.0).toColor();
      }),
    );
    canvas.drawRRect(rect, Paint()..shader = gradient.createShader(rect.outerRect));

    // Draw selector
    final selectorX = (hue / 360) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(selectorX, size.height / 2), width: 4, height: size.height + 4),
        const Radius.circular(2),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _HueSliderPainter oldDelegate) {
    return hue != oldDelegate.hue;
  }
}

/// Painter for opacity slider
class _OpacitySliderPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _OpacitySliderPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );

    // Draw checkerboard background
    _drawCheckerboard(canvas, rect.outerRect);

    // Draw opacity gradient
    final gradient = LinearGradient(
      colors: [color.withValues(alpha: 0.0), color],
    );
    canvas.drawRRect(rect, Paint()..shader = gradient.createShader(rect.outerRect));

    // Draw selector
    final selectorX = opacity * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(selectorX, size.height / 2), width: 4, height: size.height + 4),
        const Radius.circular(2),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawCheckerboard(Canvas canvas, Rect rect) {
    const checkSize = 4.0;
    final paint1 = Paint()..color = Colors.white;
    final paint2 = Paint()..color = const Color(0xFFCCCCCC);

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));

    for (var y = 0.0; y < rect.height; y += checkSize) {
      for (var x = 0.0; x < rect.width; x += checkSize) {
        final isEven = ((x ~/ checkSize) + (y ~/ checkSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(rect.left + x, rect.top + y, checkSize, checkSize),
          isEven ? paint1 : paint2,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OpacitySliderPainter oldDelegate) {
    return color != oldDelegate.color || opacity != oldDelegate.opacity;
  }
}

/// Simple color swatch for displaying colors
class ColorSwatch extends StatelessWidget {
  final Color color;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  const ColorSwatch({
    super.key,
    required this.color,
    this.size = 24,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFF0D99FF) : const Color(0xFF444444),
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
