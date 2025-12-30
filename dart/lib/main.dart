/// Figma Viewer - Main Entry Point
///
/// This app loads and renders a Figma .fig file using the kiwi_schema library.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'kiwi.dart';
import 'flutter_renderer.dart';
import 'src/flutter/assets/variables.dart';
import 'src/flutter/variables/variables_panel.dart';
import 'src/flutter/ui/floating_panel.dart';

void main() {
  runApp(const FigmaViewerApp());
}

class FigmaViewerApp extends StatelessWidget {
  const FigmaViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Figma Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const FigmaViewerPage(),
    );
  }
}

class FigmaViewerPage extends StatefulWidget {
  const FigmaViewerPage({super.key});

  @override
  State<FigmaViewerPage> createState() => _FigmaViewerPageState();
}

class _FigmaViewerPageState extends State<FigmaViewerPage> {
  FigmaDocument? _document;
  String? _error;
  bool _isLoading = false;
  String _statusMessage = '';
  bool _showVariablesPanel = false;
  VariableManager? _variableManager;

  @override
  void initState() {
    super.initState();
    _loadExampleFile();
  }

  Future<void> _loadExampleFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading from bundled assets...';
    });

    try {
      // Load from bundled assets
      final schemaData = await rootBundle.load('test/fixtures/figma_schema.bin');
      final messageData = await rootBundle.load('test/fixtures/figma_message.bin');

      final schemaBytes = schemaData.buffer.asUint8List();
      final messageBytes = messageData.buffer.asUint8List();

      // Decode
      final schema = decodeBinarySchema(schemaBytes);
      final compiled = compileSchema(schema);
      final message = compiled.decode('Message', messageBytes);

      // Create document
      final document = FigmaDocument.fromMessage(message);

      // Set images directory (for rendering images from the Figma file)
      final imagesDirPaths = [
        '/Users/johndpope/Downloads/Apple iOS UI Kit/images',
      ];
      for (final path in imagesDirPaths) {
        if (Directory(path).existsSync()) {
          document.imagesDirectory = path;
          break;
        }
      }

      // Initialize variable manager - try to extract real variables from Figma file
      _variableManager = _extractVariablesFromDocument(document, message);

      setState(() {
        _document = document;
        _isLoading = false;
        _statusMessage = 'Loaded ${document.nodeCount} nodes';
      });
    } catch (e, stack) {
      print('Error loading: $e\n$stack');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Figma Viewer')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                  _loadExampleFile();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Figma Viewer')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_statusMessage),
            ],
          ),
        ),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Figma Viewer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Figma Viewer',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage.isEmpty
                      ? 'No document loaded'
                      : _statusMessage,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Figma canvas
        FigmaCanvasView(
          document: _document!,
          showPageSelector: true,
          showDebugInfo: true,
        ),
        // Variables button in bottom toolbar
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => setState(() => _showVariablesPanel = !_showVariablesPanel),
            icon: const Icon(Icons.data_object),
            label: const Text('Variables'),
            backgroundColor: _showVariablesPanel
                ? const Color(0xFF0D99FF)
                : const Color(0xFF3C3C3C),
          ),
        ),
        // Floating Variables Panel
        if (_showVariablesPanel && _variableManager != null)
          FloatingPanel(
            title: 'Local variables',
            initialPosition: const Offset(50, 50),
            initialSize: const Size(700, 500),
            minSize: const Size(500, 300),
            onClose: () => setState(() => _showVariablesPanel = false),
            child: VariablesPanelFull(
              manager: _variableManager!,
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
    );
  }

  /// Extract variables from Figma document, or create sample variables if none exist
  VariableManager _extractVariablesFromDocument(FigmaDocument document, Map<String, dynamic> message) {
    // Check if the message contains variable data
    final variableCollections = message['variableCollections'];
    final variables = message['variables'];

    final hasVariables = (variableCollections is Map && variableCollections.isNotEmpty) ||
                         (variables is Map && variables.isNotEmpty);

    if (hasVariables) {
      // Use real variables from the Figma file
      debugPrint('Found ${(variableCollections as Map?)?.length ?? 0} variable collections and ${(variables as Map?)?.length ?? 0} variables in Figma file');

      final resolver = VariableResolver.fromDocument(message);

      debugPrint('Parsed ${resolver.collections.length} collections and ${resolver.variables.length} variables');
      for (final collection in resolver.collections.values) {
        debugPrint('  Collection: ${collection.name} with ${collection.modes.length} modes');
      }

      return VariableManager(resolver);
    } else {
      // No variables in file - create sample data for demo purposes
      debugPrint('No variables found in Figma file, using sample data');
      return _createSampleVariableManager();
    }
  }

  /// Create sample variable manager for demo when no variables exist in file
  VariableManager _createSampleVariableManager() {
    final resolver = VariableResolver(variables: {}, collections: {});
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

    // iOS System colors
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

    // Background colors
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

    return manager;
  }
}
