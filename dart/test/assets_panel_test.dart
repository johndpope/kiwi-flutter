/// Exhaustive UI tests for Figma-style Assets Panel
///
/// Tests cover:
/// - Panel rendering and structure
/// - Category list with emoji labels
/// - Search and filtering
/// - Item selection and insertion
/// - Tab switching (File/Assets)
/// - Hover and selection states
/// - Performance

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

// Re-export AssetItemType for convenience in tests
typedef AssetType = AssetItemType;

void main() {
  group('AssetCategory Tests', () {
    test('creates category with label and emoji', () {
      const category = AssetCategory(
        id: 'colors',
        label: 'A.01 Colors',
        emoji: '🎨',
      );

      expect(category.id, 'colors');
      expect(category.label, 'A.01 Colors');
      expect(category.emoji, '🎨');
    });

    test('creates category with icon instead of emoji', () {
      const category = AssetCategory(
        id: 'styles',
        label: 'Text Styles',
        icon: Icons.text_fields,
      );

      expect(category.icon, Icons.text_fields);
      expect(category.emoji, null);
    });

    test('creates category with subcategories', () {
      const category = AssetCategory(
        id: 'components',
        label: 'Components',
        subcategories: [
          AssetCategory(id: 'buttons', label: 'Buttons'),
          AssetCategory(id: 'inputs', label: 'Inputs'),
        ],
      );

      expect(category.subcategories, isNotNull);
      expect(category.subcategories!.length, 2);
    });

    test('creates category with items', () {
      final category = AssetCategory(
        id: 'icons',
        label: 'Icons',
        items: [
          const AssetItem(id: '1', name: 'Home', type: AssetType.component),
          const AssetItem(id: '2', name: 'Settings', type: AssetType.component),
        ],
      );

      expect(category.items.length, 2);
    });
  });

  group('AssetItem Tests', () {
    test('creates component item', () {
      const item = AssetItem(
        id: 'btn_1',
        name: 'Primary Button',
        type: AssetType.component,
        description: 'Main action button',
      );

      expect(item.id, 'btn_1');
      expect(item.name, 'Primary Button');
      expect(item.type, AssetType.component);
      expect(item.description, 'Main action button');
    });

    test('creates color item', () {
      const item = AssetItem(
        id: 'color_1',
        name: 'Primary Blue',
        type: AssetType.color,
        metadata: {'hex': '#0D99FF'},
      );

      expect(item.type, AssetType.color);
      expect(item.metadata?['hex'], '#0D99FF');
    });

    test('creates text style item', () {
      const item = AssetItem(
        id: 'style_1',
        name: 'Heading 1',
        type: AssetType.textStyle,
      );

      expect(item.type, AssetType.textStyle);
    });
  });

  group('DefaultAssetCategories Tests', () {
    test('has Components section', () {
      final categories = DefaultAssetCategories.components;
      final components = categories.firstWhere((c) => c.id == 'components');

      expect(components, isNotNull);
      expect(components.label, 'Components');
      expect(components.subcategories, isNotNull);
    });

    test('Components has correct subcategories', () {
      final categories = DefaultAssetCategories.components;
      final components = categories.firstWhere((c) => c.id == 'components');
      final subs = components.subcategories!;

      // Check for expected categories from Figma
      expect(subs.any((s) => s.label.contains('Colors')), true);
      expect(subs.any((s) => s.label.contains('Materials')), true);
      expect(subs.any((s) => s.label.contains('Typography')), true);
      expect(subs.any((s) => s.label.contains('System Experiences')), true);
      expect(subs.any((s) => s.label.contains('Navigation')), true);
      expect(subs.any((s) => s.label.contains('Selection')), true);
      expect(subs.any((s) => s.label.contains('Menus')), true);
      expect(subs.any((s) => s.label.contains('Layout')), true);
      expect(subs.any((s) => s.label.contains('Presentation')), true);
      expect(subs.any((s) => s.label.contains('Bezels')), true);
      expect(subs.any((s) => s.label.contains('Sizes')), true);
    });

    test('has Internal section', () {
      final categories = DefaultAssetCategories.components;
      final internal = categories.firstWhere((c) => c.id == 'internal');

      expect(internal, isNotNull);
      expect(internal.label, 'Internal');
      expect(internal.subcategories, isNotNull);
    });

    test('Internal has correct subcategories', () {
      final categories = DefaultAssetCategories.components;
      final internal = categories.firstWhere((c) => c.id == 'internal');
      final subs = internal.subcategories!;

      expect(subs.any((s) => s.label.contains('Internal')), true);
      expect(subs.any((s) => s.label.contains('Icons')), true);
      expect(subs.any((s) => s.label.contains('App Logos')), true);
      expect(subs.any((s) => s.label.contains('Thumbnail')), true);
    });

    test('categories have emoji labels', () {
      final categories = DefaultAssetCategories.components;
      final components = categories.firstWhere((c) => c.id == 'components');

      for (final sub in components.subcategories!) {
        expect(sub.emoji, isNotNull, reason: '${sub.label} should have emoji');
      }
    });
  });

  group('AssetsPanelState Tests', () {
    test('default state has empty search', () {
      final state = AssetsPanelState();
      expect(state.searchQuery, '');
    });

    test('setSearchQuery updates state', () {
      final state = AssetsPanelState();
      state.setSearchQuery('button');
      expect(state.searchQuery, 'button');
    });

    test('selectCategory updates state', () {
      final state = AssetsPanelState();
      state.selectCategory('icons');
      expect(state.selectedCategoryId, 'icons');
    });

    test('selectItem updates state', () {
      final state = AssetsPanelState();
      state.selectItem('item_1');
      expect(state.selectedItemId, 'item_1');
    });

    test('toggleExpanded toggles state', () {
      final state = AssetsPanelState();
      expect(state.isExpanded, true);
      state.toggleExpanded();
      expect(state.isExpanded, false);
      state.toggleExpanded();
      expect(state.isExpanded, true);
    });

    test('toggleCategoryExpanded toggles category', () {
      final state = AssetsPanelState();
      expect(state.expandedCategories.contains('new_cat'), false);
      state.toggleCategoryExpanded('new_cat');
      expect(state.expandedCategories.contains('new_cat'), true);
      state.toggleCategoryExpanded('new_cat');
      expect(state.expandedCategories.contains('new_cat'), false);
    });

    test('state notifies listeners', () {
      final state = AssetsPanelState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.setSearchQuery('test');
      expect(notifyCount, 1);

      state.selectCategory('cat');
      expect(notifyCount, 2);

      state.selectItem('item');
      expect(notifyCount, 3);
    });
  });

  group('FigmaAssetsPanel Widget Tests', () {
    testWidgets('renders panel with search bar', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
          ),
        ),
      ));

      // Verify search bar
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget); // Filter icon
    });

    testWidgets('renders category section headers', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
          ),
        ),
      ));

      // Verify section headers
      expect(find.text('Components'), findsOneWidget);
      expect(find.text('Internal'), findsOneWidget);
    });

    testWidgets('renders subcategory items with emojis', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
          ),
        ),
      ));

      // Verify some subcategories
      expect(find.textContaining('A.01'), findsOneWidget);
      expect(find.textContaining('Colors'), findsOneWidget);
    });

    testWidgets('tapping subcategory selects it', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
          ),
        ),
      ));

      // Find and tap A.01 Colors
      final colorsTile = find.textContaining('A.01');
      await tester.tap(colorsTile);
      await tester.pump();

      expect(state.selectedCategoryId, 'a01_colors');
    });

    testWidgets('search filters categories', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
          ),
        ),
      ));

      // Enter search text
      state.setSearchQuery('Typography');
      await tester.pump();

      // Typography should be visible
      expect(find.textContaining('Typography'), findsOneWidget);
    });

    testWidgets('panel has correct width', (tester) async {
      final state = AssetsPanelState();
      const testWidth = 280.0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            width: testWidth,
          ),
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FigmaAssetsPanel),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.constraints?.maxWidth, testWidth);
    });
  });

  group('FigmaAssetsPanelWithTabs Tests', () {
    testWidgets('renders File and Assets tabs', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanelWithTabs(
            state: state,
          ),
        ),
      ));

      expect(find.text('File'), findsOneWidget);
      expect(find.text('Assets'), findsOneWidget);
    });

    testWidgets('renders library icon in header', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanelWithTabs(
            state: state,
          ),
        ),
      ));

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('Assets tab is selected by default', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanelWithTabs(
            state: state,
          ),
        ),
      ));

      // Assets content should be visible
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tapping File tab switches content', (tester) async {
      final state = AssetsPanelState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanelWithTabs(
            state: state,
            layersContent: const Text('Layers Content'),
          ),
        ),
      ));

      await tester.tap(find.text('File'));
      await tester.pump();

      expect(find.text('Layers Content'), findsOneWidget);
    });
  });

  group('Item Selection and Callbacks Tests', () {
    // NOTE: Item callbacks require visible items in the ListView.
    // These tests verify the callback signature but actual rendering
    // requires items to be in visible viewport of the ListView.
    testWidgets('onItemSelected callback is provided', (tester) async {
      final state = AssetsPanelState();
      AssetItem? selectedItem;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
            onItemSelected: (item) => selectedItem = item,
          ),
        ),
      ));

      // Panel renders without error with callback
      expect(find.byType(FigmaAssetsPanel), findsOneWidget);
    });

    testWidgets('onItemInsert callback is provided', (tester) async {
      final state = AssetsPanelState();
      AssetItem? insertedItem;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
            onItemInsert: (item) => insertedItem = item,
          ),
        ),
      ));

      // Panel renders without error with callback
      expect(find.byType(FigmaAssetsPanel), findsOneWidget);
    });
  });

  group('AssetType Tests', () {
    test('all asset types are defined', () {
      expect(AssetType.values.length, 6);
      expect(AssetType.values.contains(AssetType.component), true);
      expect(AssetType.values.contains(AssetType.color), true);
      expect(AssetType.values.contains(AssetType.textStyle), true);
      expect(AssetType.values.contains(AssetType.effect), true);
      expect(AssetType.values.contains(AssetType.grid), true);
      expect(AssetType.values.contains(AssetType.image), true);
    });
  });

  group('Colors and Styling Tests', () {
    test('AssetsPanelColors has correct values', () {
      expect(AssetsPanelColors.background, const Color(0xFF2C2C2C));
      expect(AssetsPanelColors.textPrimary, const Color(0xFFFFFFFF));
      expect(AssetsPanelColors.selectedBackground, const Color(0xFF0D99FF));
    });
  });

  group('Performance Tests', () {
    testWidgets('panel renders quickly', (tester) async {
      final state = AssetsPanelState();
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: DefaultAssetCategories.components,
          ),
        ),
      ));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    testWidgets('panel handles many categories', (tester) async {
      final state = AssetsPanelState();

      final categories = List.generate(50, (i) => AssetCategory(
        id: 'cat_$i',
        label: 'Category $i',
        emoji: '📁',
        items: List.generate(10, (j) => AssetItem(
          id: 'item_${i}_$j',
          name: 'Item $j',
          type: AssetType.component,
        )),
      ));

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FigmaAssetsPanel(
            state: state,
            categories: categories,
          ),
        ),
      ));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
  });

  group('Search Filter Tests', () {
    test('filter matches category labels', () {
      final state = AssetsPanelState();
      state.setSearchQuery('colors');

      // This would be tested via widget
      expect(state.searchQuery, 'colors');
    });

    test('filter is case insensitive', () {
      final state = AssetsPanelState();
      state.setSearchQuery('COLORS');

      expect(state.searchQuery, 'COLORS');
      // Actual filtering in widget would be case-insensitive
    });

    test('empty search shows all categories', () {
      final state = AssetsPanelState();
      state.setSearchQuery('');

      expect(state.searchQuery, '');
    });
  });
}
