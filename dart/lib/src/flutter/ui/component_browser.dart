/// Component browser for viewing and using design components
///
/// Features:
/// - Component library with search
/// - Component variants and properties
/// - Drag-to-insert components
/// - Component thumbnails

import 'package:flutter/material.dart';

/// Component category
class ComponentCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<String> componentIds;

  const ComponentCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.componentIds = const [],
  });
}

/// Component variant property
class VariantProperty {
  final String name;
  final String value;

  const VariantProperty({
    required this.name,
    required this.value,
  });
}

/// Component data
class ComponentData {
  /// Component node ID
  final String id;

  /// Component name
  final String name;

  /// Component description
  final String? description;

  /// Parent component set ID (for variants)
  final String? componentSetId;

  /// Variant properties (if this is a variant)
  final List<VariantProperty> variantProperties;

  /// Component thumbnail (base64 or URL)
  final String? thumbnail;

  /// Component bounds for preview
  final Size size;

  /// Whether this is a published component
  final bool isPublished;

  /// Component key for linking
  final String? key;

  const ComponentData({
    required this.id,
    required this.name,
    this.description,
    this.componentSetId,
    this.variantProperties = const [],
    this.thumbnail,
    this.size = const Size(100, 100),
    this.isPublished = false,
    this.key,
  });

  /// Create from Figma node map
  factory ComponentData.fromNode(Map<String, dynamic> node) {
    final id = node['_guidKey']?.toString() ?? '';
    final name = node['name'] as String? ?? 'Component';
    final size = node['size'] as Map<String, dynamic>?;
    final derivedConfig = node['derivedSymbolData'] as Map<String, dynamic>?;

    // Parse variant properties from name (e.g., "Button, Size=Large, State=Hover")
    final variantProps = <VariantProperty>[];
    if (name.contains('=')) {
      final parts = name.split(', ');
      for (final part in parts) {
        if (part.contains('=')) {
          final keyValue = part.split('=');
          if (keyValue.length == 2) {
            variantProps.add(VariantProperty(
              name: keyValue[0].trim(),
              value: keyValue[1].trim(),
            ));
          }
        }
      }
    }

    return ComponentData(
      id: id,
      name: name.split(',').first.trim(),
      description: derivedConfig?['description'] as String?,
      componentSetId: derivedConfig?['componentSetId']?.toString(),
      variantProperties: variantProps,
      size: Size(
        (size?['x'] as num?)?.toDouble() ?? 100,
        (size?['y'] as num?)?.toDouble() ?? 100,
      ),
      key: derivedConfig?['componentKey']?.toString(),
    );
  }

  /// Check if this is a variant
  bool get isVariant => componentSetId != null;

  /// Get display name (without variant properties)
  String get displayName {
    if (variantProperties.isEmpty) return name;
    return variantProperties.map((p) => p.value).join(', ');
  }
}

/// Component set data (contains multiple variants)
class ComponentSetData {
  /// Component set ID
  final String id;

  /// Set name
  final String name;

  /// Description
  final String? description;

  /// Available property names and their values
  final Map<String, List<String>> properties;

  /// Variant components in this set
  final List<ComponentData> variants;

  const ComponentSetData({
    required this.id,
    required this.name,
    this.description,
    this.properties = const {},
    this.variants = const [],
  });

  /// Create from node and its children
  factory ComponentSetData.fromNode(
    Map<String, dynamic> node,
    Map<String, Map<String, dynamic>> nodeMap,
  ) {
    final id = node['_guidKey']?.toString() ?? '';
    final name = node['name'] as String? ?? 'Component Set';

    // Collect variants
    final variants = <ComponentData>[];
    final properties = <String, Set<String>>{};

    final children = node['children'] as List<dynamic>? ?? [];
    for (final child in children) {
      final childNode = child as Map<String, dynamic>;
      final type = childNode['type'] as String?;
      if (type == 'COMPONENT') {
        final component = ComponentData.fromNode(childNode);
        variants.add(component);

        // Collect property values
        for (final prop in component.variantProperties) {
          properties.putIfAbsent(prop.name, () => <String>{});
          properties[prop.name]!.add(prop.value);
        }
      }
    }

    return ComponentSetData(
      id: id,
      name: name,
      variants: variants,
      properties: properties.map((k, v) => MapEntry(k, v.toList()..sort())),
    );
  }

  /// Find a variant matching the given properties
  ComponentData? findVariant(Map<String, String> propertyValues) {
    for (final variant in variants) {
      bool matches = true;
      for (final entry in propertyValues.entries) {
        final prop = variant.variantProperties
            .where((p) => p.name == entry.key)
            .firstOrNull;
        if (prop == null || prop.value != entry.value) {
          matches = false;
          break;
        }
      }
      if (matches) return variant;
    }
    return null;
  }
}

/// Component browser widget
class ComponentBrowser extends StatefulWidget {
  /// All components in the document
  final List<ComponentData> components;

  /// Component sets
  final List<ComponentSetData> componentSets;

  /// Categories for organizing components
  final List<ComponentCategory> categories;

  /// Callback when a component is selected
  final ValueChanged<ComponentData>? onSelect;

  /// Callback when a component is dragged to canvas
  final void Function(ComponentData component, Offset position)? onInsert;

  /// Panel width
  final double width;

  /// Whether to show search
  final bool showSearch;

  const ComponentBrowser({
    super.key,
    required this.components,
    this.componentSets = const [],
    this.categories = const [],
    this.onSelect,
    this.onInsert,
    this.width = 240,
    this.showSearch = true,
  });

  @override
  State<ComponentBrowser> createState() => _ComponentBrowserState();
}

class _ComponentBrowserState extends State<ComponentBrowser> {
  String _searchQuery = '';
  String? _selectedCategoryId;
  ComponentSetData? _expandedSet;

  List<ComponentData> get _filteredComponents {
    var result = widget.components;

    // Filter by category
    if (_selectedCategoryId != null) {
      final category = widget.categories
          .where((c) => c.id == _selectedCategoryId)
          .firstOrNull;
      if (category != null) {
        result = result.where((c) => category.componentIds.contains(c.id)).toList();
      }
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              (c.description?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          _buildHeader(),
          if (widget.showSearch) _buildSearchBar(),
          if (widget.categories.isNotEmpty) _buildCategories(),
          Expanded(
            child: _expandedSet != null
                ? _buildComponentSetDetail(_expandedSet!)
                : _buildComponentGrid(),
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
          if (_expandedSet != null) ...[
            GestureDetector(
              onTap: () => setState(() => _expandedSet = null),
              child: const Icon(Icons.arrow_back, size: 14, color: Colors.white54),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _expandedSet?.name ?? 'Components',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredComponents.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: const InputDecoration(
            hintText: 'Search components...',
            hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
            prefixIcon: Icon(Icons.search, size: 14, color: Colors.white38),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryChip(
            label: 'All',
            isSelected: _selectedCategoryId == null,
            onTap: () => setState(() => _selectedCategoryId = null),
          ),
          for (final category in widget.categories)
            _CategoryChip(
              label: category.name,
              icon: category.icon,
              isSelected: _selectedCategoryId == category.id,
              onTap: () => setState(() => _selectedCategoryId = category.id),
            ),
        ],
      ),
    );
  }

  Widget _buildComponentGrid() {
    final components = _filteredComponents;
    final sets = widget.componentSets
        .where((s) =>
            _searchQuery.isEmpty ||
            s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: sets.length + components.length,
      itemBuilder: (context, index) {
        if (index < sets.length) {
          return _ComponentSetCard(
            componentSet: sets[index],
            onTap: () => setState(() => _expandedSet = sets[index]),
          );
        }

        final component = components[index - sets.length];
        return _ComponentCard(
          component: component,
          onTap: () => widget.onSelect?.call(component),
          onDragEnd: (details) {
            widget.onInsert?.call(component, details.offset);
          },
        );
      },
    );
  }

  Widget _buildComponentSetDetail(ComponentSetData set) {
    return Column(
      children: [
        // Property selectors
        if (set.properties.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final entry in set.properties.entries)
                  _PropertySelector(
                    propertyName: entry.key,
                    values: entry.value,
                    selectedValue: entry.value.first,
                    onChanged: (value) {
                      // Find and select the matching variant
                    },
                  ),
              ],
            ),
          ),

        // Variants grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: set.variants.length,
            itemBuilder: (context, index) {
              final variant = set.variants[index];
              return _ComponentCard(
                component: variant,
                onTap: () => widget.onSelect?.call(variant),
                onDragEnd: (details) {
                  widget.onInsert?.call(variant, details.offset);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Category filter chip
class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 12,
                  color: isSelected ? Colors.blue : Colors.white54,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.blue : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Component card widget
class _ComponentCard extends StatelessWidget {
  final ComponentData component;
  final VoidCallback onTap;
  final void Function(DraggableDetails details) onDragEnd;

  const _ComponentCard({
    required this.component,
    required this.onTap,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<ComponentData>(
      data: component,
      onDragEnd: onDragEnd,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF3C3C3C),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue),
          ),
          child: Center(
            child: Icon(
              Icons.widgets_outlined,
              color: const Color(0xFF9747FF),
              size: 32,
            ),
          ),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              // Thumbnail area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: component.thumbnail != null
                      ? Image.network(
                          component.thumbnail!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),

              // Name
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  component.displayName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.widgets_outlined,
        color: const Color(0xFF9747FF).withValues(alpha: 0.5),
        size: 24,
      ),
    );
  }
}

/// Component set card
class _ComponentSetCard extends StatelessWidget {
  final ComponentSetData componentSet;
  final VoidCallback onTap;

  const _ComponentSetCard({
    required this.componentSet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF9747FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF9747FF).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 2x2 grid preview
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 8),
              child: GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (int i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9747FF)
                            .withValues(alpha: 0.2 + (i * 0.1)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),

            Text(
              componentSet.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${componentSet.variants.length} variants',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Property selector for component variants
class _PropertySelector extends StatelessWidget {
  final String propertyName;
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const _PropertySelector({
    required this.propertyName,
    required this.values,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              propertyName,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: const Color(0xFF3C3C3C),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  items: values
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(v),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extract components from a node map
List<ComponentData> extractComponents(
    Map<String, Map<String, dynamic>> nodeMap) {
  return nodeMap.entries
      .where((e) => e.value['type'] == 'COMPONENT')
      .map((e) => ComponentData.fromNode(e.value))
      .toList();
}

/// Extract component sets from a node map
List<ComponentSetData> extractComponentSets(
    Map<String, Map<String, dynamic>> nodeMap) {
  return nodeMap.entries
      .where((e) => e.value['type'] == 'COMPONENT_SET')
      .map((e) => ComponentSetData.fromNode(e.value, nodeMap))
      .toList();
}
