/// 「绑定学校」遮罩弹窗的可视阶段。
///
/// - [initial]：尚未发起申请（或用户点击「重新绑定」回到表单），展示
///   输入框 + 「发起绑定」按钮；
/// - [pending]：申请已提交后台审核中（schoolJoinList 返回 `status=0`）；
/// - [rejected]：申请被驳回（`status=2`），展示原因 + 「重新绑定」按钮。
enum SchoolBindingStage { initial, pending, rejected }

/// 「绑定学校」控制器对外暴露的状态。
///
/// 设计意图：
/// - [resolved] 标记一次完整的「拉取 schoolList + 必要时拉取 joinList」
///   是否已完成。**在 resolved=true 之前不应展示遮罩**，否则冷启动会
///   出现「页面闪一下」的弹窗。
/// - [hasSchool] 用 `/v2/user/schoolList` 返回的 `data.isNotEmpty` 来
///   判断，是「无需展示遮罩」的唯一信号。
/// - [serverStage] / [userOverride]：申请阶段拆成「服务器告诉我们的真
///   实状态」与「用户手动切换到的本地状态」两层。「重新绑定」按钮只是
///   把视图切回表单，不改变后端记录，所以用 [userOverride] 覆盖；下次
///   成功提交后再清空，让 [serverStage] 接管。
class SchoolBindingState {
  const SchoolBindingState({
    this.resolved = false,
    this.hasSchool = false,
    this.serverStage = SchoolBindingStage.initial,
    this.userOverride,
    this.rejectReason = '',
    this.schoolIdInput = '',
    this.submitting = false,
    this.errorMessage = '',
  });

  /// 是否已经至少完成一次「拉取学校列表」请求。
  ///
  /// 仅当为 true 且 [hasSchool] 为 false 时遮罩才可以渲染，避免冷启动
  /// 阶段（API 还没回来）短暂闪一下绑定弹窗。
  final bool resolved;

  /// 当前账号是否已绑定到任一学校。`true` 时遮罩需要立刻消失。
  final bool hasSchool;

  /// 后端 `schoolJoinList` 推导出来的「真实」申请阶段。
  final SchoolBindingStage serverStage;

  /// 用户主动覆盖的本地阶段（如点击「重新绑定」时强制切回 [initial]）。
  /// 为 `null` 时以 [serverStage] 为准。
  final SchoolBindingStage? userOverride;

  /// `serverStage == rejected` 时后端给的驳回原因；
  /// 兜底文案在控制器里统一塞入，UI 直接读即可。
  final String rejectReason;

  /// 用户在输入框里键入的学校 ID（trim 后），跨 stage 不自动清空——
  /// 只有「重新绑定」与「提交成功」两个时机由控制器主动清空。
  final String schoolIdInput;

  /// 是否正在调用 `schoolJoin`，UI 用来禁用按钮。
  final bool submitting;

  /// 上一次提交 / 校验出错的提示文案。可空字符串表示无错误。
  final String errorMessage;

  /// 视图应当展示的阶段：[userOverride] 优先于 [serverStage]。
  SchoolBindingStage get stage => userOverride ?? serverStage;

  /// 给 ShellScaffold 直接调用：是否需要渲染遮罩弹窗。
  bool get shouldShowOverlay => resolved && !hasSchool;

  SchoolBindingState copyWith({
    bool? resolved,
    bool? hasSchool,
    SchoolBindingStage? serverStage,
    Object? userOverride = _sentinel,
    String? rejectReason,
    String? schoolIdInput,
    bool? submitting,
    String? errorMessage,
  }) {
    return SchoolBindingState(
      resolved: resolved ?? this.resolved,
      hasSchool: hasSchool ?? this.hasSchool,
      serverStage: serverStage ?? this.serverStage,
      userOverride: identical(userOverride, _sentinel)
          ? this.userOverride
          : userOverride as SchoolBindingStage?,
      rejectReason: rejectReason ?? this.rejectReason,
      schoolIdInput: schoolIdInput ?? this.schoolIdInput,
      submitting: submitting ?? this.submitting,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 用于 [copyWith] 区分「未传 userOverride」与「显式传 null」。
  static const Object _sentinel = Object();
}
