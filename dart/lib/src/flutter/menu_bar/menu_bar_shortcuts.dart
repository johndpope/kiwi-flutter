/// Menu Bar Keyboard Shortcuts
///
/// Provides keyboard shortcut handling for menu bar actions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'menu_bar_actions.dart';

// Intent classes for menu actions

// File menu intents
class BackToFilesIntent extends Intent {
  const BackToFilesIntent();
}

class NewDesignFileIntent extends Intent {
  const NewDesignFileIntent();
}

class PlaceImageIntent extends Intent {
  const PlaceImageIntent();
}

class SaveLocalCopyIntent extends Intent {
  const SaveLocalCopyIntent();
}

class ExportIntent extends Intent {
  const ExportIntent();
}

class PreferencesIntent extends Intent {
  const PreferencesIntent();
}

// Edit menu intents
class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class CopyIntent extends Intent {
  const CopyIntent();
}

class CopyPropertiesIntent extends Intent {
  const CopyPropertiesIntent();
}

class CutIntent extends Intent {
  const CutIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class PasteToReplaceIntent extends Intent {
  const PasteToReplaceIntent();
}

class PasteOverSelectionIntent extends Intent {
  const PasteOverSelectionIntent();
}

class DuplicateIntent extends Intent {
  const DuplicateIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}

class SelectInverseIntent extends Intent {
  const SelectInverseIntent();
}

class SelectNoneIntent extends Intent {
  const SelectNoneIntent();
}

class FindAndReplaceIntent extends Intent {
  const FindAndReplaceIntent();
}

// View menu intents
class TogglePixelGridIntent extends Intent {
  const TogglePixelGridIntent();
}

class ToggleLayoutGridsIntent extends Intent {
  const ToggleLayoutGridsIntent();
}

class ToggleRulersIntent extends Intent {
  const ToggleRulersIntent();
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

class ZoomTo100Intent extends Intent {
  const ZoomTo100Intent();
}

class ZoomToFitIntent extends Intent {
  const ZoomToFitIntent();
}

class ZoomToSelectionIntent extends Intent {
  const ZoomToSelectionIntent();
}

class ToggleOutlineModeIntent extends Intent {
  const ToggleOutlineModeIntent();
}

// Object menu intents
class GroupIntent extends Intent {
  const GroupIntent();
}

class UngroupIntent extends Intent {
  const UngroupIntent();
}

class FrameSelectionIntent extends Intent {
  const FrameSelectionIntent();
}

class AddAutoLayoutIntent extends Intent {
  const AddAutoLayoutIntent();
}

class CreateComponentIntent extends Intent {
  const CreateComponentIntent();
}

class DetachInstanceIntent extends Intent {
  const DetachInstanceIntent();
}

class MaskIntent extends Intent {
  const MaskIntent();
}

class ToggleLockIntent extends Intent {
  const ToggleLockIntent();
}

class ToggleVisibilityIntent extends Intent {
  const ToggleVisibilityIntent();
}

// Vector menu intents
class FlattenIntent extends Intent {
  const FlattenIntent();
}

class OutlineStrokeIntent extends Intent {
  const OutlineStrokeIntent();
}

class BooleanUnionIntent extends Intent {
  const BooleanUnionIntent();
}

class BooleanSubtractIntent extends Intent {
  const BooleanSubtractIntent();
}

class BooleanIntersectIntent extends Intent {
  const BooleanIntersectIntent();
}

class BooleanExcludeIntent extends Intent {
  const BooleanExcludeIntent();
}

// Text menu intents
class BoldIntent extends Intent {
  const BoldIntent();
}

class ItalicIntent extends Intent {
  const ItalicIntent();
}

class UnderlineIntent extends Intent {
  const UnderlineIntent();
}

// Arrange menu intents
class BringToFrontIntent extends Intent {
  const BringToFrontIntent();
}

class BringForwardIntent extends Intent {
  const BringForwardIntent();
}

class SendBackwardIntent extends Intent {
  const SendBackwardIntent();
}

class SendToBackIntent extends Intent {
  const SendToBackIntent();
}

/// Widget that wraps children with menu bar keyboard shortcuts
class MenuBarShortcuts extends StatelessWidget {
  final Widget child;
  final MenuBarActions actions;
  final bool enabled;

  const MenuBarShortcuts({
    super.key,
    required this.child,
    required this.actions,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: _buildActions(),
        child: child,
      ),
    );
  }

  static final Map<ShortcutActivator, Intent> _shortcuts = {
    // File menu
    const SingleActivator(LogicalKeyboardKey.backslash, meta: true):
        const BackToFilesIntent(),
    const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
        const NewDesignFileIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK, meta: true, shift: true):
        const PlaceImageIntent(),
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
        const SaveLocalCopyIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
        const ExportIntent(),
    const SingleActivator(LogicalKeyboardKey.comma, meta: true):
        const PreferencesIntent(),

    // Edit menu
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
        const UndoIntent(),
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        const RedoIntent(),
    const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
        const CopyIntent(),
    const SingleActivator(LogicalKeyboardKey.keyC, meta: true, alt: true):
        const CopyPropertiesIntent(),
    const SingleActivator(LogicalKeyboardKey.keyX, meta: true):
        const CutIntent(),
    const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
        const PasteIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR, meta: true, shift: true):
        const PasteToReplaceIntent(),
    const SingleActivator(LogicalKeyboardKey.keyV, meta: true, shift: true):
        const PasteOverSelectionIntent(),
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
        const DuplicateIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace): const DeleteIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
        const SelectAllIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA, meta: true, shift: true):
        const SelectInverseIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const SelectNoneIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
        const FindAndReplaceIntent(),

    // View menu
    const SingleActivator(LogicalKeyboardKey.quote, meta: true):
        const TogglePixelGridIntent(),
    const SingleActivator(LogicalKeyboardKey.keyG, control: true):
        const ToggleLayoutGridsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR, shift: true):
        const ToggleRulersIntent(),
    const SingleActivator(LogicalKeyboardKey.equal, meta: true):
        const ZoomInIntent(),
    const SingleActivator(LogicalKeyboardKey.minus, meta: true):
        const ZoomOutIntent(),
    const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
        const ZoomTo100Intent(),
    const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
        const ZoomToFitIntent(),
    const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
        const ZoomToSelectionIntent(),
    const SingleActivator(LogicalKeyboardKey.keyY, meta: true):
        const ToggleOutlineModeIntent(),

    // Object menu
    const SingleActivator(LogicalKeyboardKey.keyG, meta: true):
        const GroupIntent(),
    const SingleActivator(LogicalKeyboardKey.keyG, meta: true, shift: true):
        const UngroupIntent(),
    const SingleActivator(LogicalKeyboardKey.keyG, meta: true, alt: true):
        const FrameSelectionIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA, shift: true):
        const AddAutoLayoutIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK, meta: true, alt: true):
        const CreateComponentIntent(),
    const SingleActivator(LogicalKeyboardKey.keyB, meta: true, alt: true):
        const DetachInstanceIntent(),
    const SingleActivator(LogicalKeyboardKey.keyM, meta: true, control: true):
        const MaskIntent(),
    const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
        const ToggleLockIntent(),
    const SingleActivator(LogicalKeyboardKey.keyH, meta: true, shift: true):
        const ToggleVisibilityIntent(),

    // Vector menu
    const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
        const OutlineStrokeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyU, meta: true, alt: true):
        const BooleanUnionIntent(),
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true, alt: true):
        const BooleanSubtractIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI, meta: true, alt: true):
        const BooleanIntersectIntent(),
    const SingleActivator(LogicalKeyboardKey.keyX, meta: true, alt: true):
        const BooleanExcludeIntent(),

    // Text menu
    const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
        const BoldIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
        const ItalicIntent(),
    const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
        const UnderlineIntent(),

    // Arrange menu
    const SingleActivator(LogicalKeyboardKey.bracketRight):
        const BringToFrontIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
        const BringForwardIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
        const SendBackwardIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketLeft):
        const SendToBackIntent(),
  };

  Map<Type, Action<Intent>> _buildActions() {
    return {
      // File menu
      BackToFilesIntent: CallbackAction<BackToFilesIntent>(
        onInvoke: (_) {
          actions.onBackToFiles?.call();
          return null;
        },
      ),
      NewDesignFileIntent: CallbackAction<NewDesignFileIntent>(
        onInvoke: (_) {
          actions.onNewDesignFile?.call();
          return null;
        },
      ),
      PlaceImageIntent: CallbackAction<PlaceImageIntent>(
        onInvoke: (_) {
          actions.onPlaceImage?.call();
          return null;
        },
      ),
      SaveLocalCopyIntent: CallbackAction<SaveLocalCopyIntent>(
        onInvoke: (_) {
          actions.onSaveLocalCopy?.call();
          return null;
        },
      ),
      ExportIntent: CallbackAction<ExportIntent>(
        onInvoke: (_) {
          actions.onExport?.call();
          return null;
        },
      ),
      PreferencesIntent: CallbackAction<PreferencesIntent>(
        onInvoke: (_) {
          actions.onPreferences?.call();
          return null;
        },
      ),

      // Edit menu
      UndoIntent: CallbackAction<UndoIntent>(
        onInvoke: (_) {
          actions.onUndo?.call();
          return null;
        },
      ),
      RedoIntent: CallbackAction<RedoIntent>(
        onInvoke: (_) {
          actions.onRedo?.call();
          return null;
        },
      ),
      CopyIntent: CallbackAction<CopyIntent>(
        onInvoke: (_) {
          actions.onCopy?.call();
          return null;
        },
      ),
      CopyPropertiesIntent: CallbackAction<CopyPropertiesIntent>(
        onInvoke: (_) {
          actions.onCopyProperties?.call();
          return null;
        },
      ),
      CutIntent: CallbackAction<CutIntent>(
        onInvoke: (_) {
          actions.onCut?.call();
          return null;
        },
      ),
      PasteIntent: CallbackAction<PasteIntent>(
        onInvoke: (_) {
          actions.onPaste?.call();
          return null;
        },
      ),
      PasteToReplaceIntent: CallbackAction<PasteToReplaceIntent>(
        onInvoke: (_) {
          actions.onPasteToReplace?.call();
          return null;
        },
      ),
      PasteOverSelectionIntent: CallbackAction<PasteOverSelectionIntent>(
        onInvoke: (_) {
          actions.onPasteOverSelection?.call();
          return null;
        },
      ),
      DuplicateIntent: CallbackAction<DuplicateIntent>(
        onInvoke: (_) {
          actions.onDuplicate?.call();
          return null;
        },
      ),
      DeleteIntent: CallbackAction<DeleteIntent>(
        onInvoke: (_) {
          actions.onDelete?.call();
          return null;
        },
      ),
      SelectAllIntent: CallbackAction<SelectAllIntent>(
        onInvoke: (_) {
          actions.onSelectAll?.call();
          return null;
        },
      ),
      SelectInverseIntent: CallbackAction<SelectInverseIntent>(
        onInvoke: (_) {
          actions.onSelectInverse?.call();
          return null;
        },
      ),
      SelectNoneIntent: CallbackAction<SelectNoneIntent>(
        onInvoke: (_) {
          actions.onSelectNone?.call();
          return null;
        },
      ),
      FindAndReplaceIntent: CallbackAction<FindAndReplaceIntent>(
        onInvoke: (_) {
          actions.onFindAndReplace?.call();
          return null;
        },
      ),

      // View menu
      TogglePixelGridIntent: CallbackAction<TogglePixelGridIntent>(
        onInvoke: (_) {
          actions.onTogglePixelGrid?.call();
          return null;
        },
      ),
      ToggleLayoutGridsIntent: CallbackAction<ToggleLayoutGridsIntent>(
        onInvoke: (_) {
          actions.onToggleLayoutGrids?.call();
          return null;
        },
      ),
      ToggleRulersIntent: CallbackAction<ToggleRulersIntent>(
        onInvoke: (_) {
          actions.onToggleRulers?.call();
          return null;
        },
      ),
      ZoomInIntent: CallbackAction<ZoomInIntent>(
        onInvoke: (_) {
          actions.onZoomIn?.call();
          return null;
        },
      ),
      ZoomOutIntent: CallbackAction<ZoomOutIntent>(
        onInvoke: (_) {
          actions.onZoomOut?.call();
          return null;
        },
      ),
      ZoomTo100Intent: CallbackAction<ZoomTo100Intent>(
        onInvoke: (_) {
          actions.onZoomTo100?.call();
          return null;
        },
      ),
      ZoomToFitIntent: CallbackAction<ZoomToFitIntent>(
        onInvoke: (_) {
          actions.onZoomToFit?.call();
          return null;
        },
      ),
      ZoomToSelectionIntent: CallbackAction<ZoomToSelectionIntent>(
        onInvoke: (_) {
          actions.onZoomToSelection?.call();
          return null;
        },
      ),
      ToggleOutlineModeIntent: CallbackAction<ToggleOutlineModeIntent>(
        onInvoke: (_) {
          actions.onToggleOutlineMode?.call();
          return null;
        },
      ),

      // Object menu
      GroupIntent: CallbackAction<GroupIntent>(
        onInvoke: (_) {
          actions.onGroup?.call();
          return null;
        },
      ),
      UngroupIntent: CallbackAction<UngroupIntent>(
        onInvoke: (_) {
          actions.onUngroup?.call();
          return null;
        },
      ),
      FrameSelectionIntent: CallbackAction<FrameSelectionIntent>(
        onInvoke: (_) {
          actions.onFrameSelection?.call();
          return null;
        },
      ),
      AddAutoLayoutIntent: CallbackAction<AddAutoLayoutIntent>(
        onInvoke: (_) {
          actions.onAddAutoLayout?.call();
          return null;
        },
      ),
      CreateComponentIntent: CallbackAction<CreateComponentIntent>(
        onInvoke: (_) {
          actions.onCreateComponent?.call();
          return null;
        },
      ),
      DetachInstanceIntent: CallbackAction<DetachInstanceIntent>(
        onInvoke: (_) {
          actions.onDetachInstance?.call();
          return null;
        },
      ),
      MaskIntent: CallbackAction<MaskIntent>(
        onInvoke: (_) {
          actions.onMask?.call();
          return null;
        },
      ),
      ToggleLockIntent: CallbackAction<ToggleLockIntent>(
        onInvoke: (_) {
          actions.onToggleLock?.call();
          return null;
        },
      ),
      ToggleVisibilityIntent: CallbackAction<ToggleVisibilityIntent>(
        onInvoke: (_) {
          actions.onToggleVisibility?.call();
          return null;
        },
      ),

      // Vector menu
      FlattenIntent: CallbackAction<FlattenIntent>(
        onInvoke: (_) {
          actions.onFlatten?.call();
          return null;
        },
      ),
      OutlineStrokeIntent: CallbackAction<OutlineStrokeIntent>(
        onInvoke: (_) {
          actions.onOutlineStroke?.call();
          return null;
        },
      ),
      BooleanUnionIntent: CallbackAction<BooleanUnionIntent>(
        onInvoke: (_) {
          actions.onBooleanUnion?.call();
          return null;
        },
      ),
      BooleanSubtractIntent: CallbackAction<BooleanSubtractIntent>(
        onInvoke: (_) {
          actions.onBooleanSubtract?.call();
          return null;
        },
      ),
      BooleanIntersectIntent: CallbackAction<BooleanIntersectIntent>(
        onInvoke: (_) {
          actions.onBooleanIntersect?.call();
          return null;
        },
      ),
      BooleanExcludeIntent: CallbackAction<BooleanExcludeIntent>(
        onInvoke: (_) {
          actions.onBooleanExclude?.call();
          return null;
        },
      ),

      // Text menu
      BoldIntent: CallbackAction<BoldIntent>(
        onInvoke: (_) {
          actions.onBold?.call();
          return null;
        },
      ),
      ItalicIntent: CallbackAction<ItalicIntent>(
        onInvoke: (_) {
          actions.onItalic?.call();
          return null;
        },
      ),
      UnderlineIntent: CallbackAction<UnderlineIntent>(
        onInvoke: (_) {
          actions.onUnderline?.call();
          return null;
        },
      ),

      // Arrange menu
      BringToFrontIntent: CallbackAction<BringToFrontIntent>(
        onInvoke: (_) {
          actions.onBringToFront?.call();
          return null;
        },
      ),
      BringForwardIntent: CallbackAction<BringForwardIntent>(
        onInvoke: (_) {
          actions.onBringForward?.call();
          return null;
        },
      ),
      SendBackwardIntent: CallbackAction<SendBackwardIntent>(
        onInvoke: (_) {
          actions.onSendBackward?.call();
          return null;
        },
      ),
      SendToBackIntent: CallbackAction<SendToBackIntent>(
        onInvoke: (_) {
          actions.onSendToBack?.call();
          return null;
        },
      ),
    };
  }
}
