/// Figma canvas view with pan, zoom, and page navigation
///
/// This provides a complete canvas experience for viewing Figma documents.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'node_renderer.dart';

/// Helper class to process Figma message data
class FigmaDocument {
  final Map<String, dynamic> message;
  final Map<String, Map<String, dynamic>> nodeMap;
  final List<Map<String, dynamic>> pages;
  final Map<String, dynamic>? documentNode;

  FigmaDocument._({
    required this.message,
    required this.nodeMap,
    required this.pages,
    this.documentNode,
  });

  /// Create a FigmaDocument from a decoded Figma message
  factory FigmaDocument.fromMessage(Map<String, dynamic> message) {
    final nodeChanges = message['nodeChanges'] as List? ?? [];
    final nodeMap = <String, Map<String, dynamic>>{};
    final pages = <Map<String, dynamic>>[];
    Map<String, dynamic>? documentNode;

    // Build node map by guid
    for (final node in nodeChanges) {
      if (node is Map<String, dynamic>) {
        final guid = node['guid'];
        if (guid != null) {
          nodeMap[guid.toString()] = node;

          // Identify document and canvas nodes
          final type = node['type'];
          if (type == 'DOCUMENT') {
            documentNode = node;
          } else if (type == 'CANVAS') {
            pages.add(node);
          }
        }
      }
    }

    return FigmaDocument._(
      message: message,
      nodeMap: nodeMap,
      pages: pages,
      documentNode: documentNode,
    );
  }

  /// Get the total node count
  int get nodeCount => nodeMap.length;

  /// Get a summary of node types
  Map<String, int> get nodeTypeCounts {
    final counts = <String, int>{};
    for (final node in nodeMap.values) {
      final type = node['type'] as String? ?? 'UNKNOWN';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }
}

/// Main canvas widget for viewing Figma documents
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
    this.backgroundColor = const Color(0xFFF5F5F5),
  });

  @override
  State<FigmaCanvasView> createState() => _FigmaCanvasViewState();
}

class _FigmaCanvasViewState extends State<FigmaCanvasView> {
  late int _currentPageIndex;
  late TransformationController _transformController;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialPageIndex;
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _currentPage {
    if (_currentPageIndex < 0 || _currentPageIndex >= widget.document.pages.length) {
      return null;
    }
    return widget.document.pages[_currentPageIndex];
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
      // Reset view when changing pages
      _transformController.value = Matrix4.identity();
      _scale = 1.0;
    });
  }

  void _zoomIn() {
    final center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    _setScale(_scale * 1.2, center);
  }

  void _zoomOut() {
    final center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    _setScale(_scale / 1.2, center);
  }

  void _resetView() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _scale = 1.0;
    });
  }

  void _fitToScreen() {
    final page = _currentPage;
    if (page == null) return;

    final children = page['children'] as List?;
    if (children == null || children.isEmpty) return;

    // Calculate bounds of all children
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

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
    final padding = 50.0;

    final scaleX = (screenSize.width - padding * 2) / contentWidth;
    final scaleY = (screenSize.height - padding * 2) / contentHeight;
    final newScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.1, 5.0);

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    final offsetX = screenSize.width / 2 - centerX * newScale;
    final offsetY = screenSize.height / 2 - centerY * newScale;

    setState(() {
      _scale = newScale;
      final matrix = Matrix4.identity();
      matrix.setEntry(0, 3, offsetX);
      matrix.setEntry(1, 3, offsetY);
      matrix.setEntry(0, 0, newScale);
      matrix.setEntry(1, 1, newScale);
      _transformController.value = matrix;
    });
  }

  void _setScale(double newScale, Offset focalPoint) {
    newScale = newScale.clamp(0.1, 10.0);

    final oldScale = _scale;
    final matrix = _transformController.value.clone();

    final translation = matrix.getTranslation();
    final focalPointInCanvas =
        (focalPoint - Offset(translation.x, translation.y)) / oldScale;

    final newTranslation =
        focalPoint - focalPointInCanvas * newScale;

    setState(() {
      _scale = newScale;
      final matrix = Matrix4.identity();
      matrix.setEntry(0, 3, newTranslation.dx);
      matrix.setEntry(1, 3, newTranslation.dy);
      matrix.setEntry(0, 0, newScale);
      matrix.setEntry(1, 1, newScale);
      _transformController.value = matrix;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Column(
        children: [
          // Page selector
          if (widget.showPageSelector && widget.document.pages.isNotEmpty)
            _buildPageSelector(),

          // Canvas area
          Expanded(
            child: Stack(
              children: [
                // Main canvas with pan/zoom
                Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      final delta = event.scrollDelta.dy;
                      final factor = delta > 0 ? 0.9 : 1.1;
                      _setScale(_scale * factor, event.localPosition);
                    }
                  },
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.1,
                    maxScale: 10.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    onInteractionUpdate: (details) {
                      setState(() {
                        _scale = _transformController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: _buildCanvasContent(),
                  ),
                ),

                // Zoom controls
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _buildZoomControls(),
                ),

                // Debug info
                if (widget.showDebugInfo)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _buildDebugInfo(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSelector() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.document.pages.length,
        itemBuilder: (context, index) {
          final page = widget.document.pages[index];
          final name = page['name'] as String? ?? 'Page ${index + 1}';
          final isSelected = index == _currentPageIndex;

          return GestureDetector(
            onTap: () => _onPageChanged(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCanvasContent() {
    final page = _currentPage;
    if (page == null) {
      return const Center(
        child: Text('No pages found'),
      );
    }

    return Container(
      // Large canvas to allow scrolling
      width: 10000,
      height: 10000,
      color: Colors.transparent,
      child: FigmaNodeWidget(
        node: page,
        nodeMap: widget.document.nodeMap,
        scale: 1.0,
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomButton(
          icon: Icons.add,
          onPressed: _zoomIn,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1A000000), // black with 0.1 opacity
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            '${(_scale * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        _ZoomButton(
          icon: Icons.remove,
          onPressed: _zoomOut,
        ),
        const SizedBox(height: 8),
        _ZoomButton(
          icon: Icons.fit_screen,
          onPressed: _fitToScreen,
          tooltip: 'Fit to screen',
        ),
        const SizedBox(height: 4),
        _ZoomButton(
          icon: Icons.refresh,
          onPressed: _resetView,
          tooltip: 'Reset view',
        ),
      ],
    );
  }

  Widget _buildDebugInfo() {
    final page = _currentPage;
    final typeCounts = widget.document.nodeTypeCounts;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xB3000000), // black with 0.7 opacity
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nodes: ${widget.document.nodeCount}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'Pages: ${widget.document.pages.length}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'Page: ${page?['name'] ?? 'None'}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'Scale: ${_scale.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(height: 4),
          const Text(
            'Types:',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          ...typeCounts.entries
              .toList()
              .take(10)
              .map((e) => Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  )),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _ZoomButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // black with 0.1 opacity
            blurRadius: 4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }
}

/// Simple canvas widget without page selector (for embedding)
class FigmaSimpleCanvas extends StatelessWidget {
  final Map<String, dynamic> node;
  final Map<String, Map<String, dynamic>> nodeMap;
  final double scale;
  final bool showBounds;

  const FigmaSimpleCanvas({
    super.key,
    required this.node,
    required this.nodeMap,
    this.scale = 1.0,
    this.showBounds = false,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.1,
      maxScale: 10.0,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: FigmaNodeWidget(
        node: node,
        nodeMap: nodeMap,
        scale: scale,
        showBounds: showBounds,
      ),
    );
  }
}
