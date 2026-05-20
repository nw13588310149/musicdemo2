import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';
import 'circle_action_buttons.dart';
import 'circle_badges.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 列表模式下的单个帖子卡片：作者 / 文字 / 配图 / 操作按钮。
class CirclePostCard extends StatelessWidget {
  const CirclePostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    required this.onTap,
    this.onDeletePost,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  final VoidCallback? onDeletePost;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(16)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CardAuthor(post: post, onDeletePost: onDeletePost),
              SizedBox(height: ui(8)),
              Text(
                post.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  height: 19.6 / 14,
                ),
              ),
              SizedBox(height: ui(6)),
              Text(
                post.timeLabel,
                style: TextStyle(
                  color: const Color(0xFFB6B5BB),
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                ),
              ),
              SizedBox(height: ui(13)),
              _CardImage(post: post),
              SizedBox(height: ui(12)),
              CircleActionRow(
                post: post,
                onLike: onLike,
                onComment: onComment,
                onFavorite: onFavorite,
              ),
              SizedBox(height: ui(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAuthor extends StatelessWidget {
  const _CardAuthor({required this.post, this.onDeletePost});

  final CirclePost post;
  final VoidCallback? onDeletePost;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(url: post.author.avatarUrl, size: ui(44)),
        SizedBox(width: ui(11)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF0B081A),
                        fontSize: ui(18),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                  if (post.badges.isNotEmpty) ...[
                    SizedBox(width: ui(12)),
                    CircleBadgeRow(badges: post.badges),
                  ],
                ],
              ),
              SizedBox(height: ui(2)),
              Text(
                post.author.role,
                style: TextStyle(
                  color: const Color(0xFFB6B5BB),
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
        ),
        if (onDeletePost != null)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: ui(32),
              minHeight: ui(32),
            ),
            onPressed: onDeletePost,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: ui(20),
              color: const Color(0xFFB6B5BB),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: const Color(0xFFEAE5FF),
            alignment: Alignment.center,
            child: Icon(
              Icons.person,
              color: const Color(0xFF8741FF),
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(12)),
      child: AspectRatio(
        aspectRatio: post.imageAspectRatio,
        child: switch (post.mediaKind) {
          PostMediaKind.image => _ImageCover(url: post.imageUrl),
          PostMediaKind.video => _VideoCover(post: post),
          PostMediaKind.audio => _AudioCover(post: post),
        },
      ),
    );
  }
}

/// 图片帖封面：直接铺整张图，加载中 / 加载失败做兜底。
class _ImageCover extends StatelessWidget {
  const _ImageCover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFEFEFF4),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: ui(32),
          color: const Color(0xFFB6B5BB),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) =>
          Container(color: const Color(0xFFD9D9D9)),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFFEFEFF4),
          alignment: Alignment.center,
          child: SizedBox(
            width: ui(20),
            height: ui(20),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

/// 视频帖封面：海报（coverImg 或退化深色背景）+ 中央播放按钮 + 右下角时长 chip。
class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (post.imageUrl.isNotEmpty)
          Image.network(
            post.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF1B1530)),
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF252035), Color(0xFF0B081A)],
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x66000000)],
            ),
          ),
        ),
        Center(
          child: Container(
            width: ui(48),
            height: ui(48),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: ui(28),
            ),
          ),
        ),
        Positioned(
          left: ui(8),
          bottom: ui(8),
          child: _MediaTypeChip(
            icon: Icons.videocam_rounded,
            label: '视频',
          ),
        ),
      ],
    );
  }
}

/// 音频帖封面：渐变背景 + 大音符 + 中央播放按钮 + 左下"音频" chip。
class _AudioCover extends StatelessWidget {
  const _AudioCover({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (post.imageUrl.isNotEmpty)
          Image.network(
            post.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _AudioGradient(),
          )
        else
          const _AudioGradient(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x55000000)],
            ),
          ),
        ),
        Center(
          child: Container(
            width: ui(48),
            height: ui(48),
            decoration: const BoxDecoration(
              color: Color(0xFF8741FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: ui(28),
            ),
          ),
        ),
        Positioned(
          left: ui(8),
          bottom: ui(8),
          child: _MediaTypeChip(
            icon: Icons.music_note_rounded,
            label: '音频',
          ),
        ),
      ],
    );
  }
}

class _AudioGradient extends StatelessWidget {
  const _AudioGradient();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE2D0FF), Color(0xFF8741FF)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.graphic_eq_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: ui(56),
        ),
      ),
    );
  }
}

class _MediaTypeChip extends StatelessWidget {
  const _MediaTypeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: ui(12)),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: ui(11),
              fontFamily: 'PingFang SC',
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
