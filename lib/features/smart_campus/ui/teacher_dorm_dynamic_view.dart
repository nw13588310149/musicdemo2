// =============================================================================
// 班主任端「查寝动态」独立页面
//
// 入口：班主任 dashboard 快捷区「查寝动态」按钮 → controller.openDormDynamic()
//      → mainView == dormDynamic + role == headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高, 4deg #F9EDFF→white 渐变, 圆角 16, 顶部居中"查寝动态"
//      16/600 + 副标题 12/#B6B5BB 说明本页不提供打卡入口；左 12 返回 32×32
//      白底 outline #F3F2F3）。
//   2. 提示文字 12/#B6B5BB「默认由家长在小程序审批后再由班主任审批；……
//      补课协调以教务安排为准。」
//   3. 4 张统计卡（100 高 + 各自 196deg 渐变 + 右下 54×54 装饰渐变方块 +
//      右上 32×32 白底图标）：
//      A. 「住宿生」橙渐变 rgba(255,168,70,.16)→0 + 绿色 home icon
//      B. 「今晚已归寝口径」绿渐变 rgba(70,255,119,.09)→0 + 同图标
//      C. 「异常（未打/晚归）」红渐变 rgba(255,70,70,.09)→0 + 紫色 alert
//      D. 「补卡待审」紫渐变 rgba(147,70,255,.14)→0 + "需协同审核" 12 副标题
//   4. Tabs row（44 高）：白底圆角 8 + 2 个 pill：本班查纪 / 补卡审核
//      （后者带 22×15 #F04545 红底徽章 "10+"）；右侧搜索框 324×44。
//   5. Sub-toolbar：「全部异常记录 N 条」(N 紫色) + 全部 / 异常 toggle。
//   6. 卡片网格 3 列（每张 312×width，padding 12，背景 207deg #FAF0FF→
//      white 渐变，圆角 16，gap 16）：
//      · 学生口径卡：头像 40 + 姓名 14/500 + 学号 12/#B6B5BB + "查寝"
//        12/#6D6B75 + 状态徽章 16 高（正常 #DAD2FF/#8741FF / 未打卡
//        #FEE4E8/#FF323C / 迟到 #DBE2FF/#325BFF）；下行 宿舍 12 + 日期；
//        灰底块 #F5F6FA H50 居中两列：规定时间 / 打卡时间；底部 备注。
//      · 宿舍口径卡：晨查寝 / 晚查寝 18 Barlow/600 标题 + 大色块状态徽章
//        正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF 全为白字；下行
//        宿舍 13/#6D6B75 + 日期；灰底块同；底部 备注。
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
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
const Color _kTextPlaceholder = Color(0xFFD1D1D1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFEE4E8);
const Color _kBlue = Color(0xFF325BFF);
const Color _kGreen = Color(0xFF1CD097);
const Color _kBadgeRed = Color(0xFFF04545);

// —— 顶部 tab 枚举 ——————————————————————————————————————————————
enum _TopTab {
  classRoster('本班查纪'),
  punchAudit('补卡审核');

  const _TopTab(this.label);
  final String label;
}

// —— 全部 / 异常 toggle ————————————————————————————————————————————
enum _FilterTab {
  all('全部'),
  exception('异常');

  const _FilterTab(this.label);
  final String label;
}

// —— 学生口径状态 ——————————————————————————————————————————————————
// Figma 学生口径卡只出现 "正常 / 未打卡" 两种；如需扩展（如"迟到"），
// 可参考 _DormStatus 加入蓝底 _kBlue 配色。
enum _StudentStatus {
  normal('正常', _kPurpleSoftBg, _kPurple),
  absent('未打卡', _kRedSoftBg, _kRed);

  const _StudentStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  bool get isException => this != _StudentStatus.normal;
}

// —— 宿舍口径状态（实色徽章）—————————————————————————————————————
enum _DormStatus {
  normal('正常', Color(0xFFA773FF)),
  absent('未打卡', _kRed),
  late_('迟到', _kBlue);

  const _DormStatus(this.label, this.solidBg);
  final String label;
  final Color solidBg;

  bool get isException => this != _DormStatus.normal;
}

// —— 补卡审核状态 —————————————————————————————————————————————
// 待审核 / 已通过 / 已驳回；徽章为柔和底 + 实色字。
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);
const Color _kGreenAudit = Color(0xFF12CE51);
const Color _kGreenAuditSoftBg = Color(0xFFE4FFED);

enum _PunchAuditStatus {
  pending('待审核', _kOrangeSoftBg, _kOrange),
  approved('已通过', _kGreenAuditSoftBg, _kGreenAudit),
  rejected('已驳回', Color(0xFFFFE4E5), _kRed);

  const _PunchAuditStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

// —— 数据模型 ——————————————————————————————————————————————————
class _StudentRecord {
  const _StudentRecord({
    required this.studentName,
    required this.studentNo,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final String studentName;
  final String studentNo;
  final _StudentStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;
}

class _DormRecord {
  const _DormRecord({
    required this.title,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final String title;
  final _DormStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;
}

class _PunchAuditRecord {
  const _PunchAuditRecord({
    required this.studentName,
    required this.studentNo,
    required this.dormName,
    required this.date,
    required this.reason,
    required this.status,
  });

  final String studentName;
  final String studentNo;
  final String dormName;
  final String date;
  final String reason;
  final _PunchAuditStatus status;
}

// —— 顶级视图 ——————————————————————————————————————————————————

class TeacherDormDynamicView extends StatefulWidget {
  const TeacherDormDynamicView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TeacherDormDynamicView> createState() => _TeacherDormDynamicViewState();
}

class _TeacherDormDynamicViewState extends State<TeacherDormDynamicView> {
  _TopTab _topTab = _TopTab.classRoster;
  _FilterTab _filterTab = _FilterTab.all;
  late final List<_StudentRecord> _students;
  late final List<_DormRecord> _dormRecords;
  // 补卡审核列表：使用可变 list，支持点击"通过/驳回"后实时更新状态。
  late List<_PunchAuditRecord> _punchAudits;

  @override
  void initState() {
    super.initState();
    _students = _demoStudents();
    _dormRecords = _demoDormRecords();
    _punchAudits = _demoPunchAudits();
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
            const _StatsRow(
              residentCount: 12,
              returnedCount: 10,
              exceptionCount: 2,
              auditCount: 1,
            ),
            SizedBox(height: ui(16)),
            _TabsRow(
              current: _topTab,
              pendingPunchCount: _pendingPunchCount(),
              onTap: (t) => setState(() => _topTab = t),
            ),
            SizedBox(height: ui(16)),
            // 「本班查纪」展示 全部 / 异常 toggle + 学生口径 / 宿舍口径卡片网格；
            // 「补卡审核」直接展示补卡申请卡片网格（无 toggle）。
            if (_topTab == _TopTab.classRoster) ...[
              _FilterToolbar(
                total: _exceptionTotal(),
                current: _filterTab,
                onTap: (t) => setState(() => _filterTab = t),
              ),
              SizedBox(height: ui(12)),
              _CardsGrid(
                students: _filteredStudents(),
                dormRecords: _filteredDormRecords(),
              ),
            ] else ...[
              _PunchAuditGrid(
                records: _punchAudits,
                onApprove: _onApprovePunchAudit,
                onReject: _onRejectPunchAudit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _exceptionTotal() {
    final s = _students.where((r) => r.status.isException).length;
    final d = _dormRecords.where((r) => r.status.isException).length;
    return s + d;
  }

  int _pendingPunchCount() =>
      _punchAudits.where((r) => r.status == _PunchAuditStatus.pending).length;

  List<_StudentRecord> _filteredStudents() {
    if (_filterTab == _FilterTab.exception) {
      return _students.where((r) => r.status.isException).toList();
    }
    return _students;
  }

  List<_DormRecord> _filteredDormRecords() {
    if (_filterTab == _FilterTab.exception) {
      return _dormRecords.where((r) => r.status.isException).toList();
    }
    return _dormRecords;
  }

  void _onApprovePunchAudit(_PunchAuditRecord record) {
    setState(() {
      final idx = _punchAudits.indexOf(record);
      if (idx >= 0) {
        _punchAudits[idx] = _PunchAuditRecord(
          studentName: record.studentName,
          studentNo: record.studentNo,
          dormName: record.dormName,
          date: record.date,
          reason: record.reason,
          status: _PunchAuditStatus.approved,
        );
      }
    });
    AppToast.show(context, '已通过 ${record.studentName} 的补卡申请（演示）');
  }

  void _onRejectPunchAudit(_PunchAuditRecord record) {
    setState(() {
      final idx = _punchAudits.indexOf(record);
      if (idx >= 0) {
        _punchAudits[idx] = _PunchAuditRecord(
          studentName: record.studentName,
          studentNo: record.studentNo,
          dormName: record.dormName,
          date: record.date,
          reason: record.reason,
          status: _PunchAuditStatus.rejected,
        );
      }
    });
    AppToast.show(context, '已驳回 ${record.studentName} 的补卡申请（演示）');
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
                    '查寝动态',
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
                    '掌握本班住宿生归宿与晨检结果，协同处理补卡与异常跟进。现场刷脸/签到由查寝老师/宿管在专用端执行——本页不提供打卡入口。',
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
    required this.residentCount,
    required this.returnedCount,
    required this.exceptionCount,
    required this.auditCount,
  });

  final int residentCount;
  final int returnedCount;
  final int exceptionCount;
  final int auditCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '住宿生',
            value: residentCount,
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
            label: '今晚已归寝口径',
            value: returnedCount,
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
            label: '异常（未打/晚归）',
            value: exceptionCount,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x17FF4646), Color(0x00FFFFFF)],
            ),
            iconColor: _kPurple,
            iconKind: _StatIconKind.alert,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '补卡待审',
            value: auditCount,
            subtitle: '需协同审核',
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
    this.subtitle,
  });

  final String label;
  final int value;
  final LinearGradient gradient;
  final Color iconColor;
  final _StatIconKind iconKind;
  final String? subtitle;

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
                if (subtitle != null) ...[
                  SizedBox(height: ui(5)),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.0,
                    ),
                  ),
                ],
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

// —— Tabs row + 搜索框 ——————————————————————————————————————————————

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.current,
    required this.pendingPunchCount,
    required this.onTap,
  });

  final _TopTab current;
  final int pendingPunchCount;
  final ValueChanged<_TopTab> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 注意：tabs 容器和搜索框都不再写死 height，让其根据子 pill 的 padding
    // 自然撑高。中文（PingFang SC）在 line-height: 1.0 + 固定 44/32 高度
    // 容器内会出现 baseline 被裁、字体看上去"被压扁"的视觉错觉，因此采用
    // 内容驱动高度 + 较宽的 line-height(1.2) 的策略。
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _TopTab.values.length; i++) ...[
                if (i != 0) SizedBox(width: ui(16)),
                _TabPill(
                  tab: _TopTab.values[i],
                  active: _TopTab.values[i] == current,
                  pendingPunchCount: pendingPunchCount,
                  onTap: () => onTap(_TopTab.values[i]),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: ui(324),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(12)),
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
                    height: 1.2,
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
    required this.tab,
    required this.active,
    required this.pendingPunchCount,
    required this.onTap,
  });

  final _TopTab tab;
  final bool active;
  final int pendingPunchCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontSize: ui(14),
                color: active ? Colors.white : _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
            if (tab == _TopTab.punchAudit && pendingPunchCount > 0) ...[
              SizedBox(width: ui(4)),
              _RedBadge(
                text: pendingPunchCount > 9 ? '10+' : '$pendingPunchCount',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RedBadge extends StatelessWidget {
  const _RedBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(22),
      height: ui(15),
      decoration: BoxDecoration(
        color: _kBadgeRed,
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(10),
          color: Colors.white,
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

// —— 全部异常记录 + 全部 / 异常 toggle ————————————————————————————————

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.total,
    required this.current,
    required this.onTap,
  });

  final int total;
  final _FilterTab current;
  final ValueChanged<_FilterTab> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
              children: [
                const TextSpan(text: '全部异常记录 '),
                TextSpan(
                  text: '$total',
                  style: const TextStyle(color: _kPurple),
                ),
                const TextSpan(text: ' 条'),
              ],
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        for (var i = 0; i < _FilterTab.values.length; i++) ...[
          if (i != 0) SizedBox(width: ui(12)),
          _FilterPill(
            tab: _FilterTab.values[i],
            active: _FilterTab.values[i] == current,
            onTap: () => onTap(_FilterTab.values[i]),
          ),
        ],
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _FilterTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(7)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Text(
          tab.label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// —— 卡片网格 ——————————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({required this.students, required this.dormRecords});

  final List<_StudentRecord> students;
  final List<_DormRecord> dormRecords;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasContent = students.isNotEmpty || dormRecords.isNotEmpty;
    if (!hasContent) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            '暂无相关记录',
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
        // Figma 设计 970 宽下 3 列 312；自适应：cw 不足时降到 2 / 1 列。
        var columns = 3;
        if (w < ui(720)) columns = 2;
        if (w < ui(480)) columns = 1;
        final cardWidth = (w - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in students)
              SizedBox(
                width: cardWidth,
                child: _StudentCard(record: r),
              ),
            for (final r in dormRecords)
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

// —— 卡片背景（共用）—————————————————————————————————————————————

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFAF0FF), Colors.white],
  ),
  borderRadius: BorderRadius.circular(radius),
);

// —— 学生口径卡 ——————————————————————————————————————————————————

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.record});

  final _StudentRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: _cardDecoration(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 姓名 / 学号 + 状态徽章；姓名行下方 宿舍 + 日期。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
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
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        Text(
                          '查寝',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.0,
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
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        Text(
                          record.date,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.0,
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
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// 学生口径状态徽章（柔和底）
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
      alignment: Alignment.center,
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

// —— 宿舍口径卡 ——————————————————————————————————————————————————

class _DormCard extends StatelessWidget {
  const _DormCard({required this.record});

  final _DormRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: _cardDecoration(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: ui(8)),
              Text(
                record.date,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.0,
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
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// 宿舍口径状态徽章（实色 + 白字）
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
      alignment: Alignment.center,
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

// —— 灰底时间块（规定时间 / 打卡时间 居中两列）—————————————————————

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.requiredTime, required this.punchTime});

  final String requiredTime;
  final String punchTime;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 注意：不再写死 height，让两行文字 + padding + 中间 5px 自然撑高
    // （PingFang SC 在 height: 1.0 时实际渲染高度仍可能 >12px，固定 50 会
    //  在不同字体回退情况下溢出 9px 左右）。
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(11), horizontal: ui(12)),
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
        SizedBox(height: ui(4)),
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

// —— 补卡审核卡片网格 ————————————————————————————————————————————

class _PunchAuditGrid extends StatelessWidget {
  const _PunchAuditGrid({
    required this.records,
    required this.onApprove,
    required this.onReject,
  });

  final List<_PunchAuditRecord> records;
  final ValueChanged<_PunchAuditRecord> onApprove;
  final ValueChanged<_PunchAuditRecord> onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            '暂无补卡申请',
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
        var columns = 3;
        if (w < ui(720)) columns = 2;
        if (w < ui(480)) columns = 1;
        final cardWidth = (w - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardWidth,
                child: _PunchAuditCard(
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

class _PunchAuditCard extends StatelessWidget {
  const _PunchAuditCard({
    required this.record,
    required this.onApprove,
    required this.onReject,
  });

  final _PunchAuditRecord record;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPending = record.status == _PunchAuditStatus.pending;

    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: _cardDecoration(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 姓名/学号 + 状态徽章；下行 宿舍 + 日期。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
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
                                    height: 1.2,
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
                        ),
                        SizedBox(width: ui(8)),
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
                        _PunchAuditStatusBadge(status: record.status),
                      ],
                    ),
                    SizedBox(height: ui(6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.dormName,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: ui(8)),
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
          SizedBox(height: ui(10)),
          // 说明：xxxx —— 起头"说明："为灰色 hint，正文为深色。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '说明：',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.6,
                ),
              ),
              Expanded(
                child: Text(
                  record.reason,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(10)),
          // 仅"待审核"显示通过/驳回；已通过/已驳回时按钮自动隐藏。
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: _PunchActionButton(
                    label: '通过',
                    isPrimary: true,
                    onTap: onApprove,
                  ),
                ),
                SizedBox(width: ui(12)),
                Expanded(
                  child: _PunchActionButton(
                    label: '驳回',
                    isPrimary: false,
                    onTap: onReject,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// 补卡审核状态徽章（柔和底 + 实色字）
class _PunchAuditStatusBadge extends StatelessWidget {
  const _PunchAuditStatusBadge({required this.status});

  final _PunchAuditStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      alignment: Alignment.center,
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

// 通过/驳回按钮：通过为紫渐变实底白字，驳回为白底深色字 + 浅边框。
class _PunchActionButton extends StatelessWidget {
  const _PunchActionButton({
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
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: isPrimary ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// —— Demo 数据 ——————————————————————————————————————————————————

List<_PunchAuditRecord> _demoPunchAudits() => const [
  _PunchAuditRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    reason: '当晚在艺术楼排练至22:40，手机没电未能扫脸，回寝后已找宿管登记。',
    status: _PunchAuditStatus.pending,
  ),
  _PunchAuditRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    reason: '当晚在艺术楼排练至22:40，手机没电未能扫脸，回寝后已找宿管登记。',
    status: _PunchAuditStatus.pending,
  ),
  _PunchAuditRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    reason: '当晚在艺术楼排练至22:40，手机没电未能扫脸，回寝后已找宿管登记。',
    status: _PunchAuditStatus.pending,
  ),
];

List<_StudentRecord> _demoStudents() => const [
  _StudentRecord(
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

List<_DormRecord> _demoDormRecords() => const [
  _DormRecord(
    title: '晨查寝',
    status: _DormStatus.normal,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _DormRecord(
    title: '晨查寝',
    status: _DormStatus.absent,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _DormRecord(
    title: '晚查寝',
    status: _DormStatus.late_,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '21:20前',
    punchTime: '21:23',
    note: '教师拖堂',
  ),
];
