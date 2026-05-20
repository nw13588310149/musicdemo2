// =============================================================================
// 任课老师 / 班主任端「签课管理」独立页面
//
// 入口：教师 dashboard 快捷区「签课管理」按钮 → controller.openClassAttendance()
//      → mainView == classAttendance + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变；左 32 返回；居中 "签课管理"
//      16/600；右上 "历史记录" pill（紫色时钟 icon + 12/600 黑字）。
//   2. "签课数据统计" section header（18/500 #1A1A1A）+ 右侧 44 高 3 段
//      pill 切换器：总数据 / 本学期 / 本月（激活段 #0B081A 黑底白字 6 圆角）。
//   3. 5 张统计卡（一行平铺，white 100 高，12 圆角）：签课节次数 187 /
//      大班一键签到 2 / 小班签课完成 2 / 学生迟到 24 / 缺勤人次 1。
//      第一张右上加紫色渐变装饰圈，与 Figma 一致。
//   4. "最近签课记录" section + 右侧"查看全部 ›"链接 → 一行 3 张
//      312 宽白卡：时间 18/600 + 日期 12/400；课名 + 大/小课 tag；
//      第N节 副标；右侧 40 头像；底部 50 高灰底统计（应到/实到/签到方式）。
//   5. 双列：
//      · 左 340 宽 "今日课程" 面板（白底 16 圆角 12 padding）：日期 16/500
//        + 多张 316×104 时间段卡（已结束=灰底 / 进行中=淡紫底，带右上角"已结
//        束/进行中" tag）。点卡片切换右侧 active class。
//      · 右 614 宽 "签到操作" 面板：根据 active class 类型渲染：
//          - 大课：614×465 白底 16 圆角，顶部"第N节·HH:MM-HH:MM"（时间紫
//            色）+ 教师 + 课名 + 课时·教室；中部 #F5F6FA 灰底"班级学生"
//            块（6 状态 chip + 8 列 × 2 行学生网格，点击头像循环切换状态
//            present→late→leave→absent→missing→present）；下方 #F0E8FC
//            提示带（"待完成大班一键签到" + 说明文案）；最底紫色渐变
//            "一键完成全班签到" CTA 按钮。
//          - 小课：参考学生端 [StudentCheckInView] 的 _CheckInActionPanel
//            视觉（614×280 白底，灰底内面板，单学生信息 + 教师上课/下课
//            签时间轴 + 两枚 "教师上课签 / 教师下课签" 时间 pill）。
//
// 颜色：白卡 / #F5F6FA 灰底 / #F3F2F3 边 / #8741FF 主紫 / #A773FF 大课紫 /
//      #0CAC40 出勤绿 / #FF323C 缺勤红 / #325BFF 请假蓝 / #B6B5BB 提示
// 字体：PingFang SC（标题 16/18 / 正文 12/14）+ Barlow（时间 18 / 数值 32）
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 配色 -------------------------------------------------------------------
const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFA773FF);
const Color _kPurpleSoftHint = Color(0xFFF0E8FC); // 大班签到提示带 bg
const Color _kPurpleSoftBg = Color(0xFFEAE5FF); // "进行中"角标 bg
const Color _kPurpleSoftRing = Color(0xFFF7F2FF); // 时间轴外环
const Color _kInProgressCardBg = Color(0xFFF4F4FF); // 今日课程"进行中"卡 bg
const Color _kEndedTagBg = Color(0xFFE6E9F1);
const Color _kCourseTagBg = Color(0xFFDFFCF0); // 古筝课 tag 绿底
const Color _kCourseTagFg = Color(0xFF0CAC40);
const Color _kStatusPresent = Color(0xFF0CAC40); // 实到
const Color _kStatusLate = Color(0xFFFF323C); // 迟到 / 缺课 / 未到
const Color _kStatusLeave = Color(0xFF325BFF); // 请假
const Color _kBigClassDot = Color(0xFFA773FF); // 大课 tag dot

// ---- 数据模型 ---------------------------------------------------------------

/// 课程类型：大课走班级名单网格 + 一键签到；小课走单学生 + 教师上下课签时间轴。
enum _ClassKind { big, small }

/// 课程进行状态：影响今日课程卡的底色（已结束=灰，进行中=淡紫）以及
/// 角标文本（已结束 / 进行中 / 待开始）。
enum _ClassRunState { ended, inProgress, upcoming }

/// 学生考勤状态。点击头像循环切换：
/// present(实到/绿) → late(迟到/红) → leave(请假/蓝) → absent(缺课/红) →
/// missing(未到/红) → present。
enum _AttendStatus { present, late, leave, absent, missing }

class _StudentAttend {
  _StudentAttend({required this.name, required this.status});
  final String name;
  _AttendStatus status;
}

class _AttendClass {
  _AttendClass({
    required this.periodIndex,
    required this.startTime,
    required this.endTime,
    required this.teacherName,
    required this.courseName,
    required this.duration,
    required this.location,
    required this.kind,
    required this.runState,
    required this.students,
    this.singleStudent,
  });

  final int periodIndex;
  final String startTime;
  final String endTime;
  final String teacherName;
  final String courseName;
  final String duration;
  final String location;
  final _ClassKind kind;
  final _ClassRunState runState;

  /// 班级学生名单（大课用）。小课时通常仅 1 项，但保持同字段方便共享。
  final List<_StudentAttend> students;

  /// 小课模式下右侧面板展示的"主学生"（教师 1 对 1 课表）；当 [kind] = big
  /// 时为 null。Figma 中小课卡片的展示主体是这位学生的头像 + 信息。
  final String? singleStudent;
}

class _StatItem {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;
}

class _RecentRecord {
  const _RecentRecord({
    required this.time,
    required this.date,
    required this.courseName,
    required this.kind,
    required this.periodLabel,
    required this.teacherName,
    required this.expected,
    required this.present,
    required this.method,
  });

  final String time;
  final String date;
  final String courseName;
  final _ClassKind kind;
  final String periodLabel;
  final String teacherName;
  final int expected;
  final int present;
  final String method;
}

// =============================================================================
// 入口 widget
// =============================================================================

class TeacherClassAttendanceView extends StatefulWidget {
  const TeacherClassAttendanceView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TeacherClassAttendanceView> createState() =>
      _TeacherClassAttendanceViewState();
}

class _TeacherClassAttendanceViewState
    extends State<TeacherClassAttendanceView> {
  /// 0 = 总数据 / 1 = 本学期 / 2 = 本月。仅切换 stat 卡数值，不调接口（demo）。
  int _selectedTabIdx = 0;

  /// 双列右侧 active class 索引；默认指向"进行中"那节课。
  late int _activeClassIdx;

  late List<_AttendClass> _classes;

  /// 是否切到「历史记录」子页面（banner 右上"历史记录"按钮 / "查看全部"
  /// 链接触发）。子页面 banner 的返回按钮把它置回 false，回到本主页。
  bool _showHistory = false;

  /// 历史记录子页面的过滤模式：0=全部 / 1=大班 / 2=小班。
  int _historyFilterIdx = 0;

  /// 历史记录子页面的搜索文本（课程、节次、教室）。
  String _historyQuery = '';

  @override
  void initState() {
    super.initState();
    _classes = _buildInitialClasses();
    // 进行中的课优先展示；否则取第一节。
    final inProgress = _classes.indexWhere(
      (c) => c.runState == _ClassRunState.inProgress,
    );
    _activeClassIdx = inProgress >= 0 ? inProgress : 0;
  }

  void _selectClass(int idx) {
    if (_activeClassIdx == idx) return;
    setState(() => _activeClassIdx = idx);
  }

  void _cycleStudentStatus(int studentIdx) {
    setState(() {
      final s = _classes[_activeClassIdx].students[studentIdx];
      const order = _AttendStatus.values;
      s.status = order[(s.status.index + 1) % order.length];
    });
  }

  void _bulkSign() {
    setState(() {
      for (final s in _classes[_activeClassIdx].students) {
        if (s.status == _AttendStatus.missing) {
          s.status = _AttendStatus.present;
        }
      }
    });
    AppToast.show(context, '已完成全班签到');
  }

  void _openHistory() {
    if (_showHistory) return;
    setState(() => _showHistory = true);
  }

  void _closeHistory() {
    if (!_showHistory) return;
    setState(() => _showHistory = false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (_showHistory) {
      return _HistoryView(
        onBack: _closeHistory,
        filterIdx: _historyFilterIdx,
        onFilter: (i) => setState(() => _historyFilterIdx = i),
        query: _historyQuery,
        onQueryChanged: (v) => setState(() => _historyQuery = v),
      );
    }
    final stats = _statsForTab(_selectedTabIdx);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AttendanceBanner(onBack: widget.onBack, onOpenHistory: _openHistory),
          SizedBox(height: ui(16)),
          _StatsHeaderRow(
            tabIdx: _selectedTabIdx,
            onTab: (i) => setState(() => _selectedTabIdx = i),
          ),
          SizedBox(height: ui(12)),
          _StatsRow(stats: stats),
          SizedBox(height: ui(24)),
          _SectionHeaderRow(
            title: '最近签课记录',
            trailingLabel: '查看全部',
            onTrailingTap: _openHistory,
          ),
          SizedBox(height: ui(12)),
          _RecentRecordsRow(records: _kDemoRecentRecords),
          SizedBox(height: ui(28)),
          // 双列：今日课程 + 签到操作
          LayoutBuilder(
            builder: (context, c) {
              final isCompact = c.maxWidth < ui(720);
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('今日课程'),
                    SizedBox(height: ui(12)),
                    _TodayClassesPanel(
                      title: _todayPanelTitle(),
                      classes: _classes,
                      activeIdx: _activeClassIdx,
                      onSelect: _selectClass,
                    ),
                    SizedBox(height: ui(20)),
                    _SectionTitle('签到操作'),
                    SizedBox(height: ui(12)),
                    _ActionPanelSwitcher(
                      data: _classes[_activeClassIdx],
                      onCycleStudent: _cycleStudentStatus,
                      onBulkSign: _bulkSign,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: ui(340),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('今日课程'),
                        SizedBox(height: ui(12)),
                        _TodayClassesPanel(
                          title: _todayPanelTitle(),
                          classes: _classes,
                          activeIdx: _activeClassIdx,
                          onSelect: _selectClass,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: ui(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('签到操作'),
                        SizedBox(height: ui(12)),
                        _ActionPanelSwitcher(
                          data: _classes[_activeClassIdx],
                          onCycleStudent: _cycleStudentStatus,
                          onBulkSign: _bulkSign,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _todayPanelTitle() {
    // 与 Figma 一致：固定到 demo 日期；接入接口时可改为 DateTime.now()。
    return '2026年4月2日 周三';
  }

  List<_StatItem> _statsForTab(int idx) {
    switch (idx) {
      case 1:
        return const [
          _StatItem(value: '128', label: '签课节次数'),
          _StatItem(value: '4', label: '大班一键签到'),
          _StatItem(value: '6', label: '小班签课完成'),
          _StatItem(value: '12', label: '学生迟到'),
          _StatItem(value: '3', label: '缺勤人次'),
        ];
      case 2:
        return const [
          _StatItem(value: '32', label: '签课节次数'),
          _StatItem(value: '1', label: '大班一键签到'),
          _StatItem(value: '2', label: '小班签课完成'),
          _StatItem(value: '4', label: '学生迟到'),
          _StatItem(value: '0', label: '缺勤人次'),
        ];
      case 0:
      default:
        return const [
          _StatItem(value: '187', label: '签课节次数'),
          _StatItem(value: '2', label: '大班一键签到'),
          _StatItem(value: '2', label: '小班签课完成'),
          _StatItem(value: '24', label: '学生迟到'),
          _StatItem(value: '1', label: '缺勤人次'),
        ];
    }
  }
}

// =============================================================================
// 顶部 banner（62 高）
// =============================================================================

class _AttendanceBanner extends StatelessWidget {
  const _AttendanceBanner({required this.onBack, required this.onOpenHistory});

  final VoidCallback onBack;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
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
                '签课管理',
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
            right: ui(12),
            top: ui(14),
            child: InkWell(
              onTap: onOpenHistory,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                height: ui(34),
                padding: EdgeInsets.symmetric(horizontal: ui(12)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: ui(16), color: _kPurple),
                    SizedBox(width: ui(4)),
                    Text(
                      '历史记录',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 签课数据统计 header（标题 + 3 段 tab 切换器）
// =============================================================================

class _StatsHeaderRow extends StatelessWidget {
  const _StatsHeaderRow({required this.tabIdx, required this.onTab});

  final int tabIdx;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const labels = ['总数据', '本学期', '本月'];
    return Row(
      children: [
        Expanded(
          child: Text(
            '签课数据统计',
            style: TextStyle(
              fontSize: ui(18),
              color: _kTextSection,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft),
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) SizedBox(width: ui(4)),
                _SegmentChip(
                  label: labels[i],
                  selected: i == tabIdx,
                  onTap: () => onTab(i),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
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
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: selected ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5 张统计卡（一行平铺，white 100 高）
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: ui(12)),
          Expanded(
            child: _StatCard(item: stats[i], showAccent: i == 0),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item, this.showAccent = false});

  final _StatItem item;

  /// 第一张卡（签课节次数）右上贴一组紫色渐变装饰圈（与 Figma 一致）。
  final bool showAccent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(16)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (showAccent)
            Positioned(
              right: ui(0),
              top: ui(0),
              child: SizedBox(
                width: ui(72),
                height: ui(72),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: ui(54),
                        height: ui(51),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _kPurpleLight.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: ui(8),
                      top: ui(34),
                      child: Container(
                        width: ui(18),
                        height: ui(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _kPurpleLight.withValues(alpha: 0.20),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontSize: ui(14),
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
              Text(
                item.value,
                style: TextStyle(
                  fontSize: ui(32),
                  color: _kTextDark,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// section 公共 header
// =============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(18),
        color: _kTextSection,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1,
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    required this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle(title)),
        InkWell(
          onTap: onTrailingTap,
          borderRadius: BorderRadius.circular(ui(6)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
                SizedBox(width: ui(2)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: ui(16),
                  color: const Color(0xFFCECED1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 最近签课记录（一行 3 张 312 宽白卡）
// =============================================================================

class _RecentRecordsRow extends StatelessWidget {
  const _RecentRecordsRow({required this.records});

  final List<_RecentRecord> records;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0) SizedBox(width: ui(16)),
          Expanded(child: _RecentRecordCard(record: records[i])),
        ],
      ],
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({required this.record});

  final _RecentRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 时间 + 日期
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                record.time,
                style: TextStyle(
                  fontSize: ui(18),
                  color: _kTextSection,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                record.date,
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
          SizedBox(height: ui(12)),
          // 课名 + tag + 节次（左）+ 头像（右）
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          record.courseName,
                          style: TextStyle(
                            fontSize: ui(14),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                            height: 1,
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        _ClassKindTag(kind: record.kind),
                      ],
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      record.periodLabel,
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
              SizedBox(width: ui(8)),
              _Avatar(seed: record.teacherName, size: ui(40)),
            ],
          ),
          SizedBox(height: ui(12)),
          // 底部统计：应到 / 实到 / 签到方式。
          // 不写死 50 高 —— Figma 50 高在 1.0 文字缩放下勉强容下 12+5+12，
          // 但只要稍微放大字体就会底部溢出 ~10px。改为 padding 自然撑高。
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: ui(10), horizontal: ui(8)),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _RecordStatCol('应到', '${record.expected}人')),
                  Expanded(child: _RecordStatCol('实到', '${record.present}人')),
                  Expanded(child: _RecordStatCol('签到方式', record.method)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordStatCol extends StatelessWidget {
  const _RecordStatCol(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
        SizedBox(height: ui(4)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 大/小课 tag（白底浅边 + 4 圆 + 6×6 dot + 11/400 文字）
// =============================================================================

class _ClassKindTag extends StatelessWidget {
  const _ClassKindTag({required this.kind});

  final _ClassKind kind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isSmall = kind == _ClassKind.small;
    return Container(
      height: ui(16),
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(color: _kBorderSoft, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(
              color: isSmall ? _kStatusPresent : _kBigClassDot,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            isSmall ? '小课' : '大课',
            style: TextStyle(
              fontSize: ui(11),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseGreenTag extends StatelessWidget {
  const _CourseGreenTag({required this.courseName});

  final String courseName;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(16),
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: _kCourseTagBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      alignment: Alignment.center,
      child: Text(
        courseName,
        style: TextStyle(
          fontSize: ui(11),
          color: _kCourseTagFg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 14 / 11,
        ),
      ),
    );
  }
}

// =============================================================================
// 今日课程面板（左 340 宽）
// =============================================================================

class _TodayClassesPanel extends StatelessWidget {
  const _TodayClassesPanel({
    required this.title,
    required this.classes,
    required this.activeIdx,
    required this.onSelect,
  });

  final String title;
  final List<_AttendClass> classes;
  final int activeIdx;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextSection,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
          SizedBox(height: ui(12)),
          for (var i = 0; i < classes.length; i++) ...[
            if (i > 0) SizedBox(height: ui(8)),
            _TodayClassCard(
              data: classes[i],
              isActive: i == activeIdx,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  const _TodayClassCard({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  final _AttendClass data;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEnded = data.runState == _ClassRunState.ended;
    final isInProgress = data.runState == _ClassRunState.inProgress;
    final bg = isInProgress ? _kInProgressCardBg : _kInnerGray;
    final tagBg = isInProgress ? _kPurpleSoftBg : _kEndedTagBg;
    final tagFg = isInProgress ? _kTextDark : _kTextHint;
    final tagText = isInProgress
        ? '进行中'
        : isEnded
        ? '已结束'
        : '待开始';
    final mainStudent =
        data.singleStudent ??
        (data.students.isNotEmpty ? data.students.first.name : '');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: ui(104),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ui(12)),
              border: isActive
                  ? Border.all(color: _kPurple.withValues(alpha: 0.6), width: 1)
                  : null,
            ),
            child: Stack(
              children: [
                // 角标
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: ui(68),
                    height: ui(22),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(ui(12)),
                        bottomLeft: Radius.circular(ui(12)),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tagText,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: tagFg,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                // 时间段
                Positioned(
                  left: ui(16),
                  top: ui(12),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: ui(18),
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      children: [
                        TextSpan(
                          text: '${data.startTime} ',
                          style: const TextStyle(color: _kTextSection),
                        ),
                        const TextSpan(
                          text: '- ',
                          style: TextStyle(color: _kTextHint),
                        ),
                        TextSpan(
                          text: data.endTime,
                          style: const TextStyle(color: _kTextSection),
                        ),
                      ],
                    ),
                  ),
                ),
                // 头像
                Positioned(
                  left: ui(16),
                  top: ui(48),
                  child: _Avatar(seed: mainStudent, size: ui(40)),
                ),
                // 学生信息
                Positioned(
                  left: ui(64),
                  top: ui(50),
                  right: ui(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mainStudent,
                            style: TextStyle(
                              fontSize: ui(14),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w600,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: ui(4)),
                          _CourseGreenTag(courseName: data.courseName),
                          SizedBox(width: ui(4)),
                          _ClassKindTag(kind: data.kind),
                        ],
                      ),
                      SizedBox(height: ui(4)),
                      Text(
                        '${data.duration}·${data.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 签到操作 — 大/小课分发
// =============================================================================

class _ActionPanelSwitcher extends StatelessWidget {
  const _ActionPanelSwitcher({
    required this.data,
    required this.onCycleStudent,
    required this.onBulkSign,
  });

  final _AttendClass data;
  final ValueChanged<int> onCycleStudent;
  final VoidCallback onBulkSign;

  @override
  Widget build(BuildContext context) {
    if (data.kind == _ClassKind.big) {
      return _BigClassActionPanel(
        data: data,
        onCycleStudent: onCycleStudent,
        onBulkSign: onBulkSign,
      );
    }
    return _SmallClassActionPanel(data: data);
  }
}

// =============================================================================
// 大课签到面板（614 宽 × 465 高）
// =============================================================================

class _BigClassActionPanel extends StatelessWidget {
  const _BigClassActionPanel({
    required this.data,
    required this.onCycleStudent,
    required this.onBulkSign,
  });

  final _AttendClass data;
  final ValueChanged<int> onCycleStudent;
  final VoidCallback onBulkSign;

  int _countOf(_AttendStatus s) =>
      data.students.where((e) => e.status == s).length;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：第N节·HH:MM-HH:MM（时间紫色）
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
              children: [
                TextSpan(
                  text: '第${data.periodIndex}节·',
                  style: const TextStyle(color: _kTextSection),
                ),
                TextSpan(
                  text: '${data.startTime}-${data.endTime}',
                  style: const TextStyle(color: _kPurple),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(20)),
          // 教师信息行：头像 + 姓名 + 时长·教室 + 课程 tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(seed: data.teacherName, size: ui(40)),
              SizedBox(width: ui(6)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.teacherName,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      '${data.duration}·${data.location}',
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
              _CourseGreenTag(courseName: data.courseName),
            ],
          ),
          SizedBox(height: ui(16)),
          // 班级学生（灰底面板）
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(ui(12), ui(14), ui(12), ui(16)),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '班级学生',
                        style: TextStyle(
                          fontSize: ui(16),
                          color: Colors.black,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 20 / 16,
                        ),
                      ),
                    ),
                    Text(
                      '点击头像可更改状态',
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
                SizedBox(height: ui(12)),
                // 6 状态 chip（应到/实到/迟到/请假/缺课/未到）
                Wrap(
                  spacing: ui(8),
                  runSpacing: ui(8),
                  children: [
                    _StatusChip(
                      label: '应到',
                      count: data.students.length,
                      dotColor: const Color(0xFFD9D9D9),
                    ),
                    _StatusChip(
                      label: '实到',
                      count: _countOf(_AttendStatus.present),
                      dotColor: _kStatusPresent,
                    ),
                    _StatusChip(
                      label: '迟到',
                      count: _countOf(_AttendStatus.late),
                      dotColor: _kStatusLate,
                    ),
                    _StatusChip(
                      label: '请假',
                      count: _countOf(_AttendStatus.leave),
                      dotColor: _kStatusLeave,
                    ),
                    _StatusChip(
                      label: '缺课',
                      count: _countOf(_AttendStatus.absent),
                      dotColor: _kStatusLate,
                    ),
                    _StatusChip(
                      label: '未到',
                      count: _countOf(_AttendStatus.missing),
                      dotColor: _kStatusLate,
                    ),
                  ],
                ),
                SizedBox(height: ui(16)),
                // 学生网格：8 列，自动分行
                _StudentAttendGrid(
                  students: data.students,
                  onTapStudent: onCycleStudent,
                ),
              ],
            ),
          ),
          SizedBox(height: ui(12)),
          // 提示带：待完成大班一键签到
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(12), ui(8)),
            decoration: BoxDecoration(
              color: _kPurpleSoftHint,
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: _kBorderSoft, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '待完成大班一键签到',
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  '可先核对名单并修改状态，再点击下方完成全班签到；完成后学生端展示到课结果。',
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 14 / 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(12)),
          // CTA：一键完成全班签到
          InkWell(
            onTap: onBulkSign,
            borderRadius: BorderRadius.circular(ui(12)),
            child: Container(
              width: double.infinity,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    size: ui(20),
                    color: Colors.white,
                  ),
                  SizedBox(width: ui(4)),
                  Text(
                    '一键完成全班签到',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.dotColor,
  });

  final String label;
  final int count;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(24),
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(8),
            height: ui(8),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            '$count',
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
    );
  }
}

class _StudentAttendGrid extends StatelessWidget {
  const _StudentAttendGrid({
    required this.students,
    required this.onTapStudent,
  });

  final List<_StudentAttend> students;
  final ValueChanged<int> onTapStudent;

  static const int _columns = 8;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rows = <Widget>[];
    for (var r = 0; r * _columns < students.length; r++) {
      final rowItems = <Widget>[];
      for (var c = 0; c < _columns; c++) {
        final idx = r * _columns + c;
        if (idx >= students.length) {
          rowItems.add(SizedBox(width: ui(60)));
        } else {
          rowItems.add(
            _StudentAttendCell(
              student: students[idx],
              onTap: () => onTapStudent(idx),
            ),
          );
        }
      }
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rowItems,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: ui(12)),
          rows[i],
        ],
      ],
    );
  }
}

class _StudentAttendCell extends StatelessWidget {
  const _StudentAttendCell({required this.student, required this.onTap});

  final _StudentAttend student;
  final VoidCallback onTap;

  Color _dotColorFor(_AttendStatus s) {
    switch (s) {
      case _AttendStatus.present:
        return _kStatusPresent;
      case _AttendStatus.leave:
        return _kStatusLeave;
      case _AttendStatus.late:
      case _AttendStatus.absent:
      case _AttendStatus.missing:
        return _kStatusLate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(20)),
      child: SizedBox(
        width: ui(60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _Avatar(seed: student.name, size: ui(36)),
                Positioned(
                  right: ui(-2),
                  bottom: ui(-2),
                  child: Container(
                    width: ui(10),
                    height: ui(10),
                    decoration: BoxDecoration(
                      color: _dotColorFor(student.status),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ui(4)),
            Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 小课签到面板（614 宽 × ~280 高，参考学生端 _CheckInActionPanel）
// =============================================================================

class _SmallClassActionPanel extends StatefulWidget {
  const _SmallClassActionPanel({required this.data});

  final _AttendClass data;

  @override
  State<_SmallClassActionPanel> createState() => _SmallClassActionPanelState();
}

class _SmallClassActionPanelState extends State<_SmallClassActionPanel> {
  String? _signedStartTime;
  String? _signedEndTime;

  String _now() {
    final now = TimeOfDay.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(DateTime.now().second)}';
  }

  void _onSignStart() {
    setState(() => _signedStartTime = _now());
  }

  void _onSignEnd() {
    setState(() => _signedEndTime = _now());
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = widget.data;
    final mainStudent =
        data.singleStudent ??
        (data.students.isNotEmpty ? data.students.first.name : '学生');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
              children: [
                TextSpan(
                  text: '第${data.periodIndex}节·',
                  style: const TextStyle(color: _kTextSection),
                ),
                TextSpan(
                  text: '${data.startTime}-${data.endTime}',
                  style: const TextStyle(color: _kPurple),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(16)),
          // 灰底面板：单学生 + 时间轴 + 上下课签按钮
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(16)),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 学生信息
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(seed: mainStudent, size: ui(40)),
                    SizedBox(width: ui(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                mainStudent,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w600,
                                  height: 1,
                                ),
                              ),
                              SizedBox(width: ui(4)),
                              _CourseGreenTag(courseName: data.courseName),
                              SizedBox(width: ui(4)),
                              _ClassKindTag(kind: data.kind),
                            ],
                          ),
                          SizedBox(height: ui(4)),
                          Text(
                            '${data.duration}·${data.location}',
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
                SizedBox(height: ui(16)),
                // 时间轴 + 上下课签
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui(8)),
                  child: SizedBox(
                    height: ui(14),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: ui(7),
                          right: ui(7),
                          top: ui(7),
                          child: Container(height: 1, color: _kBorderHair),
                        ),
                        Positioned(left: 0, top: 0, child: _TimelineDot()),
                        Positioned(right: 0, top: 0, child: _TimelineDot()),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: ui(8)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TeacherSignSlot(
                        title: '教师上课签',
                        signedTime: _signedStartTime,
                        onSign: _onSignStart,
                        actionLabel: '上课签',
                      ),
                    ),
                    Expanded(
                      child: _TeacherSignSlot(
                        title: '教师下课签',
                        signedTime: _signedEndTime,
                        onSign: _onSignEnd,
                        actionLabel: '下课签',
                        // 必须先签上课，才能签下课
                        enabled: _signedStartTime != null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherSignSlot extends StatelessWidget {
  const _TeacherSignSlot({
    required this.title,
    required this.signedTime,
    required this.onSign,
    required this.actionLabel,
    this.enabled = true,
  });

  final String title;
  final String? signedTime;
  final VoidCallback onSign;
  final String actionLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final signed = signedTime != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(8)),
        signed
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(10),
                  vertical: ui(6),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: ui(14),
                      color: _kPurple,
                    ),
                    SizedBox(width: ui(4)),
                    Text(
                      signedTime!,
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextDark,
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              )
            : Opacity(
                opacity: enabled ? 1 : 0.45,
                child: InkWell(
                  onTap: enabled ? onSign : null,
                  borderRadius: BorderRadius.circular(ui(6)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(12),
                      vertical: ui(6),
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                      ),
                      borderRadius: BorderRadius.circular(ui(6)),
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(14),
      height: ui(14),
      decoration: const BoxDecoration(
        color: _kPurpleSoftRing,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: ui(9),
        height: ui(9),
        decoration: BoxDecoration(
          color: _kPurple,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
        ),
      ),
    );
  }
}

// =============================================================================
// 简易头像（颜色 hash + 首字母占位，避免 Figma `placehold.co` 出网图）
// =============================================================================

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, required this.size});

  final String seed;
  final double size;

  static const List<List<Color>> _palettes = [
    [Color(0xFFC1A6FF), Color(0xFF8741FF)],
    [Color(0xFFFFB892), Color(0xFFE56B26)],
    [Color(0xFF8DC8FF), Color(0xFF1B6BE0)],
    [Color(0xFF8AE6B4), Color(0xFF12A050)],
    [Color(0xFFFFAEC2), Color(0xFFE94B6F)],
    [Color(0xFFFFD589), Color(0xFFD8851A)],
  ];

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    final palette = _palettes[hash % _palettes.length];
    final initial = seed.isEmpty ? '?' : seed.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w600,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 初始 demo 数据
// =============================================================================

const List<_RecentRecord> _kDemoRecentRecords = [
  _RecentRecord(
    time: '08:54',
    date: '2026-04-01',
    courseName: '钢琴副项',
    kind: _ClassKind.small,
    periodLabel: '第三节',
    teacherName: '郝江',
    expected: 60,
    present: 58,
    method: '教师一键签到',
  ),
  _RecentRecord(
    time: '08:54',
    date: '2026-04-01',
    courseName: '视唱练耳',
    kind: _ClassKind.big,
    periodLabel: '第三节',
    teacherName: '陈老师',
    expected: 60,
    present: 58,
    method: '扫码签到',
  ),
  _RecentRecord(
    time: '08:54',
    date: '2026-04-01',
    courseName: '钢琴副项',
    kind: _ClassKind.big,
    periodLabel: '第三节',
    teacherName: '郝江',
    expected: 60,
    present: 58,
    method: '教师一键签到',
  ),
];

List<_AttendClass> _buildInitialClasses() {
  return [
    _AttendClass(
      periodIndex: 1,
      startTime: '07:00',
      endTime: '07:45',
      teacherName: '陈江凯',
      courseName: '古筝课',
      duration: '45分钟',
      location: '艺术楼 报告厅',
      kind: _ClassKind.small,
      runState: _ClassRunState.ended,
      students: [_StudentAttend(name: '陈江凯', status: _AttendStatus.present)],
      singleStudent: '陈江凯',
    ),
    _AttendClass(
      periodIndex: 2,
      startTime: '08:35',
      endTime: '09:25',
      teacherName: '郝江',
      courseName: '古筝课',
      duration: '45分钟',
      location: '艺术楼 报告厅',
      kind: _ClassKind.small,
      runState: _ClassRunState.ended,
      students: [_StudentAttend(name: '郝江', status: _AttendStatus.present)],
      singleStudent: '郝江',
    ),
    _AttendClass(
      periodIndex: 3,
      startTime: '10:00',
      endTime: '10:45',
      teacherName: '郝江',
      courseName: '视唱练耳',
      duration: '45分钟',
      location: '艺术楼 报告厅',
      kind: _ClassKind.big,
      runState: _ClassRunState.inProgress,
      students: [
        _StudentAttend(name: '赵子峰', status: _AttendStatus.present),
        _StudentAttend(name: '周兆贤', status: _AttendStatus.present),
        _StudentAttend(name: '冯俊', status: _AttendStatus.present),
        _StudentAttend(name: '王本强', status: _AttendStatus.present),
        _StudentAttend(name: '钱亮', status: _AttendStatus.present),
        _StudentAttend(name: '周蓓蓓', status: _AttendStatus.present),
        _StudentAttend(name: '李俊卓', status: _AttendStatus.present),
        _StudentAttend(name: '吴洁莉', status: _AttendStatus.absent),
        _StudentAttend(name: '孙正芸', status: _AttendStatus.leave),
        _StudentAttend(name: '赵小瑞', status: _AttendStatus.late),
        _StudentAttend(name: '孙杰', status: _AttendStatus.leave),
        _StudentAttend(name: '王琴', status: _AttendStatus.missing),
      ],
    ),
    _AttendClass(
      periodIndex: 4,
      startTime: '14:00',
      endTime: '14:45',
      teacherName: '陈江凯',
      courseName: '钢琴副项',
      duration: '45分钟',
      location: '艺术楼 301',
      kind: _ClassKind.small,
      runState: _ClassRunState.upcoming,
      students: [_StudentAttend(name: '陈江凯', status: _AttendStatus.missing)],
      singleStudent: '陈江凯',
    ),
  ];
}

// =============================================================================
// 历史记录 子页面
//   - 顶部 banner（白→#F9EDFF 渐变 16 圆角，左 32 返回 + 居中 "历史记录"）
//   - 控制条（44 高）：左侧 全部 / 大班 / 小班 三段 pill 切换；右侧 324×44
//     白底搜索框（占位 "课程、节次、教室"）
//   - 多个日期 section：日期 16/500 + 一行最多 3 张 312 宽签课卡
//     （时间 + 节次 / 大小课 tag / 课名 + 教室 / 头像 / 灰底应到-实到-签到方式）
// =============================================================================

class _HistoryRecord {
  const _HistoryRecord({
    required this.time,
    required this.periodLabel,
    required this.courseName,
    required this.kind,
    required this.location,
    required this.teacherName,
    required this.expected,
    required this.present,
    required this.method,
  });

  final String time;
  final String periodLabel;
  final String courseName;
  final _ClassKind kind;
  final String location;
  final String teacherName;
  final int expected;
  final int present;
  final String method;
}

class _HistoryDay {
  const _HistoryDay({required this.date, required this.records});
  final String date;
  final List<_HistoryRecord> records;
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.onBack,
    required this.filterIdx,
    required this.onFilter,
    required this.query,
    required this.onQueryChanged,
  });

  final VoidCallback onBack;
  final int filterIdx;
  final ValueChanged<int> onFilter;
  final String query;
  final ValueChanged<String> onQueryChanged;

  bool _matchKind(_ClassKind k) {
    switch (filterIdx) {
      case 1:
        return k == _ClassKind.big;
      case 2:
        return k == _ClassKind.small;
      case 0:
      default:
        return true;
    }
  }

  bool _matchQuery(_HistoryRecord r) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    return r.courseName.toLowerCase().contains(q) ||
        r.periodLabel.toLowerCase().contains(q) ||
        r.location.toLowerCase().contains(q) ||
        r.teacherName.toLowerCase().contains(q) ||
        r.method.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filteredDays = <_HistoryDay>[];
    for (final day in _kDemoHistoryDays) {
      final keep = day.records
          .where((r) => _matchKind(r.kind) && _matchQuery(r))
          .toList();
      if (keep.isNotEmpty) {
        filteredDays.add(_HistoryDay(date: day.date, records: keep));
      }
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryBanner(onBack: onBack),
          SizedBox(height: ui(16)),
          _HistoryFilterRow(
            filterIdx: filterIdx,
            onFilter: onFilter,
            query: query,
            onQueryChanged: onQueryChanged,
          ),
          SizedBox(height: ui(24)),
          if (filteredDays.isEmpty)
            _HistoryEmptyState(query: query)
          else
            for (var i = 0; i < filteredDays.length; i++) ...[
              if (i > 0) SizedBox(height: ui(16)),
              _HistoryDaySection(day: filteredDays[i]),
            ],
        ],
      ),
    );
  }
}

class _HistoryBanner extends StatelessWidget {
  const _HistoryBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
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
                '历史记录',
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
        ],
      ),
    );
  }
}

class _HistoryFilterRow extends StatelessWidget {
  const _HistoryFilterRow({
    required this.filterIdx,
    required this.onFilter,
    required this.query,
    required this.onQueryChanged,
  });

  final int filterIdx;
  final ValueChanged<int> onFilter;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const labels = ['全部', '大班', '小班'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft),
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) SizedBox(width: ui(4)),
                _SegmentChip(
                  label: labels[i],
                  selected: i == filterIdx,
                  onTap: () => onFilter(i),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: ui(324),
          child: _HistorySearchField(
            initialText: query,
            onChanged: onQueryChanged,
          ),
        ),
      ],
    );
  }
}

class _HistorySearchField extends StatefulWidget {
  const _HistorySearchField({
    required this.initialText,
    required this.onChanged,
  });

  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_HistorySearchField> createState() => _HistorySearchFieldState();
}

class _HistorySearchFieldState extends State<_HistorySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: ui(18),
            color: const Color(0xFFC6C6C6),
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: ui(12)),
                border: InputBorder.none,
                hintText: '课程、节次、教室',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFFD1D1D1),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDaySection extends StatelessWidget {
  const _HistoryDaySection({required this.day});

  final _HistoryDay day;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day.date,
          style: TextStyle(
            fontSize: ui(16),
            color: _kTextSection,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1,
          ),
        ),
        SizedBox(height: ui(12)),
        Wrap(
          spacing: ui(16),
          runSpacing: ui(16),
          children: [
            for (final r in day.records)
              SizedBox(
                width: ui(312),
                child: _HistoryRecordCard(record: r),
              ),
          ],
        ),
      ],
    );
  }
}

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({required this.record});

  final _HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 时间 + 节次
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                record.time,
                style: TextStyle(
                  fontSize: ui(18),
                  color: _kTextSection,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                record.periodLabel,
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
          SizedBox(height: ui(12)),
          // 大/小课 tag 单独一行
          _ClassKindTag(kind: record.kind),
          SizedBox(height: ui(12)),
          // 课名 + 教室（左）+ 头像（右）
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.courseName,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      record.location,
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
              SizedBox(width: ui(8)),
              _Avatar(seed: record.teacherName, size: ui(40)),
            ],
          ),
          SizedBox(height: ui(12)),
          // 底部统计：应到 / 实到 / 签到方式
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: ui(10), horizontal: ui(8)),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _RecordStatCol('应到', '${record.expected}人')),
                  Expanded(child: _RecordStatCol('实到', '${record.present}人')),
                  Expanded(child: _RecordStatCol('签到方式', record.method)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasQuery = query.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: ui(40), color: _kTextHint),
          SizedBox(height: ui(12)),
          Text(
            hasQuery ? '没有符合条件的签课记录' : '暂无历史签课记录',
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
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

const List<_HistoryDay> _kDemoHistoryDays = [
  _HistoryDay(
    date: '2026年4月2日 周四',
    records: [
      _HistoryRecord(
        time: '08:54',
        periodLabel: '第三节',
        courseName: '钢琴副项',
        kind: _ClassKind.small,
        location: '艺术楼',
        teacherName: '郝江',
        expected: 60,
        present: 58,
        method: '教师一键签到',
      ),
      _HistoryRecord(
        time: '10:20',
        periodLabel: '第四节',
        courseName: '视唱练耳',
        kind: _ClassKind.big,
        location: '艺术楼',
        teacherName: '陈老师',
        expected: 60,
        present: 58,
        method: '扫码签到',
      ),
      _HistoryRecord(
        time: '14:00',
        periodLabel: '第六节',
        courseName: '钢琴副项',
        kind: _ClassKind.big,
        location: '艺术楼',
        teacherName: '郝江',
        expected: 60,
        present: 58,
        method: '教师一键签到',
      ),
    ],
  ),
  _HistoryDay(
    date: '2026年4月1日 周三',
    records: [
      _HistoryRecord(
        time: '08:54',
        periodLabel: '第三节',
        courseName: '钢琴副项',
        kind: _ClassKind.small,
        location: '艺术楼',
        teacherName: '郝江',
        expected: 60,
        present: 58,
        method: '教师一键签到',
      ),
      _HistoryRecord(
        time: '10:20',
        periodLabel: '第四节',
        courseName: '视唱练耳',
        kind: _ClassKind.big,
        location: '艺术楼',
        teacherName: '陈老师',
        expected: 60,
        present: 58,
        method: '扫码签到',
      ),
    ],
  ),
  _HistoryDay(
    date: '2026年3月31日 周二',
    records: [
      _HistoryRecord(
        time: '08:54',
        periodLabel: '第三节',
        courseName: '钢琴副项',
        kind: _ClassKind.small,
        location: '艺术楼',
        teacherName: '郝江',
        expected: 60,
        present: 58,
        method: '教师一键签到',
      ),
    ],
  ),
  _HistoryDay(
    date: '2026年3月30日 周一',
    records: [
      _HistoryRecord(
        time: '08:54',
        periodLabel: '第三节',
        courseName: '钢琴副项',
        kind: _ClassKind.small,
        location: '艺术楼',
        teacherName: '郝江',
        expected: 60,
        present: 58,
        method: '教师一键签到',
      ),
      _HistoryRecord(
        time: '10:20',
        periodLabel: '第四节',
        courseName: '视唱练耳',
        kind: _ClassKind.big,
        location: '艺术楼',
        teacherName: '陈老师',
        expected: 60,
        present: 58,
        method: '扫码签到',
      ),
      _HistoryRecord(
        time: '14:00',
        periodLabel: '第六节',
        courseName: '钢琴副项',
        kind: _ClassKind.big,
        location: '艺术楼',
        teacherName: '郝江',
        expected: 60,
        present: 58,
        method: '教师一键签到',
      ),
    ],
  ),
  _HistoryDay(
    date: '2026年3月27日 周五',
    records: [
      _HistoryRecord(
        time: '08:54',
        periodLabel: '第二节',
        courseName: '钢琴副项',
        kind: _ClassKind.small,
        location: '艺术楼',
        teacherName: '郝江',
        expected: 60,
        present: 58,
        method: '教师一键签到',
      ),
      _HistoryRecord(
        time: '10:20',
        periodLabel: '第四节',
        courseName: '视唱练耳',
        kind: _ClassKind.big,
        location: '艺术楼',
        teacherName: '陈老师',
        expected: 60,
        present: 58,
        method: '扫码签到',
      ),
    ],
  ),
];
