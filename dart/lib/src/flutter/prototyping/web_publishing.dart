// Web Publishing for Prototypes
// Convert prototypes to responsive web previews

import 'dart:math' show cos, sin;

import 'package:flutter/material.dart';
import 'interactions.dart';

/// Responsive breakpoint
class Breakpoint {
  final String name;
  final double minWidth;
  final double maxWidth;

  const Breakpoint({
    required this.name,
    required this.minWidth,
    this.maxWidth = double.infinity,
  });

  bool matches(double width) {
    return width >= minWidth && width < maxWidth;
  }

  /// Common breakpoints
  static const mobile = Breakpoint(name: 'Mobile', minWidth: 0, maxWidth: 768);
  static const tablet = Breakpoint(name: 'Tablet', minWidth: 768, maxWidth: 1024);
  static const desktop = Breakpoint(name: 'Desktop', minWidth: 1024, maxWidth: 1440);
  static const largeDesktop = Breakpoint(name: 'Large Desktop', minWidth: 1440);

  static const List<Breakpoint> defaults = [mobile, tablet, desktop, largeDesktop];
}

/// Web publish configuration
class WebPublishConfig {
  final String title;
  final String description;
  final String? faviconUrl;
  final String? ogImageUrl;
  final String? customDomain;
  final bool enableSEO;
  final bool enableAnalytics;
  final bool enablePasswordProtection;
  final String? password;
  final List<Breakpoint> breakpoints;
  final bool enableResponsive;
  final Color backgroundColor;

  const WebPublishConfig({
    this.title = 'Prototype',
    this.description = '',
    this.faviconUrl,
    this.ogImageUrl,
    this.customDomain,
    this.enableSEO = true,
    this.enableAnalytics = false,
    this.enablePasswordProtection = false,
    this.password,
    this.breakpoints = const [],
    this.enableResponsive = true,
    this.backgroundColor = Colors.white,
  });

  WebPublishConfig copyWith({
    String? title,
    String? description,
    String? faviconUrl,
    String? ogImageUrl,
    String? customDomain,
    bool? enableSEO,
    bool? enableAnalytics,
    bool? enablePasswordProtection,
    String? password,
    List<Breakpoint>? breakpoints,
    bool? enableResponsive,
    Color? backgroundColor,
  }) {
    return WebPublishConfig(
      title: title ?? this.title,
      description: description ?? this.description,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      ogImageUrl: ogImageUrl ?? this.ogImageUrl,
      customDomain: customDomain ?? this.customDomain,
      enableSEO: enableSEO ?? this.enableSEO,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      enablePasswordProtection: enablePasswordProtection ?? this.enablePasswordProtection,
      password: password ?? this.password,
      breakpoints: breakpoints ?? this.breakpoints,
      enableResponsive: enableResponsive ?? this.enableResponsive,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

/// Published prototype info
class PublishedPrototype {
  final String id;
  final String url;
  final String embedCode;
  final DateTime publishedAt;
  final WebPublishConfig config;

  const PublishedPrototype({
    required this.id,
    required this.url,
    required this.embedCode,
    required this.publishedAt,
    required this.config,
  });
}

/// Web publishing engine
class WebPublishingEngine {
  /// Generate a shareable URL (mock)
  Future<PublishedPrototype> publish({
    required String prototypeId,
    required WebPublishConfig config,
  }) async {
    // Simulate publishing delay
    await Future.delayed(const Duration(seconds: 1));

    final publishId = 'pub_${DateTime.now().millisecondsSinceEpoch}';
    final url = 'https://prototype.example.com/$publishId';

    return PublishedPrototype(
      id: publishId,
      url: url,
      embedCode: _generateEmbedCode(url, config),
      publishedAt: DateTime.now(),
      config: config,
    );
  }

  String _generateEmbedCode(String url, WebPublishConfig config) {
    return '''<iframe
  src="$url"
  width="100%"
  height="600"
  style="border: none; border-radius: 8px;"
  title="${config.title}"
  allow="fullscreen"
></iframe>''';
  }

  /// Generate HTML preview
  String generateHTMLPreview({
    required String prototypeId,
    required WebPublishConfig config,
  }) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${config.title}</title>
  <meta name="description" content="${config.description}">
  ${config.faviconUrl != null ? '<link rel="icon" href="${config.faviconUrl}">' : ''}
  ${config.enableSEO ? '''
  <meta property="og:title" content="${config.title}">
  <meta property="og:description" content="${config.description}">
  ${config.ogImageUrl != null ? '<meta property="og:image" content="${config.ogImageUrl}">' : ''}
  ''' : ''}
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: ${_colorToHex(config.backgroundColor)};
      min-height: 100vh;
    }
    .prototype-container {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
    }
    .prototype-frame {
      background: white;
      border-radius: 40px;
      overflow: hidden;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    }
    ${_generateResponsiveCSS(config)}
  </style>
</head>
<body>
  <div class="prototype-container">
    <div class="prototype-frame" id="prototype">
      <!-- Prototype content would be rendered here -->
      <div style="padding: 40px; text-align: center;">
        <h1>Prototype Preview</h1>
        <p>ID: $prototypeId</p>
      </div>
    </div>
  </div>
  ${config.enableAnalytics ? '<script>/* Analytics code */</script>' : ''}
</body>
</html>''';
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
  }

  String _generateResponsiveCSS(WebPublishConfig config) {
    if (!config.enableResponsive) return '';

    final breakpoints = config.breakpoints.isEmpty
        ? Breakpoint.defaults
        : config.breakpoints;

    final css = StringBuffer();

    for (final bp in breakpoints) {
      if (bp.maxWidth == double.infinity) {
        css.writeln('@media (min-width: ${bp.minWidth}px) {');
      } else {
        css.writeln(
            '@media (min-width: ${bp.minWidth}px) and (max-width: ${bp.maxWidth - 1}px) {');
      }

      // Add breakpoint-specific styles
      switch (bp.name) {
        case 'Mobile':
          css.writeln('  .prototype-frame { width: 375px; height: 812px; }');
          break;
        case 'Tablet':
          css.writeln('  .prototype-frame { width: 768px; height: 1024px; }');
          break;
        case 'Desktop':
          css.writeln('  .prototype-frame { width: 1280px; height: 800px; border-radius: 8px; }');
          break;
        default:
          css.writeln('  .prototype-frame { width: 1440px; height: 900px; border-radius: 8px; }');
      }

      css.writeln('}');
    }

    return css.toString();
  }
}

/// Responsive preview widget
class ResponsivePreview extends StatefulWidget {
  final Widget child;
  final List<Breakpoint> breakpoints;
  final Breakpoint? initialBreakpoint;

  const ResponsivePreview({
    super.key,
    required this.child,
    this.breakpoints = const [],
    this.initialBreakpoint,
  });

  @override
  State<ResponsivePreview> createState() => _ResponsivePreviewState();
}

class _ResponsivePreviewState extends State<ResponsivePreview> {
  late Breakpoint _currentBreakpoint;
  late List<Breakpoint> _breakpoints;

  @override
  void initState() {
    super.initState();
    _breakpoints = widget.breakpoints.isEmpty
        ? Breakpoint.defaults
        : widget.breakpoints;
    _currentBreakpoint = widget.initialBreakpoint ?? _breakpoints.first;
  }

  Size _getSizeForBreakpoint(Breakpoint breakpoint) {
    switch (breakpoint.name) {
      case 'Mobile':
        return const Size(375, 812);
      case 'Tablet':
        return const Size(768, 1024);
      case 'Desktop':
        return const Size(1280, 800);
      case 'Large Desktop':
        return const Size(1440, 900);
      default:
        return Size(breakpoint.minWidth, 800);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _getSizeForBreakpoint(_currentBreakpoint);

    return Column(
      children: [
        // Breakpoint selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[850],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _breakpoints.map((bp) {
              final isSelected = bp.name == _currentBreakpoint.name;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _BreakpointButton(
                  breakpoint: bp,
                  isSelected: isSelected,
                  onTap: () => setState(() => _currentBreakpoint = bp),
                ),
              );
            }).toList(),
          ),
        ),

        // Preview area
        Expanded(
          child: Center(
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                    _currentBreakpoint.name == 'Mobile' ? 40 : 8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.child,
            ),
          ),
        ),

        // Size indicator
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[900],
          child: Text(
            '${size.width.toInt()} × ${size.height.toInt()}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _BreakpointButton extends StatelessWidget {
  final Breakpoint breakpoint;
  final bool isSelected;
  final VoidCallback onTap;

  const _BreakpointButton({
    required this.breakpoint,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIcon(),
              color: isSelected ? Colors.white : Colors.grey[400],
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              breakpoint.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (breakpoint.name) {
      case 'Mobile':
        return Icons.smartphone;
      case 'Tablet':
        return Icons.tablet;
      case 'Desktop':
        return Icons.computer;
      case 'Large Desktop':
        return Icons.desktop_mac;
      default:
        return Icons.devices;
    }
  }
}

/// Web publishing panel
class WebPublishingPanel extends StatefulWidget {
  final String prototypeId;
  final void Function(PublishedPrototype) onPublished;

  const WebPublishingPanel({
    super.key,
    required this.prototypeId,
    required this.onPublished,
  });

  @override
  State<WebPublishingPanel> createState() => _WebPublishingPanelState();
}

class _WebPublishingPanelState extends State<WebPublishingPanel> {
  final _engine = WebPublishingEngine();
  WebPublishConfig _config = const WebPublishConfig();
  PublishedPrototype? _published;
  bool _isPublishing = false;

  Future<void> _publish() async {
    setState(() => _isPublishing = true);

    final result = await _engine.publish(
      prototypeId: widget.prototypeId,
      config: _config,
    );

    setState(() {
      _isPublishing = false;
      _published = result;
    });

    widget.onPublished(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.teal[700]!],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.public, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Publish to Web',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  _buildLabel('Title'),
                  _buildTextInput(
                    _config.title,
                    'Prototype title',
                    (v) => setState(() => _config = _config.copyWith(title: v)),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  _buildLabel('Description'),
                  _buildTextInput(
                    _config.description,
                    'Brief description',
                    (v) => setState(
                        () => _config = _config.copyWith(description: v)),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Options
                  _buildLabel('Options'),
                  _buildCheckbox(
                    'Enable responsive preview',
                    _config.enableResponsive,
                    (v) => setState(
                        () => _config = _config.copyWith(enableResponsive: v)),
                  ),
                  _buildCheckbox(
                    'Enable SEO',
                    _config.enableSEO,
                    (v) => setState(
                        () => _config = _config.copyWith(enableSEO: v)),
                  ),
                  _buildCheckbox(
                    'Enable analytics',
                    _config.enableAnalytics,
                    (v) => setState(
                        () => _config = _config.copyWith(enableAnalytics: v)),
                  ),
                  _buildCheckbox(
                    'Password protection',
                    _config.enablePasswordProtection,
                    (v) => setState(() =>
                        _config = _config.copyWith(enablePasswordProtection: v)),
                  ),

                  if (_config.enablePasswordProtection) ...[
                    const SizedBox(height: 8),
                    _buildTextInput(
                      _config.password ?? '',
                      'Enter password',
                      (v) =>
                          setState(() => _config = _config.copyWith(password: v)),
                      obscure: true,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Custom domain
                  _buildLabel('Custom Domain (optional)'),
                  _buildTextInput(
                    _config.customDomain ?? '',
                    'e.g., prototype.yoursite.com',
                    (v) => setState(
                        () => _config = _config.copyWith(customDomain: v)),
                  ),

                  const SizedBox(height: 24),

                  // Publish button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isPublishing ? null : _publish,
                      icon: _isPublishing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload, size: 18),
                      label: Text(_isPublishing ? 'Publishing...' : 'Publish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  // Published result
                  if (_published != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Published!',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildLabel('URL'),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _published!.url,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                color: Colors.grey[400],
                                onPressed: () {
                                  // Copy to clipboard
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildLabel('Embed Code'),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _published!.embedCode,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildTextInput(
    String value,
    String hint,
    void Function(String) onChanged, {
    int maxLines = 1,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: TextEditingController(text: value),
        maxLines: maxLines,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, void Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
        ],
      ),
    );
  }
}

/// Prototype mode toggle and canvas overlay
class PrototypeModeOverlay extends StatelessWidget {
  final bool isPrototypeMode;
  final List<FlowConnection> connections;
  final VoidCallback onToggleMode;

  const PrototypeModeOverlay({
    super.key,
    required this.isPrototypeMode,
    required this.connections,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Connection arrows
        if (isPrototypeMode)
          CustomPaint(
            size: Size.infinite,
            painter: _ConnectionPainter(connections: connections),
          ),

        // Mode toggle button
        Positioned(
          top: 16,
          right: 16,
          child: _ModeToggle(
            isPrototypeMode: isPrototypeMode,
            onToggle: onToggleMode,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool isPrototypeMode;
  final VoidCallback onToggle;

  const _ModeToggle({
    required this.isPrototypeMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            icon: Icons.edit,
            label: 'Design',
            isActive: !isPrototypeMode,
            onTap: isPrototypeMode ? onToggle : null,
          ),
          _ModeButton(
            icon: Icons.play_arrow,
            label: 'Prototype',
            isActive: isPrototypeMode,
            onTap: !isPrototypeMode ? onToggle : null,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey[400]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlowConnection {
  final Offset start;
  final Offset end;
  final Color color;

  const FlowConnection({
    required this.start,
    required this.end,
    this.color = Colors.blue,
  });
}

class _ConnectionPainter extends CustomPainter {
  final List<FlowConnection> connections;

  _ConnectionPainter({required this.connections});

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      final paint = Paint()
        ..color = connection.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(connection.start.dx, connection.start.dy);

      // Curved line
      final controlX = (connection.start.dx + connection.end.dx) / 2;
      path.quadraticBezierTo(
        controlX,
        connection.start.dy,
        connection.end.dx,
        connection.end.dy,
      );

      canvas.drawPath(path, paint);

      // Arrow head
      _drawArrow(canvas, connection.end, connection.start, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset from, Paint paint) {
    final direction = (tip - from);
    final angle = direction.direction;
    const arrowSize = 10.0;

    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(
      tip.dx - arrowSize * cos(angle - 0.5),
      tip.dy - arrowSize * sin(angle - 0.5),
    );
    path.lineTo(
      tip.dx - arrowSize * cos(angle + 0.5),
      tip.dy - arrowSize * sin(angle + 0.5),
    );
    path.close();

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(_ConnectionPainter oldDelegate) {
    return connections != oldDelegate.connections;
  }
}
