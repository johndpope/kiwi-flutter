/// State management exports for the Figma editor
///
/// Provides Provider-based state management with:
/// - DocumentState: Central state container
/// - Selection: Multi-select with marquee support
/// - UndoStack: History management with 50+ levels
/// - Command: Command pattern for reversible actions

export 'document_state.dart';
export 'selection.dart';
export 'undo_stack.dart';
export 'command.dart';
