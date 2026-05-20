// =============================================================================
// 学生端「请假管理」独立页面
//
// 入口：学生 dashboard 快捷区「请假管理」按钮 → controller.openLeaveManagement()
//      → mainView == leaveManagement + role == student → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变，左 32 返回 + 中"请假管理"
//      16px/600 + 副标题 12px/#B6B5BB（默认审批流程说明）。
//   2. 三色统计卡（100 高）：
//      A. 紫渐变 196deg #E7DCFF→white：「待审批」14px + 32px 数值 1
//      B. 绿渐变 196deg #DCFFE7→white：「已通过」14px + 32px 数值 2
//      C. 红渐变 196deg #FFE2DC→white：「已拒绝」14px + 32px 数值 1
//      右下角各放一个对应色 24~54 半透明几何装饰。
//   3. Tabs row（44 高）：白底圆角 8 容器，5 个 pill：
//      全部 / 审批中 / 已通过 / 已拒绝 / 已撤销，激活态 #0B081A 黑底白字 14/500，
//      未激活 #6D6B75 14/500 透明底；右侧紫色渐变胶囊「+ 发起申请」（44 高）。
//      点击「发起申请」→ 右侧抽屉 _LeaveApplyDrawer（600 宽，紫渐变提交按钮）。
//   4. 双列卡片网格（每张 477 宽，padding 12，gradient 210deg #F9EEFF→white，
//      圆角 12，gap 16）：
//      · header 一行：类型 16/500「病假/事假」+ "时长4小时" 12/#6D6B75 +
//        右侧状态徽章 12/4×2 padding（审批中紫底紫字 / 已通过 #E4FFED+#12CE51 /
//        已拒绝 #FFE4E5+#FF323C / 已撤销 灰底灰字）。
//      · 内嵌灰底卡（#F5F6FA，padding 16）：5 行 label-value
//        （请假时间 / 请假事由 / 申请时间 / 路径 / 备注）；
//        中间一段 horizontal stepper：
//           家长 [已通过] ─────────── 班主任 [待审批/已通过/已拒绝]
//        进度点：未到为白底灰描边，激活/到达态使用对应色填充（待审批用 #FF6A00
//        橙；通过用 #12CE51 绿；拒绝用 #FF323C 红）。
//      · footer：审批中卡多一行 40 高描边按钮"撤销申请"。
//
// 颜色 / 字体：
//   主紫 #8741FF / 主紫渐变 270deg #B68EFF→#8640FF；卡片 gradient #F9EEFF→white；
//   状态徽章配色见上；字体 PingFang SC，数字 32 用 Barlow（与 Figma 一致）。
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
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
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFFE4E5);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);

// —— 顶级视图 ——————————————————————————————————————————————————————

class StudentLeaveManagementView extends StatefulWidget {
  const StudentLeaveManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<StudentLeaveManagementView> createState() =>
      _StudentLeaveManagementViewState();
}

class _StudentLeaveManagementViewState
    extends State<StudentLeaveManagementView> {
  _StatusTab _tab = _StatusTab.all;
  late List<_LeaveRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = List<_LeaveRecord>.from(_kDemoLeaveRecords);
  }

  /// 撤销 demo：把对应申请置为「已撤销」，并把审批步骤上的 "待审批" / 当前
  /// 进行中节点都置回 dim 状态。真实接入时换成 API call。
  void _withdraw(String id) {
    setState(() {
      _records = [
        for (final r in _records)
          if (r.id == id)
            r.copyWith(
              status: _LeaveStatus.withdrawn,
              steps: [
                for (final s in r.steps)
                  if (s.state == _StepState.pending)
                    s.copyWith(state: _StepState.dim, label: '已撤销')
                  else
                    s,
              ],
            )
          else
            r,
      ];
    });
  }

  /// 弹出右侧抽屉发起请假，提交后追加到 _records 顶部。
  /// 真实接入时换成 API call，并以服务器返回的记录刷新列表。
  ///
  /// 注意：`showGeneralDialog` 通过 root Navigator 推 route，新子树**不在原
  /// dashboard 的祖先链**上，所以必须显式把 [DashboardScaleScope] 注入到
  /// `pageBuilder` 中，否则 drawer 内 `DashboardScaleScope.of(context)` 会
  /// 抛 "DashboardScaleScope not found in widget tree."。
  Future<void> _showApplyDrawer() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final result = await showGeneralDialog<_LeaveApplyResult>(
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
              child: _LeaveApplyDrawer(
                onCancel: () => Navigator.of(ctx).maybePop(),
                onSubmit: (data) => Navigator.of(ctx).pop(data),
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

    if (!mounted || result == null) return;

    final newRecord = _LeaveRecord(
      id: 'leave-${DateTime.now().microsecondsSinceEpoch}',
      type: result.type,
      durationLabel: result.durationLabel,
      timeRange:
          '${_LeaveApplyDrawer.formatDateTime(result.start)} - '
          '${_LeaveApplyDrawer.formatDateTime(result.end)}',
      reason: result.reason,
      appliedAt: _LeaveApplyDrawer.formatDateTime(DateTime.now()),
      flowPath: '家长小程序 - 班主任',
      steps: const [
        _ApprovalStep(title: '家长', label: '待审批', state: _StepState.pending),
        _ApprovalStep(title: '班主任', label: '未开始', state: _StepState.dim),
      ],
      note: result.note.isEmpty ? '—' : result.note,
      status: _LeaveStatus.reviewing,
    );

    setState(() {
      _records = [newRecord, ..._records];
      _tab = _StatusTab.reviewing;
    });

    AppToast.show(context, '请假申请已提交，等待审批');
  }

  List<_LeaveRecord> get _visible {
    return _records.where((r) {
      switch (_tab) {
        case _StatusTab.all:
          return true;
        case _StatusTab.reviewing:
          return r.status == _LeaveStatus.reviewing;
        case _StatusTab.approved:
          return r.status == _LeaveStatus.approved;
        case _StatusTab.rejected:
          return r.status == _LeaveStatus.rejected;
        case _StatusTab.withdrawn:
          return r.status == _LeaveStatus.withdrawn;
      }
    }).toList();
  }

  int _countOf(_LeaveStatus s) => _records.where((r) => r.status == s).length;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeaveBanner(onBack: widget.onBack),
            SizedBox(height: ui(12)),
            _StatsRow(
              reviewing: _countOf(_LeaveStatus.reviewing),
              approved: _countOf(_LeaveStatus.approved),
              rejected: _countOf(_LeaveStatus.rejected),
            ),
            SizedBox(height: ui(12)),
            _TabsAndCreateRow(
              tab: _tab,
              onTab: (t) => setState(() => _tab = t),
              onCreate: _showApplyDrawer,
            ),
            SizedBox(height: ui(12)),
            _LeaveCardsGrid(records: _visible, onWithdraw: _withdraw),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner：返回 + 标题 + 副标题
// =============================================================================

class _LeaveBanner extends StatelessWidget {
  const _LeaveBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
      ),
      child: Row(
        children: [
          _BackButton(onTap: onBack),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '请假管理',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    '默认由家长在小程序审批后再由班主任审批；已与家长充分沟通的可选择班主任直接审批。',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: ui(32)),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
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
    );
  }
}

// =============================================================================
// 三色统计卡
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.reviewing,
    required this.approved,
    required this.rejected,
  });

  final int reviewing;
  final int approved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '待审批',
            value: reviewing,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFE7DCFF), Colors.white],
              stops: [0, 0.73],
            ),
            decorationColor: const Color(0x33D5BEFF),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '已通过',
            value: approved,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFDCFFE7), Colors.white],
              stops: [0, 0.73],
            ),
            decorationColor: const Color(0x4DBEFFCB),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '已拒绝',
            value: rejected,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFE2DC), Colors.white],
              stops: [0, 0.73],
            ),
            decorationColor: const Color(0x4DFFC2B5),
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
    required this.decorationColor,
  });

  final String label;
  final int value;
  final LinearGradient gradient;
  final Color decorationColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(14)),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        children: [
          // 右下半透明几何装饰：和 Figma 的 24/54 三角形 + 圆角块对应。
          Positioned(
            right: ui(8),
            bottom: ui(8),
            child: Container(
              width: ui(44),
              height: ui(44),
              decoration: BoxDecoration(
                color: decorationColor,
                borderRadius: BorderRadius.circular(ui(10)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(14),
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
              SizedBox(height: ui(8)),
              Text(
                '$value',
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
// Tabs + 发起申请 row
// =============================================================================

enum _StatusTab { all, reviewing, approved, rejected, withdrawn }

extension on _StatusTab {
  String get label {
    switch (this) {
      case _StatusTab.all:
        return '全部';
      case _StatusTab.reviewing:
        return '审批中';
      case _StatusTab.approved:
        return '已通过';
      case _StatusTab.rejected:
        return '已拒绝';
      case _StatusTab.withdrawn:
        return '已撤销';
    }
  }
}

class _TabsAndCreateRow extends StatelessWidget {
  const _TabsAndCreateRow({
    required this.tab,
    required this.onTab,
    required this.onCreate,
  });

  final _StatusTab tab;
  final ValueChanged<_StatusTab> onTab;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _StatusTab.values.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i == _StatusTab.values.length - 1 ? 0 : ui(4),
                  ),
                  child: _TabPill(
                    label: _StatusTab.values[i].label,
                    active: _StatusTab.values[i] == tab,
                    onTap: () => onTab(_StatusTab.values[i]),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        _CreateApplyButton(onTap: onCreate),
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
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
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
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _CreateApplyButton extends StatelessWidget {
  const _CreateApplyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(44),
        padding: EdgeInsets.symmetric(horizontal: ui(14)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(8)),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(alpha: 0.18),
              blurRadius: ui(10),
              offset: Offset(0, ui(3)),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_document, size: ui(16), color: Colors.white),
            SizedBox(width: ui(8)),
            Text(
              '发起申请',
              style: TextStyle(
                fontSize: ui(16),
                color: Colors.white,
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

// =============================================================================
// 卡片网格
// =============================================================================

class _LeaveCardsGrid extends StatelessWidget {
  const _LeaveCardsGrid({required this.records, required this.onWithdraw});

  final List<_LeaveRecord> records;
  final ValueChanged<String> onWithdraw;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return _EmptyState();
    }
    return LayoutBuilder(
      builder: (context, c) {
        final gap = ui(16);
        final twoCol = c.maxWidth >= ui(720);
        final cardWidth = twoCol ? (c.maxWidth - gap) / 2 : c.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardWidth,
                child: _LeaveCard(
                  record: r,
                  onWithdraw: () => onWithdraw(r.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(40)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: ui(48), color: _kTextHint),
          SizedBox(height: ui(8)),
          Text(
            '当前筛选下没有请假记录',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.record, required this.onWithdraw});

  final _LeaveRecord record;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF9EEFF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeaderRow(record: record),
          SizedBox(height: ui(8)),
          _CardBoardBody(record: record),
          if (record.status == _LeaveStatus.reviewing) ...[
            SizedBox(height: ui(8)),
            _WithdrawButton(onTap: onWithdraw),
          ],
        ],
      ),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({required this.record});

  final _LeaveRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Text(
          record.type,
          style: TextStyle(
            fontSize: ui(16),
            color: Colors.black,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.1,
          ),
        ),
        SizedBox(width: ui(12)),
        Text(
          '时长${record.durationLabel}',
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.1,
          ),
        ),
        const Spacer(),
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
    final (Color bg, Color fg, String label) = switch (status) {
      _LeaveStatus.reviewing => (_kPurpleSoftBg, _kPurple, '审批中'),
      _LeaveStatus.approved => (_kGreenSoftBg, _kGreen, '已通过'),
      _LeaveStatus.rejected => (_kRedSoftBg, _kRed, '已拒绝'),
      _LeaveStatus.withdrawn => (_kBoardBg, _kTextSecondary, '已撤销'),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
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

class _CardBoardBody extends StatelessWidget {
  const _CardBoardBody({required this.record});

  final _LeaveRecord record;

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
          _LabelRow(label: '请假时间：', value: record.timeRange),
          SizedBox(height: ui(6)),
          _LabelRow(label: '请假事由：', value: record.reason),
          SizedBox(height: ui(6)),
          _LabelRow(label: '申请时间：', value: record.appliedAt),
          SizedBox(height: ui(6)),
          _LabelRow(label: '路径：', value: record.flowPath),
          SizedBox(height: ui(8)),
          _ApprovalStepper(steps: record.steps),
          SizedBox(height: ui(8)),
          _LabelRow(label: '备注：', value: record.note),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.value});

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

// =============================================================================
// 审批 stepper（家长 → 班主任）
// =============================================================================

class _ApprovalStepper extends StatelessWidget {
  const _ApprovalStepper({required this.steps});

  final List<_ApprovalStep> steps;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(4)),
      child: SizedBox(
        height: ui(20),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            // 两个节点居中分布在两侧 25% / 75% 处。
            final positions = [w * 0.18, w * 0.62];
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 横线
                Positioned(
                  left: ui(8),
                  right: ui(8),
                  top: ui(9),
                  child: Container(height: 1, color: _kBorderHair),
                ),
                for (var i = 0; i < steps.length; i++)
                  Positioned(
                    left: positions[i],
                    top: 0,
                    child: _ApprovalNodeView(step: steps[i]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalNodeView extends StatelessWidget {
  const _ApprovalNodeView({required this.step});

  final _ApprovalStep step;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (
      Color dot,
      Color halo,
      Color labelBg,
      Color labelFg,
    ) = switch (step.state) {
      _StepState.pending => (
        _kOrange,
        const Color(0xFFFFF1D9),
        _kOrangeSoftBg,
        _kOrange,
      ),
      _StepState.passed => (
        _kGreen,
        const Color(0xFFEFFFE7),
        Colors.white,
        _kTextHint,
      ),
      _StepState.rejected => (
        _kRed,
        const Color(0xFFFFE5E7),
        _kRedSoftBg,
        _kRed,
      ),
      _StepState.dim => (
        _kTextDivider,
        Colors.transparent,
        Colors.white,
        _kTextHint,
      ),
    };

    final hasHalo = step.state != _StepState.dim;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: ui(14),
          height: ui(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasHalo)
                Container(
                  width: ui(14),
                  height: ui(14),
                  decoration: BoxDecoration(
                    color: halo,
                    borderRadius: BorderRadius.circular(ui(7)),
                  ),
                ),
              Container(
                width: ui(9),
                height: ui(9),
                decoration: BoxDecoration(
                  color: step.state == _StepState.dim ? Colors.white : dot,
                  borderRadius: BorderRadius.circular(ui(5)),
                  border: Border.all(
                    color: step.state == _StepState.dim
                        ? _kTextDivider
                        : Colors.white,
                    width: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          step.title,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(width: ui(6)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Text(
            step.label,
            style: TextStyle(
              fontSize: ui(12),
              color: labelFg,
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

class _WithdrawButton extends StatelessWidget {
  const _WithdrawButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: double.infinity,
        height: ui(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Text(
          '撤销申请',
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 24 / 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 数据模型 + Demo 数据
// =============================================================================

enum _LeaveStatus { reviewing, approved, rejected, withdrawn }

enum _StepState { pending, passed, rejected, dim }

class _ApprovalStep {
  const _ApprovalStep({
    required this.title,
    required this.label,
    required this.state,
  });

  final String title;
  final String label;
  final _StepState state;

  _ApprovalStep copyWith({String? label, _StepState? state}) => _ApprovalStep(
    title: title,
    label: label ?? this.label,
    state: state ?? this.state,
  );
}

class _LeaveRecord {
  const _LeaveRecord({
    required this.id,
    required this.type,
    required this.durationLabel,
    required this.timeRange,
    required this.reason,
    required this.appliedAt,
    required this.flowPath,
    required this.steps,
    required this.note,
    required this.status,
  });

  final String id;
  final String type; // 病假 / 事假 / 公假 ...
  final String durationLabel; // "4小时" / "1天"
  final String timeRange;
  final String reason;
  final String appliedAt;
  final String flowPath; // "家长小程序 - 班主任"
  final List<_ApprovalStep> steps;
  final String note;
  final _LeaveStatus status;

  _LeaveRecord copyWith({_LeaveStatus? status, List<_ApprovalStep>? steps}) =>
      _LeaveRecord(
        id: id,
        type: type,
        durationLabel: durationLabel,
        timeRange: timeRange,
        reason: reason,
        appliedAt: appliedAt,
        flowPath: flowPath,
        steps: steps ?? this.steps,
        note: note,
        status: status ?? this.status,
      );
}

const List<_LeaveRecord> _kDemoLeaveRecords = [
  _LeaveRecord(
    id: 'leave-1',
    type: '病假',
    durationLabel: '4小时',
    timeRange: '2026-04-02 08:00 - 2026-04-02 12:00',
    reason: '发热就诊，需上午门诊检查。',
    appliedAt: '2026-04-01 18:00',
    flowPath: '家长小程序 - 班主任',
    steps: [
      _ApprovalStep(title: '家长', label: '已通过', state: _StepState.passed),
      _ApprovalStep(title: '班主任', label: '待审批', state: _StepState.pending),
    ],
    note: '已知晓注意休息',
    status: _LeaveStatus.reviewing,
  ),
  _LeaveRecord(
    id: 'leave-2',
    type: '病假',
    durationLabel: '4小时',
    timeRange: '2026-03-22 08:00 - 2026-03-22 12:00',
    reason: '发热就诊，需上午门诊检查。',
    appliedAt: '2026-03-21 18:00',
    flowPath: '家长小程序 - 班主任',
    steps: [
      _ApprovalStep(title: '家长', label: '已通过', state: _StepState.passed),
      _ApprovalStep(title: '班主任', label: '已通过', state: _StepState.passed),
    ],
    note: '已知晓注意休息',
    status: _LeaveStatus.approved,
  ),
  _LeaveRecord(
    id: 'leave-3',
    type: '事假',
    durationLabel: '4小时',
    timeRange: '2026-03-15 14:00 - 2026-03-15 18:00',
    reason: '家中有事需提前回家协助。',
    appliedAt: '2026-03-14 18:00',
    flowPath: '家长小程序 - 班主任',
    steps: [
      _ApprovalStep(title: '家长', label: '已通过', state: _StepState.passed),
      _ApprovalStep(title: '班主任', label: '已拒绝', state: _StepState.rejected),
    ],
    note: '请协调班委处理课程笔记',
    status: _LeaveStatus.rejected,
  ),
  _LeaveRecord(
    id: 'leave-4',
    type: '病假',
    durationLabel: '4小时',
    timeRange: '2026-03-08 08:00 - 2026-03-08 12:00',
    reason: '复诊检查，需上午就诊。',
    appliedAt: '2026-03-07 19:00',
    flowPath: '家长小程序 - 班主任',
    steps: [
      _ApprovalStep(title: '家长', label: '已通过', state: _StepState.passed),
      _ApprovalStep(title: '班主任', label: '已通过', state: _StepState.passed),
    ],
    note: '已知晓注意休息',
    status: _LeaveStatus.approved,
  ),
];

// =============================================================================
// 发起请假 · 右侧抽屉
//   · 整体 600 宽，从右滑入；与 dorm 端共用同一布局，但裁剪掉「顶班/交接说明」
//     字段（学生不需要），并把"作业标题"换成「请假类型」单选下拉。
//   · 时长根据开始/结束时间自动计算（向上取小时整数），用户可手动覆盖。
//   · 提交按钮在校验通过后回调 `_LeaveApplyResult` 给父级，由父级新增记录。
// =============================================================================

class _LeaveApplyResult {
  const _LeaveApplyResult({
    required this.type,
    required this.start,
    required this.end,
    required this.durationLabel,
    required this.reason,
    required this.note,
  });

  final String type;
  final DateTime start;
  final DateTime end;
  final String durationLabel;
  final String reason;
  final String note;
}

class _LeaveApplyDrawer extends StatefulWidget {
  const _LeaveApplyDrawer({required this.onCancel, required this.onSubmit});

  final VoidCallback onCancel;
  final ValueChanged<_LeaveApplyResult> onSubmit;

  static String formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  State<_LeaveApplyDrawer> createState() => _LeaveApplyDrawerState();
}

class _LeaveApplyDrawerState extends State<_LeaveApplyDrawer> {
  static const _types = ['病假', '事假', '其他'];

  String _type = '病假';
  DateTime? _start;
  DateTime? _end;
  final _hoursCtrl = TextEditingController();
  bool _hoursDirty = false; // 用户是否手动改过时长
  final _reasonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hoursCtrl.addListener(() {
      // 用户开始输入后，自动算时长不再覆盖
      if (!_hoursDirty) _hoursDirty = true;
    });
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _autoFillHours() {
    if (_start == null || _end == null) return;
    if (!_end!.isAfter(_start!)) return;
    final minutes = _end!.difference(_start!).inMinutes;
    final hours = (minutes / 60);
    final label = hours == hours.floorToDouble()
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    _hoursDirty = false;
    _hoursCtrl.text = label;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_start ?? DateTime.now())
        : (_end ?? _start ?? DateTime.now());
    // 用项目主紫 #8741FF 覆盖 Material picker 的默认配色，与 dorm 端补卡
    // 表单保持视觉一致；同时把 day-period chip / hour-minute 按钮等用到的
    // primaryContainer 一并改成淡紫底，避免 Material 默认的 tonalSurface 色。
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 2),
      helpText: isStart ? '选择开始日期' : '选择结束日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: appPickerDialogTheme,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: isStart ? '选择开始时间' : '选择结束时间',
      cancelText: '取消',
      confirmText: '确定',
      builder: appPickerDialogTheme,
    );
    if (pickedTime == null || !mounted) return;
    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
      if (!_hoursDirty) _autoFillHours();
    });
  }

  void _onSubmit() {
    final start = _start;
    final end = _end;
    final reason = _reasonCtrl.text.trim();
    if (start == null || end == null) {
      _toast('请选择开始与结束时间');
      return;
    }
    if (!end.isAfter(start)) {
      _toast('结束时间需晚于开始时间');
      return;
    }
    final hoursText = _hoursCtrl.text.trim();
    if (hoursText.isEmpty) {
      _toast('请填写时长');
      return;
    }
    if (reason.isEmpty) {
      _toast('请填写请假事由');
      return;
    }
    final durationLabel = hoursText.endsWith('小时') ? hoursText : '$hoursText小时';

    widget.onSubmit(
      _LeaveApplyResult(
        type: _type,
        start: start,
        end: end,
        durationLabel: durationLabel,
        reason: reason,
        note: _noteCtrl.text.trim(),
      ),
    );
  }

  void _toast(String msg) {
    AppToast.show(context, msg);
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
            _DrawerHeader(onClose: widget.onCancel),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(ui(20), ui(8), ui(20), ui(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('请假类型'),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _type,
                      items: _types,
                      itemLabel: (s) => s,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('开始时间'),
                              SizedBox(height: ui(12)),
                              _DateField(
                                value: _start,
                                placeholder: '年/月/日',
                                onTap: () => _pickDateTime(isStart: true),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ui(32)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('结束时间'),
                              SizedBox(height: ui(12)),
                              _DateField(
                                value: _end,
                                placeholder: '年/月/日',
                                onTap: () => _pickDateTime(isStart: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('时长（自动算，可手动修改）'),
                    SizedBox(height: ui(12)),
                    _TextInputField(
                      controller: _hoursCtrl,
                      placeholder: '请输入时长（小时）',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('请假事由'),
                    SizedBox(height: ui(12)),
                    _TextAreaField(
                      controller: _reasonCtrl,
                      placeholder: '请输入请假理由',
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('备注（选填）'),
                    SizedBox(height: ui(12)),
                    _TextAreaField(
                      controller: _noteCtrl,
                      placeholder: '补充说明，例如已与班主任沟通、需课代表代收作业等',
                    ),
                    SizedBox(height: ui(28)),
                  ],
                ),
              ),
            ),
            _DrawerFooter(onCancel: widget.onCancel, onSubmit: _onSubmit),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});

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
            '发起请假',
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

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({required this.onCancel, required this.onSubmit});

  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(ui(12)),
              child: Container(
                height: ui(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kBorderHair,
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 24 / 14,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: ui(24)),
          Expanded(
            child: InkWell(
              onTap: onSubmit,
              borderRadius: BorderRadius.circular(ui(12)),
              child: Container(
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
                child: Text(
                  '提交申请',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 24 / 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: Colors.black,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 20 / 14,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filled = value != null;
    final text = filled
        ? _LeaveApplyDrawer.formatDateTime(value!)
        : placeholder;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBoardBg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: filled ? _kTextDark : _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_rounded,
              size: ui(16),
              color: const Color(0xFF1C274C),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.controller,
    required this.placeholder,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBoardBg),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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
          hintText: placeholder,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({required this.controller, required this.placeholder});

  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(72),
      padding: EdgeInsets.fromLTRB(ui(16), ui(12), ui(16), ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBoardBg),
      ),
      child: TextField(
        controller: controller,
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
          hintText: placeholder,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
