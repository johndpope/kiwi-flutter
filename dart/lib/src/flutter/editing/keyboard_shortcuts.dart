/// Keyboard shortcuts handler for the Figma editor
///
/// Provides standard keyboard shortcuts:
/// - Cmd/Ctrl+Z: Undo
/// - Cmd/Ctrl+Shift+Z: Redo
/// - Cmd/Ctrl+C: Copy
/// - Cmd/Ctrl+X: Cut
/// - Cmd/Ctrl+V: Paste
/// - Cmd/Ctrl+D: Duplicate
/// - Delete/Backspace: Delete selected
/// - Cmd/Ctrl+A: Select all
/// - Escape: Deselect / Cancel
/// - Arrow keys: Nudge selection
/// - Shift+Arrow: Large nudge (10px)

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcut actions
enum ShortcutAction {
  undo,
  redo,
  copy,
  cut,
  paste,
  duplicate,
  delete,
  selectAll,
  deselect,
  cancel,
  nudgeUp,
  nudgeDown,
  nudgeLeft,
  nudgeRight,
  nudgeUpLarge,
  nudgeDownLarge,
  nudgeLeftLarge,
  nudgeRightLarge,
  group,
  ungroup,
  bringForward,
  sendBackward,
  bringToFront,
  sendToBack,
  zoomIn,
  zoomOut,
  zoomToFit,
  zoomTo100,
  toggleGrid,
  toggleRulers,
  save,
}

/// Callback for shortcut actions
typedef ShortcutCallback = void Function(ShortcutAction action);

/// Keyboard shortcuts widget
class KeyboardShortcuts extends StatelessWidget {
  /// Child widget
  final Widget child;

  /// Callback when a shortcut is triggered
  final ShortcutCallback onShortcut;

  /// Whether shortcuts are enabled
  final bool enabled;

  /// Focus node for keyboard events
  final FocusNode? focusNode;

  const KeyboardShortcuts({
    super.key,
    required this.child,
    required this.onShortcut,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(
        actions: _buildActions(),
        child: Focus(
          focusNode: focusNode,
          autofocus: true,
          child: child,
        ),
      ),
    );
  }

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;

    return {
      // Undo/Redo
      SingleActivator(LogicalKeyboardKey.keyZ, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.undo),
      SingleActivator(LogicalKeyboardKey.keyZ, meta: isMac, control: !isMac, shift: true):
          const _ShortcutIntent(ShortcutAction.redo),

      // Clipboard
      SingleActivator(LogicalKeyboardKey.keyC, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.copy),
      SingleActivator(LogicalKeyboardKey.keyX, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.cut),
      SingleActivator(LogicalKeyboardKey.keyV, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.paste),
      SingleActivator(LogicalKeyboardKey.keyD, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.duplicate),

      // Delete
      const SingleActivator(LogicalKeyboardKey.delete):
          const _ShortcutIntent(ShortcutAction.delete),
      const SingleActivator(LogicalKeyboardKey.backspace):
          const _ShortcutIntent(ShortcutAction.delete),

      // Selection
      SingleActivator(LogicalKeyboardKey.keyA, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.selectAll),
      const SingleActivator(LogicalKeyboardKey.escape):
          const _ShortcutIntent(ShortcutAction.deselect),

      // Nudge
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const _ShortcutIntent(ShortcutAction.nudgeUp),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const _ShortcutIntent(ShortcutAction.nudgeDown),
      const SingleActivator(LogicalKeyboardKey.arrowLeft):
          const _ShortcutIntent(ShortcutAction.nudgeLeft),
      const SingleActivator(LogicalKeyboardKey.arrowRight):
          const _ShortcutIntent(ShortcutAction.nudgeRight),
      const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
          const _ShortcutIntent(ShortcutAction.nudgeUpLarge),
      const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
          const _ShortcutIntent(ShortcutAction.nudgeDownLarge),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
          const _ShortcutIntent(ShortcutAction.nudgeLeftLarge),
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
          const _ShortcutIntent(ShortcutAction.nudgeRightLarge),

      // Grouping
      SingleActivator(LogicalKeyboardKey.keyG, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.group),
      SingleActivator(LogicalKeyboardKey.keyG, meta: isMac, control: !isMac, shift: true):
          const _ShortcutIntent(ShortcutAction.ungroup),

      // Layer ordering
      const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
          const _ShortcutIntent(ShortcutAction.bringForward),
      const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
          const _ShortcutIntent(ShortcutAction.sendBackward),
      const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true, alt: true):
          const _ShortcutIntent(ShortcutAction.bringToFront),
      const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true, alt: true):
          const _ShortcutIntent(ShortcutAction.sendToBack),

      // Zoom
      SingleActivator(LogicalKeyboardKey.equal, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.zoomIn),
      SingleActivator(LogicalKeyboardKey.minus, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.zoomOut),
      SingleActivator(LogicalKeyboardKey.digit1, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.zoomTo100),
      SingleActivator(LogicalKeyboardKey.digit0, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.zoomToFit),

      // View toggles
      SingleActivator(LogicalKeyboardKey.quote, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.toggleGrid),

      // Save
      SingleActivator(LogicalKeyboardKey.keyS, meta: isMac, control: !isMac):
          const _ShortcutIntent(ShortcutAction.save),
    };
  }

  Map<Type, Action<Intent>> _buildActions() {
    return {
      _ShortcutIntent: CallbackAction<_ShortcutIntent>(
        onInvoke: (intent) {
          onShortcut(intent.action);
          return null;
        },
      ),
    };
  }
}

/// Intent for shortcut actions
class _ShortcutIntent extends Intent {
  final ShortcutAction action;

  const _ShortcutIntent(this.action);
}

/// Extension to get nudge offset from action
extension ShortcutActionExtension on ShortcutAction {
  /// Get the nudge offset for this action
  Offset? get nudgeOffset {
    const smallNudge = 1.0;
    const largeNudge = 10.0;

    switch (this) {
      case ShortcutAction.nudgeUp:
        return const Offset(0, -smallNudge);
      case ShortcutAction.nudgeDown:
        return const Offset(0, smallNudge);
      case ShortcutAction.nudgeLeft:
        return const Offset(-smallNudge, 0);
      case ShortcutAction.nudgeRight:
        return const Offset(smallNudge, 0);
      case ShortcutAction.nudgeUpLarge:
        return const Offset(0, -largeNudge);
      case ShortcutAction.nudgeDownLarge:
        return const Offset(0, largeNudge);
      case ShortcutAction.nudgeLeftLarge:
        return const Offset(-largeNudge, 0);
      case ShortcutAction.nudgeRightLarge:
        return const Offset(largeNudge, 0);
      default:
        return null;
    }
  }

  /// Check if this is a nudge action
  bool get isNudge {
    return nudgeOffset != null;
  }
}

/// Tool selection keyboard shortcuts
class ToolShortcuts extends StatelessWidget {
  final Widget child;
  final void Function(String tool) onToolSelected;
  final bool enabled;

  const ToolShortcuts({
    super.key,
    required this.child,
    required this.onToolSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyV): _ToolIntent('select'),
        SingleActivator(LogicalKeyboardKey.keyF): _ToolIntent('frame'),
        SingleActivator(LogicalKeyboardKey.keyR): _ToolIntent('rectangle'),
        SingleActivator(LogicalKeyboardKey.keyO): _ToolIntent('ellipse'),
        SingleActivator(LogicalKeyboardKey.keyL): _ToolIntent('line'),
        SingleActivator(LogicalKeyboardKey.keyT): _ToolIntent('text'),
        SingleActivator(LogicalKeyboardKey.keyP): _ToolIntent('pen'),
        SingleActivator(LogicalKeyboardKey.keyH): _ToolIntent('hand'),
        SingleActivator(LogicalKeyboardKey.space): _ToolIntent('hand_temp'),
        SingleActivator(LogicalKeyboardKey.keyC): _ToolIntent('comment'),
        SingleActivator(LogicalKeyboardKey.keyS): _ToolIntent('slice'),
      },
      child: Actions(
        actions: {
          _ToolIntent: CallbackAction<_ToolIntent>(
            onInvoke: (intent) {
              onToolSelected(intent.tool);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _ToolIntent extends Intent {
  final String tool;
  const _ToolIntent(this.tool);
}
