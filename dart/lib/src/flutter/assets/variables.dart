/// Variable system for dynamic design tokens
///
/// Supports:
/// - Color variables
/// - Number variables
/// - String variables
/// - Boolean variables
/// - Variable modes (light/dark, breakpoints)
/// - Variable collections
/// - Variable bindings to node properties

import 'package:flutter/material.dart';

/// Variable type enumeration
enum VariableType {
  color,
  number,
  string,
  boolean,
}

/// Variable resolve type (how value is determined)
enum VariableResolveType {
  /// Direct value
  value,

  /// Reference to another variable
  alias,
}

/// Variable mode (e.g., light, dark, compact, expanded)
class VariableMode {
  /// Mode ID
  final String id;

  /// Mode name (e.g., "Light", "Dark")
  final String name;

  /// Mode index for ordering
  final int index;

  /// Emoji for visual indicator (e.g., "☀️" for Light, "🌙" for Dark)
  final String? emoji;

  const VariableMode({
    required this.id,
    required this.name,
    this.index = 0,
    this.emoji,
  });

  /// Default light mode
  static const light = VariableMode(id: 'light', name: 'Light', index: 0, emoji: '☀️');

  /// Default dark mode
  static const dark = VariableMode(id: 'dark', name: 'Dark', index: 1, emoji: '🌙');

  /// Display name with emoji
  String get displayName => emoji != null ? '$emoji $name' : name;

  /// Create from Figma mode data
  factory VariableMode.fromMap(Map<String, dynamic> map, int index) {
    final name = map['name'] as String? ?? 'Mode $index';
    return VariableMode(
      id: map['modeId']?.toString() ?? '',
      name: name,
      index: index,
      emoji: _inferEmoji(name),
    );
  }

  /// Infer emoji from mode name
  static String? _inferEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('light')) return '☀️';
    if (lower.contains('dark')) return '🌙';
    if (lower.contains('mobile')) return '📱';
    if (lower.contains('desktop')) return '🖥️';
    if (lower.contains('tablet')) return '📱';
    if (lower.contains('default')) return '⭐';
    return null;
  }

  VariableMode copyWith({
    String? id,
    String? name,
    int? index,
    String? emoji,
  }) {
    return VariableMode(
      id: id ?? this.id,
      name: name ?? this.name,
      index: index ?? this.index,
      emoji: emoji ?? this.emoji,
    );
  }
}

/// Variable group within a collection
class VariableGroup {
  /// Group ID
  final String id;

  /// Group name (e.g., "system", "bg", "grouped-bg")
  final String name;

  /// Number of variables in this group
  final int variableCount;

  /// Parent group ID (for nested groups)
  final String? parentGroupId;

  const VariableGroup({
    required this.id,
    required this.name,
    this.variableCount = 0,
    this.parentGroupId,
  });

  /// Extract group name from variable path (e.g., "system/red" -> "system")
  static String? extractGroupFromPath(String variableName) {
    final parts = variableName.split('/');
    if (parts.length > 1) {
      return parts.first;
    }
    return null;
  }
}

/// Variable collection (groups variables with shared modes)
class VariableCollection {
  /// Collection ID
  final String id;

  /// Collection name
  final String name;

  /// Display order (1-based for display: "1. Themes")
  final int order;

  /// Available modes in this collection
  final List<VariableMode> modes;

  /// Default mode ID
  final String defaultModeId;

  /// Whether this collection is remote (from library)
  final bool remote;

  /// Whether modes are hidden from users
  final bool hiddenFromPublishing;

  const VariableCollection({
    required this.id,
    required this.name,
    this.order = 0,
    required this.modes,
    required this.defaultModeId,
    this.remote = false,
    this.hiddenFromPublishing = false,
  });

  /// Display name with order (e.g., "1. Themes")
  String get displayName => order > 0 ? '$order. $name' : name;

  /// Create from Figma collection data
  factory VariableCollection.fromMap(Map<String, dynamic> map, {int order = 0}) {
    final modesData = map['modes'] as List<dynamic>? ?? [];
    final modes = <VariableMode>[];
    for (var i = 0; i < modesData.length; i++) {
      modes.add(VariableMode.fromMap(modesData[i] as Map<String, dynamic>, i));
    }

    return VariableCollection(
      id: map['id']?.toString() ?? '',
      name: map['name'] as String? ?? 'Collection',
      order: order,
      modes: modes,
      defaultModeId: map['defaultModeId']?.toString() ?? modes.firstOrNull?.id ?? '',
      remote: map['remote'] as bool? ?? false,
      hiddenFromPublishing: map['hiddenFromPublishing'] as bool? ?? false,
    );
  }

  /// Get mode by ID
  VariableMode? getModeById(String modeId) {
    return modes.where((m) => m.id == modeId).firstOrNull;
  }

  /// Get default mode
  VariableMode? get defaultMode => getModeById(defaultModeId);

  VariableCollection copyWith({
    String? id,
    String? name,
    int? order,
    List<VariableMode>? modes,
    String? defaultModeId,
    bool? remote,
    bool? hiddenFromPublishing,
  }) {
    return VariableCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      modes: modes ?? this.modes,
      defaultModeId: defaultModeId ?? this.defaultModeId,
      remote: remote ?? this.remote,
      hiddenFromPublishing: hiddenFromPublishing ?? this.hiddenFromPublishing,
    );
  }
}

/// Variable value for a specific mode
class VariableValue<T> {
  /// The value
  final T value;

  /// Resolve type
  final VariableResolveType resolveType;

  /// Alias variable ID (if resolveType is alias)
  final String? aliasId;

  const VariableValue({
    required this.value,
    this.resolveType = VariableResolveType.value,
    this.aliasId,
  });

  /// Create an alias reference
  factory VariableValue.alias(String variableId) {
    return VariableValue(
      value: null as T,
      resolveType: VariableResolveType.alias,
      aliasId: variableId,
    );
  }

  /// Check if this is an alias
  bool get isAlias => resolveType == VariableResolveType.alias;
}

/// Design variable
class DesignVariable {
  /// Variable ID
  final String id;

  /// Variable name
  final String name;

  /// Variable type
  final VariableType type;

  /// Collection ID this variable belongs to
  final String collectionId;

  /// Values by mode ID
  final Map<String, VariableValue<dynamic>> valuesByMode;

  /// Scopes where this variable can be used
  final List<VariableScope> scopes;

  /// Code syntax (for developers)
  final String? codeSyntax;

  /// Description
  final String? description;

  /// Whether this is a remote variable
  final bool remote;

  const DesignVariable({
    required this.id,
    required this.name,
    required this.type,
    required this.collectionId,
    required this.valuesByMode,
    this.scopes = const [VariableScope.allScopes],
    this.codeSyntax,
    this.description,
    this.remote = false,
  });

  /// Create from Figma variable data
  factory DesignVariable.fromMap(Map<String, dynamic> map) {
    final typeStr = map['resolvedType'] as String? ?? 'STRING';
    VariableType type;
    switch (typeStr) {
      case 'COLOR':
        type = VariableType.color;
        break;
      case 'FLOAT':
        type = VariableType.number;
        break;
      case 'BOOLEAN':
        type = VariableType.boolean;
        break;
      default:
        type = VariableType.string;
    }

    // Parse values by mode
    final valuesByModeData = map['valuesByMode'] as Map<String, dynamic>? ?? {};
    final valuesByMode = <String, VariableValue<dynamic>>{};

    for (final entry in valuesByModeData.entries) {
      final modeId = entry.key;
      final valueData = entry.value;

      if (valueData is Map<String, dynamic>) {
        if (valueData['type'] == 'VARIABLE_ALIAS') {
          valuesByMode[modeId] = VariableValue.alias(
            valueData['id']?.toString() ?? '',
          );
        } else {
          // Parse the actual value based on type
          valuesByMode[modeId] = VariableValue(
            value: _parseValue(type, valueData),
          );
        }
      } else {
        valuesByMode[modeId] = VariableValue(value: valueData);
      }
    }

    // Parse scopes
    final scopesData = map['scopes'] as List<dynamic>? ?? ['ALL_SCOPES'];
    final scopes = scopesData.map((s) => _parseScope(s as String)).toList();

    return DesignVariable(
      id: map['id']?.toString() ?? '',
      name: map['name'] as String? ?? 'Variable',
      type: type,
      collectionId: map['variableCollectionId']?.toString() ?? '',
      valuesByMode: valuesByMode,
      scopes: scopes,
      codeSyntax: map['codeSyntax']?['WEB'] as String?,
      description: map['description'] as String?,
      remote: map['remote'] as bool? ?? false,
    );
  }

  static dynamic _parseValue(VariableType type, dynamic data) {
    if (data == null) return null;

    switch (type) {
      case VariableType.color:
        if (data is Map<String, dynamic>) {
          return Color.fromRGBO(
            ((data['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((data['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((data['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (data['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        return Colors.black;
      case VariableType.number:
        return (data as num?)?.toDouble() ?? 0.0;
      case VariableType.boolean:
        return data as bool? ?? false;
      case VariableType.string:
        return data?.toString() ?? '';
    }
  }

  static VariableScope _parseScope(String scope) {
    switch (scope) {
      case 'ALL_SCOPES':
        return VariableScope.allScopes;
      case 'TEXT_CONTENT':
        return VariableScope.textContent;
      case 'CORNER_RADIUS':
        return VariableScope.cornerRadius;
      case 'WIDTH_HEIGHT':
        return VariableScope.widthHeight;
      case 'GAP':
        return VariableScope.gap;
      case 'ALL_FILLS':
        return VariableScope.allFills;
      case 'FRAME_FILL':
        return VariableScope.frameFill;
      case 'SHAPE_FILL':
        return VariableScope.shapeFill;
      case 'TEXT_FILL':
        return VariableScope.textFill;
      case 'STROKE_COLOR':
        return VariableScope.strokeColor;
      case 'EFFECT_COLOR':
        return VariableScope.effectColor;
      default:
        return VariableScope.allScopes;
    }
  }

  /// Get value for a specific mode
  T? getValue<T>(String modeId) {
    final varValue = valuesByMode[modeId];
    if (varValue == null) return null;
    if (varValue.isAlias) return null; // Needs resolution
    return varValue.value as T?;
  }

  /// Get color value
  Color? getColorValue(String modeId) => getValue<Color>(modeId);

  /// Get number value
  double? getNumberValue(String modeId) => getValue<double>(modeId);

  /// Get string value
  String? getStringValue(String modeId) => getValue<String>(modeId);

  /// Get boolean value
  bool? getBooleanValue(String modeId) => getValue<bool>(modeId);
}

/// Variable scope (where it can be used)
enum VariableScope {
  allScopes,
  textContent,
  cornerRadius,
  widthHeight,
  gap,
  allFills,
  frameFill,
  shapeFill,
  textFill,
  strokeColor,
  effectColor,
}

/// Variable binding to a node property
class VariableBoundProperty {
  /// Node ID
  final String nodeId;

  /// Property name (e.g., "fills", "cornerRadius")
  final String property;

  /// Variable ID
  final String variableId;

  /// Field within property (e.g., index for array properties)
  final String? field;

  const VariableBoundProperty({
    required this.nodeId,
    required this.property,
    required this.variableId,
    this.field,
  });
}

/// Variable resolver for computing values
class VariableResolver {
  /// All variables by ID
  final Map<String, DesignVariable> variables;

  /// All collections by ID
  final Map<String, VariableCollection> collections;

  /// Current mode IDs by collection ID
  final Map<String, String> currentModes;

  VariableResolver({
    required this.variables,
    required this.collections,
    Map<String, String>? currentModes,
  }) : currentModes = currentModes ?? {};

  /// Get the current mode for a collection
  String getModeId(String collectionId) {
    return currentModes[collectionId] ??
        collections[collectionId]?.defaultModeId ??
        '';
  }

  /// Set the current mode for a collection
  void setMode(String collectionId, String modeId) {
    currentModes[collectionId] = modeId;
  }

  /// Resolve a variable value
  T? resolve<T>(String variableId, {int maxDepth = 10}) {
    if (maxDepth <= 0) return null; // Prevent infinite loops

    final variable = variables[variableId];
    if (variable == null) return null;

    final modeId = getModeId(variable.collectionId);
    final varValue = variable.valuesByMode[modeId];

    if (varValue == null) return null;

    if (varValue.isAlias && varValue.aliasId != null) {
      // Recursively resolve alias
      return resolve<T>(varValue.aliasId!, maxDepth: maxDepth - 1);
    }

    return varValue.value as T?;
  }

  /// Resolve a color variable
  Color? resolveColor(String variableId) => resolve<Color>(variableId);

  /// Resolve a number variable
  double? resolveNumber(String variableId) => resolve<double>(variableId);

  /// Resolve a string variable
  String? resolveString(String variableId) => resolve<String>(variableId);

  /// Resolve a boolean variable
  bool? resolveBoolean(String variableId) => resolve<bool>(variableId);

  /// Get all variables in a collection
  List<DesignVariable> getVariablesInCollection(String collectionId) {
    return variables.values
        .where((v) => v.collectionId == collectionId)
        .toList();
  }

  /// Get all color variables
  List<DesignVariable> get colorVariables =>
      variables.values.where((v) => v.type == VariableType.color).toList();

  /// Get all number variables
  List<DesignVariable> get numberVariables =>
      variables.values.where((v) => v.type == VariableType.number).toList();

  /// Switch all collections to a named mode (e.g., "Dark")
  void switchToNamedMode(String modeName) {
    for (final collection in collections.values) {
      final mode = collection.modes.where((m) => m.name == modeName).firstOrNull;
      if (mode != null) {
        currentModes[collection.id] = mode.id;
      }
    }
  }

  /// Create from Figma document variables
  factory VariableResolver.fromDocument(Map<String, dynamic> variablesData) {
    final collectionsData = variablesData['variableCollections'] as Map<String, dynamic>? ?? {};
    final variablesMap = variablesData['variables'] as Map<String, dynamic>? ?? {};

    final collections = <String, VariableCollection>{};
    for (final entry in collectionsData.entries) {
      final collection = VariableCollection.fromMap(entry.value as Map<String, dynamic>);
      collections[collection.id] = collection;
    }

    final variables = <String, DesignVariable>{};
    for (final entry in variablesMap.entries) {
      final variable = DesignVariable.fromMap(entry.value as Map<String, dynamic>);
      variables[variable.id] = variable;
    }

    return VariableResolver(
      variables: variables,
      collections: collections,
    );
  }
}

/// Variable manager for editing and creating variables
class VariableManager extends ChangeNotifier {
  final VariableResolver _resolver;

  VariableManager(this._resolver);

  VariableResolver get resolver => _resolver;

  /// Create a new variable
  DesignVariable createVariable({
    required String name,
    required VariableType type,
    required String collectionId,
    required Map<String, dynamic> valuesByMode,
  }) {
    final id = 'var_${DateTime.now().millisecondsSinceEpoch}';
    final variable = DesignVariable(
      id: id,
      name: name,
      type: type,
      collectionId: collectionId,
      valuesByMode: valuesByMode.map(
        (k, v) => MapEntry(k, VariableValue(value: v)),
      ),
    );

    _resolver.variables[id] = variable;
    notifyListeners();
    return variable;
  }

  /// Create a new collection
  VariableCollection createCollection({
    required String name,
    List<String> modeNames = const ['Default'],
  }) {
    final id = 'collection_${DateTime.now().millisecondsSinceEpoch}';
    final modes = modeNames.asMap().entries.map((e) {
      return VariableMode(
        id: '${id}_mode_${e.key}',
        name: e.value,
        index: e.key,
      );
    }).toList();

    final collection = VariableCollection(
      id: id,
      name: name,
      modes: modes,
      defaultModeId: modes.first.id,
    );

    _resolver.collections[id] = collection;
    notifyListeners();
    return collection;
  }

  /// Update a variable value for a mode
  void updateVariableValue(String variableId, String modeId, dynamic value) {
    final variable = _resolver.variables[variableId];
    if (variable == null) return;

    final newValuesByMode = Map<String, VariableValue<dynamic>>.from(variable.valuesByMode);
    newValuesByMode[modeId] = VariableValue(value: value);

    _resolver.variables[variableId] = DesignVariable(
      id: variable.id,
      name: variable.name,
      type: variable.type,
      collectionId: variable.collectionId,
      valuesByMode: newValuesByMode,
      scopes: variable.scopes,
      codeSyntax: variable.codeSyntax,
      description: variable.description,
      remote: variable.remote,
    );

    notifyListeners();
  }

  /// Delete a variable
  void deleteVariable(String variableId) {
    _resolver.variables.remove(variableId);
    notifyListeners();
  }

  /// Switch mode
  void switchMode(String collectionId, String modeId) {
    _resolver.setMode(collectionId, modeId);
    notifyListeners();
  }

  /// Switch all to named mode
  void switchAllToNamedMode(String modeName) {
    _resolver.switchToNamedMode(modeName);
    notifyListeners();
  }
}

/// Theme data generated from variables
class VariableThemeData {
  /// Color scheme from color variables
  final ColorScheme? colorScheme;

  /// Text theme from text variables
  final TextTheme? textTheme;

  /// Custom color map
  final Map<String, Color> colors;

  /// Custom number map
  final Map<String, double> numbers;

  const VariableThemeData({
    this.colorScheme,
    this.textTheme,
    this.colors = const {},
    this.numbers = const {},
  });

  /// Generate from variable resolver
  factory VariableThemeData.fromResolver(VariableResolver resolver) {
    final colors = <String, Color>{};
    final numbers = <String, double>{};

    for (final variable in resolver.variables.values) {
      switch (variable.type) {
        case VariableType.color:
          final color = resolver.resolveColor(variable.id);
          if (color != null) {
            colors[variable.name] = color;
          }
          break;
        case VariableType.number:
          final number = resolver.resolveNumber(variable.id);
          if (number != null) {
            numbers[variable.name] = number;
          }
          break;
        default:
          break;
      }
    }

    return VariableThemeData(
      colors: colors,
      numbers: numbers,
    );
  }
}
