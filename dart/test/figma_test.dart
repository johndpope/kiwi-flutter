import 'package:test/test.dart';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  group('Figma Schema', () {
    group('Schema Parsing', () {
      test('parses Figma schema successfully', () {
        expect(figmaSchema, isNotNull);
        expect(figmaSchema.definitions.length, greaterThan(50));
      });

      test('compiles Figma schema successfully', () {
        expect(compiledFigmaSchema, isNotNull);
      });

      test('has NodeType enum', () {
        final nodeTypes = figmaNodeTypeValues;
        expect(nodeTypes['NONE'], equals(0));
        expect(nodeTypes['DOCUMENT'], equals(1));
        expect(nodeTypes['CANVAS'], equals(2));
        expect(nodeTypes['FRAME'], equals(3));
        expect(nodeTypes['GROUP'], equals(4));
        expect(nodeTypes['VECTOR'], equals(5));
        expect(nodeTypes['RECTANGLE'], equals(10));
        expect(nodeTypes['TEXT'], equals(13));
        expect(nodeTypes['COMPONENT'], equals(38));
        expect(nodeTypes['INSTANCE'], equals(16));
      });

      test('has BlendMode enum', () {
        final blendModes = figmaBlendModeValues;
        expect(blendModes['PASS_THROUGH'], equals(0));
        expect(blendModes['NORMAL'], equals(1));
        expect(blendModes['MULTIPLY'], equals(3));
        expect(blendModes['SCREEN'], equals(6));
        expect(blendModes['OVERLAY'], equals(8));
      });

      test('has PaintType enum', () {
        final paintTypes = figmaPaintTypeValues;
        expect(paintTypes['SOLID'], equals(0));
        expect(paintTypes['GRADIENT_LINEAR'], equals(1));
        expect(paintTypes['GRADIENT_RADIAL'], equals(2));
        expect(paintTypes['IMAGE'], equals(5));
      });

      test('has EffectType enum', () {
        final effectTypes = figmaEffectTypeValues;
        expect(effectTypes['DROP_SHADOW'], equals(0));
        expect(effectTypes['INNER_SHADOW'], equals(1));
        expect(effectTypes['LAYER_BLUR'], equals(2));
        expect(effectTypes['BACKGROUND_BLUR'], equals(3));
      });
    });

    group('Paint Encoding/Decoding', () {
      test('encodes and decodes solid paint', () {
        final paint = {
          'type': 'SOLID',
          'color': {'r': 1.0, 'g': 0.5, 'b': 0.0, 'a': 1.0},
          'opacity': 1.0,
          'visible': true,
          'blendMode': 'NORMAL',
        };

        final encoded = encodeFigmaPaint(paint);
        expect(encoded, isNotEmpty);

        final decoded = decodeFigmaPaint(encoded);
        expect(decoded['type'], equals('SOLID'));
        expect(decoded['visible'], equals(true));
        expect(decoded['blendMode'], equals('NORMAL'));
        expect(decoded['color']['r'], equals(1.0));
        expect(decoded['color']['g'], equals(0.5));
        expect(decoded['color']['b'], equals(0.0));
        expect(decoded['color']['a'], equals(1.0));
      });

      test('encodes and decodes linear gradient paint', () {
        final paint = {
          'type': 'GRADIENT_LINEAR',
          'opacity': 0.8,
          'visible': true,
          'blendMode': 'MULTIPLY',
          'gradientStops': [
            {
              'position': 0.0,
              'color': {'r': 1.0, 'g': 0.0, 'b': 0.0, 'a': 1.0}
            },
            {
              'position': 1.0,
              'color': {'r': 0.0, 'g': 0.0, 'b': 1.0, 'a': 1.0}
            },
          ],
          'gradientTransform': {
            'handlePositionA': {'x': 0.0, 'y': 0.0},
            'handlePositionB': {'x': 1.0, 'y': 0.0},
            'handlePositionC': {'x': 0.0, 'y': 1.0},
          },
        };

        final encoded = encodeFigmaPaint(paint);
        final decoded = decodeFigmaPaint(encoded);

        expect(decoded['type'], equals('GRADIENT_LINEAR'));
        expect(decoded['opacity'], closeTo(0.8, 0.001));
        expect(decoded['gradientStops'], hasLength(2));
        expect(decoded['gradientStops'][0]['position'], equals(0.0));
        expect(decoded['gradientStops'][1]['position'], equals(1.0));
      });

      test('encodes and decodes image paint', () {
        final paint = {
          'type': 'IMAGE',
          'opacity': 1.0,
          'visible': true,
          'blendMode': 'NORMAL',
          'imageScaleMode': 'FILL',
          'imageSizeX': 100.0,
          'imageSizeY': 100.0,
          'imageTransform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
        };

        final encoded = encodeFigmaPaint(paint);
        final decoded = decodeFigmaPaint(encoded);

        expect(decoded['type'], equals('IMAGE'));
        expect(decoded['imageScaleMode'], equals('FILL'));
        expect(decoded['imageSizeX'], equals(100.0));
      });
    });

    group('Effect Encoding/Decoding', () {
      test('encodes and decodes drop shadow', () {
        final effect = {
          'type': 'DROP_SHADOW',
          'visible': true,
          'color': {'r': 0.0, 'g': 0.0, 'b': 0.0, 'a': 0.25},
          'blendMode': 'NORMAL',
          'offset': {'x': 0.0, 'y': 4.0},
          'radius': 8.0,
          'spread': 0.0,
          'showShadowBehindNode': false,
        };

        final encoded = encodeFigmaEffect(effect);
        final decoded = decodeFigmaEffect(encoded);

        expect(decoded['type'], equals('DROP_SHADOW'));
        expect(decoded['visible'], equals(true));
        expect(decoded['offset']['x'], equals(0.0));
        expect(decoded['offset']['y'], equals(4.0));
        expect(decoded['radius'], equals(8.0));
      });

      test('encodes and decodes layer blur', () {
        final effect = {
          'type': 'LAYER_BLUR',
          'visible': true,
          'radius': 12.0,
        };

        final encoded = encodeFigmaEffect(effect);
        final decoded = decodeFigmaEffect(encoded);

        expect(decoded['type'], equals('LAYER_BLUR'));
        expect(decoded['radius'], equals(12.0));
      });
    });

    group('NodeChange Encoding/Decoding', () {
      test('encodes and decodes FRAME node', () {
        final frame = {
          'guid': {'sessionID': 1, 'localID': 100},
          'type': 'FRAME',
          'name': 'Test Frame',
          'visible': true,
          'locked': false,
          'opacity': 1.0,
          'blendMode': 'PASS_THROUGH',
          'size': {'width': 200.0, 'height': 100.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 50.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 50.0
          },
          'clipsContent': true,
          'cornerRadius': 8.0,
          'cornerSmoothing': 0.6,
        };

        final encoded = encodeFigmaNodeChange(frame);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('FRAME'));
        expect(decoded['name'], equals('Test Frame'));
        expect(decoded['visible'], equals(true));
        expect(decoded['size']['width'], equals(200.0));
        expect(decoded['size']['height'], equals(100.0));
        expect(decoded['cornerRadius'], equals(8.0));
      });

      test('encodes and decodes RECTANGLE node', () {
        final rect = {
          'guid': {'sessionID': 1, 'localID': 200},
          'type': 'RECTANGLE',
          'name': 'Background',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 100.0, 'height': 100.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'fillPaints': [
            {
              'type': 'SOLID',
              'color': {'r': 0.2, 'g': 0.4, 'b': 0.8, 'a': 1.0},
              'visible': true,
            }
          ],
          'strokeWeight': 2.0,
          'strokeAlign': 'INSIDE',
        };

        final encoded = encodeFigmaNodeChange(rect);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('RECTANGLE'));
        expect(decoded['name'], equals('Background'));
        expect(decoded['fillPaints'], hasLength(1));
        expect(decoded['fillPaints'][0]['type'], equals('SOLID'));
        expect(decoded['strokeWeight'], equals(2.0));
        expect(decoded['strokeAlign'], equals('INSIDE'));
      });

      test('encodes and decodes TEXT node', () {
        final text = {
          'guid': {'sessionID': 1, 'localID': 300},
          'type': 'TEXT',
          'name': 'Title',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 200.0, 'height': 50.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 10.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 10.0
          },
          'textData': {
            'characters': 'Hello, World!',
            'autoResize': 'WIDTH_AND_HEIGHT',
            'truncation': 'DISABLED',
            'maxLines': 0,
          },
        };

        final encoded = encodeFigmaNodeChange(text);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('TEXT'));
        expect(decoded['textData']['characters'], equals('Hello, World!'));
        expect(decoded['textData']['autoResize'], equals('WIDTH_AND_HEIGHT'));
      });

      test('encodes and decodes VECTOR node', () {
        final vector = {
          'guid': {'sessionID': 1, 'localID': 400},
          'type': 'VECTOR',
          'name': 'Icon',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 24.0, 'height': 24.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'vectorData': {
            'vertices': [
              {
                'x': 0.0,
                'y': 0.0,
                'handleInX': 0.0,
                'handleInY': 0.0,
                'handleOutX': 0.0,
                'handleOutY': 0.0,
                'cornerRadius': 0.0,
                'handleMirroring': false,
              },
              {
                'x': 24.0,
                'y': 12.0,
                'handleInX': 0.0,
                'handleInY': 0.0,
                'handleOutX': 0.0,
                'handleOutY': 0.0,
                'cornerRadius': 0.0,
                'handleMirroring': false,
              },
              {
                'x': 0.0,
                'y': 24.0,
                'handleInX': 0.0,
                'handleInY': 0.0,
                'handleOutX': 0.0,
                'handleOutY': 0.0,
                'cornerRadius': 0.0,
                'handleMirroring': false,
              },
            ],
            'segments': [
              {
                'startVertex': 0,
                'endVertex': 1,
                'tangentStart': 0.0,
                'tangentEnd': 0.0,
              },
              {
                'startVertex': 1,
                'endVertex': 2,
                'tangentStart': 0.0,
                'tangentEnd': 0.0,
              },
              {
                'startVertex': 2,
                'endVertex': 0,
                'tangentStart': 0.0,
                'tangentEnd': 0.0,
              },
            ],
          },
        };

        final encoded = encodeFigmaNodeChange(vector);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('VECTOR'));
        expect(decoded['vectorData']['vertices'], hasLength(3));
        expect(decoded['vectorData']['segments'], hasLength(3));
      });

      test('encodes and decodes ELLIPSE node with arc data', () {
        final ellipse = {
          'guid': {'sessionID': 1, 'localID': 500},
          'type': 'ELLIPSE',
          'name': 'Circle',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 100.0, 'height': 100.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'arcData': {
            'startingAngle': 0.0,
            'endingAngle': 6.283185307179586, // 2 * PI
            'innerRadius': 0.0,
          },
        };

        final encoded = encodeFigmaNodeChange(ellipse);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('ELLIPSE'));
        expect(decoded['arcData']['startingAngle'], equals(0.0));
        expect(decoded['arcData']['innerRadius'], equals(0.0));
      });

      test('encodes and decodes STAR node', () {
        final star = {
          'guid': {'sessionID': 1, 'localID': 600},
          'type': 'STAR',
          'name': 'Star',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 100.0, 'height': 100.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'starPointCount': 5,
          'starInnerRadius': 0.4,
        };

        final encoded = encodeFigmaNodeChange(star);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('STAR'));
        expect(decoded['starPointCount'], equals(5));
        expect(decoded['starInnerRadius'], closeTo(0.4, 0.001));
      });

      test('encodes and decodes COMPONENT node', () {
        final component = {
          'guid': {'sessionID': 1, 'localID': 700},
          'type': 'COMPONENT',
          'name': 'Button',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'PASS_THROUGH',
          'size': {'width': 120.0, 'height': 40.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'clipsContent': true,
          'cornerRadius': 20.0,
        };

        final encoded = encodeFigmaNodeChange(component);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('COMPONENT'));
        expect(decoded['name'], equals('Button'));
        expect(decoded['cornerRadius'], equals(20.0));
      });

      test('encodes and decodes INSTANCE node', () {
        final instance = {
          'guid': {'sessionID': 1, 'localID': 800},
          'type': 'INSTANCE',
          'name': 'Button Instance',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'PASS_THROUGH',
          'size': {'width': 120.0, 'height': 40.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 200.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 100.0
          },
          'componentID': {'sessionID': 1, 'localID': 700},
          'componentPropertyAssignments': [
            {'definitionID': 'label', 'value': 'Click Me'},
          ],
        };

        final encoded = encodeFigmaNodeChange(instance);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('INSTANCE'));
        expect(decoded['componentID']['localID'], equals(700));
        expect(decoded['componentPropertyAssignments'], hasLength(1));
        expect(decoded['componentPropertyAssignments'][0]['value'],
            equals('Click Me'));
      });

      test('encodes and decodes node with auto-layout', () {
        final autoLayoutFrame = {
          'guid': {'sessionID': 1, 'localID': 900},
          'type': 'FRAME',
          'name': 'Auto Layout Frame',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'PASS_THROUGH',
          'size': {'width': 300.0, 'height': 200.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'clipsContent': true,
          'stackMode': 'VERTICAL',
          'stackPrimaryAlign': 'MIN',
          'stackCounterAlign': 'CENTER',
          'stackSpacing': 16.0,
          'stackPaddingTop': 24.0,
          'stackPaddingRight': 24.0,
          'stackPaddingBottom': 24.0,
          'stackPaddingLeft': 24.0,
          'stackPrimarySizing': 'RESIZE_TO_FIT',
          'stackCounterSizing': 'FIXED',
        };

        final encoded = encodeFigmaNodeChange(autoLayoutFrame);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['stackMode'], equals('VERTICAL'));
        expect(decoded['stackPrimaryAlign'], equals('MIN'));
        expect(decoded['stackCounterAlign'], equals('CENTER'));
        expect(decoded['stackSpacing'], equals(16.0));
        expect(decoded['stackPaddingTop'], equals(24.0));
      });

      test('encodes and decodes node with effects', () {
        final nodeWithEffects = {
          'guid': {'sessionID': 1, 'localID': 1000},
          'type': 'RECTANGLE',
          'name': 'Card',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 200.0, 'height': 150.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'cornerRadius': 12.0,
          'effects': [
            {
              'type': 'DROP_SHADOW',
              'visible': true,
              'color': {'r': 0.0, 'g': 0.0, 'b': 0.0, 'a': 0.15},
              'blendMode': 'NORMAL',
              'offset': {'x': 0.0, 'y': 4.0},
              'radius': 16.0,
              'spread': 0.0,
            },
            {
              'type': 'DROP_SHADOW',
              'visible': true,
              'color': {'r': 0.0, 'g': 0.0, 'b': 0.0, 'a': 0.08},
              'blendMode': 'NORMAL',
              'offset': {'x': 0.0, 'y': 1.0},
              'radius': 4.0,
              'spread': 0.0,
            },
          ],
        };

        final encoded = encodeFigmaNodeChange(nodeWithEffects);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['effects'], hasLength(2));
        expect(decoded['effects'][0]['type'], equals('DROP_SHADOW'));
        expect(decoded['effects'][0]['radius'], equals(16.0));
        expect(decoded['effects'][1]['radius'], equals(4.0));
      });

      test('encodes and decodes node with prototype interaction', () {
        final nodeWithInteraction = {
          'guid': {'sessionID': 1, 'localID': 1100},
          'type': 'RECTANGLE',
          'name': 'Button',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 100.0, 'height': 40.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'interactions': [
            {
              'trigger': 'ON_CLICK',
              'actions': [
                {
                  'navigationType': 'NAVIGATE',
                  'destinationID': {'sessionID': 1, 'localID': 2000},
                  'transition': {
                    'type': 'DISSOLVE',
                    'duration': 0.3,
                    'easingType': 'EASE_IN_OUT',
                  },
                  'preserveScrollPosition': false,
                },
              ],
              'delay': 0.0,
            },
          ],
        };

        final encoded = encodeFigmaNodeChange(nodeWithInteraction);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['interactions'], hasLength(1));
        expect(decoded['interactions'][0]['trigger'], equals('ON_CLICK'));
        expect(decoded['interactions'][0]['actions'][0]['navigationType'],
            equals('NAVIGATE'));
        expect(decoded['interactions'][0]['actions'][0]['transition']['type'],
            equals('DISSOLVE'));
      });

      test('encodes and decodes BOOLEAN_OPERATION node', () {
        final boolOp = {
          'guid': {'sessionID': 1, 'localID': 1200},
          'type': 'BOOLEAN_OPERATION',
          'name': 'Union',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'NORMAL',
          'size': {'width': 100.0, 'height': 100.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
          'booleanOperation': 'UNION',
        };

        final encoded = encodeFigmaNodeChange(boolOp);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('BOOLEAN_OPERATION'));
        expect(decoded['booleanOperation'], equals('UNION'));
      });

      test('encodes and decodes SECTION node', () {
        final section = {
          'guid': {'sessionID': 1, 'localID': 1300},
          'type': 'SECTION',
          'name': 'Design Section',
          'visible': true,
          'opacity': 1.0,
          'blendMode': 'PASS_THROUGH',
          'size': {'width': 1000.0, 'height': 800.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 0.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 0.0
          },
        };

        final encoded = encodeFigmaNodeChange(section);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('SECTION'));
        expect(decoded['name'], equals('Design Section'));
      });

      test('encodes and decodes GROUP node', () {
        final group = {
          'guid': {'sessionID': 1, 'localID': 1400},
          'type': 'GROUP',
          'name': 'Icon Group',
          'visible': true,
          'opacity': 0.8,
          'blendMode': 'NORMAL',
          'size': {'width': 48.0, 'height': 48.0},
          'transform': {
            'm00': 1.0,
            'm01': 0.0,
            'm02': 100.0,
            'm10': 0.0,
            'm11': 1.0,
            'm12': 100.0
          },
        };

        final encoded = encodeFigmaNodeChange(group);
        final decoded = decodeFigmaNodeChange(encoded);

        expect(decoded['type'], equals('GROUP'));
        expect(decoded['opacity'], closeTo(0.8, 0.001));
      });
    });

    group('Message Encoding/Decoding', () {
      test('encodes and decodes empty Message', () {
        final message = {
          'nodeChanges': <Map<String, dynamic>>[],
          'blobs': <Map<String, dynamic>>[],
          'blobBaseIndex': 0,
        };

        final encoded = encodeFigmaMessage(message);
        final decoded = decodeFigmaMessage(encoded);

        expect(decoded['nodeChanges'], isEmpty);
        expect(decoded['blobs'], isEmpty);
        expect(decoded['blobBaseIndex'], equals(0));
      });

      test('encodes and decodes Message with multiple nodes', () {
        final message = {
          'nodeChanges': [
            {
              'guid': {'sessionID': 1, 'localID': 1},
              'type': 'FRAME',
              'name': 'Frame 1',
              'visible': true,
              'size': {'width': 100.0, 'height': 100.0},
              'transform': {
                'm00': 1.0,
                'm01': 0.0,
                'm02': 0.0,
                'm10': 0.0,
                'm11': 1.0,
                'm12': 0.0
              },
            },
            {
              'guid': {'sessionID': 1, 'localID': 2},
              'type': 'RECTANGLE',
              'name': 'Rectangle 1',
              'visible': true,
              'size': {'width': 50.0, 'height': 50.0},
              'transform': {
                'm00': 1.0,
                'm01': 0.0,
                'm02': 25.0,
                'm10': 0.0,
                'm11': 1.0,
                'm12': 25.0
              },
            },
          ],
          'blobs': <Map<String, dynamic>>[],
          'blobBaseIndex': 0,
        };

        final encoded = encodeFigmaMessage(message);
        final decoded = decodeFigmaMessage(encoded);

        expect(decoded['nodeChanges'], hasLength(2));
        expect(decoded['nodeChanges'][0]['type'], equals('FRAME'));
        expect(decoded['nodeChanges'][1]['type'], equals('RECTANGLE'));
      });
    });

    group('Enum Name Resolution', () {
      test('resolves NodeType names correctly', () {
        final names = figmaNodeTypeNames;
        expect(names[0], equals('NONE'));
        expect(names[3], equals('FRAME'));
        expect(names[10], equals('RECTANGLE'));
        expect(names[13], equals('TEXT'));
      });

      test('resolves BlendMode names correctly', () {
        final names = figmaBlendModeNames;
        expect(names[0], equals('PASS_THROUGH'));
        expect(names[1], equals('NORMAL'));
        expect(names[3], equals('MULTIPLY'));
      });

      test('resolves PaintType names correctly', () {
        final names = figmaPaintTypeNames;
        expect(names[0], equals('SOLID'));
        expect(names[1], equals('GRADIENT_LINEAR'));
        expect(names[5], equals('IMAGE'));
      });
    });

    group('Binary Schema Encoding', () {
      test('encodes Figma schema to binary and decodes back', () {
        final binarySchema = encodeBinarySchema(figmaSchema);
        expect(binarySchema, isNotEmpty);

        final decodedSchema = decodeBinarySchema(binarySchema);
        expect(decodedSchema.definitions.length,
            equals(figmaSchema.definitions.length));
      });

      test('pretty prints Figma schema', () {
        final printed = prettyPrintSchema(figmaSchema);
        expect(printed, contains('enum NodeType'));
        expect(printed, contains('enum BlendMode'));
        expect(printed, contains('struct Color'));
        expect(printed, contains('message Paint'));
        expect(printed, contains('message NodeChange'));
      });
    });
  });
}
