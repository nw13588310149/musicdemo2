// =============================================================================
// 学生端「我的成绩」独立页面
//
// 入口：学生 dashboard 快捷区「我的成绩」按钮 → controller.openMyGrades()
//      → mainView == myGrades + role == student → SmartCampusPage 路由到
//      本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变，左 32 返回 + 中标题
//      "成绩与排名" 16px 600，右侧 "本学期/上学期" 双 tab pills（44 高
//      白色容器 + #F3F2F3 描边，激活态 #0B081A 黑底 / 白字）。
//   2. 4 张 100 高统计卡（一行平铺，gap 12）：
//      A. 白底「学年考试均分」14 + 数值 32 + 进度条（86/118 紫色填充）
//         + 灰小字 "各次月考/大考总均分平均"
//      B. 紫渐变「最近班级」14 + 数值 32 + "/42" + 紫"持平"tag（横线图标）
//      C. 绿渐变「最近年级」14 + 数值 32 + "/368" + 绿"上升3名"tag（上升箭头）
//      D. 白底「本学期最佳考试」14 + 紫色 20px "六月摸底考试" + 紫底
//         "均分 91分" tag
//   3. 双列卡：
//      左 640「6次考试 折线趋势」（496 高白卡）：
//         · 顶部科目 tabs（总均分 / 主项 / 副项 / 听写 / 乐理 / 视唱）
//         · 左 Y 轴标签 100/95/90/85/80/0（80→0 用一段压缩刻度）
//         · 6 个数据点（86/87/86.5/91/93/90），紫线 + 紫渐变填充
//         · 每点上方紫色数值标签
//         · 底部 X 轴 6 个月份标签（2月 / 3月 / 4月 / 5月 / 期中 / 6月）
//         · 下方"每场·总成绩排名 (班级/全校)" + 6 列紧凑统计单元
//      右 318「场次均分分布」（496 高白卡）：5 段灰底面板，
//         区间标签 + 占比% + 紫色渐变进度条 + 右下"X场"
//   4. 「考试记录与各科成绩」2 列 × 多行卡片网格（每张 477 宽）：
//      - 表头：「X月月考」16 + 日期灰字 + 折叠图标按钮
//      - 5 项一排统计 (12px)：总均分 / 及格科数 / 优秀科数 / 班级排名 / 全校排名
//      - 展开态：4 张科目子卡（声乐紫 / 器乐紫 / 视唱绿 / 乐理绿），
//        含 老师名 + 科目 tag + 班/全校排名 + 教师评语 + 录像/录音/无录制
//        tag + 蓝色右上角分数 + "查看详情"按钮
//      - 折叠态：仅头 + 统计行
//
// 颜色：白卡 / #F5F6FA 浅灰 / #8741FF 主紫 / #325BFF 蓝（科目分数）
//      / #0CAC40 绿 / #DFFCF0 绿底（视唱/乐理 tag） / #EAE5FF 紫底（声乐/器乐）
//      / #12CE51 上升绿 / #F4F4FF 进度条底 / #E2D0FF→#8741FF 进度条渐变
// 字体：PingFang SC（中文） + Barlow（数字 32 / 20）
// =============================================================================

import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kCardBg = Colors.white;
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFA773FF);
const Color _kPurpleSoftBg = Color(0xFFEAE5FF);
const Color _kPurpleBestBg = Color(0xFFF7F2FF);
const Color _kProgressBg = Color(0xFFF4F4FF);
const Color _kBlueScore = Color(0xFF325BFF);
const Color _kSubjectGreen = Color(0xFF0CAC40);
const Color _kSubjectGreenBg = Color(0xFFDFFCF0);
const Color _kRiseGreen = Color(0xFF12CE51);
const Color _kAxisLabel = Color(0xFFB6B5BB);

// =============================================================================
// 顶级视图
// =============================================================================

class StudentMyGradesView extends StatefulWidget {
  const StudentMyGradesView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<StudentMyGradesView> createState() => _StudentMyGradesViewState();
}

class _StudentMyGradesViewState extends State<StudentMyGradesView> {
  _SemesterTab _semester = _SemesterTab.current;
  _LineSubject _lineSubject = _LineSubject.total;

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
            _GradesBanner(
              onBack: widget.onBack,
              selected: _semester,
              onSelected: (v) => setState(() => _semester = v),
            ),
            SizedBox(height: ui(16)),
            const _GradesStatsRow(),
            SizedBox(height: ui(16)),
            _DualPanelRow(
              lineSubject: _lineSubject,
              onLineSubjectChanged: (v) => setState(() => _lineSubject = v),
            ),
            SizedBox(height: ui(16)),
            const _ExamRecordsSection(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner：返回 / 标题 / 学期 tabs
// =============================================================================

enum _SemesterTab { current, previous }

class _GradesBanner extends StatelessWidget {
  const _GradesBanner({
    required this.onBack,
    required this.selected,
    required this.onSelected,
  });

  final VoidCallback onBack;
  final _SemesterTab selected;
  final ValueChanged<_SemesterTab> onSelected;

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
            child: Center(
              child: Text(
                '成绩与排名',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          _SemesterTabs(selected: selected, onSelected: onSelected),
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

class _SemesterTabs extends StatelessWidget {
  const _SemesterTabs({required this.selected, required this.onSelected});

  final _SemesterTab selected;
  final ValueChanged<_SemesterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget pill(_SemesterTab tab, String label) {
      final active = selected == tab;
      return GestureDetector(
        onTap: () => onSelected(tab),
        behavior: HitTestBehavior.opaque,
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

    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(_SemesterTab.current, '本学期'),
          SizedBox(width: ui(8)),
          pill(_SemesterTab.previous, '上学期'),
        ],
      ),
    );
  }
}

// =============================================================================
// 4 张统计卡
// =============================================================================

class _GradesStatsRow extends StatelessWidget {
  const _GradesStatsRow();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _AverageCard()),
                  SizedBox(width: ui(12)),
                  Expanded(child: _ClassRankCard()),
                ],
              ),
              SizedBox(height: ui(12)),
              Row(
                children: [
                  Expanded(child: _GradeRankCard()),
                  SizedBox(width: ui(12)),
                  Expanded(child: _BestExamCard()),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _AverageCard()),
            SizedBox(width: ui(12)),
            Expanded(child: _ClassRankCard()),
            SizedBox(width: ui(12)),
            Expanded(child: _GradeRankCard()),
            SizedBox(width: ui(12)),
            Expanded(child: _BestExamCard()),
          ],
        );
      },
    );
  }
}

// 卡 A：学年考试均分（白底 + 进度条）
class _AverageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(14)),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              '学年考试均分',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: ui(28),
            child: Text(
              '32',
              style: TextStyle(
                fontSize: ui(32),
                color: _kTextDark,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(64),
            right: 0,
            top: ui(36),
            child: Text(
              '各次月考/大考总均分平均',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextDivider,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(64),
            right: 0,
            bottom: ui(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(20)),
              child: Stack(
                children: [
                  Container(height: ui(8), color: _kProgressBg),
                  FractionallySizedBox(
                    widthFactor: 0.73,
                    child: Container(height: ui(8), color: _kPurpleLight),
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

// 卡 B / C：最近班级 / 最近年级（紫渐变 / 绿渐变 + 右上 tag）
class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.title,
    required this.value,
    required this.totalSuffix,
    required this.gradient,
    required this.badge,
  });

  factory _RankCard.classRank() => const _RankCard(
    title: '最近班级',
    value: '8',
    totalSuffix: '/42',
    gradient: LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [Color(0x239346FF), Color(0x00FFFFFF)],
    ),
    badge: _RankBadge.flat(),
  );

  factory _RankCard.gradeRank() => const _RankCard(
    title: '最近年级',
    value: '62',
    totalSuffix: '/368',
    gradient: LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [Color(0x2E46FF77), Color(0x00FFFFFF)],
    ),
    badge: _RankBadge.rise('上升3名'),
  );

  final String title;
  final String value;
  final String totalSuffix;
  final Gradient gradient;
  final _RankBadge badge;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        gradient: gradient,
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ui(32),
                    color: _kTextDark,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                SizedBox(width: ui(2)),
                Padding(
                  padding: EdgeInsets.only(bottom: ui(2)),
                  child: Text(
                    totalSuffix,
                    style: TextStyle(
                      fontSize: ui(20),
                      color: _kTextDivider,
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(right: ui(12), top: ui(14), child: badge.build(context)),
        ],
      ),
    );
  }
}

class _ClassRankCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _RankCard.classRank();
}

class _GradeRankCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _RankCard.gradeRank();
}

class _RankBadge {
  const _RankBadge.flat() : isFlat = true, text = '持平', color = _kPurple;

  const _RankBadge.rise(this.text) : isFlat = false, color = _kRiseGreen;

  final bool isFlat;
  final String text;
  final Color color;

  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(24),
      padding: EdgeInsets.symmetric(horizontal: ui(8)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFlat)
            Container(width: ui(8), height: 1, color: color)
          else
            Icon(Icons.trending_up_rounded, size: ui(12), color: color),
          SizedBox(width: ui(4)),
          Text(
            text,
            style: TextStyle(
              fontSize: ui(11),
              color: color,
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

// 卡 D：本学期最佳考试
class _BestExamCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            child: Text(
              '本学期最佳考试',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(50),
            right: ui(12),
            child: Text(
              '六月摸底考试',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(20),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(14),
            child: Container(
              height: ui(24),
              padding: EdgeInsets.symmetric(horizontal: ui(8)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPurpleBestBg,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '均分 ',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                  Text(
                    '91分',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1,
                    ),
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

// =============================================================================
// 双列：折线趋势 + 分数段分布
// =============================================================================

class _DualPanelRow extends StatelessWidget {
  const _DualPanelRow({
    required this.lineSubject,
    required this.onLineSubjectChanged,
  });

  final _LineSubject lineSubject;
  final ValueChanged<_LineSubject> onLineSubjectChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(820);
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('6次考试 折线趋势'),
              SizedBox(height: ui(12)),
              _LineChartCard(
                subject: lineSubject,
                onSubjectChanged: onLineSubjectChanged,
              ),
              SizedBox(height: ui(20)),
              const _SectionTitle('场次均分分布'),
              SizedBox(height: ui(12)),
              const _ScoreDistributionCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('6次考试 折线趋势'),
                  SizedBox(height: ui(12)),
                  _LineChartCard(
                    subject: lineSubject,
                    onSubjectChanged: onLineSubjectChanged,
                  ),
                ],
              ),
            ),
            SizedBox(width: ui(12)),
            Expanded(
              flex: 318,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('场次均分分布'),
                  SizedBox(height: ui(12)),
                  const _ScoreDistributionCard(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

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
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.2,
      ),
    );
  }
}

// =============================================================================
// 折线图卡（左 640 宽 / 496 高）
// =============================================================================

enum _LineSubject { total, major, minor, dictation, theory, sightSinging }

const _kLineSubjectLabels = <_LineSubject, String>{
  _LineSubject.total: '总均分',
  _LineSubject.major: '主项',
  _LineSubject.minor: '副项',
  _LineSubject.dictation: '听写',
  _LineSubject.theory: '乐理',
  _LineSubject.sightSinging: '视唱',
};

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({required this.subject, required this.onSubjectChanged});

  final _LineSubject subject;
  final ValueChanged<_LineSubject> onSubjectChanged;

  static const _months = <String>['2月', '3月', '4月', '5月', '期中', '6月'];
  static const _values = <double>[86, 87, 86.5, 91, 93, 90];
  static const _classRanks = <int>[11, 11, 11, 11, 11, 11];
  static const _schoolRanks = <int>[178, 178, 178, 178, 178, 178];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(496),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LineSubjectTabs(selected: subject, onSelected: onSubjectChanged),
          SizedBox(height: ui(8)),
          Expanded(
            child: _LineChartArea(months: _months, values: _values),
          ),
          SizedBox(height: ui(8)),
          _RankRowHeader(),
          SizedBox(height: ui(6)),
          _RankCellRow(
            months: _months,
            values: _values,
            classRanks: _classRanks,
            schoolRanks: _schoolRanks,
          ),
        ],
      ),
    );
  }
}

class _LineSubjectTabs extends StatelessWidget {
  const _LineSubjectTabs({required this.selected, required this.onSelected});

  final _LineSubject selected;
  final ValueChanged<_LineSubject> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _kLineSubjectLabels.entries) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(entry.key),
                child: _LineTabChip(
                  label: entry.value,
                  active: selected == entry.key,
                ),
              ),
              SizedBox(width: ui(8)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineTabChip extends StatelessWidget {
  const _LineTabChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(36),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(ui(6)),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xB5B5B5B5).withValues(alpha: 0.35),
                  blurRadius: ui(20),
                  offset: Offset(0, ui(8)),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(14),
          color: active ? _kTextDark : _kTextSecondary,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// 折线图绘制区
class _LineChartArea extends StatelessWidget {
  const _LineChartArea({required this.months, required this.values});

  final List<String> months;
  final List<double> values;

  static const _ticks = <int>[100, 95, 90, 85, 80, 0];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final axisLabelW = ui(28);
        final xLabelH = ui(20);
        final chartW = (w - axisLabelW).clamp(0.0, double.infinity);
        final chartH = (h - xLabelH).clamp(0.0, double.infinity);
        const tickCount = 6;
        final tickGap = chartH / (tickCount - 1);

        // 80→100 区间映射到上方 5/6 高度，最后 1/6 高度压缩 80→0。
        double yForValue(double v) {
          if (v >= 80) {
            final ratio = (100 - v) / 20.0;
            return ratio * (chartH * 5 / (tickCount - 1));
          }
          return chartH;
        }

        final n = values.length;
        final cellW = chartW / n;
        final points = <Offset>[
          for (var i = 0; i < n; i++)
            Offset(axisLabelW + cellW * (i + 0.5), yForValue(values[i])),
        ];

        return Stack(
          children: [
            // Y 轴标签
            for (var i = 0; i < tickCount; i++)
              Positioned(
                left: 0,
                top: i * tickGap - ui(10),
                width: ui(20),
                child: Text(
                  '${_ticks[i]}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kAxisLabel,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 12,
                  ),
                ),
              ),
            // 折线 + 渐变填充
            Positioned.fill(
              bottom: xLabelH,
              child: CustomPaint(
                painter: _LinePainter(points: points, chartHeight: chartH),
              ),
            ),
            // 数值标签（紫色 12px）位于点上方
            for (var i = 0; i < points.length; i++)
              Positioned(
                left: points[i].dx - ui(20),
                top: points[i].dy - ui(20),
                width: ui(40),
                child: Text(
                  values[i] == values[i].roundToDouble()
                      ? values[i].toInt().toString()
                      : values[i].toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 12,
                  ),
                ),
              ),
            // X 轴月份标签
            Positioned(
              left: axisLabelW,
              right: 0,
              bottom: 0,
              height: xLabelH,
              child: Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          months[i],
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 20 / 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.points, required this.chartHeight});

  final List<Offset> points;
  final double chartHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Build smooth path
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cx = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Fill path: extend to bottom
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE7D9FF), Color(0x00E7D9FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = _kPurple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, strokePaint);

    // Dots
    final dotFill = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = _kPurple
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotFill);
      canvas.drawCircle(p, 4, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.chartHeight != chartHeight;
}

// 折线图下方：每场·总成绩排名（班级/全校）行头
class _RankRowHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(2)),
      child: Row(
        children: [
          Text(
            '每场·总成绩排名 (班级/全校)',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            '班级总人数：42',
            style: TextStyle(
              fontSize: ui(10),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(width: ui(20)),
          Text(
            '全校总人数：368',
            style: TextStyle(
              fontSize: ui(10),
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

class _RankCellRow extends StatelessWidget {
  const _RankCellRow({
    required this.months,
    required this.values,
    required this.classRanks,
    required this.schoolRanks,
  });

  final List<String> months;
  final List<double> values;
  final List<int> classRanks;
  final List<int> schoolRanks;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(100),
      child: Row(
        children: [
          for (var i = 0; i < months.length; i++) ...[
            if (i > 0) SizedBox(width: ui(8)),
            Expanded(
              child: _RankCell(
                month: months[i],
                value: values[i],
                classRank: classRanks[i],
                schoolRank: schoolRanks[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankCell extends StatelessWidget {
  const _RankCell({
    required this.month,
    required this.value,
    required this.classRank,
    required this.schoolRank,
  });

  final String month;
  final double value;
  final int classRank;
  final int schoolRank;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      padding: EdgeInsets.fromLTRB(ui(8), ui(4), ui(8), ui(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            month,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            value == value.roundToDouble()
                ? value.toInt().toString()
                : value.toString(),
            style: TextStyle(
              fontSize: ui(20),
              color: _kPurple,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          SizedBox(height: ui(4)),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(6)),
            ),
            padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(4)),
            child: Column(
              children: [
                _MiniStatRow(label: '班级：', value: '$classRank'),
                _MiniStatRow(label: '全校：', value: '$schoolRank'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
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

// =============================================================================
// 场次均分分布（右 318 宽 / 496 高）
// =============================================================================

class _ScoreDistributionCard extends StatelessWidget {
  const _ScoreDistributionCard();

  static const _segments = <_ScoreSegment>[
    _ScoreSegment(label: '90-100分', percent: 33, count: 3),
    _ScoreSegment(label: '80-90分', percent: 33, count: 3),
    _ScoreSegment(label: '70-80分', percent: 15, count: 1),
    _ScoreSegment(label: '60-70分', percent: 0, count: 0),
    _ScoreSegment(label: '<60分', percent: 0, count: 0),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(496),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        children: [
          for (var i = 0; i < _segments.length; i++) ...[
            if (i > 0) SizedBox(height: ui(12)),
            Expanded(child: _ScoreSegmentTile(segment: _segments[i])),
          ],
        ],
      ),
    );
  }
}

class _ScoreSegment {
  const _ScoreSegment({
    required this.label,
    required this.percent,
    required this.count,
  });

  final String label;
  final int percent; // 0~100
  final int count;
}

class _ScoreSegmentTile extends StatelessWidget {
  const _ScoreSegmentTile({required this.segment});

  final _ScoreSegment segment;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fraction = (segment.percent / 100).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      padding: EdgeInsets.fromLTRB(ui(14), ui(13), ui(14), ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                segment.label,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${segment.percent}%',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(11)),
            child: SizedBox(
              height: ui(8),
              child: Stack(
                children: [
                  Container(color: _kBorderHair),
                  if (fraction > 0)
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [_kPurple, Color(0xFFE2D0FF)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: ui(8)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${segment.count}场',
              style: TextStyle(
                fontSize: ui(12),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
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
// 考试记录与各科成绩（2 列网格）
// =============================================================================

class _ExamRecordsSection extends StatelessWidget {
  const _ExamRecordsSection();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('考试记录与各科成绩'),
        SizedBox(height: ui(12)),
        _ExamRecordsGrid(records: _kDemoExams),
      ],
    );
  }
}

class _ExamRecordsGrid extends StatelessWidget {
  const _ExamRecordsGrid({required this.records});

  final List<_ExamRecordData> records;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        final cols = isCompact ? 1 : 2;
        final gap = ui(16);
        final cardW = (c.maxWidth - gap * (cols - 1)) / cols;

        final rows = <Widget>[];
        for (var i = 0; i < records.length; i += cols) {
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: ui(12)));
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) SizedBox(width: gap),
                  SizedBox(
                    width: cardW,
                    child: i + j < records.length
                        ? _ExamRecordCard(record: records[i + j])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

// =============================================================================
// 单张考试记录卡
// =============================================================================

class _ExamRecordCard extends StatefulWidget {
  const _ExamRecordCard({required this.record});

  final _ExamRecordData record;

  @override
  State<_ExamRecordCard> createState() => _ExamRecordCardState();
}

class _ExamRecordCardState extends State<_ExamRecordCard> {
  late bool _expanded = widget.record.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExamCardHeader(
            title: widget.record.title,
            date: widget.record.date,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
          SizedBox(height: ui(8)),
          _ExamSummaryRow(record: widget.record),
          if (_expanded && widget.record.subjects.isNotEmpty) ...[
            for (final s in widget.record.subjects) ...[
              SizedBox(height: ui(8)),
              _ExamSubjectTile(data: s),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExamCardHeader extends StatelessWidget {
  const _ExamCardHeader({
    required this.title,
    required this.date,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final String date;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: ui(16),
            color: Colors.black,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
        ),
        SizedBox(width: ui(12)),
        Text(
          date,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDivider,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onToggle,
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
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: ui(18),
              color: _kTextDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamSummaryRow extends StatelessWidget {
  const _ExamSummaryRow({required this.record});

  final _ExamRecordData record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final stats = <(String, String)>[
      ('总均分', record.totalAvg),
      ('及格科数', '${record.passCount}'),
      ('优秀科数', '${record.excellentCount}'),
      ('班级排名', '${record.classRank}'),
      ('全校排名', '${record.schoolRank}'),
    ];
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: ui(4)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  stats[i].$1,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: ui(4)),
                Text(
                  stats[i].$2,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// 考试卡内的科目子卡
// =============================================================================

class _ExamSubjectTile extends StatelessWidget {
  const _ExamSubjectTile({required this.data});

  final _ExamSubjectData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    data.teacher,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  _SubjectTag(subject: data.subject),
                ],
              ),
              SizedBox(height: ui(8)),
              Row(
                children: [
                  Text(
                    '班级排名：${data.classRank}',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(12)),
                  Container(width: 1, height: ui(10), color: _kTextHint),
                  SizedBox(width: ui(12)),
                  Text(
                    '全校排名：${data.schoolRank}',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                data.comment,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
              SizedBox(height: ui(8)),
              _MediaTag(kind: data.media),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Text(
              '${data.score}分',
              style: TextStyle(
                fontSize: ui(14),
                color: _kBlueScore,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          Positioned(right: 0, bottom: 0, child: _ViewDetailButton()),
        ],
      ),
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.subject});

  final _SubjectKind subject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPurple =
        subject == _SubjectKind.vocal || subject == _SubjectKind.instrument;
    final bg = isPurple ? _kPurpleSoftBg : _kSubjectGreenBg;
    final fg = isPurple ? _kPurple : _kSubjectGreen;
    final label = switch (subject) {
      _SubjectKind.vocal => '声乐',
      _SubjectKind.instrument => '器乐',
      _SubjectKind.sightSinging => '视唱',
      _SubjectKind.theory => '乐理',
    };
    return Container(
      height: ui(16),
      padding: EdgeInsets.symmetric(horizontal: ui(4)),
      alignment: Alignment.center,
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

class _MediaTag extends StatelessWidget {
  const _MediaTag({required this.kind});

  final _ReplayMedia kind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (bg, fg, label, icon) = switch (kind) {
      _ReplayMedia.video => (
        _kPurpleSoftBg,
        _kPurple,
        '可回看录像',
        Icons.videocam_outlined,
      ),
      _ReplayMedia.audio => (
        _kPurpleSoftBg,
        _kPurple,
        '可回听录音',
        Icons.mic_none_rounded,
      ),
      _ReplayMedia.none => (_kBorderHair, _kTextHint, '本场无回放录制', null),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: ui(12), color: fg),
            SizedBox(width: ui(2)),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: ui(11),
              color: fg,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 15.24 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewDetailButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(80),
      height: ui(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        '查看详情',
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 16 / 12,
        ),
      ),
    );
  }
}

// =============================================================================
// 数据模型 + Demo
// =============================================================================

enum _SubjectKind { vocal, instrument, sightSinging, theory }

enum _ReplayMedia { video, audio, none }

class _ExamSubjectData {
  const _ExamSubjectData({
    required this.teacher,
    required this.subject,
    required this.classRank,
    required this.schoolRank,
    required this.comment,
    required this.score,
    required this.media,
  });

  final String teacher;
  final _SubjectKind subject;
  final int classRank;
  final int schoolRank;
  final String comment;
  final int score;
  final _ReplayMedia media;
}

class _ExamRecordData {
  const _ExamRecordData({
    required this.title,
    required this.date,
    required this.totalAvg,
    required this.passCount,
    required this.excellentCount,
    required this.classRank,
    required this.schoolRank,
    required this.subjects,
    this.initiallyExpanded = false,
  });

  final String title;
  final String date;
  final String totalAvg;
  final int passCount;
  final int excellentCount;
  final int classRank;
  final int schoolRank;
  final List<_ExamSubjectData> subjects;
  final bool initiallyExpanded;
}

const _kDemoSubjects = <_ExamSubjectData>[
  _ExamSubjectData(
    teacher: '刘老师',
    subject: _SubjectKind.vocal,
    classRank: 8,
    schoolRank: 88,
    comment: '寒假回课状态好，咬字再收',
    score: 88,
    media: _ReplayMedia.video,
  ),
  _ExamSubjectData(
    teacher: '刘老师',
    subject: _SubjectKind.instrument,
    classRank: 8,
    schoolRank: 88,
    comment: '寒假回课状态好，咬字再收',
    score: 92,
    media: _ReplayMedia.video,
  ),
  _ExamSubjectData(
    teacher: '陈老师',
    subject: _SubjectKind.sightSinging,
    classRank: 8,
    schoolRank: 88,
    comment: '寒假回课状态好，咬字再收',
    score: 78,
    media: _ReplayMedia.audio,
  ),
  _ExamSubjectData(
    teacher: '刘老师',
    subject: _SubjectKind.theory,
    classRank: 8,
    schoolRank: 88,
    comment: '寒假回课状态好，咬字再收',
    score: 83,
    media: _ReplayMedia.none,
  ),
];

const _kDemoExams = <_ExamRecordData>[
  _ExamRecordData(
    title: '2月月考',
    date: '2026-02-24',
    totalAvg: '86',
    passCount: 3,
    excellentCount: 1,
    classRank: 11,
    schoolRank: 78,
    subjects: _kDemoSubjects,
    initiallyExpanded: true,
  ),
  _ExamRecordData(
    title: '3月月考',
    date: '2026-03-24',
    totalAvg: '87',
    passCount: 3,
    excellentCount: 1,
    classRank: 11,
    schoolRank: 78,
    subjects: _kDemoSubjects,
    initiallyExpanded: true,
  ),
  _ExamRecordData(
    title: '4月月考',
    date: '2026-04-21',
    totalAvg: '86.5',
    passCount: 3,
    excellentCount: 1,
    classRank: 11,
    schoolRank: 78,
    subjects: _kDemoSubjects,
  ),
  _ExamRecordData(
    title: '5月月考',
    date: '2026-05-15',
    totalAvg: '91',
    passCount: 4,
    excellentCount: 2,
    classRank: 8,
    schoolRank: 62,
    subjects: _kDemoSubjects,
  ),
  _ExamRecordData(
    title: '期中考试',
    date: '2026-04-30',
    totalAvg: '93',
    passCount: 4,
    excellentCount: 3,
    classRank: 6,
    schoolRank: 48,
    subjects: _kDemoSubjects,
  ),
  _ExamRecordData(
    title: '六月摸底考试',
    date: '2026-06-10',
    totalAvg: '90',
    passCount: 4,
    excellentCount: 3,
    classRank: 8,
    schoolRank: 62,
    subjects: _kDemoSubjects,
  ),
];
