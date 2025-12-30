/// Stroke section for Design Panel
///
/// Enhanced stroke controls with per-side and advanced options.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../design_panel_icons.dart';
import '../widgets/section_header.dart';
import '../widgets/property_row.dart';
import '../widgets/visibility_toggle.dart';
import '../widgets/dropdown_button.dart';
import '../widgets/icon_input.dart';

/// Stroke section widget
class StrokeSection extends StatefulWidget {
  final List<Map<String, dynamic>> strokes;
  final double strokeWeight;
  final String strokeAlign; // INSIDE, CENTER, OUTSIDE
  final String strokeCap; // NONE, ROUND, SQUARE
  final String strokeJoin; // MITER, ROUND, BEVEL
  final List<double>? strokeDashes;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onAdd;
  final VoidCallback? onAdvancedSettings;
  final void Function(int index, Map<String, dynamic> changes)? onStrokeChanged;
  final void Function(int index)? onRemove;
  final void Function(int index)? onToggleVisibility;
  final void Function(int index)? onColorTap;
  final ValueChanged<double>? onWeightChanged;
  final ValueChanged<String>? onAlignChanged;

  const StrokeSection({
    super.key,
    required this.strokes,
    this.strokeWeight = 1,
    this.strokeAlign = 'INSIDE',
    this.strokeCap = 'NONE',
    this.strokeJoin = 'MITER',
    this.strokeDashes,
    required this.expanded,
    required this.onToggle,
    this.onAdd,
    this.onAdvancedSettings,
    this.onStrokeChanged,
    this.onRemove,
    this.onToggleVisibility,
    this.onColorTap,
    this.onWeightChanged,
    this.onAlignChanged,
  });

  @override
  State<StrokeSection> createState() => _StrokeSectionState();
}

class _StrokeSectionState extends State<StrokeSection> {
  bool _showPerSide = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeaderWithGrid(
          title: 'Stroke',
          expanded: widget.expanded,
          onToggle: widget.onToggle,
          onGridSettings: widget.onAdvancedSettings,
          onAdd: widget.onAdd,
          leadingIcon: const Icon(
            DesignPanelIcons.stroke,
            size: DesignPanelDimensions.smallIconSize,
            color: DesignPanelColors.text3,
          ),
        ),
        if (widget.expanded)
          SectionContent(
            children: [
              if (widget.strokes.isEmpty)
                const EmptySectionMessage(message: 'No strokes')
              else ...[
                // Stroke items
                ...widget.strokes.asMap().entries.map((e) => _StrokeItem(
                      stroke: e.value,
                      index: e.key,
                      onRemove: () => widget.onRemove?.call(e.key),
                      onToggleVisibility: () => widget.onToggleVisibility?.call(e.key),
                      onColorTap: () => widget.onColorTap?.call(e.key),
                    )),
                const SizedBox(height: DesignPanelSpacing.sm),
                // Position and Weight row
                _PositionWeightRow(
                  position: widget.strokeAlign,
                  weight: widget.strokeWeight,
                  onPositionChanged: widget.onAlignChanged,
                  onWeightChanged: widget.onWeightChanged,
                  onPerSideTap: () => setState(() => _showPerSide = !_showPerSide),
                  onAdvancedTap: widget.onAdvancedSettings,
                  perSideActive: _showPerSide,
                ),
                // Per-side weights (when expanded)
                if (_showPerSide)
                  _PerSideWeights(
                    weights: [widget.strokeWeight, widget.strokeWeight, widget.strokeWeight, widget.strokeWeight],
                    onChanged: (weights) {
                      // Apply first weight for now (could support per-side later)
                      widget.onWeightChanged?.call(weights.first);
                    },
                  ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Individual stroke item
class _StrokeItem extends StatelessWidget {
  final Map<String, dynamic> stroke;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onColorTap;

  const _StrokeItem({
    required this.stroke,
    required this.index,
    this.onRemove,
    this.onToggleVisibility,
    this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = stroke['type'] as String? ?? 'SOLID';
    final visible = stroke['visible'] ?? true;
    final opacity = (stroke['opacity'] as num?)?.toDouble() ?? 1.0;

    // Extract color
    Color color = Colors.black;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignPanelSpacing.sm),
      child: Row(
        children: [
          // Color swatch
          GestureDetector(
            onTap: onColorTap,
            child: Container(
              width: DesignPanelDimensions.colorSwatchSize,
              height: DesignPanelDimensions.colorSwatchSize,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                border: Border.all(color: color, width: 2),
              ),
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Hex value
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
                  color.value.toRadixString(16).substring(2).toUpperCase(),
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
}

/// Position and weight row with advanced buttons
class _PositionWeightRow extends StatelessWidget {
  final String position;
  final double weight;
  final ValueChanged<String>? onPositionChanged;
  final ValueChanged<double>? onWeightChanged;
  final VoidCallback? onPerSideTap;
  final VoidCallback? onAdvancedTap;
  final bool perSideActive;

  const _PositionWeightRow({
    required this.position,
    required this.weight,
    this.onPositionChanged,
    this.onWeightChanged,
    this.onPerSideTap,
    this.onAdvancedTap,
    this.perSideActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Labels
        Row(
          children: [
            const Expanded(
              child: Text(
                'Position',
                style: DesignPanelTypography.labelStyle,
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            const Expanded(
              child: Text(
                'Weight',
                style: DesignPanelTypography.labelStyle,
              ),
            ),
            const SizedBox(width: 64), // Space for buttons
          ],
        ),
        const SizedBox(height: DesignPanelSpacing.xs),
        // Inputs
        Row(
          children: [
            // Position dropdown
            Expanded(
              child: CompactDropdown(
                value: position,
                options: const ['Inside', 'Center', 'Outside'],
                onChanged: (v) {
                  onPositionChanged?.call(v.toUpperCase());
                },
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            // Weight input
            Expanded(
              child: NumericInput(
                label: '≡',
                value: weight,
                onChanged: onWeightChanged,
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            // Per-side button
            _PerSideButton(
              active: perSideActive,
              onTap: onPerSideTap,
            ),
            const SizedBox(width: DesignPanelSpacing.xs),
            // Advanced button
            _AdvancedButton(onTap: onAdvancedTap),
          ],
        ),
      ],
    );
  }
}

/// Per-side stroke toggle button
class _PerSideButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;

  const _PerSideButton({required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Individual sides',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: DesignPanelDimensions.buttonSize,
          height: DesignPanelDimensions.buttonSize,
          decoration: BoxDecoration(
            color: active
                ? DesignPanelColors.accentWithOpacity(0.2)
                : DesignPanelColors.bg1,
            borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
            border: Border.all(
              color: active ? DesignPanelColors.accent : DesignPanelColors.border,
            ),
          ),
          child: Icon(
            Icons.border_all,
            size: DesignPanelDimensions.smallIconSize,
            color: active ? DesignPanelColors.accent : DesignPanelColors.text3,
          ),
        ),
      ),
    );
  }
}

/// Advanced stroke settings button
class _AdvancedButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AdvancedButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Advanced stroke',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: DesignPanelDimensions.buttonSize,
          height: DesignPanelDimensions.buttonSize,
          decoration: BoxDecoration(
            color: DesignPanelColors.bg1,
            borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
            border: Border.all(color: DesignPanelColors.border),
          ),
          child: const Icon(
            Icons.crop_square,
            size: DesignPanelDimensions.smallIconSize,
            color: DesignPanelColors.text3,
          ),
        ),
      ),
    );
  }
}

/// Per-side weights editor
class _PerSideWeights extends StatelessWidget {
  final List<double> weights; // [top, right, bottom, left]
  final ValueChanged<List<double>>? onChanged;

  const _PerSideWeights({
    required this.weights,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DesignPanelSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: NumericInput(
              label: 'T',
              value: weights.isNotEmpty ? weights[0] : 0,
              onChanged: (v) => _updateWeight(0, v),
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.xs),
          Expanded(
            child: NumericInput(
              label: 'R',
              value: weights.length > 1 ? weights[1] : 0,
              onChanged: (v) => _updateWeight(1, v),
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.xs),
          Expanded(
            child: NumericInput(
              label: 'B',
              value: weights.length > 2 ? weights[2] : 0,
              onChanged: (v) => _updateWeight(2, v),
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.xs),
          Expanded(
            child: NumericInput(
              label: 'L',
              value: weights.length > 3 ? weights[3] : 0,
              onChanged: (v) => _updateWeight(3, v),
            ),
          ),
        ],
      ),
    );
  }

  void _updateWeight(int index, double value) {
    final newWeights = List<double>.from(weights);
    while (newWeights.length <= index) {
      newWeights.add(0);
    }
    newWeights[index] = value;
    onChanged?.call(newWeights);
  }
}
