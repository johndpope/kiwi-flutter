import 'package:flutter/material.dart';
import 'src/flutter/assets/variables.dart';
import 'src/flutter/variables/variables_panel.dart';
import 'src/flutter/ui/floating_panel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Variables Panel Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const VariablesPanelDemo(),
    );
  }
}

class VariablesPanelDemo extends StatefulWidget {
  const VariablesPanelDemo({super.key});

  @override
  State<VariablesPanelDemo> createState() => _VariablesPanelDemoState();
}

class _VariablesPanelDemoState extends State<VariablesPanelDemo> {
  late VariableManager _manager;
  bool _showVariablesPanel = true;

  @override
  void initState() {
    super.initState();
    _manager = _createSampleManager();
  }

  VariableManager _createSampleManager() {
    // Create resolver first
    final resolver = VariableResolver(
      variables: {},
      collections: {},
    );
    final manager = VariableManager(resolver);

    // Create "Themes" collection with Light/Dark modes
    final themesCollection = VariableCollection(
      id: 'themes',
      name: 'Themes',
      order: 1,
      modes: const [
        VariableMode(id: 'light', name: 'Light', index: 0, emoji: '☀️'),
        VariableMode(id: 'dark', name: 'Dark', index: 1, emoji: '🌙'),
      ],
      defaultModeId: 'light',
    );
    manager.resolver.collections['themes'] = themesCollection;

    // Create "Responsive" collection
    final responsiveCollection = VariableCollection(
      id: 'responsive',
      name: 'Responsive',
      order: 2,
      modes: const [
        VariableMode(id: 'mobile', name: 'Mobile', index: 0, emoji: '📱'),
        VariableMode(id: 'desktop', name: 'Desktop', index: 1, emoji: '🖥️'),
      ],
      defaultModeId: 'mobile',
    );
    manager.resolver.collections['responsive'] = responsiveCollection;

    // Add sample variables to Themes collection
    // Boolean variable
    manager.createVariable(
      name: 'theme',
      type: VariableType.boolean,
      collectionId: 'themes',
      valuesByMode: {'light': false, 'dark': true},
    );

    manager.createVariable(
      name: 'dark-theme',
      type: VariableType.boolean,
      collectionId: 'themes',
      valuesByMode: {'light': false, 'dark': true},
    );

    // System color group
    manager.createVariable(
      name: 'system/red',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFFFF3B30),
        'dark': const Color(0xFFFF453A),
      },
    );

    manager.createVariable(
      name: 'system/orange',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFFFF9500),
        'dark': const Color(0xFFFF9F0A),
      },
    );

    manager.createVariable(
      name: 'system/yellow',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFFFFCC00),
        'dark': const Color(0xFFFFD60A),
      },
    );

    manager.createVariable(
      name: 'system/green',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFF34C759),
        'dark': const Color(0xFF30D158),
      },
    );

    manager.createVariable(
      name: 'system/blue',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFF007AFF),
        'dark': const Color(0xFF0A84FF),
      },
    );

    // Background color group
    manager.createVariable(
      name: 'bg/primary',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFFFFFFFF),
        'dark': const Color(0xFF000000),
      },
    );

    manager.createVariable(
      name: 'bg/secondary',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFFF2F2F7),
        'dark': const Color(0xFF1C1C1E),
      },
    );

    manager.createVariable(
      name: 'bg/tertiary',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFFE5E5EA),
        'dark': const Color(0xFF2C2C2E),
      },
    );

    // Text colors
    manager.createVariable(
      name: 'text/primary',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFF000000),
        'dark': const Color(0xFFFFFFFF),
      },
    );

    manager.createVariable(
      name: 'text/secondary',
      type: VariableType.color,
      collectionId: 'themes',
      valuesByMode: {
        'light': const Color(0xFF8E8E93),
        'dark': const Color(0xFF8E8E93),
      },
    );

    // Responsive variables
    manager.createVariable(
      name: 'spacing/base',
      type: VariableType.number,
      collectionId: 'responsive',
      valuesByMode: {'mobile': 8.0, 'desktop': 16.0},
    );

    manager.createVariable(
      name: 'spacing/large',
      type: VariableType.number,
      collectionId: 'responsive',
      valuesByMode: {'mobile': 16.0, 'desktop': 32.0},
    );

    manager.createVariable(
      name: 'radius/button',
      type: VariableType.number,
      collectionId: 'responsive',
      valuesByMode: {'mobile': 8.0, 'desktop': 12.0},
    );

    manager.createVariable(
      name: 'font/body',
      type: VariableType.string,
      collectionId: 'responsive',
      valuesByMode: {'mobile': 'SF Pro Text', 'desktop': 'SF Pro Display'},
    );

    return manager;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background canvas area
          Container(
            color: const Color(0xFF121212),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Canvas Area',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_showVariablesPanel)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showVariablesPanel = true),
                      icon: const Icon(Icons.data_object),
                      label: const Text('Show Variables Panel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D99FF),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Floating Variables Panel
          if (_showVariablesPanel)
            FloatingPanel(
              title: 'Local variables',
              initialPosition: const Offset(50, 50),
              initialSize: const Size(700, 500),
              minSize: const Size(500, 300),
              onClose: () => setState(() => _showVariablesPanel = false),
              child: VariablesPanelFull(
                manager: _manager,
                onVariableSelected: (variable) {
                  debugPrint('Selected: ${variable.name}');
                },
                onModeChanged: (collectionId, modeId) {
                  debugPrint('Mode changed: $collectionId -> $modeId');
                  setState(() {});
                },
                onClose: () => setState(() => _showVariablesPanel = false),
              ),
            ),
        ],
      ),
    );
  }
}
