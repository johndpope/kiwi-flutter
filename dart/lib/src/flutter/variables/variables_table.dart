/// Variables Table View
///
/// Table view with mode columns matching Figma's variables panel design.

import 'package:flutter/material.dart';
import '../assets/variables.dart';
import 'variable_icons.dart';
import 'inline_editors.dart';

/// Colors for the table
class TableColors {
  static const background = Color(0xFF2C2C2C);
  static const headerBackground = Color(0xFF252525);
  static const rowBackground = Color(0xFF2C2C2C);
  static const rowHover = Color(0xFF3C3C3C);
  static const rowSelected = Color(0xFF0D99FF);
  static const divider = Color(0xFF3C3C3C);
  static const headerText = Color(0xFFB3B3B3);
  static const cellText = Color(0xFFE5E5E5);
  static const groupHeader = Color(0xFF8C8C8C);
}

/// Variables table widget
class VariablesTable extends StatefulWidget {
  final List<DesignVariable> variables;
  final VariableCollection? collection;
  final VariableResolver resolver;
  final String? selectedVariableId;
  final ValueChanged<DesignVariable>? onVariableSelected;
  final void Function(DesignVariable, String modeId, dynamic value)? onValueChanged;
  final VoidCallback? onAddMode;
  final VoidCallback? onCreateVariable;

  const VariablesTable({
    super.key,
    required this.variables,
    required this.collection,
    required this.resolver,
    this.selectedVariableId,
    this.onVariableSelected,
    this.onValueChanged,
    this.onAddMode,
    this.onCreateVariable,
  });

  @override
  State<VariablesTable> createState() => _VariablesTableState();
}

class _VariablesTableState extends State<VariablesTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modes = widget.collection?.modes ?? [];
    final groupedVariables = _groupVariablesByPath(widget.variables);

    return Column(
      children: [
        // Table header
        _buildTableHeader(modes),
        const Divider(color: TableColors.divider, height: 1),
        // Table body
        Expanded(
          child: _buildTableBody(groupedVariables, modes),
        ),
        // Footer
        _buildFooter(),
      ],
    );
  }

  Widget _buildTableHeader(List<VariableMode> modes) {
    return Container(
      color: TableColors.headerBackground,
      child: Row(
        children: [
          // Name column header
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Text(
              'Name',
              style: TextStyle(
                color: TableColors.headerText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const VerticalDivider(
            color: TableColors.divider,
            width: 1,
            thickness: 1,
          ),
          // Mode column headers
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...modes.map((mode) => _buildModeColumnHeader(mode)),
                  // Add mode button
                  if (widget.onAddMode != null)
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      color: TableColors.headerText,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: widget.onAddMode,
                      tooltip: 'Add mode',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeColumnHeader(VariableMode mode) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (mode.emoji != null) ...[
            Text(
              mode.emoji!,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              mode.name,
              style: const TextStyle(
                color: TableColors.headerText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBody(
    Map<String?, List<DesignVariable>> groupedVariables,
    List<VariableMode> modes,
  ) {
    return ListView.builder(
      controller: _verticalController,
      itemCount: groupedVariables.length,
      itemBuilder: (context, index) {
        final groupName = groupedVariables.keys.elementAt(index);
        final groupVariables = groupedVariables[groupName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupName != null) _buildGroupHeader(groupName),
            ...groupVariables.map((v) => _buildVariableRow(v, modes)),
          ],
        );
      },
    );
  }

  Widget _buildGroupHeader(String groupName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        groupName,
        style: const TextStyle(
          color: TableColors.groupHeader,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVariableRow(DesignVariable variable, List<VariableMode> modes) {
    final isSelected = variable.id == widget.selectedVariableId;

    return _VariableRow(
      variable: variable,
      modes: modes,
      resolver: widget.resolver,
      isSelected: isSelected,
      onTap: () => widget.onVariableSelected?.call(variable),
      onValueChanged: widget.onValueChanged != null
          ? (modeId, value) => widget.onValueChanged!(variable, modeId, value)
          : null,
    );
  }

  Widget _buildFooter() {
    return GestureDetector(
      onTap: widget.onCreateVariable,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: TableColors.divider)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Create variable',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String?, List<DesignVariable>> _groupVariablesByPath(
    List<DesignVariable> variables,
  ) {
    final grouped = <String?, List<DesignVariable>>{};

    for (final variable in variables) {
      final groupName = VariableGroup.extractGroupFromPath(variable.name);
      grouped.putIfAbsent(groupName, () => []).add(variable);
    }

    // Sort groups: null (ungrouped) first, then alphabetically
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) return -1;
        if (b == null) return 1;
        return a.compareTo(b);
      });

    return {
      for (final key in sortedKeys) key: grouped[key]!,
    };
  }
}

/// Single variable row
class _VariableRow extends StatefulWidget {
  final DesignVariable variable;
  final List<VariableMode> modes;
  final VariableResolver resolver;
  final bool isSelected;
  final VoidCallback? onTap;
  final void Function(String modeId, dynamic value)? onValueChanged;

  const _VariableRow({
    required this.variable,
    required this.modes,
    required this.resolver,
    required this.isSelected,
    this.onTap,
    this.onValueChanged,
  });

  @override
  State<_VariableRow> createState() => _VariableRowState();
}

class _VariableRowState extends State<_VariableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: widget.isSelected
              ? TableColors.rowSelected.withValues(alpha: 0.3)
              : _isHovered
                  ? TableColors.rowHover
                  : TableColors.rowBackground,
          child: Row(
            children: [
              // Name cell
              _buildNameCell(),
              const VerticalDivider(
                color: TableColors.divider,
                width: 1,
                thickness: 1,
              ),
              // Value cells for each mode
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.modes
                        .map((mode) => _buildValueCell(mode))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameCell() {
    final displayName = widget.variable.name.split('/').last;
    final varValue = widget.variable.valuesByMode.values.firstOrNull;
    final isAlias = varValue?.isAlias ?? false;

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          VariableTypeIcon(
            type: widget.variable.type,
            size: 18,
            isAlias: isAlias,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                color: TableColors.cellText,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCell(VariableMode mode) {
    final varValue = widget.variable.valuesByMode[mode.id];
    final isAlias = varValue?.isAlias ?? false;

    dynamic resolvedValue;
    String? aliasTargetName;
    String? aliasEmoji;

    if (isAlias && varValue?.aliasId != null) {
      // Resolve alias - follow the chain to get the actual value
      resolvedValue = _resolveValueForMode(widget.variable.id, mode.id);
      final aliasTarget = widget.resolver.variables[varValue!.aliasId];
      if (aliasTarget != null) {
        aliasTargetName = aliasTarget.name.split('/').last;
        // Try to get mode emoji for alias display
        aliasEmoji = mode.emoji;
      }
    } else {
      // Direct value - just get from valuesByMode
      resolvedValue = varValue?.value;
    }

    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InlineVariableEditor(
        variable: widget.variable,
        value: resolvedValue,
        isAlias: isAlias,
        aliasTargetName: aliasTargetName,
        aliasEmoji: aliasEmoji,
        onValueChanged: widget.onValueChanged != null
            ? (value) => widget.onValueChanged!(mode.id, value)
            : null,
      ),
    );
  }

  /// Resolve value for a specific mode, following alias chains
  dynamic _resolveValueForMode(String variableId, String modeId, {int maxDepth = 10}) {
    if (maxDepth <= 0) return null;

    final variable = widget.resolver.variables[variableId];
    if (variable == null) return null;

    final varValue = variable.valuesByMode[modeId];
    if (varValue == null) return null;

    if (varValue.isAlias && varValue.aliasId != null) {
      return _resolveValueForMode(varValue.aliasId!, modeId, maxDepth: maxDepth - 1);
    }

    return varValue.value;
  }
}

/// Table header bar with collection name, search, and actions
class VariablesTableHeader extends StatefulWidget {
  final VariableCollection? collection;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onExpandPressed;
  final VoidCallback? onClosePressed;

  const VariablesTableHeader({
    super.key,
    this.collection,
    this.searchQuery = '',
    this.onSearchChanged,
    this.onSettingsPressed,
    this.onExpandPressed,
    this.onClosePressed,
  });

  @override
  State<VariablesTableHeader> createState() => VariablesTableHeaderState();
}

class VariablesTableHeaderState extends State<VariablesTableHeader> {
  late TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(VariablesTableHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged?.call('');
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: TableColors.headerBackground,
        border: Border(bottom: BorderSide(color: TableColors.divider)),
      ),
      child: Row(
        children: [
          // Collection name
          if (widget.collection != null)
            Text(
              widget.collection!.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          // Search field with Cmd+F shortcut hint
          SizedBox(
            width: 180,
            height: 28,
            child: Material(
              color: Colors.transparent,
              child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search ⌘F',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 14, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        color: Colors.white54,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        onPressed: _clearSearch,
                        tooltip: 'Clear search',
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF3C3C3C),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {}); // Trigger rebuild for clear button
                widget.onSearchChanged?.call(value);
              },
            ),
            ),
          ),
          const SizedBox(width: 8),
          // Settings button
          IconButton(
            icon: const Icon(Icons.tune, size: 16),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onSettingsPressed,
            tooltip: 'Settings',
          ),
          // Expand button
          IconButton(
            icon: const Icon(Icons.open_in_full, size: 14),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onExpandPressed,
            tooltip: 'Expand',
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onClosePressed,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// Focus the search field (call from parent via GlobalKey)
  void focusSearch() {
    _searchFocusNode.requestFocus();
  }
}
