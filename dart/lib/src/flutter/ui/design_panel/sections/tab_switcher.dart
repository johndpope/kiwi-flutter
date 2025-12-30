/// Tab switcher widget for Design Panel
///
/// Design/Prototype tab switcher with zoom percentage display.

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';

/// Tab type enum
enum DesignPanelTab {
  design,
  prototype,
}

/// Design/Prototype tab switcher with zoom display
class TabSwitcher extends StatelessWidget {
  final DesignPanelTab activeTab;
  final ValueChanged<DesignPanelTab>? onTabChanged;
  final double zoomLevel;
  final ValueChanged<double>? onZoomChanged;

  const TabSwitcher({
    super.key,
    required this.activeTab,
    this.onTabChanged,
    this.zoomLevel = 1.0,
    this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesignPanelDimensions.tabHeight,
      padding: const EdgeInsets.symmetric(horizontal: DesignPanelSpacing.panelPadding),
      decoration: const BoxDecoration(
        color: DesignPanelColors.bg2,
        border: Border(
          bottom: BorderSide(color: DesignPanelColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Design tab
          _TabButton(
            label: 'Design',
            isActive: activeTab == DesignPanelTab.design,
            onTap: () => onTabChanged?.call(DesignPanelTab.design),
          ),
          const SizedBox(width: DesignPanelSpacing.lg),
          // Prototype tab
          _TabButton(
            label: 'Prototype',
            isActive: activeTab == DesignPanelTab.prototype,
            onTap: () => onTabChanged?.call(DesignPanelTab.prototype),
          ),
          const Spacer(),
          // Zoom percentage
          _ZoomDropdown(
            zoomLevel: zoomLevel,
            onZoomChanged: onZoomChanged,
          ),
        ],
      ),
    );
  }
}

/// Individual tab button
class _TabButton extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DesignPanelSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? DesignPanelColors.accent
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            widget.label,
            style: widget.isActive
                ? DesignPanelTypography.tabStyle
                : (_isHovered
                    ? DesignPanelTypography.tabStyle.copyWith(
                        color: DesignPanelColors.text1,
                      )
                    : DesignPanelTypography.tabInactiveStyle),
          ),
        ),
      ),
    );
  }
}

/// Zoom percentage dropdown
class _ZoomDropdown extends StatelessWidget {
  final double zoomLevel;
  final ValueChanged<double>? onZoomChanged;

  const _ZoomDropdown({
    required this.zoomLevel,
    this.onZoomChanged,
  });

  static const _zoomPresets = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0];

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (zoomLevel * 100).round();

    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<double>(
      tooltip: 'Zoom',
      onSelected: onZoomChanged,
      offset: const Offset(0, 36),
      color: DesignPanelColors.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        side: const BorderSide(color: DesignPanelColors.border),
      ),
      itemBuilder: (context) => _zoomPresets.map((zoom) {
        return PopupMenuItem<double>(
          value: zoom,
          height: 32,
          child: Text(
            '${(zoom * 100).round()}%',
            style: TextStyle(
              color: (zoom - zoomLevel).abs() < 0.01
                  ? DesignPanelColors.accent
                  : DesignPanelColors.text1,
              fontSize: DesignPanelTypography.fontSizeMd,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignPanelSpacing.sm,
          vertical: DesignPanelSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: DesignPanelColors.bg1,
          borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
          border: Border.all(color: DesignPanelColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$zoomPercent%',
              style: DesignPanelTypography.valueStyle,
            ),
            const SizedBox(width: DesignPanelSpacing.xs),
            const Icon(
              Icons.arrow_drop_down,
              size: DesignPanelDimensions.iconSize,
              color: DesignPanelColors.text2,
            ),
          ],
        ),
      ),
    ),
    );
  }
}
