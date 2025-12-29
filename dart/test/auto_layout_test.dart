/// Auto layout tests
///
/// Tests for:
/// - Data model parsing
/// - Flow rendering (Column/Row/Wrap/Grid)
/// - Alignment and spacing
/// - Resizing behaviors
/// - Absolute positioning
/// - Constraint handling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  group('AutoLayoutConfig', () {
    test('parses vertical flow', () {
      final node = {
        'stackMode': 'VERTICAL',
        'itemSpacing': 10.0,
      };

      final config = AutoLayoutConfig.fromNode(node);

      expect(config.flow, AutoLayoutFlow.vertical);
      expect(config.isVertical, true);
      expect(config.isHorizontal, false);
      expect(config.itemSpacing, 10.0);
    });

    test('parses horizontal flow', () {
      final node = {
        'stackMode': 'HORIZONTAL',
        'itemSpacing': 20.0,
      };

      final config = AutoLayoutConfig.fromNode(node);

      expect(config.flow, AutoLayoutFlow.horizontal);
      expect(config.isHorizontal, true);
      expect(config.isVertical, false);
      expect(config.itemSpacing, 20.0);
    });

    test('parses wrap flow', () {
      final node = {
        'stackMode': 'HORIZONTAL',
        'layoutWrap': 'WRAP',
      };

      final config = AutoLayoutConfig.fromNode(node);

      expect(config.flow, AutoLayoutFlow.wrap);
      expect(config.wrapEnabled, true);
    });

    test('parses grid flow', () {
      final node = {
        'stackMode': 'GRID',
        'gridColumns': 3,
        'gridRowGap': 10.0,
        'gridColumnGap': 15.0,
      };

      final config = AutoLayoutConfig.fromNode(node);

      expect(config.flow, AutoLayoutFlow.grid);
      expect(config.isGrid, true);
      expect(config.gridConfig?.columns, 3);
      expect(config.gridConfig?.rowGap, 10.0);
      expect(config.gridConfig?.columnGap, 15.0);
    });

    test('parses padding', () {
      final node = {
        'stackMode': 'VERTICAL',
        'stackPaddingTop': 10.0,
        'stackPaddingRight': 20.0,
        'stackPaddingBottom': 30.0,
        'stackPaddingLeft': 40.0,
      };

      final config = AutoLayoutConfig.fromNode(node);

      expect(config.padding.top, 10.0);
      expect(config.padding.right, 20.0);
      expect(config.padding.bottom, 30.0);
      expect(config.padding.left, 40.0);
    });

    test('parses main axis alignment', () {
      final testCases = [
        ('MIN', AutoLayoutMainAxisAlign.start),
        ('CENTER', AutoLayoutMainAxisAlign.center),
        ('MAX', AutoLayoutMainAxisAlign.end),
        ('SPACE_BETWEEN', AutoLayoutMainAxisAlign.spaceBetween),
      ];

      for (final (value, expected) in testCases) {
        final node = {
          'stackMode': 'VERTICAL',
          'stackPrimaryAlignItems': value,
        };
        final config = AutoLayoutConfig.fromNode(node);
        expect(config.mainAxisAlign, expected,
            reason: 'Expected $expected for $value');
      }
    });

    test('parses cross axis alignment', () {
      final testCases = [
        ('MIN', AutoLayoutCrossAxisAlign.start),
        ('CENTER', AutoLayoutCrossAxisAlign.center),
        ('MAX', AutoLayoutCrossAxisAlign.end),
        ('STRETCH', AutoLayoutCrossAxisAlign.stretch),
        ('BASELINE', AutoLayoutCrossAxisAlign.baseline),
      ];

      for (final (value, expected) in testCases) {
        final node = {
          'stackMode': 'VERTICAL',
          'stackCounterAlignItems': value,
        };
        final config = AutoLayoutConfig.fromNode(node);
        expect(config.crossAxisAlign, expected,
            reason: 'Expected $expected for $value');
      }
    });

    test('converts to Flutter MainAxisAlignment', () {
      expect(
        AutoLayoutConfig(mainAxisAlign: AutoLayoutMainAxisAlign.start)
            .flutterMainAxisAlignment,
        MainAxisAlignment.start,
      );
      expect(
        AutoLayoutConfig(mainAxisAlign: AutoLayoutMainAxisAlign.center)
            .flutterMainAxisAlignment,
        MainAxisAlignment.center,
      );
      expect(
        AutoLayoutConfig(mainAxisAlign: AutoLayoutMainAxisAlign.end)
            .flutterMainAxisAlignment,
        MainAxisAlignment.end,
      );
      expect(
        AutoLayoutConfig(mainAxisAlign: AutoLayoutMainAxisAlign.spaceBetween)
            .flutterMainAxisAlignment,
        MainAxisAlignment.spaceBetween,
      );
    });

    test('converts to Flutter CrossAxisAlignment', () {
      expect(
        AutoLayoutConfig(crossAxisAlign: AutoLayoutCrossAxisAlign.start)
            .flutterCrossAxisAlignment,
        CrossAxisAlignment.start,
      );
      expect(
        AutoLayoutConfig(crossAxisAlign: AutoLayoutCrossAxisAlign.center)
            .flutterCrossAxisAlignment,
        CrossAxisAlignment.center,
      );
      expect(
        AutoLayoutConfig(crossAxisAlign: AutoLayoutCrossAxisAlign.stretch)
            .flutterCrossAxisAlignment,
        CrossAxisAlignment.stretch,
      );
    });

    test('copyWith creates modified copy', () {
      const original = AutoLayoutConfig(
        flow: AutoLayoutFlow.vertical,
        itemSpacing: 10,
      );

      final modified = original.copyWith(
        flow: AutoLayoutFlow.horizontal,
        itemSpacing: 20,
      );

      expect(modified.flow, AutoLayoutFlow.horizontal);
      expect(modified.itemSpacing, 20);
      // Original unchanged
      expect(original.flow, AutoLayoutFlow.vertical);
      expect(original.itemSpacing, 10);
    });

    test('toNodeProperties serializes correctly', () {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.vertical,
        itemSpacing: 15,
        mainAxisAlign: AutoLayoutMainAxisAlign.center,
        crossAxisAlign: AutoLayoutCrossAxisAlign.stretch,
        padding: AutoLayoutPadding(
          top: 10,
          right: 10,
          bottom: 10,
          left: 10,
        ),
      );

      final props = config.toNodeProperties();

      expect(props['stackMode'], 'VERTICAL');
      expect(props['itemSpacing'], 15);
      expect(props['stackPrimaryAlignItems'], 'CENTER');
      expect(props['stackCounterAlignItems'], 'STRETCH');
      expect(props['stackPaddingTop'], 10);
    });
  });

  group('AutoLayoutPadding', () {
    test('creates uniform padding', () {
      const padding = AutoLayoutPadding.all(10);

      expect(padding.top, 10);
      expect(padding.right, 10);
      expect(padding.bottom, 10);
      expect(padding.left, 10);
      expect(padding.isUniform, true);
    });

    test('creates symmetric padding', () {
      const padding = AutoLayoutPadding.symmetric(
        horizontal: 20,
        vertical: 10,
      );

      expect(padding.top, 10);
      expect(padding.bottom, 10);
      expect(padding.left, 20);
      expect(padding.right, 20);
      expect(padding.isSymmetric, true);
    });

    test('converts to EdgeInsets with scale', () {
      const padding = AutoLayoutPadding(
        top: 10,
        right: 20,
        bottom: 30,
        left: 40,
      );

      final edgeInsets = padding.toEdgeInsets(2.0);

      expect(edgeInsets.top, 20);
      expect(edgeInsets.right, 40);
      expect(edgeInsets.bottom, 60);
      expect(edgeInsets.left, 80);
    });

    test('detects zero padding', () {
      const zeroPadding = AutoLayoutPadding();
      const nonZeroPadding = AutoLayoutPadding(top: 1);

      expect(zeroPadding.isZero, true);
      expect(nonZeroPadding.isZero, false);
    });
  });

  group('AutoLayoutConstraints', () {
    test('parses constraints from node', () {
      final node = {
        'minWidth': 100.0,
        'maxWidth': 500.0,
        'minHeight': 50.0,
        'maxHeight': 200.0,
      };

      final constraints = AutoLayoutConstraints.fromNode(node);

      expect(constraints.minWidth, 100);
      expect(constraints.maxWidth, 500);
      expect(constraints.minHeight, 50);
      expect(constraints.maxHeight, 200);
      expect(constraints.hasConstraints, true);
    });

    test('converts to BoxConstraints', () {
      const constraints = AutoLayoutConstraints(
        minWidth: 100,
        maxWidth: 500,
      );

      final boxConstraints = constraints.toBoxConstraints();

      expect(boxConstraints.minWidth, 100);
      expect(boxConstraints.maxWidth, 500);
      expect(boxConstraints.minHeight, 0);
      expect(boxConstraints.maxHeight, double.infinity);
    });

    test('hasConstraints returns false for empty', () {
      const constraints = AutoLayoutConstraints();
      expect(constraints.hasConstraints, false);
    });
  });

  group('AutoLayoutChildConfig', () {
    test('parses fill sizing', () {
      final node = {
        'layoutSizingHorizontal': 'FILL',
        'layoutSizingVertical': 'HUG',
      };

      final config = AutoLayoutChildConfig.fromNode(node);

      expect(config.widthSizing, AutoLayoutSizing.fill);
      expect(config.heightSizing, AutoLayoutSizing.hug);
      expect(config.isFillWidth, true);
      expect(config.isFillHeight, false);
    });

    test('parses absolute positioning', () {
      final node = {
        'layoutPositioning': 'ABSOLUTE',
        'x': 100.0,
        'y': 50.0,
        'constraints': {
          'horizontal': 'LEFT',
          'vertical': 'TOP',
        },
      };

      final config = AutoLayoutChildConfig.fromNode(node);

      expect(config.isAbsolute, true);
      expect(config.absoluteLeft, 100.0);
      expect(config.absoluteTop, 50.0);
    });

    test('parses flow positioning (default)', () {
      final node = <String, dynamic>{};

      final config = AutoLayoutChildConfig.fromNode(node);

      expect(config.isAbsolute, false);
    });
  });

  group('AutoLayoutRenderer', () {
    testWidgets('builds Column for vertical flow', (tester) async {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.vertical,
        itemSpacing: 10,
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: [
          Container(width: 100, height: 50, color: Colors.red),
          Container(width: 100, height: 50, color: Colors.blue),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('builds Row for horizontal flow', (tester) async {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.horizontal,
        itemSpacing: 10,
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: [
          Container(width: 50, height: 100, color: Colors.red),
          Container(width: 50, height: 100, color: Colors.blue),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('builds Wrap for wrap flow', (tester) async {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.wrap,
        itemSpacing: 10,
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: [
          Container(width: 50, height: 50, color: Colors.red),
          Container(width: 50, height: 50, color: Colors.blue),
          Container(width: 50, height: 50, color: Colors.green),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('builds GridView for grid flow', (tester) async {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.grid,
        gridConfig: AutoLayoutGridConfig(columns: 2),
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: [
          Container(color: Colors.red),
          Container(color: Colors.blue),
          Container(color: Colors.green),
          Container(color: Colors.yellow),
        ],
        frameSize: const Size(200, 200),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 200, height: 200, child: widget),
        ),
      ));

      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('applies padding', (tester) async {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.vertical,
        padding: AutoLayoutPadding.all(20),
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: [
          Container(width: 100, height: 50, color: Colors.red),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.byType(Padding), findsOneWidget);

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(padding.padding, const EdgeInsets.all(20));
    });

    testWidgets('overlays absolute children', (tester) async {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.vertical,
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: [
          Container(width: 100, height: 50, color: Colors.red),
        ],
        absoluteChildren: [
          Positioned(
            top: 10,
            left: 10,
            child: Container(width: 30, height: 30, color: Colors.yellow),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Should have at least one Stack for the absolute overlay
      expect(find.byType(Stack), findsWidgets);
      expect(find.byType(Positioned), findsOneWidget);
    });

    testWidgets('clips content when enabled', (tester) async {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.vertical,
        clipContent: true,
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: [
          Container(width: 100, height: 50, color: Colors.red),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.byType(ClipRect), findsOneWidget);
    });
  });

  group('AutoLayoutRenderer.wrapChild', () {
    testWidgets('wraps fill child with Expanded in Row', (tester) async {
      const parentConfig = AutoLayoutConfig(flow: AutoLayoutFlow.horizontal);
      const childConfig = AutoLayoutChildConfig(
        widthSizing: AutoLayoutSizing.fill,
      );

      final wrapped = AutoLayoutRenderer.wrapChild(
        child: Container(color: Colors.red),
        childConfig: childConfig,
        parentConfig: parentConfig,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(children: [wrapped]),
        ),
      ));

      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('wraps fill child with Expanded in Column', (tester) async {
      const parentConfig = AutoLayoutConfig(flow: AutoLayoutFlow.vertical);
      const childConfig = AutoLayoutChildConfig(
        heightSizing: AutoLayoutSizing.fill,
      );

      final wrapped = AutoLayoutRenderer.wrapChild(
        child: Container(color: Colors.blue),
        childConfig: childConfig,
        parentConfig: parentConfig,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [wrapped]),
        ),
      ));

      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('applies fixed size', (tester) async {
      const parentConfig = AutoLayoutConfig(flow: AutoLayoutFlow.horizontal);
      const childConfig = AutoLayoutChildConfig(
        widthSizing: AutoLayoutSizing.fixed,
        fixedWidth: 100,
        heightSizing: AutoLayoutSizing.fixed,
        fixedHeight: 50,
      );

      final wrapped = AutoLayoutRenderer.wrapChild(
        child: Container(color: Colors.green),
        childConfig: childConfig,
        parentConfig: parentConfig,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(children: [wrapped]),
        ),
      ));

      expect(find.byType(SizedBox), findsOneWidget);
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 100);
      expect(sizedBox.height, 50);
    });
  });

  group('AutoLayoutWidget', () {
    testWidgets('renders with decoration', (tester) async {
      const config = AutoLayoutConfig(flow: AutoLayoutFlow.vertical);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AutoLayoutWidget(
            config: config,
            flowChildren: [
              Container(width: 100, height: 50, color: Colors.red),
            ],
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black),
            ),
          ),
        ),
      ));

      expect(find.byType(DecoratedBox), findsOneWidget);
    });
  });

  group('Node extension', () {
    test('hasAutoLayout returns true for auto layout nodes', () {
      final node = {'stackMode': 'VERTICAL'};
      expect(node.hasAutoLayout, true);
    });

    test('hasAutoLayout returns false for non-auto layout nodes', () {
      final node = {'stackMode': 'NONE'};
      expect(node.hasAutoLayout, false);
    });

    test('hasAutoLayout returns false for nodes without stackMode', () {
      final node = <String, dynamic>{};
      expect(node.hasAutoLayout, false);
    });

    test('autoLayoutConfig returns parsed config', () {
      final node = {
        'stackMode': 'HORIZONTAL',
        'itemSpacing': 15.0,
      };

      final config = node.autoLayoutConfig;

      expect(config.flow, AutoLayoutFlow.horizontal);
      expect(config.itemSpacing, 15.0);
    });
  });

  group('Edge cases', () {
    test('handles empty flow with no children', () {
      const config = AutoLayoutConfig(flow: AutoLayoutFlow.vertical);
      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(flowChildren: []);

      expect(widget, isA<Widget>());
    });

    test('handles negative spacing', () {
      final node = {
        'stackMode': 'HORIZONTAL',
        'itemSpacing': -5.0,
      };

      final config = AutoLayoutConfig.fromNode(node);
      expect(config.itemSpacing, -5.0);
    });

    test('handles large number of children', () {
      const config = AutoLayoutConfig(
        flow: AutoLayoutFlow.vertical,
        itemSpacing: 2,
      );

      final renderer = AutoLayoutRenderer(config: config);
      final widget = renderer.build(
        flowChildren: List.generate(
          100,
          (i) => Container(height: 10, color: Colors.primaries[i % Colors.primaries.length]),
        ),
      );

      expect(widget, isA<Widget>());
    });

    test('handles deeply nested configs', () {
      const parentConfig = AutoLayoutConfig(flow: AutoLayoutFlow.vertical);
      const childConfig = AutoLayoutConfig(flow: AutoLayoutFlow.horizontal);

      // Nested auto layouts should work
      final renderer = AutoLayoutRenderer(config: parentConfig);
      final childRenderer = AutoLayoutRenderer(config: childConfig);

      final innerWidget = childRenderer.build(
        flowChildren: [
          Container(color: Colors.red),
          Container(color: Colors.blue),
        ],
      );

      final outerWidget = renderer.build(
        flowChildren: [
          innerWidget,
          Container(color: Colors.green),
        ],
      );

      expect(outerWidget, isA<Widget>());
    });
  });

  group('GridConfig', () {
    test('parses grid configuration', () {
      final node = {
        'gridColumns': 4,
        'gridRows': 3,
        'gridColumnGap': 8.0,
        'gridRowGap': 12.0,
      };

      final config = AutoLayoutGridConfig.fromNode(node);

      expect(config.columns, 4);
      expect(config.rows, 3);
      expect(config.columnGap, 8.0);
      expect(config.rowGap, 12.0);
    });

    test('uses itemSpacing as fallback for gaps', () {
      final node = {
        'itemSpacing': 10.0,
      };

      final config = AutoLayoutGridConfig.fromNode(node);

      expect(config.columnGap, 10.0);
      expect(config.rowGap, 10.0);
    });
  });
}
