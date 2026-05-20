import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';
import '../data/piano_key_specs.dart';

/// 全局共享的虚拟钢琴键盘组件。
///
/// 行为对齐 `the-road-of-music/pages/music/VirtualPiano.vue`：
///
/// - 35 白键 + 25 黑键的全键盘（C2-B6），可水平滚动。
/// - 顶部工具条：缩小、mini 预览滚动条、放大、显示/隐藏标签开关。
/// - 多指按下、跨键拖动（按下→滑入下一键自动 release 旧键 + press 新键）。
/// - 中央 C 红色高亮、可选简谱+音名标签。
///
/// 使用方只需提供 [activeNotes] 用于高亮显示，以及 [onPress]/[onRelease] 用于
/// 触发音频播放。Widget 内部维护缩放、滚动、标签开关等纯 UI 状态。
class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    required this.activeNotes,
    required this.onPress,
    required this.onRelease,
    this.height = 220,
    this.borderRadius = 16,
    this.showChrome = true,
    this.minWhiteKeyWidth = 36,
    this.maxWhiteKeyWidth = 92,
    this.zoomStep = 8,
    this.initialWhiteKeyWidth,
    this.initialLabelsVisible = false,
    this.initialScrollToCenterC = true,
    this.whiteKeys = kPianoFullWhiteKeys,
    this.blackKeys = kPianoFullBlackKeys,
    super.key,
  });

  /// 当前被按下的 token 集合（如 {"C4", "F#4"}），用于渲染高亮。
  final Set<String> activeNotes;

  /// 按下回调，可异步（用于解锁音频上下文等）。
  final Future<void> Function(String token) onPress;

  /// 抬起回调，应保证幂等（同一 token 多次 release 不出错）。
  final void Function(String token) onRelease;

  /// 键盘内容（不含顶部工具条）的高度。
  final double height;

  /// 整体外框圆角。
  final double borderRadius;

  /// 是否显示顶部工具条（- / 滚动条 / + / 切换）。
  final bool showChrome;

  /// 白键宽度的最小/最大限制以及每次缩放步长。
  final double minWhiteKeyWidth;
  final double maxWhiteKeyWidth;
  final double zoomStep;

  /// 初始白键宽度。为 null 时按视口尽量铺满 17 个白键。
  final double? initialWhiteKeyWidth;

  /// 是否初始显示音名 / 简谱标签。
  final bool initialLabelsVisible;

  /// 初始是否把视口滚动到「键盘内容几何中点」（与 1.0 VirtualPiano.vue
  /// 一致：`left = (100 - allWidth) / 2`）。中央 C 会自然落在视口中部偏左、
  /// 左右各显示约一个 octave。字段保留旧名以避免破坏外部调用方。
  final bool initialScrollToCenterC;

  /// 自定义键位（默认全键盘 C2-B6）。
  final List<PianoKeySpec> whiteKeys;
  final List<PianoKeySpec> blackKeys;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  /// 用 ScrollController 来双向同步：键盘滚动 ↔ mini 预览缩略图的 thumb。
  final ScrollController _scroll = ScrollController();

  /// pointerId → 当前所按 key token，用于跨键滑动时正确 release。
  final Map<int, String> _pointerToken = <int, String>{};

  /// 命中测试缓存。在 LayoutBuilder 阶段重建。
  final List<_KeyHitRect> _hitRects = <_KeyHitRect>[];

  /// 当前白键宽度（逻辑像素），决定整个键盘内容宽度。
  double? _whiteKeyWidth;

  late bool _labelsVisible;

  bool _appliedInitialScroll = false;

  /// 仅做一次：4 张键贴图的 ImageProvider 预解码，
  /// 避免首次进入时白键露出底部暗色背景"黑一下"。
  bool _precachedKeyAssets = false;

  @override
  void initState() {
    super.initState();
    _labelsVisible = widget.initialLabelsVisible;
    _whiteKeyWidth = widget.initialWhiteKeyWidth;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precachedKeyAssets) {
      _precachedKeyAssets = true;
      // 把 4 张键贴图丢进 ImageCache。即使首帧渲染时还没解码完，
      // 第二帧（约 16ms 后）就会拿到结果；配合下面 _PianoWhiteKey /
      // _PianoBlackKey 的 frameBuilder 占位色，实际看不到"黑一下"。
      for (final asset in const <String>[
        _whiteIdleAsset,
        _whitePressedAsset,
        _blackIdleAsset,
        _blackPressedAsset,
      ]) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _zoomIn() {
    if (_whiteKeyWidth == null) {
      return;
    }
    final next = math.min(
      _whiteKeyWidth! + widget.zoomStep,
      widget.maxWhiteKeyWidth,
    );
    if (next == _whiteKeyWidth) {
      return;
    }
    setState(() => _whiteKeyWidth = next);
  }

  void _zoomOut() {
    if (_whiteKeyWidth == null) {
      return;
    }
    final next = math.max(
      _whiteKeyWidth! - widget.zoomStep,
      widget.minWhiteKeyWidth,
    );
    if (next == _whiteKeyWidth) {
      return;
    }
    setState(() => _whiteKeyWidth = next);
  }

  void _toggleLabels() {
    setState(() => _labelsVisible = !_labelsVisible);
  }

  /// 把整段键盘内容的几何中点对到视口中央（= maxScrollExtent / 2）。
  ///
  /// 对齐 1.0 `the-road-of-music/pages/music/VirtualPiano.vue` 的初始
  /// 滚动逻辑：`left = (100 - allWidth) / 2`。35 个白键的几何中点在
  /// idx ≈ 17（F4 附近），中央 C 自然落在视口中部偏左、左右各能看到约
  /// 一个 octave 的键。这样的"键盘居中"符合用户对默认视图的预期；如果
  /// 改成把 C4 钉在视口正中（如旧实现），左侧只能露出 5–6 个白键、
  /// 右侧能露出 8–9 个，整个键盘视觉上会"偏左"。
  ///
  /// 在原始几何中点的基础上，按用户要求再向右平移一个白键宽度——
  /// 这样默认视口显示的中央 C 会更贴近视觉正中，整体键盘在视觉上
  /// 不再偏左。clamp 防止键盘宽度不足以滚动时越界。
  void _scrollToContentCenter({required double viewportWidth}) {
    final whiteKeyWidth = _whiteKeyWidth;
    if (whiteKeyWidth == null) {
      return;
    }
    final contentWidth = widget.whiteKeys.length * whiteKeyWidth;
    final maxOffset = math.max(0.0, contentWidth - viewportWidth);
    if (_scroll.hasClients) {
      final target = (maxOffset / 2 + whiteKeyWidth).clamp(0.0, maxOffset);
      _scroll.jumpTo(target);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final token = _hitTest(event.localPosition);
    if (token == null) {
      return;
    }
    _pointerToken[event.pointer] = token;
    widget.onPress(token);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final token = _hitTest(event.localPosition);
    final old = _pointerToken[event.pointer];
    if (token == old) {
      return;
    }
    if (old != null) {
      widget.onRelease(old);
    }
    if (token != null) {
      _pointerToken[event.pointer] = token;
      widget.onPress(token);
    } else {
      _pointerToken.remove(event.pointer);
    }
  }

  void _onPointerUpOrCancel(int pointer) {
    final token = _pointerToken.remove(pointer);
    if (token != null) {
      widget.onRelease(token);
    }
  }

  /// 命中测试：先黑键（在上层），后白键。
  ///
  /// `Listener` 位于 `SingleChildScrollView` 的内层 `SizedBox` 里，
  /// 其 `localPosition` 已包含滚动量（即内容坐标），不要再叠加 `scroll.offset`。
  String? _hitTest(Offset localPos) {
    final x = localPos.dx;
    final y = localPos.dy;
    // 黑键优先
    for (final hit in _hitRects) {
      if (!hit.isBlack) {
        continue;
      }
      if (hit.rect.contains(Offset(x, y))) {
        return hit.token;
      }
    }
    for (final hit in _hitRects) {
      if (hit.isBlack) {
        continue;
      }
      if (hit.rect.contains(Offset(x, y))) {
        return hit.token;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final chromeHeight = widget.showChrome ? ui(38) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 父级未限制高度时（比如直接放在 Column 里），用 widget.height 作为兜底，
        // 否则白键填满父级给到的全部高度。
        final fallbackTotal = ui(widget.height) + chromeHeight;
        final totalHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : fallbackTotal;

        return SizedBox(
          height: totalHeight,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ui(widget.borderRadius)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0x1F111827),
                  blurRadius: ui(14),
                  offset: Offset(0, ui(8)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(widget.borderRadius)),
              child: Container(
                color: const Color(0xFF1A1C21),
                child: Column(
                  children: <Widget>[
                    if (widget.showChrome) _buildChrome(context, chromeHeight),
                    Expanded(child: _buildKeyboardArea(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChrome(BuildContext context, double height) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(6)),
        child: Row(
          children: [
            _PianoChromeImageButton(
              asset: 'assets/images/home/dictation/3.png',
              size: ui(26),
              onTap: _zoomOut,
              tooltip: '缩小',
            ),
            SizedBox(width: ui(8)),
            Expanded(
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  return _PianoMiniScrollTrack(
                    whiteKeys: widget.whiteKeys,
                    blackKeys: widget.blackKeys,
                    contentWidth:
                        (_whiteKeyWidth ?? 0) * widget.whiteKeys.length,
                    viewportWidth: _scroll.hasClients
                        ? _scroll.position.viewportDimension
                        : 0,
                    scrollOffset: _scroll.hasClients ? _scroll.offset : 0,
                    onThumbDrag: (deltaFraction) {
                      if (!_scroll.hasClients) {
                        return;
                      }
                      final maxOffset = _scroll.position.maxScrollExtent;
                      final next = (_scroll.offset + deltaFraction * maxOffset)
                          .clamp(0.0, maxOffset);
                      _scroll.jumpTo(next);
                    },
                    onTrackTap: (fraction) {
                      if (!_scroll.hasClients) {
                        return;
                      }
                      final maxOffset = _scroll.position.maxScrollExtent;
                      _scroll.jumpTo(
                        (fraction * maxOffset).clamp(0.0, maxOffset),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(width: ui(8)),
            _PianoChromeImageButton(
              asset: 'assets/images/home/dictation/4.png',
              size: ui(26),
              onTap: _zoomIn,
              tooltip: '放大',
            ),
            SizedBox(width: ui(8)),
            _PianoLabelToggle(active: _labelsVisible, onTap: _toggleLabels),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardArea(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 视口宽度
        final viewport = constraints.maxWidth;
        // 默认白键宽度：尽量铺满 17 个键
        final whiteKeyWidth = _whiteKeyWidth ??= () {
          if (widget.initialWhiteKeyWidth != null) {
            return widget.initialWhiteKeyWidth!;
          }
          final guess = viewport / 17.0;
          return guess
              .clamp(widget.minWhiteKeyWidth, widget.maxWhiteKeyWidth)
              .toDouble();
        }();

        final contentWidth = math.max(
          viewport,
          whiteKeyWidth * widget.whiteKeys.length,
        );
        final keysHeight = constraints.maxHeight;
        final blackKeyWidth = whiteKeyWidth * 0.62;
        final blackKeyHeight = keysHeight * 0.6;

        // 重建命中区
        _hitRects
          ..clear()
          ..addAll(
            _buildHitRects(
              whiteKeyWidth: whiteKeyWidth,
              blackKeyWidth: blackKeyWidth,
              blackKeyHeight: blackKeyHeight,
              keysHeight: keysHeight,
            ),
          );

        // 首次进入：把键盘横向滚动到「内容几何中点」对到视口中央，
        // 与 1.0 Vue 行为一致。中央 C 会自然落到视口中部偏左、左右
        // 各显示约一个 octave，整体视觉居中而不偏左。
        if (!_appliedInitialScroll && widget.initialScrollToCenterC) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) {
              return;
            }
            _appliedInitialScroll = true;
            _scrollToContentCenter(viewportWidth: viewport);
          });
        }

        return ScrollConfiguration(
          behavior: const _PianoScrollBehavior(),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // 用户手指拖动用于按键滑奏（在 Listener 中处理），
            // 滚动只通过顶部 mini-thumb 控制。
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: contentWidth,
              height: keysHeight,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: (e) => _onPointerUpOrCancel(e.pointer),
                onPointerCancel: (e) => _onPointerUpOrCancel(e.pointer),
                onPointerPanZoomEnd: (e) => _onPointerUpOrCancel(e.pointer),
                child: Stack(
                  children: <Widget>[
                    // 白键铺满整块区域
                    for (var i = 0; i < widget.whiteKeys.length; i++)
                      Positioned(
                        left: i * whiteKeyWidth,
                        top: 0,
                        width: whiteKeyWidth,
                        height: keysHeight,
                        child: _PianoWhiteKey(
                          spec: widget.whiteKeys[i],
                          index: i,
                          isPressed: widget.activeNotes.contains(
                            widget.whiteKeys[i].token,
                          ),
                          showLabel: _labelsVisible,
                        ),
                      ),
                    // 黑键按比例占用上方 60%
                    for (final spec in widget.blackKeys)
                      Positioned(
                        left:
                            (spec.afterWhiteIndex + 1) * whiteKeyWidth -
                            blackKeyWidth / 2,
                        top: 0,
                        width: blackKeyWidth,
                        height: blackKeyHeight,
                        child: _PianoBlackKey(
                          spec: spec,
                          isPressed: widget.activeNotes.contains(spec.token),
                          showLabel: _labelsVisible,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Iterable<_KeyHitRect> _buildHitRects({
    required double whiteKeyWidth,
    required double blackKeyWidth,
    required double blackKeyHeight,
    required double keysHeight,
  }) sync* {
    for (var i = 0; i < widget.whiteKeys.length; i++) {
      yield _KeyHitRect(
        token: widget.whiteKeys[i].token,
        rect: Rect.fromLTWH(i * whiteKeyWidth, 0, whiteKeyWidth, keysHeight),
        isBlack: false,
      );
    }
    for (final spec in widget.blackKeys) {
      final left =
          (spec.afterWhiteIndex + 1) * whiteKeyWidth - blackKeyWidth / 2;
      yield _KeyHitRect(
        token: spec.token,
        rect: Rect.fromLTWH(left, 0, blackKeyWidth, blackKeyHeight),
        isBlack: true,
      );
    }
  }
}

class _KeyHitRect {
  const _KeyHitRect({
    required this.token,
    required this.rect,
    required this.isBlack,
  });

  final String token;
  final Rect rect;
  final bool isBlack;
}

/// 顶部圆形 chrome 按钮，使用 3.png / 4.png 资源。
class _PianoChromeImageButton extends StatelessWidget {
  const _PianoChromeImageButton({
    required this.asset,
    required this.size,
    required this.onTap,
    this.tooltip,
  });

  final String asset;
  final double size;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// 顶部 mini 缩略键盘 + 滚动条。
///
/// 视觉上是一条横排的小键盘，半透明 thumb 覆盖在当前可见区域上；
/// 拖动 thumb 或点击空白区都能改变滚动位置。
class _PianoMiniScrollTrack extends StatelessWidget {
  const _PianoMiniScrollTrack({
    required this.whiteKeys,
    required this.blackKeys,
    required this.contentWidth,
    required this.viewportWidth,
    required this.scrollOffset,
    required this.onThumbDrag,
    required this.onTrackTap,
  });

  final List<PianoKeySpec> whiteKeys;
  final List<PianoKeySpec> blackKeys;
  final double contentWidth;
  final double viewportWidth;
  final double scrollOffset;

  /// 拖动 thumb 的相对偏移（占可滚动范围的比例 0..1）。
  final ValueChanged<double> onThumbDrag;

  /// 点击空白区跳到的位置（占可滚动范围的比例 0..1）。
  final ValueChanged<double> onTrackTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;

        // thumb 占比 / 位置
        final ratio = contentWidth <= 0
            ? 1.0
            : (viewportWidth / contentWidth).clamp(0.05, 1.0);
        final thumbWidth = trackWidth * ratio;
        final maxThumbOffset = math.max(0.0, trackWidth - thumbWidth);
        final maxScroll = math.max(0.0, contentWidth - viewportWidth);
        final thumbLeft = maxScroll <= 0
            ? 0.0
            : (scrollOffset / maxScroll) * maxThumbOffset;

        return SizedBox(
          height: ui(26),
          child: Stack(
            children: [
              // 5.png 风格的轨道背景
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (maxThumbOffset <= 0) {
                      return;
                    }
                    final localX = details.localPosition.dx - thumbWidth / 2;
                    final clamped = localX.clamp(0.0, maxThumbOffset);
                    onTrackTap(clamped / maxThumbOffset);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ui(6)),
                    child: _PianoMiniKeysStrip(
                      whiteKeys: whiteKeys,
                      blackKeys: blackKeys,
                    ),
                  ),
                ),
              ),
              // 透明 thumb：仅描边 + 微调亮度，便于看到下方 mini 键盘
              Positioned(
                left: thumbLeft,
                top: 0,
                bottom: 0,
                width: thumbWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (maxThumbOffset <= 0) {
                      return;
                    }
                    onThumbDrag(details.delta.dx / maxThumbOffset);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ui(6)),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.65),
                        width: ui(1.0),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
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

/// 顶部缩略图：把所有黑白键画成横向一条缩小版，用于背景。
class _PianoMiniKeysStrip extends StatelessWidget {
  const _PianoMiniKeysStrip({required this.whiteKeys, required this.blackKeys});

  final List<PianoKeySpec> whiteKeys;
  final List<PianoKeySpec> blackKeys;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final whiteW = w / whiteKeys.length;
        final blackW = whiteW * 0.62;
        final blackH = h * 0.62;
        return Stack(
          children: <Widget>[
            // 整体黑底
            Positioned.fill(child: Container(color: const Color(0xFF11141A))),
            // 白键缩略
            for (var i = 0; i < whiteKeys.length; i++)
              Positioned(
                left: i * whiteW + 0.5,
                top: 1,
                width: whiteW - 1,
                height: h - 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFFFDFEFF), Color(0xFFD7DAE6)],
                    ),
                  ),
                ),
              ),
            // 黑键缩略
            for (final b in blackKeys)
              Positioned(
                left: (b.afterWhiteIndex + 1) * whiteW - blackW / 2,
                top: 0,
                width: blackW,
                height: blackH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(2),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF2E323D), Color(0xFF0A0C12)],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 显示 / 隐藏标签的 toggle。
///
/// - `active = false`（标签隐藏）→ 显示 `piano1.png`（暗色状态）
/// - `active = true`（标签显示）→ 显示 `piano2.png`（紫色高亮 C4 状态）
///
/// 两张图片之间做 200ms 淡入淡出切换，逻辑对齐 VirtualPiano.vue 的 `isShow` 开关。
class _PianoLabelToggle extends StatelessWidget {
  const _PianoLabelToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final height = ui(26);
    final width = ui(68);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // piano1.png — 标签隐藏状态（暗色）
            AnimatedOpacity(
              opacity: active ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Image.asset(
                'assets/images/home/piano1.png',
                fit: BoxFit.contain,
              ),
            ),
            // piano2.png — 标签显示状态（紫色高亮）
            AnimatedOpacity(
              opacity: active ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Image.asset(
                'assets/images/home/piano2.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个白键。
///
/// 视觉素材统一使用 Figma 切图：
/// - 默认态：`assets/images/piano/3.png`
/// - 按下态：`assets/images/piano/4.png`
///
/// PNG 自身已经包含键面渐变、底部"键背阴影/脚线"等 3D 厚度感，
/// 这里只把图片按 [BoxFit.fill] 拉伸到键的整块区域，再叠一层
/// 标签（音名胶囊 + 简谱数字）。
class _PianoWhiteKey extends StatelessWidget {
  const _PianoWhiteKey({
    required this.spec,
    required this.index,
    required this.isPressed,
    required this.showLabel,
  });

  final PianoKeySpec spec;

  /// 白键在键盘中的下标（0 = C2，14 = C4 ……），用于 label 取颜色分组。
  final int index;
  final bool isPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(0.5)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 切图自身会描绘"键面 + 底部脚线/阴影"。按下时阴影变小、键面下沉
          // 的视觉变化全部由 4.png 自己负责，所以这里不再做位置动画。
          //
          // 标签需要落在"键面区域"的下方、避开底部那段阴影。按现有切图实测：
          // - 默认态 3.png 大约底部 12% 是阴影；
          // - 按下态 4.png 阴影被压扁到 4% 左右。
          // 这里按比例算 label 的 bottom，保证两态都贴在键面下沿。
          final h = constraints.maxHeight;
          final labelBottom = isPressed ? h * 0.06 : h * 0.13;

          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: Image.asset(
                  isPressed ? _whitePressedAsset : _whiteIdleAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  // 关键 1：image 切换时保留旧帧到新图解码完成，按下/松开
                  // 之间不会出现一帧的"白色露底"。
                  gaplessPlayback: true,
                  // 关键 2：首次解码完成前给一个跟键面接近的浅色占位，避免
                  // 露出键盘容器的 #1A1C21 暗背景（视觉上的"白键黑一下"）。
                  frameBuilder: _whiteKeyFrameBuilder,
                ),
              ),
              if (showLabel)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: labelBottom,
                  child: _PianoWhiteKeyLabel(spec: spec, index: index),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 白键贴图加载占位：贴图未就绪时铺一层接近键面的浅灰，
/// 避免露出键盘容器暗背景。`wasSynchronouslyLoaded` 为 true
/// 表示已命中 ImageCache（precacheImage 起作用了），直接用真图。
Widget _whiteKeyFrameBuilder(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded || frame != null) {
    return child;
  }
  return const ColoredBox(color: Color(0xFFD8DBE6), child: SizedBox.expand());
}

/// 白键标签。布局严格对齐 1.0 Vue（VirtualPiano.vue + notes.js）：
///
/// ```
///  ┌─────────────┐
///  │   [c¹]      │  ← 顶部音名胶囊（colored pill，中央 C 特殊高亮）
///  │     ⋅       │  ← 高八度点（octaveDots > 0，画在数字上方）
///  │     1       │  ← 简谱 1..7
///  │     ⋅       │  ← 低八度点（octaveDots < 0，画在数字下方）
///  └─────────────┘
/// ```
///
/// 音名规则（来自 Vue 的 name2/name3）：
/// - 大字组（C2-B2）：大写字母 `C`/`D`/...
/// - 小字组（C3-B3）：小写字母 `c`/`d`/...
/// - 小字一/二/三组（C4+）：小写字母 + 上标数字（C4→`c¹`，C5→`c²`，C6→`c³`）。
///
/// 胶囊背景按白键下标分 5 组（与 `bgComputed` 一致），中央 C 单独使用高亮色。
class _PianoWhiteKeyLabel extends StatelessWidget {
  const _PianoWhiteKeyLabel({required this.spec, required this.index});

  final PianoKeySpec spec;

  /// 白键在键盘中的下标（0..34）。
  final int index;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    // ---- 解析 token "C4" / "F#3" → 字母 + 八度 ----
    final octave =
        int.tryParse(spec.token.substring(spec.token.length - 1)) ?? 4;
    final rawLetter = spec.token
        .substring(0, spec.token.length - 1)
        .replaceAll('#', '');
    // 大字组用大写，其余小写。
    final mainText = octave <= 2
        ? rawLetter.toUpperCase()
        : rawLetter.toLowerCase();
    // C4→1，C5→2，C6→3；C2/C3 不带上标。
    final superscript = octave >= 4 ? '${octave - 3}' : '';

    final bgColor = spec.isCenterC
        ? const Color(0xFFC4F25E) // 中央 C：黄绿高亮
        : _capsuleColor(index);
    final textColor = spec.isCenterC
        ? const Color(0xFF0B081A)
        : const Color(0xFF1A1A1A);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 顶部音名胶囊
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(3), vertical: ui(1.5)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(2.5)),
            color: bgColor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                mainText,
                style: TextStyle(
                  color: textColor,
                  fontSize: ui(11),
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              if (superscript.isNotEmpty) ...<Widget>[
                SizedBox(width: ui(0.5)),
                Transform.translate(
                  offset: Offset(0, -ui(2.0)),
                  child: Text(
                    superscript,
                    style: TextStyle(
                      color: textColor,
                      fontSize: ui(7),
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: ui(3)),
        // 高八度点（数字上方）
        if (spec.octaveDots > 0)
          Padding(
            padding: EdgeInsets.only(bottom: ui(1.5)),
            child: _OctaveDots(
              count: spec.octaveDots,
              color: const Color(0xFF6D6B75),
            ),
          ),
        // 简谱 1..7
        Text(
          spec.solfege == 0 ? '' : '${spec.solfege}',
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: ui(13),
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        // 低八度点（数字下方）
        if (spec.octaveDots < 0)
          Padding(
            padding: EdgeInsets.only(top: ui(1.5)),
            child: _OctaveDots(
              count: -spec.octaveDots,
              color: const Color(0xFF6D6B75),
            ),
          ),
      ],
    );
  }

  /// 与 Vue `bgComputed` 一致的 5 段分组配色（按白键下标）。
  Color _capsuleColor(int idx) {
    if (idx < 7) {
      return const Color(0xCCFDBCD2); // 粉
    }
    if (idx < 14) {
      return const Color(0xCCACAFFE); // 浅紫
    }
    if (idx < 21) {
      return const Color(0xCCFEE5C6); // 米
    }
    if (idx < 28) {
      return const Color(0xCCA6FFFB); // 浅青
    }
    return const Color(0xCCA4FEBE); // 浅绿
  }
}

/// 简谱八度点：竖向堆叠，体现 Chinese 简谱"加点表示高低八度"的写法。
class _OctaveDots extends StatelessWidget {
  const _OctaveDots({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: ui(0.5)),
            child: Container(
              width: ui(3),
              height: ui(3),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
      ],
    );
  }
}

/// 单个黑键。
///
/// 视觉素材统一使用 Figma 切图：
/// - 默认态：`assets/images/piano/1.png`
/// - 按下态：`assets/images/piano/2.png`
///
/// PNG **画布尺寸**为 [_blackCanvasW] × [_blackCanvasH]（73.65 × 144.82），
/// 其中**有效键身**只占 [_blackEffectiveW] × [_blackEffectiveH]（39.5 × 136.13）
/// 居中位置，画布四周剩余部分是透明留白 + drop-shadow。
///
/// 因此不能直接 `BoxFit.fill` 把整张画布拉到键区——那样会把透明边一起塞进
/// 键身里，导致键看起来偏小、底部阴影错位。这里反过来：把图片渲染得**比键身
/// 略大**，让"有效区"刚好对齐键身，多出的画布（即阴影 + 透明）自然超出键
/// 边、落在相邻白键上方，模拟真实的 drop-shadow。
class _PianoBlackKey extends StatelessWidget {
  const _PianoBlackKey({
    required this.spec,
    required this.isPressed,
    required this.showLabel,
  });

  final PianoKeySpec spec;
  final bool isPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // 默认态 / 按下态各自有一组"画布尺寸"和"有效区尺寸"。
          // 调键体在屏幕上看起来的大小请参考下方常量：
          //   - effectiveW / effectiveH **变小** → PNG 整体渲染**变大**
          //     → 键体在屏幕上看起来更大；
          //   - 反之 effective* **变大** → 键体看起来更小。
          // 横向和纵向可以独立调，宽高比不一定保持一致。
          final canvasW = isPressed ? _blackPressedCanvasW : _blackIdleCanvasW;
          final canvasH = isPressed ? _blackPressedCanvasH : _blackIdleCanvasH;
          final effectiveW = isPressed
              ? _blackPressedEffectiveW
              : _blackIdleEffectiveW;
          final effectiveH = isPressed
              ? _blackPressedEffectiveH
              : _blackIdleEffectiveH;

          // 把 PNG 画布按"有效区 = 键身"反推回它该被渲染多大：
          // imgW / canvasW = w / effectiveW  →  imgW = w * canvasW / effectiveW
          final imgW = w * canvasW / effectiveW;
          final imgH = h * canvasH / effectiveH;
          // 留白居中分布，所以左右/上下各超出一半。
          final offsetX = -(imgW - w) / 2;
          final offsetY = -(imgH - h) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: offsetX,
                top: offsetY,
                width: imgW,
                height: imgH,
                child: Image.asset(
                  isPressed ? _blackPressedAsset : _blackIdleAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  // 同白键：保留旧帧 + 解码前画占位色，
                  // 消除"按下闪一下白""首次进入闪一下"。
                  gaplessPlayback: true,
                  frameBuilder: _blackKeyFrameBuilder,
                ),
              ),
              // 黑键不再渲染 F# / G# 等音名标签：
              // 用户要求打开"显示标签"开关时仅在白键上显示音名 / 简谱，
              // 黑键保持纯键面，避免上方密集小字干扰阅读。[showLabel]
              // 仍保留以兼容外部 API，这里有意忽略。
            ],
          );
        },
      ),
    );
  }
}

/// 黑键贴图加载占位：贴图未就绪时给一块跟键体接近的深色，
/// 避免按下/首帧露白。`Padding` 把占位色限制在键身范围内，
/// 不让它跟着画布溢出去画到相邻白键上方。
Widget _blackKeyFrameBuilder(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded || frame != null) {
    return child;
  }
  // 占位居中收缩到"有效键身"那一块（避免阴影区也铺一片黑色）。
  // 数值取自 _black*Effective* 的近似比例：横向 39.5/73.65 ≈ 0.536，
  // 纵向 136/144.82 ≈ 0.940。
  return const FractionallySizedBox(
    widthFactor: 0.536,
    heightFactor: 0.940,
    child: ColoredBox(
      color: Color(0xFF14171F),
      child: SizedBox.expand(),
    ),
  );
}

// ===== 黑键 PNG 的画布 + 有效区尺寸（Figma 单位） =====
//
// 这些常量决定了 PNG 在键里的渲染大小。每个状态四个常量：
//   _black{State}CanvasW / CanvasH        —— PNG 整张画布的设计尺寸
//   _black{State}EffectiveW / EffectiveH  —— 画布里"键体"实际占的范围
//
// 渲染逻辑：把 PNG 画到 (w * canvasW/effectiveW) × (h * canvasH/effectiveH)
// 大小，让 effective 区刚好填满键的实际显示区域 w × h，画布周围的
// 透明 / drop-shadow 部分自然超出键边、落到相邻白键上。
//
// 调按下态键体的视觉大小：
//   - 觉得键变小了 → **降低** _blackPressedEffectiveW / EffectiveH
//   - 觉得键变大了 → **提高** _blackPressedEffectiveW / EffectiveH
// 数值变化在屏幕上的放大效果：1px 设计单位差 ≈ 渲染键高的 0.7%。
const double _blackIdleCanvasW = 73.65;
const double _blackIdleCanvasH = 144.82;
const double _blackIdleEffectiveW = 39.5;
const double _blackIdleEffectiveH = 136.13;

const double _blackPressedCanvasW = 73.65;
const double _blackPressedCanvasH = 144.82;
const double _blackPressedEffectiveW = 35;
const double _blackPressedEffectiveH = 123;

// 钢琴键纹理素材路径常量（避免在两处出现魔术字符串）。
const String _whiteIdleAsset = 'assets/images/piano/3.png';
const String _whitePressedAsset = 'assets/images/piano/4.png';
const String _blackIdleAsset = 'assets/images/piano/1.png';
const String _blackPressedAsset = 'assets/images/piano/2.png';

/// 让滚动行为不显示桌面端默认的 scrollbar，并允许鼠标拖动。
class _PianoScrollBehavior extends ScrollBehavior {
  const _PianoScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}
