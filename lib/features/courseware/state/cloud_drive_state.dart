import 'dart:convert';
import 'dart:math' as math;

enum CloudFileType {
  audio(1),
  score(2),
  courseware(3);

  const CloudFileType(this.value);

  final int value;

  static CloudFileType fromValue(dynamic value) {
    final intValue = value is int
        ? value
        : int.tryParse(value?.toString() ?? '');
    return switch (intValue) {
      2 => CloudFileType.score,
      3 => CloudFileType.courseware,
      _ => CloudFileType.audio,
    };
  }

  String get label {
    return switch (this) {
      CloudFileType.audio => '音频',
      CloudFileType.score => '谱例',
      CloudFileType.courseware => '课件',
    };
  }
}

enum CloudDriveViewMode { overview, files }

enum CloudDriveSortType {
  /// 默认状态：保持后端接口返回的原始顺序，不做客户端再排序。
  /// 仅在用户主动点击「排序」按钮后才切换到下面的真实排序模式。
  none('默认'),
  name('名称'),
  time('时间'),
  size('大小'),
  type('类型');

  const CloudDriveSortType(this.label);

  final String label;
}

enum CloudUploadKind {
  image('图片'),
  score('谱例'),
  courseware('课件');

  const CloudUploadKind(this.label);

  final String label;
}

class CloudCategoryItem {
  const CloudCategoryItem({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;

  String get subtitle => '已存储 $count 个文件';
}

class CloudFolderItem {
  const CloudFolderItem({
    required this.id,
    required this.title,
    this.sizeLabel = '10MB',
    this.dateLabel = '2026.04.07',
    this.isCreateShortcut = false,
  });

  final int id;
  final String title;
  final String sizeLabel;
  final String dateLabel;
  final bool isCreateShortcut;

  CloudFolderItem copyWith({
    int? id,
    String? title,
    String? sizeLabel,
    String? dateLabel,
    bool? isCreateShortcut,
  }) {
    return CloudFolderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      dateLabel: dateLabel ?? this.dateLabel,
      isCreateShortcut: isCreateShortcut ?? this.isCreateShortcut,
    );
  }
}

class CloudFileItem {
  const CloudFileItem({
    required this.id,
    required this.title,
    required this.type,
    required this.audioUrl,
    required this.imageUrls,
    this.dateLabel = '04.07.2026',
    this.sizeLabel = '10MB',
    this.isPlaying = false,
  });

  final int id;
  final String title;
  final CloudFileType type;
  final String audioUrl;
  final List<String> imageUrls;
  final String dateLabel;
  final String sizeLabel;
  final bool isPlaying;

  CloudFileItem copyWith({
    bool? isPlaying,
    String? title,
    CloudFileType? type,
    String? audioUrl,
    List<String>? imageUrls,
    String? dateLabel,
    String? sizeLabel,
  }) {
    return CloudFileItem(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      dateLabel: dateLabel ?? this.dateLabel,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  Map<String, dynamic> toSharePayload() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'param1': '${type.value}',
      'param2': audioUrl,
      'param3': jsonEncode(imageUrls),
    };
  }
}

class CloudShareClassItem {
  const CloudShareClassItem({
    required this.id,
    required this.name,
    this.selected = false,
  });

  final String id;
  final String name;
  final bool selected;

  CloudShareClassItem copyWith({bool? selected}) {
    return CloudShareClassItem(
      id: id,
      name: name,
      selected: selected ?? this.selected,
    );
  }
}

String _formatCloudStorageBytes(int bytes) {
  if (bytes <= 0) return '0B';
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  const kb = 1024;
  if (bytes >= gb) {
    final v = bytes / gb;
    return v >= 10 ? '${v.round()}GB' : '${v.toStringAsFixed(1)}GB';
  }
  if (bytes >= mb) {
    final v = bytes / mb;
    return v >= 10 ? '${v.round()}MB' : '${v.toStringAsFixed(1)}MB';
  }
  final v = bytes / kb;
  return v >= 10 ? '${v.round()}KB' : '${v.toStringAsFixed(1)}KB';
}

class CloudDriveState {
  const CloudDriveState({
    this.loading = true,
    this.busy = false,
    this.errorMessage = '',
    this.categories = const [],
    this.selectedCategoryId = 0,
    this.folders = const [],
    this.viewMode = CloudDriveViewMode.overview,
    this.currentFolderName = '',
    this.currentFolderId = 0,
    this.files = const [],
    this.selectedFileIds = const [],
    this.sortType = CloudDriveSortType.none,
    this.sortAscending = true,
    this.storageUsedBytes = 0,
    this.storageTotalBytes = 0,
    this.previewingFile,
    this.previewIsPlaying = false,
    this.previewPosition = Duration.zero,
    this.previewDuration = Duration.zero,
    this.previewSpeed = 1.0,
    this.previewActiveImageIndex = 0,
    this.previewFavorite = false,
  });

  final bool loading;
  final bool busy;
  final String errorMessage;
  final List<CloudCategoryItem> categories;
  final int selectedCategoryId;
  final List<CloudFolderItem> folders;
  final CloudDriveViewMode viewMode;
  final String currentFolderName;
  final int currentFolderId;
  final List<CloudFileItem> files;
  final List<int> selectedFileIds;
  final CloudDriveSortType sortType;
  final bool sortAscending;

  /// 云盘已用字节数（来自 `/app/courseware/v2/usage`）。
  final int storageUsedBytes;

  /// 云盘总配额字节数。
  final int storageTotalBytes;

  /// 当前正在预览的文件；为 `null` 时显示文件列表，否则显示预览页。
  final CloudFileItem? previewingFile;

  /// 谱例预览页的播放/进度状态（由 controller 内部 `media_kit` 播放器驱动）。
  final bool previewIsPlaying;
  final Duration previewPosition;
  final Duration previewDuration;
  final double previewSpeed;

  /// 谱例 / 图片类型预览中，右侧缩略图栏激活的页码（0-based）。
  final int previewActiveImageIndex;

  /// 谱例预览页右下角的"已收藏"按钮状态（仅本地维持）。
  final bool previewFavorite;

  /// 0–100，用于进度条（已用 / 总量）。
  double get storageUsagePercent {
    if (storageTotalBytes <= 0) return 0;
    return (storageUsedBytes / storageTotalBytes * 100).clamp(0, 100);
  }

  /// 例如 `168GB可用/512GB`；无有效总量时返回 `—`。
  String get storageAvailabilityLabel {
    if (storageTotalBytes <= 0) return '—';
    final available = math.max(0, storageTotalBytes - storageUsedBytes);
    return '${_formatCloudStorageBytes(available)}可用/'
        '${_formatCloudStorageBytes(storageTotalBytes)}';
  }

  CloudCategoryItem? get selectedCategory {
    for (final item in categories) {
      if (item.id == selectedCategoryId) {
        return item;
      }
    }
    return categories.isEmpty ? null : categories.first;
  }

  bool get isFolderView => viewMode == CloudDriveViewMode.files;

  CloudDriveState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    List<CloudCategoryItem>? categories,
    int? selectedCategoryId,
    List<CloudFolderItem>? folders,
    CloudDriveViewMode? viewMode,
    String? currentFolderName,
    int? currentFolderId,
    List<CloudFileItem>? files,
    List<int>? selectedFileIds,
    CloudDriveSortType? sortType,
    bool? sortAscending,
    int? storageUsedBytes,
    int? storageTotalBytes,
    Object? previewingFile = _unset,
    bool? previewIsPlaying,
    Duration? previewPosition,
    Duration? previewDuration,
    double? previewSpeed,
    int? previewActiveImageIndex,
    bool? previewFavorite,
  }) {
    return CloudDriveState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: errorMessage ?? this.errorMessage,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      folders: folders ?? this.folders,
      viewMode: viewMode ?? this.viewMode,
      currentFolderName: currentFolderName ?? this.currentFolderName,
      currentFolderId: currentFolderId ?? this.currentFolderId,
      files: files ?? this.files,
      selectedFileIds: selectedFileIds ?? this.selectedFileIds,
      sortType: sortType ?? this.sortType,
      sortAscending: sortAscending ?? this.sortAscending,
      storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
      storageTotalBytes: storageTotalBytes ?? this.storageTotalBytes,
      previewingFile: identical(previewingFile, _unset)
          ? this.previewingFile
          : previewingFile as CloudFileItem?,
      previewIsPlaying: previewIsPlaying ?? this.previewIsPlaying,
      previewPosition: previewPosition ?? this.previewPosition,
      previewDuration: previewDuration ?? this.previewDuration,
      previewSpeed: previewSpeed ?? this.previewSpeed,
      previewActiveImageIndex:
          previewActiveImageIndex ?? this.previewActiveImageIndex,
      previewFavorite: previewFavorite ?? this.previewFavorite,
    );
  }
}

const Object _unset = Object();
