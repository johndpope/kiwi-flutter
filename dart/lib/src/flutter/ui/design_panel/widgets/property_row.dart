/// Property row widget for Design Panel
///
/// Reusable row layouts for property editing.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';

/// Row with label and value widget
class PropertyRow extends StatelessWidget {
  final String? label;
  final Widget child;
  final double labelWidth;

  const PropertyRow({
    super.key,
    this.label,
    required this.child,
    this.labelWidth = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null) ...[
          SizedBox(
            width: labelWidth,
            child: Text(
              label!,
              style: DesignPanelTypography.labelStyle,
            ),
          ),
        ],
        Expanded(child: child),
      ],
    );
  }
}

/// Two-column property row (common pattern)
class TwoColumnRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double gap;

  const TwoColumnRow({
    super.key,
    required this.left,
    required this.right,
    this.gap = DesignPanelSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        SizedBox(width: gap),
        Expanded(child: right),
      ],
    );
  }
}

/// Color swatch with hex value and opacity
class ColorPropertyRow extends StatelessWidget {
  final Color color;
  final double opacity;
  final VoidCallback? onColorTap;
  final ValueChanged<double>? onOpacityChanged;
  final Widget? trailing;

  const ColorPropertyRow({
    super.key,
    required this.color,
    this.opacity = 1.0,
    this.onColorTap,
    this.onOpacityChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hex = color.value.toRadixString(16).substring(2).toUpperCase();

    return Row(
      children: [
        // Color swatch
        GestureDetector(
          onTap: onColorTap,
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
                hex,
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
            padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.sm),
            decoration: BoxDecoration(
              color: DesignPanelColors.bg1,
              borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
              border: Border.all(color: DesignPanelColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${(opacity * 100).toInt()}',
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

        if (trailing != null) ...[
          const SizedBox(width: DesignPanelSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// Section content wrapper with padding
class SectionContent extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;

  const SectionContent({
    super.key,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            DesignPanelSpacing.panelPadding,
            0,
            DesignPanelSpacing.panelPadding,
            DesignPanelSpacing.sectionPadding,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Empty state message for sections
class EmptySectionMessage extends StatelessWidget {
  final String message;

  const EmptySectionMessage({
    super.key,
    this.message = 'None',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignPanelSpacing.sm),
      child: Text(
        message,
        style: const TextStyle(
          color: DesignPanelColors.text3,
          fontSize: DesignPanelTypography.fontSizeMd,
        ),
      ),
    );
  }
}
