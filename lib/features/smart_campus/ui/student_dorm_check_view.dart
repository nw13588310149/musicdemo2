// =============================================================================
// 学生端「查寝管理」独立页面
//
// 入口：学生 dashboard 快捷区「查寝管理」按钮 → controller.openDormCheck()
//      → mainView == dormCheck + role == student → SmartCampusPage 路由到
//      本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：左→右白→#F9EEFF 渐变，左 32 返回 + 中
//      "查寝管理" 16/600 + 副标题（仅展示本人「<姓名>」的查寝记录;补卡需
//      宿管/班主任审核），其中名字段用紫色 #8741FF 高亮。
//   2. 4 张统计卡（一行平铺，gap 12，100 高）：
//      A. 「宿舍床位」14/500 + 床位 18/500（女生宿舍3号楼 612） + 蓝色
//         楼宇图标小方块（米色淡色光晕）
//      B. 「正常打卡」14/500 + 数字 32/500
//      C. 「异常（未打/晚归）」14/500 + 数字 32/500 + 紫色异常图标
//      D. 「补卡待审」14/500 + 数字 32/500 + "共 N 条申请"灰小字
//   3. 列表区："我的查寝记录" 18/500 + 右侧白底 全部/异常 双 tab。
//   4. 卡片网格（3 列，每张 312 宽，padding 12，gradient 207deg #FAF0FF→white）：
//      - 头部：场次（晚查寝/晨查寝） 18/600 + 状态徽章
//        正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF。
//      - 副标题：宿舍 + 日期。
//      - 内嵌灰底 50 高小方块：规定时间 / 打卡时间（迟到时打卡时间用
//        #FF323C 高亮）。
//      - 备注：灰小字。
//   5. 顶部右上角浮按钮「申请补卡」12/600 + 紫色多日历图标 → 弹出
//      `GradientHeaderDialog` 表单（日期 / 场次 / 补卡说明 + 取消/确认）。
//
// 颜色 / 字体：
//   主紫 #8741FF / Banner 渐变 white → #F9EEFF / 卡片 gradient #FAF0FF→white；
//   字体 PingFang SC，数字 32 用 Barlow（与 Figma 一致）。
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleStatus = Color(0xFFA773FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kBlue = Color(0xFF325BFF);

// —— 顶级视图 ——————————————————————————————————————————————————————

class StudentDormCheckView extends StatefulWidget {
  const StudentDormCheckView({
    super.key,
    required this.onBack,
    this.studentName = '苏音桐',
    this.dorm = '女生宿舍3号楼 612',
  });

  final VoidCallback onBack;
  final String studentName;
  final String dorm;

  @override
  State<StudentDormCheckView> createState() => _StudentDormCheckViewState();
}

class _StudentDormCheckViewState extends State<StudentDormCheckView> {
  _DormTab _tab = _DormTab.all;
  late List<_DormCheckRecord> _records;
  int _pendingResubmits = 1;

  @override
  void initState() {
    super.initState();
    _records = List<_DormCheckRecord>.from(_kDemoDormRecords);
  }

  int _countOf(_DormStatus s) => _records.where((r) => r.status == s).length;

  int get _normalCount => _countOf(_DormStatus.normal);
  int get _abnormalCount => _records
      .where(
        (r) => r.status == _DormStatus.missed || r.status == _DormStatus.late,
      )
      .length;

  List<_DormCheckRecord> get _visible {
    switch (_tab) {
      case _DormTab.all:
        return _records;
      case _DormTab.abnormal:
        return _records
            .where(
              (r) =>
                  r.status == _DormStatus.missed ||
                  r.status == _DormStatus.late,
            )
            .toList();
    }
  }

  Future<void> _openApplyDialog() async {
    final result = await showScaledDialog<_DormResubmitFormResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => const _DormResubmitDialog(),
    );
    if (!mounted || result == null) return;
    setState(() => _pendingResubmits += 1);
    AppToast.show(context, '已提交补卡申请：${result.dateLabel} · ${result.scene}');
  }

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
            _DormBanner(
              onBack: widget.onBack,
              studentName: widget.studentName,
              onApplyResubmit: _openApplyDialog,
            ),
            SizedBox(height: ui(16)),
            _DormStatsRow(
              dorm: widget.dorm,
              normal: _normalCount,
              abnormal: _abnormalCount,
              pendingResubmits: _pendingResubmits,
            ),
            SizedBox(height: ui(28)),
            _SectionHeader(tab: _tab, onTab: (t) => setState(() => _tab = t)),
            SizedBox(height: ui(16)),
            _DormCardsGrid(records: _visible),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner：返回 + 标题 + 副标题 + 申请补卡按钮
// =============================================================================

class _DormBanner extends StatelessWidget {
  const _DormBanner({
    required this.onBack,
    required this.studentName,
    required this.onApplyResubmit,
  });

  final VoidCallback onBack;
  final String studentName;
  final VoidCallback onApplyResubmit;

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
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Color(0xFFF9EEFF)],
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
                    '查寝管理',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  RichText(
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.1,
                      ),
                      children: [
                        const TextSpan(text: '仅展示本人'),
                        TextSpan(
                          text: '「$studentName」',
                          style: const TextStyle(color: _kPurple),
                        ),
                        const TextSpan(text: '的查寝记录;补卡需宿管/班主任审核。'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ApplyResubmitButton(onTap: onApplyResubmit),
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

class _ApplyResubmitButton extends StatelessWidget {
  const _ApplyResubmitButton({required this.onTap});

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
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: ui(14), color: _kPurple),
            SizedBox(width: ui(6)),
            Text(
              '申请补卡',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
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
// 4 张统计卡
// =============================================================================

class _DormStatsRow extends StatelessWidget {
  const _DormStatsRow({
    required this.dorm,
    required this.normal,
    required this.abnormal,
    required this.pendingResubmits,
  });

  final String dorm;
  final int normal;
  final int abnormal;
  final int pendingResubmits;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _DormStatCard(
            label: '宿舍床位',
            value: dorm,
            valueIsText: true,
            tintColor: const Color(0xFFFFA846),
            iconBuilder: (ctx, sz) =>
                Icon(Icons.apartment_rounded, size: sz, color: _kBlue),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _DormStatCard(
            label: '正常打卡',
            value: '$normal',
            tintColor: const Color(0xFF46FF77),
            iconBuilder: (ctx, sz) => Icon(
              Icons.check_circle_outline_rounded,
              size: sz,
              color: const Color(0xFF1CD097),
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _DormStatCard(
            label: '异常（未打/晚归）',
            value: '$abnormal',
            tintColor: const Color(0xFFFF4646),
            iconBuilder: (ctx, sz) =>
                Icon(Icons.report_problem_outlined, size: sz, color: _kPurple),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _DormStatCard(
            label: '补卡待审',
            value: '$pendingResubmits',
            sublabel: '共$pendingResubmits条申请',
            tintColor: const Color(0xFF9346FF),
            iconBuilder: (ctx, sz) =>
                Icon(Icons.event_repeat_outlined, size: sz, color: _kPurple),
          ),
        ),
      ],
    );
  }
}

class _DormStatCard extends StatelessWidget {
  const _DormStatCard({
    required this.label,
    required this.value,
    required this.tintColor,
    required this.iconBuilder,
    this.sublabel,
    this.valueIsText = false,
  });

  final String label;
  final String value;
  final Color tintColor;
  final Widget Function(BuildContext, double) iconBuilder;
  final String? sublabel;
  final bool valueIsText;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 高度用 ConstrainedBox 而非固定值：Figma 100 高在 PingFang/Barlow 实际
    // typography metrics 下会出 ~1.6 px 微溢出，给个 minHeight 让容器
    // 在内容真的更高时也不会触发 RenderFlex overflow。
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: ui(100)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(14)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [tintColor.withValues(alpha: 0.16), Colors.white],
            stops: const [0, 1],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: Colors.white),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: ui(2),
              child: Container(
                width: ui(32),
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: iconBuilder(context, ui(20)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(8)),
                if (valueIsText)
                  Padding(
                    padding: EdgeInsets.only(right: ui(40)),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(18),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.1,
                      ),
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: ui(32),
                          color: _kTextDark,
                          fontFamily: 'Barlow',
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                      if (sublabel != null) ...[
                        SizedBox(width: ui(8)),
                        Padding(
                          padding: EdgeInsets.only(bottom: ui(2)),
                          child: Text(
                            sublabel!,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextHint,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 章节头：我的查寝记录 + 全部 / 异常 tabs
// =============================================================================

enum _DormTab { all, abnormal }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.tab, required this.onTab});

  final _DormTab tab;
  final ValueChanged<_DormTab> onTab;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Text(
          '我的查寝记录',
          style: TextStyle(
            fontSize: ui(18),
            color: _kTextSection,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabPill(
                label: '全部',
                active: tab == _DormTab.all,
                onTap: () => onTab(_DormTab.all),
              ),
              SizedBox(width: ui(4)),
              _TabPill(
                label: '异常',
                active: tab == _DormTab.abnormal,
                onTap: () => onTab(_DormTab.abnormal),
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

// =============================================================================
// 卡片网格 + 单张卡片
// =============================================================================

class _DormCardsGrid extends StatelessWidget {
  const _DormCardsGrid({required this.records});

  final List<_DormCheckRecord> records;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
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
              '当前筛选下没有查寝记录',
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final gap = ui(16);
        final cols = c.maxWidth >= ui(960)
            ? 3
            : c.maxWidth >= ui(640)
            ? 2
            : 1;
        final cardWidth = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardWidth,
                child: _DormCard(record: r),
              ),
          ],
        );
      },
    );
  }
}

class _DormCard extends StatelessWidget {
  const _DormCard({required this.record});

  final _DormCheckRecord record;

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
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                record.session,
                style: TextStyle(
                  fontSize: ui(18),
                  color: _kTextSection,
                  // Figma 在不同 cell 间混用了 Barlow / PingFang SC，这里
                  // 必须用 PingFang SC：Barlow 不含中文字形，
                  // CanvasKit 字体回退会触发 "table index is out of bounds"。
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              _StatusBadge(status: record.status),
            ],
          ),
          SizedBox(height: ui(4)),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.dorm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 13,
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
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _TimePanel(
            requiredTime: record.requiredTime,
            stampedTime: record.stampedTime,
            stampedHighlight: record.status == _DormStatus.late,
          ),
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _DormStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (Color bg, String label) = switch (status) {
      _DormStatus.normal => (_kPurpleStatus, '正常'),
      _DormStatus.missed => (_kRed, '未打卡'),
      _DormStatus.late => (_kBlue, '迟到'),
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
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _TimePanel extends StatelessWidget {
  const _TimePanel({
    required this.requiredTime,
    required this.stampedTime,
    required this.stampedHighlight,
  });

  final String requiredTime;
  final String? stampedTime;
  final bool stampedHighlight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Figma 的 50 高对应 11+12+5+12+11=51（因为 Text 含 leading），
    // 这里改成自适应内容高度并保留 padding，避免 1px overflow。
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ui(10)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _TimeCell(label: '规定时间', value: requiredTime),
              ),
              Expanded(
                child: _TimeCell(
                  label: '打卡时间',
                  value: stampedTime ?? '—',
                  valueColor: stampedHighlight ? _kRed : _kTextDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.value,
    this.valueColor = _kTextDark,
  });

  final String label;
  final String value;
  final Color valueColor;

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
            height: 1,
          ),
        ),
        SizedBox(height: ui(5)),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(12),
            color: valueColor,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 申请查寝补卡 dialog
// =============================================================================

class _DormResubmitFormResult {
  const _DormResubmitFormResult({
    required this.dateLabel,
    required this.scene,
    required this.note,
  });

  final String dateLabel;
  final String scene;
  final String note;
}

enum _ResubmitScene { morning, evening }

extension on _ResubmitScene {
  String get label {
    switch (this) {
      case _ResubmitScene.morning:
        return '晨打卡';
      case _ResubmitScene.evening:
        return '晚打卡';
    }
  }
}

class _DormResubmitDialog extends StatefulWidget {
  const _DormResubmitDialog();

  @override
  State<_DormResubmitDialog> createState() => _DormResubmitDialogState();
}

class _DormResubmitDialogState extends State<_DormResubmitDialog> {
  DateTime? _date;
  _ResubmitScene _scene = _ResubmitScene.evening;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _canConfirm => _date != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确认',
      builder: appPickerDialogTheme,
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  String _dateText() {
    final d = _date;
    if (d == null) return '年/月/日';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mm/$dd';
  }

  void _submit() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(
      _DormResubmitFormResult(
        dateLabel: _dateText(),
        scene: _scene.label,
        note: _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '申请查寝补卡',
      titleFontSize: 24,
      titleFontWeight: FontWeight.w500,
      titlePaddingTop: 39,
      width: 428,
      actionBar: AppDialogActionBar(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmEnabled: _canConfirm,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FieldLabel('日期'),
            SizedBox(height: ui(10)),
            _DatePickerField(text: _dateText(), onTap: _pickDate),
            SizedBox(height: ui(15)),
            _FieldLabel('场次'),
            SizedBox(height: ui(10)),
            Row(
              children: [
                _ScenePill(
                  label: _ResubmitScene.evening.label,
                  active: _scene == _ResubmitScene.evening,
                  onTap: () => setState(() => _scene = _ResubmitScene.evening),
                ),
                SizedBox(width: ui(12)),
                _ScenePill(
                  label: _ResubmitScene.morning.label,
                  active: _scene == _ResubmitScene.morning,
                  onTap: () => setState(() => _scene = _ResubmitScene.morning),
                ),
              ],
            ),
            SizedBox(height: ui(15)),
            _FieldLabel('补卡说明'),
            SizedBox(height: ui(10)),
            _NoteField(controller: _noteCtrl),
          ],
        ),
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
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 20 / 14,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPlaceholder = text == '年/月/日';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: ui(14),
                  color: isPlaceholder ? const Color(0xFFCECED1) : _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: ui(16), color: _kPurple),
          ],
        ),
      ),
    );
  }
}

class _ScenePill extends StatelessWidget {
  const _ScenePill({
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
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(24)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
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
          hintText: '请输入',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(16),
            vertical: ui(12),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// =============================================================================
// 数据模型 + Demo 数据
// =============================================================================

enum _DormStatus { normal, missed, late }

class _DormCheckRecord {
  const _DormCheckRecord({
    required this.session,
    required this.status,
    required this.dorm,
    required this.date,
    required this.requiredTime,
    required this.stampedTime,
    required this.note,
  });

  final String session; // 晨查寝 / 晚查寝
  final _DormStatus status;
  final String dorm;
  final String date;
  final String requiredTime;
  final String? stampedTime;
  final String note;
}

const List<_DormCheckRecord> _kDemoDormRecords = [
  _DormCheckRecord(
    session: '晨查寝',
    status: _DormStatus.normal,
    dorm: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    stampedTime: '07:18',
    note: '无',
  ),
  _DormCheckRecord(
    session: '晨查寝',
    status: _DormStatus.missed,
    dorm: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    stampedTime: null,
    note: '无',
  ),
  _DormCheckRecord(
    session: '晚查寝',
    status: _DormStatus.late,
    dorm: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '21:20前',
    stampedTime: '21:23',
    note: '教师拖堂',
  ),
  _DormCheckRecord(
    session: '晨查寝',
    status: _DormStatus.normal,
    dorm: '女生宿舍3号楼 612',
    date: '2026-04-01',
    requiredTime: '07:20前',
    stampedTime: '07:18',
    note: '无',
  ),
  _DormCheckRecord(
    session: '晨查寝',
    status: _DormStatus.missed,
    dorm: '女生宿舍3号楼 612',
    date: '2026-04-01',
    requiredTime: '07:20前',
    stampedTime: null,
    note: '无',
  ),
  _DormCheckRecord(
    session: '晚查寝',
    status: _DormStatus.late,
    dorm: '女生宿舍3号楼 612',
    date: '2026-04-01',
    requiredTime: '21:20前',
    stampedTime: '21:23',
    note: '教师拖堂',
  ),
];
