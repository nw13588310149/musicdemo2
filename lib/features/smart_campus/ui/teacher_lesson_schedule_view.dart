// =============================================================================
// 任课老师端「授课课表」独立页面
//
// 入口：教师 dashboard 快捷区「授课课表」按钮 → controller.openMySchedule()
//      → mainView == mySchedule + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（68 高）：白→#F9EDFF 渐变；左 32 返回；居中 16/600
//      "授课课表" + 12/B6B5BB 副标题；右上角 "查看 / 编辑" 分段控制
//      （32 高白底 + #F3F2F3 边；激活段紫底 #8741FF / 白字）。
//   2. 控制条（64 高 #F5F6FA 灰底 12 圆角）：
//      - 左上：教学周第 N 周（16/600，N 用 #8741FF 紫）。
//      - 左下：legend 两枚 pill：⚫ #A773FF "大课"·灰副标"不可编辑"；
//             ⚫ #0CAC40 "小课"·灰副标"编辑模式下可点击"。
//      - 右侧：[◀ 本周 ▶] 周切换器 + "YYYY/MM/DD" 日历 pill。
//   3. 网格（930×N，1px #F3F2F3 描边，12 圆角）：与学生 / 管理员端共用同
//      4 主题课卡 + 时间冻结列 + 横滚日期区。左侧时间列由
//      `schoolTimeConfigList` 接口返回；课表数据来自任课老师端
//      `/app/school/v2/teacher/courseList`，已按 token 过滤为当前老师的课。
//      同时并行拉 `/app/school/v2/teacher/schoolSmallCourseApplyList`，把
//      「待审核 / 已驳回」的小课申请以幽灵卡形式叠到对应日期 / 节次格子里
//      （已通过的申请因 courseList 已包含，做 (classId,date,lineNum) 去重
//      避免双显示）。这些幽灵卡右上角用对应颜色徽章替代默认「小课」pill。
//   4. 编辑模式：
//      - 大课（紫）原样展示，不可编辑（与 admin 端不同：admin 端可拖动）；
//      - 小课（橙 / 蓝）变可点击；
//      - 不论本节当前是空、是小课、还是已经排了大课，卡片下方都会挂一枚
//        48 高 "申请小课" pill：教师可以直接在大课同节申请加排一节小课
//        （高三艺考生加练等场景）→ 打开右侧 [_ApplySmallLessonDrawer]，
//        提交触发 `/app/school/v2/teacher/schoolSmallCourseApplySave`。
//   5. 查看模式空格画 "空闲" 灰边占位；编辑模式下空格走"申请小课"。
//
// 颜色：白 / #F5F6FA 灰 / #F3F2F3 边 / #8741FF 主紫 / #6D6B75 副字 /
//      #B6B5BB 提示 / #774B09 橙文 / #0D3A6D 蓝文 / #7535BE 紫文
// =============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../school/data/school_repository.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import '../data/teacher_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 通用配色（与学生 / 管理员端 schedule 保持一致）----------------------

const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);

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

// 「我的小课申请」状态色（与 admin schedule 端 _kPendingBg/Fg 等保持一致），
// 用于课卡右上角的状态徽章替代默认「小课」pill。
const Color _kApplyPendingBg = Color(0xFFFFEDD3);
const Color _kApplyPendingFg = Color(0xFFFF6A00);
const Color _kApplyRejectedBg = Color(0xFFFFE5E5);
const Color _kApplyRejectedFg = Color(0xFFE83A3A);

// 列与行尺寸
const double _kTimeColWidth = 120;
const double _kDayColWidth = 200;
const double _kHeaderHeight = 60;

enum _ScheduleMode { view, edit }

/// 「我的小课申请」状态：与后端 `status` 字段双向映射 —— 1 通过 / 2 驳回 /
/// 0 / null 待审核。和 admin schedule 端 `_ApplyStatus` 完全一致。
enum _ApplyStatus { pending, passed, rejected }

// ---- 数据模型 -----------------------------------------------------------

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
    this.applyStatus,
    this.apply,
  });

  final _CardKind kind;
  final String location;
  final String name;
  final String subline;
  final String? capacity;

  /// API `color` 字段（hex 解析后）覆盖默认主题底色；为空则按 [kind] 走预设。
  final Color? bgColor;

  /// `courseList` 单条原始记录（保留以备后续扩展，例如详情弹窗等）。
  final Map<String, dynamic>? raw;

  /// 非空 = 这张卡来自「我的小课申请」(schoolSmallCourseApplyList)，
  /// 不是已生效的真实课表项。卡片右上角会用对应颜色徽章替换默认的
  /// 「小课」pill 提示当前审核状态。
  ///
  /// 已通过(`passed`) 的申请不会落到这里 —— 后端 `courseList` 会同步
  /// 返回它作为真实排课，避免双重渲染。
  final _ApplyStatus? applyStatus;

  /// 当 [applyStatus] 非空时一并存这条申请的回看上下文：申请 id、驳回理由、
  /// 原始 classroomId / subjectId / color / lineNum / date 等 —— 点击卡片时
  /// 弹详情对话框、以及「重新申请」打开申请抽屉时预填都靠它。
  final _ApplyContext? apply;
}

/// 「我的小课申请」幽灵卡的回看上下文，封装一条申请的关键参数 + 状态 / 理由。
///
/// 字段直接对应 `schoolSmallCourseApplyList` 接口里每条记录的核心字段（含
/// `courseData` 解开后的 child）。详情弹窗 / 重新申请抽屉都从这里取值，
/// 避免把 raw map 在多个调用点重新解析一次。
class _ApplyContext {
  const _ApplyContext({
    required this.applyId,
    required this.status,
    required this.classId,
    required this.lineNum,
    required this.dateIso,
    this.reason,
    this.classroomId,
    this.subjectId,
    this.colorHex,
  });

  final String applyId;
  final _ApplyStatus status;
  final String classId;
  final int lineNum;
  final String dateIso;

  /// 驳回理由（仅 [_ApplyStatus.rejected] 时通常有值）。
  final String? reason;
  final int? classroomId;
  final int? subjectId;
  final String? colorHex;
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

/// 节次时间配置（来自 `schoolTimeConfigList`）。
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

/// 兜底节次：API 拉不到 / 无配置时显示 5 节，与原 demo 节奏保持一致。
const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  _TimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  _TimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  _TimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  _TimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

/// 本学期总教学周数（与 admin 端约定一致：18 周）。"本学期所有教学周"
/// 复用模式从当前 `currentWeek` 起补到第 [_kTermTotalWeeks] 周。
const int _kTermTotalWeeks = 18;

// =============================================================================
// 入口 widget
// =============================================================================

class TeacherLessonScheduleView extends ConsumerStatefulWidget {
  const TeacherLessonScheduleView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherLessonScheduleView> createState() =>
      _TeacherLessonScheduleViewState();
}

class _TeacherLessonScheduleViewState
    extends ConsumerState<TeacherLessonScheduleView> {
  /// 当前显示的周一（用于日期范围 / 标签 / API begin/end）。
  late DateTime _weekStart;

  /// "教学周第 N 周" 的展示数字。本地维护：默认 12 周（"本周"），每翻一周 ±1。
  /// 后端 swagger 没单独返回教学周编号，仅作 UI 展示。
  int _currentWeek = 12;
  static const int _baseWeek = 12;

  _ScheduleMode _mode = _ScheduleMode.view;

  /// 班级列表第一项 id（来自 teacher `/teacher/classList`，已基于 token
  /// 过滤为「我教的班级」）。仅用于驱动 `schoolTimeConfigList` 拉对应班级
  /// 的节次时间表 + 抽屉默认班级回填。抽屉自身会再调一次 `classList`
  /// (带 type:1) 拿最新的我的小班列表，无需在这里整张缓存。
  String? _firstClassId;

  /// 课表数据字典（id → 名称），仅给「我的小课申请」幽灵卡用 ——
  /// 申请记录里只有 id，没有 name / realname 等字段；要在画卡前把名字
  /// 补齐才能显示班级 / 教室 / 科目。
  ///
  /// 真实课表项（`courseList` 接口）后端已经把这些字段平铺好了，所以这套
  /// 字典只服务申请合并路径，不影响主流程。
  Map<String, String> _classNameById = const {};
  Map<int, String> _classroomNameById = const {};
  Map<int, String> _subjectNameById = const {};

  /// 课表左侧节次时间表（按 `lineNum` 升序）。
  List<_TimeConfig> _timeConfigs = const [];

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  /// 当前周的网格数据，[7 天][N 节] → 多张课卡。null = 尚未加载。
  List<List<List<_ScheduleCardData>>>? _serverCells;
  bool _scheduleLoading = false;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    if (picked == null || !mounted) return;
    final newWeekStart = _mondayOf(picked);
    final delta = newWeekStart.difference(_mondayOf(DateTime.now())).inDays;
    setState(() {
      _weekStart = newWeekStart;
      _currentWeek = _baseWeek + (delta / 7).round();
    });
    _loadSchedule();
  }

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 先拉班级列表（驱动 timeConfig 用），再并行拉时间表 + 字典
      // （教室 / 科目，给申请幽灵卡补名字），最后拉课表。字典失败不会
      // 阻断 schedule 渲染，只是申请卡上的字段会缺。
      await _loadClasses();
      if (!mounted) return;
      await Future.wait([_loadTimeConfig(), _loadDirectories()]);
      if (!mounted) return;
      _loadSchedule();
    });
  }

  // —— 数据加载 ————————————————————————————————————————————————

  Future<void> _loadClasses() async {
    // 任课老师身份进入授课课表页 → 走 teacher 端 classList，后端基于 token
    // 自动过滤为「我教的班级」（含大班 + 小班），与 admin 端 classList 区分开。
    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.classList();
    if (!mounted || !resp.isSuccess) return;
    final rows = _extractList(resp);
    String? firstId;
    final nameById = <String, String>{};
    for (final m in rows) {
      final id = _pickString(m, ['id', 'classId'], '');
      if (id.isEmpty) continue;
      firstId ??= id;
      final name = _pickString(m, [
        'name',
        'className',
        'fullName',
      ], '');
      if (name.isNotEmpty) nameById[id] = name;
    }
    if (!mounted) return;
    setState(() {
      _firstClassId = firstId;
      _classNameById = nameById;
    });
  }

  /// 拉教室 / 科目字典 —— 仅给「我的小课申请」幽灵卡补齐展示字段，与课表
  /// 主流程解耦：失败 / 慢都不会阻断 schedule 渲染。
  ///
  /// - 教室走 admin `classroomList`（教室是全校公共资源，与身份无关），
  ///   一次拿全量；
  /// - 科目走 user `subjectList(classId)`，必须按班级查 —— 接口不传 classId
  ///   后端实测不返回全量。所以这里对 `_classNameById` 里的每个班级并行
  ///   发 N 个请求，结果合并成一张大字典。教师通常只教若干班级 (<20)，
  ///   单次开页面的成本可控。
  Future<void> _loadDirectories() async {
    final adminRepo = ref.read(adminRepositoryProvider);
    final schoolRepo = ref.read(schoolRepositoryProvider);

    final classIds = _classNameById.keys.toList();
    final classroomFuture = adminRepo.classroomList();
    final subjectFutures = <Future<ApiResponse>>[
      for (final cid in classIds) schoolRepo.subjectList(classId: cid),
    ];

    final classroomResp = await classroomFuture;
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
      _subjectNameById = subjectMap;
    });
  }

  /// 取课表左侧时间列表。`schoolTimeConfigList` 接口要求 `classId` 必填，
  /// 用班级列表第一项作为基准；为空时回退到 [_kDefaultTimeConfigs]。
  Future<void> _loadTimeConfig() async {
    final classId = _firstClassId;
    if (classId == null || classId.isEmpty) return;
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.schoolTimeConfigList(classId: classId);
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

  Future<void> _loadSchedule() async {
    setState(() => _scheduleLoading = true);
    final repo = ref.read(teacherRepositoryProvider);
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    // 并行：① 真实课表（已排定）； ② 我的小课申请列表（含审核中 / 已驳回，
    // 用来在课表上同步显示状态徽章）。已通过的申请会同步出现在 ① 里作为
    // 真实排课，所以 ② 的 passed 记录会被跳过避免双显示。
    //
    // size: 100 兜底单个老师近期的全部申请（学期内极少超过 100 条），暂不
    // 引入分页；超过时再加 current 循环。
    final results = await Future.wait([
      repo.courseList(beginDate: _isoDate(start), endDate: _isoDate(end)),
      repo.schoolSmallCourseApplyList(current: 1, size: 100),
    ]);
    if (!mounted) return;
    final courseResp = results[0];
    final applyResp = results[1];

    if (!courseResp.isSuccess) {
      setState(() {
        _serverCells = _emptyCells();
        _scheduleLoading = false;
      });
      return;
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    final rows = _extractCourseRows(courseResp);
    final smallSeq = <int, int>{};
    // 去重 key：'classId|date|lineNum'。courseList 已经吃掉的格子，apply
    // 列表里若有同 key 的项（理论上是 passed，但用 key 兜底更鲁棒）就不
    // 再叠一张幽灵卡上去。
    final realCourseKeys = <String>{};

    for (final entry in rows) {
      final m = entry.row;
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
      var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
      if (slotIdx < 0) {
        slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
      }

      final cellKey = dayIdx * 1000 + slotIdx;
      final card = _parseCourseCard(m, smallSeq[cellKey] ?? 0);
      smallSeq[cellKey] = (smallSeq[cellKey] ?? 0) + 1;
      cells[dayIdx][slotIdx].add(card);

      // 记录已有排课的 (classId,date,lineNum)，给申请列表去重。
      final cid = _pickString(m, ['classId', 'cId'], '');
      final cdate = (dateStr.split('T').first);
      if (cid.isNotEmpty && cdate.isNotEmpty) {
        realCourseKeys.add('$cid|$cdate|$lineNum');
      }
    }

    if (applyResp.isSuccess) {
      _mergeApplyRecords(
        applyResp,
        cells: cells,
        smallSeq: smallSeq,
        realCourseKeys: realCourseKeys,
      );
    }

    setState(() {
      _serverCells = cells;
      _scheduleLoading = false;
    });
  }

  /// 解析「我的小课申请」分页响应，把待审核 / 已驳回的项以幽灵卡形式插入
  /// [cells]，并通过 [realCourseKeys] 去重已经落地的项。
  ///
  /// 后端返回结构（实测 swagger 一致）：
  /// ```
  /// data.records: [
  ///   {
  ///     id, schoolId, classId, teacherId, subjectId, lineNum, color,
  ///     classroomId, status, reason, createTime, auditTime,
  ///     startDate, endDate,
  ///     courseData: "[{classId,classroomId,color,date,lineNum,
  ///                    subjectId,teacherId}, ...]"   // ← JSON 字符串
  ///   }
  /// ]
  /// ```
  /// `courseData` 是 **字符串化的 JSON 数组**，复用方式（本学期 / 后续 4 周
  /// / 后续 8 周）会展开成多条 child，按 child.date 落到对应日期 / 节次格。
  void _mergeApplyRecords(
    ApiResponse resp, {
    required List<List<List<_ScheduleCardData>>> cells,
    required Map<int, int> smallSeq,
    required Set<String> realCourseKeys,
  }) {
    final raw = resp.data;
    // 分页响应：data 通常是 {records: [...], total: N} 也可能直接是 List。
    List<dynamic> rows = const [];
    if (raw is Map) {
      final r = raw['records'] ?? raw['list'] ?? raw['data'];
      if (r is List) rows = r;
    } else if (raw is List) {
      rows = raw;
    }
    if (rows.isEmpty) return;

    final configs = _activeTimeConfigs;
    for (final item in rows) {
      if (item is! Map) continue;
      final apply = item.cast<String, dynamic>();
      final status = _parseApplyStatus(apply['status']);
      // 课表里只画「待审核」幽灵卡：
      //   - 已通过：courseList 已经返回真实排课，不重复渲染；
      //   - 已驳回：被驳回的不再占用课表格子，避免视觉污染；
      //     用户可以在右上角「申请记录」面板里看全部状态 + 重新申请。
      if (status != _ApplyStatus.pending) continue;

      // `courseData` 是 JSON 字符串；`courseList` 留作前向兼容（万一后端某
      // 个版本改成结构化数组）。两者都没有时退化为顶层 startDate + lineNum
      // 单点占位。
      //
      // 解码前先把雪花长 ID（>= 2^53，等价于长度 >= 16 的纯数字字面量）
      // 包成字符串：Dart Web 上 int = JS Number(double)，未引号大数会被
      // jsonDecode 截到相邻偶数，导致后面用 classId 反查班级名永远失败。
      final children = <Map<String, dynamic>>[];
      final cdRaw = apply['courseData'];
      if (cdRaw is String && cdRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(_preserveLongIds(cdRaw));
          if (decoded is List) {
            for (final c in decoded) {
              if (c is Map) children.add(c.cast<String, dynamic>());
            }
          }
        } catch (_) {
          // 静默忽略：坏数据不应让整条申请挂掉，下方 fallback 至少画一张
          // 顶层占位卡。
        }
      } else if (cdRaw is List) {
        for (final c in cdRaw) {
          if (c is Map) children.add(c.cast<String, dynamic>());
        }
      } else {
        final legacy = apply['courseList'];
        if (legacy is List) {
          for (final c in legacy) {
            if (c is Map) children.add(c.cast<String, dynamic>());
          }
        }
      }
      if (children.isEmpty) {
        children.add(<String, dynamic>{
          'date': _pickString(apply, ['startDate', 'applyDate'], ''),
          'lineNum': apply['lineNum'],
        });
      }

      for (final cm in children) {
        final dateStr = _pickString(cm, [
          'date',
          'classDate',
          'courseDate',
        ], '');
        final dayIdx = _dayIndex(dateStr);
        if (dayIdx < 0) continue;

        final lnRaw = cm['lineNum'] ?? apply['lineNum'];
        final lineNum = lnRaw is int
            ? lnRaw
            : (int.tryParse(lnRaw?.toString() ?? '') ?? 0);
        if (lineNum < 1) continue;
        var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
        if (slotIdx < 0) {
          slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
        }

        // 去重：同 (classId,date,lineNum) 已有真实排课就跳过（多数是 passed
        // 走 courseList，少数极端场景下后端可能在 apply 列表里也回这条）。
        final cid = _pickString(cm, [
          'classId',
          'cId',
        ], _pickString(apply, ['classId'], ''));
        final cdate = dateStr.split('T').first;
        if (cid.isNotEmpty && cdate.isNotEmpty) {
          if (realCourseKeys.contains('$cid|$cdate|$lineNum')) continue;
        }

        // 合并外层（顶层 apply）+ 内层 child：内层 date/lineNum/classId 优先。
        // 同时强制 type=2 → 走小课卡解析分支，保证视觉是小课色 + 小课形状。
        final merged = <String, dynamic>{
          ...apply,
          ...cm,
          'type': 2,
        };

        // 用字典补齐展示字段：申请记录仅含 id，没有名称，需要按
        // (classId, classroomId, subjectId, teacherId) 反查字典。
        // 已有同名 key 时不覆盖（极少数 courseData 已自带的字段保留原值）。
        final className = _classNameById[cid];
        if (className != null && className.isNotEmpty) {
          merged.putIfAbsent('className', () => className);
        }
        final classroomIdRaw = cm['classroomId'] ?? apply['classroomId'];
        final classroomIdInt = classroomIdRaw is int
            ? classroomIdRaw
            : int.tryParse(classroomIdRaw?.toString() ?? '');
        if (classroomIdInt != null) {
          final classroomName = _classroomNameById[classroomIdInt];
          if (classroomName != null && classroomName.isNotEmpty) {
            merged.putIfAbsent('classroomName', () => classroomName);
          }
        }
        final subjectIdRaw = cm['subjectId'] ?? apply['subjectId'];
        final subjectIdInt = subjectIdRaw is int
            ? subjectIdRaw
            : int.tryParse(subjectIdRaw?.toString() ?? '');
        if (subjectIdInt != null) {
          final subjectName = _subjectNameById[subjectIdInt];
          if (subjectName != null && subjectName.isNotEmpty) {
            merged.putIfAbsent('subjectName', () => subjectName);
          }
        }
        // 教师：申请人就是当前登录的任课老师，直接走 shell 的 user 兜底；
        // 极端场景下 teacherId 与 shell.user.id 不一致也无所谓，因为这本
        // 来就是「我的申请」列表，UI 字段只是辅助显示。
        final shellUser = ref.read(shellControllerProvider).user;
        final teacherDisplayName = shellUser.realname.isNotEmpty
            ? shellUser.realname
            : shellUser.nickname;
        if (teacherDisplayName.isNotEmpty) {
          merged.putIfAbsent('teacherRealname', () => teacherDisplayName);
        }

        // 构造回看上下文，给详情对话框 + 重新申请抽屉用。classId 取已经
        // 做过雪花精度保留的 cid（_preserveLongIds 已处理过 courseData），
        // classroom / subject / color 兜底到外层 apply 字段。
        final applyId = _pickString(apply, ['id', 'applyId'], '');
        final applyReason = _pickString(apply, ['reason'], '');
        final applyCtx = _ApplyContext(
          applyId: applyId,
          status: status,
          classId: cid.isNotEmpty
              ? cid
              : _pickString(apply, ['classId'], ''),
          lineNum: lineNum,
          dateIso: cdate,
          reason: applyReason.isEmpty ? null : applyReason,
          classroomId: classroomIdInt,
          subjectId: subjectIdInt,
          colorHex: _pickString(merged, ['color'], ''),
        );

        final cellKey = dayIdx * 1000 + slotIdx;
        final smallIdx = smallSeq[cellKey] ?? 0;
        final card = _parseCourseCard(
          merged,
          smallIdx,
          applyStatus: status,
          apply: applyCtx,
        );
        smallSeq[cellKey] = smallIdx + 1;
        cells[dayIdx][slotIdx].add(card);
      }
    }
  }

  /// `courseList` 的 `data` 既可能是按日期分组的 Map（新格式：
  /// `{"2026-05-11": [{...}, ...]}`），也可能是扁平 List（老格式）。
  /// 统一摊平成 `(dateKey, row)` 元组。
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
  /// 编辑模式下额外预留 56px：8 间距 + 48 高 "申请小课" pill，让"大课下方
  /// 也能申请小课"在每一节都成立。
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
    final base = 120.0 + (maxCards - 1) * 102.0;
    // 编辑模式下不论是否已有课卡，都在卡片下方挂"申请小课" pill（8 + 48）。
    if (_mode == _ScheduleMode.edit) return base + 56;
    return base;
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
  /// `type == 2` → 小课（同一格里第 0 张橙、第 1 张蓝循环）；其它值 → 大课。
  /// `color` 是 hex（含 `#`），存到卡片做背景覆盖；标题色按 kind 走语义色。
  ///
  /// 当 [applyStatus] 非空时，表示这条来自「我的小课申请」列表，会被透传
  /// 到 [_ScheduleCardData.applyStatus] 给卡片画状态徽章用；同时 [apply]
  /// 用来回看上下文（详情弹窗 / 重新申请抽屉预填）。
  _ScheduleCardData _parseCourseCard(
    Map<String, dynamic> json,
    int smallIdxInCell, {
    _ApplyStatus? applyStatus,
    _ApplyContext? apply,
  }) {
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
        applyStatus: applyStatus,
        apply: apply,
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
      applyStatus: applyStatus,
      apply: apply,
    );
  }

  /// 解析 `#RRGGBB` / `#AARRGGBB` 形式的 hex；非法则返回 null。
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

  /// 把节次/日期组合成 "第N节 HH:MM-HH:MM· 周X yyyy-MM-dd" 形式（抽屉只读项）。
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

  /// 给「已驳回 / 待审核」申请幽灵卡拼一句只读时间标签：
  /// `第N节 HH:MM-HH:MM· 周X yyyy-MM-dd`。lineNum 在时间配置里找不到时
  /// 就直接用 `第${lineNum}节`，避免误导。dateIso 已是 yyyy-MM-dd。
  String _slotLabelForApply(_ApplyContext ctx) {
    final cfg = _activeTimeConfigs.firstWhere(
      (c) => c.lineNum == ctx.lineNum,
      orElse: () => _TimeConfig(lineNum: ctx.lineNum, start: '', end: ''),
    );
    final timeSegment = cfg.start.isNotEmpty && cfg.end.isNotEmpty
        ? ' ${cfg.start}-${cfg.end}'
        : '';
    String weekdayLabel = '';
    try {
      final d = DateTime.parse(ctx.dateIso);
      const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      // DateTime.weekday：周一=1 .. 周日=7
      weekdayLabel = labels[(d.weekday - 1).clamp(0, 6)];
    } catch (_) {
      weekdayLabel = '';
    }
    final prefix = weekdayLabel.isEmpty ? '' : '· $weekdayLabel ';
    return '第${ctx.lineNum}节$timeSegment$prefix${ctx.dateIso}';
  }

  /// 打开「我的小课申请记录」右侧抽屉：
  ///   - 列出我所有状态的申请（待审核 / 通过 / 驳回）
  ///   - 「驳回」记录可点击「重新申请」复用原参数二次提交
  ///   - 抽屉关闭后若提交过新申请，回到课表会重新拉一次课表 + 申请列表
  Future<void> _openApplyRecords() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final reapplied = await showGeneralDialog<bool>(
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
              child: _ApplyRecordsDrawer(
                classNameById: _classNameById,
                classroomNameById: _classroomNameById,
                subjectNameById: _subjectNameById,
                onClose: () => Navigator.of(ctx).maybePop(),
                onRequestReapply: (apply) async {
                  Navigator.of(ctx).pop(true);
                  await _reapplySmallLesson(apply);
                },
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

    if (reapplied == true && mounted) {
      await _loadSchedule();
    }
  }

  /// 重新申请：以驳回申请的 classId / classroomId / subjectId / color /
  /// lineNum / date 作为初始值打开 [_ApplySmallLessonDrawer]，用户可以
  /// 直接点提交（同一参数），也可以微调日期 / 节次 / 复用方式后再交。
  Future<void> _reapplySmallLesson(_ApplyContext apply) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
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
              child: _ApplySmallLessonDrawer(
                slotLabel: _slotLabelForApply(apply),
                baseDateIso: apply.dateIso,
                lineNum: apply.lineNum,
                currentWeek: _currentWeek,
                initialClassId: apply.classId,
                initialClassroomId: apply.classroomId?.toString(),
                initialSubjectId: apply.subjectId?.toString(),
                initialColorHex: apply.colorHex,
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
    AppToast.show(context, '已提交教务审核');
    await _loadSchedule();
  }

  /// 编辑模式下点击空格 → 弹右侧 [_ApplySmallLessonDrawer]，提交时调
  /// `schoolSmallCourseApplySave` 写入一条申请，成功后重新拉取本周课表。
  Future<void> _onApplySmallLesson(int dayIdx, int slotIdx) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final day = _weekStart.add(Duration(days: dayIdx));

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
              child: _ApplySmallLessonDrawer(
                slotLabel: _slotLabel(dayIdx, slotIdx),
                baseDateIso: _isoDate(day),
                lineNum: _lineNumOf(slotIdx),
                currentWeek: _currentWeek,
                initialClassId: _firstClassId,
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
    AppToast.show(context, '已提交教务审核');
    await _loadSchedule();
  }

  // —— Build ————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cells = _serverCells ?? _emptyCells();
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();

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
            _TeacherScheduleHeader(
              onBack: widget.onBack,
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
              onOpenApplyRecords: _openApplyRecords,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(12)),
              child: _TeacherScheduleControlBar(
                week: _currentWeek,
                weekDateLabel: _fmtDate(_weekStart),
                onPrev: _gotoPrev,
                onCurrent: _gotoCurrent,
                onNext: _gotoNext,
                onPickDate: _pickDate,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(20)),
              child: Stack(
                children: [
                  _ScheduleGrid(
                    mode: _mode,
                    slots: slots,
                    days: days,
                    cells: cells,
                    onApplySmallLesson: _onApplySmallLesson,
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
                          child: const CircularProgressIndicator(
                            color: _kPurple,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 顶部 banner：68 高，白→紫淡色渐变；居中标题 + 副标题；右上"查看/编辑"分段
// =============================================================================

class _TeacherScheduleHeader extends StatelessWidget {
  const _TeacherScheduleHeader({
    required this.onBack,
    required this.mode,
    required this.onModeChanged,
    required this.onOpenApplyRecords,
  });

  final VoidCallback onBack;
  final _ScheduleMode mode;
  final ValueChanged<_ScheduleMode> onModeChanged;

  /// 顶部右上「申请记录」按钮回调，打开「我的小课申请记录」抽屉，
  /// 内容由父页面注入完整字典（班级 / 教室 / 科目）+ 「重新申请」连接。
  final VoidCallback onOpenApplyRecords;

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
                '授课课表',
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
            top: ui(18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ApplyRecordsButton(onTap: onOpenApplyRecords),
                SizedBox(width: ui(10)),
                _ViewEditSegment(mode: mode, onChanged: onModeChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyRecordsButton extends StatelessWidget {
  const _ApplyRecordsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: ui(14),
              color: const Color(0xFF1C274C),
            ),
            SizedBox(width: ui(6)),
            Text(
              '申请记录',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentChip(
            label: '查看',
            active: mode == _ScheduleMode.view,
            onTap: () => onChanged(_ScheduleMode.view),
          ),
          _SegmentChip(
            label: '编辑',
            active: mode == _ScheduleMode.edit,
            onTap: () => onChanged(_ScheduleMode.edit),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
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
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
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
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 控制条：教学周 + legend + 周切换 + 当周日期
// =============================================================================

class _TeacherScheduleControlBar extends StatelessWidget {
  const _TeacherScheduleControlBar({
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
                      tail: '不可编辑',
                    ),
                    SizedBox(width: ui(16)),
                    const _LegendItem(
                      dotColor: _kStatusGreen,
                      label: '小课',
                      tail: '编辑模式下可点击',
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(ui(8))),
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
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

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
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

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
  });

  final int slotIdx;
  final double height;
  final _ScheduleMode mode;
  final List<List<_ScheduleCardData>> rowCells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

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
                      slotIdx: slotIdx,
                      slotHeight: height,
                      mode: mode,
                      cards: rowCells[i],
                      onApplySmallLesson: () => onApplySmallLesson(i, slotIdx),
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
    required this.slotIdx,
    required this.slotHeight,
    required this.mode,
    required this.cards,
    required this.onApplySmallLesson,
  });

  final int slotIdx;
  final double slotHeight;
  final _ScheduleMode mode;
  final List<_ScheduleCardData> cards;
  final VoidCallback onApplySmallLesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEditing = mode == _ScheduleMode.edit;
    if (cards.isEmpty) {
      // 查看模式所有空格画 "空闲" 占位；编辑模式画 "申请小课" pill。
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
        child: isEditing
            ? Align(
                alignment: Alignment.topCenter,
                child: _ApplySmallLessonButton(onTap: onApplySmallLesson),
              )
            : const _IdleSlotPlaceholder(),
      );
    }
    // 编辑模式：无论本格当前是大课还是小课，都允许在卡片下方继续"申请小课"。
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(height: ui(6)),
            _ClassCard(
              data: cards[i],
              editable: isEditing && _isSmall(cards[i].kind),
            ),
          ],
          if (isEditing) ...[
            SizedBox(height: ui(8)),
            _ApplySmallLessonButton(onTap: onApplySmallLesson),
          ],
        ],
      ),
    );
  }

  bool _isSmall(_CardKind k) =>
      k == _CardKind.smallOrange || k == _CardKind.smallBlue;
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
              '申请小课',
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
                left: ui(108),
                top: ui(6),
                // 申请态卡片 → 用「待审核 / 已驳回」徽章替换默认小课 pill；
                // 已通过的申请不会跑到这里（_loadSchedule 已过滤掉），所以
                // 申请徽章只可能是这两种态。
                child: data.applyStatus != null
                    ? _ApplyStatusBadge(status: data.applyStatus!)
                    : _ClassKindTag(isSmall: theme.isSmall, outlined: false),
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
                child: const _ClassKindTag(isSmall: false, outlined: true),
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

/// 「我的小课申请」状态徽章（替换课卡右上角的「小课」pill）。
/// 颜色与 admin schedule 审核 tab 的 `_ApplyStatusBadge` 一致：
///   - 待审核：橙底橙字 (#FFEDD3 / #FF6A00)
///   - 已驳回：红底红字 (#FFE5E5 / #E83A3A)
/// 已通过的申请不会画到课表上（_loadSchedule 已去重），所以这里只覆盖
/// pending / rejected 两种态。
class _ApplyStatusBadge extends StatelessWidget {
  const _ApplyStatusBadge({required this.status});

  final _ApplyStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (label, bg, fg) = switch (status) {
      _ApplyStatus.pending => ('待审核', _kApplyPendingBg, _kApplyPendingFg),
      _ApplyStatus.rejected => ('已驳回', _kApplyRejectedBg, _kApplyRejectedFg),
      // 不会渲染，留作 fallback 保证 switch 穷举。
      _ApplyStatus.passed => ('已通过', _kApplyPendingBg, _kApplyPendingFg),
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ui(40),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
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
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(18)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFA894EB) : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: primary ? null : Border.all(color: _kBorderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(13),
            color: primary ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 18 / 13,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 「我的小课申请记录」右侧抽屉
//
// 入口：授课课表右上角「申请记录」按钮 → _openApplyRecords →
//      showGeneralDialog 右滑入场 → 本抽屉。
//
// 设计：宽 520，全高，白底；顶部 62 高 _DrawerHeader（3×15 紫竖条 + 标题
// 「我的小课申请记录」+ 关闭 X，底部 1px #F3F2F3 边）；表体为
// `teacherRepo.schoolSmallCourseApplyList(current:1,size:100)` 返回的记录列表，
// 一条申请一张卡片，按 `createTime` 倒序显示。每张卡片包含：
//   - 顶行：状态徽章（橙待审核 / 绿通过 / 红驳回）+ 班级 · 科目
//   - 时间：startDate ~ endDate · 共 N 次 · 第 lineNum 节
//   - 教室
//   - 申请时间（createTime）
//   - 驳回时额外渲染红底块「驳回理由：…」+ 右侧「重新申请」紫底按钮
//     点击「重新申请」会带着原 classId / classroomId / subjectId / color /
//     lineNum / 首次 date 打开 _ApplySmallLessonDrawer，用户可直接提交。
// =============================================================================
class _ApplyRecordsDrawer extends ConsumerStatefulWidget {
  const _ApplyRecordsDrawer({
    required this.classNameById,
    required this.classroomNameById,
    required this.subjectNameById,
    required this.onClose,
    required this.onRequestReapply,
  });

  /// 父页面缓存的班级 id → 名称字典（classId 是 String，雪花）。
  final Map<String, String> classNameById;

  /// 父页面缓存的教室 id → 名称字典（classroomId 是 int）。
  final Map<int, String> classroomNameById;

  /// 父页面缓存的科目 id → 名称字典（subjectId 是 int）。
  final Map<int, String> subjectNameById;

  final VoidCallback onClose;

  /// 「重新申请」按钮回调，参数即驳回申请的回看上下文；
  /// 父页面收到后会先关本抽屉、再打开申请抽屉预填同参数。
  final ValueChanged<_ApplyContext> onRequestReapply;

  @override
  ConsumerState<_ApplyRecordsDrawer> createState() =>
      _ApplyRecordsDrawerState();
}

class _ApplyRecordsDrawerState extends ConsumerState<_ApplyRecordsDrawer> {
  bool _loading = true;
  String? _error;
  List<_ApplyRecordItem> _records = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplyList(current: 1, size: 100);
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _loading = false;
        _error = resp.msg.isEmpty ? '加载失败' : resp.msg;
      });
      return;
    }
    final raw = resp.data;
    List<dynamic> rows = const [];
    if (raw is Map) {
      final r = raw['records'] ?? raw['list'] ?? raw['data'];
      if (r is List) rows = r;
    } else if (raw is List) {
      rows = raw;
    }
    final items = <_ApplyRecordItem>[];
    for (final r in rows) {
      if (r is! Map) continue;
      final m = r.cast<String, dynamic>();
      final item = _ApplyRecordItem.fromJson(m);
      if (item != null) items.add(item);
    }
    // 按 createTime 倒序：最新提交的排最前。createTime 字符串可直接字典序比较
    // （`yyyy-MM-dd HH:mm:ss`），无 createTime 的兜底排到最后。
    items.sort((a, b) => b.createTime.compareTo(a.createTime));
    setState(() {
      _records = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(520),
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawerHeader(title: '我的小课申请记录', onClose: widget.onClose),
          Expanded(child: _buildBody(context, ui)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, double Function(double) ui) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Text(
          '暂无申请记录',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(ui(20), ui(16), ui(20), ui(20)),
      itemCount: _records.length,
      separatorBuilder: (_, _) => SizedBox(height: ui(12)),
      itemBuilder: (ctx, i) {
        final r = _records[i];
        return _ApplyRecordCard(
          record: r,
          classNameById: widget.classNameById,
          classroomNameById: widget.classroomNameById,
          subjectNameById: widget.subjectNameById,
          onReapply: () => widget.onRequestReapply(r.toReapplyContext()),
        );
      },
    );
  }
}

/// 「我的小课申请记录」抽屉一张卡片对应的数据模型。
/// 字段一对一对应 `schoolSmallCourseApplyList` 单条记录里我们用得到的部分。
class _ApplyRecordItem {
  const _ApplyRecordItem({
    required this.id,
    required this.status,
    required this.classId,
    required this.classroomId,
    required this.subjectId,
    required this.lineNum,
    required this.startDate,
    required this.endDate,
    required this.occurrences,
    required this.firstDateIso,
    required this.colorHex,
    required this.reason,
    required this.createTime,
  });

  final String id;
  final _ApplyStatus status;
  final String classId;
  final int? classroomId;
  final int? subjectId;
  final int lineNum;
  final String startDate;
  final String endDate;
  final int occurrences;

  /// `courseData` 第一条的 date；为空时退化为 [startDate]。
  /// 「重新申请」会用它作为申请抽屉的 baseDateIso。
  final String firstDateIso;
  final String colorHex;
  final String reason;
  final String createTime;

  static _ApplyRecordItem? fromJson(Map<String, dynamic> m) {
    final id = _pickString(m, ['id', 'applyId'], '');
    if (id.isEmpty) return null;
    final statusRaw = m['status'];
    final status = _parseApplyStatus(statusRaw);
    final classId = _pickString(m, ['classId', 'cId'], '');
    final lineRaw = m['lineNum'];
    final lineNum = lineRaw is int
        ? lineRaw
        : (int.tryParse(lineRaw?.toString() ?? '') ?? 0);
    final classroomRaw = m['classroomId'];
    final classroomId = classroomRaw is int
        ? classroomRaw
        : int.tryParse(classroomRaw?.toString() ?? '');
    final subjectRaw = m['subjectId'];
    final subjectId = subjectRaw is int
        ? subjectRaw
        : int.tryParse(subjectRaw?.toString() ?? '');
    final startDate = _pickString(m, ['startDate'], '');
    final endDate = _pickString(m, ['endDate'], '');
    final colorHex = _pickString(m, ['color'], '');
    final reason = _pickString(m, ['reason'], '');
    final createTime = _pickString(m, ['createTime'], '');

    // 解 courseData 拿到「共 N 次」和 firstDateIso。雪花 ID 走 _preserveLongIds
    // 包成字符串再 decode，避免 Web 端 JS number 53bit 截断。
    int occurrences = 0;
    String firstDateIso = startDate;
    final cdRaw = m['courseData'];
    List<dynamic>? children;
    if (cdRaw is String && cdRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(_preserveLongIds(cdRaw));
        if (decoded is List) children = decoded;
      } catch (_) {}
    } else if (cdRaw is List) {
      children = cdRaw;
    }
    if (children != null) {
      occurrences = children.length;
      if (children.isNotEmpty && children.first is Map) {
        final first = (children.first as Map).cast<String, dynamic>();
        final d = _pickString(first, ['date'], '');
        if (d.isNotEmpty) firstDateIso = d;
      }
    }

    return _ApplyRecordItem(
      id: id,
      status: status,
      classId: classId,
      classroomId: classroomId,
      subjectId: subjectId,
      lineNum: lineNum,
      startDate: startDate,
      endDate: endDate,
      occurrences: occurrences,
      firstDateIso: firstDateIso,
      colorHex: colorHex,
      reason: reason,
      createTime: createTime,
    );
  }

  _ApplyContext toReapplyContext() {
    return _ApplyContext(
      applyId: id,
      status: status,
      classId: classId,
      lineNum: lineNum,
      dateIso: firstDateIso,
      reason: reason.isEmpty ? null : reason,
      classroomId: classroomId,
      subjectId: subjectId,
      colorHex: colorHex,
    );
  }
}

class _ApplyRecordCard extends StatelessWidget {
  const _ApplyRecordCard({
    required this.record,
    required this.classNameById,
    required this.classroomNameById,
    required this.subjectNameById,
    required this.onReapply,
  });

  final _ApplyRecordItem record;
  final Map<String, String> classNameById;
  final Map<int, String> classroomNameById;
  final Map<int, String> subjectNameById;

  /// 仅 rejected 卡片底部「重新申请」按钮才会调用；其它状态不展示按钮。
  final VoidCallback onReapply;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isRejected = record.status == _ApplyStatus.rejected;
    final className = classNameById[record.classId] ?? '';
    final classroomName = record.classroomId == null
        ? ''
        : (classroomNameById[record.classroomId!] ?? '');
    final subjectName = record.subjectId == null
        ? ''
        : (subjectNameById[record.subjectId!] ?? '');
    final headRow = <String>[
      if (className.isNotEmpty) className,
      if (subjectName.isNotEmpty) subjectName,
    ].join(' · ');
    final dateLabel = _composeDateLabel();
    final timeRow = <String>[
      if (dateLabel.isNotEmpty) dateLabel,
      if (record.lineNum > 0) '第${record.lineNum}节',
    ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(14)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ApplyStatusBadge(status: record.status),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  headRow.isEmpty ? '—' : headRow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 20 / 14,
                  ),
                ),
              ),
            ],
          ),
          if (timeRow.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            _DetailLine(label: '时间', value: timeRow),
          ],
          if (classroomName.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            _DetailLine(label: '教室', value: classroomName),
          ],
          if (record.createTime.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            _DetailLine(label: '提交', value: record.createTime),
          ],
          if (isRejected && record.reason.isNotEmpty) ...[
            SizedBox(height: ui(12)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ui(12),
                vertical: ui(10),
              ),
              decoration: BoxDecoration(
                color: _kApplyRejectedBg,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '驳回理由',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kApplyRejectedFg,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 16 / 12,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    record.reason,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isRejected) ...[
            SizedBox(height: ui(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButton(label: '重新申请', primary: true, onTap: onReapply),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// `startDate ~ endDate · 共 N 次`；单次或起止相同时简化为 `date · 共 1 次`。
  String _composeDateLabel() {
    final s = record.startDate;
    final e = record.endDate;
    final n = record.occurrences;
    String dateSeg;
    if (s.isEmpty && e.isEmpty) {
      dateSeg = '';
    } else if (s.isEmpty) {
      dateSeg = e;
    } else if (e.isEmpty || s == e) {
      dateSeg = s;
    } else {
      dateSeg = '$s ~ $e';
    }
    if (n > 0) {
      return dateSeg.isEmpty ? '共 $n 次' : '$dateSeg · 共 $n 次';
    }
    return dateSeg;
  }
}

// =============================================================================
// 申请「小课」右侧抽屉
//
// 入口：编辑模式格子内的"申请小课" pill → _onApplySmallLesson →
//      showGeneralDialog 右滑入场 → 本抽屉。
//
// 设计：宽 600，全高，白底；顶部 62 高 _DrawerHeader（3×15 紫竖条 + "申请小课"
// 16/600 标题 + 关闭 X，底部 1px #F3F2F3 边）；表单 6 段：
//   1. 课程时间：只读 #F5F6FA 灰底 48 高
//   2. 班级：调 teacher.classList(type: 1)，String id 下拉 ——
//          仅展示「我的小班」（type=1），避免把小课申请挂到大班上。
//   3. 教室：调 admin.classroomList，int id 下拉
//   4. 科目：调 user.subjectList(classId)，int id 下拉
//   5. 颜色：13 色色板 + 当前 hex chip
//   6. 是否复用：不复用 / 本学期所有 / 后续 4 周 / 后续 8 周
// 底部：560×48 紫色横向渐变 (#B68EFF→#8640FF) "提交教务审核" 按钮。
//
// 提交：调 `/app/school/v2/teacher/schoolSmallCourseApplySave`，
// 字段格式：
// ```json
// {
//   "classId": "...",       // String，雪花
//   "classroomId": 1,       // int
//   "subjectId": 1,         // int
//   "color": "#xxxxxx",
//   "lineNum": 1,
//   "startDate": "2026-05-08",
//   "endDate": "2026-05-08",
//   "courseList": [
//     {
//       "classId": "...",
//       "classroomId": 1,
//       "subjectId": 1,
//       "color": "#xxxxxx",
//       "date": "2026-05-08",
//       "lineNum": 1,
//       "teacherId": "..."   // String，当前任课老师 id（雪花）
//     }
//   ]
// }
// ```
//
// 时间字段全部使用 `yyyy-MM-dd`（不带时区后缀，按需求统一）。
// =============================================================================

class _ApplySmallLessonDrawer extends ConsumerStatefulWidget {
  const _ApplySmallLessonDrawer({
    required this.slotLabel,
    required this.baseDateIso,
    required this.lineNum,
    required this.currentWeek,
    required this.onCancel,
    required this.onSubmitted,
    this.initialClassId,
    this.initialClassroomId,
    this.initialSubjectId,
    this.initialColorHex,
  });

  /// 抽屉顶部只读"课程时间"展示，例如
  /// `第 1 节 08:00-08:40· 周一 2026-05-04`。
  final String slotLabel;

  /// 用户点击空格对应的当周日期（`yyyy-MM-dd`）。
  final String baseDateIso;

  /// 节次（与 schoolTimeConfigList.lineNum 对齐）。
  final int lineNum;

  /// 父页面当前显示的"教学周第 N 周"，复用模式按它计算还剩多少周。
  final int currentWeek;

  /// 父页面已知的默认班级（班级列表第一项）；非空时直接预选。
  final String? initialClassId;

  /// 「重新申请」场景下用驳回申请的原 classroomId 预选；
  /// 普通申请走列表第 1 项兜底。
  final String? initialClassroomId;

  /// 「重新申请」场景下用驳回申请的原 subjectId 预选；
  /// 等 _loadSubjects 拉完后会校验该 id 是否在当前班级科目里。
  final String? initialSubjectId;

  /// 「重新申请」场景下用驳回申请的原颜色（hex，含或不含 #）预选；
  /// 解析失败 / 为空则走默认 _palette[1]。
  final String? initialColorHex;

  final VoidCallback onCancel;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ApplySmallLessonDrawer> createState() =>
      _ApplySmallLessonDrawerState();
}

class _ApplySmallLessonDrawerState
    extends ConsumerState<_ApplySmallLessonDrawer> {
  // 班级 / 教室 / 科目下拉的 cache：(label, id)。
  List<({String id, String name})> _classes = const [];
  List<({String id, String name})> _classrooms = const [];
  List<({String id, String name})> _subjects = const [];

  String? _classId;
  String? _classroomId;
  String? _subjectId;
  bool _loadingSubjects = false;

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
    // 「重新申请」入口会把驳回申请的颜色透传过来；解析成功就预选这色，
    // 失败 / 空就保留默认 _palette[1]。
    final initialColor = _parseHexToColor(widget.initialColorHex);
    if (initialColor != null) _color = initialColor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOptions();
    });
  }

  /// `#A894EB` / `A894EB` / `#FF0000` → Color；不合法返回 null。
  Color? _parseHexToColor(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  Future<void> _loadOptions() async {
    // 班级走 teacher.classList(type: 1) → 仅返回我担任教师的小班；
    // 教室仍走 admin.classroomList，因为教室是全校公共资源不区分身份。
    final teacherRepo = ref.read(teacherRepositoryProvider);
    final adminRepo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      teacherRepo.classList(type: 1),
      adminRepo.classroomList(),
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
      // 父页面已选班级时优先回填；否则取列表第 1 项。
      final initial = widget.initialClassId;
      if (initial != null &&
          initial.isNotEmpty &&
          _classes.any((c) => c.id == initial)) {
        _classId = initial;
      } else {
        _classId ??= _classes.isNotEmpty ? _classes.first.id : null;
      }
      // 「重新申请」预填教室：用驳回申请的原 classroomId；不在当前列表里
      // 就回退到列表第 1 项，避免提交时引用一个不存在的 id。
      final initialRoom = widget.initialClassroomId;
      if (initialRoom != null &&
          initialRoom.isNotEmpty &&
          _classrooms.any((c) => c.id == initialRoom)) {
        _classroomId = initialRoom;
      } else {
        _classroomId ??= _classrooms.isNotEmpty ? _classrooms.first.id : null;
      }
      // 科目还没拉，先把「重新申请」希望预选的 id 兜在 _subjectId 里，
      // _loadSubjects 拉完后会校验它是否在当前班级科目里 → 不在就回退。
      if (widget.initialSubjectId != null &&
          widget.initialSubjectId!.isNotEmpty) {
        _subjectId = widget.initialSubjectId;
      }
    });
    _loadSubjects(_classId);
  }

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
      // _subjectId 已被 _loadOptions 兜成「重新申请」希望预选的 id 时，
      // 这里校验是否在当前班级的科目列表里 —— 不在 / 为空就回退到第 1 项。
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

  /// 根据 `_reuse` 选项展开成多个排课日期：
  ///   - 不复用 → 仅基准日 1 行
  ///   - 本学期所有教学周 → 从当前周开始补到第 [_kTermTotalWeeks] 周
  ///   - 后续 4 周 → 基准日 + 4 个连续周（共 5 行）
  ///   - 后续 8 周 → 基准日 + 8 个连续周（共 9 行）
  List<DateTime> _computeReuseDates() {
    final base = DateTime.tryParse(widget.baseDateIso) ?? DateTime.now();
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

  /// `2026-05-04` 格式（无时间，无时区）。
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_submitting) return;
    if (_classId == null || _classId!.isEmpty) {
      AppToast.show(context, '请先选择班级');
      return;
    }
    if (_classroomId == null || _classroomId!.isEmpty) {
      AppToast.show(context, '请先选择教室');
      return;
    }
    if (_subjectId == null || _subjectId!.isEmpty) {
      AppToast.show(context, '请先选择科目');
      return;
    }
    setState(() => _submitting = true);

    // classroomId / subjectId 后端期望 int；雪花长 classId / teacherId 走 String。
    final classroomNum = int.tryParse(_classroomId!);
    final subjectNum = int.tryParse(_subjectId!);

    // teacherId 取自当前登录的任课老师（shellState.user.id 是 myInfo.user.id 原文，
    // 雪花长以 String 承载，避免 web 端 JS Number 精度截断）。空串时省略，
    // 让后端按 token 自行解析。
    final teacherId = ref.read(shellControllerProvider).user.id;

    final dates = _computeReuseDates();
    final color = _hexLabel;
    final courseList = <Map<String, dynamic>>[
      for (final d in dates)
        <String, dynamic>{
          'classId': _classId,
          'classroomId': classroomNum ?? _classroomId,
          'subjectId': subjectNum ?? _subjectId,
          'color': color,
          'date': _ymd(d),
          'lineNum': widget.lineNum,
          if (teacherId.isNotEmpty) 'teacherId': teacherId,
        },
    ];

    final body = <String, dynamic>{
      'classId': _classId,
      'classroomId': classroomNum ?? _classroomId,
      'subjectId': subjectNum ?? _subjectId,
      'color': color,
      'lineNum': widget.lineNum,
      'startDate': _ymd(dates.first),
      'endDate': _ymd(dates.last),
      'courseList': courseList,
    };

    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplySave(body);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isEmpty ? '提交失败' : resp.msg);
      return;
    }
    if (courseList.length > 1) {
      AppToast.show(context, '已提交申请（共 ${courseList.length} 周）');
    }
    widget.onSubmitted();
  }

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
            _DrawerHeader(title: '申请小课', onClose: widget.onCancel),
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
                        _loadSubjects(v);
                      },
                    ),
                    SizedBox(height: ui(8)),
                    Text(
                      '课表展示为「小班·班级名」，无需再选教学组织形式。',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextDivider,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
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
                label: _submitting ? '提交中…' : '提交教务审核',
                onTap: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉顶部 62 高 header：3×15 紫竖条 + 标题 + 关闭 X。
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
// 通用 helpers（与 admin / 学生端一致的解析函数）
// =============================================================================

/// `status`: 1 = 已通过；2 = 已驳回；0 / null / 其他 = 待审核。
/// 顶层 helper：申请记录抽屉的 `_ApplyRecordItem.fromJson` 是静态工厂方法，
/// 没法访问 state 的实例方法，所以放成 top-level。
_ApplyStatus _parseApplyStatus(dynamic raw) {
  final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
  if (n == 1) return _ApplyStatus.passed;
  if (n == 2) return _ApplyStatus.rejected;
  return _ApplyStatus.pending;
}

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

/// 在 `jsonDecode` 前把字符串里未加引号、长度 >= 16 的纯整数字面量补上引号。
///
/// 场景：雪花长 ID（19 位）超过 2^53，Dart Web 经 JS `Number` 解码会截到
/// 相邻偶数（精度丢失）；包成字符串后 jsonDecode 当 String 保留原样。
///
/// 正则要点：
/// - 前置 lookbehind `[:,\[\s]`：保证数字串紧跟在 `:` / `,` / `[` / 空白
///   后，排除已经被引号或属于其它 token 的数字串；
/// - 后置 lookahead  `[,}\]\s]`：保证数字串紧贴 `,` / `}` / `]` / 空白结
///   束，同理。
String _preserveLongIds(String input) {
  return input.replaceAllMapped(
    RegExp(r'(?<=[:,\[\s])(\d{16,})(?=[,}\]\s])'),
    (m) => '"${m.group(1)}"',
  );
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

/// `09:00:00` → `09:00`（兼容已经是 `09:00` 的情况）。
String _trimToHm(String s) {
  if (s.isEmpty) return s;
  final parts = s.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return s;
}
