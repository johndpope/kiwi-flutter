/// Plugins panel UI for viewing and managing installed plugins
///
/// Displays:
/// - List of installed plugins with status
/// - Plugin details (name, description, permissions)
/// - Enable/disable toggle
/// - Run/stop buttons
/// - Install/uninstall actions

import 'package:flutter/material.dart';
import 'plugin_manifest.dart';
import 'plugin_manager.dart';

/// Figma-style colors for the plugins panel
class _Colors {
  static const bg1 = Color(0xFF1E1E1E);
  static const bg2 = Color(0xFF2C2C2C);
  static const bg3 = Color(0xFF383838);
  static const border = Color(0xFF444444);
  static const text1 = Color(0xFFFFFFFF);
  static const text2 = Color(0xFFB3B3B3);
  static const text3 = Color(0xFF7A7A7A);
  static const accent = Color(0xFF0D99FF);
  static const success = Color(0xFF14AE5C);
  static const warning = Color(0xFFFFCD29);
  static const error = Color(0xFFF24822);
}

/// Plugins panel widget
class PluginsPanel extends StatefulWidget {
  /// Width of the panel
  final double width;

  /// Callback when a plugin is run
  final void Function(InstalledPlugin plugin, String? command)? onRunPlugin;

  /// Callback when install is requested
  final VoidCallback? onInstallPlugin;

  const PluginsPanel({
    super.key,
    this.width = 300,
    this.onRunPlugin,
    this.onInstallPlugin,
  });

  @override
  State<PluginsPanel> createState() => _PluginsPanelState();
}

class _PluginsPanelState extends State<PluginsPanel> {
  final _manager = PluginManager.instance;
  InstalledPlugin? _selectedPlugin;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    setState(() {});
  }

  List<InstalledPlugin> get _filteredPlugins {
    var plugins = _manager.plugins;
    if (_searchQuery.isNotEmpty) {
      plugins = plugins.where((p) {
        final query = _searchQuery.toLowerCase();
        return p.manifest.name.toLowerCase().contains(query) ||
            p.manifest.id.toLowerCase().contains(query) ||
            (p.manifest.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return plugins;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: _Colors.bg2,
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: _filteredPlugins.isEmpty
                ? _buildEmptyState()
                : _buildPluginsList(),
          ),
          if (_selectedPlugin != null) _buildDetailsPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Colors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.extension, size: 18, color: _Colors.text1),
          const SizedBox(width: 8),
          const Text(
            'Plugins',
            style: TextStyle(
              color: _Colors.text1,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _buildIconButton(
            icon: Icons.add,
            tooltip: 'Install plugin',
            onTap: widget.onInstallPlugin,
          ),
          const SizedBox(width: 4),
          _buildIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onTap: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: _Colors.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Colors.border),
        ),
        child: TextField(
          style: const TextStyle(color: _Colors.text1, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Search plugins...',
            hintStyle: TextStyle(color: _Colors.text3, fontSize: 12),
            prefixIcon: Icon(Icons.search, size: 16, color: _Colors.text3),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.extension_off, size: 48, color: _Colors.text3),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty ? 'No plugins installed' : 'No plugins found',
            style: const TextStyle(color: _Colors.text3, fontSize: 12),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: widget.onInstallPlugin,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Install Plugin'),
              style: TextButton.styleFrom(
                foregroundColor: _Colors.accent,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPluginsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _filteredPlugins.length,
      itemBuilder: (context, index) {
        final plugin = _filteredPlugins[index];
        return _buildPluginItem(plugin);
      },
    );
  }

  Widget _buildPluginItem(InstalledPlugin plugin) {
    final isSelected = _selectedPlugin?.manifest.id == plugin.manifest.id;
    final isRunning = _manager.isRunning(plugin.manifest.id);

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPlugin = isSelected ? null : plugin;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? _Colors.bg3 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: _Colors.accent) : null,
        ),
        child: Row(
          children: [
            // Plugin icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _Colors.bg1,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                _getPluginIcon(plugin),
                size: 18,
                color: plugin.enabled ? _Colors.accent : _Colors.text3,
              ),
            ),
            const SizedBox(width: 8),

            // Plugin info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plugin.manifest.name,
                          style: TextStyle(
                            color: plugin.enabled ? _Colors.text1 : _Colors.text3,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRunning)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _Colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plugin.manifest.description ?? plugin.manifest.id,
                    style: const TextStyle(color: _Colors.text3, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            // Status and actions
            _buildStatusBadge(plugin),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(InstalledPlugin plugin) {
    Color color;
    String text;

    switch (plugin.status) {
      case PluginStatus.running:
        color = _Colors.success;
        text = 'Running';
        break;
      case PluginStatus.error:
        color = _Colors.error;
        text = 'Error';
        break;
      case PluginStatus.disabled:
        color = _Colors.text3;
        text = 'Disabled';
        break;
      default:
        if (!plugin.enabled) {
          color = _Colors.text3;
          text = 'Disabled';
        } else {
          return const SizedBox.shrink();
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final plugin = _selectedPlugin!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: _Colors.bg1,
        border: Border(top: BorderSide(color: _Colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  plugin.manifest.name,
                  style: const TextStyle(
                    color: _Colors.text1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onTap: () => setState(() => _selectedPlugin = null),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Version and ID
          Text(
            'v${plugin.manifest.version ?? '1.0.0'} | ${plugin.manifest.id}',
            style: const TextStyle(color: _Colors.text3, fontSize: 10),
          ),
          const SizedBox(height: 8),

          // Description
          if (plugin.manifest.description != null) ...[
            Text(
              plugin.manifest.description!,
              style: const TextStyle(color: _Colors.text2, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],

          // Permissions
          if (plugin.manifest.permissions?.isNotEmpty ?? false) ...[
            const Text(
              'Permissions',
              style: TextStyle(
                color: _Colors.text2,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: plugin.manifest.permissions!.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _Colors.bg3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p,
                    style: const TextStyle(color: _Colors.text2, fontSize: 9),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],

          // Network access warning
          if (plugin.manifest.requiresNetworkAccess) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _Colors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _Colors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi, size: 14, color: _Colors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Network access: ${plugin.manifest.networkAccess!.allowedDomains.join(", ")}',
                      style: const TextStyle(color: _Colors.warning, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Actions
          Row(
            children: [
              // Enable/Disable toggle
              Expanded(
                child: _buildActionButton(
                  icon: plugin.enabled ? Icons.visibility : Icons.visibility_off,
                  label: plugin.enabled ? 'Enabled' : 'Disabled',
                  color: plugin.enabled ? _Colors.success : _Colors.text3,
                  onTap: () => _manager.setEnabled(
                    plugin.manifest.id,
                    !plugin.enabled,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Run/Stop button
              Expanded(
                child: _manager.isRunning(plugin.manifest.id)
                    ? _buildActionButton(
                        icon: Icons.stop,
                        label: 'Stop',
                        color: _Colors.error,
                        onTap: () => _manager.stopPlugin(plugin.manifest.id),
                      )
                    : _buildActionButton(
                        icon: Icons.play_arrow,
                        label: 'Run',
                        color: _Colors.accent,
                        onTap: plugin.enabled
                            ? () => widget.onRunPlugin?.call(plugin, null)
                            : null,
                      ),
              ),
              const SizedBox(width: 8),

              // Uninstall button
              _buildIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Uninstall',
                color: _Colors.error,
                onTap: () => _showUninstallDialog(plugin),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _Colors.bg3,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 14,
            color: onTap != null ? (color ?? _Colors.text2) : _Colors.text3,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.15) : _Colors.bg3,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: onTap != null ? color.withOpacity(0.3) : _Colors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: onTap != null ? color : _Colors.text3,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? color : _Colors.text3,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPluginIcon(InstalledPlugin plugin) {
    final manifest = plugin.manifest;

    // Check for specific capabilities
    if (manifest.capabilities?.codegen ?? false) {
      return Icons.code;
    }
    if (manifest.capabilities?.inspect ?? false) {
      return Icons.search;
    }

    // Check for editor type
    if (manifest.editorType.contains(PluginEditorType.figjam)) {
      return Icons.sticky_note_2;
    }
    if (manifest.editorType.contains(PluginEditorType.dev)) {
      return Icons.developer_mode;
    }

    // Default
    return Icons.extension;
  }

  void _showUninstallDialog(InstalledPlugin plugin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _Colors.bg2,
        title: Text(
          'Uninstall ${plugin.manifest.name}?',
          style: const TextStyle(color: _Colors.text1, fontSize: 16),
        ),
        content: const Text(
          'This will remove the plugin and all its data.',
          style: TextStyle(color: _Colors.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _manager.uninstall(plugin.manifest.id);
              setState(() => _selectedPlugin = null);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: _Colors.error),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }
}

/// Plugin menu dialog for running plugins with commands
class PluginMenuDialog extends StatelessWidget {
  final InstalledPlugin plugin;
  final void Function(String? command, Map<String, dynamic>? parameters) onRun;

  const PluginMenuDialog({
    super.key,
    required this.plugin,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final menu = plugin.manifest.menu;

    if (menu == null || menu.isEmpty) {
      // No menu, just run
      return AlertDialog(
        backgroundColor: _Colors.bg2,
        title: Text(
          plugin.manifest.name,
          style: const TextStyle(color: _Colors.text1, fontSize: 16),
        ),
        content: const Text(
          'Run this plugin?',
          style: TextStyle(color: _Colors.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onRun(null, null);
              Navigator.of(context).pop();
            },
            child: const Text('Run'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: _Colors.bg2,
      title: Text(
        plugin.manifest.name,
        style: const TextStyle(color: _Colors.text1, fontSize: 16),
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: menu.map((item) => _buildMenuItem(context, item)).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, PluginMenuItem item) {
    if (item.separator) {
      return const Divider(color: _Colors.border, height: 16);
    }

    if (item.menu != null) {
      // Submenu
      return ExpansionTile(
        title: Text(
          item.name,
          style: const TextStyle(color: _Colors.text1, fontSize: 13),
        ),
        tilePadding: EdgeInsets.zero,
        children: item.menu!.map((sub) => _buildMenuItem(context, sub)).toList(),
      );
    }

    return ListTile(
      title: Text(
        item.name,
        style: const TextStyle(color: _Colors.text1, fontSize: 13),
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () {
        onRun(item.command, null);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Parameter input dialog
class PluginParameterDialog extends StatefulWidget {
  final InstalledPlugin plugin;
  final String? command;
  final List<PluginParameter> parameters;
  final void Function(Map<String, dynamic> values) onSubmit;

  const PluginParameterDialog({
    super.key,
    required this.plugin,
    this.command,
    required this.parameters,
    required this.onSubmit,
  });

  @override
  State<PluginParameterDialog> createState() => _PluginParameterDialogState();
}

class _PluginParameterDialogState extends State<PluginParameterDialog> {
  final Map<String, dynamic> _values = {};

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    for (final param in widget.parameters) {
      switch (param.type) {
        case ParameterType.boolean:
          _values[param.key] = false;
          break;
        case ParameterType.number:
          _values[param.key] = 0;
          break;
        case ParameterType.string:
          _values[param.key] = '';
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _Colors.bg2,
      title: Text(
        widget.command ?? widget.plugin.manifest.name,
        style: const TextStyle(color: _Colors.text1, fontSize: 16),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.parameters.map(_buildParameterInput).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Run'),
        ),
      ],
    );
  }

  Widget _buildParameterInput(PluginParameter param) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                param.name,
                style: const TextStyle(color: _Colors.text1, fontSize: 12),
              ),
              if (!param.optional)
                const Text(' *', style: TextStyle(color: _Colors.error)),
            ],
          ),
          if (param.description != null) ...[
            const SizedBox(height: 2),
            Text(
              param.description!,
              style: const TextStyle(color: _Colors.text3, fontSize: 10),
            ),
          ],
          const SizedBox(height: 4),
          _buildInputWidget(param),
        ],
      ),
    );
  }

  Widget _buildInputWidget(PluginParameter param) {
    switch (param.type) {
      case ParameterType.boolean:
        return Row(
          children: [
            Switch(
              value: _values[param.key] as bool? ?? false,
              onChanged: (v) => setState(() => _values[param.key] = v),
              activeColor: _Colors.accent,
            ),
          ],
        );

      case ParameterType.number:
        return TextField(
          style: const TextStyle(color: _Colors.text1, fontSize: 12),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: _Colors.bg1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _Colors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (v) => setState(() {
            _values[param.key] = double.tryParse(v) ?? 0;
          }),
        );

      case ParameterType.string:
        if (param.options != null) {
          return DropdownButtonFormField<String>(
            value: _values[param.key] as String?,
            dropdownColor: _Colors.bg2,
            decoration: InputDecoration(
              filled: true,
              fillColor: _Colors.bg1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _Colors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            items: param.options!.map((opt) {
              return DropdownMenuItem(
                value: opt.name,
                child: Text(
                  opt.name,
                  style: const TextStyle(color: _Colors.text1, fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _values[param.key] = v),
          );
        }
        return TextField(
          style: const TextStyle(color: _Colors.text1, fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: _Colors.bg1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _Colors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (v) => setState(() => _values[param.key] = v),
        );
    }
  }

  bool get _canSubmit {
    for (final param in widget.parameters) {
      if (!param.optional) {
        final value = _values[param.key];
        if (value == null) return false;
        if (value is String && value.isEmpty) return false;
      }
    }
    return true;
  }

  void _submit() {
    widget.onSubmit(_values);
    Navigator.of(context).pop();
  }
}
