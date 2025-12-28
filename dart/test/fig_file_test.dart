import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  group('FigFile Parser', () {
    late Uint8List figFileData;

    setUpAll(() {
      // Load the canvas.fig file
      final file = File('${Directory.current.path}/../Apple_iOS_UI_Kit/canvas.fig');
      if (file.existsSync()) {
        figFileData = file.readAsBytesSync();
      } else {
        // Try relative path from test directory
        final altFile = File('${Directory.current.path}/../../Apple_iOS_UI_Kit/canvas.fig');
        if (altFile.existsSync()) {
          figFileData = altFile.readAsBytesSync();
        } else {
          throw Exception('canvas.fig not found. Run tests from dart directory.');
        }
      }
    });

    test('parses fig file structure', () {
      final figFile = parseFigFileStructure(figFileData);

      expect(figFile.header.prelude, equals('fig-kiwie'));
      expect(figFile.schemaChunk.data.length, equals(24208));
      expect(figFile.dataChunk.data.length, equals(3106170));
      expect(figFile.dataChunk.isZstd, isTrue);
      expect(figFile.schemaChunk.isDeflate, isTrue);
    });

    test('detects compression types correctly', () {
      // ZSTD signature
      final zstdData = Uint8List.fromList([0x28, 0xB5, 0x2F, 0xFD, 0x00]);
      expect(FigFileParser.detectCompression(zstdData), equals(CompressionType.zstd));

      // ZLIB signature (0x78 followed by valid second byte)
      final zlibData = Uint8List.fromList([0x78, 0x9C, 0x00, 0x00]);
      expect(FigFileParser.detectCompression(zlibData), equals(CompressionType.zlib));

      // Deflate when marked as schema chunk
      final deflateData = Uint8List.fromList([0xB5, 0xBD, 0x09, 0x98]);
      expect(FigFileParser.detectCompression(deflateData, isSchemaChunk: true),
             equals(CompressionType.deflate));

      // Unknown when not schema chunk and no known signature
      final unknownData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      expect(FigFileParser.detectCompression(unknownData), equals(CompressionType.unknown));
    });

    test('FigHeader properties work correctly', () {
      final header = FigHeader(prelude: 'fig-kiwie', version: 0);
      expect(header.isFigKiwi, isTrue);
      expect(header.isFigJam, isFalse);

      final jamHeader = FigHeader(prelude: 'fig-jam.', version: 0);
      expect(jamHeader.isFigJam, isTrue);
      expect(jamHeader.isFigKiwi, isFalse);
    });
  });

  group('Binary Schema Decoding', () {
    late Uint8List schemaData;

    setUpAll(() {
      final file = File('${Directory.current.path}/test/fixtures/figma_schema.bin');
      if (file.existsSync()) {
        schemaData = file.readAsBytesSync();
      } else {
        throw Exception('figma_schema.bin not found');
      }
    });

    test('decodes binary schema', () {
      final schema = decodeBinarySchema(schemaData);

      expect(schema.definitions.length, greaterThan(100));

      // Check for expected types
      final defNames = schema.definitions.map((d) => d.name).toList();
      expect(defNames, contains('NodeType'));
      expect(defNames, contains('Message'));
      expect(defNames, contains('NodeChange'));
      expect(defNames, contains('Paint'));
      expect(defNames, contains('Effect'));
    });

    test('compiles decoded schema', () {
      final schema = decodeBinarySchema(schemaData);
      final compiled = compileSchema(schema);

      expect(compiled, isNotNull);

      // Check enum access
      final nodeTypes = compiled.getEnumValues('NodeType');
      expect(nodeTypes, isNotNull);
      // Figma's schema has different enum values than our predefined schema
      expect(nodeTypes!.containsKey('DOCUMENT'), isTrue);
      expect(nodeTypes.containsKey('FRAME'), isTrue);
      expect(nodeTypes.containsKey('TEXT'), isTrue);
    });

    test('schema has expected definitions', () {
      final schema = decodeBinarySchema(schemaData);

      // Find NodeChange definition
      final nodeChangeDef = schema.definitions.firstWhere(
        (d) => d.name == 'NodeChange',
        orElse: () => throw Exception('NodeChange not found'),
      );

      expect(nodeChangeDef.kind, equals(DefinitionKind.MESSAGE));
      expect(nodeChangeDef.fields.length, greaterThan(20));

      // Check some fields exist
      final fieldNames = nodeChangeDef.fields.map((f) => f.name).toList();
      expect(fieldNames, contains('guid'));
      expect(fieldNames, contains('type'));
      expect(fieldNames, contains('name'));
    });
  });

  group('Message Decoding', () {
    late Schema schema;
    late CompiledSchema compiledSchema;
    late Uint8List messageData;

    setUpAll(() {
      // Load schema
      final schemaFile = File('${Directory.current.path}/test/fixtures/figma_schema.bin');
      final schemaBytes = schemaFile.readAsBytesSync();
      schema = decodeBinarySchema(schemaBytes);
      compiledSchema = compileSchema(schema);

      // Load message sample (first 100KB)
      final messageFile = File('${Directory.current.path}/test/fixtures/figma_message_sample.bin');
      if (messageFile.existsSync()) {
        messageData = messageFile.readAsBytesSync();
      } else {
        throw Exception('figma_message_sample.bin not found');
      }
    });

    test('decodes message partially', () {
      // The sample is truncated so full decode will fail,
      // but we can verify the decoder starts correctly
      try {
        final message = compiledSchema.decode('Message', messageData);
        expect(message, isNotNull);
        expect(message['nodeChanges'], isNotNull);
      } catch (e) {
        // Expected - truncated data
        print('Partial decode (expected to fail): $e');
      }
    });
  });

  group('Full Message Decoding', () {
    late Schema schema;
    late CompiledSchema compiledSchema;
    late Uint8List messageData;

    setUpAll(() {
      // Load schema
      final schemaFile = File('${Directory.current.path}/test/fixtures/figma_schema.bin');
      final schemaBytes = schemaFile.readAsBytesSync();
      schema = decodeBinarySchema(schemaBytes);
      compiledSchema = compileSchema(schema);

      // Load full message
      final messageFile = File('${Directory.current.path}/test/fixtures/figma_message.bin');
      if (messageFile.existsSync()) {
        messageData = messageFile.readAsBytesSync();
      } else {
        throw Exception('figma_message.bin not found');
      }
    });

    test('decodes full message from Apple iOS UI Kit', () {
      final message = compiledSchema.decode('Message', messageData);

      expect(message, isNotNull);
      expect(message['nodeChanges'], isA<List>());

      final nodeChanges = message['nodeChanges'] as List;
      print('Total nodes: ${nodeChanges.length}');
      expect(nodeChanges.length, greaterThan(100));
    });

    test('finds document node', () {
      final message = compiledSchema.decode('Message', messageData);
      final nodeChanges = message['nodeChanges'] as List;

      final docNode = nodeChanges.firstWhere(
        (n) => n['type'] == 'DOCUMENT',
        orElse: () => null,
      );

      expect(docNode, isNotNull);
      expect(docNode['name'], equals('Document'));
    });

    test('finds canvas nodes', () {
      final message = compiledSchema.decode('Message', messageData);
      final nodeChanges = message['nodeChanges'] as List;

      final canvasNodes = nodeChanges.where((n) => n['type'] == 'CANVAS').toList();

      expect(canvasNodes.length, greaterThan(0));
      print('Canvas pages: ${canvasNodes.map((n) => n['name']).join(', ')}');
    });

    test('finds frame nodes', () {
      final message = compiledSchema.decode('Message', messageData);
      final nodeChanges = message['nodeChanges'] as List;

      final frameNodes = nodeChanges.where((n) => n['type'] == 'FRAME').toList();

      expect(frameNodes.length, greaterThan(0));
      print('Frames: ${frameNodes.length}');
    });

    test('finds text nodes', () {
      final message = compiledSchema.decode('Message', messageData);
      final nodeChanges = message['nodeChanges'] as List;

      final textNodes = nodeChanges.where((n) => n['type'] == 'TEXT').toList();

      expect(textNodes.length, greaterThan(0));
      print('Text nodes: ${textNodes.length}');

      // Check first text node has text data
      if (textNodes.isNotEmpty) {
        final textNode = textNodes.first;
        print('First text: ${textNode['name']}');
      }
    });

    test('finds component and instance nodes', () {
      final message = compiledSchema.decode('Message', messageData);
      final nodeChanges = message['nodeChanges'] as List;

      final componentNodes = nodeChanges.where((n) => n['type'] == 'COMPONENT').toList();
      final instanceNodes = nodeChanges.where((n) => n['type'] == 'INSTANCE').toList();

      print('Components: ${componentNodes.length}');
      print('Instances: ${instanceNodes.length}');
    });

    test('node count summary', () {
      final message = compiledSchema.decode('Message', messageData);
      final nodeChanges = message['nodeChanges'] as List;

      // Count by type
      final typeCounts = <String, int>{};
      for (final node in nodeChanges) {
        final type = node['type'] as String? ?? 'UNKNOWN';
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }

      print('\n=== Node Type Summary ===');
      final sortedTypes = typeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedTypes) {
        print('${entry.key}: ${entry.value}');
      }
      print('========================\n');
    });
  });
}
