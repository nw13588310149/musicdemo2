class VideoBannerItem {
  const VideoBannerItem({required this.imageUrl});

  final String imageUrl;
}

class VideoMenuChild {
  const VideoMenuChild({required this.id, required this.name});

  final String id;
  final String name;
}

class VideoMenu {
  const VideoMenu({
    required this.id,
    required this.name,
    required this.children,
  });

  final String? id;
  final String name;
  final List<VideoMenuChild> children;
}

class VideoListItem {
  const VideoListItem({
    required this.id,
    required this.name,
    required this.coverImg,
    required this.duration,
    required this.playCount,
    required this.vip,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String coverImg;
  final String duration;
  final int playCount;
  final int vip;
  final bool isFavorite;

  VideoListItem copyWith({bool? isFavorite}) {
    return VideoListItem(
      id: id,
      name: name,
      coverImg: coverImg,
      duration: duration,
      playCount: playCount,
      vip: vip,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toShareMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'coverImg': coverImg,
      'duration': duration,
      'playCount': playCount,
      'vip': vip,
    };
  }
}

class VideoDetail {
  const VideoDetail({
    required this.id,
    required this.name,
    required this.url,
    required this.coverImg,
    required this.description,
    required this.vip,
    required this.isFavorite,
    required this.scoreImages,
    required this.seriesVideoList,
    required this.duration,
    required this.playCount,
  });

  final String id;
  final String name;
  final String url;
  final String coverImg;
  final String description;
  final int vip;
  final bool isFavorite;
  final List<String> scoreImages;
  final List<VideoListItem> seriesVideoList;
  final String duration;
  final int playCount;

  VideoDetail copyWith({bool? isFavorite}) {
    return VideoDetail(
      id: id,
      name: name,
      url: url,
      coverImg: coverImg,
      description: description,
      vip: vip,
      isFavorite: isFavorite ?? this.isFavorite,
      scoreImages: scoreImages,
      seriesVideoList: seriesVideoList,
      duration: duration,
      playCount: playCount,
    );
  }

  Map<String, dynamic> toShareMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'coverImg': coverImg,
      'url': url,
      'duration': duration,
      'playCount': playCount,
      'vip': vip,
      'isFavorite': isFavorite,
      'param1': scoreImages,
      'param3': description,
      'seriesVideoList': seriesVideoList
          .map((item) => item.toShareMap())
          .toList(),
    };
  }
}

class VideoTutorialState {
  const VideoTutorialState({
    this.loading = true,
    this.loadingMore = false,
    this.detailLoading = false,
    this.banners = const [],
    this.menus = const [],
    this.selectedMenuId,
    this.selectedChildId,
    this.videoList = const [],
    this.currentPage = 1,
    this.hasMore = true,
    this.showDetailPanel = false,
    this.detailTabIndex = 0,
    this.detail,
    this.vipExpireDate,
    this.checkStatusEnabled = false,
    this.busy = false,
    this.errorMessage = '',
  });

  final bool loading;
  final bool loadingMore;
  final bool detailLoading;
  final List<VideoBannerItem> banners;
  final List<VideoMenu> menus;
  final String? selectedMenuId;
  final String? selectedChildId;
  final List<VideoListItem> videoList;
  final int currentPage;
  final bool hasMore;
  final bool showDetailPanel;
  final int detailTabIndex;
  final VideoDetail? detail;
  final DateTime? vipExpireDate;
  final bool checkStatusEnabled;
  final bool busy;
  final String errorMessage;

  VideoMenu? get selectedMenu {
    for (final menu in menus) {
      if (menu.id == selectedMenuId) {
        return menu;
      }
    }
    return menus.isEmpty ? null : menus.first;
  }

  VideoTutorialState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? detailLoading,
    List<VideoBannerItem>? banners,
    List<VideoMenu>? menus,
    String? selectedMenuId,
    bool clearSelectedMenuId = false,
    String? selectedChildId,
    bool clearSelectedChildId = false,
    List<VideoListItem>? videoList,
    int? currentPage,
    bool? hasMore,
    bool? showDetailPanel,
    int? detailTabIndex,
    VideoDetail? detail,
    bool clearDetail = false,
    DateTime? vipExpireDate,
    bool clearVipExpireDate = false,
    bool? checkStatusEnabled,
    bool? busy,
    String? errorMessage,
  }) {
    return VideoTutorialState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      detailLoading: detailLoading ?? this.detailLoading,
      banners: banners ?? this.banners,
      menus: menus ?? this.menus,
      selectedMenuId: clearSelectedMenuId
          ? null
          : (selectedMenuId ?? this.selectedMenuId),
      selectedChildId: clearSelectedChildId
          ? null
          : (selectedChildId ?? this.selectedChildId),
      videoList: videoList ?? this.videoList,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      showDetailPanel: showDetailPanel ?? this.showDetailPanel,
      detailTabIndex: detailTabIndex ?? this.detailTabIndex,
      detail: clearDetail ? null : (detail ?? this.detail),
      vipExpireDate: clearVipExpireDate
          ? null
          : (vipExpireDate ?? this.vipExpireDate),
      checkStatusEnabled: checkStatusEnabled ?? this.checkStatusEnabled,
      busy: busy ?? this.busy,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
