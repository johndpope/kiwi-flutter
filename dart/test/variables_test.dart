// Tests for Variables functionality (PRD Section 4.11)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  group('Variable Types', () {
    test('VariableType enum has all types', () {
      expect(VariableType.values.length, 4);
      expect(VariableType.values, contains(VariableType.color));
      expect(VariableType.values, contains(VariableType.number));
      expect(VariableType.values, contains(VariableType.string));
      expect(VariableType.values, contains(VariableType.boolean));
    });

    test('VariableResolveType enum has value and alias', () {
      expect(VariableResolveType.values, contains(VariableResolveType.value));
      expect(VariableResolveType.values, contains(VariableResolveType.alias));
    });

    test('VariableScope enum has all scopes', () {
      expect(VariableScope.values, contains(VariableScope.allScopes));
      expect(VariableScope.values, contains(VariableScope.textContent));
      expect(VariableScope.values, contains(VariableScope.cornerRadius));
      expect(VariableScope.values, contains(VariableScope.allFills));
      expect(VariableScope.values, contains(VariableScope.strokeColor));
    });
  });

  group('VariableMode', () {
    test('creates light and dark presets', () {
      expect(VariableMode.light.name, 'Light');
      expect(VariableMode.dark.name, 'Dark');
    });

    test('creates from map', () {
      final mode = VariableMode.fromMap({
        'modeId': 'custom_mode',
        'name': 'Custom Mode',
      }, 2);

      expect(mode.id, 'custom_mode');
      expect(mode.name, 'Custom Mode');
      expect(mode.index, 2);
    });
  });

  group('VariableCollection', () {
    test('creates collection with modes', () {
      const collection = VariableCollection(
        id: 'col1',
        name: 'Colors',
        modes: [VariableMode.light, VariableMode.dark],
        defaultModeId: 'light',
      );

      expect(collection.id, 'col1');
      expect(collection.name, 'Colors');
      expect(collection.modes.length, 2);
      expect(collection.defaultModeId, 'light');
    });

    test('getModeById returns correct mode', () {
      const collection = VariableCollection(
        id: 'col1',
        name: 'Colors',
        modes: [VariableMode.light, VariableMode.dark],
        defaultModeId: 'light',
      );

      final mode = collection.getModeById('light');
      expect(mode?.name, 'Light');
    });

    test('defaultMode returns correct mode', () {
      const collection = VariableCollection(
        id: 'col1',
        name: 'Colors',
        modes: [VariableMode.light, VariableMode.dark],
        defaultModeId: 'dark',
      );

      expect(collection.defaultMode?.name, 'Dark');
    });
  });

  group('VariableValue', () {
    test('creates direct value', () {
      const value = VariableValue(value: Colors.blue);
      expect(value.isAlias, false);
      expect(value.value, Colors.blue);
    });

    test('creates alias value', () {
      // Use dynamic type for alias since value is null
      final value = VariableValue<dynamic>.alias('other_var');
      expect(value.isAlias, true);
      expect(value.aliasId, 'other_var');
    });
  });

  group('DesignVariable', () {
    test('creates color variable', () {
      const variable = DesignVariable(
        id: 'var1',
        name: 'primary',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {},
      );

      expect(variable.type, VariableType.color);
      expect(variable.name, 'primary');
    });

    test('getValue returns correct value', () {
      const variable = DesignVariable(
        id: 'var1',
        name: 'primary',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {
          'light': VariableValue(value: Colors.blue),
          'dark': VariableValue(value: Colors.blueAccent),
        },
      );

      expect(variable.getColorValue('light'), Colors.blue);
      expect(variable.getColorValue('dark'), Colors.blueAccent);
    });

    test('creates from map', () {
      final variable = DesignVariable.fromMap({
        'id': 'var1',
        'name': 'Test Variable',
        'resolvedType': 'COLOR',
        'variableCollectionId': 'col1',
        'valuesByMode': {
          'mode1': {'r': 1.0, 'g': 0.0, 'b': 0.0, 'a': 1.0},
        },
        'scopes': ['ALL_FILLS'],
      });

      expect(variable.type, VariableType.color);
      expect(variable.scopes, contains(VariableScope.allFills));
    });
  });

  group('VariableResolver', () {
    late VariableResolver resolver;

    setUp(() {
      const collection = VariableCollection(
        id: 'col1',
        name: 'Colors',
        modes: [VariableMode.light, VariableMode.dark],
        defaultModeId: 'light',
      );

      const primaryVar = DesignVariable(
        id: 'primary',
        name: 'primary',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {
          'light': VariableValue(value: Colors.blue),
          'dark': VariableValue(value: Colors.blueAccent),
        },
      );

      resolver = VariableResolver(
        variables: {'primary': primaryVar},
        collections: {'col1': collection},
      );
    });

    test('resolves color in default mode', () {
      final color = resolver.resolveColor('primary');
      expect(color, Colors.blue);
    });

    test('resolves color in different mode', () {
      resolver.setMode('col1', 'dark');
      final color = resolver.resolveColor('primary');
      expect(color, Colors.blueAccent);
    });

    test('switchToNamedMode changes all collections', () {
      resolver.switchToNamedMode('Dark');
      expect(resolver.getModeId('col1'), 'dark');
    });

    test('getVariablesInCollection returns filtered list', () {
      final vars = resolver.getVariablesInCollection('col1');
      expect(vars.length, 1);
      expect(vars.first.name, 'primary');
    });
  });

  group('VariableManager', () {
    late VariableManager manager;

    setUp(() {
      final resolver = VariableResolver(
        variables: {},
        collections: {},
      );
      manager = VariableManager(resolver);
    });

    test('creates collection', () {
      final collection = manager.createCollection(
        name: 'My Colors',
        modeNames: ['Light', 'Dark'],
      );

      expect(collection.name, 'My Colors');
      expect(collection.modes.length, 2);
    });

    test('creates variable', () {
      final collection = manager.createCollection(
        name: 'Colors',
        modeNames: ['Default'],
      );

      final variable = manager.createVariable(
        name: 'primary',
        type: VariableType.color,
        collectionId: collection.id,
        valuesByMode: {collection.modes.first.id: Colors.blue},
      );

      expect(variable.name, 'primary');
      expect(variable.type, VariableType.color);
    });

    test('updates variable value', () {
      final collection = manager.createCollection(name: 'Colors');
      final variable = manager.createVariable(
        name: 'primary',
        type: VariableType.color,
        collectionId: collection.id,
        valuesByMode: {collection.modes.first.id: Colors.blue},
      );

      manager.updateVariableValue(
        variable.id,
        collection.modes.first.id,
        Colors.red,
      );

      final resolved = manager.resolver.resolveColor(variable.id);
      expect(resolved, Colors.red);
    });

    test('deletes variable', () {
      final collection = manager.createCollection(name: 'Colors');
      final variable = manager.createVariable(
        name: 'temp',
        type: VariableType.string,
        collectionId: collection.id,
        valuesByMode: {},
      );

      manager.deleteVariable(variable.id);
      expect(manager.resolver.variables.containsKey(variable.id), false);
    });
  });

  group('Extended Collections', () {
    test('ExtendedVariableCollection supports inheritance', () {
      final parent = ExtendedVariableCollection(
        id: 'parent',
        name: 'Base Colors',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
      );

      final child = ExtendedVariableCollection(
        id: 'child',
        name: 'Brand Colors',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
        parentCollectionId: 'parent',
        inheritsFromParent: true,
      );

      expect(child.parentCollectionId, 'parent');
      expect(child.inheritsFromParent, true);
    });

    test('canAddMoreModes respects maxModes', () {
      final collection = ExtendedVariableCollection(
        id: 'col',
        name: 'Test',
        modes: List.generate(20, (i) => VariableMode(id: 'm$i', name: 'M$i')),
        defaultModeId: 'm0',
        maxModes: 20,
      );

      expect(collection.canAddMoreModes, false);
    });

    test('isOverridden checks override set', () {
      final collection = ExtendedVariableCollection(
        id: 'col',
        name: 'Test',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
        overriddenVariableIds: {'var1', 'var2'},
      );

      expect(collection.isOverridden('var1'), true);
      expect(collection.isOverridden('var3'), false);
    });
  });

  group('CollectionInheritanceManager', () {
    late CollectionInheritanceManager manager;

    setUp(() {
      manager = CollectionInheritanceManager();
    });

    test('creates child collection from parent', () {
      final parent = ExtendedVariableCollection(
        id: 'parent',
        name: 'Base',
        modes: const [VariableMode.light, VariableMode.dark],
        defaultModeId: 'light',
      );
      manager.addCollection(parent);

      final child = manager.createChildCollection(
        parentId: 'parent',
        name: 'Brand A',
        brandId: 'brand_a',
      );

      expect(child.parentCollectionId, 'parent');
      expect(child.modes.length, 2);
      expect(child.brandId, 'brand_a');
    });

    test('getHierarchy returns parent chain', () {
      final root = ExtendedVariableCollection(
        id: 'root',
        name: 'Root',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
      );
      manager.addCollection(root);

      final child = manager.createChildCollection(
        parentId: 'root',
        name: 'Child',
      );

      final hierarchy = manager.getHierarchy(child.id);
      expect(hierarchy.length, 2);
      expect(hierarchy.first.id, 'root');
    });
  });

  group('W3C Design Tokens', () {
    group('Importer', () {
      test('parses simple token file', () {
        const json = '''
{
  "color": {
    "\$type": "color",
    "primary": {
      "\$value": "#0066cc"
    }
  }
}
''';

        final importer = W3CDesignTokensImporter();
        final file = importer.parse(json);

        expect(file.tokens.length, 1);
        expect(file.tokens.first.path, 'color.primary');
        expect(file.tokens.first.type, W3CTokenType.color);
      });

      test('parses alias tokens', () {
        const json = '''
{
  "color": {
    "\$type": "color",
    "base": {
      "\$value": "#0066cc"
    },
    "primary": {
      "\$value": "{color.base}"
    }
  }
}
''';

        final importer = W3CDesignTokensImporter();
        final file = importer.parse(json);

        final primary = file.getTokenByPath('color.primary');
        expect(primary?.isAlias, true);
        expect(primary?.aliasPath, 'color.base');
      });

      test('imports to variables', () {
        const json = '''
{
  "spacing": {
    "\$type": "dimension",
    "small": {
      "\$value": "8px"
    },
    "medium": {
      "\$value": "16px"
    }
  }
}
''';

        final importer = W3CDesignTokensImporter();
        final file = importer.parse(json);
        final result = importer.importToVariables(file, collectionName: 'Spacing');

        expect(result.collection.name, 'Spacing');
        expect(result.variables.length, 2);
      });
    });

    group('Exporter', () {
      test('exports collection to W3C format', () {
        const collection = ExtendedVariableCollection(
          id: 'col1',
          name: 'Colors',
          modes: [VariableMode.light],
          defaultModeId: 'light',
        );

        const variable = DesignVariable(
          id: 'var1',
          name: 'colors/primary',
          type: VariableType.color,
          collectionId: 'col1',
          valuesByMode: {'light': VariableValue(value: Colors.blue)},
        );

        final resolver = VariableResolver(
          variables: {'var1': variable},
          collections: {'col1': collection},
        );

        final exporter = W3CDesignTokensExporter();
        final json = exporter.export(collection, [variable], resolver);

        expect(json, contains('\$type'));
        expect(json, contains('\$value'));
        expect(json, contains('colors'));
      });
    });

    group('DesignTokensIO', () {
      test('validates correct JSON', () {
        const json = '''
{
  "color": {
    "\$type": "color",
    "primary": {
      "\$value": "#0066cc"
    }
  }
}
''';

        final io = DesignTokensIO();
        final result = io.validate(json);

        expect(result.valid, true);
        expect(result.tokenCount, 1);
      });

      test('validates invalid JSON', () {
        const json = 'not valid json';

        final io = DesignTokensIO();
        final result = io.validate(json);

        expect(result.valid, false);
        expect(result.errors, isNotEmpty);
      });
    });
  });

  group('Check Designs Audit', () {
    test('AuditSeverity has all levels', () {
      expect(AuditSeverity.values, contains(AuditSeverity.error));
      expect(AuditSeverity.values, contains(AuditSeverity.warning));
      expect(AuditSeverity.values, contains(AuditSeverity.suggestion));
      expect(AuditSeverity.values, contains(AuditSeverity.info));
    });

    test('AuditCategory has all categories', () {
      expect(AuditCategory.values, contains(AuditCategory.hardcodedValue));
      expect(AuditCategory.values, contains(AuditCategory.unusedVariable));
      expect(AuditCategory.values, contains(AuditCategory.namingConvention));
    });

    test('AuditConfig has presets', () {
      expect(AuditConfig.strict.checkHardcodedColors, true);
      expect(AuditConfig.lenient.checkHardcodedDimensions, false);
    });

    test('DesignAuditor finds hardcoded colors', () {
      const variable = DesignVariable(
        id: 'primary',
        name: 'primary',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {'default': VariableValue(value: Colors.blue)},
      );

      final resolver = VariableResolver(
        variables: {'primary': variable},
        collections: {
          'col1': const VariableCollection(
            id: 'col1',
            name: 'Colors',
            modes: [VariableMode(id: 'default', name: 'Default')],
            defaultModeId: 'default',
          ),
        },
      );

      final auditor = DesignAuditor(resolver: resolver);

      final properties = [
        const PropertyValue(
          nodeId: 'node1',
          nodeName: 'Button',
          propertyName: 'backgroundColor',
          value: Colors.blue,
        ),
      ];

      final result = auditor.audit(properties);
      expect(result.issues.any((i) => i.category == AuditCategory.hardcodedValue), true);
    });

    test('DesignAuditor finds unused variables', () {
      const variable = DesignVariable(
        id: 'unused',
        name: 'unused_color',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {},
      );

      final resolver = VariableResolver(
        variables: {'unused': variable},
        collections: {
          'col1': const VariableCollection(
            id: 'col1',
            name: 'Colors',
            modes: [VariableMode(id: 'default', name: 'Default')],
            defaultModeId: 'default',
          ),
        },
      );

      final auditor = DesignAuditor(resolver: resolver);
      final result = auditor.audit([]);

      expect(result.issues.any((i) => i.category == AuditCategory.unusedVariable), true);
    });

    test('AuditReportGenerator creates markdown', () {
      final result = AuditResult(
        issues: const [
          AuditIssue(
            id: 'test1',
            severity: AuditSeverity.warning,
            category: AuditCategory.hardcodedValue,
            title: 'Test Issue',
            description: 'A test issue',
          ),
        ],
        timestamp: DateTime.now(),
        config: const AuditConfig(),
        stats: const AuditStats(
          totalNodesScanned: 10,
          totalPropertiesScanned: 50,
          hardcodedValuesFound: 1,
          variablesUsed: 5,
          variablesTotal: 10,
          unusedVariables: 5,
          auditDuration: Duration(milliseconds: 100),
        ),
      );

      final generator = AuditReportGenerator();
      final markdown = generator.generateMarkdownReport(result);

      expect(markdown, contains('Design Audit Report'));
      expect(markdown, contains('Test Issue'));
    });
  });

  group('Code Export', () {
    late VariableResolver resolver;
    late ExtendedVariableCollection collection;
    late List<DesignVariable> variables;

    setUp(() {
      collection = const ExtendedVariableCollection(
        id: 'col1',
        name: 'Design Tokens',
        modes: [VariableMode.light],
        defaultModeId: 'light',
      );

      variables = const [
        DesignVariable(
          id: 'primary',
          name: 'colors/primary',
          type: VariableType.color,
          collectionId: 'col1',
          valuesByMode: {'light': VariableValue(value: Colors.blue)},
        ),
        DesignVariable(
          id: 'spacing',
          name: 'spacing/medium',
          type: VariableType.number,
          collectionId: 'col1',
          valuesByMode: {'light': VariableValue(value: 16.0)},
        ),
      ];

      resolver = VariableResolver(
        variables: {for (var v in variables) v.id: v},
        collections: {'col1': collection},
      );
    });

    test('exports to CSS', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final css = exporter.export(CodeExportFormat.css, collection, variables);

      expect(css, contains(':root'));
      expect(css, contains('--colors-primary'));
      expect(css, contains('--spacing-medium'));
    });

    test('exports to SCSS', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final scss = exporter.export(CodeExportFormat.scss, collection, variables);

      expect(scss, contains(r'$colors-primary'));
      expect(scss, contains(r'$spacing-medium'));
    });

    test('exports to JavaScript', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final js = exporter.export(CodeExportFormat.javascript, collection, variables);

      expect(js, contains('export const tokens'));
      expect(js, contains('colorsPrimary'));
    });

    test('exports to TypeScript', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final ts = exporter.export(CodeExportFormat.typescript, collection, variables);

      expect(ts, contains('interface TokenColors'));
      expect(ts, contains('export const tokens'));
    });

    test('exports to Swift', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final swift = exporter.export(CodeExportFormat.swift, collection, variables);

      expect(swift, contains('import SwiftUI'));
      expect(swift, contains('extension Color'));
      expect(swift, contains('static let'));
    });

    test('exports to Kotlin', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final kotlin = exporter.export(CodeExportFormat.kotlin, collection, variables);

      expect(kotlin, contains('package com.example'));
      expect(kotlin, contains('object DesignTokens'));
      expect(kotlin, contains('val'));
    });

    test('exports to Tailwind config', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final tailwind = exporter.export(CodeExportFormat.tailwind, collection, variables);

      expect(tailwind, contains('module.exports'));
      expect(tailwind, contains('theme'));
      expect(tailwind, contains('colors'));
    });

    test('exports to Flutter', () {
      final exporter = CodeExportEngine(resolver: resolver);
      final flutter = exporter.export(CodeExportFormat.flutter, collection, variables);

      expect(flutter, contains("import 'package:flutter/material.dart'"));
      expect(flutter, contains('abstract class DesignTokens'));
      expect(flutter, contains('static const Color'));
    });
  });

  group('Library Publishing', () {
    late CollectionInheritanceManager collectionManager;
    late LibraryPublishingManager publishingManager;

    setUp(() {
      collectionManager = CollectionInheritanceManager();
      publishingManager = LibraryPublishingManager(collectionManager);

      final collection = ExtendedVariableCollection(
        id: 'col1',
        name: 'Design System',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
      );
      collectionManager.addCollection(collection);
    });

    test('publishes collection as library', () {
      final library = publishingManager.publishCollection(
        collectionId: 'col1',
        name: 'My Design System',
        ownerId: 'user1',
        tags: ['design-system', 'colors'],
      );

      expect(library.name, 'My Design System');
      expect(library.status, PublicationStatus.published);
      expect(library.currentVersion, '1.0.0');
      expect(library.tags, contains('colors'));
    });

    test('publishes new version', () {
      final library = publishingManager.publishCollection(
        collectionId: 'col1',
        name: 'My Library',
        ownerId: 'user1',
      );

      publishingManager.publishNewVersion(
        libraryId: library.id,
        newVersion: '1.1.0',
        publishedBy: 'user1',
        releaseNotes: 'Added new colors',
      );

      final updated = publishingManager.libraries[library.id]!;
      expect(updated.currentVersion, '1.1.0');
      expect(updated.versions.length, 2);
    });

    test('subscribes to library', () {
      final library = publishingManager.publishCollection(
        collectionId: 'col1',
        name: 'Shared Tokens',
        ownerId: 'user1',
      );

      final targetCollection = ExtendedVariableCollection(
        id: 'target',
        name: 'My Project',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
      );
      collectionManager.addCollection(targetCollection);

      final subscription = publishingManager.subscribe(
        libraryId: library.id,
        targetCollectionId: 'target',
      );

      expect(subscription.libraryId, library.id);
      expect(subscription.status, SubscriptionStatus.active);
    });

    test('unsubscribes from library', () {
      final library = publishingManager.publishCollection(
        collectionId: 'col1',
        name: 'Tokens',
        ownerId: 'user1',
      );

      final targetCollection = ExtendedVariableCollection(
        id: 'target',
        name: 'Project',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
      );
      collectionManager.addCollection(targetCollection);

      final subscription = publishingManager.subscribe(
        libraryId: library.id,
        targetCollectionId: 'target',
      );

      publishingManager.unsubscribe(subscription.id);

      expect(publishingManager.subscriptions.containsKey(subscription.id), false);
    });

    test('deprecates library', () {
      final library = publishingManager.publishCollection(
        collectionId: 'col1',
        name: 'Old Tokens',
        ownerId: 'user1',
      );

      publishingManager.deprecateLibrary(library.id);

      final updated = publishingManager.libraries[library.id]!;
      expect(updated.status, PublicationStatus.deprecated);
    });
  });

  group('Variables Panel UI', () {
    testWidgets('VariablesPanel renders', (tester) async {
      final resolver = VariableResolver(
        variables: {},
        collections: {},
      );
      final manager = VariableManager(resolver);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariablesPanel(manager: manager),
          ),
        ),
      );

      expect(find.text('Variables'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('VariableBindingDropdown renders', (tester) async {
      const variable = DesignVariable(
        id: 'primary',
        name: 'primary',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {},
      );

      final resolver = VariableResolver(
        variables: {'primary': variable},
        collections: {
          'col1': const VariableCollection(
            id: 'col1',
            name: 'Colors',
            modes: [VariableMode.light],
            defaultModeId: 'light',
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariableBindingDropdown(
              resolver: resolver,
              type: VariableType.color,
              onChanged: (id) {},
            ),
          ),
        ),
      );

      // The dropdown widget should render (contains a dropdown button)
      expect(find.byType(DropdownButton<String?>), findsOneWidget);
    });
  });

  group('Performance', () {
    test('resolves 1000+ variables efficiently', () {
      // Create large collection
      final collection = VariableCollection(
        id: 'large',
        name: 'Large Collection',
        modes: const [VariableMode.light],
        defaultModeId: 'light',
      );

      final variables = <String, DesignVariable>{};
      for (var i = 0; i < 1000; i++) {
        variables['var_$i'] = DesignVariable(
          id: 'var_$i',
          name: 'variable_$i',
          type: VariableType.number,
          collectionId: 'large',
          valuesByMode: {'light': VariableValue(value: i.toDouble())},
        );
      }

      final resolver = VariableResolver(
        variables: variables,
        collections: {'large': collection},
      );

      final stopwatch = Stopwatch()..start();

      // Resolve all variables
      for (final id in variables.keys) {
        resolver.resolveNumber(id);
      }

      stopwatch.stop();

      // Should complete in under 50ms
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });

  group('Edge Cases', () {
    test('handles alias cycles by limiting depth', () {
      // Create circular alias reference using dynamic
      final varA = DesignVariable(
        id: 'varA',
        name: 'A',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {'default': VariableValue<dynamic>.alias('varB')},
      );

      final varBDesign = DesignVariable(
        id: 'varB',
        name: 'B',
        type: VariableType.color,
        collectionId: 'col1',
        valuesByMode: {'default': VariableValue<dynamic>.alias('varA')},
      );

      final resolver = VariableResolver(
        variables: {'varA': varA, 'varB': varBDesign},
        collections: {
          'col1': const VariableCollection(
            id: 'col1',
            name: 'Test',
            modes: [VariableMode(id: 'default', name: 'Default')],
            defaultModeId: 'default',
          ),
        },
      );

      // Should not infinite loop, returns null due to max depth
      final result = resolver.resolveColor('varA');
      expect(result, isNull);
    });

    test('handles empty collection gracefully', () {
      final resolver = VariableResolver(
        variables: {},
        collections: {},
      );

      expect(resolver.colorVariables, isEmpty);
      expect(resolver.resolveColor('nonexistent'), isNull);
    });
  });
}
