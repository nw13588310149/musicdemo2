import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/providers/app_providers.dart';
import '../../courseware/ui/courseware_inline_preview.dart';
import '../../courseware/ui/courseware_url_opener.dart';
import '../../shell/ui/shell_layout.dart';

/// 与课件内嵌预览一致的后缀分流（仅用于原生端在 [CoursewareInlinePreview] 不覆盖
/// 音视频时走 `media_kit`）。
enum StudentSubmissionPreviewKind {
  image,
  pdf,
  audio,
  video,
  unknown,
}

StudentSubmissionPreviewKind inferStudentSubmissionPreviewKind(
  String url, {
  String typeTag = '',
  String mediumLabel = '',
  String attachmentName = '',
}) {
  final fromUrl = _kindFromPath(url);
  if (fromUrl != StudentSubmissionPreviewKind.unknown) return fromUrl;
  final fromName = _kindFromPath(attachmentName);
  if (fromName != StudentSubmissionPreviewKind.unknown) return fromName;

  final hints = '${typeTag.toLowerCase()} ${mediumLabel.toLowerCase()} '
      '${attachmentName.toLowerCase()}';
  if (hints.contains('视频') || hints.contains('mp4') || hints.contains('mov')) {
    return StudentSubmissionPreviewKind.video;
  }
  if (hints.contains('音频') ||
      hints.contains('录音') ||
      hints.contains('mp3') ||
      hints.contains('m4a') ||
      hints.contains('wav')) {
    return StudentSubmissionPreviewKind.audio;
  }
  if (hints.contains('图片') || hints.contains('照片') || hints.contains('jpg')) {
    return StudentSubmissionPreviewKind.image;
  }
  if (hints.contains('pdf')) {
    return StudentSubmissionPreviewKind.pdf;
  }
  return StudentSubmissionPreviewKind.unknown;
}

StudentSubmissionPreviewKind _kindFromPath(String raw) {
  if (raw.trim().isEmpty) return StudentSubmissionPreviewKind.unknown;
  final lower = raw.toLowerCase();
  final pathOnly = lower.split('?').first.split('#').first;
  bool hasExt(List<String> exts) {
    for (final e in exts) {
      if (pathOnly.endsWith('.$e')) return true;
    }
    return false;
  }

  if (hasExt(const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'])) {
    return StudentSubmissionPreviewKind.image;
  }
  if (hasExt(const ['pdf'])) return StudentSubmissionPreviewKind.pdf;
  if (hasExt(const ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'])) {
    return StudentSubmissionPreviewKind.audio;
  }
  if (hasExt(const ['mp4', 'webm', 'mov', 'm4v', 'ogv'])) {
    return StudentSubmissionPreviewKind.video;
  }
  return StudentSubmissionPreviewKind.unknown;
}

/// 学生作业「我的提交」文件预览：Web 走 [CoursewareInlinePreview]（浏览器内嵌
/// 图片 / 音视频 / PDF 等）；原生端图片与 PDF 内嵌，音视频用 `media_kit`；
/// 无法识别类型时提示并在浏览器打开。
Future<void> showStudentHomeworkSubmissionPreview(
  BuildContext context, {
  required WidgetRef ref,
  required String fileUrl,
  String title = '',
  String typeTag = '',
  String mediumLabel = '',
  String attachmentName = '',
}) async {
  final u = fileUrl.trim();
  if (u.isEmpty) return;

  final token = ref.read(appStorageProvider).token;
  if (!context.mounted) return;

  // `showDialog` 的 builder 拿到的 context 在根 Navigator 的 overlay 上，
  // 通常不是 Shell 里 [DashboardScaleScope] 的子节点，不能在里面 `of(ctx)`。
  final scaleData = DashboardScaleScope.maybeOf(context) ??
      DashboardScaleData(
        viewportScale: 1,
        availableSize: MediaQuery.sizeOf(context),
      );
  final ui = scaleData.ui;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return _SubmissionPreviewShell(
        ui: ui,
        title: title,
        token: token,
        fileUrl: u,
        typeTag: typeTag,
        mediumLabel: mediumLabel,
        attachmentName: attachmentName,
        useWebInline: kIsWeb,
      );
    },
  );
}

class _SubmissionPreviewShell extends StatelessWidget {
  const _SubmissionPreviewShell({
    required this.ui,
    required this.title,
    required this.token,
    required this.fileUrl,
    required this.typeTag,
    required this.mediumLabel,
    required this.attachmentName,
    required this.useWebInline,
  });

  final double Function(double) ui;
  final String title;
  final String token;
  final String fileUrl;
  final String typeTag;
  final String mediumLabel;
  final String attachmentName;
  final bool useWebInline;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.92;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Dialog(
      insetPadding: EdgeInsets.all(ui(16)),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: SizedBox(
          width: ui(720),
          height: ui(520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PreviewTitleBar(
                ui: ui,
                title: title.trim().isEmpty ? '预览提交文件' : title.trim(),
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: useWebInline
                    ? CoursewareInlinePreview(url: fileUrl, authToken: token)
                    : _NativeSubmissionBody(
                        ui: ui,
                        fileUrl: fileUrl,
                        authToken: token,
                        typeTag: typeTag,
                        mediumLabel: mediumLabel,
                        attachmentName: attachmentName,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTitleBar extends StatelessWidget {
  const _PreviewTitleBar({
    required this.ui,
    required this.title,
    required this.onClose,
  });

  final double Function(double) ui;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(15),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'PingFang SC',
                  color: const Color(0xFF0B081A),
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, size: ui(22)),
              color: const Color(0xFF6D6B75),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeSubmissionBody extends StatelessWidget {
  const _NativeSubmissionBody({
    required this.ui,
    required this.fileUrl,
    required this.authToken,
    required this.typeTag,
    required this.mediumLabel,
    required this.attachmentName,
  });

  final double Function(double) ui;
  final String fileUrl;
  final String authToken;
  final String typeTag;
  final String mediumLabel;
  final String attachmentName;

  @override
  Widget build(BuildContext context) {
    final kind = inferStudentSubmissionPreviewKind(
      fileUrl,
      typeTag: typeTag,
      mediumLabel: mediumLabel,
      attachmentName: attachmentName,
    );
    return switch (kind) {
      StudentSubmissionPreviewKind.image => _NativeImagePreview(url: fileUrl),
      StudentSubmissionPreviewKind.pdf =>
        _NativePdfPreview(url: fileUrl, authToken: authToken),
      StudentSubmissionPreviewKind.audio =>
        _HomeworkMediaKitPlayer(url: fileUrl, isVideo: false, ui: ui),
      StudentSubmissionPreviewKind.video =>
        _HomeworkMediaKitPlayer(url: fileUrl, isVideo: true, ui: ui),
      StudentSubmissionPreviewKind.unknown =>
        _NativeUnsupportedFallback(url: fileUrl, ui: ui),
    };
  }
}

class _NativeImagePreview extends StatelessWidget {
  const _NativeImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFAFAFD),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        placeholder: (context, _) => const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF8741FF),
            ),
          ),
        ),
        errorWidget: (context, _, _) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Color(0xFFC9C6D8),
          ),
        ),
      ),
    );
  }
}

class _NativePdfPreview extends StatelessWidget {
  const _NativePdfPreview({required this.url, required this.authToken});

  final String url;
  final String authToken;

  @override
  Widget build(BuildContext context) {
    final headers = <String, String>{
      if (authToken.isNotEmpty) 'app-token': authToken,
    };
    return PdfViewer.uri(
      Uri.parse(url),
      headers: headers.isEmpty ? null : headers,
      withCredentials: true,
      params: PdfViewerParams(
        backgroundColor: const Color(0xFFFAFAFB),
        margin: 12,
        pageDropShadow: null,
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
          final progress = (totalBytes != null && totalBytes > 0)
              ? bytesDownloaded / totalBytes
              : null;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress,
                    color: const Color(0xFF8741FF),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  progress == null
                      ? 'PDF 加载中…'
                      : 'PDF 加载中…${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF6D6B75),
                    fontSize: 12,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          );
        },
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'PDF 加载失败：$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6D6B75),
                  fontSize: 13,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NativeUnsupportedFallback extends StatelessWidget {
  const _NativeUnsupportedFallback({required this.url, required this.ui});

  final String url;
  final double Function(double) ui;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFAFAFD),
      child: Padding(
        padding: EdgeInsets.all(ui(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '当前类型无法在应用内预览，可在浏览器中打开查看。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF8F86A8),
                fontSize: ui(13),
                fontFamily: 'PingFang SC',
                height: 1.4,
              ),
            ),
            SizedBox(height: ui(16)),
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(context);
                openCoursewareUrl(url);
              },
              child: Text(
                '在浏览器中打开',
                style: TextStyle(fontSize: ui(14), fontFamily: 'PingFang SC'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeworkMediaKitPlayer extends StatefulWidget {
  const _HomeworkMediaKitPlayer({
    required this.url,
    required this.isVideo,
    required this.ui,
  });

  final String url;
  final bool isVideo;
  final double Function(double) ui;

  @override
  State<_HomeworkMediaKitPlayer> createState() => _HomeworkMediaKitPlayerState();
}

class _HomeworkMediaKitPlayerState extends State<_HomeworkMediaKitPlayer> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playingSub;

  bool _disposed = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    final player = Player();
    _player = player;
    if (widget.isVideo) {
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
    unawaited(player.open(Media(widget.url), play: false));
  }

  void _teardown() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _posSub = _durSub = _playingSub = null;
    final player = _player;
    if (player != null) {
      try {
        unawaited(player.pause());
      } catch (_) {}
      unawaited(player.dispose());
    }
    _player = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _teardown();
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

  String _fmt(Duration d) {
    if (d == Duration.zero) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    if (widget.isVideo) {
      final vc = _videoController;
      if (vc == null) {
        return const ColoredBox(
          color: Color(0xFF0B081A),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ColoredBox(
        color: const Color(0xFF0B081A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: vc,
              fit: BoxFit.contain,
              controls: NoVideoControls,
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_togglePlay()),
                child: AnimatedOpacity(
                  opacity: _isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Center(
                    child: _HomeworkPlayDisc(ui: ui, playing: _isPlaying),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _HomeworkProgressStrip(
                ui: ui,
                position: _position,
                duration: _duration,
                fmt: _fmt,
                onSeek: (t) => unawaited(_player?.seek(t)),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1E66), Color(0xFF0B081A)],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_togglePlay()),
              child: Center(
                child: _HomeworkPlayDisc(ui: ui, playing: _isPlaying),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(20)),
            child: _HomeworkProgressStrip(
              ui: ui,
              position: _position,
              duration: _duration,
              fmt: _fmt,
              lightStyle: true,
              onSeek: (t) => unawaited(_player?.seek(t)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeworkPlayDisc extends StatelessWidget {
  const _HomeworkPlayDisc({required this.ui, required this.playing});

  final double Function(double) ui;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ui(72),
      height: ui(72),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: ui(40),
      ),
    );
  }
}

class _HomeworkProgressStrip extends StatelessWidget {
  const _HomeworkProgressStrip({
    required this.ui,
    required this.position,
    required this.duration,
    required this.fmt,
    required this.onSeek,
    this.lightStyle = false,
  });

  final double Function(double) ui;
  final Duration position;
  final Duration duration;
  final String Function(Duration) fmt;
  final ValueChanged<Duration> onSeek;
  final bool lightStyle;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final ratio = (position.inMilliseconds / total).clamp(0.0, 1.0);
    final track = lightStyle
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.22);
    final fill = lightStyle ? Colors.white : Colors.white.withValues(alpha: 0.9);
    final textPri = lightStyle ? Colors.white : Colors.white;
    final textSec = lightStyle
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.65);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _emitSeek(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) =>
                  _emitSeek(d.localPosition.dx, width),
              child: SizedBox(
                height: ui(22),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: ui(3),
                      decoration: BoxDecoration(
                        color: track,
                        borderRadius: BorderRadius.circular(ui(2)),
                      ),
                    ),
                    Container(
                      height: ui(3),
                      width: width * ratio,
                      decoration: BoxDecoration(
                        color: fill,
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
              fmt(position),
              style: TextStyle(
                color: textPri,
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
              ),
            ),
            Text(
              fmt(duration),
              style: TextStyle(
                color: textSec,
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _emitSeek(double dx, double width) {
    if (width <= 0 || duration.inMilliseconds <= 0) return;
    final r = (dx / width).clamp(0.0, 1.0);
    onSeek(
      Duration(
        milliseconds: (duration.inMilliseconds * r).round(),
      ),
    );
  }
}
