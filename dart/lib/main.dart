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
import 'src/flutter/tiles/tiles.dart';

void main() {
  runApp(const FigmaViewerApp());
}

/// Quick access to test harness for debugging tile rendering
class TestHarnessRoute extends StatelessWidget {
  const TestHarnessRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const TileTestHarness();
  }
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

  // Tile-based rendering (enabled by default for large documents)
  bool _useTileRendering = true;

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

      // Debug: Print all top-level keys in the message to find style/variable data
      debugPrint('📋 MESSAGE TOP-LEVEL KEYS: ${message.keys.toList()}');

      // Examine blobs structure - user hinted that hex values should match
      final blobs = message['blobs'] as List? ?? [];
      debugPrint('📦 BLOBS count: ${blobs.length}');

      // Target asset keys from colorVar references
      final targetAssetKeys = [
        '44e3c4781fcc7aa4a3df3182f3234bb8bc3dc0d8', // From podcast cards
        '7bb6ad78796564b1d11f0db8b8a3521f32d53ec1',
        'd21936c5c10855ad0944c247f81f64b0b00d0269',
      ];

      if (blobs.isNotEmpty) {
        // Print first few blob structures to understand format
        for (var i = 0; i < blobs.length && i < 5; i++) {
          final blob = blobs[i];
          if (blob is Map) {
            debugPrint('📦 Blob $i keys: ${blob.keys.toList()}');
          }
        }

        // Search for matching asset keys
        for (final blob in blobs) {
          if (blob is Map) {
            final blobKey = blob['key']?.toString() ?? blob['hash']?.toString();
            if (blobKey != null && targetAssetKeys.contains(blobKey)) {
              debugPrint('🎯 FOUND BLOB WITH MATCHING KEY: $blobKey');
              debugPrint('   Full blob: $blob');
            }
          }
        }
      }

      // Search for library references in message
      debugPrint('📚 Looking for library data...');
      for (final key in ['sharedPluginData', 'libraryAssetMapping', 'libraries', 'librarySharedStyles']) {
        if (message.containsKey(key)) {
          final data = message[key];
          debugPrint('📚 Found $key: ${data.runtimeType}');
          if (data is Map && data.isNotEmpty) {
            debugPrint('   Keys: ${data.keys.take(5).toList()}...');
          } else if (data is List) {
            debugPrint('   Count: ${data.length}');
          }
        }
      }

      // Search for shared styles in nodes (fillStyleID, strokeStyleID)
      final nodeChanges = message['nodeChanges'] as List? ?? [];
      final styleNodes = <String, Map<String, dynamic>>{};

      for (final node in nodeChanges) {
        if (node is Map) {
          // Look for nodes with style info
          if (node['fillStyleID'] != null || node['strokeStyleID'] != null) {
            final guid = node['guid'];
            if (guid is Map) {
              final guidKey = '${guid['sessionID']}:${guid['localID']}';
              debugPrint('🎨 Node with style ID: $guidKey');
              debugPrint('   fillStyleID: ${node['fillStyleID']}');
              debugPrint('   name: ${node['name']}');
            }
          }

          // Collect STYLE type nodes
          final type = node['type']?.toString();
          if (type != null && type.contains('STYLE')) {
            final guid = node['guid'];
            if (guid is Map) {
              final guidKey = '${guid['sessionID']}:${guid['localID']}';
              styleNodes[guidKey] = node as Map<String, dynamic>;
            }
          }
        }
      }

      if (styleNodes.isNotEmpty) {
        debugPrint('🎨 Found ${styleNodes.length} STYLE nodes:');
        for (final entry in styleNodes.entries.take(10)) {
          debugPrint('   ${entry.key}: ${entry.value['name']} (${entry.value['type']})');
          final fills = entry.value['fillPaints'] as List?;
          if (fills != null && fills.isNotEmpty) {
            debugPrint('      fills: $fills');
          }
        }
      }

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
        // Integrated Figma canvas with optional tile rendering
        FigmaCanvasView(
          document: _document!,
          showPageSelector: true,
          showDebugInfo: true,
          useTileRenderer: _useTileRendering,
          onTileRendererChanged: (v) => setState(() => _useTileRendering = v),
        ),

        // Rendering mode toggle (top-left) - only show when NOT in tile mode (tile mode has its own controls)
        if (!_useTileRendering)
        Positioned(
          top: 16,
          left: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF444444)),
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle between rendering modes
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grid_view, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    const Text('Tile Rendering', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _useTileRendering,
                      onChanged: (v) => setState(() => _useTileRendering = v),
                      activeColor: const Color(0xFF0D99FF),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),

        // Test harness button (bottom left)
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton.small(
            heroTag: 'testHarness',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TileTestHarness()),
              );
            },
            backgroundColor: const Color(0xFF3C3C3C),
            child: const Icon(Icons.bug_report, size: 20),
          ),
        ),

        // Variables button in bottom toolbar
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'variables',
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

  /// Extract variables from Figma document by parsing nodeChanges
  VariableManager _extractVariablesFromDocument(FigmaDocument document, Map<String, dynamic> message) {
    final nodeChanges = message['nodeChanges'] as List? ?? [];

    // Extract VARIABLE_SET nodes (collections with modes)
    final variableSets = <String, Map<String, dynamic>>{};
    // Extract VARIABLE nodes (actual variables with values)
    final variableNodes = <String, Map<String, dynamic>>{};

    for (final node in nodeChanges) {
      if (node is! Map) continue;
      final type = node['type']?.toString();
      final guid = node['guid'];
      if (guid is! Map) continue;
      final guidKey = '${guid['sessionID']}:${guid['localID']}';

      if (type == 'VARIABLE_SET') {
        variableSets[guidKey] = node as Map<String, dynamic>;
      } else if (type == 'VARIABLE') {
        variableNodes[guidKey] = node as Map<String, dynamic>;
      }
    }

    debugPrint('📊 Found ${variableSets.length} VARIABLE_SET and ${variableNodes.length} VARIABLE nodes');

    if (variableSets.isEmpty && variableNodes.isEmpty) {
      debugPrint('No variables found in Figma file, using sample data');
      return _createSampleVariableManager();
    }

    // Parse collections from VARIABLE_SET nodes
    final collections = <String, VariableCollection>{};
    var collectionOrder = 1;

    for (final entry in variableSets.entries) {
      final guidKey = entry.key;
      final node = entry.value;
      final name = node['name']?.toString() ?? 'Collection';

      // Parse modes from variableSetModes
      final modesData = node['variableSetModes'];
      final modes = <VariableMode>[];

      if (modesData is Map && modesData['entries'] is List) {
        final entries = modesData['entries'] as List;
        for (var i = 0; i < entries.length; i++) {
          final modeEntry = entries[i];
          if (modeEntry is Map) {
            final modeId = modeEntry['modeID'];
            String modeIdKey = '';
            if (modeId is Map) {
              modeIdKey = '${modeId['sessionID']}:${modeId['localID']}';
            }
            final modeName = modeEntry['name']?.toString() ?? 'Mode ${i + 1}';
            modes.add(VariableMode(
              id: modeIdKey,
              name: modeName,
              index: i,
              emoji: _inferModeEmoji(modeName),
            ));
          }
        }
      }

      // Default modes if none found
      if (modes.isEmpty) {
        modes.add(const VariableMode(id: 'default', name: 'Default', index: 0));
      }

      collections[guidKey] = VariableCollection(
        id: guidKey,
        name: name,
        order: collectionOrder++,
        modes: modes,
        defaultModeId: modes.first.id,
      );

      debugPrint('  📁 Collection "$name" with ${modes.length} modes: ${modes.map((m) => m.name).join(', ')}');
    }

    // Parse variables from VARIABLE nodes
    final variables = <String, DesignVariable>{};

    for (final entry in variableNodes.entries) {
      final guidKey = entry.key;
      final node = entry.value;
      final name = node['name']?.toString() ?? 'Variable';

      // Determine variable type - get from first mode entry's dataType or resolvedDataType
      VariableType type = VariableType.string; // default
      final typeDataValues = node['variableDataValues'];
      if (typeDataValues is Map && typeDataValues['entries'] is List) {
        final entries = typeDataValues['entries'] as List;
        if (entries.isNotEmpty && entries.first is Map) {
          final firstEntry = entries.first as Map;
          final variableData = firstEntry['variableData'];
          if (variableData is Map) {
            final dataType = (variableData['resolvedDataType'] ?? variableData['dataType'])?.toString().toUpperCase();
            switch (dataType) {
              case 'COLOR':
                type = VariableType.color;
                break;
              case 'FLOAT':
                type = VariableType.number;
                break;
              case 'BOOLEAN':
                type = VariableType.boolean;
                break;
              case 'STRING':
              default:
                type = VariableType.string;
            }
          }
        }
      }

      // Find parent collection - handle nested guid structure: {guid: {sessionID, localID}}
      var collectionId = '';
      final variableSetID = node['variableSetID'] ?? node['variableCollectionID'];
      if (variableSetID is Map) {
        final guid = variableSetID['guid'];
        if (guid is Map) {
          collectionId = '${guid['sessionID']}:${guid['localID']}';
        } else {
          collectionId = '${variableSetID['sessionID']}:${variableSetID['localID']}';
        }
      }

      // Parse values by mode from variableDataValues
      final valuesByMode = <String, VariableValue<dynamic>>{};
      final dataValues = node['variableDataValues'];

      if (dataValues is Map && dataValues['entries'] is List) {
        final entries = dataValues['entries'] as List;
        for (final modeEntry in entries) {
          if (modeEntry is! Map) continue;

          final modeId = modeEntry['modeID'];
          String modeIdKey = '';
          if (modeId is Map) {
            modeIdKey = '${modeId['sessionID']}:${modeId['localID']}';
          }

          final variableData = modeEntry['variableData'];
          if (variableData is! Map) continue;

          final dataType = variableData['dataType']?.toString().toUpperCase();
          final valueData = variableData['value'];

          // Handle both string and enum int values for dataType
          if ((dataType == 'COLOR' || dataType == '1') && valueData is Map) {
            final colorValue = valueData['colorValue'];
            if (colorValue is Map) {
              final r = (colorValue['r'] as num?)?.toDouble() ?? 0;
              final g = (colorValue['g'] as num?)?.toDouble() ?? 0;
              final b = (colorValue['b'] as num?)?.toDouble() ?? 0;
              final a = (colorValue['a'] as num?)?.toDouble() ?? 1;
              valuesByMode[modeIdKey] = VariableValue(
                value: Color.fromRGBO(
                  (r * 255).round().clamp(0, 255),
                  (g * 255).round().clamp(0, 255),
                  (b * 255).round().clamp(0, 255),
                  a,
                ),
              );
            }
          } else if ((dataType == 'ALIAS' || dataType == '5') && valueData is Map) {
            final alias = valueData['alias'];
            if (alias is Map && alias['guid'] is Map) {
              final aliasGuid = alias['guid'] as Map;
              final aliasKey = '${aliasGuid['sessionID']}:${aliasGuid['localID']}';
              valuesByMode[modeIdKey] = VariableValue(
                value: null,
                resolveType: VariableResolveType.alias,
                aliasId: aliasKey,
              );
            }
          }
        }
      }

      // Parse scopes
      final scopesData = node['scopes'] as List?;
      final scopes = <VariableScope>[];
      if (scopesData != null) {
        for (final scope in scopesData) {
          if (scope == 'ALL_SCOPES') scopes.add(VariableScope.allScopes);
          else if (scope == 'ALL_FILLS') scopes.add(VariableScope.allFills);
          else if (scope == 'FRAME_FILL') scopes.add(VariableScope.frameFill);
          else if (scope == 'SHAPE_FILL') scopes.add(VariableScope.shapeFill);
          else if (scope == 'TEXT_FILL') scopes.add(VariableScope.textFill);
          else if (scope == 'STROKE_COLOR') scopes.add(VariableScope.strokeColor);
        }
      }
      if (scopes.isEmpty) scopes.add(VariableScope.allScopes);

      variables[guidKey] = DesignVariable(
        id: guidKey,
        name: name,
        type: type,
        collectionId: collectionId,
        valuesByMode: valuesByMode,
        scopes: scopes,
      );
    }

    debugPrint('📊 Parsed ${collections.length} collections and ${variables.length} variables');

    // Count by type
    final colorCount = variables.values.where((v) => v.type == VariableType.color).length;
    final numberCount = variables.values.where((v) => v.type == VariableType.number).length;
    final stringCount = variables.values.where((v) => v.type == VariableType.string).length;
    final boolCount = variables.values.where((v) => v.type == VariableType.boolean).length;
    debugPrint('  🎨 $colorCount color, 📐 $numberCount number, 📝 $stringCount string, ✓ $boolCount boolean');

    final resolver = VariableResolver(
      variables: variables,  // Include all variable types
      collections: collections,
    );

    return VariableManager(resolver);
  }

  /// Infer emoji from mode name
  String? _inferModeEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('light')) return '☀️';
    if (lower.contains('dark')) return '🌙';
    if (lower.contains('mobile')) return '📱';
    if (lower.contains('desktop')) return '🖥️';
    if (lower.contains('tablet')) return '📱';
    if (lower.contains('default')) return '⭐';
    return null;
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
