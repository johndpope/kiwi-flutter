/// Figma-style Assets Panel Implementation
///
/// Provides browsing, searching, and inserting reusable elements like
/// Components, Colors, Materials, Typography, etc. with category organization.

import 'package:flutter/material.dart';

/// Asset panel colors matching Figma's dark theme
class AssetsPanelColors {
  static const background = Color(0xFF2C2C2C);
  static const headerBackground = Color(0xFF383838);
  static const itemBackground = Color(0xFF1E1E1E);
  static const hoverBackground = Color(0xFF404040);
  static const selectedBackground = Color(0xFF0D99FF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const textMuted = Color(0xFF7A7A7A);
  static const dividerColor = Color(0xFF4A4A4A);
  static const searchBackground = Color(0xFF1E1E1E);
  static const searchBorder = Color(0xFF4A4A4A);
}

/// Asset category with emoji/icon and items
class AssetCategory {
  final String id;
  final String label;
  final String? emoji;
  final IconData? icon;
  final List<AssetItem> items;
  final List<AssetCategory>? subcategories;

  const AssetCategory({
    required this.id,
    required this.label,
    this.emoji,
    this.icon,
    this.items = const [],
    this.subcategories,
  });
}

/// Individual asset item
class AssetItem {
  final String id;
  final String name;
  final String? description;
  final String? thumbnailUrl;
  final IconData? icon;
  final AssetItemType type;
  final Map<String, dynamic>? metadata;

  const AssetItem({
    required this.id,
    required this.name,
    this.description,
    this.thumbnailUrl,
    this.icon,
    required this.type,
    this.metadata,
  });
}

/// Asset item types for the panel
enum AssetItemType {
  component,
  color,
  textStyle,
  effect,
  grid,
  image,
}

/// Default asset categories matching Figma's organization
class DefaultAssetCategories {
  static List<AssetCategory> get components => [
    const AssetCategory(
      id: 'components',
      label: 'Components',
      subcategories: [
        AssetCategory(
          id: 'a01_colors',
          label: 'A.01 Colors',
          emoji: '🎨',
        ),
        AssetCategory(
          id: 'a02_materials',
          label: 'A.02 Materials',
          emoji: '🧱',
        ),
        AssetCategory(
          id: 'a03_typography',
          label: 'A.03 Typography',
          emoji: '📝',
        ),
        AssetCategory(
          id: 'a04_system_experiences',
          label: 'A.04 System Experiences',
          emoji: '🖥️',
        ),
        AssetCategory(
          id: 'a05_navigation',
          label: 'A.05 Navigation',
          emoji: '🗺️',
        ),
        AssetCategory(
          id: 'a06_selection_inputs',
          label: 'A.06 Selection and Inputs',
          emoji: '📋',
        ),
        AssetCategory(
          id: 'a07_menus_actions',
          label: 'A.07 Menus and Actions',
          emoji: '🎛️',
        ),
        AssetCategory(
          id: 'a08_layout_organization',
          label: 'A.08 Layout and Organization',
          emoji: '📁',
        ),
        AssetCategory(
          id: 'a09_presentation',
          label: 'A.09 Presentation',
          emoji: '📊',
        ),
        AssetCategory(
          id: 'a10_bezels',
          label: 'A.10 Bezels',
          emoji: '📱',
        ),
        AssetCategory(
          id: 'a11_sizes',
          label: 'A.11 Sizes',
          emoji: '📐',
        ),
      ],
    ),
    const AssetCategory(
      id: 'internal',
      label: 'Internal',
      subcategories: [
        AssetCategory(
          id: 'c01_internal',
          label: 'C.01 Internal',
          emoji: '🔧',
        ),
        AssetCategory(
          id: 'c02_icons',
          label: 'C.02 Icons',
          emoji: '🙂',
        ),
        AssetCategory(
          id: 'c03_app_logos',
          label: 'C.03 App Logos',
          emoji: '✏️',
        ),
        AssetCategory(
          id: 'c04_thumbnail',
          label: 'C.04 Thumbnail',
          emoji: '🖼️',
        ),
      ],
    ),
  ];
}

/// Assets panel state
class AssetsPanelState extends ChangeNotifier {
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedItemId;
  bool _isExpanded = true;
  Set<String> _expandedCategories = {'components', 'internal'};

  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  String? get selectedItemId => _selectedItemId;
  bool get isExpanded => _isExpanded;
  Set<String> get expandedCategories => _expandedCategories;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectCategory(String? id) {
    _selectedCategoryId = id;
    notifyListeners();
  }

  void selectItem(String? id) {
    _selectedItemId = id;
    notifyListeners();
  }

  void toggleExpanded() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }

  void toggleCategoryExpanded(String categoryId) {
    if (_expandedCategories.contains(categoryId)) {
      _expandedCategories.remove(categoryId);
    } else {
      _expandedCategories.add(categoryId);
    }
    notifyListeners();
  }
}

/// Main Assets Panel Widget
class FigmaAssetsPanel extends StatefulWidget {
  final AssetsPanelState state;
  final List<AssetCategory> categories;
  final void Function(AssetItem)? onItemSelected;
  final void Function(AssetItem)? onItemInsert;
  final double width;

  const FigmaAssetsPanel({
    super.key,
    required this.state,
    this.categories = const [],
    this.onItemSelected,
    this.onItemInsert,
    this.width = 240,
  });

  @override
  State<FigmaAssetsPanel> createState() => _FigmaAssetsPanelState();
}

class _FigmaAssetsPanelState extends State<FigmaAssetsPanel> {
  late List<AssetCategory> _effectiveCategories;

  @override
  void initState() {
    super.initState();
    _effectiveCategories = widget.categories.isNotEmpty
        ? widget.categories
        : DefaultAssetCategories.components;
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
    return Container(
      width: widget.width,
      color: AssetsPanelColors.background,
      child: Column(
        children: [
          // Header with search
          _buildHeader(),
          // Category list
          Expanded(
            child: _buildCategoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AssetsPanelColors.headerBackground,
        border: Border(
          bottom: BorderSide(color: AssetsPanelColors.dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: AssetsPanelColors.searchBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AssetsPanelColors.searchBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.search, size: 14, color: AssetsPanelColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                      color: AssetsPanelColors.textPrimary,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search in this library',
                      hintStyle: TextStyle(color: AssetsPanelColors.textMuted, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: widget.state.setSearchQuery,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.tune, size: 14, color: AssetsPanelColors.textMuted),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    final filteredCategories = _filterCategories(_effectiveCategories);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        return _buildCategorySection(filteredCategories[index]);
      },
    );
  }

  List<AssetCategory> _filterCategories(List<AssetCategory> categories) {
    if (widget.state.searchQuery.isEmpty) {
      return categories;
    }

    final query = widget.state.searchQuery.toLowerCase();
    return categories.where((category) {
      if (category.label.toLowerCase().contains(query)) return true;
      if (category.subcategories != null) {
        return category.subcategories!.any(
          (sub) => sub.label.toLowerCase().contains(query),
        );
      }
      return category.items.any(
        (item) => item.name.toLowerCase().contains(query),
      );
    }).toList();
  }

  Widget _buildCategorySection(AssetCategory category) {
    final isExpanded = widget.state.expandedCategories.contains(category.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with divider
        _buildSectionHeader(category.label),
        // Subcategories or items
        if (isExpanded && category.subcategories != null)
          ...category.subcategories!.map(_buildSubcategoryItem),
        if (isExpanded && category.items.isNotEmpty)
          ...category.items.map(_buildAssetItem),
      ],
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AssetsPanelColors.dividerColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: AssetsPanelColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AssetsPanelColors.dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(AssetCategory subcategory) {
    final isSelected = widget.state.selectedCategoryId == subcategory.id;

    return _HoverableItem(
      isSelected: isSelected,
      onTap: () => widget.state.selectCategory(subcategory.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Emoji or icon
            if (subcategory.emoji != null)
              Text(
                subcategory.emoji!,
                style: const TextStyle(fontSize: 14),
              )
            else if (subcategory.icon != null)
              Icon(
                subcategory.icon,
                size: 14,
                color: AssetsPanelColors.textSecondary,
              ),
            const SizedBox(width: 10),
            // Label
            Expanded(
              child: Text(
                subcategory.label,
                style: TextStyle(
                  color: isSelected
                      ? AssetsPanelColors.textPrimary
                      : AssetsPanelColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            // Item count
            if (subcategory.items.isNotEmpty)
              Text(
                '${subcategory.items.length}',
                style: const TextStyle(
                  color: AssetsPanelColors.textMuted,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetItem(AssetItem item) {
    final isSelected = widget.state.selectedItemId == item.id;

    return _HoverableItem(
      isSelected: isSelected,
      onTap: () {
        widget.state.selectItem(item.id);
        widget.onItemSelected?.call(item);
      },
      onDoubleTap: () => widget.onItemInsert?.call(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // Thumbnail or icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AssetsPanelColors.itemBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: item.thumbnailUrl != null
                  ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                  : Icon(
                      item.icon ?? _getDefaultIcon(item.type),
                      size: 16,
                      color: AssetsPanelColors.textMuted,
                    ),
            ),
            const SizedBox(width: 10),
            // Name
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  color: isSelected
                      ? AssetsPanelColors.textPrimary
                      : AssetsPanelColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDefaultIcon(AssetItemType type) {
    switch (type) {
      case AssetItemType.component:
        return Icons.widgets_outlined;
      case AssetItemType.color:
        return Icons.palette_outlined;
      case AssetItemType.textStyle:
        return Icons.text_fields;
      case AssetItemType.effect:
        return Icons.auto_awesome;
      case AssetItemType.grid:
        return Icons.grid_4x4;
      case AssetItemType.image:
        return Icons.image_outlined;
    }
  }
}

/// Hoverable item with selection state
class _HoverableItem extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const _HoverableItem({
    required this.child,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  State<_HoverableItem> createState() => _HoverableItemState();
}

class _HoverableItemState extends State<_HoverableItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          color: widget.isSelected
              ? AssetsPanelColors.selectedBackground
              : (_isHovered ? AssetsPanelColors.hoverBackground : Colors.transparent),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Assets panel with tabs (File/Assets)
class FigmaAssetsPanelWithTabs extends StatefulWidget {
  final AssetsPanelState state;
  final List<AssetCategory> categories;
  final Widget? layersContent;
  final void Function(AssetItem)? onItemSelected;
  final void Function(AssetItem)? onItemInsert;
  final double width;

  const FigmaAssetsPanelWithTabs({
    super.key,
    required this.state,
    this.categories = const [],
    this.layersContent,
    this.onItemSelected,
    this.onItemInsert,
    this.width = 240,
  });

  @override
  State<FigmaAssetsPanelWithTabs> createState() => _FigmaAssetsPanelWithTabsState();
}

class _FigmaAssetsPanelWithTabsState extends State<FigmaAssetsPanelWithTabs> {
  int _selectedTab = 1; // 0 = File, 1 = Assets

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: AssetsPanelColors.background,
      child: Column(
        children: [
          // Tab header
          _buildTabHeader(),
          // Content based on selected tab
          Expanded(
            child: _selectedTab == 0
                ? widget.layersContent ?? const SizedBox()
                : FigmaAssetsPanel(
                    state: widget.state,
                    categories: widget.categories,
                    onItemSelected: widget.onItemSelected,
                    onItemInsert: widget.onItemInsert,
                    width: widget.width,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AssetsPanelColors.headerBackground,
        border: Border(
          bottom: BorderSide(color: AssetsPanelColors.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildTab('File', 0),
          _buildTab('Assets', 1),
          const Spacer(),
          // Library icon
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.menu_book_outlined,
              size: 18,
              color: AssetsPanelColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AssetsPanelColors.selectedBackground : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? AssetsPanelColors.textPrimary
                  : AssetsPanelColors.textMuted,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
