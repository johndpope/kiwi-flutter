/// Figma-style Context Menu Implementation
///
/// Provides dynamic, selection-aware right-click menus for layers, canvas, and assets.
/// Matches Figma's context menu structure with actions, shortcuts, and submenus.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Context menu colors matching Figma's dark theme
class ContextMenuColors {
  static const background = Color(0xFF2C2C2C);
  static const hoverBackground = Color(0xFF0D99FF);
  static const textColor = Color(0xFFFFFFFF);
  static const shortcutColor = Color(0xFF8C8C8C);
  static const disabledColor = Color(0xFF5C5C5C);
  static const dividerColor = Color(0xFF4A4A4A);
  static const submenuArrowColor = Color(0xFF8C8C8C);
}

/// Menu item types
enum MenuItemType {
  action,
  submenu,
  divider,
}

/// Context menu item configuration
class ContextMenuItem {
  final String label;
  final String? shortcut;
  final IconData? icon;
  final MenuItemType type;
  final VoidCallback? onTap;
  final List<ContextMenuItem>? submenu;
  final bool enabled;
  final String? id;

  const ContextMenuItem({
    required this.label,
    this.shortcut,
    this.icon,
    this.type = MenuItemType.action,
    this.onTap,
    this.submenu,
    this.enabled = true,
    this.id,
  });

  const ContextMenuItem.divider()
      : label = '',
        shortcut = null,
        icon = null,
        type = MenuItemType.divider,
        onTap = null,
        submenu = null,
        enabled = true,
        id = null;

  const ContextMenuItem.submenu({
    required this.label,
    required this.submenu,
    this.icon,
    this.enabled = true,
    this.id,
  })  : shortcut = null,
        type = MenuItemType.submenu,
        onTap = null;
}

/// Device preset for resize to device
class DevicePreset {
  final String name;
  final String category;
  final double width;
  final double height;
  final String? icon;

  const DevicePreset({
    required this.name,
    required this.category,
    required this.width,
    required this.height,
    this.icon,
  });
}

/// Default device presets matching Figma
class DevicePresets {
  static const List<DevicePreset> ios = [
    DevicePreset(name: 'iPhone 16 Pro Max', category: 'iOS', width: 440, height: 956),
    DevicePreset(name: 'iPhone 16 Pro', category: 'iOS', width: 402, height: 874),
    DevicePreset(name: 'iPhone 16 Plus', category: 'iOS', width: 430, height: 932),
    DevicePreset(name: 'iPhone 16', category: 'iOS', width: 393, height: 852),
    DevicePreset(name: 'iPhone 15 Pro Max', category: 'iOS', width: 430, height: 932),
    DevicePreset(name: 'iPhone 15 Pro', category: 'iOS', width: 393, height: 852),
    DevicePreset(name: 'iPhone 15', category: 'iOS', width: 393, height: 852),
    DevicePreset(name: 'iPhone SE', category: 'iOS', width: 375, height: 667),
    DevicePreset(name: 'iPad Pro 12.9"', category: 'iOS', width: 1024, height: 1366),
    DevicePreset(name: 'iPad Pro 11"', category: 'iOS', width: 834, height: 1194),
    DevicePreset(name: 'iPad Air', category: 'iOS', width: 820, height: 1180),
    DevicePreset(name: 'iPad Mini', category: 'iOS', width: 744, height: 1133),
  ];

  static const List<DevicePreset> android = [
    DevicePreset(name: 'Pixel 9 Pro XL', category: 'Android', width: 412, height: 915),
    DevicePreset(name: 'Pixel 9 Pro', category: 'Android', width: 411, height: 823),
    DevicePreset(name: 'Pixel 9', category: 'Android', width: 393, height: 785),
    DevicePreset(name: 'Samsung Galaxy S24 Ultra', category: 'Android', width: 412, height: 915),
    DevicePreset(name: 'Samsung Galaxy S24+', category: 'Android', width: 412, height: 915),
    DevicePreset(name: 'Samsung Galaxy S24', category: 'Android', width: 360, height: 780),
    DevicePreset(name: 'Android Large', category: 'Android', width: 360, height: 800),
    DevicePreset(name: 'Android Small', category: 'Android', width: 360, height: 640),
  ];

  static const List<DevicePreset> desktop = [
    DevicePreset(name: 'Desktop', category: 'Desktop', width: 1440, height: 1024),
    DevicePreset(name: 'MacBook Pro 16"', category: 'Desktop', width: 1728, height: 1117),
    DevicePreset(name: 'MacBook Pro 14"', category: 'Desktop', width: 1512, height: 982),
    DevicePreset(name: 'MacBook Air', category: 'Desktop', width: 1280, height: 832),
    DevicePreset(name: 'iMac 24"', category: 'Desktop', width: 2048, height: 1152),
    DevicePreset(name: 'Surface Pro 8', category: 'Desktop', width: 1368, height: 912),
  ];
}

/// Selection context for adapting menu items
class SelectionContext {
  final int selectedCount;
  final bool isGroupSelected;
  final bool isComponentSelected;
  final bool isInstanceSelected;
  final bool isTextSelected;
  final bool isVectorSelected;
  final bool isFrameSelected;
  final bool hasAutoLayout;
  final bool isLocked;
  final bool isHidden;
  final List<String> availablePages;
  final List<String> recentPlugins;
  final bool hasPrototype;
  final bool canInspect;

  const SelectionContext({
    this.selectedCount = 0,
    this.isGroupSelected = false,
    this.isComponentSelected = false,
    this.isInstanceSelected = false,
    this.isTextSelected = false,
    this.isVectorSelected = false,
    this.isFrameSelected = false,
    this.hasAutoLayout = false,
    this.isLocked = false,
    this.isHidden = false,
    this.availablePages = const [],
    this.recentPlugins = const [],
    this.hasPrototype = false,
    this.canInspect = true,
  });

  bool get hasSelection => selectedCount > 0;
  bool get isMultiSelection => selectedCount > 1;
}

/// Context menu action callbacks
class ContextMenuActions {
  // Copy/Paste actions
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onPasteHere;
  final VoidCallback? onPasteToReplace;
  final void Function(String format)? onCopyAs;
  final void Function(String format)? onPasteAs;

  // Ordering actions
  final VoidCallback? onBringToFront;
  final VoidCallback? onSendToBack;
  final VoidCallback? onBringForward;
  final VoidCallback? onSendBackward;

  // Grouping actions
  final VoidCallback? onGroup;
  final VoidCallback? onUngroup;
  final VoidCallback? onFrame;

  // Vector operations
  final VoidCallback? onFlatten;
  final VoidCallback? onOutlineStroke;
  final VoidCallback? onUseAsMask;
  final VoidCallback? onSetAsThumbnail;

  // Layout actions
  final VoidCallback? onRemoveAutoLayout;
  final VoidCallback? onAddAutoLayout;
  final VoidCallback? onWrapInContainer;

  // Component actions
  final VoidCallback? onCreateComponent;
  final VoidCallback? onDetachInstance;
  final VoidCallback? onResetInstance;
  final VoidCallback? onGoToMainComponent;
  final VoidCallback? onPushChangesToComponent;

  // Visibility/Lock actions
  final VoidCallback? onShowHide;
  final VoidCallback? onLockUnlock;

  // Transform actions
  final VoidCallback? onFlipHorizontal;
  final VoidCallback? onFlipVertical;
  final VoidCallback? onRotate90CW;
  final VoidCallback? onRotate90CCW;

  // General actions
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final void Function(String pageId)? onMoveToPage;
  final VoidCallback? onSelectParent;
  final VoidCallback? onSelectChildren;

  // Device actions
  final void Function(DevicePreset device)? onResizeToDevice;
  final VoidCallback? onPreviewOnDevice;

  // Development actions
  final VoidCallback? onInspect;
  final VoidCallback? onExportCode;
  final void Function(String language)? onCopyAsCode;
  final VoidCallback? onViewInDevMode;
  final VoidCallback? onOpenInPlayground;

  // Plugin actions
  final void Function(String pluginId)? onRunPlugin;
  final VoidCallback? onRunLastPlugin;
  final VoidCallback? onManagePlugins;
  final VoidCallback? onOpenPluginsMenu;

  // Prototype actions
  final VoidCallback? onAddInteraction;
  final VoidCallback? onRemoveInteractions;
  final VoidCallback? onPreviewPrototype;

  const ContextMenuActions({
    this.onCopy,
    this.onPaste,
    this.onPasteHere,
    this.onPasteToReplace,
    this.onCopyAs,
    this.onPasteAs,
    this.onBringToFront,
    this.onSendToBack,
    this.onBringForward,
    this.onSendBackward,
    this.onGroup,
    this.onUngroup,
    this.onFrame,
    this.onFlatten,
    this.onOutlineStroke,
    this.onUseAsMask,
    this.onSetAsThumbnail,
    this.onRemoveAutoLayout,
    this.onAddAutoLayout,
    this.onWrapInContainer,
    this.onCreateComponent,
    this.onDetachInstance,
    this.onResetInstance,
    this.onGoToMainComponent,
    this.onPushChangesToComponent,
    this.onShowHide,
    this.onLockUnlock,
    this.onFlipHorizontal,
    this.onFlipVertical,
    this.onRotate90CW,
    this.onRotate90CCW,
    this.onDelete,
    this.onRename,
    this.onDuplicate,
    this.onMoveToPage,
    this.onSelectParent,
    this.onSelectChildren,
    this.onResizeToDevice,
    this.onPreviewOnDevice,
    this.onInspect,
    this.onExportCode,
    this.onCopyAsCode,
    this.onViewInDevMode,
    this.onOpenInPlayground,
    this.onRunPlugin,
    this.onRunLastPlugin,
    this.onManagePlugins,
    this.onOpenPluginsMenu,
    this.onAddInteraction,
    this.onRemoveInteractions,
    this.onPreviewPrototype,
  });
}

/// Builds context menu items based on selection context
class ContextMenuBuilder {
  final SelectionContext context;
  final ContextMenuActions actions;

  ContextMenuBuilder({
    required this.context,
    required this.actions,
  });

  List<ContextMenuItem> build() {
    return [
      // Copy/Paste section
      ContextMenuItem(
        label: 'Copy',
        shortcut: '⌘C',
        onTap: actions.onCopy,
        enabled: context.hasSelection,
        id: 'copy',
      ),
      ContextMenuItem(
        label: 'Paste here',
        onTap: actions.onPasteHere,
        id: 'paste_here',
      ),
      ContextMenuItem(
        label: 'Paste to replace',
        shortcut: '⇧⌘R',
        onTap: actions.onPasteToReplace,
        enabled: context.hasSelection,
        id: 'paste_to_replace',
      ),
      ContextMenuItem.submenu(
        label: 'Copy/Paste as',
        submenu: [
          ContextMenuItem(
            label: 'Copy as PNG',
            shortcut: '⇧⌘C',
            onTap: () => actions.onCopyAs?.call('PNG'),
            id: 'copy_as_png',
          ),
          ContextMenuItem(
            label: 'Copy as SVG',
            onTap: () => actions.onCopyAs?.call('SVG'),
            id: 'copy_as_svg',
          ),
          ContextMenuItem(
            label: 'Copy as CSS',
            onTap: () => actions.onCopyAs?.call('CSS'),
            id: 'copy_as_css',
          ),
          const ContextMenuItem.divider(),
          ContextMenuItem(
            label: 'Paste as auto layout',
            onTap: () => actions.onPasteAs?.call('auto_layout'),
            id: 'paste_as_auto_layout',
          ),
        ],
        enabled: context.hasSelection,
        id: 'copy_paste_as',
      ),
      ContextMenuItem(
        label: 'Send to Figma Make',
        onTap: () {}, // AI feature placeholder
        enabled: context.hasSelection,
        id: 'send_to_figma_make',
      ),

      const ContextMenuItem.divider(),

      // Select/Move section
      ContextMenuItem.submenu(
        label: 'Select layer',
        submenu: [
          ContextMenuItem(
            label: 'Select parent',
            shortcut: '⎋',
            onTap: actions.onSelectParent,
            id: 'select_parent',
          ),
          ContextMenuItem(
            label: 'Select children',
            shortcut: '↵',
            onTap: actions.onSelectChildren,
            id: 'select_children',
          ),
        ],
        enabled: context.hasSelection,
        id: 'select_layer',
      ),
      ContextMenuItem.submenu(
        label: 'Move to page',
        submenu: context.availablePages.map((page) {
          return ContextMenuItem(
            label: page,
            onTap: () => actions.onMoveToPage?.call(page),
            id: 'move_to_$page',
          );
        }).toList(),
        enabled: context.hasSelection && context.availablePages.isNotEmpty,
        id: 'move_to_page',
      ),

      // Ordering section
      ContextMenuItem(
        label: 'Bring to front',
        shortcut: ']',
        onTap: actions.onBringToFront,
        enabled: context.hasSelection,
        id: 'bring_to_front',
      ),
      ContextMenuItem(
        label: 'Send to back',
        shortcut: '[',
        onTap: actions.onSendToBack,
        enabled: context.hasSelection,
        id: 'send_to_back',
      ),

      const ContextMenuItem.divider(),

      // Grouping section
      ContextMenuItem(
        label: 'Group selection',
        shortcut: '⌘G',
        onTap: actions.onGroup,
        enabled: context.selectedCount >= 2,
        id: 'group_selection',
      ),
      ContextMenuItem(
        label: 'Frame selection',
        shortcut: '⌥⌘G',
        onTap: actions.onFrame,
        enabled: context.hasSelection,
        id: 'frame_selection',
      ),
      ContextMenuItem(
        label: 'Ungroup',
        shortcut: '⌘⌫',
        onTap: actions.onUngroup,
        enabled: context.isGroupSelected || context.isFrameSelected,
        id: 'ungroup',
      ),

      // Vector operations section
      ContextMenuItem(
        label: 'Flatten',
        shortcut: '⌥⇧F',
        onTap: actions.onFlatten,
        enabled: context.hasSelection && (context.isVectorSelected || context.selectedCount > 1),
        id: 'flatten',
      ),
      ContextMenuItem(
        label: 'Outline stroke',
        shortcut: '⌥⌘O',
        onTap: actions.onOutlineStroke,
        enabled: context.hasSelection,
        id: 'outline_stroke',
      ),
      ContextMenuItem(
        label: 'Use as mask',
        shortcut: '⌃⌘M',
        onTap: actions.onUseAsMask,
        enabled: context.hasSelection,
        id: 'use_as_mask',
      ),
      ContextMenuItem(
        label: 'Set as thumbnail',
        onTap: actions.onSetAsThumbnail,
        enabled: context.hasSelection,
        id: 'set_as_thumbnail',
      ),

      const ContextMenuItem.divider(),

      // Layout section
      ContextMenuItem(
        label: 'Remove auto layout',
        shortcut: '⌥⇧A',
        onTap: actions.onRemoveAutoLayout,
        enabled: context.hasAutoLayout,
        id: 'remove_auto_layout',
      ),
      ContextMenuItem.submenu(
        label: 'More layout options',
        submenu: [
          ContextMenuItem(
            label: 'Add auto layout',
            shortcut: '⇧A',
            onTap: () {},
            id: 'add_auto_layout',
          ),
          ContextMenuItem(
            label: 'Wrap in container',
            onTap: () {},
            id: 'wrap_in_container',
          ),
        ],
        enabled: context.hasSelection,
        id: 'more_layout_options',
      ),

      // Component section
      ContextMenuItem(
        label: 'Create component',
        shortcut: '⌥⌘K',
        onTap: actions.onCreateComponent,
        enabled: context.hasSelection && !context.isComponentSelected,
        id: 'create_component',
      ),
      if (context.isInstanceSelected) ...[
        ContextMenuItem(
          label: 'Detach instance',
          shortcut: '⌥⌘B',
          onTap: actions.onDetachInstance,
          id: 'detach_instance',
        ),
        ContextMenuItem(
          label: 'Reset instance',
          onTap: actions.onResetInstance,
          id: 'reset_instance',
        ),
        ContextMenuItem(
          label: 'Go to main component',
          onTap: actions.onGoToMainComponent,
          id: 'go_to_main_component',
        ),
      ],

      const ContextMenuItem.divider(),

      // Device section - resize to device dimensions
      ContextMenuItem.submenu(
        label: 'Device',
        submenu: [
          ContextMenuItem.submenu(
            label: 'iOS',
            submenu: DevicePresets.ios.asMap().entries.map((entry) => ContextMenuItem(
              label: '${entry.value.name} (${entry.value.width.toInt()}×${entry.value.height.toInt()})',
              onTap: () => actions.onResizeToDevice?.call(entry.value),
              id: 'device_ios_${entry.key}',
            )).toList(),
            id: 'device_ios',
          ),
          ContextMenuItem.submenu(
            label: 'Android',
            submenu: DevicePresets.android.asMap().entries.map((entry) => ContextMenuItem(
              label: '${entry.value.name} (${entry.value.width.toInt()}×${entry.value.height.toInt()})',
              onTap: () => actions.onResizeToDevice?.call(entry.value),
              id: 'device_android_${entry.key}',
            )).toList(),
            id: 'device_android',
          ),
          ContextMenuItem.submenu(
            label: 'Desktop',
            submenu: DevicePresets.desktop.asMap().entries.map((entry) => ContextMenuItem(
              label: '${entry.value.name} (${entry.value.width.toInt()}×${entry.value.height.toInt()})',
              onTap: () => actions.onResizeToDevice?.call(entry.value),
              id: 'device_desktop_${entry.key}',
            )).toList(),
            id: 'device_desktop',
          ),
          const ContextMenuItem.divider(),
          ContextMenuItem(
            label: 'Preview on device...',
            onTap: actions.onPreviewOnDevice,
            enabled: context.hasSelection,
            id: 'preview_on_device',
          ),
        ],
        enabled: context.isFrameSelected,
        id: 'device',
      ),

      // Development section
      ContextMenuItem.submenu(
        label: 'Development',
        submenu: [
          ContextMenuItem(
            label: 'Inspect',
            shortcut: '⌥⌘I',
            onTap: actions.onInspect,
            enabled: context.canInspect,
            id: 'inspect',
          ),
          const ContextMenuItem.divider(),
          ContextMenuItem(
            label: 'Export code...',
            onTap: actions.onExportCode,
            enabled: context.hasSelection,
            id: 'export_code',
          ),
          ContextMenuItem.submenu(
            label: 'Copy as code',
            submenu: [
              ContextMenuItem(
                label: 'Flutter',
                onTap: () => actions.onCopyAsCode?.call('flutter'),
                id: 'copy_as_flutter',
              ),
              ContextMenuItem(
                label: 'SwiftUI',
                onTap: () => actions.onCopyAsCode?.call('swiftui'),
                id: 'copy_as_swiftui',
              ),
              ContextMenuItem(
                label: 'React',
                onTap: () => actions.onCopyAsCode?.call('react'),
                id: 'copy_as_react',
              ),
              ContextMenuItem(
                label: 'HTML/CSS',
                onTap: () => actions.onCopyAsCode?.call('html_css'),
                id: 'copy_as_html_css',
              ),
              ContextMenuItem(
                label: 'Tailwind CSS',
                onTap: () => actions.onCopyAsCode?.call('tailwind'),
                id: 'copy_as_tailwind',
              ),
            ],
            enabled: context.hasSelection,
            id: 'copy_as_code',
          ),
          const ContextMenuItem.divider(),
          ContextMenuItem(
            label: 'View in Dev Mode',
            onTap: actions.onViewInDevMode,
            id: 'view_in_dev_mode',
          ),
          ContextMenuItem(
            label: 'Open in Playground',
            onTap: actions.onOpenInPlayground,
            enabled: context.hasSelection,
            id: 'open_in_playground',
          ),
        ],
        id: 'development',
      ),

      // Plugins/Widgets section
      ContextMenuItem.submenu(
        label: 'Plugins',
        submenu: [
          ContextMenuItem(
            label: 'Run last plugin',
            shortcut: '⌥⌘P',
            onTap: actions.onRunLastPlugin,
            id: 'run_last_plugin',
          ),
          if (context.recentPlugins.isNotEmpty) ...[
            const ContextMenuItem.divider(),
            ...context.recentPlugins.take(5).map((plugin) => ContextMenuItem(
              label: plugin,
              onTap: () => actions.onRunPlugin?.call(plugin),
              id: 'plugin_$plugin',
            )),
          ],
          const ContextMenuItem.divider(),
          ContextMenuItem(
            label: 'Manage plugins...',
            onTap: actions.onManagePlugins,
            id: 'manage_plugins',
          ),
        ],
        id: 'plugins',
      ),
      ContextMenuItem.submenu(
        label: 'Widgets',
        submenu: [
          ContextMenuItem(
            label: 'Insert widget...',
            onTap: () {},
            id: 'insert_widget',
          ),
        ],
        id: 'widgets',
      ),

      // Prototype section (if applicable)
      if (context.hasPrototype || context.isFrameSelected) ...[
        const ContextMenuItem.divider(),
        ContextMenuItem.submenu(
          label: 'Prototype',
          submenu: [
            ContextMenuItem(
              label: 'Add interaction',
              onTap: actions.onAddInteraction,
              enabled: context.hasSelection,
              id: 'add_interaction',
            ),
            ContextMenuItem(
              label: 'Remove all interactions',
              onTap: actions.onRemoveInteractions,
              enabled: context.hasPrototype,
              id: 'remove_interactions',
            ),
            const ContextMenuItem.divider(),
            ContextMenuItem(
              label: 'Preview prototype',
              shortcut: '⌥⌘↵',
              onTap: actions.onPreviewPrototype,
              id: 'preview_prototype',
            ),
          ],
          id: 'prototype',
        ),
      ],

      const ContextMenuItem.divider(),

      // Visibility/Lock section
      ContextMenuItem(
        label: context.isHidden ? 'Show' : 'Hide',
        shortcut: '⇧⌘H',
        onTap: actions.onShowHide,
        enabled: context.hasSelection,
        id: 'show_hide',
      ),
      ContextMenuItem(
        label: context.isLocked ? 'Unlock' : 'Lock',
        shortcut: '⇧⌘L',
        onTap: actions.onLockUnlock,
        enabled: context.hasSelection,
        id: 'lock_unlock',
      ),

      const ContextMenuItem.divider(),

      // Flip section
      ContextMenuItem(
        label: 'Flip horizontal',
        shortcut: '⇧H',
        onTap: actions.onFlipHorizontal,
        enabled: context.hasSelection,
        id: 'flip_horizontal',
      ),
      ContextMenuItem(
        label: 'Flip vertical',
        shortcut: '⇧V',
        onTap: actions.onFlipVertical,
        enabled: context.hasSelection,
        id: 'flip_vertical',
      ),
    ];
  }
}

/// Main context menu widget
class FigmaContextMenu extends StatelessWidget {
  final List<ContextMenuItem> items;
  final VoidCallback onDismiss;

  const FigmaContextMenu({
    super.key,
    required this.items,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        decoration: BoxDecoration(
          color: ContextMenuColors.background,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                for (final item in items) _buildMenuItem(context, item),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, ContextMenuItem item) {
    if (item.type == MenuItemType.divider) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Container(
          height: 1,
          color: ContextMenuColors.dividerColor,
        ),
      );
    }

    return _ContextMenuItemWidget(
      item: item,
      onDismiss: onDismiss,
    );
  }
}

class _ContextMenuItemWidget extends StatefulWidget {
  final ContextMenuItem item;
  final VoidCallback onDismiss;

  const _ContextMenuItemWidget({
    required this.item,
    required this.onDismiss,
  });

  @override
  State<_ContextMenuItemWidget> createState() => _ContextMenuItemWidgetState();
}

class _ContextMenuItemWidgetState extends State<_ContextMenuItemWidget> {
  bool _isHovered = false;
  OverlayEntry? _submenuOverlay;

  @override
  void dispose() {
    _hideSubmenu();
    super.dispose();
  }

  void _showSubmenu(BuildContext context) {
    if (widget.item.submenu == null || !widget.item.enabled) return;

    _hideSubmenu();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _submenuOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx + size.width - 4,
        top: position.dy - 4,
        child: _SubmenuWidget(
          items: widget.item.submenu!,
          onDismiss: () {
            _hideSubmenu();
            widget.onDismiss();
          },
        ),
      ),
    );

    Overlay.of(context).insert(_submenuOverlay!);
  }

  void _hideSubmenu() {
    _submenuOverlay?.remove();
    _submenuOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final isSubmenu = widget.item.type == MenuItemType.submenu;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (isSubmenu) {
          _showSubmenu(context);
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        // Delay hiding submenu to allow mouse to move to it
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isHovered) {
            _hideSubmenu();
          }
        });
      },
      child: GestureDetector(
        onTap: widget.item.enabled && !isSubmenu
            ? () {
                widget.item.onTap?.call();
                widget.onDismiss();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _isHovered && widget.item.enabled
              ? ContextMenuColors.hoverBackground
              : Colors.transparent,
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(
                  widget.item.icon,
                  size: 14,
                  color: widget.item.enabled
                      ? ContextMenuColors.textColor
                      : ContextMenuColors.disabledColor,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: widget.item.enabled
                        ? ContextMenuColors.textColor
                        : ContextMenuColors.disabledColor,
                    fontSize: 12,
                  ),
                ),
              ),
              if (widget.item.shortcut != null)
                Text(
                  widget.item.shortcut!,
                  style: TextStyle(
                    color: widget.item.enabled
                        ? ContextMenuColors.shortcutColor
                        : ContextMenuColors.disabledColor,
                    fontSize: 11,
                  ),
                ),
              if (isSubmenu)
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: widget.item.enabled
                      ? ContextMenuColors.submenuArrowColor
                      : ContextMenuColors.disabledColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmenuWidget extends StatelessWidget {
  final List<ContextMenuItem> items;
  final VoidCallback onDismiss;

  const _SubmenuWidget({
    required this.items,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return FigmaContextMenu(
      items: items,
      onDismiss: onDismiss,
    );
  }
}

/// Shows the context menu at the given position
Future<void> showFigmaContextMenu({
  required BuildContext context,
  required Offset position,
  required List<ContextMenuItem> items,
}) async {
  final overlay = Overlay.of(context);
  OverlayEntry? entry;

  void dismiss() {
    entry?.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        // Dismiss on tap outside
        Positioned.fill(
          child: GestureDetector(
            onTap: dismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          left: position.dx,
          top: position.dy,
          child: FigmaContextMenu(
            items: items,
            onDismiss: dismiss,
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry);
}

/// Gesture detector that shows context menu on right-click
class ContextMenuRegion extends StatelessWidget {
  final Widget child;
  final SelectionContext selectionContext;
  final ContextMenuActions actions;

  const ContextMenuRegion({
    super.key,
    required this.child,
    required this.selectionContext,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        final menuBuilder = ContextMenuBuilder(
          context: selectionContext,
          actions: actions,
        );
        showFigmaContextMenu(
          context: context,
          position: details.globalPosition,
          items: menuBuilder.build(),
        );
      },
      child: child,
    );
  }
}

/// Keyboard shortcuts for context menu actions
class ContextMenuShortcuts extends StatelessWidget {
  final Widget child;
  final ContextMenuActions actions;

  const ContextMenuShortcuts({
    super.key,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Copy/Paste shortcuts
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyC): const _CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): const _PasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR): const _PasteToReplaceIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD): const _DuplicateIntent(),
        LogicalKeySet(LogicalKeyboardKey.backspace): const _DeleteIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): const _DeleteIntent(),

        // Grouping shortcuts
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyG): const _GroupIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyG): const _FrameIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.backspace): const _UngroupIntent(),

        // Ordering shortcuts
        LogicalKeySet(LogicalKeyboardKey.bracketRight): const _BringToFrontIntent(),
        LogicalKeySet(LogicalKeyboardKey.bracketLeft): const _SendToBackIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketRight): const _BringForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketLeft): const _SendBackwardIntent(),

        // Visibility/Lock shortcuts
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyH): const _ShowHideIntent(),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyL): const _LockUnlockIntent(),

        // Transform shortcuts
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyH): const _FlipHorizontalIntent(),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyV): const _FlipVerticalIntent(),

        // Component shortcuts
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK): const _CreateComponentIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB): const _DetachInstanceIntent(),

        // Layout shortcuts
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyA): const _AddAutoLayoutIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyA): const _RemoveAutoLayoutIntent(),

        // Development shortcuts
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyI): const _InspectIntent(),

        // Plugin shortcuts
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP): const _RunLastPluginIntent(),

        // Prototype shortcuts
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.meta, LogicalKeyboardKey.enter): const _PreviewPrototypeIntent(),

        // Rename shortcut
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR): const _RenameIntent(),
      },
      child: Actions(
        actions: {
          // Copy/Paste actions
          _CopyIntent: CallbackAction<_CopyIntent>(onInvoke: (_) => actions.onCopy?.call()),
          _PasteIntent: CallbackAction<_PasteIntent>(onInvoke: (_) => actions.onPaste?.call()),
          _PasteToReplaceIntent: CallbackAction<_PasteToReplaceIntent>(onInvoke: (_) => actions.onPasteToReplace?.call()),
          _DuplicateIntent: CallbackAction<_DuplicateIntent>(onInvoke: (_) => actions.onDuplicate?.call()),
          _DeleteIntent: CallbackAction<_DeleteIntent>(onInvoke: (_) => actions.onDelete?.call()),

          // Grouping actions
          _GroupIntent: CallbackAction<_GroupIntent>(onInvoke: (_) => actions.onGroup?.call()),
          _FrameIntent: CallbackAction<_FrameIntent>(onInvoke: (_) => actions.onFrame?.call()),
          _UngroupIntent: CallbackAction<_UngroupIntent>(onInvoke: (_) => actions.onUngroup?.call()),

          // Ordering actions
          _BringToFrontIntent: CallbackAction<_BringToFrontIntent>(onInvoke: (_) => actions.onBringToFront?.call()),
          _SendToBackIntent: CallbackAction<_SendToBackIntent>(onInvoke: (_) => actions.onSendToBack?.call()),
          _BringForwardIntent: CallbackAction<_BringForwardIntent>(onInvoke: (_) => actions.onBringForward?.call()),
          _SendBackwardIntent: CallbackAction<_SendBackwardIntent>(onInvoke: (_) => actions.onSendBackward?.call()),

          // Visibility/Lock actions
          _ShowHideIntent: CallbackAction<_ShowHideIntent>(onInvoke: (_) => actions.onShowHide?.call()),
          _LockUnlockIntent: CallbackAction<_LockUnlockIntent>(onInvoke: (_) => actions.onLockUnlock?.call()),

          // Transform actions
          _FlipHorizontalIntent: CallbackAction<_FlipHorizontalIntent>(onInvoke: (_) => actions.onFlipHorizontal?.call()),
          _FlipVerticalIntent: CallbackAction<_FlipVerticalIntent>(onInvoke: (_) => actions.onFlipVertical?.call()),

          // Component actions
          _CreateComponentIntent: CallbackAction<_CreateComponentIntent>(onInvoke: (_) => actions.onCreateComponent?.call()),
          _DetachInstanceIntent: CallbackAction<_DetachInstanceIntent>(onInvoke: (_) => actions.onDetachInstance?.call()),

          // Layout actions
          _AddAutoLayoutIntent: CallbackAction<_AddAutoLayoutIntent>(onInvoke: (_) => actions.onAddAutoLayout?.call()),
          _RemoveAutoLayoutIntent: CallbackAction<_RemoveAutoLayoutIntent>(onInvoke: (_) => actions.onRemoveAutoLayout?.call()),

          // Development actions
          _InspectIntent: CallbackAction<_InspectIntent>(onInvoke: (_) => actions.onInspect?.call()),

          // Plugin actions
          _RunLastPluginIntent: CallbackAction<_RunLastPluginIntent>(onInvoke: (_) => actions.onRunLastPlugin?.call()),

          // Prototype actions
          _PreviewPrototypeIntent: CallbackAction<_PreviewPrototypeIntent>(onInvoke: (_) => actions.onPreviewPrototype?.call()),

          // Rename action
          _RenameIntent: CallbackAction<_RenameIntent>(onInvoke: (_) => actions.onRename?.call()),
        },
        child: child,
      ),
    );
  }
}

// Intent classes for keyboard shortcuts
// Copy/Paste intents
class _CopyIntent extends Intent { const _CopyIntent(); }
class _PasteIntent extends Intent { const _PasteIntent(); }
class _PasteToReplaceIntent extends Intent { const _PasteToReplaceIntent(); }
class _DuplicateIntent extends Intent { const _DuplicateIntent(); }
class _DeleteIntent extends Intent { const _DeleteIntent(); }

// Grouping intents
class _GroupIntent extends Intent { const _GroupIntent(); }
class _FrameIntent extends Intent { const _FrameIntent(); }
class _UngroupIntent extends Intent { const _UngroupIntent(); }

// Ordering intents
class _BringToFrontIntent extends Intent { const _BringToFrontIntent(); }
class _SendToBackIntent extends Intent { const _SendToBackIntent(); }
class _BringForwardIntent extends Intent { const _BringForwardIntent(); }
class _SendBackwardIntent extends Intent { const _SendBackwardIntent(); }

// Visibility/Lock intents
class _ShowHideIntent extends Intent { const _ShowHideIntent(); }
class _LockUnlockIntent extends Intent { const _LockUnlockIntent(); }

// Transform intents
class _FlipHorizontalIntent extends Intent { const _FlipHorizontalIntent(); }
class _FlipVerticalIntent extends Intent { const _FlipVerticalIntent(); }

// Component intents
class _CreateComponentIntent extends Intent { const _CreateComponentIntent(); }
class _DetachInstanceIntent extends Intent { const _DetachInstanceIntent(); }

// Layout intents
class _AddAutoLayoutIntent extends Intent { const _AddAutoLayoutIntent(); }
class _RemoveAutoLayoutIntent extends Intent { const _RemoveAutoLayoutIntent(); }

// Development intents
class _InspectIntent extends Intent { const _InspectIntent(); }

// Plugin intents
class _RunLastPluginIntent extends Intent { const _RunLastPluginIntent(); }

// Prototype intents
class _PreviewPrototypeIntent extends Intent { const _PreviewPrototypeIntent(); }

// General intents
class _RenameIntent extends Intent { const _RenameIntent(); }
