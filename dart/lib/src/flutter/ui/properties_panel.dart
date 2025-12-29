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

          // Type-specific sections
          ..._buildTypeSpecificSections(),
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

    Color? color;
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
                    color: color ?? _Colors.bg3,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _Colors.border),
                  ),
                  child: type == 'IMAGE'
                      ? const Icon(Icons.image, size: 14, color: _Colors.text2)
                      : type.contains('GRADIENT')
                          ? const Icon(Icons.gradient, size: 14, color: _Colors.text2)
                          : null,
                ),
                const SizedBox(width: 8),

                // Type label
                Expanded(
                  child: Text(
                    type == 'SOLID' && color != null
                        ? '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}'
                        : type,
                    style: const TextStyle(color: _Colors.text1, fontSize: 11),
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
              ],
            ),
          ),
        ),

        // Inline color picker
        if (_editingFillIndex == index && type == 'SOLID')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FigmaColorPicker(
              initialColor: color ?? Colors.grey,
              initialOpacity: opacity,
              onColorChanged: (result) {
                _updateFillColor(index, result.color, result.opacity);
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
        ],
      ],
    );
  }

  Widget _buildStrokeItem(Map<String, dynamic> stroke, int index) {
    final type = stroke['type'] as String? ?? 'SOLID';
    final visible = stroke['visible'] ?? true;

    Color? color;
    if (type == 'SOLID') {
      final c = stroke['color'] as Map<String, dynamic>?;
      if (c != null) {
        color = Color.fromRGBO(
          ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          1.0,
        );
      }
    }

    return GestureDetector(
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
              child: Text(
                color != null ? '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}' : type,
                style: const TextStyle(color: _Colors.text1, fontSize: 11),
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
          ],
        ),
      ),
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
    final fontSize = (textData['fontSize'] as num?)?.toDouble() ?? 14;
    final lineHeight = (textData['lineHeight'] as num?)?.toDouble();
    final letterSpacing = (textData['letterSpacing'] as num?)?.toDouble() ?? 0;

    return _buildSection(
      title: 'Text',
      expanded: true,
      onToggle: () {},
      child: Column(
        children: [
          // Font family (simplified)
          Row(
            children: [
              const Text('Font', style: TextStyle(color: _Colors.text2, fontSize: 11)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _Colors.bg1,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _Colors.border),
                ),
                child: const Text(
                  'Inter',
                  style: TextStyle(color: _Colors.text1, fontSize: 11),
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

          // Letter spacing
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
              const Expanded(child: SizedBox()),
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

  void _updateProperty(String property, dynamic value) {
    widget.onPropertyChanged?.call(property, value);
  }
}
