/// Plugin manager for installation, lifecycle, and execution
///
/// Handles:
/// - Plugin installation from files/directories
/// - Plugin loading and unloading
/// - Plugin execution and sandbox management
/// - Plugin state persistence

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'plugin_manifest.dart';

/// Status of a plugin
enum PluginStatus {
  /// Plugin is installed but not loaded
  installed,

  /// Plugin is loaded and ready to run
  loaded,

  /// Plugin is currently running
  running,

  /// Plugin encountered an error
  error,

  /// Plugin is disabled by user
  disabled,
}

/// Installed plugin with runtime state
class InstalledPlugin {
  /// Unique installation ID
  final String installationId;

  /// Plugin manifest
  final PluginManifest manifest;

  /// Installation path on disk
  final String installPath;

  /// Current status
  PluginStatus status;

  /// Error message if status is error
  String? errorMessage;

  /// Installation timestamp
  final DateTime installedAt;

  /// Last run timestamp
  DateTime? lastRunAt;

  /// Whether plugin is enabled
  bool enabled;

  /// Relaunch data stored by plugin
  final Map<String, String> relaunchData;

  InstalledPlugin({
    required this.installationId,
    required this.manifest,
    required this.installPath,
    this.status = PluginStatus.installed,
    this.errorMessage,
    required this.installedAt,
    this.lastRunAt,
    this.enabled = true,
    Map<String, String>? relaunchData,
  }) : relaunchData = relaunchData ?? {};

  /// Create from JSON for persistence
  factory InstalledPlugin.fromJson(Map<String, dynamic> json) {
    return InstalledPlugin(
      installationId: json['installationId'] as String,
      manifest: PluginManifest.fromJson(json['manifest'] as Map<String, dynamic>),
      installPath: json['installPath'] as String,
      status: PluginStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PluginStatus.installed,
      ),
      errorMessage: json['errorMessage'] as String?,
      installedAt: DateTime.parse(json['installedAt'] as String),
      lastRunAt: json['lastRunAt'] != null
          ? DateTime.parse(json['lastRunAt'] as String)
          : null,
      enabled: json['enabled'] as bool? ?? true,
      relaunchData: (json['relaunchData'] as Map<String, dynamic>?)
              ?.cast<String, String>() ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'installationId': installationId,
        'manifest': manifest.toJson(),
        'installPath': installPath,
        'status': status.name,
        if (errorMessage != null) 'errorMessage': errorMessage,
        'installedAt': installedAt.toIso8601String(),
        if (lastRunAt != null) 'lastRunAt': lastRunAt!.toIso8601String(),
        'enabled': enabled,
        'relaunchData': relaunchData,
      };
}

/// Result of plugin execution
class PluginExecutionResult {
  final bool success;
  final dynamic result;
  final String? error;
  final Duration executionTime;

  const PluginExecutionResult({
    required this.success,
    this.result,
    this.error,
    required this.executionTime,
  });
}

/// Plugin manager singleton
class PluginManager extends ChangeNotifier {
  static PluginManager? _instance;

  /// Get the singleton instance
  static PluginManager get instance {
    _instance ??= PluginManager._();
    return _instance!;
  }

  PluginManager._();

  /// All installed plugins
  final Map<String, InstalledPlugin> _plugins = {};

  /// Currently running plugins
  final Set<String> _runningPlugins = {};

  /// Plugin installation directory
  String? _pluginsDirectory;

  /// Event stream for plugin events
  final _eventController = StreamController<PluginEvent>.broadcast();

  /// Stream of plugin events
  Stream<PluginEvent> get events => _eventController.stream;

  /// Get all installed plugins
  List<InstalledPlugin> get plugins => _plugins.values.toList();

  /// Get enabled plugins
  List<InstalledPlugin> get enabledPlugins =>
      _plugins.values.where((p) => p.enabled).toList();

  /// Get plugins by editor type
  List<InstalledPlugin> getPluginsForEditor(PluginEditorType editor) {
    return _plugins.values
        .where((p) => p.enabled && p.manifest.supportsEditor(editor))
        .toList();
  }

  /// Initialize the plugin manager
  Future<void> initialize(String pluginsDirectory) async {
    _pluginsDirectory = pluginsDirectory;

    // Create plugins directory if it doesn't exist
    final dir = Directory(pluginsDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Load installed plugins from disk
    await _loadInstalledPlugins();
  }

  /// Load previously installed plugins
  Future<void> _loadInstalledPlugins() async {
    if (_pluginsDirectory == null) return;

    final manifestFile = File('$_pluginsDirectory/installed.json');
    if (!await manifestFile.exists()) return;

    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final pluginsList = json['plugins'] as List? ?? [];

      for (final pluginJson in pluginsList) {
        try {
          final plugin =
              InstalledPlugin.fromJson(pluginJson as Map<String, dynamic>);
          _plugins[plugin.manifest.id] = plugin;
        } catch (e) {
          debugPrint('Failed to load plugin: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load installed plugins: $e');
    }
  }

  /// Save installed plugins to disk
  Future<void> _saveInstalledPlugins() async {
    if (_pluginsDirectory == null) return;

    final manifestFile = File('$_pluginsDirectory/installed.json');
    final json = {
      'plugins': _plugins.values.map((p) => p.toJson()).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    };

    await manifestFile.writeAsString(jsonEncode(json));
  }

  /// Install a plugin from a directory
  Future<InstalledPlugin> installFromDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw PluginInstallationException('Directory does not exist: $path');
    }

    // Read manifest
    final manifestFile = File('$path/manifest.json');
    if (!await manifestFile.exists()) {
      throw PluginInstallationException('manifest.json not found in $path');
    }

    final manifestContent = await manifestFile.readAsString();
    final manifest = PluginManifest.fromJsonString(manifestContent);

    // Validate manifest
    final validation = manifest.validate();
    if (!validation.isValid) {
      throw PluginInstallationException(
        'Invalid manifest: ${validation.errors.join(', ')}',
      );
    }

    // Check if main file exists
    final mainFile = File('$path/${manifest.main}');
    if (!await mainFile.exists()) {
      throw PluginInstallationException(
        'Main file not found: ${manifest.main}',
      );
    }

    // Check for duplicate installation
    if (_plugins.containsKey(manifest.id)) {
      // Update existing installation
      return await _updatePlugin(manifest, path);
    }

    // Copy to plugins directory
    final installPath = '$_pluginsDirectory/${manifest.id}';
    await _copyDirectory(dir, Directory(installPath));

    // Create installed plugin record
    final installed = InstalledPlugin(
      installationId: _generateInstallationId(),
      manifest: manifest,
      installPath: installPath,
      installedAt: DateTime.now(),
    );

    _plugins[manifest.id] = installed;
    await _saveInstalledPlugins();

    _eventController.add(PluginInstalledEvent(installed));
    notifyListeners();

    return installed;
  }

  /// Install a plugin from a zip file
  Future<InstalledPlugin> installFromZip(String zipPath) async {
    // For now, just throw - would need archive package
    throw UnimplementedError(
      'Zip installation requires additional dependencies',
    );
  }

  /// Update an existing plugin
  Future<InstalledPlugin> _updatePlugin(
      PluginManifest manifest, String sourcePath) async {
    final existing = _plugins[manifest.id]!;

    // Copy new files
    await _copyDirectory(
      Directory(sourcePath),
      Directory(existing.installPath),
    );

    // Update manifest
    final updated = InstalledPlugin(
      installationId: existing.installationId,
      manifest: manifest,
      installPath: existing.installPath,
      installedAt: existing.installedAt,
      lastRunAt: existing.lastRunAt,
      enabled: existing.enabled,
      relaunchData: existing.relaunchData,
    );

    _plugins[manifest.id] = updated;
    await _saveInstalledPlugins();

    _eventController.add(PluginUpdatedEvent(updated));
    notifyListeners();

    return updated;
  }

  /// Uninstall a plugin
  Future<void> uninstall(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;

    // Stop if running
    if (_runningPlugins.contains(pluginId)) {
      await stopPlugin(pluginId);
    }

    // Remove files
    final dir = Directory(plugin.installPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    _plugins.remove(pluginId);
    await _saveInstalledPlugins();

    _eventController.add(PluginUninstalledEvent(pluginId));
    notifyListeners();
  }

  /// Enable or disable a plugin
  Future<void> setEnabled(String pluginId, bool enabled) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;

    plugin.enabled = enabled;
    if (!enabled && _runningPlugins.contains(pluginId)) {
      await stopPlugin(pluginId);
    }

    await _saveInstalledPlugins();
    notifyListeners();
  }

  /// Run a plugin with optional command and parameters
  Future<PluginExecutionResult> runPlugin(
    String pluginId, {
    String? command,
    Map<String, dynamic>? parameters,
  }) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) {
      return PluginExecutionResult(
        success: false,
        error: 'Plugin not found: $pluginId',
        executionTime: Duration.zero,
      );
    }

    if (!plugin.enabled) {
      return PluginExecutionResult(
        success: false,
        error: 'Plugin is disabled',
        executionTime: Duration.zero,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      _runningPlugins.add(pluginId);
      plugin.status = PluginStatus.running;
      notifyListeners();

      _eventController.add(PluginStartedEvent(plugin, command));

      // Execute the plugin (would need JS runtime in real implementation)
      // For now, just simulate execution
      await Future.delayed(const Duration(milliseconds: 100));

      plugin.lastRunAt = DateTime.now();
      plugin.status = PluginStatus.loaded;
      await _saveInstalledPlugins();

      stopwatch.stop();

      _eventController.add(PluginCompletedEvent(plugin, null));
      notifyListeners();

      return PluginExecutionResult(
        success: true,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      plugin.status = PluginStatus.error;
      plugin.errorMessage = e.toString();

      _eventController.add(PluginErrorEvent(plugin, e.toString()));
      notifyListeners();

      return PluginExecutionResult(
        success: false,
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    } finally {
      _runningPlugins.remove(pluginId);
    }
  }

  /// Stop a running plugin
  Future<void> stopPlugin(String pluginId) async {
    if (!_runningPlugins.contains(pluginId)) return;

    final plugin = _plugins[pluginId];
    if (plugin == null) return;

    _runningPlugins.remove(pluginId);
    plugin.status = PluginStatus.loaded;

    _eventController.add(PluginStoppedEvent(plugin));
    notifyListeners();
  }

  /// Set relaunch data for a plugin on a node
  void setRelaunchData(String pluginId, String nodeId, String data) {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;

    plugin.relaunchData[nodeId] = data;
    _saveInstalledPlugins();
  }

  /// Get relaunch data for a plugin on a node
  String? getRelaunchData(String pluginId, String nodeId) {
    return _plugins[pluginId]?.relaunchData[nodeId];
  }

  /// Clear relaunch data
  void clearRelaunchData(String pluginId, String nodeId) {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;

    plugin.relaunchData.remove(nodeId);
    _saveInstalledPlugins();
  }

  /// Get plugin by ID
  InstalledPlugin? getPlugin(String pluginId) => _plugins[pluginId];

  /// Check if plugin is running
  bool isRunning(String pluginId) => _runningPlugins.contains(pluginId);

  /// Copy directory recursively
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final newPath =
          '${destination.path}/${entity.path.split('/').last}';

      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  /// Generate unique installation ID
  String _generateInstallationId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }

  /// Dispose of resources
  void dispose() {
    _eventController.close();
  }
}

/// Exception during plugin installation
class PluginInstallationException implements Exception {
  final String message;

  PluginInstallationException(this.message);

  @override
  String toString() => 'PluginInstallationException: $message';
}

/// Base class for plugin events
abstract class PluginEvent {
  final DateTime timestamp;

  PluginEvent() : timestamp = DateTime.now();
}

/// Plugin was installed
class PluginInstalledEvent extends PluginEvent {
  final InstalledPlugin plugin;

  PluginInstalledEvent(this.plugin);
}

/// Plugin was updated
class PluginUpdatedEvent extends PluginEvent {
  final InstalledPlugin plugin;

  PluginUpdatedEvent(this.plugin);
}

/// Plugin was uninstalled
class PluginUninstalledEvent extends PluginEvent {
  final String pluginId;

  PluginUninstalledEvent(this.pluginId);
}

/// Plugin started execution
class PluginStartedEvent extends PluginEvent {
  final InstalledPlugin plugin;
  final String? command;

  PluginStartedEvent(this.plugin, this.command);
}

/// Plugin completed execution
class PluginCompletedEvent extends PluginEvent {
  final InstalledPlugin plugin;
  final dynamic result;

  PluginCompletedEvent(this.plugin, this.result);
}

/// Plugin stopped
class PluginStoppedEvent extends PluginEvent {
  final InstalledPlugin plugin;

  PluginStoppedEvent(this.plugin);
}

/// Plugin encountered an error
class PluginErrorEvent extends PluginEvent {
  final InstalledPlugin plugin;
  final String error;

  PluginErrorEvent(this.plugin, this.error);
}
