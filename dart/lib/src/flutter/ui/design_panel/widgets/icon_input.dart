/// Icon input widget for Design Panel
///
/// Input field with optional leading icon, matching Figma's style.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_panel_colors.dart';

/// Input field with optional leading icon/label
class IconInput extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final String value;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final double? width;

  const IconInput({
    super.key,
    this.label,
    this.icon,
    required this.value,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textAlign = TextAlign.right,
    this.width,
  });

  @override
  State<IconInput> createState() => _IconInputState();
}

class _IconInputState extends State<IconInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(IconInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    if (!_focusNode.hasFocus) {
      widget.onSubmitted?.call(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: DesignPanelDimensions.inputHeight,
      decoration: BoxDecoration(
        color: DesignPanelColors.bg1,
        borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
        border: Border.all(
          color: _isFocused
              ? DesignPanelColors.borderFocus
              : DesignPanelColors.border,
        ),
      ),
      child: Row(
        children: [
          // Leading icon or label
          if (widget.icon != null || widget.label != null)
            Container(
              width: 24,
              alignment: Alignment.center,
              child: widget.icon != null
                  ? Icon(
                      widget.icon,
                      size: DesignPanelDimensions.smallIconSize,
                      color: DesignPanelColors.text3,
                    )
                  : Text(
                      widget.label!,
                      style: const TextStyle(
                        color: DesignPanelColors.text3,
                        fontSize: DesignPanelTypography.fontSizeSm,
                      ),
                    ),
            ),
          // Input field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              textAlign: widget.textAlign,
              style: DesignPanelTypography.valueStyle,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DesignPanelSpacing.xs,
                  vertical: 0,
                ),
                isDense: true,
                suffixText: widget.suffix,
                suffixStyle: const TextStyle(
                  color: DesignPanelColors.text3,
                  fontSize: DesignPanelTypography.fontSizeSm,
                ),
              ),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric input with label
class NumericInput extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final String? suffix;
  final double? width;
  final int decimals;

  const NumericInput({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.suffix,
    this.width,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return IconInput(
      label: label,
      value: decimals > 0
          ? value.toStringAsFixed(decimals)
          : value.toInt().toString(),
      suffix: suffix,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.-]')),
      ],
      width: width,
      onSubmitted: (text) {
        final newValue = double.tryParse(text);
        if (newValue != null) {
          onChanged?.call(newValue);
        }
      },
    );
  }
}

/// Percentage input (0-100%)
class PercentageInput extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final ValueChanged<double>? onChanged;
  final double? width;

  const PercentageInput({
    super.key,
    required this.value,
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return NumericInput(
      label: '',
      value: (value * 100).clamp(0, 100),
      suffix: '%',
      width: width,
      onChanged: (v) => onChanged?.call((v / 100).clamp(0, 1)),
    );
  }
}
