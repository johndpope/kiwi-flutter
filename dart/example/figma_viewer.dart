/// Figma Viewer Example
///
/// This example demonstrates how to load and render a Figma .fig file
/// using the kiwi_schema library.
///
/// Note: This example requires external decompression libraries for
/// ZSTD and DEFLATE support. On desktop, you can use dart:io's zlib.
/// For ZSTD, you'll need a native library binding.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  runApp(const FigmaViewerApp());
}

class FigmaViewerApp extends StatelessWidget {
  const FigmaViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Figma Viewer',
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

  @override
  void initState() {
    super.initState();
    _loadExampleFile();
  }

  Future<void> _loadExampleFile() async {
    // Try to load the Apple iOS UI Kit from the fixtures
    final paths = [
      // Check from example directory
      '${Directory.current.path}/test/fixtures/figma_message.bin',
      // Check from dart directory
      'test/fixtures/figma_message.bin',
      // Check parent directories
      '${Directory.current.path}/../test/fixtures/figma_message.bin',
    ];

    print('Current directory: ${Directory.current.path}');
    for (final path in paths) {
      print('Trying path: $path');
      final file = File(path);
      if (await file.exists()) {
        print('Found file at: $path');
        await _loadPreDecompressedMessage(file);
        return;
      }
    }

    setState(() {
      _statusMessage = 'No Figma file found.\n'
          'Run: python3 /tmp/decompress_fig.py /path/to/canvas.fig test/fixtures\n'
          'to create test fixtures.';
    });
  }

  Future<void> _loadPreDecompressedMessage(File messageFile) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading pre-decompressed message...';
    });

    try {
      // Find schema file
      final schemaPaths = [
        'test/fixtures/figma_schema.bin',
        '${Directory.current.path}/test/fixtures/figma_schema.bin',
        '${Directory.current.path}/../test/fixtures/figma_schema.bin',
      ];

      File? schemaFile;
      for (final path in schemaPaths) {
        final file = File(path);
        if (file.existsSync()) {
          schemaFile = file;
          break;
        }
      }

      if (schemaFile == null) {
        throw Exception('Schema file not found in any of: ${schemaPaths.join(", ")}');
      }

      final schemaBytes = await schemaFile.readAsBytes();
      final messageBytes = await messageFile.readAsBytes();

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

  Future<void> _loadFigFile(File file) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Parsing file structure...';
    });

    try {
      final data = await file.readAsBytes();

      // Parse the file structure first
      final figFile = parseFigFileStructure(data);

      setState(() {
        _statusMessage = 'File: ${figFile.header.prelude}\n'
            'Schema: ${figFile.schemaChunk.data.length} bytes (${figFile.schemaChunk.compression.name})\n'
            'Data: ${figFile.dataChunk.data.length} bytes (${figFile.dataChunk.compression.name})';
      });

      // For full parsing, we need decompression
      // The schema uses raw DEFLATE, data uses ZSTD
      if (figFile.schemaChunk.isDeflate && figFile.dataChunk.isZstd) {
        setState(() {
          _statusMessage += '\n\nNote: Full parsing requires ZSTD and DEFLATE decompression.\n'
              'On desktop, DEFLATE is available via dart:io zlib.\n'
              'For ZSTD, you need a native library like zstd_dart.';
        });
      }
    } catch (e) {
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
                const SizedBox(height: 24),
                const Text(
                  'To use this viewer:\n\n'
                  '1. Export a Figma file (.fig)\n'
                  '2. Place it in the Apple_iOS_UI_Kit directory\n'
                  '3. Add ZSTD decompression support\n\n'
                  'Or use the pre-decompressed test fixtures.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FigmaCanvasView(
      document: _document!,
      showPageSelector: true,
      showDebugInfo: true,
    );
  }
}

/// Example of manually loading a Figma file with custom decompression
///
/// This shows how you would integrate with a ZSTD library:
/// ```dart
/// import 'package:zstd/zstd.dart' as zstd;
///
/// final parsed = parseFigFile(
///   fileData,
///   zstdDecompress: (data) => Uint8List.fromList(zstd.decode(data)),
///   deflateDecompress: (data) => Uint8List.fromList(
///     zlib.ZLibDecoder(raw: true).convert(data)),
/// );
///
/// final document = FigmaDocument.fromMessage(parsed.message);
/// ```
class FigmaFileLoader {
  /// Load a Figma file with decompression support
  ///
  /// Example with dart:io zlib for DEFLATE:
  /// ```dart
  /// import 'dart:io';
  ///
  /// final loader = FigmaFileLoader(
  ///   deflateDecompress: (data) {
  ///     return Uint8List.fromList(
  ///       zlib.ZLibDecoder(raw: true).convert(data.toList())
  ///     );
  ///   },
  /// );
  /// ```
  final Uint8List Function(Uint8List)? zstdDecompress;
  final Uint8List Function(Uint8List)? deflateDecompress;
  final Uint8List Function(Uint8List)? zlibDecompress;

  FigmaFileLoader({
    this.zstdDecompress,
    this.deflateDecompress,
    this.zlibDecompress,
  });

  FigmaDocument load(Uint8List data) {
    final parsed = parseFigFile(
      data,
      zstdDecompress: zstdDecompress,
      deflateDecompress: deflateDecompress,
      zlibDecompress: zlibDecompress,
    );

    return FigmaDocument.fromMessage(parsed.message);
  }

  FigFile parseStructureOnly(Uint8List data) {
    return parseFigFileStructure(data);
  }
}
