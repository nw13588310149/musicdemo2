import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../data/dictation_repository.dart';
import 'dictation_state.dart';

final dictationControllerProvider = StateNotifierProvider.autoDispose
    .family<DictationController, DictationState, DictationPageArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(dictationRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      return DictationController(
        repository: repository,
        storage: storage,
        args: args,
      );
    });

class DictationController extends StateNotifier<DictationState> {
  DictationController({
    required DictationRepository repository,
    required AppStorage storage,
    required DictationPageArgs args,
  }) : _repository = repository,
       _storage = storage,
       _args = args,
       super(
         DictationState.initial.copyWith(
           schoolMode: args.schoolMode,
           showVipBadge: storage.hasCheckStatus,
         ),
       ) {
    unawaited(bootstrap());
  }

  final DictationRepository _repository;
  final AppStorage _storage;
  final DictationPageArgs _args;

  Future<void> bootstrap() async {
    state = state.copyWith(
      bootstrapping: true,
      loading: true,
      clearErrorMessage: true,
      showVipBadge: _storage.hasCheckStatus,
      schoolMode: _args.schoolMode,
    );

    try {
      final responses = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getMenuList(),
        _repository.getMyInfo(),
      ]);
      if (!mounted) {
        return;
      }

      final menus = _parseMenus(responses[0].data);
      final vipExpireDate = _parseVipExpireDate(responses[1].data);
      final selectedMenuId = _resolveSelectedMenuId(menus);
      final selectedChildId = _resolveSelectedChildId(menus, selectedMenuId);

      state = state.copyWith(
        menus: menus,
        selectedMenuId: selectedMenuId,
        selectedChildId: selectedChildId,
        vipExpireDate: vipExpireDate,
        loading: false,
      );

      await refreshLessons();
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        bootstrapping: false,
        loading: false,
        errorMessage: '听写页面初始化失败，请稍后重试',
      );
    }
  }

  Future<void> selectMenu(String menuId) async {
    if (state.selectedMenuId == menuId) {
      return;
    }
    final menu = state.menus.firstWhere((item) => item.id == menuId);
    final nextChildId = menu.children.isEmpty ? null : menu.children.first.id;
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
        lessonGroups: const <DictationLessonGroup>[],
        errorMessage: '未获取到听写分类',
      );
      return;
    }

    state = state.copyWith(loading: true, clearErrorMessage: true);
    final response = await _repository.getTextbookList(
      firstMenu: selectedMenu,
      secondMenu: state.selectedChildId ?? '',
      schoolMode: state.schoolMode,
    );
    if (!mounted) {
      return;
    }

    if (!response.isSuccess) {
      state = state.copyWith(
        bootstrapping: false,
        loading: false,
        lessonGroups: const <DictationLessonGroup>[],
        errorMessage: response.msg.isEmpty ? '听写教材加载失败' : response.msg,
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
  }

  List<DictationMenu> _parseMenus(dynamic data) {
    if (data is! List) {
      return const <DictationMenu>[];
    }

    final result = <DictationMenu>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(item['id']);
      final name = _asString(item['name']);
      if (id.isEmpty || name.isEmpty) {
        continue;
      }

      final children = <DictationMenuChild>[];
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
          children.add(DictationMenuChild(id: childId, name: childName));
        }
      }

      result.add(DictationMenu(id: id, name: name, children: children));
    }
    return result;
  }

  List<DictationLessonGroup> _parseLessonGroups(dynamic data) {
    if (data is! List) {
      return const <DictationLessonGroup>[];
    }

    final lessons = <DictationLesson>[];
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
        DictationLesson(
          id: id,
          title: title,
          subtitle: _asString(item['shortText2']),
          groupTitle: _asString(item['shortText1']),
          vip: _toInt(item['vip']) == 1,
        ),
      );
    }

    if (lessons.isEmpty) {
      return const <DictationLessonGroup>[];
    }

    final hasGroup = lessons.any((lesson) => lesson.groupTitle.isNotEmpty);
    if (!hasGroup) {
      return <DictationLessonGroup>[
        DictationLessonGroup(title: '', lessons: lessons),
      ];
    }

    final grouped = <String, List<DictationLesson>>{};
    final order = <String>[];
    for (final lesson in lessons) {
      final key = lesson.groupTitle.isEmpty ? '未分组' : lesson.groupTitle;
      if (!grouped.containsKey(key)) {
        grouped[key] = <DictationLesson>[];
        order.add(key);
      }
      grouped[key]!.add(lesson);
    }

    return order
        .map((key) => DictationLessonGroup(title: key, lessons: grouped[key]!))
        .toList(growable: false);
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

  String? _resolveSelectedMenuId(List<DictationMenu> menus) {
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
      if (menu.id == '8') {
        return menu.id;
      }
    }
    return menus.first.id;
  }

  String? _resolveSelectedChildId(
    List<DictationMenu> menus,
    String? selectedMenuId,
  ) {
    if (selectedMenuId == null) {
      return null;
    }
    DictationMenu? selected;
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
