/// Code Export for Variables
///
/// Exports variables to various code formats:
/// - CSS Custom Properties (CSS Variables)
/// - JavaScript/TypeScript objects
/// - SCSS/SASS variables
/// - Swift constants
/// - Kotlin constants
/// - Tailwind CSS config
/// - Style Dictionary format

import 'package:flutter/material.dart';
import '../assets/variables.dart';
import 'extended_collections.dart';

/// Export format types
enum CodeExportFormat {
  css('CSS Custom Properties', 'css'),
  scss('SCSS Variables', 'scss'),
  sass('SASS Variables', 'sass'),
  less('LESS Variables', 'less'),
  javascript('JavaScript Object', 'js'),
  typescript('TypeScript Object', 'ts'),
  swift('Swift Constants', 'swift'),
  kotlin('Kotlin Constants', 'kt'),
  tailwind('Tailwind Config', 'js'),
  styleDictionary('Style Dictionary', 'json'),
  flutter('Flutter Theme', 'dart');

  final String label;
  final String extension;
  const CodeExportFormat(this.label, this.extension);
}

/// Export configuration
class CodeExportConfig {
  /// Include comments with variable descriptions
  final bool includeComments;

  /// Include mode variations
  final bool includeModes;

  /// Use aliases where possible
  final bool preserveAliases;

  /// Prefix for variable names
  final String? prefix;

  /// Convert names to specific case
  final NamingCase namingCase;

  /// Indent string (spaces or tabs)
  final String indent;

  /// Line ending
  final String lineEnding;

  const CodeExportConfig({
    this.includeComments = true,
    this.includeModes = true,
    this.preserveAliases = true,
    this.prefix,
    this.namingCase = NamingCase.kebab,
    this.indent = '  ',
    this.lineEnding = '\n',
  });
}

/// Naming case options
enum NamingCase {
  kebab, // kebab-case
  snake, // snake_case
  camel, // camelCase
  pascal, // PascalCase
  constant, // CONSTANT_CASE
}

/// Code export engine
class CodeExportEngine {
  final VariableResolver resolver;
  final CodeExportConfig config;

  CodeExportEngine({
    required this.resolver,
    this.config = const CodeExportConfig(),
  });

  /// Export to specified format
  String export(
    CodeExportFormat format,
    ExtendedVariableCollection collection,
    List<DesignVariable> variables, {
    String? modeId,
  }) {
    switch (format) {
      case CodeExportFormat.css:
        return _exportCSS(collection, variables, modeId);
      case CodeExportFormat.scss:
        return _exportSCSS(collection, variables, modeId);
      case CodeExportFormat.sass:
        return _exportSASS(collection, variables, modeId);
      case CodeExportFormat.less:
        return _exportLESS(collection, variables, modeId);
      case CodeExportFormat.javascript:
        return _exportJS(collection, variables, modeId);
      case CodeExportFormat.typescript:
        return _exportTS(collection, variables, modeId);
      case CodeExportFormat.swift:
        return _exportSwift(collection, variables, modeId);
      case CodeExportFormat.kotlin:
        return _exportKotlin(collection, variables, modeId);
      case CodeExportFormat.tailwind:
        return _exportTailwind(collection, variables);
      case CodeExportFormat.styleDictionary:
        return _exportStyleDictionary(collection, variables);
      case CodeExportFormat.flutter:
        return _exportFlutter(collection, variables, modeId);
    }
  }

  String _exportCSS(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();

    if (config.includeModes && modeId == null) {
      // Export all modes
      for (final mode in collection.modes) {
        buffer.writeln('/* ${mode.name} mode */');
        buffer.writeln(_cssSelector(mode.name) + ' {');
        _writeCSS(buffer, variables, mode.id);
        buffer.writeln('}');
        buffer.writeln();
      }
    } else {
      // Export single mode
      final effectiveModeId = modeId ?? collection.defaultModeId;
      buffer.writeln(':root {');
      _writeCSS(buffer, variables, effectiveModeId);
      buffer.writeln('}');
    }

    return buffer.toString();
  }

  String _cssSelector(String modeName) {
    final lower = modeName.toLowerCase();
    if (lower == 'dark') return '[data-theme="dark"]';
    if (lower == 'light') return ':root';
    return '[data-mode="$lower"]';
  }

  void _writeCSS(StringBuffer buffer, List<DesignVariable> variables, String modeId) {
    for (final variable in variables) {
      final name = _formatName(variable.name, NamingCase.kebab);
      final prefix = config.prefix ?? '';
      final cssName = '--$prefix$name';

      if (config.includeComments && variable.description != null) {
        buffer.writeln('${config.indent}/* ${variable.description} */');
      }

      final value = _getCSSValue(variable, modeId);
      buffer.writeln('${config.indent}$cssName: $value;');
    }
  }

  String _getCSSValue(DesignVariable variable, String modeId) {
    final varValue = variable.valuesByMode[modeId];

    if (config.preserveAliases && varValue?.isAlias == true) {
      final aliasVar = resolver.variables[varValue!.aliasId!];
      if (aliasVar != null) {
        final aliasName = _formatName(aliasVar.name, NamingCase.kebab);
        final prefix = config.prefix ?? '';
        return 'var(--$prefix$aliasName)';
      }
    }

    final value = resolver.resolve(variable.id);
    return _formatCSSValue(variable.type, value);
  }

  String _formatCSSValue(VariableType type, dynamic value) {
    if (value == null) return 'initial';

    switch (type) {
      case VariableType.color:
        if (value is Color) {
          final alpha = value.alpha / 255;
          if (alpha < 1) {
            return 'rgba(${value.red}, ${value.green}, ${value.blue}, ${alpha.toStringAsFixed(2)})';
          }
          return '#${value.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        }
        return value.toString();
      case VariableType.number:
        final number = value as num;
        // Assume pixels for dimensions
        return '${number}px';
      case VariableType.string:
        return '"$value"';
      case VariableType.boolean:
        return value.toString();
    }
  }

  String _exportSCSS(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();
    final effectiveModeId = modeId ?? collection.defaultModeId;

    buffer.writeln('// Generated from ${collection.name}');
    buffer.writeln();

    for (final variable in variables) {
      final name = _formatName(variable.name, NamingCase.kebab);
      final prefix = config.prefix ?? '';

      if (config.includeComments && variable.description != null) {
        buffer.writeln('// ${variable.description}');
      }

      final value = _getSCSSValue(variable, effectiveModeId);
      buffer.writeln('\$$prefix$name: $value;');
    }

    return buffer.toString();
  }

  String _getSCSSValue(DesignVariable variable, String modeId) {
    final varValue = variable.valuesByMode[modeId];

    if (config.preserveAliases && varValue?.isAlias == true) {
      final aliasVar = resolver.variables[varValue!.aliasId!];
      if (aliasVar != null) {
        final aliasName = _formatName(aliasVar.name, NamingCase.kebab);
        final prefix = config.prefix ?? '';
        return '\$$prefix$aliasName';
      }
    }

    final value = resolver.resolve(variable.id);
    return _formatSCSSValue(variable.type, value);
  }

  String _formatSCSSValue(VariableType type, dynamic value) {
    if (value == null) return 'null';

    switch (type) {
      case VariableType.color:
        if (value is Color) {
          return '#${value.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        }
        return value.toString();
      case VariableType.number:
        final number = value as num;
        return '${number}px';
      case VariableType.string:
        return '"$value"';
      case VariableType.boolean:
        return value.toString();
    }
  }

  String _exportSASS(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    // SASS uses same syntax as SCSS for variables
    return _exportSCSS(collection, variables, modeId);
  }

  String _exportLESS(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();
    final effectiveModeId = modeId ?? collection.defaultModeId;

    buffer.writeln('// Generated from ${collection.name}');
    buffer.writeln();

    for (final variable in variables) {
      final name = _formatName(variable.name, NamingCase.kebab);
      final prefix = config.prefix ?? '';

      if (config.includeComments && variable.description != null) {
        buffer.writeln('// ${variable.description}');
      }

      final value = _getSCSSValue(variable, effectiveModeId);
      buffer.writeln('@$prefix$name: $value;');
    }

    return buffer.toString();
  }

  String _exportJS(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('// Generated from ${collection.name}');
    buffer.writeln();

    if (config.includeModes && modeId == null) {
      buffer.writeln('export const tokens = {');
      for (final mode in collection.modes) {
        buffer.writeln('${config.indent}${_formatName(mode.name, NamingCase.camel)}: {');
        _writeJSObject(buffer, variables, mode.id, config.indent + config.indent);
        buffer.writeln('${config.indent}},');
      }
      buffer.writeln('};');
    } else {
      final effectiveModeId = modeId ?? collection.defaultModeId;
      buffer.writeln('export const tokens = {');
      _writeJSObject(buffer, variables, effectiveModeId, config.indent);
      buffer.writeln('};');
    }

    return buffer.toString();
  }

  void _writeJSObject(
    StringBuffer buffer,
    List<DesignVariable> variables,
    String modeId,
    String indent,
  ) {
    for (final variable in variables) {
      final name = _formatName(variable.name, NamingCase.camel);

      if (config.includeComments && variable.description != null) {
        buffer.writeln('$indent/** ${variable.description} */');
      }

      final value = _getJSValue(variable, modeId);
      buffer.writeln('$indent$name: $value,');
    }
  }

  String _getJSValue(DesignVariable variable, String modeId) {
    final value = resolver.resolve(variable.id);
    return _formatJSValue(variable.type, value);
  }

  String _formatJSValue(VariableType type, dynamic value) {
    if (value == null) return 'null';

    switch (type) {
      case VariableType.color:
        if (value is Color) {
          return "'#${value.value.toRadixString(16).padLeft(8, '0').substring(2)}'";
        }
        return "'$value'";
      case VariableType.number:
        return value.toString();
      case VariableType.string:
        return "'${value.toString().replaceAll("'", "\\'")}'";
      case VariableType.boolean:
        return value.toString();
    }
  }

  String _exportTS(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('// Generated from ${collection.name}');
    buffer.writeln();

    // Generate types
    buffer.writeln('export interface TokenColors {');
    for (final v in variables.where((v) => v.type == VariableType.color)) {
      final name = _formatName(v.name, NamingCase.camel);
      buffer.writeln('${config.indent}$name: string;');
    }
    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('export interface TokenNumbers {');
    for (final v in variables.where((v) => v.type == VariableType.number)) {
      final name = _formatName(v.name, NamingCase.camel);
      buffer.writeln('${config.indent}$name: number;');
    }
    buffer.writeln('}');
    buffer.writeln();

    // Generate values
    buffer.write(_exportJS(collection, variables, modeId));

    return buffer.toString();
  }

  String _exportSwift(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();
    final effectiveModeId = modeId ?? collection.defaultModeId;

    buffer.writeln('// Generated from ${collection.name}');
    buffer.writeln();
    buffer.writeln('import SwiftUI');
    buffer.writeln();
    buffer.writeln('extension Color {');

    for (final variable in variables.where((v) => v.type == VariableType.color)) {
      final name = _formatName(variable.name, NamingCase.camel);
      final value = resolver.resolve<Color>(variable.id);

      if (config.includeComments && variable.description != null) {
        buffer.writeln('${config.indent}/// ${variable.description}');
      }

      if (value != null) {
        final r = value.red / 255;
        final g = value.green / 255;
        final b = value.blue / 255;
        final a = value.alpha / 255;
        buffer.writeln(
            '${config.indent}static let $name = Color(red: $r, green: $g, blue: $b, opacity: $a)');
      }
    }

    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('enum DesignTokens {');
    for (final variable in variables.where((v) => v.type == VariableType.number)) {
      final name = _formatName(variable.name, NamingCase.camel);
      final value = resolver.resolve<double>(variable.id) ?? 0;

      if (config.includeComments && variable.description != null) {
        buffer.writeln('${config.indent}/// ${variable.description}');
      }

      buffer.writeln('${config.indent}static let $name: CGFloat = $value');
    }
    buffer.writeln('}');

    return buffer.toString();
  }

  String _exportKotlin(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();
    final effectiveModeId = modeId ?? collection.defaultModeId;

    buffer.writeln('// Generated from ${collection.name}');
    buffer.writeln();
    buffer.writeln('package com.example.designtokens');
    buffer.writeln();
    buffer.writeln('import androidx.compose.ui.graphics.Color');
    buffer.writeln();
    buffer.writeln('object DesignTokens {');

    buffer.writeln('${config.indent}object Colors {');
    for (final variable in variables.where((v) => v.type == VariableType.color)) {
      final name = _formatName(variable.name, NamingCase.pascal);
      final value = resolver.resolve<Color>(variable.id);

      if (config.includeComments && variable.description != null) {
        buffer.writeln('${config.indent}${config.indent}/** ${variable.description} */');
      }

      if (value != null) {
        final hex = value.value.toRadixString(16).padLeft(8, '0').toUpperCase();
        buffer.writeln('${config.indent}${config.indent}val $name = Color(0x$hex)');
      }
    }
    buffer.writeln('${config.indent}}');
    buffer.writeln();

    buffer.writeln('${config.indent}object Dimensions {');
    for (final variable in variables.where((v) => v.type == VariableType.number)) {
      final name = _formatName(variable.name, NamingCase.pascal);
      final value = resolver.resolve<double>(variable.id) ?? 0;

      if (config.includeComments && variable.description != null) {
        buffer.writeln('${config.indent}${config.indent}/** ${variable.description} */');
      }

      buffer.writeln('${config.indent}${config.indent}const val $name = ${value}f');
    }
    buffer.writeln('${config.indent}}');

    buffer.writeln('}');

    return buffer.toString();
  }

  String _exportTailwind(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('// Generated Tailwind config from ${collection.name}');
    buffer.writeln();
    buffer.writeln('module.exports = {');
    buffer.writeln('${config.indent}theme: {');
    buffer.writeln('${config.indent}${config.indent}extend: {');

    // Colors
    buffer.writeln('${config.indent}${config.indent}${config.indent}colors: {');
    for (final variable in variables.where((v) => v.type == VariableType.color)) {
      final name = _formatName(variable.name, NamingCase.kebab);
      final value = resolver.resolve<Color>(variable.id);
      if (value != null) {
        final hex = '#${value.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        buffer.writeln("${config.indent}${config.indent}${config.indent}${config.indent}'$name': '$hex',");
      }
    }
    buffer.writeln('${config.indent}${config.indent}${config.indent}},');

    // Spacing
    buffer.writeln('${config.indent}${config.indent}${config.indent}spacing: {');
    for (final variable in variables.where((v) => v.type == VariableType.number)) {
      if (variable.name.contains('spacing') || variable.name.contains('gap')) {
        final name = _formatName(variable.name, NamingCase.kebab);
        final value = resolver.resolve<double>(variable.id) ?? 0;
        buffer.writeln("${config.indent}${config.indent}${config.indent}${config.indent}'$name': '${value}px',");
      }
    }
    buffer.writeln('${config.indent}${config.indent}${config.indent}},');

    buffer.writeln('${config.indent}${config.indent}},');
    buffer.writeln('${config.indent}},');
    buffer.writeln('};');

    return buffer.toString();
  }

  String _exportStyleDictionary(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('{');

    final grouped = <String, List<DesignVariable>>{};
    for (final v in variables) {
      final category = _getCategory(v);
      grouped.putIfAbsent(category, () => []).add(v);
    }

    final categories = grouped.keys.toList();
    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      final vars = grouped[category]!;

      buffer.writeln('${config.indent}"$category": {');

      for (var j = 0; j < vars.length; j++) {
        final v = vars[j];
        final name = _formatName(v.name.split('/').last, NamingCase.camel);
        final value = resolver.resolve(v.id);

        buffer.writeln('${config.indent}${config.indent}"$name": {');
        buffer.writeln('${config.indent}${config.indent}${config.indent}"value": ${_formatJSValue(v.type, value)},');
        buffer.writeln('${config.indent}${config.indent}${config.indent}"type": "${_sdType(v.type)}"');
        buffer.write('${config.indent}${config.indent}}');
        if (j < vars.length - 1) buffer.write(',');
        buffer.writeln();
      }

      buffer.write('${config.indent}}');
      if (i < categories.length - 1) buffer.write(',');
      buffer.writeln();
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  String _getCategory(DesignVariable variable) {
    final parts = variable.name.split('/');
    if (parts.length > 1) return parts.first;

    switch (variable.type) {
      case VariableType.color:
        return 'color';
      case VariableType.number:
        return 'size';
      default:
        return 'other';
    }
  }

  String _sdType(VariableType type) {
    switch (type) {
      case VariableType.color:
        return 'color';
      case VariableType.number:
        return 'size';
      case VariableType.string:
        return 'content';
      case VariableType.boolean:
        return 'boolean';
    }
  }

  String _exportFlutter(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    String? modeId,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('// Generated from ${collection.name}');
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln();

    buffer.writeln('abstract class DesignTokens {');

    // Colors
    buffer.writeln('${config.indent}// Colors');
    for (final variable in variables.where((v) => v.type == VariableType.color)) {
      final name = _formatName(variable.name, NamingCase.camel);
      final value = resolver.resolve<Color>(variable.id);

      if (config.includeComments && variable.description != null) {
        buffer.writeln('${config.indent}/// ${variable.description}');
      }

      if (value != null) {
        final hex = value.value.toRadixString(16).padLeft(8, '0').toUpperCase();
        buffer.writeln('${config.indent}static const Color $name = Color(0x$hex);');
      }
    }

    buffer.writeln();
    buffer.writeln('${config.indent}// Dimensions');
    for (final variable in variables.where((v) => v.type == VariableType.number)) {
      final name = _formatName(variable.name, NamingCase.camel);
      final value = resolver.resolve<double>(variable.id) ?? 0;

      if (config.includeComments && variable.description != null) {
        buffer.writeln('${config.indent}/// ${variable.description}');
      }

      buffer.writeln('${config.indent}static const double $name = $value;');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  String _formatName(String name, NamingCase targetCase) {
    // First normalize to words
    final words = name
        .replaceAll('/', '-')
        .replaceAll('_', '-')
        .split('-')
        .where((w) => w.isNotEmpty)
        .toList();

    switch (targetCase) {
      case NamingCase.kebab:
        return words.map((w) => w.toLowerCase()).join('-');
      case NamingCase.snake:
        return words.map((w) => w.toLowerCase()).join('_');
      case NamingCase.camel:
        if (words.isEmpty) return '';
        return words.first.toLowerCase() +
            words.skip(1).map((w) => _capitalize(w)).join();
      case NamingCase.pascal:
        return words.map((w) => _capitalize(w)).join();
      case NamingCase.constant:
        return words.map((w) => w.toUpperCase()).join('_');
    }
  }

  String _capitalize(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }
}
