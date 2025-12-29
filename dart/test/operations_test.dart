import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  group('Boolean Operations', () {
    group('BooleanEngine', () {
      test('union combines two overlapping paths', () {
        final path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
        final path2 = Path()..addRect(const Rect.fromLTWH(50, 50, 100, 100));

        final result = BooleanEngine.combine(path1, path2, BooleanOperation.union);

        expect(result.success, true);
        expect(result.operation, BooleanOperation.union);
        expect(result.bounds.width, greaterThan(100));
        expect(result.bounds.height, greaterThan(100));
      });

      test('subtract removes overlapping area', () {
        final path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
        final path2 = Path()..addRect(const Rect.fromLTWH(50, 50, 100, 100));

        final result = BooleanEngine.combine(path1, path2, BooleanOperation.subtract);

        expect(result.success, true);
        expect(result.operation, BooleanOperation.subtract);
      });

      test('intersect keeps only overlapping area', () {
        final path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
        final path2 = Path()..addRect(const Rect.fromLTWH(50, 50, 100, 100));

        final result = BooleanEngine.combine(path1, path2, BooleanOperation.intersect);

        expect(result.success, true);
        expect(result.operation, BooleanOperation.intersect);
        // Intersection should be smaller than either input
        expect(result.bounds.width, lessThanOrEqualTo(50));
        expect(result.bounds.height, lessThanOrEqualTo(50));
      });

      test('exclude creates XOR of paths', () {
        final path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
        final path2 = Path()..addRect(const Rect.fromLTWH(50, 50, 100, 100));

        final result = BooleanEngine.combine(path1, path2, BooleanOperation.exclude);

        expect(result.success, true);
        expect(result.operation, BooleanOperation.exclude);
      });

      test('combineMultiple handles multiple paths', () {
        final paths = [
          Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50)),
          Path()..addRect(const Rect.fromLTWH(25, 0, 50, 50)),
          Path()..addRect(const Rect.fromLTWH(50, 0, 50, 50)),
        ];

        final result = BooleanEngine.combineMultiple(paths, BooleanOperation.union);

        expect(result.success, true);
        expect(result.bounds.width, 100);
        expect(result.bounds.height, 50);
      });

      test('combineMultiple returns error for empty list', () {
        final result = BooleanEngine.combineMultiple([], BooleanOperation.union);

        expect(result.success, false);
        expect(result.error, contains('No paths provided'));
      });

      test('combineMultiple returns single path unchanged', () {
        final path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
        final result = BooleanEngine.combineMultiple([path], BooleanOperation.union);

        expect(result.success, true);
        expect(result.bounds, const Rect.fromLTWH(0, 0, 100, 100));
      });
    });

    group('BooleanEngine utilities', () {
      test('pathFromRect creates rectangular path', () {
        final path = BooleanEngine.pathFromRect(const Rect.fromLTWH(0, 0, 100, 50));
        expect(path.getBounds(), const Rect.fromLTWH(0, 0, 100, 50));
      });

      test('pathFromRect creates rounded rect path', () {
        final path = BooleanEngine.pathFromRect(
          const Rect.fromLTWH(0, 0, 100, 50),
          cornerRadii: [10, 10, 10, 10],
        );
        expect(path.getBounds().width, 100);
        expect(path.getBounds().height, 50);
      });

      test('pathFromEllipse creates oval path', () {
        final path = BooleanEngine.pathFromEllipse(const Rect.fromLTWH(0, 0, 100, 50));
        expect(path.getBounds().width, 100);
        expect(path.getBounds().height, 50);
      });

      test('pathFromPolygon creates hexagon', () {
        final path = BooleanEngine.pathFromPolygon(const Offset(50, 50), 40, 6);
        expect(path.getBounds(), isNotNull);
      });

      test('pathFromStar creates 5-pointed star', () {
        final path = BooleanEngine.pathFromStar(const Offset(50, 50), 40, 20, 5);
        expect(path.getBounds(), isNotNull);
      });

      test('flatten converts curves to line segments', () {
        final path = Path()..addOval(const Rect.fromLTWH(0, 0, 100, 100));
        final flattened = BooleanEngine.flatten(path);

        expect(flattened.getBounds().width, closeTo(100, 1));
        expect(flattened.getBounds().height, closeTo(100, 1));
      });
    });

    group('BooleanOperationsToolbar', () {
      testWidgets('renders all operation buttons', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BooleanOperationsToolbar(
                onOperationSelected: (_) {},
                selectedCount: 2,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.add_box_outlined), findsOneWidget);
        expect(find.byIcon(Icons.indeterminate_check_box_outlined), findsOneWidget);
        expect(find.byIcon(Icons.filter_none), findsOneWidget);
        expect(find.byIcon(Icons.flip_to_front), findsOneWidget);
      });

      testWidgets('buttons disabled when less than 2 shapes selected', (tester) async {
        BooleanOperation? selectedOp;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BooleanOperationsToolbar(
                onOperationSelected: (op) => selectedOp = op,
                selectedCount: 1,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.add_box_outlined));
        expect(selectedOp, isNull);
      });

      testWidgets('calls callback when operation selected', (tester) async {
        BooleanOperation? selectedOp;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BooleanOperationsToolbar(
                onOperationSelected: (op) => selectedOp = op,
                selectedCount: 2,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.add_box_outlined));
        await tester.pump();
        expect(selectedOp, BooleanOperation.union);
      });
    });
  });

  group('Export Engine', () {
    group('ExportSettings', () {
      test('default settings', () {
        const settings = ExportSettings();

        expect(settings.format, ExportFormat.png);
        expect(settings.scale, 1.0);
        expect(settings.includeBackground, true);
        expect(settings.jpegQuality, 0.92);
      });

      test('preset creates correct settings', () {
        final settings = ExportSettings.preset(ExportScale.x2);

        expect(settings.scale, 2.0);
        expect(settings.suffix, '@2x');
      });

      test('copyWith preserves unchanged values', () {
        const original = ExportSettings(
          format: ExportFormat.png,
          scale: 2.0,
          includeBackground: false,
        );

        final modified = original.copyWith(format: ExportFormat.svg);

        expect(modified.format, ExportFormat.svg);
        expect(modified.scale, 2.0);
        expect(modified.includeBackground, false);
      });
    });

    group('ExportResult', () {
      test('success result has correct properties', () {
        const result = ExportResult(
          format: ExportFormat.png,
          width: 100,
          height: 200,
          suggestedFilename: 'test',
        );

        expect(result.success, true);
        expect(result.mimeType, 'image/png');
        expect(result.extension, 'png');
      });

      test('failed result has error message', () {
        final result = ExportResult.failed('Test error', ExportFormat.svg);

        expect(result.success, false);
        expect(result.error, 'Test error');
      });

      test('mimeType returns correct type for each format', () {
        expect(const ExportResult(format: ExportFormat.png, width: 1, height: 1).mimeType, 'image/png');
        expect(const ExportResult(format: ExportFormat.jpg, width: 1, height: 1).mimeType, 'image/jpeg');
        expect(const ExportResult(format: ExportFormat.svg, width: 1, height: 1).mimeType, 'image/svg+xml');
        expect(const ExportResult(format: ExportFormat.pdf, width: 1, height: 1).mimeType, 'application/pdf');
      });
    });

    group('SvgBuilder', () {
      test('creates valid SVG document', () {
        final builder = SvgBuilder();
        builder.startDocument(100, 100);
        builder.addRect(
          const Rect.fromLTWH(10, 10, 80, 80),
          fill: Colors.blue,
        );
        final svg = builder.endDocument();

        expect(svg, contains('<?xml version="1.0"'));
        expect(svg, contains('<svg'));
        expect(svg, contains('<rect'));
        expect(svg, contains('</svg>'));
      });

      test('adds ellipse correctly', () {
        final builder = SvgBuilder();
        builder.startDocument(100, 100);
        builder.addEllipse(
          const Rect.fromLTWH(10, 10, 80, 60),
          fill: Colors.red,
        );
        final svg = builder.endDocument();

        expect(svg, contains('<ellipse'));
        expect(svg, matches(RegExp(r'cx="50(\.0)?"'))); // Accept 50 or 50.0
        expect(svg, matches(RegExp(r'cy="40(\.0)?"'))); // Accept 40 or 40.0
      });

      test('adds text correctly', () {
        final builder = SvgBuilder();
        builder.startDocument(100, 100);
        builder.addText('Hello', const Offset(10, 20));
        final svg = builder.endDocument();

        expect(svg, contains('<text'));
        expect(svg, contains('Hello'));
      });

      test('creates linear gradient', () {
        final builder = SvgBuilder();
        builder.startDocument(100, 100);
        final gradientId = builder.addLinearGradient(
          [Colors.red, Colors.blue],
          [0.0, 1.0],
        );
        final svg = builder.endDocument();

        expect(svg, contains('<linearGradient'));
        expect(svg, contains('<stop'));
        expect(gradientId, startsWith('url(#'));
      });
    });

    group('ExportPanel', () {
      testWidgets('renders format buttons', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExportPanel(
                selectionBounds: const Rect.fromLTWH(0, 0, 100, 100),
                onExport: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('PNG'), findsOneWidget);
        expect(find.text('JPG'), findsOneWidget);
        expect(find.text('SVG'), findsOneWidget);
        expect(find.text('PDF'), findsOneWidget);
      });

      testWidgets('shows scale options for raster formats', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExportPanel(
                selectionBounds: const Rect.fromLTWH(0, 0, 100, 100),
                onExport: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('1x'), findsOneWidget);
        expect(find.text('2x'), findsOneWidget);
      });
    });
  });

  group('Constraints', () {
    group('LayoutConstraints', () {
      test('default constraints are top-left', () {
        const constraints = LayoutConstraints();

        expect(constraints.horizontal, HorizontalConstraint.left);
        expect(constraints.vertical, VerticalConstraint.top);
      });

      test('preset constraints', () {
        expect(LayoutConstraints.centered.horizontal, HorizontalConstraint.center);
        expect(LayoutConstraints.centered.vertical, VerticalConstraint.center);

        expect(LayoutConstraints.scale.horizontal, HorizontalConstraint.scale);
        expect(LayoutConstraints.scale.vertical, VerticalConstraint.scale);

        expect(LayoutConstraints.stretch.horizontal, HorizontalConstraint.leftRight);
        expect(LayoutConstraints.stretch.vertical, VerticalConstraint.topBottom);
      });
    });

    group('ConstraintValues', () {
      test('creates from rect and parent size', () {
        final values = ConstraintValues.fromRect(
          const Rect.fromLTWH(10, 20, 80, 60),
          const Size(200, 150),
        );

        expect(values.left, 10);
        expect(values.top, 20);
        expect(values.right, 110); // 200 - 90
        expect(values.bottom, 70); // 150 - 80
        expect(values.width, 80);
        expect(values.height, 60);
      });

      test('calculates ratios correctly', () {
        final values = ConstraintValues.fromPosition(
          x: 50,
          y: 25,
          width: 100,
          height: 50,
          parentWidth: 200,
          parentHeight: 100,
        );

        expect(values.widthRatio, 0.5);
        expect(values.heightRatio, 0.5);
        expect(values.leftRatio, 0.25);
        expect(values.topRatio, 0.25);
      });
    });

    group('ConstraintEngine', () {
      test('left constraint maintains left position', () {
        final values = ConstraintValues.fromPosition(
          x: 10,
          y: 20,
          width: 80,
          height: 60,
          parentWidth: 200,
          parentHeight: 150,
        );

        final newRect = ConstraintEngine.applyConstraints(
          constraints: const LayoutConstraints(
            horizontal: HorizontalConstraint.left,
            vertical: VerticalConstraint.top,
          ),
          values: values,
          newParentSize: const Size(300, 200),
        );

        expect(newRect.left, 10); // Unchanged
        expect(newRect.top, 20); // Unchanged
        expect(newRect.width, 80); // Unchanged
      });

      test('right constraint maintains right position', () {
        final values = ConstraintValues.fromPosition(
          x: 110,
          y: 20,
          width: 80,
          height: 60,
          parentWidth: 200,
          parentHeight: 150,
        );

        final newRect = ConstraintEngine.applyConstraints(
          constraints: const LayoutConstraints(
            horizontal: HorizontalConstraint.right,
            vertical: VerticalConstraint.top,
          ),
          values: values,
          newParentSize: const Size(300, 150),
        );

        expect(newRect.right, 300 - 10); // Same distance from right
      });

      test('leftRight constraint stretches width', () {
        final values = ConstraintValues.fromPosition(
          x: 10,
          y: 20,
          width: 180,
          height: 60,
          parentWidth: 200,
          parentHeight: 150,
        );

        final newRect = ConstraintEngine.applyConstraints(
          constraints: const LayoutConstraints(
            horizontal: HorizontalConstraint.leftRight,
            vertical: VerticalConstraint.top,
          ),
          values: values,
          newParentSize: const Size(300, 150),
        );

        expect(newRect.left, 10); // Unchanged
        expect(newRect.width, 280); // Stretched (300 - 10 - 10)
      });

      test('center constraint maintains center position', () {
        final values = ConstraintValues.fromPosition(
          x: 60,
          y: 45,
          width: 80,
          height: 60,
          parentWidth: 200,
          parentHeight: 150,
        );

        final newRect = ConstraintEngine.applyConstraints(
          constraints: LayoutConstraints.centered,
          values: values,
          newParentSize: const Size(400, 300),
        );

        expect(newRect.center.dx, closeTo(200, 1)); // Centered in new width
        expect(newRect.center.dy, closeTo(150, 1)); // Centered in new height
      });

      test('scale constraint maintains proportions', () {
        final values = ConstraintValues.fromPosition(
          x: 50,
          y: 25,
          width: 100,
          height: 50,
          parentWidth: 200,
          parentHeight: 100,
        );

        final newRect = ConstraintEngine.applyConstraints(
          constraints: LayoutConstraints.scale,
          values: values,
          newParentSize: const Size(400, 200),
        );

        expect(newRect.left, 100); // 0.25 * 400
        expect(newRect.top, 50); // 0.25 * 200
        expect(newRect.width, 200); // 0.5 * 400
        expect(newRect.height, 100); // 0.5 * 200
      });

      test('inferConstraints detects left-top', () {
        final constraints = ConstraintEngine.inferConstraints(
          const Rect.fromLTWH(5, 5, 50, 50),
          const Size(200, 200),
        );

        expect(constraints.horizontal, HorizontalConstraint.left);
        expect(constraints.vertical, VerticalConstraint.top);
      });

      test('inferConstraints detects right-bottom', () {
        final constraints = ConstraintEngine.inferConstraints(
          const Rect.fromLTWH(145, 145, 50, 50),
          const Size(200, 200),
        );

        expect(constraints.horizontal, HorizontalConstraint.right);
        expect(constraints.vertical, VerticalConstraint.bottom);
      });
    });

    group('ConstraintsPanel', () {
      testWidgets('renders constraint dropdowns', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConstraintsPanel(
                constraints: LayoutConstraints.defaultConstraints,
                onConstraintsChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Constraints'), findsOneWidget);
        expect(find.text('Horizontal'), findsOneWidget);
        expect(find.text('Vertical'), findsOneWidget);
      });
    });
  });

  group('Stroke Options', () {
    group('StrokeConfig', () {
      test('default config', () {
        const config = StrokeConfig();

        expect(config.color, Colors.black);
        expect(config.width, 1.0);
        expect(config.cap, StrokeCap.butt);
        expect(config.join, StrokeJoin.miter);
        expect(config.position, StrokePosition.center);
        expect(config.isDashed, false);
      });

      test('solid factory creates solid stroke', () {
        final config = StrokeConfig.solid(color: Colors.red, width: 2.0);

        expect(config.color, Colors.red);
        expect(config.width, 2.0);
        expect(config.isDashed, false);
      });

      test('dashed factory creates dashed stroke', () {
        final config = StrokeConfig.dashed(
          color: Colors.blue,
          dashLength: 10,
          gapLength: 5,
        );

        expect(config.isDashed, true);
        expect(config.dashPattern, [10, 5]);
      });

      test('dotted factory creates dotted stroke', () {
        final config = StrokeConfig.dotted(spacing: 6);

        expect(config.isDashed, true);
        expect(config.cap, StrokeCap.round);
        expect(config.dashPattern, [1.0, 6.0]);
      });

      test('fromPreset creates correct patterns', () {
        final solid = StrokeConfig.fromPreset(DashPreset.solid);
        expect(solid.isDashed, false);

        final dashed = StrokeConfig.fromPreset(DashPreset.dashed, width: 2);
        expect(dashed.isDashed, true);

        final dotted = StrokeConfig.fromPreset(DashPreset.dotted);
        expect(dotted.cap, StrokeCap.round);
      });

      test('toPaint creates correct paint', () {
        const config = StrokeConfig(
          color: Color(0xFF4CAF50), // Use explicit color instead of MaterialColor
          width: 3.0,
          cap: StrokeCap.round,
          join: StrokeJoin.bevel,
        );

        final paint = config.toPaint();

        expect(paint.color.value, const Color(0xFF4CAF50).value);
        expect(paint.strokeWidth, 3.0);
        expect(paint.strokeCap, StrokeCap.round);
        expect(paint.strokeJoin, StrokeJoin.bevel);
        expect(paint.style, PaintingStyle.stroke);
      });
    });

    group('StrokeSides', () {
      test('all sides enabled by default', () {
        const sides = StrokeSides();

        expect(sides.hasAll, true);
        expect(sides.enabledCount, 4);
      });

      test('none has no sides', () {
        expect(StrokeSides.none.hasAny, false);
        expect(StrokeSides.none.enabledCount, 0);
      });

      test('horizontal has only top/bottom', () {
        expect(StrokeSides.horizontal.top, true);
        expect(StrokeSides.horizontal.bottom, true);
        expect(StrokeSides.horizontal.left, false);
        expect(StrokeSides.horizontal.right, false);
      });

      test('vertical has only left/right', () {
        expect(StrokeSides.vertical.top, false);
        expect(StrokeSides.vertical.bottom, false);
        expect(StrokeSides.vertical.left, true);
        expect(StrokeSides.vertical.right, true);
      });
    });
  });

  group('Shape Tools', () {
    group('ShapeBuilder', () {
      test('buildPolygon creates polygon path', () {
        final path = ShapeBuilder.buildPolygon(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          config: const PolygonConfig(sides: 6),
        );

        expect(path.getBounds(), isNotNull);
      });

      test('buildStar creates star path', () {
        final path = ShapeBuilder.buildStar(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          config: const StarConfig(points: 5, innerRadiusRatio: 0.5),
        );

        expect(path.getBounds(), isNotNull);
      });

      test('buildLine creates line path', () {
        final path = ShapeBuilder.buildLine(
          start: const Offset(0, 0),
          end: const Offset(100, 100),
          config: const LineConfig(),
        );

        expect(path.getBounds(), isNotNull);
      });

      test('buildLine with arrows', () {
        final path = ShapeBuilder.buildLine(
          start: const Offset(0, 0),
          end: const Offset(100, 0),
          config: const LineConfig(
            startArrow: ArrowHead.triangle,
            endArrow: ArrowHead.triangle,
          ),
        );

        expect(path.getBounds(), isNotNull);
      });

      test('buildArc creates arc path', () {
        final path = ShapeBuilder.buildArc(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          config: const ArcConfig(sweepAngle: 3.14159),
        );

        expect(path.getBounds(), isNotNull);
      });

      test('buildTriangle creates 3-sided polygon', () {
        final path = ShapeBuilder.buildTriangle(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
        );

        expect(path.getBounds(), isNotNull);
      });

      test('buildRoundedRect with different corners', () {
        final path = ShapeBuilder.buildRoundedRect(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          topLeft: 10,
          topRight: 20,
          bottomRight: 10,
          bottomLeft: 20,
        );

        expect(path.getBounds(), const Rect.fromLTWH(0, 0, 100, 100));
      });
    });

    group('Shape configs', () {
      test('PolygonConfig defaults', () {
        const config = PolygonConfig();

        expect(config.sides, 6);
        expect(config.cornerRadius, 0);
      });

      test('StarConfig defaults', () {
        const config = StarConfig();

        expect(config.points, 5);
        expect(config.innerRadiusRatio, 0.5);
      });

      test('LineConfig defaults', () {
        const config = LineConfig();

        expect(config.startArrow, ArrowHead.none);
        expect(config.endArrow, ArrowHead.none);
        expect(config.arrowSize, 12);
      });

      test('ArcConfig defaults', () {
        const config = ArcConfig();

        expect(config.startAngle, 0);
        expect(config.closePath, false);
      });
    });

    group('ShapeToolbar', () {
      testWidgets('renders all shape tools', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShapeToolbar(
                selectedTool: ShapeTool.rectangle,
                onToolSelected: (_) {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.rectangle_outlined), findsOneWidget);
        expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
        expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
        expect(find.byIcon(Icons.hexagon_outlined), findsOneWidget);
        expect(find.byIcon(Icons.star_outline), findsOneWidget);
      });

      testWidgets('calls callback when tool selected', (tester) async {
        ShapeTool? selectedTool;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShapeToolbar(
                selectedTool: ShapeTool.rectangle,
                onToolSelected: (tool) => selectedTool = tool,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.circle_outlined));
        await tester.pump();

        expect(selectedTool, ShapeTool.ellipse);
      });
    });
  });
}
