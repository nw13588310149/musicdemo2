// =============================================================================
// 管理员「签课管理」独立页面
//
// 入口：管理员首页快捷区「签课管理」→ controller.openSignManagement()
//      → mainView == signManagement → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack。
//
// 逻辑设计（与业务描述对齐）：
//
//   ┌ 大课管理 tab ─────────────────────────────────────────────────────────┐
//   │ 按班级 + 日期查询当日大课列表。                                        │
//   │ 每节大课卡：课程名 / 时间 / 教室 + 已签 M/N + 状态徽章。               │
//   │ 点击卡片展开学生名单：每人显示当前签到状态（正常/迟到/早退/请假/缺勤）   │
//   │ 管理员可直接点选修改单个学生状态（弹出 bottomSheet 选状态）。           │
//   │ 补签申请入口：底部「待审核补签 N 条」红点 → 打开右侧抽屉审核列表。      │
//   └───────────────────────────────────────────────────────────────────────┘
//
//   ┌ 小课管理 tab ─────────────────────────────────────────────────────────┐
//   │ 按班级 + 日期查询当日小课列表。                                        │
//   │ 五步签到进度条：                                                       │
//   │   ① 教师上课签到  ② 学生上课签到  ③ 教师下课签到                     │
//   │   ④ 学生下课签到  ⑤ 学生评价  ⑥ 管理员确认完成                      │
//   │ 进度条按步骤着色：已完成=紫 / 当前=橙动效 / 未到=灰。                  │
//   │ 待管理员确认的小课：底部渲染「确认完成」按钮 + 查看评价按钮。           │
//   │ 补签申请审核：右上角红角标 badge + 右侧抽屉（与大课共用 UI 组件）。     │
//   └───────────────────────────────────────────────────────────────────────┘
//
// 颜色：白卡 / #F5F6FA 浅灰 / #8741FF 主紫 / #FF323C 红 / #0CAC40 绿
//      / #F59E0B 橙黄 / #B6B5BB 灰 / #6D6B75 副字
// 字体：PingFang SC（中文）+ Barlow（时间数字）
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_date_time_pickers.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ─── 调色板 ────────────────────────────────────────────────────────────────

const Color _kCardBg = Colors.white;
const Color _kPageBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFA773FF);
const Color _kPurpleSoftBg = Color(0xFFEAE5FF);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kGreenBg = Color(0xFFDFFCF0);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kOrangeBg = Color(0xFFFFF7E6);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedBg = Color(0xFFFFEEEF);
const Color _kBlueBg = Color(0xFFE8F0FF);
const Color _kBlue = Color(0xFF3B6FFF);

// ─── 入口视图 ──────────────────────────────────────────────────────────────

enum _SignTab { large, small }

class AdminSignManagementView extends StatefulWidget {
  const AdminSignManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminSignManagementView> createState() =>
      _AdminSignManagementViewState();
}

class _AdminSignManagementViewState extends State<AdminSignManagementView> {
  _SignTab _tab = _SignTab.large;
  int _pendingMakeupCount = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SignBanner(
          onBack: widget.onBack,
          selectedTab: _tab,
          onSelectTab: (t) => setState(() => _tab = t),
          pendingMakeupCount: _pendingMakeupCount,
          onOpenMakeupAudit: _openMakeupAuditDrawer,
        ),
        Expanded(
          child: _tab == _SignTab.large
              ? _LargeClassTab(
                  pendingMakeupCount: _pendingMakeupCount,
                  onOpenMakeupAudit: _openMakeupAuditDrawer,
                )
              : _SmallClassTab(
                  pendingMakeupCount: _pendingMakeupCount,
                  onOpenMakeupAudit: _openMakeupAuditDrawer,
                ),
        ),
      ],
    );
  }

  Future<void> _openMakeupAuditDrawer() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, _) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _MakeupAuditDrawer(
                records: _kDemoMakeupRecords,
                onClose: () => Navigator.of(ctx).maybePop(),
                onAuditDone: (remaining) {
                  setState(() => _pendingMakeupCount = remaining);
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }
}

// ─── banner ────────────────────────────────────────────────────────────────

class _SignBanner extends StatelessWidget {
  const _SignBanner({
    required this.onBack,
    required this.selectedTab,
    required this.onSelectTab,
    required this.pendingMakeupCount,
    required this.onOpenMakeupAudit,
  });

  final VoidCallback onBack;
  final _SignTab selectedTab;
  final ValueChanged<_SignTab> onSelectTab;
  final int pendingMakeupCount;
  final VoidCallback onOpenMakeupAudit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: _kBorderSoft),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      child: Row(
        children: [
          // 返回按钮
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              width: ui(32),
              height: ui(32),
              decoration: BoxDecoration(
                color: _kCardBg,
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
          SizedBox(width: ui(12)),
          // 标题
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '签课管理',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1,
                ),
              ),
              SizedBox(height: ui(2)),
              Text(
                '大课一键入册 · 小课全流程签到 · 补签审核',
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(width: ui(20)),
          // 自定义分段控制（避免 TabBar 在 Row 中无界宽的布局错误）
          _SegmentControl(
            selected: selectedTab,
            onSelect: onSelectTab,
          ),
          const Spacer(),
          // 补签审核入口
          _MakeupBadgeButton(
            count: pendingMakeupCount,
            onTap: onOpenMakeupAudit,
          ),
        ],
      ),
    );
  }
}

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({required this.selected, required this.onSelect});

  final _SignTab selected;
  final ValueChanged<_SignTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(32),
      padding: EdgeInsets.all(ui(3)),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegBtn(
            label: '大课管理',
            active: selected == _SignTab.large,
            onTap: () => onSelect(_SignTab.large),
          ),
          SizedBox(width: ui(2)),
          _SegBtn(
            label: '小课管理',
            active: selected == _SignTab.small,
            onTap: () => onSelect(_SignTab.small),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: ui(14)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kCardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            fontWeight: active ? AppFont.w500 : AppFont.w400,
            color: active ? _kPurple : _kTextSecondary,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _MakeupBadgeButton extends StatelessWidget {
  const _MakeupBadgeButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: ui(32),
            padding: EdgeInsets.symmetric(horizontal: ui(12)),
            decoration: BoxDecoration(
              color: _kPurpleSoftBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  size: ui(14),
                  color: _kPurple,
                ),
                SizedBox(width: ui(4)),
                Text(
                  '补签审核',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Positioned(
              right: ui(-6),
              top: ui(-6),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(4),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
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

// =============================================================================
// 大课管理 Tab
// =============================================================================

class _LargeClassTab extends StatefulWidget {
  const _LargeClassTab({
    required this.pendingMakeupCount,
    required this.onOpenMakeupAudit,
  });

  final int pendingMakeupCount;
  final VoidCallback onOpenMakeupAudit;

  @override
  State<_LargeClassTab> createState() => _LargeClassTabState();
}

class _LargeClassTabState extends State<_LargeClassTab> {
  String _selectedClass = '音乐一班';
  String _selectedDate = '2026-05-16';
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计行
          _LargeClassStatsRow(
            sessions: _kDemoLargeClassSessions,
            pendingMakeupCount: widget.pendingMakeupCount,
          ),
          SizedBox(height: ui(16)),
          // 筛选栏
          _FilterBar(
            selectedClass: _selectedClass,
            selectedDate: _selectedDate,
            classOptions: const ['音乐一班', '乐理一班', '视唱一班'],
            onClassChanged: (v) => setState(() {
              _selectedClass = v;
              _expandedIndex = null;
            }),
            onDateChanged: (v) => setState(() {
              _selectedDate = v;
              _expandedIndex = null;
            }),
          ),
          SizedBox(height: ui(16)),
          // 课次列表
          for (var i = 0; i < _kDemoLargeClassSessions.length; i++) ...[
            if (i > 0) SizedBox(height: ui(12)),
            _LargeClassSessionCard(
              session: _kDemoLargeClassSessions[i],
              expanded: _expandedIndex == i,
              onToggle: () => setState(
                () => _expandedIndex = _expandedIndex == i ? null : i,
              ),
              onChangeStudentStatus: (studentIdx, status) {
                setState(() {
                  _kDemoLargeClassSessions[i].students[studentIdx].status =
                      status;
                });
              },
            ),
          ],
          SizedBox(height: ui(16)),
          // 补签入口行
          _PendingMakeupRow(
            count: widget.pendingMakeupCount,
            onTap: widget.onOpenMakeupAudit,
          ),
        ],
      ),
    );
  }
}

class _LargeClassStatsRow extends StatelessWidget {
  const _LargeClassStatsRow({
    required this.sessions,
    required this.pendingMakeupCount,
  });

  final List<_LargeClassSession> sessions;
  final int pendingMakeupCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final total = sessions.length;
    final signed = sessions
        .where(
          (s) =>
              s.students.every((st) => st.status != _StudentSignStatus.unsigned),
        )
        .length;
    final totalStudents = sessions.fold<int>(
      0,
      (acc, s) => acc + s.students.length,
    );
    final signedStudents = sessions.fold<int>(
      0,
      (acc, s) =>
          acc +
          s.students
              .where((st) => st.status != _StudentSignStatus.unsigned)
              .length,
    );
    return Row(
      children: [
        _SignStatCard(
          value: '$total',
          label: '今日大课节数',
          gradColors: const [Color(0xFFB68EFF), Color(0xFF8640FF)],
        ),
        SizedBox(width: ui(12)),
        _SignStatCard(
          value: '$signed',
          label: '已完成签到',
          gradColors: const [Color(0xFF67D58C), Color(0xFF0CAC40)],
        ),
        SizedBox(width: ui(12)),
        _SignStatCard(
          value: '$signedStudents/$totalStudents',
          label: '学生已签/应签',
          gradColors: const [Color(0xFFFBC06F), Color(0xFFF59E0B)],
        ),
        SizedBox(width: ui(12)),
        _SignStatCard(
          value: '$pendingMakeupCount',
          label: '待处理补签',
          gradColors: const [Color(0xFFFF7A7A), Color(0xFFFF323C)],
        ),
      ],
    );
  }
}

class _LargeClassSessionCard extends StatelessWidget {
  const _LargeClassSessionCard({
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.onChangeStudentStatus,
  });

  final _LargeClassSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(int studentIdx, _StudentSignStatus status)
  onChangeStudentStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final signedCount = session.students
        .where((s) => s.status != _StudentSignStatus.unsigned)
        .length;
    final total = session.students.length;
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        children: [
          // 课次头部
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(ui(12)),
              topRight: Radius.circular(ui(12)),
              bottomLeft:
                  expanded ? Radius.zero : Radius.circular(ui(12)),
              bottomRight:
                  expanded ? Radius.zero : Radius.circular(ui(12)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: ui(4),
                    height: ui(32),
                    decoration: BoxDecoration(
                      color: _kPurple,
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                  ),
                  SizedBox(width: ui(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.courseName,
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
                          '${session.timeRange} · ${session.classroom}',
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
                  _SignProgressPill(
                    signed: signedCount,
                    total: total,
                  ),
                  SizedBox(width: ui(10)),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: ui(18),
                    color: _kTextHint,
                  ),
                ],
              ),
            ),
          ),
          // 展开：学生列表
          if (expanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: _kBorderSoft,
              indent: ui(16),
              endIndent: ui(16),
            ),
            Padding(
              padding: EdgeInsets.all(ui(12)),
              child: Column(
                children: [
                  for (var i = 0; i < session.students.length; i++) ...[
                    if (i > 0) SizedBox(height: ui(8)),
                    _StudentSignRow(
                      student: session.students[i],
                      onChangeStatus: (s) => onChangeStudentStatus(i, s),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentSignRow extends StatelessWidget {
  const _StudentSignRow({
    required this.student,
    required this.onChangeStatus,
  });

  final _StudentSignRecord student;
  final ValueChanged<_StudentSignStatus> onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          _MiniAvatar(seed: student.name, size: ui(32)),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  student.no,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          _StudentStatusChip(
            status: student.status,
            onTap: () => _showStatusPicker(context, student.status, onChangeStatus),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker(
    BuildContext context,
    _StudentSignStatus current,
    ValueChanged<_StudentSignStatus> onPick,
  ) {
    final ui = DashboardScaleScope.of(context).ui;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            '修改签到状态',
            style: TextStyle(
              fontSize: ui(15),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: ui(12),
            horizontal: ui(4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _StudentSignStatus.values.map((s) {
              final isSelected = s == current;
              return ListTile(
                dense: true,
                leading: Container(
                  width: ui(8),
                  height: ui(8),
                  decoration: BoxDecoration(
                    color: _statusColor(s),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                    fontWeight:
                        isSelected ? AppFont.w600 : AppFont.w400,
                    color: isSelected ? _kPurple : _kTextDark,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, size: ui(16), color: _kPurple)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onPick(s);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _StudentStatusChip extends StatelessWidget {
  const _StudentStatusChip({required this.status, required this.onTap});

  final _StudentSignStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = _statusColor(status);
    final bg = _statusBg(status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status.label,
              style: TextStyle(
                fontSize: ui(12),
                color: color,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
            SizedBox(width: ui(4)),
            Icon(Icons.edit_rounded, size: ui(11), color: color),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(_StudentSignStatus s) {
  switch (s) {
    case _StudentSignStatus.normal:
      return _kGreen;
    case _StudentSignStatus.late:
      return _kOrange;
    case _StudentSignStatus.earlyLeave:
      return _kBlue;
    case _StudentSignStatus.leave:
      return const Color(0xFF6D6B75);
    case _StudentSignStatus.absent:
      return _kRed;
    case _StudentSignStatus.unsigned:
      return _kTextHint;
  }
}

Color _statusBg(_StudentSignStatus s) {
  switch (s) {
    case _StudentSignStatus.normal:
      return _kGreenBg;
    case _StudentSignStatus.late:
      return _kOrangeBg;
    case _StudentSignStatus.earlyLeave:
      return _kBlueBg;
    case _StudentSignStatus.leave:
      return const Color(0xFFF0F0F0);
    case _StudentSignStatus.absent:
      return _kRedBg;
    case _StudentSignStatus.unsigned:
      return _kPageBg;
  }
}

// =============================================================================
// 小课管理 Tab
// =============================================================================

class _SmallClassTab extends StatefulWidget {
  const _SmallClassTab({
    required this.pendingMakeupCount,
    required this.onOpenMakeupAudit,
  });

  final int pendingMakeupCount;
  final VoidCallback onOpenMakeupAudit;

  @override
  State<_SmallClassTab> createState() => _SmallClassTabState();
}

class _SmallClassTabState extends State<_SmallClassTab> {
  String _selectedClass = '全部班级';
  String _selectedDate = '2026-05-16';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计行
          _SmallClassStatsRow(sessions: _kDemoSmallClassSessions),
          SizedBox(height: ui(16)),
          // 说明条
          _SmallClassFlowHint(),
          SizedBox(height: ui(16)),
          // 筛选栏
          _FilterBar(
            selectedClass: _selectedClass,
            selectedDate: _selectedDate,
            classOptions: const ['全部班级', '测试班级1', '视唱1班'],
            onClassChanged: (v) => setState(() => _selectedClass = v),
            onDateChanged: (v) => setState(() => _selectedDate = v),
          ),
          SizedBox(height: ui(16)),
          // 小课列表
          Wrap(
            spacing: ui(16),
            runSpacing: ui(16),
            children: [
              for (var i = 0; i < _kDemoSmallClassSessions.length; i++)
                SizedBox(
                  width: ui(460),
                  child: _SmallClassSessionCard(
                    session: _kDemoSmallClassSessions[i],
                    onConfirm: () {
                      setState(() {
                        _kDemoSmallClassSessions[i].currentStep =
                            _SmallClassStep.adminConfirmed;
                      });
                    },
                    onViewEvaluation: () =>
                        _showEvaluationDialog(context, _kDemoSmallClassSessions[i]),
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(16)),
          _PendingMakeupRow(
            count: widget.pendingMakeupCount,
            onTap: widget.onOpenMakeupAudit,
          ),
        ],
      ),
    );
  }

  void _showEvaluationDialog(BuildContext context, _SmallClassSession session) {
    final ui = DashboardScaleScope.of(context).ui;
    final evaluated = session.students
        .where((s) => s.evaluation != null)
        .toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(
              '学生课后评价',
              style: TextStyle(
                fontSize: ui(15),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
              ),
            ),
            SizedBox(width: ui(8)),
            Text(
              '${evaluated.length}/${session.students.length}人已评',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        content: SizedBox(
          width: ui(360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < session.students.length; i++) ...[
                  if (i > 0) Divider(height: ui(20), thickness: 0.5, color: _kBorderSoft),
                  _StudentEvalBlock(student: session.students[i]),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '关闭',
              style: TextStyle(color: _kPurple, fontFamily: 'PingFang SC'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallClassStatsRow extends StatelessWidget {
  const _SmallClassStatsRow({required this.sessions});

  final List<_SmallClassSession> sessions;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final total = sessions.length;
    final completed = sessions
        .where((s) => s.currentStep == _SmallClassStep.adminConfirmed)
        .length;
    final pendingAdmin = sessions
        .where((s) => s.currentStep == _SmallClassStep.studentEvaluated)
        .length;
    final inProgress = total - completed - pendingAdmin;
    return Row(
      children: [
        _SignStatCard(
          value: '$total',
          label: '今日小课总数',
          gradColors: const [Color(0xFFB68EFF), Color(0xFF8640FF)],
        ),
        SizedBox(width: ui(12)),
        _SignStatCard(
          value: '$inProgress',
          label: '进行中',
          gradColors: const [Color(0xFFFBC06F), Color(0xFFF59E0B)],
        ),
        SizedBox(width: ui(12)),
        _SignStatCard(
          value: '$pendingAdmin',
          label: '待管理员确认',
          gradColors: const [Color(0xFF6DAEFF), Color(0xFF3B6FFF)],
        ),
        SizedBox(width: ui(12)),
        _SignStatCard(
          value: '$completed',
          label: '已完成',
          gradColors: const [Color(0xFF67D58C), Color(0xFF0CAC40)],
        ),
      ],
    );
  }
}

class _SmallClassFlowHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const steps = [
      '师上课签',
      '生上课签',
      '师下课签',
      '生下课签',
      '生评价',
      '管理员确认',
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPurpleSoftBg,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Icon(Icons.arrow_forward_ios_rounded, size: ui(10), color: _kPurpleLight),
            Text(
              steps[i],
              style: TextStyle(
                fontSize: ui(11),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallClassSessionCard extends StatelessWidget {
  const _SmallClassSessionCard({
    required this.session,
    required this.onConfirm,
    required this.onViewEvaluation,
  });

  final _SmallClassSession session;
  final VoidCallback onConfirm;
  final VoidCallback onViewEvaluation;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final step = session.currentStep;
    final isConfirmed = step == _SmallClassStep.adminConfirmed;
    final canConfirm = step == _SmallClassStep.studentEvaluated;
    final hasEval = step.index >= _SmallClassStep.studentEvaluated.index;

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(
          color: canConfirm ? _kPurple.withValues(alpha: 0.35) : _kBorderSoft,
        ),
      ),
      padding: EdgeInsets.all(ui(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题行 ────────────────────────────────────────
          Row(
            children: [
              Container(
                width: ui(4),
                height: ui(32),
                decoration: BoxDecoration(
                  color: isConfirmed ? _kGreen : _kPurple,
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
              ),
              SizedBox(width: ui(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.courseName,
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(3)),
                    Text(
                      '${session.timeRange} · ${session.classroom} · ${session.students.length}名学生',
                      style: TextStyle(
                        fontSize: ui(11),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallClassStatusBadge(step: step),
            ],
          ),
          SizedBox(height: ui(12)),
          // ── 六步进度条 ────────────────────────────────────
          _SmallClassStepper(currentStep: step),
          SizedBox(height: ui(12)),
          // ── 教师签到信息 ──────────────────────────────────
          _TimelineSection(
            icon: Icons.person_rounded,
            iconColor: _kPurple,
            title: '${session.teacherName}（教师）',
            rows: [
              _TimelineRow(
                label: '上课签到',
                time: session.teacherCheckInTime,
                done: session.teacherCheckInTime != null,
              ),
              _TimelineRow(
                label: '下课签到',
                time: session.teacherCheckOutTime,
                done: session.teacherCheckOutTime != null,
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          // ── 学生签到信息 ──────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 表头
                Row(
                  children: [
                    Icon(Icons.group_rounded, size: ui(13), color: _kTextSecondary),
                    SizedBox(width: ui(5)),
                    Text(
                      '学生（${session.students.length}人）',
                      style: TextStyle(
                        fontSize: ui(11),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    _TimelineLabel(text: '上课签到', color: _kTextHint),
                    SizedBox(width: ui(16)),
                    _TimelineLabel(text: '下课签到', color: _kTextHint),
                  ],
                ),
                SizedBox(height: ui(8)),
                // 学生行
                for (var i = 0; i < session.students.length; i++) ...[
                  if (i > 0)
                    Divider(height: ui(12), thickness: 0.5, color: _kBorderSoft),
                  _StudentTimeRow(student: session.students[i]),
                ],
              ],
            ),
          ),
          // ── 操作按钮 ──────────────────────────────────────
          if (hasEval || canConfirm || isConfirmed) ...[
            SizedBox(height: ui(12)),
            Row(
              children: [
                if (hasEval) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewEvaluation,
                      icon: Icon(Icons.star_outline_rounded, size: ui(14)),
                      label: Text(
                        '查看评价',
                        style: TextStyle(fontSize: ui(12), fontFamily: 'PingFang SC'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kPurple,
                        side: const BorderSide(color: _kPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: ui(8)),
                      ),
                    ),
                  ),
                  if (canConfirm) SizedBox(width: ui(10)),
                ],
                if (canConfirm)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: Icon(Icons.check_circle_outline_rounded, size: ui(14)),
                      label: Text(
                        '确认完成',
                        style: TextStyle(fontSize: ui(12), fontFamily: 'PingFang SC'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: ui(8)),
                      ),
                    ),
                  ),
                if (isConfirmed)
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(vertical: ui(8)),
                      decoration: BoxDecoration(
                        color: _kGreenBg,
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: ui(14), color: _kGreen),
                          SizedBox(width: ui(4)),
                          Text(
                            '已确认完成',
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kGreen,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w500,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
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

// ── 教师签到区块 ──────────────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<_TimelineRow> rows;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(8)),
      child: Row(
        children: [
          _MiniAvatar(seed: title, size: ui(30)),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(5)),
                Row(
                  children: [
                    for (var row in rows) ...[
                      if (rows.indexOf(row) > 0) SizedBox(width: ui(16)),
                      _TimestampChip(label: row.label, time: row.time, done: row.done),
                    ],
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

class _TimelineRow {
  const _TimelineRow({required this.label, required this.time, required this.done});
  final String label;
  final String? time;
  final bool done;
}

class _TimestampChip extends StatelessWidget {
  const _TimestampChip({required this.label, required this.time, required this.done});

  final String label;
  final String? time;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(11),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            height: 1,
          ),
        ),
        SizedBox(width: ui(4)),
        if (done) ...[
          Icon(Icons.check_circle_rounded, size: ui(12), color: _kGreen),
          SizedBox(width: ui(2)),
          Text(
            time ?? '',
            style: TextStyle(
              fontSize: ui(12),
              color: _kGreen,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ] else
          Text(
            '—',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              height: 1,
            ),
          ),
      ],
    );
  }
}

class _TimelineLabel extends StatelessWidget {
  const _TimelineLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(10),
        color: color,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1,
      ),
    );
  }
}

// ── 学生签到行（含上课/下课时间戳）──────────────────────────────────────

class _StudentTimeRow extends StatelessWidget {
  const _StudentTimeRow({required this.student});

  final _SmallClassStudentRecord student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        _MiniAvatar(seed: student.name, size: ui(26)),
        SizedBox(width: ui(7)),
        Expanded(
          child: Text(
            student.name,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
        // 上课签到时间
        _StudentTimeCell(time: student.checkInTime),
        SizedBox(width: ui(16)),
        // 下课签到时间
        _StudentTimeCell(time: student.checkOutTime),
      ],
    );
  }
}

class _StudentTimeCell extends StatelessWidget {
  const _StudentTimeCell({required this.time});

  final String? time;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (time != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: ui(11), color: _kGreen),
          SizedBox(width: ui(3)),
          Text(
            time!,
            style: TextStyle(
              fontSize: ui(12),
              color: _kGreen,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      );
    }
    return Text(
      '未签到',
      style: TextStyle(
        fontSize: ui(11),
        color: _kTextHint,
        fontFamily: 'PingFang SC',
        height: 1,
      ),
    );
  }
}

class _SmallClassStepper extends StatelessWidget {
  const _SmallClassStepper({required this.currentStep});

  final _SmallClassStep currentStep;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const steps = [
      (label: '师\n上课签', step: _SmallClassStep.teacherCheckedIn),
      (label: '生\n上课签', step: _SmallClassStep.studentCheckedIn),
      (label: '师\n下课签', step: _SmallClassStep.teacherCheckedOut),
      (label: '生\n下课签', step: _SmallClassStep.studentCheckedOut),
      (label: '学生\n评价', step: _SmallClassStep.studentEvaluated),
      (label: '管理员\n确认', step: _SmallClassStep.adminConfirmed),
    ];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: ui(2),
                color: currentStep.index >= steps[i].step.index
                    ? _kPurple
                    : _kBorderHair,
              ),
            ),
          _StepDot(
            label: steps[i].label,
            isDone: currentStep.index >= steps[i].step.index,
            isCurrent: currentStep == steps[i].step,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.isDone, required this.isCurrent});

  final String label;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final Color dotColor;
    if (isDone) {
      dotColor = _kPurple;
    } else if (isCurrent) {
      dotColor = _kOrange;
    } else {
      dotColor = _kBorderHair;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ui(20),
          height: ui(20),
          decoration: BoxDecoration(
            color: isDone ? _kPurple : Colors.transparent,
            border: Border.all(color: dotColor, width: ui(2)),
            shape: BoxShape.circle,
          ),
          child: isDone
              ? Icon(Icons.check_rounded, size: ui(12), color: Colors.white)
              : null,
        ),
        SizedBox(height: ui(4)),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(9),
            color: isDone ? _kPurple : (isCurrent ? _kOrange : _kTextHint),
            fontFamily: 'PingFang SC',
            fontWeight: isDone ? AppFont.w500 : AppFont.w400,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _SmallClassStatusBadge extends StatelessWidget {
  const _SmallClassStatusBadge({required this.step});

  final _SmallClassStep step;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final String label;
    final Color color;
    final Color bg;
    switch (step) {
      case _SmallClassStep.notStarted:
        label = '未开始';
        color = _kTextHint;
        bg = _kPageBg;
        break;
      case _SmallClassStep.teacherCheckedIn:
      case _SmallClassStep.studentCheckedIn:
      case _SmallClassStep.teacherCheckedOut:
      case _SmallClassStep.studentCheckedOut:
        label = '进行中';
        color = _kOrange;
        bg = _kOrangeBg;
        break;
      case _SmallClassStep.studentEvaluated:
        label = '待确认';
        color = _kBlue;
        bg = _kBlueBg;
        break;
      case _SmallClassStep.adminConfirmed:
        label = '已完成';
        color = _kGreen;
        bg = _kGreenBg;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(7), vertical: ui(3)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(11),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 补签审核右侧抽屉
// =============================================================================

class _MakeupAuditDrawer extends StatefulWidget {
  const _MakeupAuditDrawer({
    required this.records,
    required this.onClose,
    required this.onAuditDone,
  });

  final List<_MakeupRecord> records;
  final VoidCallback onClose;
  final void Function(int remaining) onAuditDone;

  @override
  State<_MakeupAuditDrawer> createState() => _MakeupAuditDrawerState();
}

class _MakeupAuditDrawerState extends State<_MakeupAuditDrawer> {
  late final List<_MakeupRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = List.of(widget.records);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pending = _records
        .where((r) => r.status == _MakeupStatus.pending)
        .length;
    return Container(
      width: ui(520),
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(16)),
          bottomLeft: Radius.circular(ui(16)),
        ),
      ),
      child: Column(
        children: [
          // header
          Container(
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
                SizedBox(width: ui(8)),
                Text(
                  '补签申请审核',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: ui(8)),
                if (pending > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(6),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: _kRed,
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                    child: Text(
                      '$pending',
                      style: TextStyle(
                        fontSize: ui(11),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1,
                      ),
                    ),
                  ),
                const Spacer(),
                InkWell(
                  onTap: widget.onClose,
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
          ),
          // list
          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Text(
                      '暂无补签申请',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(20)),
                    itemCount: _records.length,
                    separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                    itemBuilder: (ctx, i) => _MakeupAuditCard(
                      record: _records[i],
                      onApprove: () {
                        setState(() => _records[i].status = _MakeupStatus.approved);
                        final remaining = _records
                            .where((r) => r.status == _MakeupStatus.pending)
                            .length;
                        widget.onAuditDone(remaining);
                      },
                      onReject: (reason) {
                        setState(() {
                          _records[i].status = _MakeupStatus.rejected;
                          _records[i].rejectReason = reason;
                        });
                        final remaining = _records
                            .where((r) => r.status == _MakeupStatus.pending)
                            .length;
                        widget.onAuditDone(remaining);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MakeupAuditCard extends StatelessWidget {
  const _MakeupAuditCard({
    required this.record,
    required this.onApprove,
    required this.onReject,
  });

  final _MakeupRecord record;
  final VoidCallback onApprove;
  final void Function(String reason) onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPending = record.status == _MakeupStatus.pending;
    final isApproved = record.status == _MakeupStatus.approved;
    return Container(
      padding: EdgeInsets.all(ui(14)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(
          color: isPending
              ? _kOrange.withValues(alpha: 0.4)
              : _kBorderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头
          Row(
            children: [
              _MakeupStatusBadge(status: record.status),
              const Spacer(),
              Text(
                record.applyTime,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(10)),
          // 申请人
          Row(
            children: [
              _MiniAvatar(seed: record.applicantName, size: ui(32)),
              SizedBox(width: ui(8)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.applicantName,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    record.applicantRole,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: ui(10)),
          // 补签信息
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(10)),
            decoration: BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: '课程', value: record.courseName),
                SizedBox(height: ui(6)),
                _InfoLine(label: '补签课次', value: record.lessonDate),
                SizedBox(height: ui(6)),
                _InfoLine(label: '补签理由', value: record.reason),
                SizedBox(height: ui(6)),
                _InfoLine(
                  label: '类型',
                  value: record.classType == _ClassType.large ? '大课' : '小课',
                ),
              ],
            ),
          ),
          if (record.rejectReason != null && record.rejectReason!.isNotEmpty) ...[
            SizedBox(height: ui(8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ui(10),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: _kRedBg,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Text(
                '驳回原因：${record.rejectReason}',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kRed,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
          // 操作按钮（仅待审核状态）
          if (isPending) ...[
            SizedBox(height: ui(12)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: const BorderSide(color: _kRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: ui(8)),
                    ),
                    child: Text(
                      '驳回',
                      style: TextStyle(
                        fontSize: ui(13),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ui(10)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: ui(8)),
                    ),
                    child: Text(
                      '通过',
                      style: TextStyle(
                        fontSize: ui(13),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isApproved) ...[
            SizedBox(height: ui(10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: ui(14), color: _kGreen),
                SizedBox(width: ui(4)),
                Text(
                  '已通过审核',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kGreen,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    final ui = DashboardScaleScope.of(context).ui;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '驳回原因',
          style: TextStyle(
            fontSize: ui(15),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '请填写驳回原因…',
            hintStyle: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            contentPadding: EdgeInsets.all(ui(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: _kTextSecondary, fontFamily: 'PingFang SC'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(ctx).pop();
              onReject(reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ui(8)),
              ),
            ),
            child: Text(
              '确认驳回',
              style: TextStyle(fontFamily: 'PingFang SC'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MakeupStatusBadge extends StatelessWidget {
  const _MakeupStatusBadge({required this.status});

  final _MakeupStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (String label, Color color, Color bg) = switch (status) {
      _MakeupStatus.pending => ('待审核', _kOrange, _kOrangeBg),
      _MakeupStatus.approved => ('已通过', _kGreen, _kGreenBg),
      _MakeupStatus.rejected => ('已驳回', _kRed, _kRedBg),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(7), vertical: ui(3)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(11),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 共用小组件
// =============================================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedClass,
    required this.selectedDate,
    required this.classOptions,
    required this.onClassChanged,
    required this.onDateChanged,
  });

  final String selectedClass;
  final String selectedDate;
  final List<String> classOptions;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        // 班级 dropdown
        Container(
          height: ui(34),
          padding: EdgeInsets.symmetric(horizontal: ui(10)),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedClass,
              isDense: true,
              items: classOptions
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: ui(12),
                          fontFamily: 'PingFang SC',
                          color: _kTextDark,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onClassChanged(v);
              },
            ),
          ),
        ),
        SizedBox(width: ui(10)),
        // 日期 picker pill
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  DateTime.tryParse(selectedDate) ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              helpText: '选择日期',
              cancelText: '取消',
              confirmText: '确定',
              builder: appPickerDialogTheme,
            );
            if (picked != null) {
              final iso =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              onDateChanged(iso);
            }
          },
          borderRadius: BorderRadius.circular(ui(8)),
          child: Container(
            height: ui(34),
            padding: EdgeInsets.symmetric(horizontal: ui(10)),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: _kBorderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: ui(13),
                  color: _kPurple,
                ),
                SizedBox(width: ui(5)),
                Text(
                  selectedDate,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
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
    );
  }
}

class _PendingMakeupRow extends StatelessWidget {
  const _PendingMakeupRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (count == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(10)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
        decoration: BoxDecoration(
          color: _kOrangeBg,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: _kOrange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.pending_actions_rounded, size: ui(18), color: _kOrange),
            SizedBox(width: ui(8)),
            Text(
              '待审核补签申请  $count 条',
              style: TextStyle(
                fontSize: ui(13),
                color: _kOrange,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: ui(18), color: _kOrange),
          ],
        ),
      ),
    );
  }
}

class _SignStatCard extends StatelessWidget {
  const _SignStatCard({
    required this.value,
    required this.label,
    required this.gradColors,
  });

  final String value;
  final String label;
  final List<Color> gradColors;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: ui(14), horizontal: ui(16)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: ui(24),
                color: Colors.white,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            SizedBox(height: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(11),
                color: Colors.white.withValues(alpha: 0.85),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignProgressPill extends StatelessWidget {
  const _SignProgressPill({required this.signed, required this.total});

  final int signed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isAll = signed >= total && total > 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
      decoration: BoxDecoration(
        color: isAll ? _kGreenBg : _kOrangeBg,
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Text(
        '$signed / $total 已签',
        style: TextStyle(
          fontSize: ui(11),
          color: isAll ? _kGreen : _kOrange,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final firstChar = seed.isNotEmpty ? seed.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFB98FFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        firstChar,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ui(60),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
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
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// 评价弹窗内单个学生的评价卡。
class _StudentEvalBlock extends StatelessWidget {
  const _StudentEvalBlock({required this.student});

  final _SmallClassStudentRecord student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final eval = student.evaluation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 学生信息行
        Row(
          children: [
            _MiniAvatar(seed: student.name, size: ui(28)),
            SizedBox(width: ui(8)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  student.no,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    height: 1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (eval != null)
              Row(
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < eval.rating.floor();
                    final half = !filled && i < eval.rating;
                    return Icon(
                      half ? Icons.star_half_rounded : Icons.star_rounded,
                      size: ui(14),
                      color: filled || half ? _kOrange : _kBorderSoft,
                    );
                  }),
                  SizedBox(width: ui(4)),
                  Text(
                    '${eval.rating}',
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kOrange,
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              )
            else
              Text(
                '未评价',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
          ],
        ),
        if (eval != null) ...[
          SizedBox(height: ui(8)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(10)),
            decoration: BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EvalRow(label: '掌握程度', value: eval.mastery),
                if (eval.note.isNotEmpty) ...[
                  SizedBox(height: ui(6)),
                  _EvalRow(label: '评价备注', value: eval.note),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EvalRow extends StatelessWidget {
  const _EvalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ui(64),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
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
              fontWeight: AppFont.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 数据模型
// =============================================================================

enum _StudentSignStatus {
  unsigned,
  normal,
  late,
  earlyLeave,
  leave,
  absent;

  String get label {
    switch (this) {
      case _StudentSignStatus.unsigned:
        return '未签到';
      case _StudentSignStatus.normal:
        return '正常';
      case _StudentSignStatus.late:
        return '迟到';
      case _StudentSignStatus.earlyLeave:
        return '早退';
      case _StudentSignStatus.leave:
        return '请假';
      case _StudentSignStatus.absent:
        return '缺勤';
    }
  }
}

class _StudentSignRecord {
  _StudentSignRecord({
    required this.name,
    required this.no,
    required this.status,
  });

  final String name;
  final String no;
  _StudentSignStatus status;
}

class _LargeClassSession {
  _LargeClassSession({
    required this.courseName,
    required this.timeRange,
    required this.classroom,
    required this.students,
  });

  final String courseName;
  final String timeRange;
  final String classroom;
  final List<_StudentSignRecord> students;
}

enum _SmallClassStep {
  notStarted,
  teacherCheckedIn,
  studentCheckedIn,
  teacherCheckedOut,
  studentCheckedOut,
  studentEvaluated,
  adminConfirmed,
}

class _SmallClassEvaluation {
  const _SmallClassEvaluation({
    required this.rating,
    required this.mastery,
    required this.note,
  });

  final double rating;
  final String mastery;
  final String note;
}

/// 小班课中每位学生的签到记录与课后评价。
class _SmallClassStudentRecord {
  _SmallClassStudentRecord({
    required this.name,
    required this.no,
    this.checkInTime,
    this.checkOutTime,
    this.evaluation,
  });

  final String name;
  final String no;
  /// 上课签到时间，null 表示未签到。
  String? checkInTime;
  /// 下课签到时间，null 表示未签到。
  String? checkOutTime;
  /// 课后评价，null 表示尚未评价。
  _SmallClassEvaluation? evaluation;
}

class _SmallClassSession {
  _SmallClassSession({
    required this.courseName,
    required this.teacherName,
    required this.timeRange,
    required this.classroom,
    required this.currentStep,
    required this.students,
    this.teacherCheckInTime,
    this.teacherCheckOutTime,
  });

  final String courseName;
  final String teacherName;
  final String timeRange;
  final String classroom;
  _SmallClassStep currentStep;
  /// 1 位教师 → N 位学生（小班课典型 1:2~1:4）。
  final List<_SmallClassStudentRecord> students;
  /// 教师上课签到时间，null 表示未签到。
  String? teacherCheckInTime;
  /// 教师下课签到时间，null 表示未签到。
  String? teacherCheckOutTime;
}

enum _ClassType { large, small }

enum _MakeupStatus { pending, approved, rejected }

class _MakeupRecord {
  _MakeupRecord({
    required this.applicantName,
    required this.applicantRole,
    required this.courseName,
    required this.lessonDate,
    required this.reason,
    required this.classType,
    required this.applyTime,
    required this.status,
    // ignore: unused_element_parameter
    this.rejectReason,
  });

  final String applicantName;
  final String applicantRole;
  final String courseName;
  final String lessonDate;
  final String reason;
  final _ClassType classType;
  final String applyTime;
  _MakeupStatus status;
  String? rejectReason;
}

// =============================================================================
// Demo 数据
// =============================================================================

final _kDemoLargeClassSessions = <_LargeClassSession>[
  _LargeClassSession(
    courseName: '乐理基础',
    timeRange: '08:00 - 08:45',
    classroom: '艺术楼 101',
    students: [
      _StudentSignRecord(name: '郝江', no: '2026000001', status: _StudentSignStatus.normal),
      _StudentSignRecord(name: '陈江凯', no: '2026000002', status: _StudentSignStatus.late),
      _StudentSignRecord(name: '李梓燕', no: '2026000003', status: _StudentSignStatus.normal),
      _StudentSignRecord(name: '王凯', no: '2026000004', status: _StudentSignStatus.unsigned),
      _StudentSignRecord(name: '刘思远', no: '2026000005', status: _StudentSignStatus.leave),
    ],
  ),
  _LargeClassSession(
    courseName: '音乐史',
    timeRange: '09:00 - 09:45',
    classroom: '艺术楼 报告厅',
    students: [
      _StudentSignRecord(name: '郝江', no: '2026000001', status: _StudentSignStatus.normal),
      _StudentSignRecord(name: '陈江凯', no: '2026000002', status: _StudentSignStatus.absent),
      _StudentSignRecord(name: '赵敏', no: '2026000006', status: _StudentSignStatus.normal),
    ],
  ),
  _LargeClassSession(
    courseName: '视唱练耳',
    timeRange: '10:10 - 10:55',
    classroom: '艺术楼 排练厅',
    students: [
      _StudentSignRecord(name: '郝江', no: '2026000001', status: _StudentSignStatus.unsigned),
      _StudentSignRecord(name: '李梓燕', no: '2026000003', status: _StudentSignStatus.unsigned),
      _StudentSignRecord(name: '刘思远', no: '2026000005', status: _StudentSignStatus.unsigned),
    ],
  ),
];

final _kDemoSmallClassSessions = <_SmallClassSession>[
  // 场景1：全流程完成，待管理员确认（3 名学生）
  _SmallClassSession(
    courseName: '古筝小组课',
    teacherName: '宁为',
    timeRange: '14:00 - 14:45',
    classroom: '小琴房 301',
    currentStep: _SmallClassStep.studentEvaluated,
    teacherCheckInTime: '14:02',
    teacherCheckOutTime: '14:47',
    students: [
      _SmallClassStudentRecord(
        name: '郝江', no: '2026000001',
        checkInTime: '14:05', checkOutTime: '14:46',
        evaluation: const _SmallClassEvaluation(rating: 4.5, mastery: '良好', note: '指法进步明显'),
      ),
      _SmallClassStudentRecord(
        name: '陈江凯', no: '2026000002',
        checkInTime: '14:06', checkOutTime: '14:46',
        evaluation: const _SmallClassEvaluation(rating: 4.0, mastery: '一般', note: '节奏还需加强练习'),
      ),
      _SmallClassStudentRecord(
        name: '李梓燕', no: '2026000003',
        checkInTime: '14:04', checkOutTime: '14:47',
        evaluation: const _SmallClassEvaluation(rating: 5.0, mastery: '优秀', note: '完美掌握本节内容'),
      ),
    ],
  ),
  // 场景2：进行中——教师已下课签，等学生下课签（2 名学生）
  _SmallClassSession(
    courseName: '声乐小组课',
    teacherName: '吴敏华',
    timeRange: '15:00 - 15:45',
    classroom: '录音室 B',
    currentStep: _SmallClassStep.teacherCheckedOut,
    teacherCheckInTime: '15:01',
    teacherCheckOutTime: '15:48',
    students: [
      _SmallClassStudentRecord(
        name: '王凯', no: '2026000004',
        checkInTime: '15:03', checkOutTime: null,
      ),
      _SmallClassStudentRecord(
        name: '刘思远', no: '2026000005',
        checkInTime: '15:05', checkOutTime: null,
      ),
    ],
  ),
  // 场景3：已管理员确认完成（3 名学生）
  _SmallClassSession(
    courseName: '钢琴小组课',
    teacherName: '张明远',
    timeRange: '16:00 - 16:45',
    classroom: '小琴房 205',
    currentStep: _SmallClassStep.adminConfirmed,
    teacherCheckInTime: '16:00',
    teacherCheckOutTime: '16:46',
    students: [
      _SmallClassStudentRecord(
        name: '李梓燕', no: '2026000003',
        checkInTime: '16:02', checkOutTime: '16:45',
        evaluation: const _SmallClassEvaluation(rating: 5.0, mastery: '优秀', note: '完成了第三章练习曲'),
      ),
      _SmallClassStudentRecord(
        name: '赵敏', no: '2026000006',
        checkInTime: '16:01', checkOutTime: '16:45',
        evaluation: const _SmallClassEvaluation(rating: 4.5, mastery: '良好', note: '情感表达有进步'),
      ),
      _SmallClassStudentRecord(
        name: '陈江凯', no: '2026000002',
        checkInTime: '16:03', checkOutTime: '16:44',
        evaluation: const _SmallClassEvaluation(rating: 4.0, mastery: '一般', note: '左手力度不稳，需重点练习'),
      ),
    ],
  ),
  // 场景4：尚未开始（2 名学生）
  _SmallClassSession(
    courseName: '竖笛小组课',
    teacherName: '林小燕',
    timeRange: '17:00 - 17:45',
    classroom: '小琴房 102',
    currentStep: _SmallClassStep.notStarted,
    students: [
      _SmallClassStudentRecord(name: '赵敏', no: '2026000006'),
      _SmallClassStudentRecord(name: '郝江', no: '2026000001'),
    ],
  ),
  // 场景5：进行中——学生已上课签，等教师下课签（4 名学生）
  _SmallClassSession(
    courseName: '乐团分组排练',
    teacherName: '陈建国',
    timeRange: '13:00 - 14:30',
    classroom: '排练厅 A',
    currentStep: _SmallClassStep.studentCheckedIn,
    teacherCheckInTime: '13:01',
    students: [
      _SmallClassStudentRecord(name: '郝江', no: '2026000001', checkInTime: '13:05'),
      _SmallClassStudentRecord(name: '李梓燕', no: '2026000003', checkInTime: '13:04'),
      _SmallClassStudentRecord(name: '王凯', no: '2026000004', checkInTime: '13:07'),
      _SmallClassStudentRecord(name: '刘思远', no: '2026000005', checkInTime: '13:10'),
    ],
  ),
];

final _kDemoMakeupRecords = <_MakeupRecord>[
  _MakeupRecord(
    applicantName: '郝江',
    applicantRole: '学生 · 音乐一班',
    courseName: '乐理基础',
    lessonDate: '2026-05-14  08:00-08:45',
    reason: '当日发烧请假，已提交请假条',
    classType: _ClassType.large,
    applyTime: '2026-05-15 10:22',
    status: _MakeupStatus.pending,
  ),
  _MakeupRecord(
    applicantName: '宁为',
    applicantRole: '教师 · 古筝课',
    courseName: '古筝一对一',
    lessonDate: '2026-05-10  14:00-14:45',
    reason: '课堂签到系统故障导致下课签未记录',
    classType: _ClassType.small,
    applyTime: '2026-05-11 09:05',
    status: _MakeupStatus.pending,
  ),
  _MakeupRecord(
    applicantName: '陈江凯',
    applicantRole: '学生 · 乐理一班',
    courseName: '视唱练耳',
    lessonDate: '2026-05-08  10:10-10:55',
    reason: '网络问题导致上课签到失败',
    classType: _ClassType.large,
    applyTime: '2026-05-09 14:30',
    status: _MakeupStatus.approved,
  ),
];
