import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';
import '../state/smart_campus_state.dart';
import 'widgets/role_switcher_buttons.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 管理员智慧校园首页：970×~1100 双栏布局。
///
/// 左主栏（约 696 宽）自上而下：
/// 1. **8 项数据统计**：分两行各 4 卡，白底 + 24/500 数值（今日待办 4
///    用 `#8741FF` 紫高亮） + 12/PingFang 灰色标签。
/// 2. **管理端 10 项快捷入口卡**（697×255）：5×2 网格，每个 cell
///    `43.73 #EAE5FF` 圆角底 + `assets/images/adminHome/{1..10}.png`
///    + 14/PingFang/500 文案；学生管理(1) → 教师管理(2) → 班级编辑(3) →
///    排课与课表(4) → 宿管请假审批(5) → 人脸库(6) → 通知管理(7) →
///    群聊(8) → 校长信箱(9) → 校圈治理(10)。
/// 3. **数据看板**：白底卡 + 7 天紫色平滑曲线 + 浅紫渐变填充
///    （5 刻度 100/95/90/85/80/0 + 横轴 周一-周日）。
/// 4. **四端职能 + 工作提醒**：左右两白卡。
///    - 四端职能：4 tab（学生端/任课老师/班主任/宿管端）+ 滚动文案；
///    - 工作提醒：3 条预警卡，红色「预警」徽章 + 标题 + 副标题 + 灰小点。
///
/// 右栏（256 宽）固定为单张白卡：
/// - 顶部 72 圆形头像 + 「管理员」16/500 + 绿点「运行中」+
///   「音乐学科 一级教师」+ 黄底「管理员」徽章；
/// - 「主项 / 副项 / 带班」3 行键值；
/// - 「校级通知」title + 滚动通知列表，每条卡含分类徽章
///   （教研室 / 场地 / 大师课）+ 内容 + 时间 + 红 / 灰未读点。
///
/// 不带 `onBack` —— 这就是 admin 角色下 `mainView == dashboard` 的根视图，
/// 不会被 `controller.backToDashboard()` 弹出。
class AdminHomeView extends StatelessWidget {
  const AdminHomeView({
    super.key,
    required this.shellDisplayName,
    required this.avatarUrl,
    this.availableRoles = const [SmartCampusRole.admin],
    this.selectedRole = SmartCampusRole.admin,
    this.onSelectRole,
    this.onOpenGroupChat,
    this.onOpenPrincipalMailbox,
    this.onOpenSchoolCircle,
    this.onOpenStudentManagement,
    this.onOpenTeacherManagement,
    this.onOpenClassManagement,
    this.onOpenScheduleManagement,
    this.onOpenDormLeaveApproval,
    this.onOpenFaceLibrary,
    this.onOpenNotificationManagement,
    this.onOpenSignManagement,
  });

  final String shellDisplayName;
  final String avatarUrl;

  /// 当前用户在校内可切换的全部身份（admin / headTeacher / teacher /
  /// dormManager / student 子集）。一般来自
  /// `SmartCampusState.availableRoles`，由 `myInfo.role + teacherRole`
  /// 接口共同决定。仅含 `[admin]` 时右栏隐藏「身份切换」区。
  final List<SmartCampusRole> availableRoles;

  /// 当前已选身份。用于让右栏切换按钮高亮当前所在的身份（admin 默认）。
  final SmartCampusRole selectedRole;

  /// 切换身份回调。一般直接传 `SmartCampusController.selectRole`，
  /// state 写入后由 [SmartCampusPage] 重新路由到目标身份的大 dashboard。
  /// 为 `null` 时右栏隐藏「身份切换」区。
  final ValueChanged<SmartCampusRole>? onSelectRole;

  /// 「群聊」/ 「校长信箱」/ 「校圈治理」三个快捷入口共用全站对应页面：
  /// 由 [smartCampusPage] 传入对应的 `controller.openGroupChat` /
  /// `controller.openPrincipalMailbox` / `Navigator.pushNamed(circle)`。
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenPrincipalMailbox;
  final VoidCallback? onOpenSchoolCircle;

  /// 「学生管理」管理端独立入口：进入 [AdminStudentManagementView]。
  final VoidCallback? onOpenStudentManagement;

  /// 「教师管理」管理端独立入口：进入 [AdminTeacherManagementView]。
  final VoidCallback? onOpenTeacherManagement;

  /// 「班级编辑 / 班级编组」管理端独立入口：进入 [AdminClassManagementView]。
  final VoidCallback? onOpenClassManagement;

  /// 「排课与课表」管理端独立入口：进入 [AdminScheduleManagementView]。
  final VoidCallback? onOpenScheduleManagement;

  /// 「宿管请假审批」管理端独立入口：进入 [AdminDormLeaveApprovalView]。
  final VoidCallback? onOpenDormLeaveApproval;

  /// 「人脸库」管理端独立入口：进入 [AdminFaceLibraryView]。
  final VoidCallback? onOpenFaceLibrary;

  /// 「通知管理」管理端独立入口：进入 [AdminNotificationManagementView]。
  final VoidCallback? onOpenNotificationManagement;

  /// 「签课管理」管理端独立入口：进入 [AdminSignManagementView]。
  final VoidCallback? onOpenSignManagement;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: ui(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _StatsRow(stats: _statsRow1),
                SizedBox(height: ui(12)),
                const _StatsRow(stats: _statsRow2),
                SizedBox(height: ui(16)),
                _QuickActionsCard(
                  onOpenGroupChat: onOpenGroupChat,
                  onOpenPrincipalMailbox: onOpenPrincipalMailbox,
                  onOpenSchoolCircle: onOpenSchoolCircle,
                  onOpenStudentManagement: onOpenStudentManagement,
                  onOpenTeacherManagement: onOpenTeacherManagement,
                  onOpenClassManagement: onOpenClassManagement,
                  onOpenScheduleManagement: onOpenScheduleManagement,
                  onOpenDormLeaveApproval: onOpenDormLeaveApproval,
                  onOpenFaceLibrary: onOpenFaceLibrary,
                  onOpenNotificationManagement: onOpenNotificationManagement,
                  onOpenSignManagement: onOpenSignManagement,
                ),
                SizedBox(height: ui(24)),
                const _SectionTitle(title: '数据看板'),
                SizedBox(height: ui(12)),
                const _DataDashboardCard(),
                SizedBox(height: ui(24)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionTitle(title: '四端职能'),
                          SizedBox(height: 12),
                          _FourEndsCard(),
                        ],
                      ),
                    ),
                    SizedBox(width: ui(16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionTitle(title: '工作提醒'),
                          SizedBox(height: 12),
                          _WorkRemindersCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          SizedBox(
            width: ui(256),
            child: _AdminSidePanel(
              displayName: shellDisplayName,
              avatarUrl: avatarUrl,
              availableRoles: availableRoles,
              selectedRole: selectedRole,
              onSelectRole: onSelectRole,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 数据
// ============================================================================

class _StatItem {
  const _StatItem(this.value, this.label, {this.highlight = false});

  final String value;
  final String label;
  final bool highlight;
}

const _statsRow1 = <_StatItem>[
  _StatItem('75', '在籍学生'),
  _StatItem('73', '任课老师'),
  _StatItem('68', '本学期班级'),
  _StatItem('4', '今日待办', highlight: true),
];

const _statsRow2 = <_StatItem>[
  _StatItem('23', '待审宿管假'),
  _StatItem('67', '人脸待补录'),
  _StatItem('43', '通知草稿'),
  _StatItem('32', '校圈待处理'),
];

class _QuickAction {
  const _QuickAction(
    this.label,
    this.iconAsset, {
    // ignore: unused_element_parameter
    this.badge,
  });

  final String label;
  final String iconAsset;

  /// 右上角红色角标（如 "10+"）。当前所有快捷入口默认不带角标，保留字段
  /// 与渲染逻辑以便后续按需启用某个入口的红点提醒。
  final String? badge;
}

const _quickActions = <_QuickAction>[
  _QuickAction('学生管理', 'assets/images/adminHome/1.png'),
  _QuickAction('教师管理', 'assets/images/adminHome/2.png'),
  _QuickAction('班级编辑', 'assets/images/adminHome/3.png'),
  _QuickAction('排课与课表', 'assets/images/adminHome/4.png'),
  _QuickAction('签课管理', 'assets/images/adminHome/4.png'),
  _QuickAction('宿管请假审批', 'assets/images/adminHome/5.png'),
  _QuickAction('人脸库', 'assets/images/adminHome/6.png'),
  _QuickAction('通知管理', 'assets/images/adminHome/7.png'),
  _QuickAction('群聊', 'assets/images/adminHome/8.png'),
  _QuickAction('校长信箱', 'assets/images/adminHome/9.png'),
  _QuickAction('校圈治理', 'assets/images/adminHome/10.png'),
];

class _NoticeItem {
  const _NoticeItem({
    required this.tag,
    required this.text,
    required this.time,
    required this.unread,
  });

  final String tag;
  final String text;
  final String time;
  final bool unread;
}

const _schoolNotices = <_NoticeItem>[
  _NoticeItem(
    tag: '教研室',
    text: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
    time: '09:10',
    unread: true,
  ),
  _NoticeItem(
    tag: '场地',
    text: '断电提醒教学楼夜间 21:00 后静音巡查，22:00 断电，请提前保存练习视频。',
    time: '周一',
    unread: true,
  ),
  _NoticeItem(
    tag: '大师课',
    text: '本周六上午 10:00 邀请上海音乐学院教授开设大师课，请相关学生准时到场。',
    time: '周一',
    unread: false,
  ),
  _NoticeItem(
    tag: '大师课',
    text: '高三汇报演出排练时间调整为周三下午 16:30，地点不变。',
    time: '周一',
    unread: false,
  ),
  _NoticeItem(
    tag: '场地',
    text: '小琴房本周五 13:00-17:00 维护暂停使用，请合理安排练琴时间。',
    time: '周一',
    unread: true,
  ),
  _NoticeItem(
    tag: '大师课',
    text: '声乐组本月专题课报名截止时间延期至下周一 12:00。',
    time: '周一',
    unread: false,
  ),
];

class _WorkReminder {
  const _WorkReminder(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

const _workReminders = <_WorkReminder>[
  _WorkReminder('高三音乐实验班·昨晚查寝1人未打卡未闭环', '宿管端已登记，待确认是否转晚归备案。'),
  _WorkReminder('高二7班·本周作业批改完成度 78%', '尚有 3 名任课老师作业批改未提交，待跟进。'),
  _WorkReminder('校园通知草稿超 7 日未发布', '通知管理后台累计 12 条草稿，请及时审核或归档。'),
];

const _fourEndsTabs = <String>['学生端', '任课老师', '班主任', '宿管端'];

const _fourEndsContent = <String, ({String title, String body})>{
  '学生端': (title: '核心场景', body: '课表、作业、成绩、课堂签到、请假与补课、查寝管理、校圈、我的班级、群聊'),
  '任课老师': (title: '核心场景', body: '授课课表、签课管理、学生名册、作业批改、考评管理、课堂签到、班级公告、群聊'),
  '班主任': (title: '核心场景', body: '班级工作台、请假审批、查寝动态、查寝历史、学生档案、家校沟通、班级通知、群聊'),
  '宿管端': (title: '核心场景', body: '查寝排班、晨晚查寝、补卡审核、请假审批、宿舍异常处理、宿舍人脸库、通知发布'),
};

const _managerEndContent = '学籍 / 排课与课表 / 人脸库 / 校圈治理 / 通知管理 / 校长信箱 / 校园数据看板';

// ============================================================================
// Section title
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        height: 1.2,
        fontWeight: AppFont.w500,
        color: const Color(0xFF1A1A1A),
        fontFamily: 'PingFang SC',
      ),
    );
  }
}

// ============================================================================
// 1. 管理端快捷入口（10 项）
// ============================================================================

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    this.onOpenGroupChat,
    this.onOpenPrincipalMailbox,
    this.onOpenSchoolCircle,
    this.onOpenStudentManagement,
    this.onOpenTeacherManagement,
    this.onOpenClassManagement,
    this.onOpenScheduleManagement,
    this.onOpenDormLeaveApproval,
    this.onOpenFaceLibrary,
    this.onOpenNotificationManagement,
    this.onOpenSignManagement,
  });

  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenPrincipalMailbox;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenStudentManagement;
  final VoidCallback? onOpenTeacherManagement;
  final VoidCallback? onOpenClassManagement;
  final VoidCallback? onOpenScheduleManagement;
  final VoidCallback? onOpenDormLeaveApproval;
  final VoidCallback? onOpenFaceLibrary;
  final VoidCallback? onOpenNotificationManagement;
  final VoidCallback? onOpenSignManagement;

  VoidCallback? _resolveTap(String label) {
    switch (label) {
      case '群聊':
        return onOpenGroupChat;
      case '校长信箱':
        return onOpenPrincipalMailbox;
      case '校圈治理':
        return onOpenSchoolCircle;
      case '学生管理':
        return onOpenStudentManagement;
      case '教师管理':
        return onOpenTeacherManagement;
      case '班级编辑':
        return onOpenClassManagement;
      case '排课与课表':
        return onOpenScheduleManagement;
      case '签课管理':
        return onOpenSignManagement;
      case '宿管请假审批':
        return onOpenDormLeaveApproval;
      case '人脸库':
        return onOpenFaceLibrary;
      case '通知管理':
        return onOpenNotificationManagement;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 11 items → 5 + 5 + 1（末行左对齐，其余列用空白 Expanded 补位）
    const rowSize = 5;
    final rowCount = (_quickActions.length / rowSize).ceil();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(28)),
      child: Column(
        children: [
          for (var ri = 0; ri < rowCount; ri++) ...[
            if (ri > 0) SizedBox(height: ui(24)),
            Row(
              children: [
                for (var ci = 0; ci < rowSize; ci++) ...[
                  if (ci > 0) SizedBox(width: ui(12)),
                  Expanded(
                    child: () {
                      final idx = ri * rowSize + ci;
                      if (idx < _quickActions.length) {
                        return _QuickActionCell(
                          action: _quickActions[idx],
                          onTap: _resolveTap(_quickActions[idx].label),
                        );
                      }
                      return const SizedBox();
                    }(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionCell extends StatelessWidget {
  const _QuickActionCell({required this.action, this.onTap});

  final _QuickAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ui(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ui(48),
              height: ui(48),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: ui(44),
                    height: ui(44),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE5FF),
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                  ),
                  Image.asset(
                    action.iconAsset,
                    width: ui(28),
                    height: ui(28),
                    fit: BoxFit.contain,
                  ),
                  if (action.badge != null)
                    Positioned(
                      right: -ui(2),
                      top: -ui(2),
                      child: Container(
                        height: ui(15),
                        padding: EdgeInsets.symmetric(horizontal: ui(5)),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF04545),
                          borderRadius: BorderRadius.circular(ui(20)),
                        ),
                        child: Text(
                          action.badge!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ui(10),
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              action.label,
              style: TextStyle(
                fontSize: ui(14),
                height: 1.2,
                fontWeight: AppFont.w500,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. 4 列统计卡
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(child: _StatCard(item: stats[i])),
          if (i < stats.length - 1) SizedBox(width: ui(16)),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      child: Column(
        children: [
          Text(
            item.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(24),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: item.highlight
                  ? const Color(0xFF8741FF)
                  : const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: const Color(0xFF6D6B75),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. 数据看板（紫色平滑曲线）
// ============================================================================

class _DataDashboardCard extends StatelessWidget {
  const _DataDashboardCard();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    const yLabels = ['100', '95', '90', '85', '80', '0'];
    const xLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const values = [85.0, 95.0, 87.0, 95.0, 89.0, 99.0, 95.0];

    return Container(
      height: ui(261),
      padding: EdgeInsets.fromLTRB(ui(12), ui(20), ui(12), ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: ui(8)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final l in yLabels)
                        Text(
                          l,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.0,
                            color: const Color(0xFFB6B5BB),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: _LineChartPainter(values: values),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(12)),
          Padding(
            padding: EdgeInsets.only(left: ui(28)),
            child: Row(
              children: [
                for (final x in xLabels)
                  Expanded(
                    child: Text(
                      x,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.2,
                        color: const Color(0xFF6D6B75),
                        fontFamily: 'PingFang SC',
                      ),
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

/// 7 点平滑曲线 + 浅紫渐变填充 + 紫色描边 + 白点紫边圆点。
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // y 轴：100 → top, 80 → 5 行刻度等距，0 → 底（最后一段大跨）
    // 简化：把 [80, 100] 映射到 [chartHeight*0.8, 0]（顶部 80% 区域），
    // 底部 20% 留给「0」标签。
    const minV = 80.0;
    const maxV = 100.0;
    final chartTop = 0.0;
    final chartBottom = size.height * 0.78;
    final stride = size.width / (values.length - 1);

    Offset pointAt(int i) {
      final v = values[i].clamp(minV, maxV);
      final ratio = (v - minV) / (maxV - minV);
      final y = chartBottom - ratio * (chartBottom - chartTop);
      return Offset(stride * i, y);
    }

    final pts = [for (var i = 0; i < values.length; i++) pointAt(i)];

    // 1. 平滑路径（cardinal-ish via cubic）
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[0] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i == pts.length - 2 ? pts[i + 1] : pts[i + 2];
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      linePath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    // 2. 填充：闭合到底部
    final fillPath = Path.from(linePath)
      ..lineTo(pts.last.dx, chartBottom)
      ..lineTo(pts.first.dx, chartBottom)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE7D9FF), Color(0x00E7D9FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartBottom));
    canvas.drawPath(fillPath, fillPaint);

    // 3. 描边
    final strokePaint = Paint()
      ..color = const Color(0xFF8741FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // 4. 圆点
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = const Color(0xFF8741FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final p in pts) {
      canvas.drawCircle(p, 4, dotFill);
      canvas.drawCircle(p, 4, dotStroke);
    }

    // 5. 底部 dashed baseline 轻提示（可选）
    final base = Paint()
      ..color = const Color(0xFFF1ECFF)
      ..strokeWidth = 1;
    final dash = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, chartBottom),
        Offset(math.min(x + dash, size.width), chartBottom),
        base,
      );
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.values != values;
}

// ============================================================================
// 4. 四端职能（tab + 文案）
// ============================================================================

class _FourEndsCard extends StatefulWidget {
  const _FourEndsCard();

  @override
  State<_FourEndsCard> createState() => _FourEndsCardState();
}

class _FourEndsCardState extends State<_FourEndsCard> {
  String _activeTab = _fourEndsTabs.first;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final content = _fourEndsContent[_activeTab]!;

    return Container(
      height: ui(243),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _fourEndsTabs.length; i++) ...[
                  _FourEndTab(
                    label: _fourEndsTabs[i],
                    active: _fourEndsTabs[i] == _activeTab,
                    onTap: () => setState(() => _activeTab = _fourEndsTabs[i]),
                  ),
                  if (i < _fourEndsTabs.length - 1) SizedBox(width: ui(12)),
                ],
              ],
            ),
          ),
          SizedBox(height: ui(20)),
          Text(
            content.title,
            style: TextStyle(
              fontSize: ui(14),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            content.body,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.66,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(20)),
          Text(
            '管理端',
            style: TextStyle(
              fontSize: ui(14),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            _managerEndContent,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.66,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _FourEndTab extends StatelessWidget {
  const _FourEndTab({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(8)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0B081A) : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              height: 1.2,
              color: active ? Colors.white : const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. 工作提醒
// ============================================================================

class _WorkRemindersCard extends StatelessWidget {
  const _WorkRemindersCard();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(243),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _workReminders.length,
        separatorBuilder: (_, _) => SizedBox(height: ui(8)),
        itemBuilder: (context, i) => _WorkReminderCard(item: _workReminders[i]),
      ),
    );
  }
}

class _WorkReminderCard extends StatelessWidget {
  const _WorkReminderCard({required this.item});

  final _WorkReminder item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(20), ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(6),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    child: Text(
                      '预警',
                      style: TextStyle(
                        fontSize: ui(10),
                        height: 1.2,
                        fontWeight: AppFont.w500,
                        color: const Color(0xFFFF323C),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.4,
                        color: const Color(0xFF0B081A),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: ui(12),
                  height: 1.4,
                  color: const Color(0xFFB6B5BB),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: ui(6),
              height: ui(6),
              decoration: const BoxDecoration(
                color: Color(0xFFCECED1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 右侧栏：管理员档案 + 校级通知
// ============================================================================

class _AdminSidePanel extends StatelessWidget {
  const _AdminSidePanel({
    required this.displayName,
    required this.avatarUrl,
    required this.availableRoles,
    required this.selectedRole,
    required this.onSelectRole,
  });

  final String displayName;
  final String avatarUrl;
  final List<SmartCampusRole> availableRoles;
  final SmartCampusRole selectedRole;
  final ValueChanged<SmartCampusRole>? onSelectRole;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 只有用户实际拥有 2+ 个身份（且上层传入了切换回调）时才显示「身份切换」
    // 区块。单身份 admin（普通校长 / 教务管理员）下隐藏，避免出现"只能切到
    // 自己"的无意义按钮。
    final showRoleSwitcher =
        onSelectRole != null && availableRoles.length > 1;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.fromLTRB(ui(16), ui(24), ui(16), ui(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(displayName: displayName, avatarUrl: avatarUrl),
          SizedBox(height: ui(20)),
          const _ProfileInfoRows(),
          if (showRoleSwitcher) ...[
            SizedBox(height: ui(20)),
            Text(
              '身份切换',
              style: TextStyle(
                fontSize: ui(14),
                height: 1.2,
                fontWeight: AppFont.w500,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
              ),
            ),
            SizedBox(height: ui(10)),
            RoleSwitcherButtons(
              availableRoles: availableRoles,
              selectedRole: selectedRole,
              onSelectRole: onSelectRole!,
            ),
          ],
          SizedBox(height: ui(24)),
          Text(
            '校级通知',
            style: TextStyle(
              fontSize: ui(16),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          SizedBox(
            height: ui(620),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _schoolNotices.length,
              separatorBuilder: (_, _) => SizedBox(height: ui(8)),
              itemBuilder: (_, i) => _SchoolNoticeCard(item: _schoolNotices[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: ui(72),
              height: ui(72),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEAE5FF),
                image: avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl.isEmpty
                  ? Center(
                      child: Text(
                        displayName.isEmpty
                            ? 'A'
                            : displayName.characters.first,
                        style: TextStyle(
                          fontSize: ui(28),
                          height: 1.0,
                          color: const Color(0xFF8741FF),
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: ui(8)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName.isEmpty ? '管理员' : displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(16),
                            height: 1.2,
                            fontWeight: AppFont.w500,
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ),
                      SizedBox(width: ui(6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(6),
                          vertical: ui(3),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ui(4)),
                          border: Border.all(
                            color: const Color(0xFFF3F2F3),
                            width: 0.5,
                          ),
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
                              '运行中',
                              style: TextStyle(
                                fontSize: ui(11),
                                height: 1.0,
                                color: const Color(0xFF0B081A),
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    '音乐学科 一级教师',
                    style: TextStyle(
                      fontSize: ui(12),
                      height: 1.2,
                      color: const Color(0xFF6D6B75),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // 黄色「管理员」徽章：贴在头像底部中间
        Positioned(
          left: ui(18),
          top: ui(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: ui(7), vertical: ui(2)),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC13C),
              borderRadius: BorderRadius.circular(ui(10)),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              '管理员',
              style: TextStyle(
                fontSize: ui(11),
                height: 1.2,
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoRows extends StatelessWidget {
  const _ProfileInfoRows();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(label: '主项：', value: '合声基础'),
        SizedBox(height: 4),
        _InfoLine(label: '副项：', value: '钢琴'),
        SizedBox(height: 4),
        _InfoLine(label: '带班：', value: '高三音乐实验班'),
      ],
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
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            height: 1.2,
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      ],
    );
  }
}

class _SchoolNoticeCard extends StatelessWidget {
  const _SchoolNoticeCard({required this.item});

  final _NoticeItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(10), ui(10), ui(20), ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(6),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE5FF),
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    child: Text(
                      item.tag,
                      style: TextStyle(
                        fontSize: ui(10),
                        height: 1.2,
                        fontWeight: AppFont.w500,
                        color: const Color(0xFF0B081A),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Expanded(
                    child: Text(
                      item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.4,
                        color: const Color(0xFF0B081A),
                        fontFamily: 'Source Han Sans SC',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                item.time,
                style: TextStyle(
                  fontSize: ui(12),
                  height: 1.2,
                  color: const Color(0xFFCECED1),
                  fontFamily: 'Source Han Sans SC',
                ),
              ),
            ],
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
