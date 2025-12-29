/// Auto layout properties panel for editing layout settings
///
/// Provides UI for:
/// - Enabling/disabling auto layout
/// - Flow direction (vertical/horizontal/grid)
/// - Spacing and padding
/// - Alignment controls
/// - Resizing behaviors
/// - Min/max constraints

import 'package:flutter/material.dart';
import 'auto_layout_data.dart';

/// Auto layout properties panel
class AutoLayoutPanel extends StatefulWidget {
  /// Current auto layout configuration
  final AutoLayoutConfig config;

  /// Callback when configuration changes
  final ValueChanged<AutoLayoutConfig>? onConfigChanged;

  /// Whether to show the enable toggle
  final bool showEnableToggle;

  /// Whether the panel is collapsed
  final bool collapsed;

  /// Callback when collapsed state changes
  final ValueChanged<bool>? onCollapsedChanged;

  /// Panel width
  final double width;

  const AutoLayoutPanel({
    super.key,
    required this.config,
    this.onConfigChanged,
    this.showEnableToggle = true,
    this.collapsed = false,
    this.onCollapsedChanged,
    this.width = 240,
  });

  @override
  State<AutoLayoutPanel> createState() => _AutoLayoutPanelState();
}

class _AutoLayoutPanelState extends State<AutoLayoutPanel> {
  late AutoLayoutConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  void didUpdateWidget(AutoLayoutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config) {
      _config = widget.config;
    }
  }

  void _updateConfig(AutoLayoutConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    widget.onConfigChanged?.call(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with enable toggle
          _buildHeader(),

          // Content
          if (!widget.collapsed && _config.isEnabled) ...[
            _buildFlowSection(),
            _buildSpacingSection(),
            _buildPaddingSection(),
            _buildAlignmentSection(),
            _buildSizingSection(),
            if (_config.constraints.hasConstraints) _buildConstraintsSection(),
            if (_config.isGrid) _buildGridSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () => widget.onCollapsedChanged?.call(!widget.collapsed),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              widget.collapsed
                  ? Icons.chevron_right
                  : Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.white54,
            ),
            const SizedBox(width: 4),

            // Auto layout icon
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _config.isEnabled
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                _config.isVertical
                    ? Icons.view_agenda_outlined
                    : _config.isGrid
                        ? Icons.grid_view
                        : Icons.view_week_outlined,
                size: 12,
                color: _config.isEnabled ? Colors.blue : Colors.white38,
              ),
            ),
            const SizedBox(width: 8),

            const Text(
              'Auto layout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),

            // Enable toggle
            if (widget.showEnableToggle)
              GestureDetector(
                onTap: () {
                  _updateConfig(_config.copyWith(
                    flow: _config.isEnabled
                        ? AutoLayoutFlow.none
                        : AutoLayoutFlow.vertical,
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _config.isEnabled
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _config.isEnabled ? 'On' : 'Off',
                    style: TextStyle(
                      color:
                          _config.isEnabled ? Colors.blue : Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          const SizedBox(
            width: 60,
            child: Text(
              'Direction',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(
            child: _FlowSelector(
              flow: _config.flow,
              onFlowChanged: (flow) => _updateConfig(_config.copyWith(flow: flow)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          const SizedBox(
            width: 60,
            child: Text(
              'Gap',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(
            child: _NumberInput(
              value: _config.itemSpacing,
              min: 0,
              onChanged: (value) =>
                  _updateConfig(_config.copyWith(itemSpacing: value)),
              suffix: 'px',
            ),
          ),
          const SizedBox(width: 8),
          // Auto spacing toggle
          GestureDetector(
            onTap: () {
              _updateConfig(_config.copyWith(
                mainAxisAlign:
                    _config.mainAxisAlign == AutoLayoutMainAxisAlign.spaceBetween
                        ? AutoLayoutMainAxisAlign.start
                        : AutoLayoutMainAxisAlign.spaceBetween,
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _config.mainAxisAlign ==
                        AutoLayoutMainAxisAlign.spaceBetween
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Auto',
                style: TextStyle(
                  color: _config.mainAxisAlign ==
                          AutoLayoutMainAxisAlign.spaceBetween
                      ? Colors.blue
                      : Colors.white54,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaddingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'Padding',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
              Expanded(
                child: _PaddingEditor(
                  padding: _config.padding,
                  onPaddingChanged: (padding) =>
                      _updateConfig(_config.copyWith(padding: padding)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alignment',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          _AlignmentGrid(
            mainAxisAlign: _config.mainAxisAlign,
            crossAxisAlign: _config.crossAxisAlign,
            isVertical: _config.isVertical,
            onMainAxisChanged: (align) =>
                _updateConfig(_config.copyWith(mainAxisAlign: align)),
            onCrossAxisChanged: (align) =>
                _updateConfig(_config.copyWith(crossAxisAlign: align)),
          ),
        ],
      ),
    );
  }

  Widget _buildSizingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resizing',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Width sizing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'W',
                      style: TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    _SizingDropdown(
                      sizing: _config.widthSizing,
                      onChanged: (sizing) =>
                          _updateConfig(_config.copyWith(widthSizing: sizing)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Height sizing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'H',
                      style: TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    _SizingDropdown(
                      sizing: _config.heightSizing,
                      onChanged: (sizing) =>
                          _updateConfig(_config.copyWith(heightSizing: sizing)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Constraints',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ConstraintInput(
                  label: 'Min W',
                  value: _config.constraints.minWidth,
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    constraints: _config.constraints.copyWith(minWidth: v),
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConstraintInput(
                  label: 'Max W',
                  value: _config.constraints.maxWidth,
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    constraints: _config.constraints.copyWith(maxWidth: v),
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _ConstraintInput(
                  label: 'Min H',
                  value: _config.constraints.minHeight,
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    constraints: _config.constraints.copyWith(minHeight: v),
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConstraintInput(
                  label: 'Max H',
                  value: _config.constraints.maxHeight,
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    constraints: _config.constraints.copyWith(maxHeight: v),
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridSection() {
    final gridConfig = _config.gridConfig ?? const AutoLayoutGridConfig();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grid',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberInput(
                  value: gridConfig.columns?.toDouble() ?? 2,
                  min: 1,
                  max: 12,
                  label: 'Columns',
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    gridConfig: gridConfig.copyWith(columns: v.toInt()),
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberInput(
                  value: gridConfig.columnGap,
                  min: 0,
                  label: 'Col gap',
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    gridConfig: gridConfig.copyWith(columnGap: v),
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _NumberInput(
                  value: gridConfig.rows?.toDouble() ?? 0,
                  min: 0,
                  label: 'Rows',
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    gridConfig: gridConfig.copyWith(
                        rows: v > 0 ? v.toInt() : null),
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberInput(
                  value: gridConfig.rowGap,
                  min: 0,
                  label: 'Row gap',
                  onChanged: (v) => _updateConfig(_config.copyWith(
                    gridConfig: gridConfig.copyWith(rowGap: v),
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Flow direction selector
class _FlowSelector extends StatelessWidget {
  final AutoLayoutFlow flow;
  final ValueChanged<AutoLayoutFlow> onFlowChanged;

  const _FlowSelector({
    required this.flow,
    required this.onFlowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FlowButton(
          icon: Icons.view_agenda_outlined,
          isSelected: flow == AutoLayoutFlow.vertical,
          onTap: () => onFlowChanged(AutoLayoutFlow.vertical),
          tooltip: 'Vertical',
        ),
        const SizedBox(width: 4),
        _FlowButton(
          icon: Icons.view_week_outlined,
          isSelected: flow == AutoLayoutFlow.horizontal,
          onTap: () => onFlowChanged(AutoLayoutFlow.horizontal),
          tooltip: 'Horizontal',
        ),
        const SizedBox(width: 4),
        _FlowButton(
          icon: Icons.wrap_text,
          isSelected: flow == AutoLayoutFlow.wrap,
          onTap: () => onFlowChanged(AutoLayoutFlow.wrap),
          tooltip: 'Wrap',
        ),
        const SizedBox(width: 4),
        _FlowButton(
          icon: Icons.grid_view,
          isSelected: flow == AutoLayoutFlow.grid,
          onTap: () => onFlowChanged(AutoLayoutFlow.grid),
          tooltip: 'Grid',
        ),
      ],
    );
  }
}

class _FlowButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _FlowButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 24,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.blue : Colors.white54,
          ),
        ),
      ),
    );
  }
}

/// Padding editor with individual/uniform toggle
class _PaddingEditor extends StatefulWidget {
  final AutoLayoutPadding padding;
  final ValueChanged<AutoLayoutPadding> onPaddingChanged;

  const _PaddingEditor({
    required this.padding,
    required this.onPaddingChanged,
  });

  @override
  State<_PaddingEditor> createState() => _PaddingEditorState();
}

class _PaddingEditorState extends State<_PaddingEditor> {
  bool _showIndividual = false;

  @override
  void initState() {
    super.initState();
    _showIndividual = !widget.padding.isUniform;
  }

  @override
  Widget build(BuildContext context) {
    if (_showIndividual) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _NumberInput(
                  value: widget.padding.top,
                  min: 0,
                  label: 'T',
                  onChanged: (v) => widget.onPaddingChanged(
                    widget.padding.copyWith(top: v),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _NumberInput(
                  value: widget.padding.right,
                  min: 0,
                  label: 'R',
                  onChanged: (v) => widget.onPaddingChanged(
                    widget.padding.copyWith(right: v),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _NumberInput(
                  value: widget.padding.bottom,
                  min: 0,
                  label: 'B',
                  onChanged: (v) => widget.onPaddingChanged(
                    widget.padding.copyWith(bottom: v),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _NumberInput(
                  value: widget.padding.left,
                  min: 0,
                  label: 'L',
                  onChanged: (v) => widget.onPaddingChanged(
                    widget.padding.copyWith(left: v),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _ToggleButton(
                icon: Icons.link,
                isSelected: false,
                onTap: () => setState(() => _showIndividual = false),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _NumberInput(
            value: widget.padding.top,
            min: 0,
            onChanged: (v) => widget.onPaddingChanged(
              AutoLayoutPadding.all(v),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _ToggleButton(
          icon: Icons.link_off,
          isSelected: false,
          onTap: () => setState(() => _showIndividual = true),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 12,
          color: isSelected ? Colors.blue : Colors.white54,
        ),
      ),
    );
  }
}

/// Alignment grid (3x3)
class _AlignmentGrid extends StatelessWidget {
  final AutoLayoutMainAxisAlign mainAxisAlign;
  final AutoLayoutCrossAxisAlign crossAxisAlign;
  final bool isVertical;
  final ValueChanged<AutoLayoutMainAxisAlign> onMainAxisChanged;
  final ValueChanged<AutoLayoutCrossAxisAlign> onCrossAxisChanged;

  const _AlignmentGrid({
    required this.mainAxisAlign,
    required this.crossAxisAlign,
    required this.isVertical,
    required this.onMainAxisChanged,
    required this.onCrossAxisChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int row = 0; row < 3; row++)
            for (int col = 0; col < 3; col++)
              _AlignmentCell(
                isSelected: _isSelected(row, col),
                onTap: () => _handleTap(row, col),
              ),
        ],
      ),
    );
  }

  bool _isSelected(int row, int col) {
    int mainIndex = isVertical ? row : col;
    int crossIndex = isVertical ? col : row;

    bool mainMatch;
    switch (mainAxisAlign) {
      case AutoLayoutMainAxisAlign.start:
        mainMatch = mainIndex == 0;
        break;
      case AutoLayoutMainAxisAlign.center:
        mainMatch = mainIndex == 1;
        break;
      case AutoLayoutMainAxisAlign.end:
        mainMatch = mainIndex == 2;
        break;
      case AutoLayoutMainAxisAlign.spaceBetween:
        mainMatch = mainIndex == 1;
        break;
    }

    bool crossMatch;
    switch (crossAxisAlign) {
      case AutoLayoutCrossAxisAlign.start:
        crossMatch = crossIndex == 0;
        break;
      case AutoLayoutCrossAxisAlign.center:
        crossMatch = crossIndex == 1;
        break;
      case AutoLayoutCrossAxisAlign.end:
        crossMatch = crossIndex == 2;
        break;
      case AutoLayoutCrossAxisAlign.stretch:
      case AutoLayoutCrossAxisAlign.baseline:
        crossMatch = crossIndex == 1;
        break;
    }

    return mainMatch && crossMatch;
  }

  void _handleTap(int row, int col) {
    int mainIndex = isVertical ? row : col;
    int crossIndex = isVertical ? col : row;

    AutoLayoutMainAxisAlign newMain;
    switch (mainIndex) {
      case 0:
        newMain = AutoLayoutMainAxisAlign.start;
        break;
      case 1:
        newMain = AutoLayoutMainAxisAlign.center;
        break;
      case 2:
        newMain = AutoLayoutMainAxisAlign.end;
        break;
      default:
        newMain = AutoLayoutMainAxisAlign.start;
    }

    AutoLayoutCrossAxisAlign newCross;
    switch (crossIndex) {
      case 0:
        newCross = AutoLayoutCrossAxisAlign.start;
        break;
      case 1:
        newCross = AutoLayoutCrossAxisAlign.center;
        break;
      case 2:
        newCross = AutoLayoutCrossAxisAlign.end;
        break;
      default:
        newCross = AutoLayoutCrossAxisAlign.start;
    }

    onMainAxisChanged(newMain);
    onCrossAxisChanged(newCross);
  }
}

class _AlignmentCell extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _AlignmentCell({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Sizing dropdown
class _SizingDropdown extends StatelessWidget {
  final AutoLayoutSizing sizing;
  final ValueChanged<AutoLayoutSizing> onChanged;

  const _SizingDropdown({
    required this.sizing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AutoLayoutSizing>(
          value: sizing,
          isExpanded: true,
          isDense: true,
          dropdownColor: const Color(0xFF3C3C3C),
          style: const TextStyle(color: Colors.white, fontSize: 10),
          items: [
            DropdownMenuItem(
              value: AutoLayoutSizing.fixed,
              child: _SizingItem(
                icon: Icons.lock_outline,
                label: 'Fixed',
              ),
            ),
            DropdownMenuItem(
              value: AutoLayoutSizing.hug,
              child: _SizingItem(
                icon: Icons.compress,
                label: 'Hug',
              ),
            ),
            DropdownMenuItem(
              value: AutoLayoutSizing.fill,
              child: _SizingItem(
                icon: Icons.expand,
                label: 'Fill',
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _SizingItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SizingItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 10, color: Colors.white54),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

/// Number input field
class _NumberInput extends StatelessWidget {
  final double value;
  final double? min;
  final double? max;
  final String? label;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const _NumberInput({
    required this.value,
    this.min,
    this.max,
    this.label,
    this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                label!,
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          Expanded(
            child: TextField(
              controller:
                  TextEditingController(text: value.toStringAsFixed(0)),
              style: const TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
                suffixText: suffix,
                suffixStyle:
                    const TextStyle(color: Colors.white38, fontSize: 9),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (text) {
                final parsed = double.tryParse(text);
                if (parsed != null) {
                  var newValue = parsed;
                  if (min != null) newValue = newValue.clamp(min!, double.infinity);
                  if (max != null) newValue = newValue.clamp(double.negativeInfinity, max!);
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Constraint input with clear button
class _ConstraintInput extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  const _ConstraintInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ),
          Expanded(
            child: TextField(
              controller: TextEditingController(
                text: value?.toStringAsFixed(0) ?? '—',
              ),
              style: const TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (text) {
                if (text == '—' || text.isEmpty) {
                  onChanged(null);
                } else {
                  final parsed = double.tryParse(text);
                  onChanged(parsed);
                }
              },
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: () => onChanged(null),
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.close, size: 10, color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }
}

/// Child-specific auto layout panel
class AutoLayoutChildPanel extends StatelessWidget {
  final AutoLayoutChildConfig config;
  final AutoLayoutConfig parentConfig;
  final ValueChanged<AutoLayoutChildConfig>? onConfigChanged;

  const AutoLayoutChildPanel({
    super.key,
    required this.config,
    required this.parentConfig,
    this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Absolute position toggle
          Row(
            children: [
              const Text(
                'Position',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  onConfigChanged?.call(
                    config.copyWith(isAbsolute: !config.isAbsolute),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: config.isAbsolute
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    config.isAbsolute ? 'Absolute' : 'Auto',
                    style: TextStyle(
                      color: config.isAbsolute
                          ? Colors.orange
                          : Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (!config.isAbsolute) ...[
            const SizedBox(height: 8),
            // Resizing
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'W',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                      const SizedBox(height: 4),
                      _SizingDropdown(
                        sizing: config.widthSizing,
                        onChanged: (sizing) {
                          onConfigChanged?.call(
                            config.copyWith(widthSizing: sizing),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'H',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                      const SizedBox(height: 4),
                      _SizingDropdown(
                        sizing: config.heightSizing,
                        onChanged: (sizing) {
                          onConfigChanged?.call(
                            config.copyWith(heightSizing: sizing),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
