import 'dart:typed_data';

enum RecordingViewMode { list, record, preview }

/// 在 [RecordingViewMode.list] 内部的二级视图：
/// - [folders] 显示当前分类下的文件夹列表（参照「我的云盘」一级页面）。
/// - [files]   进入某个文件夹后显示该文件夹下的录音文件列表。
enum RecordingListView { folders, files }

enum RecordingPhase { idle, recording, paused }

class RecordingCategoryItem {
  const RecordingCategoryItem({
    required this.id,
    required this.name,
    this.count = 0,
  });

  final int id;
  final String name;
  final int count;
}

/// 录音系统中分类下挂载的「文件夹」节点，用于和我的云盘保持相同的层级结构。
/// 实际的录音文件由 [RecordingEntry] 表达，存放在某个 `folderId` 之下。
class RecordingFolderItem {
  const RecordingFolderItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.count = 0,
    this.sizeLabel = '',
    this.dateLabel = '',
  });

  final int id;
  final int categoryId;
  final String name;
  final int count;
  final String sizeLabel;
  final String dateLabel;
}

class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.url,
    required this.durationLabel,
    required this.waveform,
    required this.payload,
    this.sizeLabel = '',
    this.dateLabel = '',
    this.isLocalDraft = false,
  });

  final int id;
  final int categoryId;
  final String name;
  final String url;
  final String durationLabel;
  final List<double> waveform;
  final Map<String, dynamic> payload;

  /// 文件大小展示串（如 `1.2MB`），来自后端 `fileSize` / `size` 字段；
  /// 与「我的云盘」文件卡的右下角信息一致。
  final String sizeLabel;

  /// 创建时间展示串（如 `05.06.2026`），来自后端 `createTime` 字段；
  /// 与「我的云盘」文件卡的右下角信息一致。
  final String dateLabel;
  final bool isLocalDraft;
}

class RecordingShareClass {
  const RecordingShareClass({
    required this.id,
    required this.name,
    this.selected = false,
  });

  final String id;
  final String name;
  final bool selected;

  RecordingShareClass copyWith({String? id, String? name, bool? selected}) {
    return RecordingShareClass(
      id: id ?? this.id,
      name: name ?? this.name,
      selected: selected ?? this.selected,
    );
  }
}

class RecordingSystemState {
  const RecordingSystemState({
    this.loading = false,
    this.busy = false,
    this.errorMessage,
    this.viewMode = RecordingViewMode.list,
    this.listView = RecordingListView.folders,
    this.categories = const <RecordingCategoryItem>[],
    this.selectedCategoryId = 0,
    this.folders = const <RecordingFolderItem>[],
    this.currentFolderId = 0,
    this.currentFolderName = '',
    this.items = const <RecordingEntry>[],
    this.searchQuery = '',
    this.recordingPhase = RecordingPhase.idle,
    this.elapsedMs = 0,
    this.liveWaveform = const <double>[],
    this.previewItem,
    this.previewSource,
    this.previewPositionMs = 0,
    this.previewDurationMs = 0,
    this.previewPlaying = false,
    this.previewPlaybackRate = 1,
    this.previewCollected = false,
    this.recordedBytes,
    this.showSaveDialog = false,
    this.showShareDialog = false,
    this.shareClasses = const <RecordingShareClass>[],
    this.selectedSaveCategoryId = 0,
    this.pendingTitle = '',
    this.selectedEffectIndex = 0,
  });

  final bool loading;
  final bool busy;
  final String? errorMessage;
  final RecordingViewMode viewMode;

  /// 列表视图下的二级视图：文件夹概览或文件夹内部文件列表。
  final RecordingListView listView;
  final List<RecordingCategoryItem> categories;
  final int selectedCategoryId;

  /// 当前分类下的文件夹列表。
  final List<RecordingFolderItem> folders;

  /// 当前已进入的文件夹 id（0 表示尚未进入任何文件夹，正在看文件夹列表）。
  final int currentFolderId;

  /// 当前已进入的文件夹名称（用于面包屑显示）。
  final String currentFolderName;
  final List<RecordingEntry> items;
  final String searchQuery;
  final RecordingPhase recordingPhase;
  final int elapsedMs;
  final List<double> liveWaveform;
  final RecordingEntry? previewItem;
  final String? previewSource;
  final int previewPositionMs;
  final int previewDurationMs;
  final bool previewPlaying;
  final double previewPlaybackRate;
  final bool previewCollected;
  final Uint8List? recordedBytes;
  final bool showSaveDialog;
  final bool showShareDialog;
  final List<RecordingShareClass> shareClasses;
  final int selectedSaveCategoryId;
  final String pendingTitle;
  final int selectedEffectIndex;

  /// 是否已经进入某个文件夹（即"文件视图"）。
  bool get isInsideFolder => listView == RecordingListView.files;

  List<RecordingEntry> get visibleItems {
    final keyword = searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return items;
    }
    return items
        .where((item) => item.name.toLowerCase().contains(keyword))
        .toList();
  }

  RecordingCategoryItem? get selectedCategory {
    for (final item in categories) {
      if (item.id == selectedCategoryId) {
        return item;
      }
    }
    return categories.isEmpty ? null : categories.first;
  }

  RecordingSystemState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    RecordingViewMode? viewMode,
    RecordingListView? listView,
    List<RecordingCategoryItem>? categories,
    int? selectedCategoryId,
    List<RecordingFolderItem>? folders,
    int? currentFolderId,
    String? currentFolderName,
    List<RecordingEntry>? items,
    String? searchQuery,
    RecordingPhase? recordingPhase,
    int? elapsedMs,
    List<double>? liveWaveform,
    RecordingEntry? previewItem,
    bool clearPreviewItem = false,
    String? previewSource,
    bool clearPreviewSource = false,
    int? previewPositionMs,
    int? previewDurationMs,
    bool? previewPlaying,
    double? previewPlaybackRate,
    bool? previewCollected,
    Uint8List? recordedBytes,
    bool clearRecordedBytes = false,
    bool? showSaveDialog,
    bool? showShareDialog,
    List<RecordingShareClass>? shareClasses,
    int? selectedSaveCategoryId,
    String? pendingTitle,
    int? selectedEffectIndex,
  }) {
    return RecordingSystemState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      viewMode: viewMode ?? this.viewMode,
      listView: listView ?? this.listView,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      folders: folders ?? this.folders,
      currentFolderId: currentFolderId ?? this.currentFolderId,
      currentFolderName: currentFolderName ?? this.currentFolderName,
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      recordingPhase: recordingPhase ?? this.recordingPhase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      liveWaveform: liveWaveform ?? this.liveWaveform,
      previewItem: clearPreviewItem ? null : (previewItem ?? this.previewItem),
      previewSource: clearPreviewSource
          ? null
          : (previewSource ?? this.previewSource),
      previewPositionMs: previewPositionMs ?? this.previewPositionMs,
      previewDurationMs: previewDurationMs ?? this.previewDurationMs,
      previewPlaying: previewPlaying ?? this.previewPlaying,
      previewPlaybackRate: previewPlaybackRate ?? this.previewPlaybackRate,
      previewCollected: previewCollected ?? this.previewCollected,
      recordedBytes: clearRecordedBytes
          ? null
          : (recordedBytes ?? this.recordedBytes),
      showSaveDialog: showSaveDialog ?? this.showSaveDialog,
      showShareDialog: showShareDialog ?? this.showShareDialog,
      shareClasses: shareClasses ?? this.shareClasses,
      selectedSaveCategoryId:
          selectedSaveCategoryId ?? this.selectedSaveCategoryId,
      pendingTitle: pendingTitle ?? this.pendingTitle,
      selectedEffectIndex: selectedEffectIndex ?? this.selectedEffectIndex,
    );
  }
}
