/// Variable Type Icons
///
/// Custom icons matching Figma's variable type indicators.

import 'package:flutter/material.dart';
import '../assets/variables.dart';

/// Colors for variable type icons
class VariableIconColors {
  static const color = Color(0xFFE879F9); // Pink/purple for colors
  static const number = Color(0xFF60A5FA); // Blue for numbers
  static const string = Color(0xFF4ADE80); // Green for strings
  static const boolean = Color(0xFFFB923C); // Orange for booleans
  static const alias = Color(0xFF94A3B8); // Gray for aliases

  static Color forType(VariableType type) {
    switch (type) {
      case VariableType.color:
        return color;
      case VariableType.number:
        return number;
      case VariableType.string:
        return string;
      case VariableType.boolean:
        return boolean;
    }
  }
}

/// Base variable type icon widget
class VariableTypeIcon extends StatelessWidget {
  final VariableType type;
  final double size;
  final bool isAlias;

  const VariableTypeIcon({
    super.key,
    required this.type,
    this.size = 20,
    this.isAlias = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isAlias) {
      return _AliasIcon(size: size, type: type);
    }

    switch (type) {
      case VariableType.color:
        return _ColorTypeIcon(size: size);
      case VariableType.number:
        return _NumberTypeIcon(size: size);
      case VariableType.string:
        return _StringTypeIcon(size: size);
      case VariableType.boolean:
        return _BooleanTypeIcon(size: size);
    }
  }
}

/// Color type icon - filled circle
class _ColorTypeIcon extends StatelessWidget {
  final double size;

  const _ColorTypeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VariableIconColors.color.withValues(alpha: 0.2),
        border: Border.all(
          color: VariableIconColors.color,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VariableIconColors.color,
          ),
        ),
      ),
    );
  }
}

/// Number type icon - hash/number symbol
class _NumberTypeIcon extends StatelessWidget {
  final double size;

  const _NumberTypeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: VariableIconColors.number.withValues(alpha: 0.2),
      ),
      child: Center(
        child: Text(
          '#',
          style: TextStyle(
            color: VariableIconColors.number,
            fontSize: size * 0.65,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// String type icon - T in a box (text)
class _StringTypeIcon extends StatelessWidget {
  final double size;

  const _StringTypeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: VariableIconColors.string.withValues(alpha: 0.2),
        border: Border.all(
          color: VariableIconColors.string,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            color: VariableIconColors.string,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Boolean type icon - eye/visibility icon
class _BooleanTypeIcon extends StatelessWidget {
  final double size;

  const _BooleanTypeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: VariableIconColors.boolean.withValues(alpha: 0.2),
      ),
      child: Icon(
        Icons.visibility_outlined,
        size: size * 0.7,
        color: VariableIconColors.boolean,
      ),
    );
  }
}

/// Alias icon - chain link indicator
class _AliasIcon extends StatelessWidget {
  final double size;
  final VariableType type;

  const _AliasIcon({required this.size, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = VariableIconColors.forType(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.15),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.link,
            size: size * 0.6,
            color: color.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

/// Color swatch with hex value display
class ColorSwatchWithHex extends StatelessWidget {
  final Color color;
  final double swatchSize;
  final bool showHex;
  final TextStyle? hexStyle;

  const ColorSwatchWithHex({
    super.key,
    required this.color,
    this.swatchSize = 16,
    this.showHex = true,
    this.hexStyle,
  });

  @override
  Widget build(BuildContext context) {
    final hex = color.value.toRadixString(16).substring(2).toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: swatchSize,
          height: swatchSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        if (showHex) ...[
          const SizedBox(width: 8),
          Text(
            hex,
            style: hexStyle ??
                const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ],
    );
  }
}

/// Boolean toggle display matching Figma style
class BooleanValueDisplay extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const BooleanValueDisplay({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
          child: Container(
            width: 36,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: value
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF4A4A4A),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value ? 'True' : 'False',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Alias value display with emoji and target name
class AliasValueDisplay extends StatelessWidget {
  final String? emoji;
  final String targetName;
  final VoidCallback? onTap;

  const AliasValueDisplay({
    super.key,
    this.emoji,
    required this.targetName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(
              emoji!,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            targetName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.link,
            size: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

/// Number value display
class NumberValueDisplay extends StatelessWidget {
  final double value;
  final String? unit;

  const NumberValueDisplay({
    super.key,
    required this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    String displayValue;
    if (value == value.truncateToDouble()) {
      displayValue = value.toInt().toString();
    } else {
      displayValue = value.toStringAsFixed(2);
    }

    return Text(
      unit != null ? '$displayValue$unit' : displayValue,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 11,
        fontFamily: 'monospace',
      ),
    );
  }
}

/// String value display with quotes
class StringValueDisplay extends StatelessWidget {
  final String value;
  final int maxLength;

  const StringValueDisplay({
    super.key,
    required this.value,
    this.maxLength = 20,
  });

  @override
  Widget build(BuildContext context) {
    String displayValue = value;
    if (displayValue.length > maxLength) {
      displayValue = '${displayValue.substring(0, maxLength)}...';
    }

    return Text(
      '"$displayValue"',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 11,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
