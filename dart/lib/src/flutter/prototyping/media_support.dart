// Media Support for Prototyping
// Video and GIF playback in prototypes

import 'dart:async';
import 'package:flutter/material.dart';

/// Media type
enum MediaType {
  video('Video'),
  gif('GIF'),
  image('Image'),
  lottie('Lottie');

  final String label;
  const MediaType(this.label);
}

/// Video playback state
enum PlaybackState {
  idle,
  loading,
  playing,
  paused,
  stopped,
  error,
}

/// Media configuration
class MediaConfig {
  final String id;
  final MediaType type;
  final String source;
  final bool autoPlay;
  final bool loop;
  final bool muted;
  final double volume;
  final bool showControls;
  final BoxFit fit;
  final Duration? startTime;
  final Duration? endTime;

  const MediaConfig({
    required this.id,
    required this.type,
    required this.source,
    this.autoPlay = true,
    this.loop = true,
    this.muted = false,
    this.volume = 1.0,
    this.showControls = false,
    this.fit = BoxFit.cover,
    this.startTime,
    this.endTime,
  });

  MediaConfig copyWith({
    String? id,
    MediaType? type,
    String? source,
    bool? autoPlay,
    bool? loop,
    bool? muted,
    double? volume,
    bool? showControls,
    BoxFit? fit,
    Duration? startTime,
    Duration? endTime,
  }) {
    return MediaConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      source: source ?? this.source,
      autoPlay: autoPlay ?? this.autoPlay,
      loop: loop ?? this.loop,
      muted: muted ?? this.muted,
      volume: volume ?? this.volume,
      showControls: showControls ?? this.showControls,
      fit: fit ?? this.fit,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'source': source,
      'autoPlay': autoPlay,
      'loop': loop,
      'muted': muted,
      'volume': volume,
      'showControls': showControls,
      'fit': fit.name,
      'startTimeMs': startTime?.inMilliseconds,
      'endTimeMs': endTime?.inMilliseconds,
    };
  }

  factory MediaConfig.fromMap(Map<String, dynamic> map) {
    return MediaConfig(
      id: map['id'],
      type: MediaType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MediaType.video,
      ),
      source: map['source'],
      autoPlay: map['autoPlay'] ?? true,
      loop: map['loop'] ?? true,
      muted: map['muted'] ?? false,
      volume: (map['volume'] ?? 1.0).toDouble(),
      showControls: map['showControls'] ?? false,
      fit: BoxFit.values.firstWhere(
        (e) => e.name == map['fit'],
        orElse: () => BoxFit.cover,
      ),
      startTime: map['startTimeMs'] != null
          ? Duration(milliseconds: map['startTimeMs'])
          : null,
      endTime: map['endTimeMs'] != null
          ? Duration(milliseconds: map['endTimeMs'])
          : null,
    );
  }
}

/// Media controller for playback control
class PrototypeMediaController extends ChangeNotifier {
  PlaybackState _state = PlaybackState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _muted = false;
  Timer? _positionTimer;

  PlaybackState get state => _state;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get muted => _muted;
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0;

  void play() {
    _state = PlaybackState.playing;
    _startPositionTimer();
    notifyListeners();
  }

  void pause() {
    _state = PlaybackState.paused;
    _stopPositionTimer();
    notifyListeners();
  }

  void stop() {
    _state = PlaybackState.stopped;
    _position = Duration.zero;
    _stopPositionTimer();
    notifyListeners();
  }

  void seekTo(Duration position) {
    _position = position;
    notifyListeners();
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
  }

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_state == PlaybackState.playing) {
        _position += const Duration(milliseconds: 100);
        if (_position >= _duration && _duration > Duration.zero) {
          _position = Duration.zero; // Loop
        }
        notifyListeners();
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void setDuration(Duration duration) {
    _duration = duration;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPositionTimer();
    super.dispose();
  }
}

/// Placeholder video player widget (simulates video playback)
/// In a real implementation, this would use video_player package
class PrototypeVideoPlayer extends StatefulWidget {
  final MediaConfig config;
  final PrototypeMediaController? controller;
  final void Function(PrototypeMediaController)? onControllerCreated;

  const PrototypeVideoPlayer({
    super.key,
    required this.config,
    this.controller,
    this.onControllerCreated,
  });

  @override
  State<PrototypeVideoPlayer> createState() => _PrototypeVideoPlayerState();
}

class _PrototypeVideoPlayerState extends State<PrototypeVideoPlayer> {
  late PrototypeMediaController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = PrototypeMediaController();
      _ownsController = true;
      widget.onControllerCreated?.call(_controller);
    }

    // Simulate loading
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.setDuration(const Duration(seconds: 30));
        if (widget.config.autoPlay) {
          _controller.play();
        }
      }
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Video placeholder
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _controller.state == PlaybackState.playing
                          ? Icons.play_circle_filled
                          : Icons.pause_circle_filled,
                      color: Colors.white.withOpacity(0.5),
                      size: 64,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.config.source.split('/').last,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDuration(_controller.position)} / ${_formatDuration(_controller.duration)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controls overlay
            if (widget.config.showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildControls(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _controller.progress,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds:
                      (value * _controller.duration.inMilliseconds).round(),
                );
                _controller.seekTo(newPosition);
              },
            ),
          ),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _controller.muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _controller.toggleMute,
              ),
              IconButton(
                icon: Icon(
                  _controller.state == PlaybackState.playing
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  if (_controller.state == PlaybackState.playing) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white, size: 20),
                onPressed: _controller.stop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// GIF player widget (simulates animated GIF)
class PrototypeGifPlayer extends StatefulWidget {
  final MediaConfig config;
  final Widget? placeholder;

  const PrototypeGifPlayer({
    super.key,
    required this.config,
    this.placeholder,
  });

  @override
  State<PrototypeGifPlayer> createState() => _PrototypeGifPlayerState();
}

class _PrototypeGifPlayerState extends State<PrototypeGifPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.config.autoPlay) {
      if (widget.config.loop) {
        _controller.repeat();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            border: Border.all(
              color: Colors.grey[600]!,
              width: 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Animated placeholder
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: _controller,
                      child: Icon(
                        Icons.gif_box,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.config.source.split('/').last,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'GIF Placeholder',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Play indicator
              if (!widget.config.autoPlay && _controller.status != AnimationStatus.forward)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (widget.config.loop) {
                        _controller.repeat();
                      } else {
                        _controller.forward();
                      }
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Media embed widget (auto-selects player based on type)
class PrototypeMediaEmbed extends StatelessWidget {
  final MediaConfig config;
  final PrototypeMediaController? controller;

  const PrototypeMediaEmbed({
    super.key,
    required this.config,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    switch (config.type) {
      case MediaType.video:
        return PrototypeVideoPlayer(
          config: config,
          controller: controller,
        );
      case MediaType.gif:
        return PrototypeGifPlayer(config: config);
      case MediaType.image:
        return _buildImagePlaceholder();
      case MediaType.lottie:
        return _buildLottiePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              config.source.split('/').last,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLottiePlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.animation, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Lottie Animation',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            Text(
              config.source.split('/').last,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Media configuration panel
class MediaConfigPanel extends StatefulWidget {
  final MediaConfig config;
  final void Function(MediaConfig) onConfigChanged;

  const MediaConfigPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<MediaConfigPanel> createState() => _MediaConfigPanelState();
}

class _MediaConfigPanelState extends State<MediaConfigPanel> {
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
              'Media Settings',
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
                // Media type
                _buildLabel('Type'),
                _buildTypeSelector(),

                const SizedBox(height: 16),

                // Source URL
                _buildLabel('Source'),
                _buildTextInput(
                  widget.config.source,
                  'Enter URL or path',
                  (source) => widget.onConfigChanged(
                    widget.config.copyWith(source: source),
                  ),
                ),

                const SizedBox(height: 16),

                // Playback options
                _buildCheckbox(
                  'Auto play',
                  widget.config.autoPlay,
                  (v) => widget.onConfigChanged(
                    widget.config.copyWith(autoPlay: v),
                  ),
                ),
                _buildCheckbox(
                  'Loop',
                  widget.config.loop,
                  (v) => widget.onConfigChanged(
                    widget.config.copyWith(loop: v),
                  ),
                ),
                _buildCheckbox(
                  'Muted',
                  widget.config.muted,
                  (v) => widget.onConfigChanged(
                    widget.config.copyWith(muted: v),
                  ),
                ),
                _buildCheckbox(
                  'Show controls',
                  widget.config.showControls,
                  (v) => widget.onConfigChanged(
                    widget.config.copyWith(showControls: v),
                  ),
                ),

                const SizedBox(height: 16),

                // Fit mode
                _buildLabel('Fit'),
                _buildFitSelector(),

                const SizedBox(height: 16),

                // Volume slider
                if (widget.config.type == MediaType.video) ...[
                  _buildLabel('Volume ${(widget.config.volume * 100).round()}%'),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Colors.grey[700],
                      thumbColor: Colors.blue,
                    ),
                    child: Slider(
                      value: widget.config.volume,
                      min: 0,
                      max: 1,
                      onChanged: (v) => widget.onConfigChanged(
                        widget.config.copyWith(volume: v),
                      ),
                    ),
                  ),
                ],
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

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      children: MediaType.values.map((type) {
        final isSelected = widget.config.type == type;
        return InkWell(
          onTap: () => widget.onConfigChanged(
            widget.config.copyWith(type: type),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type.label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFitSelector() {
    final fits = [BoxFit.cover, BoxFit.contain, BoxFit.fill, BoxFit.none];
    return Wrap(
      spacing: 8,
      children: fits.map((fit) {
        final isSelected = widget.config.fit == fit;
        return InkWell(
          onTap: () => widget.onConfigChanged(
            widget.config.copyWith(fit: fit),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              fit.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(
    String value,
    String hint,
    void Function(String) onChanged,
  ) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: TextEditingController(text: value),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
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
              activeColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
        ],
      ),
    );
  }
}
