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

    group('checkUrl detailed validation', () {
      test('rejects invalid URL format', () {
        const access = NetworkAccess(allowedDomains: ['*']);
        final result = access.checkUrl('not a url');
        expect(result.allowed, false);
        expect(result.reason, NetworkDenyReason.invalidUrl);
      });

      test('rejects URL without host', () {
        const access = NetworkAccess(allowedDomains: ['*']);
        final result = access.checkUrl('file:///local/path');
        expect(result.allowed, false);
        expect(result.reason, NetworkDenyReason.invalidUrl);
      });

      test('rejects non-http protocols', () {
        const access = NetworkAccess(allowedDomains: ['*']);

        final ftpResult = access.checkUrl('ftp://files.example.com/file');
        expect(ftpResult.allowed, false);
        expect(ftpResult.reason, NetworkDenyReason.invalidProtocol);

        final wsResult = access.checkUrl('ws://socket.example.com');
        expect(wsResult.allowed, false);
        expect(wsResult.reason, NetworkDenyReason.invalidProtocol);
      });

      test('blocks localhost by default', () {
        const access = NetworkAccess(allowedDomains: ['api.example.com']);

        expect(access.checkUrl('http://localhost:3000').allowed, false);
        expect(access.checkUrl('http://localhost:3000').reason, NetworkDenyReason.privateNetwork);

        expect(access.checkUrl('http://127.0.0.1:8080').allowed, false);
        expect(access.checkUrl('http://127.0.0.1:8080').reason, NetworkDenyReason.privateNetwork);
      });

      test('blocks private IPv4 ranges', () {
        const access = NetworkAccess(allowedDomains: ['api.example.com']);

        // 10.x.x.x
        expect(access.checkUrl('http://10.0.0.1').reason, NetworkDenyReason.privateNetwork);

        // 172.16-31.x.x
        expect(access.checkUrl('http://172.16.0.1').reason, NetworkDenyReason.privateNetwork);
        expect(access.checkUrl('http://172.31.255.255').reason, NetworkDenyReason.privateNetwork);

        // 192.168.x.x
        expect(access.checkUrl('http://192.168.1.1').reason, NetworkDenyReason.privateNetwork);
      });

      test('allows localhost when explicitly configured', () {
        const access = NetworkAccess(allowedDomains: ['localhost']);
        expect(access.checkUrl('http://localhost:3000').allowed, true);
      });

      test('allows private network with wildcard', () {
        const access = NetworkAccess(allowedDomains: ['*']);
        expect(access.checkUrl('http://localhost:3000').allowed, true);
        expect(access.checkUrl('http://192.168.1.1').allowed, true);
      });

      test('returns matched pattern on success', () {
        const access = NetworkAccess(allowedDomains: ['*.example.com']);
        final result = access.checkUrl('https://api.example.com/v1');
        expect(result.allowed, true);
        expect(result.matchedPattern, '*.example.com');
      });

      test('domain matching is case-insensitive', () {
        const access = NetworkAccess(allowedDomains: ['API.Example.COM']);
        expect(access.checkUrl('https://api.example.com/v1').allowed, true);
        expect(access.checkUrl('https://API.EXAMPLE.COM/v1').allowed, true);
      });

      test('wildcard matches exact domain and subdomains', () {
        const access = NetworkAccess(allowedDomains: ['*.example.com']);

        // Matches subdomains
        expect(access.checkUrl('https://api.example.com').allowed, true);
        expect(access.checkUrl('https://cdn.example.com').allowed, true);
        expect(access.checkUrl('https://deep.sub.example.com').allowed, true);

        // Matches the base domain itself
        expect(access.checkUrl('https://example.com').allowed, true);
      });

      test('rejects domain not in allowed list', () {
        const access = NetworkAccess(allowedDomains: ['api.example.com']);
        final result = access.checkUrl('https://malicious.com/data');
        expect(result.allowed, false);
        expect(result.reason, NetworkDenyReason.domainNotAllowed);
        expect(result.message, contains('malicious.com'));
      });
    });
  });

  group('Plugin API Fetch', () {
    test('fetch throws PluginNetworkError for blocked domain', () async {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        networkAccess: const NetworkAccess(allowedDomains: ['api.example.com']),
      );

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      expect(
        () => api.fetch('https://blocked.com/data'),
        throwsA(isA<PluginNetworkError>().having(
          (e) => e.url,
          'url',
          'https://blocked.com/data',
        ).having(
          (e) => e.reason,
          'reason',
          NetworkDenyReason.domainNotAllowed,
        )),
      );
    });

    test('fetch throws PluginNetworkError for private network', () async {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        networkAccess: const NetworkAccess(allowedDomains: ['api.example.com']),
      );

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      expect(
        () => api.fetch('http://192.168.1.1/admin'),
        throwsA(isA<PluginNetworkError>().having(
          (e) => e.reason,
          'reason',
          NetworkDenyReason.privateNetwork,
        )),
      );
    });

    test('fetch succeeds for allowed domain', () async {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        networkAccess: const NetworkAccess(allowedDomains: ['api.example.com']),
      );

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
      final response = await api.fetch('https://api.example.com/data');

      expect(response.ok, true);
      expect(response.status, 200);
    });

    test('fetch throws when no network access configured', () async {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        // No networkAccess
      );

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      expect(
        () => api.fetch('https://api.example.com/data'),
        throwsA(isA<PluginNetworkError>()),
      );
    });

    test('PluginFetchResponse provides header access', () {
      const response = PluginFetchResponse(
        status: 200,
        ok: true,
        headers: {'Content-Type': 'application/json', 'X-Custom': 'value'},
        body: '{"data": true}',
      );

      expect(response.header('content-type'), 'application/json');
      expect(response.header('CONTENT-TYPE'), 'application/json');
      expect(response.header('x-custom'), 'value');
      expect(response.header('missing'), null);
      expect(response.text(), '{"data": true}');
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
      expect(node.type, NodeType.RECTANGLE);
      expect(node.name, 'Rectangle');
    });

    test('createFrame creates FRAME node', () {
      final node = api.createFrame();
      expect(node.type, NodeType.FRAME);
      expect(node.name, 'Frame');
    });

    test('createText creates TEXT node', () {
      final node = api.createText();
      expect(node.type, NodeType.TEXT);
      expect(node.name, 'Text');
    });

    test('createEllipse creates ELLIPSE node', () {
      final node = api.createEllipse();
      expect(node.type, NodeType.ELLIPSE);
      expect(node.name, 'Ellipse');
    });

    test('createComponent creates COMPONENT node', () {
      final node = api.createComponent();
      expect(node.type, NodeType.COMPONENT);
    });

    test('createStar creates STAR node', () {
      final node = api.createStar();
      expect(node.type, NodeType.STAR);
      expect(node.name, 'Star');
    });

    test('createSection creates SECTION node', () {
      final node = api.createSection();
      expect(node.type, NodeType.SECTION);
      expect(node.name, 'Section');
    });

    test('createTable creates TABLE node with rows/columns', () {
      final table = api.createTable(rows: 4, columns: 5);
      expect(table.type, NodeType.TABLE);
      expect(table.numRows, 4);
      expect(table.numColumns, 5);
    });

    test('boolean operations create correct nodes', () {
      final parent = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'F');

      final union = api.union([], parent);
      expect(union.booleanOperation, BooleanOperationType.UNION);

      final subtract = api.subtract([], parent);
      expect(subtract.booleanOperation, BooleanOperationType.SUBTRACT);

      final intersect = api.intersect([], parent);
      expect(intersect.booleanOperation, BooleanOperationType.INTERSECT);

      final exclude = api.exclude([], parent);
      expect(exclude.booleanOperation, BooleanOperationType.EXCLUDE);
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

    test('event handlers register and fire', () {
      var callCount = 0;
      api.on('selectionchange', () => callCount++);

      api.triggerSelectionChange();
      expect(callCount, 1);

      api.triggerSelectionChange();
      expect(callCount, 2);
    });

    test('off removes event handlers', () {
      var callCount = 0;
      void handler() => callCount++;

      api.on('selectionchange', handler);
      api.triggerSelectionChange();
      expect(callCount, 1);

      api.off('selectionchange', handler);
      api.triggerSelectionChange();
      expect(callCount, 1); // Still 1, handler removed
    });

    test('permission checking throws for unauthorized access', () {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        // No permissions
      );

      final restrictedApi = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      expect(
        () => restrictedApi.currentUser,
        throwsA(isA<PluginPermissionError>()),
      );
    });

    test('permission checking allows authorized access', () {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        permissions: ['currentuser'],
      );

      final authorizedApi = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // Should not throw
      expect(() => authorizedApi.currentUser, returnsNormally);
    });

    test('network access checking works', () {
      final manifest = PluginManifest(
        name: 'Test',
        id: 'test',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        networkAccess: const NetworkAccess(allowedDomains: ['api.example.com']),
      );

      final apiWithNetwork = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      expect(apiWithNetwork.isNetworkAccessAllowed('https://api.example.com/v1'), true);
      expect(apiWithNetwork.isNetworkAccessAllowed('https://other.com/v1'), false);
    });

    test('createStyles adds to local styles', () {
      final paintStyle = api.createPaintStyle();
      expect(api.getLocalPaintStyles(), contains(paintStyle));

      final textStyle = api.createTextStyle();
      expect(api.getLocalTextStyles(), contains(textStyle));

      final effectStyle = api.createEffectStyle();
      expect(api.getLocalEffectStyles(), contains(effectStyle));

      final gridStyle = api.createGridStyle();
      expect(api.getLocalGridStyles(), contains(gridStyle));
    });

    test('timer setTimeout works', () async {
      var called = false;
      api.timer.setTimeout(() => called = true, 10);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(called, true);
    });

    test('timer clearTimeout cancels', () async {
      var called = false;
      final id = api.timer.setTimeout(() => called = true, 50);
      api.timer.clearTimeout(id);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(called, false);
    });
  });

  group('PluginNodeProxy', () {
    test('clone creates independent copy', () {
      final original = PluginNodeProxy(
        id: '1',
        type: NodeType.RECTANGLE,
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
      final parent = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Parent');
      final child = PluginNodeProxy(id: '2', type: NodeType.RECTANGLE, name: 'Child');

      parent.appendChild(child);

      expect(parent.children, contains(child));
      expect(child.parent, parent);
    });

    test('remove removes from parent', () {
      final parent = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Parent');
      final child = PluginNodeProxy(id: '2', type: NodeType.RECTANGLE, name: 'Child');

      parent.appendChild(child);
      child.remove();

      expect(parent.children, isEmpty);
      expect(child.parent, isNull);
    });

    test('findChild finds nested child', () {
      final parent = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Parent');
      final child = PluginNodeProxy(id: '2', type: NodeType.FRAME, name: 'Child');
      final grandchild = PluginNodeProxy(id: '3', type: NodeType.TEXT, name: 'Target');

      parent.appendChild(child);
      child.appendChild(grandchild);

      final found = parent.findChild((n) => n.type == NodeType.TEXT);
      expect(found, grandchild);
    });

    test('findAll finds all matching nodes', () {
      final parent = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Parent');
      final rect1 = PluginNodeProxy(id: '2', type: NodeType.RECTANGLE, name: 'Rect1');
      final rect2 = PluginNodeProxy(id: '3', type: NodeType.RECTANGLE, name: 'Rect2');
      final text = PluginNodeProxy(id: '4', type: NodeType.TEXT, name: 'Text');

      parent.appendChild(rect1);
      parent.appendChild(rect2);
      parent.appendChild(text);

      final rects = parent.findAll((n) => n.type == NodeType.RECTANGLE);
      expect(rects.length, 2);
    });

    test('plugin data storage works', () {
      final node = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Frame');

      node.setPluginData('key1', 'value1');
      node.setPluginData('key2', 'value2');

      expect(node.getPluginData('key1'), 'value1');
      expect(node.getPluginData('key2'), 'value2');
      expect(node.getPluginDataKeys(), ['key1', 'key2']);
    });

    test('shared plugin data storage works', () {
      final node = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Frame');

      node.setSharedPluginData('namespace', 'key', 'value');

      expect(node.getSharedPluginData('namespace', 'key'), 'value');
      expect(node.getSharedPluginDataKeys('namespace'), ['key']);
    });

    test('relaunch data storage works', () {
      final node = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Frame');

      node.setRelaunchData({'edit': 'Edit this node', 'refresh': 'Refresh'});

      expect(node.relaunchData['edit'], 'Edit this node');
      expect(node.relaunchData['refresh'], 'Refresh');
    });

    test('absoluteBoundingBox calculates correctly', () {
      final parent = PluginNodeProxy(id: '1', type: NodeType.FRAME, name: 'Parent');
      parent.x = 100;
      parent.y = 100;

      final child = PluginNodeProxy(id: '2', type: NodeType.RECTANGLE, name: 'Child');
      child.x = 50;
      child.y = 50;
      child.width = 200;
      child.height = 100;

      parent.appendChild(child);

      final bounds = child.absoluteBoundingBox;
      expect(bounds.x, 150);
      expect(bounds.y, 150);
      expect(bounds.width, 200);
      expect(bounds.height, 100);
    });

    test('resize updates dimensions', () {
      final node = PluginNodeProxy(id: '1', type: NodeType.RECTANGLE, name: 'Rect');
      node.width = 100;
      node.height = 100;

      node.resize(200, 300);

      expect(node.width, 200);
      expect(node.height, 300);
    });

    test('rescale multiplies dimensions', () {
      final node = PluginNodeProxy(id: '1', type: NodeType.RECTANGLE, name: 'Rect');
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
      expect(rgb.r, 1.0);
      expect(rgb.g, 0.0);
      expect(rgb.b, 0.0);
    });

    test('hexToRgb handles short hex', () {
      final rgb = PluginColorUtils.hexToRgb('#F00');
      expect(rgb.r, 1.0);
      expect(rgb.g, 0.0);
      expect(rgb.b, 0.0);
    });

    test('hexToRgb handles without hash', () {
      final rgb = PluginColorUtils.hexToRgb('00FF00');
      expect(rgb.r, 0.0);
      expect(rgb.g, 1.0);
      expect(rgb.b, 0.0);
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

  group('Plugin Manager', () {
    test('singleton instance is consistent', () {
      final manager1 = PluginManager.instance;
      final manager2 = PluginManager.instance;
      expect(identical(manager1, manager2), true);
    });

    test('getPlugin returns null for non-existent plugin', () {
      final manager = PluginManager.instance;
      expect(manager.getPlugin('non-existent-id'), isNull);
    });

    test('isRunning returns false for non-existent plugin', () {
      final manager = PluginManager.instance;
      expect(manager.isRunning('non-existent-id'), false);
    });

    test('runPlugin fails gracefully for non-existent plugin', () async {
      final manager = PluginManager.instance;
      final result = await manager.runPlugin('non-existent-plugin');
      expect(result.success, false);
      expect(result.error, contains('not found'));
    });

    test('setEnabled does nothing for non-existent plugin', () async {
      final manager = PluginManager.instance;
      // Should not throw
      await manager.setEnabled('non-existent-id', false);
    });

    test('stopPlugin does nothing for non-existent plugin', () async {
      final manager = PluginManager.instance;
      // Should not throw
      await manager.stopPlugin('non-existent-id');
    });
  });

  group('InstalledPlugin', () {
    test('creates with default values', () {
      final manifest = PluginManifest.fromJsonString('''
      {
        "name": "Test Plugin",
        "id": "com.test.plugin",
        "api": "1.0.0",
        "main": "code.js",
        "editorType": "figma"
      }
      ''');

      final plugin = InstalledPlugin(
        installationId: 'install-1',
        manifest: manifest,
        installPath: '/path/to/plugin',
        installedAt: DateTime.now(),
      );

      expect(plugin.status, PluginStatus.installed);
      expect(plugin.enabled, true);
      expect(plugin.errorMessage, isNull);
      expect(plugin.lastRunAt, isNull);
      expect(plugin.relaunchData, isEmpty);
    });

    test('serializes to and from JSON', () {
      final manifest = PluginManifest.fromJsonString('''
      {
        "name": "Test Plugin",
        "id": "com.test.plugin",
        "api": "1.0.0",
        "main": "code.js",
        "editorType": "figma"
      }
      ''');

      final installedAt = DateTime(2024, 1, 1, 12, 0);
      final lastRunAt = DateTime(2024, 1, 2, 14, 30);

      final plugin = InstalledPlugin(
        installationId: 'install-abc',
        manifest: manifest,
        installPath: '/plugins/com.test.plugin',
        installedAt: installedAt,
        lastRunAt: lastRunAt,
        enabled: false,
        status: PluginStatus.loaded,
        relaunchData: {'node1': 'data1', 'node2': 'data2'},
      );

      final json = plugin.toJson();
      final restored = InstalledPlugin.fromJson(json);

      expect(restored.installationId, 'install-abc');
      expect(restored.manifest.id, 'com.test.plugin');
      expect(restored.installPath, '/plugins/com.test.plugin');
      expect(restored.enabled, false);
      expect(restored.status, PluginStatus.loaded);
      expect(restored.relaunchData['node1'], 'data1');
      expect(restored.relaunchData['node2'], 'data2');
    });
  });

  group('PluginExecutionResult', () {
    test('success result', () {
      final result = PluginExecutionResult(
        success: true,
        result: {'data': 'value'},
        executionTime: const Duration(milliseconds: 150),
      );

      expect(result.success, true);
      expect(result.result, {'data': 'value'});
      expect(result.error, isNull);
      expect(result.executionTime.inMilliseconds, 150);
    });

    test('error result', () {
      final result = PluginExecutionResult(
        success: false,
        error: 'Something went wrong',
        executionTime: const Duration(milliseconds: 50),
      );

      expect(result.success, false);
      expect(result.result, isNull);
      expect(result.error, 'Something went wrong');
    });
  });

  group('Plugin API Document Operations', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('create and manipulate document structure', () {
      final page = api.createPage();
      expect(page.name, 'Page');

      api.root.appendChild(page);
      expect(api.root.children.length, 1);

      final frame = api.createFrame();
      frame.name = 'Main Frame';
      frame.width = 800;
      frame.height = 600;
      page.appendChild(frame);
      expect(page.children.length, 1);

      final rect = api.createRectangle();
      rect.x = 100;
      rect.y = 100;
      rect.width = 200;
      rect.height = 150;
      frame.appendChild(rect);
      expect(frame.children.length, 1);
    });

    test('selection management', () {
      final rect1 = api.createRectangle();
      final rect2 = api.createRectangle();
      final text = api.createText();

      api.selection = [rect1, rect2];
      expect(api.selection.length, 2);
      expect(api.selection, contains(rect1));
      expect(api.selection, contains(rect2));

      api.selection = [text];
      expect(api.selection.length, 1);
      expect(api.selection.first, text);
    });

    test('boolean operations', () {
      final page = api.createPage();
      api.root.appendChild(page);

      final frame = api.createFrame();
      page.appendChild(frame);

      final rect1 = api.createRectangle();
      final rect2 = api.createRectangle();

      // Union
      final union = api.union([rect1.clone(), rect2.clone()], frame);
      expect(union.type, NodeType.BOOLEAN_OPERATION);
      expect(union.booleanOperation, BooleanOperationType.UNION);
      expect(union.children.length, 2);

      // Subtract
      final subtract = api.subtract([rect1.clone(), rect2.clone()], frame);
      expect(subtract.booleanOperation, BooleanOperationType.SUBTRACT);

      // Intersect
      final intersect = api.intersect([rect1.clone(), rect2.clone()], frame);
      expect(intersect.booleanOperation, BooleanOperationType.INTERSECT);

      // Exclude
      final exclude = api.exclude([rect1.clone(), rect2.clone()], frame);
      expect(exclude.booleanOperation, BooleanOperationType.EXCLUDE);
    });

    test('group and ungroup operations', () {
      final page = api.createPage();
      api.root.appendChild(page);

      final frame = api.createFrame();
      page.appendChild(frame);

      final rect1 = api.createRectangle();
      rect1.x = 0;
      rect1.y = 0;
      frame.appendChild(rect1);

      final rect2 = api.createRectangle();
      rect2.x = 50;
      rect2.y = 50;
      frame.appendChild(rect2);

      expect(frame.children.length, 2);

      // Group
      final group = api.group([rect1, rect2], frame);
      expect(group.type, NodeType.GROUP);
      expect(group.children.length, 2);
      expect(frame.children.length, 1);
      expect(frame.children.first, group);

      // Ungroup
      final ungrouped = api.ungroup(group);
      expect(ungrouped.length, 2);
      expect(frame.children.length, 2);
    });

    test('create all node types', () {
      expect(api.createRectangle().type, NodeType.RECTANGLE);
      expect(api.createFrame().type, NodeType.FRAME);
      expect(api.createText().type, NodeType.TEXT);
      expect(api.createEllipse().type, NodeType.ELLIPSE);
      expect(api.createLine().type, NodeType.LINE);
      expect(api.createPolygon().type, NodeType.POLYGON);
      expect(api.createStar().type, NodeType.STAR);
      expect(api.createVector().type, NodeType.VECTOR);
      expect(api.createBooleanOperation().type, NodeType.BOOLEAN_OPERATION);
      expect(api.createComponent().type, NodeType.COMPONENT);
      expect(api.createComponentSet().type, NodeType.COMPONENT_SET);
      expect(api.createSlice().type, NodeType.SLICE);
      expect(api.createSection().type, NodeType.SECTION);
      expect(api.createSticky().type, NodeType.STICKY);
      expect(api.createShapeWithText().type, NodeType.SHAPE_WITH_TEXT);
      expect(api.createConnector().type, NodeType.CONNECTOR);
      expect(api.createCodeBlock().type, NodeType.CODE_BLOCK);
      expect(api.createTable().type, NodeType.TABLE);
    });
  });

  group('Plugin API Styles and Variables', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('create and manage paint styles', () {
      expect(api.getLocalPaintStyles().length, 0);

      final style1 = api.createPaintStyle();
      style1.name = 'Primary Blue';
      style1.paints = [
        Paint.solid(const FigmaColor(r: 0.0, g: 0.4, b: 1.0)),
      ];

      final style2 = api.createPaintStyle();
      style2.name = 'Secondary Gray';

      expect(api.getLocalPaintStyles().length, 2);
      expect(api.getLocalPaintStyles().first.name, 'Primary Blue');
    });

    test('create and manage text styles', () {
      expect(api.getLocalTextStyles().length, 0);

      final style = api.createTextStyle();
      style.name = 'Heading 1';
      style.fontSize = 32;
      style.fontName = const FontName(family: 'Inter', style: 'Bold');

      expect(api.getLocalTextStyles().length, 1);
      expect(api.getLocalTextStyles().first.name, 'Heading 1');
    });

    test('create and manage effect styles', () {
      expect(api.getLocalEffectStyles().length, 0);

      final style = api.createEffectStyle();
      style.name = 'Elevation 1';
      style.effects = [
        Effect.dropShadow(
          color: const FigmaColor(r: 0, g: 0, b: 0, a: 0.25),
          offsetY: 4,
          radius: 8,
        ),
      ];

      expect(api.getLocalEffectStyles().length, 1);
    });

    test('create and manage variables', () {
      final collection = api.createVariableCollection('Brand Colors');
      expect(collection.name, 'Brand Colors');

      final variable = api.createVariable(
        'primary',
        collection.id,
        'COLOR',
      );
      expect(variable.name, 'primary');
      expect(variable.resolvedType, 'COLOR');

      variable.setValueForMode('mode1', const FigmaColor(r: 0, g: 0.4, b: 1.0));
      expect(variable.valuesByMode['mode1'], isNotNull);
    });
  });

  group('Plugin API UI Controller', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('show and hide UI', () {
      expect(api.ui.visible, false);

      api.showUI('<html></html>', width: 400, height: 300);
      expect(api.ui.visible, true);

      api.ui.hide();
      expect(api.ui.visible, false);
    });

    test('resize UI', () {
      api.showUI('<html></html>', width: 400, height: 300);
      api.ui.resize(600, 500);
      // Just verify no error is thrown
    });

    test('close UI', () {
      api.showUI('<html></html>');
      expect(api.ui.visible, true);

      api.ui.close();
      expect(api.ui.visible, false);
    });
  });

  group('Plugin API Client Storage', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('store and retrieve values', () async {
      await api.clientStorage.setAsync('theme', 'dark');
      await api.clientStorage.setAsync('fontSize', 14);
      await api.clientStorage.setAsync('settings', {'a': 1, 'b': 2});

      expect(await api.clientStorage.getAsync('theme'), 'dark');
      expect(await api.clientStorage.getAsync('fontSize'), 14);
      expect(await api.clientStorage.getAsync('settings'), {'a': 1, 'b': 2});
    });

    test('delete values', () async {
      await api.clientStorage.setAsync('temp', 'value');
      expect(await api.clientStorage.getAsync('temp'), 'value');

      await api.clientStorage.deleteAsync('temp');
      expect(await api.clientStorage.getAsync('temp'), isNull);
    });

    test('list keys', () async {
      await api.clientStorage.setAsync('key1', 'a');
      await api.clientStorage.setAsync('key2', 'b');
      await api.clientStorage.setAsync('key3', 'c');

      final keys = await api.clientStorage.keysAsync();
      expect(keys, containsAll(['key1', 'key2', 'key3']));
    });
  });

  group('Plugin API Viewport', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('viewport properties', () {
      expect(api.viewport.zoom, 1);
      expect(api.viewport.center, isA<Vector2>());
      expect(api.viewport.bounds, isA<FigmaRect>());
    });

    test('scroll and zoom into view', () {
      final page = api.createPage();
      api.root.appendChild(page);

      final frame = api.createFrame();
      frame.x = 1000;
      frame.y = 1000;
      page.appendChild(frame);

      // Just verify no error is thrown
      api.viewport.scrollAndZoomIntoView([frame]);
    });
  });

  group('Plugin API Codegen Support', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('getCSSAsync generates basic CSS', () async {
      final rect = api.createRectangle();
      rect.width = 200;
      rect.height = 100;
      rect.cornerRadius = 8;
      rect.fills = [
        Paint.solid(const FigmaColor(r: 1.0, g: 0.0, b: 0.0)),
      ];

      final css = await api.getCSSAsync(rect);

      expect(css['width'], '200.0px');
      expect(css['height'], '100.0px');
      expect(css['border-radius'], '8.0px');
      expect(css['background-color'], contains('255'));
    });

    test('skipInvisibleInstanceChildren default is false', () {
      expect(api.skipInvisibleInstanceChildren, false);
      api.skipInvisibleInstanceChildren = true;
      expect(api.skipInvisibleInstanceChildren, true);
    });
  });

  group('Plugin API Team Library Import', () {
    test('importComponentByKeyAsync requires teamlibrary permission', () async {
      final manifest = PluginManifest.fromJsonString('''
      {
        "name": "Test",
        "id": "test",
        "api": "1.0.0",
        "main": "code.js",
        "editorType": "figma",
        "permissions": []
      }
      ''');

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      expect(
        () => api.importComponentByKeyAsync('key123'),
        throwsA(isA<PluginPermissionError>()),
      );
    });

    test('importComponentByKeyAsync succeeds with permission', () async {
      final manifest = PluginManifest.fromJsonString('''
      {
        "name": "Test",
        "id": "test",
        "api": "1.0.0",
        "main": "code.js",
        "editorType": "figma",
        "permissions": ["teamlibrary"]
      }
      ''');

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // Should not throw
      final result = await api.importComponentByKeyAsync('key123');
      expect(result, isNull); // Returns null in mock implementation
    });
  });

  group('Plugin Error Types', () {
    test('PluginPermissionError has correct message', () {
      final error = PluginPermissionError('Test error message');
      expect(error.message, 'Test error message');
      expect(error.toString(), contains('PluginPermissionError'));
      expect(error.toString(), contains('Test error message'));
    });

    test('PluginNetworkError includes URL', () {
      final error = PluginNetworkError(
        'Domain not allowed',
        url: 'https://blocked.com/api',
      );
      expect(error.message, 'Domain not allowed');
      expect(error.url, 'https://blocked.com/api');
      expect(error.toString(), contains('blocked.com'));
    });

    test('PluginTypeError includes type info', () {
      final error = PluginTypeError(
        'Invalid value',
        expectedType: 'String',
        actualType: 'int',
      );
      expect(error.toString(), contains('expected: String'));
      expect(error.toString(), contains('got: int'));
    });

    test('PluginNodeError includes node ID', () {
      final error = PluginNodeError(
        'Node not found',
        nodeId: '1:234',
      );
      expect(error.toString(), contains('node: 1:234'));
    });

    test('PluginManifestError includes error list', () {
      final error = PluginManifestError(
        'Invalid manifest',
        errors: ['Missing name', 'Invalid API version'],
      );
      expect(error.toString(), contains('Missing name'));
      expect(error.toString(), contains('Invalid API version'));
    });
  });

  group('BoundVariable', () {
    test('creates with required fields', () {
      const bound = BoundVariable(variableId: 'var-123');
      expect(bound.variableId, 'var-123');
      expect(bound.modeId, isNull);
    });

    test('creates with mode ID', () {
      const bound = BoundVariable(variableId: 'var-456', modeId: 'mode-1');
      expect(bound.variableId, 'var-456');
      expect(bound.modeId, 'mode-1');
    });

    test('toJson includes all fields', () {
      const bound = BoundVariable(variableId: 'var-789', modeId: 'mode-2');
      final json = bound.toJson();
      expect(json['variableId'], 'var-789');
      expect(json['modeId'], 'mode-2');
    });
  });

  group('Plugin API Dev Mode', () {
    late FigmaPluginAPI api;

    setUp(() {
      api = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );
    });

    test('add and get annotations', () {
      final node = api.createRectangle();
      expect(api.getAnnotations(node), isEmpty);

      const annotation = Annotation(
        label: 'Design Note',
        properties: [AnnotationProperty(type: 'text', textValue: 'Use brand colors')],
      );
      api.addAnnotation(node, annotation);

      final annotations = api.getAnnotations(node);
      expect(annotations.length, 1);
      expect(annotations.first.label, 'Design Note');
    });

    test('get measurements', () {
      final node = api.createRectangle();
      expect(api.getMeasurements(node), isEmpty);
    });
  });

  // ============================================================
  // Sample Plugin End-to-End Test
  // ============================================================
  // This demonstrates a complete plugin workflow as specified in PRD 4.16

  group('Sample Plugin End-to-End Test', () {
    test('complete plugin workflow: design grid creator', () async {
      // 1. Parse manifest (simulating plugin installation)
      final manifest = PluginManifest.fromJsonString('''
      {
        "name": "Grid Creator",
        "id": "com.example.gridcreator",
        "api": "1.0.0",
        "main": "code.js",
        "ui": "ui.html",
        "editorType": ["figma"],
        "version": "1.2.0",
        "description": "Creates design grids with customizable spacing",
        "networkAccess": {
          "allowedDomains": ["api.gridcreator.com"],
          "reasoning": "For fetching preset configurations"
        },
        "permissions": ["currentuser"],
        "menu": [
          {"name": "Create 12-Column Grid", "command": "grid-12"},
          {"name": "Create 8-Column Grid", "command": "grid-8"},
          {"separator": true},
          {"name": "Custom Grid...", "command": "custom"}
        ]
      }
      ''');

      // 2. Validate manifest
      final validation = manifest.validate();
      expect(validation.isValid, true);
      expect(validation.errors, isEmpty);

      // 3. Initialize API with manifest
      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // 4. Check API properties (PRD 4.16.1.1)
      expect(api.apiVersion, isNotEmpty);
      expect(api.editorType, PluginEditorType.figma);

      // 5. Create nodes (PRD 4.16.2.1) - simulating grid creation
      final frame = api.createFrame();
      frame.name = 'Grid Container';
      frame.width = 1440;
      frame.height = 900;

      // Create 12 column rectangles
      final columns = <PluginNodeProxy>[];
      const columnWidth = 100.0;
      const gutterWidth = 20.0;

      for (var i = 0; i < 12; i++) {
        final column = api.createRectangle();
        column.name = 'Column ${i + 1}';
        column.width = columnWidth;
        column.height = 900;
        column.x = i * (columnWidth + gutterWidth);
        column.y = 0;
        column.opacity = 0.1;
        columns.add(column);
      }

      expect(columns.length, 12);
      expect(columns.first.name, 'Column 1');
      expect(columns.last.name, 'Column 12');

      // 6. Group nodes (PRD 4.16.2.2)
      final group = api.group(columns, frame);
      expect(group.type, NodeType.GROUP);
      expect(group.name, 'Group');

      // 7. Event handling (PRD 4.16.1.8)
      var selectionChanged = false;
      api.on('selectionchange', () {
        selectionChanged = true;
      });

      // Simulate selection change
      api.selection = [frame];
      expect(api.selection.length, 1);

      // 8. Client storage (PRD 4.16.1.6)
      await api.clientStorage.setAsync('lastGridType', '12-column');
      final stored = await api.clientStorage.getAsync('lastGridType');
      expect(stored, '12-column');

      // 9. Viewport operations (PRD 4.16.1.6)
      api.viewport.scrollAndZoomIntoView([frame]);
      api.viewport.zoom = 0.5;
      expect(api.viewport.zoom, 0.5);

      // 10. Network access check (PRD 4.16.8.2)
      expect(api.isNetworkAccessAllowed('https://api.gridcreator.com/presets'), true);
      expect(api.isNetworkAccessAllowed('https://evil.com/steal'), false);

      // 11. Fetch with enforcement
      final response = await api.fetch('https://api.gridcreator.com/presets');
      expect(response.ok, true);

      // 12. Verify fetch throws for blocked domain
      expect(
        () => api.fetch('https://blocked.com/data'),
        throwsA(isA<PluginNetworkError>()),
      );

      // 13. UI interaction (PRD 4.16.1.5)
      api.ui.show(width: 400, height: 300);
      expect(api.ui.isVisible, true);

      // 14. Close plugin (PRD 4.16.1.7)
      api.closePlugin('Grid created successfully!');
    });

    test('plugin with document operations', () async {
      final manifest = PluginManifest(
        name: 'Document Inspector',
        id: 'com.example.inspector',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
      );

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // Create a component hierarchy
      final page = api.createPage();
      page.name = 'Design System';

      final component = api.createComponent();
      component.name = 'Button/Primary';
      component.width = 120;
      component.height = 40;

      // Create internal structure
      final background = api.createRectangle();
      background.name = 'Background';
      background.width = 120;
      background.height = 40;
      background.cornerRadius = 8;

      final label = api.createText();
      label.name = 'Label';
      label.characters = 'Click me';

      // Boolean operations (PRD 4.16.2.2)
      // Use a frame as parent for boolean operations
      final container = api.createFrame();
      container.name = 'Boolean Container';

      final rect1 = api.createRectangle();
      rect1.width = 100;
      rect1.height = 100;

      final rect2 = api.createRectangle();
      rect2.width = 100;
      rect2.height = 100;
      rect2.x = 50;
      rect2.y = 50;

      final unionResult = api.union([rect1, rect2], container);
      expect(unionResult.type, NodeType.BOOLEAN_OPERATION);

      final subtractResult = api.subtract([rect1, rect2], container);
      expect(subtractResult.type, NodeType.BOOLEAN_OPERATION);

      final intersectResult = api.intersect([rect1, rect2], container);
      expect(intersectResult.type, NodeType.BOOLEAN_OPERATION);

      final excludeResult = api.exclude([rect1, rect2], container);
      expect(excludeResult.type, NodeType.BOOLEAN_OPERATION);

      // Flatten (PRD 4.16.2.2)
      final vector = api.createVector();
      final flattened = api.flatten([vector], container);
      expect(flattened.type, NodeType.VECTOR);
    });

    test('plugin with styles and variables', () async {
      final manifest = PluginManifest(
        name: 'Theme Manager',
        id: 'com.example.theme',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
      );

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // Create styles (PRD 4.16.5.1)
      final paintStyle = api.createPaintStyle();
      paintStyle.name = 'Brand/Primary';
      expect(paintStyle.name, 'Brand/Primary');

      final textStyle = api.createTextStyle();
      textStyle.name = 'Heading/H1';
      expect(textStyle.name, 'Heading/H1');

      final effectStyle = api.createEffectStyle();
      effectStyle.name = 'Shadow/Medium';

      final gridStyle = api.createGridStyle();
      gridStyle.name = 'Layout/12-Column';

      // Get local styles (PRD 4.16.5.2)
      final localPaintStyles = await api.getLocalPaintStylesAsync();
      expect(localPaintStyles, isA<List>());

      final localTextStyles = await api.getLocalTextStylesAsync();
      expect(localTextStyles, isA<List>());

      // Variables (PRD 4.16.1.6)
      final variable = api.variables.createVariable('spacing-small', 'FLOAT');
      expect(variable.name, 'spacing-small');
    });

    test('plugin with codegen support', () async {
      final manifest = PluginManifest(
        name: 'Flutter Codegen',
        id: 'com.example.fluttergen',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.dev],
        capabilities: const PluginCapabilities(codegen: true),
        codegenLanguages: ['dart', 'flutter'],
      );

      final api = FigmaPluginAPI(
        manifest: manifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // Create a node for codegen
      final button = api.createFrame();
      button.name = 'PrimaryButton';
      button.width = 200;
      button.height = 48;

      // Generate CSS (PRD 4.16.1.2 - skipInvisibleInstanceChildren)
      api.skipInvisibleInstanceChildren = true;
      expect(api.skipInvisibleInstanceChildren, true);

      // Get CSS async
      final css = await api.getCSSAsync(button);
      expect(css, isA<Map<String, String>>());
      expect(css['width'], '200.0px');
      expect(css['height'], '48.0px');
    });

    test('plugin error handling scenarios', () async {
      // Test without manifest (no permissions)
      final apiNoManifest = FigmaPluginAPI(
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // Network access should fail without manifest
      expect(apiNoManifest.isNetworkAccessAllowed('https://any.com'), false);

      // Test with restricted permissions
      final restrictedManifest = PluginManifest(
        name: 'Restricted Plugin',
        id: 'com.example.restricted',
        api: '1.0.0',
        main: 'code.js',
        editorType: [PluginEditorType.figma],
        // No permissions granted
      );

      final restrictedApi = FigmaPluginAPI(
        manifest: restrictedManifest,
        ui: PluginUIController(),
        viewport: PluginViewportProxy(),
      );

      // Should throw for permission-required operations
      expect(
        () => restrictedApi.currentUser,
        throwsA(isA<PluginPermissionError>()),
      );

      // Test error types
      final nodeError = PluginNodeError('Node not found', nodeId: 'invalid-id');
      expect(nodeError.toString(), contains('invalid-id'));

      final typeError = PluginTypeError(
        'Expected RectangleNode',
        expectedType: 'RectangleNode',
        actualType: 'TextNode',
      );
      expect(typeError.toString(), contains('RectangleNode'));
      expect(typeError.toString(), contains('TextNode'));

      final manifestError = PluginManifestError(
        'Invalid manifest',
        errors: ['Missing name', 'Invalid API version'],
      );
      expect(manifestError.errors.length, 2);
    });
  });
}
