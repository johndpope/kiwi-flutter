/// Variables Panel UI
///
/// Provides:
/// - Variables browser with search and filters
/// - Collection management
/// - Mode switching
/// - Variable creation and editing
/// - Property binding UI
/// - Canvas feedback indicators

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../assets/variables.dart';
import 'extended_collections.dart';

/// Variables panel widget
class VariablesPanel extends StatefulWidget {
  final VariableManager manager;
  final void Function(DesignVariable)? onVariableSelected;
  final void Function(String collectionId, String modeId)? onModeChanged;

  const VariablesPanel({
    super.key,
    required this.manager,
    this.onVariableSelected,
    this.onModeChanged,
  });

  @override
  State<VariablesPanel> createState() => _VariablesPanelState();
}

class _VariablesPanelState extends State<VariablesPanel> {
  String _searchQuery = '';
  VariableType? _typeFilter;
  String? _selectedCollectionId;
  bool _showCreateDialog = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildFilters(),
          Expanded(child: _buildVariablesList()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3C3C3C))),
      ),
      child: Row(
        children: [
          const Icon(Icons.data_object, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          const Text(
            'Variables',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _buildModeSelector(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            color: Colors.white70,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => setState(() => _showCreateDialog = true),
            tooltip: 'Create Variable',
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final collections = widget.manager.resolver.collections.values.toList();
    if (collections.isEmpty) return const SizedBox.shrink();

    final collection = _selectedCollectionId != null
        ? widget.manager.resolver.collections[_selectedCollectionId]
        : collections.first;

    if (collection == null || collection.modes.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentModeId = widget.manager.resolver.getModeId(collection.id);
    final currentMode = collection.getModeById(currentModeId);

    return PopupMenuButton<String>(
      initialValue: currentModeId,
      tooltip: 'Switch Mode',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF3C3C3C),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentMode?.name ?? 'Default',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
          ],
        ),
      ),
      onSelected: (modeId) {
        widget.manager.switchMode(collection.id, modeId);
        widget.onModeChanged?.call(collection.id, modeId);
      },
      itemBuilder: (context) => collection.modes.map((mode) {
        return PopupMenuItem(
          value: mode.id,
          child: Text(mode.name),
        );
      }).toList(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search variables...',
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF3C3C3C),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', _typeFilter == null, () {
              setState(() => _typeFilter = null);
            }),
            _buildFilterChip('Color', _typeFilter == VariableType.color, () {
              setState(() => _typeFilter = VariableType.color);
            }),
            _buildFilterChip('Number', _typeFilter == VariableType.number, () {
              setState(() => _typeFilter = VariableType.number);
            }),
            _buildFilterChip('String', _typeFilter == VariableType.string, () {
              setState(() => _typeFilter = VariableType.string);
            }),
            _buildFilterChip('Boolean', _typeFilter == VariableType.boolean, () {
              setState(() => _typeFilter = VariableType.boolean);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : const Color(0xFF3C3C3C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariablesList() {
    final variables = widget.manager.resolver.variables.values
        .where((v) {
          if (_typeFilter != null && v.type != _typeFilter) return false;
          if (_searchQuery.isNotEmpty &&
              !v.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
          if (_selectedCollectionId != null &&
              v.collectionId != _selectedCollectionId) {
            return false;
          }
          return true;
        })
        .toList();

    if (variables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.data_object, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(
              'No variables found',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Group by collection
    final grouped = <String, List<DesignVariable>>{};
    for (final v in variables) {
      grouped.putIfAbsent(v.collectionId, () => []).add(v);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final collectionId = grouped.keys.elementAt(index);
        final collectionVars = grouped[collectionId]!;
        final collection = widget.manager.resolver.collections[collectionId];

        return _buildCollectionSection(
          collection?.name ?? 'Unknown',
          collectionId,
          collectionVars,
        );
      },
    );
  }

  Widget _buildCollectionSection(
    String name,
    String collectionId,
    List<DesignVariable> variables,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedCollectionId =
                  _selectedCollectionId == collectionId ? null : collectionId;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _selectedCollectionId == collectionId
                      ? Icons.folder_open
                      : Icons.folder,
                  size: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${variables.length})',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        ...variables.map((v) => _buildVariableItem(v)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVariableItem(DesignVariable variable) {
    return GestureDetector(
      onTap: () => widget.onVariableSelected?.call(variable),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF3C3C3C),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            _buildVariableIcon(variable),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variable.name.split('/').last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variable.description != null)
                    Text(
                      variable.description!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _buildVariableValue(variable),
          ],
        ),
      ),
    );
  }

  Widget _buildVariableIcon(DesignVariable variable) {
    IconData icon;
    Color color;

    switch (variable.type) {
      case VariableType.color:
        icon = Icons.palette;
        color = Colors.pink;
        break;
      case VariableType.number:
        icon = Icons.numbers;
        color = Colors.blue;
        break;
      case VariableType.string:
        icon = Icons.text_fields;
        color = Colors.green;
        break;
      case VariableType.boolean:
        icon = Icons.toggle_on;
        color = Colors.orange;
        break;
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Widget _buildVariableValue(DesignVariable variable) {
    final value = widget.manager.resolver.resolve(variable.id);

    if (variable.type == VariableType.color && value is Color) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
      );
    }

    return Text(
      _formatValue(variable.type, value),
      style: TextStyle(color: Colors.grey[500], fontSize: 11),
    );
  }

  String _formatValue(VariableType type, dynamic value) {
    if (value == null) return '-';

    switch (type) {
      case VariableType.color:
        if (value is Color) {
          return '#${value.value.toRadixString(16).substring(2).toUpperCase()}';
        }
        return value.toString();
      case VariableType.number:
        return value.toString();
      case VariableType.string:
        return '"$value"';
      case VariableType.boolean:
        return value ? 'true' : 'false';
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF3C3C3C))),
      ),
      child: Row(
        children: [
          Text(
            '${widget.manager.resolver.variables.length} variables',
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.file_download, size: 16),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: _showImportDialog,
            tooltip: 'Import',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload, size: 16),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: _showExportDialog,
            tooltip: 'Export',
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    // TODO: Implement import dialog
  }

  void _showExportDialog() {
    // TODO: Implement export dialog
  }
}

/// Variable creation dialog
class CreateVariableDialog extends StatefulWidget {
  final VariableManager manager;
  final String? defaultCollectionId;
  final void Function(DesignVariable)? onCreated;

  const CreateVariableDialog({
    super.key,
    required this.manager,
    this.defaultCollectionId,
    this.onCreated,
  });

  @override
  State<CreateVariableDialog> createState() => _CreateVariableDialogState();
}

class _CreateVariableDialogState extends State<CreateVariableDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  VariableType _type = VariableType.color;
  String? _collectionId;
  Color _colorValue = Colors.blue;
  double _numberValue = 0;
  String _stringValue = '';
  bool _boolValue = false;

  @override
  void initState() {
    super.initState();
    _collectionId = widget.defaultCollectionId ??
        widget.manager.resolver.collections.keys.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: const Text(
        'Create Variable',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Name', _nameController),
            const SizedBox(height: 12),
            _buildTextField('Description', _descriptionController),
            const SizedBox(height: 12),
            _buildCollectionSelector(),
            const SizedBox(height: 12),
            _buildTypeSelector(),
            const SizedBox(height: 12),
            _buildValueInput(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createVariable,
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF3C3C3C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3C3C3C),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _collectionId,
              isExpanded: true,
              dropdownColor: const Color(0xFF3C3C3C),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: widget.manager.resolver.collections.values.map((c) {
                return DropdownMenuItem(value: c.id, child: Text(c.name));
              }).toList(),
              onChanged: (value) => setState(() => _collectionId = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
        const SizedBox(height: 4),
        SegmentedButton<VariableType>(
          segments: const [
            ButtonSegment(value: VariableType.color, label: Text('Color')),
            ButtonSegment(value: VariableType.number, label: Text('Number')),
            ButtonSegment(value: VariableType.string, label: Text('String')),
            ButtonSegment(value: VariableType.boolean, label: Text('Bool')),
          ],
          selected: {_type},
          onSelectionChanged: (set) => setState(() => _type = set.first),
        ),
      ],
    );
  }

  Widget _buildValueInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Value',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
        const SizedBox(height: 4),
        switch (_type) {
          VariableType.color => _buildColorInput(),
          VariableType.number => _buildNumberInput(),
          VariableType.string => _buildStringInput(),
          VariableType.boolean => _buildBoolInput(),
        },
      ],
    );
  }

  Widget _buildColorInput() {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            // TODO: Show color picker
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _colorValue,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '#RRGGBB',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF3C3C3C),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              if (value.startsWith('#') && value.length == 7) {
                try {
                  final color = Color(int.parse('FF${value.substring(1)}', radix: 16));
                  setState(() => _colorValue = color);
                } catch (_) {}
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput() {
    return TextField(
      style: const TextStyle(color: Colors.white, fontSize: 13),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF3C3C3C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        setState(() => _numberValue = double.tryParse(value) ?? 0);
      },
    );
  }

  Widget _buildStringInput() {
    return TextField(
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Enter value',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF3C3C3C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) => setState(() => _stringValue = value),
    );
  }

  Widget _buildBoolInput() {
    return SwitchListTile(
      value: _boolValue,
      onChanged: (value) => setState(() => _boolValue = value),
      title: Text(
        _boolValue ? 'True' : 'False',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _createVariable() {
    if (_nameController.text.isEmpty || _collectionId == null) return;

    final collection = widget.manager.resolver.collections[_collectionId!];
    if (collection == null) return;

    dynamic value;
    switch (_type) {
      case VariableType.color:
        value = _colorValue;
        break;
      case VariableType.number:
        value = _numberValue;
        break;
      case VariableType.string:
        value = _stringValue;
        break;
      case VariableType.boolean:
        value = _boolValue;
        break;
    }

    final valuesByMode = <String, dynamic>{};
    for (final mode in collection.modes) {
      valuesByMode[mode.id] = value;
    }

    final variable = widget.manager.createVariable(
      name: _nameController.text,
      type: _type,
      collectionId: _collectionId!,
      valuesByMode: valuesByMode,
    );

    widget.onCreated?.call(variable);
    Navigator.of(context).pop();
  }
}

/// Variable binding dropdown for properties panel
class VariableBindingDropdown extends StatelessWidget {
  final VariableResolver resolver;
  final VariableType type;
  final String? boundVariableId;
  final void Function(String?) onChanged;
  final List<VariableScope> scopes;

  const VariableBindingDropdown({
    super.key,
    required this.resolver,
    required this.type,
    this.boundVariableId,
    required this.onChanged,
    this.scopes = const [VariableScope.allScopes],
  });

  @override
  Widget build(BuildContext context) {
    final variables = resolver.variables.values
        .where((v) => v.type == type)
        .where((v) => v.scopes.any((s) => scopes.contains(s) || s == VariableScope.allScopes))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3C3C3C),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: boundVariableId,
          isExpanded: true,
          dropdownColor: const Color(0xFF3C3C3C),
          hint: const Text(
            'Select variable',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('None'),
            ),
            ...variables.map((v) {
              return DropdownMenuItem(
                value: v.id,
                child: Row(
                  children: [
                    _buildIcon(v.type),
                    const SizedBox(width: 8),
                    Text(v.name),
                  ],
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildIcon(VariableType type) {
    final color = switch (type) {
      VariableType.color => Colors.pink,
      VariableType.number => Colors.blue,
      VariableType.string => Colors.green,
      VariableType.boolean => Colors.orange,
    };

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Icon(Icons.data_object, size: 10, color: color),
    );
  }
}

/// Canvas indicator for variable-bound properties
class VariableBoundIndicator extends StatelessWidget {
  final DesignVariable variable;
  final Offset position;
  final bool showValue;

  const VariableBoundIndicator({
    super.key,
    required this.variable,
    required this.position,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              variable.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keyboard shortcuts for variables
class VariablesKeyboardShortcuts {
  /// Quick mode switch shortcut (Cmd+Opt+M on Mac, Ctrl+Alt+M on others)
  static const modeSwitchShortcut = SingleActivator(
    LogicalKeyboardKey.keyM,
    meta: true,
    alt: true,
  );

  /// Create variable shortcut (Cmd+Shift+V on Mac)
  static const createVariableShortcut = SingleActivator(
    LogicalKeyboardKey.keyV,
    meta: true,
    shift: true,
  );

  /// Show variables panel shortcut
  static const showPanelShortcut = SingleActivator(
    LogicalKeyboardKey.keyV,
    meta: true,
    alt: true,
  );
}

/// Mode preview selector (for prototype previews)
class ModePreviewSelector extends StatelessWidget {
  final VariableResolver resolver;
  final void Function(String collectionId, String modeId)? onModeChanged;

  const ModePreviewSelector({
    super.key,
    required this.resolver,
    this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final collections = resolver.collections.values.toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Mode',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...collections.map((c) => _buildCollectionModes(c)),
        ],
      ),
    );
  }

  Widget _buildCollectionModes(VariableCollection collection) {
    final currentModeId = resolver.getModeId(collection.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          collection.name,
          style: TextStyle(color: Colors.grey[500], fontSize: 10),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: collection.modes.map((mode) {
            final isSelected = mode.id == currentModeId;
            return GestureDetector(
              onTap: () => onModeChanged?.call(collection.id, mode.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : const Color(0xFF3C3C3C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  mode.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
