import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';

/// 单个操作按钮（点赞 / 评论 / 收藏），支持 light / dark 两种调色。
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.iconAsset,
    required this.count,
    required this.onTap,
    this.dark = false,
    this.iconSize,
    this.coloredIcon,
  });

  final String iconAsset;
  final int count;
  final VoidCallback onTap;

  /// 沉浸模式（黑色背景）下使用白色文字与放大的图标。
  final bool dark;
  final double? iconSize;

  /// 当 dark=true 但仍需要保留资源原色（例如已点赞的红心）时填 null；
  /// 否则可通过 [Color] 让 png 转为指定颜色（如沉浸态默认白）。
  final Color? coloredIcon;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final size = iconSize ?? (dark ? ui(28) : ui(20));

    final iconWidget = coloredIcon == null
        ? AppAssetGraphic(iconAsset, width: size, height: size)
        : ColorFiltered(
            colorFilter: ColorFilter.mode(coloredIcon!, BlendMode.srcIn),
            child: AppAssetGraphic(iconAsset, width: size, height: size),
          );
    final textWidget = Text(
      formatCircleCount(count),
      style: TextStyle(
        color: dark ? Colors.white : const Color(0xFF0B081A),
        fontSize: ui(14),
        fontFamily: 'PingFang SC',
        height: 24 / 14,
      ),
    );

    // 沉浸态（dark=true）保持纵向：图标在上、数量在下；
    // 列表态（dark=false）按设计稿改为横向：图标 + 4px 间距 + 数量。
    final body = dark
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              SizedBox(height: ui(4)),
              textWidget,
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              SizedBox(width: ui(4)),
              textWidget,
            ],
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}

/// 列表模式下的一行三个操作按钮。
class CircleActionRow extends StatelessWidget {
  const CircleActionRow({
    super.key,
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
    return Row(
      children: [
        CircleActionButton(
          iconAsset: AppAssets.schoolIconLiked,
          count: post.likeCount,
          onTap: onLike,
          coloredIcon: post.liked
              ? const Color(0xFFFF323C)
              : const Color(0xFFB6B5BB),
        ),
        SizedBox(width: ui(16)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconComment,
          count: post.commentCount,
          onTap: onComment,
          coloredIcon: const Color(0xFFB6B5BB),
        ),
        SizedBox(width: ui(16)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconFavorite,
          count: post.favoriteCount,
          onTap: onFavorite,
          coloredIcon: post.favorited
              ? const Color(0xFFFFB400)
              : const Color(0xFFB6B5BB),
        ),
      ],
    );
  }
}
