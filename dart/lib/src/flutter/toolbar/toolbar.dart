/// Figma-style Toolbar Implementation
///
/// Provides a central hub for accessing core design tools, modes, and actions.
/// Matches Figma's toolbar structure with tool icons, dropdowns, and shortcuts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Available design tools in the toolbar
enum DesignTool {
  move,
  scale,
  hand,
  frame,
  section,
  slice,
  rectangle,
  line,
  arrow,
  ellipse,
  polygon,
  star,
  pen,
  pencil,
  text,
  resources,
  comment,
}

/// Design modes (tabs)
enum DesignMode {
  design,
  prototype,
  dev,
}

/// Toolbar state management
class ToolbarState extends ChangeNotifier {
  DesignTool _activeTool = DesignTool.move;
  DesignMode _activeMode = DesignMode.design;
  bool _isToolbarVisible = true;
  Set<DesignTool> _pinnedTools = {};

  DesignTool get activeTool => _activeTool;
  DesignMode get activeMode => _activeMode;
  bool get isToolbarVisible => _isToolbarVisible;
  Set<DesignTool> get pinnedTools => _pinnedTools;

  void setTool(DesignTool tool) {
    if (_activeTool != tool) {
      _activeTool = tool;
      notifyListeners();
    }
  }

  void setMode(DesignMode mode) {
    if (_activeMode != mode) {
      _activeMode = mode;
      notifyListeners();
    }
  }

  void toggleToolbarVisibility() {
    _isToolbarVisible = !_isToolbarVisible;
    notifyListeners();
  }

  void pinTool(DesignTool tool) {
    _pinnedTools.add(tool);
    notifyListeners();
  }

  void unpinTool(DesignTool tool) {
    _pinnedTools.remove(tool);
    notifyListeners();
  }
}

/// Tool configuration with icon, shortcut, and dropdown items
class ToolConfig {
  final DesignTool tool;
  final IconData icon;
  final String label;
  final String shortcut;
  final List<ToolConfig>? dropdownItems;

  const ToolConfig({
    required this.tool,
    required this.icon,
    required this.label,
    required this.shortcut,
    this.dropdownItems,
  });
}

/// Predefined tool configurations matching Figma
class ToolConfigs {
  static const moveTools = ToolConfig(
    tool: DesignTool.move,
    icon: Icons.near_me,
    label: 'Move',
    shortcut: 'V',
    dropdownItems: [
      ToolConfig(tool: DesignTool.move, icon: Icons.near_me, label: 'Move', shortcut: 'V'),
      ToolConfig(tool: DesignTool.scale, icon: Icons.open_in_full, label: 'Scale', shortcut: 'K'),
      ToolConfig(tool: DesignTool.hand, icon: Icons.pan_tool, label: 'Hand tool', shortcut: 'H'),
    ],
  );

  static const frameTools = ToolConfig(
    tool: DesignTool.frame,
    icon: Icons.grid_3x3,
    label: 'Frame',
    shortcut: 'F',
    dropdownItems: [
      ToolConfig(tool: DesignTool.frame, icon: Icons.grid_3x3, label: 'Frame', shortcut: 'F'),
      ToolConfig(tool: DesignTool.section, icon: Icons.view_agenda, label: 'Section', shortcut: 'Shift+S'),
      ToolConfig(tool: DesignTool.slice, icon: Icons.crop, label: 'Slice', shortcut: 'S'),
    ],
  );

  static const shapeTools = ToolConfig(
    tool: DesignTool.rectangle,
    icon: Icons.crop_square,
    label: 'Rectangle',
    shortcut: 'R',
    dropdownItems: [
      ToolConfig(tool: DesignTool.rectangle, icon: Icons.crop_square, label: 'Rectangle', shortcut: 'R'),
      ToolConfig(tool: DesignTool.line, icon: Icons.remove, label: 'Line', shortcut: 'L'),
      ToolConfig(tool: DesignTool.arrow, icon: Icons.arrow_forward, label: 'Arrow', shortcut: 'Shift+L'),
      ToolConfig(tool: DesignTool.ellipse, icon: Icons.circle_outlined, label: 'Ellipse', shortcut: 'O'),
      ToolConfig(tool: DesignTool.polygon, icon: Icons.hexagon_outlined, label: 'Polygon', shortcut: ''),
      ToolConfig(tool: DesignTool.star, icon: Icons.star_border, label: 'Star', shortcut: ''),
    ],
  );

  static const penTools = ToolConfig(
    tool: DesignTool.pen,
    icon: Icons.edit,
    label: 'Pen',
    shortcut: 'P',
    dropdownItems: [
      ToolConfig(tool: DesignTool.pen, icon: Icons.edit, label: 'Pen', shortcut: 'P'),
      ToolConfig(tool: DesignTool.pencil, icon: Icons.brush, label: 'Pencil', shortcut: 'Shift+P'),
    ],
  );

  static const textTool = ToolConfig(
    tool: DesignTool.text,
    icon: Icons.text_fields,
    label: 'Text',
    shortcut: 'T',
  );

  static const resourcesTool = ToolConfig(
    tool: DesignTool.resources,
    icon: Icons.widgets,
    label: 'Resources',
    shortcut: 'Shift+I',
  );

  static const commentTool = ToolConfig(
    tool: DesignTool.comment,
    icon: Icons.chat_bubble_outline,
    label: 'Comment',
    shortcut: 'C',
  );

  static List<ToolConfig> get allTools => [
    moveTools,
    frameTools,
    shapeTools,
    penTools,
    textTool,
    resourcesTool,
    commentTool,
  ];
}

/// Figma-style colors for toolbar
class ToolbarColors {
  static const background = Color(0xFF2C2C2C);
  static const toolBackground = Color(0xFF383838);
  static const activeToolBackground = Color(0xFF0D99FF);
  static const iconColor = Color(0xFFFFFFFF);
  static const iconInactiveColor = Color(0xFFB3B3B3);
  static const dividerColor = Color(0xFF4A4A4A);
  static const hoverColor = Color(0xFF404040);
}

/// Main Toolbar Widget
class FigmaToolbar extends StatefulWidget {
  final ToolbarState state;
  final VoidCallback? onSharePressed;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onActionsPressed;

  const FigmaToolbar({
    super.key,
    required this.state,
    this.onSharePressed,
    this.onPlayPressed,
    this.onActionsPressed,
  });

  @override
  State<FigmaToolbar> createState() => _FigmaToolbarState();
}

class _FigmaToolbarState extends State<FigmaToolbar> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.isToolbarVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      color: ToolbarColors.background,
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Left section: Design tools
          _buildToolsSection(),
          const SizedBox(width: 16),
          // Divider
          Container(width: 1, height: 24, color: ToolbarColors.dividerColor),
          const SizedBox(width: 16),
          // Central section: Actions menu
          _buildActionsButton(),
          const Spacer(),
          // Right section: Mode toggles
          _buildModeToggles(),
          const SizedBox(width: 16),
          // Share and Play buttons
          _buildShareButton(),
          const SizedBox(width: 8),
          _buildPlayButton(),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildToolsSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final config in ToolConfigs.allTools) ...[
          _ToolButton(
            config: config,
            isActive: _isToolActive(config),
            onTap: () => widget.state.setTool(config.tool),
            onDropdownSelect: (tool) => widget.state.setTool(tool),
          ),
          const SizedBox(width: 2),
        ],
      ],
    );
  }

  bool _isToolActive(ToolConfig config) {
    if (widget.state.activeTool == config.tool) return true;
    if (config.dropdownItems != null) {
      return config.dropdownItems!.any((item) => item.tool == widget.state.activeTool);
    }
    return false;
  }

  Widget _buildActionsButton() {
    return _HoverButton(
      onTap: widget.onActionsPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ToolbarColors.toolBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: ToolbarColors.iconColor),
            const SizedBox(width: 6),
            Text(
              'Actions',
              style: TextStyle(color: ToolbarColors.iconColor, fontSize: 12),
            ),
            const SizedBox(width: 4),
            Text(
              '⌘K',
              style: TextStyle(color: ToolbarColors.iconInactiveColor, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggles() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ToolbarColors.toolBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeToggle(
            icon: Icons.edit_outlined,
            label: 'Design',
            isActive: widget.state.activeMode == DesignMode.design,
            onTap: () => widget.state.setMode(DesignMode.design),
          ),
          _ModeToggle(
            icon: Icons.play_arrow_outlined,
            label: 'Prototype',
            isActive: widget.state.activeMode == DesignMode.prototype,
            onTap: () => widget.state.setMode(DesignMode.prototype),
          ),
          _ModeToggle(
            icon: Icons.code,
            label: 'Dev',
            isActive: widget.state.activeMode == DesignMode.dev,
            onTap: () => widget.state.setMode(DesignMode.dev),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return _HoverButton(
      onTap: widget.onSharePressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D99FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Share',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return _HoverButton(
      onTap: widget.onPlayPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: ToolbarColors.toolBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.play_arrow, size: 18, color: ToolbarColors.iconColor),
      ),
    );
  }
}

/// Individual tool button with optional dropdown
class _ToolButton extends StatefulWidget {
  final ToolConfig config;
  final bool isActive;
  final VoidCallback onTap;
  final void Function(DesignTool) onDropdownSelect;

  const _ToolButton({
    required this.config,
    required this.isActive,
    required this.onTap,
    required this.onDropdownSelect,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasDropdown = widget.config.dropdownItems != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: hasDropdown ? () => _showDropdown(context) : null,
        child: Tooltip(
          message: '${widget.config.label} (${widget.config.shortcut})',
          child: Container(
            width: hasDropdown ? 44 : 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? ToolbarColors.activeToolBackground
                  : (_isHovered ? ToolbarColors.hoverColor : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.config.icon,
                  size: 18,
                  color: widget.isActive ? Colors.white : ToolbarColors.iconColor,
                ),
                if (hasDropdown) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 12,
                    color: widget.isActive ? Colors.white : ToolbarColors.iconInactiveColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDropdown(BuildContext context) {
    final items = widget.config.dropdownItems!;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<DesignTool>(
      context: context,
      position: position,
      color: ToolbarColors.background,
      items: items.map((item) {
        return PopupMenuItem<DesignTool>(
          value: item.tool,
          child: Row(
            children: [
              Icon(item.icon, size: 16, color: ToolbarColors.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(color: ToolbarColors.iconColor, fontSize: 12),
                ),
              ),
              if (item.shortcut.isNotEmpty)
                Text(
                  item.shortcut,
                  style: TextStyle(color: ToolbarColors.iconInactiveColor, fontSize: 10),
                ),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        widget.onDropdownSelect(value);
      }
    });
  }
}

/// Mode toggle button (Design/Prototype/Dev)
class _ModeToggle extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeToggle({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ModeToggle> createState() => _ModeToggleState();
}

class _ModeToggleState extends State<_ModeToggle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? ToolbarColors.background
                : (_isHovered ? ToolbarColors.hoverColor : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isActive ? ToolbarColors.iconColor : ToolbarColors.iconInactiveColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive ? ToolbarColors.iconColor : ToolbarColors.iconInactiveColor,
                  fontSize: 11,
                  fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic hover button
class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverButton({required this.child, this.onTap});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: _isHovered ? 0.9 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Keyboard shortcuts handler for toolbar
class ToolbarShortcuts extends StatelessWidget {
  final Widget child;
  final ToolbarState state;

  const ToolbarShortcuts({
    super.key,
    required this.child,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Tool shortcuts
        LogicalKeySet(LogicalKeyboardKey.keyV): const _SetToolIntent(DesignTool.move),
        LogicalKeySet(LogicalKeyboardKey.keyK): const _SetToolIntent(DesignTool.scale),
        LogicalKeySet(LogicalKeyboardKey.keyH): const _SetToolIntent(DesignTool.hand),
        LogicalKeySet(LogicalKeyboardKey.keyF): const _SetToolIntent(DesignTool.frame),
        LogicalKeySet(LogicalKeyboardKey.keyR): const _SetToolIntent(DesignTool.rectangle),
        LogicalKeySet(LogicalKeyboardKey.keyL): const _SetToolIntent(DesignTool.line),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyL): const _SetToolIntent(DesignTool.arrow),
        LogicalKeySet(LogicalKeyboardKey.keyO): const _SetToolIntent(DesignTool.ellipse),
        LogicalKeySet(LogicalKeyboardKey.keyP): const _SetToolIntent(DesignTool.pen),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyP): const _SetToolIntent(DesignTool.pencil),
        LogicalKeySet(LogicalKeyboardKey.keyT): const _SetToolIntent(DesignTool.text),
        LogicalKeySet(LogicalKeyboardKey.keyC): const _SetToolIntent(DesignTool.comment),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyI): const _SetToolIntent(DesignTool.resources),
        // Mode shortcuts
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.keyD): const _SetModeIntent(DesignMode.dev),
        // Visibility toggle
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.slash): const _ToggleToolbarIntent(),
      },
      child: Actions(
        actions: {
          _SetToolIntent: CallbackAction<_SetToolIntent>(
            onInvoke: (intent) => state.setTool(intent.tool),
          ),
          _SetModeIntent: CallbackAction<_SetModeIntent>(
            onInvoke: (intent) => state.setMode(intent.mode),
          ),
          _ToggleToolbarIntent: CallbackAction<_ToggleToolbarIntent>(
            onInvoke: (intent) => state.toggleToolbarVisibility(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class _SetToolIntent extends Intent {
  final DesignTool tool;
  const _SetToolIntent(this.tool);
}

class _SetModeIntent extends Intent {
  final DesignMode mode;
  const _SetModeIntent(this.mode);
}

class _ToggleToolbarIntent extends Intent {
  const _ToggleToolbarIntent();
}
