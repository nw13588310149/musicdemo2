import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class ClassShareItem {
  const ClassShareItem({
    required this.id,
    required this.name,
    this.checked = false,
  });

  final String id;
  final String name;
  final bool checked;
}

Future<T?> showClassShareDrawer<T>({
  required BuildContext context,
  required Widget child,
  DashboardScaleData? scale,
}) {
  final resolvedScale =
      scale ?? DashboardScaleScope.maybeOf(context) ?? _fallbackScale(context);
  return showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.20),
    barrierDismissible: true,
    barrierLabel: '关闭分享',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return DashboardScaleScope(data: resolvedScale, child: child);
    },
    transitionBuilder: (context, animation, secondary, child) {
      final offset = Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return SlideTransition(position: offset, child: child);
    },
  );
}

DashboardScaleData _fallbackScale(BuildContext context) {
  final size = MediaQuery.maybeSizeOf(context) ?? const Size(1024, 768);
  return DashboardScaleScope.fromSize(size);
}

class ClassShareDrawer extends StatelessWidget {
  const ClassShareDrawer({
    super.key,
    this.title = '分享课件',
    required this.targetCard,
    required this.classes,
    required this.loading,
    required this.sending,
    required this.onToggleClass,
    required this.onSend,
  });

  final String title;
  final Widget targetCard;
  final List<ClassShareItem> classes;
  final bool loading;
  final bool sending;
  final ValueChanged<String> onToggleClass;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
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
                _ShareDrawerTitle(title: title),
                SizedBox(height: ui(20)),
                const Divider(height: 1, color: Color(0xFFF3F2F3)),
                SizedBox(height: ui(24)),
                targetCard,
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
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : classes.isEmpty
                      ? const _ShareDrawerEmpty()
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: classes.length,
                          separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                          itemBuilder: (context, index) {
                            final item = classes[index];
                            return _ClassShareRow(
                              item: item,
                              onTap: () => onToggleClass(item.id),
                            );
                          },
                        ),
                ),
                SizedBox(height: ui(12)),
                _ShareSendButton(loading: sending, onTap: onSend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShareTargetCard extends StatelessWidget {
  const ShareTargetCard({
    super.key,
    required this.label,
    required this.title,
    this.coverUrl = '',
    this.placeholderIcon = Icons.ondemand_video_rounded,
    this.resolveUrl,
  });

  final String label;
  final String title;
  final String coverUrl;
  final IconData placeholderIcon;
  final String Function(String)? resolveUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final resolvedCover = resolveUrl == null ? coverUrl : resolveUrl!(coverUrl);

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
                  label,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(10)),
                Text(
                  title,
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
            child: resolvedCover.isEmpty
                ? Icon(placeholderIcon, color: const Color(0xFFA773FF))
                : Image.network(
                    resolvedCover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(placeholderIcon, color: const Color(0xFFA773FF)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShareDrawerTitle extends StatelessWidget {
  const _ShareDrawerTitle({required this.title});

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

class _ClassShareRow extends StatelessWidget {
  const _ClassShareRow({required this.item, required this.onTap});

  final ClassShareItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
                    color: item.checked
                        ? const Color(0xFF8741FF)
                        : const Color(0xFFCECED1),
                    width: 1,
                  ),
                ),
                child: item.checked
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
                  item.name,
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

class _ShareSendButton extends StatelessWidget {
  const _ShareSendButton({required this.loading, required this.onTap});

  final bool loading;
  final Future<void> Function() onTap;

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
                ),
              ),
      ),
    );
  }
}
