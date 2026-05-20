// =============================================================================
// 学生端「我的班级」独立页面
//
// 入口：学生 dashboard 快捷区「我的班级」按钮 → controller.openMyClass()
//      → mainView == myClass + role == student → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack（controller.backToDashboard）。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（高 62）：白→#F9EDFF 渐变，左返回按钮，居中"我的班级"标题
//   2. 班级信息卡（高 163）：左上 班级名 + 副标题 + 三列信息（班主任 / 辅导员 / 教室）
//      + 底部"教务与艺术实践办公室·列表展示12/42人"；右上 全班 / 男生 / 女生 三个
//      100×100 紫色数字统计盒
//   3. 班级通知：标题行（"班级通知" + "查看全部 >"）+ 白卡内 2 条紫底 #F0E8FC 通知
//      （数据来自 classNoticeControllerProvider，班主任在「班级工作台」可发布/删除）
//   4. 师资：三段（教务老师 / 班主任 / 任课老师），每段一张白卡内若干 308×171 灰底
//      老师卡（任课卡右上多一个粉色课程标签）
//   5. 同班同学：标题行（"同班同学" + 搜索框）+ 白卡内 124×124 学生卡 7 列网格，
//      第一格固定为"自己"
//
// 颜色：白卡 #FFFFFF / 灰底 #F5F6FA / 主紫 #8741FF / 软紫 #B98FFF / 紫底 #F0E8FC
//      / 粉签 #FFC8D9 / 自己卡片背景 #F7F2FF / 描述 #B6B5BB / 副字 #6D6B75
// 字体：PingFang SC（标题 18 / 正文 12~14 / 提示 11）+ Barlow（数字 24，紫色）
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/ui/shell_layout.dart';
import '../state/class_notice_controller.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleAvatar = Color(0xFFB98FFF);
const Color _kAnnounceBg = Color(0xFFF0E8FC);
const Color _kCoursePink = Color(0xFFFFC8D9);
const Color _kSelfTagBg = Color(0xFFF7F2FF);
const Color _kPlaceholder = Color(0xFFD1D1D1);

class StudentMyClassView extends StatefulWidget {
  const StudentMyClassView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<StudentMyClassView> createState() => _StudentMyClassViewState();
}

class _StudentMyClassViewState extends State<StudentMyClassView> {
  String _classmateQuery = '';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MyClassBanner(onBack: widget.onBack),
          SizedBox(height: ui(16)),
          _ClassInfoCard(data: _kDemoClass),
          SizedBox(height: ui(16)),
          const _AnnouncementSection(),
          SizedBox(height: ui(16)),
          _FacultySection(sections: _kDemoFacultySections),
          SizedBox(height: ui(16)),
          _ClassmateSection(
            classmates: _kDemoClassmates,
            query: _classmateQuery,
            onQueryChanged: (v) => setState(() => _classmateQuery = v),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 顶部 banner：白→紫淡色渐变，左返回按钮 + 居中标题
// =============================================================================

class _MyClassBanner extends StatelessWidget {
  const _MyClassBanner({required this.onBack});

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
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
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
          Center(
            child: Text(
              '我的班级',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontWeight: AppFont.w600,
                fontFamily: 'PingFang SC',
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 班级信息卡（高 163）
// =============================================================================

class _ClassInfoData {
  const _ClassInfoData({
    required this.name,
    required this.subtitle,
    required this.headTeacher,
    required this.counselor,
    required this.classroom,
    required this.footer,
    required this.totalCount,
    required this.boyCount,
    required this.girlCount,
  });

  final String name;
  final String subtitle;
  final String headTeacher;
  final String counselor;
  final String classroom;
  final String footer;
  final int totalCount;
  final int boyCount;
  final int girlCount;
}

class _ClassInfoCard extends StatelessWidget {
  const _ClassInfoCard({required this.data});

  final _ClassInfoData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(163),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          // 211deg ≈ 从右上向左下，颜色从白到 #FAF0FF
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Colors.white, Color(0xFFFAF0FF)],
        ),
      ),
      child: Stack(
        children: [
          // 标题
          Positioned(
            left: ui(16),
            top: ui(12),
            child: Text(
              data.name,
              style: TextStyle(
                fontSize: ui(18),
                color: _kTextDark,
                fontWeight: AppFont.w500,
                fontFamily: 'PingFang SC',
                height: 1,
              ),
            ),
          ),
          // 副标题
          Positioned(
            left: ui(16),
            top: ui(41),
            child: Text(
              data.subtitle,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontWeight: AppFont.w400,
                fontFamily: 'PingFang SC',
                height: 1,
              ),
            ),
          ),
          // 三列信息（班主任 / 辅导员 / 教室）
          // 不再外包 SizedBox(height: 40)：固定 40 在系统 textScaler > 1.0
          // 时（label 14 + gap 8 + value 14 都按比例放大）会触发
          // "BOTTOM OVERFLOWED BY 8.0 PIXELS"。
          // 让 Row 自适应即可——_VDivider 自带 height:31，不依赖父级。
          Positioned(
            left: ui(16),
            top: ui(70),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _InfoPair(label: '班主任', value: data.headTeacher),
                SizedBox(width: ui(12)),
                _VDivider(),
                SizedBox(width: ui(12)),
                _InfoPair(label: '辅导员', value: data.counselor),
                SizedBox(width: ui(12)),
                _VDivider(),
                SizedBox(width: ui(12)),
                _InfoPair(label: '教室', value: data.classroom),
              ],
            ),
          ),
          // footer
          Positioned(
            left: ui(16),
            top: ui(134),
            child: Text(
              data.footer,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontWeight: AppFont.w400,
                fontFamily: 'PingFang SC',
                height: 1.2,
              ),
            ),
          ),
          // 右上：三个数字盒
          Positioned(
            right: ui(20),
            top: ui(31),
            child: Row(
              children: [
                _StatBox(label: '全班', value: data.totalCount),
                SizedBox(width: ui(16)),
                _StatBox(label: '男生', value: data.boyCount),
                SizedBox(width: ui(16)),
                _StatBox(label: '女生', value: data.girlCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(160),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
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

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(width: 1, height: ui(31), color: _kBorderSoft);
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(100),
      height: ui(100),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: Colors.black,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(10)),
          Text(
            '$value',
            style: TextStyle(
              fontSize: ui(24),
              color: _kPurple,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 班级通知（与班主任「班级工作台 → 概况」共享同一 provider，班主任发布/
// 删除后这里实时同步）
// =============================================================================

class _AnnouncementSection extends ConsumerWidget {
  const _AnnouncementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final items = ref.watch(classNoticeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: '班级通知', actionLabel: '查看全部', onAction: () {}),
        SizedBox(height: ui(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          // 学生视角不暴露任何编辑入口；空列表时显示提示文字。
          child: items.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: ui(20)),
                  child: Center(
                    child: Text(
                      '暂无通知',
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
              // IntrinsicHeight：父级是 SingleChildScrollView/Column，给的高度
              // 约束是 0..Infinity；Row 上若直接用 crossAxisAlignment.stretch
              // 会触发 RenderFlex 断言（"vertical viewport was given unbounded
              // height"）。包一层 IntrinsicHeight 把两张通知卡撑到等高。
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length && i < 2; i++) ...[
                        if (i > 0) SizedBox(width: ui(8)),
                        Expanded(child: _AnnouncementCard(item: items[i])),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});

  final ClassNotice item;

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
              if (item.highlighted) ...[
                SizedBox(
                  width: ui(12),
                  height: ui(20),
                  child: Center(
                    child: Container(
                      width: ui(10),
                      height: ui(10),
                      color: _kPurple,
                    ),
                  ),
                ),
                SizedBox(width: ui(8)),
              ],
              Expanded(
                child: Text(
                  item.text,
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
          SizedBox(height: ui(4)),
          Padding(
            padding: EdgeInsets.only(left: ui(20)),
            child: Text(
              item.date,
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

// =============================================================================
// 师资
// =============================================================================

class _FacultyMember {
  const _FacultyMember({
    required this.name,
    required this.role,
    required this.location,
    required this.description,
    required this.phone,
    required this.email,
    this.courseTag,
  });

  final String name;
  final String role;
  final String location;
  final String description;
  final String phone;
  final String email;

  /// 任课老师卡片右上角的课程标签（如"形体课"），其他段落为 null。
  final String? courseTag;
}

class _FacultySectionData {
  const _FacultySectionData({required this.title, required this.members});

  final String title;
  final List<_FacultyMember> members;
}

class _FacultySection extends StatelessWidget {
  const _FacultySection({required this.sections});

  final List<_FacultySectionData> sections;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('师资'),
        SizedBox(height: ui(12)),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: ui(12)),
          _FacultyGroupCard(section: sections[i]),
        ],
      ],
    );
  }
}

class _FacultyGroupCard extends StatelessWidget {
  const _FacultyGroupCard({required this.section});

  final _FacultySectionData section;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Wrap(
            spacing: ui(12),
            runSpacing: ui(12),
            children: [
              for (final m in section.members) _FacultyCard(member: m),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacultyCard extends StatelessWidget {
  const _FacultyCard({required this.member});

  final _FacultyMember member;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(308),
      height: ui(171),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          // 头像 40×40 占位
          Positioned(
            left: ui(12),
            top: ui(8),
            child: Container(
              width: ui(40),
              height: ui(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.person_outline_rounded,
                size: ui(22),
                color: _kTextHint,
              ),
            ),
          ),
          // 姓名
          Positioned(
            left: ui(60),
            top: ui(8),
            child: Text(
              member.name,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          // 角色（紫字）
          Positioned(
            left: ui(108),
            top: ui(10),
            child: Text(
              member.role,
              style: TextStyle(
                fontSize: ui(12),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
          // 课程标签（仅任课）
          if (member.courseTag != null)
            Positioned(
              right: ui(12),
              top: ui(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(4),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: _kCoursePink,
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  member.courseTag!,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 15.24 / 12,
                  ),
                ),
              ),
            ),
          // 位置
          Positioned(
            left: ui(60),
            top: ui(32),
            child: SizedBox(
              width: ui(209),
              child: Text(
                member.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
          ),
          // 描述
          Positioned(
            left: ui(12),
            top: ui(57),
            child: SizedBox(
              width: ui(282),
              child: Text(
                member.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ),
          ),
          // 联系信息：电话 / 邮箱
          Positioned(
            left: ui(12),
            top: ui(96),
            child: Container(
              width: ui(284),
              padding: EdgeInsets.symmetric(
                horizontal: ui(2),
                vertical: ui(12),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ContactCol(label: '电话', value: member.phone),
                  ),
                  Expanded(
                    child: _ContactCol(label: '邮箱', value: member.email),
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

class _ContactCol extends StatelessWidget {
  const _ContactCol({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(9)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
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
// 同班同学
// =============================================================================

class _ClassmateData {
  const _ClassmateData({
    required this.name,
    required this.major,
    this.role,
    this.isSelf = false,
  });

  final String name;
  final String major;
  final String? role;

  /// 第一格固定为"自己"，强制带紫色"自己"标签，且头像走文字方块占位。
  final bool isSelf;
}

class _ClassmateSection extends StatelessWidget {
  const _ClassmateSection({
    required this.classmates,
    required this.query,
    required this.onQueryChanged,
  });

  final List<_ClassmateData> classmates;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filtered = query.trim().isEmpty
        ? classmates
        : classmates
              .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle('同班同学')),
            _ClassmateSearchBox(value: query, onChanged: onQueryChanged),
          ],
        ),
        SizedBox(height: ui(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: ui(40)),
                  child: Center(
                    child: Text(
                      '没有匹配的同学',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                )
              : Wrap(
                  spacing: ui(12),
                  runSpacing: ui(12),
                  children: [for (final c in filtered) _ClassmateCard(item: c)],
                ),
        ),
      ],
    );
  }
}

class _ClassmateSearchBox extends StatefulWidget {
  const _ClassmateSearchBox({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ClassmateSearchBox> createState() => _ClassmateSearchBoxState();
}

class _ClassmateSearchBoxState extends State<_ClassmateSearchBox> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _ClassmateSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级以非用户输入的方式重置搜索词时（例如未来"清空"按钮），同步 controller。
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(324),
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
              controller: _controller,
              onChanged: widget.onChanged,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '搜索名字',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kPlaceholder,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassmateCard extends StatelessWidget {
  const _ClassmateCard({required this.item});

  final _ClassmateData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final firstChar = item.name.isNotEmpty ? item.name.characters.first : '?';
    final showInitial = item.isSelf || _shouldUseInitial(item.name);
    return Container(
      width: ui(124),
      height: ui(124),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        children: [
          SizedBox(height: ui(8)),
          // 头像：紫色文字方块占位 / 灰色 person 占位
          Container(
            width: ui(36),
            height: ui(36),
            decoration: BoxDecoration(
              color: showInitial ? _kPurpleAvatar : Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            alignment: Alignment.center,
            child: showInitial
                ? Text(
                    firstChar,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  )
                : Icon(Icons.person_rounded, size: ui(20), color: _kTextHint),
          ),
          SizedBox(height: ui(8)),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 20 / 14,
            ),
          ),
          Text(
            item.major,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 12,
            ),
          ),
          if (item.isSelf || (item.role != null && item.role!.isNotEmpty))
            Padding(
              padding: EdgeInsets.only(top: ui(4)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: _kSelfTagBg,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
                child: Text(
                  item.isSelf ? '自己' : item.role!,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 演示：约 30% 的同学卡片走"姓首字母 + 紫底"，剩余走灰底 person 占位，
  /// 与 Figma 中两种头像样式比例大致一致。
  static bool _shouldUseInitial(String name) {
    if (name.isEmpty) return false;
    return name.codeUnits.fold<int>(0, (a, b) => a + b) % 4 == 0;
  }
}

// =============================================================================
// 通用：段标题、带 Action 的段标题
// =============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        color: _kTextSection,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle(title)),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(ui(4)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(2), vertical: ui(2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: ui(16),
                  color: _kTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Demo 数据
// =============================================================================

const _ClassInfoData _kDemoClass = _ClassInfoData(
  name: '高三音乐实验班',
  subtitle: '高三年级·主项声乐·副项钢琴(演示)',
  headTeacher: '李老师',
  counselor: '张辅导员',
  classroom: '艺术楼3号楼8楼803',
  footer: '教务与艺术实践办公室·列表展示12/42人',
  totalCount: 64,
  boyCount: 23,
  girlCount: 41,
);

const String _kDemoTeacherDesc = '负责本专业教学运行、排课与考务协调；有事可先通过班主任汇总。';

const List<_FacultySectionData> _kDemoFacultySections = [
  _FacultySectionData(
    title: '教务老师',
    members: [
      _FacultyMember(
        name: '王老师',
        role: '教务统筹',
        location: '形体房3号办公室502桌',
        description: _kDemoTeacherDesc,
        phone: '18774276813',
        email: 'npwokszehss@139.com',
      ),
      _FacultyMember(
        name: '王老师',
        role: '教务统筹',
        location: '形体房3号办公室502桌',
        description: _kDemoTeacherDesc,
        phone: '17028813170',
        email: 'ksnezowshp@gmail.com',
      ),
    ],
  ),
  _FacultySectionData(
    title: '班主任',
    members: [
      _FacultyMember(
        name: '王老师',
        role: '班主任',
        location: '形体房3号办公室502桌',
        description: _kDemoTeacherDesc,
        phone: '13176645408',
        email: 'npssw@hotmail.com',
      ),
    ],
  ),
  _FacultySectionData(
    title: '任课老师',
    members: [
      _FacultyMember(
        name: '王老师',
        role: '任课老师',
        location: '形体房3号办公室502桌',
        description: _kDemoTeacherDesc,
        phone: '13126245985',
        email: 'sowshp@gmail.com',
        courseTag: '形体课',
      ),
      _FacultyMember(
        name: '李老师',
        role: '任课老师',
        location: '形体房3号办公室502桌',
        description: _kDemoTeacherDesc,
        phone: '13809981987',
        email: 'zskohswe@163.com',
        courseTag: '形体课',
      ),
      _FacultyMember(
        name: '马老师',
        role: '任课老师',
        location: '形体房3号办公室502桌',
        description: _kDemoTeacherDesc,
        phone: '13338170101',
        email: 'dssohp@qq.com',
        courseTag: '形体课',
      ),
    ],
  ),
];

const List<_ClassmateData> _kDemoClassmates = [
  _ClassmateData(name: '李思涵', major: '钢琴主项', isSelf: true),
  _ClassmateData(name: '王琴', major: '声乐主项', role: '学习委员'),
  _ClassmateData(name: '张音铭', major: '钢琴主项', role: '班长'),
  _ClassmateData(name: '周静', major: '钢琴主项', role: '纪律委员'),
  _ClassmateData(name: '赖军', major: '钢琴主项', role: '副班长'),
  _ClassmateData(name: '贾涛', major: '钢琴主项', role: '艺术委员'),
  _ClassmateData(name: '郑娟', major: '钢琴主项', role: '团委书记'),
  _ClassmateData(name: '刘娟', major: '钢琴主项'),
  _ClassmateData(name: '蒋欣', major: '声乐主项', role: '副班长'),
  _ClassmateData(name: '赵敏', major: '钢琴主项'),
  _ClassmateData(name: '崔静', major: '钢琴主项', role: '体育委员'),
  _ClassmateData(name: '黄娟', major: '钢琴主项'),
  _ClassmateData(name: '王杰', major: '钢琴主项', role: '学习委员'),
  _ClassmateData(name: '周涛', major: '钢琴主项', role: '作业委员'),
  _ClassmateData(name: '杨颖', major: '钢琴主项'),
  _ClassmateData(name: '杨军', major: '声乐主项', role: '卫生委员'),
  _ClassmateData(name: '陶丽', major: '钢琴主项'),
  _ClassmateData(name: '崔静', major: '钢琴主项'),
  _ClassmateData(name: '郑丽', major: '钢琴主项'),
  _ClassmateData(name: '邵军', major: '钢琴主项'),
  _ClassmateData(name: '杨军', major: '钢琴主项'),
];
