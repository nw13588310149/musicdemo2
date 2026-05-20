import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';

/// 沉浸模式下的统一媒体播放壳：
/// - **图片**：盖一张大图 + 加载/失败兜底
/// - **视频**：基于 `media_kit` 的内联视频播放（自动播放，离开/dispose 释放）
/// - **音频**：渐变封面 + 中央 play/pause + 底部进度条
///
/// 之所以做成单独 widget 而不是写在 `_ImmersiveSlide` 里，是因为它需要
/// `StatefulWidget` 持有 `Player`/`VideoController`，并保证翻页时
/// **彻底 dispose 旧的 Player**（不然多个 voice 同时在响、退出再进还会"漏播"）。
class CircleMediaPlayer extends StatefulWidget {
  const CircleMediaPlayer({
    super.key,
    required this.post,
    this.autoPlay = true,
  });

  final CirclePost post;

  /// 内联视频/音频是否自动开始播放。默认 true（沉浸模式翻到这一帧就播）。
  final bool autoPlay;

  @override
  State<CircleMediaPlayer> createState() => _CircleMediaPlayerState();
}

class _CircleMediaPlayerState extends State<CircleMediaPlayer> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playingSub;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _setupForCurrentPost();
  }

  @override
  void didUpdateWidget(covariant CircleMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.primaryMediaUrl != widget.post.primaryMediaUrl ||
        oldWidget.post.mediaKind != widget.post.mediaKind) {
      _teardownPlayer();
      _setupForCurrentPost();
    }
  }

  void _setupForCurrentPost() {
    final url = widget.post.primaryMediaUrl;
    if (url.isEmpty) return;
    if (widget.post.mediaKind == PostMediaKind.image) return;

    final player = Player();
    _player = player;
    if (widget.post.mediaKind == PostMediaKind.video) {
      _videoController = VideoController(player);
    }
    _posSub = player.stream.position.listen((p) {
      if (_disposed) return;
      setState(() => _position = p);
    });
    _durSub = player.stream.duration.listen((d) {
      if (_disposed) return;
      setState(() => _duration = d);
    });
    _playingSub = player.stream.playing.listen((p) {
      if (_disposed) return;
      setState(() => _isPlaying = p);
    });
    unawaited(player.open(Media(url), play: widget.autoPlay));
  }

  void _teardownPlayer() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _posSub = _durSub = null;
    _playingSub = null;
    final player = _player;
    if (player != null) {
      // 同步 pause 让声音/画面立刻消失，再 unawaited dispose 释放原生资源。
      try {
        unawaited(player.pause());
      } catch (_) {}
      unawaited(player.dispose());
    }
    _player = null;
    _videoController = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  @override
  void dispose() {
    _disposed = true;
    _teardownPlayer();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.post.mediaKind) {
      PostMediaKind.image => _ImageBackdrop(url: widget.post.imageUrl),
      PostMediaKind.video => _buildVideoBody(),
      PostMediaKind.audio => _buildAudioBody(),
    };
  }

  Widget _buildVideoBody() {
    final controller = _videoController;
    final url = widget.post.primaryMediaUrl;
    if (url.isEmpty || controller == null) {
      return _ImageBackdrop(url: widget.post.imageUrl);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
          controller: controller,
          fit: BoxFit.contain,
          controls: NoVideoControls,
        ),
        // 用一层透明 GestureDetector 接管点击播放/暂停，比 chewie 更轻量。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: AnimatedOpacity(
              opacity: _isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Center(child: _BigPlayButton()),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ProgressBar(
            position: _position,
            duration: _duration,
            onSeek: (target) => unawaited(_player?.seek(target) ?? Future.value()),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.post.imageUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: const ColorFilter.mode(
              Color(0x55000000),
              BlendMode.darken,
            ),
            child: Image.network(
              widget.post.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _AudioBackdrop(),
            ),
          )
        else
          const _AudioBackdrop(),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: Center(
              child: _BigPlayButton(playing: _isPlaying),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ProgressBar(
            position: _position,
            duration: _duration,
            onSeek: (target) => unawaited(_player?.seek(target) ?? Future.value()),
          ),
        ),
      ],
    );
  }
}

class _ImageBackdrop extends StatelessWidget {
  const _ImageBackdrop({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(color: Color(0xFF1B1530));
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) =>
          const ColoredBox(color: Color(0xFF1B1530)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(color: Color(0xFF1B1530));
      },
    );
  }
}

class _AudioBackdrop extends StatelessWidget {
  const _AudioBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1E66), Color(0xFF0B081A)],
        ),
      ),
    );
  }
}

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({this.playing = false});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(76),
      height: ui(76),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
      ),
      child: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: ui(44),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final total = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final ratio = (position.inMilliseconds / total).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(80)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _emit(d.localPosition.dx, width),
                onHorizontalDragUpdate: (d) =>
                    _emit(d.localPosition.dx, width),
                child: SizedBox(
                  height: ui(20),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: ui(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(ui(2)),
                        ),
                      ),
                      Container(
                        height: ui(3),
                        width: width * ratio,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ui(2)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: ui(6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(12),
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
              Text(
                _fmt(duration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: ui(12),
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _emit(double dx, double width) {
    if (width <= 0 || duration.inMilliseconds <= 0) return;
    final r = (dx / width).clamp(0.0, 1.0);
    final target = Duration(
      milliseconds: (duration.inMilliseconds * r).round(),
    );
    onSeek(target);
  }

  static String _fmt(Duration d) {
    if (d == Duration.zero) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
