// =============================================================================
// 班主任端「查寝历史」独立页面
//
// 入口：班主任 dashboard 快捷区「查寝历史」按钮 → controller.openDormHistory()
//      → mainView == dormHistory + role == headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高, 紫白渐变 #F9EDFF→white, 圆角 16, 顶部居中 "查寝历史
//      记录" 16/600 + 副标题 12/#B6B5BB「按自然日查看本班住宿生晚查寝、晨查寝
//      打卡汇总；数据与「查寝动态」演示同源。查寝老师打卡在专用端完成。」；
//      左 12 返回 32×32 白底 outline #F3F2F3）。
//   2. 提示文字 12/#B6B5BB「默认由家长在小程序审批后再由班主任审批；……」。
//   3. 日期条卡（970×110，圆角 16，白底）：
//      - 顶部 12,12 处 `2026-04-17` 14/500 + 下拉小箭头（演示）；
//      - 右侧 762 处 `晚查寝应统计12人，当日流水20条。` 12 hint；
//      - 底部 14 个 58×59 圆角 8 灰底 cells（顶部 `星期` 12 hint /
//        底部 `日期` 16 Barlow/600），第 7 个 "日 / 今" 紫底白字。
//   4. 4 张统计卡（100 高 + 白底 + 右上 32×32 outlined icon 容器）：
//      A. 「晚查寝 · 已归寝口径」10 + "正常/免检/补卡过" + 蓝色 sun icon
//      B. 「晚查寝 · 待关注」 2 + "晚归/未打卡" + 绿色 home icon
//      C. 「晨查寝 · 已到位口径」2 + "正常/免检/补卡过" + 紫色 alert icon
//      D. 「晨查寝 · 待关注」 1 + "晚归/未打卡" + 紫色 alert icon
//   5. Tabs row（44 高）：白底圆角 8 + 2 pills：晚查寝（active 黑底白字）/
//      晨查寝（灰字）。无搜索框。
//   6. 卡片网格 3 列（每张 312 宽，padding 12，背景 207deg #FAF0FF→white
//      渐变，圆角 16，gap 16）：
//      - 宿舍口径卡：晨查寝 / 晚查寝 18 Barlow/600 标题 + 大色块状态徽章
//        正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF 全为白字；下行
//        宿舍 13/#6D6B75 + 日期；灰底块同；底部 备注。
//      - 学生口径卡：头像 40 + 姓名 14/500 + 学号 12/#B6B5BB +
//        "查寝" 12/#6D6B75 + 状态徽章 16 高（正常 #DAD2FF/#8741FF /
//        未打卡 #FEE4E8/#FF323C）；下行 宿舍 12 + 日期；灰底块 #F5F6FA
//        H50 居中两列：规定时间 / 打卡时间；底部 备注。
// =============================================================================

import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE5E7EB);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFEE4E8);
const Color _kBlue = Color(0xFF325BFF);
const Color _kGreen = Color(0xFF1CD097);
const Color _kCalendarHint = Color(0xFFE6E9F1);

// —— 顶部 tab 枚举（晚查寝 / 晨查寝）—————————————————————————————
enum _SessionTab {
  evening('晚查寝'),
  morning('晨查寝');

  const _SessionTab(this.label);
  final String label;
}

// —— 学生口径状态（仅出现 正常 / 未打卡 两种） ——————————————————————
enum _StudentStatus {
  normal('正常', _kPurpleSoftBg, _kPurple),
  absent('未打卡', _kRedSoftBg, _kRed);

  const _StudentStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

// —— 宿舍口径状态（实色徽章）—————————————————————————————————————
enum _DormStatus {
  normal('正常', Color(0xFFA773FF)),
  absent('未打卡', _kRed),
  late_('迟到', _kBlue);

  const _DormStatus(this.label, this.solidBg);
  final String label;
  final Color solidBg;
}

enum _Session { morning, evening }

// —— 数据模型 ——————————————————————————————————————————————————
class _DormRecord {
  const _DormRecord({
    required this.session,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final _Session session;
  final _DormStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;

  String get titleText => session == _Session.morning ? '晨查寝' : '晚查寝';
}

class _StudentRecord {
  const _StudentRecord({
    required this.session,
    required this.studentName,
    required this.studentNo,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final _Session session;
  final String studentName;
  final String studentNo;
  final _StudentStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;
}

// —— 日历日 ————————————————————————————————————————————————————
class _CalendarDay {
  const _CalendarDay({
    required this.weekdayLabel,
    required this.dayLabel,
    this.isToday = false,
  });

  final String weekdayLabel;
  final String dayLabel;
  final bool isToday;
}

// —— 顶级视图 ——————————————————————————————————————————————————

class TeacherDormHistoryView extends StatefulWidget {
  const TeacherDormHistoryView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TeacherDormHistoryView> createState() => _TeacherDormHistoryViewState();
}

class _TeacherDormHistoryViewState extends State<TeacherDormHistoryView> {
  _SessionTab _tab = _SessionTab.evening;
  int _selectedDayIndex = 6; // 第 7 个 "今"
  late final List<_CalendarDay> _days;
  late final List<_DormRecord> _dormRecords;
  late final List<_StudentRecord> _students;

  @override
  void initState() {
    super.initState();
    _days = _demoDays();
    _dormRecords = _demoDormRecords();
    _students = _demoStudents();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(10)),
            Padding(
              padding: EdgeInsets.only(left: ui(8)),
              child: Text(
                '默认由家长在小程序审批后再由班主任审批；已与家长充分沟通的可选择班主任直接审批。补课协调以教务安排为准。',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            _DateStripCard(
              days: _days,
              selectedIndex: _selectedDayIndex,
              dateText: '2026-04-17',
              statText: '晚查寝应统计12人，当日流水20条。',
              onTapDay: (i) => setState(() => _selectedDayIndex = i),
            ),
            SizedBox(height: ui(16)),
            const _StatsRow(
              eveningReturned: 10,
              eveningWatch: 2,
              morningArrived: 2,
              morningWatch: 1,
            ),
            SizedBox(height: ui(16)),
            _TabsRow(current: _tab, onTap: (t) => setState(() => _tab = t)),
            SizedBox(height: ui(16)),
            _CardsGrid(
              dormRecords: _filteredDormRecords(),
              students: _filteredStudents(),
            ),
          ],
        ),
      ),
    );
  }

  _Session get _activeSession =>
      _tab == _SessionTab.evening ? _Session.evening : _Session.morning;

  List<_DormRecord> _filteredDormRecords() =>
      _dormRecords.where((r) => r.session == _activeSession).toList();

  List<_StudentRecord> _filteredStudents() =>
      _students.where((r) => r.session == _activeSession).toList();
}

// —— Banner ————————————————————————————————————————————————————————

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
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
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '查寝历史记录',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '按自然日查看本班住宿生晚查寝、晨查寝打卡汇总；数据与「查寝动态」演示同源。查寝老师打卡在专用端完成。',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// —— 日期条卡 ——————————————————————————————————————————————————

class _DateStripCard extends StatelessWidget {
  const _DateStripCard({
    required this.days,
    required this.selectedIndex,
    required this.dateText,
    required this.statText,
    required this.onTapDay,
  });

  final List<_CalendarDay> days;
  final int selectedIndex;
  final String dateText;
  final String statText;
  final ValueChanged<int> onTapDay;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              SizedBox(width: ui(6)),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(16),
                color: const Color(0xFF1A1A1A),
              ),
              const Spacer(),
              Text(
                statText,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(14)),
          // 14 天日期条
          LayoutBuilder(
            builder: (context, constraints) {
              const cellCount = 14;
              const gap = 6.0;
              final scaledGap = ui(gap);
              final totalGap = scaledGap * (cellCount - 1);
              final cellWidth = (constraints.maxWidth - totalGap) / cellCount;
              return Row(
                children: List.generate(cellCount, (i) {
                  final day = days[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == cellCount - 1 ? 0 : scaledGap,
                    ),
                    child: SizedBox(
                      width: cellWidth,
                      child: _CalendarCell(
                        day: day,
                        selected: selected,
                        onTap: () => onTapDay(i),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _CalendarDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = selected ? _kPurple : _kCardGreyBg;
    final weekdayColor = selected ? _kCalendarHint : _kTextHint;
    final dayColor = selected ? Colors.white : _kTextDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(59),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.weekdayLabel,
              style: TextStyle(
                fontSize: ui(12),
                color: weekdayColor,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(7)),
            Text(
              day.dayLabel,
              style: TextStyle(
                fontSize: ui(16),
                color: dayColor,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// —— 4 张统计卡 ————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.eveningReturned,
    required this.eveningWatch,
    required this.morningArrived,
    required this.morningWatch,
  });

  final int eveningReturned;
  final int eveningWatch;
  final int morningArrived;
  final int morningWatch;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '晚查寝 · 已归寝口径',
            value: eveningReturned,
            subtitle: '正常/免检/补卡过',
            icon: Icons.wb_sunny_outlined,
            iconColor: _kBlue,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            title: '晚查寝 · 待关注',
            value: eveningWatch,
            subtitle: '晚归/未打卡',
            icon: Icons.home_outlined,
            iconColor: _kGreen,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            title: '晨查寝 · 已到位口径',
            value: morningArrived,
            subtitle: '正常/免检/补卡过',
            icon: Icons.notifications_active_outlined,
            iconColor: _kPurple,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            title: '晨查寝 · 待关注',
            value: morningWatch,
            subtitle: '晚归/未打卡',
            icon: Icons.notifications_active_outlined,
            iconColor: _kPurple,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            right: ui(56),
            child: Text(
              title,
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
          Positioned(
            left: ui(16),
            top: ui(40),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: ui(32),
                color: _kTextDark,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ),
          Positioned(
            right: ui(13),
            top: ui(34),
            child: Container(
              width: ui(32),
              height: ui(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderHair, width: 0.5),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: ui(20), color: iconColor),
            ),
          ),
          Positioned(
            left: ui(16),
            bottom: ui(14),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// —— Tabs ————————————————————————————————————————————————————————

class _TabsRow extends StatelessWidget {
  const _TabsRow({required this.current, required this.onTap});

  final _SessionTab current;
  final ValueChanged<_SessionTab> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _SessionTab.values) ...[
            _TabPill(
              label: t.label,
              active: current == t,
              onTap: () => onTap(t),
            ),
            if (t != _SessionTab.values.last) SizedBox(width: ui(8)),
          ],
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// —— 卡片网格 ——————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({required this.dormRecords, required this.students});

  final List<_DormRecord> dormRecords;
  final List<_StudentRecord> students;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const gap = 16.0;
        final scaledGap = ui(gap);
        final cardWidth =
            (constraints.maxWidth - scaledGap * (columns - 1)) / columns;
        // 顺序：宿舍口径在前，学生口径在后（与 Figma 第一行就是 3 张
        // 宿舍口径卡 + 后续行学生口径一致；当前 tab 切换时仅显示同 session 的
        // 数据）。
        final widgets = <Widget>[];
        for (final r in dormRecords) {
          widgets.add(
            SizedBox(
              width: cardWidth,
              child: _DormCard(record: r),
            ),
          );
        }
        for (final r in students) {
          widgets.add(
            SizedBox(
              width: cardWidth,
              child: _StudentCard(record: r),
            ),
          );
        }
        return Wrap(
          spacing: scaledGap,
          runSpacing: scaledGap,
          children: widgets,
        );
      },
    );
  }
}

// —— 宿舍口径卡 ————————————————————————————————————————————————

class _DormCard extends StatelessWidget {
  const _DormCard({required this.record});

  final _DormRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFAF0FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                record.titleText,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              _DormStatusBadge(status: record.status),
            ],
          ),
          SizedBox(height: ui(4)),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.dormName,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
              Text(
                record.date,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _TimeBlock(
            requiredTime: record.requiredTime,
            punchTime: record.punchTime,
          ),
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DormStatusBadge extends StatelessWidget {
  const _DormStatusBadge({required this.status});

  final _DormStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.solidBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// —— 学生口径卡 ————————————————————————————————————————————————

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.record});

  final _StudentRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFAF0FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icons.person_rounded,
                  size: ui(24),
                  color: _kTextHint,
                ),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  record.studentName,
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
                              SizedBox(width: ui(4)),
                              Text(
                                record.studentNo,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextHint,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w400,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '查寝',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        _StudentStatusBadge(status: record.status),
                      ],
                    ),
                    SizedBox(height: ui(6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.dormName,
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
                        ),
                        Text(
                          record.date,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _TimeBlock(
            requiredTime: record.requiredTime,
            punchTime: record.punchTime,
          ),
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentStatusBadge extends StatelessWidget {
  const _StudentStatusBadge({required this.status});

  final _StudentStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: status.fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// —— 灰底时间双列 ————————————————————————————————————————————

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.requiredTime, required this.punchTime});

  final String requiredTime;
  final String punchTime;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(11), horizontal: ui(8)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeColumn(label: '规定时间', value: requiredTime),
          ),
          Expanded(
            child: _TimeColumn(label: '打卡时间', value: punchTime),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        SizedBox(height: ui(6)),
        Text(
          value,
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

// —— 演示数据 ——————————————————————————————————————————————————

List<_CalendarDay> _demoDays() => const [
  _CalendarDay(weekdayLabel: '一', dayLabel: '11'),
  _CalendarDay(weekdayLabel: '二', dayLabel: '12'),
  _CalendarDay(weekdayLabel: '三', dayLabel: '13'),
  _CalendarDay(weekdayLabel: '四', dayLabel: '14'),
  _CalendarDay(weekdayLabel: '五', dayLabel: '15'),
  _CalendarDay(weekdayLabel: '六', dayLabel: '16'),
  _CalendarDay(weekdayLabel: '日', dayLabel: '今', isToday: true),
  _CalendarDay(weekdayLabel: '一', dayLabel: '18'),
  _CalendarDay(weekdayLabel: '二', dayLabel: '19'),
  _CalendarDay(weekdayLabel: '三', dayLabel: '20'),
  _CalendarDay(weekdayLabel: '四', dayLabel: '21'),
  _CalendarDay(weekdayLabel: '五', dayLabel: '22'),
  _CalendarDay(weekdayLabel: '六', dayLabel: '23'),
  _CalendarDay(weekdayLabel: '日', dayLabel: '24'),
];

List<_DormRecord> _demoDormRecords() => const [
  // 晨查寝 · 正常（女生宿舍3号楼 612）
  _DormRecord(
    session: _Session.morning,
    status: _DormStatus.normal,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  // 晨查寝 · 未打卡
  _DormRecord(
    session: _Session.morning,
    status: _DormStatus.absent,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  // 晚查寝 · 迟到（备注：教师拖堂）
  _DormRecord(
    session: _Session.evening,
    status: _DormStatus.late_,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '21:20前',
    punchTime: '21:23',
    note: '教师拖堂',
  ),
];

// 学生口径示例：晚查寝 / 晨查寝 各 6 张（演示分布）。
List<_StudentRecord> _demoStudents() => const [
  _StudentRecord(
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  // 晨查寝
  _StudentRecord(
    session: _Session.morning,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    session: _Session.morning,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    session: _Session.morning,
    studentName: '王晴',
    studentNo: 'G3030201',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
];
