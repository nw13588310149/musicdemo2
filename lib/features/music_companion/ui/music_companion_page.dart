import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../piano/ui/piano_keyboard.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/music_companion_controller.dart';
import '../state/music_companion_state.dart';
import 'widgets/piano_visualizer.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class MusicCompanionV2Page extends ConsumerStatefulWidget {
  const MusicCompanionV2Page({super.key});

  @override
  ConsumerState<MusicCompanionV2Page> createState() =>
      _MusicCompanionV2PageState();
}

class _MusicCompanionV2PageState extends ConsumerState<MusicCompanionV2Page> {
  @override
  Widget build(BuildContext context) {
    ref.listen<MusicCompanionState>(musicCompanionControllerProvider, (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message == null || message == previous?.errorMessage || !mounted) {
        return;
      }
      AppToast.show(context, message);
      ref.read(musicCompanionControllerProvider.notifier).clearError();
    });

    final state = ref.watch(musicCompanionControllerProvider);
    final controller = ref.read(musicCompanionControllerProvider.notifier);
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    // Outer padding is moved INSIDE each tab pane so the piano keyboard can
    // sit flush with the surface edges (full-bleed) for a more immersive
    // look. ClipRRect respects the panel's rounded corners so the piano's
    // drop shadow never leaks past them. Metronome / Tuner panes get a
    // wrapper Padding that reproduces the previous outer page padding.
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(ShellLayoutSpec.panelRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(18), ui(18), ui(18), 0),
              child: _CompanionTabBar(
                activeTab: state.activeTab,
                onTabSelected: controller.setTab,
              ),
            ),
            SizedBox(height: ui(18)),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (state.activeTab) {
                  MusicCompanionTab.piano => _VirtualPianoPane(
                    key: const ValueKey<String>('music_piano'),
                    audioReady: state.audioReady,
                    activeNotes: state.activePianoNotes,
                    onPressKey: controller.pressPianoKey,
                    onReleaseKey: controller.releasePianoKey,
                  ),
                  MusicCompanionTab.metronome => Padding(
                    key: const ValueKey<String>('music_metronome'),
                    padding: EdgeInsets.fromLTRB(ui(18), 0, ui(18), ui(16)),
                    child: _MetronomePane(
                      state: state,
                      onToneSelected: controller.setMetronomeTone,
                      onSignatureSelected: controller.setMetronomeSignature,
                      onToggle: controller.toggleMetronome,
                      onBpmChanged: controller.setMetronomeBpm,
                      onDecreaseBpm: () => controller.nudgeMetronomeBpm(-1),
                      onIncreaseBpm: () => controller.nudgeMetronomeBpm(1),
                    ),
                  ),
                  MusicCompanionTab.tuner => Padding(
                    key: const ValueKey<String>('music_tuner'),
                    padding: EdgeInsets.fromLTRB(ui(18), 0, ui(18), ui(16)),
                    child: _TunerPane(
                      state: state,
                      onDecreaseFrequency: () =>
                          controller.nudgeTunerReferenceFrequency(-1),
                      onIncreaseFrequency: () =>
                          controller.nudgeTunerReferenceFrequency(1),
                      onUse442Hz: () =>
                          controller.setTunerReferenceFrequency(442),
                      onRetryPermission: controller.retryTunerPermission,
                    ),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionTabBar extends StatelessWidget {
  const _CompanionTabBar({
    required this.activeTab,
    required this.onTabSelected,
  });

  final MusicCompanionTab activeTab;
  final ValueChanged<MusicCompanionTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final tabs = MusicCompanionTab.values;
    return Container(
      // 用 minHeight 代替固定 height，确保中文字符在不同 DPI 下不被裁剪。
      constraints: BoxConstraints(minHeight: ui(44)),
      padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < tabs.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: ui(16)),
            _CompanionTabItem(
              tab: tabs[i],
              active: activeTab == tabs[i],
              onTap: () => onTabSelected(tabs[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanionTabItem extends StatelessWidget {
  const _CompanionTabItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final MusicCompanionTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final label = switch (tab) {
      MusicCompanionTab.piano => '虚拟钢琴',
      MusicCompanionTab.metronome => '节拍器',
      MusicCompanionTab.tuner => '调音器',
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          // Figma: active 6px、inactive 8px
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x59B5B5B5),
                    blurRadius: ui(20),
                    offset: Offset(0, ui(8)),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            height: 1.2,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            color: active ? const Color(0xFF0B081A) : const Color(0xFF6D6B75),
          ),
        ),
      ),
    );
  }
}

class _VirtualPianoPane extends StatelessWidget {
  const _VirtualPianoPane({
    required this.audioReady,
    required this.activeNotes,
    required this.onPressKey,
    required this.onReleaseKey,
    super.key,
  });

  final bool audioReady;
  final Set<String> activeNotes;
  final Future<void> Function(String token) onPressKey;
  final ValueChanged<String> onReleaseKey;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Visualizer keeps the original horizontal inset (page 18 + internal 24
    // = 42) so its on-screen position is unchanged. The keyboard, in
    // contrast, fills the full pane width and butts up against the panel
    // bottom for the immersive look.
    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(42)),
                child: RepaintBoundary(
                  child: PianoVisualizer(activeNotes: activeNotes),
                ),
              ),
            ),
            SizedBox(height: ui(18)),
            RepaintBoundary(
              child: PianoKeyboard(
                activeNotes: activeNotes,
                onPress: onPressKey,
                onRelease: onReleaseKey,
                height: 240,
              ),
            ),
          ],
        ),
        if (!audioReady)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: const Color(0x660B081A),
                child: Center(
                  child: Text(
                    '钢琴音频加载中…',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetronomePane extends StatelessWidget {
  const _MetronomePane({
    required this.state,
    required this.onToneSelected,
    required this.onSignatureSelected,
    required this.onToggle,
    required this.onBpmChanged,
    required this.onDecreaseBpm,
    required this.onIncreaseBpm,
  });

  final MusicCompanionState state;
  final ValueChanged<int> onToneSelected;
  final ValueChanged<int> onSignatureSelected;
  final Future<void> Function() onToggle;
  final ValueChanged<double> onBpmChanged;
  final VoidCallback onDecreaseBpm;
  final VoidCallback onIncreaseBpm;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    // First row: 12 signatures laid out 6 per row by splitting in two halves.
    final signatures = kMusicCompanionSignatures;
    final half = (signatures.length / 2).ceil();
    final firstRow = signatures.sublist(0, half);
    final secondRow = signatures.sublist(half);

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(18), ui(18), ui(18), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetronomeHeaderCard(state: state, onToggle: onToggle),
          SizedBox(height: ui(20)),
          Text(
            '音色选择',
            style: TextStyle(
              fontSize: ui(16),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 28 / 16,
              color: Colors.black,
            ),
          ),
          SizedBox(height: ui(12)),
          Row(
            children: [
              for (var i = 0; i < kMusicCompanionToneOptions.length; i++) ...[
                _ChoiceChipButton(
                  label: kMusicCompanionToneOptions[i].label,
                  selected: i == state.metronomeToneIndex,
                  onTap: () => onToneSelected(i),
                ),
                if (i != kMusicCompanionToneOptions.length - 1)
                  SizedBox(width: ui(24)),
              ],
            ],
          ),
          SizedBox(height: ui(20)),
          Text(
            '节拍选择',
            style: TextStyle(
              fontSize: ui(16),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 28 / 16,
              color: Colors.black,
            ),
          ),
          SizedBox(height: ui(12)),
          _SignatureRow(
            signatures: firstRow,
            offset: 0,
            activeIndex: state.metronomeSignatureIndex,
            onSelect: onSignatureSelected,
          ),
          SizedBox(height: ui(24)),
          _SignatureRow(
            signatures: secondRow,
            offset: half,
            activeIndex: state.metronomeSignatureIndex,
            onSelect: onSignatureSelected,
          ),
          const Spacer(),
          _MetronomeTempoSlider(
            bpm: state.metronomeBpm,
            onChanged: onBpmChanged,
            onDecrease: onDecreaseBpm,
            onIncrease: onIncreaseBpm,
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of signature chips with a fixed leading [offset] used to
/// translate the chip's local index into the global signature index.
class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.signatures,
    required this.offset,
    required this.activeIndex,
    required this.onSelect,
  });

  final List<MusicCompanionSignature> signatures;
  final int offset;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (var i = 0; i < signatures.length; i++) ...[
          _ChoiceChipButton(
            label: signatures[i].label,
            selected: (offset + i) == activeIndex,
            labelWidth: ui(32),
            onTap: () => onSelect(offset + i),
          ),
          if (i != signatures.length - 1) SizedBox(width: ui(24)),
        ],
      ],
    );
  }
}

class _MetronomeHeaderCard extends StatelessWidget {
  const _MetronomeHeaderCard({required this.state, required this.onToggle});

  final MusicCompanionState state;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final beatCount = state.activeSignature.visualBeatCount;
    final activeDot = state.metronomePlaying && state.metronomeActiveBeat >= 0
        ? state.metronomeActiveBeat % beatCount
        : -1;

    // BPM 15..300 → pointer angle -75°..+75° (pivot at the gauge bottom).
    final fraction = ((state.metronomeBpm - 15) / 285).clamp(0.0, 1.0);
    final pointerAngle = (fraction * 2 - 1) * (75 * math.pi / 180);

    return Container(
      width: double.infinity,
      height: ui(140),
      // Right padding is bumped to 40 so the 72×72 play/pause button sits
      // 40px in from the card's right border (per spec).
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(40), ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          // ── gauge: 1.png background + 2.png rotating pointer ──
          SizedBox(
            width: ui(198),
            height: ui(108),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Image.asset(
                    'assets/images/music/1.png',
                    width: ui(198),
                    height: ui(99),
                    fit: BoxFit.contain,
                  ),
                ),
                // Pointer pivot is at the bottom-center of the 36x76 image,
                // which sits horizontally centered inside the 198-wide gauge
                // and bottom-aligns to the gauge's vertical center axis.
                Positioned(
                  left: ui(99) - ui(18),
                  top: ui(99) - ui(76),
                  width: ui(36),
                  height: ui(76),
                  child: Transform.rotate(
                    angle: pointerAngle,
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      'assets/images/music/2.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // ── beat dots ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < beatCount; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: ui(20),
                  height: ui(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == activeDot
                        ? const Color(0xFF8741FF)
                        : const Color(0xFFE6E9F1),
                  ),
                ),
                if (i != beatCount - 1) SizedBox(width: ui(16)),
              ],
            ],
          ),
          const Spacer(),
          // ── play / pause button ──
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: ui(72),
              height: ui(72),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF8741FF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: ui(1)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x33874BFF),
                    blurRadius: ui(16),
                    offset: Offset(0, ui(8)),
                  ),
                ],
              ),
              child: Icon(
                state.metronomePlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: ui(32),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.labelWidth,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When provided, the inner text is wrapped in a fixed-width box so signature
  /// labels (`1/4` vs `12/8`) align in a predictable grid.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final textStyle = TextStyle(
      fontSize: ui(14),
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      color: selected ? Colors.white : const Color(0xFF0B081A),
    );
    // `softWrap: false` + `overflow: visible` keeps wider labels (`12/8`)
    // on a single line even when the fixed `labelWidth` is too narrow for
    // them; without it Flutter breaks the slash onto a second line.
    final Widget labelWidget = labelWidth != null
        ? SizedBox(
            width: labelWidth,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: textStyle,
            ),
          )
        : Text(label, maxLines: 1, softWrap: false, style: textStyle);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(36), vertical: ui(10)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0B081A) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: labelWidget,
      ),
    );
  }
}

class _MetronomeTempoSlider extends StatelessWidget {
  const _MetronomeTempoSlider({
    required this.bpm,
    required this.onChanged,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int bpm;
  final ValueChanged<double> onChanged;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    // Card geometry mirrors the design spec (880×82 inside 920×72 reference).
    return Container(
      height: ui(82),
      padding: EdgeInsets.symmetric(horizontal: ui(32)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final trackY = height / 2;

          // Reserve room for the +/- buttons (48×48) at both ends and a small
          // gap before the track itself starts.
          final actionSize = ui(48);
          final trackInset = actionSize + ui(16);
          final trackLeft = trackInset;
          final trackRight = width - trackInset;
          final trackWidth = trackRight - trackLeft;
          final fraction = ((bpm - 15) / 285).clamp(0.0, 1.0);
          final thumbCenter = trackLeft + trackWidth * fraction;

          void updateFromX(double localX) {
            final normalized = ((localX - trackLeft) / trackWidth).clamp(
              0.0,
              1.0,
            );
            onChanged(15 + normalized * 285);
          }

          // Drag/tap region spans the entire track row (including under
          // the thumb image) so we can map the finger's absolute X position
          // directly to a BPM. Using `localPosition.dx` avoids the lag of
          // delta-based updates – every pointer event becomes a 1:1 jump
          // to the touched coordinate, making the slider feel sticky to
          // the finger even during fast drags.
          void onPointerEventX(double localX) {
            updateFromX(localX + trackLeft);
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Minus button (image-based, sits at left).
              Positioned(
                left: 0,
                top: (height - actionSize) / 2,
                child: _TempoIconButton(
                  asset: 'assets/images/music/4.png',
                  size: actionSize,
                  onTap: onDecrease,
                ),
              ),
              // Plus button.
              Positioned(
                right: 0,
                top: (height - actionSize) / 2,
                child: _TempoIconButton(
                  asset: 'assets/images/music/5.png',
                  size: actionSize,
                  onTap: onIncrease,
                ),
              ),
              // Background track (visual, ignores hits so the gesture layer
              // below catches everything).
              Positioned(
                left: trackLeft,
                right: trackInset,
                top: trackY - ui(4),
                child: IgnorePointer(
                  child: Container(
                    height: ui(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(999)),
                    ),
                  ),
                ),
              ),
              // Filled portion (purple gradient, also non-interactive).
              Positioned(
                left: trackLeft,
                top: trackY - ui(4),
                child: IgnorePointer(
                  child: Container(
                    width: math.max(thumbCenter - trackLeft, ui(8)),
                    height: ui(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[Color(0xFF8741FF), Color(0xFFE2D0FF)],
                      ),
                      borderRadius: BorderRadius.circular(ui(999)),
                    ),
                  ),
                ),
              ),
              // Slider thumb (3.png) – purely visual; gesture is handled by
              // the transparent layer above.
              Positioned(
                left: thumbCenter - ui(20),
                top: trackY - ui(16),
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/music/3.png',
                    width: ui(40),
                    height: ui(32),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Speed badge floats above the bar, centered horizontally on
              // the thumb. `Stack(clipBehavior: Clip.none)` lets it overflow
              // upward into the spacer above the slider card.
              Positioned(
                top: -ui(13),
                left: thumbCenter - ui(44),
                child: IgnorePointer(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(12),
                      vertical: ui(6),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(8)),
                      border: Border.all(
                        color: const Color(0xFFF3F2F3),
                        width: ui(1),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0x14000000),
                          blurRadius: ui(8),
                          offset: Offset(0, ui(2)),
                        ),
                      ],
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          const TextSpan(text: '速度：'),
                          TextSpan(text: '$bpm'),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: ui(14),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // ── Single gesture layer covering the whole track row. ──
              // Sits last in the Stack so it receives every pointer event
              // even when the finger is over the thumb / fill / track bg.
              Positioned(
                left: trackLeft,
                right: trackInset,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      onPointerEventX(details.localPosition.dx),
                  // Use the generic pan handlers (not horizontalDrag) so
                  // there is no startup distance threshold – the thumb
                  // begins moving on the very first frame of the gesture.
                  onPanStart: (details) =>
                      onPointerEventX(details.localPosition.dx),
                  onPanUpdate: (details) =>
                      onPointerEventX(details.localPosition.dx),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TempoIconButton extends StatelessWidget {
  const _TempoIconButton({
    required this.asset,
    required this.size,
    required this.onTap,
  });

  final String asset;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: Image.asset(asset, fit: BoxFit.contain)),
      ),
    );
  }
}

class _TunerPane extends StatelessWidget {
  const _TunerPane({
    required this.state,
    required this.onDecreaseFrequency,
    required this.onIncreaseFrequency,
    required this.onUse442Hz,
    required this.onRetryPermission,
  });

  final MusicCompanionState state;
  final VoidCallback onDecreaseFrequency;
  final VoidCallback onIncreaseFrequency;
  final VoidCallback onUse442Hz;
  final Future<void> Function() onRetryPermission;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(18), ui(18), ui(18), ui(18)),
      child: Column(
        children: [
          SizedBox(height: ui(58)),
          Center(
            child: Container(
              width: ui(240),
              height: ui(140),
              padding: EdgeInsets.all(ui(12)),
              decoration: BoxDecoration(
                color: const Color(0xCCE8E9F1),
                borderRadius: BorderRadius.circular(ui(20)),
                border: Border.all(color: Colors.white, width: ui(0.4)),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(12)),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF25064A), Color(0xFF090611)],
                  ),
                ),
                child: Center(
                  child: Text(
                    state.tunerNote,
                    style: TextStyle(
                      fontSize: ui(38),
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: ui(26)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tuner-specific ± stepper icons (6.png / 7.png) at 48×48.
              _TempoIconButton(
                asset: 'assets/images/music/6.png',
                size: ui(48),
                onTap: onDecreaseFrequency,
              ),
              SizedBox(width: ui(22)),
              Text(
                '${state.tunerReferenceFrequency}hz',
                style: TextStyle(
                  fontSize: ui(20),
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF151515),
                ),
              ),
              SizedBox(width: ui(22)),
              _TempoIconButton(
                asset: 'assets/images/music/7.png',
                size: ui(48),
                onTap: onIncreaseFrequency,
              ),
            ],
          ),
          SizedBox(height: ui(20)),
          Row(
            children: [
              SizedBox(width: ui(98)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '特定频段',
                    style: TextStyle(
                      fontSize: ui(15),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: ui(12)),
                  GestureDetector(
                    onTap: onUse442Hz,
                    child: Container(
                      width: ui(86),
                      height: ui(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: state.tunerReferenceFrequency == 442
                            ? const Color(0xFF141228)
                            : const Color(0xFFF4F5FA),
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Text(
                        '442hz',
                        style: TextStyle(
                          fontSize: ui(13),
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w600,
                          color: state.tunerReferenceFrequency == 442
                              ? Colors.white
                              : const Color(0xFF434A59),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
          SizedBox(height: ui(28)),
          Container(
            width: ui(740),
            height: ui(140),
            padding: EdgeInsets.fromLTRB(ui(24), ui(18), ui(24), ui(18)),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5FD),
              borderRadius: BorderRadius.circular(ui(16)),
            ),
            child: CustomPaint(
              painter: _TunerRulerPainter(cents: state.tunerCents),
            ),
          ),
          SizedBox(height: ui(14)),
          Text(
            state.tunerPermissionGranted
                ? (state.tunerListening
                      ? '实时检测中 ${state.tunerDetectedFrequency.toStringAsFixed(1)}Hz'
                      : '准备开始实时检测')
                : '麦克风未授权，点击这里重新开启',
            style: TextStyle(
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              color: const Color(0xFF7B8191),
            ),
          ),
          if (!state.tunerPermissionGranted) ...[
            SizedBox(height: ui(10)),
            TextButton(
              onPressed: onRetryPermission,
              child: Text(
                '重新授权麦克风',
                style: TextStyle(
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  color: const Color(0xFF7F46FF),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TunerRulerPainter extends CustomPainter {
  _TunerRulerPainter({required this.cents});

  final double cents;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 18.0;
    final rightPadding = 18.0;
    final contentWidth = size.width - leftPadding - rightPadding;
    final zeroX = leftPadding + contentWidth / 2;
    final tickSpacing = contentWidth / 100;
    final baselineY = size.height * 0.56;

    final basePaint = Paint()
      ..color = const Color(0xFF2F3443)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = const Color(0xFF8F58FF)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final dividerPaint = Paint()
      ..color = const Color(0xFFD7DCEB)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(leftPadding, size.height - 28),
      Offset(size.width - rightPadding, size.height - 28),
      dividerPaint,
    );

    final targetX = zeroX + cents.clamp(-50, 50) * tickSpacing;

    for (var i = -50; i <= 50; i++) {
      final x = zeroX + i * tickSpacing;
      final tickHeight = i % 10 == 0
          ? 30.0
          : i % 5 == 0
          ? 22.0
          : 16.0;
      final isActive = cents >= 0
          ? x >= zeroX && x <= targetX
          : x <= zeroX && x >= targetX;
      canvas.drawLine(
        Offset(x, baselineY - tickHeight),
        Offset(x, baselineY),
        isActive ? activePaint : basePaint,
      );
    }

    _drawMarker(canvas, zeroX, baselineY - 38, const Color(0xFF8F58FF));
    _drawMarker(canvas, targetX, baselineY - 38, const Color(0xFF8F58FF));

    for (var value = -50; value <= 50; value += 10) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$value',
          style: const TextStyle(
            color: Color(0xFF6F7381),
            fontSize: 12,
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = zeroX + value * tickSpacing - textPainter.width / 2;
      textPainter.paint(canvas, Offset(x, size.height - 20));
    }
  }

  void _drawMarker(Canvas canvas, double x, double y, Color color) {
    final path = Path()
      ..moveTo(x, y)
      ..lineTo(x - 4, y - 8)
      ..lineTo(x + 4, y - 8)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TunerRulerPainter oldDelegate) {
    return oldDelegate.cents != cents;
  }
}
