// Prototyping interactions module
// Defines interaction triggers, actions, and transitions

import 'package:flutter/material.dart';

/// Trigger types for interactions
enum InteractionTrigger {
  onClick('On click'),
  onHover('On hover'),
  onPress('On press'),
  onDrag('On drag'),
  afterDelay('After delay'),
  mouseEnter('Mouse enter'),
  mouseLeave('Mouse leave'),
  mouseDown('Mouse down'),
  mouseUp('Mouse up'),
  keyDown('Key down');

  final String label;
  const InteractionTrigger(this.label);
}

/// Action types for interactions
enum InteractionAction {
  navigate('Navigate to'),
  openOverlay('Open overlay'),
  closeOverlay('Close overlay'),
  swap('Swap with'),
  back('Go back'),
  scrollTo('Scroll to'),
  openLink('Open link'),
  setVariable('Set variable');

  final String label;
  const InteractionAction(this.label);
}

/// Navigation types
enum NavigationType {
  navigate('Navigate'),
  swap('Swap'),
  overlay('Overlay'),
  scrollTo('Scroll to');

  final String label;
  const NavigationType(this.label);
}

/// Animation easing types
enum AnimationEasing {
  linear('Linear'),
  easeIn('Ease in'),
  easeOut('Ease out'),
  easeInOut('Ease in out'),
  easeInBack('Ease in back'),
  easeOutBack('Ease out back'),
  easeInOutBack('Ease in out back'),
  spring('Spring'),
  gentleSpring('Gentle spring'),
  quickSpring('Quick spring'),
  bouncy('Bouncy'),
  custom('Custom');

  final String label;
  const AnimationEasing(this.label);

  Curve toCurve() {
    switch (this) {
      case AnimationEasing.linear:
        return Curves.linear;
      case AnimationEasing.easeIn:
        return Curves.easeIn;
      case AnimationEasing.easeOut:
        return Curves.easeOut;
      case AnimationEasing.easeInOut:
        return Curves.easeInOut;
      case AnimationEasing.easeInBack:
        return Curves.easeInBack;
      case AnimationEasing.easeOutBack:
        return Curves.easeOutBack;
      case AnimationEasing.easeInOutBack:
        return Curves.easeInOutBack;
      case AnimationEasing.spring:
        return Curves.elasticOut;
      case AnimationEasing.gentleSpring:
        return Curves.easeOutCubic;
      case AnimationEasing.quickSpring:
        return Curves.easeOutQuart;
      case AnimationEasing.bouncy:
        return Curves.bounceOut;
      case AnimationEasing.custom:
        return Curves.easeInOut;
    }
  }
}

/// Transition animation types
enum TransitionType {
  instant('Instant'),
  dissolve('Dissolve'),
  smartAnimate('Smart animate'),
  moveIn('Move in'),
  moveOut('Move out'),
  push('Push'),
  slideIn('Slide in'),
  slideOut('Slide out');

  final String label;
  const TransitionType(this.label);
}

/// Direction for directional transitions
enum TransitionDirection {
  left('Left'),
  right('Right'),
  top('Top'),
  bottom('Bottom');

  final String label;
  const TransitionDirection(this.label);

  Offset toOffset() {
    switch (this) {
      case TransitionDirection.left:
        return const Offset(-1, 0);
      case TransitionDirection.right:
        return const Offset(1, 0);
      case TransitionDirection.top:
        return const Offset(0, -1);
      case TransitionDirection.bottom:
        return const Offset(0, 1);
    }
  }
}

/// Overlay position presets
enum OverlayPosition {
  manual('Manual'),
  center('Center'),
  topLeft('Top left'),
  topCenter('Top center'),
  topRight('Top right'),
  bottomLeft('Bottom left'),
  bottomCenter('Bottom center'),
  bottomRight('Bottom right');

  final String label;
  const OverlayPosition(this.label);

  Alignment toAlignment() {
    switch (this) {
      case OverlayPosition.manual:
      case OverlayPosition.center:
        return Alignment.center;
      case OverlayPosition.topLeft:
        return Alignment.topLeft;
      case OverlayPosition.topCenter:
        return Alignment.topCenter;
      case OverlayPosition.topRight:
        return Alignment.topRight;
      case OverlayPosition.bottomLeft:
        return Alignment.bottomLeft;
      case OverlayPosition.bottomCenter:
        return Alignment.bottomCenter;
      case OverlayPosition.bottomRight:
        return Alignment.bottomRight;
    }
  }
}

/// Transition configuration
class TransitionConfig {
  final TransitionType type;
  final TransitionDirection direction;
  final AnimationEasing easing;
  final Duration duration;
  final bool matchLayers;

  const TransitionConfig({
    this.type = TransitionType.dissolve,
    this.direction = TransitionDirection.right,
    this.easing = AnimationEasing.easeInOut,
    this.duration = const Duration(milliseconds: 300),
    this.matchLayers = false,
  });

  TransitionConfig copyWith({
    TransitionType? type,
    TransitionDirection? direction,
    AnimationEasing? easing,
    Duration? duration,
    bool? matchLayers,
  }) {
    return TransitionConfig(
      type: type ?? this.type,
      direction: direction ?? this.direction,
      easing: easing ?? this.easing,
      duration: duration ?? this.duration,
      matchLayers: matchLayers ?? this.matchLayers,
    );
  }

  static const instant = TransitionConfig(
    type: TransitionType.instant,
    duration: Duration.zero,
  );

  static const dissolve = TransitionConfig(
    type: TransitionType.dissolve,
    duration: Duration(milliseconds: 300),
  );

  static const smartAnimate = TransitionConfig(
    type: TransitionType.smartAnimate,
    duration: Duration(milliseconds: 300),
    matchLayers: true,
  );

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'direction': direction.name,
      'easing': easing.name,
      'durationMs': duration.inMilliseconds,
      'matchLayers': matchLayers,
    };
  }

  factory TransitionConfig.fromMap(Map<String, dynamic> map) {
    return TransitionConfig(
      type: TransitionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransitionType.dissolve,
      ),
      direction: TransitionDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => TransitionDirection.right,
      ),
      easing: AnimationEasing.values.firstWhere(
        (e) => e.name == map['easing'],
        orElse: () => AnimationEasing.easeInOut,
      ),
      duration: Duration(milliseconds: map['durationMs'] ?? 300),
      matchLayers: map['matchLayers'] ?? false,
    );
  }
}

/// Overlay settings
class OverlaySettings {
  final OverlayPosition position;
  final Offset manualOffset;
  final bool closeOnClickOutside;
  final bool addBackgroundBehind;
  final Color backgroundColor;
  final double backgroundOpacity;

  const OverlaySettings({
    this.position = OverlayPosition.center,
    this.manualOffset = Offset.zero,
    this.closeOnClickOutside = true,
    this.addBackgroundBehind = true,
    this.backgroundColor = Colors.black,
    this.backgroundOpacity = 0.5,
  });

  OverlaySettings copyWith({
    OverlayPosition? position,
    Offset? manualOffset,
    bool? closeOnClickOutside,
    bool? addBackgroundBehind,
    Color? backgroundColor,
    double? backgroundOpacity,
  }) {
    return OverlaySettings(
      position: position ?? this.position,
      manualOffset: manualOffset ?? this.manualOffset,
      closeOnClickOutside: closeOnClickOutside ?? this.closeOnClickOutside,
      addBackgroundBehind: addBackgroundBehind ?? this.addBackgroundBehind,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position.name,
      'manualOffsetX': manualOffset.dx,
      'manualOffsetY': manualOffset.dy,
      'closeOnClickOutside': closeOnClickOutside,
      'addBackgroundBehind': addBackgroundBehind,
      'backgroundColor': backgroundColor.value,
      'backgroundOpacity': backgroundOpacity,
    };
  }

  factory OverlaySettings.fromMap(Map<String, dynamic> map) {
    return OverlaySettings(
      position: OverlayPosition.values.firstWhere(
        (e) => e.name == map['position'],
        orElse: () => OverlayPosition.center,
      ),
      manualOffset: Offset(
        (map['manualOffsetX'] ?? 0).toDouble(),
        (map['manualOffsetY'] ?? 0).toDouble(),
      ),
      closeOnClickOutside: map['closeOnClickOutside'] ?? true,
      addBackgroundBehind: map['addBackgroundBehind'] ?? true,
      backgroundColor: Color(map['backgroundColor'] ?? 0xFF000000),
      backgroundOpacity: (map['backgroundOpacity'] ?? 0.5).toDouble(),
    );
  }
}

/// Scroll settings for scroll-to action
class ScrollSettings {
  final Offset scrollOffset;
  final bool preserveScrollPosition;
  final bool resetScrollPosition;

  const ScrollSettings({
    this.scrollOffset = Offset.zero,
    this.preserveScrollPosition = false,
    this.resetScrollPosition = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'scrollOffsetX': scrollOffset.dx,
      'scrollOffsetY': scrollOffset.dy,
      'preserveScrollPosition': preserveScrollPosition,
      'resetScrollPosition': resetScrollPosition,
    };
  }

  factory ScrollSettings.fromMap(Map<String, dynamic> map) {
    return ScrollSettings(
      scrollOffset: Offset(
        (map['scrollOffsetX'] ?? 0).toDouble(),
        (map['scrollOffsetY'] ?? 0).toDouble(),
      ),
      preserveScrollPosition: map['preserveScrollPosition'] ?? false,
      resetScrollPosition: map['resetScrollPosition'] ?? true,
    );
  }
}

/// Single interaction definition
class Interaction {
  final String id;
  final InteractionTrigger trigger;
  final InteractionAction action;
  final String? destinationNodeId;
  final TransitionConfig transition;
  final OverlaySettings? overlaySettings;
  final ScrollSettings? scrollSettings;
  final Duration? triggerDelay;
  final String? externalLink;
  final Map<String, dynamic>? variableSettings;

  Interaction({
    String? id,
    required this.trigger,
    required this.action,
    this.destinationNodeId,
    this.transition = const TransitionConfig(),
    this.overlaySettings,
    this.scrollSettings,
    this.triggerDelay,
    this.externalLink,
    this.variableSettings,
  }) : id = id ?? UniqueKey().toString();

  Interaction copyWith({
    String? id,
    InteractionTrigger? trigger,
    InteractionAction? action,
    String? destinationNodeId,
    TransitionConfig? transition,
    OverlaySettings? overlaySettings,
    ScrollSettings? scrollSettings,
    Duration? triggerDelay,
    String? externalLink,
    Map<String, dynamic>? variableSettings,
  }) {
    return Interaction(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
      destinationNodeId: destinationNodeId ?? this.destinationNodeId,
      transition: transition ?? this.transition,
      overlaySettings: overlaySettings ?? this.overlaySettings,
      scrollSettings: scrollSettings ?? this.scrollSettings,
      triggerDelay: triggerDelay ?? this.triggerDelay,
      externalLink: externalLink ?? this.externalLink,
      variableSettings: variableSettings ?? this.variableSettings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trigger': trigger.name,
      'action': action.name,
      'destinationNodeId': destinationNodeId,
      'transition': transition.toMap(),
      'overlaySettings': overlaySettings?.toMap(),
      'scrollSettings': scrollSettings?.toMap(),
      'triggerDelayMs': triggerDelay?.inMilliseconds,
      'externalLink': externalLink,
      'variableSettings': variableSettings,
    };
  }

  factory Interaction.fromMap(Map<String, dynamic> map) {
    return Interaction(
      id: map['id'],
      trigger: InteractionTrigger.values.firstWhere(
        (e) => e.name == map['trigger'],
        orElse: () => InteractionTrigger.onClick,
      ),
      action: InteractionAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => InteractionAction.navigate,
      ),
      destinationNodeId: map['destinationNodeId'],
      transition: map['transition'] != null
          ? TransitionConfig.fromMap(map['transition'])
          : const TransitionConfig(),
      overlaySettings: map['overlaySettings'] != null
          ? OverlaySettings.fromMap(map['overlaySettings'])
          : null,
      scrollSettings: map['scrollSettings'] != null
          ? ScrollSettings.fromMap(map['scrollSettings'])
          : null,
      triggerDelay: map['triggerDelayMs'] != null
          ? Duration(milliseconds: map['triggerDelayMs'])
          : null,
      externalLink: map['externalLink'],
      variableSettings: map['variableSettings'],
    );
  }

  /// Quick constructors for common interactions
  factory Interaction.navigateTo(String nodeId, {TransitionConfig? transition}) {
    return Interaction(
      trigger: InteractionTrigger.onClick,
      action: InteractionAction.navigate,
      destinationNodeId: nodeId,
      transition: transition ?? const TransitionConfig(),
    );
  }

  factory Interaction.openOverlay(
    String nodeId, {
    OverlaySettings? settings,
    TransitionConfig? transition,
  }) {
    return Interaction(
      trigger: InteractionTrigger.onClick,
      action: InteractionAction.openOverlay,
      destinationNodeId: nodeId,
      overlaySettings: settings ?? const OverlaySettings(),
      transition: transition ?? const TransitionConfig(),
    );
  }

  factory Interaction.back({TransitionConfig? transition}) {
    return Interaction(
      trigger: InteractionTrigger.onClick,
      action: InteractionAction.back,
      transition: transition ?? const TransitionConfig(),
    );
  }

  factory Interaction.openLink(String url) {
    return Interaction(
      trigger: InteractionTrigger.onClick,
      action: InteractionAction.openLink,
      externalLink: url,
    );
  }

  factory Interaction.onHoverNavigate(String nodeId) {
    return Interaction(
      trigger: InteractionTrigger.onHover,
      action: InteractionAction.navigate,
      destinationNodeId: nodeId,
    );
  }

  factory Interaction.afterDelay(
    Duration delay,
    String nodeId, {
    TransitionConfig? transition,
  }) {
    return Interaction(
      trigger: InteractionTrigger.afterDelay,
      action: InteractionAction.navigate,
      destinationNodeId: nodeId,
      triggerDelay: delay,
      transition: transition ?? const TransitionConfig(),
    );
  }
}

/// Collection of interactions for a node
class NodeInteractions {
  final String nodeId;
  final List<Interaction> interactions;

  const NodeInteractions({
    required this.nodeId,
    this.interactions = const [],
  });

  NodeInteractions copyWith({
    String? nodeId,
    List<Interaction>? interactions,
  }) {
    return NodeInteractions(
      nodeId: nodeId ?? this.nodeId,
      interactions: interactions ?? this.interactions,
    );
  }

  NodeInteractions addInteraction(Interaction interaction) {
    return copyWith(interactions: [...interactions, interaction]);
  }

  NodeInteractions removeInteraction(String interactionId) {
    return copyWith(
      interactions: interactions.where((i) => i.id != interactionId).toList(),
    );
  }

  NodeInteractions updateInteraction(Interaction interaction) {
    return copyWith(
      interactions: interactions
          .map((i) => i.id == interaction.id ? interaction : i)
          .toList(),
    );
  }

  bool get hasInteractions => interactions.isNotEmpty;

  List<Interaction> getInteractionsByTrigger(InteractionTrigger trigger) {
    return interactions.where((i) => i.trigger == trigger).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'nodeId': nodeId,
      'interactions': interactions.map((i) => i.toMap()).toList(),
    };
  }

  factory NodeInteractions.fromMap(Map<String, dynamic> map) {
    return NodeInteractions(
      nodeId: map['nodeId'],
      interactions: (map['interactions'] as List?)
              ?.map((i) => Interaction.fromMap(i))
              .toList() ??
          [],
    );
  }
}

/// Prototype flow definition (starting point and device settings)
class PrototypeFlow {
  final String id;
  final String name;
  final String startingNodeId;
  final PrototypeDevice device;
  final Color backgroundColor;

  const PrototypeFlow({
    required this.id,
    required this.name,
    required this.startingNodeId,
    this.device = PrototypeDevice.iphone14,
    this.backgroundColor = Colors.white,
  });

  PrototypeFlow copyWith({
    String? id,
    String? name,
    String? startingNodeId,
    PrototypeDevice? device,
    Color? backgroundColor,
  }) {
    return PrototypeFlow(
      id: id ?? this.id,
      name: name ?? this.name,
      startingNodeId: startingNodeId ?? this.startingNodeId,
      device: device ?? this.device,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startingNodeId': startingNodeId,
      'device': device.name,
      'backgroundColor': backgroundColor.value,
    };
  }

  factory PrototypeFlow.fromMap(Map<String, dynamic> map) {
    return PrototypeFlow(
      id: map['id'],
      name: map['name'],
      startingNodeId: map['startingNodeId'],
      device: PrototypeDevice.values.firstWhere(
        (e) => e.name == map['device'],
        orElse: () => PrototypeDevice.iphone14,
      ),
      backgroundColor: Color(map['backgroundColor'] ?? 0xFFFFFFFF),
    );
  }
}

/// Prototype device presets
enum PrototypeDevice {
  iphone14('iPhone 14', 390, 844),
  iphone14Pro('iPhone 14 Pro', 393, 852),
  iphone14ProMax('iPhone 14 Pro Max', 430, 932),
  iphoneSE('iPhone SE', 375, 667),
  ipadMini('iPad Mini', 744, 1133),
  ipadPro11('iPad Pro 11"', 834, 1194),
  ipadPro129('iPad Pro 12.9"', 1024, 1366),
  pixel7('Pixel 7', 412, 915),
  pixel7Pro('Pixel 7 Pro', 412, 892),
  galaxyS23('Galaxy S23', 360, 780),
  desktop('Desktop', 1440, 900),
  macbook('MacBook', 1440, 900),
  presentation4_3('Presentation 4:3', 1024, 768),
  presentation16_9('Presentation 16:9', 1920, 1080),
  custom('Custom', 0, 0);

  final String label;
  final double width;
  final double height;

  const PrototypeDevice(this.label, this.width, this.height);

  Size get size => Size(width, height);
}
