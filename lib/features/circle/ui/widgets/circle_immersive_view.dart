import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_action_buttons.dart';
import 'circle_badges.dart';
import 'circle_comment_panel.dart';
import 'circle_media_player.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 沉浸模式：全屏单帖，纵向 PageView 翻页，右侧操作按钮，下方文字浮层；
/// 评论面板从右侧滑入，覆盖在沉浸面板之上。
class CircleImmersiveView extends StatefulWidget {
  const CircleImmersiveView({
    super.key,
    required this.state,
    required this.controller,
    required this.permissions,
  });

  final CircleState state;
  final CircleController controller;
  final CirclePermissions permissions;

  @override
  State<CircleImmersiveView> createState() => _CircleImmersiveViewState();
}

class _CircleImmersiveViewState extends State<CircleImmersiveView> {
  late final PageController _pageController = PageController(
    initialPage: widget.state.immersiveIndex,
  );

  @override
  void didUpdateWidget(covariant CircleImmersiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.state.immersiveIndex;
    if (_pageController.hasClients && _pageController.page?.round() != target) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _activePostId() {
    final s = widget.state;
    if (s.commentTargetPostId.isNotEmpty) return s.commentTargetPostId;
    return s.currentImmersivePost?.id;
  }

  Future<void> _togglePostLike(BuildContext context, String postId) async {
    final ok = await widget.controller.toggleLike(postId);
    if (!context.mounted) return;
    if (!ok) AppToast.show(context, '操作失败，请稍后再试');
  }

  Future<void> _submitComment(
    BuildContext context,
    String postId,
    String text,
  ) async {
    final ok = await widget.controller.addComment(postId, text);
    if (!context.mounted) return;
    if (!ok) AppToast.show(context, '发送失败');
  }

  Future<void> _toggleCommentLike(
    BuildContext context,
    String postId,
    String commentId,
  ) async {
    final ok = await widget.controller.toggleCommentLike(postId, commentId);
    if (!context.mounted) return;
    if (!ok) AppToast.show(context, '操作失败，请稍后再试');
  }

  Future<void> _confirmDeletePost(BuildContext context, CirclePost post) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除帖子',
      content: '确定删除这条动态吗？删除后不可恢复。',
    );
    if (!ok || !context.mounted) return;
    final success = await widget.controller.deletePost(post.id);
    if (!context.mounted) return;
    if (!success) AppToast.show(context, '删除失败');
  }

  Future<void> _confirmDeleteComment(
    BuildContext context,
    String commentId,
  ) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除评论',
      content: '确定删除这条评论吗？',
    );
    if (!ok || !context.mounted) return;
    final postId = _activePostId();
    if (postId == null) return;
    final success = await widget.controller.deleteComment(
      postId: postId,
      commentId: commentId,
    );
    if (!context.mounted) return;
    if (!success) AppToast.show(context, '删除失败');
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = widget.state;
    final controller = widget.controller;
    final posts = state.visiblePosts;

    if (posts.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF0B081A),
        child: Center(
          child: Text(
            '暂无动态',
            style: TextStyle(
              color: Color(0xFFB6B5BB),
              fontSize: 14,
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      );
    }

    final commentsLoading = state.commentsLoadingPostId != null &&
        state.commentsLoadingPostId == _activePostId();

    return Container(
      color: const Color(0xFF0B081A),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: posts.length,
            onPageChanged: controller.setImmersiveIndex,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _ImmersiveSlide(
                post: post,
                canDeletePost: widget.permissions.canDeletePost(post),
                onDeletePost: widget.permissions.canDeletePost(post)
                    ? () => _confirmDeletePost(context, post)
                    : null,
                onLike: () => unawaited(_togglePostLike(context, post.id)),
                onComment: () => unawaited(controller.openCommentPanel(post.id)),
                onFavorite: () => controller.toggleFavorite(post.id),
              );
            },
          ),

          _AnimatedCommentPanel(
            visible: state.commentPanelOpen,
            child: CircleCommentPanel(
              post: state.commentTargetPost ?? state.currentImmersivePost,
              permissions: widget.permissions,
              commentsLoading: commentsLoading,
              onClose: controller.closeCommentPanel,
              onSubmit: (text) {
                final id = _activePostId();
                if (id != null) {
                  unawaited(_submitComment(context, id, text));
                }
              },
              onCommentLikeTap: (commentId) {
                final id = _activePostId();
                if (id != null) {
                  unawaited(_toggleCommentLike(context, id, commentId));
                }
              },
              onDeleteComment: (commentId) =>
                  unawaited(_confirmDeleteComment(context, commentId)),
            ),
          ),

          if (state.commentPanelOpen)
            Positioned.fill(
              right: ui(420),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.closeCommentPanel,
                child: const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单帖：背景图 + 底部渐变 + 文本 + 右侧操作。
class _ImmersiveSlide extends StatelessWidget {
  const _ImmersiveSlide({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    required this.canDeletePost,
    this.onDeletePost,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;
  final bool canDeletePost;
  final VoidCallback? onDeletePost;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          // 图片 / 视频 / 音频 三种形态由 CircleMediaPlayer 内部按
          // post.mediaKind 自动分支；视频和音频会按需创建 / 释放 Player。
          child: CircleMediaPlayer(post: post),
        ),

        if (canDeletePost && onDeletePost != null)
          Positioned(
            top: ui(16),
            right: ui(16),
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(ui(8)),
              child: InkWell(
                onTap: onDeletePost,
                borderRadius: BorderRadius.circular(ui(8)),
                child: Padding(
                  padding: EdgeInsets.all(ui(8)),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: ui(22),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: ui(220),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x000B081A),
                  Color(0xCC0B081A),
                  Color(0xFF0B081A),
                ],
                stops: [0, 0.6, 1],
              ),
            ),
          ),
        ),

        Positioned(
          left: ui(32),
          right: ui(160),
          bottom: ui(28),
          child: _ImmersiveTextBlock(post: post),
        ),

        Positioned(
          right: ui(28),
          bottom: ui(32),
          child: _ImmersiveActions(
            post: post,
            onLike: onLike,
            onComment: onComment,
            onFavorite: onFavorite,
          ),
        ),
      ],
    );
  }
}

class _ImmersiveTextBlock extends StatelessWidget {
  const _ImmersiveTextBlock({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ui(12),
          runSpacing: ui(6),
          children: [
            Text(
              '@${post.author.name}',
              style: TextStyle(
                color: Colors.white,
                fontSize: ui(20),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1.2,
              ),
            ),
            Text(
              post.author.role,
              style: TextStyle(
                color: const Color(0xFFCECED1),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                height: 1.2,
              ),
            ),
            for (final b in post.badges) CircleBadgeChip(badge: b),
          ],
        ),
        SizedBox(height: ui(12)),
        Text(
          post.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 24 / 14,
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
      ],
    );
  }
}

class _ImmersiveActions extends StatelessWidget {
  const _ImmersiveActions({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImmersiveAvatar(url: post.author.avatarUrl, size: ui(44)),
        SizedBox(height: ui(20)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconLiked,
          count: post.likeCount,
          onTap: onLike,
          dark: true,
          coloredIcon: post.liked ? const Color(0xFFFF323C) : Colors.white,
        ),
        SizedBox(height: ui(16)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconComment,
          count: post.commentCount,
          onTap: onComment,
          dark: true,
          coloredIcon: Colors.white,
        ),
        SizedBox(height: ui(16)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconFavorite,
          count: post.favoriteCount,
          onTap: onFavorite,
          dark: true,
          coloredIcon: post.favorited ? const Color(0xFFFFB400) : Colors.white,
        ),
      ],
    );
  }
}

class _ImmersiveAvatar extends StatelessWidget {
  const _ImmersiveAvatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF6D6B75), width: 1),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: const Color(0xFF252035),
            alignment: Alignment.center,
            child: Icon(
              Icons.person,
              color: Colors.white.withValues(alpha: 0.6),
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

/// 用 AnimatedPositioned 包装的右侧滑入面板。
class _AnimatedCommentPanel extends StatelessWidget {
  const _AnimatedCommentPanel({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: visible ? 0 : -ui(440),
      width: ui(420),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: child,
      ),
    );
  }
}
