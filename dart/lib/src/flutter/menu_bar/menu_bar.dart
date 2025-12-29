/// Figma-style Menu Bar Implementation
///
/// Provides a top-level menu bar with File, Edit, View, Object, Vector, Text, Arrange menus.
/// Matches Figma's menu bar style and functionality.

import 'package:flutter/material.dart';
import 'menu_bar_state.dart';
import 'menu_bar_builder.dart';

/// Menu bar colors matching Figma's dark theme
class MenuBarColors {
  static const background = Color(0xFF2C2C2C);
  static const dropdownBackground = Color(0xFF2C2C2C);
  static const hoverBackground = Color(0xFF0D99FF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textShortcut = Color(0xFF8C8C8C);
  static const textDisabled = Color(0xFF5C5C5C);
  static const dividerColor = Color(0xFF4A4A4A);
  static const checkmarkColor = Color(0xFF0D99FF);
  static const topBarHover = Color(0xFF404040);
}

/// Menu bar item types
enum MenuBarItemType {
  action,
  submenu,
  divider,
  toggle,
}

/// A single menu bar item configuration
class MenuBarItem {
  final String label;
  final String? shortcut;
  final IconData? icon;
  final MenuBarItemType type;
  final VoidCallback? onTap;
  final List<MenuBarItem>? submenu;
  final bool enabled;
  final bool checked;
  final String? id;

  const MenuBarItem({
    this.label = '',
    this.shortcut,
    this.icon,
    this.type = MenuBarItemType.action,
    this.onTap,
    this.submenu,
    this.enabled = true,
    this.checked = false,
    this.id,
  });

  /// Creates a divider item
  const MenuBarItem.divider()
      : label = '',
        shortcut = null,
        icon = null,
        type = MenuBarItemType.divider,
        onTap = null,
        submenu = null,
        enabled = true,
        checked = false,
        id = null;

  /// Creates a submenu item
  const MenuBarItem.submenu({
    required this.label,
    required this.submenu,
    this.icon,
    this.enabled = true,
    this.id,
  })  : shortcut = null,
        type = MenuBarItemType.submenu,
        onTap = null,
        checked = false;

  /// Creates a toggle item (with checkmark)
  const MenuBarItem.toggle({
    required this.label,
    required this.checked,
    this.shortcut,
    this.onTap,
    this.enabled = true,
    this.id,
  })  : icon = null,
        type = MenuBarItemType.toggle,
        submenu = null;
}

/// A top-level menu section (File, Edit, View, etc.)
class MenuBarSection {
  final String label;
  final List<MenuBarItem> items;
  final String id;

  const MenuBarSection({
    required this.label,
    required this.items,
    required this.id,
  });
}

/// Main Menu Bar Widget
class FigmaMenuBar extends StatefulWidget {
  final MenuBarState state;
  final List<MenuBarSection> sections;
  final double height;

  const FigmaMenuBar({
    super.key,
    required this.state,
    this.sections = const [],
    this.height = 32,
  });

  @override
  State<FigmaMenuBar> createState() => _FigmaMenuBarState();
}

class _FigmaMenuBarState extends State<FigmaMenuBar> {
  OverlayEntry? _dropdownOverlay;
  late List<MenuBarSection> _effectiveSections;

  @override
  void initState() {
    super.initState();
    _effectiveSections = widget.sections.isNotEmpty
        ? widget.sections
        : DefaultMenuBarSections.all;
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _hideDropdown();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {
      if (widget.state.openMenuId == null) {
        _hideDropdown();
      }
    });
  }

  void _hideDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  void _showDropdown(BuildContext itemContext, MenuBarSection section) {
    _hideDropdown();

    final RenderBox renderBox = itemContext.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _dropdownOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss area
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                widget.state.closeMenu();
              },
            ),
          ),
          // Dropdown menu
          Positioned(
            left: position.dx,
            top: position.dy + size.height,
            child: _MenuDropdown(
              items: section.items,
              onDismiss: () {
                widget.state.closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(itemContext).insert(_dropdownOverlay!);
    widget.state.openMenu(section.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      color: MenuBarColors.background,
      child: Row(
        children: [
          // Figma logo/icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.layers,
              size: 18,
              color: MenuBarColors.textPrimary,
            ),
          ),
          // Menu items
          ..._effectiveSections.map((section) => _buildMenuButton(section)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMenuButton(MenuBarSection section) {
    final isOpen = widget.state.openMenuId == section.id;

    return Builder(
      builder: (context) {
        return _HoverMenuButton(
          label: section.label,
          isOpen: isOpen,
          onTap: () {
            if (isOpen) {
              widget.state.closeMenu();
            } else {
              _showDropdown(context, section);
            }
          },
          onHover: (hovering) {
            // If another menu is open, hovering opens this menu
            if (hovering && widget.state.openMenuId != null && widget.state.openMenuId != section.id) {
              _showDropdown(context, section);
            }
          },
        );
      },
    );
  }
}

/// Hover button for top-level menu items
class _HoverMenuButton extends StatefulWidget {
  final String label;
  final bool isOpen;
  final VoidCallback onTap;
  final void Function(bool) onHover;

  const _HoverMenuButton({
    required this.label,
    required this.isOpen,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<_HoverMenuButton> createState() => _HoverMenuButtonState();
}

class _HoverMenuButtonState extends State<_HoverMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isOpen || _isHovered;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHover(false);
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: showHighlight ? MenuBarColors.topBarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: MenuBarColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown menu widget
class _MenuDropdown extends StatelessWidget {
  final List<MenuBarItem> items;
  final VoidCallback onDismiss;

  const _MenuDropdown({
    required this.items,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
        decoration: BoxDecoration(
          color: MenuBarColors.dropdownBackground,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items.map((item) => _buildItem(item)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(MenuBarItem item) {
    if (item.type == MenuBarItemType.divider) {
      return Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        color: MenuBarColors.dividerColor,
      );
    }

    return _MenuItemWidget(
      item: item,
      onDismiss: onDismiss,
    );
  }
}

/// Individual menu item widget
class _MenuItemWidget extends StatefulWidget {
  final MenuBarItem item;
  final VoidCallback onDismiss;

  const _MenuItemWidget({
    required this.item,
    required this.onDismiss,
  });

  @override
  State<_MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<_MenuItemWidget> {
  bool _isHovered = false;
  OverlayEntry? _submenuOverlay;

  @override
  void dispose() {
    _hideSubmenu();
    super.dispose();
  }

  void _hideSubmenu() {
    _submenuOverlay?.remove();
    _submenuOverlay = null;
  }

  void _showSubmenu(BuildContext context) {
    _hideSubmenu();

    if (widget.item.submenu == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _submenuOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx + size.width - 4,
        top: position.dy - 6,
        child: _MenuDropdown(
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

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.item.enabled;
    final isSubmenu = widget.item.type == MenuBarItemType.submenu;
    final isToggle = widget.item.type == MenuBarItemType.toggle;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (isSubmenu) {
          _showSubmenu(context);
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        // Delay hiding submenu to allow mouse movement
        if (isSubmenu) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!_isHovered) {
              _hideSubmenu();
            }
          });
        }
      },
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isEnabled && !isSubmenu
            ? () {
                widget.item.onTap?.call();
                widget.onDismiss();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _isHovered && isEnabled
              ? MenuBarColors.hoverBackground
              : Colors.transparent,
          child: Row(
            children: [
              // Checkmark for toggle items
              SizedBox(
                width: 20,
                child: isToggle && widget.item.checked
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: _isHovered
                            ? MenuBarColors.textPrimary
                            : MenuBarColors.checkmarkColor,
                      )
                    : null,
              ),
              // Label
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: isEnabled
                        ? (_isHovered
                            ? MenuBarColors.textPrimary
                            : MenuBarColors.textPrimary)
                        : MenuBarColors.textDisabled,
                    fontSize: 12,
                  ),
                ),
              ),
              // Shortcut or submenu arrow
              if (widget.item.shortcut != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    widget.item.shortcut!,
                    style: TextStyle(
                      color: isEnabled
                          ? (_isHovered
                              ? MenuBarColors.textPrimary
                              : MenuBarColors.textShortcut)
                          : MenuBarColors.textDisabled,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (isSubmenu)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: isEnabled
                        ? MenuBarColors.textShortcut
                        : MenuBarColors.textDisabled,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
