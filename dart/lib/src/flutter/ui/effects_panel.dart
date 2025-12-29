/// Layer effects panel for editing shadows, blur, and other effects
///
/// Supports Figma effect types:
/// - Drop shadow
/// - Inner shadow
/// - Layer blur
/// - Background blur

import 'package:flutter/material.dart';
import 'color_picker.dart';

/// Effect type enum matching Figma
enum EffectType {
  dropShadow,
  innerShadow,
  layerBlur,
  backgroundBlur,
}

/// Effect blend mode
enum EffectBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  hue,
  saturation,
  color,
  luminosity,
}

/// Effect data model
class EffectData {
  /// Effect type
  final EffectType type;

  /// Whether the effect is visible
  bool visible;

  /// Effect color (for shadows)
  Color color;

  /// Effect opacity (0.0 - 1.0)
  double opacity;

  /// Blur radius
  double radius;

  /// X offset (for shadows)
  double offsetX;

  /// Y offset (for shadows)
  double offsetY;

  /// Spread (for shadows)
  double spread;

  /// Blend mode
  EffectBlendMode blendMode;

  /// Whether to show behind transparent areas
  bool showBehindTransparent;

  EffectData({
    required this.type,
    this.visible = true,
    this.color = Colors.black,
    this.opacity = 0.25,
    this.radius = 4.0,
    this.offsetX = 0.0,
    this.offsetY = 4.0,
    this.spread = 0.0,
    this.blendMode = EffectBlendMode.normal,
    this.showBehindTransparent = false,
  });

  /// Create from Figma effect map
  factory EffectData.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'DROP_SHADOW';
    final color = map['color'] as Map<String, dynamic>?;

    return EffectData(
      type: _parseEffectType(typeStr),
      visible: map['visible'] as bool? ?? true,
      color: color != null
          ? Color.fromRGBO(
              ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              1.0,
            )
          : Colors.black,
      opacity: (color?['a'] as num?)?.toDouble() ?? 0.25,
      radius: (map['radius'] as num?)?.toDouble() ?? 4.0,
      offsetX: (map['offset']?['x'] as num?)?.toDouble() ?? 0.0,
      offsetY: (map['offset']?['y'] as num?)?.toDouble() ?? 4.0,
      spread: (map['spread'] as num?)?.toDouble() ?? 0.0,
      blendMode: _parseBlendMode(map['blendMode'] as String?),
      showBehindTransparent: map['showShadowBehindNode'] as bool? ?? false,
    );
  }

  static EffectType _parseEffectType(String type) {
    switch (type) {
      case 'DROP_SHADOW':
        return EffectType.dropShadow;
      case 'INNER_SHADOW':
        return EffectType.innerShadow;
      case 'LAYER_BLUR':
        return EffectType.layerBlur;
      case 'BACKGROUND_BLUR':
        return EffectType.backgroundBlur;
      default:
        return EffectType.dropShadow;
    }
  }

  static EffectBlendMode _parseBlendMode(String? mode) {
    switch (mode) {
      case 'MULTIPLY':
        return EffectBlendMode.multiply;
      case 'SCREEN':
        return EffectBlendMode.screen;
      case 'OVERLAY':
        return EffectBlendMode.overlay;
      case 'DARKEN':
        return EffectBlendMode.darken;
      case 'LIGHTEN':
        return EffectBlendMode.lighten;
      case 'COLOR_DODGE':
        return EffectBlendMode.colorDodge;
      case 'COLOR_BURN':
        return EffectBlendMode.colorBurn;
      case 'HARD_LIGHT':
        return EffectBlendMode.hardLight;
      case 'SOFT_LIGHT':
        return EffectBlendMode.softLight;
      case 'DIFFERENCE':
        return EffectBlendMode.difference;
      case 'EXCLUSION':
        return EffectBlendMode.exclusion;
      case 'HUE':
        return EffectBlendMode.hue;
      case 'SATURATION':
        return EffectBlendMode.saturation;
      case 'COLOR':
        return EffectBlendMode.color;
      case 'LUMINOSITY':
        return EffectBlendMode.luminosity;
      default:
        return EffectBlendMode.normal;
    }
  }

  /// Convert to Figma effect map
  Map<String, dynamic> toMap() {
    return {
      'type': _effectTypeToString(type),
      'visible': visible,
      'color': {
        'r': color.red / 255.0,
        'g': color.green / 255.0,
        'b': color.blue / 255.0,
        'a': opacity,
      },
      'radius': radius,
      'offset': {'x': offsetX, 'y': offsetY},
      'spread': spread,
      'blendMode': _blendModeToString(blendMode),
      'showShadowBehindNode': showBehindTransparent,
    };
  }

  String _effectTypeToString(EffectType type) {
    switch (type) {
      case EffectType.dropShadow:
        return 'DROP_SHADOW';
      case EffectType.innerShadow:
        return 'INNER_SHADOW';
      case EffectType.layerBlur:
        return 'LAYER_BLUR';
      case EffectType.backgroundBlur:
        return 'BACKGROUND_BLUR';
    }
  }

  String _blendModeToString(EffectBlendMode mode) {
    switch (mode) {
      case EffectBlendMode.normal:
        return 'NORMAL';
      case EffectBlendMode.multiply:
        return 'MULTIPLY';
      case EffectBlendMode.screen:
        return 'SCREEN';
      case EffectBlendMode.overlay:
        return 'OVERLAY';
      case EffectBlendMode.darken:
        return 'DARKEN';
      case EffectBlendMode.lighten:
        return 'LIGHTEN';
      case EffectBlendMode.colorDodge:
        return 'COLOR_DODGE';
      case EffectBlendMode.colorBurn:
        return 'COLOR_BURN';
      case EffectBlendMode.hardLight:
        return 'HARD_LIGHT';
      case EffectBlendMode.softLight:
        return 'SOFT_LIGHT';
      case EffectBlendMode.difference:
        return 'DIFFERENCE';
      case EffectBlendMode.exclusion:
        return 'EXCLUSION';
      case EffectBlendMode.hue:
        return 'HUE';
      case EffectBlendMode.saturation:
        return 'SATURATION';
      case EffectBlendMode.color:
        return 'COLOR';
      case EffectBlendMode.luminosity:
        return 'LUMINOSITY';
    }
  }

  /// Create a copy with modifications
  EffectData copyWith({
    EffectType? type,
    bool? visible,
    Color? color,
    double? opacity,
    double? radius,
    double? offsetX,
    double? offsetY,
    double? spread,
    EffectBlendMode? blendMode,
    bool? showBehindTransparent,
  }) {
    return EffectData(
      type: type ?? this.type,
      visible: visible ?? this.visible,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      radius: radius ?? this.radius,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      spread: spread ?? this.spread,
      blendMode: blendMode ?? this.blendMode,
      showBehindTransparent: showBehindTransparent ?? this.showBehindTransparent,
    );
  }

  /// Get display name for the effect type
  String get displayName {
    switch (type) {
      case EffectType.dropShadow:
        return 'Drop shadow';
      case EffectType.innerShadow:
        return 'Inner shadow';
      case EffectType.layerBlur:
        return 'Layer blur';
      case EffectType.backgroundBlur:
        return 'Background blur';
    }
  }

  /// Check if this is a shadow effect
  bool get isShadow =>
      type == EffectType.dropShadow || type == EffectType.innerShadow;

  /// Check if this is a blur effect
  bool get isBlur =>
      type == EffectType.layerBlur || type == EffectType.backgroundBlur;
}

/// Effects panel widget
class EffectsPanel extends StatefulWidget {
  /// List of effects
  final List<EffectData> effects;

  /// Callback when effects change
  final ValueChanged<List<EffectData>>? onEffectsChanged;

  /// Panel width
  final double width;

  /// Whether the panel is collapsed
  final bool collapsed;

  /// Callback when collapsed state changes
  final ValueChanged<bool>? onCollapsedChanged;

  const EffectsPanel({
    super.key,
    required this.effects,
    this.onEffectsChanged,
    this.width = 240,
    this.collapsed = false,
    this.onCollapsedChanged,
  });

  @override
  State<EffectsPanel> createState() => _EffectsPanelState();
}

class _EffectsPanelState extends State<EffectsPanel> {
  late List<EffectData> _effects;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _effects = List.from(widget.effects);
  }

  @override
  void didUpdateWidget(EffectsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.effects != oldWidget.effects) {
      _effects = List.from(widget.effects);
    }
  }

  void _updateEffect(int index, EffectData effect) {
    setState(() {
      _effects[index] = effect;
    });
    widget.onEffectsChanged?.call(_effects);
  }

  void _addEffect(EffectType type) {
    setState(() {
      _effects.add(EffectData(type: type));
      _expandedIndex = _effects.length - 1;
    });
    widget.onEffectsChanged?.call(_effects);
  }

  void _removeEffect(int index) {
    setState(() {
      _effects.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    widget.onEffectsChanged?.call(_effects);
  }

  void _reorderEffects(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final effect = _effects.removeAt(oldIndex);
      _effects.insert(newIndex, effect);
    });
    widget.onEffectsChanged?.call(_effects);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Effects list
          if (!widget.collapsed) ...[
            if (_effects.isEmpty)
              _buildEmptyState()
            else
              _buildEffectsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () => widget.onCollapsedChanged?.call(!widget.collapsed),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              widget.collapsed
                  ? Icons.chevron_right
                  : Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.white54,
            ),
            const SizedBox(width: 4),
            const Text(
              'Effects',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Add effect menu
            PopupMenuButton<EffectType>(
              icon: const Icon(Icons.add, size: 16, color: Colors.white54),
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              tooltip: 'Add effect',
              color: const Color(0xFF3C3C3C),
              onSelected: _addEffect,
              itemBuilder: (context) => [
                _buildEffectMenuItem(
                    EffectType.dropShadow, Icons.blur_on, 'Drop shadow'),
                _buildEffectMenuItem(
                    EffectType.innerShadow, Icons.blur_circular, 'Inner shadow'),
                _buildEffectMenuItem(
                    EffectType.layerBlur, Icons.blur_linear, 'Layer blur'),
                _buildEffectMenuItem(EffectType.backgroundBlur,
                    Icons.blur_on_outlined, 'Background blur'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<EffectType> _buildEffectMenuItem(
      EffectType type, IconData icon, String label) {
    return PopupMenuItem(
      value: type,
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'Click + to add an effect',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildEffectsList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _effects.length,
      onReorder: _reorderEffects,
      itemBuilder: (context, index) {
        final effect = _effects[index];
        final isExpanded = _expandedIndex == index;

        return _EffectItem(
          key: ValueKey('effect_$index'),
          effect: effect,
          index: index,
          isExpanded: isExpanded,
          onToggleExpand: () {
            setState(() {
              _expandedIndex = isExpanded ? null : index;
            });
          },
          onUpdate: (updated) => _updateEffect(index, updated),
          onDelete: () => _removeEffect(index),
        );
      },
    );
  }
}

/// Individual effect item widget
class _EffectItem extends StatelessWidget {
  final EffectData effect;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<EffectData> onUpdate;
  final VoidCallback onDelete;

  const _EffectItem({
    super.key,
    required this.effect,
    required this.index,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row
        InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 14,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(width: 4),

                // Visibility toggle
                GestureDetector(
                  onTap: () => onUpdate(effect.copyWith(visible: !effect.visible)),
                  child: Icon(
                    effect.visible ? Icons.visibility : Icons.visibility_off,
                    size: 14,
                    color: effect.visible ? Colors.white70 : Colors.white38,
                  ),
                ),
                const SizedBox(width: 8),

                // Effect type icon and name
                _EffectIcon(type: effect.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    effect.displayName,
                    style: TextStyle(
                      color: effect.visible ? Colors.white : Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),

                // Delete button
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.remove_circle_outline,
                    size: 14,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded editor
        if (isExpanded) _buildEditor(),
      ],
    );
  }

  Widget _buildEditor() {
    if (effect.isShadow) {
      return _ShadowEditor(
        effect: effect,
        onUpdate: onUpdate,
      );
    } else {
      return _BlurEditor(
        effect: effect,
        onUpdate: onUpdate,
      );
    }
  }
}

/// Effect type icon
class _EffectIcon extends StatelessWidget {
  final EffectType type;

  const _EffectIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case EffectType.dropShadow:
        icon = Icons.blur_on;
        break;
      case EffectType.innerShadow:
        icon = Icons.blur_circular;
        break;
      case EffectType.layerBlur:
        icon = Icons.blur_linear;
        break;
      case EffectType.backgroundBlur:
        icon = Icons.blur_on_outlined;
        break;
    }

    return Icon(icon, size: 14, color: Colors.white54);
  }
}

/// Shadow effect editor
class _ShadowEditor extends StatelessWidget {
  final EffectData effect;
  final ValueChanged<EffectData> onUpdate;

  const _ShadowEditor({
    required this.effect,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color and opacity row
          Row(
            children: [
              // Color picker button
              GestureDetector(
                onTap: () => _showColorPicker(context),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: effect.color.withValues(alpha: effect.opacity),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Opacity slider
              Expanded(
                child: _buildSlider(
                  value: effect.opacity * 100,
                  min: 0,
                  max: 100,
                  label: '${(effect.opacity * 100).round()}%',
                  onChanged: (v) => onUpdate(effect.copyWith(opacity: v / 100)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // X/Y offset row
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(
                  label: 'X',
                  value: effect.offsetX,
                  onChanged: (v) => onUpdate(effect.copyWith(offsetX: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  label: 'Y',
                  value: effect.offsetY,
                  onChanged: (v) => onUpdate(effect.copyWith(offsetY: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Blur and spread row
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(
                  label: 'Blur',
                  value: effect.radius,
                  min: 0,
                  onChanged: (v) => onUpdate(effect.copyWith(radius: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  label: 'Spread',
                  value: effect.spread,
                  onChanged: (v) => onUpdate(effect.copyWith(spread: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show behind transparent checkbox
          if (effect.type == EffectType.dropShadow)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Checkbox(
                    value: effect.showBehindTransparent,
                    onChanged: (v) =>
                        onUpdate(effect.copyWith(showBehindTransparent: v)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Show behind transparent areas',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C2C2C),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FigmaColorPicker(
            initialColor: effect.color,
            initialOpacity: effect.opacity,
            showOpacity: true,
            onColorChanged: (result) {
              onUpdate(effect.copyWith(
                color: result.color,
                opacity: result.opacity,
              ));
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.blue.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput({
    required String label,
    required double value,
    double? min,
    double? max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ),
        Expanded(
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: TextEditingController(text: value.toStringAsFixed(0)),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onSubmitted: (text) {
                final parsed = double.tryParse(text);
                if (parsed != null) {
                  var newValue = parsed;
                  if (min != null) newValue = newValue.clamp(min, double.infinity);
                  if (max != null) newValue = newValue.clamp(double.negativeInfinity, max);
                  onChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Blur effect editor
class _BlurEditor extends StatelessWidget {
  final EffectData effect;
  final ValueChanged<EffectData> onUpdate;

  const _BlurEditor({
    required this.effect,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blur amount
          Row(
            children: [
              const SizedBox(
                width: 48,
                child: Text(
                  'Blur',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.blue.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: effect.radius,
                    min: 0,
                    max: 100,
                    onChanged: (v) => onUpdate(effect.copyWith(radius: v)),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${effect.radius.round()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact effect preview for property panels
class EffectPreview extends StatelessWidget {
  final EffectData effect;
  final VoidCallback? onTap;

  const EffectPreview({
    super.key,
    required this.effect,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            _EffectIcon(type: effect.type),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                effect.displayName,
                style: TextStyle(
                  color: effect.visible ? Colors.white : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
            if (effect.isShadow) ...[
              Text(
                '${effect.offsetX.round()}, ${effect.offsetY.round()}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ] else ...[
              Text(
                '${effect.radius.round()}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
