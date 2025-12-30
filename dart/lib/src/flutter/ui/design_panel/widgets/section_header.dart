/// Section header widget for Design Panel
///
/// Displays expandable section headers with optional trailing actions.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../design_panel_icons.dart';

/// A collapsible section header matching Figma's design
class SectionHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? trailing;
  final Widget? leadingIcon;
  final bool showDivider;

  const SectionHeader({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.trailing,
    this.leadingIcon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      hoverColor: DesignPanelColors.bg3.withOpacity(0.5),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignPanelSpacing.panelPadding,
          vertical: DesignPanelSpacing.sectionPadding,
        ),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: DesignPanelColors.border,
                    width: 1,
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: DesignPanelDimensions.iconSize,
              color: DesignPanelColors.text2,
            ),
            const SizedBox(width: DesignPanelSpacing.xs),
            if (leadingIcon != null) ...[
              leadingIcon!,
              const SizedBox(width: DesignPanelSpacing.xs),
            ],
            Text(title, style: DesignPanelTypography.headerStyle),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Section header with add button (most common pattern)
class SectionHeaderWithAdd extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onAdd;
  final Widget? extraActions;
  final Widget? leadingIcon;
  final bool showDivider;

  const SectionHeaderWithAdd({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.onAdd,
    this.extraActions,
    this.leadingIcon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      title: title,
      expanded: expanded,
      onToggle: onToggle,
      showDivider: showDivider,
      leadingIcon: leadingIcon,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (extraActions != null) ...[
            extraActions!,
            const SizedBox(width: DesignPanelSpacing.xs),
          ],
          if (onAdd != null)
            _AddButton(onTap: onAdd!),
        ],
      ),
    );
  }
}

/// Section header with grid icon and add button (Stroke, Effects, Layout guide)
class SectionHeaderWithGrid extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onGridSettings;
  final VoidCallback? onAdd;
  final Widget? leadingIcon;
  final bool showDivider;

  const SectionHeaderWithGrid({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.onGridSettings,
    this.onAdd,
    this.leadingIcon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      title: title,
      expanded: expanded,
      onToggle: onToggle,
      showDivider: showDivider,
      leadingIcon: leadingIcon,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onGridSettings != null)
            _IconButton(
              icon: Icons.grid_view,
              onTap: onGridSettings!,
            ),
          if (onAdd != null) ...[
            const SizedBox(width: DesignPanelSpacing.xs),
            _AddButton(onTap: onAdd!),
          ],
        ],
      ),
    );
  }
}

/// Simple add button (+)
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(
        Icons.add,
        size: DesignPanelDimensions.iconSize,
        color: DesignPanelColors.text2,
      ),
    );
  }
}

/// Simple icon button
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: DesignPanelDimensions.smallIconSize,
        color: DesignPanelColors.text3,
      ),
    );
  }
}
