import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  runApp(const KiwiDemoApp());
}

class KiwiDemoApp extends StatelessWidget {
  const KiwiDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiwi File Format Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const KiwiDemoPage(),
    );
  }
}

class KiwiDemoPage extends StatefulWidget {
  const KiwiDemoPage({super.key});

  @override
  State<KiwiDemoPage> createState() => _KiwiDemoPageState();
}

class _KiwiDemoPageState extends State<KiwiDemoPage> {
  final TextEditingController _jsonController = TextEditingController();
  final TextEditingController _binaryController = TextEditingController();
  final TextEditingController _schemaController = TextEditingController();
  final TextEditingController _logController = TextEditingController();

  final FocusNode _jsonFocus = FocusNode();
  final FocusNode _binaryFocus = FocusNode();
  final FocusNode _schemaFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    _jsonController.text = '''{
  "clientID": 100,
  "type": "POINTED",
  "colors": [
    {
      "red": 255,
      "green": 127,
      "blue": 0,
      "alpha": 255
    }
  ]
}''';

    _schemaController.text = '''enum Type {
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
}''';

    _jsonFocus.addListener(_onFocusChange);
    _binaryFocus.addListener(_onFocusChange);
    _schemaFocus.addListener(_onFocusChange);

    // Initial update
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _binaryController.dispose();
    _schemaController.dispose();
    _logController.dispose();
    _jsonFocus.dispose();
    _binaryFocus.dispose();
    _schemaFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _update();
  }

  String _toHex(Uint8List value) {
    return value.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  Uint8List _fromHex(String value) {
    var parts = value.trim().split(RegExp(r'[\s,]+'));
    if (parts.length == 1 && parts[0].isEmpty) {
      return Uint8List(0);
    }
    return Uint8List.fromList(
      parts.map((x) => int.parse(x, radix: 16)).toList(),
    );
  }

  String? _findLastMessageOrStruct(String schemaText) {
    // Find the last message or struct name
    final regex = RegExp(r'\b(?:message|struct)\s+(\w+)\b');
    String? lastName;
    for (var match in regex.allMatches(schemaText)) {
      lastName = match.group(1);
    }
    return lastName;
  }

  void _update() {
    try {
      var compiled = compileSchema(_schemaController.text);
      var name = _findLastMessageOrStruct(_schemaController.text);

      if (name == null) {
        throw Exception('No message or struct found');
      }

      if (_jsonFocus.hasFocus) {
        var jsonData = json.decode(_jsonController.text) as Map<String, dynamic>;
        var encoded = compiled.encode(name, jsonData);
        _binaryController.text = '${_toHex(encoded)}\n';
      } else if (_binaryFocus.hasFocus) {
        var decoded = compiled.decode(name, _fromHex(_binaryController.text));
        _jsonController.text = '${const JsonEncoder.withIndent('  ').convert(decoded)}\n';
      }

      _logController.text = 'Success';
    } catch (e, stack) {
      _logController.text = '$e\n$stack';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiwi File Format Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'See https://github.com/evanw/kiwi for more information.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSection(
                    'JSON',
                    _jsonController,
                    _jsonFocus,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSection(
                    'Binary',
                    _binaryController,
                    _binaryFocus,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSection(
                    'Schema',
                    _schemaController,
                    _schemaFocus,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSection(
                    'Log',
                    _logController,
                    null,
                    readOnly: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    TextEditingController controller,
    FocusNode? focusNode, {
    bool readOnly = false,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            autofocus: autofocus,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => _update(),
          ),
        ),
      ],
    );
  }
}
