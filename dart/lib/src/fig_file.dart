/// Figma .fig file parser for Dart/Flutter
///
/// This module provides support for reading Figma's .fig file format,
/// which uses the Kiwi binary schema format with compression.
///
/// The file format structure:
/// - Header: "fig-kiwi" (8 bytes) or "fig-kiwie" (9 bytes) + padding
/// - Version/padding to align to 4 bytes
/// - Chunks: Each chunk is [size: uint32_le] + [data: bytes]
///   - Chunk 0: Binary Kiwi schema (may be raw or deflate compressed)
///   - Chunk 1: Message data (ZSTD or deflate compressed)
///   - Chunk 2: Preview image (optional)

library fig_file;

import 'dart:typed_data';
import 'binary.dart';
import 'compiler.dart';
import 'schema.dart';

/// Magic bytes for Figma Kiwi format
const String figKiwiMagic = 'fig-kiwi';
const String figKiwieMagic = 'fig-kiwie';
const String figJamMagic = 'fig-jam.';

/// ZSTD compression signature: 0x28, 0xB5, 0x2F, 0xFD
const List<int> zstdSignature = [0x28, 0xB5, 0x2F, 0xFD];

/// ZLIB compression signature (common variants: 0x78 0x01, 0x78 0x9C, 0x78 0xDA)
const int zlibSignature = 0x78;

/// Deflate (raw) - hard to detect without trying to decompress
/// Figma uses raw deflate for schema chunks

/// Parsed header from a .fig file
class FigHeader {
  final String prelude;
  final int version;

  FigHeader({required this.prelude, required this.version});

  bool get isFigKiwi => prelude == figKiwiMagic || prelude == figKiwieMagic;
  bool get isFigJam => prelude == figJamMagic;

  @override
  String toString() => 'FigHeader(prelude: $prelude, version: $version)';
}

/// Compression type detected in a chunk
enum CompressionType {
  /// No compression detected (raw data)
  none,
  /// ZSTD compression (magic: 0x28 0xB5 0x2F 0xFD)
  zstd,
  /// ZLIB compression (magic: 0x78 ...)
  zlib,
  /// Raw DEFLATE (no header, used by Figma for schema)
  deflate,
  /// Unknown compression
  unknown,
}

/// A chunk from a .fig file
class FigChunk {
  final Uint8List data;
  final CompressionType compression;

  FigChunk({required this.data, required this.compression});

  /// Check if this chunk uses ZSTD compression
  bool get isZstd => compression == CompressionType.zstd;

  /// Check if this chunk uses ZLIB compression
  bool get isZlib => compression == CompressionType.zlib;

  /// Check if this chunk uses raw DEFLATE compression
  bool get isDeflate => compression == CompressionType.deflate;

  /// Check if this chunk is uncompressed
  bool get isRaw => compression == CompressionType.none;
}

/// Result of parsing a .fig file
class FigFile {
  final FigHeader header;
  final FigChunk schemaChunk;
  final FigChunk dataChunk;
  final Uint8List? previewChunk;

  FigFile({
    required this.header,
    required this.schemaChunk,
    required this.dataChunk,
    this.previewChunk,
  });

  @override
  String toString() =>
      'FigFile(header: $header, schemaSize: ${schemaChunk.data.length}, '
      'dataSize: ${dataChunk.data.length}, hasPreview: ${previewChunk != null})';
}

/// Parsed Figma document with decoded schema and message
class ParsedFigFile {
  final FigHeader header;
  final Schema schema;
  final CompiledSchema compiledSchema;
  final Map<String, dynamic> message;
  final Uint8List? preview;

  ParsedFigFile({
    required this.header,
    required this.schema,
    required this.compiledSchema,
    required this.message,
    this.preview,
  });

  /// Get all node changes from the message
  List<Map<String, dynamic>> get nodeChanges {
    final changes = message['nodeChanges'];
    if (changes is List) {
      return changes.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get blobs from the message
  List<Map<String, dynamic>> get blobs {
    final blobList = message['blobs'];
    if (blobList is List) {
      return blobList.cast<Map<String, dynamic>>();
    }
    return [];
  }
}

/// Parser for .fig files
class FigFileParser {
  final Uint8List _data;
  int _offset = 0;

  FigFileParser(this._data);

  /// Read bytes from the buffer
  Uint8List _read(int count) {
    if (_offset + count > _data.length) {
      throw FormatException(
          'Unexpected end of data: need $count bytes at offset $_offset, '
          'but only ${_data.length - _offset} available');
    }
    final result = _data.sublist(_offset, _offset + count);
    _offset += count;
    return result;
  }

  /// Read a little-endian uint32
  int _readUint32() {
    final bytes = _read(4);
    return bytes[0] |
        (bytes[1] << 8) |
        (bytes[2] << 16) |
        (bytes[3] << 24);
  }

  /// Detect compression type from data
  static CompressionType detectCompression(Uint8List data, {bool isSchemaChunk = false}) {
    if (data.length < 4) return CompressionType.unknown;

    // Check ZSTD signature
    if (data[0] == zstdSignature[0] &&
        data[1] == zstdSignature[1] &&
        data[2] == zstdSignature[2] &&
        data[3] == zstdSignature[3]) {
      return CompressionType.zstd;
    }

    // Check ZLIB signature (0x78 followed by 0x01, 0x9C, or 0xDA)
    if (data[0] == zlibSignature &&
        (data[1] == 0x01 || data[1] == 0x9C || data[1] == 0xDA)) {
      return CompressionType.zlib;
    }

    // Schema chunks in Figma use raw deflate (no header)
    if (isSchemaChunk) {
      return CompressionType.deflate;
    }

    // Unknown compression - could be raw deflate or uncompressed
    return CompressionType.unknown;
  }

  /// Parse the .fig file structure
  FigFile parse() {
    // Read prelude
    final preludeBytes = _read(8);
    String prelude = String.fromCharCodes(preludeBytes);

    // Check for fig-kiwie (9 bytes) or other variants
    if (prelude == figKiwiMagic) {
      // Check if it's actually fig-kiwie
      if (_offset < _data.length && _data[_offset] == 0x65) {
        // 'e'
        _read(1); // consume the 'e'
        prelude = figKiwieMagic;
      }
    }

    // Align to 4-byte boundary
    while (_offset % 4 != 0 && _offset < _data.length) {
      _read(1);
    }

    // Validate prelude
    if (prelude != figKiwiMagic &&
        prelude != figKiwieMagic &&
        prelude != figJamMagic) {
      throw FormatException('Invalid fig file prelude: "$prelude"');
    }

    // For fig-kiwie, there's no explicit version field in the new format
    // The chunks start immediately after alignment
    int version = 0;

    // Read chunks
    final chunks = <FigChunk>[];
    while (_offset + 4 <= _data.length) {
      final size = _readUint32();
      if (size == 0 || _offset + size > _data.length) break;

      final chunkData = _read(size);
      // First chunk (schema) uses raw deflate, others may use zstd
      final isSchemaChunk = chunks.isEmpty;
      final compression = detectCompression(chunkData, isSchemaChunk: isSchemaChunk);
      chunks.add(FigChunk(data: chunkData, compression: compression));

      if (chunks.length >= 3) break; // Max 3 chunks expected
    }

    if (chunks.isEmpty) {
      throw FormatException('No chunks found in fig file');
    }

    if (chunks.length < 2) {
      throw FormatException(
          'Expected at least 2 chunks (schema + data), found ${chunks.length}');
    }

    return FigFile(
      header: FigHeader(prelude: prelude, version: version),
      schemaChunk: chunks[0],
      dataChunk: chunks[1],
      previewChunk: chunks.length > 2 ? chunks[2].data : null,
    );
  }
}

/// Callback type for decompressing data
typedef Decompressor = Uint8List Function(Uint8List data);

/// Parse a .fig file with custom decompressors
///
/// Since ZSTD decompression requires native code, you must provide
/// decompressors for the compression types used in your file.
///
/// Example:
/// ```dart
/// import 'package:zstd/zstd.dart' as zstd;
/// import 'dart:io' show zlib;
///
/// final parsed = parseFigFile(
///   data,
///   zstdDecompress: (data) => Uint8List.fromList(zstd.decode(data)),
///   zlibDecompress: (data) => Uint8List.fromList(zlib.decode(data)),
///   deflateDecompress: (data) => Uint8List.fromList(
///     zlib.ZLibDecoder(raw: true).convert(data)),
/// );
/// ```
ParsedFigFile parseFigFile(
  Uint8List data, {
  Decompressor? zstdDecompress,
  Decompressor? zlibDecompress,
  Decompressor? deflateDecompress,
}) {
  final parser = FigFileParser(data);
  final figFile = parser.parse();

  // Decompress schema chunk
  Uint8List schemaData;
  switch (figFile.schemaChunk.compression) {
    case CompressionType.zstd:
      if (zstdDecompress == null) {
        throw UnsupportedError(
            'Schema chunk is ZSTD compressed but no zstdDecompress provided');
      }
      schemaData = zstdDecompress(figFile.schemaChunk.data);
      break;
    case CompressionType.zlib:
      if (zlibDecompress == null) {
        throw UnsupportedError(
            'Schema chunk is ZLIB compressed but no zlibDecompress provided');
      }
      schemaData = zlibDecompress(figFile.schemaChunk.data);
      break;
    case CompressionType.deflate:
      if (deflateDecompress == null) {
        throw UnsupportedError(
            'Schema chunk is DEFLATE compressed but no deflateDecompress provided');
      }
      schemaData = deflateDecompress(figFile.schemaChunk.data);
      break;
    case CompressionType.none:
    case CompressionType.unknown:
      // Assume raw binary schema
      schemaData = figFile.schemaChunk.data;
      break;
  }

  // Decompress data chunk
  Uint8List messageData;
  switch (figFile.dataChunk.compression) {
    case CompressionType.zstd:
      if (zstdDecompress == null) {
        throw UnsupportedError(
            'Data chunk is ZSTD compressed but no zstdDecompress provided');
      }
      messageData = zstdDecompress(figFile.dataChunk.data);
      break;
    case CompressionType.zlib:
      if (zlibDecompress == null) {
        throw UnsupportedError(
            'Data chunk is ZLIB compressed but no zlibDecompress provided');
      }
      messageData = zlibDecompress(figFile.dataChunk.data);
      break;
    case CompressionType.deflate:
      if (deflateDecompress == null) {
        throw UnsupportedError(
            'Data chunk is DEFLATE compressed but no deflateDecompress provided');
      }
      messageData = deflateDecompress(figFile.dataChunk.data);
      break;
    case CompressionType.none:
    case CompressionType.unknown:
      messageData = figFile.dataChunk.data;
      break;
  }

  // Decode binary schema
  final schema = decodeBinarySchema(schemaData);
  final compiledSchema = compileSchema(schema);

  // Decode message
  final message = compiledSchema.decode('Message', messageData);

  return ParsedFigFile(
    header: figFile.header,
    schema: schema,
    compiledSchema: compiledSchema,
    message: message,
    preview: figFile.previewChunk,
  );
}

/// Parse just the file structure without decompressing
FigFile parseFigFileStructure(Uint8List data) {
  final parser = FigFileParser(data);
  return parser.parse();
}
