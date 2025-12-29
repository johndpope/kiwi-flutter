/// Layout guide section for Design Panel
///
/// Grid, columns, and rows layout guides with visibility and editing.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/property_row.dart';
import '../widgets/visibility_toggle.dart';
import '../widgets/dropdown_button.dart';
import '../widgets/icon_input.dart';

/// Layout guide types
enum LayoutGuideType {
  grid,
  columns,
  rows,
}

/// Layout guide section widget
class LayoutGuideSection extends StatelessWidget {
  final List<Map<String, dynamic>> guides;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onAdd;
  final VoidCallback? onGridSettings;
  final void Function(int index, Map<String, dynamic> changes)? onGuideChanged;
  final void Function(int index)? onRemove;
  final void Function(int index)? onToggleVisibility;
  final void Function(int index)? onEditGuide;

  const LayoutGuideSection({
    super.key,
    required this.guides,
    required this.expanded,
    required this.onToggle,
    this.onAdd,
    this.onGridSettings,
    this.onGuideChanged,
    this.onRemove,
    this.onToggleVisibility,
    this.onEditGuide,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeaderWithGrid(
          title: 'Layout guide',
          expanded: expanded,
          onToggle: onToggle,
          onGridSettings: onGridSettings,
          onAdd: onAdd,
        ),
        if (expanded)
          SectionContent(
            children: guides.isEmpty
                ? [const EmptySectionMessage(message: 'No layout guides')]
                : guides
                    .asMap()
                    .entries
                    .map((e) => _LayoutGuideItem(
                          guide: e.value,
                          index: e.key,
                          onChanged: (changes) => onGuideChanged?.call(e.key, changes),
                          onRemove: () => onRemove?.call(e.key),
                          onToggleVisibility: () => onToggleVisibility?.call(e.key),
                          onEdit: () => onEditGuide?.call(e.key),
                        ))
                    .toList(),
          ),
      ],
    );
  }
}

/// Individual layout guide item
class _LayoutGuideItem extends StatelessWidget {
  final Map<String, dynamic> guide;
  final int index;
  final void Function(Map<String, dynamic> changes)? onChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onEdit;

  const _LayoutGuideItem({
    required this.guide,
    required this.index,
    this.onChanged,
    this.onRemove,
    this.onToggleVisibility,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final type = guide['type'] as String? ?? 'GRID';
    final visible = guide['visible'] ?? true;
    final size = (guide['size'] as num?)?.toDouble() ?? 10.0;
    final count = (guide['count'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignPanelSpacing.sm),
      child: Row(
        children: [
          // Grid icon
          _GridTypeIcon(type: type),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Type and size dropdown/input
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              child: CompactDropdown(
                value: _getGuideLabel(type, size, count),
                options: const ['Grid 8px', 'Grid 10px', 'Grid 12px', 'Columns', 'Rows'],
                onChanged: (value) {
                  if (value.startsWith('Grid')) {
                    final px = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
                    onChanged?.call({'type': 'GRID', 'size': px.toDouble()});
                  } else if (value == 'Columns') {
                    onChanged?.call({'type': 'COLUMNS', 'count': 12});
                  } else if (value == 'Rows') {
                    onChanged?.call({'type': 'ROWS', 'count': 4});
                  }
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

  String _getGuideLabel(String type, double size, int? count) {
    switch (type) {
      case 'GRID':
        return 'Grid ${size.toInt()}px';
      case 'COLUMNS':
        return count != null ? 'Columns ($count)' : 'Columns';
      case 'ROWS':
        return count != null ? 'Rows ($count)' : 'Rows';
      default:
        return type;
    }
  }
}

/// Grid type icon (grid, columns, rows)
class _GridTypeIcon extends StatelessWidget {
  final String type;

  const _GridTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case 'COLUMNS':
        icon = Icons.view_column_outlined;
        break;
      case 'ROWS':
        icon = Icons.table_rows_outlined;
        break;
      case 'GRID':
      default:
        icon = Icons.grid_4x4;
        break;
    }

    return Container(
      width: DesignPanelDimensions.colorSwatchSize,
      height: DesignPanelDimensions.colorSwatchSize,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: Icon(
        icon,
        size: DesignPanelDimensions.smallIconSize,
        color: DesignPanelColors.text2,
      ),
    );
  }
}

/// Layout guide editor (expanded view for detailed settings)
class LayoutGuideEditor extends StatelessWidget {
  final Map<String, dynamic> guide;
  final void Function(Map<String, dynamic> changes)? onChanged;

  const LayoutGuideEditor({
    super.key,
    required this.guide,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final type = guide['type'] as String? ?? 'GRID';

    if (type == 'GRID') {
      return _GridEditor(guide: guide, onChanged: onChanged);
    } else {
      return _ColumnsRowsEditor(guide: guide, onChanged: onChanged);
    }
  }
}

/// Grid editor (size, color)
class _GridEditor extends StatelessWidget {
  final Map<String, dynamic> guide;
  final void Function(Map<String, dynamic> changes)? onChanged;

  const _GridEditor({
    required this.guide,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = (guide['size'] as num?)?.toDouble() ?? 10.0;
    final color = _extractColor(guide);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignPanelSpacing.panelPadding,
        0,
        DesignPanelSpacing.panelPadding,
        DesignPanelSpacing.sm,
      ),
      child: Column(
        children: [
          // Size row
          Row(
            children: [
              const Text('Size', style: DesignPanelTypography.labelStyle),
              const SizedBox(width: DesignPanelSpacing.md),
              Expanded(
                child: NumericInput(
                  label: '',
                  value: size,
                  suffix: 'px',
                  onChanged: (v) {
                    onChanged?.call({'size': v});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignPanelSpacing.sm),
          // Color row
          Row(
            children: [
              const Text('Color', style: DesignPanelTypography.labelStyle),
              const SizedBox(width: DesignPanelSpacing.md),
              Container(
                width: DesignPanelDimensions.colorSwatchSize,
                height: DesignPanelDimensions.colorSwatchSize,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                  border: Border.all(color: DesignPanelColors.border),
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              Expanded(
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
            ],
          ),
        ],
      ),
    );
  }

  Color _extractColor(Map<String, dynamic> guide) {
    final c = guide['color'] as Map<String, dynamic>?;
    if (c != null) {
      return Color.fromRGBO(
        ((c['r'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
        ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
        (c['a'] as num?)?.toDouble() ?? 0.1,
      );
    }
    return Colors.red.withOpacity(0.1);
  }
}

/// Columns/Rows editor (count, gutter, margin, offset)
class _ColumnsRowsEditor extends StatelessWidget {
  final Map<String, dynamic> guide;
  final void Function(Map<String, dynamic> changes)? onChanged;

  const _ColumnsRowsEditor({
    required this.guide,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = (guide['count'] as num?)?.toInt() ?? 12;
    final gutter = (guide['gutter'] as num?)?.toDouble() ?? 20.0;
    final margin = (guide['margin'] as num?)?.toDouble() ?? 20.0;
    final color = _extractColor(guide);
    final type = guide['type'] as String? ?? 'COLUMNS';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignPanelSpacing.panelPadding,
        0,
        DesignPanelSpacing.panelPadding,
        DesignPanelSpacing.sm,
      ),
      child: Column(
        children: [
          // Count and gutter
          Row(
            children: [
              Expanded(
                child: NumericInput(
                  label: type == 'COLUMNS' ? '#' : '#',
                  value: count.toDouble(),
                  onChanged: (v) {
                    onChanged?.call({'count': v.toInt()});
                  },
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.xs),
              Expanded(
                child: NumericInput(
                  label: 'G',
                  value: gutter,
                  onChanged: (v) {
                    onChanged?.call({'gutter': v});
                  },
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.xs),
              Expanded(
                child: NumericInput(
                  label: 'M',
                  value: margin,
                  onChanged: (v) {
                    onChanged?.call({'margin': v});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignPanelSpacing.sm),
          // Color row
          Row(
            children: [
              Container(
                width: DesignPanelDimensions.colorSwatchSize,
                height: DesignPanelDimensions.colorSwatchSize,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                  border: Border.all(color: DesignPanelColors.border),
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              Expanded(
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
              PercentageInput(
                value: color.opacity,
                onChanged: (v) {
                  // Update opacity
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _extractColor(Map<String, dynamic> guide) {
    final c = guide['color'] as Map<String, dynamic>?;
    if (c != null) {
      return Color.fromRGBO(
        ((c['r'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
        ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
        (c['a'] as num?)?.toDouble() ?? 0.1,
      );
    }
    return Colors.red.withOpacity(0.1);
  }
}
