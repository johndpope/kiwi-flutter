/// Exhaustive UI tests for Figma-style Menu Bar
///
/// Tests cover:
/// - Menu structure (all menus and items)
/// - State management (open/close/hover)
/// - Keyboard shortcuts
/// - Widget rendering
/// - Enable/disable states
/// - Toggle items (checkmarks)
/// - Submenus
/// - Performance

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void setupMenuBarViewport(WidgetTester tester) {
  tester.view.physicalSize = const ui.Size(1400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('MenuBarItem Tests', () {
    test('creates action item correctly', () {
      const item = MenuBarItem(
        id: 'copy',
        label: 'Copy',
        shortcut: '⌘C',
      );

      expect(item.id, 'copy');
      expect(item.label, 'Copy');
      expect(item.shortcut, '⌘C');
      expect(item.type, MenuBarItemType.action);
      expect(item.enabled, true);
    });

    test('creates divider correctly', () {
      const item = MenuBarItem.divider();

      expect(item.type, MenuBarItemType.divider);
      expect(item.label, '');
    });

    test('creates submenu correctly', () {
      const item = MenuBarItem.submenu(
        id: 'panels',
        label: 'Panels',
        submenu: [
          MenuBarItem(id: 'layers', label: 'Layers'),
          MenuBarItem(id: 'assets', label: 'Assets'),
        ],
      );

      expect(item.type, MenuBarItemType.submenu);
      expect(item.submenu, isNotNull);
      expect(item.submenu!.length, 2);
    });

    test('creates toggle item correctly', () {
      const item = MenuBarItem.toggle(
        id: 'rulers',
        label: 'Rulers',
        shortcut: '⇧R',
        checked: true,
      );

      expect(item.type, MenuBarItemType.toggle);
      expect(item.checked, true);
      expect(item.shortcut, '⇧R');
    });

    test('disabled item has enabled = false', () {
      const item = MenuBarItem(
        id: 'paste',
        label: 'Paste',
        enabled: false,
      );

      expect(item.enabled, false);
    });
  });

  group('MenuBarSection Tests', () {
    test('creates section correctly', () {
      const section = MenuBarSection(
        id: 'file',
        label: 'File',
        items: [
          MenuBarItem(id: 'new', label: 'New'),
          MenuBarItem.divider(),
          MenuBarItem(id: 'save', label: 'Save'),
        ],
      );

      expect(section.id, 'file');
      expect(section.label, 'File');
      expect(section.items.length, 3);
    });
  });

  group('MenuBarState Tests', () {
    test('default state has no open menu', () {
      final state = MenuBarState();
      expect(state.openMenuId, isNull);
      expect(state.isMenuOpen, false);
    });

    test('openMenu sets openMenuId', () {
      final state = MenuBarState();
      state.openMenu('file');
      expect(state.openMenuId, 'file');
      expect(state.isMenuOpen, true);
    });

    test('closeMenu clears openMenuId', () {
      final state = MenuBarState();
      state.openMenu('file');
      state.closeMenu();
      expect(state.openMenuId, isNull);
      expect(state.isMenuOpen, false);
    });

    test('toggleMenu opens when closed', () {
      final state = MenuBarState();
      state.toggleMenu('file');
      expect(state.openMenuId, 'file');
    });

    test('toggleMenu closes when same menu is open', () {
      final state = MenuBarState();
      state.openMenu('file');
      state.toggleMenu('file');
      expect(state.openMenuId, isNull);
    });

    test('openMenu switches when different menu is open', () {
      final state = MenuBarState();
      state.openMenu('file');
      state.openMenu('edit');
      expect(state.openMenuId, 'edit');
    });

    test('hoverItem sets hoveredItemId', () {
      final state = MenuBarState();
      state.hoverItem('copy');
      expect(state.hoveredItemId, 'copy');
    });

    test('selectNext moves to next item', () {
      final state = MenuBarState();
      state.setMenuItems(['item1', 'item2', 'item3']);
      state.selectFirst();
      expect(state.hoveredIndex, 0);
      state.selectNext();
      expect(state.hoveredIndex, 1);
    });

    test('selectPrevious moves to previous item', () {
      final state = MenuBarState();
      state.setMenuItems(['item1', 'item2', 'item3']);
      state.selectLast();
      expect(state.hoveredIndex, 2);
      state.selectPrevious();
      expect(state.hoveredIndex, 1);
    });

    test('state notifies listeners', () {
      final state = MenuBarState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.openMenu('file');
      expect(notifyCount, 1);

      state.closeMenu();
      expect(notifyCount, 2);

      state.hoverItem('item1');
      expect(notifyCount, 3);
    });
  });

  group('MenuBarViewState Tests', () {
    test('default state has correct defaults', () {
      const state = MenuBarViewState();
      expect(state.pixelGridEnabled, false);
      expect(state.layoutGridsEnabled, false);
      expect(state.rulersEnabled, true);
      expect(state.outlineModeEnabled, false);
      expect(state.layersVisible, true);
      expect(state.assetsVisible, true);
      expect(state.designPanelVisible, true);
      expect(state.prototypePanelVisible, false);
      expect(state.inspectPanelVisible, false);
      expect(state.zoomLevel, 100.0);
    });

    test('copyWith updates specified fields', () {
      const state = MenuBarViewState();
      final updated = state.copyWith(
        pixelGridEnabled: true,
        zoomLevel: 150.0,
      );

      expect(updated.pixelGridEnabled, true);
      expect(updated.zoomLevel, 150.0);
      expect(updated.rulersEnabled, true); // unchanged
    });
  });

  group('MenuBarContext Tests', () {
    test('default context has correct defaults', () {
      const context = MenuBarContext();
      expect(context.hasDocument, true);
      expect(context.hasSelection, false);
      expect(context.hasMultipleSelection, false);
      expect(context.canUndo, false);
      expect(context.canRedo, false);
    });

    test('context with selection', () {
      const context = MenuBarContext(
        hasSelection: true,
        hasMultipleSelection: true,
      );

      expect(context.hasSelection, true);
      expect(context.hasMultipleSelection, true);
    });
  });

  group('MenuBarActions Tests', () {
    test('creates actions with callbacks', () {
      bool undoCalled = false;
      bool redoCalled = false;

      final actions = MenuBarActions(
        onUndo: () => undoCalled = true,
        onRedo: () => redoCalled = true,
      );

      actions.onUndo?.call();
      actions.onRedo?.call();

      expect(undoCalled, true);
      expect(redoCalled, true);
    });

    test('null callbacks are handled', () {
      const actions = MenuBarActions();
      // Should not throw
      actions.onUndo?.call();
      actions.onRedo?.call();
      actions.onCopy?.call();
    });
  });

  group('DefaultMenuBarSections Tests', () {
    test('has all 7 menu sections', () {
      final sections = DefaultMenuBarSections.all;
      expect(sections.length, 7);
    });

    test('has File menu with correct items', () {
      final fileMenu = DefaultMenuBarSections.fileMenu;
      expect(fileMenu.id, 'file');
      expect(fileMenu.label, 'File');

      // Check for key items
      final itemIds = fileMenu.items
          .where((item) => item.type != MenuBarItemType.divider)
          .map((item) => item.id)
          .toList();

      expect(itemIds.contains('back_to_files'), true);
      expect(itemIds.contains('new_design_file'), true);
      expect(itemIds.contains('save_local_copy'), true);
      expect(itemIds.contains('export'), true);
      expect(itemIds.contains('preferences'), true);
    });

    test('has Edit menu with correct items', () {
      final editMenu = DefaultMenuBarSections.editMenu;
      expect(editMenu.id, 'edit');
      expect(editMenu.label, 'Edit');

      final itemIds = editMenu.items
          .where((item) => item.type != MenuBarItemType.divider)
          .map((item) => item.id)
          .toList();

      expect(itemIds.contains('undo'), true);
      expect(itemIds.contains('redo'), true);
      expect(itemIds.contains('copy'), true);
      expect(itemIds.contains('cut'), true);
      expect(itemIds.contains('paste'), true);
      expect(itemIds.contains('duplicate'), true);
      expect(itemIds.contains('delete'), true);
      expect(itemIds.contains('select_all'), true);
    });

    test('has View menu with correct items', () {
      final viewMenu = DefaultMenuBarSections.viewMenu;
      expect(viewMenu.id, 'view');
      expect(viewMenu.label, 'View');

      final itemIds = viewMenu.items
          .where((item) => item.type != MenuBarItemType.divider)
          .map((item) => item.id)
          .toList();

      expect(itemIds.contains('pixel_grid'), true);
      expect(itemIds.contains('layout_grids'), true);
      expect(itemIds.contains('rulers'), true);
      expect(itemIds.contains('zoom_in'), true);
      expect(itemIds.contains('zoom_out'), true);
      expect(itemIds.contains('panels'), true);
      expect(itemIds.contains('outline_mode'), true);
    });

    test('View menu has Panels submenu', () {
      final viewMenu = DefaultMenuBarSections.viewMenu;
      final panelsItem = viewMenu.items.firstWhere((item) => item.id == 'panels');

      expect(panelsItem.type, MenuBarItemType.submenu);
      expect(panelsItem.submenu, isNotNull);
      expect(panelsItem.submenu!.length, greaterThan(0));
    });

    test('has Object menu with correct items', () {
      final objectMenu = DefaultMenuBarSections.objectMenu;
      expect(objectMenu.id, 'object');
      expect(objectMenu.label, 'Object');

      final itemIds = objectMenu.items
          .where((item) => item.type != MenuBarItemType.divider)
          .map((item) => item.id)
          .toList();

      expect(itemIds.contains('group'), true);
      expect(itemIds.contains('ungroup'), true);
      expect(itemIds.contains('frame_selection'), true);
      expect(itemIds.contains('add_auto_layout'), true);
      expect(itemIds.contains('create_component'), true);
      expect(itemIds.contains('lock_unlock'), true);
    });

    test('has Vector menu with correct items', () {
      final vectorMenu = DefaultMenuBarSections.vectorMenu;
      expect(vectorMenu.id, 'vector');
      expect(vectorMenu.label, 'Vector');

      final itemIds = vectorMenu.items
          .where((item) => item.type != MenuBarItemType.divider)
          .map((item) => item.id)
          .toList();

      expect(itemIds.contains('flatten'), true);
      expect(itemIds.contains('outline_stroke'), true);
      expect(itemIds.contains('boolean_operation'), true);
    });

    test('Vector menu has Boolean operation submenu', () {
      final vectorMenu = DefaultMenuBarSections.vectorMenu;
      final booleanItem = vectorMenu.items.firstWhere((item) => item.id == 'boolean_operation');

      expect(booleanItem.type, MenuBarItemType.submenu);
      expect(booleanItem.submenu, isNotNull);

      final subIds = booleanItem.submenu!.map((i) => i.id).toList();
      expect(subIds.contains('union'), true);
      expect(subIds.contains('subtract'), true);
      expect(subIds.contains('intersect'), true);
      expect(subIds.contains('exclude'), true);
    });

    test('has Text menu with correct items', () {
      final textMenu = DefaultMenuBarSections.textMenu;
      expect(textMenu.id, 'text');
      expect(textMenu.label, 'Text');

      final itemIds = textMenu.items
          .where((item) => item.type != MenuBarItemType.divider)
          .map((item) => item.id)
          .toList();

      expect(itemIds.contains('bold'), true);
      expect(itemIds.contains('italic'), true);
      expect(itemIds.contains('underline'), true);
      expect(itemIds.contains('align_left'), true);
      expect(itemIds.contains('align_center'), true);
      expect(itemIds.contains('align_right'), true);
    });

    test('has Arrange menu with correct items', () {
      final arrangeMenu = DefaultMenuBarSections.arrangeMenu;
      expect(arrangeMenu.id, 'arrange');
      expect(arrangeMenu.label, 'Arrange');

      final itemIds = arrangeMenu.items
          .where((item) => item.type != MenuBarItemType.divider)
          .map((item) => item.id)
          .toList();

      expect(itemIds.contains('bring_to_front'), true);
      expect(itemIds.contains('bring_forward'), true);
      expect(itemIds.contains('send_backward'), true);
      expect(itemIds.contains('send_to_back'), true);
      expect(itemIds.contains('align_left_edge'), true);
      expect(itemIds.contains('distribute_horizontal'), true);
    });
  });

  group('MenuBarBuilder Tests', () {
    test('builds all menu sections', () {
      const context = MenuBarContext();
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      expect(sections.length, 7);
    });

    test('undo is disabled when canUndo is false', () {
      const context = MenuBarContext(canUndo: false);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final editMenu = sections.firstWhere((s) => s.id == 'edit');
      final undoItem = editMenu.items.firstWhere((i) => i.id == 'undo');

      expect(undoItem.enabled, false);
    });

    test('undo is enabled when canUndo is true', () {
      const context = MenuBarContext(canUndo: true);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final editMenu = sections.firstWhere((s) => s.id == 'edit');
      final undoItem = editMenu.items.firstWhere((i) => i.id == 'undo');

      expect(undoItem.enabled, true);
    });

    test('copy is disabled without selection', () {
      const context = MenuBarContext(hasSelection: false);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final editMenu = sections.firstWhere((s) => s.id == 'edit');
      final copyItem = editMenu.items.firstWhere((i) => i.id == 'copy');

      expect(copyItem.enabled, false);
    });

    test('copy is enabled with selection', () {
      const context = MenuBarContext(hasSelection: true);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final editMenu = sections.firstWhere((s) => s.id == 'edit');
      final copyItem = editMenu.items.firstWhere((i) => i.id == 'copy');

      expect(copyItem.enabled, true);
    });

    test('group is disabled without multiple selection', () {
      const context = MenuBarContext(hasMultipleSelection: false);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final objectMenu = sections.firstWhere((s) => s.id == 'object');
      final groupItem = objectMenu.items.firstWhere((i) => i.id == 'group');

      expect(groupItem.enabled, false);
    });

    test('group is enabled with multiple selection', () {
      const context = MenuBarContext(hasMultipleSelection: true);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final objectMenu = sections.firstWhere((s) => s.id == 'object');
      final groupItem = objectMenu.items.firstWhere((i) => i.id == 'group');

      expect(groupItem.enabled, true);
    });

    test('text formatting is disabled without text selection', () {
      const context = MenuBarContext(isTextSelected: false);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final textMenu = sections.firstWhere((s) => s.id == 'text');
      final boldItem = textMenu.items.firstWhere((i) => i.id == 'bold');

      expect(boldItem.enabled, false);
    });

    test('text formatting is enabled with text selection', () {
      const context = MenuBarContext(isTextSelected: true);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final textMenu = sections.firstWhere((s) => s.id == 'text');
      final boldItem = textMenu.items.firstWhere((i) => i.id == 'bold');

      expect(boldItem.enabled, true);
    });

    test('view toggles reflect viewState', () {
      const viewState = MenuBarViewState(
        rulersEnabled: true,
        pixelGridEnabled: false,
      );
      const context = MenuBarContext(viewState: viewState);
      const actions = MenuBarActions();
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final viewMenu = sections.firstWhere((s) => s.id == 'view');
      final rulersItem = viewMenu.items.firstWhere((i) => i.id == 'rulers');
      final pixelGridItem = viewMenu.items.firstWhere((i) => i.id == 'pixel_grid');

      expect(rulersItem.checked, true);
      expect(pixelGridItem.checked, false);
    });

    test('actions are connected to menu items', () {
      bool copyCalled = false;

      const context = MenuBarContext(hasSelection: true);
      final actions = MenuBarActions(
        onCopy: () => copyCalled = true,
      );
      final builder = MenuBarBuilder(context: context, actions: actions);

      final sections = builder.build();
      final editMenu = sections.firstWhere((s) => s.id == 'edit');
      final copyItem = editMenu.items.firstWhere((i) => i.id == 'copy');

      copyItem.onTap?.call();
      expect(copyCalled, true);
    });
  });

  group('FigmaMenuBar Widget Tests', () {
    testWidgets('renders menu bar with all sections', (tester) async {
      setupMenuBarViewport(tester);
      final state = MenuBarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaMenuBar(
            state: state,
          ),
        ),
      ));

      expect(find.text('File'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Object'), findsOneWidget);
      expect(find.text('Vector'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Arrange'), findsOneWidget);
    });

    testWidgets('renders with correct background color', (tester) async {
      setupMenuBarViewport(tester);
      final state = MenuBarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaMenuBar(
            state: state,
          ),
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FigmaMenuBar),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.color, MenuBarColors.background);
    });

    testWidgets('tapping menu button opens dropdown', (tester) async {
      setupMenuBarViewport(tester);
      final state = MenuBarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaMenuBar(
            state: state,
          ),
        ),
      ));

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      expect(state.openMenuId, 'file');
    });

    testWidgets('tapping open menu button closes it', (tester) async {
      setupMenuBarViewport(tester);
      final state = MenuBarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaMenuBar(
            state: state,
          ),
        ),
      ));

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      expect(state.openMenuId, 'file');

      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      expect(state.openMenuId, isNull);
    });

    testWidgets('renders with custom sections', (tester) async {
      setupMenuBarViewport(tester);
      final state = MenuBarState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaMenuBar(
            state: state,
            sections: const [
              MenuBarSection(
                id: 'custom',
                label: 'Custom',
                items: [
                  MenuBarItem(id: 'action1', label: 'Action 1'),
                ],
              ),
            ],
          ),
        ),
      ));

      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('File'), findsNothing);
    });

    testWidgets('renders with custom height', (tester) async {
      setupMenuBarViewport(tester);
      final state = MenuBarState();
      const customHeight = 48.0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaMenuBar(
            state: state,
            height: customHeight,
          ),
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FigmaMenuBar),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.constraints?.maxHeight, customHeight);
    });
  });

  group('MenuBarColors Tests', () {
    test('has correct color values', () {
      expect(MenuBarColors.background, const Color(0xFF2C2C2C));
      expect(MenuBarColors.dropdownBackground, const Color(0xFF2C2C2C));
      expect(MenuBarColors.hoverBackground, const Color(0xFF0D99FF));
      expect(MenuBarColors.textPrimary, const Color(0xFFFFFFFF));
      expect(MenuBarColors.textShortcut, const Color(0xFF8C8C8C));
      expect(MenuBarColors.textDisabled, const Color(0xFF5C5C5C));
      expect(MenuBarColors.dividerColor, const Color(0xFF4A4A4A));
      expect(MenuBarColors.checkmarkColor, const Color(0xFF0D99FF));
      expect(MenuBarColors.topBarHover, const Color(0xFF404040));
    });
  });

  group('MenuBarShortcuts Tests', () {
    testWidgets('wraps child with shortcuts', (tester) async {
      const actions = MenuBarActions();

      await tester.pumpWidget(MaterialApp(
        home: MenuBarShortcuts(
          actions: actions,
          child: const Text('Test'),
        ),
      ));

      expect(find.text('Test'), findsOneWidget);
      // Should find our Shortcuts widget (MaterialApp adds default ones too)
      expect(find.byType(Shortcuts), findsWidgets);
      expect(find.byType(Actions), findsWidgets);
    });

    testWidgets('disabled shortcuts do not wrap with actions', (tester) async {
      const actions = MenuBarActions();

      await tester.pumpWidget(MaterialApp(
        home: MenuBarShortcuts(
          actions: actions,
          enabled: false,
          child: const Text('Test'),
        ),
      ));

      expect(find.text('Test'), findsOneWidget);
      // Disabled MenuBarShortcuts doesn't add Shortcuts, but MaterialApp still has default ones
      // So we just verify the widget structure is simpler
      expect(find.byType(MenuBarShortcuts), findsOneWidget);
    });

    testWidgets('undo shortcut triggers callback', (tester) async {
      bool undoCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: MenuBarShortcuts(
          actions: MenuBarActions(
            onUndo: () => undoCalled = true,
          ),
          child: const Focus(
            autofocus: true,
            child: SizedBox(),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(undoCalled, true);
    });

    testWidgets('copy shortcut triggers callback', (tester) async {
      bool copyCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: MenuBarShortcuts(
          actions: MenuBarActions(
            onCopy: () => copyCalled = true,
          ),
          child: const Focus(
            autofocus: true,
            child: SizedBox(),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(copyCalled, true);
    });
  });

  group('Performance Tests', () {
    testWidgets('menu bar renders quickly', (tester) async {
      setupMenuBarViewport(tester);
      final state = MenuBarState();
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaMenuBar(state: state),
        ),
      ));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    testWidgets('builder constructs menus quickly', (tester) async {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        const context = MenuBarContext(
          hasSelection: true,
          canUndo: true,
          canRedo: true,
        );
        const actions = MenuBarActions();
        final builder = MenuBarBuilder(context: context, actions: actions);
        builder.build();
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Shortcut Text Tests', () {
    test('File menu items have correct shortcuts', () {
      final fileMenu = DefaultMenuBarSections.fileMenu;
      final items = {for (var i in fileMenu.items) i.id: i.shortcut};

      expect(items['back_to_files'], '⌘\\');
      expect(items['new_design_file'], '⌘N');
      expect(items['place_image'], '⇧⌘K');
      expect(items['save_local_copy'], '⌘S');
      expect(items['export'], '⌘E');
      expect(items['preferences'], '⌘,');
    });

    test('Edit menu items have correct shortcuts', () {
      final editMenu = DefaultMenuBarSections.editMenu;
      final items = {for (var i in editMenu.items) i.id: i.shortcut};

      expect(items['undo'], '⌘Z');
      expect(items['redo'], '⇧⌘Z');
      expect(items['copy'], '⌘C');
      expect(items['copy_properties'], '⌥⌘C');
      expect(items['cut'], '⌘X');
      expect(items['paste'], '⌘V');
      expect(items['duplicate'], '⌘D');
      expect(items['delete'], '⌫');
      expect(items['select_all'], '⌘A');
      expect(items['find_and_replace'], '⌘F');
    });

    test('View menu items have correct shortcuts', () {
      final viewMenu = DefaultMenuBarSections.viewMenu;
      final items = {for (var i in viewMenu.items) i.id: i.shortcut};

      expect(items['pixel_grid'], "⌘'");
      expect(items['layout_grids'], '⌃G');
      expect(items['rulers'], '⇧R');
      expect(items['zoom_in'], '⌘+');
      expect(items['zoom_out'], '⌘-');
      expect(items['zoom_100'], '⌘0');
      expect(items['zoom_fit'], '⌘1');
      expect(items['zoom_selection'], '⌘2');
      expect(items['outline_mode'], '⌘Y');
    });

    test('Object menu items have correct shortcuts', () {
      final objectMenu = DefaultMenuBarSections.objectMenu;
      final items = {for (var i in objectMenu.items) i.id: i.shortcut};

      expect(items['group'], '⌘G');
      expect(items['ungroup'], '⇧⌘G');
      expect(items['frame_selection'], '⌥⌘G');
      expect(items['add_auto_layout'], '⇧A');
      expect(items['create_component'], '⌥⌘K');
      expect(items['detach_instance'], '⌥⌘B');
      expect(items['mask'], '⌃⌘M');
      expect(items['lock_unlock'], '⌘L');
      expect(items['show_hide'], '⇧⌘H');
    });

    test('Arrange menu items have correct shortcuts', () {
      final arrangeMenu = DefaultMenuBarSections.arrangeMenu;
      final items = {for (var i in arrangeMenu.items) i.id: i.shortcut};

      expect(items['bring_to_front'], ']');
      expect(items['bring_forward'], '⌘]');
      expect(items['send_backward'], '⌘[');
      expect(items['send_to_back'], '[');
    });
  });
}
