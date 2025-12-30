/// Simple test to verify font rendering works
///
/// Run with: flutter test test/debug_simple_text_test.dart --update-goldens

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('simple text render', (tester) async {
    final testKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: testKey,
          child: Container(
            width: 400,
            height: 200,
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Hello World - 17pt',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Red Text - 12pt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFFFF382B), // RGB(255,56,43)
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Gray Text - 11pt',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF8E8E93), // RGB(142,142,147)
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Tiny Text - 5pt (0.5 scale of 10pt)',
                  style: TextStyle(
                    fontSize: 5,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(testKey),
      matchesGoldenFile('goldens/debug_simple_text.png'),
    );
  });
}
