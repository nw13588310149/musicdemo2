import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../shell_layout.dart';

enum ShellToolAction { metronome, recorder, piano }

class ShellFloatingTools extends StatelessWidget {
  const ShellFloatingTools({
    required this.expanded,
    required this.onToggle,
    required this.onAction,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<ShellToolAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    if (expanded) {
      return Container(
        width: ui(55),
        height: ui(285),
        padding: EdgeInsets.symmetric(horizontal: ui(2), vertical: ui(10)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(35)),
          boxShadow: [
            BoxShadow(color: const Color(0xFFEEEEEE), blurRadius: ui(4)),
          ],
        ),
        child: Column(
          children: [
            _toolItem(
              context: context,
              icon: AppAssets.shellMetronome,
              label: '\u8282\u62cd\u5668',
              onTap: () => onAction(ShellToolAction.metronome),
            ),
            _toolItem(
              context: context,
              icon: AppAssets.shellRecorder,
              label: '\u5f55\u97f3',
              onTap: () => onAction(ShellToolAction.recorder),
            ),
            _toolItem(
              context: context,
              icon: AppAssets.shellPiano,
              label: '\u94a2\u7434',
              onTap: () => onAction(ShellToolAction.piano),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onToggle,
              child: Image.asset(
                AppAssets.shellWechatClose,
                width: ui(45),
                height: ui(45),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onToggle,
      child: Image.asset(AppAssets.shellWechat, width: ui(50), height: ui(50)),
    );
  }

  Widget _toolItem({
    required BuildContext context,
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: ui(72),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: const Color(0xFFEEEEEE), width: ui(1)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, width: ui(25), height: ui(25)),
            SizedBox(height: ui(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF7F7F7F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
