// =============================================================================
// 班主任端「请假审批」独立页面
//
// 入口：班主任 dashboard 快捷区「请假审批」按钮 → controller.openLeaveApproval()
//      → mainView == leaveApproval + role == headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高, 4deg #F9EDFF→white 渐变, 圆角 16, 顶部居中"请假审批"
//      16/600 + 副标题 12/#B6B5BB；左 12 返回按钮 32×32 白底 outline #F3F2F3）。
//   2. 紫色提示 12/#B6B5BB「默认由家长在小程序审批后再由班主任审批；已与
//      家长充分沟通的可选择班主任直接审批。补课协调以教务安排为准。」
//   3. 4 张统计卡（100 高）：
//      A. 「待审批」橙渐变 196deg rgba(255,168,70,.16)→0
//      B. 「审批中」紫渐变 196deg rgba(147,70,255,.14)→0
//      C. 「已通过」绿渐变 196deg #DCFFE7→white 73%
//      D. 「已拒绝」红渐变 196deg #FFE2DC→white 73%
//      数值字体 32 Barlow / 标签 14/500 black。
//   4. 备案说明 12/#6D6B75「备案说明：病假超过规定天数或跨周末离校等情形，
//      通过后系统将提醒年级组备案；驳回须填写原因，学生端与家长端均可查看。」
//   5. Tabs row（44 高）：白底圆角 8 容器 + 6 个 pill：
//      全部 / 待我审批 / 审批中 / 已通过 / 已拒绝 / 已撤销，激活态 #0B081A
//      黑底白字 14/500，未激活 #6D6B75 14/500 透明底；右侧搜索框 324×44。
//   6. 双列卡片网格（每张 477 宽，padding 12，白底圆角 12，gap 16）：
//      · header：头像 40 + 姓名 14/500 + 学号 12/#B6B5BB + "病假" 12 + "时长4小时"
//        12/#6D6B75 + 状态徽章（审批中紫底紫字 / 已通过 #E4FFED+#12CE51 /
//        已拒绝 #FFE4E5+#FF323C / 已撤销 灰底灰字）。
//      · 灰底信息块 #F5F6FA padding 16：请假时间 / 请假事由 / 申请时间 /
//        路径；中间一段 horizontal stepper：
//           家长 [已通过] ─────────── 班主任 [待审批/已通过/已拒绝]
//        进度点：未到为白底灰描边，激活/到达态使用对应色填充（待审批用
//        #FF6A00 橙；通过用 #12CE51 绿；拒绝用 #FF323C 红）；最后一行备注。
//      · 仅"审批中"卡片 footer 多一行：紫渐变"通过"按钮 + 描边"驳回"按钮，
//        点击"驳回"打开 GradientHeaderDialog 形式的"驳回申请"弹窗。
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextHintLight = Color(0xFFCECED1);
const Color _kTextPlaceholder = Color(0xFFD1D1D1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFFE4E5);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);

// —— 状态枚举 ——————————————————————————————————————————————————————
enum _StatusTab {
  all('全部'),
  mine('待我审批'),
  reviewing('审批中'),
  approved('已通过'),
  rejected('已拒绝'),
  withdrawn('已撤销');

  const _StatusTab(this.label);
  final String label;
}

enum _LeaveStatus {
  reviewing('审批中', _kPurpleSoftBg, _kPurple),
  approved('已通过', _kGreenSoftBg, _kGreen),
  rejected('已拒绝', _kRedSoftBg, _kRed),
  withdrawn('已撤销', Color(0xFFEFEFEF), _kTextSecondary);

  const _LeaveStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

/// 审批节点状态。
enum _StepStatus {
  pending('待审批', _kOrange, _kOrangeSoftBg),
  approved('已通过', _kGreen, _kGreenSoftBg),
  rejected('已拒绝', _kRed, _kRedSoftBg);

  const _StepStatus(this.label, this.color, this.softBg);
  final String label;
  final Color color;
  final Color softBg;
}

class _LeaveRequest {
  const _LeaveRequest({
    required this.studentName,
    required this.studentNo,
    required this.leaveType,
    required this.duration,
    required this.timeRange,
    required this.reason,
    required this.appliedAt,
    required this.path,
    required this.status,
    required this.parentStep,
    required this.headTeacherStep,
    required this.note,
  });

  final String studentName;
  final String studentNo;
  final String leaveType;
  final String duration;
  final String timeRange;
  final String reason;
  final String appliedAt;
  final String path;
  final _LeaveStatus status;
  final _StepStatus parentStep;
  final _StepStatus headTeacherStep;
  final String note;
}

// —— 顶级视图 ——————————————————————————————————————————————————————

class TeacherLeaveApprovalView extends StatefulWidget {
  const TeacherLeaveApprovalView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TeacherLeaveApprovalView> createState() =>
      _TeacherLeaveApprovalViewState();
}

class _TeacherLeaveApprovalViewState extends State<TeacherLeaveApprovalView> {
  _StatusTab _tab = _StatusTab.all;
  late List<_LeaveRequest> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _demoRequests();
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
            SizedBox(height: ui(16)),
            const _StatsRow(
              pendingCount: 1,
              reviewingCount: 2,
              approvedCount: 2,
              rejectedCount: 1,
            ),
            SizedBox(height: ui(8)),
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
            SizedBox(height: ui(8)),
            Text(
              '备案说明：病假超过规定天数或跨周末离校等情形，通过后系统将提醒年级组备案；驳回须填写原因，学生端与家长端均可查看。',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.5,
              ),
            ),
            SizedBox(height: ui(16)),
            _TabsRow(current: _tab, onTap: (t) => setState(() => _tab = t)),
            SizedBox(height: ui(16)),
            _CardsGrid(
              records: _filtered(),
              onApprove: _onApprove,
              onReject: _onReject,
            ),
          ],
        ),
      ),
    );
  }

  List<_LeaveRequest> _filtered() {
    switch (_tab) {
      case _StatusTab.all:
        return _requests;
      case _StatusTab.mine:
      case _StatusTab.reviewing:
        return _requests
            .where((r) => r.status == _LeaveStatus.reviewing)
            .toList();
      case _StatusTab.approved:
        return _requests
            .where((r) => r.status == _LeaveStatus.approved)
            .toList();
      case _StatusTab.rejected:
        return _requests
            .where((r) => r.status == _LeaveStatus.rejected)
            .toList();
      case _StatusTab.withdrawn:
        return _requests
            .where((r) => r.status == _LeaveStatus.withdrawn)
            .toList();
    }
  }

  void _onApprove(_LeaveRequest record) {
    AppToast.show(
      context,
      '已通过 ${record.studentName} 的${record.leaveType}申请（演示）',
    );
  }

  Future<void> _onReject(_LeaveRequest record) async {
    final reason = await _showRejectDialog(context, record: record);
    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;
    AppToast.show(
      context,
      '已驳回 ${record.studentName} 的${record.leaveType}申请：$reason（演示）',
    );
  }
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
                    '请假审批',
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
                    '查看本班学生请假材料、家长节点与审批路径；与家长链路一致。通过或驳回后同步到学生端与年级备案（演示）。',
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

// —— 4 张统计卡 ——————————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.pendingCount,
    required this.reviewingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  final int pendingCount;
  final int reviewingCount;
  final int approvedCount;
  final int rejectedCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '待审批',
            value: pendingCount,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x29FFA846), Color(0x00FFFFFF)],
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '审批中',
            value: reviewingCount,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x249346FF), Color(0x00FFFFFF)],
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '已通过',
            value: approvedCount,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFDCFFE7), Colors.white],
              stops: [0.0, 0.73],
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '已拒绝',
            value: rejectedCount,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFE2DC), Colors.white],
              stops: [0.0, 0.73],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.gradient,
  });

  final String label;
  final int value;
  final LinearGradient gradient;

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
      child: Padding(
        padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.0,
              ),
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
    );
  }
}

// —— Tabs row + 搜索框 ——————————————————————————————————————————————

class _TabsRow extends StatelessWidget {
  const _TabsRow({required this.current, required this.onTap});

  final _StatusTab current;
  final ValueChanged<_StatusTab> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          height: ui(44),
          padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _StatusTab.values.length; i++) ...[
                if (i != 0) SizedBox(width: ui(16)),
                _TabPill(
                  label: _StatusTab.values[i].label,
                  active: _StatusTab.values[i] == current,
                  onTap: () => onTap(_StatusTab.values[i]),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: ui(324),
          height: ui(44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          padding: EdgeInsets.symmetric(horizontal: ui(24)),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: ui(16),
                color: const Color(0xFFC6C6C6),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  '搜索姓名、学号、手机、宿舍、家长',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextPlaceholder,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// —— 卡片网格 ——————————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.records,
    required this.onApprove,
    required this.onReject,
  });

  final List<_LeaveRequest> records;
  final ValueChanged<_LeaveRequest> onApprove;
  final ValueChanged<_LeaveRequest> onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            '暂无相关申请',
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = ui(16);
        // 970 设计宽下两列每张 477，gap 16；自适应：尽量两列。
        final cardWidth = (w - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardWidth,
                child: _LeaveCard(
                  record: r,
                  onApprove: () => onApprove(r),
                  onReject: () => onReject(r),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.record,
    required this.onApprove,
    required this.onReject,
  });

  final _LeaveRequest record;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showActions = record.status == _LeaveStatus.reviewing;

    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(record: record),
          SizedBox(height: ui(8)),
          _CardBody(record: record),
          if (showActions) ...[
            SizedBox(height: ui(8)),
            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    label: '通过',
                    isPrimary: true,
                    onTap: onApprove,
                  ),
                ),
                SizedBox(width: ui(12)),
                Expanded(
                  child: _CardActionButton(
                    label: '驳回',
                    isPrimary: false,
                    onTap: onReject,
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

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.record});

  final _LeaveRequest record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          width: ui(40),
          height: ui(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            image: const DecorationImage(
              image: AssetImage('assets/images/schoolA/30.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                Text(
                  record.studentName,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.0,
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
                    height: 1.0,
                  ),
                ),
                SizedBox(width: ui(12)),
                Text(
                  record.leaveType,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: ui(12)),
                Text(
                  '时长${record.duration}',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        _StatusBadge(status: record.status),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
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
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.record});

  final _LeaveRequest record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(16)),
      decoration: BoxDecoration(
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(label: '请假时间：', value: record.timeRange),
          SizedBox(height: ui(6)),
          _InfoLine(label: '请假事由：', value: record.reason),
          SizedBox(height: ui(6)),
          _InfoLine(label: '申请时间：', value: record.appliedAt),
          SizedBox(height: ui(6)),
          _InfoLine(label: '路径：', value: record.path),
          SizedBox(height: ui(8)),
          _StepperBar(
            parent: record.parentStep,
            headTeacher: record.headTeacherStep,
          ),
          SizedBox(height: ui(8)),
          _InfoLine(label: '备注：', value: record.note),
        ],
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
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.5,
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
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// —— 审批 stepper：家长 → 班主任 ————————————————————————————————————

class _StepperBar extends StatelessWidget {
  const _StepperBar({required this.parent, required this.headTeacher});

  final _StepStatus parent;
  final _StepStatus headTeacher;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(28),
      child: Row(
        children: [
          _StepNode(label: '家长', status: parent, isFirst: true),
          Expanded(
            child: Container(height: ui(1), color: _kBorderHair),
          ),
          _StepNode(label: '班主任', status: headTeacher, isFirst: false),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.status,
    required this.isFirst,
  });

  final String label;
  final _StepStatus status;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(14),
          height: ui(14),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F2FF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: ui(8),
            height: ui(8),
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.0,
          ),
        ),
        SizedBox(width: ui(8)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: status == _StepStatus.approved
                ? Colors.white
                : status.softBg,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: ui(12),
              color: status == _StepStatus.approved ? _kTextHint : status.color,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 15.24 / 12,
            ),
          ),
        ),
      ],
    );
  }
}

// —— 审批中卡片 通过 / 驳回 按钮 ————————————————————————————————————

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(40),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: isPrimary ? null : Colors.white,
          border: Border.all(color: _kBorderSoft, width: 1),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: isPrimary ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 24 / 14,
          ),
        ),
      ),
    );
  }
}

// —— 驳回申请弹窗 ——————————————————————————————————————————————————

Future<String?> _showRejectDialog(
  BuildContext context, {
  required _LeaveRequest record,
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
              '学生 ${record.studentName}（${record.studentNo}）· ${record.leaveType}',
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
                    color: _kTextHintLight,
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

// —— Demo data ————————————————————————————————————————————————————————

List<_LeaveRequest> _demoRequests() {
  return [
    const _LeaveRequest(
      studentName: '王晴',
      studentNo: 'G3030201',
      leaveType: '病假',
      duration: '4小时',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      appliedAt: '2026-04-01 18:00',
      path: '家长小程序 - 班主任',
      status: _LeaveStatus.reviewing,
      parentStep: _StepStatus.approved,
      headTeacherStep: _StepStatus.pending,
      note: '已知晓注意休息',
    ),
    const _LeaveRequest(
      studentName: '王晴',
      studentNo: 'G3030201',
      leaveType: '病假',
      duration: '4小时',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      appliedAt: '2026-04-01 18:00',
      path: '家长小程序 - 班主任',
      status: _LeaveStatus.approved,
      parentStep: _StepStatus.approved,
      headTeacherStep: _StepStatus.approved,
      note: '同意',
    ),
    const _LeaveRequest(
      studentName: '王晴',
      studentNo: 'G3030201',
      leaveType: '病假',
      duration: '4小时',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      appliedAt: '2026-04-01 18:00',
      path: '家长小程序 - 班主任',
      status: _LeaveStatus.approved,
      parentStep: _StepStatus.approved,
      headTeacherStep: _StepStatus.approved,
      note: '同意',
    ),
    const _LeaveRequest(
      studentName: '王晴',
      studentNo: 'G3030201',
      leaveType: '病假',
      duration: '4小时',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      appliedAt: '2026-04-01 18:00',
      path: '家长小程序 - 班主任',
      status: _LeaveStatus.rejected,
      parentStep: _StepStatus.approved,
      headTeacherStep: _StepStatus.rejected,
      note: '请补充证明材料后再申请',
    ),
  ];
}
