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
import 'ui/design_panel/design_panel.dart';

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

  // View options
  bool _showPixelGrid = false;
  bool _showLayoutGrids = false;
  bool _showRulers = false;
  bool _showOutlines = false;

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

  // Main menu overlay
  OverlayEntry? _mainMenuOverlay;

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
    _hideMainMenu();
    super.dispose();
  }

  // ============ MAIN MENU ============
  void _hideMainMenu() {
    _mainMenuOverlay?.remove();
    _mainMenuOverlay = null;
  }

  void _showMainMenu(BuildContext buttonContext) {
    _hideMainMenu();

    final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _mainMenuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss area
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideMainMenu,
            ),
          ),
          // Main menu dropdown
          Positioned(
            left: position.dx,
            top: position.dy + 40,
            child: _FigmaMainMenu(
              onDismiss: _hideMainMenu,
              onBackToFiles: () {
                _hideMainMenu();
                // TODO: Navigate back to files
              },
              onAction: (action) {
                _hideMainMenu();
                _handleMenuAction(action);
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(buttonContext).insert(_mainMenuOverlay!);
  }

  /// Handle keyboard shortcut actions
  void _handleShortcut(ShortcutAction action) {
    // Skip all shortcuts when text editing is active - let the text field handle them
    if (DebugOverlayController.instance.isEditingText) {
      return;
    }

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

  /// Handle menu actions
  void _handleMenuAction(String action) {
    debugPrint('Menu action: $action');

    switch (action.toLowerCase()) {
      // Edit menu
      case 'undo':
        _handleShortcut(ShortcutAction.undo);
        break;
      case 'redo':
        _handleShortcut(ShortcutAction.redo);
        break;
      case 'copy':
        _handleShortcut(ShortcutAction.copy);
        break;
      case 'cut':
        _handleShortcut(ShortcutAction.cut);
        break;
      case 'paste':
        _handleShortcut(ShortcutAction.paste);
        break;
      case 'duplicate':
        _handleShortcut(ShortcutAction.duplicate);
        break;
      case 'delete':
        _handleShortcut(ShortcutAction.delete);
        break;
      case 'select all':
        _handleShortcut(ShortcutAction.selectAll);
        break;

      // View menu - toggles
      case 'pixel grid':
        setState(() => _showPixelGrid = !_showPixelGrid);
        break;
      case 'layout grids':
        setState(() => _showLayoutGrids = !_showLayoutGrids);
        break;
      case 'rulers':
        setState(() => _showRulers = !_showRulers);
        break;
      case 'outlines':
        setState(() => _showOutlines = !_showOutlines);
        break;
      case 'panels':
        setState(() {
          _showLeftPanel = !_showLeftPanel;
          _showRightPanel = !_showRightPanel;
        });
        break;

      // View menu - zoom
      case 'zoom in':
        _handleShortcut(ShortcutAction.zoomIn);
        break;
      case 'zoom out':
        _handleShortcut(ShortcutAction.zoomOut);
        break;
      case 'zoom to 100%':
        _handleShortcut(ShortcutAction.zoomTo100);
        break;
      case 'zoom to fit':
        _handleShortcut(ShortcutAction.zoomToFit);
        break;
      case 'zoom to selection':
        _zoomToSelection();
        break;

      // Object menu
      case 'group selection':
        _handleShortcut(ShortcutAction.group);
        break;
      case 'ungroup selection':
        _handleShortcut(ShortcutAction.ungroup);
        break;

      // Arrange menu
      case 'bring to front':
        _handleShortcut(ShortcutAction.bringToFront);
        break;
      case 'bring forward':
        _handleShortcut(ShortcutAction.bringForward);
        break;
      case 'send backward':
        _handleShortcut(ShortcutAction.sendBackward);
        break;
      case 'send to back':
        _handleShortcut(ShortcutAction.sendToBack);
        break;

      default:
        // Action not yet implemented - just log it
        debugPrint('Unhandled menu action: $action');
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

  void _zoomToSelection() {
    final selectedNode = DebugOverlayController.instance.selectedNode;
    if (selectedNode == null) return;

    final bounds = _getAbsoluteNodeBounds(selectedNode, widget.document.nodeMap);
    final screenSize = MediaQuery.of(context).size;
    final availableWidth = screenSize.width - (_showLeftPanel ? 240 : 0) - (_showRightPanel ? 300 : 0);
    final availableHeight = screenSize.height - 88;
    final padding = 100.0;

    final scaleX = (availableWidth - padding) / bounds.width;
    final scaleY = (availableHeight - padding) / bounds.height;
    final newScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.1, 8.0);

    final centerX = bounds.left + bounds.width / 2;
    final centerY = bounds.top + bounds.height / 2;
    final offsetX = availableWidth / 2 - centerX * newScale + (_showLeftPanel ? 240 : 0);
    final offsetY = availableHeight / 2 - centerY * newScale + 48;

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
                        if (_showRightPanel) _buildNewRightPanel(),
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
          Builder(
            builder: (context) => _ToolbarButton(
              icon: Icons.menu,
              onTap: () => _showMainMenu(context),
            ),
          ),
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
        // Pages list (collapsible, constrained height)
        if (_pagesExpanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: pages.length,
              itemBuilder: (context, index) => _buildFilePageItem(index, pages[index]),
            ),
          ),

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
    // Get ABSOLUTE bounds by walking up parent hierarchy
    final absoluteBounds = _getAbsoluteNodeBounds(node, widget.document.nodeMap);

    // Get the canvas area dimensions
    final screenSize = MediaQuery.of(context).size;
    final canvasWidth = screenSize.width - (_showLeftPanel ? 240 : 0) - (_showRightPanel ? 300 : 0);
    final canvasHeight = screenSize.height - 88; // toolbar + bottom bar

    // Calculate center of the node using absolute coordinates
    final nodeCenterX = absoluteBounds.left + absoluteBounds.width / 2;
    final nodeCenterY = absoluteBounds.top + absoluteBounds.height / 2;

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

          // Pixel grid overlay
          if (_showPixelGrid)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scaleNotifier,
                  builder: (context, scale, _) {
                    // Only show grid when zoomed in enough
                    if (scale < 4.0) {
                      return const Center(
                        child: Text(
                          'Zoom in to see pixel grid',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      );
                    }
                    return CustomPaint(
                      painter: _PixelGridPainter(
                        scale: scale,
                        transform: _transformController.value,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Rulers overlay
          if (_showRulers)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scaleNotifier,
                  builder: (context, scale, _) {
                    return CustomPaint(
                      painter: _RulersPainter(
                        scale: scale,
                        transform: _transformController.value,
                        leftPanelWidth: _showLeftPanel ? 240.0 : 0.0,
                      ),
                    );
                  },
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

          // Text editor overlay
          ListenableBuilder(
            listenable: DebugOverlayController.instance,
            builder: (context, _) {
              final controller = DebugOverlayController.instance;
              if (!controller.isEditingText) return const SizedBox.shrink();

              final node = controller.editingTextNode!;

              // Calculate ABSOLUTE canvas position by walking up parent hierarchy
              final absoluteBounds = _getAbsoluteNodeBounds(node, widget.document.nodeMap);

              // Transform bounds to screen coordinates
              final matrix = _transformController.value;
              final scale = matrix.getMaxScaleOnAxis();
              final translation = matrix.getTranslation();

              final screenBounds = Rect.fromLTWH(
                absoluteBounds.left * scale + translation.x,
                absoluteBounds.top * scale + translation.y,
                absoluteBounds.width * scale,
                absoluteBounds.height * scale,
              );

              return Positioned(
                left: screenBounds.left,
                top: screenBounds.top,
                width: screenBounds.width,
                height: screenBounds.height.clamp(24.0, 500.0), // Min height for editing
                child: _InlineTextEditField(
                  node: node,
                  scale: scale,
                  onComplete: (newText) {
                    // Update the node text
                    final textData = (node['textData'] as Map<String, dynamic>?) ?? {};
                    textData['characters'] = newText;
                    node['textData'] = textData;

                    // Update in document
                    final nodeId = node['_guidKey']?.toString();
                    if (nodeId != null && widget.document.nodeMap.containsKey(nodeId)) {
                      widget.document.nodeMap[nodeId] = node;
                    }
                    controller.stopTextEditing();
                    // Force canvas rebuild to show updated text
                    setState(() {
                      _cachedCanvasContent = null;
                    });
                  },
                  onCancel: () {
                    controller.stopTextEditing();
                  },
                ),
              );
            },
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

  // ============ NEW RIGHT PANEL (FigmaDesignPanel) ============
  Widget _buildNewRightPanel() {
    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        final node = DebugOverlayController.instance.selectedNode;
        return FigmaDesignPanel(
          node: node,
          zoomLevel: _scale,
          onPropertyChanged: (path, value) {
            // Handle property changes
            print('Property changed: $path = $value');
          },
          onZoomChanged: (zoom) {
            setState(() => _scale = zoom);
          },
        );
      },
    );
  }

  // ============ OLD RIGHT PANEL (kept for reference) ============
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

  /// Calculate the ABSOLUTE canvas position of a node by walking up the parent hierarchy
  Rect _getAbsoluteNodeBounds(Map<String, dynamic> node, Map<String, Map<String, dynamic>> nodeMap) {
    final props = FigmaNodeProperties.fromMap(node);

    // Start with local coordinates
    double x = props.x;
    double y = props.y;
    double width = props.width;
    double height = props.height;

    // Walk up the parent hierarchy to accumulate transforms
    Map<String, dynamic>? current = node;
    while (current != null) {
      final parentIndex = current['parentIndex'];
      if (parentIndex is Map) {
        final parentGuid = parentIndex['guid'];
        if (parentGuid != null) {
          final parentKey = '${parentGuid['sessionID'] ?? 0}:${parentGuid['localID'] ?? 0}';
          final parentNode = nodeMap[parentKey];
          if (parentNode != null) {
            final parentType = parentNode['type'] as String?;
            // Stop at CANVAS level - that's the page root
            if (parentType == 'CANVAS') {
              break;
            }
            // Add parent's position to our coordinates
            final parentProps = FigmaNodeProperties.fromMap(parentNode);
            x += parentProps.x;
            y += parentProps.y;
            current = parentNode;
          } else {
            break;
          }
        } else {
          break;
        }
      } else {
        break;
      }
    }

    return Rect.fromLTWH(x, y, width, height);
  }
}

// ============ INLINE TEXT EDIT FIELD ============

class _InlineTextEditField extends StatefulWidget {
  final Map<String, dynamic> node;
  final double scale;
  final void Function(String) onComplete;
  final VoidCallback onCancel;

  const _InlineTextEditField({
    required this.node,
    required this.scale,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<_InlineTextEditField> createState() => _InlineTextEditFieldState();
}

class _InlineTextEditFieldState extends State<_InlineTextEditField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final textData = widget.node['textData'] as Map<String, dynamic>? ?? {};
    final initialText = textData['characters'] as String? ?? '';
    _controller = TextEditingController(text: initialText);
    _focusNode = FocusNode();

    // Auto-focus and select all text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extract text styling from node
    final textData = widget.node['textData'] as Map<String, dynamic>? ?? {};
    final styleOverrideTable = textData['styleOverrideTable'] as List? ?? [];

    // Get the default font size from the node
    double fontSize = 14.0;
    Color textColor = Colors.black;

    // Try to get font size from style override table
    if (styleOverrideTable.isNotEmpty) {
      final firstStyle = styleOverrideTable.first as Map<String, dynamic>?;
      if (firstStyle != null) {
        final fontSizeVal = firstStyle['fontSize'];
        if (fontSizeVal is num) {
          fontSize = fontSizeVal.toDouble();
        }

        // Get text color from fills
        final fills = firstStyle['fillPaints'] as List?;
        if (fills != null && fills.isNotEmpty) {
          final fill = fills.first as Map<String, dynamic>?;
          if (fill != null) {
            final color = fill['color'] as Map<String, dynamic>?;
            if (color != null) {
              final r = (color['r'] as num?)?.toDouble() ?? 0;
              final g = (color['g'] as num?)?.toDouble() ?? 0;
              final b = (color['b'] as num?)?.toDouble() ?? 0;
              final a = (color['a'] as num?)?.toDouble() ?? 1;
              textColor = Color.fromRGBO(
                (r * 255).round(),
                (g * 255).round(),
                (b * 255).round(),
                a,
              );
            }
          }
        }
      }
    }

    // Scale the font size with canvas zoom
    final scaledFontSize = fontSize * widget.scale;

    // Use Shortcuts with empty map to prevent parent shortcuts from capturing keys
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{},
      child: Actions(
        actions: <Type, Action<Intent>>{
          // Override all intents to do nothing - let the text field handle keys
        },
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              // Handle escape to cancel
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                widget.onCancel();
                return KeyEventResult.handled;
              }
              // Handle Enter to submit (without shift for newline)
              if (event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                widget.onComplete(_controller.text);
                return KeyEventResult.handled;
              }
            }
            // Let all other keys pass through to TextField
            return KeyEventResult.ignored;
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF0D99FF), width: 2),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                style: TextStyle(
                  fontSize: scaledFontSize.clamp(10.0, 100.0),
                  color: textColor,
                  height: 1.2,
                ),
                cursorColor: const Color(0xFF0D99FF),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                maxLines: null,
                onSubmitted: (value) {
                  widget.onComplete(value);
                },
              ),
            ),
          ),
        ),
      ),
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

class _LayerItemRow extends StatefulWidget {
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

  @override
  State<_LayerItemRow> createState() => _LayerItemRowState();
}

class _LayerItemRowState extends State<_LayerItemRow> {
  bool _isHovered = false;

  IconData _getIcon(String type) {
    switch (type) {
      case 'FRAME': return Icons.crop_free; // Frame icon
      case 'GROUP': return Icons.folder_outlined;
      case 'COMPONENT': return Icons.widgets_outlined;
      case 'COMPONENT_SET': return Icons.dashboard_outlined;
      case 'INSTANCE': return Icons.diamond_outlined;
      case 'TEXT': return Icons.text_fields;
      case 'RECTANGLE':
      case 'ROUNDED_RECTANGLE': return Icons.rectangle_outlined;
      case 'ELLIPSE': return Icons.circle_outlined;
      case 'VECTOR': return Icons.gesture;
      case 'LINE': return Icons.remove;
      case 'SECTION': return Icons.view_agenda_outlined;
      case 'BOOLEAN_OPERATION': return Icons.layers;
      default: return Icons.layers_outlined;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'FRAME': return const Color(0xFF6B7AFF); // Blue for frames
      case 'GROUP': return const Color(0xFFAA7AFF); // Purple for groups
      case 'COMPONENT':
      case 'COMPONENT_SET': return const Color(0xFF9747FF); // Purple for components
      case 'INSTANCE': return const Color(0xFF9747FF); // Purple for instances
      case 'TEXT': return const Color(0xFFB3B3B3); // Gray for text
      case 'VECTOR':
      case 'BOOLEAN_OPERATION': return const Color(0xFF18A0FB); // Blue for vectors
      case 'SECTION': return const Color(0xFFFF7262); // Red/orange for sections
      default: return const Color(0xFFB3B3B3); // Default gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item.node['name'] as String? ?? 'Unnamed';
    final type = widget.item.node['type'] as String? ?? 'UNKNOWN';
    final nodeKey = widget.item.node['_guidKey']?.toString();
    final isVisible = widget.item.node['visible'] as bool? ?? true;
    final isLocked = widget.item.node['locked'] as bool? ?? false;

    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        final isSelected = DebugOverlayController.instance.selectedNode?['_guidKey'] == nodeKey;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: widget.onToggleExpand,
            child: Container(
              height: 28,
              padding: EdgeInsets.only(left: 4 + widget.item.depth * 12.0, right: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0D99FF).withValues(alpha: 0.2) // Figma selection blue with transparency
                    : (_isHovered ? FigmaColors.bg3 : Colors.transparent),
                border: widget.isFocused && !isSelected
                    ? Border.all(color: FigmaColors.accent, width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  // Expand/collapse arrow
                  GestureDetector(
                    onTap: widget.onToggleExpand,
                    child: SizedBox(
                      width: 16,
                      child: widget.item.hasChildren
                          ? Icon(
                              widget.item.isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                              size: 14,
                              color: FigmaColors.text3,
                            )
                          : null,
                    ),
                  ),
                  // Type icon with color
                  Icon(
                    _getIcon(type),
                    size: 14,
                    color: isSelected ? FigmaColors.text1 : _getIconColor(type),
                  ),
                  const SizedBox(width: 6),
                  // Name
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isVisible
                            ? (isSelected ? FigmaColors.text1 : FigmaColors.text2)
                            : FigmaColors.text3.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Lock icon (show when locked or hovered)
                  if (isLocked || _isHovered)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        isLocked ? Icons.lock : Icons.lock_open_outlined,
                        size: 12,
                        color: isLocked ? FigmaColors.text2 : FigmaColors.text3.withValues(alpha: 0.5),
                      ),
                    ),
                  // Visibility icon (show when hidden or hovered)
                  if (!isVisible || _isHovered)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 12,
                        color: isVisible ? FigmaColors.text3.withValues(alpha: 0.5) : FigmaColors.text3,
                      ),
                    ),
                ],
              ),
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

/// Figma Main Menu (hamburger menu dropdown)
class _FigmaMainMenu extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback? onBackToFiles;
  final void Function(String)? onAction;

  const _FigmaMainMenu({
    required this.onDismiss,
    this.onBackToFiles,
    this.onAction,
  });

  @override
  State<_FigmaMainMenu> createState() => _FigmaMainMenuState();
}

class _FigmaMainMenuState extends State<_FigmaMainMenu> {
  String? _hoveredSubmenu;
  OverlayEntry? _submenuOverlay;
  bool _isMouseOnSubmenu = false;

  @override
  void dispose() {
    _hideSubmenu();
    super.dispose();
  }

  void _hideSubmenu() {
    _submenuOverlay?.remove();
    _submenuOverlay = null;
    _isMouseOnSubmenu = false;
  }

  void _tryHideSubmenu(String submenuId) {
    // Only hide if mouse is not on the submenu and we're still on this submenu
    Future.delayed(const Duration(milliseconds: 150), () {
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      if (_hoveredSubmenu == submenuId && !_isMouseOnSubmenu) {
        _hideSubmenu();
        setState(() => _hoveredSubmenu = null);
      }
    });
  }

  void _showSubmenu(BuildContext context, String submenuId, List<_MainMenuItem> items) {
    _hideSubmenu();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _submenuOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: position.dx + size.width - 4,
        top: position.dy - 6,
        child: MouseRegion(
          onEnter: (_) => _isMouseOnSubmenu = true,
          onExit: (_) {
            _isMouseOnSubmenu = false;
            _tryHideSubmenu(submenuId);
          },
          child: _MainMenuSubmenu(
            items: items,
            onDismiss: widget.onDismiss,
            onAction: widget.onAction,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_submenuOverlay!);
    setState(() => _hoveredSubmenu = submenuId);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back to files button
            Padding(
              padding: const EdgeInsets.all(8),
              child: _MainMenuButton(
                label: 'Back to files',
                isPrimary: true,
                onTap: widget.onBackToFiles,
              ),
            ),
            // Actions row
            _MainMenuActionItem(
              icon: Icons.search,
              label: 'Actions...',
              shortcut: '⌘K',
              onTap: () => widget.onAction?.call('actions'),
            ),
            const _MainMenuDivider(),
            // Main menu items with submenus
            _MainMenuSubmenuItem(
              label: 'File',
              isHovered: _hoveredSubmenu == 'file',
              onHover: (ctx) => _showSubmenu(ctx, 'file', _fileMenuItems),
              onLeave: () => _tryHideSubmenu('file'),
            ),
            _MainMenuSubmenuItem(
              label: 'Edit',
              isHovered: _hoveredSubmenu == 'edit',
              onHover: (ctx) => _showSubmenu(ctx, 'edit', _editMenuItems),
              onLeave: () => _tryHideSubmenu('edit'),
            ),
            _MainMenuSubmenuItem(
              label: 'View',
              isHovered: _hoveredSubmenu == 'view',
              onHover: (ctx) => _showSubmenu(ctx, 'view', _viewMenuItems),
              onLeave: () => _tryHideSubmenu('view'),
            ),
            _MainMenuSubmenuItem(
              label: 'Object',
              isHovered: _hoveredSubmenu == 'object',
              onHover: (ctx) => _showSubmenu(ctx, 'object', _objectMenuItems),
              onLeave: () => _tryHideSubmenu('object'),
            ),
            _MainMenuSubmenuItem(
              label: 'Text',
              isHovered: _hoveredSubmenu == 'text',
              onHover: (ctx) => _showSubmenu(ctx, 'text', _textMenuItems),
              onLeave: () => _tryHideSubmenu('text'),
            ),
            _MainMenuSubmenuItem(
              label: 'Arrange',
              isHovered: _hoveredSubmenu == 'arrange',
              onHover: (ctx) => _showSubmenu(ctx, 'arrange', _arrangeMenuItems),
              onLeave: () => _tryHideSubmenu('arrange'),
            ),
            _MainMenuSubmenuItem(
              label: 'Vector',
              isHovered: _hoveredSubmenu == 'vector',
              onHover: (ctx) => _showSubmenu(ctx, 'vector', _vectorMenuItems),
              onLeave: () => _tryHideSubmenu('vector'),
            ),
            const _MainMenuDivider(),
            _MainMenuSubmenuItem(
              label: 'Plugins',
              isHovered: _hoveredSubmenu == 'plugins',
              onHover: (ctx) => _showSubmenu(ctx, 'plugins', _pluginsMenuItems),
              onLeave: () => _tryHideSubmenu('plugins'),
            ),
            _MainMenuSubmenuItem(
              label: 'Widgets',
              isHovered: _hoveredSubmenu == 'widgets',
              onHover: (ctx) => _showSubmenu(ctx, 'widgets', _widgetsMenuItems),
              onLeave: () => _tryHideSubmenu('widgets'),
            ),
            _MainMenuSubmenuItem(
              label: 'Preferences',
              isHovered: _hoveredSubmenu == 'preferences',
              onHover: (ctx) => _showSubmenu(ctx, 'preferences', _preferencesMenuItems),
              onLeave: () => _tryHideSubmenu('preferences'),
            ),
            _MainMenuActionItem(
              label: 'Libraries',
              onTap: () => widget.onAction?.call('libraries'),
            ),
            const _MainMenuDivider(),
            _MainMenuActionItem(
              label: 'Open in desktop app',
              onTap: () => widget.onAction?.call('open_desktop'),
            ),
            _MainMenuSubmenuItem(
              label: 'Help and account',
              isHovered: _hoveredSubmenu == 'help',
              onHover: (ctx) => _showSubmenu(ctx, 'help', _helpMenuItems),
              onLeave: () => _tryHideSubmenu('help'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Menu item definitions
  static const _fileMenuItems = [
    _MainMenuItem('New design file', shortcut: '⌘N'),
    _MainMenuItem('New FigJam file'),
    _MainMenuItem.divider(),
    _MainMenuItem('Place image...', shortcut: '⇧⌘K'),
    _MainMenuItem.divider(),
    _MainMenuItem('Save local copy...', shortcut: '⌘S'),
    _MainMenuItem('Save to version history...', shortcut: '⌥⌘S'),
    _MainMenuItem('Export...', shortcut: '⇧⌘E'),
  ];

  static const _editMenuItems = [
    _MainMenuItem('Undo', shortcut: '⌘Z'),
    _MainMenuItem('Redo', shortcut: '⇧⌘Z'),
    _MainMenuItem.divider(),
    _MainMenuItem('Copy', shortcut: '⌘C'),
    _MainMenuItem('Cut', shortcut: '⌘X'),
    _MainMenuItem('Paste', shortcut: '⌘V'),
    _MainMenuItem('Paste over selection', shortcut: '⇧⌘V'),
    _MainMenuItem('Duplicate', shortcut: '⌘D'),
    _MainMenuItem('Delete', shortcut: '⌫'),
    _MainMenuItem.divider(),
    _MainMenuItem('Select all', shortcut: '⌘A'),
    _MainMenuItem('Select inverse', shortcut: '⇧⌘A'),
    _MainMenuItem('Select none', shortcut: '⎋'),
  ];

  static const _viewMenuItems = [
    _MainMenuItem('Pixel grid', shortcut: '⌘\''),
    _MainMenuItem('Layout grids', shortcut: '⌃G'),
    _MainMenuItem('Rulers', shortcut: '⇧R'),
    _MainMenuItem.divider(),
    _MainMenuItem('Zoom in', shortcut: '⌘+'),
    _MainMenuItem('Zoom out', shortcut: '⌘-'),
    _MainMenuItem('Zoom to 100%', shortcut: '⌘0'),
    _MainMenuItem('Zoom to fit', shortcut: '⇧1'),
    _MainMenuItem('Zoom to selection', shortcut: '⇧2'),
    _MainMenuItem.divider(),
    _MainMenuItem('Panels'),
    _MainMenuItem('Outlines', shortcut: '⌘Y'),
  ];

  static const _objectMenuItems = [
    _MainMenuItem('Group selection', shortcut: '⌘G'),
    _MainMenuItem('Ungroup selection', shortcut: '⇧⌘G'),
    _MainMenuItem('Frame selection', shortcut: '⌥⌘G'),
    _MainMenuItem.divider(),
    _MainMenuItem('Add auto layout', shortcut: '⇧A'),
    _MainMenuItem('Remove auto layout'),
    _MainMenuItem.divider(),
    _MainMenuItem('Create component', shortcut: '⌥⌘K'),
    _MainMenuItem('Create multiple components', shortcut: '⌥⌘B'),
    _MainMenuItem.divider(),
    _MainMenuItem('Lock/Unlock', shortcut: '⌘⇧L'),
    _MainMenuItem('Hide/Show', shortcut: '⌘⇧H'),
  ];

  static const _textMenuItems = [
    _MainMenuItem('Bold', shortcut: '⌘B'),
    _MainMenuItem('Italic', shortcut: '⌘I'),
    _MainMenuItem('Underline', shortcut: '⌘U'),
    _MainMenuItem('Strikethrough', shortcut: '⇧⌘X'),
    _MainMenuItem.divider(),
    _MainMenuItem('Align left', shortcut: '⌥⌘L'),
    _MainMenuItem('Align center', shortcut: '⌥⌘T'),
    _MainMenuItem('Align right', shortcut: '⌥⌘R'),
    _MainMenuItem('Justify', shortcut: '⌥⌘J'),
    _MainMenuItem.divider(),
    _MainMenuItem('UPPERCASE'),
    _MainMenuItem('lowercase'),
    _MainMenuItem('Title Case'),
  ];

  static const _arrangeMenuItems = [
    _MainMenuItem('Bring to front', shortcut: '⌘]'),
    _MainMenuItem('Bring forward', shortcut: '⌘⌥]'),
    _MainMenuItem('Send backward', shortcut: '⌘⌥['),
    _MainMenuItem('Send to back', shortcut: '⌘['),
    _MainMenuItem.divider(),
    _MainMenuItem('Align left', shortcut: '⌥A'),
    _MainMenuItem('Align horizontal centers', shortcut: '⌥H'),
    _MainMenuItem('Align right', shortcut: '⌥D'),
    _MainMenuItem('Align top', shortcut: '⌥W'),
    _MainMenuItem('Align vertical centers', shortcut: '⌥V'),
    _MainMenuItem('Align bottom', shortcut: '⌥S'),
    _MainMenuItem.divider(),
    _MainMenuItem('Distribute horizontal spacing'),
    _MainMenuItem('Distribute vertical spacing'),
  ];

  static const _vectorMenuItems = [
    _MainMenuItem('Flatten', shortcut: '⌘E'),
    _MainMenuItem('Outline stroke', shortcut: '⌘⇧O'),
    _MainMenuItem.divider(),
    _MainMenuItem('Union selection'),
    _MainMenuItem('Subtract selection'),
    _MainMenuItem('Intersect selection'),
    _MainMenuItem('Exclude selection'),
  ];

  static const _pluginsMenuItems = [
    _MainMenuItem('Manage plugins...'),
    _MainMenuItem.divider(),
    _MainMenuItem('Run last plugin', shortcut: '⌥⌘P'),
    _MainMenuItem('Browse plugins in Community'),
  ];

  static const _widgetsMenuItems = [
    _MainMenuItem('Manage widgets...'),
    _MainMenuItem.divider(),
    _MainMenuItem('Browse widgets in Community'),
  ];

  static const _preferencesMenuItems = [
    _MainMenuItem('Snap to geometry'),
    _MainMenuItem('Snap to objects'),
    _MainMenuItem('Snap to pixel grid'),
    _MainMenuItem.divider(),
    _MainMenuItem('Highlight layers on hover'),
    _MainMenuItem('Rename duplicated layers'),
    _MainMenuItem('Show dimensions on objects'),
    _MainMenuItem.divider(),
    _MainMenuItem('Keyboard shortcuts...'),
    _MainMenuItem('Account settings...'),
  ];

  static const _helpMenuItems = [
    _MainMenuItem('Help page'),
    _MainMenuItem('Keyboard shortcuts'),
    _MainMenuItem('Release notes'),
    _MainMenuItem('Legal summary'),
    _MainMenuItem.divider(),
    _MainMenuItem('Video tutorials'),
    _MainMenuItem('Community forum'),
    _MainMenuItem.divider(),
    _MainMenuItem('Support...'),
  ];
}

/// Main menu item data
class _MainMenuItem {
  final String label;
  final String? shortcut;
  final bool isDivider;

  const _MainMenuItem(this.label, {this.shortcut}) : isDivider = false;
  const _MainMenuItem.divider() : label = '', shortcut = null, isDivider = true;
}

/// Primary button (Back to files)
class _MainMenuButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _MainMenuButton({
    required this.label,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  State<_MainMenuButton> createState() => _MainMenuButtonState();
}

class _MainMenuButtonState extends State<_MainMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_isHovered ? const Color(0xFF0A7AE6) : const Color(0xFF0D99FF))
                : (_isHovered ? const Color(0xFF404040) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Action item with optional icon and shortcut
class _MainMenuActionItem extends StatefulWidget {
  final IconData? icon;
  final String label;
  final String? shortcut;
  final VoidCallback? onTap;

  const _MainMenuActionItem({
    this.icon,
    required this.label,
    this.shortcut,
    this.onTap,
  });

  @override
  State<_MainMenuActionItem> createState() => _MainMenuActionItemState();
}

class _MainMenuActionItemState extends State<_MainMenuActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _isHovered ? const Color(0xFF0D99FF) : Colors.transparent,
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              if (widget.shortcut != null)
                Text(
                  widget.shortcut!,
                  style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Submenu item with arrow
class _MainMenuSubmenuItem extends StatefulWidget {
  final String label;
  final bool isHovered;
  final void Function(BuildContext) onHover;
  final VoidCallback onLeave;

  const _MainMenuSubmenuItem({
    required this.label,
    required this.isHovered,
    required this.onHover,
    required this.onLeave,
  });

  @override
  State<_MainMenuSubmenuItem> createState() => _MainMenuSubmenuItemState();
}

class _MainMenuSubmenuItemState extends State<_MainMenuSubmenuItem> {
  bool _isLocalHovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isHovered || _isLocalHovered;

    return GestureDetector(
      onTap: () {
        // Support tap to open submenu (for touch and testing)
        setState(() => _isLocalHovered = true);
        widget.onHover(context);
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isLocalHovered = true);
          widget.onHover(context);
        },
        onExit: (_) {
          setState(() => _isLocalHovered = false);
          // Call onLeave immediately - the parent handles the delay
          widget.onLeave();
        },
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: showHighlight ? const Color(0xFF0D99FF) : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF8C8C8C)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu divider
class _MainMenuDivider extends StatelessWidget {
  const _MainMenuDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: const Color(0xFF4A4A4A),
    );
  }
}

/// Submenu dropdown
class _MainMenuSubmenu extends StatelessWidget {
  final List<_MainMenuItem> items;
  final VoidCallback onDismiss;
  final void Function(String)? onAction;

  const _MainMenuSubmenu({
    required this.items,
    required this.onDismiss,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
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
            children: items.map((item) {
              if (item.isDivider) {
                return const _MainMenuDivider();
              }
              return _SubmenuActionItem(
                label: item.label,
                shortcut: item.shortcut,
                onTap: () {
                  onAction?.call(item.label);
                  onDismiss();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Submenu action item
class _SubmenuActionItem extends StatefulWidget {
  final String label;
  final String? shortcut;
  final VoidCallback? onTap;

  const _SubmenuActionItem({
    required this.label,
    this.shortcut,
    this.onTap,
  });

  @override
  State<_SubmenuActionItem> createState() => _SubmenuActionItemState();
}

class _SubmenuActionItemState extends State<_SubmenuActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _isHovered ? const Color(0xFF0D99FF) : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              if (widget.shortcut != null)
                Text(
                  widget.shortcut!,
                  style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ VIEW OVERLAY PAINTERS ============

/// Paints a pixel grid overlay
class _PixelGridPainter extends CustomPainter {
  final double scale;
  final Matrix4 transform;

  _PixelGridPainter({required this.scale, required this.transform});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 1 / scale;

    final translation = transform.getTranslation();
    final gridSize = 1.0 * scale; // 1px grid

    // Calculate grid offset based on transform
    final offsetX = translation.x % gridSize;
    final offsetY = translation.y % gridSize;

    // Draw vertical lines
    for (double x = offsetX; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = offsetY; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) =>
      scale != oldDelegate.scale || transform != oldDelegate.transform;
}

/// Paints rulers overlay
class _RulersPainter extends CustomPainter {
  final double scale;
  final Matrix4 transform;
  final double leftPanelWidth;

  _RulersPainter({
    required this.scale,
    required this.transform,
    required this.leftPanelWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rulerSize = 20.0;
    final bgPaint = Paint()..color = const Color(0xFF2C2C2C);
    final linePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 1;
    final textStyle = const TextStyle(
      color: Color(0xFF999999),
      fontSize: 9,
    );

    final translation = transform.getTranslation();

    // Draw horizontal ruler background
    canvas.drawRect(
      Rect.fromLTWH(leftPanelWidth, 0, size.width - leftPanelWidth, rulerSize),
      bgPaint,
    );

    // Draw vertical ruler background
    canvas.drawRect(
      Rect.fromLTWH(leftPanelWidth, rulerSize, rulerSize, size.height - rulerSize),
      bgPaint,
    );

    // Calculate tick spacing based on scale
    double tickSpacing = 100.0;
    if (scale > 2) tickSpacing = 50;
    if (scale > 4) tickSpacing = 25;
    if (scale > 8) tickSpacing = 10;
    if (scale < 0.5) tickSpacing = 200;
    if (scale < 0.25) tickSpacing = 500;

    final scaledTick = tickSpacing * scale;

    // Draw horizontal ticks
    final startX = ((leftPanelWidth - translation.x) / scale / tickSpacing).floor() * tickSpacing;
    for (double x = startX; x < (size.width - translation.x) / scale; x += tickSpacing) {
      final screenX = x * scale + translation.x;
      if (screenX >= leftPanelWidth && screenX < size.width) {
        canvas.drawLine(
          Offset(screenX, rulerSize - 6),
          Offset(screenX, rulerSize),
          linePaint,
        );

        final textPainter = TextPainter(
          text: TextSpan(text: x.toInt().toString(), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(screenX + 2, 4));
      }
    }

    // Draw vertical ticks
    final startY = ((rulerSize - translation.y) / scale / tickSpacing).floor() * tickSpacing;
    for (double y = startY; y < (size.height - translation.y) / scale; y += tickSpacing) {
      final screenY = y * scale + translation.y;
      if (screenY >= rulerSize && screenY < size.height) {
        canvas.drawLine(
          Offset(leftPanelWidth + rulerSize - 6, screenY),
          Offset(leftPanelWidth + rulerSize, screenY),
          linePaint,
        );

        canvas.save();
        canvas.translate(leftPanelWidth + 4, screenY + 2);
        canvas.rotate(-1.5708); // -90 degrees
        final textPainter = TextPainter(
          text: TextSpan(text: y.toInt().toString(), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    // Draw corner square
    canvas.drawRect(
      Rect.fromLTWH(leftPanelWidth, 0, rulerSize, rulerSize),
      bgPaint,
    );
  }

  @override
  bool shouldRepaint(_RulersPainter oldDelegate) =>
      scale != oldDelegate.scale ||
      transform != oldDelegate.transform ||
      leftPanelWidth != oldDelegate.leftPanelWidth;
}
