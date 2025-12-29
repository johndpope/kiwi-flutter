/// Plugin API - Figma-compatible API exposed to plugins
///
/// Provides the `figma` global object with methods for:
/// - Node creation and manipulation
/// - Document access
/// - UI communication
/// - User information
/// - File/page operations

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'plugin_manifest.dart';

/// Figma API exposed to plugins
class FigmaPluginAPI {
  /// Current document
  final PluginDocumentProxy? currentPage;

  /// Root node of the document
  final PluginNodeProxy? root;

  /// Current user info
  final PluginUserProxy? currentUser;

  /// Plugin command being executed
  String? command;

  /// Plugin parameters
  Map<String, dynamic>? parameters;

  /// UI controller
  final PluginUIController ui;

  /// Mixed value constant
  static const mixed = _MixedSymbol();

  /// Viewport control
  final PluginViewportProxy viewport;

  /// Notify handlers
  final _closeHandlers = <VoidCallback>[];
  final _selectionChangeHandlers = <VoidCallback>[];
  final _documentChangeHandlers = <VoidCallback>[];

  FigmaPluginAPI({
    this.currentPage,
    this.root,
    this.currentUser,
    required this.ui,
    required this.viewport,
  });

  /// Create a new rectangle node
  PluginNodeProxy createRectangle() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'RECTANGLE',
      name: 'Rectangle',
    );
  }

  /// Create a new frame node
  PluginNodeProxy createFrame() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'FRAME',
      name: 'Frame',
    );
  }

  /// Create a new text node
  PluginNodeProxy createText() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'TEXT',
      name: 'Text',
    );
  }

  /// Create a new ellipse node
  PluginNodeProxy createEllipse() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'ELLIPSE',
      name: 'Ellipse',
    );
  }

  /// Create a new line node
  PluginNodeProxy createLine() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'LINE',
      name: 'Line',
    );
  }

  /// Create a new polygon node
  PluginNodeProxy createPolygon() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'POLYGON',
      name: 'Polygon',
    );
  }

  /// Create a new star node
  PluginNodeProxy createStar() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'STAR',
      name: 'Star',
    );
  }

  /// Create a new vector node
  PluginNodeProxy createVector() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'VECTOR',
      name: 'Vector',
    );
  }

  /// Create a new boolean operation node
  PluginNodeProxy createBooleanOperation() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'BOOLEAN_OPERATION',
      name: 'Boolean',
    );
  }

  /// Create a component from selection
  PluginNodeProxy createComponent() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'COMPONENT',
      name: 'Component',
    );
  }

  /// Create a component set
  PluginNodeProxy createComponentSet() {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'COMPONENT_SET',
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
      type: 'SLICE',
      name: 'Slice',
    );
  }

  /// Get node by ID
  PluginNodeProxy? getNodeById(String id) {
    // Would be implemented with actual document tree
    return null;
  }

  /// Get style by ID
  PluginStyleProxy? getStyleById(String id) {
    return null;
  }

  /// Get current selection
  List<PluginNodeProxy> get selection => [];

  /// Set current selection
  set selection(List<PluginNodeProxy> nodes) {
    // Would update selection
  }

  /// Close plugin UI
  void closePlugin([String? message]) {
    for (final handler in _closeHandlers) {
      handler();
    }
    if (message != null) {
      debugPrint('Plugin closed: $message');
    }
  }

  /// Show notification
  void notify(String message, {Duration? timeout, bool error = false}) {
    debugPrint('Plugin notification: $message');
  }

  /// Register close handler
  void on(String event, Function handler) {
    switch (event) {
      case 'close':
        _closeHandlers.add(handler as VoidCallback);
        break;
      case 'selectionchange':
        _selectionChangeHandlers.add(handler as VoidCallback);
        break;
      case 'documentchange':
        _documentChangeHandlers.add(handler as VoidCallback);
        break;
    }
  }

  /// Unregister handler
  void off(String event, Function handler) {
    switch (event) {
      case 'close':
        _closeHandlers.remove(handler);
        break;
      case 'selectionchange':
        _selectionChangeHandlers.remove(handler);
        break;
      case 'documentchange':
        _documentChangeHandlers.remove(handler);
        break;
    }
  }

  /// Trigger selection change
  void triggerSelectionChange() {
    for (final handler in _selectionChangeHandlers) {
      handler();
    }
  }

  /// Trigger document change
  void triggerDocumentChange() {
    for (final handler in _documentChangeHandlers) {
      handler();
    }
  }

  /// Commit undo group
  void commitUndo() {
    // Would commit undo
  }

  /// Group nodes
  PluginNodeProxy group(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'GROUP',
      name: 'Group',
    );
  }

  /// Flatten nodes
  PluginNodeProxy flatten(List<PluginNodeProxy> nodes) {
    return PluginNodeProxy(
      id: _generateId(),
      type: 'VECTOR',
      name: 'Vector',
    );
  }

  /// Boolean union
  PluginNodeProxy union(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = 'UNION';
    return node;
  }

  /// Boolean subtract
  PluginNodeProxy subtract(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = 'SUBTRACT';
    return node;
  }

  /// Boolean intersect
  PluginNodeProxy intersect(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = 'INTERSECT';
    return node;
  }

  /// Boolean exclude
  PluginNodeProxy exclude(
    List<PluginNodeProxy> nodes,
    PluginNodeProxy parent, [
    int? index,
  ]) {
    final node = createBooleanOperation();
    node.booleanOperation = 'EXCLUDE';
    return node;
  }

  /// Load font
  Future<void> loadFontAsync(FontName font) async {
    // Would load font
  }

  /// Get local styles
  List<PluginStyleProxy> getLocalPaintStyles() => [];
  List<PluginStyleProxy> getLocalTextStyles() => [];
  List<PluginStyleProxy> getLocalEffectStyles() => [];
  List<PluginStyleProxy> getLocalGridStyles() => [];

  /// Create styles
  PluginStyleProxy createPaintStyle() {
    return PluginStyleProxy(id: _generateId(), name: 'Paint Style');
  }

  PluginStyleProxy createTextStyle() {
    return PluginStyleProxy(id: _generateId(), name: 'Text Style');
  }

  PluginStyleProxy createEffectStyle() {
    return PluginStyleProxy(id: _generateId(), name: 'Effect Style');
  }

  PluginStyleProxy createGridStyle() {
    return PluginStyleProxy(id: _generateId(), name: 'Grid Style');
  }

  /// Get shared plugin data keys
  List<String> getSharedPluginDataKeys(String namespace) => [];

  /// Client storage API
  final clientStorage = PluginClientStorage();

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }
}

/// Symbol for mixed values
class _MixedSymbol {
  const _MixedSymbol();
}

/// Proxy for document/page
class PluginDocumentProxy {
  final String id;
  String name;
  final List<PluginNodeProxy> children = [];

  PluginDocumentProxy({
    required this.id,
    required this.name,
  });

  void appendChild(PluginNodeProxy node) {
    children.add(node);
  }

  void insertChild(int index, PluginNodeProxy node) {
    children.insert(index, node);
  }

  PluginNodeProxy? findChild(bool Function(PluginNodeProxy) callback) {
    for (final child in children) {
      if (callback(child)) return child;
    }
    return null;
  }

  List<PluginNodeProxy> findAll(bool Function(PluginNodeProxy) callback) {
    return children.where(callback).toList();
  }
}

/// Proxy for a node in the document
class PluginNodeProxy {
  final String id;
  String type;
  String name;
  PluginNodeProxy? parent;
  final List<PluginNodeProxy> children = [];

  // Transform
  double x = 0;
  double y = 0;
  double width = 100;
  double height = 100;
  double rotation = 0;

  // Appearance
  List<Map<String, dynamic>> fills = [];
  List<Map<String, dynamic>> strokes = [];
  List<Map<String, dynamic>> effects = [];
  double opacity = 1;
  String blendMode = 'NORMAL';
  bool visible = true;
  bool locked = false;

  // Corner radius
  double cornerRadius = 0;
  List<double>? rectangleCornerRadii;

  // Stroke
  double strokeWeight = 1;
  String strokeAlign = 'CENTER';
  String strokeCap = 'NONE';
  String strokeJoin = 'MITER';
  List<double>? dashPattern;

  // Text
  String characters = '';
  double fontSize = 14;
  FontName? fontName;
  String textAlignHorizontal = 'LEFT';
  String textAlignVertical = 'TOP';

  // Layout
  String? layoutMode;
  double itemSpacing = 0;
  double paddingLeft = 0;
  double paddingRight = 0;
  double paddingTop = 0;
  double paddingBottom = 0;
  String layoutAlign = 'INHERIT';
  String layoutGrow = 'FIXED';

  // Component
  PluginNodeProxy? mainComponent;
  String? booleanOperation;

  // Constraints
  String constraintsHorizontal = 'MIN';
  String constraintsVertical = 'MIN';

  // Plugin data
  final Map<String, Map<String, String>> _pluginData = {};
  final Map<String, Map<String, String>> _sharedPluginData = {};

  // Relaunch data
  final Map<String, String> _relaunchData = {};

  PluginNodeProxy({
    required this.id,
    required this.type,
    required this.name,
  });

  /// Clone this node
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
    return clone;
  }

  /// Remove this node
  void remove() {
    parent?.children.remove(this);
    parent = null;
  }

  /// Get absolute position
  Map<String, double> get absoluteTransform {
    double absX = x;
    double absY = y;
    var p = parent;
    while (p != null) {
      absX += p.x;
      absY += p.y;
      p = p.parent;
    }
    return {'x': absX, 'y': absY};
  }

  /// Get bounding box
  Map<String, double> get absoluteBoundingBox {
    final transform = absoluteTransform;
    return {
      'x': transform['x']!,
      'y': transform['y']!,
      'width': width,
      'height': height,
    };
  }

  /// Resize node
  void resize(double w, double h) {
    width = w;
    height = h;
  }

  /// Rescale node
  void rescale(double scale) {
    width *= scale;
    height *= scale;
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

  /// Set relaunch data
  void setRelaunchData(Map<String, String> data) {
    _relaunchData.clear();
    _relaunchData.addAll(data);
  }

  /// Get relaunch data
  Map<String, String> get relaunchData => Map.from(_relaunchData);

  // Child operations
  void appendChild(PluginNodeProxy node) {
    node.parent?.children.remove(node);
    node.parent = this;
    children.add(node);
  }

  void insertChild(int index, PluginNodeProxy node) {
    node.parent?.children.remove(node);
    node.parent = this;
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
}

/// Font name structure
class FontName {
  final String family;
  final String style;

  const FontName({required this.family, required this.style});
}

/// Proxy for user info
class PluginUserProxy {
  final String id;
  final String name;
  final String? photoUrl;
  final String? color;

  const PluginUserProxy({
    required this.id,
    required this.name,
    this.photoUrl,
    this.color,
  });
}

/// Proxy for styles
class PluginStyleProxy {
  final String id;
  String name;
  String? description;
  bool remote = false;

  PluginStyleProxy({
    required this.id,
    required this.name,
    this.description,
  });

  void remove() {
    // Would remove style
  }
}

/// Plugin UI controller
class PluginUIController {
  /// Show plugin UI
  void show(
    String htmlContent, {
    double? width,
    double? height,
    String? title,
    bool visible = true,
  }) {
    // Would show UI in webview
    debugPrint('Plugin UI: show');
  }

  /// Hide plugin UI
  void hide() {
    debugPrint('Plugin UI: hide');
  }

  /// Resize plugin UI
  void resize(double width, double height) {
    debugPrint('Plugin UI: resize to ${width}x$height');
  }

  /// Close plugin UI
  void close() {
    debugPrint('Plugin UI: close');
  }

  /// Post message to UI
  void postMessage(dynamic message) {
    debugPrint('Plugin UI: postMessage');
  }

  /// Message handler
  void Function(dynamic)? onmessage;
}

/// Viewport control
class PluginViewportProxy {
  double zoom = 1;
  Map<String, double> center = {'x': 0, 'y': 0};
  Map<String, double> bounds = {'x': 0, 'y': 0, 'width': 1920, 'height': 1080};

  void scrollAndZoomIntoView(List<PluginNodeProxy> nodes) {
    // Would scroll viewport
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

/// Color utilities
class PluginColorUtils {
  /// Convert hex to RGB
  static Map<String, double> hexToRgb(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
    final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
    final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
    return {'r': r, 'g': g, 'b': b};
  }

  /// Convert RGB to hex
  static String rgbToHex(double r, double g, double b) {
    final rHex = (r * 255).round().toRadixString(16).padLeft(2, '0');
    final gHex = (g * 255).round().toRadixString(16).padLeft(2, '0');
    final bHex = (b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$rHex$gHex$bHex'.toUpperCase();
  }
}
