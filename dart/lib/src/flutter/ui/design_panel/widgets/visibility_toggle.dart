/// Visibility toggle and action buttons for Design Panel
///
/// Eye icon toggle, remove button, and other common action buttons.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';

/// Eye icon visibility toggle
class VisibilityToggle extends StatelessWidget {
  final bool visible;
  final VoidCallback? onToggle;
  final double size;

  const VisibilityToggle({
    super.key,
    required this.visible,
    this.onToggle,
    this.size = DesignPanelDimensions.smallIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Icon(
        visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: size,
        color: DesignPanelColors.text3,
      ),
    );
  }
}

/// Remove/minus button
class RemoveButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const RemoveButton({
    super.key,
    this.onTap,
    this.size = DesignPanelDimensions.smallIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.remove,
        size: size,
        color: DesignPanelColors.text3,
      ),
    );
  }
}

/// Add button (+)
class AddButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const AddButton({
    super.key,
    this.onTap,
    this.size = DesignPanelDimensions.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.add,
        size: size,
        color: DesignPanelColors.text2,
      ),
    );
  }
}

/// More options button (...)
class MoreOptionsButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const MoreOptionsButton({
    super.key,
    this.onTap,
    this.size = DesignPanelDimensions.smallIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.more_horiz,
        size: size,
        color: DesignPanelColors.text3,
      ),
    );
  }
}

/// Checkbox with optional custom appearance
class FigmaCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  const FigmaCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? DesignPanelColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: value ? DesignPanelColors.accent : DesignPanelColors.border,
            width: 1,
          ),
        ),
        child: value
            ? Icon(
                Icons.check,
                size: size - 4,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

/// Row with visibility toggle and remove button
class ItemActionRow extends StatelessWidget {
  final bool visible;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onRemove;

  const ItemActionRow({
    super.key,
    required this.visible,
    this.onToggleVisibility,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VisibilityToggle(
          visible: visible,
          onToggle: onToggleVisibility,
        ),
        const SizedBox(width: DesignPanelSpacing.xs),
        RemoveButton(onTap: onRemove),
      ],
    );
  }
}

/// Icon toggle button (for selecting options)
class IconToggleButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;

  const IconToggleButton({
    super.key,
    required this.icon,
    required this.selected,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: DesignPanelDimensions.buttonSize,
        height: DesignPanelDimensions.buttonSize,
        decoration: BoxDecoration(
          color: selected
              ? DesignPanelColors.accentWithOpacity(0.2)
              : DesignPanelColors.bg1,
          borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
          border: Border.all(
            color: selected
                ? DesignPanelColors.accent
                : DesignPanelColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: DesignPanelDimensions.smallIconSize,
          color: selected ? DesignPanelColors.accent : DesignPanelColors.text2,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }
}
