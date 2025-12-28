import 'dart:typed_data';
import 'byte_buffer.dart';
import 'schema.dart';

// Standard kiwi types plus extended types used by Figma
const List<String?> _types = [
  'bool',    // 0
  'byte',    // 1
  'int',     // 2
  'uint',    // 3
  'float',   // 4
  'string',  // 5
  'int64',   // 6 - Figma extension
  'uint64',  // 7 - Figma extension
];
const List<DefinitionKind> _kinds = [
  DefinitionKind.ENUM,
  DefinitionKind.STRUCT,
  DefinitionKind.MESSAGE
];

/// Decodes a binary-encoded schema into a Schema object.
Schema decodeBinarySchema(dynamic buffer) {
  ByteBuffer bb;
  if (buffer is ByteBuffer) {
    bb = buffer;
  } else if (buffer is Uint8List) {
    bb = ByteBuffer(buffer);
  } else {
    throw ArgumentError('Buffer must be a ByteBuffer or Uint8List');
  }

  int definitionCount = bb.readVarUint();
  List<Definition> definitions = [];

  // Read in the schema
  for (int i = 0; i < definitionCount; i++) {
    String definitionName = bb.readString();
    int kindIndex = bb.readByte();
    int fieldCount = bb.readVarUint();
    List<Field> fields = [];

    for (int j = 0; j < fieldCount; j++) {
      String fieldName = bb.readString();
      int type = bb.readVarInt();
      bool isArray = (bb.readByte() & 1) != 0;
      int value = bb.readVarUint();

      fields.add(Field(
        name: fieldName,
        line: 0,
        column: 0,
        // Store type as string representation of the index temporarily
        type: _kinds[kindIndex] == DefinitionKind.ENUM ? null : type.toString(),
        isArray: isArray,
        isDeprecated: false,
        value: value,
      ));
    }

    definitions.add(Definition(
      name: definitionName,
      line: 0,
      column: 0,
      kind: _kinds[kindIndex],
      fields: fields,
    ));
  }

  // Bind type names afterwards
  for (int i = 0; i < definitionCount; i++) {
    var fields = definitions[i].fields;
    for (int j = 0; j < fields.length; j++) {
      var field = fields[j];
      if (field.type != null) {
        int type = int.parse(field.type!);

        if (type < 0) {
          int typeIndex = ~type;
          if (typeIndex >= _types.length) {
            throw Exception('Invalid type $type');
          }
          field.type = _types[typeIndex];
        } else {
          if (type >= definitions.length) {
            throw Exception('Invalid type $type');
          }
          field.type = definitions[type].name;
        }
      }
    }
  }

  return Schema(
    package: null,
    definitions: definitions,
  );
}

/// Encodes a schema into binary format.
Uint8List encodeBinarySchema(Schema schema) {
  ByteBuffer bb = ByteBuffer();
  var definitions = schema.definitions;
  Map<String, int> definitionIndex = {};

  bb.writeVarUint(definitions.length);

  for (int i = 0; i < definitions.length; i++) {
    definitionIndex[definitions[i].name] = i;
  }

  for (int i = 0; i < definitions.length; i++) {
    var definition = definitions[i];

    bb.writeString(definition.name);
    bb.writeByte(_kinds.indexOf(definition.kind));
    bb.writeVarUint(definition.fields.length);

    for (int j = 0; j < definition.fields.length; j++) {
      var field = definition.fields[j];
      int typeIndex = field.type != null ? _types.indexOf(field.type) : -1;

      bb.writeString(field.name);
      // For enums, field.type is null, write 0 as placeholder
      if (field.type == null) {
        bb.writeVarInt(0);
      } else {
        bb.writeVarInt(typeIndex == -1 ? definitionIndex[field.type!]! : ~typeIndex);
      }
      bb.writeByte(field.isArray ? 1 : 0);
      bb.writeVarUint(field.value);
    }
  }

  return bb.toUint8Array();
}
