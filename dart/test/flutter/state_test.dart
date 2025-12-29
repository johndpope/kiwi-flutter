import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';
import 'package:kiwi_schema/src/flutter/state/selection.dart';
import 'package:kiwi_schema/src/flutter/state/undo_stack.dart';
import 'package:kiwi_schema/src/flutter/state/command.dart';
import 'package:kiwi_schema/src/flutter/state/document_state.dart';

void main() {
  group('Selection', () {
    late Selection selection;

    setUp(() {
      selection = Selection();
    });

    test('initial state is empty', () {
      expect(selection.hasSelection, false);
      expect(selection.selectedNodeIds, isEmpty);
      expect(selection.primaryNodeId, isNull);
    });

    test('select single node', () {
      selection.select('node-1');
      expect(selection.hasSelection, true);
      expect(selection.selectedNodeIds, {'node-1'});
      expect(selection.primaryNodeId, 'node-1');
    });

    test('select replaces previous selection', () {
      selection.select('node-1');
      selection.select('node-2');
      expect(selection.selectedNodeIds, {'node-2'});
      expect(selection.primaryNodeId, 'node-2');
    });

    test('additive select adds to selection', () {
      selection.select('node-1');
      selection.select('node-2', additive: true);
      expect(selection.selectedNodeIds, {'node-1', 'node-2'});
      expect(selection.primaryNodeId, 'node-2');
    });

    test('toggle adds unselected node', () {
      selection.toggle('node-1');
      expect(selection.selectedNodeIds, {'node-1'});
    });

    test('toggle removes selected node', () {
      selection.select('node-1');
      selection.toggle('node-1');
      expect(selection.selectedNodeIds, isEmpty);
    });

    test('selectMultiple selects all nodes', () {
      selection.selectMultiple(['node-1', 'node-2', 'node-3']);
      expect(selection.selectedNodeIds, {'node-1', 'node-2', 'node-3'});
      expect(selection.count, 3);
      expect(selection.isMultiSelect, true);
    });

    test('deselectAll clears selection', () {
      selection.selectMultiple(['node-1', 'node-2']);
      selection.deselectAll();
      expect(selection.hasSelection, false);
      expect(selection.primaryNodeId, isNull);
    });

    test('isSelected returns correct value', () {
      selection.select('node-1');
      expect(selection.isSelected('node-1'), true);
      expect(selection.isSelected('node-2'), false);
    });

    test('marquee selection starts and updates', () {
      selection.startMarquee(Offset.zero);
      expect(selection.marqueeRect, isNotNull);
      expect(selection.marqueeRect!.topLeft, Offset.zero);

      selection.updateMarquee(const Offset(100, 100));
      expect(selection.marqueeRect!.size, const Size(100, 100));
    });

    test('endMarquee selects nodes in rect', () {
      selection.startMarquee(Offset.zero);
      selection.updateMarquee(const Offset(100, 100));
      selection.endMarquee(['node-1', 'node-2']);
      expect(selection.marqueeRect, isNull);
      expect(selection.selectedNodeIds, {'node-1', 'node-2'});
    });

    test('enterGroup sets entered group', () {
      selection.enterGroup('group-1');
      expect(selection.enteredGroupId, 'group-1');
    });

    test('exitGroup returns to parent', () {
      selection.enterGroup('group-1');
      selection.enterGroup('group-2');
      selection.exitGroup();
      expect(selection.enteredGroupId, 'group-1');
      selection.exitGroup();
      expect(selection.enteredGroupId, isNull);
    });

    test('snapshot and restore', () {
      selection.selectMultiple(['node-1', 'node-2']);
      final snapshot = selection.snapshot();

      selection.deselectAll();
      selection.restoreFromSnapshot(snapshot);

      expect(selection.selectedNodeIds, {'node-1', 'node-2'});
    });

    test('notifies listeners on changes', () {
      var notificationCount = 0;
      selection.addListener(() => notificationCount++);

      selection.select('node-1');
      expect(notificationCount, 1);

      selection.toggle('node-2');
      expect(notificationCount, 2);

      selection.deselectAll();
      expect(notificationCount, 3);
    });
  });

  group('UndoStack', () {
    late UndoStack<String> undoStack;

    setUp(() {
      undoStack = UndoStack<String>(maxHistory: 5);
    });

    test('initial state', () {
      expect(undoStack.canUndo, false);
      expect(undoStack.canRedo, false);
      expect(undoStack.historyLength, 0);
    });

    test('push adds entry', () {
      undoStack.push(UndoEntry<String>(
        description: 'Test',
        beforeState: 'before',
        afterState: 'after',
      ));
      expect(undoStack.canUndo, true);
      expect(undoStack.historyLength, 1);
    });

    test('undo returns before state', () {
      undoStack.push(UndoEntry<String>(
        description: 'Test',
        beforeState: 'before',
        afterState: 'after',
      ));
      final result = undoStack.undo();
      expect(result, 'before');
      expect(undoStack.canUndo, false);
      expect(undoStack.canRedo, true);
    });

    test('redo returns after state', () {
      undoStack.push(UndoEntry<String>(
        description: 'Test',
        beforeState: 'before',
        afterState: 'after',
      ));
      undoStack.undo();
      final result = undoStack.redo();
      expect(result, 'after');
      expect(undoStack.canRedo, false);
    });

    test('push clears redo history', () {
      undoStack.push(UndoEntry<String>(
        description: 'First',
        beforeState: 'a',
        afterState: 'b',
      ));
      undoStack.undo();
      expect(undoStack.canRedo, true);

      undoStack.push(UndoEntry<String>(
        description: 'Second',
        beforeState: 'a',
        afterState: 'c',
      ));
      expect(undoStack.canRedo, false);
    });

    test('respects maxHistory limit', () {
      for (var i = 0; i < 10; i++) {
        undoStack.push(UndoEntry<String>(
          description: 'Entry $i',
          beforeState: '$i-before',
          afterState: '$i-after',
        ));
      }
      expect(undoStack.historyLength, 5);
    });

    test('group merges consecutive entries', () {
      final groupId = undoStack.startGroup('Group');

      undoStack.push(UndoEntry<String>(
        description: 'First',
        beforeState: 'a',
        afterState: 'b',
        groupId: groupId,
      ));

      undoStack.push(UndoEntry<String>(
        description: 'Second',
        beforeState: 'b',
        afterState: 'c',
        groupId: groupId,
      ));

      undoStack.endGroup();

      expect(undoStack.historyLength, 1);
      // Single undo should go from c back to a
      final result = undoStack.undo();
      expect(result, 'a');
    });

    test('jumpTo navigates to specific index', () {
      undoStack.push(UndoEntry<String>(
        description: 'First',
        beforeState: 'a',
        afterState: 'b',
      ));
      undoStack.push(UndoEntry<String>(
        description: 'Second',
        beforeState: 'b',
        afterState: 'c',
      ));
      undoStack.push(UndoEntry<String>(
        description: 'Third',
        beforeState: 'c',
        afterState: 'd',
      ));

      final result = undoStack.jumpTo(0);
      expect(result, 'b');
      expect(undoStack.currentIndex, 0);
    });

    test('clear removes all history', () {
      undoStack.push(UndoEntry<String>(
        description: 'Test',
        beforeState: 'before',
        afterState: 'after',
      ));
      undoStack.clear();
      expect(undoStack.historyLength, 0);
      expect(undoStack.canUndo, false);
    });

    test('undoDescriptions returns correct list', () {
      undoStack.push(UndoEntry<String>(
        description: 'First',
        beforeState: 'a',
        afterState: 'b',
      ));
      undoStack.push(UndoEntry<String>(
        description: 'Second',
        beforeState: 'b',
        afterState: 'c',
      ));

      final descriptions = undoStack.undoDescriptions;
      expect(descriptions, ['Second', 'First']);
    });
  });

  group('Command', () {
    test('MoveNodeCommand executes and undoes', () {
      final positions = <String, Offset>{'node-1': const Offset(0, 0)};

      void applyMove(Set<String> nodeIds, Offset delta) {
        for (final id in nodeIds) {
          positions[id] = positions[id]! + delta;
        }
      }

      final command = MoveNodeCommand(
        nodeIds: {'node-1'},
        delta: const Offset(10, 20),
        applyMove: applyMove,
        originalPositions: Map.from(positions),
      );

      command.execute();
      expect(positions['node-1'], const Offset(10, 20));

      command.undo();
      expect(positions['node-1'], const Offset(0, 0));
    });

    test('MoveNodeCommand can merge', () {
      void applyMove(Set<String> nodeIds, Offset delta) {}

      final command1 = MoveNodeCommand(
        nodeIds: {'node-1'},
        delta: const Offset(10, 0),
        applyMove: applyMove,
        originalPositions: {'node-1': Offset.zero},
      );

      final command2 = MoveNodeCommand(
        nodeIds: {'node-1'},
        delta: const Offset(0, 20),
        applyMove: applyMove,
        originalPositions: {'node-1': const Offset(10, 0)},
      );

      expect(command1.canMergeWith(command2), true);

      final merged = command1.mergeWith(command2) as MoveNodeCommand;
      expect(merged.delta, const Offset(10, 20));
    });

    test('UpdatePropertyCommand executes and undoes', () {
      final properties = <String, dynamic>{'opacity': 1.0};

      void applyProperty(String nodeId, String name, double value) {
        properties[name] = value;
      }

      final command = UpdatePropertyCommand<double>(
        nodeId: 'node-1',
        propertyName: 'opacity',
        originalValue: 1.0,
        newValue: 0.5,
        applyProperty: applyProperty,
      );

      command.execute();
      expect(properties['opacity'], 0.5);

      command.undo();
      expect(properties['opacity'], 1.0);
    });

    test('CompoundCommand executes all in order', () {
      final log = <String>[];

      final command = CompoundCommand(
        description: 'Multiple actions',
        commands: [
          _TestCommand('first', () => log.add('exec-1'), () => log.add('undo-1')),
          _TestCommand('second', () => log.add('exec-2'), () => log.add('undo-2')),
        ],
      );

      command.execute();
      expect(log, ['exec-1', 'exec-2']);

      log.clear();
      command.undo();
      expect(log, ['undo-2', 'undo-1']); // Reverse order
    });
  });

  group('ViewState', () {
    late ViewState viewState;

    setUp(() {
      viewState = ViewState();
    });

    test('initial values', () {
      expect(viewState.zoom, 1.0);
      expect(viewState.panOffset, Offset.zero);
      expect(viewState.showRulers, true);
      expect(viewState.showGrid, false);
    });

    test('setZoom clamps value', () {
      viewState.setZoom(0.001);
      expect(viewState.zoom, 0.01);

      viewState.setZoom(500);
      expect(viewState.zoom, 256.0);
    });

    test('toggles work correctly', () {
      viewState.toggleRulers();
      expect(viewState.showRulers, false);

      viewState.toggleGrid();
      expect(viewState.showGrid, true);
    });

    test('resetView restores defaults', () {
      viewState.setZoom(2.0);
      viewState.setPanOffset(const Offset(100, 100));

      viewState.resetView();

      expect(viewState.zoom, 1.0);
      expect(viewState.panOffset, Offset.zero);
    });
  });

  group('DocumentState', () {
    late DocumentState docState;

    setUp(() {
      docState = DocumentState();
    });

    tearDown(() {
      docState.dispose();
    });

    test('initial state', () {
      expect(docState.nodeMap, isEmpty);
      expect(docState.rootNodeIds, isEmpty);
      expect(docState.isDirty, false);
      expect(docState.canUndo, false);
      expect(docState.canRedo, false);
    });

    test('loadDocument sets up state', () {
      docState.loadDocument(
        nodeMap: {
          'page-1': {'type': 'CANVAS'},
          'frame-1': {'type': 'FRAME', 'parentId': 'page-1'},
        },
        rootNodeIds: ['page-1'],
        documentName: 'Test Doc',
      );

      expect(docState.nodeMap.length, 2);
      expect(docState.rootNodeIds, ['page-1']);
      expect(docState.documentName, 'Test Doc');
      expect(docState.viewState.activePageId, 'page-1');
    });

    test('getNode returns correct node', () {
      docState.loadDocument(
        nodeMap: {'node-1': {'type': 'FRAME', 'name': 'Test'}},
        rootNodeIds: [],
      );

      final node = docState.getNode('node-1');
      expect(node?['name'], 'Test');
      expect(docState.getNode('nonexistent'), isNull);
    });

    test('setActiveTool changes tool', () {
      expect(docState.activeTool, EditorTool.select);

      docState.setActiveTool(EditorTool.rectangle);
      expect(docState.activeTool, EditorTool.rectangle);
    });

    test('selection changes notify listeners', () {
      var notified = false;
      docState.addListener(() => notified = true);

      docState.selection.select('node-1');
      expect(notified, true);
    });

    test('undo and redo work with commands', () {
      docState.loadDocument(
        nodeMap: {
          'node-1': {
            'type': 'FRAME',
            'transform': {'m02': 0.0, 'm12': 0.0}
          }
        },
        rootNodeIds: [],
      );

      // Verify initial position
      final initialPos = docState.getNodePosition('node-1');
      expect(initialPos, Offset.zero);

      // Execute a move command
      final command = MoveNodeCommand(
        nodeIds: {'node-1'},
        delta: const Offset(50, 50),
        applyMove: docState.moveNodes,
        originalPositions: {'node-1': docState.getNodePosition('node-1')},
      );
      docState.executeCommand(command);

      expect(docState.isDirty, true);
      expect(docState.canUndo, true);

      // Verify position changed
      final pos1 = docState.getNodePosition('node-1');
      expect(pos1, const Offset(50, 50));

      // Undo - restores from snapshot which has the full node map
      docState.undo();
      expect(docState.canRedo, true);

      // After undo, position should be restored to original
      final pos2 = docState.getNodePosition('node-1');
      expect(pos2.dx, closeTo(0.0, 0.01));
      expect(pos2.dy, closeTo(0.0, 0.01));

      // Redo
      docState.redo();
      final pos3 = docState.getNodePosition('node-1');
      expect(pos3.dx, closeTo(50.0, 0.01));
      expect(pos3.dy, closeTo(50.0, 0.01));
    });
  });
}

/// Helper test command
class _TestCommand extends Command {
  final String _description;
  final void Function() _execute;
  final void Function() _undo;

  _TestCommand(this._description, this._execute, this._undo);

  @override
  String get description => _description;

  @override
  void execute() => _execute();

  @override
  void undo() => _undo();
}
