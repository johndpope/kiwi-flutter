/// Fill section for Design Panel
///
/// Fill paint controls with color, gradient, and image support.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/property_row.dart';
import '../widgets/visibility_toggle.dart';

/// Fill section widget
class FillSection extends StatelessWidget {
  final List<Map<String, dynamic>> fills;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onAdd;
  final void Function(int index, Map<String, dynamic> changes)? onFillChanged;
  final void Function(int index)? onRemove;
  final void Function(int index)? onToggleVisibility;
  final void Function(int index)? onColorTap;

  const FillSection({
    super.key,
    required this.fills,
    required this.expanded,
    required this.onToggle,
    this.onAdd,
    this.onFillChanged,
    this.onRemove,
    this.onToggleVisibility,
    this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeaderWithAdd(
          title: 'Fill',
          expanded: expanded,
          onToggle: onToggle,
          onAdd: onAdd,
        ),
        if (expanded)
          SectionContent(
            children: fills.isEmpty
                ? [const EmptySectionMessage(message: 'No fills')]
                : fills
                    .asMap()
                    .entries
                    .map((e) => _FillItem(
                          fill: e.value,
                          index: e.key,
                          onChanged: (changes) => onFillChanged?.call(e.key, changes),
                          onRemove: () => onRemove?.call(e.key),
                          onToggleVisibility: () => onToggleVisibility?.call(e.key),
                          onColorTap: () => onColorTap?.call(e.key),
                        ))
                    .toList(),
          ),
      ],
    );
  }
}

/// Individual fill item
class _FillItem extends StatelessWidget {
  final Map<String, dynamic> fill;
  final int index;
  final void Function(Map<String, dynamic> changes)? onChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onColorTap;

  const _FillItem({
    required this.fill,
    required this.index,
    this.onChanged,
    this.onRemove,
    this.onToggleVisibility,
    this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = fill['type'] as String? ?? 'SOLID';
    final visible = fill['visible'] ?? true;
    final opacity = (fill['opacity'] as num?)?.toDouble() ?? 1.0;

    // Extract color
    Color color = Colors.grey;
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

    // Extract gradient
    Gradient? gradient;
    if (type.contains('GRADIENT')) {
      gradient = _extractGradient(fill);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignPanelSpacing.sm),
      child: Row(
        children: [
          // Color/gradient swatch
          GestureDetector(
            onTap: onColorTap,
            child: Container(
              width: DesignPanelDimensions.colorSwatchSize,
              height: DesignPanelDimensions.colorSwatchSize,
              decoration: BoxDecoration(
                color: gradient == null ? color : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                border: Border.all(color: DesignPanelColors.border),
              ),
              child: type == 'IMAGE'
                  ? const Icon(Icons.image, size: 14, color: DesignPanelColors.text2)
                  : null,
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Hex value / type label
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: onColorTap,
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
                  type == 'SOLID'
                      ? color.value.toRadixString(16).substring(2).toUpperCase()
                      : _getTypeLabel(type),
                  style: DesignPanelTypography.valueStyle,
                ),
              ),
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Opacity
          Expanded(
            flex: 1,
            child: Container(
              height: DesignPanelDimensions.inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.xs),
              decoration: BoxDecoration(
                color: DesignPanelColors.bg1,
                borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                border: Border.all(color: DesignPanelColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(opacity * 100).round()}',
                      style: DesignPanelTypography.valueStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const Text(
                    ' %',
                    style: TextStyle(
                      color: DesignPanelColors.text3,
                      fontSize: DesignPanelTypography.fontSizeSm,
                    ),
                  ),
                ],
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

  String _getTypeLabel(String type) {
    switch (type) {
      case 'SOLID':
        return 'Solid';
      case 'GRADIENT_LINEAR':
        return 'Linear';
      case 'GRADIENT_RADIAL':
        return 'Radial';
      case 'GRADIENT_ANGULAR':
        return 'Angular';
      case 'GRADIENT_DIAMOND':
        return 'Diamond';
      case 'IMAGE':
        return 'Image';
      default:
        return type;
    }
  }

  Gradient? _extractGradient(Map<String, dynamic> fill) {
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

    final type = fill['type'] as String? ?? '';
    if (type == 'GRADIENT_RADIAL') {
      return RadialGradient(colors: colors, stops: positions);
    }
    return LinearGradient(colors: colors, stops: positions);
  }
}
