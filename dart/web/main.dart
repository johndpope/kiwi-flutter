import 'dart:html';
import 'dart:convert';
import 'dart:typed_data';
import 'package:kiwi_schema/kiwi.dart';

TextAreaElement? jsonElement;
TextAreaElement? binaryElement;
TextAreaElement? schemaElement;
TextAreaElement? logElement;

void main() {
  jsonElement = querySelector('#json') as TextAreaElement?;
  binaryElement = querySelector('#binary') as TextAreaElement?;
  schemaElement = querySelector('#schema') as TextAreaElement?;
  logElement = querySelector('#log') as TextAreaElement?;

  jsonElement?.onFocus.listen((_) => update());
  jsonElement?.onInput.listen((_) => update());
  binaryElement?.onFocus.listen((_) => update());
  binaryElement?.onInput.listen((_) => update());
  schemaElement?.onFocus.listen((_) => update());
  schemaElement?.onInput.listen((_) => update());

  update();
}

String toHex(Uint8List value) {
  return value.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
}

Uint8List fromHex(String value) {
  var parts = value.trim().split(RegExp(r'[\s,]+'));
  if (parts.length == 1 && parts[0].isEmpty) {
    return Uint8List(0);
  }
  return Uint8List.fromList(
    parts.map((x) => int.parse(x, radix: 16)).toList(),
  );
}

String? findLastMessageOrStruct(String schemaText) {
  final regex = RegExp(r'\b(?:message|struct)\s+(\w+)\b');
  String? lastName;
  for (var match in regex.allMatches(schemaText)) {
    lastName = match.group(1);
  }
  return lastName;
}

void update() {
  try {
    var compiled = compileSchema(schemaElement?.value ?? '');
    var name = findLastMessageOrStruct(schemaElement?.value ?? '');

    if (name == null) {
      throw Exception('No message or struct found');
    }

    if (document.activeElement == jsonElement) {
      var jsonData = json.decode(jsonElement?.value ?? '{}') as Map<String, dynamic>;
      var encoded = compiled.encode(name, jsonData);
      binaryElement?.value = '${toHex(encoded)}\n';
    } else if (document.activeElement == binaryElement) {
      var decoded = compiled.decode(name, fromHex(binaryElement?.value ?? ''));
      jsonElement?.value = '${const JsonEncoder.withIndent('  ').convert(decoded)}\n';
    }

    logElement?.value = 'Success';
  } catch (e, stack) {
    logElement?.value = '$e\n$stack';
  }
}
