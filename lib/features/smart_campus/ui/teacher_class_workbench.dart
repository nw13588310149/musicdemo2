// =============================================================================
// 班主任端「班级工作台」独立页面
//
// 入口：班主任 dashboard 顶部「班级工作台」按钮 / 「班务 → 班级工作台 >」。
// 三个 Tab：
//   1. 概况   _OverviewTab   顶部「班级通知」(与学生「我的班级」共享 provider，
//      可发布/删除) + 双列布局：我的班级 + 待批请假 / 班级捷径 / 本周出勤 +
//      重点关注 / 今日节点 + 近期班务
//   2. 学生管理 _StudentsTab  标题副标题 + 搜索框 + 学生卡 3 列网格
//   3. 成绩   _GradesTab     班级成绩变化折线图 + 考试记录（分数+点评） + 学生分数变化卡
//
// 视觉：970 设计宽度自适应到容器宽度，左列约 0.5918，右列约 0.3959，gap 12。
// 颜色：白卡 #FFFFFF / 浅灰底 #F5F6FA / 紫色主色 #8741FF / 蓝色 #325BFF / 红色 #FF323C
// 字体：PingFang SC（标题 18 / 正文 12~14）+ Barlow（数字 20~24）
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/teacher_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPanelBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextHintLight = Color(0xFFD1D1D1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoft = Color(0xFFA773FF);
const Color _kBlue = Color(0xFF325BFF);
const Color _kRed = Color(0xFFFF323C);
const Color _kYellow = Color(0xFFDBEE49);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kAnnounceBg = Color(0xFFF0E8FC);

// ---- 班级通知数据模型（来自 API）----------------------------------------

class _NoticeItem {
  const _NoticeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  final String id;
  final String title;
  final String content;
  final String date;

  factory _NoticeItem.fromMap(Map<dynamic, dynamic> m) {
    final raw = m['createTime']?.toString() ?? '';
    final date = raw.length >= 10 ? raw.substring(5, 10) : raw;
    return _NoticeItem(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      date: date,
    );
  }
}

// ---- 学生管理数据模型（来自 API）-----------------------------------------

class _StudentManageData {
  const _StudentManageData({
    required this.id,
    required this.name,
    required this.studentId,
    required this.dorm,
    required this.phone,
    required this.parentName,
    required this.parentPhone,
    required this.gender,
    this.role,
    this.remark,
    this.tags,
    this.tag,
    this.tagColor,
    this.tagTextColor,
    this.avatarUrl,
  });

  /// 后端数值 id，用于调用 studentDetail / studentUpdate 接口。
  final int id;
  final String name;
  final String studentId;
  final String? role;
  final String dorm;
  final String phone;
  final String parentName;
  final String parentPhone;
  final String? remark;
  final String? tags;
  final String? tag;
  final Color? tagColor;
  final Color? tagTextColor;
  final String gender;
  final String? avatarUrl;

  factory _StudentManageData.fromMap(Map<dynamic, dynamic> m) {
    final tagsRaw = m['tags']?.toString() ?? '';
    final firstTag = tagsRaw.split(',').where((t) => t.trim().isNotEmpty).firstOrNull?.trim();
    return _StudentManageData(
      id: int.tryParse(m['id']?.toString() ?? '') ?? 0,
      name: m['realname']?.toString() ?? m['nickname']?.toString() ?? '—',
      studentId: m['studentNo']?.toString() ?? m['code']?.toString() ?? '',
      gender: m['gender']?.toString() == '1' ? '男' : '女',
      dorm: m['dormitory']?.toString() ?? m['dorm']?.toString() ?? '—',
      phone: m['mobile']?.toString() ?? m['phone']?.toString() ?? '—',
      parentName: m['parentName']?.toString() ?? m['guardianName']?.toString() ?? '—',
      parentPhone: m['parentMobile']?.toString() ?? m['guardianMobile']?.toString() ?? '—',
      role: m['classRole']?.toString() ?? m['role']?.toString(),
      remark: m['remark']?.toString(),
      tags: tagsRaw,
      tag: firstTag,
      tagColor: firstTag != null ? _kPurple : null,
      tagTextColor: firstTag != null ? Colors.white : null,
      avatarUrl: m['headUrl']?.toString() ?? m['avatar']?.toString(),
    );
  }

  _StudentManageData copyWith({String? remark, String? tags}) {
    return _StudentManageData(
      id: id,
      name: name,
      studentId: studentId,
      gender: gender,
      dorm: dorm,
      phone: phone,
      parentName: parentName,
      parentPhone: parentPhone,
      role: role,
      remark: remark ?? this.remark,
      tags: tags ?? this.tags,
      tag: (tags ?? this.tags)?.split(',').where((t) => t.trim().isNotEmpty).firstOrNull?.trim(),
      tagColor: tagColor,
      tagTextColor: tagTextColor,
      avatarUrl: avatarUrl,
    );
  }
}

enum _WorkbenchTab { overview, students, grades }

extension on _WorkbenchTab {
  String get label {
    switch (this) {
      case _WorkbenchTab.overview:
        return '概况';
      case _WorkbenchTab.students:
        return '学生管理';
      case _WorkbenchTab.grades:
        return '成绩';
    }
  }
}

class TeacherClassWorkbenchView extends ConsumerStatefulWidget {
  const TeacherClassWorkbenchView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherClassWorkbenchView> createState() =>
      _TeacherClassWorkbenchViewState();
}

class _TeacherClassWorkbenchViewState
    extends ConsumerState<TeacherClassWorkbenchView> {
  _WorkbenchTab _tab = _WorkbenchTab.overview;

  // 当前班级（从 classList 接口获取第一个班级）；id 用字符串避免雪花精度丢失。
  String _classId = '0';
  String _className = '';
  bool _loadingClass = true;
  String _classError = '';

  @override
  void initState() {
    super.initState();
    _loadClass();
  }

  Future<void> _loadClass() async {
    final res = await ref.read(teacherRepositoryProvider).classList();
    if (!mounted) return;
    if (res.isSuccess) {
      final list = res.data is List ? res.data as List : [];
      if (list.isNotEmpty) {
        final first = list.first as Map;
        setState(() {
          _classId =
              first['id']?.toString() ??
              first['classId']?.toString() ??
              '0';
          _className = first['name']?.toString() ?? '';
          _loadingClass = false;
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _loadingClass = false;
        _classError = res.msg.isNotEmpty ? res.msg : '暂无绑定班级';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final banner = _WorkbenchBanner(
      tab: _tab,
      onTabChanged: (t) => setState(() => _tab = t),
      onBack: widget.onBack,
    );

    if (_loadingClass) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          banner,
          SizedBox(height: ui(80)),
          Center(
            child: CircularProgressIndicator(
              color: _kPurple,
              strokeWidth: 2,
            ),
          ),
        ],
      );
    }

    if (_classError.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          banner,
          SizedBox(height: ui(60)),
          Center(
            child: Text(
              _classError,
              style: TextStyle(fontSize: ui(14), color: _kTextHint),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          banner,
          SizedBox(height: ui(16)),
          // 不同 Tab 的主体——保持 banner 一致，下方切换内容。
          switch (_tab) {
            _WorkbenchTab.overview =>
              _OverviewTab(classId: _classId, className: _className),
            _WorkbenchTab.students => _StudentsTab(classId: _classId),
            _WorkbenchTab.grades => const _GradesTab(),
          },
        ],
      ),
    );
  }
}

// =============================================================================
// 顶部 Banner：左侧返回按钮 / 居中「班级工作台」标题 / 右侧 3 段 Tab
// =============================================================================

class _WorkbenchBanner extends StatelessWidget {
  const _WorkbenchBanner({
    required this.tab,
    required this.onTabChanged,
    required this.onBack,
  });

  final _WorkbenchTab tab;
  final ValueChanged<_WorkbenchTab> onTabChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(12)),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Color(0xFFF9EEFF)],
        ),
      ),
      child: Stack(
        children: [
          // 返回按钮
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
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          // 居中标题
          Center(
            child: Text(
              '班级工作台',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          // 右侧 Tab
          Positioned(
            right: ui(12),
            top: ui(15),
            child: _WorkbenchTabSegmented(tab: tab, onTabChanged: onTabChanged),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchTabSegmented extends StatelessWidget {
  const _WorkbenchTabSegmented({required this.tab, required this.onTabChanged});

  final _WorkbenchTab tab;
  final ValueChanged<_WorkbenchTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(32),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _WorkbenchTab.values)
            _SegmentItem(
              label: t.label,
              selected: t == tab,
              onTap: () => onTabChanged(t),
            ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(7)),
        decoration: BoxDecoration(
          color: selected ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: selected ? Colors.white : _kTextHint,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 概况 Tab
// =============================================================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.classId, required this.className});

  final String classId;
  final String className;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoticeSection(classId: classId),
        SizedBox(height: ui(20)),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final isCompact = w < ui(820);
            if (isCompact) {
              // 窄屏：单列堆叠展示。
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildLeftColumn(ui),
                  SizedBox(height: ui(20)),
                  ..._buildRightColumn(ui),
                ],
              );
            }
            const leftRatio = 574 / 970;
            const rightRatio = 384 / 970;
            final gap = ui(12);
            final leftW = (w - gap) * leftRatio / (leftRatio + rightRatio);
            final rightW = (w - gap) * rightRatio / (leftRatio + rightRatio);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: leftW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildLeftColumn(ui),
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: rightW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildRightColumn(ui),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildLeftColumn(double Function(double) ui) {
    return [
      const _SectionTitle('我的班级'),
      SizedBox(height: ui(12)),
      const _TeacherInfoCard(),
      SizedBox(height: ui(20)),
      const _SectionTitle('班级捷径'),
      SizedBox(height: ui(12)),
      const _ShortcutStatGrid(),
      SizedBox(height: ui(20)),
      const _SectionTitle('本周出勤'),
      SizedBox(height: ui(12)),
      const _AttendanceBarCard(),
      SizedBox(height: ui(20)),
      const _SectionTitle('今日节点'),
      SizedBox(height: ui(12)),
      const _TimelineCard(items: _kTodayCheckpoints, accent: _kPurple),
    ];
  }

  List<Widget> _buildRightColumn(double Function(double) ui) {
    return [
      const _SectionTitleWithAction(title: '待批请假', actionLabel: '全部'),
      SizedBox(height: ui(12)),
      const _LeaveListCard(),
      SizedBox(height: ui(20)),
      const _SectionTitle('班级捷径'),
      SizedBox(height: ui(12)),
      const _QuickActionGrid(),
      SizedBox(height: ui(20)),
      const _SectionTitle('重点关注'),
      SizedBox(height: ui(12)),
      const _AttentionListCard(),
      SizedBox(height: ui(20)),
      const _SectionTitle('近期班务'),
      SizedBox(height: ui(12)),
      const _TimelineCard(items: _kRecentDuty, accent: _kPurple),
    ];
  }
}

// ----- 通用：Section 标题 -----

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(18),
        color: _kTextSection,
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );
  }
}

class _SectionTitleWithAction extends StatelessWidget {
  const _SectionTitleWithAction({
    required this.title,
    required this.actionLabel,
  });
  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle(title)),
        InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(ui(6)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(2), vertical: ui(2)),
            child: Row(
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
                SizedBox(width: ui(2)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: ui(16),
                  color: const Color(0xFFCECED1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----- 班级通知（班主任视角：发布 + 删除） -----
//
// 与学生「我的班级 → 班级通知」共享 classNoticeControllerProvider；这里
// 加一个"发布通知"按钮和卡片右上角"×"删除按钮。卡片样式与学生视角一致
// （紫底 #F0E8FC，左侧紫色方块 highlight，下方日期）。

class _NoticeSection extends ConsumerStatefulWidget {
  const _NoticeSection({required this.classId});

  final String classId;

  @override
  ConsumerState<_NoticeSection> createState() => _NoticeSectionState();
}

class _NoticeSectionState extends ConsumerState<_NoticeSection> {
  List<_NoticeItem> _notices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await ref.read(teacherRepositoryProvider).schoolClassNoticeList(
      classId: widget.classId,
      size: 20,
    );
    if (!mounted) return;
    if (res.isSuccess) {
      final raw = res.data;
      final list = (raw is Map ? raw['records'] ?? raw['list'] ?? raw : raw);
      if (list is List) {
        _notices = list
            .whereType<Map>()
            .map(_NoticeItem.fromMap)
            .toList();
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoticeSectionHeader(
          onPublish: () => _showPublishNoticeDialog(
            context,
            ref,
            classId: widget.classId,
            onPublished: _loadNotices,
          ),
        ),
        SizedBox(height: ui(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: _loading
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: ui(20)),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _kPurple,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : _notices.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: ui(20)),
                  child: Center(
                    child: Text(
                      '暂无通知，点击右上角"发布通知"为本班发布第一条通知。',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 20 / 13,
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.maxWidth;
                    final cols = w >= ui(820) ? 3 : w >= ui(560) ? 2 : 1;
                    final gap = ui(8);
                    final cardWidth = (w - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final n in _notices)
                          SizedBox(
                            width: cardWidth,
                            child: _NoticeCardEditable(
                              notice: n,
                              onDelete: () => _confirmDeleteNoticeItem(ctx, n),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmDeleteNoticeItem(BuildContext ctx, _NoticeItem notice) async {
    final ok = await showScaledDialog<bool>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (dialogContext) {
        final ui = DashboardScaleScope.of(dialogContext).ui;
        return GradientHeaderDialog(
          title: '删除班级通知',
          titleFontSize: 24,
          titleFontWeight: FontWeight.w500,
          titlePaddingTop: 40,
          width: 420,
          contentPadding: EdgeInsets.fromLTRB(ui(40), ui(30), ui(40), ui(30)),
          actionBar: AppDialogActionBar(
            confirmLabel: '删除',
            cancelLabel: '取消',
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '删除后学生端「我的班级」也会同步移除该通知，操作不可撤回。',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 22 / 14,
                ),
              ),
              SizedBox(height: ui(12)),
              Container(
                padding: EdgeInsets.all(ui(10)),
                decoration: BoxDecoration(
                  color: _kAnnounceBg,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  notice.title.isNotEmpty ? notice.title : notice.content,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (ok == true && mounted) {
      setState(() => _notices.removeWhere((n) => n.id == notice.id));
    }
  }
}

class _NoticeSectionHeader extends StatelessWidget {
  const _NoticeSectionHeader({required this.onPublish});

  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle('班级通知')),
        InkWell(
          onTap: onPublish,
          borderRadius: BorderRadius.circular(ui(8)),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(7)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_kPurple, _kPurpleSoft],
              ),
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: ui(16), color: Colors.white),
                SizedBox(width: ui(4)),
                Text(
                  '发布通知',
                  style: TextStyle(
                    fontSize: ui(13),
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
    );
  }
}

class _NoticeCardEditable extends StatelessWidget {
  const _NoticeCardEditable({required this.notice, required this.onDelete});

  final _NoticeItem notice;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(8)),
      decoration: BoxDecoration(
        color: _kAnnounceBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ui(12),
                height: ui(20),
                child: Center(
                  child: Container(
                    width: ui(8),
                    height: ui(8),
                    decoration: BoxDecoration(
                      color: _kPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              SizedBox(width: ui(6)),
              Expanded(
                child: Text(
                  notice.title.isNotEmpty ? notice.title : notice.content,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
              SizedBox(width: ui(4)),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(ui(10)),
                child: Container(
                  width: ui(20),
                  height: ui(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(10)),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(14),
                    color: _kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (notice.title.isNotEmpty && notice.content.isNotEmpty) ...[
            SizedBox(height: ui(4)),
            Padding(
              padding: EdgeInsets.only(left: ui(18)),
              child: Text(
                notice.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 16 / 12,
                ),
              ),
            ),
          ],
          SizedBox(height: ui(4)),
          Padding(
            padding: EdgeInsets.only(left: ui(18)),
            child: Text(
              notice.date,
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 12 / 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// —— 发布通知弹窗 ——————————————————————————————————————————————————

Future<void> _showPublishNoticeDialog(
  BuildContext context,
  WidgetRef ref, {
  required String classId,
  required VoidCallback onPublished,
}) async {
  final titleCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  final result = await showScaledDialog<({String title, String content})>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return GradientHeaderDialog(
        title: '发布班级通知',
        titleFontSize: 24,
        titleFontWeight: FontWeight.w500,
        titlePaddingTop: 40,
        width: 460,
        contentPadding: EdgeInsets.fromLTRB(ui(40), ui(40), ui(40), ui(30)),
        actionBar: AppDialogActionBar(
          confirmLabel: '发布',
          cancelLabel: '取消',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () {
            final t = titleCtrl.text.trim();
            final c = contentCtrl.text.trim();
            if (t.isEmpty || c.isEmpty) return;
            Navigator.of(dialogContext).pop((title: t, content: c));
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '本通知将同步到学生「我的班级 → 班级通知」展示位，请精炼描述。',
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
            SizedBox(height: ui(16)),
            Text(
              '通知标题',
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 14,
              ),
            ),
            SizedBox(height: ui(8)),
            Container(
              height: ui(44),
              padding: EdgeInsets.symmetric(horizontal: ui(16)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft, width: 1),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: titleCtrl,
                autofocus: true,
                maxLines: 1,
                cursorColor: _kPurple,
                cursorWidth: 1.5,
                cursorHeight: ui(16),
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
                decoration: InputDecoration(
                  hintText: '示例：本周五合唱排练通知',
                  hintStyle: TextStyle(
                    fontSize: ui(14),
                    color: _kTextHintLight,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            Text(
              '通知内容',
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 14,
              ),
            ),
            SizedBox(height: ui(8)),
            Container(
              height: ui(100),
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
                controller: contentCtrl,
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
                  hintText: '示例：本周五16:30合唱排练，地点音乐厅A201。',
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

  if (result != null && context.mounted) {
    final res = await ref.read(teacherRepositoryProvider).schoolClassNoticeSave(
      classId: classId,
      title: result.title,
      content: result.content,
    );
    if (!context.mounted) return;
    if (res.isSuccess) {
      AppToast.show(context, '班级通知已发布');
      onPublished();
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '发布失败，请重试');
    }
  }
}


// ----- 我的班级 卡片 -----

class _TeacherInfoCard extends StatelessWidget {
  const _TeacherInfoCard();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeacherInfoHeader(),
          SizedBox(height: ui(12)),
          _TeacherInfoMeta(),
          SizedBox(height: ui(14)),
          _TeacherInfoStats(),
        ],
      ),
    );
  }
}

class _TeacherInfoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 头像 + 「班主任」徽标
        SizedBox(
          width: ui(56),
          height: ui(56),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: ui(48),
                height: ui(48),
                decoration: BoxDecoration(
                  color: _kPurple,
                  borderRadius: BorderRadius.circular(ui(24)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '黎',
                  style: TextStyle(
                    fontSize: ui(18),
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: ui(36),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(7),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: _kYellow,
                    borderRadius: BorderRadius.circular(ui(10)),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '班主任',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextDark,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(12)),
        // 文字信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Grey黎',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(8),
                      vertical: ui(4),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(4)),
                      border: Border.all(color: _kBorderSoft, width: 0.5),
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
                          '在岗',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextDark,
                            fontWeight: FontWeight.w400,
                            height: 1,
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
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        // 在籍 / 实到
        Row(
          children: [
            _HeaderStat(label: '在籍人数', value: '32'),
            SizedBox(width: ui(20)),
            _HeaderStat(label: '实到/应到', value: '31', secondary: '/32'),
          ],
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value, this.secondary});

  final String label;
  final String value;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(4)),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: ui(24),
                  color: _kPurple,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Barlow',
                  height: 1,
                ),
              ),
              if (secondary != null)
                TextSpan(
                  text: secondary,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextHint,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Barlow',
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

class _TeacherInfoMeta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget metaRow(String key, String value) => Padding(
      padding: EdgeInsets.only(bottom: ui(4)),
      child: Row(
        children: [
          Text(
            key,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [metaRow('带班：', '高三音乐实验班'), metaRow('位置：', '艺术楼·合唱排练厅A201')],
    );
  }
}

class _TeacherInfoStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget box(String label, String value) => Expanded(
      child: Container(
        height: ui(78),
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              value,
              style: TextStyle(
                fontSize: ui(24),
                color: _kTextDark,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        box('请假人数', '3'),
        SizedBox(width: ui(13)),
        box('查寝人数', '3'),
        SizedBox(width: ui(13)),
        box('家校', '3'),
      ],
    );
  }
}

// ----- 班级捷径（左：4 张统计 + 操作链接） -----

class _ShortcutStatGrid extends StatelessWidget {
  const _ShortcutStatGrid();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget cell({
      required String value,
      required String label,
      String? actionLabel,
    }) => Expanded(
      child: Container(
        height: ui(82),
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: ui(24),
                      color: _kTextDark,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              Positioned(
                right: ui(8),
                bottom: ui(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kPurple,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: ui(2)),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: ui(14),
                      color: _kPurple,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            cell(value: '6', label: '今日出勤率'),
            SizedBox(width: ui(12)),
            cell(value: '6', label: '待批请假', actionLabel: '去处理'),
          ],
        ),
        SizedBox(height: ui(12)),
        Row(
          children: [
            cell(value: '6', label: '查寝异常', actionLabel: '查看'),
            SizedBox(width: ui(12)),
            cell(value: '6', label: '家校未读', actionLabel: '回复'),
          ],
        ),
      ],
    );
  }
}

// ----- 班级捷径（右：6 个紫色图标按钮 2x3） -----

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid();

  static const List<_QuickActionData> _items = [
    _QuickActionData(label: '班级工作台', imagePath: 'assets/images/schoolA/13.png'),
    _QuickActionData(label: '请假审批', imagePath: 'assets/images/schoolA/3.png'),
    _QuickActionData(label: '查寝动态', imagePath: 'assets/images/schoolA/9.png'),
    _QuickActionData(label: '家校沟通', imagePath: 'assets/images/schoolA/15.png'),
    _QuickActionData(label: '班级群聊', imagePath: 'assets/images/schoolA/6.png'),
    _QuickActionData(label: '查寝历史', imagePath: 'assets/images/schoolA/14.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) SizedBox(height: ui(12)),
            Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) SizedBox(width: ui(8)),
                  Expanded(
                    child: _QuickActionTile(data: _items[row * 3 + col]),
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

class _QuickActionData {
  const _QuickActionData({required this.label, required this.imagePath});
  final String label;
  final String imagePath;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ui(44),
          height: ui(44),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE5FF),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            data.imagePath,
            width: ui(28),
            height: ui(28),
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: ui(6)),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextSection,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ----- 本周出勤 柱状图 -----

class _AttendanceBarCard extends StatelessWidget {
  const _AttendanceBarCard();

  static const List<int> _values = [92, 92, 92, 92, 92, 92, 92];
  static const List<String> _labels = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];
  static const List<int> _ticks = [100, 95, 90, 85, 80, 0];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final chartHeight = ui(180);
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部 % 单位
          Padding(
            padding: EdgeInsets.only(left: ui(2), bottom: ui(4)),
            child: Text(
              '%',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontWeight: FontWeight.w400,
                height: 20 / 12,
              ),
            ),
          ),
          // 主图区
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AxisTicksColumn(ticks: _ticks),
                SizedBox(width: ui(8)),
                Expanded(child: _BarsRow(values: _values, maxValue: 100)),
              ],
            ),
          ),
          SizedBox(height: ui(8)),
          // X 轴标签
          Padding(
            padding: EdgeInsets.only(left: ui(28)),
            child: Row(
              children: [
                for (final l in _labels)
                  Expanded(
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontWeight: FontWeight.w400,
                        height: 20 / 12,
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

class _AxisTicksColumn extends StatelessWidget {
  const _AxisTicksColumn({required this.ticks});
  final List<int> ticks;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < ticks.length; i++) ...[
            Text(
              ticks[i].toString(),
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            if (i < ticks.length - 1) const Spacer(),
          ],
        ],
      ),
    );
  }
}

class _BarsRow extends StatelessWidget {
  const _BarsRow({required this.values, required this.maxValue});
  final List<int> values;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final ratio = (values[i] / maxValue).clamp(0.0, 1.0);
                final h = c.maxHeight * ratio;
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    SizedBox(width: ui(28), height: c.maxHeight),
                    Container(
                      width: ui(28),
                      height: h,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_kPurpleSoft, Color(0x66A773FF)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: h + ui(2),
                      child: Text(
                        values[i].toString(),
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (i < values.length - 1) SizedBox(width: ui(8)),
        ],
      ],
    );
  }
}

// ----- 待批请假 列表 -----

class _LeaveListCard extends StatelessWidget {
  const _LeaveListCard();

  static const List<_LeaveItem> _items = [
    _LeaveItem(
      name: '陈江凯',
      timeRange: '今天14:00-明天08:00',
      submitted: '提交于今天07:52',
      tag: '病假',
      tagColor: _kYellow,
      tagTextColor: _kTextDark,
    ),
    _LeaveItem(
      name: '陈江凯',
      timeRange: '今天14:00-明天08:00',
      submitted: '提交于今天07:52',
      tag: '病假',
      tagColor: _kYellow,
      tagTextColor: _kTextDark,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(12)),
            _PersonRowCard(
              avatarSeed: _items[i].name.characters.first,
              name: _items[i].name,
              line2: _items[i].timeRange,
              line3: _items[i].submitted,
              tag: _items[i].tag,
              tagColor: _items[i].tagColor,
              tagTextColor: _items[i].tagTextColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaveItem {
  const _LeaveItem({
    required this.name,
    required this.timeRange,
    required this.submitted,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
  });
  final String name;
  final String timeRange;
  final String submitted;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
}

// ----- 重点关注 列表 -----

class _AttentionListCard extends StatelessWidget {
  const _AttentionListCard();

  static const List<_AttentionItem> _items = [
    _AttentionItem(
      name: '王晴',
      desc: '考前焦虑筛查跟进中',
      time: '昨天 12:32',
      tag: '心理关注',
      tagColor: _kPurple,
      tagTextColor: Colors.white,
    ),
    _AttentionItem(
      name: '韩露',
      desc: '考前焦虑筛查跟进中',
      time: '昨天 12:32',
      tag: '正常出勤',
      tagColor: _kYellow,
      tagTextColor: _kTextDark,
    ),
    _AttentionItem(
      name: '黎芭乐',
      desc: '考前焦虑筛查跟进中',
      time: '昨天 12:32',
      tag: '正常上课',
      tagColor: _kYellow,
      tagTextColor: _kTextDark,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(12)),
            _PersonRowCard(
              avatarSeed: _items[i].name.characters.first,
              name: _items[i].name,
              line2: _items[i].desc,
              line3: _items[i].time,
              tag: _items[i].tag,
              tagColor: _items[i].tagColor,
              tagTextColor: _items[i].tagTextColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _AttentionItem {
  const _AttentionItem({
    required this.name,
    required this.desc,
    required this.time,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
  });
  final String name;
  final String desc;
  final String time;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
}

class _PersonRowCard extends StatelessWidget {
  const _PersonRowCard({
    required this.avatarSeed,
    required this.name,
    required this.line2,
    required this.line3,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
  });

  final String avatarSeed;
  final String name;
  final String line2;
  final String line3;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(88),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 主体
          Padding(
            padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像
                Container(
                  width: ui(40),
                  height: ui(40),
                  decoration: BoxDecoration(
                    color: _kPurpleSoft,
                    borderRadius: BorderRadius.circular(ui(20)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    avatarSeed,
                    style: TextStyle(
                      fontSize: ui(15),
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: ui(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(14),
                          color: _kTextDark,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: ui(6)),
                      Text(
                        line2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextSecondary,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: ui(6)),
                      Text(
                        line3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(10),
                          color: _kTextHint,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右上角标签
          Positioned(
            right: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(ui(12)),
                bottomLeft: Radius.circular(ui(12)),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(10),
                  vertical: ui(3),
                ),
                color: tagColor,
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: tagTextColor,
                    fontWeight: FontWeight.w400,
                    height: 1,
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

// ----- 通用：时间轴卡片（今日节点 / 近期班务） -----

class _TimelineItem {
  const _TimelineItem({required this.title, required this.subtitle, this.time});
  final String title;
  final String subtitle;
  final String? time;
}

const List<_TimelineItem> _kTodayCheckpoints = [
  _TimelineItem(title: '08:10', subtitle: '到校考勤'),
  _TimelineItem(title: '09:10', subtitle: '上课打卡'),
  _TimelineItem(title: '18:20', subtitle: '晚自习考勤'),
  _TimelineItem(title: '21:20', subtitle: '宿舍考勤'),
];

const List<_TimelineItem> _kRecentDuty = [
  _TimelineItem(
    title: '晨检完成',
    subtitle: '应到42人，实到 41 ，1人事假已备案',
    time: '今天08:10',
  ),
  _TimelineItem(
    title: '查寝反馈',
    subtitle: '应到42人，实到 41 ，1人事假已备案',
    time: '今天08:10',
  ),
  _TimelineItem(
    title: '年级组通知已转发班级群',
    subtitle: '应到42人，实到 41 ，1人事假已备案',
    time: '今天08:10',
  ),
  _TimelineItem(
    title: '班会材料已上传班群文件夹',
    subtitle: '应到42人，实到 41 ，1人事假已备案',
    time: '今天08:10',
  ),
];

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.items, required this.accent});
  final List<_TimelineItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(20)),
            _TimelineRow(item: items[i], accent: accent),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.accent});
  final _TimelineItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 圆点
        Padding(
          padding: EdgeInsets.only(top: ui(4)),
          child: Container(
            width: ui(14),
            height: ui(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2FF),
              borderRadius: BorderRadius.circular(ui(7)),
            ),
            alignment: Alignment.center,
            child: Container(
              width: ui(8),
              height: ui(8),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                  if (item.time != null)
                    Text(
                      item.time!,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                ],
              ),
              SizedBox(height: ui(8)),
              _TimelineSubtitle(subtitle: item.subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineSubtitle extends StatelessWidget {
  const _TimelineSubtitle({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 把数字部分（如 "实到 41 ，"）染成紫色，其它文字用次级灰。
    final regex = RegExp(r'(\d+)');
    final matches = regex.allMatches(subtitle).toList();
    if (matches.isEmpty || subtitle.contains(':')) {
      // 单纯描述（包含 ":" 的当作时间标题，原样灰色显示）。
      return Text(
        subtitle,
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextSecondary,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      );
    }
    // 用第一个数字做高亮（其余仍属上下文文字）。
    final first = matches.first;
    final before = subtitle.substring(0, first.start);
    final number = subtitle.substring(first.start, first.end);
    final after = subtitle.substring(first.end);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: before,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          TextSpan(
            text: number,
            style: TextStyle(
              fontSize: ui(12),
              color: _kPurple,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          TextSpan(
            text: after,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 学生管理 Tab
// =============================================================================

class _StudentsTab extends ConsumerStatefulWidget {
  const _StudentsTab({required this.classId});

  final String classId;

  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab> {
  String _query = '';
  List<_StudentManageData> _allStudents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final res = await ref.read(teacherRepositoryProvider).studentList(
      classId: widget.classId,
      size: 1000,
    );
    if (!mounted) return;
    if (res.isSuccess) {
      final raw = res.data;
      final list = (raw is Map ? raw['records'] ?? raw['list'] ?? raw : raw);
      if (list is List) {
        _allStudents = list
            .whereType<Map>()
            .map(_StudentManageData.fromMap)
            .toList();
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StudentsHeader(
            total: 0,
            onQueryChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: ui(40)),
          Center(
            child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2),
          ),
        ],
      );
    }

    final filtered = _query.trim().isEmpty
        ? _allStudents
        : _allStudents.where((s) {
            final q = _query.toLowerCase();
            return s.name.toLowerCase().contains(q) ||
                s.studentId.toLowerCase().contains(q) ||
                s.dorm.toLowerCase().contains(q) ||
                s.phone.contains(q) ||
                s.parentPhone.contains(q);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudentsHeader(
          total: _allStudents.length,
          onQueryChanged: (v) => setState(() => _query = v),
        ),
        SizedBox(height: ui(16)),
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: ui(40)),
              child: Text(
                _query.isEmpty ? '暂无学生数据' : '未找到匹配学生',
                style: TextStyle(fontSize: ui(14), color: _kTextHint),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final gap = ui(12);
              final minCardW = ui(280);
              final cols = math.max(
                1,
                math.min(3, ((c.maxWidth + gap) / (minCardW + gap)).floor()),
              );
              final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in filtered)
                    SizedBox(
                      width: cardW,
                      child: _StudentManageCard(
                        data: s,
                        onTap: () => _showStudentDetail(context, s),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _StudentsHeader extends StatelessWidget {
  const _StudentsHeader({required this.onQueryChanged, required this.total});
  final ValueChanged<String> onQueryChanged;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SectionTitle('学生管理'),
              SizedBox(height: ui(4)),
              Text(
                total > 0
                    ? '共 $total 名学生 · 学生及家长信息仅查看，可编辑标签与备注'
                    : '学生及家长信息仅查看，可编辑标签与备注',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(12)),
        // 搜索框
        SizedBox(
          width: ui(324),
          child: Container(
            height: ui(40),
            padding: EdgeInsets.symmetric(horizontal: ui(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
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
                    onChanged: onQueryChanged,
                    cursorColor: _kPurple,
                    cursorWidth: 1.5,
                    cursorHeight: ui(16),
                    decoration: InputDecoration(
                      hintText: '搜索姓名、学号、手机、宿舍、家长',
                      hintStyle: TextStyle(
                        fontSize: ui(14),
                        color: const Color(0xFFD1D1D1),
                        fontWeight: FontWeight.w400,
                      ),
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: ui(14), color: _kTextSection),
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


class _StudentManageCard extends StatelessWidget {
  const _StudentManageCard({required this.data, this.onTap});
  final _StudentManageData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = BorderRadius.circular(ui(12));
    return Material(
      color: _kPanelBg,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: ui(156),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Padding(
                padding: EdgeInsets.all(ui(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 头像 + 姓名 + 性别 icon + 职务
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: ui(40),
                          height: ui(40),
                          decoration: BoxDecoration(
                            color: _kPurpleSoft,
                            borderRadius: BorderRadius.circular(ui(8)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            data.name.characters.first,
                            style: TextStyle(
                              fontSize: ui(15),
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              height: 1,
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
                                  Text(
                                    data.name,
                                    style: TextStyle(
                                      fontSize: ui(14),
                                      color: _kTextDark,
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(width: ui(4)),
                                  Icon(
                                    data.gender == '男'
                                        ? Icons.male_rounded
                                        : Icons.female_rounded,
                                    size: ui(14),
                                    color: data.gender == '男'
                                        ? _kBlue
                                        : _kPurple,
                                  ),
                                  if (data.role != null) ...[
                                    SizedBox(width: ui(8)),
                                    Text(
                                      data.role!,
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        color: _kPurple,
                                        fontWeight: FontWeight.w400,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: ui(6)),
                              Text(
                                data.dorm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w400,
                                  height: 1,
                                ),
                              ),
                              SizedBox(height: ui(6)),
                              Text(
                                data.studentId,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextHint,
                                  fontWeight: FontWeight.w400,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(12)),
                    // 电话信息
                    Container(
                      padding: EdgeInsets.symmetric(vertical: ui(12)),
                      decoration: BoxDecoration(
                        color: _kInnerGray,
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Row(
                        children: [
                          _phoneCell('本人电话', data.phone),
                          _phoneCell(
                            '家长${data.parentName}电话',
                            data.parentPhone,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 右上角标签
              if (data.tag != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(ui(12)),
                      bottomLeft: Radius.circular(ui(12)),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(12),
                        vertical: ui(3),
                      ),
                      color: data.tagColor ?? _kPurple,
                      child: Text(
                        data.tag!,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: data.tagTextColor ?? Colors.white,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneCell(String label, String value) => Builder(
    builder: (context) {
      final ui = DashboardScaleScope.of(context).ui;
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ],
        ),
      );
    },
  );
}

// =============================================================================
// 成绩 Tab
// =============================================================================

class _GradesTab extends StatefulWidget {
  const _GradesTab();

  @override
  State<_GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<_GradesTab> {
  int _examIdx = 0;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('班级成绩变化'),
        SizedBox(height: ui(12)),
        const _GradesLineChartCard(),
        SizedBox(height: ui(20)),
        const _SectionTitle('考试记录'),
        SizedBox(height: ui(12)),
        _GradesExamRecordCard(
          selectedIdx: _examIdx,
          onSelect: (i) => setState(() => _examIdx = i),
        ),
        SizedBox(height: ui(20)),
        const _SectionTitle('学生分数变化'),
        SizedBox(height: ui(12)),
        const _GradesScoreChangeCard(),
      ],
    );
  }
}

// ----- 班级成绩变化（折线图） -----

class _GradesLineChartCard extends StatelessWidget {
  const _GradesLineChartCard();

  static const List<String> _months = [
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
    '1月',
    '2月',
  ];

  // 三条折线（取值百分比，0~100）。Mock 数据。
  static const List<List<double>> _series = [
    [60, 73, 64, 88, 64, 96, 56], // 音乐专业
    [88, 73, 64, 88, 64, 96, 56], // 乐理/视唱
    [56, 96, 64, 88, 64, 73, 60], // 文化课
  ];
  static const List<Color> _seriesColors = [_kPurple, _kBlue, _kRed];
  static const List<String> _seriesLabels = ['音乐专业', '乐理/视唱', '文化课'];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶栏：% / 得分率 / 图例
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '%',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
              SizedBox(width: ui(8)),
              Text(
                '得分率',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
              const Spacer(),
              for (var i = 0; i < _seriesLabels.length; i++) ...[
                if (i > 0) SizedBox(width: ui(20)),
                _LegendItem(color: _seriesColors[i], label: _seriesLabels[i]),
              ],
            ],
          ),
          SizedBox(height: ui(8)),
          // 图表区
          SizedBox(
            height: ui(180),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AxisTicksColumn(ticks: const [100, 80, 60, 40, 20, 0]),
                SizedBox(width: ui(8)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _MultiLineChartPainter(
                        series: _series,
                        colors: _seriesColors,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(8)),
          // X 轴月份
          Padding(
            padding: EdgeInsets.only(left: ui(28)),
            child: Row(
              children: [
                for (final m in _months)
                  Expanded(
                    child: Text(
                      m,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontWeight: FontWeight.w400,
                        height: 20 / 12,
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: ui(7), height: ui(2), color: color),
        SizedBox(width: ui(2)),
        Container(width: ui(7), height: ui(2), color: color),
        SizedBox(width: ui(4)),
        Container(
          width: ui(8),
          height: ui(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _MultiLineChartPainter extends CustomPainter {
  _MultiLineChartPainter({required this.series, required this.colors});

  final List<List<double>> series;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final n = series.first.length;
    if (n < 2) return;
    final stepX = size.width / (n - 1);
    Offset point(double v, int i) {
      final clamped = v.clamp(0.0, 100.0);
      final y = size.height * (1 - clamped / 100);
      return Offset(stepX * i, y);
    }

    for (var s = 0; s < series.length; s++) {
      final color = colors[s];
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(series[s][i], i);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, linePaint);

      // 数据点
      final dotFill = Paint()..color = Colors.white;
      final dotStroke = Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < n; i++) {
        final p = point(series[s][i], i);
        canvas.drawCircle(p, 4, dotFill);
        canvas.drawCircle(p, 4, dotStroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter old) {
    return old.series != series || old.colors != colors;
  }
}

// ----- 考试记录卡（含日期 Tab + 学生分数+点评） -----

class _ExamSession {
  const _ExamSession({required this.title, required this.date});
  final String title;
  final String date;
}

const List<_ExamSession> _kExamSessions = [
  _ExamSession(title: '高三年级三月月考', date: '2026-03-18'),
  _ExamSession(title: '高三年级三月月考', date: '2026-03-18'),
  _ExamSession(title: '高三年级三月月考', date: '2026-03-18'),
];

class _ExamScoreItem {
  const _ExamScoreItem({
    required this.name,
    required this.studentId,
    required this.teacher,
    required this.comment,
    required this.score,
    required this.subject,
  });
  final String name;
  final String studentId;
  final String teacher;
  final String comment;
  final int score;
  final String subject;
}

const List<_ExamScoreItem> _kExamScores = [
  _ExamScoreItem(
    name: '李铮辉',
    studentId: 'G3030201',
    teacher: '李牧茵',
    comment: '舞台表现有进步，下周重点抠作品高潮处的气息与咬字。',
    score: 86,
    subject: '音乐专业',
  ),
  _ExamScoreItem(
    name: '李铮辉',
    studentId: 'G3030201',
    teacher: '李牧茵',
    comment: '舞台表现有进步，下周重点抠作品高潮处的气息与咬字。',
    score: 86,
    subject: '音乐专业',
  ),
  _ExamScoreItem(
    name: '李铮辉',
    studentId: 'G3030201',
    teacher: '李牧茵',
    comment: '舞台表现有进步，下周重点抠作品高潮处的气息与咬字。',
    score: 86,
    subject: '音乐专业',
  ),
  _ExamScoreItem(
    name: '李铮辉',
    studentId: 'G3030201',
    teacher: '李牧茵',
    comment: '舞台表现有进步，下周重点抠作品高潮处的气息与咬字。',
    score: 86,
    subject: '音乐专业',
  ),
  _ExamScoreItem(
    name: '李铮辉',
    studentId: 'G3030201',
    teacher: '李牧茵',
    comment: '舞台表现有进步，下周重点抠作品高潮处的气息与咬字。',
    score: 86,
    subject: '音乐专业',
  ),
  _ExamScoreItem(
    name: '李铮辉',
    studentId: 'G3030201',
    teacher: '李牧茵',
    comment: '舞台表现有进步，下周重点抠作品高潮处的气息与咬字。',
    score: 86,
    subject: '音乐专业',
  ),
];

class _GradesExamRecordCard extends StatelessWidget {
  const _GradesExamRecordCard({
    required this.selectedIdx,
    required this.onSelect,
  });
  final int selectedIdx;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 考试日期 Tab
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _kExamSessions.length; i++) ...[
                  if (i > 0) SizedBox(width: ui(11)),
                  _ExamSessionChip(
                    session: _kExamSessions[i],
                    selected: i == selectedIdx,
                    onTap: () => onSelect(i),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: ui(12)),
          // 学生分数 + 点评 网格：按最小卡宽自适应列数（≥ ~360 即 2 列），
          // 不再用固定阈值 960，避免 DashboardScale 把阈值放大后被迫单列。
          LayoutBuilder(
            builder: (context, c) {
              final gap = ui(12);
              final minCardW = ui(360);
              final cols = math.max(
                1,
                ((c.maxWidth + gap) / (minCardW + gap)).floor(),
              );
              final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in _kExamScores)
                    SizedBox(
                      width: cardW,
                      child: _ExamScoreCard(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExamSessionChip extends StatelessWidget {
  const _ExamSessionChip({
    required this.session,
    required this.selected,
    required this.onTap,
  });
  final _ExamSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F4FF) : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
          border: selected ? Border.all(color: _kPurpleSoft, width: 1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.title,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(2)),
            Text(
              session.date,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamScoreCard extends StatelessWidget {
  const _ExamScoreCard({required this.item});
  final _ExamScoreItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像 + 姓名/学号 + 标签 + 右上角「详情」
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(right: ui(56)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: ui(40),
                      height: ui(40),
                      decoration: BoxDecoration(
                        color: _kPurpleSoft,
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.name.characters.first,
                        style: TextStyle(
                          fontSize: ui(15),
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          height: 1,
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
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                              ),
                              SizedBox(width: ui(8)),
                              Expanded(
                                child: Text(
                                  item.studentId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: ui(12),
                                    color: _kTextHint,
                                    fontWeight: FontWeight.w400,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ui(4)),
                          // 4 个标签：录音/录像（灰底深字）+ 视频/语音点评（紫底白字）
                          Wrap(
                            spacing: ui(4),
                            runSpacing: ui(4),
                            children: const [
                              _MiniTag(
                                text: '学生录音',
                                color: Color(0xFFE6E9F1),
                                textColor: _kTextSecondary,
                              ),
                              _MiniTag(
                                text: '学生录像',
                                color: Color(0xFFE6E9F1),
                                textColor: _kTextSecondary,
                              ),
                              _MiniTag(
                                text: '视频点评',
                                color: _kPurpleSoft,
                                textColor: Colors.white,
                              ),
                              _MiniTag(
                                text: '语音点评',
                                color: _kPurpleSoft,
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 「详情 >」固定在右上角，与头像顶端对齐
              Positioned(right: 0, top: ui(2), child: _DetailLink()),
            ],
          ),
          SizedBox(height: ui(8)),
          // 任课点评 + 分数（右侧 Barlow 20 + 音乐专业 12 灰）
          Container(
            height: ui(45),
            padding: EdgeInsets.symmetric(horizontal: ui(8)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '任课 ${item.teacher}:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextHint,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: ui(6)),
                      Text(
                        item.comment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextDark,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ui(8)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.score.toString(),
                      style: TextStyle(
                        fontSize: ui(20),
                        color: _kTextDark,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Barlow',
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      item.subject,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
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

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.text,
    required this.color,
    required this.textColor,
  });
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(11),
          color: textColor,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _DetailLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '详情',
          style: TextStyle(
            fontSize: ui(14),
            color: _kBlue,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: ui(16), color: _kBlue),
      ],
    );
  }
}

// ----- 学生分数变化 卡 -----

class _ScoreChangeItem {
  const _ScoreChangeItem({
    required this.name,
    required this.studentId,
    required this.recentScore,
    required this.delta,
  });
  final String name;
  final String studentId;
  final int recentScore;
  final String delta;
}

const List<_ScoreChangeItem> _kScoreChanges = [
  _ScoreChangeItem(
    name: '李铮辉',
    studentId: 'G3030201',
    recentScore: 86,
    delta: '+2',
  ),
  _ScoreChangeItem(
    name: '李铮辉',
    studentId: 'G3030201',
    recentScore: 86,
    delta: '+2',
  ),
  _ScoreChangeItem(
    name: '李铮辉',
    studentId: 'G3030201',
    recentScore: 86,
    delta: '+2',
  ),
  _ScoreChangeItem(
    name: '李铮辉',
    studentId: 'G3030201',
    recentScore: 86,
    delta: '+2',
  ),
  _ScoreChangeItem(
    name: '李铮辉',
    studentId: 'G3030201',
    recentScore: 86,
    delta: '+2',
  ),
  _ScoreChangeItem(
    name: '李铮辉',
    studentId: 'G3030201',
    recentScore: 86,
    delta: '+2',
  ),
];

class _GradesScoreChangeCard extends StatelessWidget {
  const _GradesScoreChangeCard();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final gap = ui(12);
          final minCardW = ui(360);
          final cols = math.max(
            1,
            ((c.maxWidth + gap) / (minCardW + gap)).floor(),
          );
          final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in _kScoreChanges)
                SizedBox(
                  width: cardW,
                  child: _ScoreChangeCard(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreChangeCard extends StatelessWidget {
  const _ScoreChangeCard({required this.item});
  final _ScoreChangeItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: ui(40),
                height: ui(40),
                decoration: BoxDecoration(
                  color: _kPurpleSoft,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.name.characters.first,
                  style: TextStyle(
                    fontSize: ui(15),
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(8)),
                    Text(
                      item.studentId,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _DetailLink(),
            ],
          ),
          SizedBox(height: ui(8)),
          Container(
            height: ui(45),
            padding: EdgeInsets.symmetric(horizontal: ui(8)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '音乐专业最近分数:',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextSecondary,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                      SizedBox(width: ui(8)),
                      Text(
                        item.recentScore.toString(),
                        style: TextStyle(
                          fontSize: ui(20),
                          color: _kTextDark,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Barlow',
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '较上一轮:',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: ui(8)),
                    Text(
                      item.delta,
                      style: TextStyle(
                        fontSize: ui(20),
                        color: item.delta.startsWith('-') ? _kRed : _kTextDark,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Barlow',
                        height: 1,
                      ),
                    ),
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

// =============================================================================
// 学生档案详情面板（点击学生卡时从右侧滑出，20% 黑底蒙层覆盖左侧）
// =============================================================================

Future<void> _showStudentDetail(BuildContext context, _StudentManageData data) {
  // showGeneralDialog 会把内容挂到根 Navigator 的 overlay 上，那条 widget 树
  // 里没有 DashboardScaleScope；这里先把当前 scale 数据捕获下来，进 dialog
  // 后再用一个新的 DashboardScaleScope 包一层，保证面板里的 ui(...) 仍然可用。
  final scaleData = DashboardScaleScope.of(context);
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭学生档案',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => DashboardScaleScope(
      data: scaleData,
      child: _StudentDetailPanel(data: data),
    ),
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(t),
        child: child,
      );
    },
  );
}

class _StudentDetailPanel extends ConsumerStatefulWidget {
  const _StudentDetailPanel({required this.data});
  final _StudentManageData data;

  @override
  ConsumerState<_StudentDetailPanel> createState() =>
      _StudentDetailPanelState();
}

class _StudentDetailPanelState extends ConsumerState<_StudentDetailPanel> {
  // 班主任标签集合；来自 API tags 字段（逗号分隔），合并已知预设。
  static const List<String> _kPresetTags = [
    '合唱团',
    '声乐部',
    '钢琴组',
    '艺术节',
    '校宣部',
    '社团骨干',
  ];

  late List<String> _selectedTags;
  late final TextEditingController _remarkCtrl;
  bool _saving = false;
  bool _loadingDetail = false;

  // 从 API 补充的详细信息（覆盖 widget.data 中的占位数据）
  Map<String, dynamic> _detailExtra = {};

  @override
  void initState() {
    super.initState();
    final tagsStr = widget.data.tags ?? '';
    _selectedTags = tagsStr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    _remarkCtrl = TextEditingController(text: widget.data.remark ?? '');
    if (widget.data.id > 0) _loadDetail();
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    final res = await ref.read(teacherRepositoryProvider).studentDetail(
      id: widget.data.id,
    );
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(() {
        _detailExtra = Map<String, dynamic>.from(res.data as Map);
        final tagsRaw = _detailExtra['tags']?.toString() ?? '';
        if (tagsRaw.isNotEmpty) {
          _selectedTags = tagsRaw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
        }
        final remarkRaw = _detailExtra['remark']?.toString() ?? '';
        if (remarkRaw.isNotEmpty) {
          _remarkCtrl.text = remarkRaw;
        }
      });
    }
    if (mounted) setState(() => _loadingDetail = false);
  }

  Future<void> _saveChanges() async {
    if (widget.data.id <= 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _saving = true);
    final tags = _selectedTags.join(',');
    final remark = _remarkCtrl.text.trim();
    final res = await ref.read(teacherRepositoryProvider).studentUpdate(
      studentId: widget.data.id,
      remark: remark,
      tags: tags,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.isSuccess) {
      AppToast.show(context, '修改已保存');
      Navigator.of(context).maybePop();
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '保存失败，请重试');
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  String _detailField(String apiKey, String fallback) {
    final v = _detailExtra[apiKey]?.toString().trim() ?? '';
    return v.isNotEmpty ? v : fallback;
  }

  late final String _classRole = widget.data.role ?? '';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final mq = MediaQuery.sizeOf(context);
    final panelW = math.min(ui(600), mq.width);
    final data = widget.data;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: panelW,
          height: mq.height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----- 顶部：紫色竖条 + 学生档案 标题 + 关闭按钮 -----
              SizedBox(
                height: ui(62),
                child: Stack(
                  children: [
                    Positioned(
                      left: ui(12),
                      top: ui(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: ui(3.25),
                            height: ui(14.85),
                            decoration: BoxDecoration(
                              color: _kPurple,
                              borderRadius: BorderRadius.circular(ui(6)),
                            ),
                          ),
                          SizedBox(width: ui(4)),
                          Text(
                            '学生档案',
                            style: TextStyle(
                              fontSize: ui(16),
                              color: _kTextDark,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: ui(12),
                      top: ui(15),
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(ui(8)),
                        child: Container(
                          width: ui(32),
                          height: ui(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ui(8)),
                            border: Border.all(color: _kBorderSoft),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close_rounded,
                            size: ui(18),
                            color: const Color(0xFF1C274C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(20)),
                child: Container(height: 1, color: _kBorderSoft),
              ),
              // ----- 头像 + 姓名 + 学号 -----
              Padding(
                padding: EdgeInsets.fromLTRB(ui(20), ui(16), ui(20), 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: ui(40),
                      height: ui(40),
                      decoration: BoxDecoration(
                        color: _kPurpleSoft,
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        data.name.characters.first,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: ui(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.name,
                          style: TextStyle(
                            fontSize: ui(16),
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: ui(8)),
                        Text(
                          data.studentId,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextHint,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ----- 滚动主体 -----
              Expanded(
                child: _loadingDetail
                    ? Center(
                        child: CircularProgressIndicator(
                          color: _kPurple,
                          strokeWidth: 2,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          ui(20),
                          ui(16),
                          ui(20),
                          ui(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailGroupCard(
                              title: '本人信息',
                              children: [
                                _DetailFieldRow(
                                  children: [
                                    _DetailField(
                                      label: '性别：',
                                      value: _detailField('gender', data.gender == '1' ? '男' : data.gender),
                                    ),
                                    _DetailField(
                                      label: '住宿：',
                                      value: _detailField('dormitory', data.dorm),
                                    ),
                                    _DetailField(
                                      label: '本人手机：',
                                      value: _detailField('mobile', data.phone),
                                    ),
                                    _DetailField(
                                      label: '常住地址：',
                                      value: _detailField('address', '—'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: ui(12)),
                            _DetailGroupCard(
                              title: '家长与监护人',
                              children: [
                                _DetailFieldRow(
                                  children: [
                                    _DetailField(
                                      label: '监护人一：',
                                      value: _detailField(
                                        'guardianName',
                                        _detailField('parentName', data.parentName),
                                      ),
                                    ),
                                    _DetailField(
                                      label: '关系：',
                                      value: _detailField('guardianRelation', '—'),
                                    ),
                                    _DetailField(
                                      label: '手机：',
                                      value: _detailField(
                                        'guardianMobile',
                                        _detailField('parentMobile', data.parentPhone),
                                      ),
                                    ),
                                    const _DetailField(
                                      label: '',
                                      value: '',
                                      invisible: true,
                                    ),
                                  ],
                                ),
                                if (_detailExtra['guardian2Name'] != null) ...[
                                  SizedBox(height: ui(8)),
                                  _DetailFieldRow(
                                    children: [
                                      _DetailField(
                                        label: '监护人二：',
                                        value: _detailField('guardian2Name', '—'),
                                      ),
                                      _DetailField(
                                        label: '关系：',
                                        value: _detailField('guardian2Relation', '—'),
                                      ),
                                      _DetailField(
                                        label: '手机：',
                                        value: _detailField('guardian2Mobile', '—'),
                                      ),
                                      const _DetailField(
                                        label: '',
                                        value: '',
                                        invisible: true,
                                      ),
                                    ],
                                  ),
                                ],
                                if (_detailExtra['emergencyContact'] != null) ...[
                                  SizedBox(height: ui(8)),
                                  _DetailFieldRow(
                                    children: [
                                      _DetailField(
                                        label: '紧急联系人：',
                                        value: _detailField('emergencyContact', '—'),
                                      ),
                                      const _DetailField(
                                        label: '',
                                        value: '',
                                        invisible: true,
                                      ),
                                      _DetailField(
                                        label: '手机：',
                                        value: _detailField(
                                          'emergencyMobile',
                                          '—',
                                        ),
                                      ),
                                      const _DetailField(
                                        label: '',
                                        value: '',
                                        invisible: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: ui(16)),
                            _detailLabel(context, '班主任备注'),
                            SizedBox(height: ui(8)),
                            Container(
                              constraints: BoxConstraints(minHeight: ui(60)),
                              padding: EdgeInsets.fromLTRB(
                                ui(16),
                                ui(12),
                                ui(16),
                                ui(12),
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ui(8)),
                                border: Border.all(color: _kInnerGray),
                              ),
                              child: TextField(
                                controller: _remarkCtrl,
                                maxLines: null,
                                cursorColor: _kPurple,
                                cursorWidth: 1.5,
                                cursorHeight: ui(16),
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w400,
                                  height: 20 / 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: '为该学生添加备注…',
                                  hintStyle: TextStyle(
                                    fontSize: ui(14),
                                    color: _kTextHint,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_classRole.isNotEmpty) ...[
                              SizedBox(height: ui(16)),
                              _detailLabel(context, '班级职务'),
                              SizedBox(height: ui(8)),
                              Container(
                                height: ui(48),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ui(16),
                                  vertical: ui(14),
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ui(8)),
                                  border: Border.all(color: _kInnerGray),
                                ),
                                child: Text(
                                  _classRole,
                                  style: TextStyle(
                                    fontSize: ui(14),
                                    color: _kTextDark,
                                    fontWeight: FontWeight.w400,
                                    height: 20 / 14,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: ui(16)),
                            _detailLabel(context, '班主任标签'),
                            SizedBox(height: ui(8)),
                            Wrap(
                              spacing: ui(10),
                              runSpacing: ui(10),
                              children: [
                                for (final tag in _kPresetTags)
                                  _TeacherTagChip(
                                    text: tag,
                                    selected: _selectedTags.contains(tag),
                                    onTap: () => _toggleTag(tag),
                                  ),
                              ],
                            ),
                            SizedBox(height: ui(20)),
                            InkWell(
                              onTap: _saving ? null : _saveChanges,
                              borderRadius: BorderRadius.circular(ui(12)),
                              child: Container(
                                width: double.infinity,
                                height: ui(48),
                                padding: EdgeInsets.all(ui(10)),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ui(12)),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: _saving
                                        ? [
                                            const Color(0xFFB68EFF)
                                                .withValues(alpha: 0.5),
                                            const Color(0xFF8640FF)
                                                .withValues(alpha: 0.5),
                                          ]
                                        : const [
                                            Color(0xFFB68EFF),
                                            Color(0xFF8640FF),
                                          ],
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_saving)
                                      SizedBox(
                                        width: ui(16),
                                        height: ui(16),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.check_rounded,
                                        size: ui(16),
                                        color: Colors.white,
                                      ),
                                    SizedBox(width: ui(8)),
                                    Text(
                                      _saving ? '保存中…' : '确认修改',
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        height: 24 / 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailGroupCard extends StatelessWidget {
  const _DetailGroupCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextDark,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          ...children,
        ],
      ),
    );
  }
}

class _DetailFieldRow extends StatelessWidget {
  const _DetailFieldRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: ui(8)),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.invisible = false,
  });
  final String label;
  final String value;

  /// 占位用：spec 里部分单元格 opacity:0，仅用于撑列宽。
  final bool invisible;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(2)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
    if (invisible) {
      return Opacity(opacity: 0, child: col);
    }
    return col;
  }
}

Widget _detailLabel(BuildContext context, String text) {
  final ui = DashboardScaleScope.of(context).ui;
  return Text(
    text,
    style: TextStyle(
      fontSize: ui(14),
      color: Colors.black,
      fontWeight: FontWeight.w500,
      height: 20 / 14,
    ),
  );
}

class _TeacherTagChip extends StatelessWidget {
  const _TeacherTagChip({
    required this.text,
    this.selected = false,
    this.onTap,
  });
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final Color bg;
    final Color textColor;
    if (selected) {
      bg = _kPurpleSoft;
      textColor = Colors.white;
    } else {
      bg = _kInnerGray;
      textColor = _kTextSecondary;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      // 注意：不要在外层 Container 上设 alignment——alignment 会让 Container
      // 膨胀填满 Wrap 整行的可用宽度，导致每行只能放一个 chip。
      // 这里改用「上下 padding 撑高 + 不设 alignment」让 chip 按文本宽度收缩，
      // 从而能在 Wrap 里一行并排多个。
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: ui(12),
            color: textColor,
            fontWeight: FontWeight.w400,
            height: 15.24 / 12,
          ),
        ),
      ),
    );
  }
}
