// =============================================================================
// 宿管端「查寝历史」独立页面
//
// 入口：宿管 dashboard 快捷区「查寝历史」按钮 → controller.openDormHistory()
//      → mainView == dormHistory + role == dormManager → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 设计原则：与「按宿舍查寝」(`dorm_manager_check_by_room_view.dart`) 保持
// 视觉语言的一致性，但因为本页是审计场景、单日动辄 50+ 条记录，所以
// **正文区采用表格列表**而非卡片网格 —— 让宿管在一屏内能扫到尽可能多的
// 记录。共用语言：
//   - banner 白→#F9EDFF 渐变 + 居中标题 + 副标题
//   - 14 天日历条（白底 16 圆角 + 灰底 8 圆角 cells，今日紫底白字）
//   - 4 张 100 高彩色渐变统计卡（橙 / 绿 / 红 / 紫 + 右上 32×32 白底图标）
//   - 状态徽章配色：正常 #A773FF / 请假免检 #1CD097 / 迟到 #325BFF /
//     未打卡 #FF323C
//
// 表格区列：
//   场次（晨/晚）| 宿舍 | 状态 | 规定时间 | 打卡时间 | 备注
//
// 在 by-room 视图基础之上额外补充的「历史能力」：
//   1. 日期切换 → 即时刷新统计卡 + 列表
//   2. 日内晨/晚两轮**混在同一列表**里通过「场次」列区分（用户反馈不再做
//      tab 切换，直接横铺更高效）
//   3. 当日无记录时显示空状态卡片
//
// 数据流：本页全部使用本地演示数据；切到正式接口时只需把 `_demoRecords()`
// 替换为 `dormRepository.history({date})` 即可，UI 形状无需变动。
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
const Color _kTextDarker = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kCalendarHint = Color(0xFFE6E9F1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSolid = Color(0xFFA773FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kBlue = Color(0xFF325BFF);
const Color _kGreen = Color(0xFF1CD097);

// —— 历史卡状态徽章（与 by-room 视图底部完全一致）—————————————————
enum _HistoryStatus {
  normal('正常', _kPurpleSolid),
  absent('未打卡', _kRed),
  late_('迟到', _kBlue),
  leave('请假免检', _kGreen);

  const _HistoryStatus(this.label, this.bg);
  final String label;
  final Color bg;

  bool get isException =>
      this != _HistoryStatus.normal && this != _HistoryStatus.leave;
}

// —— 数据模型 ——————————————————————————————————————————————————
//
// 一行 = 一个寝室在某一天的查寝记录。每个寝室包含若干学生及其当日状态。

class _HistoryStudent {
  const _HistoryStudent({required this.name, required this.status});

  final String name;
  final _HistoryStatus status;
}

class _HistoryRoom {
  const _HistoryRoom({
    required this.dormName,
    required this.date,
    required this.students,
  });

  final String dormName;
  final String date; // YYYY-MM-DD
  final List<_HistoryStudent> students;
}

class _CalendarDay {
  const _CalendarDay({
    required this.date,
    required this.weekdayLabel,
    required this.dayLabel,
  });

  final DateTime date;
  final String weekdayLabel; // 一 / 二 / 今 等
  final String dayLabel; // 02 / 17 等

  String get isoDate {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

// =============================================================================
// 顶级视图
// =============================================================================

class DormManagerCheckHistoryView extends StatefulWidget {
  const DormManagerCheckHistoryView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<DormManagerCheckHistoryView> createState() =>
      _DormManagerCheckHistoryViewState();
}

class _DormManagerCheckHistoryViewState
    extends State<DormManagerCheckHistoryView> {
  late List<_CalendarDay> _days; // 14 天滚动条：前 6 天 + 今 + 后 7 天
  late int _selectedDayIndex; // 默认指向"今日"，即 index 6
  late List<_HistoryRoom> _rooms;

  @override
  void initState() {
    super.initState();
    _days = _buildDays(DateTime.now());
    _selectedDayIndex = 6; // _buildDays 把"今日"放在 index 6
    _rooms = _demoRooms();
  }

  String get _selectedDateText => _days[_selectedDayIndex].isoDate;

  /// 选中日期下的所有寝室，按宿舍号升序，方便宿管按楼层从上往下核对。
  List<_HistoryRoom> get _filtered {
    final iso = _selectedDateText;
    final list = _rooms.where((r) => r.date == iso).toList();
    list.sort((a, b) => a.dormName.compareTo(b.dormName));
    return list;
  }

  /// 4 张统计卡：基于"当前选中日"全部寝室 × 学生的合并统计。
  ///
  /// - 当日寝室：被查寝的寝室数
  /// - 正常打卡：状态 normal 的学生数
  /// - 异常待跟进：状态 absent + late 的学生数
  /// - 请假免检：状态 leave 的学生数
  ({int total, int normal, int exception, int leave}) _statsForDay() {
    final iso = _selectedDateText;
    final rooms = _rooms.where((r) => r.date == iso).toList();
    int normal = 0;
    int exception = 0;
    int leave = 0;
    for (final r in rooms) {
      for (final s in r.students) {
        switch (s.status) {
          case _HistoryStatus.normal:
            normal++;
          case _HistoryStatus.leave:
            leave++;
          case _HistoryStatus.absent:
          case _HistoryStatus.late_:
            exception++;
        }
      }
    }
    return (
      total: rooms.length,
      normal: normal,
      exception: exception,
      leave: leave,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final stats = _statsForDay();
    final filtered = _filtered;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _DateStripCard(
              days: _days,
              selectedIndex: _selectedDayIndex,
              dateText: _selectedDateText,
              statText: '共 ${stats.total} 个寝室',
              onTapDay: (i) => setState(() => _selectedDayIndex = i),
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              total: stats.total,
              normal: stats.normal,
              exception: stats.exception,
              leave: stats.leave,
            ),
            SizedBox(height: ui(16)),
            if (filtered.isEmpty)
              const _EmptyState()
            else
              _HistoryList(rooms: filtered),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner
// =============================================================================

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
                    '查寝历史',
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
                    '按日期回溯本人巡寝记录与每位学生当日状态；与年级闸机数据对接后，未打卡 / 晚归 / 请假免检的状态会自动同步到此页备查。',
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

// =============================================================================
// 14 天日期条
// =============================================================================

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
                color: _kTextDarker,
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
          LayoutBuilder(
            builder: (context, c) {
              const cellCount = 14;
              final gap = ui(6);
              final totalGap = gap * (cellCount - 1);
              final cellW = (c.maxWidth - totalGap) / cellCount;
              return Row(
                children: List.generate(cellCount, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == cellCount - 1 ? 0 : gap,
                    ),
                    child: SizedBox(
                      width: cellW,
                      child: _CalendarCell(
                        day: days[i],
                        selected: i == selectedIndex,
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

// =============================================================================
// 4 张统计卡（沿用 by-room 视图的彩色渐变 + 右上图标容器风格）
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.normal,
    required this.exception,
    required this.leave,
  });

  final int total;
  final int normal;
  final int exception;
  final int leave;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '当日寝室',
            value: total,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x29FFA846), Color(0x00FFFFFF)],
            ),
            iconColor: _kGreen,
            iconKind: _StatIconKind.home,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '正常打卡',
            value: normal,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1746FF77), Color(0x00FFFFFF)],
            ),
            iconColor: _kGreen,
            iconKind: _StatIconKind.home,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '异常待跟进',
            value: exception,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1CFF4646), Color(0x00FFFFFF)],
            ),
            iconColor: _kPurple,
            iconKind: _StatIconKind.alert,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '请假免检',
            value: leave,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x249346FF), Color(0x00FFFFFF)],
            ),
            iconColor: _kPurple,
            iconKind: _StatIconKind.alert,
          ),
        ),
      ],
    );
  }
}

enum _StatIconKind { home, alert }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.gradient,
    required this.iconColor,
    required this.iconKind,
  });

  final String label;
  final int value;
  final LinearGradient gradient;
  final Color iconColor;
  final _StatIconKind iconKind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            right: ui(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ui(12)),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: ui(32),
                    color: _kTextDark,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: ui(16),
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
              child: Icon(
                iconKind == _StatIconKind.home
                    ? Icons.home_rounded
                    : Icons.error_outline_rounded,
                size: ui(16),
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 历史记录表格列表（白底圆角 + 表头 + 寝室行 + 学生 chip）
//
// 列：宿舍（固定 240）| 学生状态（Expanded，wrap 多个 chip）
// 每个 chip 显示「[状态色点] 学生姓名 · 状态」，可一眼看清该宿舍各成员的
// 当日打卡情况；行高随学生数量自适应（Wrap），保证 4–8 人都能完整展示。
// =============================================================================

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.rooms});

  final List<_HistoryRoom> rooms;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HistoryListHeader(),
          for (var i = 0; i < rooms.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, thickness: 1, color: _kBorderSoft),
            _HistoryListRow(room: rooms[i], zebra: i.isOdd),
          ],
        ],
      ),
    );
  }
}

class _HistoryListHeader extends StatelessWidget {
  const _HistoryListHeader();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: const BoxDecoration(color: _kCardGreyBg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: ui(240), child: const _HeaderText('宿舍')),
          const Expanded(child: _HeaderText('学生状态')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(12),
        color: _kTextSecondary,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.2,
      ),
    );
  }
}

class _HistoryListRow extends StatelessWidget {
  const _HistoryListRow({required this.room, required this.zebra});

  final _HistoryRoom room;
  final bool zebra;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      color: zebra ? const Color(0xFFFAFAFC) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 宿舍 + 床位提示
          SizedBox(
            width: ui(240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.dormName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  '${room.students.length} 名在校学生',
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
          // 学生 chip Wrap
          Expanded(
            child: Wrap(
              spacing: ui(8),
              runSpacing: ui(8),
              children: [
                for (final s in room.students) _StudentChip(student: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 学生 chip：圆角矩形 + 左侧状态色点 + 名字 + 状态文字。
///
/// 背景使用状态颜色的浅色版（10% 透明度），文字用纯色 + 深色名字，保证多
/// chip 横排时视觉上每个学生的状态色一眼可辨，但又不会过于花哨。
class _StudentChip extends StatelessWidget {
  const _StudentChip({required this.student});

  final _HistoryStudent student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final statusColor = student.status.bg;
    final bg = statusColor.withValues(alpha: 0.10);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(5)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(999)),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(6)),
          Text(
            student.name,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            '· ${student.status.label}',
            style: TextStyle(
              fontSize: ui(12),
              color: statusColor,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 空状态（当日 + 当前 session 无记录）
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: ui(40),
            color: const Color(0xFFD4D6D9),
          ),
          SizedBox(height: ui(8)),
          Text(
            '当日暂无查寝记录',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 14 天日历构建
// =============================================================================

List<_CalendarDay> _buildDays(DateTime today) {
  // 沿用 teacher 端布局：今日固定在 index 6，前 6 天 + 今 + 后 7 天，共 14 天。
  const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  return List<_CalendarDay>.generate(14, (i) {
    final d = today.add(Duration(days: i - 6));
    final isToday = i == 6;
    final wd = (d.weekday - 1) % 7;
    return _CalendarDay(
      date: d,
      weekdayLabel: isToday ? '今' : weekdayLabels[wd],
      dayLabel: d.day.toString().padLeft(2, '0'),
    );
  });
}

// =============================================================================
// 演示数据：当日 50 个寝室（每室 4–6 名学生），过往几天少量记录便于翻看
//
// 状态分布大体接近真实情况：
//   - 70% 正常打卡
//   - 14% 迟到
//   - 10% 未打卡
//   - 6%  请假免检
// 楼栋按男生 1–3 号楼、女生 1–3 号楼轮流分配，男生 5xx / 女生 6xx。
// 学生姓名使用常见姓 + 名表生成，确定性可复现。
// =============================================================================

const List<String> _kSurnames = [
  '王', '李', '张', '刘', '陈', '杨', '黄', '赵', '周', '吴',
  '徐', '孙', '朱', '马', '胡', '郭', '林', '何', '高', '罗',
  '沈', '韩', '唐', '冯', '邓', '曹', '彭', '曾', '萧', '蒋',
];

const List<String> _kGivenNamesMale = [
  '俊杰', '浩然', '子轩', '一鸣', '泽宇', '昊然', '晨光', '梓豪', '梓睿', '宇航',
  '思源', '志远', '哲瀚', '弘文', '伟祺', '建宏', '俊熙', '梓晨', '若飞', '景行',
];

const List<String> _kGivenNamesFemale = [
  '雨萱', '思琪', '梓涵', '欣怡', '一诺', '可馨', '诗涵', '婉清', '若曦', '清歌',
  '雅琪', '婷婷', '依依', '语彤', '念慈', '梦琪', '蕊汐', '雪萌', '昕悦', '佳琪',
];

List<_HistoryRoom> _demoRooms() {
  String iso(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  final today = DateTime.now();
  final t0 = iso(today);
  final t1 = iso(today.subtract(const Duration(days: 1)));
  final t2 = iso(today.subtract(const Duration(days: 2)));
  final t3 = iso(today.subtract(const Duration(days: 3)));

  const buildings = <String>[
    '男生宿舍1号楼',
    '男生宿舍2号楼',
    '男生宿舍3号楼',
    '女生宿舍1号楼',
    '女生宿舍2号楼',
    '女生宿舍3号楼',
  ];

  ({String name, bool isMale}) roomAt(int i) {
    final building = buildings[i % buildings.length];
    final isMale = i % buildings.length < 3;
    final floor = isMale ? 5 : 6;
    final no = (i ~/ buildings.length) + 1;
    return (name: '$building ${floor * 100 + no + 9}', isMale: isMale);
  }

  _HistoryStatus statusAt(int seed) {
    final m = seed % 100;
    if (m < 70) return _HistoryStatus.normal;
    if (m < 84) return _HistoryStatus.late_;
    if (m < 94) return _HistoryStatus.absent;
    return _HistoryStatus.leave;
  }

  String studentName(int seed, bool isMale) {
    final s = _kSurnames[seed % _kSurnames.length];
    final pool = isMale ? _kGivenNamesMale : _kGivenNamesFemale;
    final g = pool[(seed * 7 + 3) % pool.length];
    return '$s$g';
  }

  List<_HistoryStudent> studentsFor(int roomIdx, int seedOffset, bool isMale) {
    // 每间 4–6 人，按 roomIdx 决定。
    final count = 4 + (roomIdx % 3); // 4,5,6 循环
    final used = <String>{};
    final list = <_HistoryStudent>[];
    var k = 0;
    while (list.length < count) {
      final seed = seedOffset + roomIdx * 23 + k * 7;
      var name = studentName(seed, isMale);
      // 同寝室避免同名重复
      while (used.contains(name)) {
        k++;
        name = studentName(seedOffset + roomIdx * 23 + k * 7, isMale);
      }
      used.add(name);
      list.add(_HistoryStudent(
        name: name,
        status: statusAt(seed + 13),
      ));
      k++;
    }
    return list;
  }

  List<_HistoryRoom> roomsForDate(
    String date,
    int count, {
    int seedOffset = 0,
  }) {
    return List<_HistoryRoom>.generate(count, (i) {
      final r = roomAt(i);
      return _HistoryRoom(
        dormName: r.name,
        date: date,
        students: studentsFor(i, seedOffset, r.isMale),
      );
    });
  }

  return [
    ...roomsForDate(t0, 50, seedOffset: 0),
    ...roomsForDate(t1, 30, seedOffset: 101),
    ...roomsForDate(t2, 18, seedOffset: 211),
    ...roomsForDate(t3, 12, seedOffset: 307),
  ];
}
