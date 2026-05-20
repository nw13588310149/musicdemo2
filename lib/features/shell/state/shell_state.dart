import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/storage/app_storage.dart';

class ShellNavItem {
  const ShellNavItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
    this.badgeColor = 0xFFE61F62,
  });

  final String label;
  final String route;
  final String icon;
  final String activeIcon;
  final int badge;
  final int badgeColor;

  ShellNavItem copyWith({int? badge}) {
    return ShellNavItem(
      label: label,
      route: route,
      icon: icon,
      activeIcon: activeIcon,
      badge: badge ?? this.badge,
      badgeColor: badgeColor,
    );
  }
}

class ShellNoticeItem {
  const ShellNoticeItem({
    required this.id,
    required this.targetType,
    required this.content,
    required this.createTime,
  });

  final int id;
  final int targetType;
  final String content;
  final String createTime;
}

class ShellUser {
  const ShellUser({
    this.id = '',
    this.nickname = '',
    this.realname = '',
    this.avatarUrl = '',
    this.province = '',
    this.role = '',
    this.identity = '',
    this.vipExpireDate,
  });

  /// 后端 `myInfo.user.id`（雪花长整型）。**必须以字符串形式承载**，
  /// web 端经 JS number(53bit) 转换会丢精度。空串表示未登录或未知。
  ///
  /// 用于 `/chat/sendMsg` 等接口的「我是谁」对照（`fromUserId == id`）以
  /// 渲染消息气泡左右位置。
  final String id;
  final String nickname;
  final String realname;
  final String avatarUrl;
  final String province;

  /// `myInfo` 接口的 `user.role` 原文，例如 `student` / `teacher` /
  /// `headTeacher` / `dormManager` / `admin` 等，用于上层做身份分发。
  final String role;

  /// `myInfo` 接口的 `user.identity` 原文（中文身份），如「学生 / 老师 /
  /// 班主任 / 宿管 / 管理员」，作为 `role` 字段的兜底。
  final String identity;

  /// `myInfo.user.vipExpireDate` 解析后的到期时间，单位为本地时间。
  ///
  /// 为 `null` 表示从未开通会员；非空但已早于 `DateTime.now()` 表示
  /// 会员已过期。两种状态都按「未开通 / 已失效」处理，由 [isVipActive]
  /// 统一对外暴露布尔结果。
  final DateTime? vipExpireDate;

  /// 是否有有效会员（VIP）。`true` 仅当 [vipExpireDate] 非空且晚于现
  /// 在；`null` 或过期都返回 `false`。
  bool get isVipActive {
    final expire = vipExpireDate;
    if (expire == null) {
      return false;
    }
    return expire.isAfter(DateTime.now());
  }

  String get displayName {
    if (nickname.isNotEmpty) {
      return nickname;
    }
    if (realname.isNotEmpty) {
      return realname;
    }
    return '\u7528\u6237';
  }
}

class ShellState {
  const ShellState({
    required this.navItems,
    this.collapsed = false,
    this.showFloatingMenu = false,
    this.logoUrl = '',
    this.user = const ShellUser(),
    this.unreadCount = 0,
    this.noticeItems = const [],
    this.schoolCoursewareEnabled = false,
  });

  final List<ShellNavItem> navItems;
  final bool collapsed;
  final bool showFloatingMenu;
  final String logoUrl;
  final ShellUser user;
  final int unreadCount;
  final List<ShellNoticeItem> noticeItems;
  final bool schoolCoursewareEnabled;

  bool get isAuthenticated => true;

  ShellState copyWith({
    List<ShellNavItem>? navItems,
    bool? collapsed,
    bool? showFloatingMenu,
    String? logoUrl,
    ShellUser? user,
    int? unreadCount,
    List<ShellNoticeItem>? noticeItems,
    bool? schoolCoursewareEnabled,
  }) {
    return ShellState(
      navItems: navItems ?? this.navItems,
      collapsed: collapsed ?? this.collapsed,
      showFloatingMenu: showFloatingMenu ?? this.showFloatingMenu,
      logoUrl: logoUrl ?? this.logoUrl,
      user: user ?? this.user,
      unreadCount: unreadCount ?? this.unreadCount,
      noticeItems: noticeItems ?? this.noticeItems,
      schoolCoursewareEnabled:
          schoolCoursewareEnabled ?? this.schoolCoursewareEnabled,
    );
  }
}

List<ShellNavItem> buildDefaultNavItems({
  required bool schoolCoursewareEnabled,
}) {
  const base = <ShellNavItem>[
    ShellNavItem(
      label: '\u9996\u9875',
      route: RoutePaths.home,
      icon: AppAssets.leftNavHome,
      activeIcon: AppAssets.leftNavHome,
    ),
    ShellNavItem(
      label: '\u5c0f\u827a\u540c\u5b66',
      route: RoutePaths.personalAi,
      icon: AppAssets.leftNavAi,
      activeIcon: AppAssets.leftNavAi,
    ),
  ];

  final school = ShellNavItem(
    label: '\u6821\u56ed\u8bfe\u4ef6',
    route: RoutePaths.school,
    icon: AppAssets.leftNavSchool,
    activeIcon: AppAssets.leftNavSchool,
  );

  final tail = <ShellNavItem>[
    const ShellNavItem(
      label: '\u6211\u7684\u4e91\u76d8',
      route: RoutePaths.courseware,
      icon: AppAssets.leftNavYunpan,
      activeIcon: AppAssets.leftNavYunpan,
    ),
    const ShellNavItem(
      label: '\u89c6\u9891\u4e2d\u5fc3',
      route: RoutePaths.videoTutorial,
      icon: AppAssets.leftNavVideo,
      activeIcon: AppAssets.leftNavVideo,
    ),
    const ShellNavItem(
      label: '\u667a\u80fd\u542c\u5199',
      route: RoutePaths.smartDictation,
      icon: AppAssets.leftNavTingxie,
      activeIcon: AppAssets.leftNavTingxie,
    ),
    const ShellNavItem(
      label: '\u97f3\u4e50\u4f34\u4fa3',
      route: RoutePaths.music,
      icon: AppAssets.leftNavBanlv,
      activeIcon: AppAssets.leftNavBanlv,
    ),
    const ShellNavItem(
      label: '\u667a\u6167\u6821\u56ed',
      route: RoutePaths.smartCampus,
      icon: AppAssets.leftNavXiaoyuan,
      activeIcon: AppAssets.leftNavXiaoyuan,
    ),
    const ShellNavItem(
      label: '\u6211\u7684\u7b14\u8bb0',
      route: RoutePaths.myNotes,
      icon: AppAssets.leftNavBiji,
      activeIcon: AppAssets.leftNavBiji,
    ),
    const ShellNavItem(
      label: '\u5f55\u97f3\u7cfb\u7edf',
      route: RoutePaths.recording,
      icon: AppAssets.leftNavLuyin,
      activeIcon: AppAssets.leftNavLuyin,
    ),
    const ShellNavItem(
      label: '\u6211\u7684\u6536\u85cf',
      route: RoutePaths.myCollection,
      icon: AppAssets.leftNavShoucang,
      activeIcon: AppAssets.leftNavShoucang,
    ),
    const ShellNavItem(
      label: '\u4e2a\u4eba\u4e2d\u5fc3',
      route: RoutePaths.personalCenter,
      icon: AppAssets.leftNavInfo,
      activeIcon: AppAssets.leftNavInfo,
    ),
  ];

  return [...base, if (schoolCoursewareEnabled) school, ...tail];
}

ShellState createInitialShellState(AppStorage storage) {
  return ShellState(
    navItems: buildDefaultNavItems(schoolCoursewareEnabled: false),
  );
}
