import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../state/school_binding_controller.dart';
import '../../state/school_binding_state.dart';

/// 「绑定学校」强制弹窗的整页遮罩。
///
/// 设计要求：登录后若 `/v2/user/schoolList` 返回 `data == []`，则在所有
/// 受保护页面之上盖一层 80% 透明白色 + 21.75px 高斯模糊，居中弹出一个
/// 420×260 的卡片，且**不可关闭**——用户必须完成绑定流程。
///
/// 三种视图（[SchoolBindingStage]）：
/// - [SchoolBindingStage.initial]：尚未提交申请，展示输入框 + 发起绑定按钮；
/// - [SchoolBindingStage.pending]：审核中，状态行 + 重新绑定按钮；
/// - [SchoolBindingStage.rejected]：未通过，显示驳回原因 + 重新绑定按钮。
///
/// 不弹路由：通过 [AbsorbPointer] + [GestureDetector] 在遮罩层吃掉所有
/// 命中事件，并 stretch 覆盖整个 ShellScaffold 区域（侧栏 + 顶栏 + 内
/// 容），因此系统返回键 / 路由 pop 都无法关闭它，只有数据层的 hasSchool
/// 翻成 true 后由 ShellScaffold 自行卸载。
class SchoolBindingOverlay extends ConsumerStatefulWidget {
  const SchoolBindingOverlay({super.key});

  @override
  ConsumerState<SchoolBindingOverlay> createState() =>
      _SchoolBindingOverlayState();
}

class _SchoolBindingOverlayState extends ConsumerState<SchoolBindingOverlay> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(schoolBindingControllerProvider).schoolIdInput;
    _textController = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 观察 stage 变化：当控制器主动清空 schoolIdInput（重新绑定 / 提交
    // 成功）时，把本地 TextEditingController 也同步重置；同时让按钮的
    // submitting 状态生效。
    ref.listen<SchoolBindingState>(schoolBindingControllerProvider, (
      previous,
      next,
    ) {
      if (next.schoolIdInput != _textController.text) {
        _textController.value = TextEditingValue(
          text: next.schoolIdInput,
          selection: TextSelection.collapsed(offset: next.schoolIdInput.length),
        );
      }
    });

    final state = ref.watch(schoolBindingControllerProvider);
    final stage = state.stage;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // ── 全屏「磨砂玻璃」遮罩 ─────────────────────────────────
          // 视觉对齐设计稿：banner / 侧栏 / 右侧课表 / 底部资讯卡片
          // 都要能透过遮罩"被认出来"，只在上面盖一层薄白做整体压暗。
          //
          // 为什么不是 Figma 标的 `rgba(255,255,255,0.80) + blur(21.75)`：
          // 1. Figma 预览自带的 backdrop-filter 渲染算法跟 Skia/浏览器
          //    完全不同，标的数字仅供"颜色配方"参考，几乎从不能 1:1
          //    搬到运行时。
          // 2. Flutter Web 上 `ImageFilter.blur(sigma)` 的视觉强度比同
          //    数值的 CSS `blur(Npx)` 重 2~3 倍——直接套 21.75 会把整页
          //    糊成一片乳白，连 banner 大色块都认不出（实测照片为证）。
          //
          // 真实配方：sigma 8 + 白 alpha 0.20，跟设计稿的「能看清下层
          // 轮廓，整体微微泛白」基本一致。后续如需更糊调高 sigma；如需
          // 更白调高 alpha；两个旋钮互不影响。
          //
          // 结构上：GestureDetector 在最外层只负责吃手势；BackdropFilter
          // 对自己被绘制位置「之下的已合成图层」做高斯模糊；ColoredBox
          // 作为 BackdropFilter 的 child，画在模糊层之上。注意一定不能把
          // GestureDetector 放到 BackdropFilter 内部，否则 Web 渲染器会
          // 因为 saveLayer 时机错乱导致虚化失效——只剩一块纯白。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 空 onTap 仅用于在遮罩层抢占焦点，避免点透到下层菜单。
              onTap: () {},
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: _BindingDialogCard(
                state: state,
                stage: stage,
                textController: _textController,
                onChanged: (v) => ref
                    .read(schoolBindingControllerProvider.notifier)
                    .setSchoolIdInput(v),
                onSubmit: () async {
                  final notifier = ref.read(
                    schoolBindingControllerProvider.notifier,
                  );
                  final ok = await notifier.submitBinding();
                  if (!context.mounted) return;
                  if (ok) {
                    AppToast.showSuccess(context, '已提交，等待审核');
                  } else {
                    final msg = ref
                        .read(schoolBindingControllerProvider)
                        .errorMessage;
                    if (msg.isNotEmpty) {
                      AppToast.showError(context, msg);
                    }
                  }
                },
                onRebind: () => ref
                    .read(schoolBindingControllerProvider.notifier)
                    .enterRebindForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 420 × 260 卡片本体。三种 stage 共用同一个卡片容器（渐变背景 + 顶部
/// 装饰图 + 圆角），只是中部内容与按钮文案 / 行为不同，因此用一个组件
/// 统一管理布局，分支只在内容区。
class _BindingDialogCard extends StatelessWidget {
  const _BindingDialogCard({
    required this.state,
    required this.stage,
    required this.textController,
    required this.onChanged,
    required this.onSubmit,
    required this.onRebind,
  });

  final SchoolBindingState state;
  final SchoolBindingStage stage;
  final TextEditingController textController;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSubmit;
  final VoidCallback onRebind;

  static const double _w = 420;
  static const double _h = 260;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _w,
      height: _h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 卡片背景（渐变 + 圆角 + 阴影）。Container 自身做 antiAlias
          // 是为了让顶部装饰图被 24 圆角裁掉超出部分，与设计稿对齐。
          Container(
            width: _w,
            height: _h,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD8CCFF), Colors.white, Colors.white],
                stops: [0, 0.5, 1],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D0E041D),
                  offset: Offset(20, 40),
                  blurRadius: 60,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 顶部装饰图：与其他弹窗（GradientHeaderDialog）保持一致的
                // CSS —— left:0 / right:0 / top:0 + BoxFit.fitWidth，让插画
                // 横跨卡片整个顶部并被圆角自然裁切。
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _HeaderDecoration(),
                ),
                // 卡片左上角的徽章「同学你还没 / 同学未通过 / 同学您当前」。
                // initial / pending 用紫色 ts.png 气泡，rejected 用红色
                // tserror.png 气泡；白色文字居中，气泡左下角的小尾巴随图。
                Positioned(
                  left: 30,
                  top: 34,
                  child: _TopHintBadge(stage: stage, text: _topHint(stage)),
                ),
                // 大标题：initial / pending 显示，rejected 不显示
                if (stage != SchoolBindingStage.rejected)
                  Positioned(
                    left: stage == SchoolBindingStage.initial ? 30 : 22,
                    top: stage == SchoolBindingStage.initial ? 62 : 63,
                    child: _DialogTitle(stage: stage),
                  ),
                // 「* 为必填项」hint，只在 initial 出现
                if (stage == SchoolBindingStage.initial)
                  const Positioned(
                    left: 329,
                    top: 77,
                    child: _RequiredHint(),
                  ),
                // 中部内容：输入框 / 状态行
                if (stage == SchoolBindingStage.initial)
                  Positioned(
                    left: 22,
                    top: 116,
                    child: _SchoolIdInput(
                      controller: textController,
                      onChanged: onChanged,
                    ),
                  )
                else
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 123,
                    child: Center(child: _StatusRow(state: state)),
                  ),
                // 底部主按钮：initial=发起绑定 / 其余=重新绑定
                Positioned(
                  left: 22,
                  top: stage == SchoolBindingStage.initial ? 185 : 175,
                  child: _PrimaryButton(
                    label: stage == SchoolBindingStage.initial
                        ? '发起绑定'
                        : '重新绑定',
                    loading: state.submitting,
                    onTap: () {
                      if (state.submitting) return;
                      if (stage == SchoolBindingStage.initial) {
                        unawaitedSubmit(onSubmit);
                      } else {
                        onRebind();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void unawaitedSubmit(Future<void> Function() fn) {
    // ignore: unawaited_futures
    fn();
  }

  static String _topHint(SchoolBindingStage stage) {
    switch (stage) {
      case SchoolBindingStage.initial:
        return '同学你还没';
      case SchoolBindingStage.pending:
        return '同学您当前';
      case SchoolBindingStage.rejected:
        return '同学未通过';
    }
  }
}

/// 顶部装饰图。与 [GradientHeaderDialog] 等其他弹窗保持一致：横跨整个卡片
/// 顶部、`fit: BoxFit.fitWidth`，由卡片自身的圆角 + `Clip.antiAlias` 负责裁
/// 切超出部分。`errorBuilder` 兜底防止 release 包资源遗漏时直接黑屏。
class _HeaderDecoration extends StatelessWidget {
  const _HeaderDecoration();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.coursewareUploadHeader,
      fit: BoxFit.fitWidth,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// 卡片左上角的「同学…」徽章：紫色 / 红色气泡背景图 + 白色文字。
///
/// 用 [DecorationImage]（`BoxFit.fill`）让背景气泡贴合容器，文字通过
/// `padding` 偏到气泡正中，左下角的小尾巴随图绘制不需要单独画。如果资
/// 源缺失，`Image.asset` 的失败不会抛错（DecorationImage 内部静默），
/// 文字仍可见，可在弱网首屏退化为「纯白色文字」效果。
class _TopHintBadge extends StatelessWidget {
  const _TopHintBadge({required this.stage, required this.text});

  final SchoolBindingStage stage;
  final String text;

  @override
  Widget build(BuildContext context) {
    final asset = stage == SchoolBindingStage.rejected
        ? AppAssets.homeTipsBadgeError
        : AppAssets.homeTipsBadge;
    return Container(
      width: 90,
      height: 28,
      // 左/右内边距留出尾巴位置，让文字视觉居中在气泡主体上。
      padding: const EdgeInsets.only(left: 6, right: 4, bottom: 4),
      decoration: BoxDecoration(
        image: DecorationImage(image: AssetImage(asset), fit: BoxFit.fill),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1,
        ),
      ),
    );
  }
}

class _DialogTitle extends StatelessWidget {
  const _DialogTitle({required this.stage});
  final SchoolBindingStage stage;

  @override
  Widget build(BuildContext context) {
    // "绑定" 紫色 + 副标题黑色，整体 24 / w600。
    final tail = stage == SchoolBindingStage.pending ? '学校还在审核中' : '您所在的学校';
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 24,
          height: 32 / 24,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w600,
        ),
        children: [
          const TextSpan(
            text: '绑定',
            style: TextStyle(color: Color(0xFF8741FF)),
          ),
          TextSpan(text: tail, style: const TextStyle(color: Color(0xFF0B081A))),
        ],
      ),
    );
  }
}

class _RequiredHint extends StatelessWidget {
  const _RequiredHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '*',
          style: TextStyle(
            color: Color(0xFFFF6969),
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            height: 12 / 14,
          ),
        ),
        const SizedBox(width: 1),
        Text(
          '为必填项',
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: 14,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 12 / 14,
          ),
        ),
      ],
    );
  }
}

class _SchoolIdInput extends StatelessWidget {
  const _SchoolIdInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 376,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 「* 学校ID」前缀
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFFF6969),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '学校ID',
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: 14,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLength: 18,
              keyboardType: TextInputType.text,
              inputFormatters: [
                LengthLimitingTextInputFormatter(18),
              ],
              cursorColor: const Color(0xFF8741FF),
              cursorWidth: 1.4,
              cursorHeight: 16,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: 14,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: '请输入18位ID数',
                hintStyle: TextStyle(
                  color: const Color(0xFFB6B5BB),
                  fontSize: 14,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 12 / 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});

  final SchoolBindingState state;

  @override
  Widget build(BuildContext context) {
    final isPending = state.stage == SchoolBindingStage.pending;
    final prefix = isPending ? '当前状态：' : '未通过原因：';
    final accent = isPending
        ? '审核中'
        : (state.rejectReason.isEmpty ? '学校ID填写错误' : state.rejectReason);
    final accentColor = isPending
        ? const Color(0xFF325BFF)
        : const Color(0xFF8741FF);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1,
        ),
        children: [
          TextSpan(
            text: prefix,
            style: const TextStyle(color: Color(0xFFB6B5BB)),
          ),
          TextSpan(text: accent, style: TextStyle(color: accentColor)),
        ],
      ),
    );
  }
}

/// 底部主按钮：376×45 紫色渐变 + 投影。
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Container(
        width: 376,
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59AD80FF),
              offset: Offset(0, 16),
              blurRadius: 20,
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 12 / 16,
                ),
              ),
      ),
    );
  }
}
