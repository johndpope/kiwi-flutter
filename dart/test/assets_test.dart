import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  group('Asset Data Models', () {
    group('ComponentAsset', () {
      test('creates component asset with required fields', () {
        final component = ComponentAsset(
          id: 'comp-1',
          name: 'Button',
          description: 'A primary button',
          nodeId: 'node-123',
          size: const Size(100, 40),
        );

        expect(component.id, 'comp-1');
        expect(component.name, 'Button');
        expect(component.description, 'A primary button');
        expect(component.nodeId, 'node-123');
        expect(component.size, const Size(100, 40));
        expect(component.type, AssetType.component);
      });

      test('component with properties', () {
        final component = ComponentAsset(
          id: 'comp-2',
          name: 'Toggle',
          nodeId: 'node-456',
          size: const Size(50, 30),
          properties: [
            const ComponentProperty(
              id: 'prop-1',
              name: 'isOn',
              type: ComponentPropertyType.boolean,
              defaultValue: false,
            ),
            const ComponentProperty(
              id: 'prop-2',
              name: 'label',
              type: ComponentPropertyType.text,
              defaultValue: 'Toggle',
            ),
          ],
        );

        expect(component.properties, hasLength(2));
        expect(component.properties[0].type, ComponentPropertyType.boolean);
        expect(component.properties[0].defaultValue, false);
        expect(component.properties[1].type, ComponentPropertyType.text);
        expect(component.properties[1].defaultValue, 'Toggle');
      });

      test('component with instance swap property', () {
        final component = ComponentAsset(
          id: 'comp-3',
          name: 'IconButton',
          nodeId: 'node-789',
          size: const Size(48, 48),
          properties: [
            const ComponentProperty(
              id: 'prop-3',
              name: 'icon',
              type: ComponentPropertyType.instanceSwap,
              preferredValues: ['icon-1', 'icon-2', 'icon-3'],
            ),
          ],
        );

        final prop = component.properties[0];
        expect(prop.type, ComponentPropertyType.instanceSwap);
        expect(prop.preferredValues, ['icon-1', 'icon-2', 'icon-3']);
      });

      test('component with variant properties', () {
        final component = ComponentAsset(
          id: 'comp-4',
          name: 'Button',
          nodeId: 'node-variant',
          size: const Size(100, 40),
          componentSetId: 'set-1',
          variantProperties: {'size': 'large', 'state': 'hover'},
        );

        expect(component.isVariant, true);
        expect(component.variantProperties['size'], 'large');
        expect(component.variantProperties['state'], 'hover');
      });
    });

    group('ComponentSetAsset', () {
      test('creates component set with variants', () {
        final componentSet = ComponentSetAsset(
          id: 'set-1',
          name: 'Button',
          nodeId: 'node-set-1',
          variantAxes: {
            'size': ['small', 'medium', 'large'],
            'state': ['default', 'hover'],
          },
        );

        expect(componentSet.id, 'set-1');
        expect(componentSet.name, 'Button');
        expect(componentSet.variantAxes['size'], hasLength(3));
        expect(componentSet.variantAxes['state'], hasLength(2));
        expect(componentSet.type, AssetType.componentSet);
      });
    });

    group('PaintStyleAsset', () {
      test('creates solid color style', () {
        final style = PaintStyleAsset(
          id: 'style-1',
          name: 'Primary Blue',
          paintType: PaintStyleType.solid,
          color: const Color(0xFF0066FF),
          opacity: 1.0,
        );

        expect(style.id, 'style-1');
        expect(style.name, 'Primary Blue');
        expect(style.paintType, PaintStyleType.solid);
        expect(style.color, const Color(0xFF0066FF));
        expect(style.type, AssetType.paintStyle);
      });

      test('creates gradient style', () {
        final style = PaintStyleAsset(
          id: 'style-2',
          name: 'Sunset Gradient',
          paintType: PaintStyleType.gradient,
          gradient: GradientStyleData(
            type: 'GRADIENT_LINEAR',
            stops: [
              const GradientStopData(position: 0.0, color: Color(0xFFFF6B6B)),
              const GradientStopData(position: 1.0, color: Color(0xFFFFE66D)),
            ],
          ),
        );

        expect(style.paintType, PaintStyleType.gradient);
        expect(style.gradient?.stops, hasLength(2));
      });

      test('gets preview color from solid', () {
        final style = PaintStyleAsset(
          id: 'style-3',
          name: 'Red',
          paintType: PaintStyleType.solid,
          color: Colors.red,
        );

        expect(style.previewColor, Colors.red);
      });
    });

    group('TextStyleAsset', () {
      test('creates text style', () {
        final style = TextStyleAsset(
          id: 'text-1',
          name: 'Heading 1',
          fontFamily: 'Inter',
          fontWeight: FontWeight.bold,
          fontSize: 32.0,
          lineHeight: 1.2,
          letterSpacing: -0.5,
        );

        expect(style.id, 'text-1');
        expect(style.name, 'Heading 1');
        expect(style.fontFamily, 'Inter');
        expect(style.fontWeight, FontWeight.bold);
        expect(style.fontSize, 32.0);
        expect(style.lineHeight, 1.2);
        expect(style.letterSpacing, -0.5);
        expect(style.type, AssetType.textStyle);
      });

      test('converts to Flutter TextStyle', () {
        final style = TextStyleAsset(
          id: 'text-2',
          name: 'Body',
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
          fontSize: 16.0,
          lineHeight: 1.5,
          letterSpacing: 0.0,
          color: const Color(0xFF333333),
        );

        final flutterStyle = style.toFlutterTextStyle();
        expect(flutterStyle.fontFamily, 'Roboto');
        expect(flutterStyle.fontWeight, FontWeight.w400);
        expect(flutterStyle.fontSize, 16.0);
        expect(flutterStyle.height, 1.5);
        expect(flutterStyle.letterSpacing, 0.0);
        expect(flutterStyle.color, const Color(0xFF333333));
      });
    });

    group('EffectStyleAsset', () {
      test('creates shadow effect style', () {
        final style = EffectStyleAsset(
          id: 'effect-1',
          name: 'Card Shadow',
          effects: [
            const EffectStyleData(
              type: EffectStyleType.dropShadow,
              color: Color(0x1A000000),
              offset: Offset(0, 4),
              radius: 8.0,
              spread: 0.0,
            ),
          ],
        );

        expect(style.id, 'effect-1');
        expect(style.name, 'Card Shadow');
        expect(style.effects, hasLength(1));
        expect(style.effects.first.type, EffectStyleType.dropShadow);
        expect(style.type, AssetType.effectStyle);
      });

      test('creates blur effect style', () {
        final style = EffectStyleAsset(
          id: 'effect-2',
          name: 'Background Blur',
          effects: [
            const EffectStyleData(
              type: EffectStyleType.backgroundBlur,
              radius: 20.0,
            ),
          ],
        );

        expect(style.effects.first.type, EffectStyleType.backgroundBlur);
        expect(style.effects.first.radius, 20.0);
      });

      test('converts shadow to BoxShadow', () {
        const effect = EffectStyleData(
          type: EffectStyleType.dropShadow,
          color: Color(0x1A000000),
          offset: Offset(0, 4),
          radius: 8.0,
          spread: 2.0,
        );

        final boxShadow = effect.toBoxShadow();
        expect(boxShadow, isNotNull);
        expect(boxShadow!.color, const Color(0x1A000000));
        expect(boxShadow.offset, const Offset(0, 4));
        expect(boxShadow.blurRadius, 8.0);
        expect(boxShadow.spreadRadius, 2.0);
      });
    });

    group('ImageAsset', () {
      test('creates image asset', () {
        final image = ImageAsset(
          id: 'img-1',
          name: 'Hero Image',
          imageRef: 'abc123def456',
          format: 'png',
        );

        expect(image.id, 'img-1');
        expect(image.name, 'Hero Image');
        expect(image.imageRef, 'abc123def456');
        expect(image.format, 'png');
        expect(image.type, AssetType.image);
      });

      test('checks if data is available', () {
        final imageNoData = ImageAsset(
          id: 'img-2',
          name: 'No Data',
          imageRef: 'xyz789',
          format: 'jpg',
        );
        expect(imageNoData.hasData, false);

        final imageWithPath = ImageAsset(
          id: 'img-3',
          name: 'With Path',
          imageRef: 'path123',
          format: 'jpg',
          filePath: '/path/to/image.jpg',
        );
        expect(imageWithPath.hasData, true);

        final imageWithBase64 = ImageAsset(
          id: 'img-4',
          name: 'With Base64',
          imageRef: 'base64ref',
          format: 'png',
          base64Data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ',
        );
        expect(imageWithBase64.hasData, true);
      });
    });
  });

  group('Variables System', () {
    group('DesignVariable', () {
      test('creates color variable with modes', () {
        final variable = DesignVariable(
          id: 'var-1',
          name: 'primary',
          collectionId: 'col-1',
          type: VariableType.color,
          valuesByMode: {
            'light': VariableValue<dynamic>(value: const Color(0xFF0066FF)),
            'dark': VariableValue<dynamic>(value: const Color(0xFF4D9FFF)),
          },
        );

        expect(variable.id, 'var-1');
        expect(variable.name, 'primary');
        expect(variable.type, VariableType.color);
        expect(variable.valuesByMode, hasLength(2));
      });

      test('creates number variable', () {
        final variable = DesignVariable(
          id: 'var-2',
          name: 'spacing-md',
          collectionId: 'col-1',
          type: VariableType.number,
          valuesByMode: {
            'default': VariableValue<dynamic>(value: 16.0),
          },
        );

        expect(variable.type, VariableType.number);
        expect(variable.getNumberValue('default'), 16.0);
      });

      test('creates string variable', () {
        final variable = DesignVariable(
          id: 'var-3',
          name: 'app-name',
          collectionId: 'col-1',
          type: VariableType.string,
          valuesByMode: {
            'default': VariableValue<dynamic>(value: 'My App'),
          },
        );

        expect(variable.type, VariableType.string);
        expect(variable.getStringValue('default'), 'My App');
      });

      test('creates boolean variable', () {
        final variable = DesignVariable(
          id: 'var-4',
          name: 'feature-enabled',
          collectionId: 'col-1',
          type: VariableType.boolean,
          valuesByMode: {
            'default': VariableValue<dynamic>(value: true),
          },
        );

        expect(variable.type, VariableType.boolean);
        expect(variable.getBooleanValue('default'), true);
      });
    });

    group('VariableCollection', () {
      test('creates collection with modes', () {
        final collection = VariableCollection(
          id: 'col-1',
          name: 'Theme',
          modes: [
            const VariableMode(id: 'light', name: 'Light', index: 0),
            const VariableMode(id: 'dark', name: 'Dark', index: 1),
          ],
          defaultModeId: 'light',
        );

        expect(collection.id, 'col-1');
        expect(collection.name, 'Theme');
        expect(collection.modes, hasLength(2));
        expect(collection.defaultModeId, 'light');
      });

      test('gets default mode', () {
        final collection = VariableCollection(
          id: 'col-1',
          name: 'Theme',
          modes: [
            const VariableMode(id: 'light', name: 'Light', index: 0),
            const VariableMode(id: 'dark', name: 'Dark', index: 1),
          ],
          defaultModeId: 'light',
        );

        final defaultMode = collection.defaultMode;
        expect(defaultMode?.id, 'light');
        expect(defaultMode?.name, 'Light');
      });

      test('gets mode by ID', () {
        final collection = VariableCollection(
          id: 'col-1',
          name: 'Theme',
          modes: [
            const VariableMode(id: 'light', name: 'Light', index: 0),
            const VariableMode(id: 'dark', name: 'Dark', index: 1),
          ],
          defaultModeId: 'light',
        );

        final darkMode = collection.getModeById('dark');
        expect(darkMode?.id, 'dark');
        expect(darkMode?.name, 'Dark');
      });
    });

    group('VariableResolver', () {
      late VariableResolver resolver;

      setUp(() {
        final collections = <String, VariableCollection>{
          'col-1': VariableCollection(
            id: 'col-1',
            name: 'Theme',
            modes: [
              const VariableMode(id: 'light', name: 'Light', index: 0),
              const VariableMode(id: 'dark', name: 'Dark', index: 1),
            ],
            defaultModeId: 'light',
          ),
        };

        final variables = <String, DesignVariable>{
          'var-primary': DesignVariable(
            id: 'var-primary',
            name: 'primary',
            collectionId: 'col-1',
            type: VariableType.color,
            valuesByMode: {
              'light': VariableValue<dynamic>(value: const Color(0xFF0066FF)),
              'dark': VariableValue<dynamic>(value: const Color(0xFF4D9FFF)),
            },
          ),
          'var-spacing': DesignVariable(
            id: 'var-spacing',
            name: 'spacing',
            collectionId: 'col-1',
            type: VariableType.number,
            valuesByMode: {
              'light': VariableValue<dynamic>(value: 16.0),
              'dark': VariableValue<dynamic>(value: 16.0),
            },
          ),
        };

        resolver = VariableResolver(
          variables: variables,
          collections: collections,
          currentModes: {'col-1': 'light'},
        );
      });

      test('resolves color variable in light mode', () {
        final color = resolver.resolveColor('var-primary');
        expect(color, const Color(0xFF0066FF));
      });

      test('resolves color variable in dark mode', () {
        resolver.setMode('col-1', 'dark');
        final color = resolver.resolveColor('var-primary');
        expect(color, const Color(0xFF4D9FFF));
      });

      test('resolves number variable', () {
        final spacing = resolver.resolveNumber('var-spacing');
        expect(spacing, 16.0);
      });

      test('returns null for unknown variable', () {
        final result = resolver.resolveColor('unknown');
        expect(result, isNull);
      });

      test('gets current mode for collection', () {
        expect(resolver.getModeId('col-1'), 'light');
        resolver.setMode('col-1', 'dark');
        expect(resolver.getModeId('col-1'), 'dark');
      });
    });

    group('VariableAlias', () {
      test('creates alias to another variable', () {
        final alias = DesignVariable(
          id: 'var-alias',
          name: 'button-color',
          collectionId: 'col-1',
          type: VariableType.color,
          valuesByMode: {
            'light': VariableValue<dynamic>.alias('var-primary'),
          },
        );

        expect(alias.valuesByMode['light']!.isAlias, true);
        expect(alias.valuesByMode['light']!.aliasId, 'var-primary');
      });

      test('resolver follows alias chain', () {
        final collections = <String, VariableCollection>{
          'col-1': VariableCollection(
            id: 'col-1',
            name: 'Theme',
            modes: [const VariableMode(id: 'default', name: 'Default', index: 0)],
            defaultModeId: 'default',
          ),
        };

        final variables = <String, DesignVariable>{
          'var-primary': DesignVariable(
            id: 'var-primary',
            name: 'primary',
            collectionId: 'col-1',
            type: VariableType.color,
            valuesByMode: {
              'default': VariableValue<dynamic>(value: const Color(0xFF0066FF)),
            },
          ),
          'var-button': DesignVariable(
            id: 'var-button',
            name: 'button-color',
            collectionId: 'col-1',
            type: VariableType.color,
            valuesByMode: {
              'default': VariableValue<dynamic>.alias('var-primary'),
            },
          ),
        };

        final resolver = VariableResolver(
          variables: variables,
          collections: collections,
          currentModes: {'col-1': 'default'},
        );

        final color = resolver.resolveColor('var-button');
        expect(color, const Color(0xFF0066FF));
      });
    });

    group('VariableManager', () {
      test('manages mode changes', () {
        final collections = <String, VariableCollection>{
          'col-1': VariableCollection(
            id: 'col-1',
            name: 'Theme',
            modes: [
              const VariableMode(id: 'light', name: 'Light', index: 0),
              const VariableMode(id: 'dark', name: 'Dark', index: 1),
            ],
            defaultModeId: 'light',
          ),
        };

        final resolver = VariableResolver(
          variables: {},
          collections: collections,
        );

        final manager = VariableManager(resolver);

        expect(resolver.getModeId('col-1'), 'light');

        manager.switchMode('col-1', 'dark');
        expect(resolver.getModeId('col-1'), 'dark');
      });

      test('notifies listeners on mode change', () {
        final collections = <String, VariableCollection>{
          'col-1': VariableCollection(
            id: 'col-1',
            name: 'Theme',
            modes: [
              const VariableMode(id: 'light', name: 'Light', index: 0),
              const VariableMode(id: 'dark', name: 'Dark', index: 1),
            ],
            defaultModeId: 'light',
          ),
        };

        final resolver = VariableResolver(
          variables: {},
          collections: collections,
        );

        final manager = VariableManager(resolver);

        var notified = false;
        manager.addListener(() => notified = true);

        manager.switchMode('col-1', 'dark');
        expect(notified, true);
      });
    });
  });

  group('Frame Presets', () {
    test('iPhone presets have correct dimensions', () {
      final iphone16 = FramePresets.iPhones.firstWhere((p) => p.id == 'iphone_16');
      expect(iphone16.width, 393);
      expect(iphone16.height, 852);
      expect(iphone16.name, 'iPhone 16');

      final iphone16Pro = FramePresets.iPhones.firstWhere((p) => p.id == 'iphone_16_pro');
      expect(iphone16Pro.width, 402);
      expect(iphone16Pro.height, 874);

      final iphone16ProMax = FramePresets.iPhones.firstWhere((p) => p.id == 'iphone_16_pro_max');
      expect(iphone16ProMax.width, 440);
      expect(iphone16ProMax.height, 956);

      final iphoneSE = FramePresets.iPhones.firstWhere((p) => p.id == 'iphone_se');
      expect(iphoneSE.width, 320);
      expect(iphoneSE.height, 568);
    });

    test('Android presets have correct dimensions', () {
      final pixel7 = FramePresets.androids.firstWhere((p) => p.id == 'pixel_7');
      expect(pixel7.width, 412);
      expect(pixel7.height, 915);

      final samsungS23 = FramePresets.androids.firstWhere((p) => p.id == 'samsung_s23');
      expect(samsungS23.width, 360);
      expect(samsungS23.height, 780);
    });

    test('iPad presets have correct dimensions', () {
      final ipadPro12 = FramePresets.iPads.firstWhere((p) => p.id == 'ipad_pro_12_9');
      expect(ipadPro12.width, 1024);
      expect(ipadPro12.height, 1366);

      final ipadMini = FramePresets.iPads.firstWhere((p) => p.id == 'ipad_mini');
      expect(ipadMini.width, 744);
      expect(ipadMini.height, 1133);
    });

    test('MacBook presets have correct dimensions', () {
      final macbookPro14 = FramePresets.macBooks.firstWhere((p) => p.id == 'macbook_pro_14');
      expect(macbookPro14.width, 1512);
      expect(macbookPro14.height, 982);

      final macbookAir = FramePresets.macBooks.firstWhere((p) => p.id == 'macbook_air');
      expect(macbookAir.width, 1280);
      expect(macbookAir.height, 832);
    });

    test('social media presets have correct dimensions', () {
      final instagramPost = FramePresets.socialMedia.firstWhere((p) => p.id == 'instagram_post');
      expect(instagramPost.width, 1080);
      expect(instagramPost.height, 1080);

      final instagramStory = FramePresets.socialMedia.firstWhere((p) => p.id == 'instagram_story');
      expect(instagramStory.width, 1080);
      expect(instagramStory.height, 1920);

      final twitterPost = FramePresets.socialMedia.firstWhere((p) => p.id == 'twitter_post');
      expect(twitterPost.width, 1200);
      expect(twitterPost.height, 675);
    });

    test('presentation presets have correct dimensions', () {
      final slide16x9 = FramePresets.presentations.firstWhere((p) => p.id == 'slide_16_9');
      expect(slide16x9.width, 1920);
      expect(slide16x9.height, 1080);

      final slide4x3 = FramePresets.presentations.firstWhere((p) => p.id == 'slide_4_3');
      expect(slide4x3.width, 1024);
      expect(slide4x3.height, 768);
    });

    test('print presets have correct dimensions', () {
      final a4 = FramePresets.print.firstWhere((p) => p.id == 'a4_portrait');
      expect(a4.width, 595);
      expect(a4.height, 842);

      final letter = FramePresets.print.firstWhere((p) => p.id == 'letter_portrait');
      expect(letter.width, 612);
      expect(letter.height, 792);
    });

    test('all presets have unique ids', () {
      final allPresets = FramePresets.all;
      final ids = allPresets.map((p) => p.id).toSet();
      expect(ids.length, allPresets.length);
    });

    test('all presets have positive dimensions', () {
      final allPresets = FramePresets.all;

      for (final preset in allPresets) {
        expect(preset.width, greaterThan(0), reason: '${preset.name} width should be positive');
        expect(preset.height, greaterThan(0), reason: '${preset.name} height should be positive');
      }
    });

    test('byCategory returns presets for category', () {
      final phones = FramePresets.byCategory(FramePresetCategory.phone);
      expect(phones, isNotEmpty);
      for (final phone in phones) {
        expect(phone.category, FramePresetCategory.phone);
      }

      final tablets = FramePresets.byCategory(FramePresetCategory.tablet);
      expect(tablets, isNotEmpty);
      for (final tablet in tablets) {
        expect(tablet.category, FramePresetCategory.tablet);
      }
    });

    test('search finds matching presets', () {
      final results = FramePresets.search('iPhone');
      expect(results, isNotEmpty);
      for (final result in results) {
        expect(result.name.toLowerCase(), contains('iphone'));
      }
    });

    test('search returns all presets for empty query', () {
      final results = FramePresets.search('');
      expect(results, FramePresets.all);
    });

    test('preset provides landscape version', () {
      final iphone = FramePresets.iPhones.first;
      expect(iphone.isPortrait, true);

      final landscape = iphone.landscape;
      expect(landscape.isPortrait, false);
      expect(landscape.width, iphone.height);
      expect(landscape.height, iphone.width);
    });

    test('preset provides dimensions string', () {
      final iphone16 = FramePresets.iPhones.firstWhere((p) => p.id == 'iphone_16');
      expect(iphone16.dimensionsString, '393 × 852');
    });

    test('phones getter returns all phone presets', () {
      final phones = FramePresets.phones;
      expect(phones, [...FramePresets.iPhones, ...FramePresets.androids]);
    });

    test('tablets getter returns all tablet presets', () {
      final tablets = FramePresets.tablets;
      expect(tablets, [...FramePresets.iPads, ...FramePresets.otherTablets]);
    });
  });

  group('GradientStyleData', () {
    test('creates gradient with stops', () {
      final gradient = GradientStyleData(
        type: 'GRADIENT_LINEAR',
        stops: [
          const GradientStopData(position: 0.0, color: Colors.red),
          const GradientStopData(position: 1.0, color: Colors.blue),
        ],
      );

      expect(gradient.type, 'GRADIENT_LINEAR');
      expect(gradient.stops, hasLength(2));
    });

    test('converts to Flutter linear gradient', () {
      final data = GradientStyleData(
        type: 'GRADIENT_LINEAR',
        stops: [
          const GradientStopData(position: 0.0, color: Colors.red),
          const GradientStopData(position: 1.0, color: Colors.blue),
        ],
      );

      final gradient = data.toFlutterGradient();
      expect(gradient, isA<LinearGradient>());
    });

    test('converts to Flutter radial gradient', () {
      final data = GradientStyleData(
        type: 'GRADIENT_RADIAL',
        stops: [
          const GradientStopData(position: 0.0, color: Colors.red),
          const GradientStopData(position: 1.0, color: Colors.blue),
        ],
      );

      final gradient = data.toFlutterGradient();
      expect(gradient, isA<RadialGradient>());
    });
  });

  group('VariableThemeData', () {
    test('generates from resolver', () {
      final collections = <String, VariableCollection>{
        'col-1': VariableCollection(
          id: 'col-1',
          name: 'Theme',
          modes: [const VariableMode(id: 'default', name: 'Default', index: 0)],
          defaultModeId: 'default',
        ),
      };

      final variables = <String, DesignVariable>{
        'var-primary': DesignVariable(
          id: 'var-primary',
          name: 'primary',
          collectionId: 'col-1',
          type: VariableType.color,
          valuesByMode: {
            'default': VariableValue<dynamic>(value: Colors.blue),
          },
        ),
        'var-spacing': DesignVariable(
          id: 'var-spacing',
          name: 'spacing',
          collectionId: 'col-1',
          type: VariableType.number,
          valuesByMode: {
            'default': VariableValue<dynamic>(value: 16.0),
          },
        ),
      };

      final resolver = VariableResolver(
        variables: variables,
        collections: collections,
        currentModes: {'col-1': 'default'},
      );

      final themeData = VariableThemeData.fromResolver(resolver);
      expect(themeData.colors['primary'], Colors.blue);
      expect(themeData.numbers['spacing'], 16.0);
    });
  });

  group('Frame Preset Picker Widget', () {
    testWidgets('renders frame preset picker', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FramePresetPicker(
              onPresetSelected: (_) {},
            ),
          ),
        ),
      );

      // Check for "All" tab
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows iPhone presets in phone category', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FramePresetPicker(
              onPresetSelected: (_) {},
            ),
          ),
        ),
      );

      // All tab shows all presets including iPhones
      expect(find.text('iPhone 16'), findsOneWidget);
    });

    testWidgets('calls onPresetSelected when preset tapped', (tester) async {
      FramePreset? selectedPreset;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FramePresetPicker(
              onPresetSelected: (preset) => selectedPreset = preset,
            ),
          ),
        ),
      );

      await tester.tap(find.text('iPhone 16'));
      await tester.pump();

      expect(selectedPreset, isNotNull);
      expect(selectedPreset!.id, 'iphone_16');
      expect(selectedPreset!.width, 393);
      expect(selectedPreset!.height, 852);
    });

    testWidgets('filters presets with search', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FramePresetPicker(
              onPresetSelected: (_) {},
            ),
          ),
        ),
      );

      // Find search field and enter text
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'iPad');
      await tester.pump();

      // iPad presets should be visible
      expect(find.text('iPad Pro 12.9"'), findsOneWidget);
      // iPhone presets should be filtered out
      expect(find.text('iPhone 16'), findsNothing);
    });
  });

  group('Frame Type Selector Widget', () {
    testWidgets('renders frame type selector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrameTypeSelector(
              selectedType: FrameType.frame,
              onTypeChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Frame'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
    });

    testWidgets('calls onTypeChanged when type tapped', (tester) async {
      FrameType? selectedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrameTypeSelector(
              selectedType: FrameType.frame,
              onTypeChanged: (type) => selectedType = type,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Section'));
      await tester.pump();

      expect(selectedType, FrameType.section);
    });
  });

  group('Asset matching search', () {
    test('asset matches search by name', () {
      final asset = ComponentAsset(
        id: 'comp-1',
        name: 'PrimaryButton',
        nodeId: 'node-1',
        size: const Size(100, 40),
      );

      expect(asset.matchesSearch('primary'), true);
      expect(asset.matchesSearch('Button'), true);
      expect(asset.matchesSearch('BUTTON'), true); // case insensitive
      expect(asset.matchesSearch('Card'), false);
    });

    test('asset matches search by description', () {
      final asset = ComponentAsset(
        id: 'comp-1',
        name: 'Button',
        nodeId: 'node-1',
        size: const Size(100, 40),
        description: 'A clickable button component',
      );

      expect(asset.matchesSearch('clickable'), true);
      expect(asset.matchesSearch('component'), true);
    });

    test('asset matches search by tags', () {
      final asset = ComponentAsset(
        id: 'comp-1',
        name: 'Button',
        nodeId: 'node-1',
        size: const Size(100, 40),
        tags: ['ui', 'interactive', 'form'],
      );

      expect(asset.matchesSearch('ui'), true);
      expect(asset.matchesSearch('interactive'), true);
      expect(asset.matchesSearch('form'), true);
      expect(asset.matchesSearch('modal'), false);
    });
  });
}
