/// Properties panel for the Figma editor
///
/// Displays and edits properties of selected nodes:
/// - Position and size
/// - Rotation and corner radius
/// - Fill and stroke
/// - Effects (shadows, blur)
/// - Text properties
/// - Auto-layout settings

import 'package:flutter/material.dart';
import 'color_picker.dart';
import 'gradient_editor.dart';
import '../node_renderer.dart';

/// Figma-style colors
class _Colors {
  static const bg1 = Color(0xFF1E1E1E);
  static const bg2 = Color(0xFF2C2C2C);
  static const bg3 = Color(0xFF383838);
  static const border = Color(0xFF444444);
  static const text1 = Color(0xFFFFFFFF);
  static const text2 = Color(0xFFB3B3B3);
  static const text3 = Color(0xFF7A7A7A);
  static const accent = Color(0xFF0D99FF);
}

/// Properties panel widget
class PropertiesPanel extends StatefulWidget {
  /// The selected node
  final Map<String, dynamic>? node;

  /// Node properties helper
  final FigmaNodeProperties? properties;

  /// Callback when a property changes
  final void Function(String property, dynamic value)? onPropertyChanged;

  /// Width of the panel
  final double width;

  const PropertiesPanel({
    super.key,
    this.node,
    this.properties,
    this.onPropertyChanged,
    this.width = 300,
  });

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  // Expanded sections
  bool _transformExpanded = true;
  bool _fillExpanded = true;
  bool _strokeExpanded = true;
  bool _effectsExpanded = true;
  bool _layoutExpanded = true;
  bool _typographyExpanded = true;
  bool _exportExpanded = false;

  // Active editors
  int? _editingFillIndex;
  int? _editingStrokeIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.node == null || widget.properties == null) {
      return _buildEmptyState();
    }

    return Container(
      width: widget.width,
      color: _Colors.bg2,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Node name header
          _buildHeader(),

          // Transform section
          _buildSection(
            title: 'Transform',
            expanded: _transformExpanded,
            onToggle: () => setState(() => _transformExpanded = !_transformExpanded),
            child: _buildTransformSection(),
          ),

          // Layout section (for auto-layout nodes)
          if (_hasAutoLayout) ...[
            _buildSection(
              title: 'Auto layout',
              expanded: _layoutExpanded,
              onToggle: () => setState(() => _layoutExpanded = !_layoutExpanded),
              child: _buildLayoutSection(),
            ),
          ],

          // Fill section
          _buildSection(
            title: 'Fill',
            expanded: _fillExpanded,
            onToggle: () => setState(() => _fillExpanded = !_fillExpanded),
            trailing: _buildAddButton(() => _addFill()),
            child: _buildFillSection(),
          ),

          // Stroke section
          _buildSection(
            title: 'Stroke',
            expanded: _strokeExpanded,
            onToggle: () => setState(() => _strokeExpanded = !_strokeExpanded),
            trailing: _buildAddButton(() => _addStroke()),
            child: _buildStrokeSection(),
          ),

          // Effects section
          _buildSection(
            title: 'Effects',
            expanded: _effectsExpanded,
            onToggle: () => setState(() => _effectsExpanded = !_effectsExpanded),
            trailing: _buildAddButton(() => _addEffect()),
            child: _buildEffectsSection(),
          ),

          // Type-specific sections (Typography for TEXT nodes)
          ..._buildTypeSpecificSections(),

          // Export section
          _buildSection(
            title: 'Export',
            expanded: _exportExpanded,
            onToggle: () => setState(() => _exportExpanded = !_exportExpanded),
            trailing: _buildAddButton(() => _addExport()),
            child: _buildExportSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: widget.width,
      color: _Colors.bg2,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 48, color: _Colors.text3),
            SizedBox(height: 12),
            Text(
              'Select a layer to\nsee its properties',
              style: TextStyle(color: _Colors.text3, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = widget.node!['name'] as String? ?? 'Unnamed';
    final type = widget.node!['type'] as String? ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Icon(_getTypeIcon(type), size: 14, color: _Colors.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: _Colors.text1,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'FRAME':
        return Icons.crop_square;
      case 'GROUP':
        return Icons.folder_outlined;
      case 'COMPONENT':
      case 'COMPONENT_SET':
        return Icons.widgets_outlined;
      case 'INSTANCE':
        return Icons.diamond_outlined;
      case 'TEXT':
        return Icons.text_fields;
      case 'RECTANGLE':
      case 'ROUNDED_RECTANGLE':
        return Icons.rectangle_outlined;
      case 'ELLIPSE':
        return Icons.circle_outlined;
      case 'VECTOR':
      case 'LINE':
        return Icons.show_chart;
      default:
        return Icons.layers_outlined;
    }
  }

  Widget _buildSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _Colors.border, width: 1)),
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: _Colors.text2,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: _Colors.text1,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),

        // Section content
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: child,
          ),
      ],
    );
  }

  Widget _buildAddButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.add, size: 16, color: _Colors.text2),
    );
  }

  // ============ Transform Section ============

  Widget _buildTransformSection() {
    final props = widget.properties!;

    return Column(
      children: [
        // Position row
        Row(
          children: [
            Expanded(child: _buildNumericField('X', props.x, (v) => _updateProperty('x', v))),
            const SizedBox(width: 8),
            Expanded(child: _buildNumericField('Y', props.y, (v) => _updateProperty('y', v))),
          ],
        ),
        const SizedBox(height: 8),

        // Size row
        Row(
          children: [
            Expanded(child: _buildNumericField('W', props.width, (v) => _updateProperty('width', v))),
            const SizedBox(width: 8),
            Expanded(child: _buildNumericField('H', props.height, (v) => _updateProperty('height', v))),
          ],
        ),
        const SizedBox(height: 8),

        // Rotation and corner radius
        Row(
          children: [
            Expanded(
              child: _buildNumericField(
                '°',
                props.rotation,
                (v) => _updateProperty('rotation', v),
                suffix: '°',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumericField(
                '◰',
                props.cornerRadius ?? 0,
                (v) => _updateProperty('cornerRadius', v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumericField(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    String? suffix,
  }) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: _Colors.bg1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _Colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(color: _Colors.text3, fontSize: 10),
            ),
          ),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value.toStringAsFixed(0)),
              style: const TextStyle(color: _Colors.text1, fontSize: 11),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                isDense: true,
                suffixText: suffix,
                suffixStyle: const TextStyle(color: _Colors.text3, fontSize: 10),
              ),
              onSubmitted: (text) {
                final newValue = double.tryParse(text);
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============ Layout Section ============

  bool get _hasAutoLayout {
    final layoutMode = widget.node?['layoutMode'];
    return layoutMode == 'HORIZONTAL' || layoutMode == 'VERTICAL';
  }

  Widget _buildLayoutSection() {
    final node = widget.node!;
    final layoutMode = node['layoutMode'] as String?;
    final padding = node['padding'] as Map<String, dynamic>?;
    final itemSpacing = (node['itemSpacing'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        // Direction
        Row(
          children: [
            const Text('Direction', style: TextStyle(color: _Colors.text2, fontSize: 11)),
            const Spacer(),
            _buildToggleButton(
              Icons.arrow_forward,
              layoutMode == 'HORIZONTAL',
              () => _updateProperty('layoutMode', 'HORIZONTAL'),
            ),
            const SizedBox(width: 4),
            _buildToggleButton(
              Icons.arrow_downward,
              layoutMode == 'VERTICAL',
              () => _updateProperty('layoutMode', 'VERTICAL'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Spacing
        Row(
          children: [
            const Text('Spacing', style: TextStyle(color: _Colors.text2, fontSize: 11)),
            const Spacer(),
            SizedBox(
              width: 60,
              child: _buildNumericField('', itemSpacing, (v) => _updateProperty('itemSpacing', v)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Padding
        Row(
          children: [
            const Text('Padding', style: TextStyle(color: _Colors.text2, fontSize: 11)),
            const Spacer(),
            SizedBox(
              width: 40,
              child: _buildNumericField(
                'T',
                (padding?['top'] as num?)?.toDouble() ?? 0,
                (v) => _updateProperty('padding.top', v),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 40,
              child: _buildNumericField(
                'R',
                (padding?['right'] as num?)?.toDouble() ?? 0,
                (v) => _updateProperty('padding.right', v),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 40,
              child: _buildNumericField(
                'B',
                (padding?['bottom'] as num?)?.toDouble() ?? 0,
                (v) => _updateProperty('padding.bottom', v),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 40,
              child: _buildNumericField(
                'L',
                (padding?['left'] as num?)?.toDouble() ?? 0,
                (v) => _updateProperty('padding.left', v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleButton(IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? _Colors.accent : _Colors.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? _Colors.accent : _Colors.border),
        ),
        child: Icon(icon, size: 14, color: selected ? Colors.white : _Colors.text2),
      ),
    );
  }

  // ============ Fill Section ============

  Widget _buildFillSection() {
    final fills = widget.properties!.fills;

    if (fills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No fills',
          style: TextStyle(color: _Colors.text3, fontSize: 11),
        ),
      );
    }

    return Column(
      children: fills.asMap().entries.map((entry) {
        final index = entry.key;
        final fill = entry.value;
        return _buildFillItem(fill, index);
      }).toList(),
    );
  }

  Widget _buildFillItem(Map<String, dynamic> fill, int index) {
    final type = fill['type'] as String? ?? 'SOLID';
    final visible = fill['visible'] ?? true;
    final opacity = (fill['opacity'] as num?)?.toDouble() ?? 1.0;
    final blendMode = fill['blendMode'] as String? ?? 'NORMAL';

    Color? color;
    Gradient? gradient;
    if (type == 'SOLID') {
      final c = fill['color'] as Map<String, dynamic>?;
      if (c != null) {
        color = Color.fromRGBO(
          ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          opacity,
        );
      }
    } else if (type.contains('GRADIENT')) {
      gradient = _extractGradient(fill);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _editingFillIndex = _editingFillIndex == index ? null : index;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Color/gradient preview
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: gradient == null ? (color ?? _Colors.bg3) : null,
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _Colors.border),
                  ),
                  child: type == 'IMAGE'
                      ? const Icon(Icons.image, size: 14, color: _Colors.text2)
                      : null,
                ),
                const SizedBox(width: 8),

                // Type and color label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == 'SOLID' && color != null
                            ? '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}'
                            : _getFillTypeLabel(type),
                        style: const TextStyle(color: _Colors.text1, fontSize: 11),
                      ),
                      Text(
                        '${(opacity * 100).toInt()}%',
                        style: const TextStyle(color: _Colors.text3, fontSize: 9),
                      ),
                    ],
                  ),
                ),

                // Visibility toggle
                GestureDetector(
                  onTap: () => _toggleFillVisibility(index),
                  child: Icon(
                    visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 14,
                    color: _Colors.text3,
                  ),
                ),
                const SizedBox(width: 4),
                // Delete fill
                GestureDetector(
                  onTap: () => _updateProperty('removeFill', index),
                  child: const Icon(Icons.close, size: 14, color: _Colors.text3),
                ),
              ],
            ),
          ),
        ),

        // Expanded fill editor
        if (_editingFillIndex == index) ...[
          const SizedBox(height: 8),
          // Fill type selector
          _buildFillTypeSelector(index, type),
          const SizedBox(height: 8),

          // Color picker for solid fills
          if (type == 'SOLID')
            FigmaColorPicker(
              initialColor: color ?? Colors.grey,
              initialOpacity: opacity,
              onColorChanged: (result) {
                _updateFillColor(index, result.color, result.opacity);
              },
            ),

          // Gradient editor for gradient fills
          if (type.contains('GRADIENT'))
            _buildGradientEditor(fill, index),

          const SizedBox(height: 8),
          // Blend mode selector
          _buildBlendModeSelector(index, blendMode, 'fill'),
        ],
      ],
    );
  }

  String _getFillTypeLabel(String type) {
    switch (type) {
      case 'SOLID': return 'Solid';
      case 'GRADIENT_LINEAR': return 'Linear';
      case 'GRADIENT_RADIAL': return 'Radial';
      case 'GRADIENT_ANGULAR': return 'Angular';
      case 'GRADIENT_DIAMOND': return 'Diamond';
      case 'IMAGE': return 'Image';
      default: return type;
    }
  }

  Widget _buildFillTypeSelector(int index, String currentType) {
    final types = [
      ('SOLID', Icons.square_rounded, 'Solid'),
      ('GRADIENT_LINEAR', Icons.gradient, 'Linear'),
      ('GRADIENT_RADIAL', Icons.blur_circular, 'Radial'),
      ('GRADIENT_ANGULAR', Icons.donut_large, 'Angular'),
      ('GRADIENT_DIAMOND', Icons.diamond_outlined, 'Diamond'),
      ('IMAGE', Icons.image, 'Image'),
    ];

    return Row(
      children: types.map((t) {
        final isSelected = t.$1 == currentType;
        return Expanded(
          child: GestureDetector(
            onTap: () => _updateProperty('fillType.$index', t.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _Colors.accent.withOpacity(0.2) : _Colors.bg1,
                border: Border.all(
                  color: isSelected ? _Colors.accent : _Colors.border,
                ),
              ),
              child: Tooltip(
                message: t.$3,
                child: Icon(
                  t.$2,
                  size: 14,
                  color: isSelected ? _Colors.accent : _Colors.text2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGradientEditor(Map<String, dynamic> fill, int index) {
    final gradientStops = fill['gradientStops'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gradient Stops', style: TextStyle(color: _Colors.text2, fontSize: 10)),
        const SizedBox(height: 4),
        // Gradient preview bar
        Container(
          height: 20,
          decoration: BoxDecoration(
            gradient: _extractGradient(fill),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _Colors.border),
          ),
        ),
        const SizedBox(height: 8),
        // Stop list
        ...gradientStops.asMap().entries.map((entry) {
          final stop = entry.value as Map<String, dynamic>? ?? {};
          final position = (stop['position'] as num?)?.toDouble() ?? 0;
          final stopColor = stop['color'] as Map<String, dynamic>?;
          Color color = Colors.grey;
          if (stopColor != null) {
            color = Color.fromRGBO(
              ((stopColor['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((stopColor['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((stopColor['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              (stopColor['a'] as num?)?.toDouble() ?? 1.0,
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: _Colors.border),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${(position * 100).toInt()}%',
                    style: const TextStyle(color: _Colors.text1, fontSize: 10),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Gradient? _extractGradient(Map<String, dynamic> fill) {
    final type = fill['type'] as String? ?? '';
    final stops = fill['gradientStops'] as List? ?? [];

    if (stops.isEmpty) return null;

    final colors = <Color>[];
    final positions = <double>[];

    for (final stop in stops) {
      if (stop is Map) {
        final c = stop['color'] as Map?;
        final pos = (stop['position'] as num?)?.toDouble() ?? 0;
        if (c != null) {
          colors.add(Color.fromRGBO(
            ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (c['a'] as num?)?.toDouble() ?? 1.0,
          ));
          positions.add(pos);
        }
      }
    }

    if (colors.length < 2) return null;

    if (type == 'GRADIENT_RADIAL') {
      return RadialGradient(colors: colors, stops: positions);
    }
    return LinearGradient(colors: colors, stops: positions);
  }

  Widget _buildBlendModeSelector(int index, String currentMode, String propertyPrefix) {
    final modes = [
      'NORMAL', 'DARKEN', 'MULTIPLY', 'COLOR_BURN',
      'LIGHTEN', 'SCREEN', 'COLOR_DODGE',
      'OVERLAY', 'SOFT_LIGHT', 'HARD_LIGHT',
      'DIFFERENCE', 'EXCLUSION', 'HUE', 'SATURATION', 'COLOR', 'LUMINOSITY',
    ];

    return Row(
      children: [
        const Text('Blend', style: TextStyle(color: _Colors.text2, fontSize: 11)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _Colors.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _Colors.border),
          ),
          child: DropdownButton<String>(
            value: modes.contains(currentMode) ? currentMode : 'NORMAL',
            dropdownColor: _Colors.bg2,
            isDense: true,
            underline: const SizedBox(),
            style: const TextStyle(color: _Colors.text1, fontSize: 11),
            items: modes.map((mode) {
              return DropdownMenuItem(
                value: mode,
                child: Text(
                  mode.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                  style: const TextStyle(color: _Colors.text1, fontSize: 11),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateProperty('${propertyPrefix}BlendMode.$index', value);
              }
            },
          ),
        ),
      ],
    );
  }

  void _addFill() {
    _updateProperty('addFill', {
      'type': 'SOLID',
      'color': {'r': 0.5, 'g': 0.5, 'b': 0.5},
      'opacity': 1.0,
    });
  }

  void _toggleFillVisibility(int index) {
    _updateProperty('fillVisible.$index', !(widget.properties!.fills[index]['visible'] ?? true));
  }

  void _updateFillColor(int index, Color color, double opacity) {
    _updateProperty('fillColor.$index', {
      'r': color.red / 255,
      'g': color.green / 255,
      'b': color.blue / 255,
    });
    _updateProperty('fillOpacity.$index', opacity);
  }

  // ============ Stroke Section ============

  Widget _buildStrokeSection() {
    final strokes = widget.properties!.strokes;
    final strokeWeight = widget.properties!.strokeWeight;
    final strokeAlign = widget.node?['strokeAlign'] as String? ?? 'CENTER';
    final strokeCap = widget.node?['strokeCap'] as String? ?? 'NONE';
    final strokeJoin = widget.node?['strokeJoin'] as String? ?? 'MITER';
    final strokeDashes = widget.node?['strokeDashes'] as List? ?? [];

    return Column(
      children: [
        if (strokes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No strokes',
              style: TextStyle(color: _Colors.text3, fontSize: 11),
            ),
          )
        else
          ...strokes.asMap().entries.map((entry) {
            return _buildStrokeItem(entry.value, entry.key);
          }),

        if (strokes.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Weight row
          Row(
            children: [
              const Text('Weight', style: TextStyle(color: _Colors.text2, fontSize: 11)),
              const Spacer(),
              SizedBox(
                width: 60,
                child: _buildNumericField('', strokeWeight, (v) => _updateProperty('strokeWeight', v)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Position row (Inside/Center/Outside)
          Row(
            children: [
              const Text('Position', style: TextStyle(color: _Colors.text2, fontSize: 11)),
              const Spacer(),
              _buildStrokePositionSelector(strokeAlign),
            ],
          ),
          const SizedBox(height: 8),

          // Cap and Join row
          Row(
            children: [
              // Cap style
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cap', style: TextStyle(color: _Colors.text2, fontSize: 10)),
                    const SizedBox(height: 4),
                    _buildStrokeCapSelector(strokeCap),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Join style
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Join', style: TextStyle(color: _Colors.text2, fontSize: 10)),
                    const SizedBox(height: 4),
                    _buildStrokeJoinSelector(strokeJoin),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Dashes row
          Row(
            children: [
              const Text('Dashes', style: TextStyle(color: _Colors.text2, fontSize: 11)),
              const Spacer(),
              _buildDashSelector(strokeDashes),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStrokePositionSelector(String currentPosition) {
    final positions = [
      ('INSIDE', 'Inside'),
      ('CENTER', 'Center'),
      ('OUTSIDE', 'Outside'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _Colors.bg1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _Colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: positions.map((p) {
          final isSelected = p.$1 == currentPosition;
          return GestureDetector(
            onTap: () => _updateProperty('strokeAlign', p.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? _Colors.accent.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                p.$2,
                style: TextStyle(
                  color: isSelected ? _Colors.accent : _Colors.text2,
                  fontSize: 10,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStrokeCapSelector(String currentCap) {
    final caps = [
      ('NONE', Icons.remove, 'None'),
      ('ROUND', Icons.fiber_manual_record, 'Round'),
      ('SQUARE', Icons.crop_square, 'Square'),
    ];

    return Row(
      children: caps.map((c) {
        final isSelected = c.$1 == currentCap;
        return Expanded(
          child: GestureDetector(
            onTap: () => _updateProperty('strokeCap', c.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? _Colors.accent.withOpacity(0.2) : _Colors.bg1,
                border: Border.all(
                  color: isSelected ? _Colors.accent : _Colors.border,
                ),
              ),
              child: Tooltip(
                message: c.$3,
                child: Icon(
                  c.$2,
                  size: 12,
                  color: isSelected ? _Colors.accent : _Colors.text2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrokeJoinSelector(String currentJoin) {
    final joins = [
      ('MITER', Icons.change_history, 'Miter'),
      ('ROUND', Icons.circle_outlined, 'Round'),
      ('BEVEL', Icons.crop_square, 'Bevel'),
    ];

    return Row(
      children: joins.map((j) {
        final isSelected = j.$1 == currentJoin;
        return Expanded(
          child: GestureDetector(
            onTap: () => _updateProperty('strokeJoin', j.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? _Colors.accent.withOpacity(0.2) : _Colors.bg1,
                border: Border.all(
                  color: isSelected ? _Colors.accent : _Colors.border,
                ),
              ),
              child: Tooltip(
                message: j.$3,
                child: Icon(
                  j.$2,
                  size: 12,
                  color: isSelected ? _Colors.accent : _Colors.text2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDashSelector(List dashes) {
    final hasDashes = dashes.isNotEmpty;
    final dashPattern = hasDashes ? dashes.map((d) => d.toString()).join(', ') : 'None';

    return GestureDetector(
      onTap: () {
        // Toggle between solid and dashed
        if (hasDashes) {
          _updateProperty('strokeDashes', <double>[]);
        } else {
          _updateProperty('strokeDashes', [8.0, 8.0]);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _Colors.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dash preview
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: hasDashes ? Colors.transparent : _Colors.text1,
              ),
              child: hasDashes
                  ? CustomPaint(
                      painter: _DashPainter(color: _Colors.text1),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, size: 14, color: _Colors.text2),
          ],
        ),
      ),
    );
  }

  Widget _buildStrokeItem(Map<String, dynamic> stroke, int index) {
    final type = stroke['type'] as String? ?? 'SOLID';
    final visible = stroke['visible'] ?? true;
    final opacity = (stroke['opacity'] as num?)?.toDouble() ?? 1.0;
    final blendMode = stroke['blendMode'] as String? ?? 'NORMAL';

    Color? color;
    if (type == 'SOLID') {
      final c = stroke['color'] as Map<String, dynamic>?;
      if (c != null) {
        color = Color.fromRGBO(
          ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          opacity,
        );
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _editingStrokeIndex = _editingStrokeIndex == index ? null : index;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color ?? _Colors.text2, width: 2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        color != null ? '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}' : type,
                        style: const TextStyle(color: _Colors.text1, fontSize: 11),
                      ),
                      Text(
                        '${(opacity * 100).toInt()}%',
                        style: const TextStyle(color: _Colors.text3, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _toggleStrokeVisibility(index),
                  child: Icon(
                    visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 14,
                    color: _Colors.text3,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _updateProperty('removeStroke', index),
                  child: const Icon(Icons.close, size: 14, color: _Colors.text3),
                ),
              ],
            ),
          ),
        ),

        // Expanded stroke editor
        if (_editingStrokeIndex == index && type == 'SOLID') ...[
          const SizedBox(height: 8),
          FigmaColorPicker(
            initialColor: color ?? Colors.grey,
            initialOpacity: opacity,
            onColorChanged: (result) {
              _updateStrokeColor(index, result.color, result.opacity);
            },
          ),
          const SizedBox(height: 8),
          _buildBlendModeSelector(index, blendMode, 'stroke'),
        ],
      ],
    );
  }

  void _addStroke() {
    _updateProperty('addStroke', {
      'type': 'SOLID',
      'color': {'r': 0.0, 'g': 0.0, 'b': 0.0},
      'opacity': 1.0,
    });
  }

  void _toggleStrokeVisibility(int index) {
    _updateProperty('strokeVisible.$index', !(widget.properties!.strokes[index]['visible'] ?? true));
  }

  void _updateStrokeColor(int index, Color color, double opacity) {
    _updateProperty('strokeColor.$index', {
      'r': color.red / 255,
      'g': color.green / 255,
      'b': color.blue / 255,
    });
    _updateProperty('strokeOpacity.$index', opacity);
  }

  // ============ Effects Section ============

  Widget _buildEffectsSection() {
    final effects = widget.properties!.effects;

    if (effects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No effects',
          style: TextStyle(color: _Colors.text3, fontSize: 11),
        ),
      );
    }

    return Column(
      children: effects.asMap().entries.map((entry) {
        return _buildEffectItem(entry.value, entry.key);
      }).toList(),
    );
  }

  Widget _buildEffectItem(Map<String, dynamic> effect, int index) {
    final type = effect['type'] as String? ?? 'UNKNOWN';
    final visible = effect['visible'] ?? true;

    IconData icon;
    String label;

    switch (type) {
      case 'DROP_SHADOW':
        icon = Icons.filter_drama_outlined;
        label = 'Drop shadow';
        break;
      case 'INNER_SHADOW':
        icon = Icons.filter_drama;
        label = 'Inner shadow';
        break;
      case 'LAYER_BLUR':
        icon = Icons.blur_on;
        label = 'Layer blur';
        break;
      case 'BACKGROUND_BLUR':
        icon = Icons.blur_circular;
        label = 'Background blur';
        break;
      default:
        icon = Icons.auto_awesome;
        label = type;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _Colors.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: _Colors.text1, fontSize: 11)),
          ),
          GestureDetector(
            onTap: () => _toggleEffectVisibility(index),
            child: Icon(
              visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 14,
              color: _Colors.text3,
            ),
          ),
        ],
      ),
    );
  }

  void _addEffect() {
    _updateProperty('addEffect', {
      'type': 'DROP_SHADOW',
      'color': {'r': 0.0, 'g': 0.0, 'b': 0.0, 'a': 0.25},
      'offset': {'x': 0, 'y': 4},
      'radius': 4,
      'visible': true,
    });
  }

  void _toggleEffectVisibility(int index) {
    _updateProperty('effectVisible.$index', !(widget.properties!.effects[index]['visible'] ?? true));
  }

  // ============ Export Section ============

  void _addExport() {
    _updateProperty('addExport', {
      'format': 'PNG',
      'constraint': {'type': 'SCALE', 'value': 1.0},
      'suffix': '',
    });
  }

  Widget _buildExportSection() {
    // Get existing export settings from node
    final exportSettings = widget.node?['exportSettings'] as List? ?? [];

    if (exportSettings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Click + to add export',
          style: TextStyle(color: _Colors.text3, fontSize: 11),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < exportSettings.length; i++)
          _buildExportItem(exportSettings[i], i),
      ],
    );
  }

  Widget _buildExportItem(dynamic setting, int index) {
    final format = setting['format'] ?? 'PNG';
    final constraint = setting['constraint'] as Map? ?? {};
    final constraintType = constraint['type'] ?? 'SCALE';
    final constraintValue = (constraint['value'] as num?)?.toDouble() ?? 1.0;
    final suffix = setting['suffix'] ?? '';

    String sizeText;
    if (constraintType == 'SCALE') {
      sizeText = '${constraintValue}x';
    } else if (constraintType == 'WIDTH') {
      sizeText = '${constraintValue.toInt()}w';
    } else if (constraintType == 'HEIGHT') {
      sizeText = '${constraintValue.toInt()}h';
    } else {
      sizeText = '1x';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Size/Scale dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _Colors.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _Colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sizeText, style: const TextStyle(color: _Colors.text1, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 14, color: _Colors.text2),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Suffix field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _Colors.bg1,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _Colors.border),
              ),
              child: Text(
                suffix.isEmpty ? 'Suffix' : suffix,
                style: TextStyle(
                  color: suffix.isEmpty ? _Colors.text3 : _Colors.text1,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Format dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _Colors.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _Colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(format, style: const TextStyle(color: _Colors.text1, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 14, color: _Colors.text2),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Delete button
          GestureDetector(
            onTap: () => _updateProperty('removeExport', index),
            child: const Icon(Icons.remove_circle_outline, size: 16, color: _Colors.text3),
          ),
        ],
      ),
    );
  }

  // ============ Type-specific Sections ============

  List<Widget> _buildTypeSpecificSections() {
    final type = widget.node?['type'] as String?;

    switch (type) {
      case 'TEXT':
        return [_buildTextSection()];
      case 'INSTANCE':
        return [_buildInstanceSection()];
      default:
        return [];
    }
  }

  Widget _buildTextSection() {
    final textData = widget.node?['textData'] as Map<String, dynamic>? ?? {};
    final fontSize = (textData['fontSize'] as num?)?.toDouble() ??
                     (widget.node?['fontSize'] as num?)?.toDouble() ?? 14;
    final lineHeight = (textData['lineHeight'] as num?)?.toDouble();
    final letterSpacing = (textData['letterSpacing'] as num?)?.toDouble() ?? 0;
    final paragraphSpacing = (textData['paragraphSpacing'] as num?)?.toDouble() ?? 0;

    // Get font info from fontMetaData or fontName
    final fontMetaData = widget.node?['fontMetaData'] as Map?;
    final fontName = widget.node?['fontName'] as Map?;
    String fontFamily = 'Inter';
    String fontWeight = 'Regular';

    if (fontMetaData != null && fontMetaData.isNotEmpty) {
      final firstMeta = fontMetaData.values.first as Map?;
      if (firstMeta != null) {
        fontFamily = firstMeta['family'] as String? ?? fontFamily;
        fontWeight = firstMeta['style'] as String? ?? fontWeight;
      }
    } else if (fontName != null) {
      fontFamily = fontName['family'] as String? ?? fontFamily;
      fontWeight = fontName['style'] as String? ?? fontWeight;
    }

    // Text alignment
    final textAlignHorizontal = widget.node?['textAlignHorizontal'] as String? ?? 'LEFT';
    final textAlignVertical = widget.node?['textAlignVertical'] as String? ?? 'TOP';

    // Text decoration
    final textDecoration = widget.node?['textDecoration'] as String? ?? 'NONE';
    final textCase = widget.node?['textCase'] as String? ?? 'ORIGINAL';

    return _buildSection(
      title: 'Typography',
      expanded: _typographyExpanded,
      onToggle: () => setState(() => _typographyExpanded = !_typographyExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font family row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _Colors.bg1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _Colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fontFamily,
                          style: const TextStyle(color: _Colors.text1, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 14, color: _Colors.text2),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Font weight and style row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _Colors.bg1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _Colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fontWeight,
                          style: const TextStyle(color: _Colors.text1, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 14, color: _Colors.text2),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Font size and line height
          Row(
            children: [
              Expanded(child: _buildNumericField('Size', fontSize, (v) => _updateProperty('fontSize', v))),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumericField(
                  'Line',
                  lineHeight ?? fontSize * 1.5,
                  (v) => _updateProperty('lineHeight', v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Letter spacing and paragraph spacing
          Row(
            children: [
              Expanded(
                child: _buildNumericField(
                  'Letter',
                  letterSpacing,
                  (v) => _updateProperty('letterSpacing', v),
                  suffix: '%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumericField(
                  'Para',
                  paragraphSpacing,
                  (v) => _updateProperty('paragraphSpacing', v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Text alignment row
          Row(
            children: [
              const Text('Align', style: TextStyle(color: _Colors.text2, fontSize: 11)),
              const SizedBox(width: 12),
              _buildAlignmentButton(Icons.format_align_left, textAlignHorizontal == 'LEFT', () => _updateProperty('textAlignHorizontal', 'LEFT')),
              _buildAlignmentButton(Icons.format_align_center, textAlignHorizontal == 'CENTER', () => _updateProperty('textAlignHorizontal', 'CENTER')),
              _buildAlignmentButton(Icons.format_align_right, textAlignHorizontal == 'RIGHT', () => _updateProperty('textAlignHorizontal', 'RIGHT')),
              _buildAlignmentButton(Icons.format_align_justify, textAlignHorizontal == 'JUSTIFIED', () => _updateProperty('textAlignHorizontal', 'JUSTIFIED')),
              const SizedBox(width: 12),
              _buildAlignmentButton(Icons.vertical_align_top, textAlignVertical == 'TOP', () => _updateProperty('textAlignVertical', 'TOP')),
              _buildAlignmentButton(Icons.vertical_align_center, textAlignVertical == 'CENTER', () => _updateProperty('textAlignVertical', 'CENTER')),
              _buildAlignmentButton(Icons.vertical_align_bottom, textAlignVertical == 'BOTTOM', () => _updateProperty('textAlignVertical', 'BOTTOM')),
            ],
          ),
          const SizedBox(height: 12),

          // Text decoration and case row
          Row(
            children: [
              const Text('Style', style: TextStyle(color: _Colors.text2, fontSize: 11)),
              const SizedBox(width: 12),
              _buildAlignmentButton(Icons.format_underlined, textDecoration == 'UNDERLINE', () => _updateProperty('textDecoration', textDecoration == 'UNDERLINE' ? 'NONE' : 'UNDERLINE')),
              _buildAlignmentButton(Icons.format_strikethrough, textDecoration == 'STRIKETHROUGH', () => _updateProperty('textDecoration', textDecoration == 'STRIKETHROUGH' ? 'NONE' : 'STRIKETHROUGH')),
              const SizedBox(width: 12),
              _buildTextCaseButton('Aa', textCase == 'ORIGINAL', () => _updateProperty('textCase', 'ORIGINAL')),
              _buildTextCaseButton('AA', textCase == 'UPPER', () => _updateProperty('textCase', 'UPPER')),
              _buildTextCaseButton('aa', textCase == 'LOWER', () => _updateProperty('textCase', 'LOWER')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstanceSection() {
    final componentId = widget.node?['symbolID'];

    return _buildSection(
      title: 'Instance',
      expanded: true,
      onToggle: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.widgets_outlined, size: 14, color: _Colors.text2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  componentId != null ? 'Component' : 'Missing component',
                  style: const TextStyle(color: _Colors.text1, fontSize: 11),
                ),
              ),
              const Icon(Icons.open_in_new, size: 14, color: _Colors.text3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentButton(IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? _Colors.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? _Colors.accent : _Colors.text2,
        ),
      ),
    );
  }

  Widget _buildTextCaseButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? _Colors.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _Colors.accent : _Colors.text2,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _updateProperty(String property, dynamic value) {
    widget.onPropertyChanged?.call(property, value);
  }
}

/// Custom painter for dashed line preview
class _DashPainter extends CustomPainter {
  final Color color;

  _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
