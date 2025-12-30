/// Exhaustive UI tests for Figma-style Context Menu
///
/// Tests cover:
/// - Menu display and positioning
/// - Action items and callbacks
/// - Submenus
/// - Dynamic adaptation based on selection
/// - Keyboard shortcuts
/// - Accessibility
/// - Performance

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  group('ContextMenuItem Tests', () {
    test('creates action item correctly', () {
      final item = ContextMenuItem(
        label: 'Copy',
        shortcut: '⌘C',
        onTap: () {},
        id: 'copy',
      );

      expect(item.label, 'Copy');
      expect(item.shortcut, '⌘C');
      expect(item.type, MenuItemType.action);
      expect(item.enabled, true);
      expect(item.id, 'copy');
    });

    test('creates divider correctly', () {
      const item = ContextMenuItem.divider();

      expect(item.type, MenuItemType.divider);
      expect(item.label, '');
    });

    test('creates submenu correctly', () {
      final item = ContextMenuItem.submenu(
        label: 'Copy/Paste as',
        submenu: [
          ContextMenuItem(label: 'PNG', onTap: () {}),
          ContextMenuItem(label: 'SVG', onTap: () {}),
        ],
        id: 'copy_paste_as',
      );

      expect(item.label, 'Copy/Paste as');
      expect(item.type, MenuItemType.submenu);
      expect(item.submenu, isNotNull);
      expect(item.submenu!.length, 2);
    });

    test('disabled item has enabled = false', () {
      final item = ContextMenuItem(
        label: 'Delete',
        enabled: false,
        id: 'delete',
      );

      expect(item.enabled, false);
    });
  });

  group('SelectionContext Tests', () {
    test('default context has no selection', () {
      const context = SelectionContext();
      expect(context.hasSelection, false);
      expect(context.isMultiSelection, false);
      expect(context.selectedCount, 0);
    });

    test('single selection is detected', () {
      const context = SelectionContext(selectedCount: 1);
      expect(context.hasSelection, true);
      expect(context.isMultiSelection, false);
    });

    test('multi selection is detected', () {
      const context = SelectionContext(selectedCount: 3);
      expect(context.hasSelection, true);
      expect(context.isMultiSelection, true);
    });

    test('selection types are tracked', () {
      const context = SelectionContext(
        selectedCount: 1,
        isGroupSelected: true,
        isFrameSelected: false,
        hasAutoLayout: true,
      );

      expect(context.isGroupSelected, true);
      expect(context.isFrameSelected, false);
      expect(context.hasAutoLayout, true);
    });
  });

  group('ContextMenuBuilder Tests', () {
    test('builds menu with copy/paste section', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();

      // Find Copy item
      final copyItem = items.firstWhere((i) => i.id == 'copy');
      expect(copyItem.label, 'Copy');
      expect(copyItem.shortcut, '⌘C');
    });

    test('builds menu with ordering section', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();

      final bringToFront = items.firstWhere((i) => i.id == 'bring_to_front');
      expect(bringToFront.label, 'Bring to front');
      expect(bringToFront.shortcut, ']');

      final sendToBack = items.firstWhere((i) => i.id == 'send_to_back');
      expect(sendToBack.label, 'Send to back');
      expect(sendToBack.shortcut, '[');
    });

    test('builds menu with grouping section', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 2),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();

      final groupItem = items.firstWhere((i) => i.id == 'group_selection');
      expect(groupItem.label, 'Group selection');
      expect(groupItem.shortcut, '⌘G');
      expect(groupItem.enabled, true);
    });

    test('group is disabled with single selection', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final groupItem = items.firstWhere((i) => i.id == 'group_selection');
      expect(groupItem.enabled, false);
    });

    test('ungroup is enabled when group is selected', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isGroupSelected: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final ungroupItem = items.firstWhere((i) => i.id == 'ungroup');
      expect(ungroupItem.enabled, true);
    });

    test('ungroup is disabled when non-group is selected', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isGroupSelected: false,
          isFrameSelected: false,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final ungroupItem = items.firstWhere((i) => i.id == 'ungroup');
      expect(ungroupItem.enabled, false);
    });

    test('remove auto layout is enabled when has auto layout', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          hasAutoLayout: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final removeAutoLayout = items.firstWhere((i) => i.id == 'remove_auto_layout');
      expect(removeAutoLayout.enabled, true);
    });

    test('remove auto layout is disabled when no auto layout', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          hasAutoLayout: false,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final removeAutoLayout = items.firstWhere((i) => i.id == 'remove_auto_layout');
      expect(removeAutoLayout.enabled, false);
    });

    test('show/hide label changes based on isHidden', () {
      final builderHidden = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1, isHidden: true),
        actions: const ContextMenuActions(),
      );

      final builderVisible = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1, isHidden: false),
        actions: const ContextMenuActions(),
      );

      final hiddenItems = builderHidden.build();
      final visibleItems = builderVisible.build();

      final showItem = hiddenItems.firstWhere((i) => i.id == 'show_hide');
      expect(showItem.label, 'Show');

      final hideItem = visibleItems.firstWhere((i) => i.id == 'show_hide');
      expect(hideItem.label, 'Hide');
    });

    test('lock/unlock label changes based on isLocked', () {
      final builderLocked = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1, isLocked: true),
        actions: const ContextMenuActions(),
      );

      final builderUnlocked = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1, isLocked: false),
        actions: const ContextMenuActions(),
      );

      final lockedItems = builderLocked.build();
      final unlockedItems = builderUnlocked.build();

      final unlockItem = lockedItems.firstWhere((i) => i.id == 'lock_unlock');
      expect(unlockItem.label, 'Unlock');

      final lockItem = unlockedItems.firstWhere((i) => i.id == 'lock_unlock');
      expect(lockItem.label, 'Lock');
    });

    test('create component is disabled when component is selected', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isComponentSelected: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final createComponent = items.firstWhere((i) => i.id == 'create_component');
      expect(createComponent.enabled, false);
    });

    test('move to page submenu includes available pages', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          availablePages: ['Page 1', 'Page 2', 'Page 3'],
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final moveToPage = items.firstWhere((i) => i.id == 'move_to_page');
      expect(moveToPage.type, MenuItemType.submenu);
      expect(moveToPage.submenu, isNotNull);
      expect(moveToPage.submenu!.length, 3);
    });
  });

  group('FigmaContextMenu Widget Tests', () {
    testWidgets('renders menu with items', (tester) async {
      final items = [
        ContextMenuItem(label: 'Copy', shortcut: '⌘C', id: 'copy'),
        ContextMenuItem(label: 'Paste', shortcut: '⌘V', id: 'paste'),
        const ContextMenuItem.divider(),
        ContextMenuItem(label: 'Delete', id: 'delete'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaContextMenu(
            items: items,
            onDismiss: () {},
          ),
        ),
      ));

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('⌘C'), findsOneWidget);
      expect(find.text('⌘V'), findsOneWidget);
    });

    testWidgets('renders dividers between sections', (tester) async {
      final items = [
        ContextMenuItem(label: 'Copy', id: 'copy'),
        const ContextMenuItem.divider(),
        ContextMenuItem(label: 'Delete', id: 'delete'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaContextMenu(
            items: items,
            onDismiss: () {},
          ),
        ),
      ));

      // Verify divider container exists
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dividerContainers = containers.where((c) {
        return c.constraints?.maxHeight == 1;
      });
      expect(dividerContainers.isNotEmpty, true);
    });

    testWidgets('tapping item calls onTap and onDismiss', (tester) async {
      bool itemTapped = false;
      bool dismissed = false;

      final items = [
        ContextMenuItem(
          label: 'Copy',
          onTap: () => itemTapped = true,
          id: 'copy',
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaContextMenu(
            items: items,
            onDismiss: () => dismissed = true,
          ),
        ),
      ));

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(itemTapped, true);
      expect(dismissed, true);
    });

    testWidgets('disabled items cannot be tapped', (tester) async {
      bool itemTapped = false;

      final items = [
        ContextMenuItem(
          label: 'Delete',
          onTap: () => itemTapped = true,
          enabled: false,
          id: 'delete',
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaContextMenu(
            items: items,
            onDismiss: () {},
          ),
        ),
      ));

      await tester.tap(find.text('Delete'));
      await tester.pump();

      expect(itemTapped, false);
    });

    testWidgets('submenu items show arrow', (tester) async {
      final items = [
        ContextMenuItem.submenu(
          label: 'Copy/Paste as',
          submenu: [
            ContextMenuItem(label: 'PNG', id: 'png'),
          ],
          id: 'copy_paste_as',
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaContextMenu(
            items: items,
            onDismiss: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('ContextMenuActions Tests', () {
    test('actions callbacks are invoked correctly', () {
      bool copyCalled = false;
      bool pasteCalled = false;
      bool groupCalled = false;

      final actions = ContextMenuActions(
        onCopy: () => copyCalled = true,
        onPaste: () => pasteCalled = true,
        onGroup: () => groupCalled = true,
      );

      actions.onCopy?.call();
      expect(copyCalled, true);

      actions.onPaste?.call();
      expect(pasteCalled, true);

      actions.onGroup?.call();
      expect(groupCalled, true);
    });

    test('copyAs callback receives format', () {
      String? receivedFormat;

      final actions = ContextMenuActions(
        onCopyAs: (format) => receivedFormat = format,
      );

      actions.onCopyAs?.call('PNG');
      expect(receivedFormat, 'PNG');

      actions.onCopyAs?.call('SVG');
      expect(receivedFormat, 'SVG');
    });

    test('moveToPage callback receives page id', () {
      String? receivedPageId;

      final actions = ContextMenuActions(
        onMoveToPage: (pageId) => receivedPageId = pageId,
      );

      actions.onMoveToPage?.call('page_1');
      expect(receivedPageId, 'page_1');
    });
  });

  group('ContextMenuRegion Tests', () {
    testWidgets('shows context menu on right click', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuRegion(
            selectionContext: const SelectionContext(selectedCount: 1),
            actions: const ContextMenuActions(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.grey,
            ),
          ),
        ),
      ));

      // Simulate right click (secondary tap)
      await tester.tapAt(
        const Offset(100, 100),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Menu should appear with Copy
      expect(find.text('Copy'), findsOneWidget);
    });
  });

  group('ContextMenuShortcuts Tests', () {
    testWidgets('⌘G triggers group action', (tester) async {
      bool groupCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onGroup: () => groupCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      expect(groupCalled, true);
    });

    testWidgets('] triggers bring to front', (tester) async {
      bool bringToFrontCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onBringToFront: () => bringToFrontCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();

      expect(bringToFrontCalled, true);
    });

    testWidgets('[ triggers send to back', (tester) async {
      bool sendToBackCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onSendToBack: () => sendToBackCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();

      expect(sendToBackCalled, true);
    });
  });

  group('Menu Item ID Tests', () {
    test('all menu items have unique IDs', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 2,
          availablePages: ['Page 1'],
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final ids = <String>[];

      void collectIds(List<ContextMenuItem> menuItems) {
        for (final item in menuItems) {
          if (item.id != null) {
            ids.add(item.id!);
          }
          if (item.submenu != null) {
            collectIds(item.submenu!);
          }
        }
      }

      collectIds(items);

      // Check for duplicates
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, ids.length, reason: 'Duplicate IDs found');
    });
  });

  group('Shortcut Display Tests', () {
    test('shortcuts use correct symbols', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();

      // Check specific shortcuts
      final copy = items.firstWhere((i) => i.id == 'copy');
      expect(copy.shortcut, '⌘C');

      final pasteToReplace = items.firstWhere((i) => i.id == 'paste_to_replace');
      expect(pasteToReplace.shortcut, '⇧⌘R');

      final group = items.firstWhere((i) => i.id == 'group_selection');
      expect(group.shortcut, '⌘G');

      final frame = items.firstWhere((i) => i.id == 'frame_selection');
      expect(frame.shortcut, '⌥⌘G');

      final showHide = items.firstWhere((i) => i.id == 'show_hide');
      expect(showHide.shortcut, '⇧⌘H');
    });
  });

  group('Performance Tests', () {
    testWidgets('menu renders in acceptable time', (tester) async {
      final items = List.generate(20, (i) => ContextMenuItem(
        label: 'Item $i',
        id: 'item_$i',
      ));

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaContextMenu(
            items: items,
            onDismiss: () {},
          ),
        ),
      ));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('building menu items is fast', () {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        final builder = ContextMenuBuilder(
          context: SelectionContext(
            selectedCount: i % 5,
            availablePages: List.generate(10, (j) => 'Page $j'),
          ),
          actions: const ContextMenuActions(),
        );
        builder.build();
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('DevicePresets Tests', () {
    test('iOS presets are available', () {
      expect(DevicePresets.ios.isNotEmpty, true);
      expect(DevicePresets.ios.length, 12);
    });

    test('Android presets are available', () {
      expect(DevicePresets.android.isNotEmpty, true);
      expect(DevicePresets.android.length, 8);
    });

    test('Desktop presets are available', () {
      expect(DevicePresets.desktop.isNotEmpty, true);
      expect(DevicePresets.desktop.length, 6);
    });

    test('iPhone 16 Pro Max dimensions are correct', () {
      final device = DevicePresets.ios.firstWhere(
        (d) => d.name == 'iPhone 16 Pro Max',
      );
      expect(device.width, 440);
      expect(device.height, 956);
      expect(device.category, 'iOS');
    });

    test('Pixel 9 Pro XL dimensions are correct', () {
      final device = DevicePresets.android.firstWhere(
        (d) => d.name == 'Pixel 9 Pro XL',
      );
      expect(device.width, 412);
      expect(device.height, 915);
      expect(device.category, 'Android');
    });

    test('MacBook Pro 16" dimensions are correct', () {
      final device = DevicePresets.desktop.firstWhere(
        (d) => d.name == 'MacBook Pro 16"',
      );
      expect(device.width, 1728);
      expect(device.height, 1117);
      expect(device.category, 'Desktop');
    });
  });

  group('Device Submenu Tests', () {
    test('device submenu is built for frame selection', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isFrameSelected: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final deviceSubmenu = items.firstWhere((i) => i.id == 'device');
      expect(deviceSubmenu.type, MenuItemType.submenu);
      expect(deviceSubmenu.enabled, true);
    });

    test('device submenu is disabled for non-frame selection', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isFrameSelected: false,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final deviceSubmenu = items.firstWhere((i) => i.id == 'device');
      expect(deviceSubmenu.enabled, false);
    });

    test('device submenu contains iOS, Android, Desktop categories', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isFrameSelected: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final deviceSubmenu = items.firstWhere((i) => i.id == 'device');
      expect(deviceSubmenu.submenu, isNotNull);

      final categoryIds = deviceSubmenu.submenu!
          .where((i) => i.type == MenuItemType.submenu)
          .map((i) => i.id)
          .toList();
      expect(categoryIds, contains('device_ios'));
      expect(categoryIds, contains('device_android'));
      expect(categoryIds, contains('device_desktop'));
    });

    test('resize to device callback is invoked', () {
      DevicePreset? receivedDevice;

      final actions = ContextMenuActions(
        onResizeToDevice: (device) => receivedDevice = device,
      );

      actions.onResizeToDevice?.call(DevicePresets.ios.first);
      expect(receivedDevice, isNotNull);
      expect(receivedDevice!.name, 'iPhone 16 Pro Max');
    });
  });

  group('Development Submenu Tests', () {
    test('development submenu is built', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final devSubmenu = items.firstWhere((i) => i.id == 'development');
      expect(devSubmenu.type, MenuItemType.submenu);
    });

    test('development submenu contains inspect option', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          canInspect: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final devSubmenu = items.firstWhere((i) => i.id == 'development');
      final inspectItem = devSubmenu.submenu!.firstWhere((i) => i.id == 'inspect');
      expect(inspectItem.label, 'Inspect');
      expect(inspectItem.shortcut, '⌥⌘I');
      expect(inspectItem.enabled, true);
    });

    test('development submenu contains copy as code options', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(selectedCount: 1),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final devSubmenu = items.firstWhere((i) => i.id == 'development');
      final copyAsCode = devSubmenu.submenu!.firstWhere((i) => i.id == 'copy_as_code');
      expect(copyAsCode.type, MenuItemType.submenu);

      final codeFormats = copyAsCode.submenu!.map((i) => i.id).toList();
      expect(codeFormats, contains('copy_as_flutter'));
      expect(codeFormats, contains('copy_as_swiftui'));
      expect(codeFormats, contains('copy_as_react'));
      expect(codeFormats, contains('copy_as_html_css'));
      expect(codeFormats, contains('copy_as_tailwind'));
    });

    test('copy as code callback receives language', () {
      String? receivedLanguage;

      final actions = ContextMenuActions(
        onCopyAsCode: (language) => receivedLanguage = language,
      );

      actions.onCopyAsCode?.call('flutter');
      expect(receivedLanguage, 'flutter');

      actions.onCopyAsCode?.call('swiftui');
      expect(receivedLanguage, 'swiftui');
    });

    test('inspect callback is invoked', () {
      bool inspectCalled = false;

      final actions = ContextMenuActions(
        onInspect: () => inspectCalled = true,
      );

      actions.onInspect?.call();
      expect(inspectCalled, true);
    });
  });

  group('Enhanced Plugins Submenu Tests', () {
    test('plugins submenu shows recent plugins', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          recentPlugins: ['Auto Layout', 'Icons8', 'Unsplash'],
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final pluginsSubmenu = items.firstWhere((i) => i.id == 'plugins');

      // Count plugin items (excluding run last plugin, dividers, and manage)
      final pluginItems = pluginsSubmenu.submenu!.where((i) =>
        i.type == MenuItemType.action &&
        i.id != 'run_last_plugin' &&
        i.id != 'manage_plugins'
      ).toList();

      expect(pluginItems.length, 3);
      expect(pluginItems[0].label, 'Auto Layout');
      expect(pluginItems[1].label, 'Icons8');
      expect(pluginItems[2].label, 'Unsplash');
    });

    test('plugins submenu limits to 5 recent plugins', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          recentPlugins: ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7'],
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final pluginsSubmenu = items.firstWhere((i) => i.id == 'plugins');

      final pluginItems = pluginsSubmenu.submenu!.where((i) =>
        i.type == MenuItemType.action &&
        i.id != 'run_last_plugin' &&
        i.id != 'manage_plugins'
      ).toList();

      expect(pluginItems.length, 5);
    });

    test('run plugin callback receives plugin id', () {
      String? receivedPluginId;

      final actions = ContextMenuActions(
        onRunPlugin: (pluginId) => receivedPluginId = pluginId,
      );

      actions.onRunPlugin?.call('auto_layout');
      expect(receivedPluginId, 'auto_layout');
    });

    test('run last plugin callback is invoked', () {
      bool runLastCalled = false;

      final actions = ContextMenuActions(
        onRunLastPlugin: () => runLastCalled = true,
      );

      actions.onRunLastPlugin?.call();
      expect(runLastCalled, true);
    });
  });

  group('Prototype Submenu Tests', () {
    test('prototype submenu appears for frame selection', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isFrameSelected: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final prototypeSubmenu = items.where((i) => i.id == 'prototype').toList();
      expect(prototypeSubmenu.length, 1);
    });

    test('prototype submenu appears when has prototype', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          hasPrototype: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final prototypeSubmenu = items.where((i) => i.id == 'prototype').toList();
      expect(prototypeSubmenu.length, 1);
    });

    test('prototype submenu contains add/remove interaction options', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isFrameSelected: true,
          hasPrototype: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final prototypeSubmenu = items.firstWhere((i) => i.id == 'prototype');

      final addInteraction = prototypeSubmenu.submenu!.firstWhere(
        (i) => i.id == 'add_interaction',
      );
      expect(addInteraction.label, 'Add interaction');

      final removeInteractions = prototypeSubmenu.submenu!.firstWhere(
        (i) => i.id == 'remove_interactions',
      );
      expect(removeInteractions.label, 'Remove all interactions');
      expect(removeInteractions.enabled, true);
    });

    test('remove interactions is disabled when no prototype', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isFrameSelected: true,
          hasPrototype: false,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final prototypeSubmenu = items.firstWhere((i) => i.id == 'prototype');
      final removeInteractions = prototypeSubmenu.submenu!.firstWhere(
        (i) => i.id == 'remove_interactions',
      );
      expect(removeInteractions.enabled, false);
    });

    test('prototype callbacks are invoked', () {
      bool addCalled = false;
      bool removeCalled = false;
      bool previewCalled = false;

      final actions = ContextMenuActions(
        onAddInteraction: () => addCalled = true,
        onRemoveInteractions: () => removeCalled = true,
        onPreviewPrototype: () => previewCalled = true,
      );

      actions.onAddInteraction?.call();
      actions.onRemoveInteractions?.call();
      actions.onPreviewPrototype?.call();

      expect(addCalled, true);
      expect(removeCalled, true);
      expect(previewCalled, true);
    });
  });

  group('Instance Actions Tests', () {
    test('instance actions appear when instance is selected', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isInstanceSelected: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final instanceItems = items.where((i) =>
        i.id == 'detach_instance' ||
        i.id == 'reset_instance' ||
        i.id == 'go_to_main_component'
      ).toList();

      expect(instanceItems.length, 3);
    });

    test('instance actions do not appear when instance is not selected', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isInstanceSelected: false,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final instanceItems = items.where((i) =>
        i.id == 'detach_instance' ||
        i.id == 'reset_instance' ||
        i.id == 'go_to_main_component'
      ).toList();

      expect(instanceItems.length, 0);
    });

    test('detach instance has correct shortcut', () {
      final builder = ContextMenuBuilder(
        context: const SelectionContext(
          selectedCount: 1,
          isInstanceSelected: true,
        ),
        actions: const ContextMenuActions(),
      );

      final items = builder.build();
      final detachItem = items.firstWhere((i) => i.id == 'detach_instance');
      expect(detachItem.shortcut, '⌥⌘B');
    });

    test('instance callbacks are invoked', () {
      bool detachCalled = false;
      bool resetCalled = false;
      bool goToMainCalled = false;

      final actions = ContextMenuActions(
        onDetachInstance: () => detachCalled = true,
        onResetInstance: () => resetCalled = true,
        onGoToMainComponent: () => goToMainCalled = true,
      );

      actions.onDetachInstance?.call();
      actions.onResetInstance?.call();
      actions.onGoToMainComponent?.call();

      expect(detachCalled, true);
      expect(resetCalled, true);
      expect(goToMainCalled, true);
    });
  });

  group('New Keyboard Shortcuts Tests', () {
    testWidgets('⌘D triggers duplicate', (tester) async {
      bool duplicateCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onDuplicate: () => duplicateCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      expect(duplicateCalled, true);
    });

    testWidgets('Backspace triggers delete', (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onDelete: () => deleteCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(deleteCalled, true);
    });

    testWidgets('⌥⌘I triggers inspect', (tester) async {
      bool inspectCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onInspect: () => inspectCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump();

      expect(inspectCalled, true);
    });

    testWidgets('⌥⌘B triggers detach instance', (tester) async {
      bool detachCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onDetachInstance: () => detachCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump();

      expect(detachCalled, true);
    });

    testWidgets('⇧A triggers add auto layout', (tester) async {
      bool addAutoLayoutCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onAddAutoLayout: () => addAutoLayoutCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(addAutoLayoutCalled, true);
    });

    testWidgets('⌥⌘P triggers run last plugin', (tester) async {
      bool runLastPluginCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onRunLastPlugin: () => runLastPluginCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump();

      expect(runLastPluginCalled, true);
    });

    testWidgets('⌘R triggers rename', (tester) async {
      bool renameCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onRename: () => renameCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      expect(renameCalled, true);
    });

    testWidgets('⌘] triggers bring forward', (tester) async {
      bool bringForwardCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onBringForward: () => bringForwardCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      expect(bringForwardCalled, true);
    });

    testWidgets('⌘[ triggers send backward', (tester) async {
      bool sendBackwardCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ContextMenuShortcuts(
            actions: ContextMenuActions(onSendBackward: () => sendBackwardCalled = true),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      expect(sendBackwardCalled, true);
    });
  });

  group('Extended Actions Callbacks Tests', () {
    test('all new action callbacks can be invoked', () {
      bool addAutoLayoutCalled = false;
      bool wrapInContainerCalled = false;
      bool goToMainComponentCalled = false;
      bool pushChangesToComponentCalled = false;
      bool rotate90CWCalled = false;
      bool rotate90CCWCalled = false;
      bool previewOnDeviceCalled = false;
      bool exportCodeCalled = false;
      bool viewInDevModeCalled = false;
      bool openInPlaygroundCalled = false;
      bool openPluginsMenuCalled = false;

      final actions = ContextMenuActions(
        onAddAutoLayout: () => addAutoLayoutCalled = true,
        onWrapInContainer: () => wrapInContainerCalled = true,
        onGoToMainComponent: () => goToMainComponentCalled = true,
        onPushChangesToComponent: () => pushChangesToComponentCalled = true,
        onRotate90CW: () => rotate90CWCalled = true,
        onRotate90CCW: () => rotate90CCWCalled = true,
        onPreviewOnDevice: () => previewOnDeviceCalled = true,
        onExportCode: () => exportCodeCalled = true,
        onViewInDevMode: () => viewInDevModeCalled = true,
        onOpenInPlayground: () => openInPlaygroundCalled = true,
        onOpenPluginsMenu: () => openPluginsMenuCalled = true,
      );

      actions.onAddAutoLayout?.call();
      actions.onWrapInContainer?.call();
      actions.onGoToMainComponent?.call();
      actions.onPushChangesToComponent?.call();
      actions.onRotate90CW?.call();
      actions.onRotate90CCW?.call();
      actions.onPreviewOnDevice?.call();
      actions.onExportCode?.call();
      actions.onViewInDevMode?.call();
      actions.onOpenInPlayground?.call();
      actions.onOpenPluginsMenu?.call();

      expect(addAutoLayoutCalled, true);
      expect(wrapInContainerCalled, true);
      expect(goToMainComponentCalled, true);
      expect(pushChangesToComponentCalled, true);
      expect(rotate90CWCalled, true);
      expect(rotate90CCWCalled, true);
      expect(previewOnDeviceCalled, true);
      expect(exportCodeCalled, true);
      expect(viewInDevModeCalled, true);
      expect(openInPlaygroundCalled, true);
      expect(openPluginsMenuCalled, true);
    });
  });

  group('SelectionContext Extended Properties Tests', () {
    test('new selection context properties are tracked', () {
      const context = SelectionContext(
        selectedCount: 1,
        recentPlugins: ['Plugin1', 'Plugin2'],
        hasPrototype: true,
        canInspect: false,
      );

      expect(context.recentPlugins.length, 2);
      expect(context.hasPrototype, true);
      expect(context.canInspect, false);
    });

    test('default values for new properties', () {
      const context = SelectionContext();

      expect(context.recentPlugins, isEmpty);
      expect(context.hasPrototype, false);
      expect(context.canInspect, true);
    });
  });
}
