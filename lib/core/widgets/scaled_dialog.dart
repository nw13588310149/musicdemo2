import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import '../constants/app_assets.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// `showDialog` 的封装：在打开对话框前先从 [context] 中读取
/// [DashboardScaleScope]，再把同一份 [DashboardScaleData] 重新注入到弹窗子树。
///
/// 这样从 Dashboard 内层页面里直接 `showDialog` 时，弹窗 builder 收到的
/// `dialogContext` 即便走的是 root Overlay，也能让 `DashboardScaleScope.of(...)`
/// 正常工作，避免出现 `scope != null` 的断言异常。
Future<T?> showScaledDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
}) {
  final scale = DashboardScaleScope.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black54,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    builder: (dialogContext) {
      return DashboardScaleScope(
        data: scale,
        child: Builder(builder: builder),
      );
    },
  );
}

/// 「渐变顶部装饰 + 居中标题 + 自定义内容 + 底部按钮」对话框容器。
///
/// 提取自 courseware「上传课件」弹窗的视觉系统，复用给所有需要：
///   · 圆角 24 + 顶部 #D2C6FF→white 渐变（stops 0 / 0.21 / 1）
///   · 顶部一张装饰位图（默认 `AppAssets.coursewareUploadHeader`）
///   · 居中标题（默认 18/600，可通过 [titleFontSize] 覆盖；查寝补卡是 24px）
///   · 自定义 [child] 表单内容
///   · 可选底部 [actionBar]（推荐传入 [AppDialogActionBar]）
/// 的弹窗。`width` 默认 420（设计基准 428，少 8 用作左右 inset 余量）。
///
/// 用法示例：
/// ```dart
/// showScaledDialog<void>(
///   context: context,
///   builder: (ctx) => GradientHeaderDialog(
///     title: '申请查寝补卡',
///     titleFontSize: 24,
///     child: _MyForm(),
///     actionBar: AppDialogActionBar(
///       onCancel: () => Navigator.pop(ctx),
///       onConfirm: () => Navigator.pop(ctx, true),
///     ),
///   ),
/// );
/// ```
class GradientHeaderDialog extends StatelessWidget {
  const GradientHeaderDialog({
    super.key,
    required this.title,
    required this.child,
    this.actionBar,
    this.width = 420,
    this.titleFontSize = 18,
    this.titleFontWeight = FontWeight.w600,
    this.titlePaddingTop = 22,
    this.contentPadding,
    this.headerAsset = AppAssets.coursewareUploadHeader,
    this.headerHeight,
  });

  /// 标题文字（居中显示）。
  final String title;

  /// 标题与 actionBar 之间的主体内容。
  final Widget child;

  /// 底部按钮区。传入 null 时没有按钮（少数纯展示弹窗用）。
  final Widget? actionBar;

  /// 弹窗整体宽度（design 默认 420）。
  final double width;

  /// 标题字号（默认 18；查寝补卡用 24）。
  final double titleFontSize;

  final FontWeight titleFontWeight;

  /// 标题距弹窗顶部的距离（默认 22，可与图片高度配合）。
  final double titlePaddingTop;

  /// content 内边距（默认左右 20、底部 20、顶部由 [titlePaddingTop] 决定）。
  final EdgeInsets? contentPadding;

  /// 顶部装饰位图资源；传 `null` 则不画装饰图。
  final String? headerAsset;

  /// 装饰图高度（默认 fitWidth 自适应）。
  final double? headerHeight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: ui(32), vertical: ui(24)),
      child: Container(
        width: ui(width),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFD2C6FF), Colors.white, Colors.white],
            stops: <double>[0, 0.21, 1],
          ),
          borderRadius: BorderRadius.circular(ui(24)),
        ),
        child: Stack(
          children: [
            if (headerAsset != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: headerHeight != null
                    ? Image.asset(
                        headerAsset!,
                        height: ui(headerHeight!),
                        fit: BoxFit.cover,
                      )
                    : Image.asset(headerAsset!, fit: BoxFit.fitWidth),
              ),
            Padding(
              padding:
                  contentPadding ??
                  EdgeInsets.fromLTRB(
                    ui(20),
                    ui(titlePaddingTop),
                    ui(20),
                    ui(20),
                  ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: ui(titleFontSize),
                        color: const Color(0xFF0B081A),
                        fontFamily: 'PingFang SC',
                        fontWeight: titleFontWeight,
                        height: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: ui(20)),
                  Flexible(child: SingleChildScrollView(child: child)),
                  if (actionBar != null) ...[
                    SizedBox(height: ui(20)),
                    actionBar!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 通用底部按钮组（取消 / 确认），样式与上传课件弹窗一致：
/// - 取消：白底 + 浅边框 + 阴影
/// - 确认：紫色渐变 + 阴影
class AppDialogActionBar extends StatelessWidget {
  const AppDialogActionBar({
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = '取消',
    this.confirmLabel = '确认',
    this.confirmEnabled = true,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _AppDialogButton(
            label: cancelLabel,
            onTap: onCancel,
            isPrimary: false,
          ),
        ),
        SizedBox(width: ui(16)),
        Expanded(
          child: _AppDialogButton(
            label: confirmLabel,
            onTap: confirmEnabled ? onConfirm : null,
            isPrimary: true,
          ),
        ),
      ],
    );
  }
}

class _AppDialogButton extends StatelessWidget {
  const _AppDialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(45),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? const Color(0x59AD80FF)
                  : const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 12 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹出一个文本输入对话框，返回用户输入（trim 后非空）；点击取消返回 null。
///
/// 默认单行；[multiline] 为 true 时使用多行输入（类似 HTML `textarea`），
/// 适合个人简介等场景。
///
/// 样式与上传课件弹窗保持一致：
/// - 圆角 24，白底（无渐变 / 无顶部装饰图）
/// - 输入框：白底，1px `#F3F2F3` 边框，圆角 12
/// - 底部按钮使用 [AppDialogActionBar]
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  String hintText = '',
  String initialValue = '',
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  int? maxLength,
  /// 多行输入（换行、多行滚动），类似 textarea。
  bool multiline = false,
  /// 多行模式下输入框高度（逻辑像素，经 [DashboardScaleScope] 缩放）。
  double multilineHeight = 152,
}) async {
  final controller = TextEditingController(text: initialValue);
  final focusNode = FocusNode();
  final result = await showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusNode.canRequestFocus && !focusNode.hasFocus) {
          focusNode.requestFocus();
        }
      });
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              SizedBox(height: ui(20)),
              SizedBox(
                height: multiline ? ui(multilineHeight) : ui(45),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  maxLength: maxLength,
                  expands: multiline,
                  maxLines: multiline ? null : 1,
                  keyboardType: multiline
                      ? TextInputType.multiline
                      : TextInputType.text,
                  textInputAction: multiline
                      ? TextInputAction.newline
                      : TextInputAction.done,
                  onSubmitted: multiline
                      ? null
                      : (_) => Navigator.of(
                          dialogContext,
                          rootNavigator: true,
                        ).pop(controller.text.trim()),
                  textAlignVertical: multiline
                      ? TextAlignVertical.top
                      : TextAlignVertical.center,
                  cursorColor: const Color(0xFF8741FF),
                  cursorWidth: 1.5,
                  cursorHeight: ui(16),
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    counterText: '',
                    hintStyle: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFFB6B5BB),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 12 / 14,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ui(13),
                      vertical: ui(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ui(12)),
                      borderSide: BorderSide(
                        color: const Color(0xFFF3F2F3),
                        width: ui(1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ui(12)),
                      borderSide: BorderSide(
                        color: const Color(0xFFD9C7FF),
                        width: ui(1),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: ui(24)),
              AppDialogActionBar(
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
                onConfirm: () =>
                    Navigator.of(
                      dialogContext,
                      rootNavigator: true,
                    ).pop(controller.text.trim()),
              ),
            ],
          ),
        ),
      );
    },
  );
  focusNode.dispose();
  controller.dispose();
  return result;
}

/// 单选弹窗（性别 / 省份 / 身份等）：列表中点击即关闭并返回所选项；
/// 取消按钮返回 null。样式与上传课件 / 修改资料弹窗保持一致。
Future<String?> showOptionsDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selected,
  String cancelLabel = '取消',
}) async {
  return showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              SizedBox(height: ui(16)),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: ui(360)),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF3F2F3),
                  ),
                  itemBuilder: (context, index) {
                    final value = options[index];
                    final isActive = value == selected;
                    return InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(value),
                      child: Container(
                        height: ui(46),
                        padding: EdgeInsets.symmetric(horizontal: ui(8)),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: isActive
                                      ? const Color(0xFF8741FF)
                                      : const Color(0xFF0B081A),
                                  fontFamily: 'PingFang SC',
                                  fontWeight: isActive
                                      ? AppFont.w600
                                      : AppFont.w400,
                                ),
                              ),
                            ),
                            if (isActive)
                              Icon(
                                Icons.check_rounded,
                                size: ui(18),
                                color: const Color(0xFF8741FF),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ui(16)),
              Center(
                child: SizedBox(
                  width: ui(180),
                  child: _AppDialogButton(
                    label: cancelLabel,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    isPrimary: false,
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

/// 单按钮提示弹窗（"暂未开放" / "保存成功" 等纯告知场景）。
/// 样式与 [showConfirmDialog] / [showTextInputDialog] 完全一致：
/// - 圆角 24，白底，宽 420
/// - 18/600 标题 + 14/400 说明文（可选）
/// - 居中单个紫色渐变确认按钮（默认 "知道了"）
Future<void> showInfoDialog({
  required BuildContext context,
  required String title,
  String? content,
  String confirmLabel = '知道了',
  bool barrierDismissible = true,
}) async {
  await showScaledDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              if (content != null && content.isNotEmpty) ...[
                SizedBox(height: ui(12)),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.6,
                    color: const Color(0xFF788698),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
              ],
              SizedBox(height: ui(24)),
              Center(
                child: SizedBox(
                  width: ui(180),
                  child: _AppDialogButton(
                    label: confirmLabel,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    isPrimary: true,
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

/// 弹出一个二次确认对话框（带说明文本），返回 `true` 表示用户点击确认。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
}) async {
  final result = await showScaledDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              SizedBox(height: ui(12)),
              Text(
                content,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.6,
                  color: const Color(0xFF788698),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
              SizedBox(height: ui(24)),
              AppDialogActionBar(
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () => Navigator.of(dialogContext).pop(false),
                onConfirm: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
