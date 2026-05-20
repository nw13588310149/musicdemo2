import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../data/video_tutorial_repository.dart';
import 'video_tutorial_state.dart';

final videoTutorialControllerProvider =
    StateNotifierProvider.autoDispose<
      VideoTutorialController,
      VideoTutorialState
    >((ref) {
      final repository = ref.watch(videoTutorialRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      return VideoTutorialController(repository: repository, storage: storage);
    });

class VideoTutorialController extends StateNotifier<VideoTutorialState> {
  VideoTutorialController({
    required VideoTutorialRepository repository,
    required AppStorage storage,
  }) : _repository = repository,
       _storage = storage,
       super(VideoTutorialState(checkStatusEnabled: storage.hasCheckStatus)) {
    unawaited(refresh());
  }

  final VideoTutorialRepository _repository;
  final AppStorage _storage;
  final Map<String, _VideoListCacheEntry> _listCache =
      <String, _VideoListCacheEntry>{};
  final Set<String> _inFlightPageKeys = <String>{};
  final Map<String, VideoDetail> _detailCache = <String, VideoDetail>{};

  static const int _pageSize = 20;
  static const List<String> _menuOrder = <String>[
    '声乐',
    '歌剧',
    '键盘',
    '中国乐器',
    '西洋乐器',
    '音乐会',
    '大师课',
  ];

  Future<void> refresh() async {
    _listCache.clear();
    _inFlightPageKeys.clear();
    state = state.copyWith(
      loading: true,
      errorMessage: '',
      checkStatusEnabled: _storage.hasCheckStatus,
    );

    final responses = await Future.wait<dynamic>([
      _repository.getBannerList(),
      _repository.getMenuList(),
      _repository.getMyInfo(),
    ]);

    final bannerItems = _parseBanners(responses[0].data);
    final menus = _parseMenus(responses[1].data);
    final vipExpireDate = _parseVipExpireDate(responses[2].data);

    final selectedMenuId = _resolveSelectedMenuId(menus, state.selectedMenuId);
    final selectedChildId = _resolveSelectedChildId(
      menus,
      selectedMenuId,
      state.selectedChildId,
    );

    state = state.copyWith(
      banners: bannerItems,
      menus: menus,
      selectedMenuId: selectedMenuId,
      selectedChildId: selectedChildId,
      clearVipExpireDate: vipExpireDate == null,
      vipExpireDate: vipExpireDate,
      videoList: const [],
      currentPage: 1,
      hasMore: true,
      clearDetail: true,
      showDetailPanel: false,
    );

    await _loadVideoList(reset: true);
  }

  Future<void> selectMenu(String? menuId) async {
    if (state.selectedMenuId == menuId) {
      return;
    }

    final nextChildId = _resolveSelectedChildId(state.menus, menuId, null);
    final cached = _listCache[_cacheKey(menuId, nextChildId)];
    // ⚠️ "全部" tab 的 id 是 null，但 copyWith(selectedMenuId: null) 会被当成
    // "未传"而保留旧值。必须用 clearSelectedMenuId 显式清空，UI 才能切回"全部"。
    state = state.copyWith(
      selectedMenuId: menuId,
      clearSelectedMenuId: menuId == null,
      clearSelectedChildId: true,
      videoList: cached?.items ?? const [],
      currentPage: cached?.currentPage ?? 1,
      hasMore: cached?.hasMore ?? true,
      loading: cached == null,
      loadingMore: false,
      errorMessage: '',
    );

    if (cached == null) {
      await _loadVideoList(reset: true);
    }
  }

  Future<void> selectChildMenu(String? childId) async {
    if (state.selectedChildId == childId) {
      return;
    }

    final cached = _listCache[_cacheKey(state.selectedMenuId, childId)];
    state = state.copyWith(
      selectedChildId: childId,
      videoList: cached?.items ?? const [],
      currentPage: cached?.currentPage ?? 1,
      hasMore: cached?.hasMore ?? true,
      loading: cached == null,
      loadingMore: false,
      errorMessage: '',
    );

    if (cached == null) {
      await _loadVideoList(reset: true);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    await _loadVideoList(reset: false);
  }

  Future<String?> openDetail(VideoListItem item) async {
    final blockReason = _vipBlockReason(item.vip);
    if (blockReason != null) {
      return blockReason;
    }

    final cached = _detailCache[item.id];
    if (cached != null) {
      state = state.copyWith(
        showDetailPanel: true,
        detailLoading: false,
        detailTabIndex: 0,
        detail: cached,
      );
      return null;
    }

    state = state.copyWith(
      showDetailPanel: true,
      detailLoading: true,
      detailTabIndex: 0,
      clearDetail: true,
    );

    final response = await _repository.getVideoDetail(item.id);
    if (!response.isSuccess) {
      state = state.copyWith(detailLoading: false);
      return response.msg.isEmpty ? '加载视频详情失败' : response.msg;
    }

    final detail = _parseVideoDetail(response.data);
    if (detail == null) {
      state = state.copyWith(detailLoading: false);
      return '视频详情数据异常';
    }

    _detailCache[detail.id] = detail;
    state = state.copyWith(detailLoading: false, detail: detail);
    return null;
  }

  /// 通过视频 id 直接打开详情面板。
  ///
  /// 用于从其他页面（如"我的收藏"）跳转过来时——上游只持有 targetId、
  /// 没有 [VideoListItem]。流程与 [openDetail] 基本一致：先查缓存，未命中
  /// 时拉取详情、做 VIP 校验、写入 state；任一步失败时关闭 detailPanel
  /// 并返回错误文案，由 UI 层弹 toast。
  Future<String?> openDetailById(String id) async {
    if (id.isEmpty) {
      return '视频信息缺失';
    }

    final cached = _detailCache[id];
    if (cached != null) {
      final blockReason = _vipBlockReason(cached.vip);
      if (blockReason != null) {
        return blockReason;
      }
      state = state.copyWith(
        showDetailPanel: true,
        detailLoading: false,
        detailTabIndex: 0,
        detail: cached,
      );
      return null;
    }

    state = state.copyWith(
      showDetailPanel: true,
      detailLoading: true,
      detailTabIndex: 0,
      clearDetail: true,
    );

    final response = await _repository.getVideoDetail(id);
    if (!response.isSuccess) {
      state = state.copyWith(detailLoading: false, showDetailPanel: false);
      return response.msg.isEmpty ? '加载视频详情失败' : response.msg;
    }

    final detail = _parseVideoDetail(response.data);
    if (detail == null) {
      state = state.copyWith(detailLoading: false, showDetailPanel: false);
      return '视频详情数据异常';
    }

    final blockReason = _vipBlockReason(detail.vip);
    if (blockReason != null) {
      state = state.copyWith(detailLoading: false, showDetailPanel: false);
      return blockReason;
    }

    _detailCache[detail.id] = detail;
    state = state.copyWith(detailLoading: false, detail: detail);
    return null;
  }

  void closeDetail() {
    state = state.copyWith(showDetailPanel: false);
  }

  void setDetailTab(int index) {
    state = state.copyWith(detailTabIndex: index);
  }

  Future<String?> toggleFavorite() async {
    final detail = state.detail;
    if (detail == null) {
      return '请先打开视频详情';
    }

    state = state.copyWith(busy: true);
    final response = await _repository.toggleFavorite(
      targetId: detail.id,
      favorite: !detail.isFavorite,
    );
    state = state.copyWith(busy: false);

    if (!response.isSuccess) {
      return response.msg.isEmpty ? '收藏状态更新失败' : response.msg;
    }

    final updatedDetail = detail.copyWith(isFavorite: !detail.isFavorite);
    final updatedList = state.videoList.map((item) {
      if (item.id == detail.id) {
        return item.copyWith(isFavorite: !detail.isFavorite);
      }
      return item;
    }).toList();
    _detailCache[updatedDetail.id] = updatedDetail;
    _syncCachedListItem(updatedDetail.id, updatedDetail.isFavorite);

    state = state.copyWith(detail: updatedDetail, videoList: updatedList);
    return null;
  }

  Future<List<VideoShareClassItem>> fetchShareClasses() async {
    final response = await _repository.getClassList();
    if (!response.isSuccess || response.data is! List) {
      return const [];
    }

    final result = <VideoShareClassItem>[];
    for (final item in response.data as List) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(item['id']);
      final name = item['name']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty) {
        continue;
      }
      result.add(VideoShareClassItem(id: id, name: name));
    }
    return result;
  }

  Future<String?> shareCurrentVideo(List<String> classIds) async {
    final detail = state.detail;
    if (detail == null) {
      return '请先打开要分享的视频';
    }
    if (classIds.isEmpty) {
      return '请先选择要分享的班级';
    }

    state = state.copyWith(busy: true);

    final content = jsonEncode(detail.toShareMap());
    for (final classId in classIds) {
      final response = await _repository.shareVideo(
        classId: classId,
        content: content,
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return response.msg.isEmpty ? '发送失败' : response.msg;
      }
    }

    state = state.copyWith(busy: false);
    return null;
  }

  Future<void> _loadVideoList({required bool reset}) async {
    final cacheKey = _cacheKey(state.selectedMenuId, state.selectedChildId);
    final cached = _listCache[cacheKey];
    final page = reset ? 1 : (cached?.currentPage ?? state.currentPage) + 1;
    final pageKey = '$cacheKey#$page';
    if (_inFlightPageKeys.contains(pageKey)) {
      return;
    }
    if (!reset && cached?.requestedPages.contains(page) == true) {
      state = state.copyWith(
        videoList: cached!.items,
        currentPage: cached.currentPage,
        hasMore: cached.hasMore,
      );
      return;
    }

    _inFlightPageKeys.add(pageKey);
    state = state.copyWith(
      loading: reset,
      loadingMore: !reset,
      errorMessage: '',
    );

    final response = await _repository.getVideoList(
      current: page,
      size: _pageSize,
      firstMenu: state.selectedMenuId,
      secondMenu: state.selectedChildId,
    );
    _inFlightPageKeys.remove(pageKey);

    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        errorMessage: response.msg.isEmpty ? '视频列表加载失败' : response.msg,
      );
      return;
    }

    final list = _parseVideoList(response.data);
    final baseItems = reset
        ? const <VideoListItem>[]
        : (cached?.items ?? state.videoList);
    final merged = _mergeUnique(baseItems, list);
    final hasMore =
        list.length >= _pageSize && merged.length > baseItems.length;
    final requestedPages = <int>{...?cached?.requestedPages, page};
    _listCache[cacheKey] = _VideoListCacheEntry(
      items: merged,
      currentPage: page,
      hasMore: hasMore,
      requestedPages: requestedPages,
    );

    state = state.copyWith(
      loading: false,
      loadingMore: false,
      videoList: merged,
      currentPage: page,
      hasMore: hasMore,
      errorMessage: merged.isEmpty ? '暂无视频数据' : '',
    );
  }

  String _cacheKey(String? firstMenu, String? secondMenu) {
    return '${firstMenu ?? 'all'}|${secondMenu ?? 'all'}';
  }

  List<VideoListItem> _mergeUnique(
    List<VideoListItem> base,
    List<VideoListItem> incoming,
  ) {
    final result = <VideoListItem>[];
    final seen = <String>{};
    for (final item in <VideoListItem>[...base, ...incoming]) {
      if (item.id.isEmpty || !seen.add(item.id)) {
        continue;
      }
      result.add(item);
    }
    return result;
  }

  void _syncCachedListItem(String id, bool isFavorite) {
    for (final entry in _listCache.entries.toList()) {
      final nextItems = entry.value.items
          .map(
            (item) =>
                item.id == id ? item.copyWith(isFavorite: isFavorite) : item,
          )
          .toList(growable: false);
      _listCache[entry.key] = entry.value.copyWith(items: nextItems);
    }
  }

  List<VideoBannerItem> _parseBanners(dynamic data) {
    if (data is! List) {
      return const [];
    }

    final result = <VideoBannerItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final img = item['img']?.toString() ?? '';
      if (img.isEmpty) {
        continue;
      }
      result.add(VideoBannerItem(imageUrl: img));
    }
    return result;
  }

  List<VideoMenu> _parseMenus(dynamic data) {
    final parsedMenus = <VideoMenu>[];

    if (data is List) {
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final id = _toIdString(item['id']);
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) {
          continue;
        }

        final children = <VideoMenuChild>[];
        final rawChildren = item['children'];
        if (rawChildren is List) {
          for (final child in rawChildren) {
            if (child is! Map<String, dynamic>) {
              continue;
            }
            final childId = _toIdString(child['id']);
            final childName = child['name']?.toString().trim() ?? '';
            if (childId.isEmpty || childName.isEmpty) {
              continue;
            }
            children.add(VideoMenuChild(id: childId, name: childName));
          }
        }

        parsedMenus.add(
          VideoMenu(id: id.isEmpty ? null : id, name: name, children: children),
        );
      }
    }

    parsedMenus.sort((a, b) {
      final ai = _menuOrder.indexOf(a.name);
      final bi = _menuOrder.indexOf(b.name);
      final aOrder = ai < 0 ? 999 : ai;
      final bOrder = bi < 0 ? 999 : bi;
      return aOrder.compareTo(bOrder);
    });

    final allChildren = <VideoMenuChild>[];
    for (final menu in parsedMenus) {
      allChildren.addAll(menu.children);
    }

    return <VideoMenu>[
      VideoMenu(id: null, name: '全部', children: allChildren),
      ...parsedMenus,
    ];
  }

  List<VideoListItem> _parseVideoList(dynamic data) {
    final rawList = _extractList(data);
    final result = <VideoListItem>[];

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(item['id']);
      if (id.isEmpty) {
        continue;
      }
      result.add(
        VideoListItem(
          id: id,
          name: item['name']?.toString() ?? '',
          coverImg: item['coverImg']?.toString() ?? '',
          duration: item['duration']?.toString() ?? '--:--',
          playCount: _toInt(item['playCount']),
          vip: _toInt(item['vip']),
          isFavorite: _toBool(item['isFavorite']),
        ),
      );
    }

    return result;
  }

  VideoDetail? _parseVideoDetail(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final id = _toIdString(data['id']);
    if (id.isEmpty) {
      return null;
    }

    final seriesList = _parseVideoList(data['seriesVideoList']);

    return VideoDetail(
      id: id,
      name: data['name']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
      coverImg: data['coverImg']?.toString() ?? '',
      description: data['param3']?.toString() ?? '',
      vip: _toInt(data['vip']),
      isFavorite: _toBool(data['isFavorite']),
      scoreImages: _parseScoreImages(data['param1']),
      seriesVideoList: seriesList,
      duration: data['duration']?.toString() ?? '--:--',
      playCount: _toInt(data['playCount']),
    );
  }

  List<String> _parseScoreImages(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty && e != 'null')
          .toList();
    }

    final text = value?.toString() ?? '';
    if (text.isEmpty || text == 'null') {
      return const [];
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty && e != 'null')
            .toList();
      }
      if (decoded is String && decoded.isNotEmpty) {
        return <String>[decoded];
      }
    } catch (_) {
      // Keep original string as a single image URL.
    }

    return <String>[text];
  }

  DateTime? _parseVipExpireDate(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      return null;
    }

    final rawDate = user['vipExpireDate']?.toString() ?? '';
    if (rawDate.isEmpty || rawDate == 'null') {
      return null;
    }
    return DateTime.tryParse(rawDate);
  }

  String? _vipBlockReason(int vip) {
    if (vip != 1) {
      return null;
    }

    final vipExpireDate = state.vipExpireDate;
    if (vipExpireDate == null) {
      return '您还未开通会员';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expireDay = DateTime(
      vipExpireDate.year,
      vipExpireDate.month,
      vipExpireDate.day,
    );

    if (expireDay.isBefore(today)) {
      return '您的会员已过期，请续费';
    }
    return null;
  }

  String? _resolveSelectedMenuId(List<VideoMenu> menus, String? currentId) {
    if (menus.isEmpty) {
      return null;
    }
    final exists = menus.any((menu) => menu.id == currentId);
    return exists ? currentId : null;
  }

  String? _resolveSelectedChildId(
    List<VideoMenu> menus,
    String? selectedMenuId,
    String? currentChildId,
  ) {
    if (currentChildId == null) {
      return null;
    }

    VideoMenu? menu;
    for (final item in menus) {
      if (item.id == selectedMenuId) {
        menu = item;
        break;
      }
    }
    menu ??= menus.isEmpty ? null : menus.first;
    if (menu == null) {
      return null;
    }

    final exists = menu.children.any((child) => child.id == currentChildId);
    return exists ? currentChildId : null;
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final records = data['records'];
      if (records is List) {
        return records;
      }
      final list = data['list'];
      if (list is List) {
        return list;
      }
    }
    return const [];
  }

  String _toIdString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is int) {
      return value.toString();
    }
    if (value is num) {
      // Avoid sending "123.0" or scientific notation style IDs to detail APIs.
      if (value == value.toInt()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') {
      return '';
    }
    if (text.endsWith('.0')) {
      final trimmed = text.substring(0, text.length - 2);
      if (int.tryParse(trimmed) != null) {
        return trimmed;
      }
    }
    return text;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase() ?? '';
    return text == 'true' || text == '1';
  }
}

class VideoShareClassItem {
  const VideoShareClassItem({required this.id, required this.name});

  final String id;
  final String name;
}

class _VideoListCacheEntry {
  const _VideoListCacheEntry({
    required this.items,
    required this.currentPage,
    required this.hasMore,
    required this.requestedPages,
  });

  final List<VideoListItem> items;
  final int currentPage;
  final bool hasMore;
  final Set<int> requestedPages;

  _VideoListCacheEntry copyWith({
    List<VideoListItem>? items,
    int? currentPage,
    bool? hasMore,
    Set<int>? requestedPages,
  }) {
    return _VideoListCacheEntry(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      requestedPages: requestedPages ?? this.requestedPages,
    );
  }
}
