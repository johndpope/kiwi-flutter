/// W3C Design Tokens Import/Export
///
/// Implements W3C Design Tokens Community Group specification 1.0
/// https://design-tokens.github.io/community-group/format/
///
/// Supports:
/// - Import from JSON following W3C spec
/// - Export to JSON following W3C spec
/// - Color, dimension, string, boolean tokens
/// - Token groups and hierarchy
/// - Aliases ($value references)

import 'dart:convert';
import 'package:flutter/material.dart';
import '../assets/variables.dart';
import 'extended_collections.dart';

/// W3C Design Token types
enum W3CTokenType {
  color,
  dimension,
  fontFamily,
  fontWeight,
  duration,
  cubicBezier,
  number,
  string,
  // Composite types
  strokeStyle,
  border,
  transition,
  shadow,
  gradient,
  typography,
}

/// W3C Design Token
class W3CDesignToken {
  /// Token name
  final String name;

  /// Full path (e.g., "colors.primary.500")
  final String path;

  /// Token type
  final W3CTokenType type;

  /// Value (can be direct or alias reference starting with {})
  final dynamic value;

  /// Description
  final String? description;

  /// Extensions (custom metadata)
  final Map<String, dynamic> extensions;

  const W3CDesignToken({
    required this.name,
    required this.path,
    required this.type,
    required this.value,
    this.description,
    this.extensions = const {},
  });

  /// Check if value is an alias
  bool get isAlias => value is String && (value as String).startsWith('{');

  /// Get alias path (without braces)
  String? get aliasPath {
    if (!isAlias) return null;
    final str = value as String;
    return str.substring(1, str.length - 1);
  }

  /// Convert to W3C JSON format
  Map<String, dynamic> toW3CJson() {
    final json = <String, dynamic>{
      '\$value': value,
      '\$type': _typeToString(type),
    };

    if (description != null) {
      json['\$description'] = description;
    }

    if (extensions.isNotEmpty) {
      json['\$extensions'] = extensions;
    }

    return json;
  }

  /// Create from W3C JSON
  factory W3CDesignToken.fromW3CJson(
    String name,
    String path,
    Map<String, dynamic> json,
    W3CTokenType? inheritedType,
  ) {
    final typeStr = json['\$type'] as String?;
    final type = typeStr != null ? _stringToType(typeStr) : inheritedType ?? W3CTokenType.string;

    return W3CDesignToken(
      name: name,
      path: path,
      type: type,
      value: json['\$value'],
      description: json['\$description'] as String?,
      extensions: (json['\$extensions'] as Map<String, dynamic>?) ?? {},
    );
  }

  static String _typeToString(W3CTokenType type) {
    switch (type) {
      case W3CTokenType.color:
        return 'color';
      case W3CTokenType.dimension:
        return 'dimension';
      case W3CTokenType.fontFamily:
        return 'fontFamily';
      case W3CTokenType.fontWeight:
        return 'fontWeight';
      case W3CTokenType.duration:
        return 'duration';
      case W3CTokenType.cubicBezier:
        return 'cubicBezier';
      case W3CTokenType.number:
        return 'number';
      case W3CTokenType.string:
        return 'string';
      case W3CTokenType.strokeStyle:
        return 'strokeStyle';
      case W3CTokenType.border:
        return 'border';
      case W3CTokenType.transition:
        return 'transition';
      case W3CTokenType.shadow:
        return 'shadow';
      case W3CTokenType.gradient:
        return 'gradient';
      case W3CTokenType.typography:
        return 'typography';
    }
  }

  static W3CTokenType _stringToType(String type) {
    switch (type) {
      case 'color':
        return W3CTokenType.color;
      case 'dimension':
        return W3CTokenType.dimension;
      case 'fontFamily':
        return W3CTokenType.fontFamily;
      case 'fontWeight':
        return W3CTokenType.fontWeight;
      case 'duration':
        return W3CTokenType.duration;
      case 'cubicBezier':
        return W3CTokenType.cubicBezier;
      case 'number':
        return W3CTokenType.number;
      case 'strokeStyle':
        return W3CTokenType.strokeStyle;
      case 'border':
        return W3CTokenType.border;
      case 'transition':
        return W3CTokenType.transition;
      case 'shadow':
        return W3CTokenType.shadow;
      case 'gradient':
        return W3CTokenType.gradient;
      case 'typography':
        return W3CTokenType.typography;
      default:
        return W3CTokenType.string;
    }
  }
}

/// W3C Design Tokens file representation
class W3CDesignTokensFile {
  /// File name
  final String name;

  /// All tokens
  final List<W3CDesignToken> tokens;

  /// File-level metadata
  final Map<String, dynamic> metadata;

  const W3CDesignTokensFile({
    required this.name,
    required this.tokens,
    this.metadata = const {},
  });

  /// Get tokens by type
  List<W3CDesignToken> getTokensByType(W3CTokenType type) {
    return tokens.where((t) => t.type == type).toList();
  }

  /// Get token by path
  W3CDesignToken? getTokenByPath(String path) {
    return tokens.where((t) => t.path == path).firstOrNull;
  }
}

/// W3C Design Tokens importer
class W3CDesignTokensImporter {
  /// Parse W3C Design Tokens JSON
  W3CDesignTokensFile parse(String jsonString, {String fileName = 'tokens'}) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final tokens = <W3CDesignToken>[];

    _parseTokenGroup(json, '', null, tokens);

    return W3CDesignTokensFile(
      name: fileName,
      tokens: tokens,
    );
  }

  void _parseTokenGroup(
    Map<String, dynamic> group,
    String parentPath,
    W3CTokenType? inheritedType,
    List<W3CDesignToken> tokens,
  ) {
    // Check for group-level type
    final groupType = group['\$type'] as String?;
    final currentType = groupType != null
        ? W3CDesignToken._stringToType(groupType)
        : inheritedType;

    for (final entry in group.entries) {
      // Skip $ prefixed properties (metadata)
      if (entry.key.startsWith('\$')) continue;

      final value = entry.value;
      final currentPath =
          parentPath.isEmpty ? entry.key : '$parentPath.${entry.key}';

      if (value is Map<String, dynamic>) {
        // Check if this is a token or a group
        if (value.containsKey('\$value')) {
          // This is a token
          tokens.add(W3CDesignToken.fromW3CJson(
            entry.key,
            currentPath,
            value,
            currentType,
          ));
        } else {
          // This is a group, recurse
          _parseTokenGroup(value, currentPath, currentType, tokens);
        }
      }
    }
  }

  /// Import to Figma variable format
  ImportResult importToVariables(
    W3CDesignTokensFile file, {
    String? collectionName,
    List<String> modeNames = const ['Default'],
  }) {
    final collectionId = 'collection_${DateTime.now().millisecondsSinceEpoch}';
    final modes = modeNames.asMap().entries.map((e) {
      return VariableMode(
        id: '${collectionId}_mode_${e.key}',
        name: e.value,
        index: e.key,
      );
    }).toList();

    final collection = ExtendedVariableCollection(
      id: collectionId,
      name: collectionName ?? file.name,
      modes: modes,
      defaultModeId: modes.first.id,
    );

    final variables = <DesignVariable>[];
    final aliasMap = <String, String>{}; // W3C path -> variable ID

    // First pass: create non-alias variables
    for (final token in file.tokens) {
      if (token.isAlias) continue;

      final variable = _tokenToVariable(token, collectionId, modes);
      if (variable != null) {
        variables.add(variable);
        aliasMap[token.path] = variable.id;
      }
    }

    // Second pass: create alias variables
    for (final token in file.tokens) {
      if (!token.isAlias) continue;

      final aliasPath = token.aliasPath;
      final targetId = aliasMap[aliasPath];

      if (targetId != null) {
        final variable = _createAliasVariable(
          token,
          collectionId,
          modes,
          targetId,
        );
        variables.add(variable);
        aliasMap[token.path] = variable.id;
      }
    }

    return ImportResult(
      collection: collection,
      variables: variables,
      warnings: [],
    );
  }

  DesignVariable? _tokenToVariable(
    W3CDesignToken token,
    String collectionId,
    List<VariableMode> modes,
  ) {
    final variableType = _w3cTypeToVariableType(token.type);
    if (variableType == null) return null;

    final parsedValue = _parseTokenValue(token.type, token.value);
    if (parsedValue == null) return null;

    final valuesByMode = <String, VariableValue<dynamic>>{};
    for (final mode in modes) {
      valuesByMode[mode.id] = VariableValue(value: parsedValue);
    }

    return DesignVariable(
      id: 'var_${DateTime.now().millisecondsSinceEpoch}_${token.path.hashCode}',
      name: token.path.replaceAll('.', '/'),
      type: variableType,
      collectionId: collectionId,
      valuesByMode: valuesByMode,
      description: token.description,
    );
  }

  DesignVariable _createAliasVariable(
    W3CDesignToken token,
    String collectionId,
    List<VariableMode> modes,
    String targetVariableId,
  ) {
    final variableType = _w3cTypeToVariableType(token.type) ?? VariableType.string;

    final valuesByMode = <String, VariableValue<dynamic>>{};
    for (final mode in modes) {
      valuesByMode[mode.id] = VariableValue.alias(targetVariableId);
    }

    return DesignVariable(
      id: 'var_${DateTime.now().millisecondsSinceEpoch}_${token.path.hashCode}',
      name: token.path.replaceAll('.', '/'),
      type: variableType,
      collectionId: collectionId,
      valuesByMode: valuesByMode,
      description: token.description,
    );
  }

  VariableType? _w3cTypeToVariableType(W3CTokenType type) {
    switch (type) {
      case W3CTokenType.color:
        return VariableType.color;
      case W3CTokenType.dimension:
      case W3CTokenType.number:
      case W3CTokenType.duration:
      case W3CTokenType.fontWeight:
        return VariableType.number;
      case W3CTokenType.string:
      case W3CTokenType.fontFamily:
        return VariableType.string;
      default:
        return null; // Complex types not directly supported
    }
  }

  dynamic _parseTokenValue(W3CTokenType type, dynamic value) {
    switch (type) {
      case W3CTokenType.color:
        return _parseColor(value);
      case W3CTokenType.dimension:
        return _parseDimension(value);
      case W3CTokenType.number:
      case W3CTokenType.fontWeight:
        return (value as num?)?.toDouble();
      case W3CTokenType.duration:
        return _parseDuration(value);
      case W3CTokenType.string:
      case W3CTokenType.fontFamily:
        return value?.toString();
      default:
        return null;
    }
  }

  Color? _parseColor(dynamic value) {
    if (value == null) return null;
    final str = value.toString();

    // Hex color (#RRGGBB or #RRGGBBAA)
    if (str.startsWith('#')) {
      final hex = str.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }

    // RGB/RGBA
    final rgbMatch = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)')
        .firstMatch(str);
    if (rgbMatch != null) {
      final r = int.parse(rgbMatch.group(1)!);
      final g = int.parse(rgbMatch.group(2)!);
      final b = int.parse(rgbMatch.group(3)!);
      final a = rgbMatch.group(4) != null
          ? double.parse(rgbMatch.group(4)!)
          : 1.0;
      return Color.fromRGBO(r, g, b, a);
    }

    return null;
  }

  double? _parseDimension(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final str = value.toString();
    final match = RegExp(r'^([\d.]+)(px|rem|em|%)?$').firstMatch(str);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }

    return null;
  }

  double? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final str = value.toString();
    final msMatch = RegExp(r'^([\d.]+)ms$').firstMatch(str);
    if (msMatch != null) {
      return double.tryParse(msMatch.group(1)!);
    }

    final sMatch = RegExp(r'^([\d.]+)s$').firstMatch(str);
    if (sMatch != null) {
      final seconds = double.tryParse(sMatch.group(1)!);
      return seconds != null ? seconds * 1000 : null;
    }

    return null;
  }
}

/// Result of import operation
class ImportResult {
  final ExtendedVariableCollection collection;
  final List<DesignVariable> variables;
  final List<String> warnings;

  const ImportResult({
    required this.collection,
    required this.variables,
    required this.warnings,
  });
}

/// W3C Design Tokens exporter
class W3CDesignTokensExporter {
  /// Export variables to W3C Design Tokens JSON
  String export(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    VariableResolver resolver, {
    String? modeId,
    bool prettyPrint = true,
  }) {
    final effectiveModeId = modeId ?? collection.defaultModeId;
    final json = _buildTokensJson(collection, variables, resolver, effectiveModeId);

    if (prettyPrint) {
      return const JsonEncoder.withIndent('  ').convert(json);
    }
    return jsonEncode(json);
  }

  Map<String, dynamic> _buildTokensJson(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    VariableResolver resolver,
    String modeId,
  ) {
    final json = <String, dynamic>{};

    // Group variables by path segments
    final grouped = <String, List<DesignVariable>>{};
    for (final variable in variables) {
      final parts = variable.name.split('/');
      final groupPath = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '';
      grouped.putIfAbsent(groupPath, () => []).add(variable);
    }

    for (final entry in grouped.entries) {
      final groupPath = entry.key;
      final groupVariables = entry.value;

      Map<String, dynamic> targetMap = json;

      // Navigate/create nested structure
      if (groupPath.isNotEmpty) {
        for (final segment in groupPath.split('/')) {
          targetMap.putIfAbsent(segment, () => <String, dynamic>{});
          targetMap = targetMap[segment] as Map<String, dynamic>;
        }
      }

      // Add variables to current group
      for (final variable in groupVariables) {
        final tokenName = variable.name.split('/').last;
        targetMap[tokenName] = _variableToToken(variable, resolver, modeId);
      }
    }

    return json;
  }

  Map<String, dynamic> _variableToToken(
    DesignVariable variable,
    VariableResolver resolver,
    String modeId,
  ) {
    final varValue = variable.valuesByMode[modeId];
    final json = <String, dynamic>{
      '\$type': _variableTypeToW3C(variable.type),
    };

    if (varValue?.isAlias == true && varValue?.aliasId != null) {
      // Export as alias reference
      final aliasVariable = resolver.variables[varValue!.aliasId!];
      if (aliasVariable != null) {
        json['\$value'] = '{${aliasVariable.name.replaceAll('/', '.')}}';
      }
    } else {
      // Export direct value
      json['\$value'] = _formatValue(variable.type, varValue?.value);
    }

    if (variable.description != null) {
      json['\$description'] = variable.description;
    }

    return json;
  }

  String _variableTypeToW3C(VariableType type) {
    switch (type) {
      case VariableType.color:
        return 'color';
      case VariableType.number:
        return 'number';
      case VariableType.string:
        return 'string';
      case VariableType.boolean:
        return 'string'; // W3C doesn't have boolean type
    }
  }

  dynamic _formatValue(VariableType type, dynamic value) {
    if (value == null) return null;

    switch (type) {
      case VariableType.color:
        if (value is Color) {
          return '#${value.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        }
        return value.toString();
      case VariableType.number:
        return value;
      case VariableType.string:
        return value.toString();
      case VariableType.boolean:
        return value.toString();
    }
  }

  /// Export to file bytes (UTF-8)
  List<int> exportToBytes(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    VariableResolver resolver, {
    String? modeId,
  }) {
    final json = export(collection, variables, resolver, modeId: modeId);
    return utf8.encode(json);
  }
}

/// Combined import/export handler
class DesignTokensIO {
  final W3CDesignTokensImporter _importer = W3CDesignTokensImporter();
  final W3CDesignTokensExporter _exporter = W3CDesignTokensExporter();

  /// Import from JSON string
  ImportResult import(
    String jsonString, {
    String? collectionName,
    List<String> modeNames = const ['Default'],
  }) {
    final file = _importer.parse(jsonString);
    return _importer.importToVariables(
      file,
      collectionName: collectionName,
      modeNames: modeNames,
    );
  }

  /// Export to JSON string
  String export(
    ExtendedVariableCollection collection,
    List<DesignVariable> variables,
    VariableResolver resolver, {
    String? modeId,
  }) {
    return _exporter.export(collection, variables, resolver, modeId: modeId);
  }

  /// Validate W3C format
  ValidationResult validate(String jsonString) {
    try {
      final file = _importer.parse(jsonString);
      final errors = <String>[];
      final warnings = <String>[];

      for (final token in file.tokens) {
        // Check for common issues
        if (token.value == null) {
          warnings.add('Token "${token.path}" has null value');
        }

        if (token.isAlias) {
          final aliasPath = token.aliasPath;
          final target = file.getTokenByPath(aliasPath!);
          if (target == null) {
            errors.add('Token "${token.path}" references unknown alias: $aliasPath');
          }
        }
      }

      return ValidationResult(
        valid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        tokenCount: file.tokens.length,
      );
    } catch (e) {
      return ValidationResult(
        valid: false,
        errors: ['Parse error: $e'],
        warnings: [],
        tokenCount: 0,
      );
    }
  }
}

/// Validation result
class ValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;
  final int tokenCount;

  const ValidationResult({
    required this.valid,
    required this.errors,
    required this.warnings,
    required this.tokenCount,
  });
}
