/// Layers panel for viewing and managing the node hierarchy
///
/// Provides a tree view of all layers similar to Figma's left panel

import 'package:flutter/material.dart';

/// Layer visibility state
enum LayerVisibility {
  visible,
  hidden,
  parentHidden,
}

/// Layer lock state
enum LayerLockState {
  unlocked,
  locked,
  parentLocked,
}

/// Layer item data for the tree
class LayerItem {
  /// Node ID
  final String id;

  /// Node name
  final String name;

  /// Node type
  final String type;

  /// Child layer IDs
  final List<String> childIds;

  /// Parent layer ID
  final String? parentId;

  /// Depth in the hierarchy
  final int depth;

  /// Whether this layer is visible
  LayerVisibility visibility;

  /// Whether this layer is locked
  LayerLockState lockState;

  /// Whether this layer is expanded in the tree
  bool isExpanded;

  /// Whether this layer is selected
  bool isSelected;

  /// Whether this layer is being hovered
  bool isHovered;

  LayerItem({
    required this.id,
    required this.name,
    required this.type,
    this.childIds = const [],
    this.parentId,
    this.depth = 0,
    this.visibility = LayerVisibility.visible,
    this.lockState = LayerLockState.unlocked,
    this.isExpanded = true,
    this.isSelected = false,
    this.isHovered = false,
  });

  /// Create from Figma node map
  factory LayerItem.fromNode(
    Map<String, dynamic> node, {
    String? parentId,
    int depth = 0,
  }) {
    final id = node['_guidKey']?.toString() ?? '';
    final name = node['name'] as String? ?? 'Unnamed';
    final type = node['type'] as String? ?? 'UNKNOWN';
    final visible = node['visible'] as bool? ?? true;
    final locked = node['locked'] as bool? ?? false;

    // Get children
    final children = node['children'] as List<dynamic>? ?? [];
    final childIds = children
        .map((c) => (c as Map<String, dynamic>)['_guidKey']?.toString())
        .whereType<String>()
        .toList();

    return LayerItem(
      id: id,
      name: name,
      type: type,
      childIds: childIds,
      parentId: parentId,
      depth: depth,
      visibility: visible ? LayerVisibility.visible : LayerVisibility.hidden,
      lockState: locked ? LayerLockState.locked : LayerLockState.unlocked,
    );
  }

  /// Get icon for this layer type
  IconData get icon {
    switch (type) {
      case 'DOCUMENT':
        return Icons.description_outlined;
      case 'CANVAS':
        return Icons.crop_landscape_outlined;
      case 'FRAME':
        return Icons.crop_free;
      case 'GROUP':
        return Icons.folder_outlined;
      case 'SECTION':
        return Icons.view_agenda_outlined;
      case 'COMPONENT':
        return Icons.widgets_outlined;
      case 'COMPONENT_SET':
        return Icons.dashboard_outlined;
      case 'INSTANCE':
        return Icons.flip_to_front;
      case 'RECTANGLE':
        return Icons.crop_square;
      case 'ELLIPSE':
        return Icons.circle_outlined;
      case 'LINE':
        return Icons.remove;
      case 'STAR':
        return Icons.star_border;
      case 'REGULAR_POLYGON':
        return Icons.hexagon_outlined;
      case 'VECTOR':
        return Icons.gesture;
      case 'TEXT':
        return Icons.text_fields;
      case 'BOOLEAN_OPERATION':
        return Icons.layers;
      case 'SLICE':
        return Icons.content_cut;
      default:
        return Icons.crop_square_outlined;
    }
  }

  /// Get color for this layer type
  Color get iconColor {
    switch (type) {
      case 'FRAME':
        return const Color(0xFF6B7AFF);
      case 'GROUP':
        return const Color(0xFFAA7AFF);
      case 'COMPONENT':
      case 'COMPONENT_SET':
        return const Color(0xFF9747FF);
      case 'INSTANCE':
        return const Color(0xFF9747FF);
      case 'TEXT':
        return const Color(0xFFFF7262);
      case 'VECTOR':
      case 'BOOLEAN_OPERATION':
        return const Color(0xFF18A0FB);
      default:
        return const Color(0xFF999999);
    }
  }

  /// Check if this layer has children
  bool get hasChildren => childIds.isNotEmpty;
}

/// Layers panel widget
class LayersPanel extends StatefulWidget {
  /// Root node IDs to display
  final List<String> rootIds;

  /// Map of all nodes by ID
  final Map<String, Map<String, dynamic>> nodeMap;

  /// Currently selected node IDs
  final Set<String> selectedIds;

  /// Callback when selection changes
  final ValueChanged<Set<String>>? onSelectionChanged;

  /// Callback when visibility changes
  final void Function(String nodeId, bool visible)? onVisibilityChanged;

  /// Callback when lock state changes
  final void Function(String nodeId, bool locked)? onLockChanged;

  /// Callback when layer is double-clicked (focus in canvas)
  final ValueChanged<String>? onFocusNode;

  /// Callback when layer order changes (drag-drop reorder)
  final void Function(String nodeId, String newParentId, int index)?
      onReorderNode;

  /// Panel width
  final double width;

  const LayersPanel({
    super.key,
    required this.rootIds,
    required this.nodeMap,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.onVisibilityChanged,
    this.onLockChanged,
    this.onFocusNode,
    this.onReorderNode,
    this.width = 240,
  });

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  final Map<String, LayerItem> _layerItems = {};
  final Set<String> _expandedIds = {};
  String? _hoveredId;
  String? _dragTargetId;
  bool _dragAbove = false;

  @override
  void initState() {
    super.initState();
    _buildLayerTree();
  }

  @override
  void didUpdateWidget(LayersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nodeMap != oldWidget.nodeMap ||
        widget.rootIds != oldWidget.rootIds) {
      _buildLayerTree();
    }
  }

  void _buildLayerTree() {
    _layerItems.clear();

    void processNode(String nodeId, String? parentId, int depth) {
      final node = widget.nodeMap[nodeId];
      if (node == null) return;

      final item = LayerItem.fromNode(
        node,
        parentId: parentId,
        depth: depth,
      );
      item.isExpanded = _expandedIds.contains(nodeId);
      _layerItems[nodeId] = item;

      // Process children
      final children = node['children'] as List<dynamic>? ?? [];
      for (final child in children) {
        final childMap = child as Map<String, dynamic>;
        final childId = childMap['_guidKey']?.toString();
        if (childId != null) {
          processNode(childId, nodeId, depth + 1);
        }
      }
    }

    for (final rootId in widget.rootIds) {
      processNode(rootId, null, 0);
    }

    setState(() {});
  }

  void _toggleExpanded(String nodeId) {
    setState(() {
      if (_expandedIds.contains(nodeId)) {
        _expandedIds.remove(nodeId);
      } else {
        _expandedIds.add(nodeId);
      }
      _layerItems[nodeId]?.isExpanded = _expandedIds.contains(nodeId);
    });
  }

  void _selectNode(String nodeId, {bool addToSelection = false}) {
    Set<String> newSelection;
    if (addToSelection) {
      newSelection = Set.from(widget.selectedIds);
      if (newSelection.contains(nodeId)) {
        newSelection.remove(nodeId);
      } else {
        newSelection.add(nodeId);
      }
    } else {
      newSelection = {nodeId};
    }
    widget.onSelectionChanged?.call(newSelection);
  }

  void _toggleVisibility(String nodeId) {
    final item = _layerItems[nodeId];
    if (item == null) return;

    final newVisible = item.visibility != LayerVisibility.visible;
    widget.onVisibilityChanged?.call(nodeId, newVisible);
  }

  void _toggleLock(String nodeId) {
    final item = _layerItems[nodeId];
    if (item == null) return;

    final newLocked = item.lockState != LayerLockState.locked;
    widget.onLockChanged?.call(nodeId, newLocked);
  }

  List<String> _getVisibleNodeIds() {
    final visible = <String>[];

    void addNode(String nodeId) {
      visible.add(nodeId);
      final item = _layerItems[nodeId];
      if (item != null && item.isExpanded && item.hasChildren) {
        for (final childId in item.childIds) {
          addNode(childId);
        }
      }
    }

    for (final rootId in widget.rootIds) {
      addNode(rootId);
    }

    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final visibleNodes = _getVisibleNodeIds();

    return Container(
      width: widget.width,
      color: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Search (optional)
          // _buildSearch(),

          // Layer tree
          Expanded(
            child: ListView.builder(
              itemCount: visibleNodes.length,
              itemBuilder: (context, index) {
                final nodeId = visibleNodes[index];
                final item = _layerItems[nodeId];
                if (item == null) return const SizedBox.shrink();

                return _LayerRow(
                  item: item,
                  isSelected: widget.selectedIds.contains(nodeId),
                  isHovered: _hoveredId == nodeId,
                  isDragTarget: _dragTargetId == nodeId,
                  dragAbove: _dragAbove,
                  onTap: () => _selectNode(nodeId),
                  onDoubleTap: () => widget.onFocusNode?.call(nodeId),
                  onToggleExpand: () => _toggleExpanded(nodeId),
                  onToggleVisibility: () => _toggleVisibility(nodeId),
                  onToggleLock: () => _toggleLock(nodeId),
                  onHover: (hovering) {
                    setState(() {
                      _hoveredId = hovering ? nodeId : null;
                    });
                  },
                  onDragStart: () {},
                  onDragUpdate: (target, above) {
                    setState(() {
                      _dragTargetId = target;
                      _dragAbove = above;
                    });
                  },
                  onDragEnd: (targetId, above) {
                    if (targetId != null) {
                      final targetItem = _layerItems[targetId];
                      if (targetItem != null) {
                        // Determine new parent and index
                        final newParentId = above
                            ? targetItem.parentId ?? ''
                            : (targetItem.hasChildren
                                ? targetId
                                : targetItem.parentId ?? '');
                        widget.onReorderNode?.call(nodeId, newParentId, 0);
                      }
                    }
                    setState(() {
                      _dragTargetId = null;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Layers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Filter options
          IconButton(
            icon: const Icon(Icons.filter_list, size: 14),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              // Show filter options
            },
          ),
        ],
      ),
    );
  }
}

/// Individual layer row widget
class _LayerRow extends StatelessWidget {
  final LayerItem item;
  final bool isSelected;
  final bool isHovered;
  final bool isDragTarget;
  final bool dragAbove;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final ValueChanged<bool> onHover;
  final VoidCallback onDragStart;
  final void Function(String? target, bool above) onDragUpdate;
  final void Function(String? target, bool above) onDragEnd;

  const _LayerRow({
    required this.item,
    required this.isSelected,
    required this.isHovered,
    required this.isDragTarget,
    required this.dragAbove,
    required this.onTap,
    required this.onDoubleTap,
    required this.onToggleExpand,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onHover,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isHidden = item.visibility != LayerVisibility.visible;
    final isLocked = item.lockState != LayerLockState.unlocked;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Draggable<String>(
        data: item.id,
        onDragStarted: onDragStart,
        onDragEnd: (_) => onDragEnd(null, false),
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3C3C3C),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 14, color: item.iconColor),
                const SizedBox(width: 4),
                Text(
                  item.name,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (details) {
            if (details.data == item.id) return false;
            return true;
          },
          onAcceptWithDetails: (details) {
            onDragEnd(item.id, dragAbove);
          },
          onMove: (details) {
            // Determine if dropping above or below
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final localPos = renderBox.globalToLocal(details.offset);
              final above = localPos.dy < renderBox.size.height / 2;
              onDragUpdate(item.id, above);
            }
          },
          onLeave: (_) => onDragUpdate(null, false),
          builder: (context, candidateData, rejectedData) {
            return GestureDetector(
              onTap: onTap,
              onDoubleTap: onDoubleTap,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withValues(alpha: 0.3)
                      : isHovered
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.transparent,
                  border: isDragTarget
                      ? Border(
                          top: dragAbove
                              ? const BorderSide(color: Colors.blue, width: 2)
                              : BorderSide.none,
                          bottom: !dragAbove
                              ? const BorderSide(color: Colors.blue, width: 2)
                              : BorderSide.none,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Indent based on depth
                    SizedBox(width: 8 + item.depth * 16.0),

                    // Expand/collapse arrow
                    if (item.hasChildren)
                      GestureDetector(
                        onTap: onToggleExpand,
                        child: Icon(
                          item.isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.chevron_right,
                          size: 14,
                          color: Colors.white54,
                        ),
                      )
                    else
                      const SizedBox(width: 14),

                    const SizedBox(width: 4),

                    // Type icon
                    Icon(
                      item.icon,
                      size: 14,
                      color: isHidden
                          ? item.iconColor.withValues(alpha: 0.5)
                          : item.iconColor,
                    ),
                    const SizedBox(width: 8),

                    // Name
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: isHidden
                              ? Colors.white38
                              : isLocked
                                  ? Colors.white54
                                  : Colors.white,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Visibility toggle (show on hover)
                    if (isHovered || isHidden)
                      GestureDetector(
                        onTap: onToggleVisibility,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            isHidden ? Icons.visibility_off : Icons.visibility,
                            size: 14,
                            color: isHidden ? Colors.white38 : Colors.white54,
                          ),
                        ),
                      ),

                    // Lock toggle (show on hover)
                    if (isHovered || isLocked)
                      GestureDetector(
                        onTap: onToggleLock,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            isLocked ? Icons.lock : Icons.lock_open,
                            size: 14,
                            color: isLocked ? Colors.white54 : Colors.white38,
                          ),
                        ),
                      ),

                    const SizedBox(width: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact layer tree for small spaces
class CompactLayerTree extends StatelessWidget {
  /// Root node IDs
  final List<String> rootIds;

  /// Node map
  final Map<String, Map<String, dynamic>> nodeMap;

  /// Selected IDs
  final Set<String> selectedIds;

  /// Selection callback
  final ValueChanged<String>? onSelect;

  /// Maximum depth to show
  final int maxDepth;

  const CompactLayerTree({
    super.key,
    required this.rootIds,
    required this.nodeMap,
    this.selectedIds = const {},
    this.onSelect,
    this.maxDepth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rootId in rootIds) _buildNode(rootId, 0),
      ],
    );
  }

  Widget _buildNode(String nodeId, int depth) {
    if (depth > maxDepth) return const SizedBox.shrink();

    final node = nodeMap[nodeId];
    if (node == null) return const SizedBox.shrink();

    final name = node['name'] as String? ?? 'Unnamed';
    final type = node['type'] as String? ?? 'UNKNOWN';
    final children = node['children'] as List<dynamic>? ?? [];
    final isSelected = selectedIds.contains(nodeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onSelect?.call(nodeId),
          child: Container(
            padding: EdgeInsets.only(left: depth * 12.0),
            height: 24,
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.transparent,
            child: Row(
              children: [
                Icon(
                  _getIconForType(type),
                  size: 12,
                  color: isSelected ? Colors.blue : Colors.white54,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.blue : Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final child in children)
          _buildNode(
            (child as Map<String, dynamic>)['_guidKey']?.toString() ?? '',
            depth + 1,
          ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'FRAME':
        return Icons.crop_free;
      case 'GROUP':
        return Icons.folder_outlined;
      case 'COMPONENT':
        return Icons.widgets_outlined;
      case 'INSTANCE':
        return Icons.flip_to_front;
      case 'TEXT':
        return Icons.text_fields;
      case 'RECTANGLE':
        return Icons.crop_square;
      case 'ELLIPSE':
        return Icons.circle_outlined;
      case 'VECTOR':
        return Icons.gesture;
      default:
        return Icons.crop_square_outlined;
    }
  }
}

/// Layer path breadcrumb widget
class LayerBreadcrumb extends StatelessWidget {
  /// Current node ID
  final String nodeId;

  /// Node map
  final Map<String, Map<String, dynamic>> nodeMap;

  /// Callback when a breadcrumb is clicked
  final ValueChanged<String>? onNavigate;

  const LayerBreadcrumb({
    super.key,
    required this.nodeId,
    required this.nodeMap,
    this.onNavigate,
  });

  List<String> _getPath() {
    final path = <String>[];
    String? current = nodeId;

    while (current != null) {
      path.insert(0, current);
      final node = nodeMap[current];
      if (node == null) break;

      // Find parent by checking all nodes
      String? parentId;
      for (final entry in nodeMap.entries) {
        final children = entry.value['children'] as List<dynamic>?;
        if (children != null) {
          for (final child in children) {
            final childMap = child as Map<String, dynamic>;
            if (childMap['_guidKey']?.toString() == current) {
              parentId = entry.key;
              break;
            }
          }
        }
        if (parentId != null) break;
      }
      current = parentId;
    }

    return path;
  }

  @override
  Widget build(BuildContext context) {
    final path = _getPath();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < path.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 12,
                  color: Colors.white38,
                ),
              ),
            GestureDetector(
              onTap: () => onNavigate?.call(path[i]),
              child: Text(
                nodeMap[path[i]]?['name'] as String? ?? 'Unknown',
                style: TextStyle(
                  fontSize: 11,
                  color: i == path.length - 1 ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
