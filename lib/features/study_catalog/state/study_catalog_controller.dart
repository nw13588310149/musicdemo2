import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../data/study_catalog_repository.dart';
import 'study_catalog_state.dart';

final studyCatalogControllerProvider = StateNotifierProvider.autoDispose
    .family<StudyCatalogController, StudyCatalogState, StudyCatalogPageArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(studyCatalogRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      return StudyCatalogController(
        repository: repository,
        storage: storage,
        args: args,
      );
    });

class StudyCatalogController extends StateNotifier<StudyCatalogState> {
  StudyCatalogController({
    required StudyCatalogRepository repository,
    required AppStorage storage,
    required StudyCatalogPageArgs args,
  }) : _repository = repository,
       _storage = storage,
       _args = args,
       super(
         StudyCatalogState.initial(args.config).copyWith(
           schoolMode: args.schoolMode,
           showVipBadge: storage.hasCheckStatus,
         ),
       ) {
    unawaited(bootstrap());
  }

  final StudyCatalogRepository _repository;
  final AppStorage _storage;
  final StudyCatalogPageArgs _args;

  Future<void> bootstrap() async {
    state = state.copyWith(
      bootstrapping: true,
      loading: true,
      clearErrorMessage: true,
      schoolMode: _args.schoolMode,
      showVipBadge: _storage.hasCheckStatus,
    );

    try {
      final responses = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getMenuList(state.config.type),
        _repository.getMyInfo(),
      ]);
      if (!mounted) {
        return;
      }

      final menus = _parseMenus(responses[0].data);
      final userInfo = responses[1].data;
      final province = _parseProvince(userInfo);
      final vipExpireDate = _parseVipExpireDate(userInfo);
      final selectedMenuId = _resolveSelectedMenuId(menus);
      final selectedChildId = _resolveSelectedChildId(menus, selectedMenuId);

      state = state.copyWith(
        bootstrapping: false,
        loading: false,
        menus: menus,
        province: province,
        selectedMenuId: selectedMenuId,
        selectedChildId: selectedChildId,
        vipExpireDate: vipExpireDate,
      );

      await refreshLessons();
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        bootstrapping: false,
        loading: false,
        errorMessage: '${state.config.title}页面初始化失败，请稍后重试',
      );
    }
  }

  Future<void> selectMenu(String menuId) async {
    if (state.selectedMenuId == menuId) {
      return;
    }
    final menu = state.menus.firstWhere((item) => item.id == menuId);
    final nextChildId = state.config.allowSecondMenu && menu.children.isNotEmpty
        ? menu.children.first.id
        : null;
    state = state.copyWith(
      selectedMenuId: menuId,
      selectedChildId: nextChildId,
      clearSelectedChildId: nextChildId == null,
      clearErrorMessage: true,
    );
    await refreshLessons();
  }

  Future<void> selectChild(String? childId) async {
    if (state.selectedChildId == childId) {
      return;
    }
    state = state.copyWith(selectedChildId: childId, clearErrorMessage: true);
    await refreshLessons();
  }

  Future<void> refreshLessons() async {
    final selectedMenu = state.selectedMenuId;
    if (selectedMenu == null || selectedMenu.isEmpty) {
      state = state.copyWith(
        bootstrapping: false,
        loading: false,
        lessonGroups: const <StudyCatalogLessonGroup>[],
        errorMessage: '未获取到${state.config.title}分类',
      );
      return;
    }

    state = state.copyWith(loading: true, clearErrorMessage: true);
    try {
      final response = await _repository.getTextbookList(
        type: state.config.type,
        firstMenu: selectedMenu,
        secondMenu: state.config.allowSecondMenu
            ? (state.selectedChildId ?? '')
            : '',
        schoolMode: state.schoolMode,
        size: state.config.key == StudyCatalogConfig.voice.key ? 1000 : 1000,
      );
      if (!mounted) {
        return;
      }

      if (!response.isSuccess) {
        state = state.copyWith(
          bootstrapping: false,
          loading: false,
          lessonGroups: const <StudyCatalogLessonGroup>[],
          errorMessage: response.msg.isEmpty
              ? '${state.config.title}教材加载失败'
              : response.msg,
        );
        return;
      }

      final groups = _parseLessonGroups(response.data);
      state = state.copyWith(
        bootstrapping: false,
        loading: false,
        lessonGroups: groups,
        errorMessage: groups.isEmpty ? '暂无课程' : '',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        bootstrapping: false,
        loading: false,
        lessonGroups: const <StudyCatalogLessonGroup>[],
        errorMessage: '${state.config.title}教材加载失败',
      );
    }
  }

  List<StudyCatalogMenu> _parseMenus(dynamic data) {
    if (data is! List) {
      return const <StudyCatalogMenu>[];
    }

    final result = <StudyCatalogMenu>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(item['id']);
      final name = _asString(item['name']);
      if (id.isEmpty || name.isEmpty) {
        continue;
      }

      final children = <StudyCatalogMenuChild>[];
      final rawChildren = item['children'];
      if (rawChildren is List) {
        for (final child in rawChildren) {
          if (child is! Map<String, dynamic>) {
            continue;
          }
          final childId = _toIdString(child['id']);
          final childName = _asString(child['name']);
          if (childId.isEmpty || childName.isEmpty) {
            continue;
          }
          children.add(StudyCatalogMenuChild(id: childId, name: childName));
        }
      }

      result.add(StudyCatalogMenu(id: id, name: name, children: children));
    }

    if (state.config.key == StudyCatalogConfig.answerQuestions.key) {
      const order = <String>['听写', '视唱', '乐理'];
      result.sort((a, b) {
        final left = order.indexOf(a.name.trim());
        final right = order.indexOf(b.name.trim());
        final safeLeft = left == -1 ? 999 : left;
        final safeRight = right == -1 ? 999 : right;
        return safeLeft.compareTo(safeRight);
      });
    }

    return result;
  }

  List<StudyCatalogLessonGroup> _parseLessonGroups(dynamic data) {
    if (data is! List) {
      return const <StudyCatalogLessonGroup>[];
    }

    final lessons = <StudyCatalogLesson>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(item['id']);
      final title = _asString(item['title']);
      if (id.isEmpty || title.isEmpty) {
        continue;
      }
      lessons.add(
        StudyCatalogLesson(
          id: id,
          title: title,
          subtitle: _readSubtitle(item),
          groupTitle: _readGroupTitle(item),
          vip: _toInt(item['vip']) == 1,
        ),
      );
    }

    if (lessons.isEmpty) {
      return const <StudyCatalogLessonGroup>[];
    }

    if (state.config.groupField == StudyCatalogGroupField.none ||
        lessons.every((lesson) => lesson.groupTitle.isEmpty)) {
      return <StudyCatalogLessonGroup>[
        StudyCatalogLessonGroup(title: '', lessons: lessons),
      ];
    }

    final grouped = <String, List<StudyCatalogLesson>>{};
    final order = <String>[];
    for (final lesson in lessons) {
      final key = lesson.groupTitle.isEmpty ? '未分组' : lesson.groupTitle;
      if (!grouped.containsKey(key)) {
        grouped[key] = <StudyCatalogLesson>[];
        order.add(key);
      }
      grouped[key]!.add(lesson);
    }

    return order
        .map(
          (key) => StudyCatalogLessonGroup(title: key, lessons: grouped[key]!),
        )
        .toList(growable: false);
  }

  String _readGroupTitle(Map<String, dynamic> item) {
    switch (state.config.groupField) {
      case StudyCatalogGroupField.none:
        return '';
      case StudyCatalogGroupField.shortText1:
        return _asString(item['shortText1']);
      case StudyCatalogGroupField.shortText2:
        return _asString(item['shortText2']);
    }
  }

  String _readSubtitle(Map<String, dynamic> item) {
    switch (state.config.subtitleField) {
      case StudyCatalogSubtitleField.none:
        return '';
      case StudyCatalogSubtitleField.shortText1:
        return _asString(item['shortText1']);
      case StudyCatalogSubtitleField.shortText2:
        return _asString(item['shortText2']);
    }
  }

  DateTime? _parseVipExpireDate(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      return null;
    }
    final rawDate = _asString(user['vipExpireDate']);
    if (rawDate.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawDate);
  }

  String _parseProvince(dynamic data) {
    if (data is Map<String, dynamic>) {
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        final province = _asString(user['province']);
        if (province.isNotEmpty) {
          return province;
        }
      }
    }
    return '甘肃';
  }

  String? _resolveSelectedMenuId(List<StudyCatalogMenu> menus) {
    if (menus.isEmpty) {
      return null;
    }
    final requestedId = _args.initialFirstMenuId;
    if (requestedId != null && requestedId.isNotEmpty) {
      for (final menu in menus) {
        if (menu.id == requestedId) {
          return requestedId;
        }
      }
    }
    for (final menu in menus) {
      if (menu.id == state.config.defaultFirstMenuId) {
        return menu.id;
      }
    }
    return menus.first.id;
  }

  String? _resolveSelectedChildId(
    List<StudyCatalogMenu> menus,
    String? selectedMenuId,
  ) {
    if (!state.config.allowSecondMenu || selectedMenuId == null) {
      return null;
    }
    StudyCatalogMenu? selected;
    for (final menu in menus) {
      if (menu.id == selectedMenuId) {
        selected = menu;
        break;
      }
    }
    if (selected == null || selected.children.isEmpty) {
      return null;
    }
    final requestedId = _args.initialSecondMenuId;
    if (requestedId != null && requestedId.isNotEmpty) {
      for (final child in selected.children) {
        if (child.id == requestedId) {
          return requestedId;
        }
      }
    }
    return selected.children.first.id;
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') {
      return '';
    }
    return text;
  }

  String _toIdString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is int) {
      return value.toString();
    }
    if (value is num) {
      return value.toInt().toString();
    }
    final text = value.toString().trim();
    if (text.endsWith('.0')) {
      return text.substring(0, text.length - 2);
    }
    return text;
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
}
