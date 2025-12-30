/// Export section for Design Panel
///
/// Export settings with scale, format, suffix, and export button.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../design_panel_icons.dart';
import '../widgets/section_header.dart';
import '../widgets/property_row.dart';
import '../widgets/visibility_toggle.dart';
import '../widgets/dropdown_button.dart';

/// Export format options for design panel
enum DesignPanelExportFormat {
  png,
  jpg,
  svg,
  pdf,
}

/// Export section widget
class ExportSection extends StatelessWidget {
  final List<Map<String, dynamic>> exports;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onAdd;
  final void Function(int index, Map<String, dynamic> changes)? onExportChanged;
  final void Function(int index)? onRemove;
  final VoidCallback? onExportContent;

  const ExportSection({
    super.key,
    required this.exports,
    required this.expanded,
    required this.onToggle,
    this.onAdd,
    this.onExportChanged,
    this.onRemove,
    this.onExportContent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeaderWithAdd(
          title: 'Export',
          expanded: expanded,
          onToggle: onToggle,
          onAdd: onAdd,
          leadingIcon: const Icon(
            DesignPanelIcons.export,
            size: DesignPanelDimensions.smallIconSize,
            color: DesignPanelColors.text3,
          ),
        ),
        if (expanded)
          SectionContent(
            children: [
              if (exports.isEmpty)
                const EmptySectionMessage(message: 'No export settings')
              else ...[
                ...exports.asMap().entries.map((e) => _ExportItem(
                      export: e.value,
                      index: e.key,
                      onChanged: (changes) => onExportChanged?.call(e.key, changes),
                      onRemove: () => onRemove?.call(e.key),
                    )),
                const SizedBox(height: DesignPanelSpacing.sm),
              ],
              // Export Content button
              _ExportButton(onTap: onExportContent),
            ],
          ),
      ],
    );
  }
}

/// Individual export setting item
class _ExportItem extends StatelessWidget {
  final Map<String, dynamic> export;
  final int index;
  final void Function(Map<String, dynamic> changes)? onChanged;
  final VoidCallback? onRemove;

  const _ExportItem({
    required this.export,
    required this.index,
    this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scale = (export['scale'] as num?)?.toDouble() ?? 1.0;
    final format = export['format'] as String? ?? 'PNG';
    final suffix = export['suffix'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignPanelSpacing.sm),
      child: Row(
        children: [
          // Scale dropdown
          Expanded(
            flex: 1,
            child: _ScaleDropdown(
              value: scale,
              onChanged: (v) {
                onChanged?.call({'scale': v});
              },
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Format dropdown
          Expanded(
            flex: 1,
            child: CompactDropdown(
              value: format,
              options: const ['PNG', 'JPG', 'SVG', 'PDF'],
              onChanged: (v) {
                onChanged?.call({'format': v});
              },
            ),
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Suffix/options button
          _SuffixButton(
            suffix: suffix,
            onTap: () {
              // Open suffix/options dialog
            },
          ),
          const SizedBox(width: DesignPanelSpacing.sm),

          // Remove button
          RemoveButton(onTap: onRemove),
        ],
      ),
    );
  }
}

/// Scale dropdown (1x, 2x, 3x, 0.5x, etc.)
class _ScaleDropdown extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const _ScaleDropdown({
    required this.value,
    this.onChanged,
  });

  static const _scalePresets = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0];

  String _formatScale(double scale) {
    if (scale == scale.toInt()) {
      return '${scale.toInt()}x';
    }
    return '${scale}x';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Scale',
      onSelected: onChanged,
      offset: const Offset(0, 32),
      color: DesignPanelColors.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        side: const BorderSide(color: DesignPanelColors.border),
      ),
      itemBuilder: (context) => _scalePresets.map((scale) {
        return PopupMenuItem<double>(
          value: scale,
          height: 32,
          child: Text(
            _formatScale(scale),
            style: TextStyle(
              color: (scale - value).abs() < 0.01
                  ? DesignPanelColors.accent
                  : DesignPanelColors.text1,
              fontSize: DesignPanelTypography.fontSizeMd,
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: DesignPanelDimensions.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.sm),
        decoration: BoxDecoration(
          color: DesignPanelColors.bg1,
          borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
          border: Border.all(color: DesignPanelColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatScale(value),
              style: DesignPanelTypography.valueStyle,
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: DesignPanelDimensions.iconSize,
              color: DesignPanelColors.text2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Suffix/options button (three dots)
class _SuffixButton extends StatefulWidget {
  final String suffix;
  final VoidCallback? onTap;

  const _SuffixButton({
    required this.suffix,
    this.onTap,
  });

  @override
  State<_SuffixButton> createState() => _SuffixButtonState();
}

class _SuffixButtonState extends State<_SuffixButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: 'Export settings',
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: DesignPanelDimensions.buttonSize,
            height: DesignPanelDimensions.buttonSize,
            decoration: BoxDecoration(
              color: _isHovered ? DesignPanelColors.bg3 : DesignPanelColors.bg1,
              borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
              border: Border.all(color: DesignPanelColors.border),
            ),
            child: const Icon(
              Icons.more_horiz,
              size: DesignPanelDimensions.smallIconSize,
              color: DesignPanelColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Export Content button
class _ExportButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _ExportButton({this.onTap});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          height: DesignPanelDimensions.buttonHeight,
          decoration: BoxDecoration(
            color: _isHovered ? DesignPanelColors.bg3 : DesignPanelColors.bg1,
            borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
            border: Border.all(color: DesignPanelColors.border),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Export Content',
            style: TextStyle(
              color: DesignPanelColors.text1,
              fontSize: DesignPanelTypography.fontSizeMd,
            ),
          ),
        ),
      ),
    );
  }
}

/// Export options dialog
class ExportOptionsDialog extends StatelessWidget {
  final Map<String, dynamic> exportSettings;
  final void Function(Map<String, dynamic> changes)? onChanged;
  final VoidCallback? onClose;

  const ExportOptionsDialog({
    super.key,
    required this.exportSettings,
    this.onChanged,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = exportSettings['suffix'] as String? ?? '';
    final contentsOnly = exportSettings['contentsOnly'] ?? false;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(DesignPanelSpacing.md),
      decoration: BoxDecoration(
        color: DesignPanelColors.bg2,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius * 2),
        border: Border.all(color: DesignPanelColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Export options',
                style: TextStyle(
                  color: DesignPanelColors.text1,
                  fontSize: DesignPanelTypography.fontSizeMd,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close,
                  size: DesignPanelDimensions.iconSize,
                  color: DesignPanelColors.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignPanelSpacing.md),

          // Suffix input
          const Text('Suffix', style: DesignPanelTypography.labelStyle),
          const SizedBox(height: DesignPanelSpacing.xs),
          Container(
            height: DesignPanelDimensions.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.sm),
            decoration: BoxDecoration(
              color: DesignPanelColors.bg1,
              borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
              border: Border.all(color: DesignPanelColors.border),
            ),
            child: TextField(
              controller: TextEditingController(text: suffix),
              style: DesignPanelTypography.valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'e.g. @2x',
                hintStyle: TextStyle(color: DesignPanelColors.text3),
                isDense: true,
              ),
              onSubmitted: (text) {
                onChanged?.call({'suffix': text});
              },
            ),
          ),
          const SizedBox(height: DesignPanelSpacing.md),

          // Contents only checkbox
          Row(
            children: [
              FigmaCheckbox(
                value: contentsOnly,
                onChanged: (v) {
                  onChanged?.call({'contentsOnly': v});
                },
              ),
              const SizedBox(width: DesignPanelSpacing.sm),
              const Text(
                'Contents only',
                style: TextStyle(
                  color: DesignPanelColors.text1,
                  fontSize: DesignPanelTypography.fontSizeMd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
