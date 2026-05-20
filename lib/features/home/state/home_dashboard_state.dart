import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';

class HomeBannerItem {
  const HomeBannerItem({required this.imageUrl});

  final String imageUrl;
}

class HomeQuickAction {
  const HomeQuickAction({
    required this.name,
    required this.icon,
    required this.route,
    this.firstMenu,
  });

  final String name;
  final String icon;
  final String route;
  final int? firstMenu;
}

class HomeNewsItem {
  const HomeNewsItem({
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

class HomeWeekDayItem {
  const HomeWeekDayItem({
    required this.weekText,
    required this.dayText,
    required this.dateText,
    required this.courseCount,
    required this.isToday,
  });

  final String weekText;
  final String dayText;
  final String dateText;
  final int courseCount;
  final bool isToday;
}

enum HomeCourseStatus { ended, upcoming }

class HomeCourseNotice {
  const HomeCourseNotice({
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.teacherName,
    required this.teacherAvatar,
    required this.description,
    required this.status,
    this.cardColorHex,
  });

  final String startTime;
  final String endTime;
  final String subjectName;
  final String teacherName;
  final String teacherAvatar;
  final String description;
  final HomeCourseStatus status;
  // 接口 `color` 字段，如 "#fed7aa"，用于卡片左侧彩色条
  final String? cardColorHex;

  String get statusText => status == HomeCourseStatus.ended ? '已结束' : '即将开始';
}

class HomeDashboardState {
  const HomeDashboardState({
    this.loading = true,
    this.bannerItems = const [],
    this.quickActions = const [],
    this.weekItems = const [],
    this.newsItems = const [],
    this.courseNotices = const [],
    this.errorMessage = '',
  });

  final bool loading;
  final List<HomeBannerItem> bannerItems;
  final List<HomeQuickAction> quickActions;
  final List<HomeWeekDayItem> weekItems;
  final List<HomeNewsItem> newsItems;
  final List<HomeCourseNotice> courseNotices;
  final String errorMessage;

  HomeDashboardState copyWith({
    bool? loading,
    List<HomeBannerItem>? bannerItems,
    List<HomeQuickAction>? quickActions,
    List<HomeWeekDayItem>? weekItems,
    List<HomeNewsItem>? newsItems,
    List<HomeCourseNotice>? courseNotices,
    String? errorMessage,
  }) {
    return HomeDashboardState(
      loading: loading ?? this.loading,
      bannerItems: bannerItems ?? this.bannerItems,
      quickActions: quickActions ?? this.quickActions,
      weekItems: weekItems ?? this.weekItems,
      newsItems: newsItems ?? this.newsItems,
      courseNotices: courseNotices ?? this.courseNotices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 首页九宫格按钮列表，从左到右从上到下对应 home1.png ~ home9.png
List<HomeQuickAction> buildQuickActions(bool _) {
  return const <HomeQuickAction>[
    HomeQuickAction(
      name: '听写',
      icon: AppAssets.homeBtn1,
      route: RoutePaths.dictation,
      firstMenu: 8,
    ),
    HomeQuickAction(
      name: '视唱',
      icon: AppAssets.homeBtn2,
      route: RoutePaths.sightSinging,
      firstMenu: 1,
    ),
    HomeQuickAction(
      name: '乐理',
      icon: AppAssets.homeBtn3,
      route: RoutePaths.musicTheory,
      firstMenu: 5,
    ),
    HomeQuickAction(
      name: '模考',
      icon: AppAssets.homeBtn4,
      route: RoutePaths.mock,
    ),
    HomeQuickAction(
      name: '刷题',
      icon: AppAssets.homeBtn5,
      route: RoutePaths.camp,
    ),
    HomeQuickAction(
      name: '试题',
      icon: AppAssets.homeBtn6,
      route: RoutePaths.answerQuestions,
    ),
    HomeQuickAction(
      name: '资讯',
      icon: AppAssets.homeBtn7,
      route: RoutePaths.consultation,
    ),
    HomeQuickAction(
      name: '商城',
      icon: AppAssets.homeBtn8,
      route: RoutePaths.aiSong,
    ),
    HomeQuickAction(
      name: '校圈',
      icon: AppAssets.homeBtn9,
      route: RoutePaths.circle,
    ),
  ];
}
