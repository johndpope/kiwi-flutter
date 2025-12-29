/// Dropdown button widget for Design Panel
///
/// Styled dropdown matching Figma's design system.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';

/// Styled dropdown button
class FigmaDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double? width;
  final bool enabled;

  const FigmaDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.width,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: DesignPanelDimensions.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.sm),
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        dropdownColor: DesignPanelColors.bg2,
        isDense: true,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(
          Icons.arrow_drop_down,
          size: DesignPanelDimensions.iconSize,
          color: DesignPanelColors.text2,
        ),
        style: DesignPanelTypography.valueStyle,
      ),
    );
  }
}

/// Dropdown item with icon
class FigmaDropdownItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;

  const FigmaDropdownItem({
    super.key,
    this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: DesignPanelDimensions.smallIconSize,
            color: selected
                ? DesignPanelColors.accent
                : DesignPanelColors.text2,
          ),
          const SizedBox(width: DesignPanelSpacing.sm),
        ],
        Text(
          label,
          style: TextStyle(
            color: selected
                ? DesignPanelColors.accent
                : DesignPanelColors.text1,
            fontSize: DesignPanelTypography.fontSizeMd,
          ),
        ),
      ],
    );
  }
}

/// Simple text dropdown for common use cases
class TextDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String>? onChanged;
  final double? width;

  const TextDropdown({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return FigmaDropdown<String>(
      value: options.contains(value) ? value : options.first,
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            option,
            style: DesignPanelTypography.valueStyle,
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged?.call(v);
      },
      width: width,
    );
  }
}

/// Compact dropdown for inline use (e.g., position selectors)
class CompactDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String>? onChanged;

  const CompactDropdown({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignPanelSpacing.sm,
        vertical: DesignPanelSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: DropdownButton<String>(
        value: options.contains(value) ? value : options.first,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
              style: const TextStyle(
                color: DesignPanelColors.text1,
                fontSize: DesignPanelTypography.fontSizeSm,
              ),
            ),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) onChanged?.call(v);
        },
        dropdownColor: DesignPanelColors.bg2,
        isDense: true,
        underline: const SizedBox(),
        icon: const Icon(
          Icons.arrow_drop_down,
          size: 14,
          color: DesignPanelColors.text2,
        ),
        style: const TextStyle(
          color: DesignPanelColors.text1,
          fontSize: DesignPanelTypography.fontSizeSm,
        ),
      ),
    );
  }
}
