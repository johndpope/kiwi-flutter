/// Flutter node renderer for Figma nodes
///
/// This module provides widgets to render Figma nodes as Flutter widgets,
/// following the structure of grida-canvas-react-renderer-dom.

import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'rendering/paint_renderer.dart';
import 'rendering/effect_renderer.dart';
import 'rendering/blend_modes.dart';

/// Base class for node properties extracted from Figma node data
class FigmaNodeProperties {
  final String? id;
  final String? name;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final bool visible;
  final List<Map<String, dynamic>> fills;
  final List<Map<String, dynamic>> strokes;
  final double strokeWeight;
  final List<Map<String, dynamic>> effects;
  final Map<String, dynamic>? constraints;
  final List<double>? cornerRadii;
  final double? cornerRadius;
  final Map<String, dynamic> raw;

  FigmaNodeProperties({
    this.id,
    this.name,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
    this.opacity = 1.0,
    this.visible = true,
    this.fills = const [],
    this.strokes = const [],
    this.strokeWeight = 0,
    this.effects = const [],
    this.constraints,
    this.cornerRadii,
    this.cornerRadius,
    required this.raw,
  });

  /// Create properties from a raw Figma node map
  factory FigmaNodeProperties.fromMap(Map<String, dynamic> node) {
    // Extract transform/position
    double x = 0, y = 0, width = 0, height = 0, rotation = 0;

    // Try to get transform from node
    final transform = node['transform'];
    if (transform is Map) {
      x = (transform['m02'] as num?)?.toDouble() ?? 0;
      y = (transform['m12'] as num?)?.toDouble() ?? 0;
    }

    // Try to get size
    final size = node['size'];
    if (size is Map) {
      width = (size['x'] as num?)?.toDouble() ?? 0;
      height = (size['y'] as num?)?.toDouble() ?? 0;
    }

    // Try boundingBox if transform not available
    final bbox = node['boundingBox'];
    if (bbox is Map) {
      x = x == 0 ? ((bbox['x'] as num?)?.toDouble() ?? 0) : x;
      y = y == 0 ? ((bbox['y'] as num?)?.toDouble() ?? 0) : y;
      width = width == 0 ? ((bbox['width'] as num?)?.toDouble() ?? 0) : width;
      height = height == 0 ? ((bbox['height'] as num?)?.toDouble() ?? 0) : height;
    }

    // Extract fills
    List<Map<String, dynamic>> fills = [];
    final fillsData = node['fillPaints'];
    if (fillsData is List) {
      fills = fillsData.cast<Map<String, dynamic>>();
    }

    // Extract strokes
    List<Map<String, dynamic>> strokes = [];
    final strokesData = node['strokePaints'];
    if (strokesData is List) {
      strokes = strokesData.cast<Map<String, dynamic>>();
    }

    // Extract effects
    List<Map<String, dynamic>> effects = [];
    final effectsData = node['effects'];
    if (effectsData is List) {
      effects = effectsData.cast<Map<String, dynamic>>();
    }

    // Extract corner radii
    List<double>? cornerRadii;
    final radii = node['rectangleCornerRadii'];
    if (radii is List) {
      cornerRadii = radii.map((r) => (r as num).toDouble()).toList();
    }

    double? cornerRadius;
    final cr = node['cornerRadius'];
    if (cr is num) {
      cornerRadius = cr.toDouble();
    }

    return FigmaNodeProperties(
      id: node['guid']?.toString(),
      name: node['name'] as String?,
      type: node['type'] as String? ?? 'UNKNOWN',
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: rotation,
      opacity: (node['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: node['visible'] as bool? ?? true,
      fills: fills,
      strokes: strokes,
      strokeWeight: (node['strokeWeight'] as num?)?.toDouble() ?? 0,
      effects: effects,
      constraints: node['constraints'] as Map<String, dynamic>?,
      cornerRadii: cornerRadii,
      cornerRadius: cornerRadius,
      raw: node,
    );
  }

  /// Get the effective corner radius (single value or average of corners)
  double get effectiveCornerRadius {
    if (cornerRadii != null && cornerRadii!.isNotEmpty) {
      return cornerRadii!.first;
    }
    return cornerRadius ?? 0;
  }

  /// Get all corner radii as BorderRadius
  BorderRadius? get borderRadius {
    if (cornerRadii != null && cornerRadii!.length >= 4) {
      return BorderRadius.only(
        topLeft: Radius.circular(cornerRadii![0]),
        topRight: Radius.circular(cornerRadii![1]),
        bottomRight: Radius.circular(cornerRadii![2]),
        bottomLeft: Radius.circular(cornerRadii![3]),
      );
    }
    if (cornerRadius != null && cornerRadius! > 0) {
      return BorderRadius.circular(cornerRadius!);
    }
    return null;
  }
}

/// Convert imageHash bytes to hex string for filename lookup
String imageHashToHex(dynamic imageHash) {
  if (imageHash is List) {
    return imageHash.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
  }
  return '';
}

/// Global debug flag for Figma renderer - set to true to enable verbose logging
bool figmaRendererDebug = false; // Disabled - see docs/TEXT_RENDERING_ISSUE.md

/// Tracks which node types have been logged (to reduce log spam)
Set<String>? _loggedRenderTypes;

/// Main node renderer widget that routes to specific renderers based on node type
class FigmaNodeWidget extends StatelessWidget {
  final Map<String, dynamic> node;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final Map<String, List<int>>? blobMap;
  final String? imagesDirectory;
  final double scale;
  final bool showBounds;
  /// Property overrides from parent INSTANCE's symbolOverrides
  final Map<String, dynamic>? propertyOverrides;
  /// Full override map from parent INSTANCE for nested children lookup
  final Map<String, Map<String, dynamic>>? instanceOverrides;

  const FigmaNodeWidget({
    super.key,
    required this.node,
    this.nodeMap,
    this.blobMap,
    this.imagesDirectory,
    this.scale = 1.0,
    this.showBounds = false,
    this.propertyOverrides,
    this.instanceOverrides,
  });

  @override
  Widget build(BuildContext context) {
    // Look up overrides for this node from instanceOverrides if not directly provided
    Map<String, dynamic>? effectiveOverrides = propertyOverrides;
    if (effectiveOverrides == null && instanceOverrides != null) {
      // First try by _guidKey (nodeMap key)
      final nodeKey = node['_guidKey']?.toString();
      if (nodeKey != null) {
        effectiveOverrides = instanceOverrides![nodeKey];
      }
      // If not found, try by the node's original guid (which matches symbolOverrides guidPath)
      if (effectiveOverrides == null) {
        final nodeGuid = node['guid'];
        if (nodeGuid is Map) {
          final sessionId = nodeGuid['sessionID'] ?? 0;
          final localId = nodeGuid['localID'] ?? 0;
          final guidKey = '$sessionId:$localId';
          effectiveOverrides = instanceOverrides![guidKey];
        }
      }
    }

    // Apply property overrides if present (from parent INSTANCE's symbolOverrides)
    Map<String, dynamic> effectiveNode = node;
    if (effectiveOverrides != null && effectiveOverrides.isNotEmpty) {
      effectiveNode = Map<String, dynamic>.from(node);
      // Merge overrides into the node (deep merge for textData)
      effectiveOverrides.forEach((key, value) {
        if (value != null) {
          if (key == 'textData' && value is Map && effectiveNode['textData'] is Map) {
            // Deep merge textData to preserve existing properties
            final mergedTextData = Map<String, dynamic>.from(effectiveNode['textData'] as Map);
            (value as Map).forEach((k, v) {
              if (v != null) mergedTextData[k] = v;
            });
            effectiveNode['textData'] = mergedTextData;
          } else {
            effectiveNode[key] = value;
          }
        }
      });

      // Debug: Log when text override is applied
      if (figmaRendererDebug && effectiveOverrides.containsKey('textData')) {
        final td = effectiveNode['textData'];
        if (td is Map) {
          print('DEBUG TEXT OVERRIDE APPLIED: "${node['name']}" → characters="${td['characters']}"');
        }
      }
    }

    final props = FigmaNodeProperties.fromMap(effectiveNode);

    if (!props.visible) {
      return const SizedBox.shrink();
    }

    final type = props.type;

    // Debug: Log which nodes are being rendered (only once per type to reduce spam)
    if (figmaRendererDebug) {
      // Use static set to track which types we've already logged
      _loggedRenderTypes ??= <String>{};
      if (!_loggedRenderTypes!.contains(type)) {
        _loggedRenderTypes!.add(type);
        print('DEBUG RENDER: First "$type" node: "${props.name}"');
      }
    }

    Widget child;
    switch (type) {
      case 'FRAME':
      case 'GROUP':
      case 'COMPONENT':
      case 'COMPONENT_SET':
        // Debug: Log structure of key frames (limit to specific names to reduce spam)
        if (figmaRendererDebug &&
            (props.name == '📘 Components Index' ||
             props.name == 'Similar Files' ||
             props.name?.contains('Thumbnail') == true ||
             (props.name == 'Content' && props.width > 2000) ||
             props.name == 'Section' ||
             props.name == 'Cover and Text' ||
             props.name == 'Cover' ||
             props.name == 'Cropping Device' ||
             props.name == 'Device' ||
             props.name == 'Crop Screen')) {
          final ownFills = props.fills;
          final hasOwnImage = ownFills.any((f) => f['type'] == 'IMAGE');
          final isMask = props.raw['mask'] == true || props.raw['isMask'] == true;
          final hasMask = props.raw['hasMask'] == true;
          final maskType = props.raw['maskType'];
          final clipsContent = props.raw['clipsContent'] == true;
          print('DEBUG FRAME: "${props.name}" (${props.type}, ${props.width}x${props.height})${hasOwnImage ? " [IMAGE]" : ""}${isMask ? " [IS_MASK]" : ""}${hasMask ? " [HAS_MASK]" : ""}${clipsContent ? " [CLIPS]" : ""}${maskType != null ? " [maskType=$maskType]" : ""}');
          final children = props.raw['children'] as List? ?? [];
          for (int i = 0; i < children.length && i < 15; i++) {
            final childKey = children[i].toString();
            final childNode = nodeMap?[childKey];
            if (childNode != null) {
              final childName = childNode['name'];
              final childType = childNode['type'];
              final childChildren = (childNode['children'] as List?)?.length ?? 0;
              final fills = childNode['fillPaints'] as List? ?? [];
              final hasImageFill = fills.any((f) => f['type'] == 'IMAGE');
              print('  [$i] "$childName" ($childType, $childChildren ch)${hasImageFill ? " [HAS IMAGE]" : ""}');

              // Also show grandchildren for Section rows
              if (props.name == 'Section' && childType == 'FRAME' && childChildren > 0) {
                final grandKids = childNode['children'] as List? ?? [];
                for (int j = 0; j < grandKids.length && j < 5; j++) {
                  final gkKey = grandKids[j].toString();
                  final gkNode = nodeMap?[gkKey];
                  if (gkNode != null) {
                    final gkName = gkNode['name'];
                    final gkType = gkNode['type'];
                    final gkFills = gkNode['fillPaints'] as List? ?? [];
                    final gkHasImage = gkFills.any((f) => f['type'] == 'IMAGE');
                    print('      [$j] "$gkName" ($gkType)${gkHasImage ? " [HAS IMAGE]" : ""}');
                  }
                }
              }
            }
          }
        }
        child = FigmaFrameWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale, instanceOverrides: instanceOverrides);
        break;
      case 'INSTANCE':
        // INSTANCE nodes reference a COMPONENT via symbolData - resolve it
        child = FigmaInstanceWidget(
          props: props,
          nodeMap: nodeMap,
          blobMap: blobMap,
          imagesDirectory: imagesDirectory,
          scale: scale,
        );
        break;
      case 'SYMBOL':
      case 'SECTION':
        child = FigmaFrameWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale, instanceOverrides: instanceOverrides);
        break;
      case 'RECTANGLE':
      case 'ROUNDED_RECTANGLE':
        // Check if this rectangle has IMAGE fills - if so, use FigmaFrameWidget which handles images
        final hasImageFill = props.fills.any((fill) => fill['type'] == 'IMAGE');
        if (hasImageFill) {
          child = FigmaFrameWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale, instanceOverrides: instanceOverrides);
        } else {
          child = FigmaRectangleWidget(props: props);
        }
        break;
      case 'ELLIPSE':
        child = FigmaEllipseWidget(props: props);
        break;
      case 'TEXT':
        child = FigmaTextWidget(props: props, scale: scale, effectiveNode: effectiveNode);
        break;
      case 'VECTOR':
      case 'LINE':
      case 'STAR':
      case 'POLYGON':
      case 'REGULAR_POLYGON':
      case 'BOOLEAN_OPERATION':
        child = FigmaVectorWidget(props: props);
        break;
      case 'SLICE':
        // SLICE nodes are export areas - render as invisible with debug outline
        child = FigmaSliceWidget(props: props, scale: scale);
        break;
      case 'CANVAS':
        // Canvas is a page - render its children (no instanceOverrides at page level)
        child = FigmaCanvasWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale);
        break;
      case 'DOCUMENT':
        // Document is the root - skip rendering
        child = const SizedBox.shrink();
        break;

      // FigJam node types - render as basic shapes with content
      case 'STICKY':
        child = FigmaStickyWidget(props: props, scale: scale);
        break;
      case 'SHAPE_WITH_TEXT':
        child = FigmaShapeWithTextWidget(props: props, nodeMap: nodeMap, scale: scale);
        break;
      case 'CONNECTOR':
        child = FigmaConnectorWidget(props: props, nodeMap: nodeMap, scale: scale);
        break;
      case 'STAMP':
      case 'HIGHLIGHT':
      case 'WASHI_TAPE':
        // FigJam decorative elements - render as vectors or placeholders
        child = FigmaVectorWidget(props: props);
        break;

      // Advanced node types - render as frames or placeholders
      case 'TABLE':
        child = FigmaTableWidget(props: props, nodeMap: nodeMap, scale: scale);
        break;
      case 'TABLE_CELL':
        child = FigmaFrameWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale, instanceOverrides: instanceOverrides);
        break;
      case 'SECTION_OVERLAY':
      case 'SLIDE':
      case 'SLIDE_ROW':
        // Presentation elements - treat as frames
        child = FigmaFrameWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale, instanceOverrides: instanceOverrides);
        break;

      // Media and embedded content
      case 'MEDIA':
      case 'LOTTIE':
      case 'EMBED':
      case 'LINK_UNFURL':
        child = FigmaMediaWidget(props: props, scale: scale);
        break;

      // Special types
      case 'CODE_BLOCK':
        child = FigmaCodeBlockWidget(props: props, scale: scale);
        break;
      case 'WIDGET':
        // Interactive widget - render as frame
        child = FigmaFrameWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale, instanceOverrides: instanceOverrides);
        break;
      case 'VARIABLE':
        // Variable definition - typically invisible
        child = const SizedBox.shrink();
        break;
      case 'AI_FILE':
      case 'DIAGRAMMING_ELEMENT':
      case 'DIAGRAMMING_CONNECTION':
        // Newer node types - render as frames or vectors
        child = FigmaFrameWidget(props: props, nodeMap: nodeMap, blobMap: blobMap, imagesDirectory: imagesDirectory, scale: scale, instanceOverrides: instanceOverrides);
        break;

      default:
        // Fallback for unknown types - log what we're missing
        if (figmaRendererDebug) {
          print('DEBUG UNKNOWN TYPE: ${props.type} "${props.name}"');
        }
        child = FigmaPlaceholderWidget(props: props);
    }

    // Wrap with transform if needed
    if (props.rotation != 0) {
      child = Transform.rotate(
        angle: props.rotation * 3.14159265359 / 180,
        child: child,
      );
    }

    // Apply opacity
    if (props.opacity < 1.0) {
      child = Opacity(opacity: props.opacity, child: child);
    }

    // Debug bounds
    if (showBounds) {
      child = Stack(
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x80FF0000), width: 1), // red with 0.5 opacity
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Wrap with debug overlay for inspection
    return DebugNodeWrapper(
      node: node,
      scale: scale,
      child: child,
    );
  }
}

/// Frame/Group/Component renderer
class FigmaFrameWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final Map<String, List<int>>? blobMap;
  final String? imagesDirectory;
  final double scale;
  final Map<String, Map<String, dynamic>>? instanceOverrides;

  const FigmaFrameWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.blobMap,
    this.imagesDirectory,
    this.scale = 1.0,
    this.instanceOverrides,
  });

  @override
  Widget build(BuildContext context) {
    // Check for IMAGE fills first
    Widget? imageWidget;

    // Also check raw node for other fill fields
    final rawFills = props.raw['fills'];

    // Debug disabled - focusing on IMAGE fills only

    // Try multiple fill field names Figma might use
    final allFills = <Map<String, dynamic>>[
      ...props.fills, // fillPaints
      if (rawFills is List) ...rawFills.whereType<Map<String, dynamic>>(),
    ];

    // Check imagePaints specifically (Figma often separates image paints)
    final imagePaints = props.raw['imagePaints'];
    if (imagePaints is List) {
      for (final paint in imagePaints) {
        if (paint is Map<String, dynamic>) {
          allFills.add(paint);
        }
      }
    }

    // Check backgroundPaints
    final backgroundPaints = props.raw['backgroundPaints'];
    if (backgroundPaints is List) {
      for (final paint in backgroundPaints) {
        if (paint is Map<String, dynamic>) {
          allFills.add(paint);
        }
      }
    }

    // Debug: Log all fill types being processed
    if (figmaRendererDebug && allFills.isNotEmpty) {
      final fillTypes = allFills.map((f) => f['type']).toSet().toList();
      if (fillTypes.any((t) => t == 'IMAGE')) {
        print('DEBUG FILLS: "${props.name}" has ${allFills.length} fills: $fillTypes');
      }
    }

    for (final fill in allFills) {
      if (fill['visible'] == false) continue;
      final fillType = fill['type'];

      if (fillType == 'IMAGE') {
        // Debug logging (controlled by flag)
        if (figmaRendererDebug) {
          print('DEBUG IMAGE: "${props.name}" FILL_KEYS=${fill.keys.toList()}');
        }

        // Extract image reference - Figma stores it in fill['image']['hash']
        dynamic imageRef = fill['image'] ??
                           fill['imageHash'] ??
                           fill['imageRef'] ??
                           fill['hash'];

        if (imageRef != null && imagesDirectory != null) {
          String hexHash = '';

          if (imageRef is Map) {
            // Image is stored as {hash: [...bytes...], name: "..."}
            final bytes = imageRef['hash'] ?? imageRef['bytes'];
            if (bytes is List) {
              hexHash = imageHashToHex(bytes);
            }
          } else if (imageRef is List) {
            hexHash = imageHashToHex(imageRef);
          } else if (imageRef is String) {
            hexHash = imageRef;
          }

          if (hexHash.isNotEmpty) {
            final imagePath = '$imagesDirectory/$hexHash';
            final file = File(imagePath);
            if (file.existsSync()) {
              if (figmaRendererDebug) {
                print('DEBUG IMAGE: Loading ${props.width}x${props.height} from $hexHash');
              }
              imageWidget = Image.file(
                file,
                width: props.width * scale,
                height: props.height * scale,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  if (figmaRendererDebug) {
                    print('DEBUG IMAGE ERROR: $error');
                  }
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  );
                },
              );
              break;
            } else if (figmaRendererDebug) {
              print('DEBUG IMAGE: File not found: $imagePath');
            }
          }
        }
      }
    }

    // Get background from fills (non-image fills)
    final decoration = _buildDecoration();

    // Build children
    final children = _buildChildren();

    final clipsContent = props.raw['clipsContent'] == true;

    Widget content = Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: decoration,
      clipBehavior: clipsContent ? Clip.hardEdge : Clip.none,
      child: children.isEmpty
          ? null
          : Stack(
              clipBehavior: clipsContent ? Clip.hardEdge : Clip.none,
              children: children,
            ),
    );

    // Always clip frames to prevent content overflow (Figma behavior)
    // This ensures children don't render outside frame bounds
    if (children.isNotEmpty) {
      content = ClipRRect(
        borderRadius: props.borderRadius ?? BorderRadius.zero,
        child: content,
      );
    }

    // If we have an image, stack it behind the content
    if (imageWidget != null) {
      content = Stack(
        children: [
          ClipRRect(
            borderRadius: props.borderRadius ?? BorderRadius.zero,
            child: imageWidget,
          ),
          content,
        ],
      );
    }

    // Apply blur effects
    if (props.effects.isNotEmpty) {
      // Apply background blur if present
      final bgBlurRadius = EffectRenderer.getBackgroundBlurRadius(props.effects);
      if (bgBlurRadius != null && bgBlurRadius > 0) {
        content = BackgroundBlurWidget(
          blurRadius: bgBlurRadius * scale,
          borderRadius: props.borderRadius,
          child: content,
        );
      }

      // Apply layer blur if present
      final layerBlurRadius = EffectRenderer.getBlurRadius(props.effects);
      if (layerBlurRadius != null && layerBlurRadius > 0 && bgBlurRadius == null) {
        content = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: layerBlurRadius * scale,
            sigmaY: layerBlurRadius * scale,
          ),
          child: content,
        );
      }

      // Apply inner shadows if present
      if (EffectRenderer.hasInnerShadow(props.effects)) {
        content = EffectRenderer.applyEffects(
          content,
          props.effects,
          size: Size(props.width * scale, props.height * scale),
          borderRadius: props.borderRadius,
        );
      }
    }

    // Apply blend mode if not normal
    final blendMode = getBlendModeFromData(props.raw);
    if (blendMode != BlendMode.srcOver) {
      // Note: Full blend mode support would require saveLayer
      // For now, we just track it for future enhancement
    }

    // Wrap large frames in RepaintBoundary for better pan/zoom performance
    if (props.width > 200 && props.height > 200) {
      return RepaintBoundary(child: content);
    }

    return content;
  }

  BoxDecoration _buildDecoration() {
    Color? backgroundColor;
    Gradient? gradient;
    final size = Size(props.width * scale, props.height * scale);

    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final fillType = fill['type']?.toString();
      if (fillType == 'SOLID') {
        final color = fill['color'];
        final opacity = (fill['opacity'] as num?)?.toDouble() ?? 1.0;
        if (color is Map) {
          backgroundColor = PaintRenderer.buildColor(
            color.cast<String, dynamic>(),
            opacity,
          );
        }
      } else if (fillType?.startsWith('GRADIENT_') == true) {
        // Use new PaintRenderer for all gradient types
        gradient = PaintRenderer.buildGradient(fill, size);
      }
    }

    // Build border from strokes
    Border? border;
    if (props.strokes.isNotEmpty && props.strokeWeight > 0) {
      final stroke = props.strokes.first;
      if (stroke['visible'] != false) {
        final color = stroke['color'];
        final opacity = (stroke['opacity'] as num?)?.toDouble() ?? 1.0;
        if (color is Map) {
          final strokeColor = PaintRenderer.buildColor(
            color.cast<String, dynamic>(),
            opacity,
          );
          if (strokeColor != null) {
            border = Border.all(
              color: strokeColor,
              width: props.strokeWeight * scale,
            );
          }
        }
      }
    }

    // Build shadows from effects using EffectRenderer
    final shadows = EffectRenderer.buildBoxShadows(props.effects);
    // Scale shadow values
    final scaledShadows = shadows.map((shadow) => BoxShadow(
      color: shadow.color,
      offset: shadow.offset * scale,
      blurRadius: shadow.blurRadius * scale,
      spreadRadius: shadow.spreadRadius * scale,
    )).toList();

    return BoxDecoration(
      color: gradient == null ? backgroundColor : null,
      gradient: gradient,
      border: border,
      borderRadius: props.borderRadius,
      boxShadow: scaledShadows.isEmpty ? null : scaledShadows,
    );
  }

  List<Widget> _buildChildren() {
    if (nodeMap == null) return [];

    final childrenKeys = props.raw['children'] as List?;
    if (childrenKeys == null) return [];

    final children = <Widget>[];
    // In Figma, the first child in the array is visually on TOP
    // In Flutter Stack, the last child added is on TOP
    // So we REVERSE the order to match Figma's z-order
    final reversedKeys = childrenKeys.reversed.toList();
    for (final childKey in reversedKeys) {
      // childKey is now a String key like "0:123"
      final childNode = nodeMap![childKey.toString()];
      if (childNode != null) {
        final childProps = FigmaNodeProperties.fromMap(childNode);
        // Only render visible children
        if (!childProps.visible) continue;

        children.add(
          Positioned(
            left: childProps.x * scale,
            top: childProps.y * scale,
            child: FigmaNodeWidget(
              node: childNode,
              nodeMap: nodeMap,
              blobMap: blobMap,
              imagesDirectory: imagesDirectory,
              scale: scale,
              instanceOverrides: instanceOverrides,
            ),
          ),
        );
      }
    }
    return children;
  }

  /// Build children for auto-layout frames with calculated positions
  List<Widget> _buildAutoLayoutPositionedChildren(List childrenKeys, dynamic layoutMode) {
    final isVertical = layoutMode == 'VERTICAL' || layoutMode == 1;
    final itemSpacing = ((props.raw['itemSpacing'] as num?)?.toDouble() ?? 0) * scale;
    final paddingLeft = ((props.raw['stackPaddingLeft'] as num?)?.toDouble() ?? 0) * scale;
    final paddingTop = ((props.raw['stackPaddingTop'] as num?)?.toDouble() ?? 0) * scale;

    final children = <Widget>[];
    double currentOffset = isVertical ? paddingTop : paddingLeft;

    // Auto-layout uses natural order (first = top/left)
    for (final childKey in childrenKeys) {
      final childNode = nodeMap![childKey.toString()];
      if (childNode != null) {
        final childProps = FigmaNodeProperties.fromMap(childNode);
        if (!childProps.visible) continue;

        final left = isVertical ? paddingLeft : currentOffset;
        final top = isVertical ? currentOffset : paddingTop;

        children.add(
          Positioned(
            left: left,
            top: top,
            child: FigmaNodeWidget(
              node: childNode,
              nodeMap: nodeMap,
              blobMap: blobMap,
              imagesDirectory: imagesDirectory,
              scale: scale,
              instanceOverrides: instanceOverrides,
            ),
          ),
        );

        // Advance position for next child
        if (isVertical) {
          currentOffset += childProps.height * scale + itemSpacing;
        } else {
          currentOffset += childProps.width * scale + itemSpacing;
        }
      }
    }
    return children;
  }

  /// Build children for auto-layout (flexbox) frames
  Widget _buildAutoLayoutChildren() {
    if (nodeMap == null) return const SizedBox.shrink();

    final childrenKeys = props.raw['children'] as List?;
    if (childrenKeys == null || childrenKeys.isEmpty) return const SizedBox.shrink();

    final layoutMode = props.raw['stackMode'] ?? props.raw['layoutMode'];
    final isVertical = layoutMode == 'VERTICAL' || layoutMode == 1;
    final itemSpacing = ((props.raw['itemSpacing'] as num?)?.toDouble() ?? 0) * scale;

    // Get alignment
    final primaryAlign = props.raw['stackPrimaryAlignItems'] ?? props.raw['primaryAxisAlignItems'];
    final counterAlign = props.raw['stackCounterAlignItems'] ?? props.raw['counterAxisAlignItems'];

    MainAxisAlignment mainAxis = MainAxisAlignment.start;
    if (primaryAlign == 'CENTER' || primaryAlign == 1) {
      mainAxis = MainAxisAlignment.center;
    } else if (primaryAlign == 'MAX' || primaryAlign == 2) {
      mainAxis = MainAxisAlignment.end;
    } else if (primaryAlign == 'SPACE_BETWEEN' || primaryAlign == 3) {
      mainAxis = MainAxisAlignment.spaceBetween;
    }

    CrossAxisAlignment crossAxis = CrossAxisAlignment.start;
    if (counterAlign == 'CENTER' || counterAlign == 1) {
      crossAxis = CrossAxisAlignment.center;
    } else if (counterAlign == 'MAX' || counterAlign == 2) {
      crossAxis = CrossAxisAlignment.end;
    }

    // Get padding
    final paddingLeft = ((props.raw['stackPaddingLeft'] as num?)?.toDouble() ?? 0) * scale;
    final paddingRight = ((props.raw['stackPaddingRight'] as num?)?.toDouble() ?? 0) * scale;
    final paddingTop = ((props.raw['stackPaddingTop'] as num?)?.toDouble() ?? 0) * scale;
    final paddingBottom = ((props.raw['stackPaddingBottom'] as num?)?.toDouble() ?? 0) * scale;

    // Build child widgets (NOT reversed for auto-layout - natural order)
    final childWidgets = <Widget>[];
    for (int i = 0; i < childrenKeys.length; i++) {
      final childKey = childrenKeys[i].toString();
      final childNode = nodeMap![childKey];
      if (childNode != null) {
        final childProps = FigmaNodeProperties.fromMap(childNode);
        if (!childProps.visible) continue;

        if (childWidgets.isNotEmpty && itemSpacing > 0) {
          childWidgets.add(SizedBox(
            width: isVertical ? 0 : itemSpacing,
            height: isVertical ? itemSpacing : 0,
          ));
        }

        childWidgets.add(
          FigmaNodeWidget(
            node: childNode,
            nodeMap: nodeMap,
            blobMap: blobMap,
            imagesDirectory: imagesDirectory,
            scale: scale,
            instanceOverrides: instanceOverrides,
          ),
        );
      }
    }

    Widget layout;
    if (isVertical) {
      layout = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: mainAxis,
        crossAxisAlignment: crossAxis,
        children: childWidgets,
      );
    } else {
      layout = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: mainAxis,
        crossAxisAlignment: crossAxis,
        children: childWidgets,
      );
    }

    if (paddingLeft > 0 || paddingRight > 0 || paddingTop > 0 || paddingBottom > 0) {
      layout = Padding(
        padding: EdgeInsets.only(
          left: paddingLeft,
          right: paddingRight,
          top: paddingTop,
          bottom: paddingBottom,
        ),
        child: layout,
      );
    }

    // Clip overflow - auto-layout content can exceed bounds
    return ClipRect(child: layout);
  }

  /// Check if this frame uses auto-layout
  bool get _isAutoLayout {
    final layoutMode = props.raw['stackMode'] ?? props.raw['layoutMode'];
    return layoutMode != null && layoutMode != 'NONE' && layoutMode != 0;
  }
}

/// Instance renderer - resolves component reference via symbolData
class FigmaInstanceWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final Map<String, List<int>>? blobMap;
  final String? imagesDirectory;
  final double scale;

  const FigmaInstanceWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.blobMap,
    this.imagesDirectory,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Try to resolve the source component via symbolData
    Map<String, dynamic>? sourceComponent;

    final symbolData = props.raw['symbolData'];
    List<dynamic>? symbolOverrides;
    if (symbolData is Map && nodeMap != null) {
      final symbolId = symbolData['symbolID'];
      final rawOverrides = symbolData['symbolOverrides'];
      symbolOverrides = rawOverrides is List ? rawOverrides : null;
      if (symbolId is Map) {
        // Convert GUID to key format: "sessionID:localID"
        final sessionId = symbolId['sessionID'] ?? 0;
        final localId = symbolId['localID'] ?? 0;
        final symbolKey = '$sessionId:$localId';
        sourceComponent = nodeMap![symbolKey];

        if (figmaRendererDebug && sourceComponent != null) {
          final srcName = sourceComponent['name'];
          final srcType = sourceComponent['type'];
          final srcChildren = sourceComponent['children'] as List? ?? [];
          print('DEBUG INSTANCE: "${props.name}" → resolved "$srcName" ($srcType, ${srcChildren.length} children)');
          // Log ALL instances with symbolOverrides to understand the format
          if (symbolOverrides != null && symbolOverrides.isNotEmpty) {
            print('  symbolOverrides: ${symbolOverrides.length} items');
            for (int i = 0; i < symbolOverrides.length && i < 2; i++) {
              final override = symbolOverrides[i];
              if (override is Map) {
                print('  override[$i] keys: ${override.keys.toList()}');
                // Show guidPath if present (identifies which node to override)
                if (override.containsKey('guidPath')) {
                  final guidPath = override['guidPath'];
                  print('    guidPath: $guidPath');
                }
                // Show fillPaints if present (IMAGE overrides)
                if (override.containsKey('fillPaints')) {
                  final fills = override['fillPaints'] as List?;
                  if (fills != null && fills.isNotEmpty) {
                    final fillTypes = fills.map((f) => f['type']).toList();
                    print('    fillPaints: $fillTypes');
                    for (final f in fills) {
                      if (f['type'] == 'IMAGE' && f['image'] != null) {
                        final hash = f['image']['hash'];
                        if (hash is List) {
                          print('    IMAGE: ${imageHashToHex(hash)}');
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // Build decoration from instance's own fills/strokes
    final decoration = _buildDecoration();

    // Get children - either from instance's own children or from source component
    List<String> childrenKeys = [];

    // First check instance's own children
    final instanceChildren = props.raw['children'] as List?;
    if (instanceChildren != null && instanceChildren.isNotEmpty) {
      childrenKeys = instanceChildren.map((e) => e.toString()).toList();
    }
    // If no children, use source component's children
    else if (sourceComponent != null) {
      final srcChildren = sourceComponent['children'] as List?;
      if (srcChildren != null) {
        childrenKeys = srcChildren.map((e) => e.toString()).toList();
      }
    }

    // Build override map from symbolOverrides
    // Each override has a guidPath that identifies which nested node to override
    // IMPORTANT: guidPath uses the ORIGINAL component's guids, not the nodeMap guids
    // So we need to build a mapping from original guids to nodeMap keys

    // First, try to find the component property definitions (for componentPropAssignments)
    final componentPropDefs = <String, String>{}; // defID key -> target property type
    final componentPropValues = <String, dynamic>{}; // defID key -> value

    final overrideMap = <String, Map<String, dynamic>>{};
    if (symbolOverrides != null) {
      // Debug: log first few overrides to understand structure
      if (figmaRendererDebug && symbolOverrides.isNotEmpty) {
        print('DEBUG OVERRIDES for "${props.name}": ${symbolOverrides.length} overrides');
        for (int i = 0; i < symbolOverrides.length && i < 3; i++) {
          final o = symbolOverrides[i];
          if (o is Map) {
            print('  [$i] keys: ${o.keys.toList()}');
            if (o.containsKey('textData')) {
              final td = o['textData'];
              if (td is Map) {
                print('      textData.characters: "${td['characters']}"');
              }
            }
            if (o.containsKey('characters')) {
              print('      characters: "${o['characters']}"');
            }
          }
        }
      }

      // First pass: extract componentPropAssignments (text values etc)
      for (final override in symbolOverrides) {
        if (override is Map && override.containsKey('componentPropAssignments')) {
          final propAssignments = override['componentPropAssignments'];
          if (propAssignments is List) {
            for (final assignment in propAssignments) {
              if (assignment is Map) {
                final defId = assignment['defID'];
                final value = assignment['value'];
                if (defId is Map && value != null) {
                  final defKey = '${defId['sessionID']}:${defId['localID']}';
                  componentPropValues[defKey] = value;
                }
              }
            }
          }
        }
      }

      for (final override in symbolOverrides) {
        if (override is Map) {
          // Check for text-related overrides (including componentPropAssignments)
          final hasTextData = override.containsKey('textData');
          final hasCharacters = override.containsKey('characters');
          final hasPropAssignments = override.containsKey('componentPropAssignments');

          if (figmaRendererDebug && (hasTextData || hasCharacters)) {
            print('DEBUG FOUND TEXT OVERRIDE in "${props.name}": textData=$hasTextData, characters=$hasCharacters');
            if (hasTextData) print('  textData: ${override['textData']}');
            if (hasCharacters) print('  characters: ${override['characters']}');
          }

          // Check componentPropAssignments for text properties (Figma's modern way of storing overrides)
          if (hasPropAssignments) {
            final propAssignments = override['componentPropAssignments'];
            if (propAssignments is List && propAssignments.isNotEmpty) {
              for (final assignment in propAssignments) {
                if (assignment is Map) {
                  final defId = assignment['defID'];
                  final value = assignment['value'];
                  if (figmaRendererDebug && value != null) {
                    print('DEBUG PROP ASSIGNMENT in "${props.name}": defID=$defId, value=$value');
                  }
                }
              }
            }
          }

          final guidPath = override['guidPath'];
          String? overrideKey;

          if (guidPath is Map) {
            // guidPath can be in two formats:
            // 1. Direct GUID: {sessionID: x, localID: y}
            // 2. Nested: {guids: [{sessionID: x, localID: y}]}
            if (guidPath.containsKey('guids')) {
              // Nested format: {guids: [{sessionID: x, localID: y}, ...]}
              final guids = guidPath['guids'];
              if (guids is List && guids.isNotEmpty) {
                // Use the last GUID in the path (the target node)
                final targetGuid = guids.last;
                if (targetGuid is Map) {
                  final sessionId = targetGuid['sessionID'] ?? 0;
                  final localId = targetGuid['localID'] ?? 0;
                  overrideKey = '$sessionId:$localId';
                }
              }
            } else if (guidPath.containsKey('sessionID')) {
              // Direct GUID format: {sessionID: x, localID: y}
              final sessionId = guidPath['sessionID'] ?? 0;
              final localId = guidPath['localID'] ?? 0;
              overrideKey = '$sessionId:$localId';
            }
          } else if (guidPath is List && guidPath.isNotEmpty) {
            // guidPath is a list of GUIDs - use the last one (target node)
            final targetGuid = guidPath.last;
            if (targetGuid is Map) {
              final sessionId = targetGuid['sessionID'] ?? 0;
              final localId = targetGuid['localID'] ?? 0;
              overrideKey = '$sessionId:$localId';
            }
          }

          if (overrideKey != null) {
            // Store the override properties (excluding guidPath itself)
            final overrideProps = Map<String, dynamic>.from(override);
            overrideProps.remove('guidPath');
            overrideMap[overrideKey] = overrideProps;

            // Debug: Log when we find textData overrides
            if (figmaRendererDebug && overrideProps.containsKey('textData')) {
              final td = overrideProps['textData'];
              if (td is Map && td.containsKey('characters')) {
                print('DEBUG OVERRIDE: key=$overrideKey has textData.characters="${td['characters']}"');
              }
            }
          }
        }
      }
    }

    // Debug: Log override map size
    if (figmaRendererDebug && overrideMap.isNotEmpty) {
      print('DEBUG OVERRIDE MAP for "${props.name}": ${overrideMap.length} entries, keys=${overrideMap.keys.take(5).toList()}');
    }

    // Build child widgets (reversed order for correct z-order)
    final children = <Widget>[];
    if (nodeMap != null) {
      // Reverse order: Figma's first child = top, Flutter Stack's last = top
      final reversedKeys = childrenKeys.reversed.toList();

      // Debug: Log child keys vs override keys for first instance with overrides
      if (figmaRendererDebug && overrideMap.isNotEmpty && reversedKeys.isNotEmpty) {
        print('DEBUG CHILD MATCHING for "${props.name}":');
        print('  childKeys: ${reversedKeys.take(5).toList()}');
        print('  overrideKeys: ${overrideMap.keys.take(5).toList()}');
        // Also check what the child node's guid looks like
        for (final ck in reversedKeys.take(2)) {
          final cn = nodeMap![ck];
          if (cn != null) {
            final cnGuid = cn['guid'];
            print('  child "$ck" guid=${cnGuid}');
          }
        }
      }

      // Pre-scan: collect text overrides and text children for fallback matching
      // This handles the case where guidPath uses original component guids that don't match nodeMap
      final textOverrides = <String, Map<String, dynamic>>{};
      for (final entry in overrideMap.entries) {
        if (entry.value.containsKey('textData')) {
          textOverrides[entry.key] = entry.value;
        }
      }
      final textChildKeys = <String>[];
      for (final ck in reversedKeys) {
        final cn = nodeMap![ck];
        if (cn != null && cn['type'] == 'TEXT') {
          textChildKeys.add(ck);
        }
      }
      // If there's exactly one text child and one text override, they should match
      Map<String, dynamic>? singleTextOverride;
      if (textChildKeys.length == 1 && textOverrides.length == 1) {
        singleTextOverride = textOverrides.values.first;
        if (figmaRendererDebug) {
          print('DEBUG SINGLE TEXT MATCH: using fallback for "${props.name}"');
        }
      }

      for (final childKey in reversedKeys) {
        final childNode = nodeMap![childKey];
        if (childNode != null) {
          final childProps = FigmaNodeProperties.fromMap(childNode);
          if (!childProps.visible) continue;

          // Check if there's an override for this child
          // First try by childKey (nodeMap key)
          Map<String, dynamic>? childOverride = overrideMap[childKey];

          // If not found, try by the node's original guid (which matches symbolOverrides guidPath)
          if (childOverride == null && overrideMap.isNotEmpty) {
            final childGuid = childNode['guid'];
            if (childGuid is Map) {
              final sessionId = childGuid['sessionID'] ?? 0;
              final localId = childGuid['localID'] ?? 0;
              final guidKey = '$sessionId:$localId';
              childOverride = overrideMap[guidKey];
              if (figmaRendererDebug && childOverride != null) {
                print('DEBUG OVERRIDE FOUND BY GUID: childKey="$childKey" → guidKey="$guidKey"');
              }
            }
          }

          // Fallback: if this is the only TEXT child and there's only one text override, use it
          if (childOverride == null && singleTextOverride != null && childProps.type == 'TEXT') {
            childOverride = singleTextOverride;
            if (figmaRendererDebug) {
              print('DEBUG OVERRIDE FALLBACK: applying single text override to "$childKey"');
            }
          }

          // Debug: Log when we find/don't find override for TEXT nodes
          if (figmaRendererDebug && childProps.type == 'TEXT' && overrideMap.isNotEmpty) {
            print('DEBUG TEXT CHILD: key="$childKey" name="${childProps.name}" hasOverride=${childOverride != null}');
            if (childOverride != null && childOverride.containsKey('textData')) {
              final td = childOverride['textData'];
              if (td is Map) {
                print('  → OVERRIDE TEXT: "${td['characters']}"');
              }
            }
          }

          children.add(
            Positioned(
              left: childProps.x * scale,
              top: childProps.y * scale,
              child: FigmaNodeWidget(
                node: childNode,
                nodeMap: nodeMap,
                blobMap: blobMap,
                imagesDirectory: imagesDirectory,
                scale: scale,
                propertyOverrides: childOverride,
                instanceOverrides: overrideMap, // Pass full map for nested lookups
              ),
            ),
          );
        }
      }
    }

    return Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: decoration,
      clipBehavior: props.raw['clipsContent'] == true ? Clip.hardEdge : Clip.none,
      child: children.isEmpty
          ? null
          : Stack(
              clipBehavior: Clip.none,
              children: children,
            ),
    );
  }

  BoxDecoration _buildDecoration() {
    Color? backgroundColor;

    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;
      final fillType = fill['type'];
      if (fillType == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          backgroundColor = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
      }
    }

    return BoxDecoration(
      color: backgroundColor,
      borderRadius: props.borderRadius,
    );
  }
}

/// Rectangle renderer
class FigmaRectangleWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaRectangleWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(props.width, props.height),
      painter: _RectanglePainter(props: props),
    );
  }
}

class _RectanglePainter extends CustomPainter {
  final FigmaNodeProperties props;

  _RectanglePainter({required this.props});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    RRect rrect;

    if (props.cornerRadii != null && props.cornerRadii!.length >= 4) {
      rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(props.cornerRadii![0]),
        topRight: Radius.circular(props.cornerRadii![1]),
        bottomRight: Radius.circular(props.cornerRadii![2]),
        bottomLeft: Radius.circular(props.cornerRadii![3]),
      );
    } else {
      rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(props.effectiveCornerRadius),
      );
    }

    // Draw fills
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final paint = Paint();
      final fillType = fill['type'];

      if (fillType == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawRRect(rrect, paint);
      }
    }

    // Draw strokes
    if (props.strokes.isNotEmpty && props.strokeWeight > 0) {
      final stroke = props.strokes.first;
      if (stroke['visible'] != false) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = props.strokeWeight;

        final color = stroke['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ellipse renderer
class FigmaEllipseWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaEllipseWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(props.width, props.height),
      painter: _EllipsePainter(props: props),
    );
  }
}

class _EllipsePainter extends CustomPainter {
  final FigmaNodeProperties props;

  _EllipsePainter({required this.props});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw fills
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final paint = Paint();
      final fillType = fill['type'];

      if (fillType == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawOval(rect, paint);
      }
    }

    // Draw strokes
    if (props.strokes.isNotEmpty && props.strokeWeight > 0) {
      final stroke = props.strokes.first;
      if (stroke['visible'] != false) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = props.strokeWeight;

        final color = stroke['color'];
        if (color is Map) {
          paint.color = Color.fromRGBO(
            ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (color['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        canvas.drawOval(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Text renderer
class FigmaTextWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final double scale;
  /// The effective node data (with overrides applied)
  final Map<String, dynamic>? effectiveNode;

  const FigmaTextWidget({super.key, required this.props, this.scale = 1.0, this.effectiveNode});

  @override
  Widget build(BuildContext context) {
    // Use effectiveNode if provided (has overrides), otherwise use props.raw
    final nodeData = effectiveNode ?? props.raw;

    // Extract text content
    final textData = nodeData['textData'];
    String text = '';
    if (textData is Map) {
      text = textData['characters'] as String? ?? '';
      // Debug: Log text data structure for troubleshooting
      if (figmaRendererDebug && text.isNotEmpty && text.length < 20) {
        print('DEBUG TEXT: "${props.name}" textData.characters="$text" codeUnits=${text.codeUnits}');
        // Check for other text-related fields
        if (textData['glyphs'] != null) {
          print('  glyphs: ${textData['glyphs']}');
        }
        if (textData['layoutVersion'] != null) {
          print('  layoutVersion: ${textData['layoutVersion']}');
        }
      }
    } else {
      text = nodeData['characters'] as String? ?? props.name ?? '';
      // Debug: Log when falling back to characters or name
      if (figmaRendererDebug && text.isNotEmpty && text.length < 20) {
        print('DEBUG TEXT FALLBACK: "${props.name}" text="$text" (from characters/name)');
      }
    }

    // Extract text style with scaling
    var style = _buildTextStyle(text);

    // Get text alignment
    final textAlignHorizontal = props.raw['textAlignHorizontal'] as String?;
    TextAlign textAlign = TextAlign.left;
    if (textAlignHorizontal == 'CENTER') {
      textAlign = TextAlign.center;
    } else if (textAlignHorizontal == 'RIGHT') {
      textAlign = TextAlign.right;
    } else if (textAlignHorizontal == 'JUSTIFIED') {
      textAlign = TextAlign.justify;
    }

    // Check how text should auto-resize
    final textAutoResize = props.raw['textAutoResize'] as String?;
    // HEIGHT = fixed width, height adjusts to content
    // WIDTH_AND_HEIGHT = both adjust to content (no constraints)
    // NONE/TRUNCATE = fixed size

    // For auto-sizing text boxes, don't constrain
    final bool autoWidth = textAutoResize == 'WIDTH_AND_HEIGHT';
    final bool autoHeight = textAutoResize == 'WIDTH_AND_HEIGHT' || textAutoResize == 'HEIGHT';

    return SizedBox(
      width: autoWidth ? null : (props.width > 0 ? props.width * scale : null),
      height: autoHeight ? null : (props.height > 0 ? props.height * scale : null),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: TextOverflow.visible, // Allow overflow to be visible
        softWrap: true,
      ),
    );
  }

  TextStyle _buildTextStyle(String text) {
    double fontSize = 14;
    FontWeight fontWeight = FontWeight.normal;
    FontStyle fontStyle = FontStyle.normal;
    Color color = Colors.black;
    String? fontFamily;
    double? letterSpacing;
    double? height;

    // Check if text contains SF Symbols - if so, force system font
    final bool hasSFSymbols = _containsSFSymbols(text);

    // Try to get font info from various fields
    final fontMetaData = props.raw['fontMetaData'];
    if (fontMetaData is Map && fontMetaData.isNotEmpty) {
      final firstMeta = fontMetaData.values.first;
      if (firstMeta is Map) {
        fontFamily = firstMeta['family'] as String?;
        // Check style for italic
        final style = firstMeta['style'] as String?;
        if (style != null && style.toLowerCase().contains('italic')) {
          fontStyle = FontStyle.italic;
        }
        // Extract weight from style name
        if (style != null) {
          fontWeight = _getFontWeightFromStyle(style);
        }
      }
    }

    // Try fontName field (Figma plugin API format)
    final fontName = props.raw['fontName'];
    if (fontName is Map) {
      fontFamily ??= fontName['family'] as String?;
      final style = fontName['style'] as String?;
      if (style != null) {
        if (style.toLowerCase().contains('italic')) {
          fontStyle = FontStyle.italic;
        }
        fontWeight = _getFontWeightFromStyle(style);
      }
    }

    // Map Figma fonts to system fonts
    fontFamily = _mapFigmaFont(fontFamily);

    // Get font size from derivedTextData or fontSize field
    final derivedTextData = props.raw['derivedTextData'];
    if (derivedTextData is Map) {
      final baseFontSize = derivedTextData['baseFontSize'];
      if (baseFontSize is num) {
        fontSize = baseFontSize.toDouble();
      }
    }

    final rawFontSize = props.raw['fontSize'];
    if (rawFontSize is num) {
      fontSize = rawFontSize.toDouble();
    }

    // Get font weight (explicit field overrides style-derived weight)
    final rawFontWeight = props.raw['fontWeight'];
    if (rawFontWeight is num) {
      fontWeight = _getFontWeight(rawFontWeight.toInt());
    }

    // Get color from fills
    if (props.fills.isNotEmpty) {
      final fill = props.fills.first;
      if (fill['visible'] != false && fill['type'] == 'SOLID') {
        final fillColor = fill['color'];
        if (fillColor is Map) {
          color = Color.fromRGBO(
            ((fillColor['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((fillColor['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((fillColor['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (fillColor['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
      }
    }

    // Get letter spacing
    final rawLetterSpacing = props.raw['letterSpacing'];
    if (rawLetterSpacing is num) {
      letterSpacing = rawLetterSpacing.toDouble();
    }

    // Get line height
    final rawLineHeight = props.raw['lineHeight'];
    if (rawLineHeight is num && fontSize > 0) {
      height = rawLineHeight.toDouble() / fontSize;
    }

    // Force system font for SF Symbols (icons)
    if (hasSFSymbols) {
      fontFamily = '.AppleSystemUIFont';
    }

    return TextStyle(
      fontSize: fontSize * scale,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing != null ? letterSpacing * scale : null,
      height: height,
    );
  }

  FontWeight _getFontWeight(int weight) {
    if (weight <= 100) return FontWeight.w100;
    if (weight <= 200) return FontWeight.w200;
    if (weight <= 300) return FontWeight.w300;
    if (weight <= 400) return FontWeight.w400;
    if (weight <= 500) return FontWeight.w500;
    if (weight <= 600) return FontWeight.w600;
    if (weight <= 700) return FontWeight.w700;
    if (weight <= 800) return FontWeight.w800;
    return FontWeight.w900;
  }

  FontWeight _getFontWeightFromStyle(String style) {
    final lower = style.toLowerCase();
    if (lower.contains('thin') || lower.contains('hairline')) return FontWeight.w100;
    if (lower.contains('extralight') || lower.contains('ultralight')) return FontWeight.w200;
    if (lower.contains('light')) return FontWeight.w300;
    if (lower.contains('regular') || lower.contains('normal')) return FontWeight.w400;
    if (lower.contains('medium')) return FontWeight.w500;
    if (lower.contains('semibold') || lower.contains('demibold')) return FontWeight.w600;
    if (lower.contains('bold') && !lower.contains('extra') && !lower.contains('ultra')) return FontWeight.w700;
    if (lower.contains('extrabold') || lower.contains('ultrabold')) return FontWeight.w800;
    if (lower.contains('black') || lower.contains('heavy')) return FontWeight.w900;
    return FontWeight.w400;
  }

  /// Map Figma font families to system fonts available on macOS/iOS
  String? _mapFigmaFont(String? figmaFont) {
    if (figmaFont == null) return null;

    // Common Figma font mappings to system fonts
    const fontMap = {
      // SF Pro is the default iOS/macOS system font
      'SF Pro': '.AppleSystemUIFont',
      'SF Pro Display': '.AppleSystemUIFont',
      'SF Pro Text': '.AppleSystemUIFont',
      'SF Pro Rounded': '.AppleSystemUIFont',
      'SF Compact': '.AppleSystemUIFont',
      'SF Compact Text': '.AppleSystemUIFont',
      'SF Compact Display': '.AppleSystemUIFont',
      'SF Compact Rounded': '.AppleSystemUIFont',
      'SF Mono': 'Menlo',
      // SF Symbols - used for Apple icons (private use area characters)
      // These characters (like 􀄫) require the SF Pro font with symbols
      'SF Symbols': '.AppleSystemUIFont', // SF Symbols are in the system font
      // Inter is Figma's default font
      'Inter': null, // Let Flutter use default
      // Other common fonts
      'Roboto': 'Roboto',
      'Helvetica': 'Helvetica',
      'Helvetica Neue': 'Helvetica Neue',
      'Arial': 'Arial',
      'Georgia': 'Georgia',
      'Times New Roman': 'Times New Roman',
      'Courier New': 'Courier New',
      'Menlo': 'Menlo',
      'Monaco': 'Monaco',
    };

    // Check direct mapping
    if (fontMap.containsKey(figmaFont)) {
      return fontMap[figmaFont];
    }

    // Check if it starts with a known prefix
    for (final entry in fontMap.entries) {
      if (figmaFont.startsWith(entry.key)) {
        return entry.value;
      }
    }

    // Return original if no mapping found - Flutter will try to use it
    return figmaFont;
  }

  /// Check if text contains SF Symbols (private use area characters)
  bool _containsSFSymbols(String text) {
    // SF Symbols use Unicode Private Use Area: U+100000 to U+10FFFF
    // In Dart, these are represented as surrogate pairs
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // High surrogate for supplementary planes (U+10000+)
      if (code >= 0xD800 && code <= 0xDBFF) {
        return true;
      }
    }
    return false;
  }
}

/// Vector/path renderer
class FigmaVectorWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaVectorWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(props.width, props.height),
      painter: _VectorPainter(props: props),
    );
  }
}

class _VectorPainter extends CustomPainter {
  final FigmaNodeProperties props;

  _VectorPainter({required this.props});

  @override
  void paint(Canvas canvas, Size size) {
    // Get vector paths from fillGeometry
    final fillGeometry = props.raw['fillGeometry'];
    final strokeGeometry = props.raw['strokeGeometry'];

    // Draw fills
    if (fillGeometry is List) {
      for (final geom in fillGeometry) {
        if (geom is Map) {
          final pathData = geom['path'] as String?;
          if (pathData != null) {
            final path = _parseSvgPath(pathData, size);

            for (final fill in props.fills) {
              if (fill['visible'] == false) continue;

              final paint = Paint();
              if (fill['type'] == 'SOLID') {
                final color = fill['color'];
                if (color is Map) {
                  paint.color = Color.fromRGBO(
                    ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                    ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                    ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                    (color['a'] as num?)?.toDouble() ?? 1.0,
                  );
                  canvas.drawPath(path, paint);
                }
              }
            }
          }
        }
      }
    }

    // Draw strokes
    if (strokeGeometry is List && props.strokeWeight > 0) {
      for (final geom in strokeGeometry) {
        if (geom is Map) {
          final pathData = geom['path'] as String?;
          if (pathData != null) {
            final path = _parseSvgPath(pathData, size);

            for (final stroke in props.strokes) {
              if (stroke['visible'] == false) continue;

              final paint = Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = props.strokeWeight;

              final color = stroke['color'];
              if (color is Map) {
                paint.color = Color.fromRGBO(
                  ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                  ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                  ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                  (color['a'] as num?)?.toDouble() ?? 1.0,
                );
                canvas.drawPath(path, paint);
              }
            }
          }
        }
      }
    }

    // Fallback: draw simple shape if no geometry
    if (fillGeometry == null && strokeGeometry == null) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);

      for (final fill in props.fills) {
        if (fill['visible'] == false) continue;

        final paint = Paint();
        if (fill['type'] == 'SOLID') {
          final color = fill['color'];
          if (color is Map) {
            paint.color = Color.fromRGBO(
              ((color['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((color['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              (color['a'] as num?)?.toDouble() ?? 1.0,
            );
            canvas.drawRect(rect, paint);
          }
        }
      }
    }
  }

  ui.Path _parseSvgPath(String pathData, Size size) {
    final path = ui.Path();
    // Basic SVG path parser - handles M, L, C, Z commands
    // This is a simplified implementation
    final commands = pathData.split(RegExp(r'(?=[MLCQZmlcqz])'));

    double x = 0, y = 0;

    for (var cmd in commands) {
      cmd = cmd.trim();
      if (cmd.isEmpty) continue;

      final type = cmd[0];
      final args = cmd.substring(1).trim().split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).map((s) => double.tryParse(s) ?? 0).toList();

      switch (type) {
        case 'M':
          if (args.length >= 2) {
            x = args[0];
            y = args[1];
            path.moveTo(x, y);
          }
          break;
        case 'm':
          if (args.length >= 2) {
            x += args[0];
            y += args[1];
            path.moveTo(x, y);
          }
          break;
        case 'L':
          if (args.length >= 2) {
            x = args[0];
            y = args[1];
            path.lineTo(x, y);
          }
          break;
        case 'l':
          if (args.length >= 2) {
            x += args[0];
            y += args[1];
            path.lineTo(x, y);
          }
          break;
        case 'C':
          if (args.length >= 6) {
            path.cubicTo(args[0], args[1], args[2], args[3], args[4], args[5]);
            x = args[4];
            y = args[5];
          }
          break;
        case 'c':
          if (args.length >= 6) {
            path.cubicTo(x + args[0], y + args[1], x + args[2], y + args[3], x + args[4], y + args[5]);
            x += args[4];
            y += args[5];
          }
          break;
        case 'Q':
          if (args.length >= 4) {
            path.quadraticBezierTo(args[0], args[1], args[2], args[3]);
            x = args[2];
            y = args[3];
          }
          break;
        case 'q':
          if (args.length >= 4) {
            path.quadraticBezierTo(x + args[0], y + args[1], x + args[2], y + args[3]);
            x += args[2];
            y += args[3];
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Canvas (page) renderer
class FigmaCanvasWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final Map<String, List<int>>? blobMap;
  final String? imagesDirectory;
  final double scale;

  const FigmaCanvasWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.blobMap,
    this.imagesDirectory,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Get background color from canvas
    Color? backgroundColor;
    final bgColor = props.raw['backgroundColor'];
    if (bgColor is Map) {
      backgroundColor = Color.fromRGBO(
        ((bgColor['r'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        ((bgColor['g'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        ((bgColor['b'] as num?)?.toDouble() ?? 1) * 255 ~/ 1,
        (bgColor['a'] as num?)?.toDouble() ?? 1.0,
      );
    }

    final children = _buildChildren();

    return Container(
      color: backgroundColor ?? Colors.white,
      child: children.isEmpty
          ? null
          : Stack(
              clipBehavior: Clip.none,
              children: children,
            ),
    );
  }

  List<Widget> _buildChildren() {
    if (nodeMap == null) return [];

    final childrenKeys = props.raw['children'] as List?;
    if (childrenKeys == null) return [];

    final children = <Widget>[];
    // Reverse order: Figma's first child = top, Flutter Stack's last = top
    final reversedKeys = childrenKeys.reversed.toList();
    for (final childKey in reversedKeys) {
      // childKey is now a String key like "0:123"
      final childNode = nodeMap![childKey.toString()];
      if (childNode != null) {
        final childProps = FigmaNodeProperties.fromMap(childNode);
        // Only render visible children
        if (!childProps.visible) continue;

        children.add(
          Positioned(
            left: childProps.x * scale,
            top: childProps.y * scale,
            child: FigmaNodeWidget(
              node: childNode,
              nodeMap: nodeMap,
              blobMap: blobMap,
              imagesDirectory: imagesDirectory,
              scale: scale,
            ),
          ),
        );
      }
    }
    return children;
  }
}

// =============================================================================
// FigJam and Extended Node Types
// =============================================================================

/// Sticky note widget (FigJam)
class FigmaStickyWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final double scale;

  const FigmaStickyWidget({
    super.key,
    required this.props,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Extract text content
    final textData = props.raw['textData'] as Map<String, dynamic>?;
    final characters = textData?['characters'] as String? ?? '';

    // Extract background color
    Color backgroundColor = const Color(0xFFFFF9C4); // Default yellow
    if (props.fills.isNotEmpty) {
      final fill = props.fills.first;
      if (fill['type'] == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          backgroundColor = PaintRenderer.buildColor(color.cast<String, dynamic>()) ?? backgroundColor;
        }
      }
    }

    return Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(3 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      padding: EdgeInsets.all(12 * scale),
      child: Text(
        characters,
        style: TextStyle(
          fontSize: 14 * scale,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// Shape with text widget (FigJam)
class FigmaShapeWithTextWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final double scale;

  const FigmaShapeWithTextWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Extract text content
    final textData = props.raw['textData'] as Map<String, dynamic>?;
    final characters = textData?['characters'] as String? ?? '';

    // Get fill color
    Color fillColor = Colors.white;
    if (props.fills.isNotEmpty) {
      final fill = props.fills.first;
      if (fill['type'] == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          fillColor = PaintRenderer.buildColor(color.cast<String, dynamic>()) ?? fillColor;
        }
      }
    }

    // Get stroke
    Color strokeColor = Colors.black;
    if (props.strokes.isNotEmpty) {
      final stroke = props.strokes.first;
      if (stroke['type'] == 'SOLID') {
        final color = stroke['color'];
        if (color is Map) {
          strokeColor = PaintRenderer.buildColor(color.cast<String, dynamic>()) ?? strokeColor;
        }
      }
    }

    return Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: BoxDecoration(
        color: fillColor,
        border: props.strokeWeight > 0 ? Border.all(
          color: strokeColor,
          width: props.strokeWeight * scale,
        ) : null,
        borderRadius: props.borderRadius,
      ),
      alignment: Alignment.center,
      child: Text(
        characters,
        style: TextStyle(
          fontSize: 14 * scale,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Connector line widget (FigJam)
class FigmaConnectorWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final double scale;

  const FigmaConnectorWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Connectors are typically rendered as lines between nodes
    // For now, render as a simple line
    Color strokeColor = Colors.black;
    if (props.strokes.isNotEmpty) {
      final stroke = props.strokes.first;
      if (stroke['type'] == 'SOLID') {
        final color = stroke['color'];
        if (color is Map) {
          strokeColor = PaintRenderer.buildColor(color.cast<String, dynamic>()) ?? strokeColor;
        }
      }
    }

    return SizedBox(
      width: props.width * scale,
      height: props.height * scale,
      child: CustomPaint(
        painter: _ConnectorPainter(
          strokeColor: strokeColor,
          strokeWidth: props.strokeWeight * scale,
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;

  _ConnectorPainter({
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth > 0 ? strokeWidth : 1.0
      ..style = PaintingStyle.stroke;

    // Draw a simple line from start to end
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) {
    return strokeColor != oldDelegate.strokeColor ||
           strokeWidth != oldDelegate.strokeWidth;
  }
}

/// Table widget
class FigmaTableWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final Map<String, Map<String, dynamic>>? nodeMap;
  final double scale;

  const FigmaTableWidget({
    super.key,
    required this.props,
    this.nodeMap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Tables are containers with TABLE_CELL children
    // For now, render as a simple container
    Color fillColor = Colors.white;
    if (props.fills.isNotEmpty) {
      final fill = props.fills.first;
      if (fill['type'] == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          fillColor = PaintRenderer.buildColor(color.cast<String, dynamic>()) ?? fillColor;
        }
      }
    }

    return Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: Colors.grey.shade300),
      ),
      // Would need to render children as grid
    );
  }
}

/// Media placeholder widget (video, lottie, embed)
class FigmaMediaWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final double scale;

  const FigmaMediaWidget({
    super.key,
    required this.props,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4 * scale),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getMediaIcon(),
            size: 32 * scale,
            color: Colors.grey.shade600,
          ),
          SizedBox(height: 8 * scale),
          Text(
            props.type,
            style: TextStyle(
              fontSize: 10 * scale,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMediaIcon() {
    switch (props.type) {
      case 'MEDIA':
        return Icons.play_circle_outline;
      case 'LOTTIE':
        return Icons.animation;
      case 'EMBED':
        return Icons.code;
      case 'LINK_UNFURL':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }
}

/// Code block widget
class FigmaCodeBlockWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final double scale;

  const FigmaCodeBlockWidget({
    super.key,
    required this.props,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Extract code content
    final textData = props.raw['textData'] as Map<String, dynamic>?;
    final characters = textData?['characters'] as String? ?? '';

    return Container(
      width: props.width * scale,
      height: props.height * scale,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      padding: EdgeInsets.all(12 * scale),
      child: SingleChildScrollView(
        child: Text(
          characters,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12 * scale,
            color: const Color(0xFFD4D4D4),
          ),
        ),
      ),
    );
  }
}

/// Slice node renderer - export areas that are usually invisible
/// SLICE nodes define export regions in Figma
class FigmaSliceWidget extends StatelessWidget {
  final FigmaNodeProperties props;
  final double scale;

  const FigmaSliceWidget({
    super.key,
    required this.props,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Slices are typically invisible during normal rendering
    // but we show a subtle dashed border for debugging
    return SizedBox(
      width: props.width * scale,
      height: props.height * scale,
      child: CustomPaint(
        painter: _SliceBorderPainter(),
      ),
    );
  }
}

class _SliceBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x40FF6B00) // Orange with low opacity
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw dashed border
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Simple solid border for now (dashed requires more complex path iteration)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Placeholder for unknown node types
class FigmaPlaceholderWidget extends StatelessWidget {
  final FigmaNodeProperties props;

  const FigmaPlaceholderWidget({super.key, required this.props});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: props.width,
      height: props.height,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x80808080)), // grey with 0.5 opacity
        color: const Color(0x1A808080), // grey with 0.1 opacity
      ),
      child: Center(
        child: Text(
          props.type,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DEBUG OVERLAY SYSTEM
// =============================================================================

/// Global debug overlay controller - manages node inspection state
class DebugOverlayController extends ChangeNotifier {
  static final DebugOverlayController _instance = DebugOverlayController._();
  static DebugOverlayController get instance => _instance;

  DebugOverlayController._();

  bool _enabled = true; // Enabled by default for selection to work
  Map<String, dynamic>? _selectedNode;
  FigmaNodeProperties? _selectedProps;
  String? _hoveredNodeId;
  final List<String> _nodeHistory = [];
  int _historyIndex = -1;

  // For double-click to enter groups
  String? _enteredGroupId; // The group we've "entered" via double-click
  final List<String> _groupStack = []; // Stack of entered groups for nested navigation

  bool get enabled => _enabled;
  Map<String, dynamic>? get selectedNode => _selectedNode;
  FigmaNodeProperties? get selectedProps => _selectedProps;
  String? get hoveredNodeId => _hoveredNodeId;
  String? get enteredGroupId => _enteredGroupId;
  bool get isInsideGroup => _enteredGroupId != null;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _nodeHistory.length - 1;

  void toggle() {
    _enabled = !_enabled;
    if (!_enabled) {
      _selectedNode = null;
      _selectedProps = null;
      _hoveredNodeId = null;
    }
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_enabled != value) {
      _enabled = value;
      if (!_enabled) {
        _selectedNode = null;
        _selectedProps = null;
        _hoveredNodeId = null;
      }
      notifyListeners();
    }
  }

  void selectNode(Map<String, dynamic> node) {
    _selectedNode = node;
    _selectedProps = FigmaNodeProperties.fromMap(node);

    // Add to history
    final nodeId = node['_guidKey']?.toString() ?? '';
    if (_historyIndex < _nodeHistory.length - 1) {
      _nodeHistory.removeRange(_historyIndex + 1, _nodeHistory.length);
    }
    _nodeHistory.add(nodeId);
    _historyIndex = _nodeHistory.length - 1;

    notifyListeners();
  }

  void clearSelection() {
    _selectedNode = null;
    _selectedProps = null;
    notifyListeners();
  }

  void setHovered(String? nodeId) {
    if (_hoveredNodeId != nodeId) {
      _hoveredNodeId = nodeId;
      notifyListeners();
    }
  }

  void goBack(Map<String, Map<String, dynamic>> nodeMap) {
    if (canGoBack) {
      _historyIndex--;
      final nodeId = _nodeHistory[_historyIndex];
      final node = nodeMap[nodeId];
      if (node != null) {
        _selectedNode = node;
        _selectedProps = FigmaNodeProperties.fromMap(node);
        notifyListeners();
      }
    }
  }

  void goForward(Map<String, Map<String, dynamic>> nodeMap) {
    if (canGoForward) {
      _historyIndex++;
      final nodeId = _nodeHistory[_historyIndex];
      final node = nodeMap[nodeId];
      if (node != null) {
        _selectedNode = node;
        _selectedProps = FigmaNodeProperties.fromMap(node);
        notifyListeners();
      }
    }
  }

  /// Update node position (for drag-to-move)
  void updateNodePosition(Map<String, dynamic> node, double x, double y) {
    // Update the transform in the node data
    final transform = node['transform'];
    if (transform is Map) {
      transform['m02'] = x;
      transform['m12'] = y;
    } else {
      node['transform'] = {'m02': x, 'm12': y, 'm00': 1.0, 'm11': 1.0};
    }

    // Update selectedProps if this is the selected node
    if (_selectedNode == node) {
      _selectedProps = FigmaNodeProperties.fromMap(node);
    }

    notifyListeners();
  }

  /// Update node size (for resize handles)
  void updateNodeSize(Map<String, dynamic> node, double width, double height) {
    final size = node['size'];
    if (size is Map) {
      size['x'] = width;
      size['y'] = height;
    } else {
      node['size'] = {'x': width, 'y': height};
    }

    if (_selectedNode == node) {
      _selectedProps = FigmaNodeProperties.fromMap(node);
    }

    notifyListeners();
  }

  /// Update a property on the selected node
  void updateNodeProperty(String key, dynamic value) {
    if (_selectedNode != null) {
      _selectedNode![key] = value;
      _selectedProps = FigmaNodeProperties.fromMap(_selectedNode!);
      notifyListeners();
    }
  }

  /// Enter a group (double-click behavior) to select children inside
  void enterGroup(Map<String, dynamic> node) {
    final nodeId = node['_guidKey']?.toString();
    if (nodeId == null) return;

    // Check if this node has children (is a group/frame)
    final children = node['children'] as List?;
    if (children == null || children.isEmpty) return;

    // Push current group to stack if we're already inside one
    if (_enteredGroupId != null) {
      _groupStack.add(_enteredGroupId!);
    }

    _enteredGroupId = nodeId;
    _selectedNode = node;
    _selectedProps = FigmaNodeProperties.fromMap(node);
    notifyListeners();
  }

  /// Exit the current group (go back up one level)
  void exitGroup(Map<String, Map<String, dynamic>> nodeMap) {
    if (_groupStack.isNotEmpty) {
      // Go back to previous group
      _enteredGroupId = _groupStack.removeLast();
      final node = nodeMap[_enteredGroupId];
      if (node != null) {
        _selectedNode = node;
        _selectedProps = FigmaNodeProperties.fromMap(node);
      }
    } else {
      // Exit to top level
      _enteredGroupId = null;
    }
    notifyListeners();
  }

  /// Exit all groups and go to top level
  void exitAllGroups() {
    _enteredGroupId = null;
    _groupStack.clear();
    notifyListeners();
  }

  /// Check if a node is a direct child of the currently entered group
  bool isDirectChildOfEnteredGroup(Map<String, dynamic> node, Map<String, Map<String, dynamic>> nodeMap) {
    if (_enteredGroupId == null) return true; // At top level, all top-level nodes are valid

    final enteredGroup = nodeMap[_enteredGroupId];
    if (enteredGroup == null) return false;

    final children = enteredGroup['children'] as List?;
    if (children == null) return false;

    final nodeId = node['_guidKey']?.toString();
    return children.any((childKey) => childKey.toString() == nodeId);
  }

  /// Check if a node is the entered group or an ancestor of it
  bool isEnteredGroupOrAncestor(String? nodeId) {
    if (_enteredGroupId == null) return false;
    if (nodeId == _enteredGroupId) return true;
    return _groupStack.contains(nodeId);
  }
}

/// Widget that wraps nodes with debug tap handling and editing
class DebugNodeWrapper extends StatefulWidget {
  final Widget child;
  final Map<String, dynamic> node;
  final double scale;

  const DebugNodeWrapper({
    super.key,
    required this.child,
    required this.node,
    this.scale = 1.0,
  });

  @override
  State<DebugNodeWrapper> createState() => _DebugNodeWrapperState();
}

class _DebugNodeWrapperState extends State<DebugNodeWrapper> {
  Offset? _dragStart;
  Offset? _originalPosition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        if (!DebugOverlayController.instance.enabled) {
          return widget.child;
        }

        final controller = DebugOverlayController.instance;
        final nodeId = widget.node['_guidKey']?.toString() ?? '';
        final isSelected = controller.selectedNode?['_guidKey'] == nodeId;
        final isHovered = controller.hoveredNodeId == nodeId;
        final props = FigmaNodeProperties.fromMap(widget.node);

        // Check if this node has children (is a group/frame that can be entered)
        final hasChildren = (widget.node['children'] as List?)?.isNotEmpty ?? false;

        return MouseRegion(
          onEnter: (_) => controller.setHovered(nodeId),
          onExit: (_) => controller.setHovered(null),
          cursor: isSelected ? SystemMouseCursors.move : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: () {
              controller.selectNode(widget.node);
            },
            // Double-click to enter group/frame
            onDoubleTap: hasChildren ? () {
              controller.enterGroup(widget.node);
            } : null,
            // Only enable drag when selected, otherwise let pan/zoom through
            onPanStart: isSelected ? (details) {
              _dragStart = details.localPosition;
              _originalPosition = Offset(props.x, props.y);
            } : null,
            onPanUpdate: isSelected ? (details) {
              if (_dragStart != null && _originalPosition != null) {
                final delta = details.localPosition - _dragStart!;
                final newX = _originalPosition!.dx + delta.dx / widget.scale;
                final newY = _originalPosition!.dy + delta.dy / widget.scale;
                controller.updateNodePosition(widget.node, newX, newY);
              }
            } : null,
            onPanEnd: isSelected ? (details) {
              _dragStart = null;
              _originalPosition = null;
            } : null,
            // Use deferToChild so pan/zoom can work on empty areas
            behavior: HitTestBehavior.deferToChild,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                widget.child,
                // Selection outline - Figma style
                if (isSelected || isHovered)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0D99FF) // Figma blue
                                : const Color(0x600D99FF),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Selection handles (corners and edges)
                if (isSelected) ..._buildSelectionHandles(props),
                // Type label on hover
                if (isHovered && !isSelected)
                  Positioned(
                    left: 0,
                    top: -18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D99FF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '${widget.node['type']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // Size label when selected
                if (isSelected)
                  Positioned(
                    left: 0,
                    bottom: -20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D99FF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '${props.width.toStringAsFixed(0)} × ${props.height.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSelectionHandles(FigmaNodeProperties props) {
    const handleSize = 8.0;
    const handleColor = Color(0xFF0D99FF);

    Widget buildHandle(Alignment alignment, MouseCursor cursor) {
      double? left, right, top, bottom;

      if (alignment.x == -1) left = -handleSize / 2;
      if (alignment.x == 1) right = -handleSize / 2;
      if (alignment.x == 0) left = (props.width * widget.scale - handleSize) / 2;

      if (alignment.y == -1) top = -handleSize / 2;
      if (alignment.y == 1) bottom = -handleSize / 2;
      if (alignment.y == 0) top = (props.height * widget.scale - handleSize) / 2;

      return Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: handleColor, width: 1),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    }

    return [
      // Corners
      buildHandle(Alignment.topLeft, SystemMouseCursors.resizeUpLeft),
      buildHandle(Alignment.topRight, SystemMouseCursors.resizeUpRight),
      buildHandle(Alignment.bottomLeft, SystemMouseCursors.resizeDownLeft),
      buildHandle(Alignment.bottomRight, SystemMouseCursors.resizeDownRight),
      // Edges
      buildHandle(Alignment.topCenter, SystemMouseCursors.resizeUp),
      buildHandle(Alignment.bottomCenter, SystemMouseCursors.resizeDown),
      buildHandle(Alignment.centerLeft, SystemMouseCursors.resizeLeft),
      buildHandle(Alignment.centerRight, SystemMouseCursors.resizeRight),
    ];
  }
}

/// Node inspector panel - shows selected node properties
class NodeInspectorPanel extends StatelessWidget {
  final Map<String, Map<String, dynamic>>? nodeMap;

  const NodeInspectorPanel({super.key, this.nodeMap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        final controller = DebugOverlayController.instance;
        if (!controller.enabled || controller.selectedNode == null) {
          return const SizedBox.shrink();
        }

        final props = controller.selectedProps!;
        final node = controller.selectedNode!;

        return Container(
          width: 320,
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            color: const Color(0xF5FFFFFF),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    // Navigation buttons
                    if (nodeMap != null) ...[
                      _NavButton(
                        icon: Icons.arrow_back,
                        enabled: controller.canGoBack,
                        onTap: () => controller.goBack(nodeMap!),
                      ),
                      const SizedBox(width: 4),
                      _NavButton(
                        icon: Icons.arrow_forward,
                        enabled: controller.canGoForward,
                        onTap: () => controller.goForward(nodeMap!),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            props.name ?? 'Unnamed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            props.type,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.clearSelection(),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Properties
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PropertySection(
                        title: 'Transform',
                        children: [
                          _PropertyRow('Position', '(${props.x.toStringAsFixed(1)}, ${props.y.toStringAsFixed(1)})'),
                          _PropertyRow('Size', '${props.width.toStringAsFixed(1)} x ${props.height.toStringAsFixed(1)}'),
                          if (props.rotation != 0)
                            _PropertyRow('Rotation', '${props.rotation.toStringAsFixed(1)}°'),
                        ],
                      ),
                      _PropertySection(
                        title: 'Appearance',
                        children: [
                          _PropertyRow('Opacity', '${(props.opacity * 100).toStringAsFixed(0)}%'),
                          _PropertyRow('Visible', props.visible ? 'Yes' : 'No'),
                          if (props.cornerRadius != null || props.cornerRadii != null)
                            _PropertyRow('Corner Radius', props.cornerRadii?.join(', ') ?? props.cornerRadius?.toStringAsFixed(1) ?? '0'),
                        ],
                      ),
                      if (props.fills.isNotEmpty)
                        _PropertySection(
                          title: 'Fills (${props.fills.length})',
                          children: props.fills.map((fill) {
                            return _FillRow(fill: fill);
                          }).toList(),
                        ),
                      if (props.strokes.isNotEmpty)
                        _PropertySection(
                          title: 'Strokes',
                          children: [
                            _PropertyRow('Weight', '${props.strokeWeight}'),
                            ...props.strokes.map((stroke) => _FillRow(fill: stroke)),
                          ],
                        ),
                      if (props.effects.isNotEmpty)
                        _PropertySection(
                          title: 'Effects (${props.effects.length})',
                          children: props.effects.map((effect) {
                            return _PropertyRow(effect['type']?.toString() ?? 'Unknown', '');
                          }).toList(),
                        ),
                      // Children info
                      if (node['children'] is List)
                        _PropertySection(
                          title: 'Children (${(node['children'] as List).length})',
                          children: [
                            ...(node['children'] as List).take(5).map((childKey) {
                              final child = nodeMap?[childKey.toString()];
                              if (child != null) {
                                return _ChildRow(
                                  name: child['name'] ?? 'Unnamed',
                                  type: child['type'] ?? 'UNKNOWN',
                                  onTap: () => controller.selectNode(child),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                            if ((node['children'] as List).length > 5)
                              Text(
                                '... and ${(node['children'] as List).length - 5} more',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      // Raw data toggle
                      _ExpandableRawData(node: node),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: enabled ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : const Color(0x66FFFFFF),
        ),
      ),
    );
  }
}

class _PropertySection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PropertySection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final String label;
  final String value;

  const _PropertyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FillRow extends StatelessWidget {
  final Map<String, dynamic> fill;

  const _FillRow({required this.fill});

  @override
  Widget build(BuildContext context) {
    final type = fill['type'] ?? 'UNKNOWN';
    final visible = fill['visible'] ?? true;
    final opacity = (fill['opacity'] as num?)?.toDouble() ?? 1.0;

    String info = type.toString();
    Color? previewColor;

    if (type == 'SOLID') {
      final color = fill['color'];
      if (color is Map) {
        final r = ((color['r'] as num?)?.toDouble() ?? 0) * 255;
        final g = ((color['g'] as num?)?.toDouble() ?? 0) * 255;
        final b = ((color['b'] as num?)?.toDouble() ?? 0) * 255;
        final a = (color['a'] as num?)?.toDouble() ?? 1.0;
        previewColor = Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), a);
        info = 'rgba(${r.toInt()}, ${g.toInt()}, ${b.toInt()}, ${a.toStringAsFixed(2)})';
      }
    } else if (type == 'IMAGE') {
      final imageRef = fill['image'];
      if (imageRef is Map && imageRef['hash'] is List) {
        final hash = imageHashToHex(imageRef['hash']);
        info = 'IMAGE: ${hash.substring(0, 8)}...';
      }
    } else if (type == 'GRADIENT_LINEAR' || type == 'GRADIENT_RADIAL') {
      info = type.toString().replaceAll('GRADIENT_', '');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (previewColor != null)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: previewColor,
                border: Border.all(color: const Color(0x33000000)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Text(
              info,
              style: TextStyle(
                fontSize: 11,
                color: visible ? Colors.black87 : Colors.grey,
                decoration: visible ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          if (opacity < 1.0)
            Text(
              '${(opacity * 100).toInt()}%',
              style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
            ),
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  final String name;
  final String type;
  final VoidCallback onTap;

  const _ChildRow({
    required this.name,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            const Icon(Icons.subdirectory_arrow_right, size: 14, color: Color(0xFF888888)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                type,
                style: const TextStyle(fontSize: 9, color: Color(0xFF1976D2)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 11, color: Color(0xFF2196F3)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableRawData extends StatefulWidget {
  final Map<String, dynamic> node;

  const _ExpandableRawData({required this.node});

  @override
  State<_ExpandableRawData> createState() => _ExpandableRawDataState();
}

class _ExpandableRawDataState extends State<_ExpandableRawData> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Raw Data (${widget.node.keys.length} keys)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.node.entries.take(30).map((entry) {
                String valueStr;
                if (entry.value is Map) {
                  valueStr = '{...}';
                } else if (entry.value is List) {
                  valueStr = '[${(entry.value as List).length} items]';
                } else {
                  valueStr = entry.value.toString();
                  if (valueStr.length > 50) {
                    valueStr = '${valueStr.substring(0, 50)}...';
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key}: ',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF666666),
                          fontFamily: 'monospace',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          valueStr,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// Debug toggle button for the canvas
class DebugToggleButton extends StatelessWidget {
  const DebugToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        final isEnabled = DebugOverlayController.instance.enabled;
        return Container(
          decoration: BoxDecoration(
            color: isEnabled ? const Color(0xFF2196F3) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => DebugOverlayController.instance.toggle(),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bug_report,
                      size: 20,
                      color: isEnabled ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Inspect',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isEnabled ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
