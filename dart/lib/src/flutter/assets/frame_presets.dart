/// Frame presets for common device sizes and layouts
///
/// Includes presets for:
/// - Phones (iPhone, Android)
/// - Tablets (iPad, Surface)
/// - Desktop (MacBook, Desktop)
/// - Social media sizes
/// - Print sizes

import 'package:flutter/material.dart';

/// Frame preset category
enum FramePresetCategory {
  phone,
  tablet,
  desktop,
  watch,
  social,
  print,
  presentation,
  custom,
}

/// Frame preset data
class FramePreset {
  /// Preset ID
  final String id;

  /// Display name
  final String name;

  /// Category
  final FramePresetCategory category;

  /// Width in pixels
  final double width;

  /// Height in pixels
  final double height;

  /// Optional description
  final String? description;

  /// Device pixel ratio (for rendering)
  final double devicePixelRatio;

  /// Whether this is a portrait orientation
  final bool isPortrait;

  const FramePreset({
    required this.id,
    required this.name,
    required this.category,
    required this.width,
    required this.height,
    this.description,
    this.devicePixelRatio = 1.0,
    this.isPortrait = true,
  });

  /// Get size
  Size get size => Size(width, height);

  /// Get landscape version
  FramePreset get landscape {
    if (!isPortrait) return this;
    return FramePreset(
      id: '${id}_landscape',
      name: '$name (Landscape)',
      category: category,
      width: height,
      height: width,
      description: description,
      devicePixelRatio: devicePixelRatio,
      isPortrait: false,
    );
  }

  /// Display dimensions string
  String get dimensionsString => '${width.toInt()} × ${height.toInt()}';
}

/// All frame presets organized by category
class FramePresets {
  FramePresets._();

  // ============== PHONES ==============

  /// iPhone presets
  static const List<FramePreset> iPhones = [
    FramePreset(
      id: 'iphone_16',
      name: 'iPhone 16',
      category: FramePresetCategory.phone,
      width: 393,
      height: 852,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_16_pro',
      name: 'iPhone 16 Pro',
      category: FramePresetCategory.phone,
      width: 402,
      height: 874,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_16_pro_max',
      name: 'iPhone 16 Pro Max',
      category: FramePresetCategory.phone,
      width: 440,
      height: 956,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_16_plus',
      name: 'iPhone 16 Plus',
      category: FramePresetCategory.phone,
      width: 430,
      height: 932,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_14_15_pro',
      name: 'iPhone 14 & 15 Pro',
      category: FramePresetCategory.phone,
      width: 393,
      height: 852,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_14_15_pro_max',
      name: 'iPhone 14 & 15 Pro Max',
      category: FramePresetCategory.phone,
      width: 430,
      height: 932,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_13_14',
      name: 'iPhone 13 & 14',
      category: FramePresetCategory.phone,
      width: 390,
      height: 844,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_14_plus',
      name: 'iPhone 14 Plus',
      category: FramePresetCategory.phone,
      width: 428,
      height: 926,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_13_mini',
      name: 'iPhone 13 mini',
      category: FramePresetCategory.phone,
      width: 375,
      height: 812,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'iphone_se',
      name: 'iPhone SE',
      category: FramePresetCategory.phone,
      width: 320,
      height: 568,
      devicePixelRatio: 2.0,
    ),
  ];

  /// Android presets
  static const List<FramePreset> androids = [
    FramePreset(
      id: 'android_compact',
      name: 'Android Compact',
      category: FramePresetCategory.phone,
      width: 412,
      height: 917,
      devicePixelRatio: 2.625,
    ),
    FramePreset(
      id: 'android_medium',
      name: 'Android Medium',
      category: FramePresetCategory.phone,
      width: 700,
      height: 840,
      devicePixelRatio: 2.0,
    ),
    FramePreset(
      id: 'pixel_7',
      name: 'Google Pixel 7',
      category: FramePresetCategory.phone,
      width: 412,
      height: 915,
      devicePixelRatio: 2.625,
    ),
    FramePreset(
      id: 'pixel_7_pro',
      name: 'Google Pixel 7 Pro',
      category: FramePresetCategory.phone,
      width: 412,
      height: 892,
      devicePixelRatio: 3.5,
    ),
    FramePreset(
      id: 'samsung_s23',
      name: 'Samsung Galaxy S23',
      category: FramePresetCategory.phone,
      width: 360,
      height: 780,
      devicePixelRatio: 3.0,
    ),
    FramePreset(
      id: 'samsung_s23_ultra',
      name: 'Samsung Galaxy S23 Ultra',
      category: FramePresetCategory.phone,
      width: 384,
      height: 824,
      devicePixelRatio: 3.0,
    ),
  ];

  // ============== TABLETS ==============

  /// iPad presets
  static const List<FramePreset> iPads = [
    FramePreset(
      id: 'ipad_mini',
      name: 'iPad mini 8.3"',
      category: FramePresetCategory.tablet,
      width: 744,
      height: 1133,
      devicePixelRatio: 2.0,
    ),
    FramePreset(
      id: 'ipad_pro_11',
      name: 'iPad Pro 11"',
      category: FramePresetCategory.tablet,
      width: 834,
      height: 1194,
      devicePixelRatio: 2.0,
    ),
    FramePreset(
      id: 'ipad_pro_12_9',
      name: 'iPad Pro 12.9"',
      category: FramePresetCategory.tablet,
      width: 1024,
      height: 1366,
      devicePixelRatio: 2.0,
    ),
    FramePreset(
      id: 'ipad_10th',
      name: 'iPad 10th Gen',
      category: FramePresetCategory.tablet,
      width: 820,
      height: 1180,
      devicePixelRatio: 2.0,
    ),
    FramePreset(
      id: 'ipad_air',
      name: 'iPad Air',
      category: FramePresetCategory.tablet,
      width: 820,
      height: 1180,
      devicePixelRatio: 2.0,
    ),
  ];

  /// Other tablets
  static const List<FramePreset> otherTablets = [
    FramePreset(
      id: 'surface_pro_8',
      name: 'Surface Pro 8',
      category: FramePresetCategory.tablet,
      width: 1440,
      height: 960,
      devicePixelRatio: 2.0,
      isPortrait: false,
    ),
    FramePreset(
      id: 'android_expanded',
      name: 'Android Expanded',
      category: FramePresetCategory.tablet,
      width: 1280,
      height: 800,
      devicePixelRatio: 2.0,
      isPortrait: false,
    ),
    FramePreset(
      id: 'samsung_tab_s8',
      name: 'Samsung Galaxy Tab S8',
      category: FramePresetCategory.tablet,
      width: 1600,
      height: 2560,
      devicePixelRatio: 2.0,
    ),
  ];

  // ============== DESKTOP ==============

  /// MacBook presets
  static const List<FramePreset> macBooks = [
    FramePreset(
      id: 'macbook_air',
      name: 'MacBook Air',
      category: FramePresetCategory.desktop,
      width: 1280,
      height: 832,
      devicePixelRatio: 2.0,
      isPortrait: false,
    ),
    FramePreset(
      id: 'macbook_pro_14',
      name: 'MacBook Pro 14"',
      category: FramePresetCategory.desktop,
      width: 1512,
      height: 982,
      devicePixelRatio: 2.0,
      isPortrait: false,
    ),
    FramePreset(
      id: 'macbook_pro_16',
      name: 'MacBook Pro 16"',
      category: FramePresetCategory.desktop,
      width: 1728,
      height: 1117,
      devicePixelRatio: 2.0,
      isPortrait: false,
    ),
  ];

  /// Desktop presets
  static const List<FramePreset> desktops = [
    FramePreset(
      id: 'desktop_1440',
      name: 'Desktop',
      category: FramePresetCategory.desktop,
      width: 1440,
      height: 1024,
      isPortrait: false,
    ),
    FramePreset(
      id: 'desktop_1920',
      name: 'Desktop HD',
      category: FramePresetCategory.desktop,
      width: 1920,
      height: 1080,
      isPortrait: false,
    ),
    FramePreset(
      id: 'wireframes',
      name: 'Wireframes',
      category: FramePresetCategory.desktop,
      width: 1440,
      height: 1024,
      isPortrait: false,
    ),
    FramePreset(
      id: 'imac_24',
      name: 'iMac 24"',
      category: FramePresetCategory.desktop,
      width: 2240,
      height: 1260,
      devicePixelRatio: 2.0,
      isPortrait: false,
    ),
  ];

  // ============== WATCHES ==============

  /// Apple Watch presets
  static const List<FramePreset> watches = [
    FramePreset(
      id: 'apple_watch_ultra',
      name: 'Apple Watch Ultra',
      category: FramePresetCategory.watch,
      width: 205,
      height: 251,
      devicePixelRatio: 2.0,
    ),
    FramePreset(
      id: 'apple_watch_45',
      name: 'Apple Watch 45mm',
      category: FramePresetCategory.watch,
      width: 198,
      height: 242,
      devicePixelRatio: 2.0,
    ),
    FramePreset(
      id: 'apple_watch_41',
      name: 'Apple Watch 41mm',
      category: FramePresetCategory.watch,
      width: 176,
      height: 215,
      devicePixelRatio: 2.0,
    ),
  ];

  // ============== SOCIAL MEDIA ==============

  /// Social media presets
  static const List<FramePreset> socialMedia = [
    FramePreset(
      id: 'instagram_post',
      name: 'Instagram Post',
      category: FramePresetCategory.social,
      width: 1080,
      height: 1080,
      description: 'Square post',
    ),
    FramePreset(
      id: 'instagram_story',
      name: 'Instagram Story',
      category: FramePresetCategory.social,
      width: 1080,
      height: 1920,
      description: '9:16 ratio',
    ),
    FramePreset(
      id: 'twitter_post',
      name: 'Twitter/X Post',
      category: FramePresetCategory.social,
      width: 1200,
      height: 675,
      description: '16:9 ratio',
      isPortrait: false,
    ),
    FramePreset(
      id: 'facebook_cover',
      name: 'Facebook Cover',
      category: FramePresetCategory.social,
      width: 820,
      height: 312,
      isPortrait: false,
    ),
    FramePreset(
      id: 'linkedin_banner',
      name: 'LinkedIn Banner',
      category: FramePresetCategory.social,
      width: 1584,
      height: 396,
      isPortrait: false,
    ),
    FramePreset(
      id: 'youtube_thumbnail',
      name: 'YouTube Thumbnail',
      category: FramePresetCategory.social,
      width: 1280,
      height: 720,
      isPortrait: false,
    ),
  ];

  // ============== PRESENTATION ==============

  /// Presentation presets
  static const List<FramePreset> presentations = [
    FramePreset(
      id: 'slide_16_9',
      name: 'Slide 16:9',
      category: FramePresetCategory.presentation,
      width: 1920,
      height: 1080,
      isPortrait: false,
    ),
    FramePreset(
      id: 'slide_4_3',
      name: 'Slide 4:3',
      category: FramePresetCategory.presentation,
      width: 1024,
      height: 768,
      isPortrait: false,
    ),
  ];

  // ============== PRINT ==============

  /// Print presets (at 72 DPI)
  static const List<FramePreset> print = [
    FramePreset(
      id: 'a4_portrait',
      name: 'A4 Portrait',
      category: FramePresetCategory.print,
      width: 595,
      height: 842,
      description: '210 × 297 mm',
    ),
    FramePreset(
      id: 'a4_landscape',
      name: 'A4 Landscape',
      category: FramePresetCategory.print,
      width: 842,
      height: 595,
      description: '297 × 210 mm',
      isPortrait: false,
    ),
    FramePreset(
      id: 'letter_portrait',
      name: 'Letter Portrait',
      category: FramePresetCategory.print,
      width: 612,
      height: 792,
      description: '8.5 × 11 in',
    ),
    FramePreset(
      id: 'business_card',
      name: 'Business Card',
      category: FramePresetCategory.print,
      width: 252,
      height: 144,
      description: '3.5 × 2 in',
      isPortrait: false,
    ),
  ];

  /// Get all presets
  static List<FramePreset> get all => [
        ...iPhones,
        ...androids,
        ...iPads,
        ...otherTablets,
        ...macBooks,
        ...desktops,
        ...watches,
        ...socialMedia,
        ...presentations,
        ...print,
      ];

  /// Get presets by category
  static List<FramePreset> byCategory(FramePresetCategory category) {
    return all.where((p) => p.category == category).toList();
  }

  /// Get phone presets
  static List<FramePreset> get phones => [...iPhones, ...androids];

  /// Get tablet presets
  static List<FramePreset> get tablets => [...iPads, ...otherTablets];

  /// Search presets
  static List<FramePreset> search(String query) {
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(lowerQuery) ||
            (p.description?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }
}

/// Frame preset picker widget
class FramePresetPicker extends StatefulWidget {
  /// Currently selected preset
  final FramePreset? selectedPreset;

  /// Callback when preset is selected
  final ValueChanged<FramePreset>? onPresetSelected;

  /// Callback when custom size is selected
  final void Function(double width, double height)? onCustomSize;

  /// Width of the picker
  final double width;

  const FramePresetPicker({
    super.key,
    this.selectedPreset,
    this.onPresetSelected,
    this.onCustomSize,
    this.width = 280,
  });

  @override
  State<FramePresetPicker> createState() => _FramePresetPickerState();
}

class _FramePresetPickerState extends State<FramePresetPicker> {
  String _searchQuery = '';
  FramePresetCategory? _selectedCategory;

  List<FramePreset> get _filteredPresets {
    List<FramePreset> presets;
    if (_selectedCategory != null) {
      presets = FramePresets.byCategory(_selectedCategory!);
    } else {
      presets = FramePresets.all;
    }

    if (_searchQuery.isNotEmpty) {
      presets = presets
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return presets;
  }

  Map<FramePresetCategory, List<FramePreset>> get _groupedPresets {
    final grouped = <FramePresetCategory, List<FramePreset>>{};
    for (final preset in _filteredPresets) {
      grouped.putIfAbsent(preset.category, () => []);
      grouped[preset.category]!.add(preset);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with category tabs
          _buildCategoryTabs(),

          // Search
          _buildSearch(),

          // Preset list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: _buildPresetList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _CategoryTab(
            label: 'All',
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          _CategoryTab(
            icon: Icons.phone_iphone,
            isSelected: _selectedCategory == FramePresetCategory.phone,
            onTap: () =>
                setState(() => _selectedCategory = FramePresetCategory.phone),
          ),
          _CategoryTab(
            icon: Icons.tablet_mac,
            isSelected: _selectedCategory == FramePresetCategory.tablet,
            onTap: () =>
                setState(() => _selectedCategory = FramePresetCategory.tablet),
          ),
          _CategoryTab(
            icon: Icons.desktop_mac,
            isSelected: _selectedCategory == FramePresetCategory.desktop,
            onTap: () =>
                setState(() => _selectedCategory = FramePresetCategory.desktop),
          ),
          _CategoryTab(
            icon: Icons.watch,
            isSelected: _selectedCategory == FramePresetCategory.watch,
            onTap: () =>
                setState(() => _selectedCategory = FramePresetCategory.watch),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: const InputDecoration(
          hintText: 'Search presets...',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: Icon(Icons.search, size: 16, color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildPresetList() {
    final grouped = _groupedPresets;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      children: [
        for (final entry in grouped.entries) ...[
          _buildCategorySection(entry.key, entry.value),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
    FramePresetCategory category,
    List<FramePreset> presets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _getCategoryName(category),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...presets.map((preset) => _PresetRow(
              preset: preset,
              isSelected: widget.selectedPreset?.id == preset.id,
              onTap: () => widget.onPresetSelected?.call(preset),
            )),
      ],
    );
  }

  String _getCategoryName(FramePresetCategory category) {
    switch (category) {
      case FramePresetCategory.phone:
        return 'Phone';
      case FramePresetCategory.tablet:
        return 'Tablet';
      case FramePresetCategory.desktop:
        return 'Desktop';
      case FramePresetCategory.watch:
        return 'Watch';
      case FramePresetCategory.social:
        return 'Social Media';
      case FramePresetCategory.presentation:
        return 'Presentation';
      case FramePresetCategory.print:
        return 'Print';
      case FramePresetCategory.custom:
        return 'Custom';
    }
  }
}

/// Category tab button
class _CategoryTab extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.white54,
                    fontSize: 10,
                  ),
                )
              : Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.blue : Colors.white54,
                ),
        ),
      ),
    );
  }
}

/// Preset row
class _PresetRow extends StatelessWidget {
  final FramePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetRow({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            if (isSelected)
              const Icon(Icons.check, size: 14, color: Colors.blue)
            else
              const SizedBox(width: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preset.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              preset.dimensionsString,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frame type selector (Section, Frame, Group)
enum FrameType {
  section,
  frame,
  group,
}

/// Frame type selector widget
class FrameTypeSelector extends StatelessWidget {
  final FrameType selectedType;
  final ValueChanged<FrameType> onTypeChanged;

  const FrameTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: FrameType.values.map((type) {
          final isSelected = selectedType == type;
          return GestureDetector(
            onTap: () => onTypeChanged(type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getTypeName(type),
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getTypeName(FrameType type) {
    switch (type) {
      case FrameType.section:
        return 'Section';
      case FrameType.frame:
        return 'Frame';
      case FrameType.group:
        return 'Group';
    }
  }
}
