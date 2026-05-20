import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 钢琴页面专用的"按键反应式"可视化条带。
///
/// - **能量模型**：维护 `_barCount` 根柱子的标准化能量值（0..1），每帧按
///   `decayPerSecond` 指数衰减；当 [activeNotes] 中出现某个音时，将该音的
///   音高映射到 x 位置，向相邻柱子做高斯扩散注入能量，形成 ADSR 中的
///   attack + sustain。
/// - **环境波**：在所有柱子上叠一层很淡的两段 sin，让空闲时也有"呼吸"
///   节奏，避免可视化区域看起来像静态图。
/// - **渲染**：紫色垂直渐变柱 + 中线下方淡化的镜像反射；柱体使用圆头
///   圆角 (RRect)。
///
/// 后续若接入真实音频 FFT，只需把 [_PianoVisualizerState._injectActiveNotes]
/// 替换成"用 fft 数组覆盖 `_levels`"即可，渲染层无需变更。
class PianoVisualizer extends StatefulWidget {
  const PianoVisualizer({
    required this.activeNotes,
    this.barCount = 80,
    this.height,
    super.key,
  });

  /// 当前按下的琴键集合，元素形如 `C4`/`D#4`/`Bb5`。
  final Set<String> activeNotes;

  /// 柱子数量，默认 80。
  final int barCount;

  /// 显式高度；不指定则填满父级（要求父级有界）。
  final double? height;

  @override
  State<PianoVisualizer> createState() => _PianoVisualizerState();
}

class _PianoVisualizerState extends State<PianoVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _levels;
  late List<double> _ambientPhases;
  Duration _lastTick = Duration.zero;
  double _now = 0;
  // 浮动音符的初始横向比例 + 上下振幅相位
  static const List<_FloatingNote> _floatingNotes = <_FloatingNote>[
    _FloatingNote(
      symbol: '♪',
      xRatio: 0.10,
      yRatio: 0.18,
      phase: 0.0,
      size: 18,
    ),
    _FloatingNote(
      symbol: '♫',
      xRatio: 0.32,
      yRatio: 0.28,
      phase: 1.6,
      size: 16,
    ),
    _FloatingNote(
      symbol: '♩',
      xRatio: 0.55,
      yRatio: 0.22,
      phase: 0.8,
      size: 14,
    ),
    _FloatingNote(
      symbol: '♪',
      xRatio: 0.72,
      yRatio: 0.34,
      phase: 2.3,
      size: 18,
    ),
    _FloatingNote(
      symbol: '♫',
      xRatio: 0.88,
      yRatio: 0.20,
      phase: 0.4,
      size: 16,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _levels = List<double>.filled(widget.barCount, 0);
    _ambientPhases = List<double>.generate(widget.barCount, (i) => i * 0.27);
    _controller =
        AnimationController(
            vsync: this,
            // 任意非零时长，repeat 后会持续触发 listener；只把它当作 ticker。
            duration: const Duration(seconds: 1),
          )
          ..addListener(_onTick)
          ..repeat();
  }

  @override
  void didUpdateWidget(covariant PianoVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _levels = List<double>.filled(widget.barCount, 0);
      _ambientPhases = List<double>.generate(widget.barCount, (i) => i * 0.27);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _onTick() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final dtMs = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final dt = dtMs.clamp(0.0, 0.05); // 限制最大步长，避免后台切回时跳变
    _now += dt;

    // 按时间衰减（每秒衰减到 ~12% — 对应 0.5s 半衰）。
    final decay = math.pow(0.12, dt) as double;
    for (var i = 0; i < _levels.length; i++) {
      _levels[i] = _levels[i] * decay;
    }

    // 注入按键能量
    _injectActiveNotes();

    if (mounted) setState(() {});
  }

  void _injectActiveNotes() {
    if (widget.activeNotes.isEmpty) return;
    for (final note in widget.activeNotes) {
      final pos = _normalizedNotePosition(note);
      if (pos == null) continue;
      final centerBar = (pos * (widget.barCount - 1)).round();
      // 在按键中心扩散到 ±5 根柱子，距离越远高斯权重越小。
      const radius = 5;
      const sigma = 1.6;
      for (var d = -radius; d <= radius; d++) {
        final i = centerBar + d;
        if (i < 0 || i >= widget.barCount) continue;
        final w = math.exp(-(d * d) / (2 * sigma * sigma));
        // 持续按住期间持续注入，配合衰减形成 sustain 包络。
        final inject = 0.85 * w;
        if (inject > _levels[i]) {
          _levels[i] = inject;
        } else {
          // 已经较高时仍然往上推一点，避免持续按键时反而衰减。
          _levels[i] = math.min(1, _levels[i] + inject * 0.18);
        }
      }
    }
  }

  /// 把音名（C4/D#4/Bb5）映射到 [0,1]，以 C2..B6（5 个八度）为可视化范围。
  double? _normalizedNotePosition(String note) {
    if (note.isEmpty) return null;
    final upper = note.toUpperCase();
    int semitone;
    switch (upper[0]) {
      case 'C':
        semitone = 0;
        break;
      case 'D':
        semitone = 2;
        break;
      case 'E':
        semitone = 4;
        break;
      case 'F':
        semitone = 5;
        break;
      case 'G':
        semitone = 7;
        break;
      case 'A':
        semitone = 9;
        break;
      case 'B':
        semitone = 11;
        break;
      default:
        return null;
    }
    var octaveStart = 1;
    if (upper.length > 1) {
      if (upper[1] == '#') {
        semitone += 1;
        octaveStart = 2;
      } else if (upper[1] == 'B') {
        semitone -= 1;
        octaveStart = 2;
      }
    }
    if (octaveStart >= upper.length) return null;
    final octave = int.tryParse(upper.substring(octaveStart));
    if (octave == null) return null;
    final midi = octave * 12 + semitone;
    // 可视化区间：C2 (24) ~ C7 (84)
    const minMidi = 24;
    const maxMidi = 84;
    return ((midi - minMidi) / (maxMidi - minMidi)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final visualizer = LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _VisualizerPainter(
                  levels: _levels,
                  ambientPhases: _ambientPhases,
                  time: _now,
                ),
              ),
            ),
            for (final n in _floatingNotes)
              _FloatingNoteWidget(
                spec: n,
                time: _now,
                parentSize: Size(constraints.maxWidth, constraints.maxHeight),
              ),
          ],
        );
      },
    );

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: visualizer);
    }
    return visualizer;
  }
}

/// 真正负责绘制柱体 + 镜像反射的 painter。
class _VisualizerPainter extends CustomPainter {
  _VisualizerPainter({
    required this.levels,
    required this.ambientPhases,
    required this.time,
  });

  final List<double> levels;
  final List<double> ambientPhases;
  final double time;

  static const _topColor = Color(0xFF8741FF);
  static const _bottomColor = Color(0xFFC8AEFF);
  static const _topMirrorColor = Color(0x668741FF); // 40% alpha
  static const _bottomMirrorColor = Color(0x00C8AEFF); // 0% alpha

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final n = levels.length;
    if (n == 0) return;

    const gap = 3.0;
    final barW = math.max(1.0, (size.width - gap * (n - 1)) / n);
    // 中线略偏下，让上方主体占 60%、镜像占 40%
    final centerY = size.height * 0.62;
    final maxUp = size.height * 0.55;
    final maxDown = size.height * 0.32;
    final radius = Radius.circular(barW / 2);

    for (var i = 0; i < n; i++) {
      // 环境波：两段 sin 叠加 → 形成不规则但平滑的"呼吸"波形。
      final ambient =
          0.05 +
          0.06 *
              ((math.sin(time * 1.6 + ambientPhases[i]) +
                      math.sin(time * 0.9 + ambientPhases[i] * 0.6)) /
                  2);
      final level = (levels[i] + ambient).clamp(0.0, 1.0);
      // 柱高再做一次平滑曲线（pow 0.7），让小幅度更明显，大幅度差不多
      final shaped = math.pow(level, 0.7) as double;

      final x = i * (barW + gap);
      final hUp = shaped * maxUp;
      final hDown = shaped * maxDown;

      // 上半部分主体
      final topRect = Rect.fromLTRB(x, centerY - hUp, x + barW, centerY);
      canvas.drawRRect(
        RRect.fromRectAndRadius(topRect, radius),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, centerY - hUp),
            Offset(0, centerY),
            const <Color>[_topColor, _bottomColor],
          ),
      );

      // 下半部分镜像
      if (hDown > 0.5) {
        final bottomRect = Rect.fromLTRB(x, centerY, x + barW, centerY + hDown);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bottomRect, radius),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, centerY),
              Offset(0, centerY + hDown),
              const <Color>[_topMirrorColor, _bottomMirrorColor],
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter old) {
    if (old.time != time) return true;
    if (old.levels.length != levels.length) return true;
    return false;
  }
}

class _FloatingNote {
  const _FloatingNote({
    required this.symbol,
    required this.xRatio,
    required this.yRatio,
    required this.phase,
    required this.size,
  });

  final String symbol;
  final double xRatio;
  final double yRatio;
  final double phase;
  final double size;
}

class _FloatingNoteWidget extends StatelessWidget {
  const _FloatingNoteWidget({
    required this.spec,
    required this.time,
    required this.parentSize,
  });

  final _FloatingNote spec;
  final double time;
  final Size parentSize;

  @override
  Widget build(BuildContext context) {
    final dy = math.sin(time * 0.9 + spec.phase) * 6;
    final dx = math.cos(time * 0.7 + spec.phase) * 4;
    final opacity = 0.55 + 0.25 * math.sin(time * 1.1 + spec.phase);
    return Positioned(
      left: parentSize.width * spec.xRatio + dx,
      top: parentSize.height * spec.yRatio + dy,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.2, 0.85),
          child: Text(
            spec.symbol,
            style: TextStyle(
              fontSize: spec.size,
              color: const Color(0xFFB68EFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
