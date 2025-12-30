// Rust-powered Figma file loader using flutter_rust_bridge
//
// This provides high-performance .fig file parsing using Rust/WASM.
// Usage:
//   final loader = RustFigmaLoader();
//   await loader.initialize();
//   final doc = await loader.loadFile(fileBytes);
//   final nodeInfo = await loader.getNodeInfo(doc, nodeId);

import 'dart:typed_data';
import 'rust/api.dart' as rust_api;
import 'rust/frb_generated.dart';

/// High-performance Figma file loader using Rust/WASM
class RustFigmaLoader {
  bool _initialized = false;

  /// Initialize the Rust library. Call this once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    await RustLib.init();
    _initialized = true;
  }

  /// Load a .fig file from bytes
  Future<rust_api.FigmaDocument> loadFile(Uint8List data) async {
    _ensureInitialized();
    return await rust_api.loadFigmaFile(data: data);
  }

  /// Get document metadata
  Future<rust_api.DocumentInfo> getDocumentInfo(
    rust_api.FigmaDocument doc,
  ) async {
    return await rust_api.getDocumentInfo(doc: doc);
  }

  /// Get information about a specific node
  Future<rust_api.NodeInfo> getNodeInfo(
    rust_api.FigmaDocument doc,
    String nodeId,
  ) async {
    return await rust_api.getNodeInfo(doc: doc, nodeId: nodeId);
  }

  /// Get all children of a node
  Future<List<rust_api.NodeInfo>> getChildren(
    rust_api.FigmaDocument doc,
    String nodeId,
  ) async {
    return await rust_api.getChildren(doc: doc, nodeId: nodeId);
  }

  /// Get render commands for a node (for custom rendering)
  Future<List<rust_api.DrawCommand>> renderNode(
    rust_api.FigmaDocument doc,
    String nodeId, {
    bool includeChildren = true,
  }) async {
    return await rust_api.renderNode(
      doc: doc,
      nodeId: nodeId,
      includeChildren: includeChildren,
    );
  }

  /// Export a node as SVG path data
  Future<String> exportSvgPath(
    rust_api.FigmaDocument doc,
    String nodeId,
  ) async {
    return await rust_api.exportSvgPath(doc: doc, nodeId: nodeId);
  }

  /// Decode Kiwi-encoded fill paint data
  Future<List<rust_api.PaintInfo>> decodeFillPaint(Uint8List data) async {
    _ensureInitialized();
    return await rust_api.decodeFillPaint(data: data);
  }

  /// Decode Kiwi-encoded effect data
  Future<List<rust_api.EffectInfo>> decodeEffects(Uint8List data) async {
    _ensureInitialized();
    return await rust_api.decodeEffects(data: data);
  }

  /// Decode Kiwi-encoded vector data
  Future<rust_api.PathData> decodeVector(Uint8List data) async {
    _ensureInitialized();
    return await rust_api.decodeVector(data: data);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'RustFigmaLoader not initialized. Call initialize() first.',
      );
    }
  }
}
