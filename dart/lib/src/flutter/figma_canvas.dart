/// Figma canvas view with pan, zoom, and page navigation
///
/// This provides a complete canvas experience for viewing Figma documents.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'node_renderer.dart';
import 'state/state.dart';
import 'editing/editing.dart';

// Figma's exact colors
class FigmaColors {
  static const bg1 = Color(0xFF1E1E1E);      // Main background
  static const bg2 = Color(0xFF2C2C2C);      // Panels background
  static const bg3 = Color(0xFF383838);      // Hover states
  static const border = Color(0xFF444444);   // Borders
  static const text1 = Color(0xFFFFFFFF);    // Primary text
  static const text2 = Color(0xFFB3B3B3);    // Secondary text
  static const text3 = Color(0xFF7A7A7A);    // Tertiary text
  static const accent = Color(0xFF0D99FF);   // Selection blue
  static const canvas = Color(0xFF252525);   // Canvas background
}

/// Helper class to process Figma message data
class FigmaDocument {
  final Map<String, dynamic> message;
  final Map<String, Map<String, dynamic>> nodeMap;
  final List<Map<String, dynamic>> pages;
  final Map<String, dynamic>? documentNode;
  final Map<String, List<int>> blobMap;
  String? imagesDirectory;

  FigmaDocument._({
    required this.message,
    required this.nodeMap,
    required this.pages,
    this.documentNode,
    required this.blobMap,
    this.imagesDirectory,
  });

  static String _guidToKey(dynamic guid) {
    if (guid is Map) {
      final sessionId = guid['sessionID'] ?? 0;
      final localId = guid['localID'] ?? 0;
      return '$sessionId:$localId';
    }
    return guid.toString();
  }

  factory FigmaDocument.fromMessage(Map<String, dynamic> message) {
    final nodeChanges = message['nodeChanges'] as List? ?? [];
    final nodeMap = <String, Map<String, dynamic>>{};
    final pages = <Map<String, dynamic>>[];
    Map<String, dynamic>? documentNode;

    for (final node in nodeChanges) {
      if (node is Map<String, dynamic>) {
        final guid = node['guid'];
        if (guid != null) {
          final key = _guidToKey(guid);
          nodeMap[key] = node;
          node['_guidKey'] = key;

          final type = node['type'];
          if (type == 'DOCUMENT') {
            documentNode = node;
          } else if (type == 'CANVAS') {
            pages.add(node);
          }
        }
      }
    }

    final childrenMap = <String, List<String>>{};
    for (final node in nodeMap.values) {
      final parentIndex = node['parentIndex'];
      if (parentIndex is Map) {
        final parentGuid = parentIndex['guid'];
        if (parentGuid != null) {
          final parentKey = _guidToKey(parentGuid);
          childrenMap.putIfAbsent(parentKey, () => []);
          childrenMap[parentKey]!.add(node['_guidKey'] as String);
        }
      }
    }

    for (final entry in childrenMap.entries) {
      final node = nodeMap[entry.key];
      if (node != null) {
        node['children'] = entry.value;
      }
    }

    final blobMap = <String, List<int>>{};
    final blobs = message['blobs'] as List?;
    if (blobs != null) {
      for (final blob in blobs) {
        if (blob is Map) {
          final bytes = blob['bytes'];
          if (bytes is List) {
            final index = blobs.indexOf(blob);
            blobMap['blob_$index'] = bytes.cast<int>();
          }
        }
      }
    }

    return FigmaDocument._(
      message: message,
      nodeMap: nodeMap,
      pages: pages,
      documentNode: documentNode,
      blobMap: blobMap,
    );
  }

  int get nodeCount => nodeMap.length;

  Map<String, int> get nodeTypeCounts {
    final counts = <String, int>{};
    for (final node in nodeMap.values) {
      final type = node['type'] as String? ?? 'UNKNOWN';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic> auditImages() {
    final allHashes = <String>{};
    final foundHashes = <String>{};
    final missingHashes = <String>{};
    final nodesByHash = <String, List<String>>{};

    void extractImageHash(Map fill, String source) {
      final imageRef = fill['image'];
      if (imageRef is Map) {
        final hash = imageRef['hash'];
        if (hash is List) {
          final hexHash = imageHashToHex(hash);
          if (hexHash.isNotEmpty) {
            allHashes.add(hexHash);
            nodesByHash.putIfAbsent(hexHash, () => []);
            nodesByHash[hexHash]!.add(source);
          }
        }
      }
    }

    for (final node in nodeMap.values) {
      final nodeName = node['name'] as String? ?? 'unnamed';
      final fillPaints = node['fillPaints'] as List? ?? [];

      for (final fill in fillPaints) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          extractImageHash(fill, nodeName);
        }
      }

      final symbolData = node['symbolData'];
      if (symbolData is Map) {
        final overrides = symbolData['symbolOverrides'];
        if (overrides is List) {
          for (final override in overrides) {
            if (override is Map) {
              final overrideFills = override['fillPaints'] as List?;
              if (overrideFills != null) {
                for (final fill in overrideFills) {
                  if (fill is Map && fill['type'] == 'IMAGE') {
                    extractImageHash(fill, '$nodeName (override)');
                  }
                }
              }
            }
          }
        }
      }
    }

    if (imagesDirectory != null) {
      for (final hash in allHashes) {
        final file = File('$imagesDirectory/$hash');
        if (file.existsSync()) {
          foundHashes.add(hash);
        } else {
          missingHashes.add(hash);
        }
      }
    }

    print('IMAGE AUDIT:');
    print('  Total unique images: ${allHashes.length}');
    print('  Found: ${foundHashes.length}');
    print('  Missing: ${missingHashes.length}');

    if (missingHashes.isNotEmpty) {
      print('  Missing image hashes:');
      for (final hash in missingHashes.take(10)) {
        final nodes = nodesByHash[hash] ?? [];
        print('    $hash (used by: ${nodes.take(3).join(", ")})');
      }
    }

    return {
      'total': allHashes.length,
      'found': foundHashes.length,
      'missing': missingHashes.length,
      'missingHashes': missingHashes.toList(),
      'foundHashes': foundHashes.toList(),
    };
  }
}

/// Main canvas widget - Figma-like editor
class FigmaCanvasView extends StatefulWidget {
  final FigmaDocument document;
  final int initialPageIndex;
  final bool showPageSelector;
  final bool showDebugInfo;
  final Color backgroundColor;

  const FigmaCanvasView({
    super.key,
    required this.document,
    this.initialPageIndex = 0,
    this.showPageSelector = true,
    this.showDebugInfo = false,
    this.backgroundColor = FigmaColors.canvas,
  });

  @override
  State<FigmaCanvasView> createState() => _FigmaCanvasViewState();
}

class _FigmaCanvasViewState extends State<FigmaCanvasView> {
  late int _currentPageIndex;
  late TransformationController _transformController;
  final ValueNotifier<double> _scaleNotifier = ValueNotifier(1.0);
  double get _scale => _scaleNotifier.value;
  set _scale(double v) => _scaleNotifier.value = v;
  bool _showLeftPanel = true;
  bool _showRightPanel = true;
  int _rightPanelTab = 0; // 0=Design, 1=Prototype, 2=Inspect
  int _leftPanelTab = 0; // 0=Layers, 1=Assets

  // Cached canvas content widget
  Widget? _cachedCanvasContent;
  int? _cachedPageIndex;

  // State management
  late DocumentState _documentState;
  final FocusNode _canvasFocusNode = FocusNode();

  // Current tool
  String _currentTool = 'select';

  // Snap engine for alignment
  late SnapEngine _snapEngine;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialPageIndex;
    _transformController = TransformationController();
    _documentState = DocumentState();
    _initializeDocumentState();
    _snapEngine = SnapEngine(
      config: const SnapConfig(
        gridSize: 8.0,
        threshold: 8.0,
        snapToGrid: true,
        snapToObjects: true,
      ),
    );
  }

  void _initializeDocumentState() {
    // Load document into state
    final pages = widget.document.pages;
    final rootNodeIds = pages.map((p) => p['_guidKey']?.toString() ?? '').toList();
    _documentState.loadDocument(
      nodeMap: widget.document.nodeMap,
      rootNodeIds: rootNodeIds,
      documentName: widget.document.documentNode?['name'] as String?,
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    _scaleNotifier.dispose();
    _canvasFocusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard shortcut actions
  void _handleShortcut(ShortcutAction action) {
    switch (action) {
      case ShortcutAction.undo:
        if (_documentState.canUndo) {
          _documentState.undo();
          _invalidateCache();
        }
        break;
      case ShortcutAction.redo:
        if (_documentState.canRedo) {
          _documentState.redo();
          _invalidateCache();
        }
        break;
      case ShortcutAction.copy:
        _documentState.copySelection();
        break;
      case ShortcutAction.cut:
        _documentState.cutSelection();
        _invalidateCache();
        break;
      case ShortcutAction.paste:
        _documentState.paste();
        _invalidateCache();
        break;
      case ShortcutAction.duplicate:
        _duplicateSelection();
        break;
      case ShortcutAction.delete:
        _deleteSelection();
        break;
      case ShortcutAction.selectAll:
        _selectAll();
        break;
      case ShortcutAction.deselect:
      case ShortcutAction.cancel:
        _documentState.selection.deselectAll();
        DebugOverlayController.instance.clearSelection();
        setState(() {});
        break;
      case ShortcutAction.nudgeUp:
      case ShortcutAction.nudgeDown:
      case ShortcutAction.nudgeLeft:
      case ShortcutAction.nudgeRight:
      case ShortcutAction.nudgeUpLarge:
      case ShortcutAction.nudgeDownLarge:
      case ShortcutAction.nudgeLeftLarge:
      case ShortcutAction.nudgeRightLarge:
        _nudgeSelection(action.nudgeOffset!);
        break;
      case ShortcutAction.zoomIn:
        _setScale(_scale * 1.25, Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        ));
        break;
      case ShortcutAction.zoomOut:
        _setScale(_scale / 1.25, Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        ));
        break;
      case ShortcutAction.zoomToFit:
        _zoomToFit();
        break;
      case ShortcutAction.zoomTo100:
        _setScale(1.0, Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        ));
        break;
      case ShortcutAction.group:
        _groupSelection();
        break;
      case ShortcutAction.ungroup:
        _ungroupSelection();
        break;
      case ShortcutAction.save:
        // TODO: Implement save
        break;
      default:
        // Other actions not yet implemented
        break;
    }
  }

  /// Handle tool selection shortcuts
  void _handleToolSelected(String tool) {
    setState(() {
      _currentTool = tool;
    });
  }

  void _invalidateCache() {
    _cachedCanvasContent = null;
    setState(() {});
  }

  void _duplicateSelection() {
    final selectedNode = DebugOverlayController.instance.selectedNode;
    if (selectedNode == null) return;

    // Copy and paste with offset
    _documentState.copySelection();
    _documentState.paste();
    _invalidateCache();
  }

  void _deleteSelection() {
    final selectedNode = DebugOverlayController.instance.selectedNode;
    if (selectedNode == null) return;

    final nodeId = selectedNode['_guidKey']?.toString();
    if (nodeId == null) return;

    // Delete using DocumentState
    _documentState.deleteNodes({nodeId});
    DebugOverlayController.instance.clearSelection();
    _invalidateCache();
  }

  void _selectAll() {
    final page = _currentPage;
    if (page == null) return;

    final children = page['children'] as List? ?? [];
    final childIds = children.map((c) => c.toString()).toList();
    _documentState.selection.selectMultiple(childIds);
    setState(() {});
  }

  void _nudgeSelection(Offset offset) {
    final selectedNode = DebugOverlayController.instance.selectedNode;
    if (selectedNode == null) return;

    final nodeId = selectedNode['_guidKey']?.toString();
    if (nodeId == null) return;

    final props = FigmaNodeProperties.fromMap(selectedNode);
    final newX = props.x + offset.dx;
    final newY = props.y + offset.dy;

    // Move using DocumentState
    _documentState.moveNodes({nodeId}, offset);

    // Update the controller for immediate feedback
    DebugOverlayController.instance.updateNodePosition(selectedNode, newX, newY);
    _invalidateCache();
  }

  void _groupSelection() {
    if (!_documentState.selection.hasSelection) return;
    if (_documentState.selection.count < 2) return;

    // TODO: Implement proper grouping with command pattern
    // For now, just show that the action was triggered
    _invalidateCache();
  }

  void _ungroupSelection() {
    final selectedNode = DebugOverlayController.instance.selectedNode;
    if (selectedNode == null) return;

    final type = selectedNode['type'] as String?;
    if (type != 'GROUP' && type != 'FRAME') return;

    // TODO: Implement proper ungrouping with command pattern
    _invalidateCache();
  }

  Map<String, dynamic>? get _currentPage {
    if (_currentPageIndex < 0 || _currentPageIndex >= widget.document.pages.length) {
      return null;
    }
    return widget.document.pages[_currentPageIndex];
  }

  void _onPageChanged(int index) {
    _cachedCanvasContent = null; // Invalidate cache
    setState(() {
      _currentPageIndex = index;
      _transformController.value = Matrix4.identity();
      _scale = 1.0;
    });
  }

  void _setScale(double newScale, Offset focalPoint) {
    newScale = newScale.clamp(0.02, 25.0);
    final oldScale = _scale;
    final matrix = _transformController.value.clone();
    final translation = matrix.getTranslation();
    final focalPointInCanvas = (focalPoint - Offset(translation.x, translation.y)) / oldScale;
    final newTranslation = focalPoint - focalPointInCanvas * newScale;

    // Update scale without setState - use notifier
    _scale = newScale;
    final newMatrix = Matrix4.identity();
    newMatrix.setEntry(0, 3, newTranslation.dx);
    newMatrix.setEntry(1, 3, newTranslation.dy);
    newMatrix.setEntry(0, 0, newScale);
    newMatrix.setEntry(1, 1, newScale);
    _transformController.value = newMatrix;
  }

  void _zoomToFit() {
    final page = _currentPage;
    if (page == null) return;

    final children = page['children'] as List?;
    if (children == null || children.isEmpty) return;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final childId in children) {
      final child = widget.document.nodeMap[childId.toString()];
      if (child != null) {
        final props = FigmaNodeProperties.fromMap(child);
        minX = minX < props.x ? minX : props.x;
        minY = minY < props.y ? minY : props.y;
        maxX = maxX > (props.x + props.width) ? maxX : (props.x + props.width);
        maxY = maxY > (props.y + props.height) ? maxY : (props.y + props.height);
      }
    }

    if (minX == double.infinity) return;

    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    final screenSize = MediaQuery.of(context).size;
    final availableWidth = screenSize.width - (_showLeftPanel ? 240 : 0) - (_showRightPanel ? 300 : 0);
    final availableHeight = screenSize.height - 88;
    final padding = 100.0;

    final scaleX = (availableWidth - padding) / contentWidth;
    final scaleY = (availableHeight - padding) / contentHeight;
    final newScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.02, 1.0);

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final offsetX = availableWidth / 2 - centerX * newScale + (_showLeftPanel ? 240 : 0);
    final offsetY = availableHeight / 2 - centerY * newScale + 48;

    // Update scale without setState
    _scale = newScale;
    final matrix = Matrix4.identity();
    matrix.setEntry(0, 3, offsetX);
    matrix.setEntry(1, 3, offsetY);
    matrix.setEntry(0, 0, newScale);
    matrix.setEntry(1, 1, newScale);
    _transformController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcuts(
      onShortcut: _handleShortcut,
      focusNode: _canvasFocusNode,
      child: ToolShortcuts(
        onToolSelected: _handleToolSelected,
        child: Scaffold(
          backgroundColor: FigmaColors.bg1,
          body: Column(
            children: [
              _buildToolbar(),
              Expanded(
                child: Row(
                  children: [
                    if (_showLeftPanel) _buildLeftPanel(),
                    Expanded(child: _buildCanvas()),
                    if (_showRightPanel) _buildRightPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ TOOLBAR ============
  Widget _buildToolbar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: FigmaColors.bg2,
        border: Border(bottom: BorderSide(color: FigmaColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Menu button
          _ToolbarButton(icon: Icons.menu, onTap: () {}),
          Container(width: 1, height: 24, color: FigmaColors.border),

          // Move tool (V)
          _ToolbarButton(
            icon: Icons.near_me_outlined,
            onTap: () => _handleToolSelected('select'),
            selected: _currentTool == 'select',
          ),
          // Frame tool (F)
          _ToolbarButton(
            icon: Icons.crop_free,
            onTap: () => _handleToolSelected('frame'),
            selected: _currentTool == 'frame',
          ),
          Container(width: 1, height: 24, color: FigmaColors.border),

          // Shape tools
          _ToolbarButton(
            icon: Icons.rectangle_outlined,
            onTap: () => _handleToolSelected('rectangle'),
            selected: _currentTool == 'rectangle',
          ),
          _ToolbarButton(
            icon: Icons.create_outlined,
            onTap: () => _handleToolSelected('pen'),
            selected: _currentTool == 'pen',
          ),
          _ToolbarButton(
            icon: Icons.text_fields,
            onTap: () => _handleToolSelected('text'),
            selected: _currentTool == 'text',
          ),
          Container(width: 1, height: 24, color: FigmaColors.border),

          // Hand tool (H)
          _ToolbarButton(
            icon: Icons.pan_tool_outlined,
            onTap: () => _handleToolSelected('hand'),
            selected: _currentTool == 'hand' || _currentTool == 'hand_temp',
          ),
          _ToolbarButton(
            icon: Icons.chat_bubble_outline,
            onTap: () => _handleToolSelected('comment'),
            selected: _currentTool == 'comment',
          ),

          const Spacer(),

          // File name / page tabs
          _buildPageDropdown(),

          const Spacer(),

          // Right side controls
          _ToolbarButton(
            icon: Icons.play_arrow,
            onTap: () {},
            label: 'Present',
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: FigmaColors.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Share', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(icon: Icons.more_horiz, onTap: () {}),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPageDropdown() {
    final page = _currentPage;
    return PopupMenuButton<int>(
      offset: const Offset(0, 40),
      color: FigmaColors.bg2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              page?['name'] as String? ?? 'Untitled',
              style: const TextStyle(color: FigmaColors.text1, fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: FigmaColors.text2, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => widget.document.pages.asMap().entries.map((entry) {
        return PopupMenuItem<int>(
          value: entry.key,
          child: Row(
            children: [
              Icon(
                entry.key == _currentPageIndex ? Icons.check : null,
                size: 16,
                color: FigmaColors.text1,
              ),
              const SizedBox(width: 8),
              Text(
                entry.value['name'] as String? ?? 'Page ${entry.key + 1}',
                style: const TextStyle(color: FigmaColors.text1, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
      onSelected: _onPageChanged,
    );
  }

  // ============ LEFT PANEL ============
  Widget _buildLeftPanel() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: FigmaColors.bg2,
        border: Border(right: BorderSide(color: FigmaColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Panel header with tabs
          Container(
            height: 40,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: FigmaColors.border, width: 1)),
            ),
            child: Row(
              children: [
                _PanelTab(label: 'Layers', selected: _leftPanelTab == 0, onTap: () => setState(() => _leftPanelTab = 0)),
                _PanelTab(label: 'Assets', selected: _leftPanelTab == 1, onTap: () => setState(() => _leftPanelTab = 1)),
              ],
            ),
          ),
          // Content based on tab
          Expanded(child: _leftPanelTab == 0 ? _buildLayersContent() : _buildAssetsContent()),
        ],
      ),
    );
  }

  Widget _buildLayersContent() {
    return Column(
      children: [
        // Page header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FigmaColors.border, width: 1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 14, color: FigmaColors.text2),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _currentPage?['name'] as String? ?? 'Page',
                  style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Layer tree
        Expanded(child: _buildLayerTree()),
      ],
    );
  }

  Widget _buildAssetsContent() {
    // Extract components from the document
    final components = <Map<String, dynamic>>[];
    for (final node in widget.document.nodeMap.values) {
      final type = node['type'];
      if (type == 'COMPONENT' || type == 'COMPONENT_SET') {
        components.add(node);
      }
    }

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FigmaColors.border, width: 1)),
          ),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: FigmaColors.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FigmaColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 14, color: FigmaColors.text3),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search in this library',
                    style: TextStyle(color: FigmaColors.text3, fontSize: 11),
                  ),
                ),
                Icon(Icons.tune, size: 14, color: FigmaColors.text3),
              ],
            ),
          ),
        ),
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.chevron_left, size: 14, color: FigmaColors.text2),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Created in this file',
                  style: TextStyle(color: FigmaColors.text1, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        // Components grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: components.length,
            itemBuilder: (context, index) {
              final comp = components[index];
              final name = comp['name'] as String? ?? 'Component';
              return GestureDetector(
                onTap: () {
                  DebugOverlayController.instance.selectNode(comp);
                  _centerOnNode(comp);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: FigmaColors.bg3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: FigmaColors.bg1,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                          child: const Center(
                            child: Icon(Icons.widgets_outlined, size: 24, color: FigmaColors.text3),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          name,
                          style: const TextStyle(color: FigmaColors.text2, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Footer showing count
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FigmaColors.border, width: 1)),
          ),
          child: Text(
            '${components.length} components',
            style: const TextStyle(color: FigmaColors.text3, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildLayerTree() {
    final page = _currentPage;
    if (page == null) return const SizedBox.shrink();

    final children = page['children'] as List? ?? [];

    return _KeyboardNavigableLayerTree(
      children: children,
      nodeMap: widget.document.nodeMap,
      onSelect: (node) {
        DebugOverlayController.instance.setEnabled(true);
        DebugOverlayController.instance.selectNode(node);
        _centerOnNode(node);
      },
    );
  }

  void _centerOnNode(Map<String, dynamic> node) {
    final props = FigmaNodeProperties.fromMap(node);

    // Get the canvas area dimensions
    final screenSize = MediaQuery.of(context).size;
    final canvasWidth = screenSize.width - (_showLeftPanel ? 240 : 0) - (_showRightPanel ? 300 : 0);
    final canvasHeight = screenSize.height - 88; // toolbar + bottom bar

    // Calculate center of the node
    final nodeCenterX = props.x + props.width / 2;
    final nodeCenterY = props.y + props.height / 2;

    // Calculate offset to center the node in the canvas
    final offsetX = canvasWidth / 2 - nodeCenterX * _scale + (_showLeftPanel ? 240 : 0);
    final offsetY = canvasHeight / 2 - nodeCenterY * _scale + 48; // 48 for toolbar

    // Update transform
    final matrix = Matrix4.identity();
    matrix.setEntry(0, 3, offsetX);
    matrix.setEntry(1, 3, offsetY);
    matrix.setEntry(0, 0, _scale);
    matrix.setEntry(1, 1, _scale);
    _transformController.value = matrix;
  }

  // ============ CANVAS ============
  Widget _buildCanvas() {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Escape to exit group or clear selection
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            final controller = DebugOverlayController.instance;
            if (controller.isInsideGroup) {
              controller.exitGroup(widget.document.nodeMap);
              return KeyEventResult.handled;
            } else if (controller.selectedNode != null) {
              controller.clearSelection();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: FigmaColors.canvas,
        child: Stack(
          children: [
            // Main canvas with RepaintBoundary for performance
            Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                // Check for pinch zoom (trackpad) vs scroll
                if (HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed) {
                  final delta = event.scrollDelta.dy;
                  final factor = delta > 0 ? 0.9 : 1.1;
                  _setScale(_scale * factor, event.localPosition);
                } else {
                  // Pan - just update controller, no setState needed
                  final matrix = _transformController.value.clone();
                  matrix.translate(-event.scrollDelta.dx, -event.scrollDelta.dy);
                  _transformController.value = matrix;
                }
              }
            },
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.02,
              maxScale: 25.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              panEnabled: true,
              scaleEnabled: true,
              onInteractionUpdate: (details) {
                // Just update the notifier, no setState - prevents rebuild
                _scaleNotifier.value = _transformController.value.getMaxScaleOnAxis();
              },
              child: RepaintBoundary(
                child: _buildCanvasContent(),
              ),
            ),
          ),

          // Bottom toolbar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCanvasContent() {
    final page = _currentPage;
    if (page == null) {
      return const Center(child: Text('No pages found', style: TextStyle(color: FigmaColors.text2)));
    }

    // Cache the content widget to avoid rebuilding on pan/zoom
    if (_cachedCanvasContent != null && _cachedPageIndex == _currentPageIndex) {
      return _cachedCanvasContent!;
    }

    _cachedPageIndex = _currentPageIndex;
    _cachedCanvasContent = SizedBox(
      width: 20000,
      height: 20000,
      child: FigmaNodeWidget(
        node: page,
        nodeMap: widget.document.nodeMap,
        blobMap: widget.document.blobMap,
        imagesDirectory: widget.document.imagesDirectory,
        scale: 1.0,
      ),
    );
    return _cachedCanvasContent!;
  }

  Widget _buildBottomBar() {
    return Container(
      height: 40,
      color: FigmaColors.bg2.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left side - toggle panels
          _BottomBarButton(
            icon: Icons.view_sidebar_outlined,
            selected: _showLeftPanel,
            onTap: () => setState(() => _showLeftPanel = !_showLeftPanel),
          ),
          const SizedBox(width: 8),

          // Zoom controls
          _BottomBarButton(icon: Icons.remove, onTap: () => _setScale(_scale / 1.2, Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2))),
          Container(
            width: 60,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _zoomToFit,
              child: ValueListenableBuilder<double>(
                valueListenable: _scaleNotifier,
                builder: (context, scale, _) => Text(
                  '${(scale * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                ),
              ),
            ),
          ),
          _BottomBarButton(icon: Icons.add, onTap: () => _setScale(_scale * 1.2, Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2))),

          const Spacer(),

          // Right side
          _BottomBarButton(
            icon: Icons.grid_on,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _BottomBarButton(
            icon: _showRightPanel ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            selected: _showRightPanel,
            onTap: () => setState(() => _showRightPanel = !_showRightPanel),
          ),
        ],
      ),
    );
  }

  // ============ RIGHT PANEL ============
  Widget _buildRightPanel() {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: FigmaColors.bg2,
        border: Border(left: BorderSide(color: FigmaColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            height: 40,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: FigmaColors.border, width: 1)),
            ),
            child: Row(
              children: [
                _PanelTab(label: 'Design', selected: _rightPanelTab == 0, onTap: () => setState(() => _rightPanelTab = 0)),
                _PanelTab(label: 'Prototype', selected: _rightPanelTab == 1, onTap: () => setState(() => _rightPanelTab = 1)),
                _PanelTab(label: 'Inspect', selected: _rightPanelTab == 2, onTap: () => setState(() => _rightPanelTab = 2)),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListenableBuilder(
              listenable: DebugOverlayController.instance,
              builder: (context, _) {
                final node = DebugOverlayController.instance.selectedNode;
                final props = DebugOverlayController.instance.selectedProps;

                if (node == null) {
                  return const Center(
                    child: Text('Select a layer', style: TextStyle(color: FigmaColors.text3, fontSize: 12)),
                  );
                }

                return _buildDesignPanel(node, props!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignPanel(Map<String, dynamic> node, FigmaNodeProperties props) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alignment section
          _buildAlignmentSection(),
          const _Divider(),

          // Frame/Position section
          _buildFrameSection(props),
          const _Divider(),

          // Layer section
          _buildLayerSection(props),

          // Fill section
          if (props.fills.isNotEmpty) ...[
            const _Divider(),
            _buildFillSection(props),
          ],

          // Stroke section
          if (props.strokes.isNotEmpty) ...[
            const _Divider(),
            _buildStrokeSection(props),
          ],

          // Effects section
          if (props.effects.isNotEmpty) ...[
            const _Divider(),
            _buildEffectsSection(props),
          ],
        ],
      ),
    );
  }

  Widget _buildAlignmentSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _AlignButton(icon: Icons.align_horizontal_left),
        _AlignButton(icon: Icons.align_horizontal_center),
        _AlignButton(icon: Icons.align_horizontal_right),
        Container(width: 1, height: 20, color: FigmaColors.border),
        _AlignButton(icon: Icons.align_vertical_top),
        _AlignButton(icon: Icons.align_vertical_center),
        _AlignButton(icon: Icons.align_vertical_bottom),
      ],
    );
  }

  Widget _buildFrameSection(FigmaNodeProperties props) {
    final controller = DebugOverlayController.instance;
    final node = controller.selectedNode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _EditableInputField(
                label: 'X',
                value: props.x.toStringAsFixed(0),
                onChanged: (val) {
                  final newX = double.tryParse(val) ?? props.x;
                  if (node != null) controller.updateNodePosition(node, newX, props.y);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EditableInputField(
                label: 'Y',
                value: props.y.toStringAsFixed(0),
                onChanged: (val) {
                  final newY = double.tryParse(val) ?? props.y;
                  if (node != null) controller.updateNodePosition(node, props.x, newY);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _EditableInputField(
                label: 'W',
                value: props.width.toStringAsFixed(0),
                onChanged: (val) {
                  final newW = double.tryParse(val) ?? props.width;
                  if (node != null) controller.updateNodeSize(node, newW, props.height);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EditableInputField(
                label: 'H',
                value: props.height.toStringAsFixed(0),
                onChanged: (val) {
                  final newH = double.tryParse(val) ?? props.height;
                  if (node != null) controller.updateNodeSize(node, props.width, newH);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _InputField(label: 'R', value: props.rotation.toStringAsFixed(0) + '°')),
            const SizedBox(width: 8),
            Expanded(
              child: _InputField(
                label: '◰',
                value: props.cornerRadius?.toStringAsFixed(0) ?? '0',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayerSection(FigmaNodeProperties props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Layer'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Opacity', style: TextStyle(color: FigmaColors.text2, fontSize: 11)),
            const Spacer(),
            SizedBox(
              width: 50,
              child: Text(
                '${(props.opacity * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: FigmaColors.bg3,
            borderRadius: BorderRadius.circular(1),
          ),
          child: FractionallySizedBox(
            widthFactor: props.opacity,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: FigmaColors.text1,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFillSection(FigmaNodeProperties props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionHeader(title: 'Fill'),
            const Spacer(),
            Icon(Icons.add, size: 14, color: FigmaColors.text2),
          ],
        ),
        const SizedBox(height: 8),
        ...props.fills.map((fill) => _FillItem(fill: fill)),
      ],
    );
  }

  Widget _buildStrokeSection(FigmaNodeProperties props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Stroke'),
        const SizedBox(height: 8),
        ...props.strokes.map((stroke) => _FillItem(fill: stroke)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Weight', style: TextStyle(color: FigmaColors.text2, fontSize: 11)),
            const Spacer(),
            Text('${props.strokeWeight}', style: const TextStyle(color: FigmaColors.text1, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildEffectsSection(FigmaNodeProperties props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Effects'),
        const SizedBox(height: 8),
        ...props.effects.map((effect) => Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.blur_on, size: 14, color: FigmaColors.text2),
              const SizedBox(width: 8),
              Text(
                effect['type']?.toString() ?? 'Effect',
                style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

// ============ HELPER WIDGETS ============

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final String? label;

  const _ToolbarButton({required this.icon, required this.onTap, this.selected = false, this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? FigmaColors.bg3 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? FigmaColors.text1 : FigmaColors.text2),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!, style: TextStyle(color: selected ? FigmaColors.text1 : FigmaColors.text2, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PanelTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PanelTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? FigmaColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? FigmaColors.text1 : FigmaColors.text3,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  const _BottomBarButton({required this.icon, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? FigmaColors.bg3 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: FigmaColors.text2),
      ),
    );
  }
}

/// Keyboard-navigable layer tree with arrow key support
class _KeyboardNavigableLayerTree extends StatefulWidget {
  final List children;
  final Map<String, Map<String, dynamic>> nodeMap;
  final void Function(Map<String, dynamic>) onSelect;

  const _KeyboardNavigableLayerTree({
    required this.children,
    required this.nodeMap,
    required this.onSelect,
  });

  @override
  State<_KeyboardNavigableLayerTree> createState() => _KeyboardNavigableLayerTreeState();
}

class _KeyboardNavigableLayerTreeState extends State<_KeyboardNavigableLayerTree> {
  final FocusNode _focusNode = FocusNode();
  final Set<String> _expandedNodes = {};
  int _focusedIndex = 0;
  List<_FlatLayerItem> _flatList = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _rebuildFlatList();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildFlatList() {
    _flatList = [];
    for (final childKey in widget.children) {
      _addToFlatList(childKey.toString(), 0);
    }
  }

  void _addToFlatList(String key, int depth) {
    final node = widget.nodeMap[key];
    if (node == null) return;

    final children = node['children'] as List? ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedNodes.contains(key);

    _flatList.add(_FlatLayerItem(
      key: key,
      node: node,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
    ));

    if (isExpanded && hasChildren) {
      for (final childKey in children) {
        _addToFlatList(childKey.toString(), depth + 1);
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _collapseOrMoveToParent();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _expandOrMoveToChild();
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _selectFocused();
    }
  }

  void _moveFocus(int delta) {
    setState(() {
      _focusedIndex = (_focusedIndex + delta).clamp(0, _flatList.length - 1);
      _scrollToFocused();
    });
  }

  void _scrollToFocused() {
    if (_flatList.isEmpty || !_scrollController.hasClients) return;

    final itemHeight = 28.0;
    final itemTop = _focusedIndex * itemHeight;
    final itemBottom = itemTop + itemHeight;
    final viewTop = _scrollController.offset;
    final viewBottom = viewTop + _scrollController.position.viewportDimension;

    // Only scroll if item is out of view
    if (itemTop < viewTop) {
      // Item is above viewport - scroll up
      _scrollController.jumpTo(itemTop);
    } else if (itemBottom > viewBottom) {
      // Item is below viewport - scroll down
      _scrollController.jumpTo(itemBottom - _scrollController.position.viewportDimension);
    }
  }

  void _collapseOrMoveToParent() {
    if (_flatList.isEmpty) return;
    final item = _flatList[_focusedIndex];

    if (item.isExpanded && item.hasChildren) {
      // Collapse this node
      setState(() {
        _expandedNodes.remove(item.key);
        _rebuildFlatList();
      });
    } else if (item.depth > 0) {
      // Move to parent
      for (int i = _focusedIndex - 1; i >= 0; i--) {
        if (_flatList[i].depth < item.depth) {
          setState(() => _focusedIndex = i);
          break;
        }
      }
    }
  }

  void _expandOrMoveToChild() {
    if (_flatList.isEmpty) return;
    final item = _flatList[_focusedIndex];

    if (item.hasChildren && !item.isExpanded) {
      // Expand this node
      setState(() {
        _expandedNodes.add(item.key);
        _rebuildFlatList();
      });
    } else if (item.hasChildren && item.isExpanded && _focusedIndex + 1 < _flatList.length) {
      // Move to first child
      setState(() => _focusedIndex++);
    }
  }

  void _selectFocused() {
    if (_flatList.isEmpty) return;
    widget.onSelect(_flatList[_focusedIndex].node);
  }

  void _toggleExpand(String key) {
    setState(() {
      if (_expandedNodes.contains(key)) {
        _expandedNodes.remove(key);
      } else {
        _expandedNodes.add(key);
      }
      _rebuildFlatList();
    });
  }

  @override
  Widget build(BuildContext context) {
    _rebuildFlatList(); // Rebuild on each render to sync with expanded state

    return Focus(
      focusNode: _focusNode,
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space) {
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount: _flatList.length,
          itemBuilder: (context, index) {
            final item = _flatList[index];
            final isFocused = index == _focusedIndex && _focusNode.hasFocus;

            return _LayerItemRow(
              item: item,
              isFocused: isFocused,
              onTap: () {
                setState(() => _focusedIndex = index);
                widget.onSelect(item.node);
                _focusNode.requestFocus();
              },
              onToggleExpand: item.hasChildren ? () => _toggleExpand(item.key) : null,
            );
          },
        ),
      ),
    );
  }
}

class _FlatLayerItem {
  final String key;
  final Map<String, dynamic> node;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;

  _FlatLayerItem({
    required this.key,
    required this.node,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
  });
}

class _LayerItemRow extends StatelessWidget {
  final _FlatLayerItem item;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback? onToggleExpand;

  const _LayerItemRow({
    required this.item,
    required this.isFocused,
    required this.onTap,
    this.onToggleExpand,
  });

  IconData _getIcon(String type) {
    switch (type) {
      case 'FRAME': return Icons.crop_square;
      case 'GROUP': return Icons.folder_outlined;
      case 'COMPONENT':
      case 'COMPONENT_SET': return Icons.widgets_outlined;
      case 'INSTANCE': return Icons.diamond_outlined;
      case 'TEXT': return Icons.text_fields;
      case 'RECTANGLE':
      case 'ROUNDED_RECTANGLE': return Icons.rectangle_outlined;
      case 'ELLIPSE': return Icons.circle_outlined;
      case 'VECTOR':
      case 'LINE': return Icons.show_chart;
      case 'SECTION': return Icons.view_agenda_outlined;
      default: return Icons.layers_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = item.node['name'] as String? ?? 'Unnamed';
    final type = item.node['type'] as String? ?? 'UNKNOWN';
    final nodeKey = item.node['_guidKey']?.toString();

    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        final isSelected = DebugOverlayController.instance.selectedNode?['_guidKey'] == nodeKey;

        return GestureDetector(
          onTap: onTap,
          onDoubleTap: onToggleExpand,
          child: Container(
            height: 28,
            padding: EdgeInsets.only(left: 4 + item.depth * 12.0, right: 4),
            decoration: BoxDecoration(
              color: isSelected ? FigmaColors.accent : (isFocused ? FigmaColors.bg3 : Colors.transparent),
              border: isFocused && !isSelected ? Border.all(color: FigmaColors.accent, width: 1) : null,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggleExpand,
                  child: SizedBox(
                    width: 16,
                    child: item.hasChildren
                        ? Icon(item.isExpanded ? Icons.expand_more : Icons.chevron_right, size: 12, color: FigmaColors.text3)
                        : null,
                  ),
                ),
                Icon(_getIcon(type), size: 12, color: isSelected ? FigmaColors.text1 : FigmaColors.text3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(color: isSelected ? FigmaColors.text1 : FigmaColors.text2, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LayerItem extends StatefulWidget {
  final Map<String, dynamic> node;
  final Map<String, Map<String, dynamic>> nodeMap;
  final int depth;
  final void Function(Map<String, dynamic>) onSelect;

  const _LayerItem({required this.node, required this.nodeMap, required this.depth, required this.onSelect});

  @override
  State<_LayerItem> createState() => _LayerItemState();
}

class _LayerItemState extends State<_LayerItem> {
  bool _expanded = false;

  IconData _getIcon(String type) {
    switch (type) {
      case 'FRAME': return Icons.crop_square;
      case 'GROUP': return Icons.folder_outlined;
      case 'COMPONENT':
      case 'COMPONENT_SET': return Icons.widgets_outlined;
      case 'INSTANCE': return Icons.diamond_outlined;
      case 'TEXT': return Icons.text_fields;
      case 'RECTANGLE':
      case 'ROUNDED_RECTANGLE': return Icons.rectangle_outlined;
      case 'ELLIPSE': return Icons.circle_outlined;
      case 'VECTOR':
      case 'LINE': return Icons.show_chart;
      case 'SECTION': return Icons.view_agenda_outlined;
      default: return Icons.layers_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.node['name'] as String? ?? 'Unnamed';
    final type = widget.node['type'] as String? ?? 'UNKNOWN';
    final children = widget.node['children'] as List? ?? [];
    final hasChildren = children.isNotEmpty;
    final nodeKey = widget.node['_guidKey']?.toString();

    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        final isSelected = DebugOverlayController.instance.selectedNode?['_guidKey'] == nodeKey;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () => widget.onSelect(widget.node),
              onDoubleTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
              child: Container(
                height: 28,
                padding: EdgeInsets.only(left: 4 + widget.depth * 12.0, right: 4),
                color: isSelected ? FigmaColors.accent : Colors.transparent,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
                      child: SizedBox(
                        width: 16,
                        child: hasChildren
                            ? Icon(_expanded ? Icons.expand_more : Icons.chevron_right, size: 12, color: FigmaColors.text3)
                            : null,
                      ),
                    ),
                    Icon(_getIcon(type), size: 12, color: isSelected ? FigmaColors.text1 : FigmaColors.text3),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(color: isSelected ? FigmaColors.text1 : FigmaColors.text2, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && hasChildren)
              ...children.map((childKey) {
                final childNode = widget.nodeMap[childKey.toString()];
                if (childNode == null) return const SizedBox.shrink();
                return _LayerItem(node: childNode, nodeMap: widget.nodeMap, depth: widget.depth + 1, onSelect: widget.onSelect);
              }),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(color: FigmaColors.text1, fontSize: 11, fontWeight: FontWeight.w500));
  }
}

class _EditableInputField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const _EditableInputField({
    required this.label,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<_EditableInputField> createState() => _EditableInputFieldState();
}

class _EditableInputFieldState extends State<_EditableInputField> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_EditableInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isFocused) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: FigmaColors.bg1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _isFocused ? FigmaColors.accent : FigmaColors.border),
      ),
      child: Row(
        children: [
          Text(widget.label, style: const TextStyle(color: FigmaColors.text3, fontSize: 10)),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onFocusChange: (focused) => setState(() => _isFocused = focused),
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: widget.onChanged,
                onEditingComplete: () {
                  widget.onChanged?.call(_controller.text);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String value;

  const _InputField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: FigmaColors.bg1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: FigmaColors.border),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: FigmaColors.text3, fontSize: 10)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: FigmaColors.text1, fontSize: 11), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _AlignButton extends StatelessWidget {
  final IconData icon;
  const _AlignButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, size: 14, color: FigmaColors.text2),
    );
  }
}

class _FillItem extends StatelessWidget {
  final Map<String, dynamic> fill;
  const _FillItem({required this.fill});

  @override
  Widget build(BuildContext context) {
    final type = fill['type'] ?? 'UNKNOWN';
    Color? color;
    String label = type.toString();

    if (type == 'SOLID') {
      final c = fill['color'];
      if (c is Map) {
        color = Color.fromRGBO(
          ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          (c['a'] as num?)?.toDouble() ?? 1.0,
        );
        final hex = color.value.toRadixString(16).substring(2).toUpperCase();
        label = '#$hex';
      }
    } else if (type == 'IMAGE') {
      label = 'Image';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color ?? FigmaColors.bg3,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FigmaColors.border),
            ),
            child: type == 'IMAGE' ? const Icon(Icons.image, size: 12, color: FigmaColors.text2) : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: FigmaColors.text1, fontSize: 11))),
          Icon(Icons.visibility_outlined, size: 14, color: FigmaColors.text3),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 1,
      color: FigmaColors.border,
    );
  }
}

/// Simple canvas widget without page selector (for embedding)
class FigmaSimpleCanvas extends StatelessWidget {
  final Map<String, dynamic> node;
  final Map<String, Map<String, dynamic>> nodeMap;
  final double scale;
  final bool showBounds;

  const FigmaSimpleCanvas({super.key, required this.node, required this.nodeMap, this.scale = 1.0, this.showBounds = false});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.1,
      maxScale: 10.0,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: FigmaNodeWidget(node: node, nodeMap: nodeMap, scale: scale, showBounds: showBounds),
    );
  }
}
