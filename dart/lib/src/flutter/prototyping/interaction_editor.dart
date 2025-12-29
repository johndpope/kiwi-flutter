// Interaction Editor Panel
// UI for creating and editing prototype interactions

import 'dart:math' show cos, sin;

import 'package:flutter/material.dart';
import 'interactions.dart';

/// Interaction editor panel
class InteractionEditorPanel extends StatefulWidget {
  final NodeInteractions? interactions;
  final List<String> availableNodeIds;
  final Map<String, String>? nodeNames;
  final void Function(NodeInteractions) onInteractionsChanged;

  const InteractionEditorPanel({
    super.key,
    this.interactions,
    required this.availableNodeIds,
    this.nodeNames,
    required this.onInteractionsChanged,
  });

  @override
  State<InteractionEditorPanel> createState() => _InteractionEditorPanelState();
}

class _InteractionEditorPanelState extends State<InteractionEditorPanel> {
  late NodeInteractions _interactions;

  @override
  void initState() {
    super.initState();
    _interactions = widget.interactions ??
        NodeInteractions(nodeId: UniqueKey().toString());
  }

  @override
  void didUpdateWidget(InteractionEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interactions != oldWidget.interactions) {
      _interactions = widget.interactions ??
          NodeInteractions(nodeId: UniqueKey().toString());
    }
  }

  void _updateInteractions(NodeInteractions interactions) {
    setState(() => _interactions = interactions);
    widget.onInteractionsChanged(interactions);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Interactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                  onPressed: _addInteraction,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.grey),

          // Interactions list
          Expanded(
            child: _interactions.interactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _interactions.interactions.length,
                    itemBuilder: (context, index) {
                      return _InteractionItem(
                        interaction: _interactions.interactions[index],
                        availableNodeIds: widget.availableNodeIds,
                        nodeNames: widget.nodeNames,
                        onUpdate: (updated) {
                          _updateInteractions(
                            _interactions.updateInteraction(updated),
                          );
                        },
                        onDelete: () {
                          _updateInteractions(
                            _interactions.removeInteraction(
                              _interactions.interactions[index].id,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, color: Colors.grey[600], size: 48),
          const SizedBox(height: 16),
          Text(
            'No interactions',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addInteraction,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add interaction'),
          ),
        ],
      ),
    );
  }

  void _addInteraction() {
    final newInteraction = Interaction(
      trigger: InteractionTrigger.onClick,
      action: InteractionAction.navigate,
    );
    _updateInteractions(_interactions.addInteraction(newInteraction));
  }
}

/// Single interaction item
class _InteractionItem extends StatefulWidget {
  final Interaction interaction;
  final List<String> availableNodeIds;
  final Map<String, String>? nodeNames;
  final void Function(Interaction) onUpdate;
  final VoidCallback onDelete;

  const _InteractionItem({
    required this.interaction,
    required this.availableNodeIds,
    this.nodeNames,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_InteractionItem> createState() => _InteractionItemState();
}

class _InteractionItemState extends State<_InteractionItem> {
  bool _isExpanded = false;

  String _getNodeName(String nodeId) {
    return widget.nodeNames?[nodeId] ?? nodeId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isExpanded ? Colors.blue : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _getTriggerIcon(widget.interaction.trigger),
                    color: Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.interaction.trigger.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getActionDescription(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trigger selector
                  _buildLabel('Trigger'),
                  _buildDropdown<InteractionTrigger>(
                    value: widget.interaction.trigger,
                    items: InteractionTrigger.values,
                    itemLabel: (t) => t.label,
                    onChanged: (trigger) {
                      widget.onUpdate(
                        widget.interaction.copyWith(trigger: trigger),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Action selector
                  _buildLabel('Action'),
                  _buildDropdown<InteractionAction>(
                    value: widget.interaction.action,
                    items: InteractionAction.values,
                    itemLabel: (a) => a.label,
                    onChanged: (action) {
                      widget.onUpdate(
                        widget.interaction.copyWith(action: action),
                      );
                    },
                  ),

                  // Destination selector (for navigate/overlay actions)
                  if (_needsDestination(widget.interaction.action)) ...[
                    const SizedBox(height: 12),
                    _buildLabel('Destination'),
                    _buildDropdown<String?>(
                      value: widget.interaction.destinationNodeId,
                      items: [null, ...widget.availableNodeIds],
                      itemLabel: (id) =>
                          id == null ? 'Select frame...' : _getNodeName(id),
                      onChanged: (nodeId) {
                        widget.onUpdate(
                          widget.interaction.copyWith(destinationNodeId: nodeId),
                        );
                      },
                    ),
                  ],

                  // Delay input (for afterDelay trigger)
                  if (widget.interaction.trigger ==
                      InteractionTrigger.afterDelay) ...[
                    const SizedBox(height: 12),
                    _buildLabel('Delay (ms)'),
                    _buildNumberInput(
                      value: widget.interaction.triggerDelay?.inMilliseconds ?? 1000,
                      onChanged: (ms) {
                        widget.onUpdate(
                          widget.interaction.copyWith(
                            triggerDelay: Duration(milliseconds: ms),
                          ),
                        );
                      },
                    ),
                  ],

                  // External link input
                  if (widget.interaction.action ==
                      InteractionAction.openLink) ...[
                    const SizedBox(height: 12),
                    _buildLabel('URL'),
                    _buildTextInput(
                      value: widget.interaction.externalLink ?? '',
                      hint: 'https://...',
                      onChanged: (url) {
                        widget.onUpdate(
                          widget.interaction.copyWith(externalLink: url),
                        );
                      },
                    ),
                  ],

                  // Transition settings
                  if (_supportsTransition(widget.interaction.action)) ...[
                    const SizedBox(height: 16),
                    _TransitionEditor(
                      transition: widget.interaction.transition,
                      onChanged: (transition) {
                        widget.onUpdate(
                          widget.interaction.copyWith(transition: transition),
                        );
                      },
                    ),
                  ],

                  // Overlay settings
                  if (widget.interaction.action ==
                      InteractionAction.openOverlay) ...[
                    const SizedBox(height: 16),
                    _OverlaySettingsEditor(
                      settings: widget.interaction.overlaySettings ??
                          const OverlaySettings(),
                      onChanged: (settings) {
                        widget.onUpdate(
                          widget.interaction.copyWith(overlaySettings: settings),
                        );
                      },
                    ),
                  ],

                  // Delete button
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[300],
                        side: BorderSide(color: Colors.red[300]!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getActionDescription() {
    final action = widget.interaction.action;
    final destination = widget.interaction.destinationNodeId;

    switch (action) {
      case InteractionAction.navigate:
      case InteractionAction.swap:
      case InteractionAction.openOverlay:
        if (destination != null) {
          return '${action.label} → ${_getNodeName(destination)}';
        }
        return action.label;
      case InteractionAction.openLink:
        return widget.interaction.externalLink ?? 'Open link';
      default:
        return action.label;
    }
  }

  IconData _getTriggerIcon(InteractionTrigger trigger) {
    switch (trigger) {
      case InteractionTrigger.onClick:
        return Icons.touch_app;
      case InteractionTrigger.onHover:
        return Icons.mouse;
      case InteractionTrigger.onPress:
        return Icons.pan_tool;
      case InteractionTrigger.onDrag:
        return Icons.swipe;
      case InteractionTrigger.afterDelay:
        return Icons.timer;
      case InteractionTrigger.mouseEnter:
        return Icons.login;
      case InteractionTrigger.mouseLeave:
        return Icons.logout;
      case InteractionTrigger.mouseDown:
        return Icons.mouse;
      case InteractionTrigger.mouseUp:
        return Icons.mouse;
      case InteractionTrigger.keyDown:
        return Icons.keyboard;
    }
  }

  bool _needsDestination(InteractionAction action) {
    return action == InteractionAction.navigate ||
        action == InteractionAction.swap ||
        action == InteractionAction.openOverlay ||
        action == InteractionAction.scrollTo;
  }

  bool _supportsTransition(InteractionAction action) {
    return action == InteractionAction.navigate ||
        action == InteractionAction.swap ||
        action == InteractionAction.openOverlay ||
        action == InteractionAction.closeOverlay ||
        action == InteractionAction.back;
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T) onChanged,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildNumberInput({
    required int value,
    required void Function(int) onChanged,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: TextEditingController(text: value.toString()),
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  Widget _buildTextInput({
    required String value,
    required String hint,
    required void Function(String) onChanged,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: TextEditingController(text: value),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Transition settings editor
class _TransitionEditor extends StatelessWidget {
  final TransitionConfig transition;
  final void Function(TransitionConfig) onChanged;

  const _TransitionEditor({
    required this.transition,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Animation',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Transition type
        _buildLabel('Type'),
        _buildDropdown<TransitionType>(
          value: transition.type,
          items: TransitionType.values,
          itemLabel: (t) => t.label,
          onChanged: (type) => onChanged(transition.copyWith(type: type)),
        ),

        // Direction (for directional transitions)
        if (_needsDirection(transition.type)) ...[
          const SizedBox(height: 8),
          _buildLabel('Direction'),
          _buildDropdown<TransitionDirection>(
            value: transition.direction,
            items: TransitionDirection.values,
            itemLabel: (d) => d.label,
            onChanged: (dir) => onChanged(transition.copyWith(direction: dir)),
          ),
        ],

        // Easing
        const SizedBox(height: 8),
        _buildLabel('Easing'),
        _buildDropdown<AnimationEasing>(
          value: transition.easing,
          items: AnimationEasing.values,
          itemLabel: (e) => e.label,
          onChanged: (easing) => onChanged(transition.copyWith(easing: easing)),
        ),

        // Duration
        const SizedBox(height: 8),
        _buildLabel('Duration (ms)'),
        _DurationSlider(
          value: transition.duration.inMilliseconds,
          onChanged: (ms) => onChanged(
            transition.copyWith(duration: Duration(milliseconds: ms)),
          ),
        ),
      ],
    );
  }

  bool _needsDirection(TransitionType type) {
    return type == TransitionType.moveIn ||
        type == TransitionType.moveOut ||
        type == TransitionType.push ||
        type == TransitionType.slideIn ||
        type == TransitionType.slideOut;
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[500], fontSize: 10),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T) onChanged,
  }) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Duration slider
class _DurationSlider extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;

  const _DurationSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.grey[700],
              thumbColor: Colors.blue,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 2000,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            style: const TextStyle(color: Colors.white, fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Overlay settings editor
class _OverlaySettingsEditor extends StatelessWidget {
  final OverlaySettings settings;
  final void Function(OverlaySettings) onChanged;

  const _OverlaySettingsEditor({
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overlay Settings',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Position
        _buildLabel('Position'),
        _buildDropdown<OverlayPosition>(
          value: settings.position,
          items: OverlayPosition.values,
          itemLabel: (p) => p.label,
          onChanged: (pos) => onChanged(settings.copyWith(position: pos)),
        ),

        const SizedBox(height: 8),

        // Close on click outside
        _buildCheckbox(
          'Close on click outside',
          settings.closeOnClickOutside,
          (v) => onChanged(settings.copyWith(closeOnClickOutside: v)),
        ),

        _buildCheckbox(
          'Add background behind',
          settings.addBackgroundBehind,
          (v) => onChanged(settings.copyWith(addBackgroundBehind: v)),
        ),

        // Background opacity
        if (settings.addBackgroundBehind) ...[
          const SizedBox(height: 8),
          _buildLabel('Background opacity'),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.grey[700],
              thumbColor: Colors.blue,
            ),
            child: Slider(
              value: settings.backgroundOpacity,
              min: 0,
              max: 1,
              onChanged: (v) => onChanged(settings.copyWith(backgroundOpacity: v)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[500], fontSize: 10),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T) onChanged,
  }) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, void Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
      ],
    );
  }
}

/// Flow connection visualizer (shows connections between frames)
class FlowConnectionPainter extends CustomPainter {
  final List<FlowConnection> connections;
  final Color connectionColor;
  final double strokeWidth;

  FlowConnectionPainter({
    required this.connections,
    this.connectionColor = Colors.blue,
    this.strokeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = connectionColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = connectionColor
      ..style = PaintingStyle.fill;

    for (final connection in connections) {
      // Draw line
      final path = Path();
      path.moveTo(connection.start.dx, connection.start.dy);

      // Curved line
      final controlPoint1 = Offset(
        connection.start.dx + (connection.end.dx - connection.start.dx) * 0.5,
        connection.start.dy,
      );
      final controlPoint2 = Offset(
        connection.start.dx + (connection.end.dx - connection.start.dx) * 0.5,
        connection.end.dy,
      );

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        connection.end.dx,
        connection.end.dy,
      );

      canvas.drawPath(path, paint);

      // Draw arrow
      _drawArrow(
        canvas,
        connection.end,
        connection.start,
        arrowPaint,
      );
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset from, Paint paint) {
    final direction = (tip - from).direction;
    const arrowSize = 8.0;

    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(
      tip.dx - arrowSize * cos(direction - 0.5),
      tip.dy - arrowSize * sin(direction - 0.5),
    );
    path.lineTo(
      tip.dx - arrowSize * cos(direction + 0.5),
      tip.dy - arrowSize * sin(direction + 0.5),
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FlowConnectionPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        connectionColor != oldDelegate.connectionColor;
  }
}

/// Single flow connection
class FlowConnection {
  final String fromNodeId;
  final String toNodeId;
  final Offset start;
  final Offset end;
  final InteractionTrigger trigger;

  const FlowConnection({
    required this.fromNodeId,
    required this.toNodeId,
    required this.start,
    required this.end,
    required this.trigger,
  });
}
