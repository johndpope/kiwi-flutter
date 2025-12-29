/// Inline Value Editors for Variables
///
/// Provides inline editing widgets for variable values matching Figma's UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../assets/variables.dart';
import 'variable_icons.dart';

/// Base inline editor that shows value and allows inline editing
class InlineVariableEditor extends StatelessWidget {
  final DesignVariable variable;
  final dynamic value;
  final bool isAlias;
  final String? aliasTargetName;
  final String? aliasEmoji;
  final ValueChanged<dynamic>? onValueChanged;
  final bool enabled;

  const InlineVariableEditor({
    super.key,
    required this.variable,
    required this.value,
    this.isAlias = false,
    this.aliasTargetName,
    this.aliasEmoji,
    this.onValueChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isAlias && aliasTargetName != null) {
      return AliasValueDisplay(
        emoji: aliasEmoji,
        targetName: aliasTargetName!,
      );
    }

    switch (variable.type) {
      case VariableType.color:
        if (value is Color) {
          return _InlineColorEditor(
            value: value as Color,
            onChanged: onValueChanged != null
                ? (c) => onValueChanged!(c)
                : null,
            enabled: enabled,
          );
        }
        return const Text('-', style: TextStyle(color: Colors.white54));

      case VariableType.boolean:
        return BooleanValueDisplay(
          value: value as bool? ?? false,
          onChanged: onValueChanged != null
              ? (b) => onValueChanged!(b)
              : null,
          enabled: enabled,
        );

      case VariableType.number:
        return _InlineNumberEditor(
          value: (value as num?)?.toDouble() ?? 0.0,
          onChanged: onValueChanged != null
              ? (n) => onValueChanged!(n)
              : null,
          enabled: enabled,
        );

      case VariableType.string:
        return _InlineStringEditor(
          value: value?.toString() ?? '',
          onChanged: onValueChanged != null
              ? (s) => onValueChanged!(s)
              : null,
          enabled: enabled,
        );
    }
  }
}

/// Inline color editor with swatch and hex
class _InlineColorEditor extends StatefulWidget {
  final Color value;
  final ValueChanged<Color>? onChanged;
  final bool enabled;

  const _InlineColorEditor({
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<_InlineColorEditor> createState() => _InlineColorEditorState();
}

class _InlineColorEditorState extends State<_InlineColorEditor> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _colorToHex(widget.value));
  }

  @override
  void didUpdateWidget(_InlineColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.value != widget.value) {
      _controller.text = _colorToHex(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).substring(2).toUpperCase();
  }

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) {
        return Color(value);
      }
    }
    return null;
  }

  void _submitValue() {
    final color = _hexToColor(_controller.text);
    if (color != null && widget.onChanged != null) {
      widget.onChanged!(color);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && widget.enabled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: widget.value,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF0D99FF)),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) => _submitValue(),
              onEditingComplete: _submitValue,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: widget.enabled ? () => setState(() => _isEditing = true) : null,
      child: ColorSwatchWithHex(
        color: widget.value,
        swatchSize: 16,
        showHex: true,
      ),
    );
  }
}

/// Inline number editor
class _InlineNumberEditor extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final bool enabled;

  const _InlineNumberEditor({
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<_InlineNumberEditor> createState() => _InlineNumberEditorState();
}

class _InlineNumberEditorState extends State<_InlineNumberEditor> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatNumber(widget.value));
  }

  @override
  void didUpdateWidget(_InlineNumberEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.value != widget.value) {
      _controller.text = _formatNumber(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _submitValue() {
    final value = double.tryParse(_controller.text);
    if (value != null && widget.onChanged != null) {
      widget.onChanged!(value);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && widget.enabled) {
      return SizedBox(
        width: 60,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF0D99FF)),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          onSubmitted: (_) => _submitValue(),
          onEditingComplete: _submitValue,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.enabled ? () => setState(() => _isEditing = true) : null,
      child: NumberValueDisplay(value: widget.value),
    );
  }
}

/// Inline string editor
class _InlineStringEditor extends StatefulWidget {
  final String value;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const _InlineStringEditor({
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<_InlineStringEditor> createState() => _InlineStringEditorState();
}

class _InlineStringEditorState extends State<_InlineStringEditor> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_InlineStringEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitValue() {
    if (widget.onChanged != null) {
      widget.onChanged!(_controller.text);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && widget.enabled) {
      return SizedBox(
        width: 120,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF0D99FF)),
            ),
          ),
          onSubmitted: (_) => _submitValue(),
          onEditingComplete: _submitValue,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.enabled ? () => setState(() => _isEditing = true) : null,
      child: StringValueDisplay(value: widget.value),
    );
  }
}
