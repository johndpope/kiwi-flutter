// Tests for Advanced Prototyping features

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';
// PrototypeVariableType and PrototypeScrollBehavior are exported from flutter_renderer

void main() {
  group('Conditional Logic', () {
    group('ComparisonOperator', () {
      test('equals evaluates correctly', () {
        expect(ComparisonOperator.equals.evaluate(5, 5), true);
        expect(ComparisonOperator.equals.evaluate(5, 6), false);
        expect(ComparisonOperator.equals.evaluate('a', 'a'), true);
      });

      test('notEquals evaluates correctly', () {
        expect(ComparisonOperator.notEquals.evaluate(5, 6), true);
        expect(ComparisonOperator.notEquals.evaluate(5, 5), false);
      });

      test('greaterThan evaluates correctly', () {
        expect(ComparisonOperator.greaterThan.evaluate(10, 5), true);
        expect(ComparisonOperator.greaterThan.evaluate(5, 10), false);
      });

      test('lessThan evaluates correctly', () {
        expect(ComparisonOperator.lessThan.evaluate(5, 10), true);
        expect(ComparisonOperator.lessThan.evaluate(10, 5), false);
      });

      test('contains evaluates correctly', () {
        expect(ComparisonOperator.contains.evaluate('hello world', 'world'), true);
        expect(ComparisonOperator.contains.evaluate('hello', 'world'), false);
        expect(ComparisonOperator.contains.evaluate([1, 2, 3], 2), true);
      });

      test('isEmpty evaluates correctly', () {
        expect(ComparisonOperator.isEmpty.evaluate('', null), true);
        expect(ComparisonOperator.isEmpty.evaluate('hello', null), false);
        expect(ComparisonOperator.isEmpty.evaluate([], null), true);
      });
    });

    group('Condition', () {
      test('evaluates with variables', () {
        const condition = Condition(
          id: 'c1',
          variableId: 'count',
          operator: ComparisonOperator.greaterThan,
          value: 5,
        );

        expect(condition.evaluate({'count': 10}), true);
        expect(condition.evaluate({'count': 3}), false);
      });

      test('serializes to and from map', () {
        const condition = Condition(
          id: 'c1',
          variableId: 'loggedIn',
          operator: ComparisonOperator.equals,
          value: true,
        );

        final map = condition.toMap();
        final restored = Condition.fromMap(map);

        expect(restored.variableId, condition.variableId);
        expect(restored.operator, condition.operator);
        expect(restored.value, condition.value);
      });
    });

    group('ConditionGroup', () {
      test('evaluates single condition', () {
        final group = ConditionGroup(
          id: 'g1',
          conditions: [
            const Condition(
              id: 'c1',
              variableId: 'active',
              operator: ComparisonOperator.equals,
              value: true,
            ),
          ],
        );

        expect(group.evaluate({'active': true}), true);
        expect(group.evaluate({'active': false}), false);
      });

      test('evaluates AND conditions', () {
        final group = ConditionGroup(
          id: 'g1',
          conditions: [
            const Condition(
              id: 'c1',
              variableId: 'loggedIn',
              operator: ComparisonOperator.equals,
              value: true,
            ),
            const Condition(
              id: 'c2',
              variableId: 'age',
              operator: ComparisonOperator.greaterOrEqual,
              value: 18,
            ),
          ],
          operators: [LogicalOperator.and],
        );

        expect(group.evaluate({'loggedIn': true, 'age': 21}), true);
        expect(group.evaluate({'loggedIn': true, 'age': 16}), false);
        expect(group.evaluate({'loggedIn': false, 'age': 21}), false);
      });

      test('evaluates OR conditions', () {
        final group = ConditionGroup(
          id: 'g1',
          conditions: [
            const Condition(
              id: 'c1',
              variableId: 'isAdmin',
              operator: ComparisonOperator.equals,
              value: true,
            ),
            const Condition(
              id: 'c2',
              variableId: 'isModerator',
              operator: ComparisonOperator.equals,
              value: true,
            ),
          ],
          operators: [LogicalOperator.or],
        );

        expect(group.evaluate({'isAdmin': true, 'isModerator': false}), true);
        expect(group.evaluate({'isAdmin': false, 'isModerator': true}), true);
        expect(group.evaluate({'isAdmin': false, 'isModerator': false}), false);
      });
    });

    group('ConditionalAction', () {
      test('returns then action when condition is true', () {
        final action = ConditionalAction(
          id: 'a1',
          condition: ConditionGroup(
            id: 'g1',
            conditions: [
              const Condition(
                id: 'c1',
                variableId: 'loggedIn',
                operator: ComparisonOperator.equals,
                value: true,
              ),
            ],
          ),
          thenActionNodeId: 'dashboard',
          elseActionNodeId: 'login',
        );

        expect(action.evaluate({'loggedIn': true}), 'dashboard');
        expect(action.evaluate({'loggedIn': false}), 'login');
      });
    });

    group('PrototypeVariable', () {
      test('creates with all properties', () {
        const variable = PrototypeVariable(
          id: 'v1',
          name: 'Count',
          type: PrototypeVariableType.number,
          defaultValue: 0,
          description: 'A counter',
        );

        expect(variable.name, 'Count');
        expect(variable.type, PrototypeVariableType.number);
        expect(variable.defaultValue, 0);
      });

      test('provides common presets', () {
        final loggedIn = PrototypeVariable.loggedIn();
        expect(loggedIn.type, PrototypeVariableType.boolean);
        expect(loggedIn.defaultValue, false);

        final darkMode = PrototypeVariable.darkMode();
        expect(darkMode.type, PrototypeVariableType.boolean);

        final userName = PrototypeVariable.userName();
        expect(userName.type, PrototypeVariableType.string);
      });
    });

    group('VariableStore', () {
      test('registers and retrieves variables', () {
        final store = VariableStore();
        store.registerVariable(PrototypeVariable.loggedIn());

        expect(store.getValue<bool>('loggedIn'), false);

        store.setValue('loggedIn', true);
        expect(store.getValue<bool>('loggedIn'), true);
      });

      test('resets to defaults', () {
        final store = VariableStore();
        store.registerVariable(PrototypeVariable.itemCount());
        store.setValue('itemCount', 5);

        expect(store.getValue<num>('itemCount'), 5);

        store.reset();
        expect(store.getValue<num>('itemCount'), 0);
      });

      test('applies set variable action', () {
        final store = VariableStore();
        store.registerVariable(PrototypeVariable.itemCount());

        store.applyAction(const SetVariableAction(
          variableId: 'itemCount',
          value: 10,
          operation: SetVariableOperation.set,
        ));
        expect(store.getValue<num>('itemCount'), 10);

        store.applyAction(const SetVariableAction(
          variableId: 'itemCount',
          value: 5,
          operation: SetVariableOperation.increment,
        ));
        expect(store.getValue<num>('itemCount'), 15);
      });
    });
  });

  group('Device Preview', () {
    group('StatusBarConfig', () {
      test('has sensible defaults', () {
        const config = StatusBarConfig();
        expect(config.visible, true);
        expect(config.style, StatusBarStyle.dark);
        expect(config.platform, PlatformType.iOS);
        expect(config.batteryLevel, 100);
      });

      test('copyWith works correctly', () {
        const config = StatusBarConfig();
        final modified = config.copyWith(
          style: StatusBarStyle.light,
          batteryLevel: 50,
          time: '10:30',
        );

        expect(modified.style, StatusBarStyle.light);
        expect(modified.batteryLevel, 50);
        expect(modified.time, '10:30');
      });
    });

    group('ScrollConfig', () {
      test('has sensible defaults', () {
        const config = ScrollConfig();
        expect(config.behavior, PrototypeScrollBehavior.vertical);
        expect(config.preserveScrollPosition, false);
      });

      test('supports fixed elements', () {
        const config = ScrollConfig(
          fixedElements: [
            FixedElement(
              id: 'header',
              nodeId: 'header-node',
              position: FixedPosition.top,
              size: 60,
            ),
          ],
        );

        expect(config.fixedElements.length, 1);
        expect(config.fixedElements.first.position, FixedPosition.top);
      });
    });

    testWidgets('IOSStatusBar renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IOSStatusBar(
              config: StatusBarConfig(),
            ),
          ),
        ),
      );

      expect(find.text('9:41'), findsOneWidget);
    });

    testWidgets('AndroidStatusBar renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AndroidStatusBar(
              config: StatusBarConfig(platform: PlatformType.android),
            ),
          ),
        ),
      );

      expect(find.text('9:41'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });
  });

  group('Media Support', () {
    group('MediaConfig', () {
      test('has sensible defaults', () {
        const config = MediaConfig(
          id: 'm1',
          type: MediaType.video,
          source: 'video.mp4',
        );

        expect(config.autoPlay, true);
        expect(config.loop, true);
        expect(config.muted, false);
        expect(config.showControls, false);
      });

      test('serializes to and from map', () {
        const config = MediaConfig(
          id: 'm1',
          type: MediaType.gif,
          source: 'animation.gif',
          autoPlay: false,
          loop: true,
        );

        final map = config.toMap();
        final restored = MediaConfig.fromMap(map);

        expect(restored.type, config.type);
        expect(restored.source, config.source);
        expect(restored.autoPlay, config.autoPlay);
      });
    });

    group('PrototypeMediaController', () {
      test('manages playback state', () {
        final controller = PrototypeMediaController();

        expect(controller.state, PlaybackState.idle);

        controller.play();
        expect(controller.state, PlaybackState.playing);

        controller.pause();
        expect(controller.state, PlaybackState.paused);

        controller.stop();
        expect(controller.state, PlaybackState.stopped);
        expect(controller.position, Duration.zero);

        controller.dispose();
      });

      test('manages volume and mute', () {
        final controller = PrototypeMediaController();

        expect(controller.volume, 1.0);
        expect(controller.muted, false);

        controller.setVolume(0.5);
        expect(controller.volume, 0.5);

        controller.toggleMute();
        expect(controller.muted, true);

        controller.dispose();
      });
    });

    testWidgets('PrototypeVideoPlayer renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: PrototypeVideoPlayer(
                config: MediaConfig(
                  id: 'v1',
                  type: MediaType.video,
                  source: 'test.mp4',
                  autoPlay: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('test.mp4'), findsOneWidget);

      // Pump to complete the delayed initialization timer
      await tester.pump(const Duration(milliseconds: 600));
    });
  });

  group('AI Prototyping', () {
    group('AIPrototypingEngine', () {
      test('generates flow from login prompt', () async {
        final engine = AIPrototypingEngine();
        final flow = await engine.generateFromPrompt('Create a login flow');

        expect(flow, isNotNull);
        expect(flow!.screens.any((s) => s.template == ScreenTemplate.login), true);
      });

      test('generates flow from onboarding prompt', () async {
        final engine = AIPrototypingEngine();
        final flow = await engine.generateFromPrompt('Create onboarding tutorial');

        expect(flow, isNotNull);
        expect(flow!.screens.any((s) => s.template == ScreenTemplate.onboarding), true);
      });

      test('generates suggestions for screens without back', () async {
        final engine = AIPrototypingEngine();
        final suggestions = await engine.getSuggestions(
          screenIds: ['home', 'settings'],
          interactions: {
            'home': NodeInteractions(
              nodeId: 'home',
              interactions: [Interaction.navigateTo('settings')],
            ),
            'settings': const NodeInteractions(nodeId: 'settings'),
          },
        );

        expect(
          suggestions.any((s) => s.type == AISuggestionType.addBackButton),
          true,
        );
      });
    });

    group('GeneratedFlow', () {
      test('contains screens and interactions', () {
        const flow = GeneratedFlow(
          id: 'f1',
          name: 'Test Flow',
          screens: [
            GeneratedScreen(id: 's1', name: 'Home', template: ScreenTemplate.home),
            GeneratedScreen(id: 's2', name: 'Profile', template: ScreenTemplate.profile),
          ],
          interactions: [
            GeneratedInteraction(
              fromScreenId: 's1',
              toScreenId: 's2',
              triggerElementId: 'profile_button',
            ),
          ],
        );

        expect(flow.screens.length, 2);
        expect(flow.interactions.length, 1);
      });
    });
  });

  group('Web Publishing', () {
    group('Breakpoint', () {
      test('matches correct widths', () {
        expect(Breakpoint.mobile.matches(375), true);
        expect(Breakpoint.mobile.matches(768), false);
        expect(Breakpoint.tablet.matches(768), true);
        expect(Breakpoint.desktop.matches(1200), true);
      });

      test('defaults include all standard breakpoints', () {
        expect(Breakpoint.defaults.length, 4);
        expect(Breakpoint.defaults.contains(Breakpoint.mobile), true);
        expect(Breakpoint.defaults.contains(Breakpoint.desktop), true);
      });
    });

    group('WebPublishConfig', () {
      test('has sensible defaults', () {
        const config = WebPublishConfig();
        expect(config.title, 'Prototype');
        expect(config.enableSEO, true);
        expect(config.enableResponsive, true);
      });

      test('copyWith works correctly', () {
        const config = WebPublishConfig();
        final modified = config.copyWith(
          title: 'My App',
          enableAnalytics: true,
          enablePasswordProtection: true,
          password: 'secret',
        );

        expect(modified.title, 'My App');
        expect(modified.enableAnalytics, true);
        expect(modified.enablePasswordProtection, true);
        expect(modified.password, 'secret');
      });
    });

    group('WebPublishingEngine', () {
      test('publishes prototype', () async {
        final engine = WebPublishingEngine();
        final result = await engine.publish(
          prototypeId: 'proto-123',
          config: const WebPublishConfig(title: 'Test Prototype'),
        );

        expect(result.url, contains('prototype.example.com'));
        expect(result.embedCode, contains('iframe'));
        expect(result.config.title, 'Test Prototype');
      });

      test('generates HTML preview', () {
        final engine = WebPublishingEngine();
        final html = engine.generateHTMLPreview(
          prototypeId: 'proto-123',
          config: const WebPublishConfig(
            title: 'Test',
            description: 'A test prototype',
            enableSEO: true,
          ),
        );

        expect(html, contains('<title>Test</title>'));
        expect(html, contains('og:title'));
        expect(html, contains('og:description'));
      });
    });

    testWidgets('ResponsivePreview renders with breakpoint selector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsivePreview(
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('Desktop'), findsOneWidget);
    });
  });

  group('Prototype Mode Overlay', () {
    testWidgets('shows mode toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrototypeModeOverlay(
              isPrototypeMode: false,
              connections: const [],
              onToggleMode: () {},
            ),
          ),
        ),
      );

      expect(find.text('Design'), findsOneWidget);
      expect(find.text('Prototype'), findsOneWidget);
    });

    testWidgets('highlights active mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrototypeModeOverlay(
              isPrototypeMode: true,
              connections: const [],
              onToggleMode: () {},
            ),
          ),
        ),
      );

      // Prototype should be highlighted when isPrototypeMode is true
      expect(find.text('Prototype'), findsOneWidget);
    });
  });

  group('Panel Widgets', () {
    testWidgets('VariableEditorPanel renders empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariableEditorPanel(
              variables: const [],
              onVariablesChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Variables'), findsOneWidget);
      expect(find.text('No variables'), findsOneWidget);
    });

    testWidgets('ConditionBuilderPanel renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConditionBuilderPanel(
              availableVariables: [PrototypeVariable.loggedIn()],
              onConditionChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Conditions'), findsOneWidget);
    });

    testWidgets('DevicePreviewPanel renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DevicePreviewPanel(
              selectedDevice: PrototypeDevice.iphone14,
              statusBarConfig: const StatusBarConfig(),
              isLandscape: false,
              onDeviceChanged: (_) {},
              onStatusBarChanged: (_) {},
              onOrientationChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Device Preview'), findsOneWidget);
      expect(find.text('Show status bar'), findsOneWidget);
    });

    testWidgets('MediaConfigPanel renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaConfigPanel(
              config: const MediaConfig(
                id: 'm1',
                type: MediaType.video,
                source: 'test.mp4',
              ),
              onConfigChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Media Settings'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
    });
  });
}
