import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../piano/ui/piano_keyboard.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/music_play_controller.dart';
import '../state/music_play_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

final Set<String> _musicPlayPrecachedImages = <String>{};

int _musicPlayDecodeWidth(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (size.width * dpr).ceil().clamp(1, 2200).toInt();
}

class MusicPlayPage extends ConsumerStatefulWidget {
  const MusicPlayPage({super.key});

  @override
  ConsumerState<MusicPlayPage> createState() => _MusicPlayPageState();
}

class _MusicPlayPageState extends ConsumerState<MusicPlayPage> {
  bool _shareDialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final args = MusicPlayPageArgs.fromRaw(
      ModalRoute.of(context)?.settings.arguments,
    );
    final state = ref.watch(musicPlayControllerProvider(args));
    final controller = ref.read(musicPlayControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;
    _precacheMusicPlayImages(context, state);

    ref.listen<MusicPlayState>(musicPlayControllerProvider(args), (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message.isNotEmpty && message != previous?.errorMessage) {
        AppToast.show(context, message);
        controller.clearError();
      }

      if (next.shareDialogVisible && !_shareDialogShowing) {
        _shareDialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(context, args);
        });
      }
    });

    // Padding is moved INSIDE each layout so that the bottom piano keyboard
    // can sit flush against the surface edges (full-bleed) for a more
    // immersive look. ClipRRect respects the panel's rounded corners so the
    // piano's drop shadow does not bleed past them.
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(ShellLayoutSpec.panelRadius)),
        child: state.loading && !state.hasDetail
            ? Padding(
                padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (state.isVocalOrInstrumental
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        ui(12),
                        ui(12),
                        ui(12),
                        ui(12),
                      ),
                      child: _buildVocalLayout(context, state, controller),
                    )
                  : _buildDefaultLayout(context, state, controller)),
      ),
    );
  }

  void _precacheMusicPlayImages(BuildContext context, MusicPlayState state) {
    final urls = <String>[
      'assets/images/home/plyabj.png',
      'assets/images/home/play1.png',
      'assets/images/home/left.png',
      'assets/images/home/right.png',
      // 视唱多课程列表的「上一首 / 下一首」按钮图。
      'assets/images/home/shang.png',
      'assets/images/home/xia.png',
      // 多曲目（节奏 / 和弦）专属：循环模式 + 音频列表 chip 用的纯图标。
      AppAssets.homeShufflePlayMode,
      AppAssets.homeLoopPlayMode,
      AppAssets.homeSingleLoopPlayMode,
      AppAssets.homePlaylistIcon,
      'assets/images/home/chevron-down.png',
      'assets/images/home/feng.png',
      'assets/images/home/dictation/8.png',
      'assets/images/home/dictation/9.png',
      'assets/images/home/dictation/10.png',
      'assets/images/404/wx.png',
      'assets/images/404/jp.png',
      if (state.detail?.coverUrl.isNotEmpty == true) state.detail!.coverUrl,
    ];

    for (final url in urls) {
      if (url.isEmpty || !_musicPlayPrecachedImages.add(url)) {
        continue;
      }
      final provider = url.startsWith('http://') || url.startsWith('https://')
          ? ResizeImage(NetworkImage(url), width: 720)
          : AssetImage(url) as ImageProvider;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          precacheImage(provider, context);
        }
      });
    }
  }

  Widget _buildDefaultLayout(
    BuildContext context,
    MusicPlayState state,
    MusicPlayController controller,
  ) {
    final ui = DashboardScaleScope.of(context).ui;
    // Top half (turntable + answer + playback bar) keeps the original page
    // padding. The bottom half – the piano keyboard, when shown – is rendered
    // edge-to-edge so it visually merges into the panel's bottom rounded
    // corners. When the keyboard is hidden the long-text panel reapplies the
    // standard padding so the original layout is preserved.
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), 0),
          child: Column(
            children: [
              SizedBox(
                height: ui(332),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: ui(320),
                      child: _TurntablePanel(
                        state: state,
                        onBack: () => Navigator.of(context).maybePop(),
                        onShare: controller.openShareDialog,
                      ),
                    ),
                    Container(
                      width: ui(1),
                      margin: EdgeInsets.only(left: ui(12), right: ui(14)),
                      color: const Color(0xFFF3F2F3),
                    ),
                    Expanded(
                      child: _AnswerPanel(
                        state: state,
                        onToggleAnswer: controller.setShowAnswer,
                        onImageChanged: controller.setImageIndex,
                        // 默认布局（听写/乐理/视唱等）不显示升降调按钮：
                        // 声乐/器乐在 [_buildVocalLayout] 中按详情开放；`firstMenu == 18`
                        // 时详情要求不展示升降调。
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ui(18)),
              _PlaybackBar(
                state: state,
                onSkipBackward: _resolveLeftAction(controller, state),
                onTogglePlay: controller.togglePlay,
                onSkipForward: _resolveRightAction(controller, state),
                leftAsset: _resolveLeftAsset(state),
                rightAsset: _resolveRightAsset(state),
                onSeekRatio: (ratio) {
                  final target = Duration(
                    milliseconds: (state.duration.inMilliseconds * ratio)
                        .round(),
                  );
                  controller.seek(target);
                },
                onSpeedChanged: controller.setPlaybackSpeed,
                onToggleFavorite: controller.toggleFavorite,
                onTogglePlayMode: controller.togglePlayMode,
                onSelectTrack: controller.selectTrack,
              ),
              SizedBox(height: ui(12)),
            ],
          ),
        ),
        Expanded(
          child: state.showsKeyboard
              ? PianoKeyboard(
                  activeNotes: state.activePianoNotes,
                  onPress: controller.pressPianoKey,
                  onRelease: controller.releasePianoKey,
                  height: 220,
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(ui(12), 0, ui(12), ui(12)),
                  child: _LongTextPanel(
                    htmlText: state.detail?.longTextHtml ?? '',
                  ),
                ),
        ),
      ],
    );
  }

  /// 声乐/器乐布局：左侧为转盘 + 简介卡片，右侧为乐谱（五线谱/简谱）。
  /// 没有底部钢琴/长文区域；播放控制条沉到页面底部。
  Widget _buildVocalLayout(
    BuildContext context,
    MusicPlayState state,
    MusicPlayController controller,
  ) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: ui(320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TurntablePanel(
                      state: state,
                      onBack: () => Navigator.of(context).maybePop(),
                      onShare: controller.openShareDialog,
                    ),
                    SizedBox(height: ui(12)),
                    Expanded(
                      child: _DescriptionCard(
                        htmlText: state.detail?.longTextHtml ?? '',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: ui(1),
                margin: EdgeInsets.only(left: ui(12), right: ui(14)),
                color: const Color(0xFFF3F2F3),
              ),
              Expanded(
                child: _AnswerPanel(
                  state: state,
                  onToggleAnswer: controller.setShowAnswer,
                  onImageChanged: controller.setImageIndex,
                  useStaffSimplifiedToggle: true,
                  pitchSemitones: state.detail?.hidePitchShift == true
                      ? null
                      : state.pitchSemitones,
                  onPitchChanged: state.detail?.hidePitchShift == true
                      ? null
                      : controller.setPitchSemitones,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ui(18)),
        _PlaybackBar(
          state: state,
          onSkipBackward: _resolveLeftAction(controller, state),
          onTogglePlay: controller.togglePlay,
          onSkipForward: _resolveRightAction(controller, state),
          leftAsset: _resolveLeftAsset(state),
          rightAsset: _resolveRightAsset(state),
          onSeekRatio: (ratio) {
            final target = Duration(
              milliseconds: (state.duration.inMilliseconds * ratio).round(),
            );
            controller.seek(target);
          },
          onSpeedChanged: controller.setPlaybackSpeed,
          onToggleFavorite: controller.toggleFavorite,
          onTogglePlayMode: controller.togglePlayMode,
          onSelectTrack: controller.selectTrack,
        ),
      ],
    );
  }

  Future<void> _skipSeconds(
    MusicPlayController controller,
    MusicPlayState state,
    int deltaSeconds,
  ) async {
    final maxMs = state.duration.inMilliseconds;
    final currentMs = state.position.inMilliseconds;
    final targetMs = maxMs > 0
        ? (currentMs + deltaSeconds * 1000).clamp(0, maxMs)
        : math.max(0, currentMs + deltaSeconds * 1000);
    await controller.seek(Duration(milliseconds: targetMs));
  }

  /// 左/右按钮是否升级为「上一首 / 下一首」：两类场景启用。
  ///   1. 视唱（多课程）：父页透传 `allLessonIds`，按 id 列表切歌；
  ///   2. 多曲目课件（节奏 / 和弦，`file1` 为数组）：按曲目内部索引切歌。
  /// 其它入口（听写 / 声乐 / 器乐 单曲目）保持 ±5s 快进/倒退语义。
  ///
  /// `previous` / `next` 的实现已经分别处理了这两类：当 allLessonIds 不为
  /// 空时走 `_switchLesson`，否则按 `tracks` 内部 index 切。
  bool _useLessonNavigation(MusicPlayState state) {
    if (state.args.allLessonIds.isNotEmpty) {
      return true;
    }
    return (state.detail?.tracks.length ?? 0) > 1;
  }

  Future<void> Function() _resolveLeftAction(
    MusicPlayController controller,
    MusicPlayState state,
  ) {
    if (_useLessonNavigation(state)) {
      return controller.previous;
    }
    return () => _skipSeconds(controller, state, -5);
  }

  Future<void> Function() _resolveRightAction(
    MusicPlayController controller,
    MusicPlayState state,
  ) {
    if (_useLessonNavigation(state)) {
      return controller.next;
    }
    return () => _skipSeconds(controller, state, 5);
  }

  String _resolveLeftAsset(MusicPlayState state) =>
      _useLessonNavigation(state)
          ? 'assets/images/home/shang.png'
          : 'assets/images/home/left.png';

  String _resolveRightAsset(MusicPlayState state) =>
      _useLessonNavigation(state)
          ? 'assets/images/home/xia.png'
          : 'assets/images/home/right.png';

  Future<void> _showShareDialog(
    BuildContext context,
    MusicPlayPageArgs args,
  ) async {
    if (!mounted) {
      return;
    }
    final scale = DashboardScaleScope.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      barrierDismissible: true,
      barrierLabel: '关闭分享',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DashboardScaleScope(
          data: scale,
          child: _ShareDrawer(args: args),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
    );
    _shareDialogShowing = false;
    if (mounted) {
      ref.read(musicPlayControllerProvider(args).notifier).closeShareDialog();
    }
  }
}

class _ShareDrawer extends ConsumerWidget {
  const _ShareDrawer({required this.args});

  final MusicPlayPageArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayControllerProvider(args));
    final controller = ref.read(musicPlayControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: ui(600),
          height: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DrawerTitle(title: '分享课件'),
                SizedBox(height: ui(20)),
                const Divider(height: 1, color: Color(0xFFF3F2F3)),
                SizedBox(height: ui(24)),
                _ShareTargetCard(detail: state.detail),
                SizedBox(height: ui(28)),
                Text(
                  '您的班级群',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
                SizedBox(height: ui(16)),
                Expanded(
                  child: state.classLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.classList.isEmpty
                      ? const _ShareDrawerEmpty()
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: state.classList.length,
                          separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                          itemBuilder: (context, index) {
                            final cls = state.classList[index];
                            return _ClassRow(
                              cls: cls,
                              onTap: () => controller.toggleClass(cls.id),
                            );
                          },
                        ),
                ),
                SizedBox(height: ui(12)),
                _SendButton(
                  loading: state.sending,
                  onTap: () async {
                    final success = await controller.sendShare();
                    if (!context.mounted) {
                      return;
                    }
                    if (success) {
                      Navigator.of(context).maybePop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerTitle extends StatelessWidget {
  const _DrawerTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: const Color(0xFF8741FF),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
          ),
        ),
      ],
    );
  }
}

class _ShareTargetCard extends StatelessWidget {
  const _ShareTargetCard({required this.detail});

  final MusicPlayDetail? detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final coverUrl = detail?.coverUrl ?? '';
    final imageProvider =
        coverUrl.startsWith('http://') || coverUrl.startsWith('https://')
        ? NetworkImage(coverUrl)
        : (coverUrl.isNotEmpty ? AssetImage(coverUrl) : null) as ImageProvider?;

    return Container(
      height: ui(106),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(20)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '您将分享的课件',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(10)),
                Text(
                  detail?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          Container(
            width: ui(75.76),
            height: ui(55.27),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1E8FD), Color(0xFFDDC4FF)],
              ),
              borderRadius: BorderRadius.circular(ui(6.82)),
            ),
            child: imageProvider == null
                ? const Icon(
                    Icons.library_music_rounded,
                    color: Color(0xFFA773FF),
                  )
                : Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.library_music_rounded,
                      color: Color(0xFFA773FF),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.cls, required this.onTap});

  final MusicPlayShareClass cls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checked = cls.checked;
    return Material(
      color: const Color(0xFFF5F6FA),
      borderRadius: BorderRadius.circular(ui(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(16)),
        onTap: onTap,
        child: Container(
          height: ui(80),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          child: Row(
            children: [
              Container(
                width: ui(24),
                height: ui(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked
                        ? const Color(0xFF8741FF)
                        : const Color(0xFFCECED1),
                    width: 1,
                  ),
                ),
                child: checked
                    ? Icon(
                        Icons.check_rounded,
                        size: ui(16),
                        color: const Color(0xFF8741FF),
                      )
                    : null,
              ),
              SizedBox(width: ui(16)),
              Expanded(
                child: Text(
                  cls.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareDrawerEmpty extends StatelessWidget {
  const _ShareDrawerEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Text(
        '暂无班级群',
        style: TextStyle(
          color: const Color(0xFFB6B5BB),
          fontSize: ui(14),
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: loading
            ? SizedBox(
                width: ui(20),
                height: ui(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '发送',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 24 / 14,
                ),
              ),
      ),
    );
  }
}

class _TurntablePanel extends StatelessWidget {
  const _TurntablePanel({
    required this.state,
    required this.onBack,
    required this.onShare,
  });

  final MusicPlayState state;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final detail = state.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const Spacer(),
            _SecondaryChipButton(
              iconAsset: 'assets/images/home/dictation/10.png',
              label: '分享',
              onTap: onShare,
            ),
          ],
        ),
        SizedBox(height: ui(22)),
        Center(child: _TurntableDisc(playing: state.isPlaying)),
        SizedBox(height: ui(14)),
        Center(
          child: Container(
            width: ui(129),
            height: ui(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDED),
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(12)),
              child: _MarqueeTitleText(
                text: detail?.title ?? '未命名听写',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: ui(11),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 18 / 11,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: ui(16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(22)),
          child: RepaintBoundary(
            child: _FrequencyVisualizer(
              frequencyBands: state.frequencyBands,
              playing: state.isPlaying,
              height: ui(38),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarqueeTitleText extends StatefulWidget {
  const _MarqueeTitleText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_MarqueeTitleText> createState() => _MarqueeTitleTextState();
}

class _MarqueeTitleTextState extends State<_MarqueeTitleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _durationMs = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _MarqueeTitleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final gap = ui(28);
    final pixelsPerSecond = ui(40);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        final textWidth = painter.width;
        final viewportWidth = constraints.maxWidth;

        if (widget.text.isEmpty || viewportWidth <= 0) {
          _controller.stop();
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: widget.style,
          );
        }

        final textSlotWidth = math.max(textWidth, viewportWidth);
        final distance = textSlotWidth + gap;
        final durationMs = math.max(
          1800,
          (distance / pixelsPerSecond * 1000).round(),
        );
        _ensureScrolling(durationMs);

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final left = -distance * _controller.value;
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  _buildPositionedText(left, textSlotWidth),
                  _buildPositionedText(left + distance, textSlotWidth),
                  _buildPositionedText(left + distance * 2, textSlotWidth),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _ensureScrolling(int durationMs) {
    if (_durationMs == durationMs && _controller.isAnimating) {
      return;
    }
    _durationMs = durationMs;
    _controller.duration = Duration(milliseconds: durationMs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    });
  }

  Widget _buildPositionedText(double left, double width) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: widget.style,
        ),
      ),
    );
  }
}

class _TurntableDisc extends StatelessWidget {
  const _TurntableDisc({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(180),
      height: ui(180),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/home/plyabj.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: ui(102),
            top: ui(10),
            child: AnimatedRotation(
              turns: playing ? 0 : -0.075,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              alignment: const Alignment(0.64, -0.79),
              child: Image.asset(
                'assets/images/home/play1.png',
                width: ui(65),
                height: ui(138),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerPanel extends StatefulWidget {
  const _AnswerPanel({
    required this.state,
    required this.onToggleAnswer,
    required this.onImageChanged,
    this.useStaffSimplifiedToggle = false,
    this.pitchSemitones,
    this.onPitchChanged,
  });

  final MusicPlayState state;
  final ValueChanged<bool> onToggleAnswer;
  final ValueChanged<int> onImageChanged;

  /// 声乐/器乐课程使用 五线谱/简谱 切换；其他课程使用 关闭/答案。
  final bool useStaffSimplifiedToggle;

  /// "升降调"按钮的当前半音数。`null` 表示不显示按钮。
  final int? pitchSemitones;

  /// 选择新的升降调半音数后回调。`null` 表示不显示按钮。
  final ValueChanged<int>? onPitchChanged;

  @override
  State<_AnswerPanel> createState() => _AnswerPanelState();
}

class _AnswerPanelState extends State<_AnswerPanel> {
  final Set<int> _failedImageIndexes = <int>{};
  List<String> _lastImages = const <String>[];

  @override
  void didUpdateWidget(covariant _AnswerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final images = widget.state.visibleImages;
    if (!_listEquals(images, _lastImages)) {
      _lastImages = List<String>.from(images);
      _failedImageIndexes.clear();
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _markImageFailed(int index) {
    if (_failedImageIndexes.contains(index)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _failedImageIndexes.add(index);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = widget.state;
    final images = state.visibleImages;
    if (!_listEquals(images, _lastImages)) {
      _lastImages = List<String>.from(images);
      _failedImageIndexes.clear();
    }
    final activeIndex = state.activeImageIndex.clamp(
      0,
      math.max(0, images.length - 1),
    );
    final showCounter =
        images.isNotEmpty && !_failedImageIndexes.contains(activeIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            if (widget.pitchSemitones != null && widget.onPitchChanged != null) ...[
              _TransposeChipButton(
                pitchSemitones: widget.pitchSemitones!,
                onPitchChanged: widget.onPitchChanged!,
              ),
              SizedBox(width: ui(10)),
            ],
            Container(
              height: ui(28),
              padding: EdgeInsets.all(ui(2)),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Row(
                children: widget.useStaffSimplifiedToggle
                    ? [
                        _TogglePill(
                          label: '五线谱',
                          active: state.showAnswer,
                          onTap: () => widget.onToggleAnswer(true),
                        ),
                        SizedBox(width: ui(4)),
                        _TogglePill(
                          label: '简谱',
                          active: !state.showAnswer,
                          onTap: () => widget.onToggleAnswer(false),
                        ),
                      ]
                    : [
                        _TogglePill(
                          label: '关闭',
                          active: !state.showAnswer,
                          onTap: () => widget.onToggleAnswer(false),
                        ),
                        SizedBox(width: ui(4)),
                        _TogglePill(
                          label: '答案',
                          active: state.showAnswer,
                          onTap: () => widget.onToggleAnswer(true),
                        ),
                      ],
              ),
            ),
          ],
        ),
        SizedBox(height: ui(18)),
        Expanded(
          child: images.isEmpty
              ? _AnswerEmptyState(
                  useStaffSimplifiedToggle: widget.useStaffSimplifiedToggle,
                  showStaff: state.showAnswer,
                )
              : Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: widget.onImageChanged,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        final failed = _failedImageIndexes.contains(index);
                        // 答案图保留原始细节：宽度铺满，超出高度允许上下滑动查看；
                        // 双击仍可调起全屏画廊（PhotoView）做缩放/拖拽。
                        if (failed) {
                          return _AnswerEmptyState(
                            useStaffSimplifiedToggle:
                                widget.useStaffSimplifiedToggle,
                            showStaff: state.showAnswer,
                          );
                        }
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () => showImageGallery(
                            context,
                            images: images,
                            initialIndex: index,
                            heroTagPrefix: 'music_play_answer',
                          ),
                          child: Scrollbar(
                            thumbVisibility: false,
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              child: Hero(
                                tag: 'music_play_answer_${image}_$index',
                                child: Image.network(
                                  image,
                                  width: double.infinity,
                                  fit: BoxFit.fitWidth,
                                  cacheWidth: _musicPlayDecodeWidth(context),
                                  errorBuilder: (context, error, stackTrace) {
                                    _markImageFailed(index);
                                    return Center(
                                      child: _AnswerEmptyState(
                                        useStaffSimplifiedToggle:
                                            widget.useStaffSimplifiedToggle,
                                        showStaff: state.showAnswer,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (showCounter)
                      Positioned(
                        right: ui(10),
                        bottom: ui(6),
                        child: Container(
                          height: ui(24),
                          padding: EdgeInsets.symmetric(horizontal: ui(8)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F2F3),
                            borderRadius: BorderRadius.circular(ui(6)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${activeIndex + 1}/${images.length}',
                            style: TextStyle(
                              color: const Color(0xFF0B081A),
                              fontSize: ui(12),
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AnswerEmptyState extends StatelessWidget {
  const _AnswerEmptyState({
    this.useStaffSimplifiedToggle = false,
    this.showStaff = true,
  });

  final bool useStaffSimplifiedToggle;
  final bool showStaff;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final asset = useStaffSimplifiedToggle
        ? (showStaff ? 'assets/images/404/wx.png' : 'assets/images/404/jp.png')
        : 'assets/images/home/dictation/8.png';
    final isStaffMode = useStaffSimplifiedToggle;
    final message = isStaffMode
        ? (showStaff ? '暂无五线谱' : '暂无简谱')
        : '同学加油！不看答案的样子真的很棒！';
    final messageStyle = isStaffMode
        ? TextStyle(
            color: const Color.fromARGB(255, 22, 22, 22),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          )
        : TextStyle(
            color: const Color(0xFFB6B5BB),
            fontSize: ui(13),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 2 / 13,
          );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            asset,
            width: ui(200),
            height: ui(200),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(0)),
          isStaffMode
              ? Text(message, style: messageStyle)
              : Transform.translate(
                  offset: Offset(0, -ui(25)),
                  child: Text(message, style: messageStyle),
                ),
        ],
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({
    required this.state,
    required this.onSkipBackward,
    required this.onTogglePlay,
    required this.onSkipForward,
    required this.onSeekRatio,
    required this.onSpeedChanged,
    required this.onToggleFavorite,
    required this.onTogglePlayMode,
    required this.onSelectTrack,
    this.leftAsset = 'assets/images/home/left.png',
    this.rightAsset = 'assets/images/home/right.png',
  });

  final MusicPlayState state;
  final Future<void> Function() onSkipBackward;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function() onSkipForward;
  final ValueChanged<double> onSeekRatio;
  final ValueChanged<double> onSpeedChanged;
  final Future<void> Function() onToggleFavorite;

  /// 播放按钮左侧图标资源。默认为 ±5s 倒退；视唱多课程场景由父级覆盖为
  /// [AppAssets.homeShang]（上一首）。
  final String leftAsset;

  /// 播放按钮右侧图标资源。默认为 ±5s 快进；视唱多课程场景由父级覆盖为
  /// [AppAssets.homeXia]（下一首）。
  final String rightAsset;

  /// 切换循环模式（顺序 / 单曲 / 随机）。
  final VoidCallback onTogglePlayMode;

  /// 直接跳到列表中的某一首并播放。
  final ValueChanged<int> onSelectTrack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final detail = state.detail;
    final track = state.activeTrack;
    final durationMs = math.max(state.duration.inMilliseconds, 1);
    final ratio = (state.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
    final favorite = detail?.favorite == true;

    return Container(
      height: ui(72),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: ui(12)),
          Container(
            width: ui(48),
            height: ui(48),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(ui(4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: detail?.coverUrl.isNotEmpty == true
                ? Image.network(
                    detail!.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/home/feng.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset('assets/images/home/feng.png', fit: BoxFit.cover),
          ),
          SizedBox(width: ui(12)),
          // 多曲目时主标题切换为"当前音频文件名"，副标题降级显示教材名；
          // 单曲目场景沿用旧的"教材名 + 听写/曲目名"。
          //
          // 旧实现用 IntrinsicWidth + softWrap=false 让标题按内容宽度
          // 自由撑开——用户反馈这种写法在副标题很长（"四分、二八、二分、附点二分"）
          // 时会把右侧的进度条压扁；现在改成给整列加一个上限宽度（180）+
          // 单行省略号，长副标题溢出显示 "…"，进度条保持原宽度。
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ui(180)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _resolvePrimaryTitle(detail, track),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(15),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
                SizedBox(height: ui(6)),
                Text(
                  _resolveSecondaryTitle(detail, track),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(12),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 12 / 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          _InlineImageIcon(
            asset: leftAsset,
            onTap: onSkipBackward,
            size: 24,
          ),
          SizedBox(width: ui(8)),
          GestureDetector(
            onTap: onTogglePlay,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: ui(44),
              height: ui(44),
              child: Center(
                child: Container(
                  width: ui(36.67),
                  height: ui(36.67),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8741FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: ui(22),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: ui(8)),
          _InlineImageIcon(
            asset: rightAsset,
            onTap: onSkipForward,
            size: 24,
          ),
          SizedBox(width: ui(12)),
          _SpeedChip(speed: state.speed, onSpeedChanged: onSpeedChanged),
          SizedBox(width: ui(14)),
          Expanded(
            child: _ProgressTrack(
              ratio: ratio,
              durationLabel:
                  '${_formatDuration(state.position)}/${_formatDuration(state.duration)}',
              onSeekRatio: onSeekRatio,
            ),
          ),
          SizedBox(width: ui(19)),
          // 多曲目时（1.0 中 `urlList?.length > 1 && isArr`）显示
          // 循环模式 + 播放列表 chip。视觉沿用 2.0 的极简 chip 风格。
          if ((detail?.tracks.length ?? 0) > 1) ...[
            _LoopModeChip(
              mode: state.playMode,
              onTap: onTogglePlayMode,
            ),
            SizedBox(width: ui(8)),
            _PlaylistChip(
              tracks: detail?.tracks ?? const <MusicPlayTrack>[],
              activeIndex: state.activeTrackIndex,
              onSelect: onSelectTrack,
            ),
            SizedBox(width: ui(16)),
          ],
          GestureDetector(
            onTap: onToggleFavorite,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: ui(24),
                  color: favorite
                      ? const Color(0xFF8741FF)
                      : const Color(0xFFB6B5BB),
                ),
                SizedBox(width: ui(4)),
                Text(
                  '收藏',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 12 / 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
        ],
      ),
    );
  }

  /// 主标题：多曲目时显示"当前音频文件名"（与左侧标题随播放切换的需求对齐），
  /// 单曲目时回退到教材名。
  String _resolvePrimaryTitle(MusicPlayDetail? detail, MusicPlayTrack? track) {
    if (detail != null && detail.tracks.length > 1) {
      final title = track?.title.trim() ?? '';
      if (title.isNotEmpty) return title;
      return detail.title;
    }
    return detail?.title ?? '未命名音频';
  }

  /// 副标题：直接对齐课件详情接口的 `shortText*` 字段。
  ///
  ///  - 多曲目（`file1` 是 [{url, filename}, ...] 数组、典型场景节奏 / 和弦）：
  ///    `shortText2 → shortText1 → "音频1"`
  ///  - 单曲目（`file1` 只有一条 mp3，典型场景听写）：
  ///    `shortText2 → "音频1"`（此场景下 shortText1 接口几乎都是空，按需求
  ///    跳过它，免得偶发的旧数据把主副标题挤成重复内容）
  ///
  /// 兜底字符串 "音频1" 与 1.0 设计稿一致；副标题永远不为空，避免播放条
  /// 因一行高度突变出现"标题往下漂移"。
  String _resolveSecondaryTitle(MusicPlayDetail? detail, MusicPlayTrack? track) {
    if (detail == null) {
      return '音频1';
    }
    final shortText2 = detail.shortText2.trim();
    if (shortText2.isNotEmpty) {
      return shortText2;
    }
    if (detail.tracks.length > 1) {
      final shortText1 = detail.shortText1.trim();
      if (shortText1.isNotEmpty) {
        return shortText1;
      }
    }
    return '音频1';
  }

  String _formatDuration(Duration value) {
    if (value == Duration.zero) {
      return '00:00';
    }
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 进度条与时间标签：滑块带紫色渐变填充与圆形 thumb；右上方显示 `当前/总时长`。
///
/// 布局策略：
///   外部父 Row 的 crossAxisAlignment 是 center（播放条 72 高），希望"滑块的
///   视觉中线"刚好落在播放条的水平中线上。原先用 Column[label, gap, slider]
///   的写法会把整列高度撑到 ~36，居中后滑块中线整体偏下。这里改用：
///     - 自身高度 = 滑块 hit zone（20），居中后中线即 = 播放条中线；
///     - 时间标签通过 Stack 浮在滑块上方，clipBehavior: Clip.none 允许其向上
///       溢出本控件的边界但不撑高布局，因此不影响滑块对齐。
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.ratio,
    required this.durationLabel,
    required this.onSeekRatio,
  });

  final double ratio;
  final String durationLabel;
  final ValueChanged<double> onSeekRatio;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hitHeight = ui(20);
    return SizedBox(
      height: hitHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _GradientSlider(ratio: ratio, onSeekRatio: onSeekRatio),
          ),
          // 时间标签：贴近可见进度条上方（轨道顶在 y=(20-4)/2=8，
          // bottom: 14 → 标签底边 y=6，距离轨道顶视觉约 ~4px）。
          Positioned(
            right: 0,
            bottom: ui(14),
            child: Text(
              durationLabel,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 自绘的紫色渐变进度条（带阴影 thumb），不依赖 Material Slider，
/// 以严格匹配设计稿中 #E2D0FF → #8741FF 的渐变填充与 12×12 thumb。
///
/// 关键交互优化（针对 iPad / iOS 上拖动卡顿、延迟大）：
///   1. 拖动期间 thumb 位置使用本地 `_dragRatio` 直绘，不再等 native
///      `player.seek()` 回来才动 —— 即时跟手；
///   2. `onSeekRatio` 节流到 ~60ms / 帧，配合 controller 端的 seek 合并，
///      保证同一时刻只有一次 native seek 在飞，松手必收敛到最新位置；
///   3. 松手后保留 250ms grace 再清掉 `_dragRatio`，给 player.stream.position
///      留出收敛时间，避免松手瞬间 thumb"回弹"到旧位置再跳回去。
class _GradientSlider extends StatefulWidget {
  const _GradientSlider({required this.ratio, required this.onSeekRatio});

  final double ratio;
  final ValueChanged<double> onSeekRatio;

  @override
  State<_GradientSlider> createState() => _GradientSliderState();
}

class _GradientSliderState extends State<_GradientSlider> {
  /// 用户拖动 / 单击期间的本地 thumb 位置；非空时覆盖 [widget.ratio]。
  double? _dragRatio;
  double? _lastEmittedRatio;
  DateTime _lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _trailingTimer;
  Timer? _graceTimer;

  /// 节流间隔：拖动期间最多每 60ms 真正下发一次 seek。配合 controller
  /// 的 seek 合并，60ms 已经足够丝滑（>16fps），不会让 native 队列堆积。
  static const Duration _kThrottle = Duration(milliseconds: 60);

  /// 松手后保留 `_dragRatio` 的 grace 时间。给 native player.seek 收敛、
  /// position stream 追上目标位置留时间，避免"thumb 闪一下旧位置"。
  static const Duration _kGrace = Duration(milliseconds: 250);

  @override
  void dispose() {
    _trailingTimer?.cancel();
    _graceTimer?.cancel();
    super.dispose();
  }

  /// 把最新 `r` 写到 `_dragRatio` 即时刷新 thumb；同时按 60ms 节流向外
  /// 透出 `onSeekRatio`，落在节流窗内的中间帧只挂一个 trailing timer，
  /// 保证窗口结束时一定补发"最后一帧"位置。
  void _emit(double r, {bool flush = false}) {
    // 如果 grace 还在跑（上一次松手到清空 _dragRatio 的过渡期），用户
    // 又重新摸了一下，立刻把 grace 取消，避免它回头把 _dragRatio 抹掉。
    _graceTimer?.cancel();
    _graceTimer = null;

    if (_dragRatio != r) {
      setState(() => _dragRatio = r);
    }

    final now = DateTime.now();
    if (flush || now.difference(_lastEmitAt) >= _kThrottle) {
      _lastEmitAt = now;
      _lastEmittedRatio = r;
      _trailingTimer?.cancel();
      _trailingTimer = null;
      widget.onSeekRatio(r);
    } else {
      _trailingTimer?.cancel();
      _trailingTimer = Timer(_kThrottle, () {
        if (!mounted) return;
        final pending = _dragRatio;
        if (pending == null) return;
        if (_lastEmittedRatio == pending) return;
        _lastEmitAt = DateTime.now();
        _lastEmittedRatio = pending;
        widget.onSeekRatio(pending);
      });
    }
  }

  void _endDrag() {
    final pending = _dragRatio;
    if (pending != null && pending != _lastEmittedRatio) {
      _trailingTimer?.cancel();
      _trailingTimer = null;
      _lastEmittedRatio = pending;
      _lastEmitAt = DateTime.now();
      widget.onSeekRatio(pending);
    }
    _graceTimer?.cancel();
    _graceTimer = Timer(_kGrace, () {
      if (!mounted) return;
      setState(() {
        _dragRatio = null;
        _lastEmittedRatio = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final trackHeight = ui(4);
    final thumbSize = ui(12);
    final hitHeight = ui(20);

    final effectiveRatio = (_dragRatio ?? widget.ratio).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * effectiveRatio;
        final thumbLeft = (width - thumbSize) * effectiveRatio;

        double localToRatio(Offset localPosition) {
          if (width <= 0) return 0;
          return (localPosition.dx / width).clamp(0.0, 1.0);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _emit(localToRatio(d.localPosition), flush: true),
          onTapUp: (_) => _endDrag(),
          onTapCancel: _endDrag,
          onHorizontalDragStart: (d) =>
              _emit(localToRatio(d.localPosition), flush: true),
          onHorizontalDragUpdate: (d) => _emit(localToRatio(d.localPosition)),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          child: SizedBox(
            height: hitHeight,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E2E5),
                    borderRadius: BorderRadius.circular(ui(23)),
                  ),
                ),
                Container(
                  height: trackHeight,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFE2D0FF), Color(0xFF8741FF)],
                    ),
                    borderRadius: BorderRadius.circular(ui(23)),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8741FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          offset: const Offset(0, 4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LongTextPanel extends StatelessWidget {
  const _LongTextPanel({required this.htmlText});

  final String htmlText;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(18)),
      decoration: BoxDecoration(
        color: const Color(0xFF101218),
        borderRadius: BorderRadius.circular(ui(14)),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SelectableText(
          htmlText
              .replaceAll(RegExp(r'<[^>]+>'), ' ')
              .replaceAll('&nbsp;', ' '),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: ui(14),
            height: 1.7,
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

/// 声乐/器乐课程左侧使用的浅色简介卡片。
/// 复用 detail.longTextHtml，剥离 HTML 标签后展示。
class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.htmlText});

  final String htmlText;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final plain = htmlText
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: SelectableText(
                plain.isEmpty ? '暂无简介' : plain,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 26 / 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Icon(icon, size: ui(16), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

class _SecondaryChipButton extends StatelessWidget {
  const _SecondaryChipButton({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.onTap,
  }) : assert(
         icon != null || iconAsset != null,
         'Either icon or iconAsset must be provided',
       );

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final leading = iconAsset != null
        ? Image.asset(
            iconAsset!,
            width: ui(20),
            height: ui(20),
            fit: BoxFit.contain,
          )
        : Icon(icon!, size: ui(16), color: const Color(0xFF1C274C));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          children: [
            leading,
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 白底描边的 chip 按钮，对应图稿"升降调"等次要操作。
class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(50),
        height: ui(24),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8741FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFFB6B5BB),
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            fontWeight: active ? AppFont.w500 : AppFont.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _InlineImageIcon extends StatelessWidget {
  const _InlineImageIcon({
    required this.asset,
    required this.onTap,
    this.size = 19,
  });

  final String asset;
  final Future<void> Function() onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        width: ui(size),
        height: ui(size),
        fit: BoxFit.contain,
      ),
    );
  }
}

/// 倍速选择 chip。点击后唤起一个极简风格的下拉浮窗：
/// - 白底、圆角 12、柔和阴影
/// - 选项行高紧凑、文字居中
/// - 当前倍速文字使用品牌紫并加粗
class _SpeedChip extends StatefulWidget {
  const _SpeedChip({required this.speed, required this.onSpeedChanged});

  final double speed;
  final ValueChanged<double> onSpeedChanged;

  /// 倍速档位（从大到小，方便用户在弹窗里默认看到加速段）。
  ///
  /// 上行（>1.0）：1.05 / 1.1 / 1.15 / 1.2 / 1.25 / 1.3 / 1.4 /
  /// 1.5 / 1.6 / 1.7 / 2.0——细粒度集中在 1.0~1.3 区间，加速练
  /// 习时方便逐档微调。
  ///
  /// 下行（<1.0）：0.95 / 0.9 / 0.85 / 0.8 / 0.75 / 0.7 / 0.6 /
  /// 0.5——同样在 0.75~1.0 区间细分，便于慢速练习。
  static const List<double> options = <double>[
    2.0,
    1.7,
    1.6,
    1.5,
    1.4,
    1.3,
    1.25,
    1.2,
    1.15,
    1.1,
    1.05,
    1.0,
    0.95,
    0.9,
    0.85,
    0.8,
    0.75,
    0.7,
    0.6,
    0.5,
  ];

  static String formatSpeed(double value) {
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) {
        text = '${text}0';
      }
    }
    return '${text}x';
  }

  @override
  State<_SpeedChip> createState() => _SpeedChipState();
}

class _SpeedChipState extends State<_SpeedChip> {
  bool _open = false;

  Future<void> _showMenu(BuildContext context) async {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    final Size size = box.size;
    final double menuWidth = ui(96);
    final double itemHeight = ui(34);
    final double padding = ui(6);
    // 选项最多展示 6 行；多于 6 行启用纵向滚动，避免弹窗顶/底超界。
    const int maxVisible = 6;
    final int visibleCount = math.min(_SpeedChip.options.length, maxVisible);
    final double menuHeight = visibleCount * itemHeight + padding * 2;
    final double gap = ui(8);

    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox;
    final Size overlaySize = overlay.size;

    double left = topLeft.dx + (size.width - menuWidth) / 2;
    left = left.clamp(ui(8), overlaySize.width - menuWidth - ui(8));
    final double topAbove = topLeft.dy - menuHeight - gap;
    final double topBelow = topLeft.dy + size.height + gap;
    final bool above = topAbove >= ui(8);
    final double top = above ? topAbove : topBelow;

    setState(() => _open = true);

    final selected = await showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'speed_menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondary) {
        return DashboardScaleScope(
          data: scale,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: menuWidth,
                height: menuHeight,
                child: _SpeedMenuCard(
                  options: _SpeedChip.options,
                  current: widget.speed,
                  itemHeight: itemHeight,
                  padding: padding,
                  onPick: (value) => Navigator.of(dialogContext).pop(value),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final offsetTween = above
            ? Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            : Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: offsetTween.animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() => _open = false);
    if (selected != null && selected != widget.speed) {
      widget.onSpeedChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMenu(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        decoration: BoxDecoration(
          color: _open ? const Color(0xFFF5F2FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _SpeedChip.formatSpeed(widget.speed),
              style: TextStyle(
                color: _open
                    ? const Color(0xFF8741FF)
                    : const Color(0xFF7F7F7F),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 12,
              ),
            ),
            SizedBox(width: ui(2)),
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              turns: _open ? 0.5 : 0,
              child: Image.asset(
                'assets/images/home/chevron-down.png',
                width: ui(12),
                height: ui(12),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedMenuCard extends StatefulWidget {
  const _SpeedMenuCard({
    required this.options,
    required this.current,
    required this.itemHeight,
    required this.padding,
    required this.onPick,
  });

  final List<double> options;
  final double current;
  final double itemHeight;
  final double padding;
  final ValueChanged<double> onPick;

  @override
  State<_SpeedMenuCard> createState() => _SpeedMenuCardState();
}

class _SpeedMenuCardState extends State<_SpeedMenuCard> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.options.indexOf(widget.current);
    final initialOffset = selectedIndex < 0
        ? 0.0
        : math.max(
            0.0,
            (selectedIndex - 2) * widget.itemHeight,
          );
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8741FF).withValues(alpha: 0.10),
              blurRadius: ui(20),
              spreadRadius: 0,
              offset: Offset(0, ui(8)),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: ui(8),
              spreadRadius: 0,
              offset: Offset(0, ui(2)),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ScrollConfiguration(
          behavior: const _NoOverscrollBehavior(),
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: widget.padding),
            itemCount: widget.options.length,
            itemExtent: widget.itemHeight,
            itemBuilder: (_, index) {
              final value = widget.options[index];
              return _SpeedMenuItem(
                label: _SpeedChip.formatSpeed(value),
                height: widget.itemHeight,
                selected: value == widget.current,
                onTap: () => widget.onPick(value),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 弹窗内的滚动列表禁用 overscroll glow，视觉更纯净。
class _NoOverscrollBehavior extends ScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _SpeedMenuItem extends StatefulWidget {
  const _SpeedMenuItem({
    required this.label,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SpeedMenuItem> createState() => _SpeedMenuItemState();
}

class _SpeedMenuItemState extends State<_SpeedMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selected = widget.selected;
    final highlighted = selected || _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.height,
          margin: EdgeInsets.symmetric(horizontal: ui(6)),
          padding: EdgeInsets.symmetric(horizontal: ui(10)),
          decoration: BoxDecoration(
            color: highlighted ? const Color(0xFFF5F2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF8741FF)
                        : const Color(0xFF0B081A),
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                    fontWeight: selected ? AppFont.w600 : AppFont.w400,
                    height: 1,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: ui(14),
                  color: const Color(0xFF8741FF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部"升降调"按钮：沿用之前 outlined chip 的视觉
/// （白底、灰边、icon + 文字），点击后从按钮下方弹出与
/// [_SpeedChip] 同款的下拉菜单，可滚动选择半音档位（-12..+12，一个八度）。
///
/// 视觉规则：
/// - 未升降调（0）：标签固定显示"升降调"，跟原设计保持一致；
/// - 已升降调：标签变成"升降调 +N" / "升降调 -N"，并把文字染成品牌紫
///   作为视觉提示（不改变背景/边框，避免破坏原来的极简感）。
class _TransposeChipButton extends StatefulWidget {
  const _TransposeChipButton({
    required this.pitchSemitones,
    required this.onPitchChanged,
  });

  final int pitchSemitones;
  final ValueChanged<int> onPitchChanged;

  /// 半音档位（从大到小，便于升调用户在弹窗第一屏看到正向区间）。
  /// 与 [MusicPlayController.setPitchSemitones] 的 `clamp(-12, 12)` 一致。
  static final List<int> options = <int>[
    for (var v = 12; v >= -12; v--) v,
  ];

  /// 弹窗每一行展示的纯档位值（"原调" / "+N" / "-N"）。
  static String formatPitch(int value) {
    if (value == 0) {
      return '原调';
    }
    return value > 0 ? '+$value' : '$value';
  }

  /// chip 自身上展示的标签，0 时退回原文案"升降调"。
  static String formatChipLabel(int value) {
    if (value == 0) {
      return '升降调';
    }
    return value > 0 ? '升降调 +$value' : '升降调 $value';
  }

  @override
  State<_TransposeChipButton> createState() => _TransposeChipButtonState();
}

class _TransposeChipButtonState extends State<_TransposeChipButton> {
  bool _open = false;

  Future<void> _showMenu(BuildContext context) async {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    final Size size = box.size;
    final double menuWidth = math.max(ui(96), size.width);
    final double itemHeight = ui(34);
    final double padding = ui(6);
    const int maxVisible = 6;
    final int visibleCount = math.min(
      _TransposeChipButton.options.length,
      maxVisible,
    );
    final double menuHeight = visibleCount * itemHeight + padding * 2;
    final double gap = ui(8);

    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox;
    final Size overlaySize = overlay.size;

    // 默认贴右对齐，让菜单的右边缘与按钮右边缘对齐——
    // 这样菜单不会"跑到屏幕外面"，符合右上角触发的视觉直觉。
    double left = topLeft.dx + size.width - menuWidth;
    left = left.clamp(ui(8), overlaySize.width - menuWidth - ui(8));
    final double topBelow = topLeft.dy + size.height + gap;
    final double topAbove = topLeft.dy - menuHeight - gap;
    // 因为按钮在右上角，优先朝下展开；下方放不下再向上。
    final bool below = topBelow + menuHeight <= overlaySize.height - ui(8);
    final double top = below ? topBelow : topAbove;

    setState(() => _open = true);

    final selected = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'transpose_menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondary) {
        return DashboardScaleScope(
          data: scale,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: menuWidth,
                height: menuHeight,
                child: _PitchMenuCard(
                  options: _TransposeChipButton.options,
                  current: widget.pitchSemitones,
                  itemHeight: itemHeight,
                  padding: padding,
                  onPick: (value) => Navigator.of(dialogContext).pop(value),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final offsetTween = below
            ? Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero)
            : Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: offsetTween.animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() => _open = false);
    if (selected != null && selected != widget.pitchSemitones) {
      widget.onPitchChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tinted = widget.pitchSemitones != 0;
    final labelColor = tinted
        ? const Color(0xFF8741FF)
        : const Color(0xFF0B081A);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMenu(context),
      child: Container(
        height: ui(28),
        padding: EdgeInsets.fromLTRB(ui(12), ui(4), ui(13), ui(4)),
        decoration: BoxDecoration(
          color: _open ? const Color(0xFFF5F2FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/home/dictation/9.png',
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(4)),
            Text(
              _TransposeChipButton.formatChipLabel(widget.pitchSemitones),
              style: TextStyle(
                color: labelColor,
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PitchMenuCard extends StatefulWidget {
  const _PitchMenuCard({
    required this.options,
    required this.current,
    required this.itemHeight,
    required this.padding,
    required this.onPick,
  });

  final List<int> options;
  final int current;
  final double itemHeight;
  final double padding;
  final ValueChanged<int> onPick;

  @override
  State<_PitchMenuCard> createState() => _PitchMenuCardState();
}

class _PitchMenuCardState extends State<_PitchMenuCard> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.options.indexOf(widget.current);
    final initialOffset = selectedIndex < 0
        ? 0.0
        : math.max(0.0, (selectedIndex - 2) * widget.itemHeight);
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8741FF).withValues(alpha: 0.10),
              blurRadius: ui(20),
              spreadRadius: 0,
              offset: Offset(0, ui(8)),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: ui(8),
              spreadRadius: 0,
              offset: Offset(0, ui(2)),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ScrollConfiguration(
          behavior: const _NoOverscrollBehavior(),
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: widget.padding),
            itemCount: widget.options.length,
            itemExtent: widget.itemHeight,
            itemBuilder: (_, index) {
              final value = widget.options[index];
              return _SpeedMenuItem(
                label: _TransposeChipButton.formatPitch(value),
                height: widget.itemHeight,
                selected: value == widget.current,
                onTap: () => widget.onPick(value),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 循环模式 chip：和 [_SpeedChip] 一致的极简胶囊外观，但点击不弹菜单，
/// 而是直接切到下一档（顺序 → 单曲 → 随机 → 顺序）。
/// 复刻 1.0 中 `play-sx.png / play-xh.png / play_sj.png` 的"一键三态"。
class _LoopModeChip extends StatelessWidget {
  const _LoopModeChip({required this.mode, required this.onTap});

  final MusicPlayMode mode;
  final VoidCallback onTap;

  static String _label(MusicPlayMode mode) {
    switch (mode) {
      case MusicPlayMode.sequence:
        return '顺序循环';
      case MusicPlayMode.single:
        return '单曲循环';
      case MusicPlayMode.shuffle:
        return '随机播放';
    }
  }

  /// 应用户要求：循环模式按钮换成设计稿提供的纯图（紫色洗牌 / 灰色循环 /
  /// 紫色单曲循环），不再使用 Material Icons 字体图标。三种模式都各自带有
  /// 设计师指定的颜色与高亮信息，因此这里不再附加染色背景，整体保持透明，
  /// 只让图自己说话。
  static String _asset(MusicPlayMode mode) {
    switch (mode) {
      case MusicPlayMode.sequence:
        return AppAssets.homeLoopPlayMode;
      case MusicPlayMode.single:
        return AppAssets.homeSingleLoopPlayMode;
      case MusicPlayMode.shuffle:
        return AppAssets.homeShufflePlayMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Tooltip(
      message: _label(mode),
      waitDuration: const Duration(milliseconds: 400),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: ui(28),
          width: ui(28),
          child: Center(
            child: Image.asset(
              _asset(mode),
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

/// 播放列表 chip：点击后从 APP 左侧弹出抽屉（与左侧导航同宽，盖在导航之上）。
///
/// 设计变化（旧版 → 新版）：
///   旧版 v1：按钮上方一个 220×260 的浮动卡片，整张通过 showGeneralDialog
///            出现，barrier 透明但仍然吃点击事件，所以一旦菜单弹出，右侧
///            播放器的暂停 / 切歌都点不动了。
///   旧版 v2：手动 OverlayEntry + didUpdateWidget 里 markNeedsBuild。父级
///            播放条因为 position 流每 ~100ms rebuild，频繁 markNeedsBuild
///            和点击 [onSelect] 触发的同帧 setState 叠加在一起，偶发会让
///            抽屉里的 builder 抛断言（"setState/markNeedsBuild called when
///            widget tree was locked"），iPad 上肉眼会闪一帧 ErrorWidget；
///            紧接着布局重算时播放条重叠成两条。
///   新版 v3：改用 [OverlayPortal.targetsRootOverlay]——抽屉的生命周期由
///            Flutter 自己接管：父级 rebuild 自动同步、dispose 时自动清理，
///            不再需要手动 OverlayEntry / markNeedsBuild。这条链路 Flutter
///            内部已经处理了所有"在 build 锁期间触发重建"的边界情况。
class _PlaylistChip extends StatefulWidget {
  const _PlaylistChip({
    required this.tracks,
    required this.activeIndex,
    required this.onSelect,
  });

  final List<MusicPlayTrack> tracks;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_PlaylistChip> createState() => _PlaylistChipState();
}

class _PlaylistChipState extends State<_PlaylistChip> {
  /// `OverlayPortalController` 由 Flutter 维护抽屉的可见性。show / hide /
  /// toggle 都安全可重入；isShowing 即时返回是否在显示。
  final OverlayPortalController _portal = OverlayPortalController();

  void _toggle() {
    if (widget.tracks.isEmpty) return;
    setState(() {
      if (_portal.isShowing) {
        _portal.hide();
      } else {
        _portal.show();
      }
    });
  }

  void _close() {
    if (!_portal.isShowing) return;
    setState(() {
      _portal.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final open = _portal.isShowing;
    // OverlayPortal 把 [overlayChildBuilder] 渲染到根 Overlay 的 Stack 里，
    // 与本 chip 的 build 在同一棵元素树里关联——父级 rebuild 时它会"自动"
    // 跟着 rebuild 拿到最新的 widget.tracks/activeIndex，不需要手动
    // markNeedsBuild。点击抽屉外部不会触发它收起（无 barrier）。
    return OverlayPortal.targetsRootOverlay(
      controller: _portal,
      overlayChildBuilder: (overlayContext) {
        return _PlaylistDrawer(
          tracks: widget.tracks,
          activeIndex: widget.activeIndex,
          // 点击曲目只切歌、不再自动收起；用户需要时再点 chip 或抽屉关闭
          // 按钮才会收起，长列表里连续试听无需反复展开/收起。
          onSelect: widget.onSelect,
          onClose: _close,
        );
      },
      child: Tooltip(
        message: '音频列表',
        waitDuration: const Duration(milliseconds: 400),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: SizedBox(
            height: ui(28),
            width: ui(28),
            child: Center(
              // 设计稿提供的 list.png 自带紫色音符 + 列表线条，整体已经是带
              // 颜色的图标；这里只在打开态外面加一层淡淡的圆角紫底暗示"已激活"。
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                height: ui(24),
                width: ui(24),
                decoration: BoxDecoration(
                  color: open ? const Color(0xFFF5F2FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  AppAssets.homePlaylistIcon,
                  width: ui(20),
                  height: ui(20),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 左侧抽屉的实际渲染件：一个 178 dp 宽、覆盖屏幕左侧整高的卡片，进场
/// 自带左滑入动画。该 widget 故意不放在 Stack 顶层覆盖整屏，而是使用
/// `Positioned(left:0, top:0, bottom:0, width: sidebarWidth)`，因此除了
/// 抽屉自身覆盖到的 178 dp 区域，其余像素事件原样穿透到下方的 ShellScaffold
/// （播放器、设置、悬浮气泡均可正常响应）。
class _PlaylistDrawer extends StatefulWidget {
  const _PlaylistDrawer({
    required this.tracks,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  final List<MusicPlayTrack> tracks;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  @override
  State<_PlaylistDrawer> createState() => _PlaylistDrawerState();
}

class _PlaylistDrawerState extends State<_PlaylistDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slide.forward();

    final initialIdx = widget.activeIndex;
    final initialOffset = initialIdx < 0
        ? 0.0
        : math.max(0.0, (initialIdx - 4) * 44.0);
    _scroll = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _slide.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final width = ui(ShellLayoutSpec.sidebarWidth);
    final mediaPad = MediaQuery.paddingOf(context);
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: width,
      // 让 drawer 自身的指针事件全部消化在 178 dp 内；抽屉以外的屏幕区域
      // 由于这个 Positioned 不存在，事件原样穿透到下方播放器。
      child: AnimatedBuilder(
        animation: _slide,
        builder: (ctx, child) {
          final value = Curves.easeOutCubic.transform(_slide.value);
          return Transform.translate(
            offset: Offset(-width * (1 - value), 0),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FC),
              border: Border(
                right: BorderSide(
                  color: const Color(0xFFE4E1EC),
                  width: 1,
                ),
              ),
              boxShadow: [
                // 仅给抽屉的右边缘加一道淡阴影，做出"浮在导航之上"的层次。
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(2, 0),
                  blurRadius: 12,
                ),
              ],
            ),
            child: SafeArea(
              right: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header：左侧标题，右侧关闭按钮，整体高度对齐顶栏 56。
                  SizedBox(
                    height: ui(56),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        ui(16),
                        0,
                        ui(8),
                        0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '音频列表',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF0B081A),
                                fontSize: ui(16),
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w600,
                                height: 1,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onClose,
                            child: SizedBox(
                              width: ui(36),
                              height: ui(36),
                              child: Center(
                                child: Icon(
                                  Icons.close_rounded,
                                  size: ui(20),
                                  color: const Color(0xFF7F7F7F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // List：使用与 [ShellLeftNav] 一致的 178 dp 宽度的窄行布局；
                  // 选中态用紫色文字 + 浅紫底块，与左侧导航选中样式视觉对齐。
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const _NoOverscrollBehavior(),
                      child: ListView.builder(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(
                          ui(8),
                          ui(4),
                          ui(8),
                          mediaPad.bottom + ui(8),
                        ),
                        itemCount: widget.tracks.length,
                        itemBuilder: (_, index) {
                          final track = widget.tracks[index];
                          final selected = index == widget.activeIndex;
                          return _PlaylistDrawerItem(
                            index: index,
                            title: track.title,
                            selected: selected,
                            onTap: () => widget.onSelect(index),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 抽屉里的单条曲目。
///
/// 应用户反馈："切歌瞬间旧曲目会闪一下灰色"——这是先前实现的 hover/选中
/// 高亮 [AnimatedContainer] 在 `#EDE6FF → Colors.transparent` 之间做颜色
/// 插值时经过的"半透明灰紫"造成的。这里彻底去掉点击/悬浮态：
///   - 去掉 hover 跟踪（StatefulWidget → StatelessWidget），抬手不再变色；
///   - 去掉 [AnimatedContainer]，背景色直接根据 [selected] 即时切换，
///     不再做 120ms 的颜色动画——切歌时一帧之内完成"旧项褪色 + 新项点亮"，
///     视觉上不会产生任何过渡灰色。
class _PlaylistDrawerItem extends StatelessWidget {
  const _PlaylistDrawerItem({
    required this.index,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(40),
        margin: EdgeInsets.symmetric(vertical: ui(2)),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEDE6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: ui(22),
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF8741FF)
                      : const Color(0xFFB6B5BB),
                  fontSize: ui(12),
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
            SizedBox(width: ui(6)),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF8741FF)
                      : const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: selected ? AppFont.w600 : AppFont.w400,
                  height: 1,
                ),
              ),
            ),
            if (selected) ...[
              SizedBox(width: ui(4)),
              Icon(
                Icons.equalizer_rounded,
                size: ui(14),
                color: const Color(0xFF8741FF),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FrequencyVisualizer extends StatelessWidget {
  const _FrequencyVisualizer({
    required this.frequencyBands,
    required this.playing,
    required this.height,
  });

  final List<double> frequencyBands;
  final bool playing;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (frequencyBands.isNotEmpty || !playing) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FrequencyVisualizerPainter(
            frequencyBands: frequencyBands,
            time: 0,
            playing: playing,
          ),
        ),
      );
    }
    return _AnimatedFrequencyFallback(height: height);
  }
}

class _AnimatedFrequencyFallback extends StatefulWidget {
  const _AnimatedFrequencyFallback({required this.height});

  final double height;

  @override
  State<_AnimatedFrequencyFallback> createState() =>
      _AnimatedFrequencyFallbackState();
}

class _AnimatedFrequencyFallbackState extends State<_AnimatedFrequencyFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _FrequencyVisualizerPainter(
              frequencyBands: const <double>[],
              time: _controller.value,
              playing: true,
            ),
          );
        },
      ),
    );
  }
}

class _FrequencyVisualizerPainter extends CustomPainter {
  const _FrequencyVisualizerPainter({
    required this.frequencyBands,
    required this.time,
    required this.playing,
  });

  final List<double> frequencyBands;
  final double time;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final count = frequencyBands.isEmpty ? 46 : frequencyBands.length;
    const gap = 3.0;
    final barWidth = math.max(1.2, (size.width - gap * (count - 1)) / count);
    final centerY = size.height * 0.62;
    final maxUp = size.height * 0.58;
    final maxDown = size.height * 0.30;
    final radius = Radius.circular(barWidth / 2);
    final idlePaint = Paint()..color = const Color(0xFFE4E1EC);

    for (var i = 0; i < count; i++) {
      final raw = frequencyBands.isEmpty
          ? (playing ? _fallbackLevel(i, count, time) : 0.0)
          : frequencyBands[i];
      final level = raw.clamp(0.0, 1.0);
      final x = i * (barWidth + gap);
      final up = math.max(size.height * 0.08, maxUp * level);
      final down = math.max(size.height * 0.03, maxDown * level);
      final active = level > 0.015;

      final topRect = Rect.fromLTRB(x, centerY - up, x + barWidth, centerY);
      final topPaint = active
          ? (Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF8741FF), Color(0xFFC8AEFF)],
              ).createShader(topRect))
          : idlePaint;
      canvas.drawRRect(RRect.fromRectAndRadius(topRect, radius), topPaint);

      final bottomRect = Rect.fromLTRB(
        x,
        centerY,
        x + barWidth,
        centerY + down,
      );
      final bottomPaint = active
          ? (Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x668741FF), Color(0x00C8AEFF)],
              ).createShader(bottomRect))
          : idlePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bottomRect, radius),
        bottomPaint,
      );
    }
  }

  double _fallbackLevel(int index, int count, double t) {
    final phase = t * math.pi * 2;
    final waveA = math.sin(phase * 1.4 + index * 0.52);
    final waveB = math.sin(phase * 2.1 + index * 0.21);
    final envelope = math.sin(index / (count - 1) * math.pi);
    return (0.18 + (waveA * 0.18 + waveB * 0.12 + 0.30) * envelope).clamp(
      0.04,
      0.88,
    );
  }

  @override
  bool shouldRepaint(covariant _FrequencyVisualizerPainter oldDelegate) {
    return oldDelegate.frequencyBands != frequencyBands ||
        oldDelegate.time != time ||
        oldDelegate.playing != playing;
  }
}
