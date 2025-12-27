import 'schema.dart';

/// Pretty-prints a schema back to text format.
String prettyPrintSchema(Schema schema) {
  var definitions = schema.definitions;
  StringBuffer text = StringBuffer();

  if (schema.package != null) {
    text.write('package ${schema.package};\n');
  }

  for (int i = 0; i < definitions.length; i++) {
    var definition = definitions[i];
    if (i > 0 || schema.package != null) text.write('\n');
    text.write('${definition.kind.name.toLowerCase()} ${definition.name} {\n');

    for (var field in definition.fields) {
      text.write('  ');
      if (definition.kind != DefinitionKind.ENUM) {
        text.write(field.type);
        if (field.isArray) {
          text.write('[]');
        }
        text.write(' ');
      }
      text.write(field.name);
      if (definition.kind != DefinitionKind.STRUCT) {
        text.write(' = ${field.value}');
      }
      if (field.isDeprecated) {
        text.write(' [deprecated]');
      }
      text.write(';\n');
    }

    text.write('}\n');
  }

  return text.toString();
}
