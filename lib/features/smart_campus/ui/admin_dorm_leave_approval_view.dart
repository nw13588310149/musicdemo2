// =============================================================================
// 管理员端「宿管请假审批」独立页面
//
// 入口：admin 首页快捷区「宿管请假审批」按钮 → controller.openDormLeaveApproval()
//      → mainView == dormLeaveApproval + role == admin → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高，4deg #F9EDFF→white 渐变，圆角 16）：
//      - 左 12 返回按钮 32×32 白底 outline #F3F2F3。
//      - 居中标题 "宿管请假审批" 16/600 + 副标题
//        12/#B6B5BB「宿管人员须在宿管端提交申请；本页为管理端后勤审批台，
//        与学生「请假与补课」、班主任审批互不混用。」
//   2. 3 张统计卡（100 高，flex 1 1 0，间距 12，196deg 渐变白底，圆角 12）：
//      A. 「待审批」紫渐变 #E7DCFF→white 73%
//      B. 「已通过」绿渐变 #DCFFE7→white 73%
//      C. 「已拒绝」红渐变 #FFE2DC→white 73%
//      数值 32 Barlow / 标签 14/500 black。
//   3. 提示行 12/#B6B5BB「默认由家长在小程序审批后再由班主任审批；已与
//      家长充分沟通的可选择班主任直接审批。补课协调以教务安排为准。」
//   4. 控制条：左侧白色 4 padding 圆角 8 容器套 4 枚 pill：
//      全部 / 待审批 / 已通过 / 已拒绝（激活态 #0B081A 黑底白字）；
//      右侧 "审批中 N 条" 标签（数字 #8741FF）+ 紫色渐变 "发起申请" 按钮。
//   5. 双列卡片网格（每张 477，padding 12 白底圆角 12，gap 16）：
//      · header：头像 40 + 姓名 14/500 + 工号 12/#B6B5BB + "病假" 12 +
//        "时长1天" 12/#6D6B75 + 状态徽章。
//      · 灰底信息块 #F5F6FA padding 16：请假时间 / 请假事由 / 管理区域 /
//        申请时间 / 工作交接（label 12/#B6B5BB + 值 12/#0B081A）。
//      · 仅"待审批"卡片 footer 多一行：紫渐变"通过" + 描边"驳回"，
//        "驳回"打开 GradientHeaderDialog 填理由。
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
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextHintLight = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFFE4E5);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);

// —— 状态 ————————————————————————————————————————————————————————
enum _StatusTab {
  all('全部'),
  pending('待审批'),
  approved('已通过'),
  rejected('已拒绝');

  const _StatusTab(this.label);
  final String label;
}

enum _LeaveStatus {
  pending('待审批', _kOrangeSoftBg, _kOrange),
  approved('已通过', _kGreenSoftBg, _kGreen),
  rejected('已拒绝', _kRedSoftBg, _kRed);

  const _LeaveStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

class _DormLeaveRequest {
  const _DormLeaveRequest({
    required this.staffName,
    required this.staffNo,
    required this.leaveType,
    required this.duration,
    required this.timeRange,
    required this.reason,
    required this.area,
    required this.appliedAt,
    required this.handoff,
    required this.status,
  });

  final String staffName;
  final String staffNo;
  final String leaveType;
  final String duration;
  final String timeRange;
  final String reason;
  final String area;
  final String appliedAt;
  final String handoff;
  final _LeaveStatus status;
}

// —— 顶级视图 ——————————————————————————————————————————————————————

class AdminDormLeaveApprovalView extends StatefulWidget {
  const AdminDormLeaveApprovalView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminDormLeaveApprovalView> createState() =>
      _AdminDormLeaveApprovalViewState();
}

class _AdminDormLeaveApprovalViewState
    extends State<AdminDormLeaveApprovalView> {
  _StatusTab _tab = _StatusTab.all;
  late List<_DormLeaveRequest> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _demoRequests();
  }

  int get _pendingCount =>
      _requests.where((r) => r.status == _LeaveStatus.pending).length;
  int get _approvedCount =>
      _requests.where((r) => r.status == _LeaveStatus.approved).length;
  int get _rejectedCount =>
      _requests.where((r) => r.status == _LeaveStatus.rejected).length;

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
            _StatsRow(
              pendingCount: _pendingCount,
              approvedCount: _approvedCount,
              rejectedCount: _rejectedCount,
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
            SizedBox(height: ui(16)),
            _ControlBar(
              current: _tab,
              pendingCount: _pendingCount,
              onTap: (t) => setState(() => _tab = t),
              onApply: _onCreateApply,
            ),
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

  List<_DormLeaveRequest> _filtered() {
    switch (_tab) {
      case _StatusTab.all:
        return _requests;
      case _StatusTab.pending:
        return _requests
            .where((r) => r.status == _LeaveStatus.pending)
            .toList();
      case _StatusTab.approved:
        return _requests
            .where((r) => r.status == _LeaveStatus.approved)
            .toList();
      case _StatusTab.rejected:
        return _requests
            .where((r) => r.status == _LeaveStatus.rejected)
            .toList();
    }
  }

  void _onCreateApply() {
    AppToast.show(context, '请在宿管端发起请假申请（演示）');
  }

  void _onApprove(_DormLeaveRequest record) {
    setState(() {
      final i = _requests.indexOf(record);
      if (i >= 0) {
        _requests[i] = _DormLeaveRequest(
          staffName: record.staffName,
          staffNo: record.staffNo,
          leaveType: record.leaveType,
          duration: record.duration,
          timeRange: record.timeRange,
          reason: record.reason,
          area: record.area,
          appliedAt: record.appliedAt,
          handoff: record.handoff,
          status: _LeaveStatus.approved,
        );
      }
    });
    AppToast.show(
      context,
      '已通过 ${record.staffName} 的${record.leaveType}申请（演示）',
    );
  }

  Future<void> _onReject(_DormLeaveRequest record) async {
    final reason = await _showRejectDialog(context, record: record);
    if (!mounted) {
      return;
    }
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    setState(() {
      final i = _requests.indexOf(record);
      if (i >= 0) {
        _requests[i] = _DormLeaveRequest(
          staffName: record.staffName,
          staffNo: record.staffNo,
          leaveType: record.leaveType,
          duration: record.duration,
          timeRange: record.timeRange,
          reason: record.reason,
          area: record.area,
          appliedAt: record.appliedAt,
          handoff: record.handoff,
          status: _LeaveStatus.rejected,
        );
      }
    });
    AppToast.show(
      context,
      '已驳回 ${record.staffName} 的${record.leaveType}申请：$reason（演示）',
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
                    '宿管请假审批',
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
                    '宿管人员须在宿管端提交申请；本页为管理端后勤审批台，与学生「请假与补课」、班主任审批互不混用。',
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

// —— 3 张统计卡 ——————————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  final int pendingCount;
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
              colors: [Color(0xFFE7DCFF), Colors.white],
              stops: [0.0, 0.73],
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

// —— 控制条：左 tabs + 右 "审批中 N 条" + 紫渐变 "发起申请" ——————————

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.current,
    required this.pendingCount,
    required this.onTap,
    required this.onApply,
  });

  final _StatusTab current;
  final int pendingCount;
  final ValueChanged<_StatusTab> onTap;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          // 用 minHeight 而不是固定 height：fixed 44 + 中文字行高 1.0 会上下
          // 截顶（图：待审批 / 已通过 / 已拒绝 像被切了一刀）。
          constraints: BoxConstraints(minHeight: ui(44)),
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
                if (i != 0) SizedBox(width: ui(8)),
                _TabPill(
                  label: _StatusTab.values[i].label,
                  active: _StatusTab.values[i] == current,
                  onTap: () => onTap(_StatusTab.values[i]),
                ),
              ],
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.0,
                ),
                children: [
                  const TextSpan(text: '审批中 '),
                  TextSpan(
                    text: '$pendingCount',
                    style: const TextStyle(color: _kPurple),
                  ),
                  const TextSpan(text: ' 条'),
                ],
              ),
            ),
            SizedBox(width: ui(12)),
            InkWell(
              onTap: onApply,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                constraints: BoxConstraints(minHeight: ui(44)),
                padding: EdgeInsets.symmetric(
                  horizontal: ui(12),
                  vertical: ui(8),
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                  ),
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.note_add_outlined,
                      size: ui(16),
                      color: Colors.white,
                    ),
                    SizedBox(width: ui(8)),
                    Text(
                      '发起申请',
                      style: TextStyle(
                        fontSize: ui(16),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        // 中文 PingFang SC 行高 1.2 留出 0.2em 内边距；padding 收到 vertical 7
        // 让 36 高内容能完整放下文字，避免上下被切。
        padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(7)),
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
            height: 1.2,
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

  final List<_DormLeaveRequest> records;
  final ValueChanged<_DormLeaveRequest> onApprove;
  final ValueChanged<_DormLeaveRequest> onReject;

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

  final _DormLeaveRequest record;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showActions = record.status == _LeaveStatus.pending;

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

  final _DormLeaveRequest record;

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
                  record.staffName,
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
                  record.staffNo,
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

  final _DormLeaveRequest record;

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
          _InfoLine(label: '管理区域：', value: record.area),
          SizedBox(height: ui(6)),
          _InfoLine(label: '申请时间：', value: record.appliedAt),
          SizedBox(height: ui(6)),
          _InfoLine(label: '工作交接：', value: record.handoff),
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

// —— 通过 / 驳回 按钮 ————————————————————————————————————————————

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

// —— 驳回弹窗 ————————————————————————————————————————————————————

Future<String?> _showRejectDialog(
  BuildContext context, {
  required _DormLeaveRequest record,
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
              '宿管 ${record.staffName}（${record.staffNo}）· ${record.leaveType}',
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

List<_DormLeaveRequest> _demoRequests() {
  return const [
    _DormLeaveRequest(
      staffName: '冯玉洁',
      staffNo: 'HG202301',
      leaveType: '病假',
      duration: '1天',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      area: '男生宿舍3、6、8号楼',
      appliedAt: '2026-04-01 18:00',
      handoff: '夜班由李敏代值，交接表已交后勤',
      status: _LeaveStatus.pending,
    ),
    _DormLeaveRequest(
      staffName: '李珍',
      staffNo: 'HG202301',
      leaveType: '病假',
      duration: '1天',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      area: '男生宿舍3、6、8号楼',
      appliedAt: '2026-04-01 18:00',
      handoff: '夜班由李敏代值，交接表已交后勤',
      status: _LeaveStatus.approved,
    ),
    _DormLeaveRequest(
      staffName: '冯雪梅',
      staffNo: 'HG202301',
      leaveType: '病假',
      duration: '1天',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      area: '男生宿舍3、6、8号楼',
      appliedAt: '2026-04-01 18:00',
      handoff: '夜班由李敏代值，交接表已交后勤',
      status: _LeaveStatus.approved,
    ),
    _DormLeaveRequest(
      staffName: '周环戕',
      staffNo: 'HG202301',
      leaveType: '病假',
      duration: '1天',
      timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
      reason: '发热就诊，需上午门诊检查。',
      area: '男生宿舍3、6、8号楼',
      appliedAt: '2026-04-01 18:00',
      handoff: '夜班由李敏代值，交接表已交后勤',
      status: _LeaveStatus.approved,
    ),
  ];
}
