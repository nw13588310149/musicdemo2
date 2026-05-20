import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/network/chat_socket_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../data/shell_repository.dart';
import 'school_binding_controller.dart';
import 'shell_state.dart';

final shellControllerProvider =
    StateNotifierProvider<ShellController, ShellState>((ref) {
      final repository = ref.watch(shellRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      final controller = ShellController(
        repository: repository,
        storage: storage,
        ref: ref,
      );
      return controller;
    });

class ShellController extends StateNotifier<ShellState> {
  ShellController({
    required ShellRepository repository,
    required AppStorage storage,
    required Ref ref,
  }) : _repository = repository,
       _storage = storage,
       _ref = ref,
       super(createInitialShellState(storage)) {
    _init();
  }

  final ShellRepository _repository;
  final AppStorage _storage;
  final Ref _ref;

  Timer? _logoTimer;
  Timer? _noticeTimer;

  List<String> _cachedProvinces = const <String>[];

  void toggleCollapse() {
    state = state.copyWith(collapsed: !state.collapsed);
  }

  void toggleFloatingMenu() {
    state = state.copyWith(showFloatingMenu: !state.showFloatingMenu);
  }

  void closeFloatingMenu() {
    state = state.copyWith(showFloatingMenu: false);
  }

  Future<void> logout() async {
    await _repository.logout();
    await _storage.clearToken();
    await _storage.clearSchoolId();
    await _storage.clearMobile();
    // 主动断开全局 WS（不再自动重连），并在下次登录成功后由 AuthController
    // 触发 reconnect 重新握手。否则旧 token 的 WS 会持续在后台尝试重连，
    // 不仅浪费连接，还可能让后端误把已登出用户当作在线状态。
    _ref.read(chatSocketServiceProvider).disconnect();
    // 清空本地用户态，特别是 vipExpireDate。否则下一次登录瞬间，
    // ShellScaffold 在 myInfo 回包前会先看到上个账号的过期会员信息，
    // 命中 VIP 网关把新用户错误地踢回 /personal-center。
    state = state.copyWith(
      user: const ShellUser(),
      unreadCount: 0,
      noticeItems: const [],
      logoUrl: '',
    );
    // 销毁「绑定学校」轮询单例，下次重新登录时由 ShellScaffold 重新观察
    // 时再创建一个全新实例（带新 token），避免旧 session 的轮询线程或
    // 已经为 true 的 hasSchool 把新账号挡在外面。
    _ref.invalidate(schoolBindingControllerProvider);
  }

  /// 演示用「白名单管理员」手机号：使用此号登录后，无论后端 `/myInfo`
  /// 返回的 `role` 是什么，都强制覆盖为 `admin`，以便测试管理员视角下
  /// 的智慧校园（5 身份切换、班主任 / 任课老师等）。
  static const _adminMobileWhitelist = <String>{'18888888888'};

  Future<void> markAllNoticeRead() async {
    final ids = state.noticeItems.map((e) => e.id).toList();
    if (ids.isEmpty) {
      return;
    }
    final response = await _repository.markRead(ids);
    if (response.code == 0) {
      state = state.copyWith(unreadCount: 0, noticeItems: const []);
    }
  }

  Future<void> refreshNoticeData() async {
    final countResponse = await _repository.getUnreadCount();
    if (countResponse.code != 0) {
      return;
    }

    final count = _readUnreadCount(countResponse.data);
    if (count <= 0) {
      state = state.copyWith(unreadCount: 0, noticeItems: const []);
      _syncCampusBadge(0);
      return;
    }

    final listResponse = await _repository.getMessageList();
    if (listResponse.code != 0) {
      return;
    }

    final notices = _parseNoticeList(listResponse.data);
    state = state.copyWith(unreadCount: count, noticeItems: notices);
    _syncCampusBadge(count);
  }

  Future<void> refreshUserAndSchool() async {
    // 并行请求用户信息与学校信息，总耗时降为单次 RTT
    final responses = await Future.wait([
      _repository.getMyInfo(),
      _repository.getSchoolInfo(),
    ]);
    final myInfoResponse = responses[0];
    final schoolResponse = responses[1];

    if (myInfoResponse.code == 0) {
      final userMap = _extractUser(myInfoResponse.data);
      // 白名单管理员：强制把 role 覆盖为 'admin'，下游
      // SmartCampusController.applyBackendRole → mapBackendRoleToCampus
      // 会将其映射为 SmartCampusRole.admin 并解锁 5 身份切换。
      var role = userMap['role']?.toString() ?? '';
      if (_adminMobileWhitelist.contains(_storage.mobile)) {
        role = 'admin';
      }
      state = state.copyWith(
        user: ShellUser(
          id: userMap['id']?.toString() ?? '',
          nickname: userMap['nickname']?.toString() ?? '',
          realname: userMap['realname']?.toString() ?? '',
          avatarUrl: userMap['headUrl']?.toString() ?? '',
          province: userMap['province']?.toString() ?? '',
          role: role,
          identity: userMap['identity']?.toString() ?? '',
          vipExpireDate: _parseVipExpireDate(userMap['vipExpireDate']),
        ),
      );
    }

    if (schoolResponse.code == 0) {
      // v2 接口返回的是学校列表，旧版接口返回单 Map；两种结构都兜住，
      // 取首项作为「当前学校」用于顶部 logo 与导航开关判定。
      final data = _firstSchool(schoolResponse.data);
      await _storage.saveSchoolId(data['id']);
      if (data.isNotEmpty) {
        final logo = data['logo']?.toString() ?? '';
        final switchFlag = data['coursewareSwitch'];
        final schoolCoursewareEnabled = switchFlag == true || switchFlag == 1;
        state = state.copyWith(
          logoUrl: logo,
          schoolCoursewareEnabled: schoolCoursewareEnabled,
          navItems: buildDefaultNavItems(
            schoolCoursewareEnabled: schoolCoursewareEnabled,
          ),
        );
        _syncCampusBadge(state.unreadCount);
      }
    } else {
      await _storage.saveSchoolId(0);
    }
  }

  /// 把 v2 `schoolList` 响应（List）或旧版 `mySchool` 响应（Map）规整成
  /// 同一种形态：当前学校信息的 Map（找不到时返回空 Map）。
  Map<String, dynamic> _firstSchool(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return first.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return const <String, dynamic>{};
  }

  /// 拉取省份列表（懒加载缓存），与 1.0 `getCity` 行为一致。
  Future<List<String>> loadProvinces() async {
    if (_cachedProvinces.isNotEmpty) {
      return _cachedProvinces;
    }
    final response = await _repository.provinceCityList();
    if (response.code != 0) {
      return const <String>[];
    }
    final raw = response.data;
    if (raw is! List<dynamic>) {
      return const <String>[];
    }
    final names = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final name = item['name']?.toString();
        if (name != null && name.isNotEmpty) {
          names.add(name);
        }
      }
    }
    _cachedProvinces = names;
    return names;
  }

  /// 切换所在地区；成功返回 null，失败返回错误信息。
  /// 与 1.0 `TopNav.vue` 中的 `onConfirmRegion` 一致：
  /// 调用 `editMyInfo({province})` 后立即刷新当前用户信息。
  Future<String?> updateProvince(String province) async {
    final response = await _repository.updateProvince(province);
    if (response.code != 0) {
      return response.msg.isEmpty ? '修改失败' : response.msg;
    }
    await refreshUserAndSchool();
    return null;
  }

  @override
  void dispose() {
    _logoTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // 用户+学校数据优先到位（菜单/头像依赖它），消息数据后台并行，不阻塞首帧
    await refreshUserAndSchool();
    unawaited(refreshNoticeData());

    _logoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refreshUserAndSchool());
    });
    _noticeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(refreshNoticeData());
    });
  }

  int _readUnreadCount(dynamic data) {
    if (data is Map<String, dynamic>) {
      final value = data['unReadMsgCount'];
      if (value is int) {
        return value;
      }
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  List<ShellNoticeItem> _parseNoticeList(dynamic data) {
    if (data is! List) {
      return const [];
    }

    final result = <ShellNoticeItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      result.add(
        ShellNoticeItem(
          id: _toInt(item['id']),
          targetType: _toInt(item['targetType']),
          content: item['content']?.toString() ?? '',
          createTime: item['createTime']?.toString() ?? '',
        ),
      );
    }
    return result;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _extractUser(dynamic data) {
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }
    return const {};
  }

  /// 将 `myInfo.user.vipExpireDate` 字段（可能是 `null` / 时间字符串 /
  /// 毫秒数）规整成 [DateTime?]。字符串遵循后端常见的 `yyyy-MM-dd HH:mm:ss`
  /// 形式；解析失败时返回 `null`，由 [ShellUser.isVipActive] 一并视作未
  /// 开通会员。
  static DateTime? _parseVipExpireDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  /// 「未开通会员 / 会员已过期」状态下仍允许访问的路由白名单。
  ///
  /// 设计目标：把用户限制在「个人中心 + 账号管理类页面」之内，让 ta
  /// 能够查看资料、改资料、看协议、退出登录或前往开通会员，但**不能**
  /// 进入首页、校园课件、视频中心等付费内容。
  ///
  /// 公共路由（login / register / forget）不在保护层，无需在此声明。
  static const _vipExemptRoutes = <String>{
    RoutePaths.personalCenter,
    RoutePaths.info,
    RoutePaths.set,
    RoutePaths.helpFeedback,
    RoutePaths.fankui,
    RoutePaths.qrcode,
    RoutePaths.email,
    RoutePaths.verifie,
    RoutePaths.xieyi,
    RoutePaths.xieyi2,
  };

  /// 路由是否在 VIP 失效时仍可访问。供 [ShellScaffold] 在入口拦截与
  /// 自动跳转判定共用。
  static bool isRouteAllowedWithoutVip(String route) {
    return _vipExemptRoutes.contains(route);
  }

  void _syncCampusBadge(int unreadCount) {
    final updated = state.navItems.map((item) {
      if (item.route == RoutePaths.smartCampus) {
        return item.copyWith(badge: unreadCount);
      }
      return item;
    }).toList();
    state = state.copyWith(navItems: updated);
  }
}
