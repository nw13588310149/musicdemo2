import 'package:flutter/material.dart';

import '../state/smart_campus_state.dart';

const _purple = Color(0xFF8F63FF);
const _purpleSoft = Color(0xFFF2ECFF);
const _blue = Color(0xFF5D8EFF);
const _blueSoft = Color(0xFFEAF2FF);
const _green = Color(0xFF2CC7B0);
const _greenSoft = Color(0xFFEAFBF7);
const _orange = Color(0xFFFFA450);
const _orangeSoft = Color(0xFFFFF1E5);
const _pink = Color(0xFFFF7298);
const _pinkSoft = Color(0xFFFFEEF3);

class SmartCampusStatCardData {
  const SmartCampusStatCardData({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;
}

class SmartCampusQuickActionData {
  const SmartCampusQuickActionData({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.badge = 0,
    this.imagePath,
  });
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final int badge;
  final String? imagePath;
}

class SmartCampusProfileData {
  const SmartCampusProfileData({
    required this.name,
    required this.title,
    required this.badgeLabel,
    required this.statusLabel,
    required this.organization,
    required this.detailLines,
    this.highlightText,
  });
  final String name;
  final String title;
  final String badgeLabel;
  final String statusLabel;
  final String organization;
  final List<String> detailLines;
  final String? highlightText;
}

class SmartCampusNoticeData {
  const SmartCampusNoticeData({
    required this.tag,
    required this.title,
    required this.time,
    required this.tagForeground,
    required this.tagBackground,
    this.unread = true,
  });
  final String tag;
  final String title;
  final String time;
  final Color tagForeground;
  final Color tagBackground;
  final bool unread;
}

class SmartCampusPanelItemData {
  const SmartCampusPanelItemData({
    required this.badge,
    required this.badgeForeground,
    required this.badgeBackground,
    required this.title,
    required this.subtitle,
    required this.person,
    required this.personHint,
    required this.trailing,
    required this.avatarSeed,
  });
  final String badge;
  final Color badgeForeground;
  final Color badgeBackground;
  final String title;
  final String subtitle;
  final String person;
  final String personHint;
  final String trailing;
  final String avatarSeed;
}

class SmartCampusPanelData {
  const SmartCampusPanelData({
    required this.title,
    required this.subtitle,
    required this.items,
  });
  final String title;
  final String subtitle;
  final List<SmartCampusPanelItemData> items;
}

class SmartCampusRoleScopeSectionData {
  const SmartCampusRoleScopeSectionData({
    required this.title,
    required this.items,
  });
  final String title;
  final List<String> items;
}

class SmartCampusAlertData {
  const SmartCampusAlertData({
    required this.tag,
    required this.title,
    required this.subtitle,
  });
  final String tag;
  final String title;
  final String subtitle;
}

class SmartCampusDashboardData {
  const SmartCampusDashboardData({
    required this.role,
    required this.statColumns,
    required this.stats,
    required this.actions,
    required this.profile,
    required this.noticeTitle,
    required this.notices,
    required this.roleTabs,
    this.primaryPanel,
    this.secondaryPanel,
    this.chartValues = const [],
    this.roleScopeSections = const [],
    this.alerts = const [],
  });
  final SmartCampusRole role;
  final int statColumns;
  final List<SmartCampusStatCardData> stats;
  final List<SmartCampusQuickActionData> actions;
  final SmartCampusProfileData profile;
  final String noticeTitle;
  final List<SmartCampusNoticeData> notices;
  final List<SmartCampusRole> roleTabs;
  final SmartCampusPanelData? primaryPanel;
  final SmartCampusPanelData? secondaryPanel;
  final List<double> chartValues;
  final List<SmartCampusRoleScopeSectionData> roleScopeSections;
  final List<SmartCampusAlertData> alerts;

  bool get isAdmin => role == SmartCampusRole.admin;
}

SmartCampusDashboardData smartCampusDashboardDataForRole(SmartCampusRole role) {
  switch (role) {
    case SmartCampusRole.student:
      return SmartCampusDashboardData(
        role: role,
        statColumns: 6,
        roleTabs: const [SmartCampusRole.student],
        noticeTitle: '校级通知',
        stats: const [
          SmartCampusStatCardData(label: '今日课程', value: '6'),
          SmartCampusStatCardData(label: '待交作业', value: '6'),
          SmartCampusStatCardData(label: '学期均分', value: '86.5'),
          SmartCampusStatCardData(label: '未读通知', value: '4'),
          SmartCampusStatCardData(label: '月考时间', value: '周五'),
          SmartCampusStatCardData(label: '距离省统考', value: '186天'),
        ],
        actions: const [
          SmartCampusQuickActionData(
            label: '我的班级',
            icon: Icons.groups_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/1.png',
          ),
          SmartCampusQuickActionData(
            label: '我的课表',
            icon: Icons.calendar_view_week_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/2.png',
          ),
          SmartCampusQuickActionData(
            label: '课堂签到',
            icon: Icons.fact_check_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/3.png',
          ),
          SmartCampusQuickActionData(
            label: '我的作业',
            icon: Icons.assignment_rounded,
            background: _blueSoft,
            foreground: _blue,
            imagePath: 'assets/images/schoolA/4.png',
          ),
          SmartCampusQuickActionData(
            label: '我的成绩',
            icon: Icons.bar_chart_rounded,
            background: _orangeSoft,
            foreground: _orange,
            imagePath: 'assets/images/schoolA/5.png',
          ),
          SmartCampusQuickActionData(
            label: '群聊',
            icon: Icons.forum_rounded,
            background: _pinkSoft,
            foreground: _pink,
            badge: 10,
            imagePath: 'assets/images/schoolA/6.png',
          ),
          SmartCampusQuickActionData(
            label: '校圈',
            icon: Icons.apartment_rounded,
            background: _blueSoft,
            foreground: _blue,
            imagePath: 'assets/images/schoolA/7.png',
          ),
          SmartCampusQuickActionData(
            label: '请假管理',
            icon: Icons.event_note_rounded,
            background: _greenSoft,
            foreground: _green,
            imagePath: 'assets/images/schoolA/8.png',
          ),
          SmartCampusQuickActionData(
            label: '查寝管理',
            icon: Icons.night_shelter_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/9.png',
          ),
          SmartCampusQuickActionData(
            label: '校长信箱',
            icon: Icons.markunread_mailbox_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/10.png',
          ),
        ],
        profile: const SmartCampusProfileData(
          name: 'Grey黎',
          title: '在校',
          badgeLabel: '学生',
          statusLabel: '在线',
          organization: '音乐之路音乐学校',
          detailLines: ['主项：民族唱法', '副项：钢琴', '班级：高三音乐实验班', '宿舍：女生宿 3号楼·612'],
          highlightText: '目标院校 · 浙江音乐学院',
        ),
        notices: const [
          SmartCampusNoticeData(
            tag: '统考',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '09:10',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
          ),
          SmartCampusNoticeData(
            tag: '宿舍',
            title: '断电提醒教学楼夜间 21:00 后静音巡查，22:00 断电，请提前保存练习视频。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
        ],
        primaryPanel: const SmartCampusPanelData(
          title: '当前课程',
          subtitle: '本节课与待完成任务',
          items: [
            SmartCampusPanelItemData(
              badge: '视唱课',
              badgeForeground: _purple,
              badgeBackground: _purpleSoft,
              title: '14:00 - 14:45',
              subtitle: '本节进行和弦连接与旋律模唱训练',
              person: '江月月',
              personHint: '45分钟·音乐体验课',
              trailing: '即将开始',
              avatarSeed: '江',
            ),
            SmartCampusPanelItemData(
              badge: '作业',
              badgeForeground: _orange,
              badgeBackground: _orangeSoft,
              title: '艺考曲目练习',
              subtitle: '今天 21:00 前上传《渔舟唱晚》练习视频',
              person: '班级作业',
              personHint: '已发布至高三音乐实验班',
              trailing: '待提交',
              avatarSeed: '作',
            ),
          ],
        ),
        secondaryPanel: const SmartCampusPanelData(
          title: '今日课表',
          subtitle: '按时间查看当日安排',
          items: [
            SmartCampusPanelItemData(
              badge: '竹笛课',
              badgeForeground: _green,
              badgeBackground: _greenSoft,
              title: '09:00 - 09:45',
              subtitle: '专业教室 A301 · 小课',
              person: '徐明敏',
              personHint: '45分钟·音乐体验课',
              trailing: '已结束',
              avatarSeed: '徐',
            ),
            SmartCampusPanelItemData(
              badge: '大课',
              badgeForeground: _pink,
              badgeBackground: _pinkSoft,
              title: '19:00 - 20:00',
              subtitle: '综合楼 201 · 晚自习集训',
              person: '李达扬',
              personHint: '60分钟·音乐体验课',
              trailing: '未开始',
              avatarSeed: '李',
            ),
          ],
        ),
      );
    case SmartCampusRole.teacher:
      return SmartCampusDashboardData(
        role: role,
        statColumns: 3,
        roleTabs: const [SmartCampusRole.teacher, SmartCampusRole.headTeacher],
        noticeTitle: '通知',
        stats: const [
          SmartCampusStatCardData(label: '今日授课', value: '6'),
          SmartCampusStatCardData(label: '待批改', value: '6'),
          SmartCampusStatCardData(label: '待签课', value: '86.5'),
          SmartCampusStatCardData(label: '未读消息', value: '4', highlight: true),
          SmartCampusStatCardData(label: '本周课时', value: '周五'),
          SmartCampusStatCardData(
            label: '下一节',
            value: '15:30',
            highlight: true,
          ),
        ],
        actions: const [
          SmartCampusQuickActionData(
            label: '授课课表',
            icon: Icons.calendar_month_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/2.png',
          ),
          SmartCampusQuickActionData(
            label: '签课管理',
            icon: Icons.how_to_reg_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/3.png',
          ),
          SmartCampusQuickActionData(
            label: '学生名册',
            icon: Icons.badge_rounded,
            background: _blueSoft,
            foreground: _blue,
            imagePath: 'assets/images/schoolA/11.png',
          ),
          SmartCampusQuickActionData(
            label: '作业批改',
            icon: Icons.edit_note_rounded,
            background: _orangeSoft,
            foreground: _orange,
            imagePath: 'assets/images/schoolA/4.png',
          ),
          SmartCampusQuickActionData(
            label: '考评管理',
            icon: Icons.rule_folder_rounded,
            background: _pinkSoft,
            foreground: _pink,
            imagePath: 'assets/images/schoolA/12.png',
          ),
          SmartCampusQuickActionData(
            label: '群聊',
            icon: Icons.forum_rounded,
            background: _purpleSoft,
            foreground: _purple,
            badge: 10,
            imagePath: 'assets/images/schoolA/6.png',
          ),
          SmartCampusQuickActionData(
            label: '校圈',
            icon: Icons.apartment_rounded,
            background: _greenSoft,
            foreground: _green,
            imagePath: 'assets/images/schoolA/7.png',
          ),
          SmartCampusQuickActionData(
            label: '校长信箱',
            icon: Icons.markunread_mailbox_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/10.png',
          ),
        ],
        profile: const SmartCampusProfileData(
          name: 'Grey黎',
          title: '在岗',
          badgeLabel: '老师',
          statusLabel: '授课中',
          organization: '音乐学科一级教师',
          detailLines: ['主项：和声基础', '副项：钢琴', '带班：高三音乐实验班'],
        ),
        notices: const [
          SmartCampusNoticeData(
            tag: '教研室',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '09:10',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
          ),
          SmartCampusNoticeData(
            tag: '场地',
            title: '断电提醒教学楼夜间 21:00 后静音巡查，22:00 断电，请提前保存练习视频。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
        ],
        primaryPanel: const SmartCampusPanelData(
          title: '当前课程',
          subtitle: '本节授课与课堂状态',
          items: [
            SmartCampusPanelItemData(
              badge: '视唱课',
              badgeForeground: _purple,
              badgeBackground: _purpleSoft,
              title: '15:20 - 16:05',
              subtitle: '教学楼 402 · 待签到 2 人，已到 32 人',
              person: '高三音乐实验班',
              personHint: '课程主题：视唱练耳综合训练',
              trailing: '签到中',
              avatarSeed: '高',
            ),
            SmartCampusPanelItemData(
              badge: '课后',
              badgeForeground: _orange,
              badgeBackground: _orangeSoft,
              title: '布置课后作业',
              subtitle: '下课后自动推送视唱训练作业至学生端',
              person: '课堂任务',
              personHint: '今日课程已配置课堂作业模板',
              trailing: '待发布',
              avatarSeed: '课',
            ),
          ],
        ),
        secondaryPanel: const SmartCampusPanelData(
          title: '今日课表',
          subtitle: '教师个人授课安排',
          items: [
            SmartCampusPanelItemData(
              badge: '合唱课',
              badgeForeground: _blue,
              badgeBackground: _blueSoft,
              title: '08:30 - 09:15',
              subtitle: '高二合唱基础 · 教学楼 301',
              person: '高二合唱班',
              personHint: '已完成上午授课',
              trailing: '已结束',
              avatarSeed: '高',
            ),
            SmartCampusPanelItemData(
              badge: '答疑',
              badgeForeground: _green,
              badgeBackground: _greenSoft,
              title: '19:10 - 19:55',
              subtitle: '琴房 3 区 · 晚自习集体答疑',
              person: '晚自习答疑',
              personHint: '计划面向高三与校考冲刺生',
              trailing: '未开始',
              avatarSeed: '晚',
            ),
          ],
        ),
      );
    case SmartCampusRole.headTeacher:
      return SmartCampusDashboardData(
        role: role,
        statColumns: 3,
        roleTabs: const [SmartCampusRole.teacher, SmartCampusRole.headTeacher],
        noticeTitle: '通知',
        stats: const [
          SmartCampusStatCardData(label: '班级出勤', value: '6'),
          SmartCampusStatCardData(label: '待批请假', value: '6'),
          SmartCampusStatCardData(label: '查寝异常', value: '86.5'),
          SmartCampusStatCardData(label: '家校未读', value: '4'),
          SmartCampusStatCardData(label: '关注学生', value: '周五'),
          SmartCampusStatCardData(label: '待办', value: '9', highlight: true),
        ],
        actions: const [
          SmartCampusQuickActionData(
            label: '班级工作台',
            icon: Icons.dashboard_customize_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/13.png',
          ),
          SmartCampusQuickActionData(
            label: '请假审批',
            icon: Icons.fact_check_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/3.png',
          ),
          SmartCampusQuickActionData(
            label: '查寝动态',
            icon: Icons.king_bed_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/9.png',
          ),
          SmartCampusQuickActionData(
            label: '查寝历史',
            icon: Icons.history_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/14.png',
          ),
          SmartCampusQuickActionData(
            label: '家校沟通',
            icon: Icons.family_restroom_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/15.png',
          ),
          SmartCampusQuickActionData(
            label: '群聊',
            icon: Icons.forum_rounded,
            background: _purpleSoft,
            foreground: _purple,
            badge: 10,
            imagePath: 'assets/images/schoolA/6.png',
          ),
          SmartCampusQuickActionData(
            label: '校圈',
            icon: Icons.apartment_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/7.png',
          ),
          SmartCampusQuickActionData(
            label: '校长信箱',
            icon: Icons.markunread_mailbox_rounded,
            background: _purpleSoft,
            foreground: _purple,
            imagePath: 'assets/images/schoolA/10.png',
          ),
        ],
        profile: const SmartCampusProfileData(
          name: 'Grey黎',
          title: '在岗',
          badgeLabel: '班主任',
          statusLabel: '值班中',
          organization: '高三音乐实验班班主任',
          detailLines: ['主项：班务总控', '副项：家校沟通', '带班：高三音乐实验班'],
        ),
        notices: const [
          SmartCampusNoticeData(
            tag: '教研室',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '09:10',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
          ),
          SmartCampusNoticeData(
            tag: '场地',
            title: '断电提醒教学楼夜间 21:00 后静音巡查，22:00 断电，请提前保存练习视频。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
          SmartCampusNoticeData(
            tag: '大师课',
            title: '笔试与面试场次确认截止本周五 17:00，逾期将影响准考证打印。',
            time: '周一',
            tagForeground: Color(0xFF0B081A),
            tagBackground: Color(0xFFEAE5FF),
            unread: false,
          ),
        ],
        primaryPanel: const SmartCampusPanelData(
          title: '当前事项',
          subtitle: '班主任今日待处理事项',
          items: [
            SmartCampusPanelItemData(
              badge: '班会',
              badgeForeground: _purple,
              badgeBackground: _purpleSoft,
              title: '班会材料 · 校考志愿说明',
              subtitle: '今天 17:00 前完成班会提纲与讲稿更新',
              person: '班务任务',
              personHint: '已同步任课老师与家长端提醒',
              trailing: '待处理',
              avatarSeed: '班',
            ),
            SmartCampusPanelItemData(
              badge: '家校',
              badgeForeground: _pink,
              badgeBackground: _pinkSoft,
              title: '重点学生沟通回访',
              subtitle: '跟进 3 位冲刺生近期作息与心理状态',
              person: '家校沟通',
              personHint: '需在本周例会前补充回访记录',
              trailing: '高优先',
              avatarSeed: '家',
            ),
          ],
        ),
        secondaryPanel: const SmartCampusPanelData(
          title: '班务',
          subtitle: '班级动态与执行进度',
          items: [
            SmartCampusPanelItemData(
              badge: '演讲',
              badgeForeground: _orange,
              badgeBackground: _orangeSoft,
              title: '校考志愿说明演讲',
              subtitle: '周五第 8 节 · 多功能厅 · 全班参加',
              person: '班级活动',
              personHint: '已通知家长同步观看回放',
              trailing: '已排期',
              avatarSeed: '演',
            ),
            SmartCampusPanelItemData(
              badge: '查寝',
              badgeForeground: _blue,
              badgeBackground: _blueSoft,
              title: '晚归闭环确认',
              subtitle: '需要和宿管端确认昨晚 2 条晚归登记',
              person: '宿舍事务',
              personHint: '确认后自动归档班务记录',
              trailing: '跟进中',
              avatarSeed: '宿',
            ),
          ],
        ),
      );
    case SmartCampusRole.dormManager:
      return SmartCampusDashboardData(
        role: role,
        statColumns: 3,
        roleTabs: const [SmartCampusRole.dormManager],
        noticeTitle: '宿舍通知',
        stats: const [
          SmartCampusStatCardData(label: '今日批次', value: '6'),
          SmartCampusStatCardData(label: '待审补卡', value: '6'),
          SmartCampusStatCardData(label: '晚归登记', value: '3'),
          SmartCampusStatCardData(label: '异常未闭环', value: '4', highlight: true),
          SmartCampusStatCardData(label: '在寝率', value: '98%'),
          SmartCampusStatCardData(label: '待处理', value: '12'),
        ],
        actions: const [
          SmartCampusQuickActionData(
            label: '按宿舍查寝',
            icon: Icons.king_bed_rounded,
            background: _purpleSoft,
            foreground: _purple,
          ),
          SmartCampusQuickActionData(
            label: '查寝历史',
            icon: Icons.history_rounded,
            background: _blueSoft,
            foreground: _blue,
          ),
          SmartCampusQuickActionData(
            label: '打卡管理',
            icon: Icons.punch_clock_rounded,
            background: _orangeSoft,
            foreground: _orange,
          ),
          SmartCampusQuickActionData(
            label: '宿管请假',
            icon: Icons.note_alt_rounded,
            background: _pinkSoft,
            foreground: _pink,
          ),
          SmartCampusQuickActionData(
            label: '校圈',
            icon: Icons.groups_3_rounded,
            background: _greenSoft,
            foreground: _green,
          ),
          SmartCampusQuickActionData(
            label: '群聊',
            icon: Icons.forum_rounded,
            background: _purpleSoft,
            foreground: _purple,
            badge: 10,
          ),
          SmartCampusQuickActionData(
            label: '校长信箱',
            icon: Icons.markunread_mailbox_rounded,
            background: _purpleSoft,
            foreground: _purple,
          ),
        ],
        profile: const SmartCampusProfileData(
          name: 'Grey黎',
          title: '值班中',
          badgeLabel: '宿管老师',
          statusLabel: '巡查中',
          organization: '生活辅导员 · 宿管值班',
          detailLines: ['区域：男生公寓 1-3 号楼', '区域：女生公寓 A 区', '职责：查寝 / 补卡 / 晚归闭环'],
        ),
        notices: const [
          SmartCampusNoticeData(
            tag: '晚查',
            title: '今晚晚查寝将提前 10 分钟开始，请确认设备与名单已同步。',
            time: '07:20',
            tagForeground: _purple,
            tagBackground: _purpleSoft,
          ),
          SmartCampusNoticeData(
            tag: '补卡',
            title: '当前有 7 条补卡申请待审核，请在白天值班时段处理。',
            time: '周二',
            tagForeground: _orange,
            tagBackground: _orangeSoft,
          ),
          SmartCampusNoticeData(
            tag: '晨检',
            title: '明晨女生公寓 A 区需增加一轮离寝统计，请提前安排。',
            time: '周三',
            tagForeground: _blue,
            tagBackground: _blueSoft,
          ),
          SmartCampusNoticeData(
            tag: '闭环',
            title: '昨晚异常 3 条仍未闭环，请联系班主任同步确认。',
            time: '周四',
            tagForeground: _pink,
            tagBackground: _pinkSoft,
          ),
        ],
        primaryPanel: const SmartCampusPanelData(
          title: '当前事项',
          subtitle: '宿舍管理即时任务',
          items: [
            SmartCampusPanelItemData(
              badge: '晚查',
              badgeForeground: _purple,
              badgeBackground: _purpleSoft,
              title: '晚查寝预备 · 设备与名单核对',
              subtitle: '今晚 21:20 前完成 3 号楼设备、电量与人脸名单同步',
              person: '值班任务',
              personHint: '值班人：Grey黎',
              trailing: '待执行',
              avatarSeed: '晚',
            ),
            SmartCampusPanelItemData(
              badge: '补卡',
              badgeForeground: _orange,
              badgeBackground: _orangeSoft,
              title: '补卡申请集中审核',
              subtitle: '今日共有 6 条待审补卡，需在 18:00 前完成批量处理',
              person: '系统任务',
              personHint: '审核后自动回写考勤记录',
              trailing: '处理中',
              avatarSeed: '补',
            ),
          ],
        ),
        secondaryPanel: const SmartCampusPanelData(
          title: '今日值班',
          subtitle: '宿管值班与巡查安排',
          items: [
            SmartCampusPanelItemData(
              badge: '晨检',
              badgeForeground: _blue,
              badgeBackground: _blueSoft,
              title: '晨检开门 · 离寝统计同步',
              subtitle: '07:00 - 07:40 · 女生 A 区',
              person: 'Grey黎',
              personHint: '今日晨检班次负责人',
              trailing: '已完成',
              avatarSeed: '晨',
            ),
            SmartCampusPanelItemData(
              badge: '晚查',
              badgeForeground: _pink,
              badgeBackground: _pinkSoft,
              title: '男生 3 号楼晚查',
              subtitle: '21:30 - 22:10 · 重点核对晚归与请假回寝',
              person: 'Grey黎',
              personHint: '与班主任端同步闭环',
              trailing: '未开始',
              avatarSeed: '宿',
            ),
          ],
        ),
      );
    case SmartCampusRole.admin:
      return SmartCampusDashboardData(
        role: role,
        statColumns: 4,
        roleTabs: const [SmartCampusRole.admin],
        noticeTitle: '校级通知',
        stats: const [
          SmartCampusStatCardData(label: '在籍学生', value: '75'),
          SmartCampusStatCardData(label: '任课老师', value: '73'),
          SmartCampusStatCardData(label: '本学期班级', value: '68'),
          SmartCampusStatCardData(label: '今日待办', value: '4', highlight: true),
          SmartCampusStatCardData(label: '待审宿管假', value: '23'),
          SmartCampusStatCardData(label: '人脸待补录', value: '67'),
          SmartCampusStatCardData(label: '通知草稿', value: '43'),
          SmartCampusStatCardData(label: '校园待处理', value: '32'),
        ],
        actions: const [
          SmartCampusQuickActionData(
            label: '学生管理',
            icon: Icons.groups_rounded,
            background: _purpleSoft,
            foreground: _purple,
          ),
          SmartCampusQuickActionData(
            label: '教师管理',
            icon: Icons.person_4_rounded,
            background: _purpleSoft,
            foreground: _purple,
          ),
          SmartCampusQuickActionData(
            label: '班级编辑',
            icon: Icons.draw_rounded,
            background: _purpleSoft,
            foreground: _purple,
          ),
          SmartCampusQuickActionData(
            label: '排课与课表',
            icon: Icons.calendar_month_rounded,
            background: _purpleSoft,
            foreground: _purple,
          ),
          SmartCampusQuickActionData(
            label: '宿管请假审批',
            icon: Icons.approval_rounded,
            background: _orangeSoft,
            foreground: _orange,
          ),
          SmartCampusQuickActionData(
            label: '人脸库',
            icon: Icons.face_retouching_natural_rounded,
            background: _blueSoft,
            foreground: _blue,
          ),
          SmartCampusQuickActionData(
            label: '通知管理',
            icon: Icons.campaign_rounded,
            background: _pinkSoft,
            foreground: _pink,
          ),
          SmartCampusQuickActionData(
            label: '群聊',
            icon: Icons.forum_rounded,
            background: _purpleSoft,
            foreground: _purple,
            badge: 10,
          ),
          SmartCampusQuickActionData(
            label: '校长信箱',
            icon: Icons.markunread_mailbox_rounded,
            background: _purpleSoft,
            foreground: _purple,
          ),
          SmartCampusQuickActionData(
            label: '校园治理',
            icon: Icons.admin_panel_settings_rounded,
            background: _greenSoft,
            foreground: _green,
          ),
        ],
        profile: const SmartCampusProfileData(
          name: 'Grey黎',
          title: '运行中',
          badgeLabel: '老师',
          statusLabel: '在线',
          organization: '校园管理端',
          detailLines: ['主项：校务统筹', '副项：教学运营', '职责：四端联动与流程治理'],
        ),
        notices: const [
          SmartCampusNoticeData(
            tag: '教研室',
            title: '笔考与面试场次确认截止本周五，请核对各批次排布。',
            time: '09:10',
            tagForeground: _purple,
            tagBackground: _purpleSoft,
          ),
          SmartCampusNoticeData(
            tag: '场地',
            title: '教学楼夜间 21:00 起统一熄灯，请同步至各班与宿管端。',
            time: '周一',
            tagForeground: _blue,
            tagBackground: _blueSoft,
          ),
          SmartCampusNoticeData(
            tag: '大课课',
            title: '统考倒计时提醒已同步至四端，请检查通知推送是否全部生效。',
            time: '周三',
            tagForeground: _purple,
            tagBackground: _purpleSoft,
          ),
          SmartCampusNoticeData(
            tag: '预警',
            title: '高三音乐实验班昨晚查寝 1 人未打卡未闭环，请尽快处理。',
            time: '周五',
            tagForeground: _pink,
            tagBackground: _pinkSoft,
          ),
        ],
        chartValues: const [88, 90, 89, 91, 93, 92, 95],
        roleScopeSections: const [
          SmartCampusRoleScopeSectionData(
            title: '核心场景',
            items: ['课表', '作业', '成绩', '课堂签到', '请假与补课', '查寝管理', '校圈', '群聊'],
          ),
          SmartCampusRoleScopeSectionData(
            title: '管理端',
            items: ['学生管理', '教师管理', '班级编辑', '排课与课表', '人脸库', '通知管理', '校园治理'],
          ),
        ],
        alerts: const [
          SmartCampusAlertData(
            tag: '预警',
            title: '高三音乐实验班昨晚查寝 1 人未打卡未闭环',
            subtitle: '宿管端已登记，待班主任确认是否已返寝。',
          ),
          SmartCampusAlertData(
            tag: '预警',
            title: '宿管请假审批超 12 小时未处理',
            subtitle: '请管理员补充责任人并通知宿管端继续值班。',
          ),
          SmartCampusAlertData(
            tag: '预警',
            title: '教务通知草稿 2 条未发布',
            subtitle: '涉及统考安排，请在今日晚间前完成核发。',
          ),
        ],
      );
  }
}
