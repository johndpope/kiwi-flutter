/// Preview section for Design Panel
///
/// Collapsed section showing component/image preview.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../design_panel_icons.dart';
import '../widgets/property_row.dart';

/// Preview section widget (collapsed by default)
class PreviewSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String? componentName;
  final Uint8List? previewImage;
  final Widget? previewWidget;

  const PreviewSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    this.componentName,
    this.previewImage,
    this.previewWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsed header with chevron
        _CollapsibleHeader(
          title: 'Preview',
          expanded: expanded,
          onToggle: onToggle,
          leadingIcon: const Icon(
            DesignPanelIcons.preview,
            size: DesignPanelDimensions.smallIconSize,
            color: DesignPanelColors.text3,
          ),
        ),
        if (expanded)
          SectionContent(
            children: [
              _PreviewContent(
                componentName: componentName,
                previewImage: previewImage,
                previewWidget: previewWidget,
              ),
            ],
          ),
      ],
    );
  }
}

/// Collapsible section header with chevron
class _CollapsibleHeader extends StatefulWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? leadingIcon;

  const _CollapsibleHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.leadingIcon,
  });

  @override
  State<_CollapsibleHeader> createState() => _CollapsibleHeaderState();
}

class _CollapsibleHeaderState extends State<_CollapsibleHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          height: DesignPanelDimensions.sectionHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.panelPadding),
          decoration: BoxDecoration(
            color: _isHovered ? DesignPanelColors.bg3 : Colors.transparent,
            border: const Border(
              top: BorderSide(color: DesignPanelColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Chevron
              AnimatedRotation(
                duration: const Duration(milliseconds: 150),
                turns: widget.expanded ? 0.25 : 0,
                child: const Icon(
                  Icons.chevron_right,
                  size: DesignPanelDimensions.iconSize,
                  color: DesignPanelColors.text2,
                ),
              ),
              const SizedBox(width: DesignPanelSpacing.xs),
              // Leading icon (if provided)
              if (widget.leadingIcon != null) ...[
                widget.leadingIcon!,
                const SizedBox(width: DesignPanelSpacing.xs),
              ],
              // Title
              Text(
                widget.title,
                style: DesignPanelTypography.sectionTitleStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview content (image or placeholder)
class _PreviewContent extends StatelessWidget {
  final String? componentName;
  final Uint8List? previewImage;
  final Widget? previewWidget;

  const _PreviewContent({
    this.componentName,
    this.previewImage,
    this.previewWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (previewWidget != null) {
      return _PreviewContainer(child: previewWidget!);
    }

    if (previewImage != null) {
      return _PreviewContainer(
        child: Image.memory(
          previewImage!,
          fit: BoxFit.contain,
        ),
      );
    }

    // Placeholder when no preview
    return _PreviewPlaceholder(componentName: componentName);
  }
}

/// Preview container with consistent styling
class _PreviewContainer extends StatelessWidget {
  final Widget child;

  const _PreviewContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius - 1),
        child: child,
      ),
    );
  }
}

/// Placeholder when no preview is available
class _PreviewPlaceholder extends StatelessWidget {
  final String? componentName;

  const _PreviewPlaceholder({this.componentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_outlined,
            size: 32,
            color: DesignPanelColors.text3,
          ),
          const SizedBox(height: DesignPanelSpacing.sm),
          Text(
            componentName ?? 'No preview',
            style: const TextStyle(
              color: DesignPanelColors.text3,
              fontSize: DesignPanelTypography.fontSizeSm,
            ),
          ),
        ],
      ),
    );
  }
}

/// Help button (typically at the bottom of the panel)
class HelpButton extends StatefulWidget {
  final VoidCallback? onTap;

  const HelpButton({super.key, this.onTap});

  @override
  State<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<HelpButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(DesignPanelSpacing.md),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: DesignPanelColors.border, width: 1),
            ),
          ),
          child: Center(
            child: Container(
              width: DesignPanelDimensions.buttonSize,
              height: DesignPanelDimensions.buttonSize,
              decoration: BoxDecoration(
                color: _isHovered ? DesignPanelColors.bg3 : DesignPanelColors.bg1,
                shape: BoxShape.circle,
                border: Border.all(color: DesignPanelColors.border),
              ),
              child: const Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: DesignPanelColors.text2,
                    fontSize: DesignPanelTypography.fontSizeMd,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
