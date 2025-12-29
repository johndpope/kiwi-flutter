/// Central document state container for the Figma editor
///
/// Manages:
/// - Document data (nodes, pages, components)
/// - Selection state
/// - Undo/redo history
/// - View state (zoom, pan, active page)
/// - Clipboard
///
/// Uses Provider for state management and notifies listeners on changes.

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'selection.dart';
import 'undo_stack.dart';
import 'command.dart';

/// Snapshot of the entire document state for undo/redo
class DocumentSnapshot {
  final Map<String, Map<String, dynamic>> nodeData;
  final SelectionSnapshot selection;

  const DocumentSnapshot({
    required this.nodeData,
    required this.selection,
  });

  /// Deep copy of node data
  static Map<String, Map<String, dynamic>> deepCopyNodes(
    Map<String, Map<String, dynamic>> nodes,
  ) {
    return nodes.map((key, value) => MapEntry(key, _deepCopyMap(value)));
  }

  /// Recursively deep copy a map
  static Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
    return source.map((key, value) {
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _deepCopyMap(value));
      } else if (value is Map) {
        return MapEntry(key, Map<String, dynamic>.from(value.map((k, v) {
          if (v is Map) {
            return MapEntry(k.toString(), _deepCopyMap(Map<String, dynamic>.from(v)));
          }
          return MapEntry(k.toString(), v);
        })));
      } else if (value is List) {
        return MapEntry(key, _deepCopyList(value));
      }
      return MapEntry(key, value);
    });
  }

  /// Recursively deep copy a list
  static List<dynamic> _deepCopyList(List<dynamic> source) {
    return source.map((item) {
      if (item is Map<String, dynamic>) {
        return _deepCopyMap(item);
      } else if (item is Map) {
        return _deepCopyMap(Map<String, dynamic>.from(item));
      } else if (item is List) {
        return _deepCopyList(item);
      }
      return item;
    }).toList();
  }
}

/// View state for the canvas
class ViewState extends ChangeNotifier {
  double _zoom = 1.0;
  Offset _panOffset = Offset.zero;
  String? _activePageId;
  bool _showRulers = true;
  bool _showGrid = false;
  bool _snapToGrid = true;
  bool _snapToObjects = true;
  double _gridSize = 8.0;

  // Getters
  double get zoom => _zoom;
  Offset get panOffset => _panOffset;
  String? get activePageId => _activePageId;
  bool get showRulers => _showRulers;
  bool get showGrid => _showGrid;
  bool get snapToGrid => _snapToGrid;
  bool get snapToObjects => _snapToObjects;
  double get gridSize => _gridSize;

  void setZoom(double value, {Offset? focalPoint}) {
    final clampedZoom = value.clamp(0.01, 256.0);
    if (_zoom != clampedZoom) {
      // If focal point provided, adjust pan to keep that point stationary
      if (focalPoint != null) {
        final zoomDelta = clampedZoom / _zoom;
        _panOffset = focalPoint - (focalPoint - _panOffset) * zoomDelta;
      }
      _zoom = clampedZoom;
      notifyListeners();
    }
  }

  void setPanOffset(Offset offset) {
    if (_panOffset != offset) {
      _panOffset = offset;
      notifyListeners();
    }
  }

  void setActivePageId(String? pageId) {
    if (_activePageId != pageId) {
      _activePageId = pageId;
      notifyListeners();
    }
  }

  void toggleRulers() {
    _showRulers = !_showRulers;
    notifyListeners();
  }

  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  void setSnapToGrid(bool value) {
    if (_snapToGrid != value) {
      _snapToGrid = value;
      notifyListeners();
    }
  }

  void setSnapToObjects(bool value) {
    if (_snapToObjects != value) {
      _snapToObjects = value;
      notifyListeners();
    }
  }

  void setGridSize(double size) {
    if (_gridSize != size) {
      _gridSize = size;
      notifyListeners();
    }
  }

  /// Zoom to fit content in viewport
  void zoomToFit(Rect contentBounds, Size viewportSize) {
    if (contentBounds.isEmpty || viewportSize.isEmpty) return;

    final scaleX = viewportSize.width / contentBounds.width;
    final scaleY = viewportSize.height / contentBounds.height;
    final newZoom = (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% to add padding

    final contentCenter = contentBounds.center;
    final viewportCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);

    _zoom = newZoom.clamp(0.01, 256.0);
    _panOffset = viewportCenter - contentCenter * _zoom;
    notifyListeners();
  }

  /// Reset to 100% zoom centered
  void resetView() {
    _zoom = 1.0;
    _panOffset = Offset.zero;
    notifyListeners();
  }
}

/// Clipboard state
class ClipboardState {
  List<Map<String, dynamic>> copiedNodes = [];
  Offset? copyOrigin;

  bool get hasContent => copiedNodes.isNotEmpty;

  void copy(List<Map<String, dynamic>> nodes, Offset origin) {
    copiedNodes = nodes.map((n) => Map<String, dynamic>.from(n)).toList();
    copyOrigin = origin;
  }

  void clear() {
    copiedNodes.clear();
    copyOrigin = null;
  }
}

/// Main document state container
class DocumentState extends ChangeNotifier {
  /// The underlying document data
  Map<String, Map<String, dynamic>> _nodeMap = {};

  /// Root node IDs (pages/canvases)
  List<String> _rootNodeIds = [];

  /// Document metadata
  String _documentName = 'Untitled';
  String? _documentId;

  /// Selection state
  final Selection selection = Selection();

  /// Undo/redo history
  final UndoStack<DocumentSnapshot> undoStack = UndoStack<DocumentSnapshot>(maxHistory: 50);

  /// View state
  final ViewState viewState = ViewState();

  /// Clipboard
  final ClipboardState clipboard = ClipboardState();

  /// Currently active tool
  EditorTool _activeTool = EditorTool.select;

  /// Whether document has unsaved changes
  bool _isDirty = false;

  // Getters
  Map<String, Map<String, dynamic>> get nodeMap => Map.unmodifiable(_nodeMap);
  List<String> get rootNodeIds => List.unmodifiable(_rootNodeIds);
  String get documentName => _documentName;
  String? get documentId => _documentId;
  EditorTool get activeTool => _activeTool;
  bool get isDirty => _isDirty;
  bool get canUndo => undoStack.canUndo;
  bool get canRedo => undoStack.canRedo;

  DocumentState() {
    // Listen to child notifiers
    selection.addListener(_onSelectionChanged);
    viewState.addListener(_onViewStateChanged);
    undoStack.addListener(_onUndoStackChanged);
  }

  @override
  void dispose() {
    selection.removeListener(_onSelectionChanged);
    viewState.removeListener(_onViewStateChanged);
    undoStack.removeListener(_onUndoStackChanged);
    selection.dispose();
    viewState.dispose();
    undoStack.dispose();
    super.dispose();
  }

  void _onSelectionChanged() => notifyListeners();
  void _onViewStateChanged() => notifyListeners();
  void _onUndoStackChanged() => notifyListeners();

  /// Load document from parsed data
  void loadDocument({
    required Map<String, Map<String, dynamic>> nodeMap,
    required List<String> rootNodeIds,
    String? documentName,
    String? documentId,
  }) {
    _nodeMap = nodeMap;
    _rootNodeIds = rootNodeIds;
    _documentName = documentName ?? 'Untitled';
    _documentId = documentId;
    _isDirty = false;

    selection.deselectAll();
    undoStack.clear();

    // Set first page as active
    if (_rootNodeIds.isNotEmpty) {
      viewState.setActivePageId(_rootNodeIds.first);
    }

    notifyListeners();
  }

  /// Get a node by ID
  Map<String, dynamic>? getNode(String nodeId) {
    return _nodeMap[nodeId];
  }

  /// Get children of a node
  List<String> getChildrenIds(String nodeId) {
    final node = _nodeMap[nodeId];
    if (node == null) return [];

    final children = node['children'] as List<dynamic>?;
    if (children == null) return [];

    return children.cast<String>();
  }

  /// Get parent ID of a node
  String? getParentId(String nodeId) {
    final node = _nodeMap[nodeId];
    return node?['parentId'] as String?;
  }

  /// Set active tool
  void setActiveTool(EditorTool tool) {
    if (_activeTool != tool) {
      _activeTool = tool;
      notifyListeners();
    }
  }

  /// Create a snapshot for undo
  DocumentSnapshot createSnapshot() {
    return DocumentSnapshot(
      nodeData: DocumentSnapshot.deepCopyNodes(_nodeMap),
      selection: selection.snapshot(),
    );
  }

  /// Restore from a snapshot
  void restoreSnapshot(DocumentSnapshot snapshot) {
    _nodeMap = DocumentSnapshot.deepCopyNodes(snapshot.nodeData);
    selection.restoreFromSnapshot(snapshot.selection);
    _isDirty = true;
    notifyListeners();
  }

  /// Execute a command with undo support
  void executeCommand(Command command) {
    final beforeSnapshot = createSnapshot();

    command.execute();
    _isDirty = true;

    final afterSnapshot = createSnapshot();

    undoStack.push(UndoEntry<DocumentSnapshot>(
      description: command.description,
      beforeState: beforeSnapshot,
      afterState: afterSnapshot,
    ));

    notifyListeners();
  }

  /// Undo last action
  void undo() {
    final snapshot = undoStack.undo();
    if (snapshot != null) {
      restoreSnapshot(snapshot);
    }
  }

  /// Redo last undone action
  void redo() {
    final snapshot = undoStack.redo();
    if (snapshot != null) {
      restoreSnapshot(snapshot);
    }
  }

  /// Start grouping commands (for drag operations, etc.)
  String startCommandGroup(String description) {
    return undoStack.startGroup(description);
  }

  /// End command grouping
  void endCommandGroup() {
    undoStack.endGroup();
  }

  // ===== Node Mutation Methods =====

  /// Update a node's properties
  void updateNode(String nodeId, Map<String, dynamic> updates) {
    final node = _nodeMap[nodeId];
    if (node == null) return;

    node.addAll(updates);
    _isDirty = true;
    notifyListeners();
  }

  /// Move nodes by delta
  void moveNodes(Set<String> nodeIds, Offset delta) {
    for (final nodeId in nodeIds) {
      final node = _nodeMap[nodeId];
      if (node == null) continue;

      // Update transform if present
      final transform = node['transform'] as Map<String, dynamic>?;
      if (transform != null) {
        final m02 = (transform['m02'] as num?)?.toDouble() ?? 0;
        final m12 = (transform['m12'] as num?)?.toDouble() ?? 0;
        transform['m02'] = m02 + delta.dx;
        transform['m12'] = m12 + delta.dy;
      }

      // Update bounding box if present
      final boundingBox = node['boundingBox'] as Map<String, dynamic>?;
      if (boundingBox != null) {
        final x = (boundingBox['x'] as num?)?.toDouble() ?? 0;
        final y = (boundingBox['y'] as num?)?.toDouble() ?? 0;
        boundingBox['x'] = x + delta.dx;
        boundingBox['y'] = y + delta.dy;
      }
    }
    _isDirty = true;
    notifyListeners();
  }

  /// Get node position
  Offset getNodePosition(String nodeId) {
    final node = _nodeMap[nodeId];
    if (node == null) return Offset.zero;

    final transform = node['transform'] as Map<String, dynamic>?;
    if (transform != null) {
      return Offset(
        (transform['m02'] as num?)?.toDouble() ?? 0,
        (transform['m12'] as num?)?.toDouble() ?? 0,
      );
    }

    final boundingBox = node['boundingBox'] as Map<String, dynamic>?;
    if (boundingBox != null) {
      return Offset(
        (boundingBox['x'] as num?)?.toDouble() ?? 0,
        (boundingBox['y'] as num?)?.toDouble() ?? 0,
      );
    }

    return Offset.zero;
  }

  /// Get node bounds
  Rect getNodeBounds(String nodeId) {
    final node = _nodeMap[nodeId];
    if (node == null) return Rect.zero;

    final position = getNodePosition(nodeId);

    final size = node['size'] as Map<String, dynamic>?;
    if (size != null) {
      return Rect.fromLTWH(
        position.dx,
        position.dy,
        (size['x'] as num?)?.toDouble() ?? 0,
        (size['y'] as num?)?.toDouble() ?? 0,
      );
    }

    final boundingBox = node['boundingBox'] as Map<String, dynamic>?;
    if (boundingBox != null) {
      return Rect.fromLTWH(
        (boundingBox['x'] as num?)?.toDouble() ?? 0,
        (boundingBox['y'] as num?)?.toDouble() ?? 0,
        (boundingBox['width'] as num?)?.toDouble() ?? 0,
        (boundingBox['height'] as num?)?.toDouble() ?? 0,
      );
    }

    return Rect.zero;
  }

  /// Get combined bounds of selected nodes
  Rect? getSelectionBounds() {
    if (!selection.hasSelection) return null;

    Rect? combined;
    for (final nodeId in selection.selectedNodeIds) {
      final bounds = getNodeBounds(nodeId);
      if (combined == null) {
        combined = bounds;
      } else {
        combined = combined.expandToInclude(bounds);
      }
    }
    return combined;
  }

  /// Delete nodes
  void deleteNodes(Set<String> nodeIds) {
    for (final nodeId in nodeIds) {
      _nodeMap.remove(nodeId);
      // Remove from parent's children list
      final parentId = getParentId(nodeId);
      if (parentId != null) {
        final parent = _nodeMap[parentId];
        if (parent != null) {
          final children = parent['children'] as List<dynamic>?;
          children?.remove(nodeId);
        }
      }
    }
    selection.deselectAll();
    _isDirty = true;
    notifyListeners();
  }

  /// Copy selected nodes to clipboard
  void copySelection() {
    if (!selection.hasSelection) return;

    final nodes = <Map<String, dynamic>>[];
    final bounds = getSelectionBounds();

    for (final nodeId in selection.selectedNodeIds) {
      final node = _nodeMap[nodeId];
      if (node != null) {
        nodes.add(Map<String, dynamic>.from(node));
      }
    }

    clipboard.copy(nodes, bounds?.center ?? Offset.zero);
  }

  /// Cut selected nodes
  void cutSelection() {
    copySelection();
    final nodeIds = Set<String>.from(selection.selectedNodeIds);
    deleteNodes(nodeIds);
  }

  /// Paste from clipboard
  void paste({Offset? at}) {
    if (!clipboard.hasContent) return;

    // TODO: Implement proper paste with new GUIDs and parent assignment
    _isDirty = true;
    notifyListeners();
  }

  /// Duplicate selected nodes
  void duplicateSelection({Offset offset = const Offset(10, 10)}) {
    if (!selection.hasSelection) return;

    // TODO: Implement proper duplication with new GUIDs
    _isDirty = true;
    notifyListeners();
  }

  /// Mark document as saved
  void markSaved() {
    _isDirty = false;
    notifyListeners();
  }
}

/// Available editor tools
enum EditorTool {
  select,
  frame,
  rectangle,
  ellipse,
  line,
  polygon,
  star,
  text,
  pen,
  pencil,
  hand,
  comment,
  slice,
}
