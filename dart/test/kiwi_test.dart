import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  late String schemaText;
  late CompiledSchema schema;

  setUpAll(() {
    schemaText = File('test/test-schema.kiwi').readAsStringSync();
    schema = compileSchema(parseSchema(schemaText));
  });

  group('struct bool', () {
    void check(bool input, List<int> output) {
      expect(
        schema.encode('BoolStruct', {'x': input}),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('BoolStruct', Uint8List.fromList(output)),
        equals({'x': input}),
      );
    }

    test('false', () => check(false, [0]));
    test('true', () => check(true, [1]));
  });

  group('struct byte', () {
    void check(int input, List<int> output) {
      expect(
        schema.encode('ByteStruct', {'x': input}),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('ByteStruct', Uint8List.fromList(output)),
        equals({'x': input}),
      );
    }

    test('0x00', () => check(0x00, [0x00]));
    test('0x01', () => check(0x01, [0x01]));
    test('0x7F', () => check(0x7F, [0x7F]));
    test('0x80', () => check(0x80, [0x80]));
    test('0xFF', () => check(0xFF, [0xFF]));
  });

  group('struct uint', () {
    void check(int input, List<int> output) {
      expect(
        schema.encode('UintStruct', {'x': input}),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('UintStruct', Uint8List.fromList(output)),
        equals({'x': input}),
      );
    }

    test('0x00', () => check(0x00, [0x00]));
    test('0x01', () => check(0x01, [0x01]));
    test('0x02', () => check(0x02, [0x02]));
    test('0x7F', () => check(0x7F, [0x7F]));
    test('0x80', () => check(0x80, [0x80, 0x01]));
    test('0x81', () => check(0x81, [0x81, 0x01]));
    test('0x100', () => check(0x100, [0x80, 0x02]));
    test('0x101', () => check(0x101, [0x81, 0x02]));
    test('0x17F', () => check(0x17F, [0xFF, 0x02]));
    test('0x180', () => check(0x180, [0x80, 0x03]));
    test('0x1FF', () => check(0x1FF, [0xFF, 0x03]));
    test('0x200', () => check(0x200, [0x80, 0x04]));
    test('0x7FFF', () => check(0x7FFF, [0xFF, 0xFF, 0x01]));
    test('0x8000', () => check(0x8000, [0x80, 0x80, 0x02]));
    test('0x7FFFFFFF', () => check(0x7FFFFFFF, [0xFF, 0xFF, 0xFF, 0xFF, 0x07]));
    test('0x80000000', () => check(0x80000000, [0x80, 0x80, 0x80, 0x80, 0x08]));
  });

  group('struct int', () {
    void check(int input, List<int> output) {
      expect(
        schema.encode('IntStruct', {'x': input}),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('IntStruct', Uint8List.fromList(output)),
        equals({'x': input}),
      );
    }

    test('0x00', () => check(0x00, [0x00]));
    test('-0x01', () => check(-0x01, [0x01]));
    test('0x01', () => check(0x01, [0x02]));
    test('-0x02', () => check(-0x02, [0x03]));
    test('0x02', () => check(0x02, [0x04]));
    test('-0x3F', () => check(-0x3F, [0x7D]));
    test('0x3F', () => check(0x3F, [0x7E]));
    test('-0x40', () => check(-0x40, [0x7F]));
    test('0x40', () => check(0x40, [0x80, 0x01]));
    test('-0x3FFF', () => check(-0x3FFF, [0xFD, 0xFF, 0x01]));
    test('0x3FFF', () => check(0x3FFF, [0xFE, 0xFF, 0x01]));
    test('-0x4000', () => check(-0x4000, [0xFF, 0xFF, 0x01]));
    test('0x4000', () => check(0x4000, [0x80, 0x80, 0x02]));
    test('-0x3FFFFFFF', () => check(-0x3FFFFFFF, [0xFD, 0xFF, 0xFF, 0xFF, 0x07]));
    test('0x3FFFFFFF', () => check(0x3FFFFFFF, [0xFE, 0xFF, 0xFF, 0xFF, 0x07]));
    test('-0x40000000', () => check(-0x40000000, [0xFF, 0xFF, 0xFF, 0xFF, 0x07]));
    test('0x40000000', () => check(0x40000000, [0x80, 0x80, 0x80, 0x80, 0x08]));
    test('-0x7FFFFFFF', () => check(-0x7FFFFFFF, [0xFD, 0xFF, 0xFF, 0xFF, 0x0F]));
    test('0x7FFFFFFF', () => check(0x7FFFFFFF, [0xFE, 0xFF, 0xFF, 0xFF, 0x0F]));
    test('-0x80000000', () => check(-0x80000000, [0xFF, 0xFF, 0xFF, 0xFF, 0x0F]));
  });

  group('struct float', () {
    void check(double input, List<int> output) {
      var encoded = schema.encode('FloatStruct', {'x': input});
      expect(encoded, equals(Uint8List.fromList(output)));

      var decoded = schema.decode('FloatStruct', Uint8List.fromList(output));
      if (input.isNaN) {
        expect((decoded['x'] as double).isNaN, isTrue);
      } else {
        expect(decoded['x'], equals(input));
      }
    }

    test('0', () => check(0.0, [0]));
    test('1', () => check(1.0, [127, 0, 0, 0]));
    test('-1', () => check(-1.0, [127, 1, 0, 0]));
    test('3.1415927410125732', () => check(3.1415927410125732, [128, 182, 31, 146]));
    test('-3.1415927410125732', () => check(-3.1415927410125732, [128, 183, 31, 146]));
    test('Infinity', () => check(double.infinity, [255, 0, 0, 0]));
    test('-Infinity', () => check(double.negativeInfinity, [255, 1, 0, 0]));
    test('NaN', () => check(double.nan, [255, 0, 0, 128]));
  });

  group('struct string', () {
    void check(String input, List<int> output) {
      expect(
        schema.encode('StringStruct', {'x': input}),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('StringStruct', Uint8List.fromList(output)),
        equals({'x': input}),
      );
    }

    test('empty', () => check('', [0]));
    test('abc', () => check('abc', [97, 98, 99, 0]));
    test('emoji', () => check('🙉🙈🙊', [240, 159, 153, 137, 240, 159, 153, 136, 240, 159, 153, 138, 0]));
  });

  group('struct compound', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('CompoundStruct', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('CompoundStruct', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('zeros', () => check({'x': 0, 'y': 0}, [0, 0]));
    test('small', () => check({'x': 1, 'y': 2}, [1, 2]));
    test('large', () => check({'x': 12345, 'y': 54321}, [185, 96, 177, 168, 3]));
  });

  group('struct nested', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('NestedStruct', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('NestedStruct', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('zeros', () => check({'a': 0, 'b': {'x': 0, 'y': 0}, 'c': 0}, [0, 0, 0, 0]));
    test('small', () => check({'a': 1, 'b': {'x': 2, 'y': 3}, 'c': 4}, [1, 2, 3, 4]));
    test('large', () => check({'a': 534, 'b': {'x': 12345, 'y': 54321}, 'c': 321}, [150, 4, 185, 96, 177, 168, 3, 193, 2]));
  });

  group('message bool', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('BoolMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('BoolMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('false', () => check({'x': false}, [1, 0, 0]));
    test('true', () => check({'x': true}, [1, 1, 0]));
  });

  group('message byte', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('ByteMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('ByteMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('value', () => check({'x': 234}, [1, 234, 0]));
  });

  group('struct byte array', () {
    void check(Map<String, dynamic> input, List<int> output) {
      var encoded = schema.encode('ByteArrayStruct', input);
      expect(encoded, equals(Uint8List.fromList(output)));

      var decoded = schema.decode('ByteArrayStruct', Uint8List.fromList(output));
      expect(decoded['x'], equals(input['x']));
    }

    test('empty', () => check({'x': Uint8List.fromList([])}, [0]));
    test('values', () => check({'x': Uint8List.fromList([4, 5, 6])}, [3, 4, 5, 6]));
  });

  group('message uint', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('UintMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('UintMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('value', () => check({'x': 12345678}, [1, 206, 194, 241, 5, 0]));
  });

  group('message int', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('IntMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('IntMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('value', () => check({'x': 12345678}, [1, 156, 133, 227, 11, 0]));
  });

  group('message float', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('FloatMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('FloatMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('value', () => check({'x': 3.1415927410125732}, [1, 128, 182, 31, 146, 0]));
  });

  group('message string', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('StringMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('StringMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('empty string', () => check({'x': ''}, [1, 0, 0]));
    test('emoji', () => check({'x': '🙉🙈🙊'}, [1, 240, 159, 153, 137, 240, 159, 153, 136, 240, 159, 153, 138, 0, 0]));
  });

  group('message compound', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('CompoundMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('CompoundMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('x only', () => check({'x': 123}, [1, 123, 0]));
    test('y only', () => check({'y': 234}, [2, 234, 1, 0]));
    test('both', () => check({'x': 123, 'y': 234}, [1, 123, 2, 234, 1, 0]));
  });

  group('message nested', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('NestedMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('NestedMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('a and c', () => check({'a': 123, 'c': 234}, [1, 123, 3, 234, 1, 0]));
    test('b only', () => check({'b': {'x': 5, 'y': 6}}, [2, 1, 5, 2, 6, 0, 0]));
    test('b and c', () => check({'b': {'x': 5}, 'c': 123}, [2, 1, 5, 0, 3, 123, 0]));
    test('all', () => check({'c': 123, 'b': {'x': 5, 'y': 6}, 'a': 234}, [1, 234, 1, 2, 1, 5, 2, 6, 0, 3, 123, 0]));
  });

  group('struct bool array', () {
    void check(List<bool> input, List<int> output) {
      expect(
        schema.encode('BoolArrayStruct', {'x': input}),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('BoolArrayStruct', Uint8List.fromList(output)),
        equals({'x': input}),
      );
    }

    test('empty', () => check([], [0]));
    test('values', () => check([true, false], [2, 1, 0]));
  });

  group('message bool array', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('BoolArrayMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('BoolArrayMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('empty array', () => check({'x': []}, [1, 0, 0]));
    test('values', () => check({'x': [true, false]}, [1, 2, 1, 0, 0]));
  });

  group('recursive message', () {
    void check(Map<String, dynamic> input, List<int> output) {
      expect(
        schema.encode('RecursiveMessage', input),
        equals(Uint8List.fromList(output)),
      );
      expect(
        schema.decode('RecursiveMessage', Uint8List.fromList(output)),
        equals(input),
      );
    }

    test('empty', () => check({}, [0]));
    test('one level', () => check({'x': {}}, [1, 0, 0]));
    test('two levels', () => check({'x': {'x': {}}}, [1, 1, 0, 0, 0]));
  });

  group('binary schema', () {
    test('round trip encoding', () {
      var compiledSchema = compileSchema(decodeBinarySchema(encodeBinarySchema(parseSchema(schemaText))));

      void check(Map<String, dynamic> message) {
        expect(
          schema.encode('NestedMessage', message),
          equals(compiledSchema.encode('NestedMessage', message)),
        );
      }

      check({'a': 1, 'c': 4});
      check({'a': 1, 'b': {}, 'c': 4});
      check({'a': 1, 'b': {'x': 2, 'y': 3}, 'c': 4});
    });
  });

  group('large schema', () {
    late String largeSchemaText;
    late CompiledSchema largeSchema;

    setUpAll(() {
      largeSchemaText = File('test/test-schema-large.kiwi').readAsStringSync();
      largeSchema = compileSchema(parseSchema(largeSchemaText));
    });

    test('struct with many fields', () {
      Map<String, dynamic> object = {};
      for (int i = 0; i < 130; i++) {
        object['f$i'] = i;
      }

      var encoded = largeSchema.encode('Struct', object);
      expect(largeSchema.decode('Struct', encoded), equals(object));
    });

    test('message with many fields', () {
      Map<String, dynamic> object = {};
      for (int i = 0; i < 130; i++) {
        object['f$i'] = i;
      }

      var encoded = largeSchema.encode('Message', object);
      expect(largeSchema.decode('Message', encoded), equals(object));
    });
  });

  group('deprecated fields', () {
    test('deprecated fields are skipped', () {
      var nonDeprecated = {
        'a': 1,
        'b': 2,
        'c': [3, 4, 5],
        'd': [6, 7, 8],
        'e': {'x': 123},
        'f': {'x': 234},
        'g': 9,
      };

      var deprecated = {
        'a': 1,
        'c': [3, 4, 5],
        'e': {'x': 123},
        'g': 9,
      };

      expect(
        schema.decode('DeprecatedMessage', schema.encode('NonDeprecatedMessage', nonDeprecated)),
        equals(deprecated),
      );
      expect(
        schema.decode('NonDeprecatedMessage', schema.encode('DeprecatedMessage', nonDeprecated)),
        equals(deprecated),
      );
    });
  });

  group('schema round trip', () {
    test('parse and print produces equivalent schema', () {
      var parsed = parseSchema(schemaText);
      var schemaText2 = prettyPrintSchema(parsed);
      var parsed2 = parseSchema(schemaText2);

      // Compare definitions (ignoring line/column)
      expect(parsed.definitions.length, equals(parsed2.definitions.length));
      for (int i = 0; i < parsed.definitions.length; i++) {
        var d1 = parsed.definitions[i];
        var d2 = parsed2.definitions[i];
        expect(d1.name, equals(d2.name));
        expect(d1.kind, equals(d2.kind));
        expect(d1.fields.length, equals(d2.fields.length));
        for (int j = 0; j < d1.fields.length; j++) {
          var f1 = d1.fields[j];
          var f2 = d2.fields[j];
          expect(f1.name, equals(f2.name));
          expect(f1.type, equals(f2.type));
          expect(f1.isArray, equals(f2.isArray));
          expect(f1.isDeprecated, equals(f2.isDeprecated));
          expect(f1.value, equals(f2.value));
        }
      }
    });
  });

  group('enum', () {
    test('encode and decode enum values', () {
      expect(
        schema.encode('EnumStruct', {'x': 'A', 'y': ['A', 'B']}),
        equals(Uint8List.fromList([100, 2, 100, 200, 1])),
      );
      expect(
        schema.decode('EnumStruct', Uint8List.fromList([100, 2, 100, 200, 1])),
        equals({'x': 'A', 'y': ['A', 'B']}),
      );
    });
  });
}
