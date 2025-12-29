/// Figma-style gradient editor widget
///
/// Supports:
/// - Linear, radial, angular, diamond gradients
/// - Color stop editing
/// - Angle/position adjustment
/// - Gradient preview

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'color_picker.dart';

/// Gradient types matching Figma
enum GradientType {
  linear,
  radial,
  angular,
  diamond,
}

/// A color stop in a gradient
class GradientStop {
  /// Position along gradient (0-1)
  double position;

  /// Color at this stop
  Color color;

  /// Opacity (0-1)
  double opacity;

  GradientStop({
    required this.position,
    required this.color,
    this.opacity = 1.0,
  });

  GradientStop copyWith({
    double? position,
    Color? color,
    double? opacity,
  }) {
    return GradientStop(
      position: position ?? this.position,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
    );
  }

  Color get colorWithOpacity => color.withValues(alpha: opacity);
}

/// Gradient data
class GradientData {
  /// Type of gradient
  GradientType type;

  /// Color stops
  List<GradientStop> stops;

  /// Angle in degrees (for linear)
  double angle;

  /// Center position for radial/angular (0-1, 0-1)
  Offset center;

  /// Scale for radial gradient
  double scale;

  GradientData({
    this.type = GradientType.linear,
    List<GradientStop>? stops,
    this.angle = 0,
    this.center = const Offset(0.5, 0.5),
    this.scale = 1.0,
  }) : stops = stops ??
            [
              GradientStop(position: 0, color: Colors.white),
              GradientStop(position: 1, color: Colors.black),
            ];

  /// Convert to Flutter Gradient
  Gradient toFlutterGradient() {
    final colors = stops.map((s) => s.colorWithOpacity).toList();
    final positions = stops.map((s) => s.position).toList();

    switch (type) {
      case GradientType.linear:
        final radians = angle * math.pi / 180;
        final dx = math.cos(radians);
        final dy = math.sin(radians);
        return LinearGradient(
          begin: Alignment(-dx, -dy),
          end: Alignment(dx, dy),
          colors: colors,
          stops: positions,
        );

      case GradientType.radial:
        return RadialGradient(
          center: Alignment(center.dx * 2 - 1, center.dy * 2 - 1),
          radius: scale,
          colors: colors,
          stops: positions,
        );

      case GradientType.angular:
        return SweepGradient(
          center: Alignment(center.dx * 2 - 1, center.dy * 2 - 1),
          startAngle: angle * math.pi / 180,
          colors: colors,
          stops: positions,
        );

      case GradientType.diamond:
        // Diamond gradient not directly supported, approximate with radial
        return RadialGradient(
          center: Alignment(center.dx * 2 - 1, center.dy * 2 - 1),
          radius: scale,
          colors: colors,
          stops: positions,
        );
    }
  }

  GradientData copyWith({
    GradientType? type,
    List<GradientStop>? stops,
    double? angle,
    Offset? center,
    double? scale,
  }) {
    return GradientData(
      type: type ?? this.type,
      stops: stops ?? this.stops.map((s) => s.copyWith()).toList(),
      angle: angle ?? this.angle,
      center: center ?? this.center,
      scale: scale ?? this.scale,
    );
  }
}

/// Gradient editor widget
class GradientEditor extends StatefulWidget {
  /// Initial gradient data
  final GradientData initialGradient;

  /// Callback when gradient changes
  final ValueChanged<GradientData>? onGradientChanged;

  /// Size of the preview
  final Size previewSize;

  const GradientEditor({
    super.key,
    required this.initialGradient,
    this.onGradientChanged,
    this.previewSize = const Size(200, 120),
  });

  @override
  State<GradientEditor> createState() => _GradientEditorState();
}

class _GradientEditorState extends State<GradientEditor> {
  late GradientData _gradient;
  int? _selectedStopIndex;
  bool _showColorPicker = false;

  @override
  void initState() {
    super.initState();
    _gradient = widget.initialGradient.copyWith();
    _selectedStopIndex = 0;
  }

  void _onGradientChanged() {
    widget.onGradientChanged?.call(_gradient);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          _buildPreview(),

          // Type selector
          _buildTypeSelector(),

          // Gradient bar with stops
          _buildGradientBar(),

          // Selected stop editor
          if (_selectedStopIndex != null) _buildStopEditor(),

          // Angle/position controls
          _buildPositionControls(),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.all(12),
      width: widget.previewSize.width,
      height: widget.previewSize.height,
      decoration: BoxDecoration(
        gradient: _gradient.toFlutterGradient(),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF444444)),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: GradientType.values.map((type) {
          final isSelected = _gradient.type == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _gradient = _gradient.copyWith(type: type);
                });
                _onGradientChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF383838) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF7A7A7A),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getTypeIcon(GradientType type) {
    switch (type) {
      case GradientType.linear:
        return Icons.gradient;
      case GradientType.radial:
        return Icons.radio_button_unchecked;
      case GradientType.angular:
        return Icons.rotate_right;
      case GradientType.diamond:
        return Icons.diamond_outlined;
    }
  }

  Widget _buildGradientBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Gradient bar
          GestureDetector(
            onTapDown: (details) {
              final position = details.localPosition.dx / (280 - 24);
              _addStop(position.clamp(0.0, 1.0));
            },
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradient.stops.map((s) => s.colorWithOpacity).toList(),
                  stops: _gradient.stops.map((s) => s.position).toList(),
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF444444)),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Stop handles
          SizedBox(
            height: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: _gradient.stops.asMap().entries.map((entry) {
                final index = entry.key;
                final stop = entry.value;
                final isSelected = _selectedStopIndex == index;

                return Positioned(
                  left: stop.position * (280 - 24) - 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedStopIndex = index),
                    onPanUpdate: (details) {
                      final newPosition = (stop.position + details.delta.dx / (280 - 24)).clamp(0.0, 1.0);
                      setState(() {
                        _gradient.stops[index] = stop.copyWith(position: newPosition);
                        _gradient.stops.sort((a, b) => a.position.compareTo(b.position));
                        _selectedStopIndex = _gradient.stops.indexOf(stop);
                      });
                      _onGradientChanged();
                    },
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: stop.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0D99FF) : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _addStop(double position) {
    // Find colors to interpolate
    GradientStop? before, after;
    for (final stop in _gradient.stops) {
      if (stop.position <= position) before = stop;
      if (stop.position >= position && after == null) after = stop;
    }

    // Interpolate color
    Color color = Colors.grey;
    if (before != null && after != null) {
      final t = (position - before.position) / (after.position - before.position);
      color = Color.lerp(before.color, after.color, t) ?? Colors.grey;
    } else if (before != null) {
      color = before.color;
    } else if (after != null) {
      color = after.color;
    }

    setState(() {
      _gradient.stops.add(GradientStop(position: position, color: color));
      _gradient.stops.sort((a, b) => a.position.compareTo(b.position));
      _selectedStopIndex = _gradient.stops.indexWhere((s) => s.position == position);
    });
    _onGradientChanged();
  }

  Widget _buildStopEditor() {
    final stop = _gradient.stops[_selectedStopIndex!];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Color preview
              GestureDetector(
                onTap: () => setState(() => _showColorPicker = !_showColorPicker),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: stop.color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF444444)),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Position
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Position', style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 10)),
                    const SizedBox(height: 2),
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF444444)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${(stop.position * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Opacity
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Opacity', style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 10)),
                    const SizedBox(height: 2),
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF444444)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${(stop.opacity * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button
              if (_gradient.stops.length > 2)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: const Color(0xFF7A7A7A),
                  onPressed: () {
                    setState(() {
                      _gradient.stops.removeAt(_selectedStopIndex!);
                      _selectedStopIndex = _selectedStopIndex! > 0 ? _selectedStopIndex! - 1 : 0;
                    });
                    _onGradientChanged();
                  },
                ),
            ],
          ),

          // Inline color picker
          if (_showColorPicker)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FigmaColorPicker(
                initialColor: stop.color,
                initialOpacity: stop.opacity,
                onColorChanged: (result) {
                  setState(() {
                    _gradient.stops[_selectedStopIndex!] = stop.copyWith(
                      color: result.color,
                      opacity: result.opacity,
                    );
                  });
                  _onGradientChanged();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPositionControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          // Angle (for linear)
          if (_gradient.type == GradientType.linear || _gradient.type == GradientType.angular)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Angle', style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 10)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: const Color(0xFF0D99FF),
                            inactiveTrackColor: const Color(0xFF444444),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _gradient.angle,
                            min: 0,
                            max: 360,
                            onChanged: (value) {
                              setState(() {
                                _gradient = _gradient.copyWith(angle: value);
                              });
                              _onGradientChanged();
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${_gradient.angle.round()}°',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Scale (for radial)
          if (_gradient.type == GradientType.radial || _gradient.type == GradientType.diamond)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scale', style: TextStyle(color: Color(0xFF7A7A7A), fontSize: 10)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: const Color(0xFF0D99FF),
                            inactiveTrackColor: const Color(0xFF444444),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _gradient.scale,
                            min: 0.1,
                            max: 2.0,
                            onChanged: (value) {
                              setState(() {
                                _gradient = _gradient.copyWith(scale: value);
                              });
                              _onGradientChanged();
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(_gradient.scale * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact gradient preview thumbnail
class GradientThumbnail extends StatelessWidget {
  final GradientData gradient;
  final double width;
  final double height;
  final bool selected;
  final VoidCallback? onTap;

  const GradientThumbnail({
    super.key,
    required this.gradient,
    this.width = 32,
    this.height = 32,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient.toFlutterGradient(),
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
