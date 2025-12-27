# Kiwi Schema - Dart/Flutter Port

A Dart/Flutter implementation of the [Kiwi](https://github.com/evanw/kiwi) binary schema format for efficiently encoding trees of data.

## Features

- **Efficient compact encoding** using variable-length encoding for small values
- **Support for optional fields** with detectable presence
- **Linear serialization** - single-scan reads and writes for cache efficiency
- **Backwards & forwards compatibility** - new schemas can read old data and vice versa
- **Pure Dart** - no native dependencies

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  kiwi_schema:
    path: ../dart  # or from pub.dev when published
```

## Usage

### Parsing and Compiling a Schema

```dart
import 'package:kiwi_schema/kiwi.dart';

const schemaText = '''
enum Type {
  FLAT = 0;
  ROUND = 1;
  POINTED = 2;
}

struct Color {
  byte red;
  byte green;
  byte blue;
  byte alpha;
}

message Example {
  uint clientID = 1;
  Type type = 2;
  Color[] colors = 3;
}
''';

void main() {
  // Parse and compile the schema
  var schema = compileSchema(schemaText);

  // Encode a message
  var message = {
    'clientID': 100,
    'type': 'POINTED',
    'colors': [
      {'red': 255, 'green': 127, 'blue': 0, 'alpha': 255}
    ]
  };

  var encoded = schema.encode('Example', message);
  print('Encoded: ${encoded.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');

  // Decode a message
  var decoded = schema.decode('Example', encoded);
  print('Decoded: $decoded');
}
```

### Binary Schema Encoding

You can also encode schemas themselves into a compact binary format:

```dart
import 'package:kiwi_schema/kiwi.dart';

var parsed = parseSchema(schemaText);
var binarySchema = encodeBinarySchema(parsed);

// Later, decode and compile from binary
var schema = compileSchema(decodeBinarySchema(binarySchema));
```

## Supported Types

### Native Types
- `bool` - Boolean value (1 byte)
- `byte` - Unsigned 8-bit integer (1 byte)
- `int` - Signed 32-bit integer (variable-length, 1-5 bytes)
- `uint` - Unsigned 32-bit integer (variable-length, 1-5 bytes)
- `float` - 32-bit IEEE 754 float (1 byte for 0, otherwise 4 bytes)
- `string` - UTF-8 null-terminated string

### User-Defined Types
- `enum` - Named integer values
- `struct` - Fixed fields, all required, cannot be extended
- `message` - Optional fields, extensible with field IDs

## Running Tests

```bash
cd dart
dart pub get
dart test
```

## Flutter Web Demo

A Flutter web demo is included in the `example/` directory that mirrors the functionality of the JavaScript demo:

```bash
cd dart/example
flutter pub get
flutter run -d chrome
```

## API Reference

### ByteBuffer

Low-level binary encoding/decoding buffer:
- `readByte()` / `writeByte(int value)`
- `readByteArray()` / `writeByteArray(Uint8List value)`
- `readVarUint()` / `writeVarUint(int value)`
- `readVarInt()` / `writeVarInt(int value)`
- `readVarFloat()` / `writeVarFloat(double value)`
- `readString()` / `writeString(String value)`
- `toUint8Array()` - Get encoded bytes

### Schema Functions

- `parseSchema(String text)` - Parse schema text into a Schema object
- `compileSchema(Schema | String)` - Compile a schema for encoding/decoding
- `encodeBinarySchema(Schema)` - Encode schema to binary format
- `decodeBinarySchema(Uint8List)` - Decode schema from binary format
- `prettyPrintSchema(Schema)` - Convert schema back to text format

### CompiledSchema

- `encode(String typeName, Map<String, dynamic> message)` - Encode a message
- `decode(String typeName, Uint8List data)` - Decode a message
- `getEnumValues(String enumName)` - Get enum name-to-value mapping
- `getEnumNames(String enumName)` - Get enum value-to-name mapping

## License

MIT
