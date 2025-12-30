/// Collections Sidebar for Variables Panel
///
/// Left sidebar with Collections and Groups lists matching Figma's design.

import 'package:flutter/material.dart';
import '../assets/variables.dart';

/// Colors for the sidebar - matching Figma's design
class SidebarColors {
  static const background = Color(0xFF2C2C2C);
  static const sectionHeader = Color(0xFFAAAAAA);
  static const itemText = Color(0xFFE5E5E5);
  static const itemCount = Color(0xFF8C8C8C);
  static const selectedBackground = Color(0xFF0D99FF);
  static const hoverBackground = Color(0xFF383838);
  static const divider = Color(0xFF383838);
  static const addButton = Color(0xFF8C8C8C);
  static const sectionDivider = Color(0xFF444444);
}

/// Collections sidebar widget
class CollectionsSidebar extends StatelessWidget {
  final List<VariableCollection> collections;
  final Map<String, int> collectionVariableCounts;
  final String? selectedCollectionId;
  final ValueChanged<String>? onCollectionSelected;
  final VoidCallback? onAddCollection;
  final List<VariableGroup> groups;
  final String? selectedGroupId;
  final ValueChanged<String?>? onGroupSelected;

  const CollectionsSidebar({
    super.key,
    required this.collections,
    required this.collectionVariableCounts,
    this.selectedCollectionId,
    this.onCollectionSelected,
    this.onAddCollection,
    this.groups = const [],
    this.selectedGroupId,
    this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: SidebarColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collections section
          _buildSectionHeader(
            'Collections',
            onAdd: onAddCollection,
          ),
          Expanded(
            flex: 2,
            child: _buildCollectionsList(),
          ),
          const Divider(color: SidebarColors.divider, height: 1),
          // Groups section
          _buildSectionHeader(
            'Groups',
            trailing: IconButton(
              icon: const Icon(Icons.sort, size: 14),
              color: SidebarColors.addButton,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () {}, // Sort/filter groups
              tooltip: 'Sort groups',
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildGroupsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onAdd, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SidebarColors.sectionHeader,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            trailing
          else if (onAdd != null)
            IconButton(
              icon: const Icon(Icons.add, size: 14),
              color: SidebarColors.addButton,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onAdd,
              tooltip: 'Add $title',
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionsList() {
    if (collections.isEmpty) {
      return Center(
        child: Text(
          'No collections',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        final count = collectionVariableCounts[collection.id] ?? 0;
        final isSelected = collection.id == selectedCollectionId;

        return _CollectionItem(
          collection: collection,
          count: count,
          isSelected: isSelected,
          onTap: () => onCollectionSelected?.call(collection.id),
        );
      },
    );
  }

  Widget _buildGroupsList() {
    // Always show "All" option first
    final allCount = collectionVariableCounts.values.fold<int>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        _GroupItem(
          name: 'All',
          count: allCount,
          isSelected: selectedGroupId == null,
          onTap: () => onGroupSelected?.call(null),
        ),
        ...groups.map((group) => _GroupItem(
              name: group.name,
              count: group.variableCount,
              isSelected: selectedGroupId == group.id,
              onTap: () => onGroupSelected?.call(group.id),
            )),
      ],
    );
  }
}

/// Collection list item
class _CollectionItem extends StatefulWidget {
  final VariableCollection collection;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CollectionItem({
    required this.collection,
    required this.count,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_CollectionItem> createState() => _CollectionItemState();
}

class _CollectionItemState extends State<_CollectionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? SidebarColors.selectedBackground
                : _isHovered
                    ? SidebarColors.hoverBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.collection.displayName,
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : SidebarColors.itemText,
                    fontSize: 12,
                    fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.count.toString(),
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : SidebarColors.itemCount,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Group list item
class _GroupItem extends StatefulWidget {
  final String name;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  const _GroupItem({
    required this.name,
    required this.count,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_GroupItem> createState() => _GroupItemState();
}

class _GroupItemState extends State<_GroupItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? SidebarColors.selectedBackground
                : _isHovered
                    ? SidebarColors.hoverBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : SidebarColors.itemText,
                    fontSize: 12,
                    fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.count.toString(),
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : SidebarColors.itemCount,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
