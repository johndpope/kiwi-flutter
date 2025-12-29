import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/src/flutter/rendering/paint_renderer.dart';
import 'package:kiwi_schema/src/flutter/rendering/effect_renderer.dart';
import 'package:kiwi_schema/src/flutter/rendering/blend_modes.dart';

void main() {
  group('PaintRenderer', () {
    group('buildColor', () {
      test('returns null for null data', () {
        expect(PaintRenderer.buildColor(null), isNull);
      });

      test('builds color from RGBA values', () {
        final color = PaintRenderer.buildColor({
          'r': 1.0,
          'g': 0.5,
          'b': 0.0,
          'a': 0.8,
        });
        expect(color, isNotNull);
        expect(color!.red, 255);
        expect(color.green, 128);
        expect(color.blue, 0);
        expect(color.alpha, 204); // 0.8 * 255
      });

      test('applies opacity multiplier', () {
        final color = PaintRenderer.buildColor({
          'r': 1.0,
          'g': 1.0,
          'b': 1.0,
          'a': 1.0,
        }, 0.5);
        expect(color!.alpha, 128); // 0.5 * 255
      });

      test('handles missing alpha', () {
        final color = PaintRenderer.buildColor({
          'r': 1.0,
          'g': 0.0,
          'b': 0.0,
        });
        expect(color!.alpha, 255); // Default to 1.0
      });
    });

    group('buildGradient', () {
      test('returns null for null paint', () {
        expect(PaintRenderer.buildGradient({}, const Size(100, 100)), isNull);
      });

      test('builds linear gradient', () {
        final gradient = PaintRenderer.buildGradient({
          'type': 'GRADIENT_LINEAR',
          'gradientHandlePositions': [
            {'x': 0.0, 'y': 0.0},
            {'x': 1.0, 'y': 1.0},
          ],
          'gradientStops': [
            {'position': 0.0, 'color': {'r': 1.0, 'g': 0.0, 'b': 0.0, 'a': 1.0}},
            {'position': 1.0, 'color': {'r': 0.0, 'g': 0.0, 'b': 1.0, 'a': 1.0}},
          ],
        }, const Size(100, 100));

        expect(gradient, isA<LinearGradient>());
      });

      test('builds radial gradient', () {
        final gradient = PaintRenderer.buildGradient({
          'type': 'GRADIENT_RADIAL',
          'gradientHandlePositions': [
            {'x': 0.5, 'y': 0.5},
            {'x': 1.0, 'y': 0.5},
          ],
          'gradientStops': [
            {'position': 0.0, 'color': {'r': 1.0, 'g': 1.0, 'b': 0.0, 'a': 1.0}},
            {'position': 1.0, 'color': {'r': 0.0, 'g': 1.0, 'b': 0.0, 'a': 1.0}},
          ],
        }, const Size(100, 100));

        expect(gradient, isA<RadialGradient>());
      });

      test('builds angular gradient', () {
        final gradient = PaintRenderer.buildGradient({
          'type': 'GRADIENT_ANGULAR',
          'gradientHandlePositions': [
            {'x': 0.5, 'y': 0.5},
            {'x': 1.0, 'y': 0.5},
          ],
          'gradientStops': [
            {'position': 0.0, 'color': {'r': 1.0, 'g': 0.0, 'b': 1.0, 'a': 1.0}},
            {'position': 1.0, 'color': {'r': 0.0, 'g': 1.0, 'b': 1.0, 'a': 1.0}},
          ],
        }, const Size(100, 100));

        expect(gradient, isA<SweepGradient>());
      });
    });

    group('buildDecoration', () {
      test('returns empty decoration for empty fills', () {
        final decoration = PaintRenderer.buildDecoration(
          fills: [],
          size: const Size(100, 100),
        );
        expect(decoration, isA<BoxDecoration>());
      });

      test('builds decoration with solid color', () {
        final decoration = PaintRenderer.buildDecoration(
          fills: [
            {
              'type': 'SOLID',
              'visible': true,
              'color': {'r': 1.0, 'g': 0.0, 'b': 0.0, 'a': 1.0},
            }
          ],
          size: const Size(100, 100),
        );
        expect(decoration.color, isNotNull);
        expect(decoration.color!.red, 255);
      });

      test('builds decoration with border radius', () {
        final decoration = PaintRenderer.buildDecoration(
          fills: [],
          size: const Size(100, 100),
          borderRadius: BorderRadius.circular(10),
        );
        expect(decoration.borderRadius, isNotNull);
      });

      test('ignores invisible fills', () {
        final decoration = PaintRenderer.buildDecoration(
          fills: [
            {
              'type': 'SOLID',
              'visible': false,
              'color': {'r': 1.0, 'g': 0.0, 'b': 0.0, 'a': 1.0},
            }
          ],
          size: const Size(100, 100),
        );
        expect(decoration.color, isNull);
      });
    });

  });

  group('EffectRenderer', () {
    group('buildBoxShadows', () {
      test('returns empty list for empty effects', () {
        final shadows = EffectRenderer.buildBoxShadows([]);
        expect(shadows, isEmpty);
      });

      test('builds drop shadow', () {
        final shadows = EffectRenderer.buildBoxShadows([
          {
            'type': 'DROP_SHADOW',
            'visible': true,
            'color': {'r': 0.0, 'g': 0.0, 'b': 0.0, 'a': 0.5},
            'offset': {'x': 4.0, 'y': 4.0},
            'radius': 8.0,
            'spread': 0.0,
          }
        ]);

        expect(shadows.length, 1);
        expect(shadows[0].offset, const Offset(4, 4));
        expect(shadows[0].blurRadius, 8.0);
      });

      test('ignores invisible effects', () {
        final shadows = EffectRenderer.buildBoxShadows([
          {
            'type': 'DROP_SHADOW',
            'visible': false,
            'color': {'r': 0.0, 'g': 0.0, 'b': 0.0, 'a': 0.5},
          }
        ]);
        expect(shadows, isEmpty);
      });

      test('skips inner shadows in box shadow list', () {
        final shadows = EffectRenderer.buildBoxShadows([
          {
            'type': 'INNER_SHADOW',
            'visible': true,
            'color': {'r': 0.0, 'g': 0.0, 'b': 0.0, 'a': 0.5},
          }
        ]);
        expect(shadows, isEmpty); // Inner shadows handled separately
      });
    });

    group('hasBlur', () {
      test('returns true for layer blur', () {
        expect(
          EffectRenderer.hasBlur([
            {'type': 'LAYER_BLUR', 'visible': true, 'radius': 10.0}
          ]),
          true,
        );
      });

      test('returns true for background blur', () {
        expect(
          EffectRenderer.hasBlur([
            {'type': 'BACKGROUND_BLUR', 'visible': true, 'radius': 10.0}
          ]),
          true,
        );
      });

      test('returns false for invisible blur', () {
        expect(
          EffectRenderer.hasBlur([
            {'type': 'LAYER_BLUR', 'visible': false, 'radius': 10.0}
          ]),
          false,
        );
      });

      test('returns false for non-blur effects', () {
        expect(
          EffectRenderer.hasBlur([
            {'type': 'DROP_SHADOW', 'visible': true}
          ]),
          false,
        );
      });
    });

    group('hasInnerShadow', () {
      test('returns true for visible inner shadow', () {
        expect(
          EffectRenderer.hasInnerShadow([
            {'type': 'INNER_SHADOW', 'visible': true}
          ]),
          true,
        );
      });

      test('returns false for invisible inner shadow', () {
        expect(
          EffectRenderer.hasInnerShadow([
            {'type': 'INNER_SHADOW', 'visible': false}
          ]),
          false,
        );
      });
    });

    group('getBlurRadius', () {
      test('returns radius for layer blur', () {
        final radius = EffectRenderer.getBlurRadius([
          {'type': 'LAYER_BLUR', 'visible': true, 'radius': 15.0}
        ]);
        expect(radius, 15.0);
      });

      test('returns null when no blur', () {
        final radius = EffectRenderer.getBlurRadius([
          {'type': 'DROP_SHADOW', 'visible': true}
        ]);
        expect(radius, isNull);
      });
    });

    group('getBackgroundBlurRadius', () {
      test('returns radius for background blur only', () {
        final radius = EffectRenderer.getBackgroundBlurRadius([
          {'type': 'LAYER_BLUR', 'visible': true, 'radius': 10.0},
          {'type': 'BACKGROUND_BLUR', 'visible': true, 'radius': 20.0},
        ]);
        expect(radius, 20.0);
      });
    });

    group('buildBlurFilter', () {
      test('returns filter for blur effect', () {
        final filter = EffectRenderer.buildBlurFilter([
          {'type': 'LAYER_BLUR', 'visible': true, 'radius': 5.0}
        ]);
        expect(filter, isNotNull);
      });

      test('returns null for no blur', () {
        final filter = EffectRenderer.buildBlurFilter([]);
        expect(filter, isNull);
      });

      test('returns null for zero radius', () {
        final filter = EffectRenderer.buildBlurFilter([
          {'type': 'LAYER_BLUR', 'visible': true, 'radius': 0.0}
        ]);
        expect(filter, isNull);
      });
    });
  });

  group('BlendModes', () {
    group('figmaToFlutterBlendMode', () {
      test('returns srcOver for null', () {
        expect(figmaToFlutterBlendMode(null), BlendMode.srcOver);
      });

      test('maps NORMAL to srcOver', () {
        expect(figmaToFlutterBlendMode('NORMAL'), BlendMode.srcOver);
      });

      test('maps PASS_THROUGH to srcOver', () {
        expect(figmaToFlutterBlendMode('PASS_THROUGH'), BlendMode.srcOver);
      });

      test('maps MULTIPLY', () {
        expect(figmaToFlutterBlendMode('MULTIPLY'), BlendMode.multiply);
      });

      test('maps SCREEN', () {
        expect(figmaToFlutterBlendMode('SCREEN'), BlendMode.screen);
      });

      test('maps OVERLAY', () {
        expect(figmaToFlutterBlendMode('OVERLAY'), BlendMode.overlay);
      });

      test('maps DARKEN', () {
        expect(figmaToFlutterBlendMode('DARKEN'), BlendMode.darken);
      });

      test('maps LIGHTEN', () {
        expect(figmaToFlutterBlendMode('LIGHTEN'), BlendMode.lighten);
      });

      test('maps COLOR_DODGE', () {
        expect(figmaToFlutterBlendMode('COLOR_DODGE'), BlendMode.colorDodge);
      });

      test('maps COLOR_BURN', () {
        expect(figmaToFlutterBlendMode('COLOR_BURN'), BlendMode.colorBurn);
      });

      test('maps HARD_LIGHT', () {
        expect(figmaToFlutterBlendMode('HARD_LIGHT'), BlendMode.hardLight);
      });

      test('maps SOFT_LIGHT', () {
        expect(figmaToFlutterBlendMode('SOFT_LIGHT'), BlendMode.softLight);
      });

      test('maps DIFFERENCE', () {
        expect(figmaToFlutterBlendMode('DIFFERENCE'), BlendMode.difference);
      });

      test('maps EXCLUSION', () {
        expect(figmaToFlutterBlendMode('EXCLUSION'), BlendMode.exclusion);
      });

      test('maps HUE', () {
        expect(figmaToFlutterBlendMode('HUE'), BlendMode.hue);
      });

      test('maps SATURATION', () {
        expect(figmaToFlutterBlendMode('SATURATION'), BlendMode.saturation);
      });

      test('maps COLOR', () {
        expect(figmaToFlutterBlendMode('COLOR'), BlendMode.color);
      });

      test('maps LUMINOSITY', () {
        expect(figmaToFlutterBlendMode('LUMINOSITY'), BlendMode.luminosity);
      });

      test('maps LINEAR_DODGE to plus', () {
        expect(figmaToFlutterBlendMode('LINEAR_DODGE'), BlendMode.plus);
      });

      test('returns srcOver for unknown', () {
        expect(figmaToFlutterBlendMode('UNKNOWN'), BlendMode.srcOver);
      });
    });

    group('figmaBlendModeIndexToFlutter', () {
      test('returns srcOver for null', () {
        expect(figmaBlendModeIndexToFlutter(null), BlendMode.srcOver);
      });

      test('maps index 0 to srcOver (PASS_THROUGH)', () {
        expect(figmaBlendModeIndexToFlutter(0), BlendMode.srcOver);
      });

      test('maps index 1 to srcOver (NORMAL)', () {
        expect(figmaBlendModeIndexToFlutter(1), BlendMode.srcOver);
      });

      test('maps index 3 to multiply (MULTIPLY)', () {
        expect(figmaBlendModeIndexToFlutter(3), BlendMode.multiply);
      });

      test('maps index 6 to screen (SCREEN)', () {
        expect(figmaBlendModeIndexToFlutter(6), BlendMode.screen);
      });

      test('returns srcOver for out of range', () {
        expect(figmaBlendModeIndexToFlutter(100), BlendMode.srcOver);
      });
    });

    group('getBlendModeFromData', () {
      test('returns srcOver for null data', () {
        expect(getBlendModeFromData(null), BlendMode.srcOver);
      });

      test('handles string blend mode', () {
        expect(
          getBlendModeFromData({'blendMode': 'MULTIPLY'}),
          BlendMode.multiply,
        );
      });

      test('handles integer blend mode', () {
        expect(
          getBlendModeFromData({'blendMode': 3}),
          BlendMode.multiply,
        );
      });

      test('returns srcOver for missing blendMode', () {
        expect(
          getBlendModeFromData({'otherField': 'value'}),
          BlendMode.srcOver,
        );
      });
    });
  });
}
