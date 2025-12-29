/// Menu Bar Actions
///
/// Callback container for all menu bar actions.

import 'package:flutter/material.dart';

/// Container for all menu bar action callbacks
class MenuBarActions {
  // File menu actions
  final VoidCallback? onBackToFiles;
  final VoidCallback? onNewDesignFile;
  final VoidCallback? onNewFigJamFile;
  final VoidCallback? onPlaceImage;
  final VoidCallback? onSaveLocalCopy;
  final VoidCallback? onSaveVersionHistory;
  final VoidCallback? onShowVersionHistory;
  final VoidCallback? onExport;
  final VoidCallback? onPreferences;

  // Edit menu actions
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onCopy;
  final VoidCallback? onCopyProperties;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final VoidCallback? onPasteToReplace;
  final VoidCallback? onPasteOverSelection;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final VoidCallback? onSelectAll;
  final VoidCallback? onSelectInverse;
  final VoidCallback? onSelectNone;
  final VoidCallback? onFindAndReplace;

  // View menu actions
  final VoidCallback? onTogglePixelGrid;
  final VoidCallback? onToggleLayoutGrids;
  final VoidCallback? onToggleRulers;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomTo100;
  final VoidCallback? onZoomToFit;
  final VoidCallback? onZoomToSelection;
  final VoidCallback? onToggleOutlineMode;
  final VoidCallback? onToggleLayers;
  final VoidCallback? onToggleAssets;
  final VoidCallback? onToggleDesign;
  final VoidCallback? onTogglePrototype;
  final VoidCallback? onToggleInspect;

  // Object menu actions
  final VoidCallback? onGroup;
  final VoidCallback? onUngroup;
  final VoidCallback? onFrameSelection;
  final VoidCallback? onAddAutoLayout;
  final VoidCallback? onRemoveAutoLayout;
  final VoidCallback? onCreateComponent;
  final VoidCallback? onResetInstance;
  final VoidCallback? onDetachInstance;
  final VoidCallback? onMask;
  final VoidCallback? onUseAsMask;
  final VoidCallback? onToggleLock;
  final VoidCallback? onToggleVisibility;

  // Vector menu actions
  final VoidCallback? onFlatten;
  final VoidCallback? onOutlineStroke;
  final VoidCallback? onBooleanUnion;
  final VoidCallback? onBooleanSubtract;
  final VoidCallback? onBooleanIntersect;
  final VoidCallback? onBooleanExclude;

  // Text menu actions
  final VoidCallback? onBold;
  final VoidCallback? onItalic;
  final VoidCallback? onUnderline;
  final VoidCallback? onStrikethrough;
  final VoidCallback? onAlignLeft;
  final VoidCallback? onAlignCenter;
  final VoidCallback? onAlignRight;
  final VoidCallback? onAlignJustify;
  final VoidCallback? onConvertToUppercase;
  final VoidCallback? onConvertToLowercase;
  final VoidCallback? onConvertToTitleCase;

  // Arrange menu actions
  final VoidCallback? onBringToFront;
  final VoidCallback? onBringForward;
  final VoidCallback? onSendBackward;
  final VoidCallback? onSendToBack;
  final VoidCallback? onAlignLeftEdge;
  final VoidCallback? onAlignRightEdge;
  final VoidCallback? onAlignTop;
  final VoidCallback? onAlignBottom;
  final VoidCallback? onAlignHorizontalCenter;
  final VoidCallback? onAlignVerticalCenter;
  final VoidCallback? onDistributeHorizontal;
  final VoidCallback? onDistributeVertical;

  const MenuBarActions({
    // File
    this.onBackToFiles,
    this.onNewDesignFile,
    this.onNewFigJamFile,
    this.onPlaceImage,
    this.onSaveLocalCopy,
    this.onSaveVersionHistory,
    this.onShowVersionHistory,
    this.onExport,
    this.onPreferences,
    // Edit
    this.onUndo,
    this.onRedo,
    this.onCopy,
    this.onCopyProperties,
    this.onCut,
    this.onPaste,
    this.onPasteToReplace,
    this.onPasteOverSelection,
    this.onDuplicate,
    this.onDelete,
    this.onSelectAll,
    this.onSelectInverse,
    this.onSelectNone,
    this.onFindAndReplace,
    // View
    this.onTogglePixelGrid,
    this.onToggleLayoutGrids,
    this.onToggleRulers,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomTo100,
    this.onZoomToFit,
    this.onZoomToSelection,
    this.onToggleOutlineMode,
    this.onToggleLayers,
    this.onToggleAssets,
    this.onToggleDesign,
    this.onTogglePrototype,
    this.onToggleInspect,
    // Object
    this.onGroup,
    this.onUngroup,
    this.onFrameSelection,
    this.onAddAutoLayout,
    this.onRemoveAutoLayout,
    this.onCreateComponent,
    this.onResetInstance,
    this.onDetachInstance,
    this.onMask,
    this.onUseAsMask,
    this.onToggleLock,
    this.onToggleVisibility,
    // Vector
    this.onFlatten,
    this.onOutlineStroke,
    this.onBooleanUnion,
    this.onBooleanSubtract,
    this.onBooleanIntersect,
    this.onBooleanExclude,
    // Text
    this.onBold,
    this.onItalic,
    this.onUnderline,
    this.onStrikethrough,
    this.onAlignLeft,
    this.onAlignCenter,
    this.onAlignRight,
    this.onAlignJustify,
    this.onConvertToUppercase,
    this.onConvertToLowercase,
    this.onConvertToTitleCase,
    // Arrange
    this.onBringToFront,
    this.onBringForward,
    this.onSendBackward,
    this.onSendToBack,
    this.onAlignLeftEdge,
    this.onAlignRightEdge,
    this.onAlignTop,
    this.onAlignBottom,
    this.onAlignHorizontalCenter,
    this.onAlignVerticalCenter,
    this.onDistributeHorizontal,
    this.onDistributeVertical,
  });
}

/// View state for toggle items in the View menu
class MenuBarViewState {
  final bool pixelGridEnabled;
  final bool layoutGridsEnabled;
  final bool rulersEnabled;
  final bool outlineModeEnabled;
  final bool layersVisible;
  final bool assetsVisible;
  final bool designPanelVisible;
  final bool prototypePanelVisible;
  final bool inspectPanelVisible;
  final double zoomLevel;

  const MenuBarViewState({
    this.pixelGridEnabled = false,
    this.layoutGridsEnabled = false,
    this.rulersEnabled = true,
    this.outlineModeEnabled = false,
    this.layersVisible = true,
    this.assetsVisible = true,
    this.designPanelVisible = true,
    this.prototypePanelVisible = false,
    this.inspectPanelVisible = false,
    this.zoomLevel = 100.0,
  });

  MenuBarViewState copyWith({
    bool? pixelGridEnabled,
    bool? layoutGridsEnabled,
    bool? rulersEnabled,
    bool? outlineModeEnabled,
    bool? layersVisible,
    bool? assetsVisible,
    bool? designPanelVisible,
    bool? prototypePanelVisible,
    bool? inspectPanelVisible,
    double? zoomLevel,
  }) {
    return MenuBarViewState(
      pixelGridEnabled: pixelGridEnabled ?? this.pixelGridEnabled,
      layoutGridsEnabled: layoutGridsEnabled ?? this.layoutGridsEnabled,
      rulersEnabled: rulersEnabled ?? this.rulersEnabled,
      outlineModeEnabled: outlineModeEnabled ?? this.outlineModeEnabled,
      layersVisible: layersVisible ?? this.layersVisible,
      assetsVisible: assetsVisible ?? this.assetsVisible,
      designPanelVisible: designPanelVisible ?? this.designPanelVisible,
      prototypePanelVisible: prototypePanelVisible ?? this.prototypePanelVisible,
      inspectPanelVisible: inspectPanelVisible ?? this.inspectPanelVisible,
      zoomLevel: zoomLevel ?? this.zoomLevel,
    );
  }
}
