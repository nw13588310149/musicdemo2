class CollectionTabItem {
  const CollectionTabItem({required this.type, required this.label});

  final int type;
  final String label;
}

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.targetId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.authorName,
    required this.avatarUrl,
    required this.metricText,
    required this.durationText,
    required this.rawPayload,
  });

  final int id;
  final int targetId;
  final int type;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String authorName;
  final String avatarUrl;
  final String metricText;
  final String durationText;
  final Map<String, dynamic> rawPayload;

  bool get isVideo => type == 6;
  bool get isVocalOrInstrument => type == 4 || type == 5;
  bool get isLesson => type == 1 || type == 2 || type == 3 || type == 10;
}

class CollectionShareClass {
  const CollectionShareClass({
    required this.id,
    required this.name,
    this.selected = false,
  });

  final int id;
  final String name;
  final bool selected;

  CollectionShareClass copyWith({int? id, String? name, bool? selected}) {
    return CollectionShareClass(
      id: id ?? this.id,
      name: name ?? this.name,
      selected: selected ?? this.selected,
    );
  }
}

class MyCollectionState {
  const MyCollectionState({
    this.loading = false,
    this.busy = false,
    this.errorMessage,
    this.tabs = const <CollectionTabItem>[],
    this.activeType = 4,
    this.items = const <CollectionEntry>[],
    this.shareClasses = const <CollectionShareClass>[],
    this.shareTarget,
  });

  final bool loading;
  final bool busy;
  final String? errorMessage;
  final List<CollectionTabItem> tabs;
  final int activeType;
  final List<CollectionEntry> items;
  final List<CollectionShareClass> shareClasses;
  final CollectionEntry? shareTarget;

  MyCollectionState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    List<CollectionTabItem>? tabs,
    int? activeType,
    List<CollectionEntry>? items,
    List<CollectionShareClass>? shareClasses,
    CollectionEntry? shareTarget,
    bool clearShareTarget = false,
  }) {
    return MyCollectionState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tabs: tabs ?? this.tabs,
      activeType: activeType ?? this.activeType,
      items: items ?? this.items,
      shareClasses: shareClasses ?? this.shareClasses,
      shareTarget: clearShareTarget ? null : (shareTarget ?? this.shareTarget),
    );
  }
}

/// 我的收藏 Tab 顺序：声乐 → 器乐 → 听写 → 视唱 → 乐理 → 试题 → 视频，
/// 与设计稿顶部分段控件顺序一致，与服务端返回的 type 字段保持一一对应。
/// type=10 对应"试题"，与 study_catalog / answerQuestions 模块一致。
const List<CollectionTabItem> kCollectionDefaultTabs = <CollectionTabItem>[
  CollectionTabItem(type: 4, label: '声乐'),
  CollectionTabItem(type: 5, label: '器乐'),
  CollectionTabItem(type: 3, label: '听写'),
  CollectionTabItem(type: 1, label: '视唱'),
  CollectionTabItem(type: 2, label: '乐理'),
  CollectionTabItem(type: 10, label: '试题'),
  CollectionTabItem(type: 6, label: '视频'),
];

const Map<String, int> kCollectionTypeByLabel = <String, int>{
  '视唱': 1,
  '乐理': 2,
  '听写': 3,
  '声乐': 4,
  '器乐': 5,
  '视频': 6,
  '试题': 10,
};
