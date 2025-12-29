// Device Preview for Prototyping
// Provides device frames, status bars, and scrolling behaviors

import 'package:flutter/material.dart';
import 'interactions.dart';

/// Status bar style
enum StatusBarStyle {
  light('Light'),
  dark('Dark');

  final String label;
  const StatusBarStyle(this.label);
}

/// Platform type for status bar
enum PlatformType {
  iOS('iOS'),
  android('Android');

  final String label;
  const PlatformType(this.label);
}

/// Status bar configuration
class StatusBarConfig {
  final bool visible;
  final StatusBarStyle style;
  final PlatformType platform;
  final String time;
  final int batteryLevel;
  final int signalStrength;
  final int wifiStrength;
  final bool showCarrier;
  final String carrierName;

  const StatusBarConfig({
    this.visible = true,
    this.style = StatusBarStyle.dark,
    this.platform = PlatformType.iOS,
    this.time = '9:41',
    this.batteryLevel = 100,
    this.signalStrength = 4,
    this.wifiStrength = 3,
    this.showCarrier = true,
    this.carrierName = 'Carrier',
  });

  StatusBarConfig copyWith({
    bool? visible,
    StatusBarStyle? style,
    PlatformType? platform,
    String? time,
    int? batteryLevel,
    int? signalStrength,
    int? wifiStrength,
    bool? showCarrier,
    String? carrierName,
  }) {
    return StatusBarConfig(
      visible: visible ?? this.visible,
      style: style ?? this.style,
      platform: platform ?? this.platform,
      time: time ?? this.time,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      wifiStrength: wifiStrength ?? this.wifiStrength,
      showCarrier: showCarrier ?? this.showCarrier,
      carrierName: carrierName ?? this.carrierName,
    );
  }
}

/// iOS Status Bar widget
class IOSStatusBar extends StatelessWidget {
  final StatusBarConfig config;
  final double height;

  const IOSStatusBar({
    super.key,
    required this.config,
    this.height = 44,
  });

  Color get _textColor =>
      config.style == StatusBarStyle.light ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) {
    if (!config.visible) return const SizedBox.shrink();

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Time (centered on notch devices)
          Expanded(
            child: Row(
              children: [
                Text(
                  config.time,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Right side indicators
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Signal bars
                _buildSignalBars(),
                const SizedBox(width: 6),
                // WiFi
                _buildWifiIcon(),
                const SizedBox(width: 6),
                // Battery
                _buildBattery(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = index < config.signalStrength;
        return Container(
          width: 3,
          height: 4.0 + (index * 2),
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: isActive ? _textColor : _textColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildWifiIcon() {
    return Icon(
      Icons.wifi,
      size: 16,
      color: _textColor,
    );
  }

  Widget _buildBattery() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 12,
          decoration: BoxDecoration(
            border: Border.all(color: _textColor, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: config.batteryLevel / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: config.batteryLevel > 20 ? _textColor : Colors.red,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 2,
          height: 5,
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: _textColor,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(1),
              bottomRight: Radius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

/// Android Status Bar widget
class AndroidStatusBar extends StatelessWidget {
  final StatusBarConfig config;
  final double height;

  const AndroidStatusBar({
    super.key,
    required this.config,
    this.height = 24,
  });

  Color get _textColor =>
      config.style == StatusBarStyle.light ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) {
    if (!config.visible) return const SizedBox.shrink();

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Left side - time
          Text(
            config.time,
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
            ),
          ),

          const Spacer(),

          // Right side indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WiFi
              Icon(Icons.wifi, size: 14, color: _textColor),
              const SizedBox(width: 4),
              // Signal
              Icon(Icons.signal_cellular_4_bar, size: 14, color: _textColor),
              const SizedBox(width: 4),
              // Battery
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.batteryLevel}%',
                    style: TextStyle(color: _textColor, fontSize: 11),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    config.batteryLevel > 80
                        ? Icons.battery_full
                        : config.batteryLevel > 20
                            ? Icons.battery_5_bar
                            : Icons.battery_1_bar,
                    size: 14,
                    color: _textColor,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status bar widget (auto-selects based on platform)
class StatusBar extends StatelessWidget {
  final StatusBarConfig config;

  const StatusBar({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    switch (config.platform) {
      case PlatformType.iOS:
        return IOSStatusBar(config: config);
      case PlatformType.android:
        return AndroidStatusBar(config: config);
    }
  }
}

/// Scroll behavior type
enum PrototypeScrollBehavior {
  none('None'),
  vertical('Vertical'),
  horizontal('Horizontal'),
  both('Both');

  final String label;
  const PrototypeScrollBehavior(this.label);
}

/// Scroll configuration
class ScrollConfig {
  final PrototypeScrollBehavior behavior;
  final bool preserveScrollPosition;
  final bool showScrollbar;
  final double? initialScrollOffset;
  final List<FixedElement> fixedElements;

  const ScrollConfig({
    this.behavior = PrototypeScrollBehavior.vertical,
    this.preserveScrollPosition = false,
    this.showScrollbar = false,
    this.initialScrollOffset,
    this.fixedElements = const [],
  });

  ScrollConfig copyWith({
    PrototypeScrollBehavior? behavior,
    bool? preserveScrollPosition,
    bool? showScrollbar,
    double? initialScrollOffset,
    List<FixedElement>? fixedElements,
  }) {
    return ScrollConfig(
      behavior: behavior ?? this.behavior,
      preserveScrollPosition: preserveScrollPosition ?? this.preserveScrollPosition,
      showScrollbar: showScrollbar ?? this.showScrollbar,
      initialScrollOffset: initialScrollOffset ?? this.initialScrollOffset,
      fixedElements: fixedElements ?? this.fixedElements,
    );
  }
}

/// Fixed element position
enum FixedPosition {
  top('Top'),
  bottom('Bottom'),
  left('Left'),
  right('Right');

  final String label;
  const FixedPosition(this.label);
}

/// Fixed element (header/footer)
class FixedElement {
  final String id;
  final String nodeId;
  final FixedPosition position;
  final double size;

  const FixedElement({
    required this.id,
    required this.nodeId,
    required this.position,
    required this.size,
  });

  FixedElement copyWith({
    String? id,
    String? nodeId,
    FixedPosition? position,
    double? size,
  }) {
    return FixedElement(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      position: position ?? this.position,
      size: size ?? this.size,
    );
  }
}

/// Scrollable prototype content
class PrototypeScrollView extends StatefulWidget {
  final ScrollConfig config;
  final Widget child;
  final Widget Function(BuildContext, String)? fixedElementBuilder;
  final void Function(Offset)? onScrollChanged;

  const PrototypeScrollView({
    super.key,
    required this.config,
    required this.child,
    this.fixedElementBuilder,
    this.onScrollChanged,
  });

  @override
  State<PrototypeScrollView> createState() => _PrototypeScrollViewState();
}

class _PrototypeScrollViewState extends State<PrototypeScrollView> {
  late ScrollController _verticalController;
  late ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController(
      initialScrollOffset: widget.config.initialScrollOffset ?? 0,
    );
    _horizontalController = ScrollController();

    _verticalController.addListener(_onScroll);
    _horizontalController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _onScroll() {
    widget.onScrollChanged?.call(Offset(
      _horizontalController.hasClients ? _horizontalController.offset : 0,
      _verticalController.hasClients ? _verticalController.offset : 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.config.behavior == PrototypeScrollBehavior.none) {
      return _buildWithFixedElements(widget.child);
    }

    Widget scrollableContent;

    switch (widget.config.behavior) {
      case PrototypeScrollBehavior.vertical:
        scrollableContent = SingleChildScrollView(
          controller: _verticalController,
          child: widget.child,
        );
        break;
      case PrototypeScrollBehavior.horizontal:
        scrollableContent = SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        );
        break;
      case PrototypeScrollBehavior.both:
        scrollableContent = SingleChildScrollView(
          controller: _verticalController,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
        );
        break;
      case PrototypeScrollBehavior.none:
        scrollableContent = widget.child;
    }

    if (widget.config.showScrollbar) {
      scrollableContent = Scrollbar(
        controller: _verticalController,
        child: scrollableContent,
      );
    }

    return _buildWithFixedElements(scrollableContent);
  }

  Widget _buildWithFixedElements(Widget content) {
    if (widget.config.fixedElements.isEmpty || widget.fixedElementBuilder == null) {
      return content;
    }

    final topElements = widget.config.fixedElements
        .where((e) => e.position == FixedPosition.top)
        .toList();
    final bottomElements = widget.config.fixedElements
        .where((e) => e.position == FixedPosition.bottom)
        .toList();

    return Column(
      children: [
        // Top fixed elements
        ...topElements.map((e) => SizedBox(
              height: e.size,
              child: widget.fixedElementBuilder!(context, e.nodeId),
            )),

        // Scrollable content
        Expanded(child: content),

        // Bottom fixed elements
        ...bottomElements.map((e) => SizedBox(
              height: e.size,
              child: widget.fixedElementBuilder!(context, e.nodeId),
            )),
      ],
    );
  }
}

/// Device frame widget with status bar and home indicator
class DeviceFrame extends StatelessWidget {
  final PrototypeDevice device;
  final Widget child;
  final StatusBarConfig statusBarConfig;
  final bool showHomeIndicator;
  final Color frameColor;
  final bool isLandscape;

  const DeviceFrame({
    super.key,
    required this.device,
    required this.child,
    this.statusBarConfig = const StatusBarConfig(),
    this.showHomeIndicator = true,
    this.frameColor = Colors.black,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLandscape
        ? Size(device.height, device.width)
        : device.size;

    final cornerRadius = _getCornerRadius();
    final notchHeight = _getNotchHeight();

    return Container(
      width: size.width + 16,
      height: size.height + 16,
      decoration: BoxDecoration(
        color: frameColor,
        borderRadius: BorderRadius.circular(cornerRadius + 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: Column(
                children: [
                  // Status bar area
                  if (statusBarConfig.visible && _hasNotch())
                    SizedBox(height: notchHeight),
                  // Content
                  Expanded(child: child),
                  // Home indicator
                  if (showHomeIndicator && _hasHomeIndicator())
                    _buildHomeIndicator(),
                ],
              ),
            ),

            // Status bar overlay
            if (statusBarConfig.visible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: StatusBar(config: statusBarConfig),
              ),

            // Notch overlay (for iPhones)
            if (_hasNotch())
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildNotch(),
              ),
          ],
        ),
      ),
    );
  }

  double _getCornerRadius() {
    switch (device) {
      case PrototypeDevice.iphone14:
      case PrototypeDevice.iphone14Pro:
      case PrototypeDevice.iphone14ProMax:
        return 47;
      case PrototypeDevice.iphoneSE:
        return 0;
      case PrototypeDevice.ipadMini:
      case PrototypeDevice.ipadPro11:
      case PrototypeDevice.ipadPro129:
        return 18;
      case PrototypeDevice.pixel7:
      case PrototypeDevice.pixel7Pro:
      case PrototypeDevice.galaxyS23:
        return 28;
      default:
        return 0;
    }
  }

  double _getNotchHeight() {
    switch (device) {
      case PrototypeDevice.iphone14:
        return 47;
      case PrototypeDevice.iphone14Pro:
      case PrototypeDevice.iphone14ProMax:
        return 54; // Dynamic Island
      default:
        return 44;
    }
  }

  bool _hasNotch() {
    switch (device) {
      case PrototypeDevice.iphone14:
      case PrototypeDevice.iphone14Pro:
      case PrototypeDevice.iphone14ProMax:
        return true;
      default:
        return false;
    }
  }

  bool _hasHomeIndicator() {
    switch (device) {
      case PrototypeDevice.iphone14:
      case PrototypeDevice.iphone14Pro:
      case PrototypeDevice.iphone14ProMax:
      case PrototypeDevice.ipadMini:
      case PrototypeDevice.ipadPro11:
      case PrototypeDevice.ipadPro129:
        return true;
      default:
        return false;
    }
  }

  Widget _buildNotch() {
    // Dynamic Island for Pro models
    if (device == PrototypeDevice.iphone14Pro ||
        device == PrototypeDevice.iphone14ProMax) {
      return Center(
        child: Container(
          margin: const EdgeInsets.only(top: 11),
          width: 126,
          height: 37,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    // Standard notch
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 0),
        width: 160,
        height: 34,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeIndicator() {
    return Container(
      height: 34,
      alignment: Alignment.center,
      child: Container(
        width: 134,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Parallax scroll effect
class ParallaxScrollView extends StatefulWidget {
  final Widget background;
  final Widget foreground;
  final double parallaxFactor;

  const ParallaxScrollView({
    super.key,
    required this.background,
    required this.foreground,
    this.parallaxFactor = 0.5,
  });

  @override
  State<ParallaxScrollView> createState() => _ParallaxScrollViewState();
}

class _ParallaxScrollViewState extends State<ParallaxScrollView> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Parallax background
        Transform.translate(
          offset: Offset(0, _scrollOffset * widget.parallaxFactor),
          child: widget.background,
        ),

        // Scrollable foreground
        SingleChildScrollView(
          controller: _scrollController,
          child: widget.foreground,
        ),
      ],
    );
  }
}

/// Device preview configuration panel
class DevicePreviewPanel extends StatefulWidget {
  final PrototypeDevice selectedDevice;
  final StatusBarConfig statusBarConfig;
  final bool isLandscape;
  final void Function(PrototypeDevice) onDeviceChanged;
  final void Function(StatusBarConfig) onStatusBarChanged;
  final void Function(bool) onOrientationChanged;

  const DevicePreviewPanel({
    super.key,
    required this.selectedDevice,
    required this.statusBarConfig,
    required this.isLandscape,
    required this.onDeviceChanged,
    required this.onStatusBarChanged,
    required this.onOrientationChanged,
  });

  @override
  State<DevicePreviewPanel> createState() => _DevicePreviewPanelState();
}

class _DevicePreviewPanelState extends State<DevicePreviewPanel> {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Device Preview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device selector
                _buildLabel('Device'),
                _buildDeviceDropdown(),

                const SizedBox(height: 16),

                // Orientation toggle
                Row(
                  children: [
                    _buildOrientationButton(Icons.stay_current_portrait, false),
                    const SizedBox(width: 8),
                    _buildOrientationButton(Icons.stay_current_landscape, true),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                const SizedBox(height: 16),

                // Status bar settings
                _buildLabel('Status Bar'),
                _buildCheckbox(
                  'Show status bar',
                  widget.statusBarConfig.visible,
                  (v) => widget.onStatusBarChanged(
                    widget.statusBarConfig.copyWith(visible: v),
                  ),
                ),

                const SizedBox(height: 8),

                // Platform selector
                Row(
                  children: [
                    _buildPlatformChip(PlatformType.iOS),
                    const SizedBox(width: 8),
                    _buildPlatformChip(PlatformType.android),
                  ],
                ),

                const SizedBox(height: 12),

                // Style selector
                Row(
                  children: [
                    _buildStyleChip(StatusBarStyle.dark),
                    const SizedBox(width: 8),
                    _buildStyleChip(StatusBarStyle.light),
                  ],
                ),

                const SizedBox(height: 12),

                // Time input
                _buildLabel('Time'),
                _buildTextInput(
                  widget.statusBarConfig.time,
                  (time) => widget.onStatusBarChanged(
                    widget.statusBarConfig.copyWith(time: time),
                  ),
                ),

                const SizedBox(height: 12),

                // Battery slider
                _buildLabel('Battery ${widget.statusBarConfig.batteryLevel}%'),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.grey[700],
                    thumbColor: Colors.blue,
                  ),
                  child: Slider(
                    value: widget.statusBarConfig.batteryLevel.toDouble(),
                    min: 0,
                    max: 100,
                    onChanged: (v) => widget.onStatusBarChanged(
                      widget.statusBarConfig.copyWith(batteryLevel: v.round()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    );
  }

  Widget _buildDeviceDropdown() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PrototypeDevice>(
          value: widget.selectedDevice,
          isExpanded: true,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: PrototypeDevice.values.map((device) {
            return DropdownMenuItem(
              value: device,
              child: Text('${device.label} (${device.width.toInt()}x${device.height.toInt()})'),
            );
          }).toList(),
          onChanged: (device) {
            if (device != null) {
              widget.onDeviceChanged(device);
            }
          },
        ),
      ),
    );
  }

  Widget _buildOrientationButton(IconData icon, bool isLandscape) {
    final isSelected = widget.isLandscape == isLandscape;
    return InkWell(
      onTap: () => widget.onOrientationChanged(isLandscape),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, void Function(bool) onChanged) {
    return Row(
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
        Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
      ],
    );
  }

  Widget _buildPlatformChip(PlatformType platform) {
    final isSelected = widget.statusBarConfig.platform == platform;
    return InkWell(
      onTap: () => widget.onStatusBarChanged(
        widget.statusBarConfig.copyWith(platform: platform),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          platform.label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStyleChip(StatusBarStyle style) {
    final isSelected = widget.statusBarConfig.style == style;
    return InkWell(
      onTap: () => widget.onStatusBarChanged(
        widget.statusBarConfig.copyWith(style: style),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          style.label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput(String value, void Function(String) onChanged) {
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
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
