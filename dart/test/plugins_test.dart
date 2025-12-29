/// Plugin system tests
///
/// Tests cover:
/// - Manifest parsing and validation
/// - Plugin installation and lifecycle
/// - Plugin API exposure
/// - UI panel rendering
/// - Permissions and security

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  group('PluginManifest', () {
    group('Parsing', () {
      test('parses minimal valid manifest', () {
        final manifest = PluginManifest.fromJsonString('''
        {
          "name": "Test Plugin",
          "id": "com.test.plugin",
          "api": "1.0.0",
          "main": "code.js",
          "editorType": "figma"
        }
        ''');

        expect(manifest.name, 'Test Plugin');
        expect(manifest.id, 'com.test.plugin');
        expect(manifest.api, '1.0.0');
        expect(manifest.main, 'code.js');
        expect(manifest.editorType, [PluginEditorType.figma]);
      });

      test('parses manifest with all optional fields', () {
        final manifest = PluginManifest.fromJsonString('''
        {
          "name": "Full Plugin",
          "id": "com.test.full",
          "api": "1.0.0",
          "main": "code.js",
          "editorType": ["figma", "figjam"],
          "ui": "ui.html",
          "version": "2.1.0",
          "description": "A full-featured plugin",
          "documentAccess": "dynamic-page",
          "networkAccess": {
            "allowedDomains": ["*.example.com", "api.test.com"],
            "reasoning": "Required for API calls"
          },
          "parameters": [
            {
              "name": "Color",
              "key": "color",
              "description": "Pick a color",
              "allowFreeform": true,
              "optional": false
            }
          ],
          "parameterOnly": false,
          "menu": [
            {"name": "Run", "command": "run"},
            {"separator": true},
            {"name": "Settings", "command": "settings"}
          ],
          "relaunchButtons": [
            {"command": "edit", "name": "Edit", "multipleSelection": true}
          ],
          "enableProposedApi": true,
          "permissions": ["currentuser"],
          "capabilities": ["codegen", "inspect"],
          "codegenLanguages": ["swift", "kotlin"],
          "codegenPreferences": {
            "unit": "px",
            "scaleFactor": 2.0
          }
        }
        ''');

        expect(manifest.name, 'Full Plugin');
        expect(manifest.editorType, [PluginEditorType.figma, PluginEditorType.figjam]);
        expect(manifest.ui, 'ui.html');
        expect(manifest.version, '2.1.0');
        expect(manifest.description, 'A full-featured plugin');
        expect(manifest.documentAccess, DocumentAccess.dynamicPage);
        expect(manifest.networkAccess?.allowedDomains, ['*.example.com', 'api.test.com']);
        expect(manifest.networkAccess?.reasoning, 'Required for API calls');
        expect(manifest.parameters?.length, 1);
        expect(manifest.parameters?.first.name, 'Color');
        expect(manifest.parameters?.first.key, 'color');
        expect(manifest.menu?.length, 3);
        expect(manifest.menu?[1].separator, true);
        expect(manifest.relaunchButtons?.length, 1);
        expect(manifest.relaunchButtons?.first.multipleSelection, true);
        expect(manifest.enableProposedApi, true);
        expect(manifest.permissions, ['currentuser']);
        expect(manifest.capabilities?.codegen, true);
        expect(manifest.capabilities?.inspect, true);
        expect(manifest.codegenLanguages, ['swift', 'kotlin']);
        expect(manifest.codegenPreferences?.unit, 'px');
        expect(manifest.codegenPreferences?.scaleFactor, 2.0);
      });

      test('parses single editorType as string', () {
        final manifest = PluginManifest.fromJsonString('''
        {
          "name": "Test",
          "id": "test",
          "api": "1.0.0",
          "main": "code.js",
          "editorType": "figjam"
        }
        ''');

        expect(manifest.editorType, [PluginEditorType.figjam]);
      });

      test('parses dev editor type', () {
        final manifest = PluginManifest.fromJsonString('''
        {
          "name": "Dev Plugin",
          "id": "dev",
          "api": "1.0.0",
          "main": "code.js",
          "editorType": "dev"
        }
        ''');

        expect(manifest.editorType, [PluginEditorType.dev]);
      });

      test('parses nested menu structure', () {
        final manifest = PluginManifest.fromJsonString('''
        {
          "name": "Test",
          "id": "test",
          "api": "1.0.0",
          "main": "code.js",
          "editorType": "figma",
          "menu": [
            {
              "name": "Export",
              "menu": [
                {"name": "PNG", "command": "export-png"},
                {"name": "SVG", "command": "export-svg"}
              ]
            }
          ]
        }
        ''');

        expect(manifest.menu?.length, 1);
        expect(manifest.menu?.first.name, 'Export');
        expect(manifest.menu?.first.menu?.length, 2);
        expect(manifest.menu?.first.menu?.first.command, 'export-png');
      });

      test('parses parameter options', () {
        final manifest = PluginManifest.fromJsonString('''
        {
          "name": "Test",
          "id": "test",
          "api": "1.0.0",
          "main": "code.js",
          "editorType": "figma",
          "parameters": [
            {
              "name": "Size",
              "key": "size",
              "options": [
                {"name": "Small", "description": "32px"},
                {"name": "Medium", "description": "64px"},
                {"name": "Large", "description": "128px"}
              ]
            }
          ]
        }
        ''');

        expect(manifest.parameters?.first.options?.length, 3);
        expect(manifest.parameters?.first.options?.first.name, 'Small');
        expect(manifest.parameters?.first.options?.first.description, '32px');
      });

      test('parses build configuration', () {
        final manifest = PluginManifest.fromJsonString('''
        {
          "name": "Test",
          "id": "test",
          "api": "1.0.0",
          "main": "dist/code.js",
          "editorType": "figma",
          "build": {
            "command": "npm run build",
            "watchCommand": "npm run watch"
          }
        }
        ''');

        expect(manifest.build?.command, 'npm run build');
        expect(manifest.build?.watchCommand, 'npm run watch');
      });
    });

    group('Validation', () {
      test('validates minimal manifest as valid', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
        );

        final result = manifest.validate();
        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('reports error for empty name', () {
        final manifest = PluginManifest(
          name: '',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
        );

        final result = manifest.validate();
        expect(result.isValid, false);
        expect(result.errors, contains('name is required'));
      });

      test('reports error for empty id', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: '',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
        );

        final result = manifest.validate();
        expect(result.isValid, false);
        expect(result.errors, contains('id is required'));
      });

      test('reports error for invalid api version', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: 'invalid',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
        );

        final result = manifest.validate();
        expect(result.isValid, false);
        expect(result.errors.any((e) => e.contains('Invalid api version')), true);
      });

      test('reports error for api version below 1.0.0', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '0.9.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
        );

        final result = manifest.validate();
        expect(result.isValid, false);
        expect(result.errors.any((e) => e.contains('at least 1.0.0')), true);
      });

      test('warns about broad network access without reasoning', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
          networkAccess: const NetworkAccess(allowedDomains: ['*']),
        );

        final result = manifest.validate();
        expect(result.isValid, true);
        expect(result.warnings, contains('Broad network access (*) should include reasoning'));
      });

      test('no warning for broad network access with reasoning', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
          networkAccess: const NetworkAccess(
            allowedDomains: ['*'],
            reasoning: 'Plugin needs to access any API',
          ),
        );

        final result = manifest.validate();
        expect(result.isValid, true);
        expect(result.warnings, isEmpty);
      });

      test('warns about codegen without languages', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
          capabilities: const PluginCapabilities(codegen: true),
        );

        final result = manifest.validate();
        expect(result.isValid, true);
        expect(result.warnings.any((w) => w.contains('codegenLanguages')), true);
      });
    });

    group('Serialization', () {
      test('roundtrip JSON conversion', () {
        final original = PluginManifest(
          name: 'Test Plugin',
          id: 'com.test.plugin',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma, PluginEditorType.figjam],
          ui: 'ui.html',
          version: '1.2.3',
          description: 'A test plugin',
          networkAccess: const NetworkAccess(
            allowedDomains: ['api.example.com'],
            reasoning: 'API access',
          ),
          parameters: [
            const PluginParameter(name: 'Test', key: 'test'),
          ],
          menu: [
            const PluginMenuItem(name: 'Run', command: 'run'),
          ],
          relaunchButtons: [
            const RelaunchButton(command: 'edit', name: 'Edit'),
          ],
          permissions: ['currentuser'],
        );

        final json = original.toJson();
        final restored = PluginManifest.fromJson(json);

        expect(restored.name, original.name);
        expect(restored.id, original.id);
        expect(restored.api, original.api);
        expect(restored.main, original.main);
        expect(restored.editorType, original.editorType);
        expect(restored.ui, original.ui);
        expect(restored.version, original.version);
        expect(restored.description, original.description);
        expect(restored.networkAccess?.allowedDomains, original.networkAccess?.allowedDomains);
        expect(restored.parameters?.length, original.parameters?.length);
        expect(restored.menu?.length, original.menu?.length);
        expect(restored.relaunchButtons?.length, original.relaunchButtons?.length);
        expect(restored.permissions, original.permissions);
      });
    });

    group('Utility methods', () {
      test('supportsEditor returns correct values', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma, PluginEditorType.dev],
        );

        expect(manifest.supportsEditor(PluginEditorType.figma), true);
        expect(manifest.supportsEditor(PluginEditorType.dev), true);
        expect(manifest.supportsEditor(PluginEditorType.figjam), false);
      });

      test('hasUI returns correct values', () {
        final withUI = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
          ui: 'ui.html',
        );

        final withoutUI = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
        );

        expect(withUI.hasUI, true);
        expect(withoutUI.hasUI, false);
      });

      test('allCommands extracts all commands from menu', () {
        final manifest = PluginManifest(
          name: 'Test',
          id: 'test',
          api: '1.0.0',
          main: 'code.js',
          editorType: [PluginEditorType.figma],
          menu: [
            const PluginMenuItem(name: 'Run', command: 'run'),
            const PluginMenuItem(
              name: 'Export',
              menu: [
                PluginMenuItem(name: 'PNG', command: 'export-png'),
                PluginMenuItem(name: 'SVG', command: 'export-svg'),
              ],
            ),
          ],
        );

        expect(manifest.allCommands, ['run', 'export-png', 'export-svg']);
      });
    });
  });

  group('NetworkAccess', () {
    test('isUrlAllowed returns true for wildcard', () {
      const access = NetworkAccess(allowedDomains: ['*']);
      expect(access.isUrlAllowed('https://any.domain.com/path'), true);
    });

    test('isUrlAllowed matches exact domain', () {
      const access = NetworkAccess(allowedDomains: ['api.example.com']);
      expect(access.isUrlAllowed('https://api.example.com/v1'), true);
      expect(access.isUrlAllowed('https://other.example.com/v1'), false);
    });

    test('isUrlAllowed matches subdomain wildcard', () {
      const access = NetworkAccess(allowedDomains: ['*.example.com']);
      expect(access.isUrlAllowed('https://api.example.com/v1'), true);
      expect(access.isUrlAllowed('https://cdn.example.com/assets'), true);
      expect(access.isUrlAllowed('https://other.com/v1'), false);
    });

    test('isUrlAllowed returns false for invalid URL', () {
      const access = NetworkAccess(allowedDomains: ['*']);
      expect(access.isUrlAllowed('not a url'), false);
    });
  });

  group('PluginParameter', () {
    test('parses string type parameter', () {
      final param = PluginParameter.fromJson({
        'name': 'Text',
        'key': 'text',
        'type': 'string',
      });

      expect(param.type, ParameterType.string);
    });

    test('parses boolean type parameter', () {
      final param = PluginParameter.fromJson({
        'name': 'Enabled',
        'key': 'enabled',
        'type': 'boolean',
      });

      expect(param.type, ParameterType.boolean);
    });

    test('parses number type parameter', () {
      final param = PluginParameter.fromJson({
        'name': 'Count',
        'key': 'count',
        'type': 'number',
      });

      expect(param.type, ParameterType.number);
    });

    test('defaults to string type', () {
      final param = PluginParameter.fromJson({
        'name': 'Unknown',
        'key': 'unknown',
      });

      expect(param.type, ParameterType.string);
    });
  });

  group('InstalledPlugin', () {
    test('serializes and deserializes correctly', () {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
      );

      final plugin = InstalledPlugin(
        installationId: 'abc123',
        manifest: manifest,
        installPath: '/path/to/plugin',
        status: PluginStatus.loaded,
        installedAt: DateTime(2025, 1, 1),
        lastRunAt: DateTime(2025, 1, 2),
        enabled: true,
        relaunchData: {'node1': 'data1'},
      );

      final json = plugin.toJson();
      final restored = InstalledPlugin.fromJson(json);

      expect(restored.installationId, plugin.installationId);
      expect(restored.manifest.id, manifest.id);
      expect(restored.installPath, plugin.installPath);
      expect(restored.status, plugin.status);
      expect(restored.enabled, plugin.enabled);
      expect(restored.relaunchData, plugin.relaunchData);
    });
  });

  group('PluginAPI', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('createRectangle creates RECTANGLE node', () {
      final node = api.createRectangle();
      expect(node.type, 'RECTANGLE');
      expect(node.name, 'Rectangle');
    });

    test('createFrame creates FRAME node', () {
      final node = api.createFrame();
      expect(node.type, 'FRAME');
      expect(node.name, 'Frame');
    });

    test('createText creates TEXT node', () {
      final node = api.createText();
      expect(node.type, 'TEXT');
      expect(node.name, 'Text');
    });

    test('createEllipse creates ELLIPSE node', () {
      final node = api.createEllipse();
      expect(node.type, 'ELLIPSE');
      expect(node.name, 'Ellipse');
    });

    test('createComponent creates COMPONENT node', () {
      final node = api.createComponent();
      expect(node.type, 'COMPONENT');
    });

    test('boolean operations create correct nodes', () {
      final union = api.union([], PluginNodeProxy(id: '1', type: 'FRAME', name: 'F'));
      expect(union.booleanOperation, 'UNION');

      final subtract = api.subtract([], PluginNodeProxy(id: '1', type: 'FRAME', name: 'F'));
      expect(subtract.booleanOperation, 'SUBTRACT');

      final intersect = api.intersect([], PluginNodeProxy(id: '1', type: 'FRAME', name: 'F'));
      expect(intersect.booleanOperation, 'INTERSECT');

      final exclude = api.exclude([], PluginNodeProxy(id: '1', type: 'FRAME', name: 'F'));
      expect(exclude.booleanOperation, 'EXCLUDE');
    });

    test('mixed symbol is accessible', () {
      expect(FigmaPluginAPI.mixed, isNotNull);
    });

    test('clientStorage operations work', () async {
      await api.clientStorage.setAsync('key', 'value');
      final result = await api.clientStorage.getAsync('key');
      expect(result, 'value');

      await api.clientStorage.deleteAsync('key');
      final deleted = await api.clientStorage.getAsync('key');
      expect(deleted, isNull);
    });
  });

  group('PluginNodeProxy', () {
    test('clone creates independent copy', () {
      final original = PluginNodeProxy(
        id: '1',
        type: 'RECTANGLE',
        name: 'Original',
      );
      original.x = 100;
      original.y = 200;
      original.width = 300;
      original.height = 400;

      final clone = original.clone();

      expect(clone.id, isNot(original.id));
      expect(clone.type, original.type);
      expect(clone.name, original.name);
      expect(clone.x, original.x);
      expect(clone.y, original.y);
      expect(clone.width, original.width);
      expect(clone.height, original.height);
    });

    test('appendChild adds child and sets parent', () {
      final parent = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Parent');
      final child = PluginNodeProxy(id: '2', type: 'RECTANGLE', name: 'Child');

      parent.appendChild(child);

      expect(parent.children, contains(child));
      expect(child.parent, parent);
    });

    test('remove removes from parent', () {
      final parent = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Parent');
      final child = PluginNodeProxy(id: '2', type: 'RECTANGLE', name: 'Child');

      parent.appendChild(child);
      child.remove();

      expect(parent.children, isEmpty);
      expect(child.parent, isNull);
    });

    test('findChild finds nested child', () {
      final parent = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Parent');
      final child = PluginNodeProxy(id: '2', type: 'FRAME', name: 'Child');
      final grandchild = PluginNodeProxy(id: '3', type: 'TEXT', name: 'Target');

      parent.appendChild(child);
      child.appendChild(grandchild);

      final found = parent.findChild((n) => n.type == 'TEXT');
      expect(found, grandchild);
    });

    test('findAll finds all matching nodes', () {
      final parent = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Parent');
      final rect1 = PluginNodeProxy(id: '2', type: 'RECTANGLE', name: 'Rect1');
      final rect2 = PluginNodeProxy(id: '3', type: 'RECTANGLE', name: 'Rect2');
      final text = PluginNodeProxy(id: '4', type: 'TEXT', name: 'Text');

      parent.appendChild(rect1);
      parent.appendChild(rect2);
      parent.appendChild(text);

      final rects = parent.findAll((n) => n.type == 'RECTANGLE');
      expect(rects.length, 2);
    });

    test('plugin data storage works', () {
      final node = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Frame');

      node.setPluginData('key1', 'value1');
      node.setPluginData('key2', 'value2');

      expect(node.getPluginData('key1'), 'value1');
      expect(node.getPluginData('key2'), 'value2');
      expect(node.getPluginDataKeys(), ['key1', 'key2']);
    });

    test('shared plugin data storage works', () {
      final node = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Frame');

      node.setSharedPluginData('namespace', 'key', 'value');

      expect(node.getSharedPluginData('namespace', 'key'), 'value');
      expect(node.getSharedPluginDataKeys('namespace'), ['key']);
    });

    test('relaunch data storage works', () {
      final node = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Frame');

      node.setRelaunchData({'edit': 'Edit this node', 'refresh': 'Refresh'});

      expect(node.relaunchData['edit'], 'Edit this node');
      expect(node.relaunchData['refresh'], 'Refresh');
    });

    test('absoluteBoundingBox calculates correctly', () {
      final parent = PluginNodeProxy(id: '1', type: 'FRAME', name: 'Parent');
      parent.x = 100;
      parent.y = 100;

      final child = PluginNodeProxy(id: '2', type: 'RECTANGLE', name: 'Child');
      child.x = 50;
      child.y = 50;
      child.width = 200;
      child.height = 100;

      parent.appendChild(child);

      final bounds = child.absoluteBoundingBox;
      expect(bounds['x'], 150);
      expect(bounds['y'], 150);
      expect(bounds['width'], 200);
      expect(bounds['height'], 100);
    });

    test('resize updates dimensions', () {
      final node = PluginNodeProxy(id: '1', type: 'RECTANGLE', name: 'Rect');
      node.width = 100;
      node.height = 100;

      node.resize(200, 300);

      expect(node.width, 200);
      expect(node.height, 300);
    });

    test('rescale multiplies dimensions', () {
      final node = PluginNodeProxy(id: '1', type: 'RECTANGLE', name: 'Rect');
      node.width = 100;
      node.height = 50;

      node.rescale(2);

      expect(node.width, 200);
      expect(node.height, 100);
    });
  });

  group('PluginColorUtils', () {
    test('hexToRgb converts correctly', () {
      final rgb = PluginColorUtils.hexToRgb('#FF0000');
      expect(rgb['r'], 1.0);
      expect(rgb['g'], 0.0);
      expect(rgb['b'], 0.0);
    });

    test('hexToRgb handles short hex', () {
      final rgb = PluginColorUtils.hexToRgb('#F00');
      expect(rgb['r'], 1.0);
      expect(rgb['g'], 0.0);
      expect(rgb['b'], 0.0);
    });

    test('hexToRgb handles without hash', () {
      final rgb = PluginColorUtils.hexToRgb('00FF00');
      expect(rgb['r'], 0.0);
      expect(rgb['g'], 1.0);
      expect(rgb['b'], 0.0);
    });

    test('rgbToHex converts correctly', () {
      final hex = PluginColorUtils.rgbToHex(1.0, 0.0, 0.0);
      expect(hex, '#FF0000');
    });

    test('rgbToHex handles intermediate values', () {
      final hex = PluginColorUtils.rgbToHex(0.5, 0.5, 0.5);
      expect(hex, '#808080');
    });
  });

  group('Version', () {
    test('comparison works correctly', () {
      const v1 = Version(1, 0, 0);
      const v2 = Version(1, 0, 1);
      const v3 = Version(1, 1, 0);
      const v4 = Version(2, 0, 0);

      expect(v1 < v2, true);
      expect(v2 < v3, true);
      expect(v3 < v4, true);
      expect(v4 > v1, true);
      expect(v1 == const Version(1, 0, 0), true);
    });

    test('toString formats correctly', () {
      const v = Version(1, 2, 3);
      expect(v.toString(), '1.2.3');
    });
  });

  group('PluginsPanel Widget', () {
    testWidgets('renders empty state when no plugins', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PluginsPanel(),
          ),
        ),
      );

      expect(find.text('Plugins'), findsOneWidget);
      expect(find.text('No plugins installed'), findsOneWidget);
    });

    testWidgets('shows search bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PluginsPanel(),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows install button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PluginsPanel(),
          ),
        ),
      );

      // There should be at least one add icon (in header)
      expect(find.byIcon(Icons.add), findsWidgets);
    });
  });
}
