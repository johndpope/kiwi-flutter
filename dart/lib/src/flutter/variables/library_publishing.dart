/// Library Publishing for Variables
///
/// Supports:
/// - Publishing variable collections as libraries
/// - Subscribing/unsubscribing to libraries
/// - Versioning and change tracking
/// - Conflict resolution
/// - Sync management

import 'package:flutter/foundation.dart';
import '../assets/variables.dart';
import 'extended_collections.dart';

/// Library publication status
enum PublicationStatus {
  draft('Draft'),
  published('Published'),
  deprecated('Deprecated'),
  archived('Archived');

  final String label;
  const PublicationStatus(this.label);
}

/// Library version
class LibraryVersion {
  final String version;
  final DateTime publishedAt;
  final String? releaseNotes;
  final String publishedBy;
  final int variableCount;
  final int modeCount;

  const LibraryVersion({
    required this.version,
    required this.publishedAt,
    this.releaseNotes,
    required this.publishedBy,
    required this.variableCount,
    required this.modeCount,
  });

  LibraryVersion copyWith({
    String? version,
    DateTime? publishedAt,
    String? releaseNotes,
    String? publishedBy,
    int? variableCount,
    int? modeCount,
  }) {
    return LibraryVersion(
      version: version ?? this.version,
      publishedAt: publishedAt ?? this.publishedAt,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      publishedBy: publishedBy ?? this.publishedBy,
      variableCount: variableCount ?? this.variableCount,
      modeCount: modeCount ?? this.modeCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'publishedAt': publishedAt.toIso8601String(),
      'releaseNotes': releaseNotes,
      'publishedBy': publishedBy,
      'variableCount': variableCount,
      'modeCount': modeCount,
    };
  }

  factory LibraryVersion.fromMap(Map<String, dynamic> map) {
    return LibraryVersion(
      version: map['version'] as String,
      publishedAt: DateTime.parse(map['publishedAt'] as String),
      releaseNotes: map['releaseNotes'] as String?,
      publishedBy: map['publishedBy'] as String,
      variableCount: map['variableCount'] as int,
      modeCount: map['modeCount'] as int,
    );
  }
}

/// Published variable library
class VariableLibrary {
  /// Library ID
  final String id;

  /// Library name
  final String name;

  /// Description
  final String? description;

  /// Source collection ID
  final String sourceCollectionId;

  /// Publication status
  final PublicationStatus status;

  /// Version history
  final List<LibraryVersion> versions;

  /// Current version
  final String currentVersion;

  /// Subscriber IDs (collections subscribed to this library)
  final List<String> subscriberIds;

  /// Owner/team
  final String ownerId;

  /// Tags for categorization
  final List<String> tags;

  /// Thumbnail/icon URL
  final String? thumbnailUrl;

  /// Created timestamp
  final DateTime createdAt;

  /// Last updated timestamp
  final DateTime updatedAt;

  const VariableLibrary({
    required this.id,
    required this.name,
    this.description,
    required this.sourceCollectionId,
    this.status = PublicationStatus.draft,
    this.versions = const [],
    required this.currentVersion,
    this.subscriberIds = const [],
    required this.ownerId,
    this.tags = const [],
    this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get current version info
  LibraryVersion? get currentVersionInfo {
    return versions.where((v) => v.version == currentVersion).firstOrNull;
  }

  /// Check if has subscribers
  bool get hasSubscribers => subscriberIds.isNotEmpty;

  VariableLibrary copyWith({
    String? id,
    String? name,
    String? description,
    String? sourceCollectionId,
    PublicationStatus? status,
    List<LibraryVersion>? versions,
    String? currentVersion,
    List<String>? subscriberIds,
    String? ownerId,
    List<String>? tags,
    String? thumbnailUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VariableLibrary(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceCollectionId: sourceCollectionId ?? this.sourceCollectionId,
      status: status ?? this.status,
      versions: versions ?? this.versions,
      currentVersion: currentVersion ?? this.currentVersion,
      subscriberIds: subscriberIds ?? this.subscriberIds,
      ownerId: ownerId ?? this.ownerId,
      tags: tags ?? this.tags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sourceCollectionId': sourceCollectionId,
      'status': status.name,
      'versions': versions.map((v) => v.toMap()).toList(),
      'currentVersion': currentVersion,
      'subscriberIds': subscriberIds,
      'ownerId': ownerId,
      'tags': tags,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VariableLibrary.fromMap(Map<String, dynamic> map) {
    return VariableLibrary(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      sourceCollectionId: map['sourceCollectionId'] as String,
      status: PublicationStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PublicationStatus.draft,
      ),
      versions: (map['versions'] as List<dynamic>?)
              ?.map((v) => LibraryVersion.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      currentVersion: map['currentVersion'] as String,
      subscriberIds: (map['subscriberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      ownerId: map['ownerId'] as String,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      thumbnailUrl: map['thumbnailUrl'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

/// Library subscription
class LibrarySubscription {
  /// Subscription ID
  final String id;

  /// Library ID
  final String libraryId;

  /// Subscribed collection ID (local collection)
  final String collectionId;

  /// Subscribed version
  final String subscribedVersion;

  /// Last synced timestamp
  final DateTime? lastSyncedAt;

  /// Auto-update setting
  final bool autoUpdate;

  /// Subscription status
  final SubscriptionStatus status;

  const LibrarySubscription({
    required this.id,
    required this.libraryId,
    required this.collectionId,
    required this.subscribedVersion,
    this.lastSyncedAt,
    this.autoUpdate = true,
    this.status = SubscriptionStatus.active,
  });

  LibrarySubscription copyWith({
    String? id,
    String? libraryId,
    String? collectionId,
    String? subscribedVersion,
    DateTime? lastSyncedAt,
    bool? autoUpdate,
    SubscriptionStatus? status,
  }) {
    return LibrarySubscription(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      collectionId: collectionId ?? this.collectionId,
      subscribedVersion: subscribedVersion ?? this.subscribedVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'libraryId': libraryId,
      'collectionId': collectionId,
      'subscribedVersion': subscribedVersion,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'autoUpdate': autoUpdate,
      'status': status.name,
    };
  }

  factory LibrarySubscription.fromMap(Map<String, dynamic> map) {
    return LibrarySubscription(
      id: map['id'] as String,
      libraryId: map['libraryId'] as String,
      collectionId: map['collectionId'] as String,
      subscribedVersion: map['subscribedVersion'] as String,
      lastSyncedAt: map['lastSyncedAt'] != null
          ? DateTime.parse(map['lastSyncedAt'] as String)
          : null,
      autoUpdate: map['autoUpdate'] as bool? ?? true,
      status: SubscriptionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SubscriptionStatus.active,
      ),
    );
  }
}

/// Subscription status
enum SubscriptionStatus {
  active,
  paused,
  updateAvailable,
  error,
}

/// Library publishing manager
class LibraryPublishingManager extends ChangeNotifier {
  final Map<String, VariableLibrary> _libraries = {};
  final Map<String, LibrarySubscription> _subscriptions = {};
  final CollectionInheritanceManager _collectionManager;

  LibraryPublishingManager(this._collectionManager);

  /// Get all libraries
  Map<String, VariableLibrary> get libraries => Map.unmodifiable(_libraries);

  /// Get all subscriptions
  Map<String, LibrarySubscription> get subscriptions =>
      Map.unmodifiable(_subscriptions);

  /// Publish a collection as a library
  VariableLibrary publishCollection({
    required String collectionId,
    required String name,
    String? description,
    required String ownerId,
    List<String> tags = const [],
    String? releaseNotes,
  }) {
    final collection = _collectionManager.collections[collectionId];
    if (collection == null) {
      throw ArgumentError('Collection not found: $collectionId');
    }

    final variables = _collectionManager.variables.values
        .where((v) => v.collectionId == collectionId)
        .toList();

    final libraryId = 'lib_${DateTime.now().millisecondsSinceEpoch}';
    final version = '1.0.0';
    final now = DateTime.now();

    final library = VariableLibrary(
      id: libraryId,
      name: name,
      description: description,
      sourceCollectionId: collectionId,
      status: PublicationStatus.published,
      versions: [
        LibraryVersion(
          version: version,
          publishedAt: now,
          releaseNotes: releaseNotes,
          publishedBy: ownerId,
          variableCount: variables.length,
          modeCount: collection.modes.length,
        ),
      ],
      currentVersion: version,
      ownerId: ownerId,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    _libraries[libraryId] = library;

    // Mark collection as library
    _collectionManager.addCollection(
      collection.copyWith(
        isLibrary: true,
        libraryId: libraryId,
      ),
    );

    notifyListeners();
    return library;
  }

  /// Publish a new version
  void publishNewVersion({
    required String libraryId,
    required String newVersion,
    required String publishedBy,
    String? releaseNotes,
  }) {
    final library = _libraries[libraryId];
    if (library == null) {
      throw ArgumentError('Library not found: $libraryId');
    }

    final collection = _collectionManager.collections[library.sourceCollectionId];
    if (collection == null) return;

    final variables = _collectionManager.variables.values
        .where((v) => v.collectionId == library.sourceCollectionId)
        .toList();

    final newVersionInfo = LibraryVersion(
      version: newVersion,
      publishedAt: DateTime.now(),
      releaseNotes: releaseNotes,
      publishedBy: publishedBy,
      variableCount: variables.length,
      modeCount: collection.modes.length,
    );

    _libraries[libraryId] = library.copyWith(
      versions: [...library.versions, newVersionInfo],
      currentVersion: newVersion,
      updatedAt: DateTime.now(),
    );

    // Mark subscribers as having updates available
    for (final subId in library.subscriberIds) {
      final subscription = _subscriptions[subId];
      if (subscription != null &&
          subscription.subscribedVersion != newVersion) {
        _subscriptions[subId] = subscription.copyWith(
          status: SubscriptionStatus.updateAvailable,
        );
      }
    }

    notifyListeners();
  }

  /// Subscribe to a library
  LibrarySubscription subscribe({
    required String libraryId,
    required String targetCollectionId,
    bool autoUpdate = true,
  }) {
    final library = _libraries[libraryId];
    if (library == null) {
      throw ArgumentError('Library not found: $libraryId');
    }

    final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}';

    final subscription = LibrarySubscription(
      id: subscriptionId,
      libraryId: libraryId,
      collectionId: targetCollectionId,
      subscribedVersion: library.currentVersion,
      lastSyncedAt: DateTime.now(),
      autoUpdate: autoUpdate,
    );

    _subscriptions[subscriptionId] = subscription;

    // Update library subscriber list
    _libraries[libraryId] = library.copyWith(
      subscriberIds: [...library.subscriberIds, subscriptionId],
    );

    // Sync variables to subscribed collection
    _syncVariables(subscriptionId);

    notifyListeners();
    return subscription;
  }

  /// Unsubscribe from a library
  void unsubscribe(String subscriptionId) {
    final subscription = _subscriptions[subscriptionId];
    if (subscription == null) return;

    final library = _libraries[subscription.libraryId];
    if (library != null) {
      _libraries[subscription.libraryId] = library.copyWith(
        subscriberIds: library.subscriberIds
            .where((id) => id != subscriptionId)
            .toList(),
      );
    }

    _subscriptions.remove(subscriptionId);
    notifyListeners();
  }

  /// Update subscription to latest version
  Future<void> updateSubscription(String subscriptionId) async {
    final subscription = _subscriptions[subscriptionId];
    if (subscription == null) return;

    final library = _libraries[subscription.libraryId];
    if (library == null) return;

    // Sync to latest version
    _subscriptions[subscriptionId] = subscription.copyWith(
      subscribedVersion: library.currentVersion,
      lastSyncedAt: DateTime.now(),
      status: SubscriptionStatus.active,
    );

    await _syncVariables(subscriptionId);
    notifyListeners();
  }

  /// Sync variables from library to subscribed collection
  Future<void> _syncVariables(String subscriptionId) async {
    final subscription = _subscriptions[subscriptionId];
    if (subscription == null) return;

    final library = _libraries[subscription.libraryId];
    if (library == null) return;

    // Get source variables
    final sourceVariables = _collectionManager.variables.values
        .where((v) => v.collectionId == library.sourceCollectionId)
        .toList();

    // Get target collection
    final targetCollection =
        _collectionManager.collections[subscription.collectionId];
    if (targetCollection == null) return;

    // Create/update variables in target collection as aliases
    for (final sourceVar in sourceVariables) {
      final existingVar = _collectionManager.variables.values
          .where((v) => v.collectionId == subscription.collectionId)
          .where((v) => v.name == sourceVar.name)
          .firstOrNull;

      if (existingVar == null) {
        // Create new alias variable
        final valuesByMode = <String, VariableValue<dynamic>>{};
        for (final mode in targetCollection.modes) {
          valuesByMode[mode.id] = VariableValue.alias(sourceVar.id);
        }

        final newVar = DesignVariable(
          id: 'var_${DateTime.now().millisecondsSinceEpoch}_${sourceVar.id}',
          name: sourceVar.name,
          type: sourceVar.type,
          collectionId: subscription.collectionId,
          valuesByMode: valuesByMode,
          scopes: sourceVar.scopes,
          description: sourceVar.description,
          remote: true,
        );

        _collectionManager.addVariable(newVar);
      }
    }
  }

  /// Get libraries by tag
  List<VariableLibrary> getLibrariesByTag(String tag) {
    return _libraries.values.where((l) => l.tags.contains(tag)).toList();
  }

  /// Get subscriptions for a collection
  List<LibrarySubscription> getSubscriptionsForCollection(String collectionId) {
    return _subscriptions.values
        .where((s) => s.collectionId == collectionId)
        .toList();
  }

  /// Check for available updates
  List<LibrarySubscription> getSubscriptionsWithUpdates() {
    return _subscriptions.values
        .where((s) => s.status == SubscriptionStatus.updateAvailable)
        .toList();
  }

  /// Deprecate a library
  void deprecateLibrary(String libraryId) {
    final library = _libraries[libraryId];
    if (library == null) return;

    _libraries[libraryId] = library.copyWith(
      status: PublicationStatus.deprecated,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  /// Archive a library
  void archiveLibrary(String libraryId) {
    final library = _libraries[libraryId];
    if (library == null) return;

    _libraries[libraryId] = library.copyWith(
      status: PublicationStatus.archived,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }
}

/// Change tracking for library updates
class LibraryChangeLog {
  final String libraryId;
  final String fromVersion;
  final String toVersion;
  final List<VariableChange> changes;
  final DateTime timestamp;

  const LibraryChangeLog({
    required this.libraryId,
    required this.fromVersion,
    required this.toVersion,
    required this.changes,
    required this.timestamp,
  });
}

/// Single variable change
class VariableChange {
  final String variableId;
  final String variableName;
  final ChangeType type;
  final dynamic oldValue;
  final dynamic newValue;

  const VariableChange({
    required this.variableId,
    required this.variableName,
    required this.type,
    this.oldValue,
    this.newValue,
  });
}

/// Change type
enum ChangeType {
  added,
  removed,
  modified,
  renamed,
}

/// Conflict resolution
class ConflictResolver {
  /// Resolve conflicts when updating subscriptions
  List<Conflict> detectConflicts(
    List<DesignVariable> localVariables,
    List<DesignVariable> remoteVariables,
  ) {
    final conflicts = <Conflict>[];

    for (final local in localVariables) {
      final remote =
          remoteVariables.where((r) => r.name == local.name).firstOrNull;

      if (remote != null) {
        // Check for type mismatch
        if (local.type != remote.type) {
          conflicts.add(Conflict(
            type: ConflictType.typeMismatch,
            localVariable: local,
            remoteVariable: remote,
            message: 'Type changed from ${local.type} to ${remote.type}',
          ));
        }

        // Check for value conflicts
        // (Would need to compare all mode values)
      }
    }

    return conflicts;
  }

  /// Apply resolution strategy
  void resolveConflict(Conflict conflict, ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        // Keep local value
        break;
      case ConflictResolution.useRemote:
        // Use remote value
        break;
      case ConflictResolution.merge:
        // Merge values (complex logic)
        break;
      case ConflictResolution.skip:
        // Skip this variable
        break;
    }
  }
}

/// Conflict between local and remote variables
class Conflict {
  final ConflictType type;
  final DesignVariable localVariable;
  final DesignVariable remoteVariable;
  final String message;

  const Conflict({
    required this.type,
    required this.localVariable,
    required this.remoteVariable,
    required this.message,
  });
}

/// Conflict type
enum ConflictType {
  typeMismatch,
  valueConflict,
  scopeConflict,
  deleted,
}

/// Conflict resolution strategy
enum ConflictResolution {
  keepLocal,
  useRemote,
  merge,
  skip,
}
