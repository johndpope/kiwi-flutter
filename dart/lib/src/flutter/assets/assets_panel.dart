/// Assets panel for browsing, searching, and using design assets
///
/// Features:
/// - Component browser with thumbnails
/// - Style browser (color, text, effect)
/// - Variable browser with mode switching
/// - Search and filtering
/// - Drag-to-insert components
/// - Favorites and recents

import 'package:flutter/material.dart';
import 'asset_data.dart';
import 'variables.dart';

/// Asset filter type
enum AssetFilter {
  all,
  components,
  styles,
  variables,
  images,
}

/// Asset library source
class AssetLibrary {
  /// Library ID
  final String id;

  /// Library name
  final String name;

  /// Whether this is the local file library
  final bool isLocal;

  /// Whether this library is enabled
  bool enabled;

  /// Components in this library
  final List<ComponentAsset> components;

  /// Component sets in this library
  final List<ComponentSetAsset> componentSets;

  /// Paint styles
  final List<PaintStyleAsset> paintStyles;

  /// Text styles
  final List<TextStyleAsset> textStyles;

  /// Effect styles
  final List<EffectStyleAsset> effectStyles;

  /// Images
  final List<ImageAsset> images;

  AssetLibrary({
    required this.id,
    required this.name,
    this.isLocal = false,
    this.enabled = true,
    this.components = const [],
    this.componentSets = const [],
    this.paintStyles = const [],
    this.textStyles = const [],
    this.effectStyles = const [],
    this.images = const [],
  });

  /// Get all assets
  List<AssetData> get allAssets => [
        ...components,
        ...componentSets,
        ...paintStyles,
        ...textStyles,
        ...effectStyles,
        ...images,
      ];

  /// Search assets
  List<AssetData> search(String query) {
    if (query.isEmpty) return allAssets;
    return allAssets.where((a) => a.matchesSearch(query)).toList();
  }

  /// Create from Figma document
  factory AssetLibrary.fromDocument(
    Map<String, Map<String, dynamic>> nodeMap, {
    String name = 'Local',
  }) {
    final components = <ComponentAsset>[];
    final componentSets = <ComponentSetAsset>[];
    final paintStyles = <PaintStyleAsset>[];
    final textStyles = <TextStyleAsset>[];
    final effectStyles = <EffectStyleAsset>[];
    final images = <ImageAsset>[];

    for (final entry in nodeMap.entries) {
      final node = entry.value;
      final type = node['type'] as String?;

      switch (type) {
        case 'COMPONENT':
          components.add(ComponentAsset.fromNode(node));
          break;
        case 'COMPONENT_SET':
          // Collect variants
          final variants = <ComponentAsset>[];
          final children = node['children'] as List<dynamic>? ?? [];
          for (final child in children) {
            final childNode = child as Map<String, dynamic>;
            if (childNode['type'] == 'COMPONENT') {
              variants.add(ComponentAsset.fromNode(childNode));
            }
          }
          componentSets.add(ComponentSetAsset.fromNode(node, variants));
          break;
      }
    }

    return AssetLibrary(
      id: 'local',
      name: name,
      isLocal: true,
      components: components,
      componentSets: componentSets,
      paintStyles: paintStyles,
      textStyles: textStyles,
      effectStyles: effectStyles,
      images: images,
    );
  }
}

/// Assets panel widget
class AssetsPanel extends StatefulWidget {
  /// Available asset libraries
  final List<AssetLibrary> libraries;

  /// Variable manager
  final VariableManager? variableManager;

  /// Callback when a component is selected
  final ValueChanged<ComponentAsset>? onComponentSelected;

  /// Callback when a component is dragged to canvas
  final void Function(ComponentAsset component, Offset position)? onComponentInsert;

  /// Callback when a style is applied
  final void Function(AssetData style)? onStyleApply;

  /// Panel width
  final double width;

  /// Favorite asset IDs
  final Set<String> favorites;

  /// Callback when favorites change
  final ValueChanged<Set<String>>? onFavoritesChanged;

  const AssetsPanel({
    super.key,
    required this.libraries,
    this.variableManager,
    this.onComponentSelected,
    this.onComponentInsert,
    this.onStyleApply,
    this.width = 240,
    this.favorites = const {},
    this.onFavoritesChanged,
  });

  @override
  State<AssetsPanel> createState() => _AssetsPanelState();
}

class _AssetsPanelState extends State<AssetsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  AssetFilter _filter = AssetFilter.all;
  String? _selectedLibraryId;
  final Set<String> _expandedSections = {};
  final List<String> _recentAssets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedLibraryId = widget.libraries.firstOrNull?.id;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  AssetLibrary? get _selectedLibrary {
    return widget.libraries
        .where((l) => l.id == _selectedLibraryId)
        .firstOrNull;
  }

  List<AssetData> get _filteredAssets {
    final library = _selectedLibrary;
    if (library == null) return [];

    List<AssetData> assets;
    switch (_filter) {
      case AssetFilter.all:
        assets = library.allAssets;
        break;
      case AssetFilter.components:
        assets = [...library.components, ...library.componentSets];
        break;
      case AssetFilter.styles:
        assets = [
          ...library.paintStyles,
          ...library.textStyles,
          ...library.effectStyles,
        ];
        break;
      case AssetFilter.variables:
        // Variables are handled separately
        assets = [];
        break;
      case AssetFilter.images:
        assets = library.images;
        break;
    }

    if (_searchQuery.isNotEmpty) {
      assets = assets.where((a) => a.matchesSearch(_searchQuery)).toList();
    }

    return assets;
  }

  void _toggleFavorite(String assetId) {
    final newFavorites = Set<String>.from(widget.favorites);
    if (newFavorites.contains(assetId)) {
      newFavorites.remove(assetId);
    } else {
      newFavorites.add(assetId);
    }
    widget.onFavoritesChanged?.call(newFavorites);
  }

  void _addToRecents(String assetId) {
    setState(() {
      _recentAssets.remove(assetId);
      _recentAssets.insert(0, assetId);
      if (_recentAssets.length > 10) {
        _recentAssets.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          // Header with tabs
          _buildHeader(),

          // Search bar
          _buildSearchBar(),

          // Library selector
          _buildLibrarySelector(),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildComponentsTab(),
                _buildStylesTab(),
                _buildVariablesTab(),
                _buildImagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: Colors.blue,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 10),
        tabs: const [
          Tab(icon: Icon(Icons.widgets_outlined, size: 16)),
          Tab(icon: Icon(Icons.palette_outlined, size: 16)),
          Tab(icon: Icon(Icons.data_object, size: 16)),
          Tab(icon: Icon(Icons.image_outlined, size: 16)),
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
            hintText: 'Search assets...',
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

  Widget _buildLibrarySelector() {
    if (widget.libraries.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLibraryId,
          isExpanded: true,
          isDense: true,
          dropdownColor: const Color(0xFF3C3C3C),
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: widget.libraries.map((lib) {
            return DropdownMenuItem(
              value: lib.id,
              child: Row(
                children: [
                  Icon(
                    lib.isLocal ? Icons.folder_outlined : Icons.cloud_outlined,
                    size: 14,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lib.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedLibraryId = value),
        ),
      ),
    );
  }

  Widget _buildComponentsTab() {
    final library = _selectedLibrary;
    if (library == null) {
      return const Center(
        child: Text('No library selected', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Favorites section
        if (widget.favorites.isNotEmpty) ...[
          _buildSection(
            'Favorites',
            library.components
                .where((c) => widget.favorites.contains(c.id))
                .toList(),
            icon: Icons.star,
          ),
          const SizedBox(height: 8),
        ],

        // Recent section
        if (_recentAssets.isNotEmpty) ...[
          _buildSection(
            'Recent',
            library.components
                .where((c) => _recentAssets.contains(c.id))
                .toList(),
            icon: Icons.history,
          ),
          const SizedBox(height: 8),
        ],

        // Component sets
        if (library.componentSets.isNotEmpty) ...[
          _buildComponentSetsSection(library.componentSets),
          const SizedBox(height: 8),
        ],

        // Individual components
        if (library.components
            .where((c) => c.componentSetId == null)
            .isNotEmpty)
          _buildSection(
            'Components',
            library.components.where((c) => c.componentSetId == null).toList(),
          ),
      ],
    );
  }

  Widget _buildSection(String title, List<dynamic> items, {IconData? icon}) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedSections.contains(title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(title);
              } else {
                _expandedSections.add(title);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.chevron_right,
                  size: 14,
                  color: Colors.white54,
                ),
                if (icon != null) ...[
                  Icon(icon, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is ComponentAsset) {
                return _ComponentCard(
                  component: item,
                  isFavorite: widget.favorites.contains(item.id),
                  onTap: () {
                    _addToRecents(item.id);
                    widget.onComponentSelected?.call(item);
                  },
                  onDoubleTap: () => _toggleFavorite(item.id),
                  onDragEnd: (details) {
                    widget.onComponentInsert?.call(item, details.offset);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildComponentSetsSection(List<ComponentSetAsset> sets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Component Sets',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...sets.map((set) => _ComponentSetCard(
              componentSet: set,
              variants: _selectedLibrary?.components
                      .where((c) => c.componentSetId == set.id)
                      .toList() ??
                  [],
              onVariantSelected: (variant) {
                _addToRecents(variant.id);
                widget.onComponentSelected?.call(variant);
              },
              onVariantInsert: widget.onComponentInsert,
            )),
      ],
    );
  }

  Widget _buildStylesTab() {
    final library = _selectedLibrary;
    if (library == null) {
      return const Center(
        child: Text('No library selected', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Color styles
        if (library.paintStyles.isNotEmpty) ...[
          _buildStyleSection(
            'Colors',
            library.paintStyles,
            Icons.palette_outlined,
          ),
          const SizedBox(height: 16),
        ],

        // Text styles
        if (library.textStyles.isNotEmpty) ...[
          _buildStyleSection(
            'Text',
            library.textStyles,
            Icons.text_fields,
          ),
          const SizedBox(height: 16),
        ],

        // Effect styles
        if (library.effectStyles.isNotEmpty)
          _buildStyleSection(
            'Effects',
            library.effectStyles,
            Icons.blur_on,
          ),
      ],
    );
  }

  Widget _buildStyleSection(
      String title, List<AssetData> styles, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${styles.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...styles.map((style) {
          if (style is PaintStyleAsset) {
            return _PaintStyleRow(
              style: style,
              onTap: () => widget.onStyleApply?.call(style),
            );
          } else if (style is TextStyleAsset) {
            return _TextStyleRow(
              style: style,
              onTap: () => widget.onStyleApply?.call(style),
            );
          } else if (style is EffectStyleAsset) {
            return _EffectStyleRow(
              style: style,
              onTap: () => widget.onStyleApply?.call(style),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildVariablesTab() {
    final manager = widget.variableManager;
    if (manager == null) {
      return const Center(
        child: Text('No variables', style: TextStyle(color: Colors.white54)),
      );
    }

    return _VariablesView(manager: manager);
  }

  Widget _buildImagesTab() {
    final library = _selectedLibrary;
    if (library == null || library.images.isEmpty) {
      return const Center(
        child: Text('No images', style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: library.images.length,
      itemBuilder: (context, index) {
        final image = library.images[index];
        return _ImageCard(image: image);
      },
    );
  }
}

/// Component card widget
class _ComponentCard extends StatelessWidget {
  final ComponentAsset component;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(DraggableDetails details) onDragEnd;

  const _ComponentCard({
    required this.component,
    required this.isFavorite,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<ComponentAsset>(
      data: component,
      onDragEnd: onDragEnd,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF3C3C3C),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue),
          ),
          child: Center(
            child: Icon(
              Icons.widgets_outlined,
              color: const Color(0xFF9747FF),
              size: 24,
            ),
          ),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.widgets_outlined,
                          color: const Color(0xFF9747FF).withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
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
              if (isFavorite)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.star,
                    size: 12,
                    color: Colors.amber.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Component set card with variants
class _ComponentSetCard extends StatefulWidget {
  final ComponentSetAsset componentSet;
  final List<ComponentAsset> variants;
  final ValueChanged<ComponentAsset> onVariantSelected;
  final void Function(ComponentAsset, Offset)? onVariantInsert;

  const _ComponentSetCard({
    required this.componentSet,
    required this.variants,
    required this.onVariantSelected,
    this.onVariantInsert,
  });

  @override
  State<_ComponentSetCard> createState() => _ComponentSetCardState();
}

class _ComponentSetCardState extends State<_ComponentSetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF9747FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.chevron_right,
                  size: 14,
                  color: const Color(0xFF9747FF),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.dashboard_outlined,
                  size: 14,
                  color: const Color(0xFF9747FF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.componentSet.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${widget.variants.length}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.variants.length,
              itemBuilder: (context, index) {
                final variant = widget.variants[index];
                return _ComponentCard(
                  component: variant,
                  isFavorite: false,
                  onTap: () => widget.onVariantSelected(variant),
                  onDoubleTap: () {},
                  onDragEnd: (details) {
                    widget.onVariantInsert?.call(variant, details.offset);
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Paint style row
class _PaintStyleRow extends StatelessWidget {
  final PaintStyleAsset style;
  final VoidCallback onTap;

  const _PaintStyleRow({
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: style.previewColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                style.name,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text style row
class _TextStyleRow extends StatelessWidget {
  final TextStyleAsset style;
  final VoidCallback onTap;

  const _TextStyleRow({
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  'Ag',
                  style: TextStyle(
                    fontFamily: style.fontFamily,
                    fontWeight: style.fontWeight,
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    style.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${style.fontFamily} ${style.fontSize.toInt()}',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Effect style row
class _EffectStyleRow extends StatelessWidget {
  final EffectStyleAsset style;
  final VoidCallback onTap;

  const _EffectStyleRow({
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: style.effects
                    .map((e) => e.toBoxShadow())
                    .whereType<BoxShadow>()
                    .toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                style.name,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Variables view
class _VariablesView extends StatelessWidget {
  final VariableManager manager;

  const _VariablesView({required this.manager});

  @override
  Widget build(BuildContext context) {
    final collections = manager.resolver.collections.values.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        final variables = manager.resolver.getVariablesInCollection(collection.id);

        return _CollectionSection(
          collection: collection,
          variables: variables,
          manager: manager,
        );
      },
    );
  }
}

/// Collection section
class _CollectionSection extends StatefulWidget {
  final VariableCollection collection;
  final List<DesignVariable> variables;
  final VariableManager manager;

  const _CollectionSection({
    required this.collection,
    required this.variables,
    required this.manager,
  });

  @override
  State<_CollectionSection> createState() => _CollectionSectionState();
}

class _CollectionSectionState extends State<_CollectionSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collection header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.chevron_right,
                  size: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.collection.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Mode switcher
                if (widget.collection.modes.length > 1)
                  _ModeSwitcher(
                    modes: widget.collection.modes,
                    currentModeId:
                        widget.manager.resolver.getModeId(widget.collection.id),
                    onModeChanged: (modeId) {
                      widget.manager.switchMode(widget.collection.id, modeId);
                    },
                  ),
              ],
            ),
          ),
        ),

        // Variables
        if (_expanded)
          ...widget.variables.map((variable) => _VariableRow(
                variable: variable,
                manager: widget.manager,
              )),

        const SizedBox(height: 8),
      ],
    );
  }
}

/// Mode switcher
class _ModeSwitcher extends StatelessWidget {
  final List<VariableMode> modes;
  final String currentModeId;
  final ValueChanged<String> onModeChanged;

  const _ModeSwitcher({
    required this.modes,
    required this.currentModeId,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: modes.map((mode) {
          final isSelected = mode.id == currentModeId;
          return GestureDetector(
            onTap: () => onModeChanged(mode.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  mode.name,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.white54,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Variable row
class _VariableRow extends StatelessWidget {
  final DesignVariable variable;
  final VariableManager manager;

  const _VariableRow({
    required this.variable,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Type icon
          Icon(
            _getIconForType(variable.type),
            size: 12,
            color: _getColorForType(variable.type),
          ),
          const SizedBox(width: 8),

          // Name
          Expanded(
            child: Text(
              variable.name,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Value preview
          _VariableValuePreview(
            variable: variable,
            manager: manager,
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(VariableType type) {
    switch (type) {
      case VariableType.color:
        return Icons.palette_outlined;
      case VariableType.number:
        return Icons.tag;
      case VariableType.string:
        return Icons.text_fields;
      case VariableType.boolean:
        return Icons.toggle_on_outlined;
    }
  }

  Color _getColorForType(VariableType type) {
    switch (type) {
      case VariableType.color:
        return Colors.pink;
      case VariableType.number:
        return Colors.orange;
      case VariableType.string:
        return Colors.green;
      case VariableType.boolean:
        return Colors.purple;
    }
  }
}

/// Variable value preview
class _VariableValuePreview extends StatelessWidget {
  final DesignVariable variable;
  final VariableManager manager;

  const _VariableValuePreview({
    required this.variable,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    switch (variable.type) {
      case VariableType.color:
        final color = manager.resolver.resolveColor(variable.id);
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color ?? Colors.grey,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24),
          ),
        );
      case VariableType.number:
        final number = manager.resolver.resolveNumber(variable.id);
        return Text(
          number?.toStringAsFixed(1) ?? '—',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        );
      case VariableType.string:
        final string = manager.resolver.resolveString(variable.id);
        return Text(
          string ?? '—',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        );
      case VariableType.boolean:
        final bool = manager.resolver.resolveBoolean(variable.id);
        return Icon(
          bool == true ? Icons.check_box : Icons.check_box_outline_blank,
          size: 14,
          color: Colors.white54,
        );
    }
  }
}

/// Image card
class _ImageCard extends StatelessWidget {
  final ImageAsset image;

  const _ImageCard({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white.withValues(alpha: 0.3),
          size: 24,
        ),
      ),
    );
  }
}
