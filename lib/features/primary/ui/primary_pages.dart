import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../ai_chat/ui/ai_chat_page.dart';

class PrimaryCardData {
  const PrimaryCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
    this.badgeText,
    this.accent = const Color(0xFF00C9A4),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  final String? badgeText;
  final Color accent;
}

class PrimaryStatData {
  const PrimaryStatData({required this.label, required this.value});

  final String label;
  final String value;
}

class PersonalAiPage extends StatelessWidget {
  const PersonalAiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AiChatPage();
  }
}

class SchoolCoursewarePage extends StatelessWidget {
  const SchoolCoursewarePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '校园课件',
      subtitle: '学校课件与课堂资料集中管理',
      stats: [
        PrimaryStatData(label: '本周新增', value: '14 份'),
        PrimaryStatData(label: '待学习', value: '6 份'),
        PrimaryStatData(label: '教师更新', value: '3 条'),
      ],
      cards: [
        PrimaryCardData(
          title: '课堂课件',
          subtitle: '按班级和课程筛选本周最新课件',
          icon: Icons.menu_book_rounded,
          route: RoutePaths.courseware,
        ),
        PrimaryCardData(
          title: '课堂通知',
          subtitle: '查看教师通知和作业要求',
          icon: Icons.campaign_rounded,
          route: RoutePaths.smartCampus,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '课堂回放',
          subtitle: '快速回看老师讲解重点片段',
          icon: Icons.live_tv_rounded,
          route: RoutePaths.videoTutorial,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class CoursewarePage extends StatelessWidget {
  const CoursewarePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '我的云盘',
      subtitle: '课件、音频、笔记和附件的一站式管理',
      stats: [
        PrimaryStatData(label: '总文件', value: '126'),
        PrimaryStatData(label: '已用空间', value: '6.8 GB'),
        PrimaryStatData(label: '最近上传', value: '今天'),
      ],
      cards: [
        PrimaryCardData(
          title: '最近文件',
          subtitle: '查看最近 7 天上传或编辑文件',
          icon: Icons.folder_open_rounded,
          route: RoutePaths.detail,
        ),
        PrimaryCardData(
          title: '共享文件',
          subtitle: '老师和同学共享资料中心',
          icon: Icons.groups_rounded,
          route: RoutePaths.detail2,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '我的收藏',
          subtitle: '快速访问常用谱例和音频',
          icon: Icons.star_rounded,
          route: RoutePaths.myCollection,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class VideoTutorialPage extends StatelessWidget {
  const VideoTutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '视频中心',
      subtitle: '按主题浏览课程视频和示范片段',
      stats: [
        PrimaryStatData(label: '推荐视频', value: '24'),
        PrimaryStatData(label: '继续观看', value: '3'),
        PrimaryStatData(label: '学习时长', value: '2h 18m'),
      ],
      cards: [
        PrimaryCardData(
          title: '今日推荐',
          subtitle: '基于学习计划推荐视频',
          icon: Icons.play_circle_fill_rounded,
          route: RoutePaths.videoTutorial,
        ),
        PrimaryCardData(
          title: '分级教程',
          subtitle: '按初级、中级、高级筛选',
          icon: Icons.stacked_line_chart_rounded,
          route: RoutePaths.musicTheory,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '课程回顾',
          subtitle: '回顾已完成课程关键点',
          icon: Icons.history_rounded,
          route: RoutePaths.consultationDetail,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class SmartDictationPage extends StatelessWidget {
  const SmartDictationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '智能听写',
      subtitle: '专项练习、自动判分与错题追踪',
      stats: [
        PrimaryStatData(label: '今日练习', value: '5 组'),
        PrimaryStatData(label: '平均得分', value: '87'),
        PrimaryStatData(label: '错题数', value: '12'),
      ],
      cards: [
        PrimaryCardData(
          title: '开始练习',
          subtitle: '进入听写题目并实时记录作答',
          icon: Icons.headphones_rounded,
          route: RoutePaths.answer,
        ),
        PrimaryCardData(
          title: '模拟考试',
          subtitle: '限时完整流程检验水平',
          icon: Icons.timer_rounded,
          route: RoutePaths.mock,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '练习结果',
          subtitle: '查看错题与复习建议',
          icon: Icons.analytics_rounded,
          route: RoutePaths.over,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class MusicCompanionPage extends StatelessWidget {
  const MusicCompanionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '音乐伙伴',
      subtitle: '演奏、练习和作品管理工具集合',
      stats: [
        PrimaryStatData(label: '今日练习', value: '48 分钟'),
        PrimaryStatData(label: '节拍稳定度', value: '91%'),
        PrimaryStatData(label: '推荐曲目', value: '7 首'),
      ],
      cards: [
        PrimaryCardData(
          title: '节拍器',
          subtitle: '多拍号和速度区间练习',
          icon: Icons.graphic_eq_rounded,
          badgeText: '工具',
        ),
        PrimaryCardData(
          title: '曲谱播放',
          subtitle: '跟随曲谱进行分段练习',
          icon: Icons.queue_music_rounded,
          route: RoutePaths.musicPlay,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '声乐训练',
          subtitle: '基于音高反馈完成训练',
          icon: Icons.mic_rounded,
          route: RoutePaths.voice,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class SmartCampusPage extends StatelessWidget {
  const SmartCampusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '智慧校园',
      subtitle: '通知、签到、班级沟通和校园事务入口',
      stats: [
        PrimaryStatData(label: '未读通知', value: '3'),
        PrimaryStatData(label: '待签到', value: '1'),
        PrimaryStatData(label: '请假审批', value: '2'),
      ],
      cards: [
        PrimaryCardData(
          title: '签到记录',
          subtitle: '查看个人和班级签到情况',
          icon: Icons.event_available_rounded,
          route: RoutePaths.smartCampusSignRecords,
        ),
        PrimaryCardData(
          title: '签到审批',
          subtitle: '处理补签和请假审批',
          icon: Icons.fact_check_rounded,
          route: RoutePaths.smartCampusSignApprovals,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '班级聊天',
          subtitle: '发布通知并参与班级交流',
          icon: Icons.chat_bubble_rounded,
          route: RoutePaths.chat,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class MyNotesPage extends StatelessWidget {
  const MyNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '我的笔记',
      subtitle: '课堂记录、重点标记和复习清单',
      stats: [
        PrimaryStatData(label: '总笔记', value: '54'),
        PrimaryStatData(label: '本周新增', value: '8'),
        PrimaryStatData(label: '待复习', value: '11'),
      ],
      cards: [
        PrimaryCardData(
          title: '最近笔记',
          subtitle: '按时间查看最近编辑内容',
          icon: Icons.sticky_note_2_rounded,
          route: RoutePaths.noteDetail,
        ),
        PrimaryCardData(
          title: '笔记背景',
          subtitle: '切换背景模板和排版风格',
          icon: Icons.brush_rounded,
          route: RoutePaths.noteBg,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '智能整理',
          subtitle: '自动提取重点生成复习卡片',
          icon: Icons.auto_awesome_rounded,
          accent: Color(0xFFFF9F43),
          badgeText: '即将上线',
        ),
      ],
    );
  }
}

class RecordingSystemPage extends StatelessWidget {
  const RecordingSystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '录音系统',
      subtitle: '录音、回放、作品提交和版本管理',
      stats: [
        PrimaryStatData(label: '作品数', value: '31'),
        PrimaryStatData(label: '本周上传', value: '4'),
        PrimaryStatData(label: '待点评', value: '2'),
      ],
      cards: [
        PrimaryCardData(
          title: '新建录音',
          subtitle: '开始录制并保存到个人作品库',
          icon: Icons.radio_button_checked_rounded,
          route: RoutePaths.recording,
        ),
        PrimaryCardData(
          title: '作品列表',
          subtitle: '按曲目管理历史录音版本',
          icon: Icons.library_music_rounded,
          route: RoutePaths.music,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '课堂提交',
          subtitle: '一键提交到老师点评队列',
          icon: Icons.upload_file_rounded,
          route: RoutePaths.smartCampus,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class MyCollectionPage extends StatelessWidget {
  const MyCollectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '我的收藏',
      subtitle: '集中管理收藏的曲谱、视频和笔记',
      stats: [
        PrimaryStatData(label: '总收藏', value: '89'),
        PrimaryStatData(label: '曲谱', value: '34'),
        PrimaryStatData(label: '视频', value: '21'),
      ],
      cards: [
        PrimaryCardData(
          title: '收藏曲谱',
          subtitle: '按难度和风格管理常用曲谱',
          icon: Icons.piano_rounded,
          route: RoutePaths.musicPlay,
        ),
        PrimaryCardData(
          title: '收藏视频',
          subtitle: '随时回看重点教学片段',
          icon: Icons.ondemand_video_rounded,
          route: RoutePaths.videoTutorial,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '收藏笔记',
          subtitle: '联动复习计划进行重点回顾',
          icon: Icons.bookmark_added_rounded,
          route: RoutePaths.myNotes,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PrimaryPageLayout(
      title: '帮助与反馈',
      subtitle: '常见问题、工单反馈和产品建议',
      stats: [
        PrimaryStatData(label: '待处理工单', value: '1'),
        PrimaryStatData(label: '已解决', value: '12'),
        PrimaryStatData(label: '响应时长', value: '< 24h'),
      ],
      cards: [
        PrimaryCardData(
          title: '提交反馈',
          subtitle: '描述问题并上传截图信息',
          icon: Icons.feedback_rounded,
          route: RoutePaths.fankui,
        ),
        PrimaryCardData(
          title: '查看协议',
          subtitle: '快速查看服务条款和隐私内容',
          icon: Icons.article_rounded,
          route: RoutePaths.xieyi,
          accent: Color(0xFF5E8BFF),
        ),
        PrimaryCardData(
          title: '联系客服',
          subtitle: '通过即时消息联系平台客服',
          icon: Icons.support_agent_rounded,
          route: RoutePaths.chat,
          accent: Color(0xFFFF9F43),
        ),
      ],
    );
  }
}

class _PrimaryPageLayout extends StatelessWidget {
  const _PrimaryPageLayout({
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final List<PrimaryStatData> stats;
  final List<PrimaryCardData> cards;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 2, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(title: title, subtitle: subtitle),
          const SizedBox(height: 12),
          _StatsGrid(stats: stats),
          const SizedBox(height: 12),
          _FeatureCards(cards: cards),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayText =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF171A20),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6A6A6A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1FFFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCDF6EC)),
            ),
            child: Text(
              dayText,
              style: const TextStyle(fontSize: 12, color: Color(0xFF00A98A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<PrimaryStatData> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980 ? 3 : (width >= 700 ? 2 : 1);
        final cardWidth = (width - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final stat in stats)
              SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF777777),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stat.value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF171A20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureCards extends StatelessWidget {
  const _FeatureCards({required this.cards});

  final List<PrimaryCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980 ? 3 : (width >= 700 ? 2 : 1);
        final cardWidth = (width - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: _FeatureCard(card: card),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.card});

  final PrimaryCardData card;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (card.route == null) {
          return;
        }
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute == card.route) {
          return;
        }
        Navigator.pushNamed(context, card.route!);
      },
      child: Container(
        height: 148,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: card.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(card.icon, color: card.accent, size: 20),
                ),
                const Spacer(),
                if (card.badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      card.badgeText!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF171A20),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              card.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF6C6C6C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
