import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/upload_result.dart';
import '../data/my_notes_repository.dart';
import 'my_notes_state.dart';

final myNotesControllerProvider =
    StateNotifierProvider.autoDispose<MyNotesController, MyNotesState>((ref) {
      final repository = ref.watch(myNotesRepositoryProvider);
      return MyNotesController(repository: repository);
    });

class MyNotesController extends StateNotifier<MyNotesState> {
  MyNotesController({required MyNotesRepository repository})
    : _repository = repository,
      super(const MyNotesState()) {
    unawaited(refresh());
  }

  final MyNotesRepository _repository;

  Future<void> refresh() async {
    try {
      state = state.copyWith(loading: true, clearError: true);

      // `/app/user/noteCategoryList` 在 v2 数据里已经直接给每个分类带上了
      // `count` 字段（左侧导航的「（数字）」就是用它），不再需要额外请求一次
      // `/app/user/noteCount`，那是旧接口、且返回值在这里也不会被使用。
      final categoriesResponse = await _repository.getCategories();
      final categories = _parseCategories(categoriesResponse.data);

      final selectedCategoryId = _resolveInitialCategoryId(
        categories,
        state.selectedCategoryId,
      );
      final notesResponse = selectedCategoryId > 0
          ? await _repository
                .getNotes(categoryId: selectedCategoryId)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () =>
                      const ApiResponse(code: -1, msg: '加载笔记超时', data: null),
                )
          : const ApiResponse(code: 0, msg: '', data: <dynamic>[]);
      final notes = _parseNotes(notesResponse.data);

      state = state.copyWith(
        loading: false,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        notes: notes,
        errorMessage: notesResponse.isSuccess
            ? null
            : _fallbackMessage(notesResponse.msg, '加载笔记失败'),
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载笔记失败，请稍后重试');
    }
  }

  Future<void> selectCategory(int categoryId) async {
    if (categoryId == state.selectedCategoryId &&
        state.view == MyNotesView.list) {
      return;
    }

    try {
      state = state.copyWith(
        selectedCategoryId: categoryId,
        loading: true,
        view: MyNotesView.list,
        clearError: true,
      );

      final response = categoryId > 0
          ? await _repository
                .getNotes(categoryId: categoryId)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () =>
                      const ApiResponse(code: -1, msg: '加载笔记超时', data: null),
                )
          : const ApiResponse(code: 0, msg: '', data: <dynamic>[]);
      state = state.copyWith(
        loading: false,
        notes: _parseNotes(response.data),
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, '加载笔记失败'),
        clearEditingNote: true,
        clearEditorBackgroundImageUrl: true,
        strokes: const <NoteStroke>[],
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载笔记失败，请稍后重试');
    }
  }

  void selectFilter(MyNotesFilter filter) {
    if (filter == state.activeFilter) {
      return;
    }
    state = state.copyWith(activeFilter: filter);
  }

  Future<String?> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入笔记分类名称';
    }

    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '新增分类失败');
    }
    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    if (id <= 0) {
      return '默认分类不能删除';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '删除分类失败');
    }
    await refresh();
    return null;
  }

  /// 重命名笔记分类。沿用 `noteCategorySave` 接口：传入既有 id + 新名称，
  /// 后端按 id 更新分类名。成功后会重新拉取分类列表，让左侧导航即时刷新。
  Future<String?> renameCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入笔记分类名称';
    }
    if (id <= 0) {
      return '默认分类不能重命名';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.updateCategory(id: id, name: trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '重命名分类失败');
    }
    await refresh();
    return null;
  }

  Future<String?> deleteNote(int id) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteNote(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '删除笔记失败');
    }
    // `selectCategory(currentId)` short-circuits when the requested category
    // matches the active one, so use `refresh()` instead to force a re-fetch
    // (also keeps the sidebar's category counts up to date).
    await refresh();
    return null;
  }

  /// Renames an existing note in-place via `/app/user/noteUpdate`.
  /// On success the current category's note list is refreshed so the new
  /// title appears in the grid immediately.
  Future<String?> renameNote(NoteEntry note, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) {
      return '请输入笔记名称';
    }
    if (trimmed == note.title) {
      return null;
    }
    if (note.id <= 0) {
      return '笔记 id 缺失，无法重命名';
    }

    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.updateNote(
      id: note.id,
      categoryId: note.categoryId > 0 ? note.categoryId : _writeCategoryId,
      paperType: note.paperType.value,
      title: trimmed,
      imageUrl: note.imageUrl,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '重命名失败');
    }
    // Same as deleteNote: `selectCategory(currentId)` would early-return,
    // so go through `refresh()` to actually re-pull the notes list and
    // make the new title appear in the grid.
    await refresh();
    return null;
  }

  /// 在弹出"新建笔记标题"输入框之前调用，用于校验当前是否存在可写入的
  /// 分类。返回 `null` 表示可以继续，否则返回需要展示给用户的错误提示。
  String? validateCanCreateNote() {
    if (_writeCategoryId <= 0) {
      return '请先新增笔记分类';
    }
    return null;
  }

  /// 进入"选择笔记样式"页面。如果调用方提前收集了用户输入的标题，
  /// 则通过 [title] 传入并写入草稿；为空时回落到默认占位文案。
  String? beginCreateNote({String? title}) {
    if (_writeCategoryId <= 0) {
      return '请先新增笔记分类';
    }
    final trimmed = title?.trim() ?? '';
    state = state.copyWith(
      view: MyNotesView.template,
      draftTitle: trimmed.isEmpty ? '笔记名称' : trimmed,
      paperType: NotePaperType.staff,
      strokes: const <NoteStroke>[],
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
      clearError: true,
    );
    return null;
  }

  void backToList() {
    state = state.copyWith(
      view: MyNotesView.list,
      strokes: const <NoteStroke>[],
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
      clearError: true,
    );
  }

  void chooseTemplate(NotePaperType type) {
    state = state.copyWith(
      view: MyNotesView.editor,
      paperType: type,
      draftTitle: state.draftTitle.isEmpty ? '笔记名称' : state.draftTitle,
      strokes: const <NoteStroke>[],
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
    );
  }

  void openExistingNote(NoteEntry note) {
    state = state.copyWith(
      view: MyNotesView.editor,
      draftTitle: note.title,
      paperType: note.paperType,
      editingNote: note,
      editorBackgroundImageUrl: note.imageUrl.isEmpty ? null : note.imageUrl,
      strokes: const <NoteStroke>[],
      clearError: true,
    );
  }

  void updateDraftTitle(String title) {
    state = state.copyWith(draftTitle: title);
  }

  void setSelectedColor(Color color) {
    state = state.copyWith(selectedColor: color);
  }

  void setStrokeWidth(double width) {
    state = state.copyWith(strokeWidth: width.clamp(2, 32));
  }

  void addStroke(List<Offset> points) {
    if (points.length < 2) {
      return;
    }
    state = state.copyWith(
      strokes: <NoteStroke>[
        ...state.strokes,
        NoteStroke(
          color: state.selectedColor,
          width: state.strokeWidth,
          points: points,
        ),
      ],
    );
  }

  void undoStroke() {
    if (state.strokes.isEmpty) {
      return;
    }
    state = state.copyWith(
      strokes: state.strokes.sublist(0, state.strokes.length - 1),
    );
  }

  void clearCanvas() {
    if (state.strokes.isEmpty) {
      return;
    }
    state = state.copyWith(strokes: const <NoteStroke>[]);
  }

  Future<String?> saveCurrentNote(Uint8List bytes) async {
    final categoryId = _writeCategoryId;
    if (categoryId <= 0) {
      return '请先新增笔记分类';
    }

    state = state.copyWith(busy: true, clearError: true);
    final uploadResponse = await _repository.uploadNoteImage(
      bytes: bytes,
      filename: 'note_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (!uploadResponse.isSuccess) {
      state = state.copyWith(busy: false);
      return _fallbackMessage(uploadResponse.msg, '上传笔记失败');
    }

    // 上传成功后保存的是相对 `path`（例如 `app/upload/.../xxx.png`），后端
    // 持久化 path，读取时再拼装为可访问地址。
    final imagePath = parseUploadResult(uploadResponse.data).savable;
    if (imagePath.isEmpty) {
      state = state.copyWith(busy: false);
      return '上传结果异常，请稍后重试';
    }

    final title = state.draftTitle.trim().isEmpty
        ? '笔记名称'
        : state.draftTitle.trim();
    final editingId = state.editingNote?.id ?? 0;
    final saveResponse = editingId > 0
        ? await _repository.updateNote(
            id: editingId,
            categoryId: categoryId,
            paperType: state.paperType.value,
            title: title,
            imageUrl: imagePath,
          )
        : await _repository.saveNote(
            categoryId: categoryId,
            paperType: state.paperType.value,
            title: title,
            imageUrl: imagePath,
          );
    if (!saveResponse.isSuccess) {
      state = state.copyWith(busy: false);
      return _fallbackMessage(saveResponse.msg, '保存笔记失败');
    }

    state = state.copyWith(busy: false);
    // 走完整 refresh 而不是 selectCategory：后者只会重拉当前分类的笔记
    // 列表，不会刷新左侧分类的 count；新建/更新笔记后必须把 sidebar 的
    //「（数字）」一同同步，否则会一直停留在旧值。
    await refresh();
    return null;
  }

  int get _writeCategoryId {
    if (state.selectedCategoryId > 0) {
      return state.selectedCategoryId;
    }
    final fallback = state.categories.where((item) => item.id > 0).firstOrNull;
    return fallback?.id ?? 0;
  }

  /// Parse the categories list returned by `/app/user/noteCategoryList`.
  ///
  /// 接口实际返回示例：
  /// ```json
  /// {
  ///   "id": "4259", "name": "D",
  ///   "createTime": "2026-05-01 00:14:37",
  ///   "userId": "...", "count": "0"
  /// }
  /// ```
  /// `count` 是后端为该分类下笔记数预先聚合好的字符串，左侧导航的
  /// 「（数字）」直接读取它，无需前端再算。
  List<NoteCategoryItem> _parseCategories(dynamic data) {
    final result = <NoteCategoryItem>[];
    if (data is! List) {
      return result;
    }
    for (final raw in data) {
      if (raw is! Map) {
        continue;
      }
      // 兼容 `Map<String, dynamic>` / `Map<dynamic, dynamic>`。
      final item = raw.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final id = _toInt(item['id']);
      final name = item['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      result.add(
        NoteCategoryItem(id: id, name: name, count: _toInt(item['count'])),
      );
    }
    return result;
  }

  int _resolveInitialCategoryId(
    List<NoteCategoryItem> categories,
    int currentId,
  ) {
    final positiveCategories = categories.where((item) => item.id > 0).toList();
    if (positiveCategories.isEmpty) {
      return 0;
    }
    if (positiveCategories.any((item) => item.id == currentId)) {
      return currentId;
    }
    return positiveCategories.first.id;
  }

  List<NoteEntry> _parseNotes(dynamic data) {
    if (data is! List) {
      return const <NoteEntry>[];
    }
    final result = <NoteEntry>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      result.add(
        NoteEntry(
          id: _toInt(item['id']),
          categoryId: _toInt(item['categoryId']),
          title: item['title']?.toString().trim().isNotEmpty == true
              ? item['title'].toString().trim()
              : '未命名笔记',
          imageUrl: item['param1']?.toString() ?? '',
          createdAt: _parseDate(item['createTime']),
          paperType: NotePaperType.fromValue(item['paperType']),
          isFavorite: _toBool(item['favorite']) || _toBool(item['isFavorite']),
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  DateTime _parseDate(dynamic value) {
    final raw = value?.toString() ?? '';
    return DateTime.tryParse(raw) ?? DateTime.now();
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

  String _fallbackMessage(String raw, String fallback) {
    return raw.trim().isEmpty ? fallback : raw.trim();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
