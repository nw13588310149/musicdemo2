import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_post_card.dart';

/// 列表模式：3 列瀑布流。沿 Y 方向按列累计高度，把每个卡片填到当前最矮的那一列。
class CircleListView extends StatelessWidget {
  const CircleListView({
    super.key,
    required this.state,
    required this.controller,
    required this.permissions,
  });

  final CircleState state;
  final CircleController controller;
  final CirclePermissions permissions;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final posts = state.visiblePosts;

    if (state.listLoading && posts.isEmpty) {
      return Container(
        color: const Color(0xFFEFF3FC),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(Color(0xFF8741FF)),
        ),
      );
    }

    if (posts.isEmpty) {
      return Container(
        color: const Color(0xFFEFF3FC),
        child: AppRefreshIndicator(
          onRefresh: () => controller.refreshPosts(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: ui(120)),
              const Center(
                child: Text(
                  '暂无动态',
                  style: TextStyle(
                    color: Color(0xFFB6B5BB),
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFEFF3FC),
      child: AppRefreshIndicator(
        onRefresh: () => controller.refreshPosts(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            final gap = ui(16);
            final available = constraints.maxWidth;
            final colWidth = (available - gap * (columns - 1)) / columns;

            final columnsContent = List<List<CirclePost>>.generate(
              columns,
              (_) => <CirclePost>[],
            );
            final columnsHeight = List<double>.filled(columns, 0);

            for (final post in posts) {
              final estTextH = ui(72);
              final estImgH = colWidth / post.imageAspectRatio;
              final estCardH =
                  ui(12) + ui(44) + ui(8) + estTextH + estImgH + ui(60);
              var target = 0;
              for (var i = 1; i < columns; i++) {
                if (columnsHeight[i] < columnsHeight[target]) target = i;
              }
              columnsContent[target].add(post);
              columnsHeight[target] += estCardH + gap;
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(
                      width: colWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final post in columnsContent[i]) ...[
                            CirclePostCard(
                              post: post,
                              onLike: () => _withToast(
                                context,
                                () => controller.toggleLike(post.id),
                              ),
                              onComment: () => _onCommentTap(post.id),
                              onFavorite: () =>
                                  controller.toggleFavorite(post.id),
                              onTap: () => _onCardTap(post.id),
                              onDeletePost: permissions.canDeletePost(post)
                                  ? () => _confirmDeletePost(context, post)
                                  : null,
                            ),
                            SizedBox(height: gap),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _withToast(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final ok = await action();
    if (!context.mounted) return;
    if (!ok) AppToast.show(context, '操作失败，请稍后再试');
  }

  Future<void> _confirmDeletePost(
    BuildContext context,
    CirclePost post,
  ) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除帖子',
      content: '确定删除这条动态吗？删除后不可恢复。',
    );
    if (!ok || !context.mounted) return;
    final success = await controller.deletePost(post.id);
    if (!context.mounted) return;
    if (!success) AppToast.show(context, '删除失败');
  }

  void _onCardTap(String postId) {
    final index = state.visiblePosts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    controller
      ..setImmersiveIndex(index)
      ..setMode(CircleMode.immersive);
  }

  void _onCommentTap(String postId) {
    final index = state.visiblePosts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    controller
      ..setImmersiveIndex(index)
      ..setMode(CircleMode.immersive);
    unawaited(controller.openCommentPanel(postId));
  }
}
