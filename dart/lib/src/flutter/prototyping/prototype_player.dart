// Prototype Player - Runtime for playing interactive prototypes
// Handles navigation, transitions, overlays, and interaction state

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'interactions.dart';

/// Navigation history entry
class NavigationEntry {
  final String nodeId;
  final DateTime timestamp;
  final TransitionConfig? transition;

  const NavigationEntry({
    required this.nodeId,
    required this.timestamp,
    this.transition,
  });
}

/// Overlay state
class OverlayState {
  final String nodeId;
  final OverlaySettings settings;
  final TransitionConfig transition;

  const OverlayState({
    required this.nodeId,
    required this.settings,
    required this.transition,
  });
}

/// Prototype player state
class PrototypeState {
  final String currentNodeId;
  final List<NavigationEntry> history;
  final List<OverlayState> overlays;
  final Map<String, Offset> scrollPositions;
  final Map<String, dynamic> variables;
  final bool isPlaying;

  const PrototypeState({
    required this.currentNodeId,
    this.history = const [],
    this.overlays = const [],
    this.scrollPositions = const {},
    this.variables = const {},
    this.isPlaying = true,
  });

  PrototypeState copyWith({
    String? currentNodeId,
    List<NavigationEntry>? history,
    List<OverlayState>? overlays,
    Map<String, Offset>? scrollPositions,
    Map<String, dynamic>? variables,
    bool? isPlaying,
  }) {
    return PrototypeState(
      currentNodeId: currentNodeId ?? this.currentNodeId,
      history: history ?? this.history,
      overlays: overlays ?? this.overlays,
      scrollPositions: scrollPositions ?? this.scrollPositions,
      variables: variables ?? this.variables,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  bool get canGoBack => history.length > 1;

  String? get previousNodeId {
    if (history.length < 2) return null;
    return history[history.length - 2].nodeId;
  }
}

/// Callback types for prototype events
typedef OnNavigateCallback = void Function(String nodeId, TransitionConfig transition);
typedef OnOverlayCallback = void Function(OverlayState overlay);
typedef OnVariableChangeCallback = void Function(String key, dynamic value);
typedef OnExternalLinkCallback = void Function(String url);

/// Prototype player controller
class PrototypePlayerController extends ChangeNotifier {
  PrototypeState _state;
  final Map<String, NodeInteractions> _nodeInteractions;
  final Map<String, Widget Function(BuildContext)> _nodeBuilders;

  OnNavigateCallback? onNavigate;
  OnOverlayCallback? onOpenOverlay;
  OnOverlayCallback? onCloseOverlay;
  OnVariableChangeCallback? onVariableChange;
  OnExternalLinkCallback? onExternalLink;

  final Map<String, Timer> _delayTimers = {};

  PrototypePlayerController({
    required String startingNodeId,
    Map<String, NodeInteractions>? nodeInteractions,
    Map<String, Widget Function(BuildContext)>? nodeBuilders,
  })  : _state = PrototypeState(
          currentNodeId: startingNodeId,
          history: [
            NavigationEntry(
              nodeId: startingNodeId,
              timestamp: DateTime.now(),
            ),
          ],
        ),
        _nodeInteractions = nodeInteractions ?? {},
        _nodeBuilders = nodeBuilders ?? {};

  PrototypeState get state => _state;
  String get currentNodeId => _state.currentNodeId;
  bool get canGoBack => _state.canGoBack;
  List<OverlayState> get overlays => _state.overlays;
  bool get hasOverlays => _state.overlays.isNotEmpty;

  /// Register interactions for a node
  void registerInteractions(String nodeId, NodeInteractions interactions) {
    _nodeInteractions[nodeId] = interactions;
  }

  /// Register a node builder
  void registerNodeBuilder(String nodeId, Widget Function(BuildContext) builder) {
    _nodeBuilders[nodeId] = builder;
  }

  /// Get node builder
  Widget Function(BuildContext)? getNodeBuilder(String nodeId) {
    return _nodeBuilders[nodeId];
  }

  /// Get interactions for a node
  NodeInteractions? getInteractions(String nodeId) {
    return _nodeInteractions[nodeId];
  }

  /// Handle an interaction trigger
  void handleTrigger(String nodeId, InteractionTrigger trigger) {
    final interactions = _nodeInteractions[nodeId];
    if (interactions == null) return;

    final matchingInteractions = interactions.getInteractionsByTrigger(trigger);
    for (final interaction in matchingInteractions) {
      _executeInteraction(interaction);
    }
  }

  /// Execute a specific interaction
  void _executeInteraction(Interaction interaction) {
    switch (interaction.action) {
      case InteractionAction.navigate:
        if (interaction.destinationNodeId != null) {
          navigateTo(
            interaction.destinationNodeId!,
            transition: interaction.transition,
          );
        }
        break;

      case InteractionAction.openOverlay:
        if (interaction.destinationNodeId != null) {
          openOverlay(
            interaction.destinationNodeId!,
            settings: interaction.overlaySettings ?? const OverlaySettings(),
            transition: interaction.transition,
          );
        }
        break;

      case InteractionAction.closeOverlay:
        closeTopOverlay(transition: interaction.transition);
        break;

      case InteractionAction.swap:
        if (interaction.destinationNodeId != null) {
          swapTo(
            interaction.destinationNodeId!,
            transition: interaction.transition,
          );
        }
        break;

      case InteractionAction.back:
        goBack(transition: interaction.transition);
        break;

      case InteractionAction.scrollTo:
        if (interaction.destinationNodeId != null) {
          scrollTo(
            interaction.destinationNodeId!,
            settings: interaction.scrollSettings,
          );
        }
        break;

      case InteractionAction.openLink:
        if (interaction.externalLink != null) {
          openExternalLink(interaction.externalLink!);
        }
        break;

      case InteractionAction.setVariable:
        if (interaction.variableSettings != null) {
          final key = interaction.variableSettings!['key'] as String?;
          final value = interaction.variableSettings!['value'];
          if (key != null) {
            setVariable(key, value);
          }
        }
        break;
    }
  }

  /// Navigate to a node
  void navigateTo(String nodeId, {TransitionConfig? transition}) {
    final entry = NavigationEntry(
      nodeId: nodeId,
      timestamp: DateTime.now(),
      transition: transition,
    );

    _state = _state.copyWith(
      currentNodeId: nodeId,
      history: [..._state.history, entry],
    );

    onNavigate?.call(nodeId, transition ?? const TransitionConfig());
    notifyListeners();

    // Check for afterDelay interactions
    _setupDelayedInteractions(nodeId);
  }

  /// Swap current node (no history entry)
  void swapTo(String nodeId, {TransitionConfig? transition}) {
    final newHistory = _state.history.isNotEmpty
        ? [..._state.history.sublist(0, _state.history.length - 1)]
        : <NavigationEntry>[];

    final entry = NavigationEntry(
      nodeId: nodeId,
      timestamp: DateTime.now(),
      transition: transition,
    );

    _state = _state.copyWith(
      currentNodeId: nodeId,
      history: [...newHistory, entry],
    );

    onNavigate?.call(nodeId, transition ?? const TransitionConfig());
    notifyListeners();
  }

  /// Go back in navigation history
  void goBack({TransitionConfig? transition}) {
    if (!canGoBack) return;

    final newHistory = _state.history.sublist(0, _state.history.length - 1);
    final previousEntry = newHistory.last;

    _state = _state.copyWith(
      currentNodeId: previousEntry.nodeId,
      history: newHistory,
    );

    onNavigate?.call(previousEntry.nodeId, transition ?? const TransitionConfig());
    notifyListeners();
  }

  /// Open an overlay
  void openOverlay(
    String nodeId, {
    required OverlaySettings settings,
    TransitionConfig? transition,
  }) {
    final overlay = OverlayState(
      nodeId: nodeId,
      settings: settings,
      transition: transition ?? const TransitionConfig(),
    );

    _state = _state.copyWith(
      overlays: [..._state.overlays, overlay],
    );

    onOpenOverlay?.call(overlay);
    notifyListeners();
  }

  /// Close the top overlay
  void closeTopOverlay({TransitionConfig? transition}) {
    if (_state.overlays.isEmpty) return;

    final closedOverlay = _state.overlays.last;
    _state = _state.copyWith(
      overlays: _state.overlays.sublist(0, _state.overlays.length - 1),
    );

    onCloseOverlay?.call(closedOverlay);
    notifyListeners();
  }

  /// Close all overlays
  void closeAllOverlays() {
    for (final overlay in _state.overlays.reversed) {
      onCloseOverlay?.call(overlay);
    }
    _state = _state.copyWith(overlays: []);
    notifyListeners();
  }

  /// Scroll to a specific element
  void scrollTo(String nodeId, {ScrollSettings? settings}) {
    // This would be implemented with actual scroll controller logic
    // For now, just store the scroll position
    final offset = settings?.scrollOffset ?? Offset.zero;
    _state = _state.copyWith(
      scrollPositions: {..._state.scrollPositions, nodeId: offset},
    );
    notifyListeners();
  }

  /// Open an external link
  void openExternalLink(String url) {
    onExternalLink?.call(url);
    // Platform-specific link handling would go here
  }

  /// Set a prototype variable
  void setVariable(String key, dynamic value) {
    _state = _state.copyWith(
      variables: {..._state.variables, key: value},
    );
    onVariableChange?.call(key, value);
    notifyListeners();
  }

  /// Get a prototype variable
  T? getVariable<T>(String key) {
    return _state.variables[key] as T?;
  }

  /// Start playing
  void play() {
    _state = _state.copyWith(isPlaying: true);
    notifyListeners();
  }

  /// Pause playing
  void pause() {
    _state = _state.copyWith(isPlaying: false);
    _cancelAllDelayTimers();
    notifyListeners();
  }

  /// Reset to starting state
  void reset(String startingNodeId) {
    _cancelAllDelayTimers();
    _state = PrototypeState(
      currentNodeId: startingNodeId,
      history: [
        NavigationEntry(
          nodeId: startingNodeId,
          timestamp: DateTime.now(),
        ),
      ],
    );
    notifyListeners();
  }

  /// Setup delayed interactions for a node
  void _setupDelayedInteractions(String nodeId) {
    final interactions = _nodeInteractions[nodeId];
    if (interactions == null) return;

    final delayedInteractions =
        interactions.getInteractionsByTrigger(InteractionTrigger.afterDelay);

    for (final interaction in delayedInteractions) {
      if (interaction.triggerDelay != null) {
        final timer = Timer(interaction.triggerDelay!, () {
          if (_state.currentNodeId == nodeId && _state.isPlaying) {
            _executeInteraction(interaction);
          }
        });
        _delayTimers[interaction.id] = timer;
      }
    }
  }

  /// Cancel all delay timers
  void _cancelAllDelayTimers() {
    for (final timer in _delayTimers.values) {
      timer.cancel();
    }
    _delayTimers.clear();
  }

  @override
  void dispose() {
    _cancelAllDelayTimers();
    super.dispose();
  }
}

/// Prototype player widget
class PrototypePlayer extends StatefulWidget {
  final PrototypePlayerController controller;
  final Widget Function(BuildContext, String nodeId) nodeBuilder;
  final bool showControls;
  final Color backgroundColor;
  final PrototypeDevice? device;

  const PrototypePlayer({
    super.key,
    required this.controller,
    required this.nodeBuilder,
    this.showControls = true,
    this.backgroundColor = Colors.black,
    this.device,
  });

  @override
  State<PrototypePlayer> createState() => _PrototypePlayerState();
}

class _PrototypePlayerState extends State<PrototypePlayer>
    with TickerProviderStateMixin {
  late AnimationController _transitionController;
  late AnimationController _overlayController;

  String? _previousNodeId;
  TransitionConfig _currentTransition = const TransitionConfig();

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    widget.controller.addListener(_onStateChange);
    widget.controller.onNavigate = _onNavigate;
    widget.controller.onOpenOverlay = _onOpenOverlay;
    widget.controller.onCloseOverlay = _onCloseOverlay;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChange);
    _transitionController.dispose();
    _overlayController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    setState(() {});
  }

  void _onNavigate(String nodeId, TransitionConfig transition) {
    _previousNodeId = widget.controller.state.history.length > 1
        ? widget.controller.state.history[widget.controller.state.history.length - 2].nodeId
        : null;
    _currentTransition = transition;
    _transitionController.duration = transition.duration;
    _transitionController.forward(from: 0);
  }

  void _onOpenOverlay(OverlayState overlay) {
    _overlayController.duration = overlay.transition.duration;
    _overlayController.forward(from: 0);
  }

  void _onCloseOverlay(OverlayState overlay) {
    _overlayController.duration = overlay.transition.duration;
    _overlayController.reverse(from: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Column(
        children: [
          if (widget.showControls) _buildControls(),
          Expanded(
            child: Center(
              child: _buildDeviceFrame(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      height: 48,
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              widget.controller.state.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              if (widget.controller.state.isPlaying) {
                widget.controller.pause();
              } else {
                widget.controller.play();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              widget.controller.reset(
                widget.controller.state.history.first.nodeId,
              );
            },
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: widget.controller.canGoBack
                  ? Colors.white
                  : Colors.grey[600],
            ),
            onPressed: widget.controller.canGoBack
                ? () => widget.controller.goBack()
                : null,
          ),
          const Spacer(),
          if (widget.device != null)
            Text(
              widget.device!.label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceFrame() {
    final device = widget.device ?? PrototypeDevice.iphone14;
    final deviceSize = device.size;

    return Container(
      width: deviceSize.width,
      height: deviceSize.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Main content with transitions
          _buildTransitioningContent(),

          // Overlays
          ..._buildOverlays(),
        ],
      ),
    );
  }

  Widget _buildTransitioningContent() {
    final currentNode = widget.nodeBuilder(
      context,
      widget.controller.currentNodeId,
    );

    if (_previousNodeId == null ||
        _currentTransition.type == TransitionType.instant) {
      return currentNode;
    }

    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        return _buildTransition(
          currentNode,
          _previousNodeId != null
              ? widget.nodeBuilder(context, _previousNodeId!)
              : const SizedBox(),
        );
      },
    );
  }

  Widget _buildTransition(Widget newContent, Widget oldContent) {
    final progress = _currentTransition.easing
        .toCurve()
        .transform(_transitionController.value);

    switch (_currentTransition.type) {
      case TransitionType.instant:
        return newContent;

      case TransitionType.dissolve:
        return Stack(
          children: [
            Opacity(opacity: 1 - progress, child: oldContent),
            Opacity(opacity: progress, child: newContent),
          ],
        );

      case TransitionType.smartAnimate:
        // Smart animate would need layer matching logic
        return Stack(
          children: [
            Opacity(opacity: 1 - progress, child: oldContent),
            Opacity(opacity: progress, child: newContent),
          ],
        );

      case TransitionType.moveIn:
        final offset = _currentTransition.direction.toOffset();
        return Stack(
          children: [
            oldContent,
            Transform.translate(
              offset: Offset(
                offset.dx * (1 - progress) * 400,
                offset.dy * (1 - progress) * 800,
              ),
              child: newContent,
            ),
          ],
        );

      case TransitionType.moveOut:
        final offset = _currentTransition.direction.toOffset();
        return Stack(
          children: [
            Transform.translate(
              offset: Offset(
                -offset.dx * progress * 400,
                -offset.dy * progress * 800,
              ),
              child: oldContent,
            ),
            newContent,
          ],
        );

      case TransitionType.push:
        final offset = _currentTransition.direction.toOffset();
        return Stack(
          children: [
            Transform.translate(
              offset: Offset(
                -offset.dx * progress * 400,
                -offset.dy * progress * 800,
              ),
              child: oldContent,
            ),
            Transform.translate(
              offset: Offset(
                offset.dx * (1 - progress) * 400,
                offset.dy * (1 - progress) * 800,
              ),
              child: newContent,
            ),
          ],
        );

      case TransitionType.slideIn:
        final offset = _currentTransition.direction.toOffset();
        return Stack(
          children: [
            oldContent,
            SlideTransition(
              position: Tween<Offset>(
                begin: offset,
                end: Offset.zero,
              ).animate(_transitionController),
              child: newContent,
            ),
          ],
        );

      case TransitionType.slideOut:
        final offset = _currentTransition.direction.toOffset();
        return Stack(
          children: [
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: Offset(-offset.dx, -offset.dy),
              ).animate(_transitionController),
              child: oldContent,
            ),
            newContent,
          ],
        );
    }
  }

  List<Widget> _buildOverlays() {
    return widget.controller.overlays.map((overlay) {
      return _buildOverlay(overlay);
    }).toList();
  }

  Widget _buildOverlay(OverlayState overlay) {
    final settings = overlay.settings;

    return Stack(
      children: [
        // Background
        if (settings.addBackgroundBehind)
          GestureDetector(
            onTap: settings.closeOnClickOutside
                ? () => widget.controller.closeTopOverlay()
                : null,
            child: AnimatedBuilder(
              animation: _overlayController,
              builder: (context, child) {
                return Container(
                  color: settings.backgroundColor
                      .withOpacity(settings.backgroundOpacity * _overlayController.value),
                );
              },
            ),
          ),

        // Overlay content
        Positioned.fill(
          child: Align(
            alignment: settings.position.toAlignment(),
            child: Transform.translate(
              offset: settings.manualOffset,
              child: AnimatedBuilder(
                animation: _overlayController,
                builder: (context, child) {
                  final progress = overlay.transition.easing
                      .toCurve()
                      .transform(_overlayController.value);

                  return Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.9 + (0.1 * progress),
                      child: widget.nodeBuilder(context, overlay.nodeId),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Interactive hotspot widget for prototype interactions
class InteractiveHotspot extends StatefulWidget {
  final Widget child;
  final String nodeId;
  final PrototypePlayerController controller;
  final bool showHotspotHint;

  const InteractiveHotspot({
    super.key,
    required this.child,
    required this.nodeId,
    required this.controller,
    this.showHotspotHint = false,
  });

  @override
  State<InteractiveHotspot> createState() => _InteractiveHotspotState();
}

class _InteractiveHotspotState extends State<InteractiveHotspot> {
  bool _isHovering = false;
  bool _isPressed = false;

  NodeInteractions? get _interactions =>
      widget.controller.getInteractions(widget.nodeId);

  bool get _hasInteractions =>
      _interactions != null && _interactions!.hasInteractions;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        widget.controller.handleTrigger(
          widget.nodeId,
          InteractionTrigger.mouseEnter,
        );
        widget.controller.handleTrigger(
          widget.nodeId,
          InteractionTrigger.onHover,
        );
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        widget.controller.handleTrigger(
          widget.nodeId,
          InteractionTrigger.mouseLeave,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _isPressed = true);
          widget.controller.handleTrigger(
            widget.nodeId,
            InteractionTrigger.mouseDown,
          );
          widget.controller.handleTrigger(
            widget.nodeId,
            InteractionTrigger.onPress,
          );
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.controller.handleTrigger(
            widget.nodeId,
            InteractionTrigger.mouseUp,
          );
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
        },
        onTap: () {
          widget.controller.handleTrigger(
            widget.nodeId,
            InteractionTrigger.onClick,
          );
        },
        onPanStart: (_) {
          widget.controller.handleTrigger(
            widget.nodeId,
            InteractionTrigger.onDrag,
          );
        },
        child: Stack(
          children: [
            widget.child,
            if (widget.showHotspotHint && _hasInteractions)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue.withOpacity(_isHovering ? 0.8 : 0.4),
                        width: 2,
                      ),
                      color: Colors.blue.withOpacity(_isPressed ? 0.2 : 0.1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Keyboard shortcuts handler for prototype
class PrototypeKeyboardHandler extends StatefulWidget {
  final Widget child;
  final PrototypePlayerController controller;
  final Map<LogicalKeyboardKey, VoidCallback>? customShortcuts;

  const PrototypeKeyboardHandler({
    super.key,
    required this.child,
    required this.controller,
    this.customShortcuts,
  });

  @override
  State<PrototypeKeyboardHandler> createState() =>
      _PrototypeKeyboardHandlerState();
}

class _PrototypeKeyboardHandlerState extends State<PrototypeKeyboardHandler> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Check custom shortcuts first
    if (widget.customShortcuts != null) {
      final callback = widget.customShortcuts![event.logicalKey];
      if (callback != null) {
        callback();
        return;
      }
    }

    // Default shortcuts
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        if (widget.controller.hasOverlays) {
          widget.controller.closeTopOverlay();
        }
        break;

      case LogicalKeyboardKey.backspace:
        if (widget.controller.canGoBack) {
          widget.controller.goBack();
        }
        break;

      case LogicalKeyboardKey.space:
        if (widget.controller.state.isPlaying) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
        break;

      case LogicalKeyboardKey.keyR:
        if (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) {
          widget.controller.reset(
            widget.controller.state.history.first.nodeId,
          );
        }
        break;
    }
  }
}
