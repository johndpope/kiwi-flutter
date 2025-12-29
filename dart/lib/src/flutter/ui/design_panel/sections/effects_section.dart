/// Effects section for Design Panel
///
/// Effect controls with enable checkbox, type dropdown, and visibility toggle.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/property_row.dart';
import '../widgets/visibility_toggle.dart';
import '../widgets/dropdown_button.dart';
import '../widgets/icon_input.dart';

/// Effect types matching Figma for design panel
enum DesignPanelEffectType {
  dropShadow,
  innerShadow,
  layerBlur,
  backgroundBlur,
}

/// Effects section widget
class EffectsSection extends StatelessWidget {
  final List<Map<String, dynamic>> effects;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onAdd;
  final VoidCallback? onGridSettings;
  final void Function(int index, Map<String, dynamic> changes)? onEffectChanged;
  final void Function(int index)? onRemove;
  final void Function(int index)? onToggleVisibility;
  final void Function(int index)? onToggleEnabled;
  final void Function(int index)? onEditEffect;

  const EffectsSection({
    super.key,
    required this.effects,
    required this.expanded,
    required this.onToggle,
    this.onAdd,
    this.onGridSettings,
    this.onEffectChanged,
    this.onRemove,
    this.onToggleVisibility,
    this.onToggleEnabled,
    this.onEditEffect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeaderWithGrid(
          title: 'Effects',
          expanded: expanded,
          onToggle: onToggle,
          onGridSettings: onGridSettings,
          onAdd: onAdd,
        ),
        if (expanded)
          SectionContent(
            children: effects.isEmpty
                ? [const EmptySectionMessage(message: 'No effects')]
                : effects
                    .asMap()
                    .entries
                    .map((e) => _EffectItem(
                          effect: e.value,
                          index: e.key,
                          onChanged: (changes) => onEffectChanged?.call(e.key, changes),
                          onRemove: () => onRemove?.call(e.key),
                          onToggleVisibility: () => onToggleVisibility?.call(e.key),
                          onToggleEnabled: () => onToggleEnabled?.call(e.key),
                          onEdit: () => onEditEffect?.call(e.key),
                        ))
                    .toList(),
          ),
      ],
    );
  }
}

/// Individual effect item with checkbox
class _EffectItem extends StatelessWidget {
  final Map<String, dynamic> effect;
  final int index;
  final void Function(Map<String, dynamic> changes)? onChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onToggleEnabled;
  final VoidCallback? onEdit;

  const _EffectItem({
    required this.effect,
    required this.index,
    this.onChanged,
    this.onRemove,
    this.onToggleVisibility,
    this.onToggleEnabled,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final type = effect['type'] as String? ?? 'DROP_SHADOW';
    final visible = effect['visible'] ?? true;
    final enabled = effect['enabled'] ?? true;

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignPanelSpacing.sm),
      child: Row(
        children: [
          // Enable checkbox
          FigmaCheckbox(
            value: enabled,
            onChanged: (_) => onToggleEnabled?.call(),
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Effect type dropdown
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              child: CompactDropdown(
                value: _getEffectLabel(type),
                options: const ['Drop shadow', 'Inner shadow', 'Layer blur', 'Background blur'],
                onChanged: (value) {
                  onChanged?.call({'type': _getEffectType(value)});
                },
              ),
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Actions
          ItemActionRow(
            visible: visible,
            onToggleVisibility: onToggleVisibility,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }

  String _getEffectLabel(String type) {
    switch (type) {
      case 'DROP_SHADOW':
        return 'Drop shadow';
      case 'INNER_SHADOW':
        return 'Inner shadow';
      case 'LAYER_BLUR':
        return 'Layer blur';
      case 'BACKGROUND_BLUR':
        return 'Background blur';
      default:
        return type;
    }
  }

  String _getEffectType(String label) {
    switch (label) {
      case 'Drop shadow':
        return 'DROP_SHADOW';
      case 'Inner shadow':
        return 'INNER_SHADOW';
      case 'Layer blur':
        return 'LAYER_BLUR';
      case 'Background blur':
        return 'BACKGROUND_BLUR';
      default:
        return 'DROP_SHADOW';
    }
  }
}

/// Expanded effect editor (for detailed shadow/blur properties)
class EffectEditor extends StatelessWidget {
  final Map<String, dynamic> effect;
  final void Function(Map<String, dynamic> changes)? onChanged;

  const EffectEditor({
    super.key,
    required this.effect,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final type = effect['type'] as String? ?? 'DROP_SHADOW';

    if (type == 'LAYER_BLUR' || type == 'BACKGROUND_BLUR') {
      return _BlurEditor(effect: effect, onChanged: onChanged);
    } else {
      return _ShadowEditor(effect: effect, onChanged: onChanged);
    }
  }
}

/// Shadow effect editor (drop shadow, inner shadow)
class _ShadowEditor extends StatelessWidget {
  final Map<String, dynamic> effect;
  final void Function(Map<String, dynamic> changes)? onChanged;

  const _ShadowEditor({
    required this.effect,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _extractColor(effect);
    final offset = effect['offset'] as Map<String, dynamic>? ?? {'x': 0, 'y': 4};
    final blur = (effect['radius'] as num?)?.toDouble() ?? 4.0;
    final spread = (effect['spread'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignPanelSpacing.panelPadding,
        0,
        DesignPanelSpacing.panelPadding,
        DesignPanelSpacing.sm,
      ),
      child: Column(
        children: [
          // Color row
          Row(
            children: [
              // Color swatch
              GestureDetector(
                onTap: () {
                  // Open color picker
                },
                child: Container(
                  width: DesignPanelDimensions.colorSwatchSize,
                  height: DesignPanelDimensions.colorSwatchSize,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                    border: Border.all(color: DesignPanelColors.border),
                  ),
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              // Hex value
              Expanded(
                flex: 2,
                child: Container(
                  height: DesignPanelDimensions.inputHeight,
                  padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.sm),
                  decoration: BoxDecoration(
                    color: DesignPanelColors.bg1,
                    borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                    border: Border.all(color: DesignPanelColors.border),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    color.value.toRadixString(16).substring(2).toUpperCase(),
                    style: DesignPanelTypography.valueStyle,
                  ),
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              // Opacity
              Expanded(
                flex: 1,
                child: PercentageInput(
                  value: color.opacity,
                  onChanged: (v) {
                    // Update opacity
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignPanelSpacing.sm),
          // X/Y offset row
          Row(
            children: [
              Expanded(
                child: NumericInput(
                  label: 'X',
                  value: (offset['x'] as num?)?.toDouble() ?? 0,
                  onChanged: (v) {
                    onChanged?.call({
                      'offset': {'x': v, 'y': offset['y']},
                    });
                  },
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.xs),
              Expanded(
                child: NumericInput(
                  label: 'Y',
                  value: (offset['y'] as num?)?.toDouble() ?? 0,
                  onChanged: (v) {
                    onChanged?.call({
                      'offset': {'x': offset['x'], 'y': v},
                    });
                  },
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.xs),
              Expanded(
                child: NumericInput(
                  label: 'B',
                  value: blur,
                  onChanged: (v) {
                    onChanged?.call({'radius': v});
                  },
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.xs),
              Expanded(
                child: NumericInput(
                  label: 'S',
                  value: spread,
                  onChanged: (v) {
                    onChanged?.call({'spread': v});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _extractColor(Map<String, dynamic> effect) {
    final c = effect['color'] as Map<String, dynamic>?;
    if (c != null) {
      return Color.fromRGBO(
        ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
        ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
        ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
        (c['a'] as num?)?.toDouble() ?? 0.25,
      );
    }
    return Colors.black.withOpacity(0.25);
  }
}

/// Blur effect editor (layer blur, background blur)
class _BlurEditor extends StatelessWidget {
  final Map<String, dynamic> effect;
  final void Function(Map<String, dynamic> changes)? onChanged;

  const _BlurEditor({
    required this.effect,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final blur = (effect['radius'] as num?)?.toDouble() ?? 4.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignPanelSpacing.panelPadding,
        0,
        DesignPanelSpacing.panelPadding,
        DesignPanelSpacing.sm,
      ),
      child: Row(
        children: [
          const Text(
            'Blur',
            style: DesignPanelTypography.labelStyle,
          ),
          const SizedBox(width: DesignPanelSpacing.sm),
          Expanded(
            child: NumericInput(
              label: '',
              value: blur,
              onChanged: (v) {
                onChanged?.call({'radius': v});
              },
            ),
          ),
        ],
      ),
    );
  }
}
