/// Extended Collections for Variables
///
/// Supports:
/// - Collection inheritance (parent/child relationships)
/// - Multi-brand inheritance
/// - Override mechanisms
/// - Auto-sync of changes from parent to children
/// - Extended mode limits (up to 20+ modes)

import 'package:flutter/foundation.dart';
import '../assets/variables.dart';

/// Extended collection with inheritance support
class ExtendedVariableCollection extends VariableCollection {
  /// Parent collection ID (for inheritance)
  final String? parentCollectionId;

  /// Whether this collection inherits from parent
  final bool inheritsFromParent;

  /// Overridden variable IDs (local overrides of parent variables)
  final Set<String> overriddenVariableIds;

  /// Brand identifier for multi-brand support
  final String? brandId;

  /// Brand name
  final String? brandName;

  /// Whether this is a library collection
  final bool isLibrary;

  /// Library ID if published
  final String? libraryId;

  /// Subscribers (collection IDs that subscribe to this)
  final List<String> subscriberIds;

  /// Last sync timestamp
  final DateTime? lastSyncTime;

  /// Max modes (soft limit, can be increased)
  final int maxModes;

  const ExtendedVariableCollection({
    required super.id,
    required super.name,
    super.order = 0,
    required super.modes,
    required super.defaultModeId,
    super.remote = false,
    super.hiddenFromPublishing = false,
    this.parentCollectionId,
    this.inheritsFromParent = false,
    this.overriddenVariableIds = const {},
    this.brandId,
    this.brandName,
    this.isLibrary = false,
    this.libraryId,
    this.subscriberIds = const [],
    this.lastSyncTime,
    this.maxModes = 20,
  });

  /// Create from base collection
  factory ExtendedVariableCollection.fromBase(
    VariableCollection base, {
    String? parentCollectionId,
    bool inheritsFromParent = false,
    Set<String>? overriddenVariableIds,
    String? brandId,
    String? brandName,
    bool isLibrary = false,
    String? libraryId,
    List<String>? subscriberIds,
    int maxModes = 20,
  }) {
    return ExtendedVariableCollection(
      id: base.id,
      name: base.name,
      order: base.order,
      modes: base.modes,
      defaultModeId: base.defaultModeId,
      remote: base.remote,
      hiddenFromPublishing: base.hiddenFromPublishing,
      parentCollectionId: parentCollectionId,
      inheritsFromParent: inheritsFromParent,
      overriddenVariableIds: overriddenVariableIds ?? {},
      brandId: brandId,
      brandName: brandName,
      isLibrary: isLibrary,
      libraryId: libraryId,
      subscriberIds: subscriberIds ?? [],
      maxModes: maxModes,
    );
  }

  /// Create from map with extended fields
  factory ExtendedVariableCollection.fromMap(Map<String, dynamic> map) {
    final base = VariableCollection.fromMap(map);
    return ExtendedVariableCollection.fromBase(
      base,
      parentCollectionId: map['parentCollectionId'] as String?,
      inheritsFromParent: map['inheritsFromParent'] as bool? ?? false,
      overriddenVariableIds:
          (map['overriddenVariableIds'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
      brandId: map['brandId'] as String?,
      brandName: map['brandName'] as String?,
      isLibrary: map['isLibrary'] as bool? ?? false,
      libraryId: map['libraryId'] as String?,
      subscriberIds: (map['subscriberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      maxModes: map['maxModes'] as int? ?? 20,
    );
  }

  /// Check if can add more modes
  bool get canAddMoreModes => modes.length < maxModes;

  /// Check if variable is overridden locally
  bool isOverridden(String variableId) => overriddenVariableIds.contains(variableId);

  /// Copy with modifications
  @override
  ExtendedVariableCollection copyWith({
    String? id,
    String? name,
    int? order,
    List<VariableMode>? modes,
    String? defaultModeId,
    bool? remote,
    bool? hiddenFromPublishing,
    String? parentCollectionId,
    bool? inheritsFromParent,
    Set<String>? overriddenVariableIds,
    String? brandId,
    String? brandName,
    bool? isLibrary,
    String? libraryId,
    List<String>? subscriberIds,
    DateTime? lastSyncTime,
    int? maxModes,
  }) {
    return ExtendedVariableCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      modes: modes ?? this.modes,
      defaultModeId: defaultModeId ?? this.defaultModeId,
      remote: remote ?? this.remote,
      hiddenFromPublishing: hiddenFromPublishing ?? this.hiddenFromPublishing,
      parentCollectionId: parentCollectionId ?? this.parentCollectionId,
      inheritsFromParent: inheritsFromParent ?? this.inheritsFromParent,
      overriddenVariableIds: overriddenVariableIds ?? this.overriddenVariableIds,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      isLibrary: isLibrary ?? this.isLibrary,
      libraryId: libraryId ?? this.libraryId,
      subscriberIds: subscriberIds ?? this.subscriberIds,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      maxModes: maxModes ?? this.maxModes,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'modes': modes.map((m) => {'modeId': m.id, 'name': m.name}).toList(),
      'defaultModeId': defaultModeId,
      'remote': remote,
      'hiddenFromPublishing': hiddenFromPublishing,
      'parentCollectionId': parentCollectionId,
      'inheritsFromParent': inheritsFromParent,
      'overriddenVariableIds': overriddenVariableIds.toList(),
      'brandId': brandId,
      'brandName': brandName,
      'isLibrary': isLibrary,
      'libraryId': libraryId,
      'subscriberIds': subscriberIds,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'maxModes': maxModes,
    };
  }
}

/// Collection inheritance manager
class CollectionInheritanceManager extends ChangeNotifier {
  /// All extended collections by ID
  final Map<String, ExtendedVariableCollection> _collections = {};

  /// Variables by ID
  final Map<String, DesignVariable> _variables = {};

  /// Get all collections
  Map<String, ExtendedVariableCollection> get collections =>
      Map.unmodifiable(_collections);

  /// Get all variables
  Map<String, DesignVariable> get variables => Map.unmodifiable(_variables);

  /// Add a collection
  void addCollection(ExtendedVariableCollection collection) {
    _collections[collection.id] = collection;
    notifyListeners();
  }

  /// Remove a collection
  void removeCollection(String collectionId) {
    _collections.remove(collectionId);
    // Also remove variables in this collection
    _variables.removeWhere((_, v) => v.collectionId == collectionId);
    notifyListeners();
  }

  /// Add a variable
  void addVariable(DesignVariable variable) {
    _variables[variable.id] = variable;
    notifyListeners();
  }

  /// Remove a variable
  void removeVariable(String variableId) {
    _variables.remove(variableId);
    notifyListeners();
  }

  /// Create child collection from parent
  ExtendedVariableCollection createChildCollection({
    required String parentId,
    required String name,
    String? brandId,
    String? brandName,
  }) {
    final parent = _collections[parentId];
    if (parent == null) {
      throw ArgumentError('Parent collection not found: $parentId');
    }

    final childId = 'collection_${DateTime.now().millisecondsSinceEpoch}';

    // Copy modes from parent
    final childModes = parent.modes.map((m) {
      return VariableMode(
        id: '${childId}_${m.id}',
        name: m.name,
        index: m.index,
      );
    }).toList();

    final child = ExtendedVariableCollection(
      id: childId,
      name: name,
      modes: childModes,
      defaultModeId: childModes.isNotEmpty ? childModes.first.id : '',
      parentCollectionId: parentId,
      inheritsFromParent: true,
      brandId: brandId,
      brandName: brandName,
    );

    _collections[childId] = child;

    // Copy variables from parent with inheritance
    final parentVariables =
        _variables.values.where((v) => v.collectionId == parentId);
    for (final pv in parentVariables) {
      final childVariable = _createInheritedVariable(pv, childId, childModes);
      _variables[childVariable.id] = childVariable;
    }

    notifyListeners();
    return child;
  }

  DesignVariable _createInheritedVariable(
    DesignVariable parent,
    String childCollectionId,
    List<VariableMode> childModes,
  ) {
    final childId = 'var_${DateTime.now().millisecondsSinceEpoch}_${parent.id}';

    // Create alias values pointing to parent
    final valuesByMode = <String, VariableValue<dynamic>>{};
    for (final mode in childModes) {
      valuesByMode[mode.id] = VariableValue.alias(parent.id);
    }

    return DesignVariable(
      id: childId,
      name: parent.name,
      type: parent.type,
      collectionId: childCollectionId,
      valuesByMode: valuesByMode,
      scopes: parent.scopes,
      description: parent.description,
    );
  }

  /// Override a variable in child collection
  void overrideVariable({
    required String childCollectionId,
    required String variableId,
    required String modeId,
    required dynamic value,
  }) {
    final collection = _collections[childCollectionId];
    if (collection == null) return;

    final variable = _variables[variableId];
    if (variable == null) return;

    // Update the value to be a direct value instead of alias
    final newValuesByMode =
        Map<String, VariableValue<dynamic>>.from(variable.valuesByMode);
    newValuesByMode[modeId] = VariableValue(value: value);

    _variables[variableId] = DesignVariable(
      id: variable.id,
      name: variable.name,
      type: variable.type,
      collectionId: variable.collectionId,
      valuesByMode: newValuesByMode,
      scopes: variable.scopes,
      description: variable.description,
    );

    // Mark as overridden
    final newOverrides = Set<String>.from(collection.overriddenVariableIds)
      ..add(variableId);
    _collections[childCollectionId] =
        collection.copyWith(overriddenVariableIds: newOverrides);

    notifyListeners();
  }

  /// Reset override (revert to parent value)
  void resetOverride({
    required String childCollectionId,
    required String variableId,
    required String modeId,
  }) {
    final collection = _collections[childCollectionId];
    if (collection == null || collection.parentCollectionId == null) return;

    final variable = _variables[variableId];
    if (variable == null) return;

    // Find parent variable
    final parentVariables = _variables.values
        .where((v) => v.collectionId == collection.parentCollectionId)
        .where((v) => v.name == variable.name);
    final parentVariable = parentVariables.firstOrNull;
    if (parentVariable == null) return;

    // Reset to alias
    final newValuesByMode =
        Map<String, VariableValue<dynamic>>.from(variable.valuesByMode);
    newValuesByMode[modeId] = VariableValue.alias(parentVariable.id);

    _variables[variableId] = DesignVariable(
      id: variable.id,
      name: variable.name,
      type: variable.type,
      collectionId: variable.collectionId,
      valuesByMode: newValuesByMode,
      scopes: variable.scopes,
      description: variable.description,
    );

    // Check if any modes still have overrides
    final hasAnyOverrides = newValuesByMode.values.any((v) => !v.isAlias);
    if (!hasAnyOverrides) {
      final newOverrides = Set<String>.from(collection.overriddenVariableIds)
        ..remove(variableId);
      _collections[childCollectionId] =
          collection.copyWith(overriddenVariableIds: newOverrides);
    }

    notifyListeners();
  }

  /// Sync changes from parent to children
  Future<SyncResult> syncFromParent(String childCollectionId) async {
    final child = _collections[childCollectionId];
    if (child == null || child.parentCollectionId == null) {
      return SyncResult(
        success: false,
        message: 'No parent collection',
        addedVariables: [],
        removedVariables: [],
        updatedVariables: [],
      );
    }

    final parent = _collections[child.parentCollectionId];
    if (parent == null) {
      return SyncResult(
        success: false,
        message: 'Parent collection not found',
        addedVariables: [],
        removedVariables: [],
        updatedVariables: [],
      );
    }

    final addedVariables = <String>[];
    final removedVariables = <String>[];
    final updatedVariables = <String>[];

    final parentVariables =
        _variables.values.where((v) => v.collectionId == parent.id).toList();
    final childVariables =
        _variables.values.where((v) => v.collectionId == child.id).toList();

    // Find variables in parent not in child
    for (final pv in parentVariables) {
      final existsInChild = childVariables.any((cv) => cv.name == pv.name);
      if (!existsInChild) {
        // Add new inherited variable
        final newVar = _createInheritedVariable(pv, child.id, child.modes);
        _variables[newVar.id] = newVar;
        addedVariables.add(pv.name);
      }
    }

    // Find variables in child not in parent (should be removed unless local)
    for (final cv in childVariables) {
      final existsInParent = parentVariables.any((pv) => pv.name == cv.name);
      if (!existsInParent && !child.isOverridden(cv.id)) {
        // Remove inherited variable that no longer exists in parent
        _variables.remove(cv.id);
        removedVariables.add(cv.name);
      }
    }

    // Update sync time
    _collections[childCollectionId] =
        child.copyWith(lastSyncTime: DateTime.now());

    notifyListeners();

    return SyncResult(
      success: true,
      message: 'Synced ${addedVariables.length} added, '
          '${removedVariables.length} removed, '
          '${updatedVariables.length} updated',
      addedVariables: addedVariables,
      removedVariables: removedVariables,
      updatedVariables: updatedVariables,
    );
  }

  /// Get collection hierarchy (parent chain)
  List<ExtendedVariableCollection> getHierarchy(String collectionId) {
    final hierarchy = <ExtendedVariableCollection>[];
    String? currentId = collectionId;

    while (currentId != null) {
      final collection = _collections[currentId];
      if (collection == null) break;
      hierarchy.add(collection);
      currentId = collection.parentCollectionId;
    }

    return hierarchy.reversed.toList();
  }

  /// Get all child collections of a parent
  List<ExtendedVariableCollection> getChildren(String parentId) {
    return _collections.values
        .where((c) => c.parentCollectionId == parentId)
        .toList();
  }

  /// Get all brand collections
  List<ExtendedVariableCollection> getBrandCollections() {
    return _collections.values.where((c) => c.brandId != null).toList();
  }

  /// Get collections by brand
  List<ExtendedVariableCollection> getCollectionsByBrand(String brandId) {
    return _collections.values.where((c) => c.brandId == brandId).toList();
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final List<String> addedVariables;
  final List<String> removedVariables;
  final List<String> updatedVariables;

  const SyncResult({
    required this.success,
    required this.message,
    required this.addedVariables,
    required this.removedVariables,
    required this.updatedVariables,
  });
}

/// Brand configuration
class BrandConfig {
  final String id;
  final String name;
  final String? logoUrl;
  final String? primaryColorVariableId;
  final Map<String, String> metadata;

  const BrandConfig({
    required this.id,
    required this.name,
    this.logoUrl,
    this.primaryColorVariableId,
    this.metadata = const {},
  });

  BrandConfig copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? primaryColorVariableId,
    Map<String, String>? metadata,
  }) {
    return BrandConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColorVariableId:
          primaryColorVariableId ?? this.primaryColorVariableId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'primaryColorVariableId': primaryColorVariableId,
      'metadata': metadata,
    };
  }

  factory BrandConfig.fromMap(Map<String, dynamic> map) {
    return BrandConfig(
      id: map['id'] as String,
      name: map['name'] as String,
      logoUrl: map['logoUrl'] as String?,
      primaryColorVariableId: map['primaryColorVariableId'] as String?,
      metadata: (map['metadata'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
    );
  }
}

/// Multi-brand manager
class MultiBrandManager extends ChangeNotifier {
  final CollectionInheritanceManager _collectionManager;
  final Map<String, BrandConfig> _brands = {};
  String? _activeBrandId;

  MultiBrandManager(this._collectionManager);

  /// Get all brands
  Map<String, BrandConfig> get brands => Map.unmodifiable(_brands);

  /// Get active brand
  BrandConfig? get activeBrand =>
      _activeBrandId != null ? _brands[_activeBrandId] : null;

  /// Get active brand ID
  String? get activeBrandId => _activeBrandId;

  /// Add a brand
  void addBrand(BrandConfig brand) {
    _brands[brand.id] = brand;
    notifyListeners();
  }

  /// Remove a brand
  void removeBrand(String brandId) {
    _brands.remove(brandId);
    if (_activeBrandId == brandId) {
      _activeBrandId = _brands.keys.firstOrNull;
    }
    notifyListeners();
  }

  /// Set active brand
  void setActiveBrand(String brandId) {
    if (_brands.containsKey(brandId)) {
      _activeBrandId = brandId;
      notifyListeners();
    }
  }

  /// Create brand-specific collection from base
  ExtendedVariableCollection createBrandCollection({
    required String baseCollectionId,
    required String brandId,
    String? name,
  }) {
    final brand = _brands[brandId];
    if (brand == null) {
      throw ArgumentError('Brand not found: $brandId');
    }

    return _collectionManager.createChildCollection(
      parentId: baseCollectionId,
      name: name ?? '${brand.name} Variables',
      brandId: brandId,
      brandName: brand.name,
    );
  }

  /// Get collections for active brand
  List<ExtendedVariableCollection> getActiveBrandCollections() {
    if (_activeBrandId == null) return [];
    return _collectionManager.getCollectionsByBrand(_activeBrandId!);
  }
}
