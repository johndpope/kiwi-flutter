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
    _assetSearchController.dispose();
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
          body: Stack(
            children: [
              Column(
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
              // Component detail panel overlay
              if (_selectedComponentForDetail != null)
                _buildComponentDetailPanel(),
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

          // Center - just show document name (not page selector)
          Text(
            widget.document.documentNode?['name'] as String? ?? 'Untitled',
            style: const TextStyle(color: FigmaColors.text1, fontSize: 13),
          ),

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
          // Panel header with tabs - Figma style with File/Assets
          Container(
            height: 40,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: FigmaColors.border, width: 1)),
            ),
            child: Row(
              children: [
                _PanelTab(label: 'File', selected: _leftPanelTab == 0, onTap: () => setState(() => _leftPanelTab = 0)),
                _PanelTab(label: 'Assets', selected: _leftPanelTab == 1, onTap: () => setState(() => _leftPanelTab = 1)),
                const Spacer(),
                // Library icon
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.menu_book_outlined, size: 18, color: FigmaColors.text2),
                ),
              ],
            ),
          ),
          // Content based on tab
          Expanded(child: _leftPanelTab == 0 ? _buildLayersContent() : _buildAssetsContent()),
        ],
      ),
    );
  }

  // File tab state
  bool _pagesExpanded = true;
  bool _componentsExpanded = true;

  Widget _buildLayersContent() {
    final pages = widget.document.pages;
    final componentsByCategory = _getComponentsByCategory();
    final sortedCategories = componentsByCategory.keys.toList()
      ..sort((a, b) {
        if (a.startsWith('A.') && !b.startsWith('A.')) return -1;
        if (!a.startsWith('A.') && b.startsWith('A.')) return 1;
        return a.compareTo(b);
      });

    return Column(
      children: [
        // ===== PAGES SECTION =====
        GestureDetector(
          onTap: () => setState(() => _pagesExpanded = !_pagesExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _pagesExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  size: 16,
                  color: FigmaColors.text2,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Pages',
                  style: TextStyle(color: FigmaColors.text1, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    // TODO: Add new page
                  },
                  child: const Icon(Icons.add, size: 16, color: FigmaColors.text2),
                ),
              ],
            ),
          ),
        ),
        // Pages list (collapsible)
        if (_pagesExpanded)
          ...pages.asMap().entries.map((entry) => _buildFilePageItem(entry.key, entry.value)),

        // ===== COMPONENTS DIVIDER =====
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Container(height: 1, color: FigmaColors.border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Components',
                  style: TextStyle(color: FigmaColors.text3, fontSize: 10),
                ),
              ),
              Expanded(child: Container(height: 1, color: FigmaColors.border)),
            ],
          ),
        ),

        // Component categories list (scrollable, limited height)
        if (sortedCategories.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: sortedCategories.length,
              itemBuilder: (context, index) {
                final category = sortedCategories[index];
                return _buildFileComponentItem(category, componentsByCategory[category] ?? []);
              },
            ),
          ),

        // ===== LAYERS SECTION =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FigmaColors.border, width: 1)),
          ),
          child: const Row(
            children: [
              Text(
                'Layers',
                style: TextStyle(color: FigmaColors.text1, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // Layer tree
        Expanded(child: _buildLayerTree()),
      ],
    );
  }

  Widget _buildFilePageItem(int index, Map<String, dynamic> page) {
    final pageName = page['name'] as String? ?? 'Page ${index + 1}';
    final isSelected = index == _currentPageIndex;

    return GestureDetector(
      onTap: () => _onPageChanged(index),
      child: Container(
        height: 28,
        padding: const EdgeInsets.only(left: 32, right: 12),
        color: isSelected ? FigmaColors.accent.withOpacity(0.3) : Colors.transparent,
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 14,
              color: isSelected ? FigmaColors.accent : FigmaColors.text3,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pageName,
                style: TextStyle(
                  color: isSelected ? FigmaColors.text1 : FigmaColors.text2,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileComponentItem(String category, List<Map<String, dynamic>> components) {
    // Extract category code (A.01, A.02, etc) and name
    String code = '';
    String name = category;
    final match = RegExp(r'^(A\.\d+)\s*(.*)$').firstMatch(category);
    if (match != null) {
      code = match.group(1) ?? '';
      name = match.group(2) ?? category;
    }

    // Get emoji based on category name
    String emoji = '📁';
    if (name.toLowerCase().contains('color')) {
      emoji = '🎨';
    } else if (name.toLowerCase().contains('material')) {
      emoji = '🧱';
    } else if (name.toLowerCase().contains('typography') || name.toLowerCase().contains('text')) {
      emoji = '📝';
    } else if (name.toLowerCase().contains('system')) {
      emoji = '🖥️';
    } else if (name.toLowerCase().contains('icon')) {
      emoji = '🔷';
    } else if (name.toLowerCase().contains('button')) {
      emoji = '🔘';
    } else if (name.toLowerCase().contains('menu')) {
      emoji = '📋';
    } else if (name.toLowerCase().contains('navigation')) {
      emoji = '🧭';
    }

    return GestureDetector(
      onTap: () {
        // Open component category in assets panel
        setState(() {
          _leftPanelTab = 1; // Switch to Assets tab
          _selectedAssetCategory = category;
        });
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                code,
                style: const TextStyle(color: FigmaColors.text3, fontSize: 10),
              ),
            ),
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name.isEmpty ? category : name,
                style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Asset panel state
  String? _selectedAssetCategory;
  int? _selectedAssetPageIndex; // Selected page in assets panel for drill-down
  Map<String, dynamic>? _selectedComponentForDetail; // Component shown in detail panel
  final TextEditingController _assetSearchController = TextEditingController();
  String _assetSearchQuery = '';

  Widget _buildAssetsContent() {
    // If a page is selected, show its children
    if (_selectedAssetPageIndex != null) {
      return _buildPageChildrenView();
    }

    // If a component category is selected, show its components
    if (_selectedAssetCategory != null) {
      return _buildComponentCategoryView();
    }

    // Otherwise show the main assets view with Pages and Components sections
    return _buildAssetsMainView();
  }

  Widget _buildAssetsMainView() {
    final allPages = widget.document.pages;
    final query = _assetSearchQuery.toLowerCase();

    // Filter pages based on search query
    final filteredPages = query.isEmpty
        ? allPages.asMap().entries.toList()
        : allPages.asMap().entries.where((entry) {
            final pageName = (entry.value['name'] as String? ?? '').toLowerCase();
            return pageName.contains(query);
          }).toList();

    // Get filtered component categories
    final componentsByCategory = _getComponentsByCategory();
    final filteredCategories = query.isEmpty
        ? componentsByCategory.keys.toList()
        : componentsByCategory.keys.where((cat) => cat.toLowerCase().contains(query)).toList();

    // Sort categories
    filteredCategories.sort((a, b) {
      if (a.startsWith('A.') && !b.startsWith('A.')) return -1;
      if (!a.startsWith('A.') && b.startsWith('A.')) return 1;
      return a.compareTo(b);
    });

    return Column(
      children: [
        // Search bar with real TextField
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
            child: Row(
              children: [
                const Icon(Icons.search, size: 14, color: FigmaColors.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _assetSearchController,
                    style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: 'Search assets (e.g., A.07, Button)',
                      hintStyle: TextStyle(color: FigmaColors.text3, fontSize: 11),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      setState(() => _assetSearchQuery = value);
                    },
                  ),
                ),
                if (_assetSearchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _assetSearchController.clear();
                      setState(() => _assetSearchQuery = '');
                    },
                    child: const Icon(Icons.close, size: 14, color: FigmaColors.text3),
                  )
                else
                  const Icon(Icons.tune, size: 14, color: FigmaColors.text3),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Pages section (only show if matches or no search)
              if (filteredPages.isNotEmpty) ...[
                _buildAssetsSectionHeader('Pages', Icons.description_outlined),
                ...filteredPages.map((entry) => _buildPageAssetItem(entry.key, entry.value)),
                const SizedBox(height: 8),
              ],
              // Components section
              if (filteredCategories.isNotEmpty) ...[
                _buildAssetsSectionHeader('Components', Icons.widgets_outlined),
                ...filteredCategories.take(10).map((category) {
                  final components = componentsByCategory[category] ?? [];
                  return _buildComponentCategoryItem(category, components);
                }),
              ],
              // No results message
              if (filteredPages.isEmpty && filteredCategories.isEmpty && query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.search_off, size: 32, color: FigmaColors.text3),
                        const SizedBox(height: 8),
                        Text(
                          'No results for "$_assetSearchQuery"',
                          style: const TextStyle(color: FigmaColors.text3, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FigmaColors.border, width: 1)),
          ),
          child: Text(
            query.isEmpty
                ? '${allPages.length} pages, ${_getComponentCount()} components'
                : '${filteredPages.length} pages, ${filteredCategories.length} categories',
            style: const TextStyle(color: FigmaColors.text3, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetsSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: FigmaColors.text2),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: FigmaColors.text1,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageAssetItem(int index, Map<String, dynamic> page) {
    final pageName = page['name'] as String? ?? 'Page ${index + 1}';
    final isCurrentPage = index == _currentPageIndex;

    // Count top-level children for this page
    final childKeys = page['children'] as List<dynamic>? ?? [];
    final childCount = childKeys.length;

    return GestureDetector(
      onTap: () => setState(() => _selectedAssetPageIndex = index),
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: FigmaColors.bg1,
          borderRadius: BorderRadius.circular(8),
          border: isCurrentPage ? Border.all(color: FigmaColors.accent, width: 1) : null,
        ),
        child: Row(
          children: [
            // Thumbnail area - shows a mini preview representation
            Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildPageThumbnail(page),
            ),
            // Page info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (isCurrentPage)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: FigmaColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            pageName.length > 18 ? '${pageName.substring(0, 18)}...' : pageName,
                            style: const TextStyle(
                              color: FigmaColors.text1,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$childCount frames',
                      style: const TextStyle(
                        color: FigmaColors.text3,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, size: 16, color: FigmaColors.text3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageThumbnail(Map<String, dynamic> page) {
    // Get children of this page to create a mini preview
    final childKeys = page['children'] as List<dynamic>? ?? [];

    if (childKeys.isEmpty) {
      return const Center(
        child: Icon(Icons.insert_drive_file_outlined, size: 24, color: FigmaColors.text3),
      );
    }

    // Show up to 4 rectangles representing frames
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: childKeys.take(4).map((childKey) {
          final child = widget.document.nodeMap[childKey];
          final type = child?['type'] as String? ?? '';

          Color frameColor = Colors.grey.shade400;
          if (type == 'FRAME') {
            frameColor = Colors.blue.shade300;
          } else if (type == 'COMPONENT' || type == 'COMPONENT_SET') {
            frameColor = Colors.purple.shade300;
          } else if (type == 'SECTION') {
            frameColor = Colors.green.shade300;
          }

          return Container(
            width: 20,
            height: 16,
            decoration: BoxDecoration(
              color: frameColor,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPageChildrenView() {
    final pageIndex = _selectedAssetPageIndex!;
    final page = widget.document.pages[pageIndex];
    final pageName = page['name'] as String? ?? 'Page ${pageIndex + 1}';
    final childKeys = page['children'] as List<dynamic>? ?? [];

    // Get actual child nodes
    final children = childKeys
        .map((key) => widget.document.nodeMap[key])
        .whereType<Map<String, dynamic>>()
        .toList();

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
                    'Search in page',
                    style: TextStyle(color: FigmaColors.text3, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Breadcrumb navigation
        GestureDetector(
          onTap: () => setState(() => _selectedAssetPageIndex = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.chevron_left, size: 14, color: FigmaColors.text2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Pages / $pageName',
                    style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Children grid
        Expanded(
          child: _buildPageChildrenGrid(children),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FigmaColors.border, width: 1)),
          ),
          child: Row(
            children: [
              Text(
                '${children.length} items',
                style: const TextStyle(color: FigmaColors.text3, fontSize: 10),
              ),
              const Spacer(),
              // Button to switch to this page
              GestureDetector(
                onTap: () {
                  _onPageChanged(pageIndex);
                  setState(() => _selectedAssetPageIndex = null);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FigmaColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Go to page',
                    style: TextStyle(color: FigmaColors.text1, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageChildrenGrid(List<Map<String, dynamic>> children) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        final name = child['name'] as String? ?? 'Element';
        final type = child['type'] as String? ?? 'FRAME';

        // Icon and color based on type
        IconData typeIcon = Icons.crop_square;
        Color iconColor = FigmaColors.text3;
        Color bgColor = const Color(0xFFF5F5F5);

        switch (type) {
          case 'FRAME':
            typeIcon = Icons.crop_square;
            iconColor = Colors.blue.shade400;
            break;
          case 'COMPONENT':
            typeIcon = Icons.diamond_outlined;
            iconColor = Colors.purple.shade400;
            break;
          case 'COMPONENT_SET':
            typeIcon = Icons.auto_awesome_mosaic;
            iconColor = Colors.purple.shade400;
            break;
          case 'SECTION':
            typeIcon = Icons.folder_outlined;
            iconColor = Colors.green.shade400;
            break;
          case 'GROUP':
            typeIcon = Icons.folder_open;
            iconColor = Colors.orange.shade400;
            break;
        }

        return GestureDetector(
          onTap: () {
            DebugOverlayController.instance.selectNode(child);
            _centerOnNode(child);
          },
          child: Container(
            decoration: BoxDecoration(
              color: FigmaColors.bg1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Preview area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Center(
                      child: Icon(typeIcon, size: 32, color: iconColor),
                    ),
                  ),
                ),
                // Name area
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(typeIcon, size: 12, color: iconColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          name.length > 12 ? '${name.substring(0, 12)}...' : name,
                          style: const TextStyle(
                            color: FigmaColors.text1,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _getComponentCount() {
    int count = 0;
    for (final node in widget.document.nodeMap.values) {
      final type = node['type'];
      if (type == 'COMPONENT' || type == 'COMPONENT_SET') {
        count++;
      }
    }
    return count;
  }

  Widget _buildComponentCategoryItem(String category, List<Map<String, dynamic>> components) {
    IconData categoryIcon = Icons.folder_outlined;
    Color iconColor = FigmaColors.text3;

    if (category.contains('Material')) {
      categoryIcon = Icons.palette_outlined;
      iconColor = const Color(0xFFE57373);
    } else if (category.contains('System') || category.contains('Status')) {
      categoryIcon = Icons.computer_outlined;
      iconColor = const Color(0xFF64B5F6);
    } else if (category.contains('Navigation')) {
      categoryIcon = Icons.navigation_outlined;
      iconColor = const Color(0xFF81C784);
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedAssetCategory = category),
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: FigmaColors.bg1,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: FigmaColors.bg3,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(categoryIcon, size: 24, color: iconColor),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.length > 20 ? '${category.substring(0, 20)}...' : category,
                      style: const TextStyle(
                        color: FigmaColors.text1,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${components.length} items',
                      style: const TextStyle(
                        color: FigmaColors.text3,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, size: 16, color: FigmaColors.text3),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _getComponentsByCategory() {
    final componentsByCategory = <String, List<Map<String, dynamic>>>{};

    for (final node in widget.document.nodeMap.values) {
      final type = node['type'];
      if (type == 'COMPONENT' || type == 'COMPONENT_SET') {
        String category = 'Uncategorized';

        final parentIndex = node['parentIndex'];
        if (parentIndex is Map) {
          final parentGuid = parentIndex['guid'];
          if (parentGuid != null) {
            final parentKey = '${parentGuid['sessionID'] ?? 0}:${parentGuid['localID'] ?? 0}';
            var parent = widget.document.nodeMap[parentKey];

            while (parent != null) {
              final parentType = parent['type'];
              final parentName = parent['name'] as String? ?? '';

              if (parentType == 'SECTION' ||
                  (parentType == 'FRAME' && parentName.contains('.') && parentName.contains(' '))) {
                category = parentName;
                break;
              }

              final grandParent = parent['parentIndex'];
              if (grandParent is Map) {
                final gpGuid = grandParent['guid'];
                if (gpGuid != null) {
                  final gpKey = '${gpGuid['sessionID'] ?? 0}:${gpGuid['localID'] ?? 0}';
                  parent = widget.document.nodeMap[gpKey];
                } else {
                  break;
                }
              } else {
                break;
              }
            }
          }
        }

        componentsByCategory.putIfAbsent(category, () => []);
        componentsByCategory[category]!.add(node);
      }
    }

    return componentsByCategory;
  }

  Widget _buildComponentCategoryView() {
    final componentsByCategory = _getComponentsByCategory();
    final components = componentsByCategory[_selectedAssetCategory] ?? [];
    final categoryName = _selectedAssetCategory!;

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
                    'Search in category',
                    style: TextStyle(color: FigmaColors.text3, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Breadcrumb navigation
        GestureDetector(
          onTap: () => setState(() => _selectedAssetCategory = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.chevron_left, size: 14, color: FigmaColors.text2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Components / ${categoryName.length > 15 ? '${categoryName.substring(0, 15)}...' : categoryName}',
                    style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Components grid
        Expanded(
          child: _buildComponentsGrid(components),
        ),
        // Footer
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

  Widget _buildComponentsGrid(List<Map<String, dynamic>> components) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: components.length,
      itemBuilder: (context, index) {
        final comp = components[index];
        final name = comp['name'] as String? ?? 'Component';
        final type = comp['type'] as String?;

        // Determine icon based on component type/name
        IconData compIcon = Icons.widgets_outlined;
        Color iconBg = FigmaColors.bg3;

        if (name.toLowerCase().contains('bar')) {
          compIcon = Icons.horizontal_rule;
        } else if (name.toLowerCase().contains('status')) {
          compIcon = Icons.signal_cellular_alt;
        } else if (name.toLowerCase().contains('battery')) {
          compIcon = Icons.battery_full;
        } else if (name.toLowerCase().contains('wifi')) {
          compIcon = Icons.wifi;
        } else if (name.toLowerCase().contains('time') || name.contains(':')) {
          compIcon = Icons.access_time;
        }

        // Component type indicator
        final isVariant = type == 'COMPONENT_SET';

        return GestureDetector(
          onTap: () {
            // Show component detail panel
            setState(() => _selectedComponentForDetail = comp);
          },
          child: Container(
            decoration: BoxDecoration(
              color: FigmaColors.bg1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Preview area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Center(
                      child: Icon(compIcon, size: 32, color: FigmaColors.text3),
                    ),
                  ),
                ),
                // Name area
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      // Component type indicator
                      Icon(
                        isVariant ? Icons.auto_awesome_mosaic : Icons.diamond_outlined,
                        size: 12,
                        color: isVariant ? const Color(0xFF81C784) : const Color(0xFFBA68C8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          name.length > 12 ? name.substring(0, 12) + '...' : name,
                          style: const TextStyle(
                            color: FigmaColors.text1,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============ COMPONENT DETAIL PANEL ============
  Widget _buildComponentDetailPanel() {
    final comp = _selectedComponentForDetail!;
    final name = comp['name'] as String? ?? 'Component';
    final type = comp['type'] as String?;
    final isVariantSet = type == 'COMPONENT_SET';

    // Count variants if this is a component set
    int variantCount = 0;
    if (isVariantSet) {
      final children = comp['children'] as List? ?? [];
      variantCount = children.length;
    }

    // Extract component properties from the node
    final componentProperties = _extractComponentProperties(comp);

    return Positioned(
      top: 48, // Below toolbar
      right: 0,
      bottom: 40, // Above footer
      width: 360,
      child: Material(
        elevation: 16,
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: FigmaColors.bg2,
            border: Border(
              left: BorderSide(color: FigmaColors.border, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: FigmaColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Details',
                            style: TextStyle(
                              color: FigmaColors.text1,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.document.documentNode?['name'] as String? ?? 'Document',
                            style: const TextStyle(
                              color: FigmaColors.text3,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedComponentForDetail = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: FigmaColors.bg3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.close, size: 16, color: FigmaColors.text2),
                      ),
                    ),
                  ],
                ),
              ),
              // Preview area
              Container(
                height: 180,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _buildComponentPreview(comp),
                ),
              ),
              // Component name and info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      isVariantSet ? Icons.auto_awesome_mosaic : Icons.diamond_outlined,
                      size: 18,
                      color: isVariantSet ? const Color(0xFF81C784) : const Color(0xFFBA68C8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: FigmaColors.text1,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isVariantSet)
                            Text(
                              'Includes $variantCount variants',
                              style: const TextStyle(
                                color: FigmaColors.text3,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Insert instance button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () {
                    // Insert instance at canvas center
                    _insertComponentInstance(comp);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: FigmaColors.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text(
                        'Insert instance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Properties section
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Properties header
                    Row(
                      children: [
                        const Icon(Icons.tune, size: 14, color: FigmaColors.text2),
                        const SizedBox(width: 6),
                        const Text(
                          'Properties',
                          style: TextStyle(
                            color: FigmaColors.text1,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {},
                          child: const Icon(Icons.refresh, size: 14, color: FigmaColors.text3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Properties list
                    ...componentProperties.map((prop) => _buildPropertyRow(prop)),
                    const SizedBox(height: 16),
                    // Variable modes section
                    if (_hasVariableModes(comp)) ...[
                      const Text(
                        'Variable modes',
                        style: TextStyle(
                          color: FigmaColors.text1,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildVariableModesSection(comp),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentPreview(Map<String, dynamic> comp) {
    final name = comp['name'] as String? ?? '';
    final type = comp['type'] as String?;

    // Determine icon based on component name
    IconData icon = Icons.widgets_outlined;
    Color iconColor = FigmaColors.text3;

    if (name.toLowerCase().contains('button')) {
      icon = Icons.smart_button;
      iconColor = Colors.blue;
    } else if (name.toLowerCase().contains('text')) {
      icon = Icons.text_fields;
      iconColor = Colors.blue;
    } else if (name.toLowerCase().contains('icon')) {
      icon = Icons.emoji_symbols;
      iconColor = Colors.purple;
    } else if (name.toLowerCase().contains('menu')) {
      icon = Icons.menu;
      iconColor = Colors.green;
    } else if (name.toLowerCase().contains('bar')) {
      icon = Icons.horizontal_rule;
      iconColor = Colors.orange;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 48, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          name.length > 20 ? '${name.substring(0, 20)}...' : name,
          style: const TextStyle(
            color: FigmaColors.text3,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _extractComponentProperties(Map<String, dynamic> comp) {
    final properties = <Map<String, dynamic>>[];
    final name = comp['name'] as String? ?? '';

    // Extract component properties from componentPropertyDefinitions if available
    final propDefs = comp['componentPropertyDefinitions'] as Map?;
    if (propDefs != null) {
      for (final entry in propDefs.entries) {
        final key = entry.key as String;
        final def = entry.value as Map?;
        if (def != null) {
          final propType = def['type'] as String?;
          final defaultValue = def['defaultValue'];

          properties.add({
            'name': _formatPropertyName(key),
            'type': propType ?? 'TEXT',
            'value': defaultValue,
            'options': def['variantOptions'] as List?,
          });
        }
      }
    }

    // If no properties found, generate some common ones based on component name
    if (properties.isEmpty) {
      if (name.toLowerCase().contains('button')) {
        properties.addAll([
          {'name': 'Size', 'type': 'VARIANT', 'value': 'Large', 'options': ['Small', 'Medium', 'Large']},
          {'name': 'Style', 'type': 'VARIANT', 'value': 'Filled', 'options': ['Filled', 'Outlined', 'Ghost']},
          {'name': 'State', 'type': 'VARIANT', 'value': 'Default', 'options': ['Default', 'Hover', 'Pressed', 'Disabled']},
          {'name': 'Has Icon', 'type': 'BOOLEAN', 'value': true},
          {'name': 'Has Text', 'type': 'BOOLEAN', 'value': true},
          {'name': 'Text', 'type': 'TEXT', 'value': 'Button'},
        ]);
      } else if (name.toLowerCase().contains('text')) {
        properties.addAll([
          {'name': 'Style', 'type': 'VARIANT', 'value': 'Body', 'options': ['Headline', 'Title', 'Body', 'Caption']},
          {'name': 'Weight', 'type': 'VARIANT', 'value': 'Regular', 'options': ['Light', 'Regular', 'Medium', 'Bold']},
          {'name': 'Text', 'type': 'TEXT', 'value': 'Text'},
        ]);
      } else {
        // Generic properties
        properties.addAll([
          {'name': 'Visible', 'type': 'BOOLEAN', 'value': true},
        ]);
      }
    }

    return properties;
  }

  String _formatPropertyName(String key) {
    // Convert camelCase or snake_case to Title Case
    return key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Widget _buildPropertyRow(Map<String, dynamic> prop) {
    final name = prop['name'] as String;
    final type = prop['type'] as String;
    final value = prop['value'];
    final options = prop['options'] as List?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: const TextStyle(color: FigmaColors.text2, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildPropertyControl(type, value, options),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyControl(String type, dynamic value, List? options) {
    switch (type) {
      case 'BOOLEAN':
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                color: value == true ? FigmaColors.accent : FigmaColors.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value == true ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );

      case 'VARIANT':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: FigmaColors.bg3,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (options != null && options.isNotEmpty)
                const Text('🎨 ', style: TextStyle(fontSize: 10)),
              Expanded(
                child: Text(
                  value?.toString() ?? '',
                  style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 12, color: FigmaColors.text3),
            ],
          ),
        );

      case 'TEXT':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: FigmaColors.bg3,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value?.toString() ?? '',
            style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: FigmaColors.bg3,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value?.toString() ?? '-',
            style: const TextStyle(color: FigmaColors.text1, fontSize: 11),
          ),
        );
    }
  }

  bool _hasVariableModes(Map<String, dynamic> comp) {
    // Check if component has variable bindings
    return comp['boundVariables'] != null || comp['explicitVariableModes'] != null;
  }

  Widget _buildVariableModesSection(Map<String, dynamic> comp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: FigmaColors.bg1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Text('1. Themes', style: TextStyle(color: FigmaColors.text2, fontSize: 11)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: FigmaColors.bg3,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌤️ ', style: TextStyle(fontSize: 10)),
                const Text('Auto (Light)', style: TextStyle(color: FigmaColors.text1, fontSize: 11)),
                const Icon(Icons.keyboard_arrow_down, size: 12, color: FigmaColors.text3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _insertComponentInstance(Map<String, dynamic> comp) {
    // For now, center on the component and close the panel
    DebugOverlayController.instance.selectNode(comp);
    _centerOnNode(comp);
    setState(() => _selectedComponentForDetail = null);

    // TODO: Actually create an instance and add it to the canvas
    // This would require implementing node creation and document modification
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
