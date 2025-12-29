/// Menu Bar Builder
///
/// Provides builder pattern for constructing menus and default menu definitions.

import 'menu_bar.dart';
import 'menu_bar_actions.dart';

/// Context for building menus - determines what's enabled/disabled
class MenuBarContext {
  final bool hasDocument;
  final bool hasSelection;
  final bool hasMultipleSelection;
  final bool canUndo;
  final bool canRedo;
  final bool hasClipboard;
  final bool isGroupSelected;
  final bool isComponentSelected;
  final bool isInstanceSelected;
  final bool isTextSelected;
  final bool isVectorSelected;
  final bool isFrameSelected;
  final bool isLocked;
  final bool isHidden;
  final MenuBarViewState viewState;

  const MenuBarContext({
    this.hasDocument = true,
    this.hasSelection = false,
    this.hasMultipleSelection = false,
    this.canUndo = false,
    this.canRedo = false,
    this.hasClipboard = false,
    this.isGroupSelected = false,
    this.isComponentSelected = false,
    this.isInstanceSelected = false,
    this.isTextSelected = false,
    this.isVectorSelected = false,
    this.isFrameSelected = false,
    this.isLocked = false,
    this.isHidden = false,
    this.viewState = const MenuBarViewState(),
  });
}

/// Default menu bar sections matching Figma
class DefaultMenuBarSections {
  static List<MenuBarSection> get all => [
        fileMenu,
        editMenu,
        viewMenu,
        objectMenu,
        vectorMenu,
        textMenu,
        arrangeMenu,
      ];

  static MenuBarSection get fileMenu => const MenuBarSection(
        id: 'file',
        label: 'File',
        items: [
          MenuBarItem(
            id: 'back_to_files',
            label: 'Back to files',
            shortcut: '⌘\\',
          ),
          MenuBarItem(
            id: 'new_design_file',
            label: 'New design file',
            shortcut: '⌘N',
          ),
          MenuBarItem(
            id: 'new_figjam_file',
            label: 'New FigJam file',
          ),
          MenuBarItem(
            id: 'place_image',
            label: 'Place image...',
            shortcut: '⇧⌘K',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'save_local_copy',
            label: 'Save local copy',
            shortcut: '⌘S',
          ),
          MenuBarItem(
            id: 'save_version_history',
            label: 'Save version history...',
          ),
          MenuBarItem(
            id: 'show_version_history',
            label: 'Show version history',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'export',
            label: 'Export...',
            shortcut: '⌘E',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'preferences',
            label: 'Preferences',
            shortcut: '⌘,',
          ),
        ],
      );

  static MenuBarSection get editMenu => const MenuBarSection(
        id: 'edit',
        label: 'Edit',
        items: [
          MenuBarItem(
            id: 'undo',
            label: 'Undo',
            shortcut: '⌘Z',
          ),
          MenuBarItem(
            id: 'redo',
            label: 'Redo',
            shortcut: '⇧⌘Z',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'copy',
            label: 'Copy',
            shortcut: '⌘C',
          ),
          MenuBarItem(
            id: 'copy_properties',
            label: 'Copy properties',
            shortcut: '⌥⌘C',
          ),
          MenuBarItem(
            id: 'cut',
            label: 'Cut',
            shortcut: '⌘X',
          ),
          MenuBarItem(
            id: 'paste',
            label: 'Paste',
            shortcut: '⌘V',
          ),
          MenuBarItem(
            id: 'paste_to_replace',
            label: 'Paste to replace',
            shortcut: '⇧⌘R',
          ),
          MenuBarItem(
            id: 'paste_over_selection',
            label: 'Paste over selection',
            shortcut: '⇧⌘V',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'duplicate',
            label: 'Duplicate',
            shortcut: '⌘D',
          ),
          MenuBarItem(
            id: 'delete',
            label: 'Delete',
            shortcut: '⌫',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'select_all',
            label: 'Select all',
            shortcut: '⌘A',
          ),
          MenuBarItem(
            id: 'select_inverse',
            label: 'Select inverse',
            shortcut: '⇧⌘A',
          ),
          MenuBarItem(
            id: 'select_none',
            label: 'Select none',
            shortcut: 'Esc',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'find_and_replace',
            label: 'Find and replace...',
            shortcut: '⌘F',
          ),
        ],
      );

  static MenuBarSection get viewMenu => MenuBarSection(
        id: 'view',
        label: 'View',
        items: [
          const MenuBarItem.toggle(
            id: 'pixel_grid',
            label: 'Pixel grid',
            shortcut: "⌘'",
            checked: false,
          ),
          const MenuBarItem.toggle(
            id: 'layout_grids',
            label: 'Layout grids',
            shortcut: '⌃G',
            checked: false,
          ),
          const MenuBarItem.toggle(
            id: 'rulers',
            label: 'Rulers',
            shortcut: '⇧R',
            checked: true,
          ),
          const MenuBarItem.divider(),
          const MenuBarItem(
            id: 'zoom_in',
            label: 'Zoom in',
            shortcut: '⌘+',
          ),
          const MenuBarItem(
            id: 'zoom_out',
            label: 'Zoom out',
            shortcut: '⌘-',
          ),
          const MenuBarItem(
            id: 'zoom_100',
            label: 'Zoom to 100%',
            shortcut: '⌘0',
          ),
          const MenuBarItem(
            id: 'zoom_fit',
            label: 'Zoom to fit',
            shortcut: '⌘1',
          ),
          const MenuBarItem(
            id: 'zoom_selection',
            label: 'Zoom to selection',
            shortcut: '⌘2',
          ),
          const MenuBarItem.divider(),
          MenuBarItem.submenu(
            id: 'panels',
            label: 'Panels',
            submenu: [
              const MenuBarItem.toggle(
                id: 'layers_panel',
                label: 'Layers',
                checked: true,
              ),
              const MenuBarItem.toggle(
                id: 'assets_panel',
                label: 'Assets',
                checked: true,
              ),
              const MenuBarItem.divider(),
              const MenuBarItem.toggle(
                id: 'design_panel',
                label: 'Design',
                checked: true,
              ),
              const MenuBarItem.toggle(
                id: 'prototype_panel',
                label: 'Prototype',
                checked: false,
              ),
              const MenuBarItem.toggle(
                id: 'inspect_panel',
                label: 'Inspect',
                checked: false,
              ),
            ],
          ),
          const MenuBarItem.toggle(
            id: 'outline_mode',
            label: 'Outline mode',
            shortcut: '⌘Y',
            checked: false,
          ),
        ],
      );

  static MenuBarSection get objectMenu => MenuBarSection(
        id: 'object',
        label: 'Object',
        items: [
          const MenuBarItem(
            id: 'group',
            label: 'Group selection',
            shortcut: '⌘G',
          ),
          const MenuBarItem(
            id: 'ungroup',
            label: 'Ungroup',
            shortcut: '⇧⌘G',
          ),
          const MenuBarItem(
            id: 'frame_selection',
            label: 'Frame selection',
            shortcut: '⌥⌘G',
          ),
          const MenuBarItem.divider(),
          const MenuBarItem(
            id: 'add_auto_layout',
            label: 'Add auto layout',
            shortcut: '⇧A',
          ),
          const MenuBarItem(
            id: 'remove_auto_layout',
            label: 'Remove auto layout',
          ),
          const MenuBarItem.divider(),
          const MenuBarItem(
            id: 'create_component',
            label: 'Create component',
            shortcut: '⌥⌘K',
          ),
          const MenuBarItem(
            id: 'reset_instance',
            label: 'Reset instance',
          ),
          const MenuBarItem(
            id: 'detach_instance',
            label: 'Detach instance',
            shortcut: '⌥⌘B',
          ),
          const MenuBarItem.divider(),
          const MenuBarItem(
            id: 'mask',
            label: 'Mask',
            shortcut: '⌃⌘M',
          ),
          const MenuBarItem(
            id: 'use_as_mask',
            label: 'Use as mask',
          ),
          const MenuBarItem.divider(),
          const MenuBarItem(
            id: 'lock_unlock',
            label: 'Lock/unlock',
            shortcut: '⌘L',
          ),
          const MenuBarItem(
            id: 'show_hide',
            label: 'Show/hide',
            shortcut: '⇧⌘H',
          ),
        ],
      );

  static MenuBarSection get vectorMenu => MenuBarSection(
        id: 'vector',
        label: 'Vector',
        items: [
          const MenuBarItem(
            id: 'flatten',
            label: 'Flatten',
            shortcut: '⌘E',
          ),
          const MenuBarItem(
            id: 'outline_stroke',
            label: 'Outline stroke',
            shortcut: '⌘O',
          ),
          const MenuBarItem.divider(),
          MenuBarItem.submenu(
            id: 'boolean_operation',
            label: 'Boolean operation',
            submenu: [
              const MenuBarItem(
                id: 'union',
                label: 'Union',
                shortcut: '⌥⌘U',
              ),
              const MenuBarItem(
                id: 'subtract',
                label: 'Subtract',
                shortcut: '⌥⌘S',
              ),
              const MenuBarItem(
                id: 'intersect',
                label: 'Intersect',
                shortcut: '⌥⌘I',
              ),
              const MenuBarItem(
                id: 'exclude',
                label: 'Exclude',
                shortcut: '⌥⌘X',
              ),
            ],
          ),
        ],
      );

  static MenuBarSection get textMenu => const MenuBarSection(
        id: 'text',
        label: 'Text',
        items: [
          MenuBarItem(
            id: 'bold',
            label: 'Bold',
            shortcut: '⌘B',
          ),
          MenuBarItem(
            id: 'italic',
            label: 'Italic',
            shortcut: '⌘I',
          ),
          MenuBarItem(
            id: 'underline',
            label: 'Underline',
            shortcut: '⌘U',
          ),
          MenuBarItem(
            id: 'strikethrough',
            label: 'Strikethrough',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'align_left',
            label: 'Align left',
          ),
          MenuBarItem(
            id: 'align_center',
            label: 'Align center',
          ),
          MenuBarItem(
            id: 'align_right',
            label: 'Align right',
          ),
          MenuBarItem(
            id: 'justify',
            label: 'Justify',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'uppercase',
            label: 'Convert to uppercase',
          ),
          MenuBarItem(
            id: 'lowercase',
            label: 'Convert to lowercase',
          ),
          MenuBarItem(
            id: 'titlecase',
            label: 'Convert to title case',
          ),
        ],
      );

  static MenuBarSection get arrangeMenu => const MenuBarSection(
        id: 'arrange',
        label: 'Arrange',
        items: [
          MenuBarItem(
            id: 'bring_to_front',
            label: 'Bring to front',
            shortcut: ']',
          ),
          MenuBarItem(
            id: 'bring_forward',
            label: 'Bring forward',
            shortcut: '⌘]',
          ),
          MenuBarItem(
            id: 'send_backward',
            label: 'Send backward',
            shortcut: '⌘[',
          ),
          MenuBarItem(
            id: 'send_to_back',
            label: 'Send to back',
            shortcut: '[',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'align_left_edge',
            label: 'Align left',
          ),
          MenuBarItem(
            id: 'align_right_edge',
            label: 'Align right',
          ),
          MenuBarItem(
            id: 'align_top_edge',
            label: 'Align top',
          ),
          MenuBarItem(
            id: 'align_bottom_edge',
            label: 'Align bottom',
          ),
          MenuBarItem(
            id: 'align_horizontal_center',
            label: 'Align horizontal center',
          ),
          MenuBarItem(
            id: 'align_vertical_center',
            label: 'Align vertical center',
          ),
          MenuBarItem.divider(),
          MenuBarItem(
            id: 'distribute_horizontal',
            label: 'Distribute horizontal spacing',
          ),
          MenuBarItem(
            id: 'distribute_vertical',
            label: 'Distribute vertical spacing',
          ),
        ],
      );
}

/// Builds menu sections dynamically based on context
class MenuBarBuilder {
  final MenuBarContext context;
  final MenuBarActions actions;

  const MenuBarBuilder({
    required this.context,
    required this.actions,
  });

  /// Builds all menu sections with proper enabled/disabled states
  List<MenuBarSection> build() {
    return [
      _buildFileMenu(),
      _buildEditMenu(),
      _buildViewMenu(),
      _buildObjectMenu(),
      _buildVectorMenu(),
      _buildTextMenu(),
      _buildArrangeMenu(),
    ];
  }

  MenuBarSection _buildFileMenu() {
    return MenuBarSection(
      id: 'file',
      label: 'File',
      items: [
        MenuBarItem(
          id: 'back_to_files',
          label: 'Back to files',
          shortcut: '⌘\\',
          onTap: actions.onBackToFiles,
        ),
        MenuBarItem(
          id: 'new_design_file',
          label: 'New design file',
          shortcut: '⌘N',
          onTap: actions.onNewDesignFile,
        ),
        MenuBarItem(
          id: 'new_figjam_file',
          label: 'New FigJam file',
          onTap: actions.onNewFigJamFile,
        ),
        MenuBarItem(
          id: 'place_image',
          label: 'Place image...',
          shortcut: '⇧⌘K',
          onTap: actions.onPlaceImage,
          enabled: context.hasDocument,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'save_local_copy',
          label: 'Save local copy',
          shortcut: '⌘S',
          onTap: actions.onSaveLocalCopy,
          enabled: context.hasDocument,
        ),
        MenuBarItem(
          id: 'save_version_history',
          label: 'Save version history...',
          onTap: actions.onSaveVersionHistory,
          enabled: context.hasDocument,
        ),
        MenuBarItem(
          id: 'show_version_history',
          label: 'Show version history',
          onTap: actions.onShowVersionHistory,
          enabled: context.hasDocument,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'export',
          label: 'Export...',
          shortcut: '⌘E',
          onTap: actions.onExport,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'preferences',
          label: 'Preferences',
          shortcut: '⌘,',
          onTap: actions.onPreferences,
        ),
      ],
    );
  }

  MenuBarSection _buildEditMenu() {
    return MenuBarSection(
      id: 'edit',
      label: 'Edit',
      items: [
        MenuBarItem(
          id: 'undo',
          label: 'Undo',
          shortcut: '⌘Z',
          onTap: actions.onUndo,
          enabled: context.canUndo,
        ),
        MenuBarItem(
          id: 'redo',
          label: 'Redo',
          shortcut: '⇧⌘Z',
          onTap: actions.onRedo,
          enabled: context.canRedo,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'copy',
          label: 'Copy',
          shortcut: '⌘C',
          onTap: actions.onCopy,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'copy_properties',
          label: 'Copy properties',
          shortcut: '⌥⌘C',
          onTap: actions.onCopyProperties,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'cut',
          label: 'Cut',
          shortcut: '⌘X',
          onTap: actions.onCut,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'paste',
          label: 'Paste',
          shortcut: '⌘V',
          onTap: actions.onPaste,
          enabled: context.hasClipboard,
        ),
        MenuBarItem(
          id: 'paste_to_replace',
          label: 'Paste to replace',
          shortcut: '⇧⌘R',
          onTap: actions.onPasteToReplace,
          enabled: context.hasClipboard && context.hasSelection,
        ),
        MenuBarItem(
          id: 'paste_over_selection',
          label: 'Paste over selection',
          shortcut: '⇧⌘V',
          onTap: actions.onPasteOverSelection,
          enabled: context.hasClipboard && context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'duplicate',
          label: 'Duplicate',
          shortcut: '⌘D',
          onTap: actions.onDuplicate,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'delete',
          label: 'Delete',
          shortcut: '⌫',
          onTap: actions.onDelete,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'select_all',
          label: 'Select all',
          shortcut: '⌘A',
          onTap: actions.onSelectAll,
          enabled: context.hasDocument,
        ),
        MenuBarItem(
          id: 'select_inverse',
          label: 'Select inverse',
          shortcut: '⇧⌘A',
          onTap: actions.onSelectInverse,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'select_none',
          label: 'Select none',
          shortcut: 'Esc',
          onTap: actions.onSelectNone,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'find_and_replace',
          label: 'Find and replace...',
          shortcut: '⌘F',
          onTap: actions.onFindAndReplace,
          enabled: context.hasDocument,
        ),
      ],
    );
  }

  MenuBarSection _buildViewMenu() {
    return MenuBarSection(
      id: 'view',
      label: 'View',
      items: [
        MenuBarItem.toggle(
          id: 'pixel_grid',
          label: 'Pixel grid',
          shortcut: "⌘'",
          checked: context.viewState.pixelGridEnabled,
          onTap: actions.onTogglePixelGrid,
        ),
        MenuBarItem.toggle(
          id: 'layout_grids',
          label: 'Layout grids',
          shortcut: '⌃G',
          checked: context.viewState.layoutGridsEnabled,
          onTap: actions.onToggleLayoutGrids,
        ),
        MenuBarItem.toggle(
          id: 'rulers',
          label: 'Rulers',
          shortcut: '⇧R',
          checked: context.viewState.rulersEnabled,
          onTap: actions.onToggleRulers,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'zoom_in',
          label: 'Zoom in',
          shortcut: '⌘+',
          onTap: actions.onZoomIn,
        ),
        MenuBarItem(
          id: 'zoom_out',
          label: 'Zoom out',
          shortcut: '⌘-',
          onTap: actions.onZoomOut,
        ),
        MenuBarItem(
          id: 'zoom_100',
          label: 'Zoom to 100%',
          shortcut: '⌘0',
          onTap: actions.onZoomTo100,
        ),
        MenuBarItem(
          id: 'zoom_fit',
          label: 'Zoom to fit',
          shortcut: '⌘1',
          onTap: actions.onZoomToFit,
        ),
        MenuBarItem(
          id: 'zoom_selection',
          label: 'Zoom to selection',
          shortcut: '⌘2',
          onTap: actions.onZoomToSelection,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem.submenu(
          id: 'panels',
          label: 'Panels',
          submenu: [
            MenuBarItem.toggle(
              id: 'layers_panel',
              label: 'Layers',
              checked: context.viewState.layersVisible,
              onTap: actions.onToggleLayers,
            ),
            MenuBarItem.toggle(
              id: 'assets_panel',
              label: 'Assets',
              checked: context.viewState.assetsVisible,
              onTap: actions.onToggleAssets,
            ),
            const MenuBarItem.divider(),
            MenuBarItem.toggle(
              id: 'design_panel',
              label: 'Design',
              checked: context.viewState.designPanelVisible,
              onTap: actions.onToggleDesign,
            ),
            MenuBarItem.toggle(
              id: 'prototype_panel',
              label: 'Prototype',
              checked: context.viewState.prototypePanelVisible,
              onTap: actions.onTogglePrototype,
            ),
            MenuBarItem.toggle(
              id: 'inspect_panel',
              label: 'Inspect',
              checked: context.viewState.inspectPanelVisible,
              onTap: actions.onToggleInspect,
            ),
          ],
        ),
        MenuBarItem.toggle(
          id: 'outline_mode',
          label: 'Outline mode',
          shortcut: '⌘Y',
          checked: context.viewState.outlineModeEnabled,
          onTap: actions.onToggleOutlineMode,
        ),
      ],
    );
  }

  MenuBarSection _buildObjectMenu() {
    return MenuBarSection(
      id: 'object',
      label: 'Object',
      items: [
        MenuBarItem(
          id: 'group',
          label: 'Group selection',
          shortcut: '⌘G',
          onTap: actions.onGroup,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'ungroup',
          label: 'Ungroup',
          shortcut: '⇧⌘G',
          onTap: actions.onUngroup,
          enabled: context.isGroupSelected,
        ),
        MenuBarItem(
          id: 'frame_selection',
          label: 'Frame selection',
          shortcut: '⌥⌘G',
          onTap: actions.onFrameSelection,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'add_auto_layout',
          label: 'Add auto layout',
          shortcut: '⇧A',
          onTap: actions.onAddAutoLayout,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'remove_auto_layout',
          label: 'Remove auto layout',
          onTap: actions.onRemoveAutoLayout,
          enabled: context.isFrameSelected,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'create_component',
          label: 'Create component',
          shortcut: '⌥⌘K',
          onTap: actions.onCreateComponent,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'reset_instance',
          label: 'Reset instance',
          onTap: actions.onResetInstance,
          enabled: context.isInstanceSelected,
        ),
        MenuBarItem(
          id: 'detach_instance',
          label: 'Detach instance',
          shortcut: '⌥⌘B',
          onTap: actions.onDetachInstance,
          enabled: context.isInstanceSelected,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'mask',
          label: 'Mask',
          shortcut: '⌃⌘M',
          onTap: actions.onMask,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'use_as_mask',
          label: 'Use as mask',
          onTap: actions.onUseAsMask,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'lock_unlock',
          label: context.isLocked ? 'Unlock' : 'Lock',
          shortcut: '⌘L',
          onTap: actions.onToggleLock,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'show_hide',
          label: context.isHidden ? 'Show' : 'Hide',
          shortcut: '⇧⌘H',
          onTap: actions.onToggleVisibility,
          enabled: context.hasSelection,
        ),
      ],
    );
  }

  MenuBarSection _buildVectorMenu() {
    return MenuBarSection(
      id: 'vector',
      label: 'Vector',
      items: [
        MenuBarItem(
          id: 'flatten',
          label: 'Flatten',
          shortcut: '⌘E',
          onTap: actions.onFlatten,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'outline_stroke',
          label: 'Outline stroke',
          shortcut: '⌘O',
          onTap: actions.onOutlineStroke,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem.submenu(
          id: 'boolean_operation',
          label: 'Boolean operation',
          enabled: context.hasMultipleSelection,
          submenu: [
            MenuBarItem(
              id: 'union',
              label: 'Union',
              shortcut: '⌥⌘U',
              onTap: actions.onBooleanUnion,
            ),
            MenuBarItem(
              id: 'subtract',
              label: 'Subtract',
              shortcut: '⌥⌘S',
              onTap: actions.onBooleanSubtract,
            ),
            MenuBarItem(
              id: 'intersect',
              label: 'Intersect',
              shortcut: '⌥⌘I',
              onTap: actions.onBooleanIntersect,
            ),
            MenuBarItem(
              id: 'exclude',
              label: 'Exclude',
              shortcut: '⌥⌘X',
              onTap: actions.onBooleanExclude,
            ),
          ],
        ),
      ],
    );
  }

  MenuBarSection _buildTextMenu() {
    return MenuBarSection(
      id: 'text',
      label: 'Text',
      items: [
        MenuBarItem(
          id: 'bold',
          label: 'Bold',
          shortcut: '⌘B',
          onTap: actions.onBold,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'italic',
          label: 'Italic',
          shortcut: '⌘I',
          onTap: actions.onItalic,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'underline',
          label: 'Underline',
          shortcut: '⌘U',
          onTap: actions.onUnderline,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'strikethrough',
          label: 'Strikethrough',
          onTap: actions.onStrikethrough,
          enabled: context.isTextSelected,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'align_left',
          label: 'Align left',
          onTap: actions.onAlignLeft,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'align_center',
          label: 'Align center',
          onTap: actions.onAlignCenter,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'align_right',
          label: 'Align right',
          onTap: actions.onAlignRight,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'justify',
          label: 'Justify',
          onTap: actions.onAlignJustify,
          enabled: context.isTextSelected,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'uppercase',
          label: 'Convert to uppercase',
          onTap: actions.onConvertToUppercase,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'lowercase',
          label: 'Convert to lowercase',
          onTap: actions.onConvertToLowercase,
          enabled: context.isTextSelected,
        ),
        MenuBarItem(
          id: 'titlecase',
          label: 'Convert to title case',
          onTap: actions.onConvertToTitleCase,
          enabled: context.isTextSelected,
        ),
      ],
    );
  }

  MenuBarSection _buildArrangeMenu() {
    return MenuBarSection(
      id: 'arrange',
      label: 'Arrange',
      items: [
        MenuBarItem(
          id: 'bring_to_front',
          label: 'Bring to front',
          shortcut: ']',
          onTap: actions.onBringToFront,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'bring_forward',
          label: 'Bring forward',
          shortcut: '⌘]',
          onTap: actions.onBringForward,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'send_backward',
          label: 'Send backward',
          shortcut: '⌘[',
          onTap: actions.onSendBackward,
          enabled: context.hasSelection,
        ),
        MenuBarItem(
          id: 'send_to_back',
          label: 'Send to back',
          shortcut: '[',
          onTap: actions.onSendToBack,
          enabled: context.hasSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'align_left_edge',
          label: 'Align left',
          onTap: actions.onAlignLeftEdge,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'align_right_edge',
          label: 'Align right',
          onTap: actions.onAlignRightEdge,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'align_top_edge',
          label: 'Align top',
          onTap: actions.onAlignTop,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'align_bottom_edge',
          label: 'Align bottom',
          onTap: actions.onAlignBottom,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'align_horizontal_center',
          label: 'Align horizontal center',
          onTap: actions.onAlignHorizontalCenter,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'align_vertical_center',
          label: 'Align vertical center',
          onTap: actions.onAlignVerticalCenter,
          enabled: context.hasMultipleSelection,
        ),
        const MenuBarItem.divider(),
        MenuBarItem(
          id: 'distribute_horizontal',
          label: 'Distribute horizontal spacing',
          onTap: actions.onDistributeHorizontal,
          enabled: context.hasMultipleSelection,
        ),
        MenuBarItem(
          id: 'distribute_vertical',
          label: 'Distribute vertical spacing',
          onTap: actions.onDistributeVertical,
          enabled: context.hasMultipleSelection,
        ),
      ],
    );
  }
}
