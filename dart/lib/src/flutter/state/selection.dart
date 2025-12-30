/// Selection state management for Figma editor
///
/// Supports:
/// - Single and multi-select
/// - Marquee drag selection
/// - Shift+click additive selection
/// - Selection bounding box calculation

import 'package:flutter/foundation.dart';
import 'dart:ui';

/// Represents the current selection state in the editor
class Selection extends ChangeNotifier {
  /// Set of selected node IDs (GUIDs)
  final Set<String> _selectedNodeIds = {};

  /// Currently active marquee selection rect (null when not dragging)
  Rect? _marqueeRect;

  /// The primary (most recently selected) node ID
  String? _primaryNodeId;

  /// Currently hovered node ID (for hover highlighting)
  String? _hoveredNodeId;

  /// Whether we're in group editing mode (entered a group/frame)
  String? _enteredGroupId;

  /// History of entered groups for navigation
  final List<String> _groupHistory = [];

  // Getters
  Set<String> get selectedNodeIds => Set.unmodifiable(_selectedNodeIds);
  Rect? get marqueeRect => _marqueeRect;
  String? get primaryNodeId => _primaryNodeId;
  String? get hoveredNodeId => _hoveredNodeId;
  String? get enteredGroupId => _enteredGroupId;
  bool get hasSelection => _selectedNodeIds.isNotEmpty;
  bool get isMultiSelect => _selectedNodeIds.length > 1;
  int get count => _selectedNodeIds.length;
  bool get hasHover => _hoveredNodeId != null;

  /// Select a single node, optionally adding to existing selection
  void select(String nodeId, {bool additive = false}) {
    if (!additive) {
      _selectedNodeIds.clear();
    }
    _selectedNodeIds.add(nodeId);
    _primaryNodeId = nodeId;
    notifyListeners();
  }

  /// Toggle selection of a node (for shift+click)
  void toggle(String nodeId) {
    if (_selectedNodeIds.contains(nodeId)) {
      _selectedNodeIds.remove(nodeId);
      if (_primaryNodeId == nodeId) {
        _primaryNodeId = _selectedNodeIds.isEmpty ? null : _selectedNodeIds.last;
      }
    } else {
      _selectedNodeIds.add(nodeId);
      _primaryNodeId = nodeId;
    }
    notifyListeners();
  }

  /// Select multiple nodes at once
  void selectMultiple(Iterable<String> nodeIds, {bool additive = false}) {
    if (!additive) {
      _selectedNodeIds.clear();
    }
    _selectedNodeIds.addAll(nodeIds);
    if (nodeIds.isNotEmpty) {
      _primaryNodeId = nodeIds.last;
    }
    notifyListeners();
  }

  /// Clear all selection
  void deselectAll() {
    if (_selectedNodeIds.isEmpty) return;
    _selectedNodeIds.clear();
    _primaryNodeId = null;
    notifyListeners();
  }

  /// Check if a node is selected
  bool isSelected(String nodeId) {
    return _selectedNodeIds.contains(nodeId);
  }

  /// Check if a node is hovered
  bool isHovered(String nodeId) {
    return _hoveredNodeId == nodeId;
  }

  /// Set hovered node (for hover highlighting)
  void setHoveredNode(String? nodeId) {
    if (_hoveredNodeId != nodeId) {
      _hoveredNodeId = nodeId;
      notifyListeners();
    }
  }

  /// Clear hover state
  void clearHover() {
    if (_hoveredNodeId != null) {
      _hoveredNodeId = null;
      notifyListeners();
    }
  }

  /// Start marquee selection
  void startMarquee(Offset start) {
    _marqueeRect = Rect.fromPoints(start, start);
    notifyListeners();
  }

  /// Update marquee selection
  void updateMarquee(Offset current) {
    if (_marqueeRect == null) return;
    _marqueeRect = Rect.fromPoints(_marqueeRect!.topLeft, current);
    notifyListeners();
  }

  /// End marquee selection and select nodes within the rect
  void endMarquee(List<String> nodesInRect, {bool additive = false}) {
    _marqueeRect = null;
    if (nodesInRect.isNotEmpty) {
      selectMultiple(nodesInRect, additive: additive);
    } else if (!additive) {
      deselectAll();
    }
    notifyListeners();
  }

  /// Cancel marquee without selecting
  void cancelMarquee() {
    _marqueeRect = null;
    notifyListeners();
  }

  /// Enter a group/frame for editing its children
  void enterGroup(String groupId) {
    if (_enteredGroupId != null) {
      _groupHistory.add(_enteredGroupId!);
    }
    _enteredGroupId = groupId;
    deselectAll();
    notifyListeners();
  }

  /// Exit the current group
  void exitGroup() {
    if (_groupHistory.isNotEmpty) {
      _enteredGroupId = _groupHistory.removeLast();
    } else {
      _enteredGroupId = null;
    }
    deselectAll();
    notifyListeners();
  }

  /// Exit all groups to root level
  void exitAllGroups() {
    _groupHistory.clear();
    _enteredGroupId = null;
    deselectAll();
    notifyListeners();
  }

  /// Replace selection with new set (for undo/redo)
  void restoreSelection(Set<String> nodeIds, String? primary) {
    _selectedNodeIds.clear();
    _selectedNodeIds.addAll(nodeIds);
    _primaryNodeId = primary;
    notifyListeners();
  }

  /// Get a snapshot of current selection for undo
  SelectionSnapshot snapshot() {
    return SelectionSnapshot(
      selectedNodeIds: Set.from(_selectedNodeIds),
      primaryNodeId: _primaryNodeId,
    );
  }

  /// Restore from a snapshot
  void restoreFromSnapshot(SelectionSnapshot snapshot) {
    _selectedNodeIds.clear();
    _selectedNodeIds.addAll(snapshot.selectedNodeIds);
    _primaryNodeId = snapshot.primaryNodeId;
    notifyListeners();
  }
}

/// Immutable snapshot of selection state for undo/redo
class SelectionSnapshot {
  final Set<String> selectedNodeIds;
  final String? primaryNodeId;

  const SelectionSnapshot({
    required this.selectedNodeIds,
    this.primaryNodeId,
  });
}
