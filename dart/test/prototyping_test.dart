// Tests for the Prototyping module

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  group('Interactions', () {
    group('InteractionTrigger', () {
      test('has correct labels', () {
        expect(InteractionTrigger.onClick.label, 'On click');
        expect(InteractionTrigger.onHover.label, 'On hover');
        expect(InteractionTrigger.afterDelay.label, 'After delay');
      });

      test('contains all expected triggers', () {
        expect(InteractionTrigger.values.length, greaterThanOrEqualTo(10));
        expect(InteractionTrigger.values, contains(InteractionTrigger.onClick));
        expect(InteractionTrigger.values, contains(InteractionTrigger.onHover));
        expect(InteractionTrigger.values, contains(InteractionTrigger.onDrag));
      });
    });

    group('InteractionAction', () {
      test('has correct labels', () {
        expect(InteractionAction.navigate.label, 'Navigate to');
        expect(InteractionAction.openOverlay.label, 'Open overlay');
        expect(InteractionAction.back.label, 'Go back');
      });

      test('contains all expected actions', () {
        expect(InteractionAction.values.length, greaterThanOrEqualTo(7));
        expect(InteractionAction.values, contains(InteractionAction.navigate));
        expect(InteractionAction.values, contains(InteractionAction.openOverlay));
        expect(InteractionAction.values, contains(InteractionAction.openLink));
      });
    });

    group('AnimationEasing', () {
      test('converts to Flutter curves', () {
        expect(AnimationEasing.linear.toCurve(), Curves.linear);
        expect(AnimationEasing.easeIn.toCurve(), Curves.easeIn);
        expect(AnimationEasing.easeOut.toCurve(), Curves.easeOut);
        expect(AnimationEasing.easeInOut.toCurve(), Curves.easeInOut);
      });
    });

    group('TransitionDirection', () {
      test('converts to offset', () {
        expect(TransitionDirection.left.toOffset(), const Offset(-1, 0));
        expect(TransitionDirection.right.toOffset(), const Offset(1, 0));
        expect(TransitionDirection.top.toOffset(), const Offset(0, -1));
        expect(TransitionDirection.bottom.toOffset(), const Offset(0, 1));
      });
    });

    group('OverlayPosition', () {
      test('converts to alignment', () {
        expect(OverlayPosition.center.toAlignment(), Alignment.center);
        expect(OverlayPosition.topLeft.toAlignment(), Alignment.topLeft);
        expect(OverlayPosition.bottomRight.toAlignment(), Alignment.bottomRight);
      });
    });
  });

  group('TransitionConfig', () {
    test('has sensible defaults', () {
      const config = TransitionConfig();
      expect(config.type, TransitionType.dissolve);
      expect(config.direction, TransitionDirection.right);
      expect(config.easing, AnimationEasing.easeInOut);
      expect(config.duration, const Duration(milliseconds: 300));
      expect(config.matchLayers, false);
    });

    test('provides presets', () {
      expect(TransitionConfig.instant.type, TransitionType.instant);
      expect(TransitionConfig.instant.duration, Duration.zero);

      expect(TransitionConfig.dissolve.type, TransitionType.dissolve);
      expect(TransitionConfig.smartAnimate.matchLayers, true);
    });

    test('copyWith works correctly', () {
      const config = TransitionConfig();
      final modified = config.copyWith(
        type: TransitionType.push,
        direction: TransitionDirection.left,
        duration: const Duration(milliseconds: 500),
      );

      expect(modified.type, TransitionType.push);
      expect(modified.direction, TransitionDirection.left);
      expect(modified.duration, const Duration(milliseconds: 500));
      expect(modified.easing, config.easing); // unchanged
    });

    test('serializes to and from map', () {
      const config = TransitionConfig(
        type: TransitionType.slideIn,
        direction: TransitionDirection.top,
        easing: AnimationEasing.bouncy,
        duration: Duration(milliseconds: 400),
        matchLayers: true,
      );

      final map = config.toMap();
      final restored = TransitionConfig.fromMap(map);

      expect(restored.type, config.type);
      expect(restored.direction, config.direction);
      expect(restored.easing, config.easing);
      expect(restored.duration, config.duration);
      expect(restored.matchLayers, config.matchLayers);
    });
  });

  group('OverlaySettings', () {
    test('has sensible defaults', () {
      const settings = OverlaySettings();
      expect(settings.position, OverlayPosition.center);
      expect(settings.manualOffset, Offset.zero);
      expect(settings.closeOnClickOutside, true);
      expect(settings.addBackgroundBehind, true);
      expect(settings.backgroundOpacity, 0.5);
    });

    test('copyWith works correctly', () {
      const settings = OverlaySettings();
      final modified = settings.copyWith(
        position: OverlayPosition.topCenter,
        closeOnClickOutside: false,
        backgroundOpacity: 0.8,
      );

      expect(modified.position, OverlayPosition.topCenter);
      expect(modified.closeOnClickOutside, false);
      expect(modified.backgroundOpacity, 0.8);
      expect(modified.addBackgroundBehind, settings.addBackgroundBehind);
    });

    test('serializes to and from map', () {
      const settings = OverlaySettings(
        position: OverlayPosition.bottomLeft,
        manualOffset: Offset(10, 20),
        closeOnClickOutside: false,
        addBackgroundBehind: false,
        backgroundOpacity: 0.7,
      );

      final map = settings.toMap();
      final restored = OverlaySettings.fromMap(map);

      expect(restored.position, settings.position);
      expect(restored.manualOffset, settings.manualOffset);
      expect(restored.closeOnClickOutside, settings.closeOnClickOutside);
      expect(restored.addBackgroundBehind, settings.addBackgroundBehind);
      expect(restored.backgroundOpacity, settings.backgroundOpacity);
    });
  });

  group('Interaction', () {
    test('creates with required parameters', () {
      final interaction = Interaction(
        trigger: InteractionTrigger.onClick,
        action: InteractionAction.navigate,
      );

      expect(interaction.id, isNotEmpty);
      expect(interaction.trigger, InteractionTrigger.onClick);
      expect(interaction.action, InteractionAction.navigate);
    });

    test('factory navigateTo creates correct interaction', () {
      final interaction = Interaction.navigateTo('frame-123');

      expect(interaction.trigger, InteractionTrigger.onClick);
      expect(interaction.action, InteractionAction.navigate);
      expect(interaction.destinationNodeId, 'frame-123');
    });

    test('factory openOverlay creates correct interaction', () {
      final interaction = Interaction.openOverlay(
        'modal-456',
        settings: const OverlaySettings(position: OverlayPosition.center),
      );

      expect(interaction.trigger, InteractionTrigger.onClick);
      expect(interaction.action, InteractionAction.openOverlay);
      expect(interaction.destinationNodeId, 'modal-456');
      expect(interaction.overlaySettings, isNotNull);
    });

    test('factory back creates correct interaction', () {
      final interaction = Interaction.back();

      expect(interaction.trigger, InteractionTrigger.onClick);
      expect(interaction.action, InteractionAction.back);
      expect(interaction.destinationNodeId, isNull);
    });

    test('factory openLink creates correct interaction', () {
      final interaction = Interaction.openLink('https://example.com');

      expect(interaction.trigger, InteractionTrigger.onClick);
      expect(interaction.action, InteractionAction.openLink);
      expect(interaction.externalLink, 'https://example.com');
    });

    test('factory afterDelay creates correct interaction', () {
      final interaction = Interaction.afterDelay(
        const Duration(seconds: 2),
        'next-frame',
      );

      expect(interaction.trigger, InteractionTrigger.afterDelay);
      expect(interaction.triggerDelay, const Duration(seconds: 2));
      expect(interaction.destinationNodeId, 'next-frame');
    });

    test('copyWith works correctly', () {
      final original = Interaction.navigateTo('frame-1');
      final modified = original.copyWith(
        destinationNodeId: 'frame-2',
        transition: TransitionConfig.smartAnimate,
      );

      expect(modified.id, original.id);
      expect(modified.trigger, original.trigger);
      expect(modified.destinationNodeId, 'frame-2');
      expect(modified.transition.type, TransitionType.smartAnimate);
    });

    test('serializes to and from map', () {
      final interaction = Interaction(
        trigger: InteractionTrigger.onHover,
        action: InteractionAction.openOverlay,
        destinationNodeId: 'overlay-123',
        transition: const TransitionConfig(
          type: TransitionType.dissolve,
          duration: Duration(milliseconds: 200),
        ),
        overlaySettings: const OverlaySettings(
          position: OverlayPosition.topRight,
        ),
      );

      final map = interaction.toMap();
      final restored = Interaction.fromMap(map);

      expect(restored.trigger, interaction.trigger);
      expect(restored.action, interaction.action);
      expect(restored.destinationNodeId, interaction.destinationNodeId);
      expect(restored.transition.type, interaction.transition.type);
      expect(restored.overlaySettings?.position, OverlayPosition.topRight);
    });
  });

  group('NodeInteractions', () {
    test('creates with node ID', () {
      const interactions = NodeInteractions(nodeId: 'button-1');
      expect(interactions.nodeId, 'button-1');
      expect(interactions.interactions, isEmpty);
      expect(interactions.hasInteractions, false);
    });

    test('addInteraction works correctly', () {
      const interactions = NodeInteractions(nodeId: 'button-1');
      final updated = interactions.addInteraction(
        Interaction.navigateTo('frame-2'),
      );

      expect(updated.interactions.length, 1);
      expect(updated.hasInteractions, true);
    });

    test('removeInteraction works correctly', () {
      final interaction = Interaction.navigateTo('frame-2');
      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [interaction],
      );

      final updated = interactions.removeInteraction(interaction.id);
      expect(updated.interactions, isEmpty);
    });

    test('updateInteraction works correctly', () {
      final interaction = Interaction.navigateTo('frame-2');
      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [interaction],
      );

      final modified = interaction.copyWith(destinationNodeId: 'frame-3');
      final updated = interactions.updateInteraction(modified);

      expect(updated.interactions.first.destinationNodeId, 'frame-3');
    });

    test('getInteractionsByTrigger filters correctly', () {
      final onClick = Interaction.navigateTo('frame-1');
      final onHover = Interaction.onHoverNavigate('frame-2');
      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [onClick, onHover],
      );

      final clickInteractions = interactions.getInteractionsByTrigger(
        InteractionTrigger.onClick,
      );
      expect(clickInteractions.length, 1);
      expect(clickInteractions.first.destinationNodeId, 'frame-1');
    });

    test('serializes to and from map', () {
      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [
          Interaction.navigateTo('frame-1'),
          Interaction.openOverlay('modal-1'),
        ],
      );

      final map = interactions.toMap();
      final restored = NodeInteractions.fromMap(map);

      expect(restored.nodeId, interactions.nodeId);
      expect(restored.interactions.length, 2);
    });
  });

  group('PrototypeFlow', () {
    test('creates with required parameters', () {
      const flow = PrototypeFlow(
        id: 'flow-1',
        name: 'Main Flow',
        startingNodeId: 'home-screen',
      );

      expect(flow.id, 'flow-1');
      expect(flow.name, 'Main Flow');
      expect(flow.startingNodeId, 'home-screen');
      expect(flow.device, PrototypeDevice.iphone14);
    });

    test('serializes to and from map', () {
      const flow = PrototypeFlow(
        id: 'flow-1',
        name: 'Main Flow',
        startingNodeId: 'home-screen',
        device: PrototypeDevice.ipadPro11,
        backgroundColor: Colors.black,
      );

      final map = flow.toMap();
      final restored = PrototypeFlow.fromMap(map);

      expect(restored.id, flow.id);
      expect(restored.name, flow.name);
      expect(restored.startingNodeId, flow.startingNodeId);
      expect(restored.device, flow.device);
    });
  });

  group('PrototypeDevice', () {
    test('has correct dimensions', () {
      expect(PrototypeDevice.iphone14.width, 390);
      expect(PrototypeDevice.iphone14.height, 844);

      expect(PrototypeDevice.ipadPro11.width, 834);
      expect(PrototypeDevice.ipadPro11.height, 1194);

      expect(PrototypeDevice.desktop.width, 1440);
      expect(PrototypeDevice.desktop.height, 900);
    });

    test('provides size as Size object', () {
      final size = PrototypeDevice.iphone14.size;
      expect(size, const Size(390, 844));
    });
  });

  group('PrototypePlayerController', () {
    late PrototypePlayerController controller;

    setUp(() {
      controller = PrototypePlayerController(
        startingNodeId: 'home',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with starting node', () {
      expect(controller.currentNodeId, 'home');
      expect(controller.state.history.length, 1);
      expect(controller.canGoBack, false);
    });

    test('navigateTo adds to history', () {
      controller.navigateTo('screen-2');

      expect(controller.currentNodeId, 'screen-2');
      expect(controller.state.history.length, 2);
      expect(controller.canGoBack, true);
    });

    test('goBack navigates to previous screen', () {
      controller.navigateTo('screen-2');
      controller.navigateTo('screen-3');
      controller.goBack();

      expect(controller.currentNodeId, 'screen-2');
      expect(controller.state.history.length, 2);
    });

    test('goBack does nothing when at start', () {
      controller.goBack();

      expect(controller.currentNodeId, 'home');
      expect(controller.state.history.length, 1);
    });

    test('swapTo replaces current in history', () {
      controller.navigateTo('screen-2');
      controller.swapTo('screen-2-variant');

      expect(controller.currentNodeId, 'screen-2-variant');
      expect(controller.state.history.length, 2);
    });

    test('openOverlay adds overlay to stack', () {
      controller.openOverlay(
        'modal-1',
        settings: const OverlaySettings(),
      );

      expect(controller.hasOverlays, true);
      expect(controller.overlays.length, 1);
      expect(controller.overlays.first.nodeId, 'modal-1');
    });

    test('closeTopOverlay removes top overlay', () {
      controller.openOverlay('modal-1', settings: const OverlaySettings());
      controller.openOverlay('modal-2', settings: const OverlaySettings());
      controller.closeTopOverlay();

      expect(controller.overlays.length, 1);
      expect(controller.overlays.first.nodeId, 'modal-1');
    });

    test('closeAllOverlays clears overlay stack', () {
      controller.openOverlay('modal-1', settings: const OverlaySettings());
      controller.openOverlay('modal-2', settings: const OverlaySettings());
      controller.closeAllOverlays();

      expect(controller.hasOverlays, false);
    });

    test('setVariable stores and retrieves values', () {
      controller.setVariable('count', 5);
      controller.setVariable('name', 'test');

      expect(controller.getVariable<int>('count'), 5);
      expect(controller.getVariable<String>('name'), 'test');
    });

    test('reset returns to starting state', () {
      controller.navigateTo('screen-2');
      controller.openOverlay('modal-1', settings: const OverlaySettings());
      controller.setVariable('count', 5);
      controller.reset('home');

      expect(controller.currentNodeId, 'home');
      expect(controller.state.history.length, 1);
      expect(controller.hasOverlays, false);
      expect(controller.state.variables, isEmpty);
    });

    test('pause and play toggle state', () {
      expect(controller.state.isPlaying, true);

      controller.pause();
      expect(controller.state.isPlaying, false);

      controller.play();
      expect(controller.state.isPlaying, true);
    });

    test('registerInteractions stores node interactions', () {
      const interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [],
      );

      controller.registerInteractions('button-1', interactions);
      expect(controller.getInteractions('button-1'), isNotNull);
    });

    test('handleTrigger executes matching interactions', () {
      String? navigatedTo;
      controller.onNavigate = (nodeId, _) => navigatedTo = nodeId;

      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [Interaction.navigateTo('screen-2')],
      );

      controller.registerInteractions('button-1', interactions);
      controller.handleTrigger('button-1', InteractionTrigger.onClick);

      expect(navigatedTo, 'screen-2');
    });
  });

  group('PrototypePlayer Widget', () {
    testWidgets('renders with controller', (tester) async {
      final controller = PrototypePlayerController(startingNodeId: 'home');

      await tester.pumpWidget(
        MaterialApp(
          home: PrototypePlayer(
            controller: controller,
            nodeBuilder: (context, nodeId) {
              return Container(
                color: Colors.white,
                child: Center(child: Text('Node: $nodeId')),
              );
            },
          ),
        ),
      );

      expect(find.text('Node: home'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('shows controls when enabled', (tester) async {
      final controller = PrototypePlayerController(startingNodeId: 'home');

      await tester.pumpWidget(
        MaterialApp(
          home: PrototypePlayer(
            controller: controller,
            nodeBuilder: (_, __) => const SizedBox(),
            showControls: true,
          ),
        ),
      );

      // Should find play/pause and refresh buttons
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      controller.dispose();
    });

    testWidgets('hides controls when disabled', (tester) async {
      final controller = PrototypePlayerController(startingNodeId: 'home');

      await tester.pumpWidget(
        MaterialApp(
          home: PrototypePlayer(
            controller: controller,
            nodeBuilder: (_, __) => const SizedBox(),
            showControls: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);

      controller.dispose();
    });
  });

  group('InteractiveHotspot Widget', () {
    testWidgets('renders child widget', (tester) async {
      final controller = PrototypePlayerController(startingNodeId: 'home');

      await tester.pumpWidget(
        MaterialApp(
          home: InteractiveHotspot(
            nodeId: 'button-1',
            controller: controller,
            child: const Text('Click me'),
          ),
        ),
      );

      expect(find.text('Click me'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('triggers onClick on tap', (tester) async {
      final controller = PrototypePlayerController(startingNodeId: 'home');
      String? triggeredNodeId;
      InteractionTrigger? triggeredType;

      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [
          Interaction(
            trigger: InteractionTrigger.onClick,
            action: InteractionAction.navigate,
            destinationNodeId: 'screen-2',
          ),
        ],
      );
      controller.registerInteractions('button-1', interactions);

      controller.onNavigate = (nodeId, _) {
        triggeredNodeId = nodeId;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: InteractiveHotspot(
            nodeId: 'button-1',
            controller: controller,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      await tester.tap(find.byType(InteractiveHotspot));
      await tester.pump();

      expect(triggeredNodeId, 'screen-2');

      controller.dispose();
    });

    testWidgets('shows hotspot hint when enabled', (tester) async {
      final controller = PrototypePlayerController(startingNodeId: 'home');

      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [Interaction.navigateTo('screen-2')],
      );
      controller.registerInteractions('button-1', interactions);

      await tester.pumpWidget(
        MaterialApp(
          home: InteractiveHotspot(
            nodeId: 'button-1',
            controller: controller,
            showHotspotHint: true,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );

      // Should find decorated container for hotspot hint
      expect(find.byType(Container), findsWidgets);

      controller.dispose();
    });
  });

  group('InteractionEditorPanel Widget', () {
    testWidgets('renders empty state when no interactions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractionEditorPanel(
              availableNodeIds: const ['frame-1', 'frame-2'],
              onInteractionsChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('No interactions'), findsOneWidget);
      expect(find.text('Add interaction'), findsOneWidget);
    });

    testWidgets('renders interaction list', (tester) async {
      final interactions = NodeInteractions(
        nodeId: 'button-1',
        interactions: [
          Interaction.navigateTo('frame-1'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractionEditorPanel(
              interactions: interactions,
              availableNodeIds: const ['frame-1', 'frame-2'],
              onInteractionsChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('On click'), findsOneWidget);
    });

    testWidgets('adds new interaction on button press', (tester) async {
      NodeInteractions? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractionEditorPanel(
              availableNodeIds: const ['frame-1', 'frame-2'],
              onInteractionsChanged: (i) => updated = i,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add interaction'));
      await tester.pump();

      expect(updated?.interactions.length, 1);
    });
  });

  group('FlowConnection', () {
    test('creates with all parameters', () {
      const connection = FlowConnection(
        fromNodeId: 'button-1',
        toNodeId: 'screen-2',
        start: Offset(100, 100),
        end: Offset(300, 200),
        trigger: InteractionTrigger.onClick,
      );

      expect(connection.fromNodeId, 'button-1');
      expect(connection.toNodeId, 'screen-2');
      expect(connection.start, const Offset(100, 100));
      expect(connection.end, const Offset(300, 200));
      expect(connection.trigger, InteractionTrigger.onClick);
    });
  });
}
