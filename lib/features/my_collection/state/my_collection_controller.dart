import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/my_collection_repository.dart';
import 'my_collection_state.dart';

final myCollectionControllerProvider =
    StateNotifierProvider.autoDispose<
      MyCollectionController,
      MyCollectionState
    >((ref) {
      final repository = ref.watch(myCollectionRepositoryProvider);
      return MyCollectionController(repository: repository);
    });

class MyCollectionController extends StateNotifier<MyCollectionState> {
  MyCollectionController({required MyCollectionRepository repository})
    : _repository = repository,
      super(
        const MyCollectionState(
          loading: true,
          tabs: kCollectionDefaultTabs,
        ),
      ) {
    unawaited(refresh());
  }

  final MyCollectionRepository _repository;

  Future<void> refresh() async {
    try {
      state = state.copyWith(loading: true, clearError: true);
      final categoryResponse = await _repository.getCategories();
      final tabs = _parseTabs(categoryResponse.data);
      final activeType = _resolveActiveType(tabs, state.activeType);
      final itemResponse = await _repository.getItems(type: activeType);
      state = state.copyWith(
        loading: false,
        tabs: tabs,
        activeType: activeType,
        items: _parseItems(itemResponse.data, activeType),
        errorMessage: itemResponse.isSuccess
            ? null
            : _fallbackMessage(itemResponse.msg),
        shareClasses: const <CollectionShareClass>[],
        clearShareTarget: true,
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载收藏失败，请稍后重试');
    }
  }

  Future<void> selectType(int type) async {
    if (type == state.activeType) {
      return;
    }
    try {
      state = state.copyWith(
        activeType: type,
        loading: true,
        clearError: true,
        items: const <CollectionEntry>[],
        shareClasses: const <CollectionShareClass>[],
        clearShareTarget: true,
      );
      final response = await _repository.getItems(type: type);
      state = state.copyWith(
        loading: false,
        items: _parseItems(response.data, type),
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg),
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载收藏失败，请稍后重试');
    }
  }

  Future<String?> removeFavorite(CollectionEntry item) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.removeFavorite(
      targetId: item.targetId,
      type: item.type,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg);
    }
    state = state.copyWith(
      items: state.items.where((entry) => entry.id != item.id).toList(),
    );
    return null;
  }

  Future<String?> openShare(CollectionEntry item) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.getClassList();
    state = state.copyWith(busy: false);
    if (!response.isSuccess || response.data is! List) {
      return _fallbackMessage(response.msg, fallback: '加载班级列表失败');
    }
    final classes = <CollectionShareClass>[];
    for (final raw in response.data as List) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      classes.add(CollectionShareClass(id: id, name: name));
    }
    state = state.copyWith(shareTarget: item, shareClasses: classes);
    return null;
  }

  void toggleShareClass(int id) {
    state = state.copyWith(
      shareClasses: state.shareClasses.map((item) {
        if (item.id != id) {
          return item;
        }
        return item.copyWith(selected: !item.selected);
      }).toList(),
    );
  }

  void closeShare() {
    state = state.copyWith(
      shareClasses: const <CollectionShareClass>[],
      clearShareTarget: true,
    );
  }

  Future<String?> sendShare() async {
    final target = state.shareTarget;
    if (target == null) {
      return '请先选择要分享的收藏';
    }
    final selected = state.shareClasses.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      return '请先选择要分享的班级';
    }

    state = state.copyWith(busy: true, clearError: true);
    for (final item in selected) {
      final response = await _repository.shareToClass(
        classId: item.id,
        type: target.type,
        payload: target.rawPayload,
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return _fallbackMessage(response.msg, fallback: '分享失败');
      }
    }
    state = state.copyWith(
      busy: false,
      shareClasses: const <CollectionShareClass>[],
      clearShareTarget: true,
    );
    return null;
  }

  /// 服务端返回的分类列表只是用来确认每个 Tab 是否启用，
  /// 顺序统一以设计稿（声乐 → 器乐 → 听写 → 视唱 → 乐理 → 视频）为准。
  List<CollectionTabItem> _parseTabs(dynamic data) {
    final allowed = <int>{};
    if (data is List) {
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final label = item['name']?.toString().trim() ?? '';
        final type = kCollectionTypeByLabel[label];
        if (type != null) {
          allowed.add(type);
        }
      }
    }
    if (allowed.isEmpty) {
      return kCollectionDefaultTabs;
    }
    return kCollectionDefaultTabs
        .where((tab) => allowed.contains(tab.type))
        .toList(growable: false);
  }

  List<CollectionEntry> _parseItems(dynamic data, int activeType) {
    if (data is! List) {
      return const <CollectionEntry>[];
    }
    final result = <CollectionEntry>[];
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final target = _resolveTarget(raw);
      if (target == null) {
        continue;
      }
      final title = (target['title'] ?? target['name'] ?? '').toString().trim();
      if (title.isEmpty) {
        continue;
      }
      result.add(
        CollectionEntry(
          id: _toInt(raw['id']),
          targetId: _toInt(raw['targetId']) > 0
              ? _toInt(raw['targetId'])
              : _toInt(target['id']),
          type: _toInt(raw['type']) == 0 ? activeType : _toInt(raw['type']),
          title: title,
          subtitle: _resolveSubtitle(target, activeType),
          coverUrl: _resolveCover(target),
          authorName: _resolveAuthor(target),
          avatarUrl: _resolveAvatar(target),
          metricText: _resolveMetric(target),
          durationText: _resolveDuration(target),
          rawPayload: Map<String, dynamic>.from(target),
        ),
      );
    }
    return result;
  }

  Map<String, dynamic>? _resolveTarget(Map<String, dynamic> raw) {
    final target = raw['target'];
    if (target is Map<String, dynamic>) {
      return target;
    }
    if (target is Map) {
      return Map<String, dynamic>.from(target);
    }
    // 部分接口直接把目标字段平铺在收藏记录上（兼容历史返回）。
    if (raw.containsKey('title') || raw.containsKey('name')) {
      return raw;
    }
    return null;
  }

  int _resolveActiveType(List<CollectionTabItem> tabs, int current) {
    if (tabs.any((item) => item.type == current)) {
      return current;
    }
    return tabs.isNotEmpty ? tabs.first.type : 4;
  }

  /// 副标题展示规则：
  /// - 声乐/器乐：调号信息（如 1=bA），字段一般为 keySignature/musicKey/param2
  /// - 听写/视唱/乐理：使用副标题或当前菜单名兜底
  /// - 视频：「主分类·副标题·作者」式描述（fallback 为 subtitle）
  String _resolveSubtitle(Map<String, dynamic> target, int type) {
    String pickFirstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final value = target[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    if (type == 4 || type == 5) {
      final key = pickFirstNonEmpty(<String>[
        'keySignature',
        'musicKey',
        'tonality',
        'param2',
        'subtitle',
      ]);
      return key.isEmpty ? '1=bA' : key;
    }

    if (type == 6) {
      final desc = pickFirstNonEmpty(<String>[
        'subtitle',
        'description',
        'param2',
        'category',
      ]);
      return desc;
    }

    final raw = pickFirstNonEmpty(<String>['subtitle', 'param2', 'param1']);
    if (raw.isNotEmpty) {
      return raw;
    }
    return switch (type) {
      1 => '标准音上下行二度',
      2 => '基础乐理知识梳理',
      3 => '听音单音专项练习',
      10 => '试题专项练习',
      _ => '',
    };
  }

  String _resolveCover(Map<String, dynamic> target) {
    for (final key in <String>[
      'coverImg',
      'cover',
      'imgUrl',
      'thumb',
      'param1',
    ]) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'string') {
        return value;
      }
    }
    return '';
  }

  String _resolveAuthor(Map<String, dynamic> target) {
    for (final key in <String>[
      'nickname',
      'realname',
      'teacherName',
      'author',
      'userName',
    ]) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '音乐之路';
  }

  String _resolveAvatar(Map<String, dynamic> target) {
    for (final key in <String>['avatarUrl', 'headImg', 'avatar', 'userAvatar']) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'string') {
        return value;
      }
    }
    return '';
  }

  String _resolveMetric(Map<String, dynamic> target) {
    for (final key in <String>['playCount', 'viewCount', 'playNum']) {
      final value = _toInt(target[key]);
      if (value > 0) {
        return '$value';
      }
    }
    return '0';
  }

  String _resolveDuration(Map<String, dynamic> target) {
    for (final key in <String>['duration', 'durationText', 'totalTime']) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '00:00';
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _fallbackMessage(String raw, {String fallback = '操作失败，请稍后重试'}) {
    return raw.trim().isEmpty ? fallback : raw.trim();
  }
}
