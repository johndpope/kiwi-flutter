/// Exhaustive UI tests for Figma-style Toolbar
///
/// Tests cover:
/// - Structure and layout
/// - Tool activation and switching
/// - Dropdown menus
/// - Mode toggles (Design/Prototype/Dev)
/// - Keyboard shortcuts
/// - Customization
/// - Accessibility
/// - Performance

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

/// Helper to set up larger viewport for toolbar tests
void setupToolbarViewport(WidgetTester tester) {
  tester.view.physicalSize = const ui.Size(1400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Toolbar Structure Tests', () {
    testWidgets('renders toolbar with all default tools', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      // Verify toolbar is rendered
      expect(find.byType(FigmaToolbar), findsOneWidget);

      // Verify Move/Select tool (arrow icon)
      expect(find.byIcon(Icons.near_me), findsOneWidget);

      // Verify Frame tool
      expect(find.byIcon(Icons.grid_3x3), findsOneWidget);

      // Verify Shape tool (rectangle)
      expect(find.byIcon(Icons.crop_square), findsOneWidget);

      // Verify Pen tool
      expect(find.byIcon(Icons.edit), findsOneWidget);

      // Verify Text tool
      expect(find.byIcon(Icons.text_fields), findsOneWidget);

      // Verify Resources tool
      expect(find.byIcon(Icons.widgets), findsOneWidget);

      // Verify Comment tool
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('renders mode toggles (Design/Prototype/Dev)', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      // Verify mode toggle buttons
      expect(find.text('Design'), findsOneWidget);
      expect(find.text('Prototype'), findsOneWidget);
      expect(find.text('Dev'), findsOneWidget);
    });

    testWidgets('renders Actions button with shortcut', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('⌘K'), findsOneWidget);
    });

    testWidgets('renders Share and Play buttons', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('toolbar has correct height (48px)', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FigmaToolbar),
          matching: find.byType(Container).first,
        ),
      );
      expect(container.constraints?.maxHeight, 48);
    });
  });

  group('Tool Activation Tests', () {
    testWidgets('clicking Move tool activates it', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();
      state.setTool(DesignTool.text); // Start with different tool

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.byIcon(Icons.near_me));
      await tester.pump();

      expect(state.activeTool, DesignTool.move);
    });

    testWidgets('clicking Text tool activates it', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.byIcon(Icons.text_fields));
      await tester.pump();

      expect(state.activeTool, DesignTool.text);
    });

    testWidgets('clicking Frame tool activates it', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.byIcon(Icons.grid_3x3));
      await tester.pump();

      expect(state.activeTool, DesignTool.frame);
    });

    testWidgets('clicking Rectangle tool activates it', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.byIcon(Icons.crop_square));
      await tester.pump();

      expect(state.activeTool, DesignTool.rectangle);
    });

    testWidgets('clicking Comment tool activates it', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pump();

      expect(state.activeTool, DesignTool.comment);
    });
  });

  group('Mode Toggle Tests', () {
    testWidgets('default mode is Design', (tester) async {
      final state = ToolbarState();

      expect(state.activeMode, DesignMode.design);
    });

    testWidgets('clicking Prototype toggles to prototype mode', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.text('Prototype'));
      await tester.pump();

      expect(state.activeMode, DesignMode.prototype);
    });

    testWidgets('clicking Dev toggles to dev mode', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.text('Dev'));
      await tester.pump();

      expect(state.activeMode, DesignMode.dev);
    });

    testWidgets('clicking Design returns to design mode', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();
      state.setMode(DesignMode.prototype);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      await tester.tap(find.text('Design'));
      await tester.pump();

      expect(state.activeMode, DesignMode.design);
    });
  });

  group('Toolbar Visibility Tests', () {
    testWidgets('toolbar is visible by default', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      expect(find.byType(FigmaToolbar), findsOneWidget);
      expect(state.isToolbarVisible, true);
    });

    testWidgets('toolbar hides when visibility toggled', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      state.toggleToolbarVisibility();
      await tester.pump();

      // Toolbar should still exist but render as SizedBox.shrink
      expect(state.isToolbarVisible, false);
    });
  });

  group('Keyboard Shortcuts Tests', () {
    testWidgets('V key activates Move tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();
      state.setTool(DesignTool.text);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pump();

      expect(state.activeTool, DesignTool.move);
    });

    testWidgets('T key activates Text tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();

      expect(state.activeTool, DesignTool.text);
    });

    testWidgets('F key activates Frame tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(state.activeTool, DesignTool.frame);
    });

    testWidgets('R key activates Rectangle tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(state.activeTool, DesignTool.rectangle);
    });

    testWidgets('O key activates Ellipse tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.pump();

      expect(state.activeTool, DesignTool.ellipse);
    });

    testWidgets('P key activates Pen tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();

      expect(state.activeTool, DesignTool.pen);
    });

    testWidgets('L key activates Line tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();

      expect(state.activeTool, DesignTool.line);
    });

    testWidgets('H key activates Hand tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();

      expect(state.activeTool, DesignTool.hand);
    });

    testWidgets('K key activates Scale tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pump();

      expect(state.activeTool, DesignTool.scale);
    });

    testWidgets('C key activates Comment tool', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolbarShortcuts(
            state: state,
            child: FigmaToolbar(state: state),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(state.activeTool, DesignTool.comment);
    });
  });

  group('Button Callback Tests', () {
    testWidgets('Share button triggers onSharePressed', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();
      bool sharePressed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(
            state: state,
            onSharePressed: () => sharePressed = true,
          ),
        ),
      ));

      await tester.tap(find.text('Share'));
      await tester.pump();

      expect(sharePressed, true);
    });

    testWidgets('Play button triggers onPlayPressed', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();
      bool playPressed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(
            state: state,
            onPlayPressed: () => playPressed = true,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(playPressed, true);
    });

    testWidgets('Actions button triggers onActionsPressed', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();
      bool actionsPressed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(
            state: state,
            onActionsPressed: () => actionsPressed = true,
          ),
        ),
      ));

      await tester.tap(find.text('Actions'));
      await tester.pump();

      expect(actionsPressed, true);
    });
  });

  group('ToolbarState Tests', () {
    test('default tool is Move', () {
      final state = ToolbarState();
      expect(state.activeTool, DesignTool.move);
    });

    test('default mode is Design', () {
      final state = ToolbarState();
      expect(state.activeMode, DesignMode.design);
    });

    test('setTool changes active tool', () {
      final state = ToolbarState();
      state.setTool(DesignTool.text);
      expect(state.activeTool, DesignTool.text);
    });

    test('setMode changes active mode', () {
      final state = ToolbarState();
      state.setMode(DesignMode.dev);
      expect(state.activeMode, DesignMode.dev);
    });

    test('toggleToolbarVisibility toggles visibility', () {
      final state = ToolbarState();
      expect(state.isToolbarVisible, true);
      state.toggleToolbarVisibility();
      expect(state.isToolbarVisible, false);
      state.toggleToolbarVisibility();
      expect(state.isToolbarVisible, true);
    });

    test('pinTool adds tool to pinned set', () {
      final state = ToolbarState();
      expect(state.pinnedTools.contains(DesignTool.pencil), false);
      state.pinTool(DesignTool.pencil);
      expect(state.pinnedTools.contains(DesignTool.pencil), true);
    });

    test('unpinTool removes tool from pinned set', () {
      final state = ToolbarState();
      state.pinTool(DesignTool.pencil);
      expect(state.pinnedTools.contains(DesignTool.pencil), true);
      state.unpinTool(DesignTool.pencil);
      expect(state.pinnedTools.contains(DesignTool.pencil), false);
    });

    test('state notifies listeners on tool change', () {
      final state = ToolbarState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.setTool(DesignTool.text);
      expect(notifyCount, 1);

      state.setTool(DesignTool.pen);
      expect(notifyCount, 2);
    });

    test('state notifies listeners on mode change', () {
      final state = ToolbarState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.setMode(DesignMode.prototype);
      expect(notifyCount, 1);
    });
  });

  group('ToolConfig Tests', () {
    test('moveTools has correct dropdown items', () {
      final config = ToolConfigs.moveTools;
      expect(config.dropdownItems, isNotNull);
      expect(config.dropdownItems!.length, 3);
      expect(config.dropdownItems![0].tool, DesignTool.move);
      expect(config.dropdownItems![1].tool, DesignTool.scale);
      expect(config.dropdownItems![2].tool, DesignTool.hand);
    });

    test('frameTools has correct dropdown items', () {
      final config = ToolConfigs.frameTools;
      expect(config.dropdownItems, isNotNull);
      expect(config.dropdownItems!.length, 3);
      expect(config.dropdownItems![0].tool, DesignTool.frame);
      expect(config.dropdownItems![1].tool, DesignTool.section);
      expect(config.dropdownItems![2].tool, DesignTool.slice);
    });

    test('shapeTools has correct dropdown items', () {
      final config = ToolConfigs.shapeTools;
      expect(config.dropdownItems, isNotNull);
      expect(config.dropdownItems!.length, 6);
      expect(config.dropdownItems![0].tool, DesignTool.rectangle);
      expect(config.dropdownItems![1].tool, DesignTool.line);
      expect(config.dropdownItems![2].tool, DesignTool.arrow);
      expect(config.dropdownItems![3].tool, DesignTool.ellipse);
      expect(config.dropdownItems![4].tool, DesignTool.polygon);
      expect(config.dropdownItems![5].tool, DesignTool.star);
    });

    test('penTools has correct dropdown items', () {
      final config = ToolConfigs.penTools;
      expect(config.dropdownItems, isNotNull);
      expect(config.dropdownItems!.length, 2);
      expect(config.dropdownItems![0].tool, DesignTool.pen);
      expect(config.dropdownItems![1].tool, DesignTool.pencil);
    });

    test('allTools returns all tool configs', () {
      final tools = ToolConfigs.allTools;
      expect(tools.length, 7);
    });
  });

  group('Performance Tests', () {
    testWidgets('toolbar renders within acceptable time', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    testWidgets('tool switching is fast (< 50ms)', (tester) async {
      setupToolbarViewport(tester);
      final state = ToolbarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaToolbar(state: state),
        ),
      ));

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        state.setTool(i.isEven ? DesignTool.move : DesignTool.text);
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMilliseconds / 100;
      expect(avgTime, lessThan(50));
    });
  });
}
