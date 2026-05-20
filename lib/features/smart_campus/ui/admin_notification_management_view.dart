// =============================================================================
// 管理员端「通知管理」独立页面
//
// 入口：admin 首页快捷区「通知管理」按钮 →
//       controller.openNotificationManagement() →
//       mainView == notificationManagement + role == admin → SmartCampusPage
//       路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高，4deg 白→#F9EDFF 渐变，圆角 16）：
//      - 左 12 返回按钮 32×32 白底 outline #F3F2F3。
//      - 居中标题 "通知管理" 16/600 + 副标题 12/#B6B5BB
//        「按类型维护校级通知，支持草稿、定时与即时发布，并配置推送范围
//        （学生 / 教师 / 宿管等）」。
//      - 右 12 「新建通知」按钮（白底 outline #F3F2F3，4 点九宫格 icon
//        + 12/600 黑字）→ 打开右侧 600 抽屉表单。
//   2. 5 张统计卡（100 高，flex 1 1 0，间距 12，196deg 渐变白底，圆角 12）：
//      - 已发布   紫渐变 #E7DCFF→white  显示 published 数量。
//      - 定时中   橙渐变 #FFF0DC→white  显示 scheduled 数量。
//      - 草稿     绿渐变 #DCFFE7→white  显示 draft 数量。
//      - 已撤回   红渐变 #FFE2DC→white  显示 withdrawn 数量。
//      - 全部     红渐变 #FFE2DC→white  显示总数。
//   3. 顶部一行筛选 / 搜索（44 高）：
//      - 左：「全部类型」+「全部状态」两个 120 宽下拉（白底 12 圆角，
//        #0B081A 14/400 + 下三角）。
//      - 右：324 宽搜索框（白底 12 圆角，圆形描边放大镜 +
//        占位「搜索标题、内容、作者」）。
//   4. 970 宽白底 16 圆角表格：12 padding，946×40 #F9FAFB 表头 +
//      多个 60 高数据行（底部 1px #F3F2F3 分隔）：
//      标题（200，title 13/500 + author 11/#6D6B75）/ 类型（flex）/
//      优先级（flex，3 根 2px 竖条信号 + 文字：普通=黑，重要=#325BFF，
//      紧急=#FF323C）/ 范围（120）/ 状态（flex，状态徽标
//      已通过=#E4FFED/#12CE51；草稿=#E6E9F1/#6D6B75；定时中=
//      #FFEDD3/#FF6A00；已撤回=#FFE5E5/#E83A3A）/ 时间（120）/
//      操作（120，已发布=蓝色「查看」；其它=紫色「编辑」+ 红色「删除」）。
//   5. 「新建通知 / 编辑通知」抽屉（右侧 600 宽，全高白底）：
//      - 头部 62 高（紫色竖条 + 16/600 标题 + 关闭按钮）。
//      - 表单（滚动）：标题（输入）/ 内容（多行）/
//        通知类型（PopupSelector：督导/通知/活动/会议/其他）/
//        优先级（信号条 segment：普通/重要/紧急）/
//        推送范围（多选 chip：学生/教师/班主任/宿管/家长/访客）/
//        发布方式（segment：立即发布 / 定时发布 / 保存为草稿；
//        定时发布展开「定时时间」TextField + 日历 picker）。
//      - 底部 48 高紫渐变「提交保存」按钮，按选择的发布方式落库。
//   6. 「查看通知」详情弹窗：用 GradientHeaderDialog，列出全部字段。
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kHairline = Color(0xFFF3F2F3);
const Color _kHeaderBg = Color(0xFFF9FAFB);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextMuted = Color(0xFF71717A);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kBlue = Color(0xFF325BFF);
const Color _kRed = Color(0xFFFF323C);
const Color _kOrange = Color(0xFFFF6A00);

// 状态徽标颜色
const Color _kPassedBg = Color(0xFFE4FFED);
const Color _kPassedFg = Color(0xFF12CE51);
const Color _kDraftBg = Color(0xFFE6E9F1);
const Color _kDraftFg = Color(0xFF6D6B75);
const Color _kPendingBg = Color(0xFFFFEDD3);
const Color _kPendingFg = _kOrange;
const Color _kRejectedBg = Color(0xFFFFE5E5);
const Color _kRejectedFg = Color(0xFFE83A3A);

// =============================================================================
// 数据模型 —— 优先级 / 状态 / 类型
// =============================================================================

enum _NPriority { normal, important, urgent }

extension _NPriorityX on _NPriority {
  String get label => switch (this) {
    _NPriority.normal => '普通',
    _NPriority.important => '重要',
    _NPriority.urgent => '紧急',
  };
  Color get color => switch (this) {
    _NPriority.normal => _kTextDark,
    _NPriority.important => _kBlue,
    _NPriority.urgent => _kRed,
  };

  /// 信号条三段：(active1, active2, active3)
  /// - 普通：仅第 1 段亮
  /// - 重要：第 1、2 段亮
  /// - 紧急：三段全亮
  List<bool> get bars => switch (this) {
    _NPriority.normal => const [true, false, false],
    _NPriority.important => const [true, true, false],
    _NPriority.urgent => const [true, true, true],
  };
}

enum _NStatus { published, scheduled, draft, withdrawn }

extension _NStatusX on _NStatus {
  String get label => switch (this) {
    _NStatus.published => '已通过',
    _NStatus.scheduled => '定时中',
    _NStatus.draft => '草稿',
    _NStatus.withdrawn => '已撤回',
  };

  Color get bg => switch (this) {
    _NStatus.published => _kPassedBg,
    _NStatus.scheduled => _kPendingBg,
    _NStatus.draft => _kDraftBg,
    _NStatus.withdrawn => _kRejectedBg,
  };

  Color get fg => switch (this) {
    _NStatus.published => _kPassedFg,
    _NStatus.scheduled => _kPendingFg,
    _NStatus.draft => _kDraftFg,
    _NStatus.withdrawn => _kRejectedFg,
  };
}

/// 通知类型：与新建抽屉里的下拉一一对应。
const List<String> _kNotificationTypes = <String>[
  '督导',
  '通知',
  '活动',
  '会议',
  '其他',
];

/// 推送范围：抽屉里的多选项；表格里展示拼接后的字符串。
const List<String> _kScopeOptions = <String>[
  '全校师生',
  '学生',
  '教师',
  '班主任',
  '宿管',
  '家长',
  '访客端',
];

/// 类型筛选下拉项 / 状态筛选下拉项的 "全部" 标识。
const String _kAllType = '全部类型';
const String _kAllStatus = '全部状态';

class _NotificationRecord {
  _NotificationRecord({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.type,
    required this.priority,
    required this.scopes,
    required this.status,
    required this.time,
    this.scheduledAt,
  });

  String id;
  String title;
  String content;
  String author;
  String type;
  _NPriority priority;
  List<String> scopes;
  _NStatus status;

  /// 用于显示的时间字符串 `2026-03-24 10:05`。
  ///
  /// 已发布：发布时间；定时中：定时时间；草稿：最后编辑；已撤回：撤回时间。
  String time;

  /// 仅 [_NStatus.scheduled] 时使用：定时发布的时间。
  DateTime? scheduledAt;

  String get scopeLabel =>
      scopes.isEmpty ? '全校师生与访客端' : scopes.join('、');
}

// =============================================================================
// 主视图
// =============================================================================

class AdminNotificationManagementView extends StatefulWidget {
  const AdminNotificationManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminNotificationManagementView> createState() =>
      _AdminNotificationManagementViewState();
}

class _AdminNotificationManagementViewState
    extends State<AdminNotificationManagementView> {
  late final List<_NotificationRecord> _records = _seedRecords();

  String _typeFilter = _kAllType;
  String _statusFilter = _kAllStatus;
  String _query = '';
  late final TextEditingController _searchCtrl = TextEditingController()
    ..addListener(_onSearchChanged);

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final v = _searchCtrl.text;
    if (v == _query) return;
    setState(() => _query = v);
  }

  // —— 筛选 ——————————————————————————————————————————————————————

  List<_NotificationRecord> get _filtered {
    final q = _query.trim().toLowerCase();
    return _records.where((r) {
      if (_typeFilter != _kAllType && r.type != _typeFilter) return false;
      if (_statusFilter != _kAllStatus &&
          _statusFilter != r.status.label) {
        return false;
      }
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.content.toLowerCase().contains(q) ||
          r.author.toLowerCase().contains(q);
    }).toList();
  }

  int _countOf(_NStatus s) => _records.where((r) => r.status == s).length;

  // —— 行操作：查看 / 编辑 / 删除 / 新建 —————————————————————————————

  Future<void> _openCreateDrawer() async {
    final scale = DashboardScaleScope.of(context);
    final result = await showGeneralDialog<_NotificationRecord>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭新建通知',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) => Align(
        alignment: Alignment.centerRight,
        child: DashboardScaleScope(
          data: scale,
          child: _NotificationFormDrawer(
            initial: null,
            onCancel: () => Navigator.of(ctx).pop(),
            onSubmit: (rec) => Navigator.of(ctx).pop(rec),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, sec, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _records.insert(0, result));
    AppToast.show(context, _toastForStatus(result.status, isCreate: true));
  }

  Future<void> _openEditDrawer(_NotificationRecord origin) async {
    final scale = DashboardScaleScope.of(context);
    final result = await showGeneralDialog<_NotificationRecord>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭编辑通知',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) => Align(
        alignment: Alignment.centerRight,
        child: DashboardScaleScope(
          data: scale,
          child: _NotificationFormDrawer(
            initial: origin,
            onCancel: () => Navigator.of(ctx).pop(),
            onSubmit: (rec) => Navigator.of(ctx).pop(rec),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, sec, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final i = _records.indexWhere((r) => r.id == origin.id);
      if (i >= 0) _records[i] = result;
    });
    AppToast.show(context, _toastForStatus(result.status, isCreate: false));
  }

  Future<void> _onDeleteRecord(_NotificationRecord r) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除通知',
      content: '确认删除「${r.title}」？删除后该通知将不再可见，操作不可恢复。',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    setState(() => _records.removeWhere((x) => x.id == r.id));
    AppToast.show(context, '已删除「${r.title}」');
  }

  Future<void> _onViewRecord(_NotificationRecord r) {
    return showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => GradientHeaderDialog(
        title: '通知详情',
        width: 460,
        child: _NotificationDetailBody(record: r),
      ),
    );
  }

  String _toastForStatus(_NStatus s, {required bool isCreate}) {
    final verb = isCreate ? '已新建' : '已更新';
    switch (s) {
      case _NStatus.published:
        return '$verb通知并发布';
      case _NStatus.scheduled:
        return '$verb通知，将按定时时间发送';
      case _NStatus.draft:
        return '$verb通知（草稿）';
      case _NStatus.withdrawn:
        return '$verb通知（已撤回）';
    }
  }

  // —— 渲染 ——————————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = _filtered;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(
              onBack: widget.onBack,
              onCreate: _openCreateDrawer,
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              published: _countOf(_NStatus.published),
              scheduled: _countOf(_NStatus.scheduled),
              draft: _countOf(_NStatus.draft),
              withdrawn: _countOf(_NStatus.withdrawn),
              total: _records.length,
            ),
            SizedBox(height: ui(16)),
            _ControlBar(
              typeValue: _typeFilter,
              statusValue: _statusFilter,
              onTypeChanged: (v) => setState(() => _typeFilter = v),
              onStatusChanged: (v) => setState(() => _statusFilter = v),
              searchCtrl: _searchCtrl,
            ),
            SizedBox(height: ui(12)),
            _NotificationTable(
              records: list,
              onView: _onViewRecord,
              onEdit: _openEditDrawer,
              onDelete: _onDeleteRecord,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// banner —— 返回 + 标题 + 副标题 + 新建通知按钮
// =============================================================================

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack, required this.onCreate});

  final VoidCallback onBack;
  final VoidCallback onCreate;

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
              padding: EdgeInsets.symmetric(horizontal: ui(160)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '通知管理',
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
                    '按类型维护校级通知，支持草稿、定时与即时发布，并配置推送范围（学生 / 教师 / 宿管等）',
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
          Positioned(
            right: ui(12),
            top: ui(14),
            child: _CreateButton(onTap: onCreate),
          ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: ui(14),
              color: const Color(0xFF1C274C),
            ),
            SizedBox(width: ui(4)),
            Text(
              '新建通知',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 5 张统计卡 ——已发布 / 定时中 / 草稿 / 已撤回 / 全部
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.published,
    required this.scheduled,
    required this.draft,
    required this.withdrawn,
    required this.total,
  });

  final int published;
  final int scheduled;
  final int draft;
  final int withdrawn;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '已发布',
            value: published,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFE7DCFF), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.send_rounded,
            iconColor: _kPurple,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '定时中',
            value: scheduled,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFF0DC), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.schedule_rounded,
            iconColor: _kOrange,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '草稿',
            value: draft,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFDCFFE7), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.edit_note_rounded,
            iconColor: _kPassedFg,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '已撤回',
            value: withdrawn,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFE2DC), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.undo_rounded,
            iconColor: _kRed,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '全部',
            value: total,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFE2DC), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.summarize_rounded,
            iconColor: _kRed,
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
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final int value;
  final LinearGradient gradient;
  final IconData icon;
  final Color iconColor;

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
          Padding(
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
          Positioned(
            right: ui(16),
            top: ui(34),
            child: Container(
              width: ui(32),
              height: ui(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: ui(20), color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 筛选 / 搜索条
// =============================================================================

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.typeValue,
    required this.statusValue,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.searchCtrl,
  });

  final String typeValue;
  final String statusValue;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        SizedBox(
          width: ui(140),
          child: PopupSelectorField<String>(
            value: typeValue,
            items: <String>[_kAllType, ..._kNotificationTypes],
            itemLabel: (s) => s,
            onChanged: onTypeChanged,
          ),
        ),
        SizedBox(width: ui(12)),
        SizedBox(
          width: ui(140),
          child: PopupSelectorField<String>(
            value: statusValue,
            items: <String>[
              _kAllStatus,
              for (final s in _NStatus.values) s.label,
            ],
            itemLabel: (s) => s,
            onChanged: onStatusChanged,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: ui(324),
          child: _SearchInput(controller: searchCtrl),
        ),
      ],
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: ui(16),
            color: const Color(0xFFC6C6C6),
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: ui(12)),
                border: InputBorder.none,
                hintText: '搜索标题、内容、作者',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFFD1D1D1),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: () => controller.clear(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(ui(2)),
                child: Icon(
                  Icons.close_rounded,
                  size: ui(14),
                  color: _kTextHint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 表格 —— 表头 + 数据行
// =============================================================================

class _NotificationTable extends StatelessWidget {
  const _NotificationTable({
    required this.records,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_NotificationRecord> records;
  final ValueChanged<_NotificationRecord> onView;
  final ValueChanged<_NotificationRecord> onEdit;
  final ValueChanged<_NotificationRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TableHeader(),
          if (records.isEmpty)
            Container(
              height: ui(120),
              alignment: Alignment.center,
              child: Text(
                '暂无通知',
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            )
          else
            for (final r in records)
              _TableRow(
                record: r,
                onTap: () => onView(r),
                onEdit: () => onEdit(r),
                onDelete: () => onDelete(r),
              ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(10)),
      decoration: BoxDecoration(
        color: _kHeaderBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: const [
          _HeaderCell(width: 200, text: '标题'),
          _HeaderGap(),
          Expanded(child: _HeaderCell(text: '类型')),
          _HeaderGap(),
          Expanded(child: _HeaderCell(text: '优先级')),
          _HeaderGap(),
          _HeaderCell(width: 120, text: '范围'),
          _HeaderGap(),
          Expanded(child: _HeaderCell(text: '状态')),
          _HeaderGap(),
          _HeaderCell(width: 120, text: '时间'),
          _HeaderGap(),
          _HeaderCell(width: 120, text: '操作'),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({this.width, required this.text});

  final double? width;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final child = Text(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextMuted,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 13,
      ),
    );
    if (width == null) return child;
    return SizedBox(width: ui(width!), child: child);
  }
}

class _HeaderGap extends StatelessWidget {
  const _HeaderGap();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(width: ui(12));
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.record,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final _NotificationRecord record;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(60),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kHairline)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: ui(200),
              child: _TitleCell(title: record.title, author: record.author),
            ),
            const _HeaderGap(),
            Expanded(child: _TextCell(text: record.type)),
            const _HeaderGap(),
            Expanded(child: _PriorityCell(priority: record.priority)),
            const _HeaderGap(),
            SizedBox(
              width: ui(120),
              child: _TextCell(text: record.scopeLabel, maxLines: 2),
            ),
            const _HeaderGap(),
            Expanded(child: _StatusCell(status: record.status)),
            const _HeaderGap(),
            SizedBox(width: ui(120), child: _TextCell(text: record.time)),
            const _HeaderGap(),
            SizedBox(
              width: ui(120),
              child: _ActionCell(
                status: record.status,
                onView: onTap,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleCell extends StatelessWidget {
  const _TitleCell({required this.title, required this.author});

  final String title;
  final String author;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 13,
          ),
        ),
        Text(
          author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(11),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 11,
          ),
        ),
      ],
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.text, this.maxLines = 1});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 13,
      ),
    );
  }
}

class _PriorityCell extends StatelessWidget {
  const _PriorityCell({required this.priority});

  final _NPriority priority;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bars = priority.bars;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _signalBar(ui(2), ui(4), bars[0] ? priority.color : _kTextDivider),
        SizedBox(width: ui(2)),
        _signalBar(ui(2), ui(6), bars[1] ? priority.color : _kTextDivider),
        SizedBox(width: ui(2)),
        _signalBar(ui(2), ui(8), bars[2] ? priority.color : _kTextDivider),
        SizedBox(width: ui(4)),
        Flexible(
          child: Text(
            priority.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(13),
              color: priority.color,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _signalBar(double w, double h, Color c) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status});

  final _NStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.status,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final _NStatus status;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 已发布 / 已撤回：仅展示「查看」；其余（草稿、定时中）允许「编辑/删除」。
    final isReadonly =
        status == _NStatus.published || status == _NStatus.withdrawn;
    if (isReadonly) {
      return Row(
        children: [
          _actionText(
            text: '查看',
            color: _kBlue,
            onTap: onView,
            ui: ui,
          ),
        ],
      );
    }
    return Row(
      children: [
        _actionText(
          text: '编辑',
          color: _kPurple,
          onTap: onEdit,
          ui: ui,
        ),
        SizedBox(width: ui(12)),
        _actionText(
          text: '删除',
          color: _kRed,
          onTap: onDelete,
          ui: ui,
        ),
      ],
    );
  }

  Widget _actionText({
    required String text,
    required Color color,
    required VoidCallback onTap,
    required double Function(num) ui,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(13),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 13,
        ),
      ),
    );
  }
}

// =============================================================================
// 通知详情弹窗
// =============================================================================

class _NotificationDetailBody extends StatelessWidget {
  const _NotificationDetailBody({required this.record});

  final _NotificationRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          record.title,
          style: TextStyle(
            fontSize: ui(15),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.5,
          ),
        ),
        SizedBox(height: ui(8)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(6),
                vertical: ui(2),
              ),
              decoration: BoxDecoration(
                color: record.status.bg,
                borderRadius: BorderRadius.circular(ui(4)),
              ),
              child: Text(
                record.status.label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: record.status.fg,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: ui(8)),
            Text(
              record.author,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
        SizedBox(height: ui(16)),
        _DetailRow(label: '类型', value: record.type),
        _DetailRow(
          label: '优先级',
          value: record.priority.label,
          valueColor: record.priority.color,
        ),
        _DetailRow(label: '推送范围', value: record.scopeLabel),
        _DetailRow(label: '时间', value: record.time, isLast: true),
        SizedBox(height: ui(12)),
        Text(
          '内容',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(6)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kInnerGray,
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Text(
            record.content.isEmpty ? '（暂无正文）' : record.content,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 22 / 13,
            ),
          ),
        ),
        SizedBox(height: ui(8)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(10)),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kHairline)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(72),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ui(13),
                color: valueColor ?? _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 新建 / 编辑通知 抽屉
// =============================================================================

/// 当 [initial] 不为 null 时为「编辑」模式；否则为「新建」。
class _NotificationFormDrawer extends StatefulWidget {
  const _NotificationFormDrawer({
    required this.initial,
    required this.onCancel,
    required this.onSubmit,
  });

  final _NotificationRecord? initial;
  final VoidCallback onCancel;
  final ValueChanged<_NotificationRecord> onSubmit;

  @override
  State<_NotificationFormDrawer> createState() =>
      _NotificationFormDrawerState();
}

enum _PublishMode { now, scheduled, draft }

extension _PublishModeX on _PublishMode {
  String get label => switch (this) {
    _PublishMode.now => '立即发布',
    _PublishMode.scheduled => '定时发布',
    _PublishMode.draft => '保存为草稿',
  };
}

class _NotificationFormDrawerState extends State<_NotificationFormDrawer> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _type;
  late _NPriority _priority;
  late Set<String> _scopes;
  late _PublishMode _mode;
  DateTime? _scheduledAt;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _contentCtrl = TextEditingController(text: init?.content ?? '');
    _type = init?.type ?? _kNotificationTypes.first;
    _priority = init?.priority ?? _NPriority.normal;
    _scopes = {...?init?.scopes};
    if (_scopes.isEmpty) _scopes.add('全校师生');
    _scheduledAt = init?.scheduledAt;
    _mode = switch (init?.status) {
      _NStatus.scheduled => _PublishMode.scheduled,
      _NStatus.draft => _PublishMode.draft,
      _NStatus.published => _PublishMode.now,
      _NStatus.withdrawn => _PublishMode.draft,
      null => _PublishMode.now,
    };
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // —— 选定时时间 —————————————————————————————————————————————————

  Future<void> _pickScheduledAt() async {
    final now = DateTime.now();
    final base = _scheduledAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '选择发布日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: appPickerDialogTheme,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: '选择发布时间',
      cancelText: '取消',
      confirmText: '确定',
      builder: appPickerDialogTheme,
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // —— 表单校验 + 提交 ——————————————————————————————————————————

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '请填写通知标题');
      return;
    }
    if (content.isEmpty) {
      AppToast.show(context, '请填写通知内容');
      return;
    }
    if (_scopes.isEmpty) {
      AppToast.show(context, '请至少勾选一个推送范围');
      return;
    }
    if (_mode == _PublishMode.scheduled) {
      if (_scheduledAt == null) {
        AppToast.show(context, '请选择定时发布时间');
        return;
      }
      if (_scheduledAt!.isBefore(DateTime.now())) {
        AppToast.show(context, '定时时间需晚于当前时间');
        return;
      }
    }

    setState(() => _submitting = true);
    // 当前后端「通知保存」接口尚未提供，先在本地组装记录返回给上层 setState。
    // 接入时改为调用 repo.notificationSave({...}) 并以返回的 id 替换。
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final origin = widget.initial;
    final status = switch (_mode) {
      _PublishMode.now => _NStatus.published,
      _PublishMode.scheduled => _NStatus.scheduled,
      _PublishMode.draft => _NStatus.draft,
    };
    final time = switch (_mode) {
      _PublishMode.now => _formatNow(),
      _PublishMode.scheduled => _formatDateTime(_scheduledAt!),
      _PublishMode.draft => _formatNow(),
    };
    final rec = _NotificationRecord(
      id: origin?.id ??
          'n${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      title: title,
      content: content,
      author: origin?.author ?? '校办 · 我',
      type: _type,
      priority: _priority,
      scopes: _scopes.toList(),
      status: status,
      time: time,
      scheduledAt: _mode == _PublishMode.scheduled ? _scheduledAt : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    widget.onSubmit(rec);
  }

  String _submitLabel() {
    if (_submitting) return '提交中…';
    return switch (_mode) {
      _PublishMode.now => '立即发布',
      _PublishMode.scheduled => '保存并定时',
      _PublishMode.draft => '保存为草稿',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEdit = widget.initial != null;
    // 外层 [Material]：showGeneralDialog 走 root overlay，其内部并没有 Material
    // 祖先；抽屉里大量使用 [InkWell] / [TextField] 都依赖 Material（splash + 默认
    // 文本主题），少了它会直接抛 "No Material widget found" 异常。
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: ui(600),
        height: double.infinity,
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              _DrawerHeader(
                title: isEdit ? '编辑通知' : '新建通知',
                onClose: widget.onCancel,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(ui(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const _SectionLabel(label: '通知标题', required: true),
                    SizedBox(height: ui(8)),
                    _TextField(
                      controller: _titleCtrl,
                      hint: '请输入通知标题（建议 ≤ 30 字）',
                      maxLength: 60,
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(label: '通知内容', required: true),
                    SizedBox(height: ui(8)),
                    _TextField(
                      controller: _contentCtrl,
                      hint: '请输入正文，可包含时间、地点、参加人员等关键信息',
                      maxLines: 5,
                      maxLength: 500,
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(label: '通知类型'),
                    SizedBox(height: ui(8)),
                    PopupSelectorField<String>(
                      value: _type,
                      items: _kNotificationTypes,
                      itemLabel: (s) => s,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(label: '优先级'),
                    SizedBox(height: ui(8)),
                    _PrioritySegment(
                      value: _priority,
                      onChanged: (v) => setState(() => _priority = v),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(label: '推送范围', required: true),
                    SizedBox(height: ui(8)),
                    _ScopeChips(
                      selected: _scopes,
                      onToggle: (s) => setState(() {
                        if (_scopes.contains(s)) {
                          _scopes.remove(s);
                        } else {
                          _scopes.add(s);
                        }
                      }),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(label: '发布方式'),
                    SizedBox(height: ui(8)),
                    _PublishModeSegment(
                      value: _mode,
                      onChanged: (v) => setState(() => _mode = v),
                    ),
                    if (_mode == _PublishMode.scheduled) ...[
                      SizedBox(height: ui(12)),
                      _ScheduledPickerField(
                        value: _scheduledAt,
                        onTap: _pickScheduledAt,
                      ),
                    ],
                    SizedBox(height: ui(8)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
              child: Row(
                children: [
                  Expanded(
                    child: _SecondaryButton(
                      label: '取消',
                      onTap: _submitting ? null : widget.onCancel,
                    ),
                  ),
                  SizedBox(width: ui(12)),
                  Expanded(
                    flex: 2,
                    child: _PrimaryButton(
                      label: _submitLabel(),
                      onTap: _submitting ? null : _onSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// —— 抽屉内表单子组件 —————————————————————————————————————————————

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.onClose});

  final String title;
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
          SizedBox(width: ui(8)),
          Text(
            title,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        if (required)
          Padding(
            padding: EdgeInsets.only(right: ui(2)),
            child: Text(
              '*',
              style: TextStyle(
                fontSize: ui(14),
                color: _kRed,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(10)),
        border: Border.all(color: _kInnerGray, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 22 / 14,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          counterText: '',
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 22 / 14,
          ),
        ),
      ),
    );
  }
}

class _PrioritySegment extends StatelessWidget {
  const _PrioritySegment({required this.value, required this.onChanged});

  final _NPriority value;
  final ValueChanged<_NPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (final p in _NPriority.values) ...[
          Expanded(
            child: InkWell(
              onTap: () => onChanged(p),
              borderRadius: BorderRadius.circular(ui(10)),
              child: Container(
                height: ui(44),
                decoration: BoxDecoration(
                  color: value == p
                      ? p.color.withValues(alpha: 0.10)
                      : _kInnerGray,
                  borderRadius: BorderRadius.circular(ui(10)),
                  border: value == p
                      ? Border.all(color: p.color, width: 1)
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bar(ui(2), ui(4),
                        p.bars[0] ? p.color : _kTextDivider),
                    SizedBox(width: ui(2)),
                    _bar(ui(2), ui(6),
                        p.bars[1] ? p.color : _kTextDivider),
                    SizedBox(width: ui(2)),
                    _bar(ui(2), ui(8),
                        p.bars[2] ? p.color : _kTextDivider),
                    SizedBox(width: ui(6)),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: ui(13),
                        color: value == p ? p.color : _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (p != _NPriority.values.last) SizedBox(width: ui(8)),
        ],
      ],
    );
  }

  Widget _bar(double w, double h, Color c) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      spacing: ui(8),
      runSpacing: ui(8),
      children: [
        for (final s in _kScopeOptions)
          InkWell(
            onTap: () => onToggle(s),
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(14),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: selected.contains(s)
                    ? _kPurple.withValues(alpha: 0.10)
                    : _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
                border: selected.contains(s)
                    ? Border.all(color: _kPurple, width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected.contains(s))
                    Padding(
                      padding: EdgeInsets.only(right: ui(4)),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: ui(14),
                        color: _kPurple,
                      ),
                    ),
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: selected.contains(s)
                          ? _kPurple
                          : _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: selected.contains(s)
                          ? AppFont.w600
                          : AppFont.w400,
                      height: 1.2,
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

class _PublishModeSegment extends StatelessWidget {
  const _PublishModeSegment({required this.value, required this.onChanged});

  final _PublishMode value;
  final ValueChanged<_PublishMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (final m in _PublishMode.values) ...[
          Expanded(
            child: InkWell(
              onTap: () => onChanged(m),
              borderRadius: BorderRadius.circular(ui(10)),
              child: Container(
                height: ui(44),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == m
                      ? _kPurple.withValues(alpha: 0.10)
                      : _kInnerGray,
                  borderRadius: BorderRadius.circular(ui(10)),
                  border: value == m
                      ? Border.all(color: _kPurple, width: 1)
                      : null,
                ),
                child: Text(
                  m.label,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: value == m ? _kPurple : _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight:
                        value == m ? AppFont.w600 : AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (m != _PublishMode.values.last) SizedBox(width: ui(8)),
        ],
      ],
    );
  }
}

class _ScheduledPickerField extends StatelessWidget {
  const _ScheduledPickerField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(10)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: _kInnerGray, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              size: ui(16),
              color: _kPurple,
            ),
            SizedBox(width: ui(8)),
            Expanded(
              child: Text(
                hasValue ? _formatDateTime(value!) : '请选择定时发布时间',
                style: TextStyle(
                  fontSize: ui(14),
                  color: hasValue ? _kTextDark : _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 22 / 14,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: ui(18),
              color: _kTextHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(15),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(15),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 时间格式化工具 + 演示种子数据
// =============================================================================

String _formatNow() => _formatDateTime(DateTime.now());

String _formatDateTime(DateTime d) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${pad(d.month)}-${pad(d.day)} '
      '${pad(d.hour)}:${pad(d.minute)}';
}

List<_NotificationRecord> _seedRecords() {
  return <_NotificationRecord>[
    _NotificationRecord(
      id: 'n001',
      title: '区教育局：艺考季校园安全与心理健康专项督导，材料请于周四前上传。',
      content:
          '请各班主任收集本班住宿生晨检记录、心理动态评估表，于周四 18:00 前上传到 OA 系统对应专项目录。'
          '督导组将于下周一开始抽查访谈。',
      author: '校办 · 王婧',
      type: '督导',
      priority: _NPriority.important,
      scopes: const ['全校师生', '访客端'],
      status: _NStatus.published,
      time: '2026-03-24 10:05',
    ),
    _NotificationRecord(
      id: 'n002',
      title: '4 月美育月闭幕展演彩排排练计划',
      content:
          '4/26 16:00 在大礼堂集中彩排，请各社团节目组提前 30 分钟进场对光对音；'
          '具体顺序见附件。',
      author: '艺术中心 · 刘老师',
      type: '通知',
      priority: _NPriority.normal,
      scopes: const ['学生', '教师'],
      status: _NStatus.draft,
      time: '2026-03-24 09:48',
    ),
    _NotificationRecord(
      id: 'n003',
      title: '高三模拟考考务培训会',
      content: '4/2 19:00 在三楼会议室召开，所有监考与巡考教师必须到场。',
      author: '教务处 · 张主任',
      type: '会议',
      priority: _NPriority.urgent,
      scopes: const ['教师', '班主任'],
      status: _NStatus.draft,
      time: '2026-03-23 17:30',
    ),
    _NotificationRecord(
      id: 'n004',
      title: '清明假期校园安全提示',
      content: '4/4 - 4/6 放假。住宿生须按时返校，请家长配合做好行程报备与体温监测。',
      author: '安保处 · 李主任',
      type: '通知',
      priority: _NPriority.urgent,
      scopes: const ['全校师生', '家长'],
      status: _NStatus.scheduled,
      time: '2026-04-03 18:00',
      scheduledAt: DateTime(2026, 4, 3, 18, 0),
    ),
    _NotificationRecord(
      id: 'n005',
      title: '春季运动会赛前注意事项',
      content: '请各班体育委员组织参赛同学在 4/15 前完成体检表上传。',
      author: '体育组 · 钱老师',
      type: '活动',
      priority: _NPriority.normal,
      scopes: const ['学生', '班主任'],
      status: _NStatus.scheduled,
      time: '2026-04-12 09:00',
      scheduledAt: DateTime(2026, 4, 12, 9, 0),
    ),
    _NotificationRecord(
      id: 'n006',
      title: '原定的家校开放日因天气原因撤回',
      content: '由于雷雨黄色预警，原定于 4/2 的家校开放日撤回，后续另行通知。',
      author: '校办 · 王婧',
      type: '通知',
      priority: _NPriority.normal,
      scopes: const ['全校师生', '家长'],
      status: _NStatus.withdrawn,
      time: '2026-03-31 16:20',
    ),
    _NotificationRecord(
      id: 'n007',
      title: '学生宿舍 3 号楼供水管道维护',
      content: '4/8 上午 9:00-12:00 暂停供水，请提前接好饮用水。',
      author: '后勤处 · 周师傅',
      type: '其他',
      priority: _NPriority.urgent,
      scopes: const ['学生', '宿管'],
      status: _NStatus.draft,
      time: '2026-03-30 11:12',
    ),
  ];
}
