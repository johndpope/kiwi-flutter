/// Plugin API - Figma-compatible API exposed to plugins
///
/// Provides the `figma` global object with methods for:
/// - Node creation and manipulation (all node types)
/// - Document access and viewport control
/// - UI communication (showUI, postMessage)
/// - User information and payments
/// - Event handling (selectionchange, documentchange)
/// - Client storage and plugin data
/// - Permissions enforcement

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'plugin_manifest.dart';

/// Permission types that plugins can request
enum PluginPermission {
  currentuser,
  activeusers,
  fileusers,
  payments,
  teamlibrary,
  brandingstatus,
}

/// Figma API exposed to plugins
class FigmaPluginAPI {
  /// Plugin manifest for permission checking
  final PluginManifest? manifest;

  /// API version (PRD 4.16.1.1)
  String get apiVersion => manifest?.api ?? '1.0.0';

  /// Plugin ID
  String? get pluginId => manifest?.id;

  /// Current page/document
  PluginDocumentProxy? _currentPage;
  PluginDocumentProxy? get currentPage => _currentPage;
  set currentPage(PluginDocumentProxy? page) {
    _currentPage = page;
    _triggerEvent('currentpagechange');
  }

  /// Set current page async (PRD 4.16.1.3)
  Future<void> setCurrentPageAsync(PluginDocumentProxy page) async {
    _currentPage = page;
    _triggerEvent('currentpagechange');
  }

  /// Root node of the document
  final PluginDocumentNode root;

  /// Current user info (requires 'currentuser' permission)
  PluginUserProxy? _currentUser;
  PluginUserProxy? get currentUser {
    _checkPermission(PluginPermission.currentuser);
    return _currentUser;
  }

  /// Active users in the file (requires 'activeusers' permission)
  List<PluginUserProxy> _activeUsers = [];
  List<PluginUserProxy> get activeUsers {
    _checkPermission(PluginPermission.activeusers);
    return List.unmodifiable(_activeUsers);
  }

  /// File users (requires 'fileusers' permission)
  List<PluginUserProxy> _fileUsers = [];
  List<PluginUserProxy> get fileUsers {
    _checkPermission(PluginPermission.fileusers);
    return List.unmodifiable(_fileUsers);
  }

  /// Plugin command being executed
  String? command;

  /// Plugin parameters from quick actions
  ParameterValues? parameters;

  /// UI controller for showUI/postMessage
  final PluginUIController ui;

  /// Mixed value constant
  static const mixed = _MixedSymbol();

  /// Viewport control
  final PluginViewportProxy viewport;

  /// Variables API (PRD 4.16.1.6)
  final PluginVariablesAPI variables = PluginVariablesAPI();

  /// Util API helpers
  final PluginUtilAPI util = PluginUtilAPI();

  /// Constants API
  final PluginConstantsAPI constants = PluginConstantsAPI();

  /// Payments API (requires 'payments' permission)
  PluginPaymentsProxy? _payments;
  PluginPaymentsProxy get payments {
    _checkPermission(PluginPermission.payments);
    return _payments ??= PluginPaymentsProxy();
  }

  /// Team library (requires 'teamlibrary' permission)
  PluginTeamLibraryProxy? _teamLibrary;
  PluginTeamLibraryProxy get teamLibrary {
    _checkPermission(PluginPermission.teamlibrary);
    return _teamLibrary ??= PluginTeamLibraryProxy();
  }

  /// Current selection
  List<PluginNodeProxy> _selection = [];
  List<PluginNodeProxy> get selection => List.unmodifiable(_selection);
  set selection(List<PluginNodeProxy> nodes) {
    _selection = List.from(nodes);
    _triggerEvent('selectionchange');
  }

  /// Editor type (figma, figjam, dev)
  final PluginEditorType editorType;

  /// File key
  final String? fileKey;

  /// Widget ID (for widget plugins)
  final String? widgetId;

  /// Timer API
  final PluginTimerProxy timer = PluginTimerProxy();

  /// Event handlers
  final Map<String, List<Function>> _eventHandlers = {};

  /// Whether plugin is running
  bool _isRunning = true;

  /// Client storage API
  final clientStorage = PluginClientStorage();

  FigmaPluginAPI({
    this.manifest,
    PluginDocumentProxy? currentPage,
    PluginDocumentNode? root,
    PluginUserProxy? currentUser,
    List<PluginUserProxy>? activeUsers,
    required this.ui,
    required this.viewport,
    this.editorType = PluginEditorType.figma,
    this.fileKey,
    this.widgetId,
  })  : _currentPage = currentPage,
        root = root ?? PluginDocumentNode(),
        _currentUser = currentUser,
        _activeUsers = activeUsers ?? [];

  /// Check if plugin has required permission
  void _checkPermission(PluginPermission permission) {
    if (manifest == null) return; // No manifest = no restrictions (for testing)

    final permissionName = permission.name;
    if (manifest!.permissions?.contains(permissionName) != true) {
      throw PluginPermissionError(
        'Plugin does not have "$permissionName" permission. '
        'Add it to manifest.json permissions array.',
      );
    }
  }

  /// Check if network access is allowed for a URL
  bool isNetworkAccessAllowed(String url) {
    if (manifest?.networkAccess == null) return false;
    return manifest!.networkAccess!.isUrlAllowed(url);
  }

  /// Check network access with detailed result
  NetworkAccessResult checkNetworkAccess(String url) {
    if (manifest?.networkAccess == null) {
      return NetworkAccessResult(
        allowed: false,
        reason: NetworkDenyReason.domainNotAllowed,
        message: 'Plugin has no network access configuration',
      );
    }
    return manifest!.networkAccess!.checkUrl(url);
  }

  /// Fetch data from a URL (enforces network permissions)
  ///
  /// Throws [PluginNetworkError] if the URL is not in the allowed domains.
  /// This method simulates a fetch operation - in a real implementation
  /// this would use http client.
  Future<PluginFetchResponse> fetch(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = checkNetworkAccess(url);

    if (!result.allowed) {
      throw PluginNetworkError(
        result.message ?? 'Network access denied',
        url: url,
        reason: result.reason,
      );
    }

    // In a real implementation, this would make an actual HTTP request
    // For now, we simulate a successful response
    debugPrint('Plugin fetch: $method $url');
    return PluginFetchResponse(
      status: 200,
      ok: true,
      headers: {'content-type': 'application/json'},
      body: '{}',
    );
  }

  // ============ Node Creation Methods ============

  /// Create a new rectangle node
  PluginNodeProxy createRectangle() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.RECTANGLE,
      name: 'Rectangle',
    );
  }

  /// Create a new frame node
  PluginNodeProxy createFrame() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.FRAME,
      name: 'Frame',
    );
  }

  /// Create a new text node
  PluginNodeProxy createText() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.TEXT,
      name: 'Text',
    );
  }

  /// Create a new ellipse node
  PluginNodeProxy createEllipse() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.ELLIPSE,
      name: 'Ellipse',
    );
  }

  /// Create a new line node
  PluginNodeProxy createLine() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.LINE,
      name: 'Line',
    );
  }

  /// Create a new polygon node
  PluginNodeProxy createPolygon() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.POLYGON,
      name: 'Polygon',
    );
  }

  /// Create a new star node
  PluginNodeProxy createStar() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.STAR,
      name: 'Star',
    );
  }

  /// Create a new vector node
  PluginNodeProxy createVector() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.VECTOR,
      name: 'Vector',
    );
  }

  /// Create a new boolean operation node
  PluginNodeProxy createBooleanOperation() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.BOOLEAN_OPERATION,
      name: 'Boolean',
    );
  }

  /// Create a component from selection
  PluginNodeProxy createComponent() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.COMPONENT,
      name: 'Component',
    );
  }

  /// Create a component set
  PluginNodeProxy createComponentSet() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.COMPONENT_SET,
      name: 'Component Set',
    );
  }

  /// Create a page
  PluginDocumentProxy createPage() {
    return PluginDocumentProxy(
      id: _generateId(),
      name: 'Page',
    );
  }

  /// Create a slice
  PluginNodeProxy createSlice() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.SLICE,
      name: 'Slice',
    );
  }

  /// Create a section node
  PluginNodeProxy createSection() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.SECTION,
      name: 'Section',
    );
  }

  /// Create a sticky note (FigJam)
  PluginNodeProxy createSticky() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.STICKY,
      name: 'Sticky',
    );
  }

  /// Create a shape with text (FigJam)
  PluginNodeProxy createShapeWithText() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.SHAPE_WITH_TEXT,
      name: 'Shape with Text',
    );
  }

  /// Create a connector (FigJam)
  PluginNodeProxy createConnector() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.CONNECTOR,
      name: 'Connector',
    );
  }

  /// Create a code block (FigJam)
  PluginNodeProxy createCodeBlock() {
    return PluginNodeProxy(
      id: _generateId(),
      type: NodeType.CODE_BLOCK,
      name: 'Code Block',
    );
  }

  /// Create a table (FigJam)
  PluginNodeProxy createTable({int rows = 3, int columns = 3}) {
    final table = PluginNodeProxy(
      id: _generateId(),
      type: NodeType.TABLE,
      name: 'Table',
    );
    table.numRows = rows;
    table.numColumns = columns;
    return table;
  }

  /// Create a widget instance
  PluginNodeProxy createNodeFromSvg(String svg) {
    final node = PluginNodeProxy(
      id: _generateId(),
      type: NodeType.VECTOR,
      name: 'SVG',
    );
    // Would parse SVG and populate vector data
    return node;
  }

  /// Create image from bytes
  Future<PluginImageProxy> createImage(List<int> bytes) async {
    final hash = _generateId();
    return PluginImageProxy(hash: hash, bytes: bytes);
  }

  // ============ Node Operations ============

  /// Get node by ID
  PluginNodeProxy? getNodeById(String id) {
    return root.findOne((n) => n.id == id);
  }

  /// Get style by ID
  PluginStyleProxy? getStyleById(String id) {
    return _localPaintStyles.firstWhere(
      (s) => s.id == id,
      orElse: () => _localTextStyles.firstWhere(
        (s) => s.id == id,
        orElse: () => _localEffectStyles.firstWhere(
          (s) => s.id == id,
          orElse: () => _localGridStyles.firstWhere(
            (s) => s.id == id,
            orElse: () => PluginStyleProxy(id: '', name: ''),
          ),
        ),
      ),
    );
  }

  /// Close plugin
  void closePlugin([String? message]) {
    _isRunning = false;
    _triggerEvent('close');
    if (message != null) {
      notify(message);
    }
  }

  /// Show notification
  NotificationHandler notify(
    String message, {
    Duration? timeout,
    bool error = false,
    VoidCallback? onDequeue,
  }) {
    debugPrint('Plugin notification${error ? " (error)" : ""}: $message');
    return NotificationHandler(
      cancel: () {
        debugPrint('Notification cancelled');
      },
    );
  }

  /// Show UI
  void showUI(
    String html, {
    double? width,
    double? height,
    String? title,
    bool visible = true,
    bool themeColors = false,
    PluginPosition? position,
  }) {
    ui.showUI(
      html,
      width: width,
      height: height,
      title: title,
      visible: visible,
    );
  }

  // ============ Event Handling ============

  /// Register event handler
  void on(String event, Function handler) {
    _eventHandlers.putIfAbsent(event, () => []).add(handler);
  }

  /// Register one-time event handler
  void once(String event, Function handler) {
    late Function wrapper;
    wrapper = () {
      handler();
      off(event, wrapper);
    };
    on(event, wrapper);
  }

  /// Unregister event handler
  void off(String event, Function handler) {
    _eventHandlers[event]?.remove(handler);
  }

  /// Trigger event
  void _triggerEvent(String event, [dynamic data]) {
    final handlers = _eventHandlers[event];
    if (handlers != null) {
      for (final handler in List.from(handlers)) {
        try {
          if (data != null) {
            handler(data);
          } else {
            handler();
          }
        } catch (e) {
          debugPrint('Event handler error: $e');
        }
      }
    }
  }

  /// Trigger selection change (called by host)
  void triggerSelectionChange() => _triggerEvent('selectionchange');

  /// Trigger document change (called by host)
  void triggerDocumentChange(DocumentChangeEvent event) {
    _triggerEvent('documentchange', event);
  }

  /// Trigger run (called by host)
  void triggerRun(RunEvent event) {
    command = event.command;
    parameters = event.parameters;
    _triggerEvent('run', event);
  }

  /// Trigger drop (called by host)
  void triggerDrop(DropEvent event) => _triggerEvent('drop', event);

  // ============ Undo/Redo ============

  /// Commit undo group
  void commitUndo() {
    // Would commit undo in actual implementation
  }

  /// Save version to history
  Future<void> saveVersionHistoryAsync(
    String title, {
    String? description,
  }) async {
    // Would save version
  }

  // ============ Grouping & Boolean Operations ============

  /// Group nodes
  PluginNodeProxy group(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final group = PluginNodeProxy(
      id: _generateId(),
      type: NodeType.GROUP,
      name: 'Group',
    );
    for (final node in nodes) {
      node.remove();
      group.appendChild(node);
    }
    if (index != null) {
      parent.insertChild(index, group);
    } else {
      parent.appendChild(group);
    }
    return group;
  }

  /// Ungroup nodes
  List<PluginNodeProxy> ungroup(PluginNodeProxy group) {
    if (group.type != NodeType.GROUP) return [];
    final parent = group.parent;
    if (parent == null) return [];

    final children = List<PluginNodeProxy>.from(group.children);
    final index = parent.children.indexOf(group);

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      child.x += group.x;
      child.y += group.y;
      parent.insertChild(index + i, child);
    }
    group.remove();
    return children;
  }

  /// Flatten nodes to vector
  PluginNodeProxy flatten(List<PluginNodeProxy> nodes, [PluginNodeProxy? parent, int? index]) {
    final vector = PluginNodeProxy(
      id: _generateId(),
      type: NodeType.VECTOR,
      name: 'Vector',
    );
    // Would compute flattened path
    return vector;
  }

  /// Boolean union
  PluginNodeProxy union(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = BooleanOperationType.UNION;
    for (final child in nodes) {
      node.appendChild(child);
    }
    if (index != null) {
      parent.insertChild(index, node);
    } else {
      parent.appendChild(node);
    }
    return node;
  }

  /// Boolean subtract
  PluginNodeProxy subtract(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = BooleanOperationType.SUBTRACT;
    for (final child in nodes) {
      node.appendChild(child);
    }
    if (index != null) {
      parent.insertChild(index, node);
    } else {
      parent.appendChild(node);
    }
    return node;
  }

  /// Boolean intersect
  PluginNodeProxy intersect(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = BooleanOperationType.INTERSECT;
    for (final child in nodes) {
      node.appendChild(child);
    }
    if (index != null) {
      parent.insertChild(index, node);
    } else {
      parent.appendChild(node);
    }
    return node;
  }

  /// Boolean exclude
  PluginNodeProxy exclude(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = BooleanOperationType.EXCLUDE;
    for (final child in nodes) {
      node.appendChild(child);
    }
    if (index != null) {
      parent.insertChild(index, node);
    } else {
      parent.appendChild(node);
    }
    return node;
  }

  // ============ Font Loading ============

  /// Load font for text operations
  Future<void> loadFontAsync(FontName font) async {
    // Would load font - required before setting text properties
    debugPrint('Loading font: ${font.family} ${font.style}');
  }

  /// List available fonts
  Future<List<FontName>> listAvailableFontsAsync() async {
    return [
      const FontName(family: 'Inter', style: 'Regular'),
      const FontName(family: 'Inter', style: 'Bold'),
      const FontName(family: 'Roboto', style: 'Regular'),
      const FontName(family: 'Roboto', style: 'Bold'),
    ];
  }

  // ============ Styles ============

  final List<PluginStyleProxy> _localPaintStyles = [];
  final List<PluginStyleProxy> _localTextStyles = [];
  final List<PluginStyleProxy> _localEffectStyles = [];
  final List<PluginStyleProxy> _localGridStyles = [];

  List<PluginStyleProxy> getLocalPaintStyles() => List.unmodifiable(_localPaintStyles);
  List<PluginStyleProxy> getLocalTextStyles() => List.unmodifiable(_localTextStyles);
  List<PluginStyleProxy> getLocalEffectStyles() => List.unmodifiable(_localEffectStyles);
  List<PluginStyleProxy> getLocalGridStyles() => List.unmodifiable(_localGridStyles);

  // Async versions (PRD 4.16.5.2)
  Future<List<PluginStyleProxy>> getLocalPaintStylesAsync() async => getLocalPaintStyles();
  Future<List<PluginStyleProxy>> getLocalTextStylesAsync() async => getLocalTextStyles();
  Future<List<PluginStyleProxy>> getLocalEffectStylesAsync() async => getLocalEffectStyles();
  Future<List<PluginStyleProxy>> getLocalGridStylesAsync() async => getLocalGridStyles();

  /// Get style by ID async (PRD 4.16.5.2)
  Future<PluginStyleProxy?> getStyleByIdAsync(String id) async {
    for (final list in [_localPaintStyles, _localTextStyles, _localEffectStyles, _localGridStyles]) {
      for (final style in list) {
        if (style.id == id) return style;
      }
    }
    return null;
  }

  PluginStyleProxy createPaintStyle() {
    final style = PluginStyleProxy(id: _generateId(), name: 'Paint Style');
    _localPaintStyles.add(style);
    return style;
  }

  PluginStyleProxy createTextStyle() {
    final style = PluginStyleProxy(id: _generateId(), name: 'Text Style');
    _localTextStyles.add(style);
    return style;
  }

  PluginStyleProxy createEffectStyle() {
    final style = PluginStyleProxy(id: _generateId(), name: 'Effect Style');
    _localEffectStyles.add(style);
    return style;
  }

  PluginStyleProxy createGridStyle() {
    final style = PluginStyleProxy(id: _generateId(), name: 'Grid Style');
    _localGridStyles.add(style);
    return style;
  }

  // ============ Variables ============

  List<PluginVariableProxy> getLocalVariables() => [];

  PluginVariableProxy createVariable(String name, String collectionId, String resolvedType) {
    return PluginVariableProxy(
      id: _generateId(),
      name: name,
      collectionId: collectionId,
      resolvedType: resolvedType,
    );
  }

  List<PluginVariableCollectionProxy> getLocalVariableCollections() => [];

  PluginVariableCollectionProxy createVariableCollection(String name) {
    return PluginVariableCollectionProxy(id: _generateId(), name: name);
  }

  // ============ Import/Export ============

  Future<List<int>> exportAsync(
    PluginNodeProxy node, {
    String format = 'PNG',
    double scale = 1,
    String? constraint,
    bool contentsOnly = false,
    bool useAbsoluteBounds = false,
    String? svgIdAttribute,
    bool svgOutlineText = true,
    bool svgSimplifyStroke = true,
  }) async {
    // Would export node to bytes
    return [];
  }

  /// Import a component by key from team library
  Future<PluginNodeProxy?> importComponentByKeyAsync(String key) async {
    _checkPermission(PluginPermission.teamlibrary);
    // Would fetch component from team library
    debugPrint('Importing component: $key');
    return null;
  }

  /// Import a component set by key from team library
  Future<PluginNodeProxy?> importComponentSetByKeyAsync(String key) async {
    _checkPermission(PluginPermission.teamlibrary);
    // Would fetch component set from team library
    debugPrint('Importing component set: $key');
    return null;
  }

  /// Import a style by key from team library
  Future<PluginStyleProxy?> importStyleByKeyAsync(String key) async {
    _checkPermission(PluginPermission.teamlibrary);
    // Would fetch style from team library
    debugPrint('Importing style: $key');
    return null;
  }

  /// Get file thumbnail node
  Future<PluginNodeProxy?> getFileThumbnailNodeAsync() async {
    // Would return the node used for file thumbnail
    return null;
  }

  /// Set file thumbnail node
  Future<void> setFileThumbnailNodeAsync(PluginNodeProxy? node) async {
    // Would set the node used for file thumbnail
    debugPrint('Setting thumbnail node: ${node?.id}');
  }

  // ============ Codegen Support ============

  /// Whether to skip invisible instance children during traversal
  bool skipInvisibleInstanceChildren = false;

  /// Get CSS for a node (codegen feature)
  Future<Map<String, String>> getCSSAsync(
    PluginNodeProxy node, {
    List<String>? stylesToInclude,
  }) async {
    // Would generate CSS from node properties
    final css = <String, String>{};

    // Basic CSS generation
    css['width'] = '${node.width}px';
    css['height'] = '${node.height}px';

    if (node.fills.isNotEmpty) {
      final fill = node.fills.first;
      if (fill.type == 'SOLID' && fill.color != null) {
        final c = fill.color!;
        css['background-color'] =
            'rgba(${(c.r * 255).round()}, ${(c.g * 255).round()}, ${(c.b * 255).round()}, ${fill.opacity})';
      }
    }

    if (node.cornerRadius > 0) {
      css['border-radius'] = '${node.cornerRadius}px';
    }

    if (node.effects.isNotEmpty) {
      final shadows = node.effects
          .where((e) => e.type == 'DROP_SHADOW')
          .map((e) =>
              '${e.offsetX ?? 0}px ${e.offsetY ?? 0}px ${e.radius}px rgba(0,0,0,0.25)')
          .join(', ');
      if (shadows.isNotEmpty) {
        css['box-shadow'] = shadows;
      }
    }

    return css;
  }

  /// Get bound variables for a node
  Map<String, BoundVariable> getBoundVariables(PluginNodeProxy node) {
    // Would return variables bound to node properties
    return {};
  }

  /// Set bound variable on a node
  void setBoundVariable(
    PluginNodeProxy node,
    String property,
    PluginVariableProxy variable,
  ) {
    // Would bind variable to property
    debugPrint('Binding ${variable.name} to $property on ${node.id}');
  }

  // ============ Dev Mode ============

  /// Get annotations for a node
  List<Annotation> getAnnotations(PluginNodeProxy node) {
    return node.annotations;
  }

  /// Add annotation to a node
  void addAnnotation(PluginNodeProxy node, Annotation annotation) {
    node.annotations.add(annotation);
  }

  /// Get measurements for a node
  List<Measurement> getMeasurements(PluginNodeProxy node) {
    return node.measurements;
  }

  /// Add measurement between nodes
  void addMeasurement(Measurement measurement) {
    // Would add measurement to document
    debugPrint('Adding measurement: ${measurement.id}');
  }

  // ============ Utilities ============

  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}:${_idCounter++}';
  }

  static int _idCounter = 0;
}

// ============ Supporting Types ============

/// Symbol for mixed values (when selection has different values)
class _MixedSymbol {
  const _MixedSymbol();

  @override
  String toString() => 'figma.mixed';
}

/// Node types supported by the API
enum NodeType {
  DOCUMENT,
  PAGE,
  FRAME,
  GROUP,
  SECTION,
  SLICE,
  RECTANGLE,
  LINE,
  ELLIPSE,
  POLYGON,
  STAR,
  VECTOR,
  TEXT,
  BOOLEAN_OPERATION,
  COMPONENT,
  COMPONENT_SET,
  INSTANCE,
  STICKY,
  SHAPE_WITH_TEXT,
  CONNECTOR,
  CODE_BLOCK,
  STAMP,
  WIDGET,
  EMBED,
  LINK_UNFURL,
  MEDIA,
  HIGHLIGHT,
  WASHI_TAPE,
  TABLE,
  TABLE_CELL,
}

/// Boolean operation types
enum BooleanOperationType {
  UNION,
  SUBTRACT,
  INTERSECT,
  EXCLUDE,
}

/// Blend modes
enum BlendMode {
  PASS_THROUGH,
  NORMAL,
  DARKEN,
  MULTIPLY,
  LINEAR_BURN,
  COLOR_BURN,
  LIGHTEN,
  SCREEN,
  LINEAR_DODGE,
  COLOR_DODGE,
  OVERLAY,
  SOFT_LIGHT,
  HARD_LIGHT,
  DIFFERENCE,
  EXCLUSION,
  HUE,
  SATURATION,
  COLOR,
  LUMINOSITY,
}

/// Stroke cap types
enum StrokeCap {
  NONE,
  ROUND,
  SQUARE,
  LINE_ARROW,
  TRIANGLE_ARROW,
  CIRCLE_FILLED,
  DIAMOND_FILLED,
}

/// Stroke join types
enum StrokeJoin {
  MITER,
  BEVEL,
  ROUND,
}

/// Stroke align types
enum StrokeAlign {
  CENTER,
  INSIDE,
  OUTSIDE,
}

/// Text alignment horizontal
enum TextAlignHorizontal {
  LEFT,
  CENTER,
  RIGHT,
  JUSTIFIED,
}

/// Text alignment vertical
enum TextAlignVertical {
  TOP,
  CENTER,
  BOTTOM,
}

/// Text decoration
enum TextDecoration {
  NONE,
  UNDERLINE,
  STRIKETHROUGH,
}

/// Text case
enum TextCase {
  ORIGINAL,
  UPPER,
  LOWER,
  TITLE,
  SMALL_CAPS,
  SMALL_CAPS_FORCED,
}

/// Auto layout direction
enum LayoutMode {
  NONE,
  HORIZONTAL,
  VERTICAL,
}

/// Layout align
enum LayoutAlign {
  MIN,
  CENTER,
  MAX,
  STRETCH,
  INHERIT,
}

/// Constraint type
enum ConstraintType {
  MIN,
  CENTER,
  MAX,
  STRETCH,
  SCALE,
}

/// Document node (root of document tree)
class PluginDocumentNode {
  final String id;
  final String name;
  final List<PluginDocumentProxy> children = [];

  PluginDocumentNode({
    String? id,
    this.name = 'Document',
  }) : id = id ?? '0:0';

  void appendChild(PluginDocumentProxy page) {
    children.add(page);
  }

  PluginNodeProxy? findOne(bool Function(PluginNodeProxy) test) {
    for (final page in children) {
      final found = page.findChild(test);
      if (found != null) return found;
    }
    return null;
  }

  List<PluginNodeProxy> findAll(bool Function(PluginNodeProxy) test) {
    final results = <PluginNodeProxy>[];
    for (final page in children) {
      results.addAll(page.findAll(test));
    }
    return results;
  }
}

/// Proxy for document/page
class PluginDocumentProxy {
  final String id;
  String name;
  final List<PluginNodeProxy> children = [];
  List<Paint>? backgrounds;
  List<PluginGuideProxy> guides = [];
  List<FlowStartingPoint> flowStartingPoints = [];
  PluginNodeProxy? selection;

  PluginDocumentProxy({
    required this.id,
    required this.name,
  });

  void appendChild(PluginNodeProxy node) {
    node.parent?.children.remove(node);
    node.parent = null;
    children.add(node);
  }

  void insertChild(int index, PluginNodeProxy node) {
    node.parent?.children.remove(node);
    node.parent = null;
    children.insert(index, node);
  }

  PluginNodeProxy? findChild(bool Function(PluginNodeProxy) callback) {
    for (final child in children) {
      if (callback(child)) return child;
      final found = child.findChild(callback);
      if (found != null) return found;
    }
    return null;
  }

  List<PluginNodeProxy> findAll(bool Function(PluginNodeProxy) callback) {
    final results = <PluginNodeProxy>[];
    for (final child in children) {
      if (callback(child)) results.add(child);
      results.addAll(child.findAll(callback));
    }
    return results;
  }

  List<PluginNodeProxy> findAllWithCriteria({
    List<NodeType>? types,
  }) {
    return findAll((node) {
      if (types != null && !types.contains(node.type)) return false;
      return true;
    });
  }
}

/// Guide proxy
class PluginGuideProxy {
  final String axis;
  final double offset;

  const PluginGuideProxy({required this.axis, required this.offset});
}

/// Flow starting point
class FlowStartingPoint {
  final String name;
  final String nodeId;

  const FlowStartingPoint({required this.name, required this.nodeId});
}

/// Proxy for a node in the document
class PluginNodeProxy {
  final String id;
  NodeType type;
  String name;
  PluginNodeProxy? parent;
  final List<PluginNodeProxy> children = [];

  // Transform
  double x = 0;
  double y = 0;
  double width = 100;
  double height = 100;
  double rotation = 0;
  List<List<double>>? relativeTransform;

  // Appearance
  List<Paint> fills = [];
  List<Paint> strokes = [];
  List<Effect> effects = [];
  double opacity = 1;
  BlendMode blendMode = BlendMode.NORMAL;
  bool visible = true;
  bool locked = false;
  bool expanded = true;

  // Corner radius
  double cornerRadius = 0;
  List<double>? rectangleCornerRadii;
  double? cornerSmoothing;

  // Stroke
  double strokeWeight = 1;
  StrokeAlign strokeAlign = StrokeAlign.CENTER;
  StrokeCap strokeCap = StrokeCap.NONE;
  StrokeJoin strokeJoin = StrokeJoin.MITER;
  List<double>? dashPattern;
  double? strokeMiterLimit;

  // Text
  String characters = '';
  double fontSize = 14;
  FontName? fontName;
  TextAlignHorizontal textAlignHorizontal = TextAlignHorizontal.LEFT;
  TextAlignVertical textAlignVertical = TextAlignVertical.TOP;
  TextDecoration textDecoration = TextDecoration.NONE;
  TextCase textCase = TextCase.ORIGINAL;
  double? lineHeight;
  double? letterSpacing;
  double? paragraphIndent;
  double? paragraphSpacing;
  bool? textAutoResize;
  String? textStyleId;

  // Layout (Auto Layout)
  LayoutMode layoutMode = LayoutMode.NONE;
  double itemSpacing = 0;
  double counterAxisSpacing = 0;
  double paddingLeft = 0;
  double paddingRight = 0;
  double paddingTop = 0;
  double paddingBottom = 0;
  LayoutAlign layoutAlign = LayoutAlign.INHERIT;
  double layoutGrow = 0;
  String primaryAxisSizingMode = 'AUTO';
  String counterAxisSizingMode = 'AUTO';
  String primaryAxisAlignItems = 'MIN';
  String counterAxisAlignItems = 'MIN';
  String layoutWrap = 'NO_WRAP';
  bool clipsContent = true;
  bool itemReverseZIndex = false;
  bool strokesIncludedInLayout = false;

  // Component
  PluginNodeProxy? mainComponent;
  BooleanOperationType? booleanOperation;
  Map<String, ComponentPropertyDefinition> componentPropertyDefinitions = {};
  bool? overflowDirection;

  // Instance overrides
  List<InstanceSwapPreferredValue>? instanceSwapPreferredValues;
  Map<String, String>? overrides;

  // Constraints
  Constraints constraints = const Constraints();

  // Export settings
  List<ExportSetting> exportSettings = [];

  // Reactions/prototyping
  List<Reaction> reactions = [];
  String? transitionNodeID;
  double? transitionDuration;
  String? transitionEasing;

  // Plugin data
  final Map<String, Map<String, String>> _pluginData = {};
  final Map<String, Map<String, String>> _sharedPluginData = {};
  final Map<String, String> _relaunchData = {};

  // Vector specific
  VectorNetwork? vectorNetwork;
  List<PluginVectorPath>? vectorPaths;

  // Table specific
  int numRows = 0;
  int numColumns = 0;

  // Annotations (Dev Mode)
  List<Annotation> annotations = [];

  // Measurements (Dev Mode)
  List<Measurement> measurements = [];

  PluginNodeProxy({
    required this.id,
    required this.type,
    required this.name,
  });

  /// Clone this node (deep copy)
  PluginNodeProxy clone() {
    final clone = PluginNodeProxy(
      id: FigmaPluginAPI._generateId(),
      type: type,
      name: name,
    );
    clone.x = x;
    clone.y = y;
    clone.width = width;
    clone.height = height;
    clone.rotation = rotation;
    clone.fills = List.from(fills);
    clone.strokes = List.from(strokes);
    clone.effects = List.from(effects);
    clone.opacity = opacity;
    clone.blendMode = blendMode;
    clone.visible = visible;
    clone.locked = locked;
    clone.cornerRadius = cornerRadius;
    clone.rectangleCornerRadii = rectangleCornerRadii != null
        ? List.from(rectangleCornerRadii!)
        : null;
    clone.strokeWeight = strokeWeight;
    clone.strokeAlign = strokeAlign;
    clone.characters = characters;
    clone.fontSize = fontSize;
    clone.fontName = fontName;

    // Clone children recursively
    for (final child in children) {
      clone.appendChild(child.clone());
    }

    return clone;
  }

  /// Remove this node from parent
  void remove() {
    parent?.children.remove(this);
    parent = null;
  }

  /// Get absolute transform matrix
  List<List<double>> get absoluteTransform {
    double absX = x;
    double absY = y;
    var p = parent;
    while (p != null) {
      absX += p.x;
      absY += p.y;
      p = p.parent;
    }
    return [
      [1, 0, absX],
      [0, 1, absY],
    ];
  }

  /// Get absolute bounding box
  FigmaRect get absoluteBoundingBox {
    final transform = absoluteTransform;
    return FigmaRect(
      x: transform[0][2],
      y: transform[1][2],
      width: width,
      height: height,
    );
  }

  /// Get absolute render bounds (includes effects like shadows)
  FigmaRect get absoluteRenderBounds {
    final box = absoluteBoundingBox;
    // Would expand for effects
    return box;
  }

  /// Resize node
  void resize(double w, double h) {
    width = w;
    height = h;
  }

  /// Resize with constraints
  void resizeWithoutConstraints(double w, double h) {
    width = w;
    height = h;
  }

  /// Rescale node
  void rescale(double scale) {
    width *= scale;
    height *= scale;
  }

  /// Set size to fill parent (auto layout)
  void setFillSizeConstraint(bool horizontal, bool vertical) {
    if (horizontal) layoutAlign = LayoutAlign.STRETCH;
    if (vertical) layoutGrow = 1;
  }

  /// Set plugin data
  void setPluginData(String key, String value) {
    _pluginData.putIfAbsent('_default', () => {})[key] = value;
  }

  /// Get plugin data
  String? getPluginData(String key) {
    return _pluginData['_default']?[key];
  }

  /// Get all plugin data keys
  List<String> getPluginDataKeys() {
    return _pluginData['_default']?.keys.toList() ?? [];
  }

  /// Set shared plugin data
  void setSharedPluginData(String namespace, String key, String value) {
    _sharedPluginData.putIfAbsent(namespace, () => {})[key] = value;
  }

  /// Get shared plugin data
  String? getSharedPluginData(String namespace, String key) {
    return _sharedPluginData[namespace]?[key];
  }

  /// Get shared plugin data keys
  List<String> getSharedPluginDataKeys(String namespace) {
    return _sharedPluginData[namespace]?.keys.toList() ?? [];
  }

  /// Set relaunch data for quick actions
  void setRelaunchData(Map<String, String> data) {
    _relaunchData.clear();
    _relaunchData.addAll(data);
  }

  /// Get relaunch data
  Map<String, String> get relaunchData => Map.unmodifiable(_relaunchData);

  // Child operations
  void appendChild(PluginNodeProxy node) {
    node.parent?.children.remove(node);
    node.parent = this;
    children.add(node);
  }

  void insertChild(int index, PluginNodeProxy node) {
    node.parent?.children.remove(node);
    node.parent = this;
    children.insert(index.clamp(0, children.length), node);
  }

  PluginNodeProxy? findChild(bool Function(PluginNodeProxy) callback) {
    for (final child in children) {
      if (callback(child)) return child;
      final found = child.findChild(callback);
      if (found != null) return found;
    }
    return null;
  }

  List<PluginNodeProxy> findAll(bool Function(PluginNodeProxy) callback) {
    final results = <PluginNodeProxy>[];
    for (final child in children) {
      if (callback(child)) results.add(child);
      results.addAll(child.findAll(callback));
    }
    return results;
  }

  List<PluginNodeProxy> findAllWithCriteria({
    List<NodeType>? types,
  }) {
    return findAll((node) {
      if (types != null && !types.contains(node.type)) return false;
      return true;
    });
  }

  /// Get range of text for styled segments
  StyledTextSegment? getRangeFontName(int start, int end) {
    return StyledTextSegment(
      start: start,
      end: end,
      fontName: fontName,
      fontSize: fontSize,
    );
  }

  /// Set text style for range
  void setRangeFontName(int start, int end, FontName font) {
    // Would apply to text range
    fontName = font;
  }

  void setRangeFontSize(int start, int end, double size) {
    fontSize = size;
  }

  void setRangeFills(int start, int end, List<Paint> paints) {
    fills = paints;
  }
}

/// Figma rectangle bounds (to avoid conflict with dart:ui Rect)
class FigmaRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const FigmaRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, double> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

/// Figma RGBA color structure (0-1 range, not Flutter's Color)
class FigmaColor {
  final double r;
  final double g;
  final double b;
  final double a;

  const FigmaColor({
    required this.r,
    required this.g,
    required this.b,
    this.a = 1,
  });

  Map<String, double> toJson() => {'r': r, 'g': g, 'b': b, 'a': a};
}

/// Font name structure
class FontName {
  final String family;
  final String style;

  const FontName({required this.family, required this.style});

  Map<String, String> toJson() => {'family': family, 'style': style};
}

/// Paint structure (fills/strokes)
class Paint {
  final String type;
  final bool visible;
  final double opacity;
  final BlendMode blendMode;
  final FigmaColor? color;
  final List<ColorStop>? gradientStops;
  final List<List<double>>? gradientTransform;
  final String? imageHash;
  final String? scaleMode;

  const Paint({
    required this.type,
    this.visible = true,
    this.opacity = 1,
    this.blendMode = BlendMode.NORMAL,
    this.color,
    this.gradientStops,
    this.gradientTransform,
    this.imageHash,
    this.scaleMode,
  });

  factory Paint.solid(FigmaColor color, {double opacity = 1}) {
    return Paint(type: 'SOLID', color: color, opacity: opacity);
  }

  factory Paint.linearGradient(List<ColorStop> stops) {
    return Paint(type: 'GRADIENT_LINEAR', gradientStops: stops);
  }

  factory Paint.radialGradient(List<ColorStop> stops) {
    return Paint(type: 'GRADIENT_RADIAL', gradientStops: stops);
  }

  factory Paint.image(String imageHash, {String scaleMode = 'FILL'}) {
    return Paint(type: 'IMAGE', imageHash: imageHash, scaleMode: scaleMode);
  }
}

/// Gradient color stop
class ColorStop {
  final double position;
  final FigmaColor color;

  const ColorStop({required this.position, required this.color});
}

/// Effect structure (shadows, blur)
class Effect {
  final String type;
  final bool visible;
  final double radius;
  final FigmaColor? color;
  final double? offsetX;
  final double? offsetY;
  final double? spread;
  final bool? showShadowBehindNode;
  final BlendMode blendMode;

  const Effect({
    required this.type,
    this.visible = true,
    this.radius = 0,
    this.color,
    this.offsetX,
    this.offsetY,
    this.spread,
    this.showShadowBehindNode,
    this.blendMode = BlendMode.NORMAL,
  });

  factory Effect.dropShadow({
    required FigmaColor color,
    double offsetX = 0,
    double offsetY = 4,
    double radius = 4,
    double spread = 0,
  }) {
    return Effect(
      type: 'DROP_SHADOW',
      color: color,
      offsetX: offsetX,
      offsetY: offsetY,
      radius: radius,
      spread: spread,
    );
  }

  factory Effect.innerShadow({
    required FigmaColor color,
    double offsetX = 0,
    double offsetY = 4,
    double radius = 4,
  }) {
    return Effect(
      type: 'INNER_SHADOW',
      color: color,
      offsetX: offsetX,
      offsetY: offsetY,
      radius: radius,
    );
  }

  factory Effect.layerBlur(double radius) {
    return Effect(type: 'LAYER_BLUR', radius: radius);
  }

  factory Effect.backgroundBlur(double radius) {
    return Effect(type: 'BACKGROUND_BLUR', radius: radius);
  }
}

/// Constraints
class Constraints {
  final ConstraintType horizontal;
  final ConstraintType vertical;

  const Constraints({
    this.horizontal = ConstraintType.MIN,
    this.vertical = ConstraintType.MIN,
  });
}

/// Export setting
class ExportSetting {
  final String format;
  final String suffix;
  final double contstraintValue;
  final String constraintType;

  const ExportSetting({
    this.format = 'PNG',
    this.suffix = '',
    this.contstraintValue = 1,
    this.constraintType = 'SCALE',
  });
}

/// Reaction for prototyping
class Reaction {
  final String trigger;
  final String? action;
  final String? destinationId;
  final String? navigation;
  final String? transition;
  final double? duration;
  final String? easing;

  const Reaction({
    required this.trigger,
    this.action,
    this.destinationId,
    this.navigation,
    this.transition,
    this.duration,
    this.easing,
  });
}

/// Vector network for vector paths
class VectorNetwork {
  final List<VectorVertex> vertices;
  final List<VectorSegment> segments;
  final List<VectorRegion> regions;

  const VectorNetwork({
    this.vertices = const [],
    this.segments = const [],
    this.regions = const [],
  });
}

class VectorVertex {
  final double x;
  final double y;
  final double? strokeCap;
  final double? strokeJoin;
  final double? cornerRadius;
  final bool? handleMirroring;

  const VectorVertex({
    required this.x,
    required this.y,
    this.strokeCap,
    this.strokeJoin,
    this.cornerRadius,
    this.handleMirroring,
  });
}

class VectorSegment {
  final int start;
  final int end;
  final double? tangentStart;
  final double? tangentEnd;

  const VectorSegment({
    required this.start,
    required this.end,
    this.tangentStart,
    this.tangentEnd,
  });
}

class VectorRegion {
  final List<int> loops;
  final int windingRule;

  const VectorRegion({required this.loops, this.windingRule = 0});
}

/// Vector path (prefixed to avoid conflict with vector_editor.dart)
class PluginVectorPath {
  final String data;
  final int windingRule;

  const PluginVectorPath({required this.data, this.windingRule = 0});
}

/// Component property definition
class ComponentPropertyDefinition {
  final String type;
  final dynamic defaultValue;
  final List<String>? variantOptions;

  const ComponentPropertyDefinition({
    required this.type,
    this.defaultValue,
    this.variantOptions,
  });
}

/// Instance swap preferred value
class InstanceSwapPreferredValue {
  final String type;
  final String key;

  const InstanceSwapPreferredValue({required this.type, required this.key});
}

/// Styled text segment
class StyledTextSegment {
  final int start;
  final int end;
  final FontName? fontName;
  final double? fontSize;
  final TextDecoration? textDecoration;
  final TextCase? textCase;
  final double? lineHeight;
  final double? letterSpacing;
  final List<Paint>? fills;

  const StyledTextSegment({
    required this.start,
    required this.end,
    this.fontName,
    this.fontSize,
    this.textDecoration,
    this.textCase,
    this.lineHeight,
    this.letterSpacing,
    this.fills,
  });
}

/// Annotation (Dev Mode)
class Annotation {
  final String label;
  final List<AnnotationProperty> properties;

  const Annotation({required this.label, this.properties = const []});
}

class AnnotationProperty {
  final String type;
  final String? textValue;

  const AnnotationProperty({required this.type, this.textValue});
}

/// Measurement (Dev Mode)
class Measurement {
  final String id;
  final String start;
  final String end;
  final double offset;

  const Measurement({
    required this.id,
    required this.start,
    required this.end,
    this.offset = 0,
  });
}

/// Proxy for user info
class PluginUserProxy {
  final String id;
  final String name;
  final String? photoUrl;
  final String? color;
  final String? sessionId;

  const PluginUserProxy({
    required this.id,
    required this.name,
    this.photoUrl,
    this.color,
    this.sessionId,
  });
}

/// Proxy for styles
class PluginStyleProxy {
  final String id;
  String name;
  String? description;
  bool remote = false;
  String? key;
  String type = 'PAINT';
  List<Paint>? paints;
  List<Effect>? effects;
  FontName? fontName;
  double? fontSize;

  PluginStyleProxy({
    required this.id,
    required this.name,
    this.description,
  });

  void remove() {
    // Would remove style
  }
}

/// Proxy for variables
class PluginVariableProxy {
  final String id;
  String name;
  final String collectionId;
  final String resolvedType;
  String? description;
  bool? hiddenFromPublishing;
  Map<String, dynamic> valuesByMode = {};
  List<String> scopes = [];

  PluginVariableProxy({
    required this.id,
    required this.name,
    required this.collectionId,
    required this.resolvedType,
  });

  void setValueForMode(String modeId, dynamic value) {
    valuesByMode[modeId] = value;
  }
}

/// Proxy for variable collections
class PluginVariableCollectionProxy {
  final String id;
  String name;
  List<String> modes = ['Mode 1'];
  String defaultModeId = 'mode1';
  bool? hiddenFromPublishing;

  PluginVariableCollectionProxy({
    required this.id,
    required this.name,
  });

  String addMode(String name) {
    modes.add(name);
    return 'mode${modes.length}';
  }

  void removeMode(String modeId) {
    modes.removeWhere((m) => m == modeId);
  }
}

/// Plugin UI controller - Figma-compatible UI API
///
/// Provides methods for creating, managing, and communicating with plugin UI.
/// The UI renders in a modal iframe with isolated JavaScript execution.
class PluginUIController {
  bool _visible = false;
  double _width = 300;
  double _height = 400;
  double _x = 0;
  double _y = 0;
  String? _title;
  String? _html;
  String? _theme;

  /// Message event handlers
  final List<MessageEventHandler> _messageHandlers = [];
  final List<MessageEventHandler> _onceHandlers = [];

  /// Whether UI is visible
  bool get visible => _visible;

  /// Alias for visible (PRD 4.16.1.6)
  bool get isVisible => _visible;

  /// Current width
  double get width => _width;

  /// Current height
  double get height => _height;

  /// Current HTML content
  String? get html => _html;

  /// Direct message handler property (Figma API compatibility)
  MessageEventHandler? onmessage;

  /// Show plugin UI with html content (figma.showUI equivalent)
  void showUI(
    String htmlContent, {
    double? width,
    double? height,
    String? title,
    bool visible = true,
    String? theme,
    PluginPosition? position,
  }) {
    _html = htmlContent;
    _width = width ?? _width;
    _height = height ?? _height;
    _title = title;
    _visible = visible;
    _theme = theme;
    if (position != null) {
      _x = position.x;
      _y = position.y;
    }
    debugPrint('Plugin UI: show (${_width}x$_height)');
  }

  /// Show plugin UI (convenience method without html)
  /// Makes hidden UI visible or creates new UI
  void show({
    double? width,
    double? height,
    String? title,
    String? html,
  }) {
    if (html != null) _html = html;
    _width = width ?? _width;
    _height = height ?? _height;
    _title = title;
    _visible = true;
    debugPrint('Plugin UI: show (${_width}x$_height)');
  }

  /// Hide plugin UI (keeps running, can send/receive messages)
  void hide() {
    _visible = false;
    debugPrint('Plugin UI: hide');
  }

  /// Resize plugin UI dynamically
  /// Width minimum: 70, Height minimum: 0
  void resize(double width, double height) {
    _width = width < 70 ? 70 : width;
    _height = height < 0 ? 0 : height;
    debugPrint('Plugin UI: resize to ${_width}x$_height');
  }

  /// Close and destroy plugin UI
  /// Stops all code execution and message handling
  void close() {
    _visible = false;
    _html = null;
    _messageHandlers.clear();
    _onceHandlers.clear();
    onmessage = null;
    debugPrint('Plugin UI: close');
  }

  /// Reposition UI window
  void reposition(double x, double y) {
    _x = x;
    _y = y;
    debugPrint('Plugin UI: reposition to ($x, $y)');
  }

  /// Get current UI position
  /// Returns position in window and canvas coordinates
  /// Throws if no UI exists
  UIPosition getPosition() {
    if (_html == null) {
      throw PluginUIError('No UI exists. Call showUI first.');
    }
    return UIPosition(
      windowSpace: Vector2(_x, _y),
      canvasSpace: Vector2(_x, _y), // Would transform to canvas coords
    );
  }

  /// Post message to UI (plugin -> UI communication)
  ///
  /// [pluginMessage] can be any serializable data
  /// [options] allows setting origin for cross-origin restrictions
  void postMessage(dynamic pluginMessage, {UIPostMessageOptions? options}) {
    debugPrint('Plugin UI: postMessage');
    final event = MessageEvent(
      pluginMessage: pluginMessage,
      origin: options?.origin ?? '*',
    );
    // In real implementation, this would send to iframe
    // For testing, we call the reverse handler
  }

  /// Register message event handler (UI -> plugin)
  void on(String type, MessageEventHandler callback) {
    if (type == 'message') {
      _messageHandlers.add(callback);
    }
  }

  /// Register one-time message handler (auto-removes after first call)
  void once(String type, MessageEventHandler callback) {
    if (type == 'message') {
      _onceHandlers.add(callback);
    }
  }

  /// Remove message event handler
  void off(String type, MessageEventHandler callback) {
    if (type == 'message') {
      _messageHandlers.remove(callback);
      _onceHandlers.remove(callback);
    }
  }

  /// Simulate receiving a message from UI (for testing)
  void receiveMessage(dynamic pluginMessage, {String origin = '*'}) {
    final event = MessageEvent(pluginMessage: pluginMessage, origin: origin);

    // Call direct handler
    onmessage?.call(pluginMessage, OnMessageProperties(origin: origin));

    // Call registered handlers
    for (final handler in _messageHandlers) {
      handler(pluginMessage, OnMessageProperties(origin: origin));
    }

    // Call and remove once handlers
    for (final handler in List.from(_onceHandlers)) {
      handler(pluginMessage, OnMessageProperties(origin: origin));
      _onceHandlers.remove(handler);
    }
  }
}

/// Message event handler type
typedef MessageEventHandler = void Function(dynamic pluginMessage, OnMessageProperties props);

/// Properties passed to message handlers
class OnMessageProperties {
  final String origin;

  const OnMessageProperties({this.origin = '*'});
}

/// Message event data
class MessageEvent {
  final dynamic pluginMessage;
  final String origin;

  const MessageEvent({required this.pluginMessage, this.origin = '*'});
}

/// UI position data
class UIPosition {
  final Vector2 windowSpace;
  final Vector2 canvasSpace;

  const UIPosition({required this.windowSpace, required this.canvasSpace});
}

/// Options for postMessage
class UIPostMessageOptions {
  /// Origin restriction (default '*' allows all)
  final String origin;

  const UIPostMessageOptions({this.origin = '*'});
}

/// Plugin UI error
class PluginUIError implements Exception {
  final String message;

  PluginUIError(this.message);

  @override
  String toString() => 'PluginUIError: $message';
}

/// Viewport control
class PluginViewportProxy {
  double zoom = 1;
  Vector2 center = Vector2(0, 0);
  FigmaRect bounds = const FigmaRect(x: 0, y: 0, width: 1920, height: 1080);

  void scrollAndZoomIntoView(List<PluginNodeProxy> nodes) {
    if (nodes.isEmpty) return;
    // Would calculate bounds and zoom to fit
  }
}

/// 2D vector
class Vector2 {
  final double x;
  final double y;

  const Vector2(this.x, this.y);
}

/// Position for UI
class PluginPosition {
  final double x;
  final double y;

  const PluginPosition(this.x, this.y);
}

/// Payments proxy
class PluginPaymentsProxy {
  PluginPaymentStatus status = const PluginPaymentStatus();

  Future<PluginPaymentStatus> getUserFirstRanSecondsAgoAsync() async {
    return status;
  }

  Future<void> initiateCheckoutAsync(Map<String, dynamic> options) async {
    // Would initiate checkout
  }

  Future<Map<String, dynamic>> getPluginPaymentTokenAsync() async {
    return {};
  }

  void setPaymentStatusInDevelopment(PluginPaymentStatus newStatus) {
    status = newStatus;
  }
}

/// Payment status
class PluginPaymentStatus {
  final String type;

  const PluginPaymentStatus({this.type = 'UNPAID'});
}

/// Team library proxy
class PluginTeamLibraryProxy {
  Future<List<PluginStyleProxy>> getAvailableStylesAsync() async {
    return [];
  }

  Future<List<ComponentSummary>> getAvailableComponentsAsync() async {
    return [];
  }
}

/// Component summary from team library
class ComponentSummary {
  final String key;
  final String name;
  final String? description;

  const ComponentSummary({
    required this.key,
    required this.name,
    this.description,
  });
}

/// Timer proxy
class PluginTimerProxy {
  final Map<int, Timer> _timers = {};
  int _nextId = 1;

  int setTimeout(VoidCallback callback, int milliseconds) {
    final id = _nextId++;
    _timers[id] = Timer(Duration(milliseconds: milliseconds), () {
      callback();
      _timers.remove(id);
    });
    return id;
  }

  void clearTimeout(int id) {
    _timers[id]?.cancel();
    _timers.remove(id);
  }

  int setInterval(VoidCallback callback, int milliseconds) {
    final id = _nextId++;
    _timers[id] = Timer.periodic(Duration(milliseconds: milliseconds), (_) {
      callback();
    });
    return id;
  }

  void clearInterval(int id) {
    _timers[id]?.cancel();
    _timers.remove(id);
  }
}

/// Client storage API
class PluginClientStorage {
  final Map<String, dynamic> _storage = {};

  Future<dynamic> getAsync(String key) async {
    return _storage[key];
  }

  Future<void> setAsync(String key, dynamic value) async {
    _storage[key] = value;
  }

  Future<void> deleteAsync(String key) async {
    _storage.remove(key);
  }

  Future<List<String>> keysAsync() async {
    return _storage.keys.toList();
  }
}

/// Variables API (PRD 4.16.1.6)
class PluginVariablesAPI {
  final List<PluginVariableProxy> _variables = [];
  final List<PluginVariableCollectionProxy> _collections = [];

  /// Create a new variable
  PluginVariableProxy createVariable(String name, String resolvedType, {String? collectionId}) {
    final variable = PluginVariableProxy(
      id: 'var_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      collectionId: collectionId ?? '',
      resolvedType: resolvedType,
    );
    _variables.add(variable);
    return variable;
  }

  /// Create a variable collection
  PluginVariableCollectionProxy createVariableCollection(String name) {
    final collection = PluginVariableCollectionProxy(
      id: 'coll_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
    _collections.add(collection);
    return collection;
  }

  /// Get local variables
  List<PluginVariableProxy> getLocalVariables() => List.unmodifiable(_variables);

  /// Get local variable collections
  List<PluginVariableCollectionProxy> getLocalVariableCollections() => List.unmodifiable(_collections);

  /// Get variable by ID async
  Future<PluginVariableProxy?> getVariableByIdAsync(String id) async {
    for (final v in _variables) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Get variable collection by ID async
  Future<PluginVariableCollectionProxy?> getVariableCollectionByIdAsync(String id) async {
    for (final c in _collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Import variable by key (PRD 4.16.6.1)
  Future<PluginVariableProxy?> importVariableByKeyAsync(String key) async {
    // Would import from team library
    return null;
  }
}

/// Util API helpers (PRD 4.16.1.6)
class PluginUtilAPI {
  /// Create solid paint
  Map<String, dynamic> solidPaint(String hex, {double opacity = 1}) {
    return {
      'type': 'SOLID',
      'color': _hexToRgb(hex),
      'opacity': opacity,
    };
  }

  /// Create gradient paint
  Map<String, dynamic> gradientPaint(
    String type,
    List<Map<String, dynamic>> gradientStops, {
    List<List<num>>? gradientTransform,
  }) {
    return {
      'type': type,
      'gradientStops': gradientStops,
      if (gradientTransform != null) 'gradientTransform': gradientTransform,
    };
  }

  /// RGB helper
  Map<String, double> rgb(double r, double g, double b) {
    return {'r': r, 'g': g, 'b': b};
  }

  /// RGBA helper
  Map<String, double> rgba(double r, double g, double b, double a) {
    return {'r': r, 'g': g, 'b': b, 'a': a};
  }

  Map<String, double> _hexToRgb(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
      final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
      final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
      return {'r': r, 'g': g, 'b': b};
    }
    return {'r': 0, 'g': 0, 'b': 0};
  }
}

/// Constants API (PRD 4.16.1.6)
class PluginConstantsAPI {
  /// Mixed symbol for properties with multiple values
  static const mixed = _MixedSymbol();

  /// Node types
  static const nodeTypes = <String>[
    'DOCUMENT', 'CANVAS', 'PAGE', 'SLICE', 'FRAME', 'GROUP', 'COMPONENT',
    'COMPONENT_SET', 'VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'LINE', 'ELLIPSE',
    'POLYGON', 'RECTANGLE', 'TEXT', 'STICKY', 'CONNECTOR', 'SHAPE_WITH_TEXT',
    'CODE_BLOCK', 'SECTION', 'TABLE', 'TABLE_CELL', 'EMBED', 'LINK_UNFURL',
    'MEDIA', 'INSTANCE', 'WIDGET', 'SLIDE', 'SLIDE_ROW',
  ];

  /// Blend modes
  static const blendModes = <String>[
    'PASS_THROUGH', 'NORMAL', 'DARKEN', 'MULTIPLY', 'LINEAR_BURN', 'COLOR_BURN',
    'LIGHTEN', 'SCREEN', 'LINEAR_DODGE', 'COLOR_DODGE', 'OVERLAY', 'SOFT_LIGHT',
    'HARD_LIGHT', 'DIFFERENCE', 'EXCLUSION', 'HUE', 'SATURATION', 'COLOR', 'LUMINOSITY',
  ];

  /// Effect types
  static const effectTypes = <String>[
    'DROP_SHADOW', 'INNER_SHADOW', 'LAYER_BLUR', 'BACKGROUND_BLUR',
  ];

  /// Constraint types
  static const constraintTypes = <String>[
    'MIN', 'CENTER', 'MAX', 'STRETCH', 'SCALE',
  ];
}

/// Notification handler
class NotificationHandler {
  final VoidCallback cancel;

  const NotificationHandler({required this.cancel});
}

/// Parameter values from quick actions
class ParameterValues {
  final Map<String, dynamic> _values;

  ParameterValues(this._values);

  dynamic operator [](String key) => _values[key];

  Map<String, dynamic> toMap() => Map.unmodifiable(_values);
}

/// Image proxy
class PluginImageProxy {
  final String hash;
  final List<int>? bytes;

  const PluginImageProxy({required this.hash, this.bytes});

  Future<List<int>> getBytesAsync() async {
    return bytes ?? [];
  }

  Future<FigmaSize> getSizeAsync() async {
    return const FigmaSize(0, 0);
  }
}

/// Figma Size (to avoid conflict with dart:ui Size)
class FigmaSize {
  final double width;
  final double height;

  const FigmaSize(this.width, this.height);
}

/// Document change event
class DocumentChangeEvent {
  final List<DocumentChange> documentChanges;

  const DocumentChangeEvent({required this.documentChanges});
}

/// Document change
class DocumentChange {
  final String type;
  final String? id;
  final Map<String, dynamic>? origin;

  const DocumentChange({required this.type, this.id, this.origin});
}

/// Run event
class RunEvent {
  final String? command;
  final ParameterValues? parameters;

  const RunEvent({this.command, this.parameters});
}

/// Drop event
class DropEvent {
  final List<DropItem> items;
  final String? node;
  final double dropOffsetX;
  final double dropOffsetY;

  const DropEvent({
    required this.items,
    this.node,
    this.dropOffsetX = 0,
    this.dropOffsetY = 0,
  });
}

/// Drop item
class DropItem {
  final String type;
  final dynamic data;

  const DropItem({required this.type, this.data});
}

/// Permission error
class PluginPermissionError implements Exception {
  final String message;

  PluginPermissionError(this.message);

  @override
  String toString() => 'PluginPermissionError: $message';
}

/// Network access error (thrown when accessing blocked domains)
class PluginNetworkError implements Exception {
  final String message;
  final String? url;
  final NetworkDenyReason? reason;

  PluginNetworkError(this.message, {this.url, this.reason});

  @override
  String toString() {
    final parts = <String>['PluginNetworkError: $message'];
    if (url != null) parts.add('url: $url');
    if (reason != null) parts.add('reason: ${reason!.name}');
    return parts.join(' | ');
  }
}

/// Response from a plugin fetch request
class PluginFetchResponse {
  /// HTTP status code
  final int status;

  /// Whether the request was successful (status 200-299)
  final bool ok;

  /// Response headers
  final Map<String, String> headers;

  /// Response body as string
  final String body;

  const PluginFetchResponse({
    required this.status,
    required this.ok,
    required this.headers,
    required this.body,
  });

  /// Get header value (case-insensitive)
  String? header(String name) {
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }

  /// Parse body as JSON
  dynamic json() {
    // In real implementation, would use dart:convert
    return body;
  }

  /// Get body as text
  String text() => body;
}

/// Type error for invalid operations
class PluginTypeError implements Exception {
  final String message;
  final String? expectedType;
  final String? actualType;

  PluginTypeError(this.message, {this.expectedType, this.actualType});

  @override
  String toString() {
    var s = 'PluginTypeError: $message';
    if (expectedType != null) s += ' (expected: $expectedType';
    if (actualType != null) s += ', got: $actualType';
    if (expectedType != null) s += ')';
    return s;
  }
}

/// Node operation error
class PluginNodeError implements Exception {
  final String message;
  final String? nodeId;

  PluginNodeError(this.message, {this.nodeId});

  @override
  String toString() => 'PluginNodeError: $message${nodeId != null ? " (node: $nodeId)" : ""}';
}

/// Invalid manifest error
class PluginManifestError implements Exception {
  final String message;
  final List<String> errors;

  PluginManifestError(this.message, {this.errors = const []});

  @override
  String toString() {
    if (errors.isEmpty) return 'PluginManifestError: $message';
    return 'PluginManifestError: $message\n  - ${errors.join("\n  - ")}';
  }
}

/// Bound variable reference
class BoundVariable {
  final String variableId;
  final String? modeId;

  const BoundVariable({required this.variableId, this.modeId});

  Map<String, dynamic> toJson() => {
        'variableId': variableId,
        if (modeId != null) 'modeId': modeId,
      };
}

/// Color utilities
class PluginColorUtils {
  /// Convert hex to RGB (0-1 range)
  static FigmaColor hexToRgb(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
    final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
    final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
    return FigmaColor(r: r, g: g, b: b);
  }

  /// Convert RGB (0-1 range) to hex
  static String rgbToHex(double r, double g, double b) {
    final rHex = (r * 255).round().toRadixString(16).padLeft(2, '0');
    final gHex = (g * 255).round().toRadixString(16).padLeft(2, '0');
    final bHex = (b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$rHex$gHex$bHex'.toUpperCase();
  }

  /// Convert RGB to HSL
  static Map<String, double> rgbToHsl(double r, double g, double b) {
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    final l = (max + min) / 2;

    if (max == min) {
      return {'h': 0, 's': 0, 'l': l};
    }

    final d = max - min;
    final s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

    double h;
    if (max == r) {
      h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    } else if (max == g) {
      h = ((b - r) / d + 2) / 6;
    } else {
      h = ((r - g) / d + 4) / 6;
    }

    return {'h': h, 's': s, 'l': l};
  }

  /// Convert HSL to RGB
  static FigmaColor hslToRgb(double h, double s, double l) {
    if (s == 0) {
      return FigmaColor(r: l, g: l, b: l);
    }

    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    return FigmaColor(
      r: hue2rgb(p, q, h + 1 / 3),
      g: hue2rgb(p, q, h),
      b: hue2rgb(p, q, h - 1 / 3),
    );
  }
}
