import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../../school/data/school_repository.dart';
import 'school_binding_state.dart';

/// 「绑定学校」模态弹窗的全局控制器。
///
/// 与登录态绑定的非 autoDispose 单例：用户登录后第一次进入受保护页面
/// （ShellScaffold 挂载）即创建并自动开始 5s 一次的轮询；用户登出时
/// ShellController 会通过 `ref.invalidate` 把它销毁，下次再登录会重建。
final schoolBindingControllerProvider =
    StateNotifierProvider<SchoolBindingController, SchoolBindingState>((ref) {
      final repository = ref.watch(schoolRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      return SchoolBindingController(
        repository: repository,
        storage: storage,
      );
    });

/// 维护「是否已绑定学校 + 当前申请阶段」并按 5 秒一次的频率轮询后端，
/// 直到拿到首条学校记录后停止。
///
/// 流程概要：
/// 1. 调 `schoolList`：返回非空 → 标记 [SchoolBindingState.hasSchool]=true，
///    取消轮询。
/// 2. 返回空 → 再调 `schoolJoinList` 取首条记录，按 `status` 映射到本地
///    [SchoolBindingStage]。`status=0` 待审核、`status=2` 拒绝、其它一律
///    视作 initial（让用户重新提交）。
/// 3. 「重新绑定」按钮调用 [enterRebindForm]，临时把视图切回输入表单，
///    不影响后端状态；轮询持续。
/// 4. 提交 `schoolJoin` 成功后立即主动 [refresh] 一次，让审核中 UI 尽快
///    出现，避免等下一个 5s tick。
class SchoolBindingController extends StateNotifier<SchoolBindingState> {
  SchoolBindingController({
    required SchoolRepository repository,
    required AppStorage storage,
  }) : _repository = repository,
       _storage = storage,
       super(const SchoolBindingState()) {
    // 构造即启动；若 token 为空（用户尚未登录的边缘场景）会跳过 API 并
    // 不起定时器，等显式 refresh() 再启动。
    _start();
  }

  final SchoolRepository _repository;
  final AppStorage _storage;

  Timer? _timer;
  bool _disposed = false;

  /// 当前是否处于「拉数据中」，避免上一次请求未完成时下一个 tick 又叠
  /// 加进来打满网络。仅用于防抖，不暴露给 UI。
  bool _refreshing = false;

  // ── 对外 API ─────────────────────────────────────────────────────────

  /// 立刻拉一次接口；如果定时器已停（首次启动 / token 切换 / hasSchool=true
  /// 之后又被外部唤醒），会同时把定时器重新点燃。
  ///
  /// 登录页提交成功后立即调用，确保新会话首屏就开始轮询。
  void refresh() {
    if (_storage.token.isEmpty) {
      return;
    }
    if (_timer == null || !_timer!.isActive) {
      _restartTimer();
    }
    unawaited(_refresh());
  }

  /// 「重新绑定」按钮的处理：把视图切回输入表单（不动后端状态），并清
  /// 空上次的输入与错误提示，避免上一轮的脏数据干扰新一轮提交。
  void enterRebindForm() {
    state = state.copyWith(
      userOverride: SchoolBindingStage.initial,
      schoolIdInput: '',
      errorMessage: '',
    );
  }

  /// 输入框 onChanged 回调。trim 一下，避免用户复制粘贴时带空格。
  void setSchoolIdInput(String value) {
    final v = value.trim();
    if (v == state.schoolIdInput && state.errorMessage.isEmpty) {
      return;
    }
    state = state.copyWith(schoolIdInput: v, errorMessage: '');
  }

  /// 调用 `schoolJoin` 上送一次绑定申请。
  ///
  /// 返回 `true` 表示后端 `code==0`，UI 可以做后续动画或提示；返回
  /// `false` 时具体错误信息会写入 [SchoolBindingState.errorMessage]，
  /// UI 直接渲染即可，无需另开 toast。
  Future<bool> submitBinding() async {
    if (state.submitting) {
      return false;
    }
    final id = state.schoolIdInput.trim();
    if (id.isEmpty) {
      state = state.copyWith(errorMessage: '请输入学校ID');
      return false;
    }

    state = state.copyWith(submitting: true, errorMessage: '');
    final ApiResponse response = await _repository.submitSchoolBinding(id);
    if (_disposed) return false;

    if (response.code != 0) {
      state = state.copyWith(
        submitting: false,
        errorMessage: response.msg.isEmpty ? '提交失败，请稍后重试' : response.msg,
      );
      return false;
    }

    // 提交成功：清掉 userOverride 让 server 推回的 stage 接管；同时把
    // serverStage 预先置为 pending，使「审核中」UI 在下一次轮询前就能
    // 立即生效，体验更顺滑。
    state = state.copyWith(
      submitting: false,
      serverStage: SchoolBindingStage.pending,
      userOverride: null,
      schoolIdInput: '',
      errorMessage: '',
    );
    refresh();
    return true;
  }

  // ── 内部实现 ─────────────────────────────────────────────────────────

  void _start() {
    if (_storage.token.isEmpty) return;
    _restartTimer();
    unawaited(_refresh());
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_disposed || _refreshing) return;
    if (_storage.token.isEmpty) {
      _timer?.cancel();
      return;
    }
    _refreshing = true;
    try {
      final schoolResp = await _repository.getSchoolInfo();
      if (_disposed) return;
      if (schoolResp.code != 0) {
        // 网络异常时不动 resolved，沿用上一帧的状态（避免突然弹/收弹窗）
        return;
      }
      final data = schoolResp.data;
      final hasSchool = data is List && data.isNotEmpty;

      if (hasSchool) {
        _timer?.cancel();
        state = state.copyWith(
          resolved: true,
          hasSchool: true,
          serverStage: SchoolBindingStage.initial,
          userOverride: null,
          rejectReason: '',
          errorMessage: '',
        );
        return;
      }

      final joinResp = await _repository.getSchoolJoinList();
      if (_disposed) return;
      if (joinResp.code != 0) {
        // joinList 失败时，也至少把 resolved 翻到 true，让弹窗按上一轮
        // 已知阶段继续展示（首次失败则按 initial 兜底）。
        state = state.copyWith(resolved: true, hasSchool: false);
        return;
      }

      final parsed = _parseJoinStage(joinResp.data);
      state = state.copyWith(
        resolved: true,
        hasSchool: false,
        serverStage: parsed.stage,
        rejectReason: parsed.reason,
      );
    } finally {
      _refreshing = false;
    }
  }

  /// 解析 `schoolJoinList` 数组里第一条记录的 `status` 字段。
  ///
  /// 后端约定：`0`-待审核 / `1`-通过 / `2`-拒绝。其它值（含异常 / 旧版本）
  /// 兜底为 [SchoolBindingStage.initial]，让用户能重新发起绑定。
  _JoinParseResult _parseJoinStage(dynamic data) {
    if (data is! List || data.isEmpty) {
      return const _JoinParseResult(SchoolBindingStage.initial, '');
    }
    final first = data.first;
    if (first is! Map) {
      return const _JoinParseResult(SchoolBindingStage.initial, '');
    }
    final statusRaw = first['status'];
    final status = statusRaw is int
        ? statusRaw
        : int.tryParse(statusRaw?.toString() ?? '') ?? -1;
    if (status == 0) {
      return const _JoinParseResult(SchoolBindingStage.pending, '');
    }
    if (status == 2) {
      final raw = first['rejectReason']?.toString().trim() ?? '';
      // 后端没返原因时，按设计稿兜底文案。
      return _JoinParseResult(
        SchoolBindingStage.rejected,
        raw.isEmpty ? '学校ID填写错误' : raw,
      );
    }
    return const _JoinParseResult(SchoolBindingStage.initial, '');
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

class _JoinParseResult {
  const _JoinParseResult(this.stage, this.reason);
  final SchoolBindingStage stage;
  final String reason;
}
