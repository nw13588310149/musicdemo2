import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';

class SchoolQuickAction {
  const SchoolQuickAction({
    required this.name,
    required this.icon,
    required this.route,
    this.firstMenu,
    this.comingSoon = false,
  });

  final String name;
  final String icon;
  final String route;

  /// 1.0 中通过 storage 写入的 firstMenu 初值；2.0 改为路由参数透传给二级页面。
  final int? firstMenu;

  /// 商城/模考 等"即将上线"按钮：点击不跳转，弹出占位提示。
  final bool comingSoon;
}

class SchoolLearningItem {
  const SchoolLearningItem({
    required this.text,
    required this.value,
    required this.color,
    required this.background,
  });

  final String text;
  final int value;
  final Color color;
  final Color background;
}

class SchoolNewsItem {
  const SchoolNewsItem({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.tags,
    required this.viewCount,
    required this.createTime,
  });

  final int id;
  final String title;
  final String shortTitle;
  final List<String> tags;
  final int viewCount;
  final DateTime? createTime;
}

class SchoolPageState {
  const SchoolPageState({
    this.loading = true,
    this.schoolId = 0,
    this.schoolName = '',
    this.quickActions = const [],
    this.learningItems = const [],
    this.newsItems = const [],
    this.errorMessage = '',
  });

  final bool loading;
  final int schoolId;
  final String schoolName;
  final List<SchoolQuickAction> quickActions;
  final List<SchoolLearningItem> learningItems;
  final List<SchoolNewsItem> newsItems;
  final String errorMessage;

  SchoolPageState copyWith({
    bool? loading,
    int? schoolId,
    String? schoolName,
    List<SchoolQuickAction>? quickActions,
    List<SchoolLearningItem>? learningItems,
    List<SchoolNewsItem>? newsItems,
    String? errorMessage,
  }) {
    return SchoolPageState(
      loading: loading ?? this.loading,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      quickActions: quickActions ?? this.quickActions,
      learningItems: learningItems ?? this.learningItems,
      newsItems: newsItems ?? this.newsItems,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 校园课件页六宫格按钮。
///
/// 与 1.0 `school.vue` 中 `btnArray` + `onButtonClick` 一致：
///   - 听写: firstMenu=8、school 模式
///   - 视唱: firstMenu=1、school 模式
///   - 乐理: firstMenu=5、school 模式
///   - 试题(=1.0 答题): 不预选 firstMenu、school 模式
///   - 视频: 不预选 firstMenu、school 模式
/// 2.0 多出的"刷题"沿用 [RoutePaths.camp]，QuizPractice 当前不依赖 firstMenu/school。
List<SchoolQuickAction> buildSchoolQuickActions() {
  return const <SchoolQuickAction>[
    SchoolQuickAction(
      name: '听写',
      icon: AppAssets.homeBtn1,
      route: RoutePaths.dictation,
      firstMenu: 8,
    ),
    SchoolQuickAction(
      name: '乐理',
      icon: AppAssets.homeBtn3,
      route: RoutePaths.musicTheory,
      firstMenu: 5,
    ),
    SchoolQuickAction(
      name: '视唱',
      icon: AppAssets.homeBtn2,
      route: RoutePaths.sightSinging,
      firstMenu: 1,
    ),
    SchoolQuickAction(
      name: '刷题',
      icon: AppAssets.homeBtn5,
      route: RoutePaths.schoolCamp,
    ),
    SchoolQuickAction(
      name: '试题',
      icon: AppAssets.homeBtn6,
      route: RoutePaths.answerQuestions,
    ),
    SchoolQuickAction(
      name: '视频',
      icon: AppAssets.schoolV2QuickVideo,
      route: RoutePaths.schoolVideo,
    ),
  ];
}
