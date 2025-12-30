/// Figma Design Panel
///
/// Complete Design/Prototype panel matching Figma's right-hand panel.

import 'package:flutter/material.dart';
import 'design_panel_colors.dart';
import 'sections/tab_switcher.dart';
import 'sections/opacity_radius_row.dart';
import 'sections/fill_section.dart';
import 'sections/stroke_section.dart';
import 'sections/effects_section.dart';
import 'sections/selection_colors.dart';
import 'sections/layout_guide.dart';
import 'sections/export_section.dart';
import 'sections/preview_section.dart';

/// Figma Design Panel widget
class FigmaDesignPanel extends StatefulWidget {
  /// The selected node data
  final Map<String, dynamic>? node;

  /// Current zoom level (0.25 - 4.0)
  final double zoomLevel;

  /// Callback when any property changes
  final void Function(String path, dynamic value)? onPropertyChanged;

  /// Callback when tab changes
  final void Function(DesignPanelTab tab)? onTabChanged;

  /// Callback when zoom changes
  final ValueChanged<double>? onZoomChanged;

  /// Callback when export is requested
  final VoidCallback? onExport;

  /// Callback when help is requested
  final VoidCallback? onHelp;

  /// Panel width
  final double width;

  const FigmaDesignPanel({
    super.key,
    this.node,
    this.zoomLevel = 1.0,
    this.onPropertyChanged,
    this.onTabChanged,
    this.onZoomChanged,
    this.onExport,
    this.onHelp,
    this.width = DesignPanelDimensions.panelWidth,
  });

  @override
  State<FigmaDesignPanel> createState() => _FigmaDesignPanelState();
}

class _FigmaDesignPanelState extends State<FigmaDesignPanel> {
  DesignPanelTab _activeTab = DesignPanelTab.design;

  // Section expansion states
  bool _fillExpanded = true;
  bool _strokeExpanded = true;
  bool _effectsExpanded = true;
  bool _selectionColorsExpanded = false;
  bool _layoutGuideExpanded = true;
  bool _exportExpanded = true;
  bool _previewExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignPanelColors.bg2,
      child: Container(
        width: widget.width,
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: DesignPanelColors.border, width: 1),
          ),
        ),
      child: Column(
        children: [
          // Tab switcher
          TabSwitcher(
            activeTab: _activeTab,
            onTabChanged: (tab) {
              setState(() => _activeTab = tab);
              widget.onTabChanged?.call(tab);
            },
            zoomLevel: widget.zoomLevel,
            onZoomChanged: widget.onZoomChanged,
          ),

          // Content
          Expanded(
            child: _activeTab == DesignPanelTab.design
                ? _buildDesignTab()
                : _buildPrototypeTab(),
          ),

          // Help button
          HelpButton(onTap: widget.onHelp),
        ],
      ),
      ),
    );
  }

  Widget _buildDesignTab() {
    final node = widget.node ?? {};

    // Extract properties
    final opacity = (node['opacity'] as num?)?.toDouble() ?? 1.0;
    final cornerRadius = _extractCornerRadius(node);
    final individualCorners = _extractIndividualCorners(node);
    final fills = _extractFills(node);
    final strokes = _extractStrokes(node);
    final strokeWeight = (node['strokeWeight'] as num?)?.toDouble() ?? 1.0;
    final strokeAlign = node['strokeAlign'] as String? ?? 'INSIDE';
    final effects = _extractEffects(node);
    final layoutGuides = _extractLayoutGuides(node);
    final exports = _extractExports(node);

    return ListView(
      children: [
        // Opacity and corner radius row
        OpacityRadiusRow(
          opacity: opacity,
          cornerRadius: cornerRadius,
          individualCorners: individualCorners,
          onOpacityChanged: (v) => _onPropertyChanged('opacity', v),
          onCornerRadiusChanged: (v) => _onPropertyChanged('cornerRadius', v),
          onIndividualCornersChanged: (v) =>
              _onPropertyChanged('rectangleCornerRadii', v),
        ),

        // Fill section
        FillSection(
          fills: fills,
          expanded: _fillExpanded,
          onToggle: () => setState(() => _fillExpanded = !_fillExpanded),
          onAdd: () => _addFill(),
          onFillChanged: (index, changes) => _updateFill(index, changes),
          onRemove: (index) => _removeFill(index),
          onToggleVisibility: (index) => _toggleFillVisibility(index),
          onColorTap: (index) => _openFillColorPicker(index),
        ),

        // Stroke section
        StrokeSection(
          strokes: strokes,
          strokeWeight: strokeWeight,
          strokeAlign: strokeAlign,
          expanded: _strokeExpanded,
          onToggle: () => setState(() => _strokeExpanded = !_strokeExpanded),
          onAdd: () => _addStroke(),
          onAdvancedSettings: () => _openAdvancedStroke(),
          onStrokeChanged: (index, changes) => _updateStroke(index, changes),
          onRemove: (index) => _removeStroke(index),
          onToggleVisibility: (index) => _toggleStrokeVisibility(index),
          onColorTap: (index) => _openStrokeColorPicker(index),
          onWeightChanged: (v) => _onPropertyChanged('strokeWeight', v),
          onAlignChanged: (v) => _onPropertyChanged('strokeAlign', v),
        ),

        // Effects section
        EffectsSection(
          effects: effects,
          expanded: _effectsExpanded,
          onToggle: () => setState(() => _effectsExpanded = !_effectsExpanded),
          onAdd: () => _addEffect(),
          onEffectChanged: (index, changes) => _updateEffect(index, changes),
          onRemove: (index) => _removeEffect(index),
          onToggleVisibility: (index) => _toggleEffectVisibility(index),
          onToggleEnabled: (index) => _toggleEffectEnabled(index),
          onEditEffect: (index) => _openEffectEditor(index),
        ),

        // Selection colors section
        SelectionColorsSection(
          expanded: _selectionColorsExpanded,
          onToggle: () =>
              setState(() => _selectionColorsExpanded = !_selectionColorsExpanded),
          onShowSelectionColors: () => _showSelectionColors(),
          selectionColors: _extractSelectionColors(node),
        ),

        // Layout guide section
        LayoutGuideSection(
          guides: layoutGuides,
          expanded: _layoutGuideExpanded,
          onToggle: () =>
              setState(() => _layoutGuideExpanded = !_layoutGuideExpanded),
          onAdd: () => _addLayoutGuide(),
          onGuideChanged: (index, changes) => _updateLayoutGuide(index, changes),
          onRemove: (index) => _removeLayoutGuide(index),
          onToggleVisibility: (index) => _toggleLayoutGuideVisibility(index),
        ),

        // Export section
        ExportSection(
          exports: exports,
          expanded: _exportExpanded,
          onToggle: () => setState(() => _exportExpanded = !_exportExpanded),
          onAdd: () => _addExport(),
          onExportChanged: (index, changes) => _updateExport(index, changes),
          onRemove: (index) => _removeExport(index),
          onExportContent: widget.onExport,
        ),

        // Preview section (collapsed by default)
        PreviewSection(
          expanded: _previewExpanded,
          onToggle: () => setState(() => _previewExpanded = !_previewExpanded),
          componentName: node['name'] as String?,
        ),

        const SizedBox(height: DesignPanelSpacing.lg),
      ],
    );
  }

  Widget _buildPrototypeTab() {
    // Prototype tab content - interactions, flows, etc.
    return ListView(
      padding: const EdgeInsets.all(DesignPanelSpacing.panelPadding),
      children: [
        const Text(
          'Prototype',
          style: TextStyle(
            color: DesignPanelColors.text1,
            fontSize: DesignPanelTypography.fontSizeLg,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: DesignPanelSpacing.md),
        Container(
          padding: const EdgeInsets.all(DesignPanelSpacing.md),
          decoration: BoxDecoration(
            color: DesignPanelColors.bg1,
            borderRadius: BorderRadius.circular(DesignPanelDimensions.borderRadius),
            border: Border.all(color: DesignPanelColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interactions',
                style: DesignPanelTypography.labelStyle,
              ),
              SizedBox(height: DesignPanelSpacing.sm),
              Text(
                'No interactions defined',
                style: TextStyle(
                  color: DesignPanelColors.text3,
                  fontSize: DesignPanelTypography.fontSizeSm,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods for extracting data
  double _extractCornerRadius(Map<String, dynamic> node) {
    if (node['cornerRadius'] != null) {
      return (node['cornerRadius'] as num).toDouble();
    }
    final radii = node['rectangleCornerRadii'] as List?;
    if (radii != null && radii.isNotEmpty) {
      return (radii.first as num).toDouble();
    }
    return 0;
  }

  List<double>? _extractIndividualCorners(Map<String, dynamic> node) {
    final radii = node['rectangleCornerRadii'] as List?;
    if (radii == null) return null;
    return radii.map((r) => (r as num).toDouble()).toList();
  }

  List<Map<String, dynamic>> _extractFills(Map<String, dynamic> node) {
    final fills = node['fillPaints'] ?? node['fills'];
    if (fills is List) {
      return fills.cast<Map<String, dynamic>>();
    }
    return [];
  }

  List<Map<String, dynamic>> _extractStrokes(Map<String, dynamic> node) {
    final strokes = node['strokePaints'] ?? node['strokes'];
    if (strokes is List) {
      return strokes.cast<Map<String, dynamic>>();
    }
    return [];
  }

  List<Map<String, dynamic>> _extractEffects(Map<String, dynamic> node) {
    final effects = node['effects'];
    if (effects is List) {
      return effects.cast<Map<String, dynamic>>();
    }
    return [];
  }

  List<Map<String, dynamic>> _extractLayoutGuides(Map<String, dynamic> node) {
    final guides = node['layoutGrids'];
    if (guides is List) {
      return guides.cast<Map<String, dynamic>>();
    }
    return [];
  }

  List<Map<String, dynamic>> _extractExports(Map<String, dynamic> node) {
    final exports = node['exportSettings'];
    if (exports is List) {
      return exports.cast<Map<String, dynamic>>();
    }
    return [];
  }

  List<Color>? _extractSelectionColors(Map<String, dynamic> node) {
    final colors = <Color>[];

    // Extract colors from fills
    for (final fill in _extractFills(node)) {
      final c = fill['color'] as Map<String, dynamic>?;
      if (c != null && fill['type'] == 'SOLID') {
        colors.add(Color.fromRGBO(
          ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          (c['a'] as num?)?.toDouble() ?? 1.0,
        ));
      }
    }

    // Extract colors from strokes
    for (final stroke in _extractStrokes(node)) {
      final c = stroke['color'] as Map<String, dynamic>?;
      if (c != null && stroke['type'] == 'SOLID') {
        colors.add(Color.fromRGBO(
          ((c['r'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['g'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          ((c['b'] as num?)?.toDouble() ?? 0) * 255 ~/ 1,
          (c['a'] as num?)?.toDouble() ?? 1.0,
        ));
      }
    }

    return colors.isNotEmpty ? colors : null;
  }

  // Property change handler
  void _onPropertyChanged(String path, dynamic value) {
    widget.onPropertyChanged?.call(path, value);
  }

  // Fill operations
  void _addFill() {
    _onPropertyChanged('fills.add', {
      'type': 'SOLID',
      'color': {'r': 1, 'g': 1, 'b': 1, 'a': 1},
      'visible': true,
      'opacity': 1.0,
    });
  }

  void _updateFill(int index, Map<String, dynamic> changes) {
    _onPropertyChanged('fills.$index', changes);
  }

  void _removeFill(int index) {
    _onPropertyChanged('fills.remove', index);
  }

  void _toggleFillVisibility(int index) {
    _onPropertyChanged('fills.$index.visible', null); // Toggle
  }

  void _openFillColorPicker(int index) {
    // Open color picker for fill at index
  }

  // Stroke operations
  void _addStroke() {
    _onPropertyChanged('strokes.add', {
      'type': 'SOLID',
      'color': {'r': 0, 'g': 0, 'b': 0, 'a': 1},
      'visible': true,
      'opacity': 1.0,
    });
  }

  void _updateStroke(int index, Map<String, dynamic> changes) {
    _onPropertyChanged('strokes.$index', changes);
  }

  void _removeStroke(int index) {
    _onPropertyChanged('strokes.remove', index);
  }

  void _toggleStrokeVisibility(int index) {
    _onPropertyChanged('strokes.$index.visible', null); // Toggle
  }

  void _openStrokeColorPicker(int index) {
    // Open color picker for stroke at index
  }

  void _openAdvancedStroke() {
    // Open advanced stroke settings dialog
  }

  // Effect operations
  void _addEffect() {
    _onPropertyChanged('effects.add', {
      'type': 'DROP_SHADOW',
      'visible': true,
      'enabled': true,
      'color': {'r': 0, 'g': 0, 'b': 0, 'a': 0.25},
      'offset': {'x': 0, 'y': 4},
      'radius': 4,
      'spread': 0,
    });
  }

  void _updateEffect(int index, Map<String, dynamic> changes) {
    _onPropertyChanged('effects.$index', changes);
  }

  void _removeEffect(int index) {
    _onPropertyChanged('effects.remove', index);
  }

  void _toggleEffectVisibility(int index) {
    _onPropertyChanged('effects.$index.visible', null); // Toggle
  }

  void _toggleEffectEnabled(int index) {
    _onPropertyChanged('effects.$index.enabled', null); // Toggle
  }

  void _openEffectEditor(int index) {
    // Open detailed effect editor
  }

  // Selection colors
  void _showSelectionColors() {
    // Show selection colors overlay
  }

  // Layout guide operations
  void _addLayoutGuide() {
    _onPropertyChanged('layoutGrids.add', {
      'type': 'GRID',
      'size': 10,
      'visible': true,
      'color': {'r': 1, 'g': 0, 'b': 0, 'a': 0.1},
    });
  }

  void _updateLayoutGuide(int index, Map<String, dynamic> changes) {
    _onPropertyChanged('layoutGrids.$index', changes);
  }

  void _removeLayoutGuide(int index) {
    _onPropertyChanged('layoutGrids.remove', index);
  }

  void _toggleLayoutGuideVisibility(int index) {
    _onPropertyChanged('layoutGrids.$index.visible', null); // Toggle
  }

  // Export operations
  void _addExport() {
    _onPropertyChanged('exportSettings.add', {
      'format': 'PNG',
      'scale': 1.0,
      'suffix': '',
    });
  }

  void _updateExport(int index, Map<String, dynamic> changes) {
    _onPropertyChanged('exportSettings.$index', changes);
  }

  void _removeExport(int index) {
    _onPropertyChanged('exportSettings.remove', index);
  }
}
