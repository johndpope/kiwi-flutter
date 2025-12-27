import 'schema.dart';

/// Native types supported by Kiwi.
const List<String> nativeTypes = [
  'bool',
  'byte',
  'float',
  'int',
  'string',
  'uint',
];

/// Reserved names that cannot be used as type names.
const List<String> reservedNames = [
  'ByteBuffer',
  'package',
];

/// Represents a token from the lexer.
class _Token {
  final String text;
  final int line;
  final int column;

  _Token(this.text, this.line, this.column);
}

/// Throws a parsing error with location information.
Never _error(String message, int line, int column) {
  throw FormatException('$message at line $line, column $column');
}

/// Quotes a string for error messages.
String _quote(String text) {
  return '"$text"';
}

/// Tokenizes the schema text into a list of tokens.
List<_Token> _tokenize(String text) {
  final regex = RegExp(
      r'((?:-|\b)\d+\b|[=;{}]|\[\]|\[deprecated\]|\b[A-Za-z_][A-Za-z0-9_]*\b|//.*|\s+)');
  final whitespace = RegExp(r'^//.*|\s+$');

  List<_Token> tokens = [];
  int column = 0;
  int line = 0;

  // Split by the regex, keeping matches
  List<String> parts = [];
  int lastEnd = 0;
  for (var match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      parts.add(text.substring(lastEnd, match.start));
      parts.add(match.group(0)!);
    } else {
      if (parts.isEmpty || parts.length % 2 == 0) {
        parts.add(text.substring(lastEnd, match.start));
      }
      parts.add(match.group(0)!);
    }
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    parts.add(text.substring(lastEnd));
  }

  // Rebuild parts array similar to JS split with capturing group
  parts = [];
  lastEnd = 0;
  for (var match in regex.allMatches(text)) {
    parts.add(text.substring(lastEnd, match.start));
    parts.add(match.group(0)!);
    lastEnd = match.end;
  }
  parts.add(text.substring(lastEnd));

  for (int i = 0; i < parts.length; i++) {
    String part = parts[i];

    // Keep non-whitespace tokens (odd indices are regex matches)
    if (i % 2 == 1) {
      if (!whitespace.hasMatch(part)) {
        tokens.add(_Token(part, line + 1, column + 1));
      }
    }
    // Detect syntax errors (even indices should be empty)
    else if (part.isNotEmpty) {
      _error('Syntax error ${_quote(part)}', line + 1, column + 1);
    }

    // Keep track of line and column counts
    List<String> lines = part.split('\n');
    if (lines.length > 1) column = 0;
    line += lines.length - 1;
    column += lines.last.length;
  }

  // End-of-file token
  tokens.add(_Token('', line, column));

  return tokens;
}

/// Parses a list of tokens into a Schema.
Schema _parse(List<_Token> tokens) {
  int index = 0;

  _Token current() => tokens[index];

  bool eat(RegExp test) {
    if (test.hasMatch(current().text)) {
      index++;
      return true;
    }
    return false;
  }

  void expect(RegExp test, String expected) {
    if (!eat(test)) {
      var token = current();
      _error('Expected $expected but found ${_quote(token.text)}', token.line,
          token.column);
    }
  }

  Never unexpectedToken() {
    var token = current();
    _error('Unexpected token ${_quote(token.text)}', token.line, token.column);
  }

  // Regex patterns
  final identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  final endOfFile = RegExp(r'^$');
  final semicolon = RegExp(r'^;$');
  final integer = RegExp(r'^-?\d+$');
  final leftBrace = RegExp(r'^\{$');
  final rightBrace = RegExp(r'^\}$');
  final arrayToken = RegExp(r'^\[\]$');
  final enumKeyword = RegExp(r'^enum$');
  final structKeyword = RegExp(r'^struct$');
  final messageKeyword = RegExp(r'^message$');
  final packageKeyword = RegExp(r'^package$');
  final deprecatedToken = RegExp(r'^\[deprecated\]$');
  final equals = RegExp(r'^=$');

  List<Definition> definitions = [];
  String? packageText;

  if (eat(packageKeyword)) {
    packageText = current().text;
    expect(identifier, 'identifier');
    expect(semicolon, '";"');
  }

  while (index < tokens.length && !eat(endOfFile)) {
    List<Field> fields = [];
    DefinitionKind kind;

    if (eat(enumKeyword)) {
      kind = DefinitionKind.ENUM;
    } else if (eat(structKeyword)) {
      kind = DefinitionKind.STRUCT;
    } else if (eat(messageKeyword)) {
      kind = DefinitionKind.MESSAGE;
    } else {
      unexpectedToken();
    }

    // All definitions start off the same
    var name = current();
    expect(identifier, 'identifier');
    expect(leftBrace, '"{"');

    // Parse fields
    while (!eat(rightBrace)) {
      String? type;
      bool isArray = false;
      bool isDeprecated = false;

      // Enums don't have types
      if (kind != DefinitionKind.ENUM) {
        type = current().text;
        expect(identifier, 'identifier');
        isArray = eat(arrayToken);
      }

      var field = current();
      expect(identifier, 'identifier');

      // Structs don't have explicit values
      _Token? value;
      if (kind != DefinitionKind.STRUCT) {
        expect(equals, '"="');
        value = current();
        expect(integer, 'integer');

        int parsed = int.parse(value.text);
        if (parsed.toString() != value.text) {
          _error('Invalid integer ${_quote(value.text)}', value.line,
              value.column);
        }
      }

      var deprecated = current();
      if (eat(deprecatedToken)) {
        if (kind != DefinitionKind.MESSAGE) {
          _error('Cannot deprecate this field', deprecated.line,
              deprecated.column);
        }
        isDeprecated = true;
      }

      expect(semicolon, '";"');

      fields.add(Field(
        name: field.text,
        line: field.line,
        column: field.column,
        type: type,
        isArray: isArray,
        isDeprecated: isDeprecated,
        value: value != null ? int.parse(value.text) : fields.length + 1,
      ));
    }

    definitions.add(Definition(
      name: name.text,
      line: name.line,
      column: name.column,
      kind: kind,
      fields: fields,
    ));
  }

  return Schema(
    package: packageText,
    definitions: definitions,
  );
}

/// Verifies the schema for correctness.
void _verify(Schema root) {
  List<String> definedTypes = List.from(nativeTypes);
  Map<String, Definition> definitions = {};

  // Define definitions
  for (var definition in root.definitions) {
    if (definedTypes.contains(definition.name)) {
      _error('The type ${_quote(definition.name)} is defined twice',
          definition.line, definition.column);
    }
    if (reservedNames.contains(definition.name)) {
      _error('The type name ${_quote(definition.name)} is reserved',
          definition.line, definition.column);
    }
    definedTypes.add(definition.name);
    definitions[definition.name] = definition;
  }

  // Check fields
  for (var definition in root.definitions) {
    var fields = definition.fields;

    if (definition.kind == DefinitionKind.ENUM || fields.isEmpty) {
      continue;
    }

    // Check types
    for (var field in fields) {
      if (!definedTypes.contains(field.type)) {
        _error(
            'The type ${_quote(field.type!)} is not defined for field ${_quote(field.name)}',
            field.line,
            field.column);
      }
    }

    // Check values
    List<int> values = [];
    for (var field in fields) {
      if (values.contains(field.value)) {
        _error('The id for field ${_quote(field.name)} is used twice',
            field.line, field.column);
      }
      if (field.value <= 0) {
        _error('The id for field ${_quote(field.name)} must be positive',
            field.line, field.column);
      }
      if (field.value > fields.length) {
        _error(
            'The id for field ${_quote(field.name)} cannot be larger than ${fields.length}',
            field.line,
            field.column);
      }
      values.add(field.value);
    }
  }

  // Check that structs don't contain themselves
  Map<String, int> state = {};

  void check(String name) {
    var definition = definitions[name];
    if (definition != null && definition.kind == DefinitionKind.STRUCT) {
      if (state[name] == 1) {
        _error('Recursive nesting of ${_quote(name)} is not allowed',
            definition.line, definition.column);
      }
      if (state[name] != 2) {
        state[name] = 1;
        var fields = definition.fields;
        for (var field in fields) {
          if (!field.isArray) {
            check(field.type!);
          }
        }
        state[name] = 2;
      }
    }
  }

  for (var definition in root.definitions) {
    check(definition.name);
  }
}

/// Parses a Kiwi schema from text.
Schema parseSchema(String text) {
  var schema = _parse(_tokenize(text));
  _verify(schema);
  return schema;
}
