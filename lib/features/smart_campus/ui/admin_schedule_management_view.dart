// =============================================================================
// 管理员端「排课与课表」独立页面
//
// 入口：admin dashboard 快捷区「排课与课表」按钮 →
//      controller.openScheduleManagement() → mainView == scheduleManagement +
//      role == admin → SmartCampusPage 路由到本视图。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（68 高）：白→#F9EDFF 渐变；左 32 返回；居中 16/600
//      "排课与课表"；右上角分段控制（周课表与排课 / 小课申请审核，
//      激活段 #0B081A 黑底白字 + 红角标（待审核条数，来自
//      schoolSmallCourseApplyList status=0 的分页 total）。
//   2. tab1「周课表与排课」：
//      - 顶部一行：「全校统一课表」班级 dropdown（左）+ 查看 / 编辑 分段
//        （右，激活 #8741FF 紫底白字）。
//      - 控制条（64 高 #F5F6FA 灰底 12 圆角）：教学周 + legend +
//        ◀ 本周 ▶ + YYYY/MM/DD 日历 pill。
//      - 网格（930×632，1px #F3F2F3 描边，12 圆角）：与学生 / 老师端共用
//        4 主题课卡 + 时间冻结列 + 横滚日期区。
//      - 编辑模式下空格 → "申请小课" pill 打开右侧 [_AdminEditCourseDrawer]，
//        提交触发 `courseBatchSave`。
//   3. tab2「小课申请审核」：
//      - "小课排班申请" 18/500 节标题。
//      - 双列卡片网格（每卡 #F5F6FA 灰底 16 圆角）：avatar + 标题 + 状态
//        徽章（待审核 / 已通过 / 已驳回）+ 日期 / 节次 灰底两列 + 备注 +
//        通过 / 驳回（仅待审核态显示）。
//      - "驳回" 打开 GradientHeaderDialog 形式的「驳回申请」弹窗
//        （理由 TextField），确认后调 `schoolSmallCourseApplyAudit
//        (status: 2, reason: ...)`；"通过" 直接调 `(status: 1)` 并刷新列表。
//
// 颜色：白 / #F5F6FA 灰 / #F3F2F3 边 / #8741FF 主紫 / #6D6B75 副字 /
//      #B6B5BB 提示 / #774B09 橙文 / #0D3A6D 蓝文 / #7535BE 紫文 /
//      #FF6A00 待审核 / #0CAC40·#12CE51 已通过
// =============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 通用配色 -----------------------------------------------------------

const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kRedBadge = Color(0xFFF04545);

// 4 种课卡主题
const Color _kSmallOrangeBg = Color(0xFFFFEDD3);
const Color _kSmallOrangeTitle = Color(0xFF774B09);
const Color _kSmallBlueBg = Color(0xFFD9EBFF);
const Color _kSmallBlueTitle = Color(0xFF0D3A6D);
const Color _kBigStandardBg = Color(0xFFE8D4FF);
const Color _kBigExtendedBg = Color(0xFFF6EFFE);
const Color _kBigTitle = Color(0xFF7535BE);

const Color _kStatusGreen = Color(0xFF0CAC40);
const Color _kStatusPurple = Color(0xFFA773FF);

// 申请卡状态色
const Color _kPendingBg = Color(0xFFFFEDD3);
const Color _kPendingFg = Color(0xFFFF6A00);
const Color _kPassedBg = Color(0xFFE4FFED);
const Color _kPassedFg = Color(0xFF12CE51);
const Color _kRejectedBg = Color(0xFFFFE5E5);
const Color _kRejectedFg = Color(0xFFE83A3A);

// 列与行尺寸
const double _kTimeColWidth = 120;
const double _kDayColWidth = 200;
const double _kHeaderHeight = 60;

enum _ScheduleMode { view, edit }

enum _AdminScheduleTab { schedule, applyAudit }

/// 申请审核状态：与后端 `status` 字段双向映射 — 1 通过 / 2 驳回 / 0 / null 待审核。
enum _ApplyStatus { pending, passed, rejected }

class AdminScheduleManagementView extends ConsumerStatefulWidget {
  const AdminScheduleManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminScheduleManagementView> createState() =>
      _AdminScheduleManagementViewState();
}

class _AdminScheduleManagementViewState
    extends ConsumerState<AdminScheduleManagementView> {
  _AdminScheduleTab _tab = _AdminScheduleTab.schedule;

  // —— tab 1 状态 ————————————————————————————————————————————————
  /// 当前显示的周一（用于日期范围 / 标签 / API begin/end）。
  late DateTime _weekStart;

  /// "教学周第 N 周" 的展示数字。本地维护，与 `_weekStart` 联动：
  /// 默认 12 周（"本周"），每翻一周 ±1。后端 swagger 没单独返回教学周编号，
  /// 这里仅做 UI 展示，与 API 数据无强耦合。
  int _currentWeek = 12;
  static const int _baseWeek = 12;

  _ScheduleMode _mode = _ScheduleMode.view;

  /// 班级下拉数据（来自 `classList`）。后端 `schoolTimeConfigList` /
  /// `courseList` 都要求 classId 必填，所以默认进入 = 班级列表第 1 项；
  /// 列表为空前用空字符串占位，加载完成后自动回填。
  List<({String id, String name})> _classes = const [];
  String? _selectedClassId;
  String _selectedClassName = '加载中…';

  /// 「小课申请审核」用的字典：申请记录里只有 ID（classId / classroomId /
  /// subjectId / teacherId），需要查字典还原成名称才能在卡片上显示。
  /// 字典加载与申请列表解耦：失败 / 慢都不会阻断 schedule 主网格渲染；
  /// 出问题时申请卡上对应字段会回落到「—」。
  Map<String, String> _classNameById = const {};
  Map<int, String> _classroomNameById = const {};
  Map<int, String> _subjectNameById = const {};
  Map<String, String> _teacherNameById = const {};

  /// 课表网格的实际数据（[7 天][N 节] → 多张课卡）。null 表示尚未加载。
  List<List<List<_ScheduleCardData>>>? _serverCells;
  bool _scheduleLoading = false;

  /// 课表左侧节次时间表（来自 `schoolTimeConfigList`），按 `lineNum` 升序。
  /// API 未返回时退回 [_kDefaultTimeConfigs] 的 5 节兜底。
  List<_TimeConfig> _timeConfigs = const [];

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 把任意日期归一化到所在 ISO 周的周一。
  DateTime _mondayOf(DateTime d) {
    final pure = DateTime(d.year, d.month, d.day);
    return pure.subtract(Duration(days: pure.weekday - 1));
  }

  void _gotoPrev() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _currentWeek -= 1;
    });
    _loadSchedule();
  }

  void _gotoNext() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _currentWeek += 1;
    });
    _loadSchedule();
  }

  void _gotoCurrent() {
    setState(() {
      _weekStart = _mondayOf(DateTime.now());
      _currentWeek = _baseWeek;
    });
    _loadSchedule();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: '选择教学日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: appPickerDialogTheme,
    );
    if (picked == null) return;
    final newMonday = _mondayOf(picked);
    final deltaWeeks = (newMonday.difference(_weekStart).inDays / 7).round();
    setState(() {
      _weekStart = newMonday;
      _currentWeek += deltaWeeks;
    });
    _loadSchedule();
  }

  String _slotLabel(int dayIdx, int slotIdx) {
    final configs = _activeTimeConfigs;
    final cfg = configs[slotIdx.clamp(0, configs.length - 1)];
    final day = _weekStart.add(Duration(days: dayIdx));
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '第${cfg.lineNum}节 ${cfg.start}-${cfg.end}· ${labels[dayIdx]} '
        '${_isoDate(day)}';
  }

  /// 编辑模式空格落点要传给抽屉的 lineNum：取该 slot 对应的 lineNum
  /// （API 配置可能是 1/2/3/5/6 这种非连续序列）。
  int _lineNumOf(int slotIdx) {
    final configs = _activeTimeConfigs;
    return configs[slotIdx.clamp(0, configs.length - 1)].lineNum;
  }

  /// 编辑模式下点击空格 → 弹右侧 [_AdminEditCourseDrawer]，提交时调
  /// `courseBatchSave` 写入一条排课，成功后重新拉取本周课表。
  Future<void> _onApplySmallLesson(int dayIdx, int slotIdx) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final day = _weekStart.add(Duration(days: dayIdx));
    final isoDate = _isoDate(day);

    final submitted = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondary) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _AdminEditCourseDrawer(
                slotLabel: _slotLabel(dayIdx, slotIdx),
                dateIso: isoDate,
                lineNum: _lineNumOf(slotIdx),
                currentWeek: _currentWeek,
                initialClassId: _selectedClassId,
                onCancel: () => Navigator.of(ctx).maybePop(),
                onSubmitted: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondary, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );

    if (submitted != true || !mounted) return;
    AppToast.show(context, '已写入课表');
    await _loadSchedule();
  }

  /// 编辑模式下，把某节大课从 `(sourceDay, sourceSlot)` 拖到
  /// `(targetDay, targetSlot)`：
  ///   1. 同格直接 no-op；
  ///   2. 乐观更新本地 `_serverCells`；
  ///   3. 调 `courseDelete(oldId)` 删旧课、`courseBatchSave(newRow)` 写一条新课
  ///      （只覆盖当前周这一节，其它周不动）；
  ///   4. 任一步失败回滚本地状态并提示；成功后 `_loadSchedule()` 拿新 id 同步。
  Future<void> _onDropCard(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  ) async {
    if (payload.sourceDay == targetDay && payload.sourceSlot == targetSlot) {
      return;
    }
    final raw = payload.card.raw;
    if (raw == null) return;
    if (_selectedClassId == null || _selectedClassId!.isEmpty) return;

    final configs = _activeTimeConfigs;
    if (targetSlot < 0 || targetSlot >= configs.length) return;
    final cellsNow = _serverCells;
    if (cellsNow == null) return;
    final newLineNum = configs[targetSlot].lineNum;
    final newDate = _isoDate(_weekStart.add(Duration(days: targetDay)));

    final backup = _cloneCells(cellsNow);

    setState(() {
      final src = cellsNow[payload.sourceDay][payload.sourceSlot];
      // 优先按 indexInSlot 移除，避免同卡多次拖动时找错；越界再回退到 identical 匹配。
      if (payload.indexInSlot < src.length &&
          identical(src[payload.indexInSlot], payload.card)) {
        src.removeAt(payload.indexInSlot);
      } else {
        src.removeWhere((c) => identical(c, payload.card));
      }
      cellsNow[targetDay][targetSlot].add(payload.card);
    });

    final repo = ref.read(adminRepositoryProvider);
    final oldId = _pickString(raw, ['id'], '');
    var ok = true;
    String? errMsg;

    if (oldId.isNotEmpty) {
      final del = await repo.courseDelete([oldId]);
      if (!del.isSuccess) {
        ok = false;
        errMsg = del.msg;
      }
    }
    if (ok) {
      final classId = _pickString(raw, ['classId'], _selectedClassId ?? '');
      final teacherId = _pickString(raw, ['teacherId'], '');
      final newRow = <String, dynamic>{
        if (classId.isNotEmpty) 'classId': classId,
        if (teacherId.isNotEmpty) 'teacherId': teacherId,
        if (raw['classroomId'] != null) 'classroomId': raw['classroomId'],
        if (raw['subjectId'] != null) 'subjectId': raw['subjectId'],
        if (raw['type'] != null) 'type': raw['type'],
        if ((raw['color'] ?? '').toString().isNotEmpty) 'color': raw['color'],
        // courseBatchSave 期望 swagger 里的 ISO+TZ 格式（与 _onApplySmallLesson 一致）。
        'date': '${newDate}',
        'lineNum': newLineNum,
      };
      final save = await repo.courseBatchSave([newRow]);
      if (!save.isSuccess) {
        ok = false;
        errMsg = save.msg;
      }
    }

    if (!mounted) return;
    if (!ok) {
      setState(() => _serverCells = backup);
      AppToast.show(
        context,
        (errMsg == null || errMsg.isEmpty) ? '移动失败，请重试' : errMsg,
      );
      return;
    }
    // 不再立刻 _loadSchedule()：后端 courseDelete 偶有落库延迟，
    // 重新拉回的列表里可能仍带着刚移走的那条记录，导致源格"鬼影"复现。
    // 这里只把本地 raw 同步到新位置，乐观更新已经把卡片从源格搬走，
    // UI 与意图保持一致；下次切周 / 切班时会自然 reload 拿到权威状态。
    raw['date'] = newDate;
    raw['lineNum'] = newLineNum;
    AppToast.show(context, '已移动');
  }

  /// `_serverCells` 三维结构的浅克隆（外两层新建 List，最内层 `_ScheduleCardData`
  /// 是不可变值，直接共享即可），用于拖动失败回滚。
  List<List<List<_ScheduleCardData>>> _cloneCells(
    List<List<List<_ScheduleCardData>>> cells,
  ) {
    return [
      for (final day in cells)
        [
          for (final slot in day) [...slot],
        ],
    ];
  }

  // —— tab 2 状态 ————————————————————————————————————————————————
  bool _applyLoading = false;
  List<_ApplyRecord>? _applies;
  String? _applyError;

  /// 当前班级下「待审核」小课申请数量（角标）。优先取列表接口里
  /// `status=0` 查询返回的分页 total；拿不到时再数列表里的 pending。
  int _pendingApplyCount = 0;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 接口要求 classId 必填 → 必须先拉班级列表，拿到第 1 项作为默认班级，
      // 再依次拉左侧时间表（按 classId 维度）+ 课表，保证 lineNum → slotIdx
      // 映射在解析课表前到位。
      await _loadClasses();
      if (!mounted) return;
      if (_classes.isNotEmpty && _selectedClassId == null) {
        setState(() {
          _selectedClassId = _classes.first.id;
          _selectedClassName = _classes.first.name;
        });
      }
      // 申请审核字典与时间表 / 课表并行：失败不阻断 schedule 渲染，只是
      // 申请卡上对应字段会回落到「—」。字典就绪前先开 _loadApplies()
      // 也无所谓 —— 申请字段会在 _loadApplyDirectories() setState 后随
      // 下一次 _loadApplies() 自然补齐（实际场景里 _loadApplies 在字典
      // ready 之后再跑，所以一次到位）。
      await Future.wait([_loadTimeConfig(), _loadApplyDirectories()]);
      if (!mounted) return;
      _loadSchedule();
      _loadApplies();
    });
  }

  // —— 数据加载 ————————————————————————————————————————————————

  /// 取课表左侧时间列表。`schoolTimeConfigList` 接口 `classId` 必填，
  /// 班级未就绪时直接跳过、走 [_kDefaultTimeConfigs] 兜底。
  ///
  /// 后端字段：`timeBegin` / `timeEnd` 是 `HH:MM:SS` 字符串（也兼容
  /// `startTime` / `beginTime` 这些历史字段名），UI 上只显示 `HH:MM`。
  Future<void> _loadTimeConfig() async {
    if (_selectedClassId == null || _selectedClassId!.isEmpty) return;
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.schoolTimeConfigList(classId: _selectedClassId);
    if (!mounted || !resp.isSuccess) return;
    final rows = _extractList(resp);
    final list = <_TimeConfig>[];
    for (final m in rows) {
      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      final start = _trimToHm(
        _pickString(m, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
      );
      final end = _trimToHm(
        _pickString(m, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
      );
      if (start.isEmpty || end.isEmpty) continue;
      list.add(_TimeConfig(lineNum: lineNum, start: start, end: end));
    }
    list.sort((a, b) => a.lineNum.compareTo(b.lineNum));
    if (!mounted || list.isEmpty) return;
    setState(() => _timeConfigs = list);
  }

  /// `HH:MM:SS` / `HH:MM` 都归一化成 `HH:MM`。
  String _trimToHm(String s) {
    if (s.isEmpty) return s;
    final parts = s.split(':');
    if (parts.length < 2) return s;
    return '${parts[0]}:${parts[1]}';
  }

  Future<void> _loadClasses() async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList();
    if (!mounted || !resp.isSuccess) return;
    final rows = _extractList(resp);
    final list = <({String id, String name})>[];
    final nameById = <String, String>{};
    for (final m in rows) {
      final id = _pickString(m, ['id', 'classId'], '');
      final name = _pickString(m, ['name', 'className', 'fullName'], '');
      if (id.isNotEmpty && name.isNotEmpty) {
        list.add((id: id, name: name));
        nameById[id] = name;
      }
    }
    if (!mounted) return;
    setState(() {
      _classes = list;
      _classNameById = nameById;
    });
  }

  /// 拉「小课申请审核」要用的字典 —— 教室 / 教师 / 科目（per 班级）。
  /// 与主流程解耦：失败不会阻断 schedule / apply 列表渲染。
  ///
  /// - 教室走 admin `classroomList`（全校公共，一次拉全量）；
  /// - 教师走 admin `teacherList`（按 schoolId 拉全量，每个雪花长 id →
  ///   `realname` / `nickname` 兜底）；
  /// - 科目走 user `subjectList(classId)`，必须按班级查 —— 接口不传 classId
  ///   实测不返回全量。所以这里按 `_classNameById` 里每个班级并行发 N 个
  ///   请求，结果合并。`_classes` 通常 < 30 个，单次开页面成本可控。
  Future<void> _loadApplyDirectories() async {
    final adminRepo = ref.read(adminRepositoryProvider);
    final schoolRepo = ref.read(schoolRepositoryProvider);

    final classIds = _classNameById.keys.toList();
    final classroomFuture = adminRepo.classroomList();
    final teacherFuture = adminRepo.teacherList();
    final subjectFutures = <Future<ApiResponse>>[
      for (final cid in classIds) schoolRepo.subjectList(classId: cid),
    ];

    final classroomResp = await classroomFuture;
    final teacherResp = await teacherFuture;
    final subjectResps = await Future.wait(subjectFutures);
    if (!mounted) return;

    final classroomMap = <int, String>{};
    if (classroomResp.isSuccess) {
      for (final m in _extractList(classroomResp)) {
        final rawId = m['id'] ?? m['classroomId'] ?? m['roomId'];
        final id = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        final name = _pickString(m, [
          'name',
          'classroomName',
          'roomName',
        ], '');
        if (id != null && name.isNotEmpty) classroomMap[id] = name;
      }
    }

    final teacherMap = <String, String>{};
    if (teacherResp.isSuccess) {
      for (final m in _extractList(teacherResp)) {
        // teacherId 是雪花 long → 必须以 String 承载，外层 JSON 已经引号
        // 包裹，这里 _pickString 直接拿原文即可。
        final id = _pickString(m, ['id', 'teacherId'], '');
        final name = _pickString(m, [
          'realname',
          'realName',
          'nickname',
          'name',
        ], '');
        if (id.isNotEmpty && name.isNotEmpty) teacherMap[id] = name;
      }
    }

    final subjectMap = <int, String>{};
    for (final resp in subjectResps) {
      if (!resp.isSuccess) continue;
      for (final m in _extractList(resp)) {
        final rawId = m['id'] ?? m['subjectId'];
        final id = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        final name = _pickString(m, [
          'name',
          'subjectName',
        ], '');
        if (id != null && name.isNotEmpty) subjectMap[id] = name;
      }
    }

    if (!mounted) return;
    setState(() {
      _classroomNameById = classroomMap;
      _teacherNameById = teacherMap;
      _subjectNameById = subjectMap;
    });
  }

  Future<void> _loadSchedule() async {
    // classId 必填：班级未就绪时先把网格清空，避免无意义请求。
    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
      setState(() {
        _serverCells = _emptyCells();
        _scheduleLoading = false;
      });
      return;
    }
    setState(() => _scheduleLoading = true);
    final repo = ref.read(adminRepositoryProvider);
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final resp = await repo.courseList(
      classId: _selectedClassId,
      beginDate: _isoDate(start),
      endDate: _isoDate(end),
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _serverCells = _emptyCells();
        _scheduleLoading = false;
      });
      return;
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    final rows = _extractCourseRows(resp);
    // 单元格内 第 N 张小课卡 用于决定 橙 / 蓝 主题轮换。
    final smallSeq = <int, int>{};
    for (final entry in rows) {
      final m = entry.row;
      // 优先用日期分组的 key（API 新格式 data: {"2026-05-11": [...]}），
      // 回退到 row 自身的 date 字段（兼容老的扁平 List 格式）。
      final dateStr = entry.dateKey.isNotEmpty
          ? entry.dateKey
          : _pickString(m, ['date', 'classDate', 'courseDate'], '');
      final dayIdx = _dayIndex(dateStr);
      if (dayIdx < 0) continue;

      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      // 用 lineNum 在 configs 中查找；非连续 lineNum 也能正确落格。
      var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
      if (slotIdx < 0) {
        slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
      }

      final cellKey = dayIdx * 1000 + slotIdx;
      final card = _parseCourseCard(m, smallSeq[cellKey] ?? 0);
      smallSeq[cellKey] = (smallSeq[cellKey] ?? 0) + 1;
      cells[dayIdx][slotIdx].add(card);
    }

    setState(() {
      _serverCells = cells;
      _scheduleLoading = false;
    });
  }

  /// `courseList` 的 `data` 既可能是按日期分组的 Map（新格式：
  /// `{"2026-05-11": [{...}, ...], "2026-05-12": [...]}`），也可能是
  /// 扁平 List（老格式）。统一摊平成 `(dateKey, row)` 元组。
  List<({String dateKey, Map<String, dynamic> row})> _extractCourseRows(
    ApiResponse resp,
  ) {
    final raw = resp.data;
    final list = <({String dateKey, Map<String, dynamic> row})>[];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final v = entry.value;
        final key = entry.key.toString();
        if (v is List) {
          for (final item in v) {
            if (item is Map) {
              list.add((dateKey: key, row: item.cast<String, dynamic>()));
            }
          }
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add((dateKey: '', row: item.cast<String, dynamic>()));
        }
      }
    }
    return list;
  }

  List<List<List<_ScheduleCardData>>> _emptyCells() {
    final n = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [for (var s = 0; s < n; s++) <_ScheduleCardData>[]],
    ];
  }

  /// 根据当前格子内最多课卡数算出每行高度（动态适配 1 / 2 / N 张课卡叠放）。
  /// 所有节次行共用同一套高度规则，第一行不再特殊拉高。
  List<_TimeSlotData> _buildSlots(List<List<List<_ScheduleCardData>>> cells) {
    final configs = _activeTimeConfigs;
    return [
      for (var i = 0; i < configs.length; i++)
        _TimeSlotData(
          start: configs[i].start,
          end: configs[i].end,
          height: _calcSlotHeight(i, cells),
        ),
    ];
  }

  double _calcSlotHeight(
    int slotIdx,
    List<List<List<_ScheduleCardData>>> cells,
  ) {
    var maxCards = 1;
    for (var d = 0; d < cells.length; d++) {
      if (slotIdx < cells[d].length) {
        final n = cells[d][slotIdx].length;
        if (n > maxCards) maxCards = n;
      }
    }
    // 1 张：96 + 24 padding = 120；2 张：96 + 6 + 96 + 24 = 222；
    // N 张：120 + (N - 1) × 102（102 = 96 卡高 + 6 间距）。
    return 120.0 + (maxCards - 1) * 102.0;
  }

  /// 把后端返回的日期字符串归一化到当前周内的 [0..6]，否则返回 -1。
  int _dayIndex(String dateStr) {
    if (dateStr.isEmpty) return -1;
    DateTime? d = DateTime.tryParse(dateStr);
    if (d == null) {
      final iso = dateStr.split('T').first;
      d = DateTime.tryParse(iso);
    }
    if (d == null) return -1;
    final dn = DateTime(d.year, d.month, d.day);
    final ws = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    final diff = dn.difference(ws).inDays;
    return (diff < 0 || diff > 6) ? -1 : diff;
  }

  /// 把 courseList 单条记录翻译成 [_ScheduleCardData]。
  ///
  /// 字段映射对齐后端真实回包：
  /// ```json
  /// {
  ///   "subjectName": "视唱",
  ///   "teacherRealname": "宁为",
  ///   "teacherNickname": "哈哈",
  ///   "className": "音乐一班",
  ///   "classroomName": "艺术楼101",
  ///   "color": "#D2C4FF",
  ///   "type": 0,
  ///   ...
  /// }
  /// ```
  ///
  /// `type == 2` → 小课（同一格里第 0 张橙、第 1 张蓝循环）；其它值 → 大课。
  /// `color` 是 hex（含 `#`），存到卡片做背景覆盖；标题色按背景亮度自适应。
  _ScheduleCardData _parseCourseCard(
    Map<String, dynamic> json,
    int smallIdxInCell,
  ) {
    final typeRaw = json['type'];
    final type = typeRaw is int
        ? typeRaw
        : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
    final isSmall = type == 2;

    final location = _pickString(json, [
      'classroomName',
      'roomName',
      'classroom',
    ], '');
    final name = _pickString(json, [
      'subjectName',
      'courseName',
      'subject',
      'name',
    ], '');
    // 教师名：优先 realname（正式名），其次 nickname；兼容 teacherName 这种
    // 老接口字段。
    final teacher = _pickString(json, [
      'teacherRealname',
      'teacherName',
      'realname',
      'realName',
      'teacherNickname',
      'teacher',
    ], '');
    final className = _pickString(json, ['className', 'class'], '');
    final colorOverride = _parseHexColor(_pickString(json, ['color'], ''));

    final rawCopy = Map<String, dynamic>.from(json);
    if (isSmall) {
      final kind = smallIdxInCell.isEven
          ? _CardKind.smallOrange
          : _CardKind.smallBlue;
      final attendCount = json['attendCount'] ?? json['signCount'];
      final totalCount =
          json['totalCount'] ?? json['capacity'] ?? json['classSize'];
      String? cap;
      if (attendCount != null && totalCount != null) {
        cap = '$attendCount/$totalCount人';
      }
      return _ScheduleCardData(
        kind: kind,
        location: location,
        name: name,
        subline: className.isNotEmpty ? className : teacher,
        capacity: cap,
        bgColor: colorOverride,
        raw: rawCopy,
      );
    }
    return _ScheduleCardData(
      kind: _CardKind.bigStandard,
      location: location,
      name: name,
      subline: teacher.isEmpty
          ? className
          : (className.isEmpty ? teacher : '$teacher-$className'),
      bgColor: colorOverride,
      raw: rawCopy,
    );
  }

  /// 解析 `#RRGGBB` / `#AARRGGBB` 形式的 hex；非法则返回 null（不覆盖默认主题）。
  Color? _parseHexColor(String hex) {
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  /// 根据 `_weekStart` 拼出 7 天的 header（标签 + MM/DD + 是否今天）。
  List<_DayHeaderData> _buildDayHeaders() {
    final today = DateTime.now();
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = _weekStart.add(Duration(days: i));
          final isToday =
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          return _DayHeaderData(
            weekdayLabel: labels[i],
            dateLabel:
                '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
            today: isToday,
          );
        }(),
    ];
  }

  Future<void> _loadApplies() async {
    final classId = _selectedClassId;
    if (classId == null || classId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _applies = const [];
        _applyError = null;
        _applyLoading = false;
        _pendingApplyCount = 0;
      });
      return;
    }

    setState(() => _applyLoading = true);
    final repo = ref.read(adminRepositoryProvider);

    // 并行：① 全量列表用于渲染；② 仅待审核 + 最小 size，用分页 total 做角标。
    final results = await Future.wait([
      repo.schoolSmallCourseApplyList(current: 1, size: 100, classId: classId),
      repo.schoolSmallCourseApplyList(
        current: 1,
        size: 1,
        classId: classId,
        status: 0,
      ),
    ]);

    if (!mounted) return;

    final listResp = results[0];
    final pendingResp = results[1];

    if (!listResp.isSuccess) {
      setState(() {
        _applyError =
            listResp.msg.isEmpty ? '加载小班课申请失败' : listResp.msg;
        _applies = const [];
        _applyLoading = false;
        _pendingApplyCount = 0;
      });
      return;
    }

    final rows = _extractList(listResp);
    final parsed = <_ApplyRecord>[];
    for (final m in rows) {
      // 把当前字典快照传进去做 ID → 名称反查；字典还没就绪也 OK，
      // _ApplyRecord.fromJson 会让对应字段回落到「—」。
      final r = _ApplyRecord.fromJson(
        m,
        classNameById: _classNameById,
        classroomNameById: _classroomNameById,
        subjectNameById: _subjectNameById,
        teacherNameById: _teacherNameById,
      );
      if (r.id.isNotEmpty) parsed.add(r);
    }

    var pendingTotal = 0;
    if (pendingResp.isSuccess) {
      pendingTotal =
          _extractPageTotal(pendingResp) ??
          parsed.where((r) => r.status == _ApplyStatus.pending).length;
    } else {
      pendingTotal =
          parsed.where((r) => r.status == _ApplyStatus.pending).length;
    }

    setState(() {
      _applies = parsed;
      _applyError = null;
      _applyLoading = false;
      _pendingApplyCount = pendingTotal;
    });
  }

  /// 打开详情弹窗：调 `schoolSmallCourseApplyDetail` 后展示。
  Future<void> _openApplyDetail(_ApplyRecord preview) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplyDetail(preview.id);
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.msg.isEmpty ? '加载详情失败' : resp.msg,
      );
      return;
    }
    final raw = resp.data;
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is Map) {
      map = raw.cast<String, dynamic>();
    }
    if (map != null &&
        map['data'] is Map &&
        _pickString(map, ['id'], '').isEmpty) {
      map = Map<String, dynamic>.from(map['data'] as Map);
    }
    final record = map != null
        ? _ApplyRecord.fromJson(
            map,
            classNameById: _classNameById,
            classroomNameById: _classroomNameById,
            subjectNameById: _subjectNameById,
            teacherNameById: _teacherNameById,
          )
        : preview;

    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) {
        return DashboardScaleScope(
          data: scaleData,
          child: Builder(
            builder: (ctx) {
              final ui = DashboardScaleScope.of(ctx).ui;
              return GradientHeaderDialog(
                title: '申请详情',
                titleFontSize: 22,
                titleFontWeight: FontWeight.w500,
                titlePaddingTop: 36,
                width: 428,
                contentPadding: EdgeInsets.fromLTRB(
                  ui(40),
                  ui(28),
                  ui(40),
                  ui(28),
                ),
                actionBar: null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.title,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: ui(8)),
                    Text(
                      record.subline.isEmpty ? '—' : record.subline,
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: ui(20)),
                    _ApplyDetailRow(
                      label: '日期',
                      value: record.dateLabel,
                      ui: ui,
                    ),
                    SizedBox(height: ui(12)),
                    _ApplyDetailRow(
                      label: '节次',
                      value: record.lineLabel,
                      ui: ui,
                    ),
                    SizedBox(height: ui(12)),
                    _ApplyDetailRow(
                      label: '备注',
                      value: record.note,
                      ui: ui,
                    ),
                    SizedBox(height: ui(24)),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(ui(12)),
                      child: Container(
                        width: double.infinity,
                        height: ui(45),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: <Color>[
                              Color(0xFFB68EFF),
                              Color(0xFF8640FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(ui(12)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x59AD80FF),
                              blurRadius: ui(20),
                              offset: Offset(0, ui(16)),
                            ),
                          ],
                        ),
                        child: Text(
                          '关闭',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ui(16),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 12 / 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _approve(_ApplyRecord record) async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplyAudit(
      id: record.id,
      pass: true,
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isEmpty ? '审核失败' : resp.msg);
      return;
    }
    AppToast.show(context, '已通过 ${record.title}');
    await _loadApplies();
  }

  Future<void> _reject(_ApplyRecord record) async {
    final reason = await _showRejectDialog(context, record: record);
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplyAudit(
      id: record.id,
      pass: false,
      reason: reason.trim(),
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isEmpty ? '驳回失败' : resp.msg);
      return;
    }
    AppToast.show(context, '已驳回 ${record.title}');
    await _loadApplies();
  }

  // —— Build ————————————————————————————————————————————————
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(20)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminScheduleHeader(
              onBack: widget.onBack,
              tab: _tab,
              applyPendingCount: _pendingApplyCount,
              onTabChanged: (t) {
                setState(() => _tab = t);
                if (t == _AdminScheduleTab.applyAudit) {
                  _loadApplies();
                }
              },
            ),
            if (_tab == _AdminScheduleTab.schedule)
              _buildScheduleTab(ui)
            else
              _buildApplyTab(ui),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab(double Function(num) ui) {
    final cells = _serverCells ?? _emptyCells();
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(12)),
          child: Row(
            children: [
              _ClassDropdownPill(
                label: _selectedClassName,
                onTap: () async {
                  final picked = await _pickClass(context);
                  if (picked == null || !mounted) return;
                  setState(() {
                    _selectedClassId = picked.id;
                    _selectedClassName = picked.name;
                  });
                  // 班级一变：先按新班重拉左侧时间表（节次可能不同），
                  // 再按新 configs 拉课表，保证 lineNum 落格正确。
                  await _loadTimeConfig();
                  if (!mounted) return;
                  _loadSchedule();
                  await _loadApplies();
                },
              ),
              const Spacer(),
              _ViewEditSegment(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(12)),
          child: _ScheduleControlBar(
            week: _currentWeek,
            weekDateLabel: _fmtDate(_weekStart),
            onPrev: _gotoPrev,
            onCurrent: _gotoCurrent,
            onNext: _gotoNext,
            onPickDate: _pickDate,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(20)),
          child: Stack(
            children: [
              _ScheduleGrid(
                mode: _mode,
                slots: slots,
                days: days,
                cells: cells,
                onApplySmallLesson: _onApplySmallLesson,
                onDropCard: _onDropCard,
              ),
              if (_scheduleLoading)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(ui(12)),
                      ),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(color: _kPurple),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplyTab(double Function(num) ui) {
    final list = _applies ?? const <_ApplyRecord>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: ui(12)),
            child: Text(
              '小课排班申请',
              style: TextStyle(
                fontSize: ui(18),
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          if (_applyLoading && list.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: ui(40)),
              child: const Center(
                child: CircularProgressIndicator(color: _kPurple),
              ),
            )
          else if (list.isEmpty)
            _ApplyEmptyState(message: _applyError ?? '暂无小课排班申请')
          else
            _ApplyGrid(
              records: list,
              onApprove: _approve,
              onReject: _reject,
              onOpenDetail: _openApplyDetail,
            ),
        ],
      ),
    );
  }

  /// 班级选择器：来自 `classList` 的真实班级。返回 (id, name) 元组；
  /// 点取消或列表为空都返回 null。`classId` 必填，所以这里不再提供
  /// "全校统一课表" 的伪选项。
  Future<({String id, String name})?> _pickClass(BuildContext context) async {
    if (_classes.isEmpty) return null;
    return showScaledDialog<({String id, String name})>(
      context: context,
      builder: (dialogContext) {
        final ui = DashboardScaleScope.of(dialogContext).ui;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: ui(32),
            vertical: ui(24),
          ),
          child: Container(
            width: ui(360),
            constraints: BoxConstraints(maxHeight: ui(420)),
            padding: EdgeInsets.all(ui(8)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(16)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in _classes)
                    InkWell(
                      onTap: () => Navigator.of(
                        dialogContext,
                      ).pop((id: c.id, name: c.name)),
                      borderRadius: BorderRadius.circular(ui(8)),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(16),
                          vertical: ui(14),
                        ),
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: ui(14),
                            color: c.id == _selectedClassId
                                ? _kPurple
                                : _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: c.id == _selectedClassId
                                ? AppFont.w600
                                : AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 顶部 banner：返回 + 居中标题 + 右上 tab 分段
// =============================================================================

class _AdminScheduleHeader extends StatelessWidget {
  const _AdminScheduleHeader({
    required this.onBack,
    required this.tab,
    required this.onTabChanged,
    required this.applyPendingCount,
  });

  final VoidCallback onBack;
  final _AdminScheduleTab tab;
  final ValueChanged<_AdminScheduleTab> onTabChanged;

  /// 当前班级下待审核申请数；≤0 时不显示角标。
  final int applyPendingCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(68),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(16)),
          topRight: Radius.circular(ui(16)),
        ),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(20),
            top: ui(20),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '排课与课表',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: ui(20),
            top: ui(16),
            child: _AdminTabSegment(
              tab: tab,
              applyPendingCount: applyPendingCount,
              onChanged: onTabChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTabSegment extends StatelessWidget {
  const _AdminTabSegment({
    required this.tab,
    required this.onChanged,
    required this.applyPendingCount,
  });

  final _AdminScheduleTab tab;
  final ValueChanged<_AdminScheduleTab> onChanged;
  final int applyPendingCount;

  String? get _applyBadgeText {
    if (applyPendingCount <= 0) return null;
    if (applyPendingCount >= 10) return '10+';
    return '$applyPendingCount';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 不写死高度，让中文 line-height 1.2 自然撑开，避免 chip 文字被夹紧 / 裁切。
    return Container(
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdminTabChip(
            label: '周课表与排课',
            active: tab == _AdminScheduleTab.schedule,
            onTap: () => onChanged(_AdminScheduleTab.schedule),
          ),
          SizedBox(width: ui(4)),
          _AdminTabChip(
            label: '小课申请审核',
            active: tab == _AdminScheduleTab.applyAudit,
            badge: _applyBadgeText,
            onTap: () => onChanged(_AdminScheduleTab.applyAudit),
          ),
        ],
      ),
    );
  }
}

class _AdminTabChip extends StatelessWidget {
  const _AdminTabChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(7)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: ui(14),
                color: active ? Colors.white : _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
            if (badge != null) ...[
              SizedBox(width: ui(6)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(5),
                  vertical: ui(1),
                ),
                decoration: BoxDecoration(
                  color: _kRedBadge,
                  borderRadius: BorderRadius.circular(ui(20)),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: ui(10),
                    color: Colors.white,
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// tab 1 - 子 header：班级 dropdown + 查看/编辑
// =============================================================================

class _ClassDropdownPill extends StatelessWidget {
  const _ClassDropdownPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 12,
              ),
            ),
            SizedBox(width: ui(6)),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: ui(16),
              color: _kTextDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewEditSegment extends StatelessWidget {
  const _ViewEditSegment({required this.mode, required this.onChanged});

  final _ScheduleMode mode;
  final ValueChanged<_ScheduleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(32),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegChip(
            label: '查看',
            active: mode == _ScheduleMode.view,
            onTap: () => onChanged(_ScheduleMode.view),
          ),
          _SegChip(
            label: '编辑',
            active: mode == _ScheduleMode.edit,
            onTap: () => onChanged(_ScheduleMode.edit),
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(4)),
        decoration: BoxDecoration(
          color: active ? _kPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: active ? Colors.white : _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: active ? AppFont.w500 : AppFont.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 控制条：教学周 + legend + 周切换 + 当周日期
// =============================================================================

class _ScheduleControlBar extends StatelessWidget {
  const _ScheduleControlBar({
    required this.week,
    required this.weekDateLabel,
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
    required this.onPickDate,
  });

  final int week;
  final String weekDateLabel;
  final VoidCallback onPrev;
  final VoidCallback onCurrent;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1,
                    ),
                    children: [
                      const TextSpan(text: '教学周第 '),
                      TextSpan(
                        text: '$week',
                        style: const TextStyle(color: _kPurple),
                      ),
                      const TextSpan(text: ' 周'),
                    ],
                  ),
                ),
                SizedBox(height: ui(8)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LegendItem(
                      dotColor: _kStatusPurple,
                      label: '大课',
                      tail: '编辑模式下可编辑',
                    ),
                    SizedBox(width: ui(16)),
                    const _LegendItem(
                      dotColor: _kStatusGreen,
                      label: '小课',
                      tail: '待任课老师发起请求',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _WeekSwitcher(onPrev: onPrev, onCurrent: onCurrent, onNext: onNext),
          SizedBox(width: ui(8)),
          _ControlPill(
            onTap: onPickDate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekDateLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
                SizedBox(width: ui(8)),
                Icon(
                  Icons.calendar_today_rounded,
                  size: ui(14),
                  color: const Color(0xFF1C274C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.dotColor,
    required this.label,
    required this.tail,
  });

  final Color dotColor;
  final String label;
  final String tail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ui(6),
                height: ui(6),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ui(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          tail,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
        ),
      ],
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: child,
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
  });

  final VoidCallback onPrev;
  final VoidCallback onCurrent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.all(ui(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChevronButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
          SizedBox(width: ui(12)),
          InkWell(
            onTap: onCurrent,
            borderRadius: BorderRadius.circular(ui(4)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(2)),
              child: Text(
                '本周',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          _ChevronButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Icon(icon, size: ui(18), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

// =============================================================================
// 网格主体：时间列（左，冻结）+ 日期区（右，横滚动）
// =============================================================================

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.mode,
    required this.slots,
    required this.days,
    required this.cells,
    required this.onApplySmallLesson,
    required this.onDropCard,
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

  /// 长按拖动到目标格子时回调（仅编辑模式 + 大课）。
  final Future<void> Function(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  )
  onDropCard;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final totalHeight =
        ui(_kHeaderHeight) + slots.fold<double>(0, (s, e) => s + ui(e.height));
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimeColumn(slots: slots),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: ui(_kDayColWidth) * days.length,
                        child: _DaysArea(
                          mode: mode,
                          slots: slots,
                          days: days,
                          cells: cells,
                          onApplySmallLesson: onApplySmallLesson,
                          onDropCard: onDropCard,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(12)),
                  border: Border.all(color: _kBorderSoft),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.slots});

  final List<_TimeSlotData> slots;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(_kTimeColWidth),
      child: Column(
        children: [
          const _TimeHeader(),
          for (final slot in slots)
            Container(
              width: double.infinity,
              height: ui(slot.height),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: _kBorderSoft),
                  bottom: BorderSide(color: _kBorderSoft),
                ),
              ),
              alignment: Alignment.center,
              child: _TimeRange(start: slot.start, end: slot.end),
            ),
        ],
      ),
    );
  }
}

class _TimeHeader extends StatelessWidget {
  const _TimeHeader();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(_kHeaderHeight),
      decoration: const BoxDecoration(
        color: _kInnerGray,
        border: Border(
          right: BorderSide(color: _kBorderSoft),
          bottom: BorderSide(color: _kBorderSoft),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiagonalLinePainter())),
          Positioned(
            right: ui(20),
            top: ui(10),
            child: Text(
              '日期',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(20),
            bottom: ui(12),
            child: Text(
              '节次',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kBorderSoft
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_DiagonalLinePainter oldDelegate) => false;
}

class _TimeRange extends StatelessWidget {
  const _TimeRange({required this.start, required this.end});

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          start,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 16 / 14,
          ),
        ),
        SizedBox(height: ui(8)),
        Container(width: ui(12), height: 1, color: _kTextDivider),
        SizedBox(height: ui(8)),
        Text(
          end,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 16 / 14,
          ),
        ),
      ],
    );
  }
}

class _DaysArea extends StatelessWidget {
  const _DaysArea({
    required this.mode,
    required this.slots,
    required this.days,
    required this.cells,
    required this.onApplySmallLesson,
    required this.onDropCard,
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;
  final Future<void> Function(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  )
  onDropCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DaysHeaderRow(days: days),
        for (var slotIdx = 0; slotIdx < slots.length; slotIdx++)
          _DayBodyRow(
            slotIdx: slotIdx,
            height: slots[slotIdx].height,
            mode: mode,
            rowCells: [
              for (var dayIdx = 0; dayIdx < days.length; dayIdx++)
                cells[dayIdx][slotIdx],
            ],
            onApplySmallLesson: onApplySmallLesson,
            onDropCard: onDropCard,
          ),
      ],
    );
  }
}

class _DaysHeaderRow extends StatelessWidget {
  const _DaysHeaderRow({required this.days});

  final List<_DayHeaderData> days;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(_kHeaderHeight),
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++)
            Container(
              width: ui(_kDayColWidth),
              height: ui(_kHeaderHeight),
              decoration: BoxDecoration(
                color: days[i].today ? Colors.white : _kInnerGray,
                border: Border(
                  bottom: const BorderSide(color: _kBorderSoft),
                  left: i == 0
                      ? BorderSide.none
                      : const BorderSide(color: _kBorderSoft),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    days[i].weekdayLabel,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    days[i].dateLabel,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayBodyRow extends StatelessWidget {
  const _DayBodyRow({
    required this.slotIdx,
    required this.height,
    required this.mode,
    required this.rowCells,
    required this.onApplySmallLesson,
    required this.onDropCard,
  });

  final int slotIdx;
  final double height;
  final _ScheduleMode mode;
  final List<List<_ScheduleCardData>> rowCells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;
  final Future<void> Function(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  )
  onDropCard;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(height),
      child: Row(
        children: [
          for (var i = 0; i < rowCells.length; i++)
            SizedBox(
              width: ui(_kDayColWidth),
              height: ui(height),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _CellContent(
                      dayIdx: i,
                      slotIdx: slotIdx,
                      slotHeight: height,
                      mode: mode,
                      cards: rowCells[i],
                      onApplySmallLesson: () => onApplySmallLesson(i, slotIdx),
                      onDropCard: onDropCard,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(height: 1, color: _kBorderSoft),
                    ),
                  ),
                  if (i != 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(width: 1, color: _kBorderSoft),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CellContent extends StatelessWidget {
  const _CellContent({
    required this.dayIdx,
    required this.slotIdx,
    required this.slotHeight,
    required this.mode,
    required this.cards,
    required this.onApplySmallLesson,
    required this.onDropCard,
  });

  final int dayIdx;
  final int slotIdx;
  final double slotHeight;
  final _ScheduleMode mode;
  final List<_ScheduleCardData> cards;
  final VoidCallback onApplySmallLesson;
  final Future<void> Function(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  )
  onDropCard;

  bool get _hasSmallCard => cards.any(
    (c) => c.kind == _CardKind.smallOrange || c.kind == _CardKind.smallBlue,
  );

  @override
  Widget build(BuildContext context) {
    final isEditing = mode == _ScheduleMode.edit;
    // 编辑模式下整个格子都做拖动落点；查看模式不接收拖动。
    if (!isEditing) {
      return _buildBody(context, hovering: false);
    }
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        // 拖回原格不算移动；返回 false 让悬停高亮也不亮起。
        final p = details.data;
        return !(p.sourceDay == dayIdx && p.sourceSlot == slotIdx);
      },
      onAcceptWithDetails: (details) {
        onDropCard(details.data, dayIdx, slotIdx);
      },
      builder: (ctx, candidate, rejected) {
        return _buildBody(ctx, hovering: candidate.isNotEmpty);
      },
    );
  }

  Widget _buildBody(BuildContext context, {required bool hovering}) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEditing = mode == _ScheduleMode.edit;
    final radius = ui(8);
    Widget wrapHover(Widget child) {
      if (!hovering) return child;
      // 拖动悬停时给整个格子叠一层紫色虚框 + 高亮底，提示可放置。
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(8),
                ),
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: _kPurple, width: 1.4),
                ),
              ),
            ),
          ),
          child,
        ],
      );
    }

    if (cards.isEmpty) {
      // 查看模式下所有空格都显示「空闲」占位；编辑模式下显示「申请小课」按钮。
      return wrapHover(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
          child: isEditing
              ? _ApplySmallLessonButton(onTap: onApplySmallLesson)
              : const _IdleSlotPlaceholder(),
        ),
      );
    }
    final shouldAppendApply =
        isEditing && slotIdx == 0 && _hasSmallCard && slotHeight >= 168;
    return wrapHover(
      Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(height: ui(6)),
              _DraggableScheduleCard(
                card: cards[i],
                isEditing: isEditing,
                sourceDay: dayIdx,
                sourceSlot: slotIdx,
                indexInSlot: i,
              ),
            ],
            if (shouldAppendApply) ...[
              SizedBox(height: ui(8)),
              _ApplySmallLessonButton(onTap: onApplySmallLesson),
            ],
          ],
        ),
      ),
    );
  }
}

bool _isSmallKind(_CardKind k) =>
    k == _CardKind.smallOrange || k == _CardKind.smallBlue;

/// 编辑模式下，大课卡 = `LongPressDraggable`；小课 / 查看模式 = 静态 [_ClassCard]。
///
/// 小课在 admin 端「待任课老师发起请求」，所以始终不可拖动。
class _DraggableScheduleCard extends StatelessWidget {
  const _DraggableScheduleCard({
    required this.card,
    required this.isEditing,
    required this.sourceDay,
    required this.sourceSlot,
    required this.indexInSlot,
  });

  final _ScheduleCardData card;
  final bool isEditing;
  final int sourceDay;
  final int sourceSlot;
  final int indexInSlot;

  bool get _draggable {
    if (!isEditing) return false;
    if (card.raw == null) return false;
    return !_isSmallKind(card.kind);
  }

  @override
  Widget build(BuildContext context) {
    final base = _ClassCard(data: card, editable: _draggable);
    if (!_draggable) return base;
    final payload = _DragPayload(
      sourceDay: sourceDay,
      sourceSlot: sourceSlot,
      indexInSlot: indexInSlot,
      card: card,
    );
    // LongPressDraggable.feedback 会被渲染到全局 Overlay，脱离当前 widget 树，
    // 必须把 DashboardScaleScope 数据捕获后重新注入，否则内部用 `ui()` 缩放
    // 的子组件会 assert "DashboardScaleScope not found"。
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    return LongPressDraggable<_DragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 220),
      hapticFeedbackOnStart: true,
      feedback: DashboardScaleScope(
        data: scaleData,
        child: _DragFeedback(card: card),
      ),
      childWhenDragging: Opacity(opacity: 0.32, child: base),
      child: base,
    );
  }
}

/// 长按拖动跟随手指的浮起卡。`Material` 透明背景仅用来给文字提供 ancestry。
/// 外层必须由调用方再裹一层 [DashboardScaleScope]（feedback 走 Overlay
/// 树，会丢失原祖先环境）。
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.card});

  final _ScheduleCardData card;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _ClassCard(data: card, editable: true),
      ),
    );
  }
}

class _IdleSlotPlaceholder extends StatelessWidget {
  const _IdleSlotPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kTextDivider, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        '空闲',
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 16 / 14,
        ),
      ),
    );
  }
}

class _ApplySmallLessonButton extends StatelessWidget {
  const _ApplySmallLessonButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: double.infinity,
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ui(14),
              height: ui(14),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _kTextHint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: ui(10), color: Colors.white),
            ),
            SizedBox(width: ui(6)),
            Text(
              '编辑大课',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 课卡（4 主题）
// =============================================================================

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.data, required this.editable});

  final _ScheduleCardData data;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final theme = _themeFor(data);
    final cardHeight = data.kind == _CardKind.bigExtended ? 120.0 : 96.0;
    return MouseRegion(
      cursor: editable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Container(
        width: ui(176),
        height: ui(cardHeight),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: ui(16),
              top: ui(8),
              child: SizedBox(
                width: ui(108),
                child: Text(
                  data.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: theme.titleColor,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 16 / 12,
                  ),
                ),
              ),
            ),
            if (data.kind != _CardKind.bigExtended)
              Positioned(
                left: ui(126),
                top: ui(6),
                child: _ClassKindTag(isSmall: theme.isSmall, outlined: false),
              ),
            Positioned(
              left: ui(4),
              top: ui(32),
              child: Container(
                width: ui(168),
                height: ui(data.kind == _CardKind.bigExtended ? 84 : 60),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
              ),
            ),
            Positioned(
              left: ui(16),
              top: ui(44),
              child: SizedBox(
                width: ui(140),
                child: Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 16 / 14,
                  ),
                ),
              ),
            ),
            if (data.kind == _CardKind.bigExtended) ...[
              Positioned(
                left: ui(16),
                top: ui(64),
                child: Text(
                  data.subline,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 16 / 12,
                  ),
                ),
              ),
              Positioned(
                left: ui(16),
                top: ui(86),
                child: _ClassKindTag(isSmall: false, outlined: true),
              ),
            ] else ...[
              Positioned(
                left: ui(16),
                top: ui(64),
                child: SizedBox(
                  width: ui(theme.isSmall && data.capacity != null ? 100 : 140),
                  child: Text(
                    data.subline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ),
              if (theme.isSmall && data.capacity != null)
                Positioned(
                  right: ui(16),
                  top: ui(64),
                  child: Text(
                    data.capacity!,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDivider,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  _CardTheme _themeFor(_ScheduleCardData data) {
    // API 给了 color 时优先用它做背景；标题色根据 kind 选语义色（小课橙/蓝、
    // 大课紫），保证在浅色背景上仍有合适的对比度。
    switch (data.kind) {
      case _CardKind.smallOrange:
        return _CardTheme(
          bg: data.bgColor ?? _kSmallOrangeBg,
          titleColor: _kSmallOrangeTitle,
          isSmall: true,
        );
      case _CardKind.smallBlue:
        return _CardTheme(
          bg: data.bgColor ?? _kSmallBlueBg,
          titleColor: _kSmallBlueTitle,
          isSmall: true,
        );
      case _CardKind.bigStandard:
        return _CardTheme(
          bg: data.bgColor ?? _kBigStandardBg,
          titleColor: _kBigTitle,
          isSmall: false,
        );
      case _CardKind.bigExtended:
        return _CardTheme(
          bg: data.bgColor ?? _kBigExtendedBg,
          titleColor: _kBigTitle,
          isSmall: false,
        );
    }
  }
}

class _ClassKindTag extends StatelessWidget {
  const _ClassKindTag({required this.isSmall, required this.outlined});

  final bool isSmall;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final dotColor = isSmall ? _kStatusGreen : _kStatusPurple;
    final label = isSmall ? '小课' : '大课';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: outlined ? Border.all(color: _kBorderSoft, width: 1.4) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 15.24 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTheme {
  const _CardTheme({
    required this.bg,
    required this.titleColor,
    required this.isSmall,
  });

  final Color bg;
  final Color titleColor;
  final bool isSmall;
}

// =============================================================================
// 数据模型 - 课表
// =============================================================================

enum _CardKind { smallOrange, smallBlue, bigStandard, bigExtended }

class _ScheduleCardData {
  const _ScheduleCardData({
    required this.kind,
    required this.location,
    required this.name,
    required this.subline,
    this.capacity,
    this.bgColor,
    this.raw,
  });

  final _CardKind kind;
  final String location;
  final String name;
  final String subline;
  final String? capacity;

  /// API `color` 字段（hex 解析后）覆盖默认主题底色；为空则按 [kind] 走
  /// 4 套预设主题。
  final Color? bgColor;

  /// `courseList` 单条原始记录。拖动改课时的「删旧课 + 写新课」需要用
  /// 这里的 `id / classId / teacherId / classroomId / subjectId / color` 等字段
  /// 重新拼请求体；DEMO 占位数据可以为 null。
  final Map<String, dynamic>? raw;
}

/// 课表拖拽时随手携带的数据。`sourceDay/sourceSlot/indexInSlot` 用于在
/// 乐观更新里精确把卡片从旧格子里挪走。
class _DragPayload {
  const _DragPayload({
    required this.sourceDay,
    required this.sourceSlot,
    required this.indexInSlot,
    required this.card,
  });

  final int sourceDay;
  final int sourceSlot;
  final int indexInSlot;
  final _ScheduleCardData card;
}

class _TimeSlotData {
  const _TimeSlotData({
    required this.start,
    required this.end,
    required this.height,
  });

  final String start;
  final String end;
  final double height;
}

class _DayHeaderData {
  const _DayHeaderData({
    required this.weekdayLabel,
    required this.dateLabel,
    this.today = false,
  });

  final String weekdayLabel;
  final String dateLabel;
  final bool today;
}

/// 课表左侧时间配置：API `schoolTimeConfigList` 返回结构 → `_TimeConfig`。
class _TimeConfig {
  const _TimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

/// API 拉取失败 / 未返回时的兜底节次配置（5 节）。
const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  _TimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  _TimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  _TimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  _TimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

// =============================================================================
// 排课编辑右侧抽屉（管理员）：课程时间只读 + 班级 / 教室 / 颜色 / 复用，
// 提交时调 `courseBatchSave`。
// =============================================================================

class _AdminEditCourseDrawer extends ConsumerStatefulWidget {
  const _AdminEditCourseDrawer({
    required this.slotLabel,
    required this.dateIso,
    required this.lineNum,
    required this.currentWeek,
    required this.onCancel,
    required this.onSubmitted,
    this.initialClassId,
  });

  final String slotLabel;
  final String dateIso;
  final int lineNum;

  /// 父页面当前显示的"教学周第 N 周"。复用为「本学期所有教学周」时，
  /// 用它计算还剩多少周（按 [_kTermTotalWeeks] 总周数兜底 18 周）。
  final int currentWeek;

  final VoidCallback onCancel;
  final VoidCallback onSubmitted;

  /// 父页面正在浏览的班级 id；非空时打开抽屉时直接预选此班级。
  final String? initialClassId;

  @override
  ConsumerState<_AdminEditCourseDrawer> createState() =>
      _AdminEditCourseDrawerState();
}

/// 本学期总教学周数（按教育部典型约定 18 周）。"本学期所有教学周" 复用
/// 模式下从当前 `currentWeek` 起补到第 [_kTermTotalWeeks] 周。
const int _kTermTotalWeeks = 18;

class _AdminEditCourseDrawerState
    extends ConsumerState<_AdminEditCourseDrawer> {
  // 班级 / 教室 / 教师 / 科目下拉的 cache：(label, id)。下拉用 label 做用户
  // 选择，提交时拿对应 id（雪花 long → String）拼到 courseBatchSave 的 body。
  List<({String id, String name})> _classes = const [];
  List<({String id, String name})> _classrooms = const [];
  List<({String id, String name})> _teachers = const [];
  List<({String id, String name})> _subjects = const [];

  String? _classId;
  String? _classroomId;
  String? _teacherId;

  /// 科目下拉当前选中（来自 `subjectList`）。`subjectId` 在 API 里是 int，
  /// 这里以 String 形式管理，提交时再 `int.tryParse` 转回。
  String? _subjectId;
  bool _loadingSubjects = false;

  // 颜色：支持色板（_palette[1] 默认）+ 自定义"取色"模式（仍使用调色板里的
  // 当前色，不再单独调出 native picker，与 teacher 端一致）。
  static const List<Color> _palette = <Color>[
    Color(0xFF1E1E1E),
    Color(0xFFE6D0FF),
    Color(0xFFD0E6FE),
    Color(0xFFFFEDD3),
    Color(0xFFD5CEC5),
    Color(0xFFD2C4FF),
    Color(0xFFADBFFF),
    Color(0xFFAAEBDD),
    Color(0xFFB1FFCE),
    Color(0xFFA894EB),
    Color(0xFF5EA9FF),
    Color(0xFF40E9A6),
    Color(0xFF74F0FE),
  ];

  Color _color = _palette[1];
  bool _customMode = false;
  String _reuse = '不复用';
  bool _submitting = false;

  static const List<String> _reuseOptions = <String>[
    '不复用',
    '本学期所有教学周',
    '后续 4 周',
    '后续 8 周',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOptions();
    });
  }

  Future<void> _loadOptions() async {
    final repo = ref.read(adminRepositoryProvider);
    // 编辑大课 → 班级下拉只展示大班（type=0），过滤掉小班，避免管理员误把
    // 大课排进小班；小班的课表走「小课申请审核」走另一套流程。
    final results = await Future.wait([
      repo.classList(type: 0),
      repo.classroomList(),
      repo.teacherList(),
    ]);
    if (!mounted) return;
    setState(() {
      _classes = _toOptions(
        results[0],
        idKeys: const ['id', 'classId', 'cId'],
        nameKeys: const ['className', 'class', 'name', 'fullName'],
      );
      _classrooms = _toOptions(
        results[1],
        idKeys: const ['id', 'classroomId', 'roomId'],
        nameKeys: const ['classroomName', 'roomName', 'name'],
      );
      _teachers = _toOptions(
        results[2],
        idKeys: const ['id', 'teacherId', 'userId'],
        nameKeys: const ['realname', 'realName', 'nickname', 'name'],
      );
      // 父页面已选班级时优先回填；否则取列表第 1 项。
      final initial = widget.initialClassId;
      if (initial != null &&
          initial.isNotEmpty &&
          _classes.any((c) => c.id == initial)) {
        _classId = initial;
      } else {
        _classId ??= _classes.isNotEmpty ? _classes.first.id : null;
      }
      _classroomId ??= _classrooms.isNotEmpty ? _classrooms.first.id : null;
      _teacherId ??= _teachers.isNotEmpty ? _teachers.first.id : null;
    });
    // 班级 id 就绪后立刻拉对应班级的可选科目。
    _loadSubjects(_classId);
  }

  /// 班级科目下拉拉取：subjectList 接口需要 classId（雪花 String）。
  /// 班级一变就重拉；选中项不在新列表里时回退到第一项。
  Future<void> _loadSubjects(String? classId) async {
    setState(() => _loadingSubjects = true);
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.subjectList(classId: classId);
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _subjects = const [];
        _subjectId = null;
        _loadingSubjects = false;
      });
      return;
    }
    final list = _toOptions(
      resp,
      idKeys: const ['id', 'subjectId'],
      nameKeys: const ['name', 'subjectName'],
    );
    setState(() {
      _subjects = list;
      if (_subjectId == null || !list.any((s) => s.id == _subjectId)) {
        _subjectId = list.isNotEmpty ? list.first.id : null;
      }
      _loadingSubjects = false;
    });
  }

  List<({String id, String name})> _toOptions(
    ApiResponse resp, {
    required List<String> idKeys,
    required List<String> nameKeys,
  }) {
    if (!resp.isSuccess) return const [];
    final rows = _extractList(resp);
    return [
      for (final m in rows)
        if (_pickString(m, idKeys, '').isNotEmpty &&
            _pickString(m, nameKeys, '').isNotEmpty)
          (id: _pickString(m, idKeys, ''), name: _pickString(m, nameKeys, '')),
    ];
  }

  String get _hexLabel {
    final argb = _color.toARGB32();
    final rgb = argb & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_classId == null || _classroomId == null || _teacherId == null) {
      AppToast.show(context, '请先选择班级 / 教室 / 教师');
      return;
    }
    if (_subjectId == null || _subjectId!.isEmpty) {
      AppToast.show(context, '请先选择科目');
      return;
    }
    setState(() => _submitting = true);

    // 后端要求 classroomId / subjectId 是 int；雪花长 classId / teacherId
    // 走 String。复用模式下按 [_reuse] 选项把基准日期 ±N 周生成多行同节次
    // 同班级的排课，一次性提交给 courseBatchSave。
    final classroomNum = int.tryParse(_classroomId!);
    final subjectNum = int.tryParse(_subjectId!);
    final dates = _computeReuseDates();
    final rows = <Map<String, dynamic>>[
      for (final d in dates)
        <String, dynamic>{
          'classId': _classId,
          'classroomId': classroomNum ?? _classroomId,
          'color': _hexLabel,
          'date': _formatIsoDate(d),
          'lineNum': widget.lineNum,
          'subjectId': subjectNum ?? _subjectId,
          'teacherId': _teacherId,
        },
    ];

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.courseBatchSave(rows);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isEmpty ? '提交失败' : resp.msg);
      return;
    }
    if (rows.length > 1) {
      AppToast.show(context, '已写入课表（共 ${rows.length} 周）');
    }
    widget.onSubmitted();
  }

  /// 根据 `_reuse` 选项展开成多个排课日期：
  ///   - 不复用 → 仅基准日 1 行
  ///   - 本学期所有教学周 → 从当前周开始补到第 [_kTermTotalWeeks] 周
  ///   - 后续 4 周 → 基准日 + 4 个连续周（共 5 行）
  ///   - 后续 8 周 → 基准日 + 8 个连续周（共 9 行）
  /// 每个克隆都是基准日 +N×7 天，节次 / 班级 / 教师 / 教室 / 颜色 / 科目
  /// 完全复用。
  List<DateTime> _computeReuseDates() {
    final base = DateTime.tryParse(widget.dateIso) ?? DateTime.now();
    int extraWeeks;
    switch (_reuse) {
      case '本学期所有教学周':
        extraWeeks = (_kTermTotalWeeks - widget.currentWeek).clamp(
          0,
          _kTermTotalWeeks,
        );
        break;
      case '后续 4 周':
        extraWeeks = 4;
        break;
      case '后续 8 周':
        extraWeeks = 8;
        break;
      case '不复用':
      default:
        extraWeeks = 0;
    }
    return [
      for (var i = 0; i <= extraWeeks; i++) base.add(Duration(days: i * 7)),
    ];
  }

  /// `2026-05-04T00:00:00.000+00:00` 格式（与 `widget.dateIso` 一致），后端
  /// `courseBatchSave` 直接吃这个串。
  String _formatIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(600),
      height: double.infinity,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            _DrawerHeader(title: '编辑大课', onClose: widget.onCancel),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ui(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(
                      icon: Icons.access_time_rounded,
                      label: '课程时间',
                    ),
                    SizedBox(height: ui(12)),
                    _ReadonlyField(text: widget.slotLabel),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(label: '班级'),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _classId ?? '',
                      items: [for (final c in _classes) c.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择班级';
                        return _classes
                            .firstWhere(
                              (c) => c.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) {
                        setState(() => _classId = v);
                        // 班级一变科目跟着重拉。
                        _loadSubjects(v);
                      },
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.menu_book_outlined,
                      label: '科目',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _subjectId ?? '',
                      items: [for (final s in _subjects) s.id],
                      itemLabel: (id) {
                        if (id.isEmpty) {
                          return _loadingSubjects ? '加载中…' : '选择科目';
                        }
                        return _subjects
                            .firstWhere(
                              (s) => s.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _subjectId = v),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.person_outline_rounded,
                      label: '教师',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _teacherId ?? '',
                      items: [for (final t in _teachers) t.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择教师';
                        return _teachers
                            .firstWhere(
                              (t) => t.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _teacherId = v),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.meeting_room_outlined,
                      label: '教室',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _classroomId ?? '',
                      items: [for (final c in _classrooms) c.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择教室';
                        return _classrooms
                            .firstWhere(
                              (c) => c.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _classroomId = v),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.palette_outlined,
                      label: '颜色',
                    ),
                    SizedBox(height: ui(12)),
                    _ColorSwatchRow(
                      colors: _palette,
                      selected: _customMode ? null : _color,
                      onSelect: (c) => setState(() {
                        _color = c;
                        _customMode = false;
                      }),
                    ),
                    SizedBox(height: ui(12)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ColorModeChip(
                          label: _hexLabel,
                          selected: !_customMode,
                          onTap: () => setState(() => _customMode = false),
                        ),
                        SizedBox(width: ui(12)),
                        _ColorModeChip(
                          label: '取色',
                          selected: _customMode,
                          onTap: () => setState(() => _customMode = true),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.copy_outlined,
                      label: '是否复用',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _reuse,
                      items: _reuseOptions,
                      itemLabel: (s) => s,
                      onChanged: (v) => setState(() => _reuse = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
              child: _SubmitGradientButton(
                label: _submitting ? '提交中…' : '提交保存',
                onTap: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(3.25),
            height: ui(15),
            decoration: BoxDecoration(
              color: _kPurple,
              borderRadius: BorderRadius.circular(ui(6)),
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
              height: 1.2,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Padding(
              padding: EdgeInsets.all(ui(8)),
              child: Icon(
                Icons.close_rounded,
                size: ui(18),
                color: _kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ui(16),
          height: ui(16),
          child: icon == null
              ? null
              : Icon(icon, size: ui(16), color: const Color(0xFF1C274C)),
        ),
        SizedBox(width: ui(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextSecondary,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kInnerGray, width: 1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            _ColorSwatch(
              color: colors[i],
              isSelected: selected == colors[i],
              onTap: () => onSelect(colors[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: ui(20),
        height: ui(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.white : color,
          border: Border.all(
            color: isSelected ? color : _kBorderSoft,
            width: 1,
          ),
        ),
        child: isSelected
            ? Container(
                width: ui(14),
                height: ui(14),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              )
            : null,
      ),
    );
  }
}

class _ColorModeChip extends StatelessWidget {
  const _ColorModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(48), vertical: ui(12)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFE5FF) : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
          border: selected ? Border.all(color: _kPurple, width: 1) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(16),
            color: selected ? _kPurple : Colors.black,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _SubmitGradientButton extends StatelessWidget {
  const _SubmitGradientButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: double.infinity,
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(16),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// tab 2 - 小课申请审核：列表卡片 + 通过/驳回 + 驳回弹窗
// =============================================================================

/// 申请详情弹窗里的一行 label / value。
class _ApplyDetailRow extends StatelessWidget {
  const _ApplyDetailRow({
    required this.label,
    required this.value,
    required this.ui,
  });

  final String label;
  final String value;
  final double Function(num) ui;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ui(52),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplyRecord {
  const _ApplyRecord({
    required this.id,
    required this.title,
    required this.teacher,
    required this.location,
    required this.applyTime,
    required this.dateLabel,
    required this.lineLabel,
    required this.note,
    required this.status,
  });

  final String id;
  final String title;
  final String teacher;
  final String location;
  final String applyTime;
  final String dateLabel;
  final String lineLabel;
  final String note;
  final _ApplyStatus status;

  /// 后端响应结构（`schoolSmallCourseApplyList` 实测）：
  /// ```
  /// {
  ///   id, schoolId, classId, teacherId, subjectId, lineNum, color,
  ///   classroomId, status, reason, createTime, auditTime, auditTeacherId,
  ///   startDate, endDate,
  ///   courseData: "[{classId,classroomId,color,date,lineNum,
  ///                  subjectId,teacherId}, ...]"   // JSON 字符串
  /// }
  /// ```
  /// 卡片上要显示的「班级 / 教室 / 教师 / 科目」全是 ID，需要外部字典反查；
  /// 字典还没就绪 / 命中不到时回落到「—」，不会让卡片报错。
  ///
  /// `dateLabel` 不再依赖 `dateLabel` / `date` 等已废弃 key，统一用顶层
  /// `startDate ~ endDate` 拼一个区间。`courseData` 解析出来的「次数」额
  /// 外拼到末尾，方便管理员一眼看到这条申请覆盖了多少节课。
  factory _ApplyRecord.fromJson(
    Map<String, dynamic> json, {
    Map<String, String>? classNameById,
    Map<int, String>? classroomNameById,
    Map<int, String>? subjectNameById,
    Map<String, String>? teacherNameById,
  }) {
    final id = _pickString(json, ['id', 'applyId', 'recordId'], '');

    // —— 名称回查（字典 miss 时统一回落到「—」）——
    final classroomIdRaw = json['classroomId'];
    final classroomId = classroomIdRaw is int
        ? classroomIdRaw
        : int.tryParse(classroomIdRaw?.toString() ?? '');
    final subjectIdRaw = json['subjectId'];
    final subjectId = subjectIdRaw is int
        ? subjectIdRaw
        : int.tryParse(subjectIdRaw?.toString() ?? '');
    final classIdStr = _pickString(json, ['classId'], '');
    final teacherIdStr = _pickString(json, ['teacherId'], '');

    // 标题：优先显示 班级 + 科目，例如「视唱1班 · 视唱」；都拿不到时再
    // 回退到接口可能下发的 subjectName / title 字段，再不行用通用文案。
    final className = classNameById?[classIdStr] ?? '';
    final subjectName = subjectId != null
        ? (subjectNameById?[subjectId] ?? '')
        : '';
    final titleParts = <String>[];
    if (className.isNotEmpty) titleParts.add(className);
    if (subjectName.isNotEmpty) titleParts.add(subjectName);
    final title = titleParts.isNotEmpty
        ? titleParts.join(' · ')
        : _pickString(json, [
            'subjectName',
            'subject',
            'courseName',
            'name',
            'title',
          ], '考前加练小班课');

    final teacher = teacherIdStr.isNotEmpty
        ? (teacherNameById?[teacherIdStr] ??
              _pickString(json, [
                'teacherRealname',
                'teacherName',
                'realname',
                'realName',
                'teacherNickname',
                'teacher',
                'applicantName',
              ], ''))
        : '';

    final classroom = classroomId != null
        ? (classroomNameById?[classroomId] ??
              _pickString(json, [
                'classroomName',
                'roomName',
                'classroom',
              ], ''))
        : '';

    // —— 备注：reason 是后端约定字段，待审核时通常为 null，已驳回 / 通过
    //          才会有内容。空时显示「无」。——
    final note = _pickString(json, [
      'reason',
      'remark',
      'note',
      'description',
    ], '');

    // —— 日期：startDate ~ endDate 区间；若相等只显示一个；若能从
    //         courseData 解出 N (>1) 个具体日期，末尾拼「· 共 N 次」。——
    final startDate = _pickString(json, ['startDate'], '');
    final endDate = _pickString(json, ['endDate'], '');
    String dateLabel;
    if (startDate.isEmpty && endDate.isEmpty) {
      dateLabel = '—';
    } else if (startDate.isEmpty || endDate.isEmpty || startDate == endDate) {
      dateLabel = startDate.isNotEmpty ? startDate : endDate;
    } else {
      dateLabel = '$startDate ~ $endDate';
    }
    final occurrenceCount = _countCourseDataOccurrences(json['courseData']);
    if (occurrenceCount > 1 && dateLabel != '—') {
      dateLabel = '$dateLabel · 共 $occurrenceCount 次';
    }

    // —— 节次：顶层 lineNum 是 int；按 admin 端原有展示规则「第 N 节」。——
    final lineNumRaw = json['lineNum'];
    final lineNum = lineNumRaw is int
        ? lineNumRaw
        : int.tryParse(lineNumRaw?.toString() ?? '') ?? 0;
    final lineLabel = lineNum > 0 ? '第 $lineNum 节' : '';

    final applyTime = _pickString(json, [
      'createTime',
      'applyTime',
      'submitTime',
    ], '');

    final statusRaw = json['status'];
    _ApplyStatus status;
    final n = statusRaw is int
        ? statusRaw
        : int.tryParse(statusRaw?.toString() ?? '') ?? 0;
    if (n == 1) {
      status = _ApplyStatus.passed;
    } else if (n == 2) {
      status = _ApplyStatus.rejected;
    } else {
      status = _ApplyStatus.pending;
    }

    return _ApplyRecord(
      id: id,
      title: title,
      teacher: teacher,
      location: classroom,
      applyTime: applyTime,
      dateLabel: dateLabel,
      lineLabel: lineLabel,
      note: note.isEmpty ? '无' : note,
      status: status,
    );
  }

  /// 解析 `courseData` JSON 字符串里的子项数量。字段缺失 / 不是字符串 /
  /// 解析失败时统一返回 0。
  static int _countCourseDataOccurrences(dynamic raw) {
    if (raw is List) return raw.length;
    if (raw is! String || raw.isEmpty) return 0;
    try {
      // 雪花长 ID 这里仅需要数 List 长度，不读取具体 id，所以即便 Web
      // 上数值精度被截也不影响计数；不必再做 _preserveLongIds 预处理。
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.length;
    } catch (_) {
      /* swallow */
    }
    return 0;
  }

  String get subline {
    final parts = <String>[];
    if (teacher.isNotEmpty) parts.add(teacher);
    if (location.isNotEmpty) parts.add(location);
    return parts.join(' · ');
  }
}

class _ApplyGrid extends StatelessWidget {
  const _ApplyGrid({
    required this.records,
    required this.onApprove,
    required this.onReject,
    required this.onOpenDetail,
  });

  final List<_ApplyRecord> records;
  final ValueChanged<_ApplyRecord> onApprove;
  final ValueChanged<_ApplyRecord> onReject;
  final ValueChanged<_ApplyRecord> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pairs = <List<_ApplyRecord>>[];
    for (var i = 0; i < records.length; i += 2) {
      pairs.add(records.sublist(i, (i + 2).clamp(0, records.length)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var rowIdx = 0; rowIdx < pairs.length; rowIdx++) ...[
          if (rowIdx > 0) SizedBox(height: ui(16)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ApplyCard(
                  record: pairs[rowIdx][0],
                  onApprove: onApprove,
                  onReject: onReject,
                  onOpenDetail: onOpenDetail,
                ),
              ),
              SizedBox(width: ui(16)),
              Expanded(
                child: pairs[rowIdx].length > 1
                    ? _ApplyCard(
                        record: pairs[rowIdx][1],
                        onApprove: onApprove,
                        onReject: onReject,
                        onOpenDetail: onOpenDetail,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ApplyCard extends StatelessWidget {
  const _ApplyCard({
    required this.record,
    required this.onApprove,
    required this.onReject,
    required this.onOpenDetail,
  });

  final _ApplyRecord record;
  final ValueChanged<_ApplyRecord> onApprove;
  final ValueChanged<_ApplyRecord> onReject;
  final ValueChanged<_ApplyRecord> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onOpenDetail(record),
            borderRadius: BorderRadius.circular(ui(12)),
            child: Padding(
              padding: EdgeInsets.only(bottom: ui(2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: ui(40),
                        height: ui(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ui(8)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.event_note_rounded,
                          size: ui(20),
                          color: _kPurple,
                        ),
                      ),
                      SizedBox(width: ui(8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    record.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: ui(14),
                                      color: _kTextDark,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: AppFont.w500,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                SizedBox(width: ui(8)),
                                _ApplyStatusBadge(status: record.status),
                              ],
                            ),
                            SizedBox(height: ui(3)),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    record.subline.isEmpty
                                        ? '—'
                                        : record.subline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: ui(12),
                                      color: _kTextDark,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: AppFont.w400,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                if (record.applyTime.isNotEmpty) ...[
                                  SizedBox(width: ui(8)),
                                  Text(
                                    record.applyTime,
                                    style: TextStyle(
                                      fontSize: ui(12),
                                      color: _kTextHint,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: AppFont.w400,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ui(12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(12),
                      vertical: ui(8),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '日期',
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextHint,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w400,
                                  height: 20 / 12,
                                ),
                              ),
                              Text(
                                record.dateLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w400,
                                  height: 20 / 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '节次',
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextHint,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w400,
                                  height: 20 / 12,
                                ),
                              ),
                              Text(
                                record.lineLabel.isEmpty ? '—' : record.lineLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w400,
                                  height: 20 / 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ui(10)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '备注：',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextHint,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 20 / 12,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          record.note,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 20 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (record.status == _ApplyStatus.pending) ...[
            SizedBox(height: ui(12)),
            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    label: '通过',
                    primary: true,
                    onTap: () => onApprove(record),
                  ),
                ),
                SizedBox(width: ui(12)),
                Expanded(
                  child: _CardActionButton(
                    label: '驳回',
                    primary: false,
                    onTap: () => onReject(record),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplyStatusBadge extends StatelessWidget {
  const _ApplyStatusBadge({required this.status});

  final _ApplyStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (label, bg, fg) = switch (status) {
      _ApplyStatus.pending => ('待审核', _kPendingBg, _kPendingFg),
      _ApplyStatus.passed => ('已通过', _kPassedBg, _kPassedFg),
      _ApplyStatus.rejected => ('已驳回', _kRejectedBg, _kRejectedFg),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: primary ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: primary ? null : Border.all(color: _kBorderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: primary ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 24 / 14,
          ),
        ),
      ),
    );
  }
}

class _ApplyEmptyState extends StatelessWidget {
  const _ApplyEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(60)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: ui(36), color: _kTextHint),
          SizedBox(height: ui(8)),
          Text(
            message,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 驳回申请弹窗（与 teacher_leave_approval_view 同款 GradientHeaderDialog）
// =============================================================================

Future<String?> _showRejectDialog(
  BuildContext context, {
  required _ApplyRecord record,
}) {
  final controller = TextEditingController();
  return showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return GradientHeaderDialog(
        title: '驳回申请',
        titleFontSize: 24,
        titleFontWeight: FontWeight.w500,
        titlePaddingTop: 40,
        width: 428,
        contentPadding: EdgeInsets.fromLTRB(ui(40), ui(40), ui(40), ui(30)),
        actionBar: AppDialogActionBar(
          confirmLabel: '确认',
          cancelLabel: '取消',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () => Navigator.of(dialogContext).pop(controller.text),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${record.title} · ${record.subline.isEmpty ? '—' : record.subline}',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 16,
              ),
            ),
            SizedBox(height: ui(15)),
            Text(
              '驳回说明',
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 14,
              ),
            ),
            SizedBox(height: ui(15)),
            Container(
              height: ui(80),
              padding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(12),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft, width: 1),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: _kPurple,
                cursorWidth: 1.5,
                cursorHeight: ui(16),
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
                decoration: InputDecoration(
                  hintText: '请输入',
                  hintStyle: TextStyle(
                    fontSize: ui(14),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 14,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// =============================================================================
// 通用 helpers
// =============================================================================

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

List<Map<String, dynamic>> _extractList(ApiResponse resp) {
  dynamic raw = resp.data;
  // 兼容 `{ data: [...] }` / `{ data: { records, total } }` 多包一层。
  if (raw is Map && raw.containsKey('data')) {
    final d = raw['data'];
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      raw = d;
    }
  }
  final list = raw is List
      ? raw
      : (raw is Map && raw['records'] is List
            ? raw['records'] as List
            : (raw is Map && raw['list'] is List
                  ? raw['list'] as List
                  : const []));
  return [
    for (final item in list)
      if (item is Map) item.cast<String, dynamic>(),
  ];
}

/// 分页接口里 total / totalCount 等字段（用于待审核角标）。
int? _extractPageTotal(ApiResponse resp) {
  dynamic raw = resp.data;
  if (raw is Map && raw['data'] is Map) {
    raw = raw['data'];
  }
  if (raw is! Map) return null;
  final m = raw.cast<String, dynamic>();
  for (final key in ['total', 'totalCount', 'recordsTotal', 'count']) {
    final v = m[key];
    if (v == null) continue;
    if (v is int) return v;
    final n = int.tryParse(v.toString());
    if (n != null) return n;
  }
  return null;
}
