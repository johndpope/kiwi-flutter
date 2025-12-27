/// Definition kinds for Kiwi schema.
enum DefinitionKind {
  ENUM,
  STRUCT,
  MESSAGE,
}

/// Represents a field in a definition.
class Field {
  final String name;
  final int line;
  final int column;
  String? type;
  final bool isArray;
  final bool isDeprecated;
  final int value;

  Field({
    required this.name,
    this.line = 0,
    this.column = 0,
    this.type,
    this.isArray = false,
    this.isDeprecated = false,
    required this.value,
  });

  Field copyWith({
    String? name,
    int? line,
    int? column,
    String? type,
    bool? isArray,
    bool? isDeprecated,
    int? value,
  }) {
    return Field(
      name: name ?? this.name,
      line: line ?? this.line,
      column: column ?? this.column,
      type: type ?? this.type,
      isArray: isArray ?? this.isArray,
      isDeprecated: isDeprecated ?? this.isDeprecated,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'line': line,
        'column': column,
        'type': type,
        'isArray': isArray,
        'isDeprecated': isDeprecated,
        'value': value,
      };
}

/// Represents a definition (enum, struct, or message) in the schema.
class Definition {
  final String name;
  final int line;
  final int column;
  final DefinitionKind kind;
  final List<Field> fields;

  Definition({
    required this.name,
    this.line = 0,
    this.column = 0,
    required this.kind,
    required this.fields,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'line': line,
        'column': column,
        'kind': kind.name,
        'fields': fields.map((f) => f.toJson()).toList(),
      };
}

/// Represents a parsed Kiwi schema.
class Schema {
  final String? package;
  final List<Definition> definitions;

  Schema({
    this.package,
    required this.definitions,
  });

  Map<String, dynamic> toJson() => {
        'package': package,
        'definitions': definitions.map((d) => d.toJson()).toList(),
      };
}
