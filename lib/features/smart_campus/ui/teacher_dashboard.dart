import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/smart_campus_dashboard_data.dart';
import '../state/smart_campus_state.dart';
import 'widgets/role_switcher_buttons.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 用于尚未迁移完成的快捷按钮：弹一个轻提示，避免"点了没反应"。
/// 真实视图迁移到 Flutter 后再把对应 onTap 替换成具体回调。
void _showActionPending(BuildContext context, String label) {
  AppToast.show(context, '「$label」页面迁移中');
}

/// 任课老师 / 班主任端的智慧校园首页布局。
///
/// 与学生端 / 管理员端走的是不同的视觉系统：
/// - 顶部 6 张统计卡（4 个数值 + 「本周课时」 + 紫色「下一节」）
/// - 中间为 `#EFF3FC` 浅紫面板，承载 8 宫功能矩阵
/// - 右栏 256 宽白底面板：头像 + 在岗胶囊 + 主项/副项/带班 +
///   任课老师 / 班主任 tab 切换 + 通知列表
///
/// `selectedRole` 来自全局 `smartCampusControllerProvider`，dashboard 内
/// 「任课老师 ↔ 班主任」tab 走 **本地 `_localTab` + 全局 `onSelectRole`** 双轨：
///   - 本地 `_localTab`：负责立刻切换 UI（任何账号都能点），由 `_selectTab`
///     的 `setState` 立即写入。
///   - 全局 `onSelectRole = controller.selectRole`：负责持久化身份。
///     - admin：`availableRoles` 含 5 个，`selectRole` 写入 state，从而
///       进出「班级工作台 / 学生名册 / 作业批改 / 考评管理」等子页再
///       返回 dashboard 时，依靠 controller 的 `hasUserSelectedRole`
///       标记保持「班主任」视角不被 `applyBackendRole` 覆盖。
///     - 普通教师：`selectRole` 会被 ignore，`state.selectedRole` 保持不变，
///       但本地 `_localTab` 已经切到 headTeacher，UI 仍然给出班主任视图的
///       本地预览（一次性，重新进入 dashboard 后会回到自身角色）。
///   - `didUpdateWidget` 仅在 `widget.selectedRole` 真正发生变化时才把
///     `_localTab` 同步为 `widget.selectedRole`，避免没变化时把已经切到的
///     本地预览打回去。
class TeacherDashboardLayout extends StatefulWidget {
  const TeacherDashboardLayout({
    super.key,
    required this.selectedRole,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.availableRoles = const [
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
    ],
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenLeaveApproval,
    this.onOpenDormDynamic,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
    this.onSelectRole,
    this.roleSwitcher,
  });

  final SmartCampusRole selectedRole;

  /// 当前用户实际可用的全部身份。由 `SmartCampusState.availableRoles`
  /// 提供，来自 `myInfo.role` + `/teacher/teacherRole` 的合并解析结果。
  /// 决定右栏「身份切换」按钮组渲染哪些按钮（默认兜底为「任课老师 +
  /// 班主任」两枚，保持以前的演示行为）。
  final List<SmartCampusRole> availableRoles;
  final String shellDisplayName;
  final String avatarUrl;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;

  /// 班主任专属：进入「班级工作台」三 Tab 页面（与学生「我的班级」分开）。
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;

  /// 学生端「课堂签到」入口；老师端没这个按钮，传 null 即可，
  /// `_TeacherActionPanel` 会在 label 命中但回调为空时走兜底 SnackBar。
  final VoidCallback? onOpenCheckIn;

  /// 学生端「我的作业」入口；老师端没这个按钮，传 null 即可。
  final VoidCallback? onOpenMyHomework;

  /// 学生端「我的成绩」入口；老师端没这个按钮，传 null 即可。
  final VoidCallback? onOpenMyGrades;

  /// 「群聊」入口（学生 / 教师 / 班主任 共用同一个聊天页面）。
  final VoidCallback? onOpenGroupChat;

  /// 「校圈」入口：学生 / 教师 / 班主任 / 宿管 共用，跳转到首页同名校圈
  /// 详情（CirclePage / RoutePaths.circle）。
  final VoidCallback? onOpenSchoolCircle;

  /// 学生端「请假管理」入口（"请假补课"页面）；其他角色入口名为
  /// "请假审批" / "宿管请假"，走各自独立路由。
  final VoidCallback? onOpenLeaveManagement;

  /// 学生端「查寝管理」入口：仅展示本人查寝记录 + 申请补卡。
  final VoidCallback? onOpenDormCheck;

  /// 任课老师 / 班主任「签课管理」入口：进入签到总览页（5 项统计 +
  /// 最近签课记录 + 今日课程 + 大课/小课签到操作面板）。
  final VoidCallback? onOpenClassAttendance;

  /// 任课老师 / 班主任「学生名册」入口：进入名册总览页（班级 dropdown +
  /// 搜索 + 当前/男/女 3 张统计卡 + 学生卡 3 列网格）。
  final VoidCallback? onOpenStudentRoster;

  /// 任课老师 / 班主任「作业批改」入口：进入"作业与批改"总览页（4 状态 tabs +
  /// 班级 dropdown + 累计/本学期/本月 toggle + 6 项统计 + 左作业列表 + 右
  /// 当前作业的提交学生表，并通过右抽屉发布作业 / 查看历史发布记录 /
  /// 进入作业点评）。
  final VoidCallback? onOpenHomeworkReview;

  /// 任课老师 / 班主任「考评管理」入口：进入"考评管理"总览页（5 状态 tabs +
  /// 班级 dropdown + 累计/本学期/本月 + 6 项统计 + 左考试列表（N/M 提交比）+
  /// 右考试详情(月考同步说明 + 4 项指标 + 学生提交表)，仅查看不可新建考试，
  /// 通过右抽屉查看历史月考 / 进入评分点评）。
  final VoidCallback? onOpenExamReview;

  /// 班主任「请假审批」入口：进入审批本班学生请假申请的页面（4 张统计卡 +
  /// 提示与备案说明 + 6 状态 tabs + 搜索框 + 双列申请卡片，审批中卡片
  /// 底部"通过 / 驳回"按钮，"驳回"打开 `GradientHeaderDialog` 弹窗）。
  final VoidCallback? onOpenLeaveApproval;

  /// 班主任「查寝动态」入口：进入掌握本班住宿生归宿与晨检结果的页面
  /// （4 张统计卡 + tabs「本班查纪 / 补卡审核」+ 学生口径 / 宿舍口径
  /// 卡片网格 + 全部 / 异常 toggle）。
  final VoidCallback? onOpenDormDynamic;

  /// 班主任「查寝历史」入口：按自然日查看本班住宿生晚查寝/晨查寝打卡
  /// 汇总（顶部 banner + 14 天日期条 + 4 张统计卡 + 晚查寝/晨查寝 tabs +
  /// 宿舍口径 / 学生口径混合卡片网格）。
  final VoidCallback? onOpenDormHistory;

  /// 班主任「家校沟通」入口：与本班学生家长就请假、成绩、心理等进行
  /// 文字沟通（banner + 3 张统计卡 + 全部/未读/待回复 tabs + 搜索 +
  /// 家长对话卡 3 列网格 + 点击进入对话详情弹窗）。
  final VoidCallback? onOpenHomeSchool;

  /// 切换 dashboard 中「任课老师 / 班主任」tab 时的回调：通常由
  /// [SmartCampusPage] 传 `controller.selectRole`，让管理员的切换持久化到
  /// 全局 state；普通教师没有班主任权限时 `selectRole` 会被忽略，UI 也
  /// 不会切换——这是合理的业务约束。
  final ValueChanged<SmartCampusRole>? onSelectRole;

  /// 管理员等多身份用户使用的悬浮身份切换器；教师/班主任传 null。
  final Widget? roleSwitcher;

  @override
  State<TeacherDashboardLayout> createState() => _TeacherDashboardLayoutState();
}

class _TeacherDashboardLayoutState extends State<TeacherDashboardLayout> {
  late SmartCampusRole _localTab;

  @override
  void initState() {
    super.initState();
    _localTab = _coerceRole(widget.selectedRole);
  }

  @override
  void didUpdateWidget(covariant TeacherDashboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当上层 `widget.selectedRole` 真的发生变化时，才让它覆盖本地 tab。
    // - admin 在 placeholder / dashboard 切到班主任 → controller state 改变
    //   → didUpdateWidget 触发 → 同步 _localTab。
    // - 普通教师在 dashboard 内点「班主任」tab：selectRole 被 ignore，
    //   widget.selectedRole 不变，didUpdateWidget 不会触发，本地预览保留。
    if (oldWidget.selectedRole != widget.selectedRole) {
      _localTab = _coerceRole(widget.selectedRole);
    }
  }

  // 仅允许 tab 在 teacher / headTeacher 之间切换；其他角色容错回退到 teacher。
  SmartCampusRole _coerceRole(SmartCampusRole role) {
    if (role == SmartCampusRole.teacher ||
        role == SmartCampusRole.headTeacher) {
      return role;
    }
    return SmartCampusRole.teacher;
  }

  void _selectTab(SmartCampusRole role) {
    // 跨端身份（admin / dormManager / student）：本地预览没意义（教师
    // dashboard 不能渲染管理员视图），直接交给 controller 切换 state，
    // SmartCampusPage 会重新路由到目标身份的大 dashboard，本 widget 卸载。
    if (role != SmartCampusRole.teacher &&
        role != SmartCampusRole.headTeacher) {
      widget.onSelectRole?.call(role);
      return;
    }
    if (_localTab == role) {
      return;
    }
    // 立刻给 UI 一个回应（任何账号都能点）；
    // 同时把切换持久化给 controller：admin / 多身份教师会写入 state，
    // 单身份的普通教师被 ignore（仅保留本地预览效果）。
    setState(() {
      _localTab = role;
    });
    widget.onSelectRole?.call(role);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = smartCampusDashboardDataForRole(_localTab);

    return LayoutBuilder(
      builder: (context, constraints) {
        var cw = constraints.maxWidth;
        if (!cw.isFinite || cw == double.infinity || cw < 2) {
          final w = MediaQuery.sizeOf(context).width;
          cw = (w - ui(ShellLayoutSpec.sidebarWidth) - ui(16) * 2).clamp(
            240.0,
            20000.0,
          );
        }
        final isCompact = cw < ui(900);
        final sidebarWidth = ui(256);
        final contentGap = ui(16);
        final mainWidth = isCompact
            ? cw
            : math.max(0.0, cw - sidebarWidth - contentGap);

        if (isCompact) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.roleSwitcher != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: widget.roleSwitcher,
                  ),
                  SizedBox(height: ui(12)),
                ],
                _TeacherMainColumn(
                  data: data,
                  width: mainWidth,
                  fillRemaining: false,
                  onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                  onOpenMyClass: widget.onOpenMyClass,
                  onOpenClassWorkbench: widget.onOpenClassWorkbench,
                  onOpenMySchedule: widget.onOpenMySchedule,
                  onOpenCheckIn: widget.onOpenCheckIn,
                  onOpenMyHomework: widget.onOpenMyHomework,
                  onOpenMyGrades: widget.onOpenMyGrades,
                  onOpenGroupChat: widget.onOpenGroupChat,
                  onOpenSchoolCircle: widget.onOpenSchoolCircle,
                  onOpenLeaveManagement: widget.onOpenLeaveManagement,
                  onOpenDormCheck: widget.onOpenDormCheck,
                  onOpenClassAttendance: widget.onOpenClassAttendance,
                  onOpenStudentRoster: widget.onOpenStudentRoster,
                  onOpenHomeworkReview: widget.onOpenHomeworkReview,
                  onOpenExamReview: widget.onOpenExamReview,
                  onOpenLeaveApproval: widget.onOpenLeaveApproval,
                  onOpenDormDynamic: widget.onOpenDormDynamic,
                  onOpenDormHistory: widget.onOpenDormHistory,
                  onOpenHomeSchool: widget.onOpenHomeSchool,
                ),
                SizedBox(height: ui(16)),
                _TeacherSidebar(
                  data: data,
                  width: cw,
                  selectedTab: _localTab,
                  onTabSelected: _selectTab,
                  availableRoles: widget.availableRoles,
                  shellDisplayName: widget.shellDisplayName,
                  avatarUrl: widget.avatarUrl,
                  fillHeight: false,
                ),
              ],
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: mainWidth,
              child: _TeacherMainColumn(
                data: data,
                width: mainWidth,
                fillRemaining: true,
                onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                onOpenMyClass: widget.onOpenMyClass,
                onOpenClassWorkbench: widget.onOpenClassWorkbench,
                onOpenMySchedule: widget.onOpenMySchedule,
                onOpenCheckIn: widget.onOpenCheckIn,
                onOpenMyHomework: widget.onOpenMyHomework,
                onOpenMyGrades: widget.onOpenMyGrades,
                onOpenGroupChat: widget.onOpenGroupChat,
                onOpenSchoolCircle: widget.onOpenSchoolCircle,
                onOpenLeaveManagement: widget.onOpenLeaveManagement,
                onOpenDormCheck: widget.onOpenDormCheck,
                onOpenClassAttendance: widget.onOpenClassAttendance,
                onOpenStudentRoster: widget.onOpenStudentRoster,
                onOpenHomeworkReview: widget.onOpenHomeworkReview,
                onOpenExamReview: widget.onOpenExamReview,
                onOpenLeaveApproval: widget.onOpenLeaveApproval,
                onOpenDormDynamic: widget.onOpenDormDynamic,
                onOpenDormHistory: widget.onOpenDormHistory,
                onOpenHomeSchool: widget.onOpenHomeSchool,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sidebarWidth,
              child: _TeacherSidebar(
                data: data,
                width: sidebarWidth,
                selectedTab: _localTab,
                onTabSelected: _selectTab,
                availableRoles: widget.availableRoles,
                shellDisplayName: widget.shellDisplayName,
                avatarUrl: widget.avatarUrl,
                fillHeight: true,
              ),
            ),
            if (widget.roleSwitcher != null)
              Positioned(
                top: ui(6),
                right: sidebarWidth + ui(8),
                child: widget.roleSwitcher!,
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// 主区：顶部统计行 + 中间浅紫面板（功能矩阵）
// =============================================================================

class _TeacherMainColumn extends StatelessWidget {
  const _TeacherMainColumn({
    required this.data,
    required this.width,
    required this.fillRemaining,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenLeaveApproval,
    this.onOpenDormDynamic,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
  });

  final SmartCampusDashboardData data;
  final double width;
  final bool fillRemaining;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;
  final VoidCallback? onOpenCheckIn;
  final VoidCallback? onOpenMyHomework;
  final VoidCallback? onOpenMyGrades;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenLeaveManagement;
  final VoidCallback? onOpenDormCheck;
  final VoidCallback? onOpenClassAttendance;
  final VoidCallback? onOpenStudentRoster;
  final VoidCallback? onOpenHomeworkReview;
  final VoidCallback? onOpenExamReview;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenDormDynamic;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenHomeSchool;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final actionPanel = _TeacherActionPanel(
      data: data,
      onOpenPrincipalMailbox: onOpenPrincipalMailbox,
      onOpenMyClass: onOpenMyClass,
      onOpenClassWorkbench: onOpenClassWorkbench,
      onOpenMySchedule: onOpenMySchedule,
      onOpenCheckIn: onOpenCheckIn,
      onOpenMyHomework: onOpenMyHomework,
      onOpenMyGrades: onOpenMyGrades,
      onOpenGroupChat: onOpenGroupChat,
      onOpenSchoolCircle: onOpenSchoolCircle,
      onOpenLeaveManagement: onOpenLeaveManagement,
      onOpenDormCheck: onOpenDormCheck,
      onOpenClassAttendance: onOpenClassAttendance,
      onOpenStudentRoster: onOpenStudentRoster,
      onOpenHomeworkReview: onOpenHomeworkReview,
      onOpenExamReview: onOpenExamReview,
      onOpenLeaveApproval: onOpenLeaveApproval,
      onOpenDormDynamic: onOpenDormDynamic,
      onOpenDormHistory: onOpenDormHistory,
      onOpenHomeSchool: onOpenHomeSchool,
    );

    // 任课老师：当前课程 + 今日课表；班主任：当前事项 + 班务
    Widget bottomSection({required bool fill}) {
      if (data.role == SmartCampusRole.headTeacher) {
        return _HeadTeacherBoardSection(
          onOpenWorkbench: onOpenClassWorkbench,
          fillRemaining: fill,
        );
      }
      return _TeacherScheduleSection(
        onOpenMySchedule: onOpenMySchedule,
        fillRemaining: fill,
      );
    }

    if (fillRemaining) {
      // 父级 (Stack > Positioned(top:0,bottom:0)) 提供了有界高度。
      // 让底部双卡 Expanded 撑满剩余空间。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          _TeacherStatRow(stats: data.stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          Expanded(child: bottomSection(fill: true)),
        ],
      );
    }

    // 紧凑模式（compact）：父级高度无界，整个主列交给滚动容器承载。
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherStatRow(stats: data.stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          bottomSection(fill: false),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _TeacherStatRow extends StatelessWidget {
  const _TeacherStatRow({required this.stats, required this.width});

  final List<SmartCampusStatCardData> stats;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    final ui = DashboardScaleScope.of(context).ui;
    // 父级（Column / ScrollView）纵向高度通常无界；这里先用 SizedBox 给一个
    // 有界高度（68），Row 内部就可以安全使用 stretch 让 6 张卡等高铺满。
    return SizedBox(
      width: width.isFinite && width > 0 ? width : null,
      height: ui(68),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            Expanded(child: _TeacherStatCard(item: stats[i])),
          ],
        ],
      ),
    );
  }
}

class _TeacherStatCard extends StatelessWidget {
  const _TeacherStatCard({required this.item});

  final SmartCampusStatCardData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    // 紫色「下一节 15:30」卡 / 班主任端「待办 9」卡：紫字 24px 在上、灰色 12px 标签在下。
    final isNextLesson = item.label == '下一节' || item.label == '待办';
    // 文字型 value（非纯数字）走 16px：避免"周五 / 186天"在 24px 下显得太挤。
    //   - 老师端："本周课时" → 周五
    //   - 班主任端："关注学生" → 周五
    //   - 学生端："月考时间" → 周五；"距离省统考" → 186天
    final isWeekly =
        item.label == '本周课时' ||
        item.label == '关注学生' ||
        item.label == '月考时间' ||
        item.label == '距离省统考';

    Widget value;
    if (isNextLesson) {
      value = Text(
        item.value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(24),
          color: const Color(0xFF8741FF),
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      );
    } else if (isWeekly) {
      value = Text(
        item.value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(16),
          color: const Color(0xFF0B081A),
          fontWeight: FontWeight.w500,
          height: 1.1,
        ),
      );
    } else {
      value = Text(
        item.value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(24),
          color: const Color(0xFF0B081A),
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.07),
            blurRadius: ui(12),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          value,
          SizedBox(height: ui(6)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF6D6B75),
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherActionPanel extends StatelessWidget {
  const _TeacherActionPanel({
    required this.data,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenLeaveApproval,
    this.onOpenDormDynamic,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
  });

  final SmartCampusDashboardData data;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;
  final VoidCallback? onOpenCheckIn;
  final VoidCallback? onOpenMyHomework;
  final VoidCallback? onOpenMyGrades;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenLeaveManagement;
  final VoidCallback? onOpenDormCheck;
  final VoidCallback? onOpenClassAttendance;
  final VoidCallback? onOpenStudentRoster;
  final VoidCallback? onOpenHomeworkReview;
  final VoidCallback? onOpenExamReview;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenDormDynamic;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenHomeSchool;

  VoidCallback? _onTapForLabel(String label) {
    switch (label) {
      case '校长信箱':
        return onOpenPrincipalMailbox;
      case '我的班级':
        return onOpenMyClass;
      case '班级工作台':
        // 班主任专属入口：进入独立三 Tab 工作台（概况 / 学生管理 / 成绩），
        // 与学生「我的班级」简版页面分开，避免 selectedRole 误判路由到学生页。
        return onOpenClassWorkbench;
      // "授课课表"是老师端 label，"我的课表"是学生端 label，
      // 但都对应同一个 mainView 切换 (`openMySchedule`)。
      case '授课课表':
      case '我的课表':
        return onOpenMySchedule;
      // 学生端独有：课堂签到。老师端没这个按钮，回调可能为 null，由
      // _TeacherActionTile 兜底弹"页面迁移中"SnackBar。
      case '课堂签到':
        return onOpenCheckIn;
      // 学生端独有：我的作业。老师端的 "作业批改" 是另一条入口，单独处理。
      case '我的作业':
        return onOpenMyHomework;
      // 学生端独有：我的成绩，进入「成绩与排名」总览页。
      case '我的成绩':
        return onOpenMyGrades;
      // 五端共用：群聊（任一角色点击都进入同一聊天主界面）。
      case '群聊':
        return onOpenGroupChat;
      // 学生 / 教师 / 班主任 / 宿管 共用：「校圈」按钮 → 跳转到首页同名校圈
      // 全屏页（CirclePage / RoutePaths.circle）。学生历史 label 是 "校园"，
      // 数据层已统一改为 "校圈"。
      case '校圈':
        return onOpenSchoolCircle;
      // 学生端独有：「请假管理」→ 进入"请假补课"页面。
      case '请假管理':
        return onOpenLeaveManagement;
      // 学生端独有：「查寝管理」→ 进入个人查寝/补卡页面。
      case '查寝管理':
        return onOpenDormCheck;
      // 任课老师/班主任专属：「签课管理」→ 进入授课签到总览页（5 项统计 +
      // 最近签课记录 + 今日课程 + 大课/小课双模签到操作面板）。
      case '签课管理':
        return onOpenClassAttendance;
      // 任课老师/班主任专属：「学生名册」→ 进入名册总览页（班级 dropdown +
      // 搜索 + 当前/男/女 3 张统计卡 + 学生卡 3 列网格）。
      case '学生名册':
        return onOpenStudentRoster;
      // 任课老师/班主任专属：「作业批改」→ 进入"作业与批改"总览页（4 状态
      // tabs + 班级 dropdown + 累计/本学期/本月 toggle + 6 项统计 + 左作业
      // 列表 + 右当前作业的提交学生表，支持发布作业 / 历史发布记录 /
      // 作业点评 3 个右抽屉）。
      case '作业批改':
        return onOpenHomeworkReview;
      // 任课老师/班主任专属：「考评管理」→ 进入"考评管理"总览页（5 状态
      // tabs + 班级 dropdown + 累计/本学期/本月 + 6 项统计 + 左考试列表
      // (N/M 提交比) + 右考试详情(月考同步说明 + 4 项指标 + 学生提交表)；
      // 仅可查看与评分，不可新建考试，通过右抽屉历史月考 / 评分 进入操作）。
      case '考评管理':
        return onOpenExamReview;
      // 班主任专属：「请假审批」→ 进入审批本班学生请假申请的总览页（4 张
      // 统计卡 + 提示与备案说明 + 6 状态 tabs + 搜索 + 双列申请卡片，审批中
      // 卡片底部"通过 / 驳回"按钮，"驳回"打开 GradientHeaderDialog 弹窗）。
      case '请假审批':
        return onOpenLeaveApproval;
      // 班主任专属：「查寝动态」→ 进入掌握本班住宿生归宿与晨检结果、协同
      // 处理补卡与异常跟进的总览页（4 张统计卡 + 「本班查纪 / 补卡审核」
      // tabs + 搜索 + 「全部异常记录 N 条」+ 全部 / 异常 toggle + 学生口径
      // 与宿舍口径两类卡片网格）。
      case '查寝动态':
        return onOpenDormDynamic;
      // 班主任专属：「查寝历史」→ 进入按自然日查看本班住宿生晚查寝/晨查寝
      // 打卡汇总的总览页（顶部 banner + 14 天日期条 + 4 张统计卡 +
      // 晚查寝 / 晨查寝 tabs + 宿舍口径 / 学生口径混合卡片网格）。
      case '查寝历史':
        return onOpenDormHistory;
      // 班主任专属：「家校沟通」→ 进入与本班学生家长就请假/成绩/心理等
      // 进行文字沟通的总览页（banner + 3 张统计卡 + 全部/未读/待回复 tabs
      // + 搜索 + 家长对话卡 3 列网格 + 点击进入对话详情弹窗）。
      case '家校沟通':
        return onOpenHomeSchool;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Figma：容器 H 255、padding 38/24/38/24；按钮 82×70；一行 5 个。
    // 老师端共 8 个 → 2 行（5 + 3）。横向间距由 spaceBetween 在剩余空间内
    // 均分（标准设计宽下 ≈ 21px）；纵向两行间距由 Column.spaceBetween
    // 在剩余 (255 − 76 − 70×2) = 39px 内分配。
    const cross = 5;
    final actions = data.actions;
    final rowsCount = actions.isEmpty ? 0 : ((actions.length - 1) ~/ cross) + 1;
    final rows = <Widget>[
      for (var r = 0; r < rowsCount; r++)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var c = 0; c < cross; c++)
              SizedBox(
                width: ui(82),
                height: ui(70),
                child: _buildSlot(r * cross + c, actions),
              ),
          ],
        ),
    ];

    return Container(
      width: double.infinity,
      height: ui(255),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(38)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: rowsCount > 1
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildSlot(int idx, List<SmartCampusQuickActionData> actions) {
    if (idx >= actions.length) {
      return const SizedBox.shrink();
    }
    final item = actions[idx];
    return _TeacherActionTile(item: item, onTap: _onTapForLabel(item.label));
  }
}

class _TeacherActionTile extends StatelessWidget {
  const _TeacherActionTile({required this.item, this.onTap});

  final SmartCampusQuickActionData item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final box = ui(38);

    Widget iconBox;
    if (item.imagePath != null) {
      iconBox = Image.asset(
        item.imagePath!,
        width: box,
        height: box,
        fit: BoxFit.contain,
      );
    } else {
      iconBox = Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          color: item.background,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: Icon(item.icon, size: ui(22), color: item.foreground),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(ui(12)),
      // 没有具体跳转的按钮也要给反馈，避免"点了没反应"。
      onTap: onTap ?? () => _showActionPending(context, item.label),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              iconBox,
              if (item.badge > 0)
                Positioned(
                  right: ui(-10),
                  top: ui(-4),
                  child: Container(
                    constraints: BoxConstraints(minWidth: ui(24)),
                    height: ui(16),
                    padding: EdgeInsets.symmetric(horizontal: ui(5)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF04545),
                      borderRadius: BorderRadius.circular(ui(20)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.badge > 99 ? '99+' : '${item.badge}+',
                      style: TextStyle(
                        fontSize: ui(9),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF1A1A1A),
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

// =============================================================================
// 右栏：头像 + 在岗 + 标签 + 主项/副项/带班 + Tab + 通知
// =============================================================================

class _TeacherSidebar extends StatelessWidget {
  const _TeacherSidebar({
    required this.data,
    required this.width,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.fillHeight,
    this.selectedTab,
    this.onTabSelected,
    this.availableRoles = const [
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
    ],
  });

  final SmartCampusDashboardData data;
  final double width;
  // 学生端无身份切换：两者均为 null 时整个切换区不渲染。
  final SmartCampusRole? selectedTab;
  final ValueChanged<SmartCampusRole>? onTabSelected;

  /// 来自 [TeacherDashboardLayout.availableRoles]。当包含 teacher /
  /// headTeacher 之外的身份（admin / dormManager / student）时，使用通
  /// 用的 [RoleSwitcherButtons]；只剩任课老师 + 班主任两枚时退回原先的
  /// 固定 2 Tab，保留单身份教师"本地预览"的演示体验。
  final List<SmartCampusRole> availableRoles;
  final String shellDisplayName;
  final String avatarUrl;
  final bool fillHeight;

  /// 判断是否需要走"通用多身份"切换器：只要 availableRoles 出现 teacher /
  /// headTeacher 之外的成员（典型场景：管理员账户、跨端老师），就升级到
  /// 全量按钮列表。
  bool get _hasExtraRoles {
    for (final role in availableRoles) {
      if (role != SmartCampusRole.teacher &&
          role != SmartCampusRole.headTeacher) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final card = Container(
      width: width.isFinite && width > 0 ? width : ui(256),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.06),
            blurRadius: ui(12),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: Column(
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeacherProfileBlock(
              data: data,
              shellDisplayName: shellDisplayName,
              avatarUrl: avatarUrl,
            ),
            SizedBox(height: ui(20)),
            if (selectedTab != null && onTabSelected != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(20)),
                // 多身份用户（admin / 跨端教师）走通用按钮组，按 availableRoles
                // 渲染；普通"任课老师 + 班主任"仍走原 2 Tab 以保留单身份
                // 教师在演示账号下"本地预览"班主任视图的体验。
                child: _hasExtraRoles
                    ? RoleSwitcherButtons(
                        availableRoles: availableRoles,
                        selectedRole: selectedTab!,
                        onSelectRole: onTabSelected!,
                      )
                    : _TeacherRoleTabs(
                        selected: selectedTab!,
                        onChanged: onTabSelected!,
                      ),
              ),
              SizedBox(height: ui(28)),
            ],
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(16)),
              child: Text(
                '通知',
                style: TextStyle(
                  fontSize: ui(16),
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            if (fillHeight)
              Expanded(
                child: _TeacherNoticeList(
                  notices: data.notices,
                  scrollable: true,
                ),
              )
            else
              _TeacherNoticeList(notices: data.notices, scrollable: false),
            SizedBox(height: ui(16)),
          ],
        ),
      ),
    );
    return card;
  }
}

class _TeacherProfileBlock extends StatelessWidget {
  const _TeacherProfileBlock({
    required this.data,
    required this.shellDisplayName,
    required this.avatarUrl,
  });

  final SmartCampusDashboardData data;
  final String shellDisplayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final profile = data.profile;
    final displayName = shellDisplayName.isNotEmpty
        ? shellDisplayName
        : profile.name;

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(20), ui(24), ui(20), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TeacherAvatar(avatarUrl: avatarUrl, size: ui(72)),
                  SizedBox(width: ui(12)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: ui(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: ui(16),
                                    color: const Color(0xFF0B081A),
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              SizedBox(width: ui(6)),
                              _TeacherStatusChip(label: profile.title),
                            ],
                          ),
                          SizedBox(height: ui(6)),
                          Text(
                            profile.organization,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: const Color(0xFF6D6B75),
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(14)),
              _TeacherDetailLines(lines: profile.detailLines),
            ],
          ),
          // 头像右下方的「老师」黄色胶囊
          Positioned(
            left: ui(58),
            top: ui(62),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ui(7), vertical: ui(2)),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEE49),
                borderRadius: BorderRadius.circular(ui(10)),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                profile.badgeLabel,
                style: TextStyle(
                  fontSize: ui(11),
                  color: const Color(0xFF0B081A),
                  fontWeight: FontWeight.w400,
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

class _TeacherAvatar extends StatelessWidget {
  const _TeacherAvatar({required this.avatarUrl, required this.size});

  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget child;
    if (avatarUrl.isNotEmpty) {
      child = Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(ui),
      );
    } else {
      child = _fallback(ui);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: child),
    );
  }

  Widget _fallback(double Function(double) ui) {
    return Container(
      color: const Color(0xFFEAE5FF),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: ui(36),
        color: const Color(0xFF8F63FF),
      ),
    );
  }
}

class _TeacherStatusChip extends StatelessWidget {
  const _TeacherStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(6)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(color: const Color(0xFFF3F2F3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: const BoxDecoration(
              color: Color(0xFF12C58A),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF0B081A),
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherDetailLines extends StatelessWidget {
  const _TeacherDetailLines({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines) ...[
          _TeacherDetailLine(line: line),
          SizedBox(height: ui(4)),
        ],
      ],
    );
  }
}

class _TeacherDetailLine extends StatelessWidget {
  const _TeacherDetailLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final idx = line.indexOf('：');
    final label = idx >= 0 ? line.substring(0, idx + 1) : '';
    final value = idx >= 0 ? line.substring(idx + 1) : line;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF0B081A),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherRoleTabs extends StatelessWidget {
  const _TeacherRoleTabs({required this.selected, required this.onChanged});

  final SmartCampusRole selected;
  final ValueChanged<SmartCampusRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _TeacherRoleTabButton(
            label: '任课老师',
            active: selected == SmartCampusRole.teacher,
            onTap: () => onChanged(SmartCampusRole.teacher),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _TeacherRoleTabButton(
            label: '班主任',
            active: selected == SmartCampusRole.headTeacher,
            onTap: () => onChanged(SmartCampusRole.headTeacher),
          ),
        ),
      ],
    );
  }
}

class _TeacherRoleTabButton extends StatelessWidget {
  const _TeacherRoleTabButton({
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
      borderRadius: BorderRadius.circular(ui(8)),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8741FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: active ? Colors.white : const Color(0xFF0B081A),
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TeacherNoticeList extends StatelessWidget {
  const _TeacherNoticeList({required this.notices, required this.scrollable});

  final List<SmartCampusNoticeData> notices;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final children = <Widget>[];
    for (var i = 0; i < notices.length; i++) {
      if (i > 0) children.add(SizedBox(height: ui(8)));
      children.add(_TeacherNoticeCard(item: notices[i]));
    }
    final list = Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
    if (scrollable) {
      return SingleChildScrollView(child: list);
    }
    return list;
  }
}

class _TeacherNoticeCard extends StatelessWidget {
  const _TeacherNoticeCard({required this.item});

  final SmartCampusNoticeData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(10), ui(10), ui(10), ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(right: ui(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(4),
                        vertical: ui(2),
                      ),
                      decoration: BoxDecoration(
                        color: item.tagBackground,
                        borderRadius: BorderRadius.circular(ui(4)),
                      ),
                      child: Text(
                        item.tag,
                        style: TextStyle(
                          fontSize: ui(10),
                          color: item.tagForeground,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ),
                    SizedBox(width: ui(4)),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: const Color(0xFF0B081A),
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(4)),
                Text(
                  item.time,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFFCECED1),
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: ui(6),
              height: ui(6),
              decoration: BoxDecoration(
                color: item.unread
                    ? const Color(0xFFFF323C)
                    : const Color(0xFFCECED1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 当前课程 + 今日课表（白色双卡区）
//
// 视觉与学生端 `_StudentDualSection` 保持一致：
//   - 标题在白卡之外（"当前课程" / "今日课表"），「今日课表」右侧带「查看完整课表 >」入口
//   - 标题→白卡间距 ui(20)
//   - 白卡 padding 12 / radius 16 / 浅阴影
//   - 白卡内部为灰底（#F5F6FA, radius 12）子卡，子卡右上 L 型角标承载状态色
//   - 子卡时段用 Text.rich 三段式（起 #1A1A1A 600 / "- " #B6B5BB 600 / 止 #0B081A 600）
//   - 老师行：渐变首字头像 + 姓名 14 600 + 课程标签（颜色背景）+ 圆点+大小课白底标签
//   - 数据为空时白卡保留，并展示占位文案
// =============================================================================

class _LessonRowData {
  const _LessonRowData({
    required this.avatarSeed,
    required this.teacherName,
    required this.courseName,
    required this.courseColor,
    required this.courseBg,
    required this.tag,
    required this.tagDotColor,
    required this.hint,
  });

  final String avatarSeed;
  final String teacherName;
  final String courseName;
  final Color courseColor;
  final Color courseBg;
  final String tag;
  final Color tagDotColor;
  final String hint;
}

class _LessonScheduleData {
  const _LessonScheduleData({
    required this.time,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.teachers,
  });

  final String time;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final List<_LessonRowData> teachers;
}

// 教师端示例数据（与学生端示例配色一致）。
// TODO：接入真实接口后改由 dashboard data + controller 注入。
const List<_LessonRowData> _kCurrentLessonTeachers = [
  _LessonRowData(
    avatarSeed: '贾',
    teacherName: '贾恩海',
    courseName: '视唱课',
    courseColor: Color(0xFF8741FF),
    courseBg: Color(0xFFEAE5FF),
    tag: '大课',
    tagDotColor: Color(0xFFA773FF),
    hint: '45分钟·艺术楼 报告厅',
  ),
  _LessonRowData(
    avatarSeed: '李',
    teacherName: '李泽芮',
    courseName: '竹笛课',
    courseColor: Color(0xFF0CAC40),
    courseBg: Color(0xFFDFFCF0),
    tag: '小课',
    tagDotColor: Color(0xFF0CAC40),
    hint: '45分钟·音乐体验课',
  ),
];

const _LessonScheduleData _kCurrentLesson = _LessonScheduleData(
  time: '07:00 - 07:45',
  status: '正在进行',
  statusColor: Color(0xFF0B081A),
  statusBg: Color(0xFFEAE5FF),
  teachers: _kCurrentLessonTeachers,
);

const List<_LessonScheduleData> _kTodayLessons = [
  _LessonScheduleData(
    time: '08:00 - 08:30',
    status: '即将开始',
    statusColor: Color(0xFF0B081A),
    statusBg: Color(0xFFEAE5FF),
    teachers: [
      _LessonRowData(
        avatarSeed: '陈',
        teacherName: '陈江凯',
        courseName: '视唱课',
        courseColor: Color(0xFF8741FF),
        courseBg: Color(0xFFEAE5FF),
        tag: '大课',
        tagDotColor: Color(0xFFA773FF),
        hint: '45分钟·艺术楼 报告厅',
      ),
      _LessonRowData(
        avatarSeed: '李',
        teacherName: '李梓燕',
        courseName: '竹笛课',
        courseColor: Color(0xFF0CAC40),
        courseBg: Color(0xFFDFFCF0),
        tag: '小课',
        tagDotColor: Color(0xFF0CAC40),
        hint: '45分钟·音乐体验课',
      ),
    ],
  ),
  _LessonScheduleData(
    time: '07:00 - 07:45',
    status: '已结束',
    statusColor: Color(0xFFB6B5BB),
    statusBg: Color(0xFFE6E9F1),
    teachers: [
      _LessonRowData(
        avatarSeed: '郝',
        teacherName: '郝江',
        courseName: '竹笛课',
        courseColor: Color(0xFF0CAC40),
        courseBg: Color(0xFFDFFCF0),
        tag: '小课',
        tagDotColor: Color(0xFF0CAC40),
        hint: '45分钟·艺术楼 报告厅',
      ),
    ],
  ),
];

class _TeacherScheduleSection extends StatelessWidget {
  const _TeacherScheduleSection({
    this.onOpenMySchedule,
    this.fillRemaining = false,
  });

  final VoidCallback? onOpenMySchedule;

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    Widget sectionTitle(String title) => Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );

    Widget scheduleTitle() => Row(
      children: [
        Text(
          '今日课表',
          style: TextStyle(
            fontSize: ui(18),
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onOpenMySchedule,
          borderRadius: BorderRadius.circular(ui(6)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(2), vertical: ui(2)),
            child: Text(
              '查看完整课表 >',
              style: TextStyle(
                fontSize: ui(14),
                color: const Color(0xFF6D6B75),
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final stackVertically = !cw.isFinite || cw < ui(690);

        if (stackVertically) {
          // 紧凑模式：标题→白卡顺序堆叠（不撑满，沿用 SingleChildScrollView 滚动）。
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              sectionTitle('当前课程'),
              SizedBox(height: ui(20)),
              const _CurrentLessonPanel(lesson: _kCurrentLesson),
              SizedBox(height: ui(20)),
              scheduleTitle(),
              SizedBox(height: ui(20)),
              const _TodaySchedulePanel(lessons: _kTodayLessons),
            ],
          );
        }

        // 宽屏：标题行 + 双卡行
        final cardsRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: _CurrentLessonPanel(lesson: _kCurrentLesson)),
            SizedBox(width: ui(16)),
            const Expanded(child: _TodaySchedulePanel(lessons: _kTodayLessons)),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fillRemaining ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sectionTitle('当前课程')),
                SizedBox(width: ui(16)),
                Expanded(child: scheduleTitle()),
              ],
            ),
            SizedBox(height: ui(20)),
            if (fillRemaining)
              // 父级有界高度：白卡撑满剩余高度
              Expanded(child: cardsRow)
            else
              // 父级高度无界：用 IntrinsicHeight 让两侧等高
              IntrinsicHeight(child: cardsRow),
          ],
        );
      },
    );
  }
}

class _CurrentLessonPanel extends StatelessWidget {
  const _CurrentLessonPanel({required this.lesson});

  final _LessonScheduleData? lesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: lesson == null
          ? const _LessonEmptyHint(text: '暂无当前课程')
          : _LessonScheduleCard(data: lesson!),
    );
  }
}

class _TodaySchedulePanel extends StatelessWidget {
  const _TodaySchedulePanel({required this.lessons});

  final List<_LessonScheduleData> lessons;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: lessons.isEmpty
          ? const _LessonEmptyHint(text: '今日暂无课表')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < lessons.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(8)),
                  _LessonScheduleCard(data: lessons[i]),
                ],
              ],
            ),
    );
  }
}

class _LessonEmptyHint extends StatelessWidget {
  const _LessonEmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(36)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note_rounded,
            size: ui(28),
            color: const Color(0xFFB6B5BB),
          ),
          SizedBox(height: ui(8)),
          Text(
            text,
            style: TextStyle(
              fontSize: ui(13),
              color: const Color(0xFF9A99A1),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonScheduleCard extends StatelessWidget {
  const _LessonScheduleCard({required this.data});

  final _LessonScheduleData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(12);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(children: _splitTime(data.time, ui))),
              SizedBox(height: ui(14)),
              for (var i = 0; i < data.teachers.length; i++) ...[
                _LessonTeacherRow(data: data.teachers[i]),
                if (i != data.teachers.length - 1) SizedBox(height: ui(14)),
              ],
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            height: ui(22),
            padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(2)),
            decoration: BoxDecoration(
              color: data.statusBg,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              data.status,
              style: TextStyle(
                fontSize: ui(12),
                color: data.statusColor,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _splitTime(String time, double Function(double) ui) {
    final parts = time.split('-');
    if (parts.length != 2) {
      return [
        TextSpan(
          text: time,
          style: TextStyle(
            fontSize: ui(18),
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ];
    }
    final start = parts[0].trim();
    final end = parts[1].trim();
    return [
      TextSpan(
        text: '$start ',
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      TextSpan(
        text: '- ',
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFFB6B5BB),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      TextSpan(
        text: end,
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFF0B081A),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ];
  }
}

class _LessonTeacherRow extends StatelessWidget {
  const _LessonTeacherRow({required this.data});

  final _LessonRowData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LessonSeedAvatar(seed: data.avatarSeed, size: ui(40)),
        SizedBox(width: ui(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      data.teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: const Color(0xFF0B081A),
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Container(
                    height: ui(16),
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(4),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: data.courseBg,
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      data.courseName,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: data.courseColor,
                        fontWeight: FontWeight.w400,
                        height: 14 / 11,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Container(
                    height: ui(16),
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(4),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(4)),
                      border: Border.all(color: const Color(0xFFF3F2F3)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: ui(6),
                          height: ui(6),
                          decoration: BoxDecoration(
                            color: data.tagDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        Text(
                          data.tag,
                          style: TextStyle(
                            fontSize: ui(11),
                            color: const Color(0xFF0B081A),
                            fontWeight: FontWeight.w400,
                            height: 14 / 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                data.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFFB6B5BB),
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 与学生端 `_SeedAvatar` 视觉一致的渐变首字头像。
/// 各取首字 `seed.codeUnitAt(0)` 在 5 套调色盘中循环。
class _LessonSeedAvatar extends StatelessWidget {
  const _LessonSeedAvatar({required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palettes = <List<Color>>[
      const [Color(0xFFFFD9E3), Color(0xFFFFBFD0)],
      const [Color(0xFFD8E4FF), Color(0xFFB9D0FF)],
      const [Color(0xFFE8DCFF), Color(0xFFD5BCFF)],
      const [Color(0xFFE6FFF6), Color(0xFFB7F0DC)],
      const [Color(0xFFFFF0D9), Color(0xFFFFD09B)],
    ];
    final index = seed.isEmpty ? 0 : (seed.codeUnitAt(0) % palettes.length);
    final palette = palettes[index];
    final initial = seed.isEmpty ? '?' : seed.substring(0, 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          color: const Color(0xFF5B536D),
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 班主任端：当前事项 + 班务（白色双卡区）
//
// 与「当前课程 / 今日课表」共用同一外层布局（标题行 + 白卡 + Expanded 撑满），
// 子卡视觉简化为 时间(Barlow 18 600 三段式) + 标题 + 紫色标签：
//   - 白卡 padding 12 / radius 16 / 浅阴影；子卡灰底 #F5F6FA / radius 12
//   - 「班务」标题右侧带「班级工作台 >」入口
// =============================================================================

class _BoardItemData {
  const _BoardItemData({
    required this.time,
    required this.title,
    required this.tag,
    required this.tagForeground,
    required this.tagBackground,
  });

  final String time;
  final String title;
  final String tag;
  final Color tagForeground;
  final Color tagBackground;
}

const Color _kBoardTagPurple = Color(0xFF8741FF);
const Color _kBoardTagPurpleSoft = Color(0xFFDAD2FF);

const List<_BoardItemData> _kHeadTeacherCurrentItems = [
  _BoardItemData(
    time: '07:00 - 07:45',
    title: '班会材料·校考志愿说明',
    tag: '班会',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
  _BoardItemData(
    time: '07:50 - 08:35',
    title: '校考志愿说明演讲',
    tag: '演讲',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
];

const List<_BoardItemData> _kHeadTeacherBoardItems = [
  _BoardItemData(
    time: '07:00 - 07:45',
    title: '班会材料·校考志愿说明',
    tag: '班会',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
  _BoardItemData(
    time: '09:00 - 09:45',
    title: '校考志愿说明演讲',
    tag: '演讲',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
  _BoardItemData(
    time: '10:00 - 10:45',
    title: '校考志愿说明演讲',
    tag: '演讲',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
];

class _HeadTeacherBoardSection extends StatelessWidget {
  const _HeadTeacherBoardSection({
    this.onOpenWorkbench,
    this.fillRemaining = false,
  });

  /// 「班级工作台 >」入口（班务白卡标题右侧）。
  final VoidCallback? onOpenWorkbench;

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    Widget sectionTitle(String title) => Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );

    Widget boardTitle() => Row(
      children: [
        Text(
          '班务',
          style: TextStyle(
            fontSize: ui(18),
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onOpenWorkbench,
          borderRadius: BorderRadius.circular(ui(6)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(2), vertical: ui(2)),
            child: Text(
              '班级工作台 >',
              style: TextStyle(
                fontSize: ui(14),
                color: const Color(0xFF6D6B75),
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final stackVertically = !cw.isFinite || cw < ui(690);

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              sectionTitle('当前事项'),
              SizedBox(height: ui(20)),
              const _BoardPanel(items: _kHeadTeacherCurrentItems),
              SizedBox(height: ui(20)),
              boardTitle(),
              SizedBox(height: ui(20)),
              const _BoardPanel(items: _kHeadTeacherBoardItems),
            ],
          );
        }

        final cardsRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: _BoardPanel(items: _kHeadTeacherCurrentItems),
            ),
            SizedBox(width: ui(16)),
            const Expanded(child: _BoardPanel(items: _kHeadTeacherBoardItems)),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fillRemaining ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sectionTitle('当前事项')),
                SizedBox(width: ui(16)),
                Expanded(child: boardTitle()),
              ],
            ),
            SizedBox(height: ui(20)),
            if (fillRemaining)
              Expanded(child: cardsRow)
            else
              IntrinsicHeight(child: cardsRow),
          ],
        );
      },
    );
  }
}

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({required this.items});

  final List<_BoardItemData> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: items.isEmpty
          ? const _LessonEmptyHint(text: '暂无事项')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(8)),
                  _BoardItemCard(data: items[i]),
                ],
              ],
            ),
    );
  }
}

class _BoardItemCard extends StatelessWidget {
  const _BoardItemCard({required this.data});

  final _BoardItemData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(TextSpan(children: _splitBoardTime(data.time, ui))),
          SizedBox(height: ui(12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(4),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: data.tagBackground,
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  data.tag,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: data.tagForeground,
                    fontWeight: FontWeight.w400,
                    height: 15.24 / 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 复用 `_LessonScheduleCard._splitTime` 同款时间三段式样式，
/// 提到顶层方便 `_BoardItemCard` 直接使用。
List<InlineSpan> _splitBoardTime(String time, double Function(double) ui) {
  final parts = time.split('-');
  if (parts.length != 2) {
    return [
      TextSpan(
        text: time,
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ];
  }
  final start = parts[0].trim();
  final end = parts[1].trim();
  return [
    TextSpan(
      text: '$start ',
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    TextSpan(
      text: '- ',
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFFB6B5BB),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    TextSpan(
      text: end,
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF0B081A),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
  ];
}

// =============================================================================
// 学生端智慧校园首页布局
//
// 复用老师端视觉系统：
//   - 主区：6 张统计卡 + 10 项功能矩阵（5×2，82×70 按钮）+ 当前课程/今日课表 双卡
//   - 侧栏 256：头像 + 在校胶囊 + 详细信息（主项/副项/班级/宿舍）+ 通知列表
//     注意：学生端**没有**老师/班主任 tab 切换，所以 _TeacherSidebar 的
//     selectedTab/onTabSelected 都不传。
//
// 数据由 [smartCampusDashboardDataForRole(SmartCampusRole.student)] 提供。
// 已实现的回调：
//   - 我的班级 → onOpenMyClass
//   - 我的课表 → onOpenMySchedule
//   - 校长信箱 → onOpenPrincipalMailbox
//   - 课堂签到 → onOpenCheckIn
//   - 我的作业 → onOpenMyHomework
//   - 我的成绩 → onOpenMyGrades
//   - 群聊 → onOpenGroupChat
//   - 校圈 → onOpenSchoolCircle（push RoutePaths.circle 全屏页）
//   - 请假管理 → onOpenLeaveManagement（"请假补课"页）
//   - 查寝管理 → onOpenDormCheck（个人查寝/补卡页）
//     `_TeacherActionTile` 统一兜底 SnackBar"页面迁移中"，避免点了无反馈。
// =============================================================================

class StudentDashboardLayout extends StatelessWidget {
  const StudentDashboardLayout({
    super.key,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenMySchedule,
    required this.onOpenCheckIn,
    required this.onOpenMyHomework,
    required this.onOpenMyGrades,
    required this.onOpenGroupChat,
    required this.onOpenSchoolCircle,
    required this.onOpenLeaveManagement,
    required this.onOpenDormCheck,
  });

  final String shellDisplayName;
  final String avatarUrl;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenMySchedule;
  final VoidCallback onOpenCheckIn;
  final VoidCallback onOpenMyHomework;
  final VoidCallback onOpenMyGrades;
  final VoidCallback onOpenGroupChat;
  final VoidCallback onOpenSchoolCircle;
  final VoidCallback onOpenLeaveManagement;
  final VoidCallback onOpenDormCheck;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = smartCampusDashboardDataForRole(SmartCampusRole.student);
    // 学生端没有"班级工作台"按钮，但 _TeacherMainColumn 签名仍要求该回调，
    // 这里给一个 noop 即可（永远不会被触发）。
    void noopOpenWorkbench() {}

    return LayoutBuilder(
      builder: (context, constraints) {
        var cw = constraints.maxWidth;
        if (!cw.isFinite || cw == double.infinity || cw < 2) {
          final w = MediaQuery.sizeOf(context).width;
          cw = (w - ui(ShellLayoutSpec.sidebarWidth) - ui(16) * 2).clamp(
            240.0,
            20000.0,
          );
        }
        final isCompact = cw < ui(900);
        final sidebarWidth = ui(256);
        final contentGap = ui(16);
        final mainWidth = isCompact
            ? cw
            : math.max(0.0, cw - sidebarWidth - contentGap);

        if (isCompact) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeacherMainColumn(
                  data: data,
                  width: mainWidth,
                  fillRemaining: false,
                  onOpenPrincipalMailbox: onOpenPrincipalMailbox,
                  onOpenMyClass: onOpenMyClass,
                  onOpenClassWorkbench: noopOpenWorkbench,
                  onOpenMySchedule: onOpenMySchedule,
                  onOpenCheckIn: onOpenCheckIn,
                  onOpenMyHomework: onOpenMyHomework,
                  onOpenMyGrades: onOpenMyGrades,
                  onOpenGroupChat: onOpenGroupChat,
                  onOpenSchoolCircle: onOpenSchoolCircle,
                  onOpenLeaveManagement: onOpenLeaveManagement,
                  onOpenDormCheck: onOpenDormCheck,
                ),
                SizedBox(height: ui(16)),
                _TeacherSidebar(
                  data: data,
                  width: cw,
                  shellDisplayName: shellDisplayName,
                  avatarUrl: avatarUrl,
                  fillHeight: false,
                ),
              ],
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: mainWidth,
              child: _TeacherMainColumn(
                data: data,
                width: mainWidth,
                fillRemaining: true,
                onOpenPrincipalMailbox: onOpenPrincipalMailbox,
                onOpenMyClass: onOpenMyClass,
                onOpenClassWorkbench: noopOpenWorkbench,
                onOpenMySchedule: onOpenMySchedule,
                onOpenCheckIn: onOpenCheckIn,
                onOpenMyHomework: onOpenMyHomework,
                onOpenMyGrades: onOpenMyGrades,
                onOpenGroupChat: onOpenGroupChat,
                onOpenSchoolCircle: onOpenSchoolCircle,
                onOpenLeaveManagement: onOpenLeaveManagement,
                onOpenDormCheck: onOpenDormCheck,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sidebarWidth,
              child: _TeacherSidebar(
                data: data,
                width: sidebarWidth,
                shellDisplayName: shellDisplayName,
                avatarUrl: avatarUrl,
                fillHeight: true,
              ),
            ),
          ],
        );
      },
    );
  }
}
