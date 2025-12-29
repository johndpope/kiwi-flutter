/// Plugin manifest parser and validator
///
/// Parses Figma-compatible manifest.json files for plugins.
/// Supports all manifest fields including:
/// - Required: name, id, api, main, editorType
/// - Optional: ui, documentAccess, networkAccess, parameters, menu, etc.

import 'dart:convert';

/// Editor types supported by plugins
enum PluginEditorType {
  figma,
  figjam,
  dev,
}

/// Document access levels
enum DocumentAccess {
  /// Plugin can only access the current page
  dynamicPage,
}

/// Parameter types for plugin inputs
enum ParameterType {
  string,
  boolean,
  number,
}

/// Network access configuration
class NetworkAccess {
  /// List of allowed domains (supports wildcards)
  final List<String> allowedDomains;

  /// Reasoning for network access (required for broad access)
  final String? reasoning;

  /// Development-only allowed domains
  final List<String>? devAllowedDomains;

  const NetworkAccess({
    required this.allowedDomains,
    this.reasoning,
    this.devAllowedDomains,
  });

  factory NetworkAccess.fromJson(Map<String, dynamic> json) {
    return NetworkAccess(
      allowedDomains: (json['allowedDomains'] as List?)?.cast<String>() ?? [],
      reasoning: json['reasoning'] as String?,
      devAllowedDomains: (json['devAllowedDomains'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'allowedDomains': allowedDomains,
        if (reasoning != null) 'reasoning': reasoning,
        if (devAllowedDomains != null) 'devAllowedDomains': devAllowedDomains,
      };

  /// Check if a URL is allowed by this network access configuration
  ///
  /// Returns a [NetworkAccessResult] with details about whether access is allowed.
  NetworkAccessResult checkUrl(String url) {
    final uri = Uri.tryParse(url);

    // Invalid URL
    if (uri == null) {
      return NetworkAccessResult(
        allowed: false,
        reason: NetworkDenyReason.invalidUrl,
        message: 'Invalid URL format',
      );
    }

    // Empty host
    if (uri.host.isEmpty) {
      return NetworkAccessResult(
        allowed: false,
        reason: NetworkDenyReason.invalidUrl,
        message: 'URL must have a host',
      );
    }

    // Only allow http and https
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return NetworkAccessResult(
        allowed: false,
        reason: NetworkDenyReason.invalidProtocol,
        message: 'Only http and https protocols are allowed',
      );
    }

    // Block localhost and private IPs unless explicitly allowed
    if (_isPrivateNetwork(uri.host) && !_hasExplicitPrivateAccess()) {
      return NetworkAccessResult(
        allowed: false,
        reason: NetworkDenyReason.privateNetwork,
        message: 'Access to private network addresses is not allowed',
      );
    }

    // Check against allowed domains
    for (final pattern in allowedDomains) {
      if (pattern == '*') {
        return NetworkAccessResult(allowed: true);
      }
      if (_matchesDomain(uri.host, pattern)) {
        return NetworkAccessResult(allowed: true, matchedPattern: pattern);
      }
    }

    return NetworkAccessResult(
      allowed: false,
      reason: NetworkDenyReason.domainNotAllowed,
      message: 'Domain "${uri.host}" is not in the allowed list',
    );
  }

  /// Simple check if URL is allowed (convenience method)
  bool isUrlAllowed(String url) {
    return checkUrl(url).allowed;
  }

  /// Check if host is a private network address
  bool _isPrivateNetwork(String host) {
    // Localhost variations
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }

    // Private IPv4 ranges
    final ipv4Pattern = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    final match = ipv4Pattern.firstMatch(host);
    if (match != null) {
      final a = int.parse(match.group(1)!);
      final b = int.parse(match.group(2)!);

      // 10.0.0.0/8
      if (a == 10) return true;
      // 172.16.0.0/12
      if (a == 172 && b >= 16 && b <= 31) return true;
      // 192.168.0.0/16
      if (a == 192 && b == 168) return true;
      // 169.254.0.0/16 (link-local)
      if (a == 169 && b == 254) return true;
    }

    return false;
  }

  /// Check if private access is explicitly allowed
  bool _hasExplicitPrivateAccess() {
    for (final pattern in allowedDomains) {
      if (pattern == '*') return true;
      if (pattern == 'localhost' || pattern.startsWith('127.')) return true;
      if (pattern.startsWith('10.') || pattern.startsWith('192.168.')) return true;
    }
    return false;
  }

  bool _matchesDomain(String host, String pattern) {
    // Wildcard subdomain matching (e.g., *.example.com)
    if (pattern.startsWith('*.')) {
      final suffix = pattern.substring(2);
      // Match exact suffix or subdomain
      return host == suffix || host.endsWith('.$suffix');
    }

    // Exact match
    return host.toLowerCase() == pattern.toLowerCase();
  }
}

/// Result of a network access check
class NetworkAccessResult {
  final bool allowed;
  final NetworkDenyReason? reason;
  final String? message;
  final String? matchedPattern;

  const NetworkAccessResult({
    required this.allowed,
    this.reason,
    this.message,
    this.matchedPattern,
  });
}

/// Reasons why network access might be denied
enum NetworkDenyReason {
  /// URL format is invalid
  invalidUrl,
  /// Protocol is not http or https
  invalidProtocol,
  /// Attempting to access private network (localhost, 192.168.x.x, etc.)
  privateNetwork,
  /// Domain is not in the allowed list
  domainNotAllowed,
}

/// Plugin parameter definition
class PluginParameter {
  /// Display name
  final String name;

  /// Unique key for this parameter
  final String key;

  /// Description shown to user
  final String? description;

  /// Type of the parameter
  final ParameterType type;

  /// Whether freeform input is allowed
  final bool allowFreeform;

  /// Whether this parameter is optional
  final bool optional;

  /// Predefined options for selection
  final List<PluginParameterOption>? options;

  const PluginParameter({
    required this.name,
    required this.key,
    this.description,
    this.type = ParameterType.string,
    this.allowFreeform = true,
    this.optional = false,
    this.options,
  });

  factory PluginParameter.fromJson(Map<String, dynamic> json) {
    return PluginParameter(
      name: json['name'] as String,
      key: json['key'] as String,
      description: json['description'] as String?,
      type: _parseParameterType(json['type'] as String?),
      allowFreeform: json['allowFreeform'] as bool? ?? true,
      optional: json['optional'] as bool? ?? false,
      options: (json['options'] as List?)
          ?.map((o) => PluginParameterOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  static ParameterType _parseParameterType(String? type) {
    switch (type) {
      case 'boolean':
        return ParameterType.boolean;
      case 'number':
        return ParameterType.number;
      default:
        return ParameterType.string;
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'key': key,
        if (description != null) 'description': description,
        'type': type.name,
        'allowFreeform': allowFreeform,
        'optional': optional,
        if (options != null) 'options': options!.map((o) => o.toJson()).toList(),
      };
}

/// Option for a plugin parameter
class PluginParameterOption {
  final String name;
  final String? description;

  const PluginParameterOption({
    required this.name,
    this.description,
  });

  factory PluginParameterOption.fromJson(Map<String, dynamic> json) {
    return PluginParameterOption(
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
      };
}

/// Menu item in plugin manifest
class PluginMenuItem {
  /// Display name
  final String name;

  /// Command to execute
  final String? command;

  /// Submenu items (if this is a parent menu)
  final List<PluginMenuItem>? menu;

  /// Parameters for this command
  final List<PluginParameter>? parameters;

  /// Whether this is a separator
  final bool separator;

  const PluginMenuItem({
    required this.name,
    this.command,
    this.menu,
    this.parameters,
    this.separator = false,
  });

  factory PluginMenuItem.separator() {
    return const PluginMenuItem(name: '-', separator: true);
  }

  factory PluginMenuItem.fromJson(Map<String, dynamic> json) {
    if (json['separator'] == true || json['name'] == '-') {
      return PluginMenuItem.separator();
    }
    return PluginMenuItem(
      name: json['name'] as String,
      command: json['command'] as String?,
      menu: (json['menu'] as List?)
          ?.map((m) => PluginMenuItem.fromJson(m as Map<String, dynamic>))
          .toList(),
      parameters: (json['parameters'] as List?)
          ?.map((p) => PluginParameter.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (command != null) 'command': command,
        if (menu != null) 'menu': menu!.map((m) => m.toJson()).toList(),
        if (parameters != null)
          'parameters': parameters!.map((p) => p.toJson()).toList(),
        if (separator) 'separator': true,
      };
}

/// Relaunch button configuration
class RelaunchButton {
  /// Command to execute on click
  final String command;

  /// Display name
  final String name;

  /// Whether to support multiple selection
  final bool multipleSelection;

  const RelaunchButton({
    required this.command,
    required this.name,
    this.multipleSelection = false,
  });

  factory RelaunchButton.fromJson(Map<String, dynamic> json) {
    return RelaunchButton(
      command: json['command'] as String,
      name: json['name'] as String,
      multipleSelection: json['multipleSelection'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'command': command,
        'name': name,
        'multipleSelection': multipleSelection,
      };
}

/// Plugin capabilities
class PluginCapabilities {
  /// Whether plugin supports codegen
  final bool codegen;

  /// Whether plugin supports inspect mode
  final bool inspect;

  /// Whether plugin supports vscode extension
  final bool vscodeExtension;

  const PluginCapabilities({
    this.codegen = false,
    this.inspect = false,
    this.vscodeExtension = false,
  });

  factory PluginCapabilities.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'] as List? ?? [];
    return PluginCapabilities(
      codegen: caps.contains('codegen'),
      inspect: caps.contains('inspect'),
      vscodeExtension: caps.contains('vscode_extension'),
    );
  }

  List<String> toJson() {
    final caps = <String>[];
    if (codegen) caps.add('codegen');
    if (inspect) caps.add('inspect');
    if (vscodeExtension) caps.add('vscode_extension');
    return caps;
  }
}

/// Build configuration for plugin
class PluginBuild {
  /// Build command to run
  final String? command;

  /// Watch command for development
  final String? watchCommand;

  const PluginBuild({
    this.command,
    this.watchCommand,
  });

  factory PluginBuild.fromJson(Map<String, dynamic> json) {
    return PluginBuild(
      command: json['command'] as String?,
      watchCommand: json['watchCommand'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (command != null) 'command': command,
        if (watchCommand != null) 'watchCommand': watchCommand,
      };
}

/// Codegen preferences
class CodegenPreferences {
  /// Preferred unit (e.g., 'px', 'rem')
  final String? unit;

  /// Scale factor
  final double? scaleFactor;

  const CodegenPreferences({
    this.unit,
    this.scaleFactor,
  });

  factory CodegenPreferences.fromJson(Map<String, dynamic> json) {
    return CodegenPreferences(
      unit: json['unit'] as String?,
      scaleFactor: (json['scaleFactor'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (unit != null) 'unit': unit,
        if (scaleFactor != null) 'scaleFactor': scaleFactor,
      };
}

/// Complete plugin manifest
class PluginManifest {
  /// Plugin display name
  final String name;

  /// Unique plugin identifier
  final String id;

  /// API version (e.g., "1.0.0")
  final String api;

  /// Main entry point file
  final String main;

  /// Supported editor types
  final List<PluginEditorType> editorType;

  /// UI entry point file (optional)
  final String? ui;

  /// Document access level
  final DocumentAccess? documentAccess;

  /// Network access configuration
  final NetworkAccess? networkAccess;

  /// Plugin parameters
  final List<PluginParameter>? parameters;

  /// Whether this plugin is parameter-only (no UI)
  final bool parameterOnly;

  /// Menu structure
  final List<PluginMenuItem>? menu;

  /// Relaunch buttons
  final List<RelaunchButton>? relaunchButtons;

  /// Enable proposed/experimental APIs
  final bool enableProposedApi;

  /// Enable private plugin APIs
  final bool enablePrivatePluginApi;

  /// Build configuration
  final PluginBuild? build;

  /// Required permissions
  final List<String>? permissions;

  /// Plugin capabilities
  final PluginCapabilities? capabilities;

  /// Supported codegen languages
  final List<String>? codegenLanguages;

  /// Codegen preferences
  final CodegenPreferences? codegenPreferences;

  /// Plugin version
  final String? version;

  /// Plugin description
  final String? description;

  const PluginManifest({
    required this.name,
    required this.id,
    required this.api,
    required this.main,
    required this.editorType,
    this.ui,
    this.documentAccess,
    this.networkAccess,
    this.parameters,
    this.parameterOnly = false,
    this.menu,
    this.relaunchButtons,
    this.enableProposedApi = false,
    this.enablePrivatePluginApi = false,
    this.build,
    this.permissions,
    this.capabilities,
    this.codegenLanguages,
    this.codegenPreferences,
    this.version,
    this.description,
  });

  /// Parse manifest from JSON string
  factory PluginManifest.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return PluginManifest.fromJson(json);
  }

  /// Parse manifest from JSON map
  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    // Parse editor types
    final editorTypeRaw = json['editorType'];
    List<PluginEditorType> editorTypes;
    if (editorTypeRaw is List) {
      editorTypes = editorTypeRaw.map((e) => _parseEditorType(e as String)).toList();
    } else if (editorTypeRaw is String) {
      editorTypes = [_parseEditorType(editorTypeRaw)];
    } else {
      editorTypes = [PluginEditorType.figma];
    }

    return PluginManifest(
      name: json['name'] as String,
      id: json['id'] as String,
      api: json['api'] as String,
      main: json['main'] as String,
      editorType: editorTypes,
      ui: json['ui'] as String?,
      documentAccess: json['documentAccess'] == 'dynamic-page'
          ? DocumentAccess.dynamicPage
          : null,
      networkAccess: json['networkAccess'] != null
          ? NetworkAccess.fromJson(json['networkAccess'] as Map<String, dynamic>)
          : null,
      parameters: (json['parameters'] as List?)
          ?.map((p) => PluginParameter.fromJson(p as Map<String, dynamic>))
          .toList(),
      parameterOnly: json['parameterOnly'] as bool? ?? false,
      menu: (json['menu'] as List?)
          ?.map((m) => PluginMenuItem.fromJson(m as Map<String, dynamic>))
          .toList(),
      relaunchButtons: (json['relaunchButtons'] as List?)
          ?.map((r) => RelaunchButton.fromJson(r as Map<String, dynamic>))
          .toList(),
      enableProposedApi: json['enableProposedApi'] as bool? ?? false,
      enablePrivatePluginApi: json['enablePrivatePluginApi'] as bool? ?? false,
      build: json['build'] != null
          ? PluginBuild.fromJson(json['build'] as Map<String, dynamic>)
          : null,
      permissions: (json['permissions'] as List?)?.cast<String>(),
      capabilities: json['capabilities'] != null
          ? PluginCapabilities.fromJson(json)
          : null,
      codegenLanguages: (json['codegenLanguages'] as List?)?.cast<String>(),
      codegenPreferences: json['codegenPreferences'] != null
          ? CodegenPreferences.fromJson(
              json['codegenPreferences'] as Map<String, dynamic>)
          : null,
      version: json['version'] as String?,
      description: json['description'] as String?,
    );
  }

  static PluginEditorType _parseEditorType(String type) {
    switch (type.toLowerCase()) {
      case 'figjam':
        return PluginEditorType.figjam;
      case 'dev':
        return PluginEditorType.dev;
      default:
        return PluginEditorType.figma;
    }
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
        'name': name,
        'id': id,
        'api': api,
        'main': main,
        'editorType': editorType.length == 1
            ? editorType.first.name
            : editorType.map((e) => e.name).toList(),
        if (ui != null) 'ui': ui,
        if (documentAccess != null) 'documentAccess': 'dynamic-page',
        if (networkAccess != null) 'networkAccess': networkAccess!.toJson(),
        if (parameters != null)
          'parameters': parameters!.map((p) => p.toJson()).toList(),
        if (parameterOnly) 'parameterOnly': parameterOnly,
        if (menu != null) 'menu': menu!.map((m) => m.toJson()).toList(),
        if (relaunchButtons != null)
          'relaunchButtons': relaunchButtons!.map((r) => r.toJson()).toList(),
        if (enableProposedApi) 'enableProposedApi': enableProposedApi,
        if (enablePrivatePluginApi)
          'enablePrivatePluginApi': enablePrivatePluginApi,
        if (build != null) 'build': build!.toJson(),
        if (permissions != null) 'permissions': permissions,
        if (capabilities != null) 'capabilities': capabilities!.toJson(),
        if (codegenLanguages != null) 'codegenLanguages': codegenLanguages,
        if (codegenPreferences != null)
          'codegenPreferences': codegenPreferences!.toJson(),
        if (version != null) 'version': version,
        if (description != null) 'description': description,
      };

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Validate the manifest
  ManifestValidationResult validate() {
    final errors = <String>[];
    final warnings = <String>[];

    // Required fields
    if (name.isEmpty) errors.add('name is required');
    if (id.isEmpty) errors.add('id is required');
    if (api.isEmpty) errors.add('api version is required');
    if (main.isEmpty) errors.add('main entry point is required');
    if (editorType.isEmpty) errors.add('editorType is required');

    // API version check
    final apiVersion = _parseVersion(api);
    if (apiVersion == null) {
      errors.add('Invalid api version format: $api');
    } else if (apiVersion < Version(1, 0, 0)) {
      errors.add('api version must be at least 1.0.0');
    }

    // Network access validation
    if (networkAccess != null) {
      if (networkAccess!.allowedDomains.contains('*')) {
        if (networkAccess!.reasoning == null ||
            networkAccess!.reasoning!.isEmpty) {
          warnings.add('Broad network access (*) should include reasoning');
        }
      }
    }

    // Codegen validation
    if (capabilities?.codegen == true) {
      if (codegenLanguages == null || codegenLanguages!.isEmpty) {
        warnings.add('Codegen capability requires codegenLanguages');
      }
    }

    return ManifestValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  Version? _parseVersion(String version) {
    final parts = version.split('.');
    if (parts.length != 3) return null;
    try {
      return Version(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if plugin supports the given editor type
  bool supportsEditor(PluginEditorType editor) {
    return editorType.contains(editor);
  }

  /// Check if plugin has UI
  bool get hasUI => ui != null && ui!.isNotEmpty;

  /// Check if plugin has menu items
  bool get hasMenu => menu != null && menu!.isNotEmpty;

  /// Check if plugin requires network access
  bool get requiresNetworkAccess =>
      networkAccess != null && networkAccess!.allowedDomains.isNotEmpty;

  /// Get all commands from menu items
  List<String> get allCommands {
    final commands = <String>[];
    void extractCommands(List<PluginMenuItem>? items) {
      if (items == null) return;
      for (final item in items) {
        if (item.command != null) commands.add(item.command!);
        extractCommands(item.menu);
      }
    }
    extractCommands(menu);
    return commands;
  }
}

/// Version helper class
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >=(Version other) => compareTo(other) >= 0;

  @override
  String toString() => '$major.$minor.$patch';
}

/// Result of manifest validation
class ManifestValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ManifestValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}
