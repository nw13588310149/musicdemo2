import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../../core/network/upload_result.dart';
import '../data/cloud_drive_repository.dart';
import 'cloud_drive_state.dart';

final cloudDriveControllerProvider =
    StateNotifierProvider.autoDispose<CloudDriveController, CloudDriveState>((
      ref,
    ) {
      final repository = ref.watch(cloudDriveRepositoryProvider);
      return CloudDriveController(repository: repository);
    });

class CloudDriveController extends StateNotifier<CloudDriveState> {
  CloudDriveController({required CloudDriveRepository repository})
    : _repository = repository,
      super(const CloudDriveState()) {
    unawaited(refresh());
  }

  final CloudDriveRepository _repository;

  // ── 谱例预览页：媒体播放器 ───────────────────────────────────────────────
  // 仅在打开谱例预览且 `audioUrl` 非空时延迟创建。关闭预览时一并 dispose。
  Player? _previewPlayer;
  StreamSubscription<bool>? _previewPlayingSub;
  StreamSubscription<Duration>? _previewPositionSub;
  StreamSubscription<Duration>? _previewDurationSub;
  StreamSubscription<bool>? _previewCompletedSub;

  @override
  void dispose() {
    _disposePreviewPlayer();
    super.dispose();
  }

  void _disposePreviewPlayer() {
    _previewPlayingSub?.cancel();
    _previewPositionSub?.cancel();
    _previewDurationSub?.cancel();
    _previewCompletedSub?.cancel();
    _previewPlayingSub = null;
    _previewPositionSub = null;
    _previewDurationSub = null;
    _previewCompletedSub = null;
    final p = _previewPlayer;
    _previewPlayer = null;
    if (p != null) {
      unawaited(p.dispose());
    }
  }

  /// 调用文件上传接口，成功返回**后端要求保存的 path**（相对路径，例如
  /// `app/upload/.../foo.png`，由 `recordingSave/coursewareSave` 等接口直接
  /// 持久化）；失败返回 null（错误信息进入 `state.errorMessage`）。
  /// 会翻转全局 busy 标志。
  Future<String?> uploadFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      state = state.copyWith(errorMessage: '空文件无法上传');
      return null;
    }
    state = state.copyWith(busy: true, errorMessage: '');
    final response = await _repository.uploadFile(
      bytes: bytes,
      filename: filename,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      state = state.copyWith(
        errorMessage: response.msg.isEmpty ? '文件上传失败' : response.msg,
      );
      return null;
    }
    final result = parseUploadResult(response.data);
    if (result.isEmpty) {
      state = state.copyWith(errorMessage: '文件上传失败：未返回地址');
      return null;
    }
    return result.savable;
  }

  /// 上传文件，带实时进度回调 [onProgress]（0.0–1.0）。
  /// 不影响全局 busy 状态，适合在对话框内按文件独立追踪进度。
  /// 成功返回**后端要求保存的 path**；失败返回 null。
  Future<String?> uploadFileRaw({
    required Uint8List bytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) return null;
    final response = await _repository.uploadFileWithProgress(
      bytes: bytes,
      filename: filename,
      onSendProgress: onProgress != null
          ? (sent, total) {
              if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
            }
          : null,
    );
    if (!response.isSuccess) return null;
    final result = parseUploadResult(response.data);
    return result.isEmpty ? null : result.savable;
  }

  /// 把后端返回的相对路径补齐为完整 URL。
  ///
  /// 内部委托给全局 `MediaUrl.resolve`，由 `/app/common/v2/configList`
  /// 拉到的文件服务器域名来做拼接（缓存于 `AppStorage.fileBaseUrl`，回退
  /// 到 `AppConstants.apiBaseUrl`）。
  Future<String?> uploadFilePathRaw({
    required String filePath,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    if (filePath.trim().isEmpty) return null;
    final response = await _repository.uploadFilePathWithProgress(
      filePath: filePath,
      filename: filename,
      onSendProgress: onProgress != null
          ? (sent, total) {
              if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
            }
          : null,
    );
    if (!response.isSuccess) return null;
    final result = parseUploadResult(response.data);
    return result.isEmpty ? null : result.savable;
  }

  static String resolveMediaUrl(String raw) => MediaUrl.resolve(raw);

  Future<void> refresh() async {
    final wasFolderView = state.isFolderView;
    final currentFolderId = state.currentFolderId;
    final currentFolderName = state.currentFolderName;
    state = state.copyWith(loading: true, errorMessage: '');

    final responses = await Future.wait([
      _repository.getCategoryList(),
      _repository.getCoursewareUsage(),
    ]);
    final categoryResponse = responses[0];
    final usageResponse = responses[1];
    final usage = _parseUsageFromResponse(usageResponse);

    final categories = _parseCategories(categoryResponse.data);

    if (categories.isEmpty) {
      state = state.copyWith(
        loading: false,
        categories: const <CloudCategoryItem>[],
        selectedCategoryId: 0,
        folders: const <CloudFolderItem>[],
        files: const <CloudFileItem>[],
        viewMode: CloudDriveViewMode.overview,
        currentFolderName: '',
        currentFolderId: 0,
        selectedFileIds: const <int>[],
        errorMessage: '',
        storageUsedBytes: usage.$1,
        storageTotalBytes: usage.$2,
      );
      return;
    }

    final selectedId = _resolveSelectedCategoryId(categories);
    final folders = await _fetchFolders(selectedId);
    final isStillInFolder =
        wasFolderView &&
        currentFolderId > 0 &&
        folders.any((item) => item.id == currentFolderId);
    final files = await _fetchFiles(
      categoryId: selectedId,
      folderId: isStillInFolder ? currentFolderId : 0,
    );

    state = state.copyWith(
      loading: false,
      categories: categories,
      selectedCategoryId: selectedId,
      folders: _sortFolders(folders, state.sortType, state.sortAscending),
      viewMode: isStillInFolder
          ? CloudDriveViewMode.files
          : CloudDriveViewMode.overview,
      currentFolderName: isStillInFolder ? currentFolderName : '',
      currentFolderId: isStillInFolder ? currentFolderId : 0,
      files: _sortFiles(files, state.sortType, state.sortAscending),
      selectedFileIds: const <int>[],
      errorMessage: '',
      storageUsedBytes: usage.$1,
      storageTotalBytes: usage.$2,
    );
  }

  Future<void> selectCategory(int categoryId) async {
    if (categoryId == state.selectedCategoryId) {
      return;
    }

    state = state.copyWith(
      loading: true,
      selectedCategoryId: categoryId,
      viewMode: CloudDriveViewMode.overview,
      currentFolderName: '',
      currentFolderId: 0,
      selectedFileIds: const <int>[],
    );
    final folders = await _fetchFolders(categoryId);
    final files = await _fetchFiles(categoryId: categoryId);
    state = state.copyWith(
      loading: false,
      files: _sortFiles(files, state.sortType, state.sortAscending),
      folders: _sortFolders(folders, state.sortType, state.sortAscending),
    );
  }

  Future<void> openFolder(CloudFolderItem folder) async {
    if (folder.isCreateShortcut) {
      return;
    }
    state = state.copyWith(
      loading: true,
      viewMode: CloudDriveViewMode.files,
      currentFolderName: folder.title,
      currentFolderId: folder.id,
      selectedFileIds: const <int>[],
    );
    final files = await _fetchFiles(
      categoryId: state.selectedCategoryId,
      folderId: folder.id,
    );
    state = state.copyWith(
      loading: false,
      files: _sortFiles(files, state.sortType, state.sortAscending),
    );
  }

  Future<void> backToOverview() async {
    state = state.copyWith(
      loading: true,
      viewMode: CloudDriveViewMode.overview,
      currentFolderName: '',
      currentFolderId: 0,
      selectedFileIds: const <int>[],
    );
    final files = await _fetchFiles(categoryId: state.selectedCategoryId);
    state = state.copyWith(
      loading: false,
      files: _sortFiles(files, state.sortType, state.sortAscending),
    );
  }

  void setSortType(CloudDriveSortType sortType) {
    // 工具栏「排序」按钮会回传 `state.sortType`，所以默认状态（none）下点击
    // 按钮等于 `setSortType(none)`。这种情况下 toggle ascending 是无效操作
    // （none 永远保持接口顺序），因此把首次点击重定向到「名称升序」，让
    // 排序按钮在默认态下也有真实的视觉反馈；后续点击则维持「同 sortType
    // 切换升降序、不同 sortType 重置为升序」的既有交互。
    CloudDriveSortType targetType = sortType;
    bool sortAscending;
    if (sortType == CloudDriveSortType.none) {
      if (state.sortType == CloudDriveSortType.none) {
        targetType = CloudDriveSortType.name;
        sortAscending = true;
      } else {
        sortAscending = state.sortAscending;
      }
    } else if (state.sortType == sortType) {
      sortAscending = !state.sortAscending;
    } else {
      sortAscending = true;
    }
    state = state.copyWith(
      sortType: targetType,
      sortAscending: sortAscending,
      files: _sortFiles(state.files, targetType, sortAscending),
      folders: _sortFolders(state.folders, targetType, sortAscending),
    );
  }

  void toggleFileSelection(int fileId) {
    final selected = <int>[...state.selectedFileIds];
    if (selected.contains(fileId)) {
      selected.remove(fileId);
    } else {
      selected.add(fileId);
    }
    state = state.copyWith(selectedFileIds: selected);
  }

  void toggleSelectAllDisplayed(List<int> visibleIds) {
    final allSelected =
        visibleIds.isNotEmpty &&
        visibleIds.every(state.selectedFileIds.contains);
    state = state.copyWith(
      selectedFileIds: allSelected ? const <int>[] : visibleIds,
    );
  }

  void clearSelection() {
    if (state.selectedFileIds.isEmpty) {
      return;
    }
    state = state.copyWith(selectedFileIds: const <int>[]);
  }

  Future<String?> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入分类名称';
    }

    state = state.copyWith(busy: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '新增分类失败' : response.msg;
    }

    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    if (id <= 0) {
      return null;
    }

    state = state.copyWith(busy: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '删除分类失败' : response.msg;
    }
    await refresh();
    return null;
  }

  /// 重命名分类（调用接口）。
  Future<String?> renameCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入分类名称';
    }
    if (id <= 0) {
      return '无效的分类';
    }

    state = state.copyWith(busy: true);
    final response = await _repository.renameCategory(id, trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '重命名失败' : response.msg;
    }
    await refresh();
    return null;
  }

  // ── Folder ────────────────────────────────────────────────────────────────

  /// 新建文件夹（调用接口）。
  Future<String?> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入文件夹名称';
    }
    if (state.selectedCategoryId <= 0) {
      return '请先选择分类';
    }

    state = state.copyWith(busy: true);
    final response = await _repository.addFolder(
      categoryId: state.selectedCategoryId,
      name: trimmed,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '新建文件夹失败' : response.msg;
    }
    await _refreshFoldersOnly();
    return null;
  }

  /// 重命名文件夹（调用接口）。
  Future<String?> renameFolder(int folderId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入文件夹名称';
    }
    if (folderId <= 0) {
      return '无效的文件夹';
    }
    final categoryId = state.selectedCategoryId;
    if (categoryId <= 0) {
      return '请先选择分类';
    }

    state = state.copyWith(busy: true);
    final response = await _repository.renameFolder(
      categoryId: categoryId,
      id: folderId,
      name: trimmed,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '重命名失败' : response.msg;
    }

    // 如果当前正处于该文件夹详情视图，本地同步更新名称
    if (state.isFolderView && state.currentFolderId == folderId) {
      state = state.copyWith(currentFolderName: trimmed);
    }
    await _refreshFoldersOnly();
    return null;
  }

  /// 删除文件夹（调用接口）。
  Future<String?> deleteFolder(int folderId) async {
    if (folderId <= 0) {
      return '无效的文件夹';
    }

    state = state.copyWith(busy: true);
    final response = await _repository.deleteFolder(folderId);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '删除文件夹失败' : response.msg;
    }

    // 如果删除的是当前文件夹，回到 overview 视图
    final removed = state.folders
        .where((item) => item.id == folderId)
        .firstOrNull;
    final isCurrent =
        removed != null &&
        removed.id == state.currentFolderId &&
        state.isFolderView;
    if (isCurrent) {
      state = state.copyWith(
        viewMode: CloudDriveViewMode.overview,
        currentFolderName: '',
        currentFolderId: 0,
        selectedFileIds: const <int>[],
      );
    }
    await _refreshFoldersOnly();
    return null;
  }

  /// 修改文件标题（调用接口）。
  Future<String?> renameCourseware(int id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return '请输入新的标题';
    }
    if (id <= 0) {
      return '无效的资料';
    }

    state = state.copyWith(busy: true);
    final response = await _repository.updateCoursewareTitle(id, trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '重命名失败' : response.msg;
    }
    await _refreshFilesOnly();
    return null;
  }

  Future<String?> addCourseware({
    required String title,
    required CloudFileType type,
    required String audioUrl,
    required String imageInput,
  }) async {
    if (state.selectedCategoryId == 0) {
      return '请先创建分类';
    }

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return '请输入资料标题';
    }

    final cleanAudio = audioUrl.trim();
    final images = _splitImages(imageInput);

    if (type == CloudFileType.audio && cleanAudio.isEmpty) {
      return '请先选择音频文件并上传';
    }
    if (type == CloudFileType.score && images.isEmpty) {
      return '请先选择图片并上传';
    }
    if (type == CloudFileType.courseware && cleanAudio.isEmpty) {
      return '请先选择课件文件并上传';
    }

    // 主文件路径：图片类型取第一张，否则取 audio/课件文件 URL。
    final filePath = type == CloudFileType.score
        ? (images.isNotEmpty ? images.first : '')
        : cleanAudio;

    state = state.copyWith(busy: true);
    final response = await _repository.addCourseware(
      categoryId: state.selectedCategoryId,
      folderId: state.currentFolderId,
      filePath: filePath,
      title: cleanTitle,
      param1: '${type.value}',
      param2: cleanAudio,
      param3: jsonEncode(images),
    );
    state = state.copyWith(busy: false);

    if (!response.isSuccess) {
      return response.msg.isEmpty ? '上传资料失败' : response.msg;
    }

    await _refreshFilesOnly();
    return null;
  }

  Future<String?> deleteCourseware(int id) async {
    if (id <= 0) {
      return null;
    }

    state = state.copyWith(busy: true);
    final response = await _repository.deleteCourseware(id);
    state = state.copyWith(busy: false);

    if (!response.isSuccess) {
      return response.msg.isEmpty ? '删除资料失败' : response.msg;
    }

    await _refreshFilesOnly();
    return null;
  }

  Future<List<CloudShareClassItem>> fetchShareClasses() async {
    final response = await _repository.getClassList();
    if (!response.isSuccess || response.data is! List) {
      return const <CloudShareClassItem>[];
    }

    final result = <CloudShareClassItem>[];
    for (final item in response.data as List) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(item['id']);
      final name = item['name']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty) {
        continue;
      }
      result.add(CloudShareClassItem(id: id, name: name));
    }
    return result;
  }

  Future<String?> shareCourseware({
    required CloudFileItem file,
    required List<String> classIds,
  }) async {
    if (classIds.isEmpty) {
      return '请先选择要分享的班级';
    }

    if (file.id <= 0 || state.selectedCategoryId <= 0) {
      return null;
    }

    state = state.copyWith(busy: true);
    for (final classId in classIds) {
      final response = await _repository.sendShareMessage(
        classId: classId,
        content: jsonEncode(file.toSharePayload()),
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return response.msg.isEmpty ? '分享失败' : response.msg;
      }
    }
    state = state.copyWith(busy: false);
    return null;
  }

  void togglePlaying(int fileId) {
    final updated = state.files.map((item) {
      if (item.id == fileId) {
        return item.copyWith(isPlaying: !item.isPlaying);
      }
      return item.copyWith(isPlaying: false);
    }).toList();
    state = state.copyWith(files: updated);
  }

  // ── Preview page lifecycle ─────────────────────────────────────────────

  /// 打开预览页。对谱例 (`CloudFileType.score`) 且有音频地址的文件，会自动
  /// 创建 `media_kit` 播放器并加载（不自动播放）。
  void openPreview(CloudFileItem item) {
    state = state.copyWith(
      previewingFile: item,
      previewActiveImageIndex: 0,
      previewIsPlaying: false,
      previewPosition: Duration.zero,
      previewDuration: Duration.zero,
      previewSpeed: 1.0,
      previewFavorite: false,
    );

    // 仅当真正存在音频地址时才创建播放器：
    // - score 类型 + 有 audioUrl → 真正的谱例预览（音频 + 乐谱）
    // - audio 类型 + 有 audioUrl → 旧式音频/兜底
    // - score 类型但 audioUrl 为空 → 业务上是「图片」，走图片预览，无需播放器
    if (item.audioUrl.trim().isNotEmpty &&
        (item.type == CloudFileType.score ||
            item.type == CloudFileType.audio)) {
      _initPreviewPlayer(item.audioUrl);
    }
  }

  /// 关闭预览页：停止播放并 dispose 播放器。
  void closePreview() {
    _disposePreviewPlayer();
    if (!mounted) return;
    state = state.copyWith(
      previewingFile: null,
      previewIsPlaying: false,
      previewPosition: Duration.zero,
      previewDuration: Duration.zero,
      previewSpeed: 1.0,
    );
  }

  void _initPreviewPlayer(String url) {
    _disposePreviewPlayer();
    final resolved = resolveMediaUrl(url);
    if (resolved.isEmpty) return;

    // media_kit 初始化在 iOS 上偶发抛 native 异常（音频会话占用、
    // libmpv 加载失败、URL 解析异常等），任意一处都不应该让整个
    // 课件预览页 / APP 跟着崩。统一 try/catch 兜底：失败时回到
    // 「无播放器」的安静状态，UI 上「播放/进度条」只是无响应。
    Player? player;
    try {
      player = Player();
    } catch (_) {
      _previewPlayer = null;
      return;
    }

    _previewPlayer = player;
    _previewPlayingSub = player.stream.playing.listen((playing) {
      if (!mounted) return;
      state = state.copyWith(previewIsPlaying: playing);
    });
    _previewPositionSub = player.stream.position.listen((position) {
      if (!mounted) return;
      state = state.copyWith(previewPosition: position);
    });
    _previewDurationSub = player.stream.duration.listen((duration) {
      if (!mounted) return;
      state = state.copyWith(previewDuration: duration);
    });
    _previewCompletedSub = player.stream.completed.listen((completed) async {
      if (completed && mounted) {
        // 播完后回到开头，停在暂停态。
        await player!.seek(Duration.zero);
        await player.pause();
      }
    });
    unawaited(
      player
          .open(Media(resolved), play: false)
          // 同样拦住 open 阶段的异常，避免 unawaited 的 future 报错把
          // zone level 的 onError 触发 fatal。
          .catchError((Object _) {}),
    );
  }

  Future<void> previewTogglePlay() async {
    final p = _previewPlayer;
    if (p == null) return;
    if (state.previewIsPlaying) {
      await p.pause();
    } else {
      await p.play();
    }
  }

  Future<void> previewSeekRatio(double ratio) async {
    final p = _previewPlayer;
    if (p == null) return;
    final ms = (state.previewDuration.inMilliseconds * ratio.clamp(0.0, 1.0))
        .round();
    await p.seek(Duration(milliseconds: ms));
  }

  Future<void> previewSkipSeconds(int delta) async {
    final p = _previewPlayer;
    if (p == null) return;
    final maxMs = state.previewDuration.inMilliseconds;
    final currentMs = state.previewPosition.inMilliseconds;
    final targetMs = maxMs > 0
        ? (currentMs + delta * 1000).clamp(0, maxMs).toInt()
        : math.max(0, currentMs + delta * 1000);
    await p.seek(Duration(milliseconds: targetMs));
  }

  Future<void> previewSetSpeed(double speed) async {
    final p = _previewPlayer;
    if (p != null) {
      await p.setRate(speed);
    }
    if (!mounted) return;
    state = state.copyWith(previewSpeed: speed);
  }

  void previewSetImageIndex(int index) {
    final item = state.previewingFile;
    if (item == null) return;
    final clamped = index
        .clamp(0, math.max(0, item.imageUrls.length - 1))
        .toInt();
    state = state.copyWith(previewActiveImageIndex: clamped);
  }

  void previewToggleFavorite() {
    state = state.copyWith(previewFavorite: !state.previewFavorite);
  }

  List<String> _splitImages(String input) {
    return input
        .split(RegExp(r'[\n,，、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _resolveSelectedCategoryId(List<CloudCategoryItem> categories) {
    if (categories.isEmpty) {
      return 0;
    }
    final current = state.selectedCategoryId;
    final exists = categories.any((e) => e.id == current);
    return exists ? current : categories.first.id;
  }

  Future<void> _refreshFoldersOnly() async {
    final categoryId = state.selectedCategoryId;
    if (categoryId <= 0) {
      return;
    }
    final folders = await _fetchFolders(categoryId);
    state = state.copyWith(
      folders: _sortFolders(folders, state.sortType, state.sortAscending),
    );
  }

  Future<void> _refreshFilesOnly() async {
    final responses = await Future.wait([
      _repository.getCategoryList(),
      _repository.getCoursewareUsage(),
    ]);
    final categoryResponse = responses[0];
    final usageResponse = responses[1];
    final usage = _parseUsageFromResponse(usageResponse);

    final categories = _parseCategories(categoryResponse.data);
    if (categories.isEmpty) {
      state = state.copyWith(
        categories: const <CloudCategoryItem>[],
        selectedCategoryId: 0,
        files: const <CloudFileItem>[],
        folders: const <CloudFolderItem>[],
        selectedFileIds: const <int>[],
        // 分类全没了，预览中的文件一定也消失，强制清空 previewingFile，
        // 上层 UI 会跟着退出预览页，避免拿着孤儿数据继续渲染。
        previewingFile: null,
        errorMessage: '',
        storageUsedBytes: usage.$1,
        storageTotalBytes: usage.$2,
      );
      return;
    }
    final selectedId = _resolveSelectedCategoryId(categories);
    final folders = await _fetchFolders(selectedId);
    final files = await _fetchFiles(
      categoryId: selectedId,
      folderId: state.currentFolderId,
    );

    // 同步 previewingFile：renameCourseware/addCourseware 等接口走完都会
    // 调本方法刷新 state.files 拿到新数据，但 state.previewingFile 还是
    // 当时 openPreview 塞进去那份旧的 CloudFileItem。预览页顶部
    // _PreviewHeaderBar 直接读 previewingFile.title 渲染，不同步的话表现
    // 就是「重命名接口已 200，header 还是旧名字」。
    //   - 在新 files 里能按 id 找到 → 用刷新后的版本覆盖（标题/imageUrls
    //     /大小等所有字段都顺带刷新，不会出现部分字段过期的脏数据）。
    //   - 找不到（被删 / 被移到其他分类 / 进了别的文件夹）→ 置 null，
    //     上层 UI 会自动关闭预览页。
    final preview = state.previewingFile;
    CloudFileItem? nextPreview = preview;
    if (preview != null) {
      nextPreview = null;
      for (final f in files) {
        if (f.id == preview.id) {
          nextPreview = f;
          break;
        }
      }
    }

    state = state.copyWith(
      categories: categories,
      selectedCategoryId: selectedId,
      files: _sortFiles(files, state.sortType, state.sortAscending),
      folders: _sortFolders(folders, state.sortType, state.sortAscending),
      selectedFileIds: const <int>[],
      previewingFile: nextPreview,
      errorMessage: '',
      storageUsedBytes: usage.$1,
      storageTotalBytes: usage.$2,
    );
  }

  /// 解析 `/app/courseware/v2/usage` 的 `data`：返回 (已用字节, 总配额字节)。
  (int, int) _parseUsageFromResponse(ApiResponse response) {
    if (!response.isSuccess) {
      return (state.storageUsedBytes, state.storageTotalBytes);
    }
    return _parseUsagePayload(response.data);
  }

  (int, int) _parseUsagePayload(dynamic data) {
    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = data.map((k, v) => MapEntry(k.toString(), v));
    }
    if (map == null || map.isEmpty) {
      return (0, 0);
    }

    int readPositive(String key) {
      final v = map![key];
      if (v == null) return 0;
      final i = _toInt(v);
      return i > 0 ? i : 0;
    }

    int total = 0;
    for (final key in <String>[
      'coursewareMaxCapacity',
      'totalBytes',
      'total',
      'limit',
      'quota',
      'capacity',
      'maxSize',
      'max',
    ]) {
      total = readPositive(key);
      if (total > 0) break;
    }

    if (total <= 0) {
      final totalGb = _toInt(map['totalGb'] ?? map['totalGB']);
      if (totalGb > 0) {
        total = totalGb * 1024 * 1024 * 1024;
      }
    }

    if (total <= 0) {
      return (0, 0);
    }

    int used = 0;
    for (final key in <String>[
      'coursewareUsageCapacity',
      'usedBytes',
      'used',
      'usage',
      'useSize',
    ]) {
      used = readPositive(key);
      if (used > 0) break;
    }

    if (used <= 0) {
      final usedGb = _toInt(map['usedGb'] ?? map['usedGB']);
      if (usedGb > 0) {
        used = usedGb * 1024 * 1024 * 1024;
      }
    }

    if (used <= 0) {
      int avail = 0;
      for (final key in <String>[
        'availableBytes',
        'available',
        'remain',
        'free',
        'surplus',
      ]) {
        avail = readPositive(key);
        if (avail > 0) break;
      }
      if (avail > 0) {
        used = math.max(0, total - avail);
      }
    }

    if (used <= 0) {
      final p = _toInt(
        map['usedPercent'] ?? map['usePercent'] ?? map['percent'],
      );
      if (p > 0 && p <= 100) {
        used = (total * p / 100).round();
      }
    }

    used = used.clamp(0, total);
    return (used, total);
  }

  Future<List<CloudFolderItem>> _fetchFolders(int categoryId) async {
    if (categoryId <= 0) {
      return const <CloudFolderItem>[];
    }
    final response = await _repository.getFolderList(categoryId: categoryId);
    if (!response.isSuccess) {
      return const <CloudFolderItem>[];
    }
    // 后端文件夹列表可能直接是 List，也可能是 {records: [...]} 分页对象
    final data = response.data;
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['records'] is List
              ? data['records'] as List
              : const <dynamic>[]);
    final result = <CloudFolderItem>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(item['id']);
      final name = item['name']?.toString() ?? item['title']?.toString() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      result.add(
        CloudFolderItem(
          id: id,
          title: name,
          sizeLabel: _resolveSizeLabel(item),
          dateLabel: _resolveDateLabel(item),
        ),
      );
    }
    return result;
  }

  Future<List<CloudFileItem>> _fetchFiles({
    required int categoryId,
    int folderId = 0,
  }) async {
    if (categoryId <= 0) {
      return const <CloudFileItem>[];
    }

    final response = await _repository.getCoursewareList(
      categoryId: categoryId,
      folderId: folderId,
    );
    if (!response.isSuccess) {
      return const <CloudFileItem>[];
    }
    final data = response.data;
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['records'] is List
              ? data['records'] as List
              : const <dynamic>[]);

    final result = <CloudFileItem>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      result.add(
        CloudFileItem(
          id: _toInt(item['id']),
          title: item['title']?.toString() ?? '',
          type: CloudFileType.fromValue(item['param1']),
          audioUrl: resolveMediaUrl(item['param2']?.toString() ?? ''),
          imageUrls: _parseImageUrls(item['param3']),
          sizeLabel: _resolveSizeLabel(item),
          dateLabel: _resolveDateLabel(item),
        ),
      );
    }

    return result;
  }

  List<CloudCategoryItem> _parseCategories(dynamic data) {
    if (data is! List) {
      return const <CloudCategoryItem>[];
    }

    final result = <CloudCategoryItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(item['id']);
      final name = item['name']?.toString() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      result.add(
        CloudCategoryItem(id: id, name: name, count: _toInt(item['count'])),
      );
    }

    return result;
  }

  List<String> _parseImageUrls(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    final text = value?.toString() ?? '';
    if (text.isEmpty || text == 'null') {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty && e != 'null')
            .toList();
      }
    } catch (_) {
      // Ignore invalid JSON and fallback to a single URL.
    }

    return <String>[text];
  }

  List<CloudFileItem> _sortFiles(
    List<CloudFileItem> files,
    CloudDriveSortType sortType,
    bool ascending,
  ) {
    // 默认状态下不做客户端再排序，直接保留接口返回的顺序。
    if (sortType == CloudDriveSortType.none) {
      return <CloudFileItem>[...files];
    }
    final sorted = <CloudFileItem>[...files];
    sorted.sort((a, b) {
      final result = switch (sortType) {
        CloudDriveSortType.none => 0,
        CloudDriveSortType.name => a.title.compareTo(b.title),
        CloudDriveSortType.time => _parseDateValue(
          a.dateLabel,
        ).compareTo(_parseDateValue(b.dateLabel)),
        CloudDriveSortType.size => _parseSizeNumber(
          a.sizeLabel,
        ).compareTo(_parseSizeNumber(b.sizeLabel)),
        CloudDriveSortType.type => a.type.value.compareTo(b.type.value),
      };
      return ascending ? result : -result;
    });
    return sorted;
  }

  List<CloudFolderItem> _sortFolders(
    List<CloudFolderItem> folders,
    CloudDriveSortType sortType,
    bool ascending,
  ) {
    if (sortType == CloudDriveSortType.none) {
      return <CloudFolderItem>[...folders];
    }
    final sorted = <CloudFolderItem>[...folders];
    sorted.sort((a, b) {
      if (a.isCreateShortcut != b.isCreateShortcut) {
        return a.isCreateShortcut ? -1 : 1;
      }
      final result = _compareFolderBySortType(a, b, sortType);
      return ascending ? result : -result;
    });
    return sorted;
  }

  int _compareFolderBySortType(
    CloudFolderItem a,
    CloudFolderItem b,
    CloudDriveSortType sortType,
  ) {
    final primary = switch (sortType) {
      CloudDriveSortType.none => 0,
      CloudDriveSortType.name => a.title.compareTo(b.title),
      CloudDriveSortType.time => _parseDateValue(
        a.dateLabel,
      ).compareTo(_parseDateValue(b.dateLabel)),
      CloudDriveSortType.size => _parseSizeNumber(
        a.sizeLabel,
      ).compareTo(_parseSizeNumber(b.sizeLabel)),
      CloudDriveSortType.type => a.title.compareTo(b.title),
    };
    if (primary != 0) {
      return primary;
    }
    final titleCompare = a.title.compareTo(b.title);
    if (titleCompare != 0) {
      return titleCompare;
    }
    return a.id.compareTo(b.id);
  }

  String _resolveSizeLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['sizeLabel'],
      item['size'],
      item['fileSize'],
      item['totalFileSize'],
      item['param4'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') {
        // totalFileSize 等字段可能是纯数字（字节数）
        final asNumber = double.tryParse(value);
        if (asNumber != null && !value.contains(RegExp(r'[a-zA-Z]'))) {
          return _formatBytes(asNumber);
        }
        return value;
      }
    }
    return '10MB';
  }

  String _resolveDateLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['createTime'],
      item['createDate'],
      item['updateTime'],
      item['param5'],
    ];
    for (final candidate in candidates) {
      final raw = candidate?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') {
        continue;
      }
      // 兼容 "2026-04-30 09:00:47" 这种格式
      final normalized = raw.contains(' ') && !raw.contains('T')
          ? raw.replaceFirst(' ', 'T')
          : raw;
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) {
        final month = parsed.month.toString().padLeft(2, '0');
        final day = parsed.day.toString().padLeft(2, '0');
        return '$month.$day.${parsed.year}';
      }
      return raw;
    }
    return '04.07.2026';
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) {
      return '0MB';
    }
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (bytes >= gb) {
      final value = bytes / gb;
      return '${value.toStringAsFixed(value < 10 ? 1 : 0)}GB';
    }
    if (bytes >= mb) {
      final value = bytes / mb;
      return '${value.toStringAsFixed(value < 10 ? 1 : 0)}MB';
    }
    final value = bytes / kb;
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)}KB';
  }

  double _parseSizeNumber(String value) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*([kmgt]?b)?',
      caseSensitive: false,
    ).firstMatch(value);
    final number = double.tryParse(match?.group(1) ?? '') ?? 0;
    final unit = (match?.group(2) ?? '').toLowerCase();
    return switch (unit) {
      'tb' => number * 1024 * 1024 * 1024 * 1024,
      'gb' => number * 1024 * 1024 * 1024,
      'mb' => number * 1024 * 1024,
      'kb' => number * 1024,
      _ => number,
    };
  }

  int _parseDateValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final normalized = trimmed.contains(' ') && !trimmed.contains('T')
        ? trimmed.replaceFirst(' ', 'T')
        : trimmed;
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) {
      return parsed.millisecondsSinceEpoch;
    }
    final dotMatch = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ).firstMatch(trimmed);
    if (dotMatch != null) {
      final month = int.tryParse(dotMatch.group(1) ?? '') ?? 1;
      final day = int.tryParse(dotMatch.group(2) ?? '') ?? 1;
      final year = int.tryParse(dotMatch.group(3) ?? '') ?? 1970;
      return DateTime(year, month, day).millisecondsSinceEpoch;
    }
    final yearFirstMatch = RegExp(
      r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})',
    ).firstMatch(trimmed);
    if (yearFirstMatch != null) {
      final year = int.tryParse(yearFirstMatch.group(1) ?? '') ?? 1970;
      final month = int.tryParse(yearFirstMatch.group(2) ?? '') ?? 1;
      final day = int.tryParse(yearFirstMatch.group(3) ?? '') ?? 1;
      return DateTime(year, month, day).millisecondsSinceEpoch;
    }
    return trimmed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _toIdString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is int) {
      return value.toString();
    }
    if (value is num) {
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
}

extension _FirstWhereOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
