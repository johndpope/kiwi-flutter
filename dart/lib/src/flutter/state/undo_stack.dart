/// Undo/Redo stack for editor history management
///
/// Features:
/// - Configurable history limit (default 50)
/// - Group related actions into single undo steps
/// - Undo/redo with state preservation

import 'package:flutter/foundation.dart';

/// Generic undo stack for managing editor history
class UndoStack<T> extends ChangeNotifier {
  /// Maximum number of history entries
  final int maxHistory;

  /// Internal history list
  final List<UndoEntry<T>> _history = [];

  /// Current position in history (-1 means at start)
  int _currentIndex = -1;

  /// Whether we're currently executing an undo/redo (to prevent recursive recording)
  bool _isUndoRedoing = false;

  /// Optional group ID for batching multiple commands
  String? _currentGroupId;

  UndoStack({this.maxHistory = 50});

  // Getters
  bool get canUndo => _currentIndex >= 0;
  bool get canRedo => _currentIndex < _history.length - 1;
  int get historyLength => _history.length;
  int get currentIndex => _currentIndex;
  bool get isUndoRedoing => _isUndoRedoing;

  /// Get the current entry (for display purposes)
  UndoEntry<T>? get currentEntry =>
      _currentIndex >= 0 && _currentIndex < _history.length
          ? _history[_currentIndex]
          : null;

  /// Get list of undo descriptions (for history panel)
  List<String> get undoDescriptions {
    return _history
        .take(_currentIndex + 1)
        .map((e) => e.description)
        .toList()
        .reversed
        .toList();
  }

  /// Get list of redo descriptions
  List<String> get redoDescriptions {
    if (_currentIndex >= _history.length - 1) return [];
    return _history
        .skip(_currentIndex + 1)
        .map((e) => e.description)
        .toList();
  }

  /// Push a new entry to the history stack
  void push(UndoEntry<T> entry) {
    if (_isUndoRedoing) return;

    // If we're in a group and this entry belongs to the same group,
    // merge it with the previous entry
    if (_currentGroupId != null &&
        entry.groupId == _currentGroupId &&
        _currentIndex >= 0) {
      final current = _history[_currentIndex];
      _history[_currentIndex] = UndoEntry<T>(
        description: current.description,
        beforeState: current.beforeState,
        afterState: entry.afterState,
        groupId: _currentGroupId,
      );
      notifyListeners();
      return;
    }

    // Remove any redo entries (we're branching history)
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // Add new entry
    _history.add(entry);
    _currentIndex = _history.length - 1;

    // Trim history if exceeding max
    while (_history.length > maxHistory) {
      _history.removeAt(0);
      _currentIndex--;
    }

    notifyListeners();
  }

  /// Undo the last action
  T? undo() {
    if (!canUndo) return null;

    _isUndoRedoing = true;
    try {
      final entry = _history[_currentIndex];
      _currentIndex--;
      notifyListeners();
      return entry.beforeState;
    } finally {
      _isUndoRedoing = false;
    }
  }

  /// Redo the next action
  T? redo() {
    if (!canRedo) return null;

    _isUndoRedoing = true;
    try {
      _currentIndex++;
      final entry = _history[_currentIndex];
      notifyListeners();
      return entry.afterState;
    } finally {
      _isUndoRedoing = false;
    }
  }

  /// Start a group of related actions (will be undone together)
  String startGroup(String description) {
    _currentGroupId = '${DateTime.now().millisecondsSinceEpoch}';
    return _currentGroupId!;
  }

  /// End the current action group
  void endGroup() {
    _currentGroupId = null;
  }

  /// Jump to a specific point in history
  T? jumpTo(int index) {
    if (index < -1 || index >= _history.length) return null;

    _isUndoRedoing = true;
    try {
      _currentIndex = index;
      notifyListeners();

      if (index >= 0) {
        return _history[index].afterState;
      }
      return null;
    } finally {
      _isUndoRedoing = false;
    }
  }

  /// Clear all history
  void clear() {
    _history.clear();
    _currentIndex = -1;
    _currentGroupId = null;
    notifyListeners();
  }
}

/// Represents a single entry in the undo history
class UndoEntry<T> {
  /// Human-readable description of this action
  final String description;

  /// State before the action
  final T beforeState;

  /// State after the action
  final T afterState;

  /// Optional group ID for batching related actions
  final String? groupId;

  /// Timestamp when this entry was created
  final DateTime timestamp;

  UndoEntry({
    required this.description,
    required this.beforeState,
    required this.afterState,
    this.groupId,
  }) : timestamp = DateTime.now();
}
