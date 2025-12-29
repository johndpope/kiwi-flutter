/// Figma File Browser and Viewer
///
/// Lists .fig files from a specified directory and allows viewing them.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

// ============================================================================
// DEBUG CONFIGURATION - Toggle these flags to enable/disable debug features
// ============================================================================
class DebugConfig {
  /// Master switch - set to false to disable ALL debug features
  static const bool enabled = true;

  /// Auto-open first .fig file on app start
  static const bool autoOpenFirstFile = enabled && true;

  /// Initial page index to show (null = first page)
  /// 0=System Experiences, 1=Internal Only (1411), 7=App Logos, 12=Welcome
  static const int? initialPageIndex = enabled ? 12 : null; // 12 = Welcome (has Components Index)

  /// Enable verbose image loading logs
  static const bool logImageLoading = enabled && false; // Disable to reduce spam

  /// Enable page list logging
  static const bool logPageList = enabled && false; // Disable to reduce spam
}

/// Decompress ZSTD data using system zstd command
Future<Uint8List> decompressZstd(Uint8List data) async {
  // Write to temp file
  final tempDir = Directory.systemTemp;
  final inputFile = File('${tempDir.path}/zstd_input_${DateTime.now().millisecondsSinceEpoch}.zst');
  final outputFile = File('${tempDir.path}/zstd_output_${DateTime.now().millisecondsSinceEpoch}.bin');

  try {
    await inputFile.writeAsBytes(data);

    // Run zstd -d
    final result = await Process.run('zstd', ['-d', inputFile.path, '-o', outputFile.path]);

    if (result.exitCode != 0) {
      throw Exception('ZSTD decompression failed: ${result.stderr}');
    }

    final decompressed = await outputFile.readAsBytes();
    return decompressed;
  } finally {
    // Cleanup
    if (await inputFile.exists()) await inputFile.delete();
    if (await outputFile.exists()) await outputFile.delete();
  }
}

void main() {
  runApp(const FigmaBrowserApp());
}

class FigmaBrowserApp extends StatelessWidget {
  const FigmaBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Figma Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const FigmaFileBrowser(),
    );
  }
}

class FigmaFileBrowser extends StatefulWidget {
  const FigmaFileBrowser({super.key});

  @override
  State<FigmaFileBrowser> createState() => _FigmaFileBrowserState();
}

class _FigmaFileBrowserState extends State<FigmaFileBrowser> {
  List<FileSystemEntity> _figFiles = [];
  bool _isLoading = true;
  String? _error;

  // Uses DebugConfig for auto-open behavior

  // Default paths to search for .fig files
  static const _searchPaths = [
    '/Users/johndpope/Downloads/Apple iOS UI Kit',
    '/Users/johndpope/Downloads',
  ];

  @override
  void initState() {
    super.initState();
    _loadFigFiles();
  }

  Future<void> _loadFigFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = <FileSystemEntity>[];

      for (final path in _searchPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File && entity.path.endsWith('.fig')) {
              files.add(entity);
            }
          }
        }
      }

      // Sort by name
      files.sort((a, b) => a.path.compareTo(b.path));

      setState(() {
        _figFiles = files;
        _isLoading = false;
      });

      // Auto-open first file for debugging
      if (DebugConfig.autoOpenFirstFile && files.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openFigFile(files.first as File);
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getFileName(FileSystemEntity entity) {
    return entity.path.split('/').last;
  }

  String _getRelativePath(FileSystemEntity entity) {
    for (final searchPath in _searchPaths) {
      if (entity.path.startsWith(searchPath)) {
        return entity.path.substring(searchPath.length + 1);
      }
    }
    return entity.path;
  }

  Future<void> _openFigFile(File file) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FigmaViewerPage(file: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Figma Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFigFiles,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for .fig files...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFigFiles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_figFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No .fig files found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Searched in:\n${_searchPaths.join('\n')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _figFiles.length,
      itemBuilder: (context, index) {
        final file = _figFiles[index] as File;
        final fileName = _getFileName(file);
        final relativePath = _getRelativePath(file);

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.design_services,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(fileName),
          subtitle: Text(
            relativePath != fileName ? relativePath : 'Figma Design File',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openFigFile(file),
        );
      },
    );
  }
}

class FigmaViewerPage extends StatefulWidget {
  final File file;

  const FigmaViewerPage({super.key, required this.file});

  @override
  State<FigmaViewerPage> createState() => _FigmaViewerPageState();
}

class _FigmaViewerPageState extends State<FigmaViewerPage> {
  FigmaDocument? _document;
  String? _error;
  bool _isLoading = true;
  String _statusMessage = 'Loading...';
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    // Delay loading to allow page transition animation to complete
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _loadFile();
    });
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading file...';
      _progress = 0.1;
    });

    // Allow UI to update before heavy work
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final data = await widget.file.readAsBytes();

      setState(() {
        _statusMessage = 'Parsing file structure...';
        _progress = 0.3;
      });

      // Parse the file structure
      final figFile = parseFigFileStructure(data);

      setState(() {
        _statusMessage = 'Decompressing schema...';
        _progress = 0.5;
      });

      // Decompress schema - try multiple approaches
      Uint8List schemaBytes;
      final schemaData = figFile.schemaChunk.data;

      // Check for ZSTD in schema chunk first
      if (schemaData.length >= 4 &&
          schemaData[0] == 0x28 && schemaData[1] == 0xB5 &&
          schemaData[2] == 0x2F && schemaData[3] == 0xFD) {
        schemaBytes = await decompressZstd(schemaData);
      } else if (figFile.schemaChunk.isZlib) {
        schemaBytes = Uint8List.fromList(
          zlib.decoder.convert(schemaData.toList()),
        );
      } else if (figFile.schemaChunk.isDeflate) {
        // Try raw deflate using RawZLibFilter
        try {
          final filter = RawZLibFilter.inflateFilter(raw: true);
          filter.process(schemaData, 0, schemaData.length);
          final chunks = <List<int>>[];
          List<int>? chunk;
          while ((chunk = filter.processed()) != null) {
            chunks.add(chunk!);
          }
          schemaBytes = Uint8List.fromList(chunks.expand((e) => e).toList());
        } catch (e) {
          // If deflate fails, try as raw binary schema
          schemaBytes = schemaData;
        }
      } else {
        schemaBytes = schemaData;
      }

      setState(() {
        _statusMessage = 'Parsing schema...';
        _progress = 0.6;
      });

      final schema = decodeBinarySchema(schemaBytes);
      final compiled = compileSchema(schema);

      setState(() {
        _statusMessage = 'Decompressing data...';
        _progress = 0.7;
      });

      // Check compression type for data chunk
      Uint8List messageBytes;
      if (figFile.dataChunk.isZstd) {
        setState(() {
          _statusMessage = 'Decompressing ZSTD data...';
          _progress = 0.75;
        });

        // Use system zstd command for decompression
        messageBytes = await decompressZstd(figFile.dataChunk.data);
      } else if (figFile.dataChunk.isDeflate) {
        messageBytes = Uint8List.fromList(
          zlib.decoder.convert(figFile.dataChunk.data.toList()),
        );
      } else if (figFile.dataChunk.isZlib) {
        messageBytes = Uint8List.fromList(
          zlib.decoder.convert(figFile.dataChunk.data.toList()),
        );
      } else {
        messageBytes = figFile.dataChunk.data;
      }

      setState(() {
        _statusMessage = 'Decoding message...';
        _progress = 0.9;
      });

      final message = compiled.decode('Message', messageBytes);
      final document = FigmaDocument.fromMessage(message);

      // Set images directory (same folder as .fig file)
      final figDir = widget.file.parent.path;
      final imagesDir = '$figDir/images';
      if (await Directory(imagesDir).exists()) {
        document.imagesDirectory = imagesDir;
        if (DebugConfig.logImageLoading) {
          print('DEBUG: Images directory: $imagesDir');
        }
        // Audit images to find missing ones
        document.auditImages();
      }

      setState(() {
        _document = document;
        _isLoading = false;
        _statusMessage = 'Loaded ${document.nodeCount} nodes';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(fileName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading file',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadFile,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(fileName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(value: _progress),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(title: Text(fileName)),
        body: const Center(
          child: Text('No document loaded'),
        ),
      );
    }

    // Remove .fig extension for display
    final displayName = fileName.endsWith('.fig')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          // Figma-style top tab bar
          _buildFigmaTabBar(displayName),
          // Canvas view
          Expanded(
            child: FigmaCanvasView(
              document: _document!,
              initialPageIndex: DebugConfig.initialPageIndex ?? 0,
              showPageSelector: true,
              showDebugInfo: DebugConfig.enabled,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds Figma-style top tab bar with file name
  Widget _buildFigmaTabBar(String fileName) {
    return Container(
      height: 40,
      color: const Color(0xFF2C2C2C),
      child: Row(
        children: [
          const SizedBox(width: 12),
          // Figma icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF0D99FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.diamond_outlined,
              size: 14,
              color: Color(0xFF0D99FF),
            ),
          ),
          const SizedBox(width: 12),
          // File tab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF383838),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Color(0xFFB3B3B3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // + button for new tab
          GestureDetector(
            onTap: () {
              // Could open file picker or show recent files
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Color(0xFFB3B3B3),
              ),
            ),
          ),
          const Spacer(),
          // Node count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF383838),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_document!.nodeCount} nodes',
              style: const TextStyle(
                color: Color(0xFF7A7A7A),
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
