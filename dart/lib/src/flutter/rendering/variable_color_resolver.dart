/// Variable color resolver for Figma colorVar references
///
/// Resolves colorVar references to actual Color values by looking up
/// VARIABLE nodes in the nodeMap and extracting color values from
/// variableDataValues based on the current mode.

import 'package:flutter/material.dart';

/// Resolves colorVar references to actual Flutter Color values
class VariableColorResolver {
  final Map<String, Map<String, dynamic>>? nodeMap;

  /// Current mode ID for variable resolution (e.g., "128:0" for Light, "128:4" for Dark)
  final String currentModeId;

  /// Cache for resolved colors to avoid repeated lookups
  final Map<String, Color?> _cache = {};

  VariableColorResolver({
    required this.nodeMap,
    this.currentModeId = '128:0', // Default to Light mode
  });

  /// Resolve a colorVar to a Color
  ///
  /// Returns null if the colorVar cannot be resolved (e.g., external library reference)
  Color? resolveColorVar(Map<String, dynamic>? colorVar, {int maxDepth = 10, bool debug = false}) {
    if (colorVar == null || nodeMap == null || maxDepth <= 0) return null;

    final value = colorVar['value'];
    if (value is! Map) return null;

    final alias = value['alias'];
    if (alias is! Map) return null;

    // Check for GUID-based reference (internal variable)
    if (alias['guid'] is Map) {
      final guid = alias['guid'] as Map;
      final guidKey = '${guid['sessionID']}:${guid['localID']}';

      // Check cache first
      if (_cache.containsKey(guidKey)) {
        if (debug) print('🔗 RESOLVED colorVar (cached): $guidKey -> ${_cache[guidKey]}');
        return _cache[guidKey];
      }

      final color = _resolveVariableGuid(guidKey, maxDepth: maxDepth - 1);
      _cache[guidKey] = color;
      if (debug && color != null) {
        print('🔗 RESOLVED colorVar: $guidKey -> $color');
      }
      return color;
    }

    // assetRef-based references are from external libraries - cannot resolve
    // These need the original library file or fallback colors
    if (alias['assetRef'] is Map) {
      // Could potentially log or return a placeholder color here
      return null;
    }

    return null;
  }

  /// Resolve a variable GUID to its color value
  Color? _resolveVariableGuid(String guidKey, {int maxDepth = 10}) {
    if (maxDepth <= 0) return null;

    final varNode = nodeMap?[guidKey];
    if (varNode == null) return null;

    final type = varNode['type']?.toString();
    if (type != 'VARIABLE') return null;

    final variableDataValues = varNode['variableDataValues'];
    if (variableDataValues is! Map) return null;

    final entries = variableDataValues['entries'];
    if (entries is! List) return null;

    // Parse current mode ID
    final modeParts = currentModeId.split(':');
    final modeSessionId = modeParts.length > 0 ? int.tryParse(modeParts[0]) : null;
    final modeLocalId = modeParts.length > 1 ? int.tryParse(modeParts[1]) : null;

    // Find the matching mode entry or fall back to first entry
    Map<String, dynamic>? matchingEntry;
    Map<String, dynamic>? firstEntry;

    for (final entry in entries) {
      if (entry is! Map) continue;
      firstEntry ??= entry as Map<String, dynamic>;

      final modeID = entry['modeID'];
      if (modeID is Map) {
        if (modeID['sessionID'] == modeSessionId && modeID['localID'] == modeLocalId) {
          matchingEntry = entry as Map<String, dynamic>;
          break;
        }
      }
    }

    final entryToUse = matchingEntry ?? firstEntry;
    if (entryToUse == null) return null;

    final variableData = entryToUse['variableData'];
    if (variableData is! Map) return null;

    final dataType = variableData['dataType']?.toString();
    final valueData = variableData['value'];
    if (valueData is! Map) return null;

    // Check if it's a direct color value
    if (dataType == 'COLOR') {
      final colorValue = valueData['colorValue'];
      if (colorValue is Map) {
        return _buildColor(colorValue.cast<String, dynamic>());
      }
    }

    // Check if it's an alias to another variable
    if (dataType == 'ALIAS') {
      final alias = valueData['alias'];
      if (alias is Map) {
        final aliasGuid = alias['guid'];
        if (aliasGuid is Map) {
          final aliasKey = '${aliasGuid['sessionID']}:${aliasGuid['localID']}';
          return _resolveVariableGuid(aliasKey, maxDepth: maxDepth - 1);
        }
      }
    }

    return null;
  }

  /// Build a Flutter Color from Figma color data
  static Color _buildColor(Map<String, dynamic> colorData) {
    final r = (colorData['r'] as num?)?.toDouble() ?? 0;
    final g = (colorData['g'] as num?)?.toDouble() ?? 0;
    final b = (colorData['b'] as num?)?.toDouble() ?? 0;
    final a = (colorData['a'] as num?)?.toDouble() ?? 1.0;

    return Color.fromRGBO(
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
      a,
    );
  }

  /// Resolve a fill's color, preferring colorVar resolution over static color
  ///
  /// Returns the resolved color from colorVar if available,
  /// otherwise falls back to the static color field
  Color? resolveFillColor(Map<String, dynamic> fill) {
    // First try to resolve colorVar
    final colorVar = fill['colorVar'];
    if (colorVar is Map) {
      final resolvedColor = resolveColorVar(colorVar.cast<String, dynamic>());
      if (resolvedColor != null) {
        return resolvedColor;
      }
    }

    // Fall back to static color
    final colorData = fill['color'];
    if (colorData is Map) {
      return _buildColor(colorData.cast<String, dynamic>());
    }

    return null;
  }

  /// Clear the resolution cache
  void clearCache() {
    _cache.clear();
  }
}

/// Default light mode ID for variable resolution
const String kLightModeId = '128:0';

/// Default dark mode ID for variable resolution
const String kDarkModeId = '128:4';
