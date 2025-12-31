/// Tile-based rendering tests
///
/// Tests for the tile rendering system, verifying that tiles are correctly
/// rendered and can reproduce the same output as direct rendering.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';
import 'package:kiwi_schema/src/flutter/tiles/tiles.dart';

void main() {
  late Schema schema;
  late CompiledSchema compiled;
  late Map<String, dynamic> message;
  late FigmaDocument document;

  setUpAll(() async {
    // Load the pre-decompressed data
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    if (!schemaFile.existsSync() || !messageFile.existsSync()) {
      throw Exception('Test fixtures not found.');
    }

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    schema = decodeBinarySchema(schemaBytes);
    compiled = compileSchema(schema);
    message = compiled.decode('Message', messageBytes);
    document = FigmaDocument.fromMessage(message);
    document.imagesDirectory = '/Users/johndpope/Downloads/Apple iOS UI Kit/images';

    print('Loaded ${document.nodeCount} nodes');
  });

  group('TileCoord', () {
    test('calculates correct bounds for LOD 0', () {
      final coord = TileCoord(0, 0, 0);
      final bounds = coord.bounds;

      expect(bounds.left, 0.0);
      expect(bounds.top, 0.0);
      expect(bounds.width, kTileSize);
      expect(bounds.height, kTileSize);
    });

    test('calculates correct bounds for LOD 1', () {
      // At LOD 1, tiles cover 2x2 LOD 0 tiles
      final coord = TileCoord(0, 0, 1);
      final bounds = coord.bounds;

      expect(bounds.left, 0.0);
      expect(bounds.top, 0.0);
      expect(bounds.width, kTileSize * 2);
      expect(bounds.height, kTileSize * 2);
    });

    test('calculates correct bounds for negative coordinates', () {
      final coord = TileCoord(-1, -1, 0);
      final bounds = coord.bounds;

      expect(bounds.left, -kTileSize);
      expect(bounds.top, -kTileSize);
      expect(bounds.width, kTileSize);
      expect(bounds.height, kTileSize);
    });
  });

  group('WorldViewport', () {
    test('calculates LOD from scale', () {
      // Scale >= 0.5 -> LOD 0
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 1.0).lod, 0);
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.5).lod, 0);

      // Scale >= 0.25 -> LOD 1
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.49).lod, 1);
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.25).lod, 1);

      // Scale >= 0.125 -> LOD 2
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.24).lod, 2);
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.125).lod, 2);

      // Scale < 0.125 -> LOD 3
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.1).lod, 3);
    });

    test('calculates effective tile size for LOD', () {
      // LOD 0: tileSize = 1024
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 1.0).effectiveTileSize, kTileSize);

      // LOD 1: tileSize = 2048
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.3).effectiveTileSize, kTileSize * 2);

      // LOD 2: tileSize = 4096
      expect(WorldViewport(x: 0, y: 0, width: 1000, height: 1000, scale: 0.2).effectiveTileSize, kTileSize * 4);
    });
  });

  group('getVisibleTiles', () {
    test('returns tiles for small viewport', () {
      final viewport = WorldViewport(x: 0, y: 0, width: 500, height: 500, scale: 1.0);
      final tiles = getVisibleTiles(viewport);

      // Should include tile (0,0) and potentially border tiles
      expect(tiles, isNotEmpty);
      expect(tiles.any((t) => t.x == 0 && t.y == 0), isTrue);
    });

    test('returns more tiles for larger viewport', () {
      final smallViewport = WorldViewport(x: 0, y: 0, width: 500, height: 500, scale: 1.0);
      final largeViewport = WorldViewport(x: 0, y: 0, width: 4000, height: 4000, scale: 1.0);

      final smallTiles = getVisibleTiles(smallViewport);
      final largeTiles = getVisibleTiles(largeViewport);

      expect(largeTiles.length, greaterThan(smallTiles.length));
    });

    test('returns fewer tiles at higher LOD', () {
      final viewport1 = WorldViewport(x: 0, y: 0, width: 4000, height: 4000, scale: 1.0);
      final viewport2 = WorldViewport(x: 0, y: 0, width: 4000, height: 4000, scale: 0.2);

      final tiles1 = getVisibleTiles(viewport1);
      final tiles2 = getVisibleTiles(viewport2);

      // At lower scale (higher LOD), tiles are larger so fewer are needed
      expect(tiles2.length, lessThanOrEqualTo(tiles1.length));
    });

    test('handles negative viewport position', () {
      final viewport = WorldViewport(x: -500, y: -500, width: 1000, height: 1000, scale: 1.0);
      final tiles = getVisibleTiles(viewport);

      expect(tiles, isNotEmpty);
      // Should include tile at negative coordinates
      expect(tiles.any((t) => t.x < 0 || t.y < 0), isTrue);
    });
  });

  group('DartTileBackend', () {
    test('initializes with FigmaDocument', () async {
      final backend = DartTileBackend();
      await backend.initialize(document, '0:0');

      expect(backend.isReady, isTrue);
      expect(backend.name, equals('Pure Dart'));
    });

    test('renders a tile with nodes', () async {
      final backend = DartTileBackend();
      final pages = document.pages;
      final rootNodeId = pages.isNotEmpty
          ? pages.first['_guidKey'] as String? ?? '0:0'
          : '0:0';

      await backend.initialize(document, rootNodeId);

      // Render a tile at origin
      final coord = TileCoord(0, 0, 0);
      final result = await backend.renderTile(coord);

      expect(result, isNotNull);
      expect(result!.image, isNotNull);
      expect(result.image.width, greaterThan(0));
      expect(result.image.height, greaterThan(0));
    });

    test('caches rendered tiles', () async {
      final backend = DartTileBackend();
      final pages = document.pages;
      final rootNodeId = pages.isNotEmpty
          ? pages.first['_guidKey'] as String? ?? '0:0'
          : '0:0';

      await backend.initialize(document, rootNodeId);

      final coord = TileCoord(0, 0, 0);

      // First render
      final result1 = await backend.renderTile(coord);
      expect(result1!.fromCache, isFalse);

      // Second render should be from cache
      final result2 = await backend.renderTile(coord);
      expect(result2!.fromCache, isTrue);
    });

    test('clears cache', () async {
      final backend = DartTileBackend();
      final pages = document.pages;
      final rootNodeId = pages.isNotEmpty
          ? pages.first['_guidKey'] as String? ?? '0:0'
          : '0:0';

      await backend.initialize(document, rootNodeId);

      final coord = TileCoord(0, 0, 0);
      await backend.renderTile(coord);

      // Clear and re-render
      await backend.clearCache();

      final result = await backend.renderTile(coord);
      expect(result!.fromCache, isFalse);
    });
  });

  group('TileManager Widget', () {
    testWidgets('renders TileManager without error', (tester) async {
      final pages = document.pages;
      final rootNodeId = pages.isNotEmpty
          ? pages.first['_guidKey'] as String? ?? '0:0'
          : '0:0';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TileManager(
                document: document,
                rootNodeId: rootNodeId,
                transformController: TransformationController(),
                config: const TileManagerConfig(
                  showDebugOverlay: false,
                  showTileBounds: false,
                  backendType: TileBackendType.dart,
                ),
              ),
            ),
          ),
        ),
      );

      // Just pump a few frames without waiting for settle (async tile rendering)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TileManager), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('TileCanvas renders and handles gestures', (tester) async {
      final pages = document.pages;
      final rootNodeId = pages.isNotEmpty
          ? pages.first['_guidKey'] as String? ?? '0:0'
          : '0:0';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TileCanvas(
                document: document,
                rootNodeId: rootNodeId,
                config: const TileManagerConfig(
                  showDebugOverlay: false,  // Disable to simplify widget tree
                  showTileBounds: false,
                  backendType: TileBackendType.dart,
                ),
              ),
            ),
          ),
        ),
      );

      // Pump a few frames (async tile rendering)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TileCanvas), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });

  group('FigmaCanvasView with Tile Rendering', () {
    testWidgets('renders with useTileRenderer flag', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: FigmaCanvasView(
                document: document,
                showPageSelector: false,
                showDebugInfo: false,
                useTileRenderer: true,  // Start in tile mode
              ),
            ),
          ),
        ),
      );

      // Pump a few frames (async tile rendering)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FigmaCanvasView), findsOneWidget);
      // TileCanvas should be present when useTileRenderer is true
      expect(find.byType(TileCanvas), findsOneWidget);
    });

    testWidgets('renders without useTileRenderer flag', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: FigmaCanvasView(
                document: document,
                showPageSelector: false,
                showDebugInfo: false,
                useTileRenderer: false,  // Standard mode
              ),
            ),
          ),
        ),
      );

      // Pump a few frames
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FigmaCanvasView), findsOneWidget);
      // TileCanvas should NOT be present
      expect(find.byType(TileCanvas), findsNothing);
    });
  });
}
