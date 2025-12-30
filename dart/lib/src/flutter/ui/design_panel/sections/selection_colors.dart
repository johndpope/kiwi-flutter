/// Selection colors section for Design Panel
///
/// Shows colors used in the current selection with a button to reveal all.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../design_panel_icons.dart';
import '../widgets/section_header.dart';
import '../widgets/property_row.dart';

/// Selection colors section widget
class SelectionColorsSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onShowSelectionColors;
  final List<Color>? selectionColors;

  const SelectionColorsSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    this.onShowSelectionColors,
    this.selectionColors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Selection colors',
          expanded: expanded,
          onToggle: onToggle,
          leadingIcon: const Icon(
            DesignPanelIcons.selectionColors,
            size: DesignPanelDimensions.smallIconSize,
            color: DesignPanelColors.text3,
          ),
        ),
        if (expanded)
          SectionContent(
            children: [
              // Show selection colors button
              _SelectionColorsButton(
                onTap: onShowSelectionColors,
              ),
              // Color swatches (if colors are provided)
              if (selectionColors != null && selectionColors!.isNotEmpty) ...[
                const SizedBox(height: DesignPanelSpacing.sm),
                _ColorSwatches(colors: selectionColors!),
              ],
            ],
          ),
      ],
    );
  }
}

/// "Show selection colors" button
class _SelectionColorsButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _SelectionColorsButton({this.onTap});

  @override
  State<_SelectionColorsButton> createState() => _SelectionColorsButtonState();
}

class _SelectionColorsButtonState extends State<_SelectionColorsButton> {
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
            'Show selection colors',
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

/// Color swatches grid
class _ColorSwatches extends StatelessWidget {
  final List<Color> colors;

  const _ColorSwatches({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DesignPanelSpacing.xs,
      runSpacing: DesignPanelSpacing.xs,
      children: colors.map((color) => _ColorSwatch(color: color)).toList(),
    );
  }
}

/// Individual color swatch
class _ColorSwatch extends StatefulWidget {
  final Color color;
  final VoidCallback? onTap;

  const _ColorSwatch({
    required this.color,
    this.onTap,
  });

  @override
  State<_ColorSwatch> createState() => _ColorSwatchState();
}

class _ColorSwatchState extends State<_ColorSwatch> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: '#${widget.color.value.toRadixString(16).substring(2).toUpperCase()}',
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: DesignPanelDimensions.colorSwatchSize,
            height: DesignPanelDimensions.colorSwatchSize,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
              border: Border.all(
                color: _isHovered ? DesignPanelColors.accent : DesignPanelColors.border,
                width: _isHovered ? 2 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection colors overlay/popup
class SelectionColorsOverlay extends StatelessWidget {
  final List<Color> colors;
  final void Function(Color color)? onColorSelected;
  final VoidCallback? onClose;

  const SelectionColorsOverlay({
    super.key,
    required this.colors,
    this.onColorSelected,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
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
                'Selection colors',
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

          // Color grid
          if (colors.isEmpty)
            const Text(
              'No colors in selection',
              style: TextStyle(
                color: DesignPanelColors.text3,
                fontSize: DesignPanelTypography.fontSizeSm,
              ),
            )
          else
            Wrap(
              spacing: DesignPanelSpacing.sm,
              runSpacing: DesignPanelSpacing.sm,
              children: colors.map((color) {
                return _SelectableColorSwatch(
                  color: color,
                  onTap: () => onColorSelected?.call(color),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Selectable color swatch with hex value
class _SelectableColorSwatch extends StatefulWidget {
  final Color color;
  final VoidCallback? onTap;

  const _SelectableColorSwatch({
    required this.color,
    this.onTap,
  });

  @override
  State<_SelectableColorSwatch> createState() => _SelectableColorSwatchState();
}

class _SelectableColorSwatchState extends State<_SelectableColorSwatch> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hex = widget.color.value.toRadixString(16).substring(2).toUpperCase();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 68,
          padding: const EdgeInsets.all(DesignPanelSpacing.xs),
          decoration: BoxDecoration(
            color: _isHovered ? DesignPanelColors.bg3 : DesignPanelColors.bg1,
            borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
            border: Border.all(
              color: _isHovered ? DesignPanelColors.accent : DesignPanelColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
                ),
              ),
              const SizedBox(height: DesignPanelSpacing.xs),
              Text(
                hex,
                style: const TextStyle(
                  color: DesignPanelColors.text2,
                  fontSize: DesignPanelTypography.fontSizeSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
