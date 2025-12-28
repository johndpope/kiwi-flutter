import 'dart:typed_data';
import 'byte_buffer.dart';
import 'schema.dart';
import 'parser.dart';

/// A compiled schema that can encode and decode messages.
class CompiledSchema {
  final Schema schema;
  final Map<String, Definition> _definitions = {};
  final Map<String, Map<String, int>> _enumValues = {};
  final Map<String, Map<int, String>> _enumNames = {};

  CompiledSchema(this.schema) {
    for (var definition in schema.definitions) {
      _definitions[definition.name] = definition;

      if (definition.kind == DefinitionKind.ENUM) {
        Map<String, int> valueMap = {};
        Map<int, String> nameMap = {};
        for (var field in definition.fields) {
          valueMap[field.name] = field.value;
          nameMap[field.value] = field.name;
        }
        _enumValues[definition.name] = valueMap;
        _enumNames[definition.name] = nameMap;
      }
    }
  }

  /// Decodes a message of the given type.
  Map<String, dynamic> decode(String typeName, dynamic data) {
    ByteBuffer bb;
    if (data is ByteBuffer) {
      bb = data;
    } else if (data is Uint8List) {
      bb = ByteBuffer(data);
    } else {
      throw ArgumentError('Data must be a ByteBuffer or Uint8List');
    }

    var definition = _definitions[typeName];
    if (definition == null) {
      throw Exception('Unknown type: $typeName');
    }

    return _decodeDefinition(bb, definition);
  }

  /// Encodes a message of the given type.
  Uint8List encode(String typeName, Map<String, dynamic> message) {
    var definition = _definitions[typeName];
    if (definition == null) {
      throw Exception('Unknown type: $typeName');
    }

    ByteBuffer bb = ByteBuffer();
    _encodeDefinition(bb, definition, message);
    return bb.toUint8Array();
  }

  Map<String, dynamic> _decodeDefinition(ByteBuffer bb, Definition definition) {
    Map<String, dynamic> result = {};

    if (definition.kind == DefinitionKind.MESSAGE) {
      while (true) {
        int fieldId = bb.readVarUint();
        if (fieldId == 0) break;

        Field? field;
        for (var f in definition.fields) {
          if (f.value == fieldId) {
            field = f;
            break;
          }
        }

        if (field == null) {
          throw Exception('Attempted to parse invalid message');
        }

        var value = _decodeField(bb, field);
        if (!field.isDeprecated) {
          result[field.name] = value;
        }
      }
    } else {
      // STRUCT
      for (var field in definition.fields) {
        var value = _decodeField(bb, field);
        if (!field.isDeprecated) {
          result[field.name] = value;
        }
      }
    }

    return result;
  }

  dynamic _decodeField(ByteBuffer bb, Field field) {
    if (field.isArray) {
      if (field.type == 'byte') {
        return bb.readByteArray();
      }
      int length = bb.readVarUint();
      List<dynamic> values = [];
      for (int i = 0; i < length; i++) {
        values.add(_decodeValue(bb, field.type!));
      }
      return values;
    } else {
      return _decodeValue(bb, field.type!);
    }
  }

  dynamic _decodeValue(ByteBuffer bb, String type) {
    switch (type) {
      case 'bool':
        return bb.readByte() != 0;
      case 'byte':
        return bb.readByte();
      case 'int':
        return bb.readVarInt();
      case 'uint':
        return bb.readVarUint();
      case 'int64':
        return bb.readVarInt64();
      case 'uint64':
        return bb.readVarUint64();
      case 'float':
        return bb.readVarFloat();
      case 'string':
        return bb.readString();
      default:
        var definition = _definitions[type];
        if (definition == null) {
          throw Exception('Unknown type: $type');
        }
        if (definition.kind == DefinitionKind.ENUM) {
          int value = bb.readVarUint();
          return _enumNames[type]![value];
        } else {
          return _decodeDefinition(bb, definition);
        }
    }
  }

  void _encodeDefinition(
      ByteBuffer bb, Definition definition, Map<String, dynamic> message) {
    if (definition.kind == DefinitionKind.MESSAGE) {
      for (var field in definition.fields) {
        if (field.isDeprecated) continue;

        var value = message[field.name];
        if (value != null) {
          bb.writeVarUint(field.value);
          _encodeField(bb, field, value);
        }
      }
      bb.writeVarUint(0); // End of message
    } else {
      // STRUCT
      for (var field in definition.fields) {
        if (field.isDeprecated) continue;

        var value = message[field.name];
        if (value == null) {
          throw Exception('Missing required field "${field.name}"');
        }
        _encodeField(bb, field, value);
      }
    }
  }

  void _encodeField(ByteBuffer bb, Field field, dynamic value) {
    if (field.isArray) {
      if (field.type == 'byte') {
        bb.writeByteArray(value as Uint8List);
      } else {
        List<dynamic> values = value as List;
        bb.writeVarUint(values.length);
        for (var v in values) {
          _encodeValue(bb, field.type!, v);
        }
      }
    } else {
      _encodeValue(bb, field.type!, value);
    }
  }

  void _encodeValue(ByteBuffer bb, String type, dynamic value) {
    switch (type) {
      case 'bool':
        bb.writeByte(value == true ? 1 : 0);
        break;
      case 'byte':
        bb.writeByte(value as int);
        break;
      case 'int':
        bb.writeVarInt(value as int);
        break;
      case 'uint':
        bb.writeVarUint(value as int);
        break;
      case 'int64':
        bb.writeVarInt64(value as int);
        break;
      case 'uint64':
        bb.writeVarUint64(value as int);
        break;
      case 'float':
        bb.writeVarFloat(value as double);
        break;
      case 'string':
        bb.writeString(value as String);
        break;
      default:
        var definition = _definitions[type];
        if (definition == null) {
          throw Exception('Unknown type: $type');
        }
        if (definition.kind == DefinitionKind.ENUM) {
          var enumValue = _enumValues[type]![value];
          if (enumValue == null) {
            throw Exception('Invalid value "$value" for enum "$type"');
          }
          bb.writeVarUint(enumValue);
        } else {
          // Handle both Map<String, dynamic> and Map<dynamic, dynamic>
          Map<String, dynamic> mapValue;
          if (value is Map<String, dynamic>) {
            mapValue = value;
          } else if (value is Map) {
            mapValue = Map<String, dynamic>.from(value);
          } else {
            throw Exception('Expected a Map for type "$type"');
          }
          _encodeDefinition(bb, definition, mapValue);
        }
    }
  }

  /// Returns the enum value map for a given enum type.
  Map<String, int>? getEnumValues(String enumName) => _enumValues[enumName];

  /// Returns the enum name map for a given enum type.
  Map<int, String>? getEnumNames(String enumName) => _enumNames[enumName];
}

/// Compiles a schema from text.
CompiledSchema compileSchema(dynamic schemaOrText) {
  Schema schema;
  if (schemaOrText is String) {
    schema = parseSchema(schemaOrText);
  } else if (schemaOrText is Schema) {
    schema = schemaOrText;
  } else {
    throw ArgumentError('Expected a Schema or String');
  }
  return CompiledSchema(schema);
}
