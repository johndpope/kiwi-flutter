/// Asset data models for Figma-style design assets
///
/// Supports:
/// - Components and component sets (variants)
/// - Paint styles (fill, stroke)
/// - Text styles
/// - Effect styles
/// - Variables with modes
/// - Image assets

import 'package:flutter/material.dart';

/// Asset type enumeration
enum AssetType {
  component,
  componentSet,
  paintStyle,
  textStyle,
  effectStyle,
  gridStyle,
  variable,
  image,
}

/// Asset scope for publishing
enum AssetScope {
  local,
  file,
  team,
  public,
}

/// Base asset data class
abstract class AssetData {
  /// Unique asset ID
  final String id;

  /// Asset name
  final String name;

  /// Asset description
  final String? description;

  /// Asset type
  AssetType get type;

  /// Creation timestamp
  final DateTime? createdAt;

  /// Last modified timestamp
  final DateTime? modifiedAt;

  /// Asset key for library linking
  final String? key;

  /// Thumbnail data (base64 or path)
  final String? thumbnail;

  /// Tags for search
  final List<String> tags;

  /// Publishing scope
  final AssetScope scope;

  /// Version number
  final int version;

  const AssetData({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.modifiedAt,
    this.key,
    this.thumbnail,
    this.tags = const [],
    this.scope = AssetScope.local,
    this.version = 1,
  });

  /// Check if asset matches search query
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowerQuery) ||
        (description?.toLowerCase().contains(lowerQuery) ?? false) ||
        tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
  }
}

/// Component property definition
class ComponentProperty {
  /// Property ID
  final String id;

  /// Property name
  final String name;

  /// Property type
  final ComponentPropertyType type;

  /// Default value
  final dynamic defaultValue;

  /// Allowed values (for variant or instance swap)
  final List<dynamic>? allowedValues;

  /// Preferred values (for string properties)
  final List<String>? preferredValues;

  const ComponentProperty({
    required this.id,
    required this.name,
    required this.type,
    this.defaultValue,
    this.allowedValues,
    this.preferredValues,
  });

  /// Create from Figma property definition
  factory ComponentProperty.fromNode(Map<String, dynamic> prop) {
    final typeStr = prop['type'] as String? ?? 'TEXT';
    ComponentPropertyType type;
    switch (typeStr) {
      case 'BOOLEAN':
        type = ComponentPropertyType.boolean;
        break;
      case 'TEXT':
        type = ComponentPropertyType.text;
        break;
      case 'INSTANCE_SWAP':
        type = ComponentPropertyType.instanceSwap;
        break;
      case 'VARIANT':
        type = ComponentPropertyType.variant;
        break;
      default:
        type = ComponentPropertyType.text;
    }

    return ComponentProperty(
      id: prop['id']?.toString() ?? '',
      name: prop['name'] as String? ?? '',
      type: type,
      defaultValue: prop['defaultValue'],
      allowedValues: prop['variantOptions'] as List<dynamic>?,
      preferredValues: (prop['preferredValues'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
}

/// Component property types
enum ComponentPropertyType {
  boolean,
  text,
  instanceSwap,
  variant,
}

/// Component asset data
class ComponentAsset extends AssetData {
  @override
  AssetType get type => AssetType.component;

  /// Source node ID
  final String nodeId;

  /// Component set ID (if this is a variant)
  final String? componentSetId;

  /// Size of the component
  final Size size;

  /// Variant properties (name=value pairs)
  final Map<String, String> variantProperties;

  /// Exposed properties
  final List<ComponentProperty> properties;

  /// Whether this is a published component
  final bool isPublished;

  const ComponentAsset({
    required super.id,
    required super.name,
    required this.nodeId,
    this.componentSetId,
    required this.size,
    this.variantProperties = const {},
    this.properties = const [],
    this.isPublished = false,
    super.description,
    super.createdAt,
    super.modifiedAt,
    super.key,
    super.thumbnail,
    super.tags,
    super.scope,
    super.version,
  });

  /// Create from Figma node
  factory ComponentAsset.fromNode(Map<String, dynamic> node) {
    final id = node['_guidKey']?.toString() ?? '';
    final name = node['name'] as String? ?? 'Component';
    final sizeData = node['size'] as Map<String, dynamic>?;
    final derivedData = node['derivedSymbolData'] as Map<String, dynamic>?;

    // Parse variant properties from name
    final variantProps = <String, String>{};
    if (name.contains('=')) {
      final parts = name.split(', ');
      for (final part in parts) {
        if (part.contains('=')) {
          final kv = part.split('=');
          if (kv.length == 2) {
            variantProps[kv[0].trim()] = kv[1].trim();
          }
        }
      }
    }

    // Parse component properties
    final propDefs = derivedData?['componentPropertyDefinitions'] as Map<String, dynamic>?;
    final properties = <ComponentProperty>[];
    if (propDefs != null) {
      for (final entry in propDefs.entries) {
        final propData = entry.value as Map<String, dynamic>;
        propData['id'] = entry.key;
        properties.add(ComponentProperty.fromNode(propData));
      }
    }

    return ComponentAsset(
      id: id,
      name: variantProps.isEmpty ? name : name.split(',').first.trim(),
      nodeId: id,
      componentSetId: derivedData?['componentSetId']?.toString(),
      size: Size(
        (sizeData?['x'] as num?)?.toDouble() ?? 100,
        (sizeData?['y'] as num?)?.toDouble() ?? 100,
      ),
      variantProperties: variantProps,
      properties: properties,
      description: derivedData?['description'] as String?,
      key: derivedData?['componentKey']?.toString(),
    );
  }

  /// Get display name for variant
  String get displayName {
    if (variantProperties.isEmpty) return name;
    return variantProperties.values.join(', ');
  }

  /// Check if this is a variant
  bool get isVariant => componentSetId != null;
}

/// Component set asset (contains variants)
class ComponentSetAsset extends AssetData {
  @override
  AssetType get type => AssetType.componentSet;

  /// Source node ID
  final String nodeId;

  /// Variant property names and their possible values
  final Map<String, List<String>> variantAxes;

  /// Default variant ID
  final String? defaultVariantId;

  const ComponentSetAsset({
    required super.id,
    required super.name,
    required this.nodeId,
    this.variantAxes = const {},
    this.defaultVariantId,
    super.description,
    super.createdAt,
    super.modifiedAt,
    super.key,
    super.thumbnail,
    super.tags,
    super.scope,
    super.version,
  });

  /// Create from Figma node and its variants
  factory ComponentSetAsset.fromNode(
    Map<String, dynamic> node,
    List<ComponentAsset> variants,
  ) {
    final id = node['_guidKey']?.toString() ?? '';
    final name = node['name'] as String? ?? 'Component Set';

    // Collect variant axes
    final axes = <String, Set<String>>{};
    for (final variant in variants) {
      for (final entry in variant.variantProperties.entries) {
        axes.putIfAbsent(entry.key, () => <String>{});
        axes[entry.key]!.add(entry.value);
      }
    }

    return ComponentSetAsset(
      id: id,
      name: name,
      nodeId: id,
      variantAxes: axes.map((k, v) => MapEntry(k, v.toList()..sort())),
      defaultVariantId: variants.isNotEmpty ? variants.first.id : null,
    );
  }
}

/// Paint style type
enum PaintStyleType {
  solid,
  gradient,
  image,
}

/// Paint style asset
class PaintStyleAsset extends AssetData {
  @override
  AssetType get type => AssetType.paintStyle;

  /// Paint type
  final PaintStyleType paintType;

  /// Solid color (for solid type)
  final Color? color;

  /// Opacity
  final double opacity;

  /// Gradient data (for gradient type)
  final GradientStyleData? gradient;

  /// Image reference (for image type)
  final String? imageRef;

  const PaintStyleAsset({
    required super.id,
    required super.name,
    required this.paintType,
    this.color,
    this.opacity = 1.0,
    this.gradient,
    this.imageRef,
    super.description,
    super.createdAt,
    super.modifiedAt,
    super.key,
    super.thumbnail,
    super.tags,
    super.scope,
    super.version,
  });

  /// Create from Figma paint
  factory PaintStyleAsset.fromPaint(String id, String name, Map<String, dynamic> paint) {
    final typeStr = paint['type'] as String? ?? 'SOLID';
    PaintStyleType paintType;
    Color? color;
    GradientStyleData? gradient;

    switch (typeStr) {
      case 'SOLID':
        paintType = PaintStyleType.solid;
        final colorData = paint['color'] as Map<String, dynamic>?;
        if (colorData != null) {
          color = Color.fromRGBO(
            ((colorData['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((colorData['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            ((colorData['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
            (colorData['a'] as num?)?.toDouble() ?? 1.0,
          );
        }
        break;
      case 'GRADIENT_LINEAR':
      case 'GRADIENT_RADIAL':
      case 'GRADIENT_ANGULAR':
      case 'GRADIENT_DIAMOND':
        paintType = PaintStyleType.gradient;
        gradient = GradientStyleData.fromPaint(paint);
        break;
      case 'IMAGE':
        paintType = PaintStyleType.image;
        break;
      default:
        paintType = PaintStyleType.solid;
    }

    return PaintStyleAsset(
      id: id,
      name: name,
      paintType: paintType,
      color: color,
      opacity: (paint['opacity'] as num?)?.toDouble() ?? 1.0,
      gradient: gradient,
      imageRef: paint['imageRef'] as String?,
    );
  }

  /// Get a preview color for thumbnails
  Color get previewColor {
    if (color != null) return color!;
    if (gradient != null && gradient!.stops.isNotEmpty) {
      return gradient!.stops.first.color;
    }
    return Colors.grey;
  }
}

/// Gradient style data
class GradientStyleData {
  final String type;
  final List<GradientStopData> stops;
  final double angle;
  final Offset? center;

  const GradientStyleData({
    required this.type,
    required this.stops,
    this.angle = 0,
    this.center,
  });

  factory GradientStyleData.fromPaint(Map<String, dynamic> paint) {
    final type = paint['type'] as String? ?? 'GRADIENT_LINEAR';
    final stopsData = paint['gradientStops'] as List<dynamic>? ?? [];

    final stops = stopsData.map((s) {
      final stopMap = s as Map<String, dynamic>;
      final colorData = stopMap['color'] as Map<String, dynamic>?;
      return GradientStopData(
        position: (stopMap['position'] as num?)?.toDouble() ?? 0,
        color: colorData != null
            ? Color.fromRGBO(
                ((colorData['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                ((colorData['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                ((colorData['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
                (colorData['a'] as num?)?.toDouble() ?? 1.0,
              )
            : Colors.black,
      );
    }).toList();

    return GradientStyleData(
      type: type,
      stops: stops,
    );
  }

  /// Convert to Flutter Gradient
  Gradient toFlutterGradient() {
    final colors = stops.map((s) => s.color).toList();
    final positions = stops.map((s) => s.position).toList();

    switch (type) {
      case 'GRADIENT_RADIAL':
        return RadialGradient(colors: colors, stops: positions);
      case 'GRADIENT_LINEAR':
      default:
        return LinearGradient(colors: colors, stops: positions);
    }
  }
}

/// Gradient stop data
class GradientStopData {
  final double position;
  final Color color;

  const GradientStopData({
    required this.position,
    required this.color,
  });
}

/// Text style asset
class TextStyleAsset extends AssetData {
  @override
  AssetType get type => AssetType.textStyle;

  /// Font family
  final String fontFamily;

  /// Font size
  final double fontSize;

  /// Font weight
  final FontWeight fontWeight;

  /// Font style (normal, italic)
  final FontStyle fontStyle;

  /// Letter spacing
  final double? letterSpacing;

  /// Line height multiplier
  final double? lineHeight;

  /// Text decoration
  final TextDecoration? decoration;

  /// Text color (optional - may be separate style)
  final Color? color;

  const TextStyleAsset({
    required super.id,
    required super.name,
    required this.fontFamily,
    required this.fontSize,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
    this.letterSpacing,
    this.lineHeight,
    this.decoration,
    this.color,
    super.description,
    super.createdAt,
    super.modifiedAt,
    super.key,
    super.thumbnail,
    super.tags,
    super.scope,
    super.version,
  });

  /// Create from Figma text style
  factory TextStyleAsset.fromStyle(String id, String name, Map<String, dynamic> style) {
    final fontMeta = style['fontMetaData'] as Map<String, dynamic>?;
    final firstFont = fontMeta?.values.firstOrNull as Map<String, dynamic>?;

    return TextStyleAsset(
      id: id,
      name: name,
      fontFamily: firstFont?['fontFamily'] as String? ?? 'Roboto',
      fontSize: (style['fontSize'] as num?)?.toDouble() ?? 14,
      fontWeight: _parseFontWeight(firstFont?['fontWeight'] as num?),
      fontStyle: firstFont?['italic'] == true ? FontStyle.italic : FontStyle.normal,
      letterSpacing: (style['letterSpacing'] as num?)?.toDouble(),
      lineHeight: (style['lineHeight'] as num?)?.toDouble(),
    );
  }

  static FontWeight _parseFontWeight(num? weight) {
    if (weight == null) return FontWeight.normal;
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

  /// Convert to Flutter TextStyle
  TextStyle toFlutterTextStyle() {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: lineHeight,
      decoration: decoration,
      color: color,
    );
  }
}

/// Effect type
enum EffectStyleType {
  dropShadow,
  innerShadow,
  layerBlur,
  backgroundBlur,
}

/// Effect style asset
class EffectStyleAsset extends AssetData {
  @override
  AssetType get type => AssetType.effectStyle;

  /// Effects in this style
  final List<EffectStyleData> effects;

  const EffectStyleAsset({
    required super.id,
    required super.name,
    required this.effects,
    super.description,
    super.createdAt,
    super.modifiedAt,
    super.key,
    super.thumbnail,
    super.tags,
    super.scope,
    super.version,
  });

  /// Create from Figma effects
  factory EffectStyleAsset.fromEffects(
    String id,
    String name,
    List<Map<String, dynamic>> effects,
  ) {
    return EffectStyleAsset(
      id: id,
      name: name,
      effects: effects.map((e) => EffectStyleData.fromEffect(e)).toList(),
    );
  }
}

/// Effect data within a style
class EffectStyleData {
  final EffectStyleType type;
  final Color color;
  final double radius;
  final Offset offset;
  final double spread;
  final bool visible;

  const EffectStyleData({
    required this.type,
    this.color = Colors.black,
    this.radius = 4,
    this.offset = Offset.zero,
    this.spread = 0,
    this.visible = true,
  });

  factory EffectStyleData.fromEffect(Map<String, dynamic> effect) {
    final typeStr = effect['type'] as String? ?? 'DROP_SHADOW';
    EffectStyleType type;
    switch (typeStr) {
      case 'INNER_SHADOW':
        type = EffectStyleType.innerShadow;
        break;
      case 'LAYER_BLUR':
        type = EffectStyleType.layerBlur;
        break;
      case 'BACKGROUND_BLUR':
        type = EffectStyleType.backgroundBlur;
        break;
      default:
        type = EffectStyleType.dropShadow;
    }

    final colorData = effect['color'] as Map<String, dynamic>?;

    return EffectStyleData(
      type: type,
      color: colorData != null
          ? Color.fromRGBO(
              ((colorData['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((colorData['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              ((colorData['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
              (colorData['a'] as num?)?.toDouble() ?? 0.25,
            )
          : Colors.black26,
      radius: (effect['radius'] as num?)?.toDouble() ?? 4,
      offset: Offset(
        (effect['offset']?['x'] as num?)?.toDouble() ?? 0,
        (effect['offset']?['y'] as num?)?.toDouble() ?? 4,
      ),
      spread: (effect['spread'] as num?)?.toDouble() ?? 0,
      visible: effect['visible'] as bool? ?? true,
    );
  }

  /// Convert to Flutter BoxShadow (for drop shadows)
  BoxShadow? toBoxShadow() {
    if (type != EffectStyleType.dropShadow &&
        type != EffectStyleType.innerShadow) {
      return null;
    }
    return BoxShadow(
      color: color,
      blurRadius: radius,
      offset: offset,
      spreadRadius: spread,
    );
  }
}

/// Image asset data
class ImageAsset extends AssetData {
  @override
  AssetType get type => AssetType.image;

  /// Image hash/ref for blob lookup
  final String imageRef;

  /// Image format (png, jpg, svg)
  final String format;

  /// Original dimensions
  final Size? originalSize;

  /// File path (if loaded from disk)
  final String? filePath;

  /// Base64 encoded data (for embedded images)
  final String? base64Data;

  const ImageAsset({
    required super.id,
    required super.name,
    required this.imageRef,
    required this.format,
    this.originalSize,
    this.filePath,
    this.base64Data,
    super.description,
    super.createdAt,
    super.modifiedAt,
    super.key,
    super.thumbnail,
    super.tags,
    super.scope,
    super.version,
  });

  /// Create from Figma image paint
  factory ImageAsset.fromImagePaint(String imageRef, Map<String, dynamic> paint) {
    return ImageAsset(
      id: imageRef,
      name: 'Image',
      imageRef: imageRef,
      format: 'png',
    );
  }

  /// Check if image data is available
  bool get hasData => base64Data != null || filePath != null;
}
