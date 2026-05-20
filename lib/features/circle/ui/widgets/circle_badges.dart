import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';

/// 单个标签胶囊：置顶 / 热门。
class CircleBadgeChip extends StatelessWidget {
  const CircleBadgeChip({super.key, required this.badge});

  final CircleBadge badge;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pinned = badge == CircleBadge.pinned;
    final bg = pinned ? const Color(0xFFEAE5FF) : const Color(0xFFFFE5E7);
    final fg = pinned ? const Color(0xFF8741FF) : const Color(0xFFFF323C);
    final iconAsset = pinned
        ? AppAssets.schoolIconPin
        : AppAssets.schoolIconHot;
    final label = pinned ? '置顶' : '热门';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAssetGraphic(iconAsset, width: ui(12), height: ui(12)),
          SizedBox(width: ui(2)),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: ui(11),
              fontFamily: 'PingFang SC',
              height: 15.24 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行多个标签。
class CircleBadgeRow extends StatelessWidget {
  const CircleBadgeRow({super.key, required this.badges});

  final List<CircleBadge> badges;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: ui(6),
      runSpacing: ui(4),
      children: [for (final b in badges) CircleBadgeChip(badge: b)],
    );
  }
}
