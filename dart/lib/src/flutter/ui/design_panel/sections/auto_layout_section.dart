/// Auto Layout Section for the Figma Design Panel
///
/// Provides full auto-layout controls matching Figma's UI:
/// - Flow direction (vertical, horizontal, wrap, grid)
/// - Resizing (Hug, Fill, Fixed for width/height)
/// - Alignment 9-point grid
/// - Gap (spacing between items)
/// - Padding (top/right/bottom/left or symmetric)
/// - Clip content toggle

import 'package:flutter/material.dart';
import '../design_panel_colors.dart';
import '../widgets/section_header.dart';

/// Sizing mode for auto layout
enum AutoLayoutSizing {
  hug,
  fill,
  fixed,
}

/// Auto Layout section widget
class AutoLayoutSection extends StatefulWidget {
  /// Whether this node has auto layout
  final bool hasAutoLayout;

  /// Flow direction: 'NONE', 'VERTICAL', 'HORIZONTAL', 'WRAP', 'GRID'
  final String layoutMode;

  /// Width in pixels
  final double width;

  /// Height in pixels
  final double height;

  /// Width sizing mode
  final AutoLayoutSizing widthSizing;

  /// Height sizing mode
  final AutoLayoutSizing heightSizing;

  /// Main axis alignment: 'MIN', 'CENTER', 'MAX', 'SPACE_BETWEEN'
  final String mainAxisAlign;

  /// Cross axis alignment: 'MIN', 'CENTER', 'MAX', 'BASELINE'
  final String crossAxisAlign;

  /// Gap (spacing) between items
  final double gap;

  /// Padding top
  final double paddingTop;

  /// Padding right
  final double paddingRight;

  /// Padding bottom
  final double paddingBottom;

  /// Padding left
  final double paddingLeft;

  /// Whether to clip overflow content
  final bool clipContent;

  /// Section expanded state
  final bool expanded;

  /// Toggle expanded callback
  final VoidCallback? onToggle;

  /// Add auto layout callback
  final VoidCallback? onAddAutoLayout;

  /// Remove auto layout callback
  final VoidCallback? onRemoveAutoLayout;

  /// Layout mode changed callback
  final ValueChanged<String>? onLayoutModeChanged;

  /// Width changed callback
  final ValueChanged<double>? onWidthChanged;

  /// Height changed callback
  final ValueChanged<double>? onHeightChanged;

  /// Width sizing changed callback
  final ValueChanged<AutoLayoutSizing>? onWidthSizingChanged;

  /// Height sizing changed callback
  final ValueChanged<AutoLayoutSizing>? onHeightSizingChanged;

  /// Main axis alignment changed callback
  final ValueChanged<String>? onMainAxisAlignChanged;

  /// Cross axis alignment changed callback
  final ValueChanged<String>? onCrossAxisAlignChanged;

  /// Gap changed callback
  final ValueChanged<double>? onGapChanged;

  /// Padding changed callback
  final void Function(double top, double right, double bottom, double left)?
      onPaddingChanged;

  /// Clip content changed callback
  final ValueChanged<bool>? onClipContentChanged;

  const AutoLayoutSection({
    super.key,
    this.hasAutoLayout = false,
    this.layoutMode = 'NONE',
    this.width = 100,
    this.height = 100,
    this.widthSizing = AutoLayoutSizing.hug,
    this.heightSizing = AutoLayoutSizing.hug,
    this.mainAxisAlign = 'MIN',
    this.crossAxisAlign = 'MIN',
    this.gap = 0,
    this.paddingTop = 0,
    this.paddingRight = 0,
    this.paddingBottom = 0,
    this.paddingLeft = 0,
    this.clipContent = true,
    this.expanded = true,
    this.onToggle,
    this.onAddAutoLayout,
    this.onRemoveAutoLayout,
    this.onLayoutModeChanged,
    this.onWidthChanged,
    this.onHeightChanged,
    this.onWidthSizingChanged,
    this.onHeightSizingChanged,
    this.onMainAxisAlignChanged,
    this.onCrossAxisAlignChanged,
    this.onGapChanged,
    this.onPaddingChanged,
    this.onClipContentChanged,
  });

  @override
  State<AutoLayoutSection> createState() => _AutoLayoutSectionState();
}

class _AutoLayoutSectionState extends State<AutoLayoutSection> {
  bool _showIndividualPadding = false;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _gapController;
  late TextEditingController _paddingHController;
  late TextEditingController _paddingVController;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(text: widget.width.toInt().toString());
    _heightController = TextEditingController(text: widget.height.toInt().toString());
    _gapController = TextEditingController(text: widget.gap.toInt().toString());
    _paddingHController = TextEditingController(
        text: widget.paddingLeft.toInt().toString());
    _paddingVController = TextEditingController(
        text: widget.paddingTop.toInt().toString());
  }

  @override
  void didUpdateWidget(AutoLayoutSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width) {
      _widthController.text = widget.width.toInt().toString();
    }
    if (oldWidget.height != widget.height) {
      _heightController.text = widget.height.toInt().toString();
    }
    if (oldWidget.gap != widget.gap) {
      _gapController.text = widget.gap.toInt().toString();
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _gapController.dispose();
    _paddingHController.dispose();
    _paddingVController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section header with auto layout toggle
        SectionHeader(
          icon: _AutoLayoutIcon(),
          title: 'Auto layout',
          expanded: widget.expanded,
          onToggle: widget.onToggle,
          trailing: _buildAutoLayoutToggle(),
        ),
        if (widget.expanded && widget.hasAutoLayout) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignPanelSpacing.panelPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flow direction row
                _buildFlowRow(),
                const SizedBox(height: DesignPanelSpacing.md),

                // Resizing row
                _buildResizingRow(),
                const SizedBox(height: DesignPanelSpacing.md),

                // Alignment and Gap row
                _buildAlignmentGapRow(),
                const SizedBox(height: DesignPanelSpacing.md),

                // Padding row
                _buildPaddingRow(),
                const SizedBox(height: DesignPanelSpacing.md),

                // Clip content
                _buildClipContentRow(),
                const SizedBox(height: DesignPanelSpacing.sm),
              ],
            ),
          ),
        ],
        const Divider(color: DesignPanelColors.border, height: 1),
      ],
    );
  }

  Widget _buildAutoLayoutToggle() {
    return GestureDetector(
      onTap: widget.hasAutoLayout
          ? widget.onRemoveAutoLayout
          : widget.onAddAutoLayout,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: widget.hasAutoLayout
              ? DesignPanelColors.accent
              : DesignPanelColors.bg1,
          borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        ),
        child: Icon(
          widget.hasAutoLayout ? Icons.grid_view : Icons.add,
          size: 16,
          color: widget.hasAutoLayout ? Colors.white : DesignPanelColors.text2,
        ),
      ),
    );
  }

  Widget _buildFlowRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Flow', style: DesignPanelTypography.labelStyle),
        const SizedBox(height: DesignPanelSpacing.xs),
        Row(
          children: [
            // Flow direction buttons
            Expanded(
              child: Row(
                children: [
                  _FlowButton(
                    icon: _VerticalStackIcon(),
                    selected: widget.layoutMode == 'VERTICAL',
                    onTap: () => widget.onLayoutModeChanged?.call('VERTICAL'),
                  ),
                  const SizedBox(width: 2),
                  _FlowButton(
                    icon: _VerticalDownIcon(),
                    selected: widget.layoutMode == 'VERTICAL_DOWN',
                    onTap: () => widget.onLayoutModeChanged?.call('VERTICAL_DOWN'),
                  ),
                  const SizedBox(width: 2),
                  _FlowButton(
                    icon: _HorizontalIcon(),
                    selected: widget.layoutMode == 'HORIZONTAL',
                    onTap: () => widget.onLayoutModeChanged?.call('HORIZONTAL'),
                  ),
                  const SizedBox(width: 2),
                  _FlowButton(
                    icon: _GridIcon(),
                    selected: widget.layoutMode == 'GRID',
                    onTap: () => widget.onLayoutModeChanged?.call('GRID'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            // Wrap toggle
            _FlowButton(
              icon: _WrapIcon(),
              selected: widget.layoutMode == 'WRAP',
              onTap: () => widget.onLayoutModeChanged?.call(
                widget.layoutMode == 'WRAP' ? 'HORIZONTAL' : 'WRAP',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResizingRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resizing', style: DesignPanelTypography.labelStyle),
        const SizedBox(height: DesignPanelSpacing.xs),
        Row(
          children: [
            // Width field
            Expanded(
              child: _SizingField(
                label: 'W',
                value: widget.width,
                sizing: widget.widthSizing,
                controller: _widthController,
                onValueChanged: widget.onWidthChanged,
                onSizingChanged: widget.onWidthSizingChanged,
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            // Height field
            Expanded(
              child: _SizingField(
                label: 'H',
                value: widget.height,
                sizing: widget.heightSizing,
                controller: _heightController,
                onValueChanged: widget.onHeightChanged,
                onSizingChanged: widget.onHeightSizingChanged,
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            // Aspect ratio lock button
            _IconButton(
              icon: Icons.aspect_ratio,
              onTap: () {}, // TODO: Implement aspect ratio lock
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlignmentGapRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alignment 9-grid
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alignment', style: DesignPanelTypography.labelStyle),
            const SizedBox(height: DesignPanelSpacing.xs),
            _AlignmentGrid(
              mainAxisAlign: widget.mainAxisAlign,
              crossAxisAlign: widget.crossAxisAlign,
              onAlignmentChanged: (main, cross) {
                widget.onMainAxisAlignChanged?.call(main);
                widget.onCrossAxisAlignChanged?.call(cross);
              },
            ),
          ],
        ),
        const SizedBox(width: DesignPanelSpacing.md),
        // Gap field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gap', style: DesignPanelTypography.labelStyle),
              const SizedBox(height: DesignPanelSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _NumericInputField(
                      icon: _GapIcon(),
                      controller: _gapController,
                      onChanged: (v) => widget.onGapChanged?.call(v),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _IconButton(
                    icon: Icons.more_vert,
                    onTap: () {}, // TODO: Gap options menu
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaddingRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Padding', style: DesignPanelTypography.labelStyle),
        const SizedBox(height: DesignPanelSpacing.xs),
        Row(
          children: [
            // Horizontal padding
            Expanded(
              child: _NumericInputField(
                icon: _PaddingHIcon(),
                controller: _paddingHController,
                onChanged: (v) => widget.onPaddingChanged?.call(
                  widget.paddingTop,
                  v,
                  widget.paddingBottom,
                  v,
                ),
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            // Vertical padding
            Expanded(
              child: _NumericInputField(
                icon: _PaddingVIcon(),
                controller: _paddingVController,
                onChanged: (v) => widget.onPaddingChanged?.call(
                  v,
                  widget.paddingRight,
                  v,
                  widget.paddingLeft,
                ),
              ),
            ),
            const SizedBox(width: DesignPanelSpacing.sm),
            // Expand to individual padding
            _IconButton(
              icon: _showIndividualPadding ? Icons.unfold_less : Icons.unfold_more,
              onTap: () => setState(() => _showIndividualPadding = !_showIndividualPadding),
            ),
          ],
        ),
        // Individual padding fields
        if (_showIndividualPadding) ...[
          const SizedBox(height: DesignPanelSpacing.sm),
          _buildIndividualPaddingRow(),
        ],
      ],
    );
  }

  Widget _buildIndividualPaddingRow() {
    return Row(
      children: [
        _SmallNumericField(
          label: 'T',
          value: widget.paddingTop,
          onChanged: (v) => widget.onPaddingChanged?.call(
            v,
            widget.paddingRight,
            widget.paddingBottom,
            widget.paddingLeft,
          ),
        ),
        const SizedBox(width: 4),
        _SmallNumericField(
          label: 'R',
          value: widget.paddingRight,
          onChanged: (v) => widget.onPaddingChanged?.call(
            widget.paddingTop,
            v,
            widget.paddingBottom,
            widget.paddingLeft,
          ),
        ),
        const SizedBox(width: 4),
        _SmallNumericField(
          label: 'B',
          value: widget.paddingBottom,
          onChanged: (v) => widget.onPaddingChanged?.call(
            widget.paddingTop,
            widget.paddingRight,
            v,
            widget.paddingLeft,
          ),
        ),
        const SizedBox(width: 4),
        _SmallNumericField(
          label: 'L',
          value: widget.paddingLeft,
          onChanged: (v) => widget.onPaddingChanged?.call(
            widget.paddingTop,
            widget.paddingRight,
            widget.paddingBottom,
            v,
          ),
        ),
      ],
    );
  }

  Widget _buildClipContentRow() {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: widget.clipContent,
            onChanged: (v) => widget.onClipContentChanged?.call(v ?? true),
            activeColor: DesignPanelColors.accent,
            side: const BorderSide(color: DesignPanelColors.border),
          ),
        ),
        const SizedBox(width: DesignPanelSpacing.sm),
        const Text(
          'Clip content',
          style: TextStyle(
            color: DesignPanelColors.text1,
            fontSize: DesignPanelTypography.fontSizeMd,
          ),
        ),
      ],
    );
  }
}

// ============ Helper Widgets ============

class _FlowButton extends StatelessWidget {
  final Widget icon;
  final bool selected;
  final VoidCallback? onTap;

  const _FlowButton({
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: selected ? DesignPanelColors.bg3 : DesignPanelColors.bg1,
            borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
            border: Border.all(
              color: selected ? DesignPanelColors.accent : DesignPanelColors.border,
            ),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _SizingField extends StatelessWidget {
  final String label;
  final double value;
  final AutoLayoutSizing sizing;
  final TextEditingController controller;
  final ValueChanged<double>? onValueChanged;
  final ValueChanged<AutoLayoutSizing>? onSizingChanged;

  const _SizingField({
    required this.label,
    required this.value,
    required this.sizing,
    required this.controller,
    this.onValueChanged,
    this.onSizingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesignPanelDimensions.inputHeight,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: Row(
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: DesignPanelColors.text3,
                fontSize: DesignPanelTypography.fontSizeMd,
              ),
            ),
          ),
          // Value
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: DesignPanelColors.text1,
                fontSize: DesignPanelTypography.fontSizeMd,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (v) {
                final num = double.tryParse(v);
                if (num != null) onValueChanged?.call(num);
              },
            ),
          ),
          // Sizing dropdown
          GestureDetector(
            onTap: () => _showSizingMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _sizingLabel(sizing),
                style: const TextStyle(
                  color: DesignPanelColors.text2,
                  fontSize: DesignPanelTypography.fontSizeSm,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sizingLabel(AutoLayoutSizing sizing) {
    switch (sizing) {
      case AutoLayoutSizing.hug:
        return 'Hug';
      case AutoLayoutSizing.fill:
        return 'Fill';
      case AutoLayoutSizing.fixed:
        return 'Fixed';
    }
  }

  void _showSizingMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final position = button.localToGlobal(Offset.zero);

    showMenu<AutoLayoutSizing>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + button.size.height,
        position.dx + button.size.width,
        position.dy,
      ),
      color: DesignPanelColors.bg2,
      items: [
        _buildMenuItem(AutoLayoutSizing.hug, 'Hug'),
        _buildMenuItem(AutoLayoutSizing.fill, 'Fill'),
        _buildMenuItem(AutoLayoutSizing.fixed, 'Fixed'),
      ],
    ).then((value) {
      if (value != null) onSizingChanged?.call(value);
    });
  }

  PopupMenuItem<AutoLayoutSizing> _buildMenuItem(
      AutoLayoutSizing value, String label) {
    return PopupMenuItem<AutoLayoutSizing>(
      value: value,
      child: Text(
        label,
        style: TextStyle(
          color: sizing == value
              ? DesignPanelColors.accent
              : DesignPanelColors.text1,
          fontSize: DesignPanelTypography.fontSizeMd,
        ),
      ),
    );
  }
}

class _AlignmentGrid extends StatelessWidget {
  final String mainAxisAlign;
  final String crossAxisAlign;
  final void Function(String main, String cross)? onAlignmentChanged;

  const _AlignmentGrid({
    required this.mainAxisAlign,
    required this.crossAxisAlign,
    this.onAlignmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 64,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAlignmentRow(['MIN', 'MIN'], ['CENTER', 'MIN'], ['MAX', 'MIN']),
          _buildAlignmentRow(
              ['MIN', 'CENTER'], ['CENTER', 'CENTER'], ['MAX', 'CENTER']),
          _buildAlignmentRow(['MIN', 'MAX'], ['CENTER', 'MAX'], ['MAX', 'MAX']),
        ],
      ),
    );
  }

  Widget _buildAlignmentRow(
      List<String> left, List<String> center, List<String> right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _AlignmentDot(
          selected: mainAxisAlign == left[0] && crossAxisAlign == left[1],
          onTap: () => onAlignmentChanged?.call(left[0], left[1]),
        ),
        _AlignmentDot(
          selected: mainAxisAlign == center[0] && crossAxisAlign == center[1],
          onTap: () => onAlignmentChanged?.call(center[0], center[1]),
          isCenter: center[0] == 'CENTER' && center[1] == 'CENTER',
        ),
        _AlignmentDot(
          selected: mainAxisAlign == right[0] && crossAxisAlign == right[1],
          onTap: () => onAlignmentChanged?.call(right[0], right[1]),
        ),
      ],
    );
  }
}

class _AlignmentDot extends StatelessWidget {
  final bool selected;
  final bool isCenter;
  final VoidCallback? onTap;

  const _AlignmentDot({
    this.selected = false,
    this.isCenter = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isCenter ? 16 : 8,
        height: isCenter ? 16 : 8,
        decoration: BoxDecoration(
          color: selected ? DesignPanelColors.accent : DesignPanelColors.text3,
          shape: isCenter ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isCenter ? BorderRadius.circular(2) : null,
        ),
        child: isCenter && selected
            ? const Icon(Icons.drag_indicator, size: 12, color: Colors.white)
            : null,
      ),
    );
  }
}

class _NumericInputField extends StatelessWidget {
  final Widget icon;
  final TextEditingController controller;
  final ValueChanged<double>? onChanged;

  const _NumericInputField({
    required this.icon,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesignPanelDimensions.inputHeight,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(color: DesignPanelColors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: icon,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: DesignPanelColors.text1,
                fontSize: DesignPanelTypography.fontSizeMd,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (v) {
                final num = double.tryParse(v);
                if (num != null) onChanged?.call(num);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallNumericField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;

  const _SmallNumericField({
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: DesignPanelDimensions.smallInputHeight,
        decoration: BoxDecoration(
          color: DesignPanelColors.bg1,
          borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
          border: Border.all(color: DesignPanelColors.border),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                label,
                style: const TextStyle(
                  color: DesignPanelColors.text3,
                  fontSize: DesignPanelTypography.fontSizeXs,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: value.toInt().toString()),
                style: const TextStyle(
                  color: DesignPanelColors.text1,
                  fontSize: DesignPanelTypography.fontSizeSm,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (v) {
                  final num = double.tryParse(v);
                  if (num != null) onChanged?.call(num);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: DesignPanelDimensions.buttonSize,
        height: DesignPanelDimensions.buttonSize,
        decoration: BoxDecoration(
          color: DesignPanelColors.bg1,
          borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
          border: Border.all(color: DesignPanelColors.border),
        ),
        child: Icon(icon, size: 14, color: DesignPanelColors.text2),
      ),
    );
  }
}

// ============ Icon Widgets ============

class _AutoLayoutIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _AutoLayoutIconPainter(),
    );
  }
}

class _AutoLayoutIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignPanelColors.text2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw two horizontal lines representing auto layout
    canvas.drawLine(
      Offset(2, size.height * 0.3),
      Offset(size.width - 2, size.height * 0.3),
      paint,
    );
    canvas.drawLine(
      Offset(2, size.height * 0.7),
      Offset(size.width - 2, size.height * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VerticalStackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.view_agenda_outlined,
        size: 14, color: DesignPanelColors.text2);
  }
}

class _VerticalDownIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.south, size: 14, color: DesignPanelColors.text2);
  }
}

class _HorizontalIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.east, size: 14, color: DesignPanelColors.text2);
  }
}

class _GridIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.grid_view, size: 14, color: DesignPanelColors.text2);
  }
}

class _WrapIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.wrap_text, size: 14, color: DesignPanelColors.text2);
  }
}

class _GapIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      '}{',
      style: TextStyle(
        color: DesignPanelColors.text3,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PaddingHIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.horizontal_distribute,
        size: 12, color: DesignPanelColors.text3);
  }
}

class _PaddingVIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.vertical_distribute,
        size: 12, color: DesignPanelColors.text3);
  }
}
