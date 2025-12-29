/// Command pattern for undo/redo operations
///
/// Each command encapsulates a reversible action that can be:
/// - Executed (apply the change)
/// - Undone (reverse the change)
/// - Merged with subsequent commands of the same type
///
/// Commands store both the action and the state needed to reverse it.

import 'dart:ui';
import 'selection.dart';

/// Base class for all undoable commands
abstract class Command {
  /// Human-readable description for history panel
  String get description;

  /// Execute the command
  void execute();

  /// Undo the command
  void undo();

  /// Whether this command can merge with another command
  bool canMergeWith(Command other) => false;

  /// Merge with another command (returns merged command)
  Command? mergeWith(Command other) => null;
}

/// Command to move one or more nodes
class MoveNodeCommand extends Command {
  final Set<String> nodeIds;
  final Offset delta;
  final Function(Set<String>, Offset) applyMove;

  /// Store original positions for undo
  final Map<String, Offset> _originalPositions;

  MoveNodeCommand({
    required this.nodeIds,
    required this.delta,
    required this.applyMove,
    required Map<String, Offset> originalPositions,
  }) : _originalPositions = Map.from(originalPositions);

  @override
  String get description => nodeIds.length == 1
      ? 'Move layer'
      : 'Move ${nodeIds.length} layers';

  @override
  void execute() {
    applyMove(nodeIds, delta);
  }

  @override
  void undo() {
    applyMove(nodeIds, -delta);
  }

  @override
  bool canMergeWith(Command other) {
    if (other is! MoveNodeCommand) return false;
    // Merge consecutive moves of the same nodes
    return other.nodeIds.containsAll(nodeIds) &&
        nodeIds.containsAll(other.nodeIds);
  }

  @override
  Command? mergeWith(Command other) {
    if (!canMergeWith(other)) return null;
    final otherMove = other as MoveNodeCommand;
    return MoveNodeCommand(
      nodeIds: nodeIds,
      delta: delta + otherMove.delta,
      applyMove: applyMove,
      originalPositions: _originalPositions,
    );
  }
}

/// Command to resize one or more nodes
class ResizeNodeCommand extends Command {
  final Set<String> nodeIds;
  final Map<String, Rect> originalBounds;
  final Map<String, Rect> newBounds;
  final Function(Map<String, Rect>) applyBounds;

  ResizeNodeCommand({
    required this.nodeIds,
    required this.originalBounds,
    required this.newBounds,
    required this.applyBounds,
  });

  @override
  String get description => nodeIds.length == 1
      ? 'Resize layer'
      : 'Resize ${nodeIds.length} layers';

  @override
  void execute() {
    applyBounds(newBounds);
  }

  @override
  void undo() {
    applyBounds(originalBounds);
  }
}

/// Command to rotate a node
class RotateNodeCommand extends Command {
  final String nodeId;
  final double originalRotation;
  final double newRotation;
  final Function(String, double) applyRotation;

  RotateNodeCommand({
    required this.nodeId,
    required this.originalRotation,
    required this.newRotation,
    required this.applyRotation,
  });

  @override
  String get description => 'Rotate layer';

  @override
  void execute() {
    applyRotation(nodeId, newRotation);
  }

  @override
  void undo() {
    applyRotation(nodeId, originalRotation);
  }

  @override
  bool canMergeWith(Command other) {
    return other is RotateNodeCommand && other.nodeId == nodeId;
  }

  @override
  Command? mergeWith(Command other) {
    if (!canMergeWith(other)) return null;
    final otherRotate = other as RotateNodeCommand;
    return RotateNodeCommand(
      nodeId: nodeId,
      originalRotation: originalRotation,
      newRotation: otherRotate.newRotation,
      applyRotation: applyRotation,
    );
  }
}

/// Command to update a property value
class UpdatePropertyCommand<T> extends Command {
  final String nodeId;
  final String propertyName;
  final T originalValue;
  final T newValue;
  final Function(String, String, T) applyProperty;

  UpdatePropertyCommand({
    required this.nodeId,
    required this.propertyName,
    required this.originalValue,
    required this.newValue,
    required this.applyProperty,
  });

  @override
  String get description => 'Change $propertyName';

  @override
  void execute() {
    applyProperty(nodeId, propertyName, newValue);
  }

  @override
  void undo() {
    applyProperty(nodeId, propertyName, originalValue);
  }

  @override
  bool canMergeWith(Command other) {
    return other is UpdatePropertyCommand<T> &&
        other.nodeId == nodeId &&
        other.propertyName == propertyName;
  }

  @override
  Command? mergeWith(Command other) {
    if (!canMergeWith(other)) return null;
    final otherUpdate = other as UpdatePropertyCommand<T>;
    return UpdatePropertyCommand<T>(
      nodeId: nodeId,
      propertyName: propertyName,
      originalValue: originalValue,
      newValue: otherUpdate.newValue,
      applyProperty: applyProperty,
    );
  }
}

/// Command to delete nodes
class DeleteNodeCommand extends Command {
  final Set<String> nodeIds;
  final Map<String, Map<String, dynamic>> deletedNodeData;
  final Map<String, String?> parentIds;
  final Map<String, int> childIndices;
  final Function(Set<String>) deleteNodes;
  final Function(Map<String, Map<String, dynamic>>, Map<String, String?>, Map<String, int>) restoreNodes;

  DeleteNodeCommand({
    required this.nodeIds,
    required this.deletedNodeData,
    required this.parentIds,
    required this.childIndices,
    required this.deleteNodes,
    required this.restoreNodes,
  });

  @override
  String get description => nodeIds.length == 1
      ? 'Delete layer'
      : 'Delete ${nodeIds.length} layers';

  @override
  void execute() {
    deleteNodes(nodeIds);
  }

  @override
  void undo() {
    restoreNodes(deletedNodeData, parentIds, childIndices);
  }
}

/// Command to create new nodes
class CreateNodeCommand extends Command {
  final Map<String, dynamic> nodeData;
  final String? parentId;
  final int? childIndex;
  final String? createdNodeId;
  final Function(Map<String, dynamic>, String?, int?) createNode;
  final Function(String) deleteNode;

  CreateNodeCommand({
    required this.nodeData,
    this.parentId,
    this.childIndex,
    this.createdNodeId,
    required this.createNode,
    required this.deleteNode,
  });

  @override
  String get description => 'Create layer';

  @override
  void execute() {
    createNode(nodeData, parentId, childIndex);
  }

  @override
  void undo() {
    if (createdNodeId != null) {
      deleteNode(createdNodeId!);
    }
  }
}

/// Command to duplicate nodes
class DuplicateNodeCommand extends Command {
  final Set<String> sourceNodeIds;
  final Set<String> duplicatedNodeIds;
  final Offset offset;
  final Function(Set<String>, Offset) duplicateNodes;
  final Function(Set<String>) deleteNodes;

  DuplicateNodeCommand({
    required this.sourceNodeIds,
    required this.duplicatedNodeIds,
    required this.offset,
    required this.duplicateNodes,
    required this.deleteNodes,
  });

  @override
  String get description => sourceNodeIds.length == 1
      ? 'Duplicate layer'
      : 'Duplicate ${sourceNodeIds.length} layers';

  @override
  void execute() {
    duplicateNodes(sourceNodeIds, offset);
  }

  @override
  void undo() {
    deleteNodes(duplicatedNodeIds);
  }
}

/// Command to group nodes
class GroupNodeCommand extends Command {
  final Set<String> nodeIds;
  final String groupId;
  final Map<String, String?> originalParentIds;
  final Function(Set<String>) createGroup;
  final Function(String, Map<String, String?>) ungroup;

  GroupNodeCommand({
    required this.nodeIds,
    required this.groupId,
    required this.originalParentIds,
    required this.createGroup,
    required this.ungroup,
  });

  @override
  String get description => 'Group layers';

  @override
  void execute() {
    createGroup(nodeIds);
  }

  @override
  void undo() {
    ungroup(groupId, originalParentIds);
  }
}

/// Command to ungroup nodes
class UngroupNodeCommand extends Command {
  final String groupId;
  final Set<String> childNodeIds;
  final Map<String, dynamic> groupData;
  final String? parentId;
  final Function(String) ungroupNode;
  final Function(Map<String, dynamic>, Set<String>, String?) regroup;

  UngroupNodeCommand({
    required this.groupId,
    required this.childNodeIds,
    required this.groupData,
    this.parentId,
    required this.ungroupNode,
    required this.regroup,
  });

  @override
  String get description => 'Ungroup';

  @override
  void execute() {
    ungroupNode(groupId);
  }

  @override
  void undo() {
    regroup(groupData, childNodeIds, parentId);
  }
}

/// Command to reorder nodes (bring to front, send to back, etc.)
class ReorderNodeCommand extends Command {
  final String nodeId;
  final int originalIndex;
  final int newIndex;
  final Function(String, int) applyOrder;

  ReorderNodeCommand({
    required this.nodeId,
    required this.originalIndex,
    required this.newIndex,
    required this.applyOrder,
  });

  @override
  String get description {
    if (newIndex > originalIndex) {
      return 'Bring forward';
    } else {
      return 'Send backward';
    }
  }

  @override
  void execute() {
    applyOrder(nodeId, newIndex);
  }

  @override
  void undo() {
    applyOrder(nodeId, originalIndex);
  }
}

/// Command to change parent (reparent)
class ReparentNodeCommand extends Command {
  final Set<String> nodeIds;
  final Map<String, String?> originalParentIds;
  final String? newParentId;
  final Function(Set<String>, String?) applyReparent;

  ReparentNodeCommand({
    required this.nodeIds,
    required this.originalParentIds,
    required this.newParentId,
    required this.applyReparent,
  });

  @override
  String get description => 'Move to frame';

  @override
  void execute() {
    applyReparent(nodeIds, newParentId);
  }

  @override
  void undo() {
    // Restore each node to its original parent
    for (final entry in originalParentIds.entries) {
      applyReparent({entry.key}, entry.value);
    }
  }
}

/// Command for selection changes (optional - for select-all undo)
class SelectionCommand extends Command {
  final SelectionSnapshot originalSelection;
  final SelectionSnapshot newSelection;
  final Function(SelectionSnapshot) applySelection;

  SelectionCommand({
    required this.originalSelection,
    required this.newSelection,
    required this.applySelection,
  });

  @override
  String get description => 'Change selection';

  @override
  void execute() {
    applySelection(newSelection);
  }

  @override
  void undo() {
    applySelection(originalSelection);
  }
}

/// Compound command that groups multiple commands together
class CompoundCommand extends Command {
  final List<Command> commands;
  final String _description;

  CompoundCommand({
    required this.commands,
    required String description,
  }) : _description = description;

  @override
  String get description => _description;

  @override
  void execute() {
    for (final command in commands) {
      command.execute();
    }
  }

  @override
  void undo() {
    // Undo in reverse order
    for (final command in commands.reversed) {
      command.undo();
    }
  }
}
