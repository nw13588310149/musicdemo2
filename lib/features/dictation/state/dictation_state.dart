import 'package:flutter/foundation.dart';

@immutable
class DictationPageArgs {
  const DictationPageArgs({
    this.schoolMode = false,
    this.initialFirstMenuId,
    this.initialSecondMenuId,
  });

  final bool schoolMode;
  final String? initialFirstMenuId;
  final String? initialSecondMenuId;

  @override
  bool operator ==(Object other) {
    return other is DictationPageArgs &&
        other.schoolMode == schoolMode &&
        other.initialFirstMenuId == initialFirstMenuId &&
        other.initialSecondMenuId == initialSecondMenuId;
  }

  @override
  int get hashCode =>
      Object.hash(schoolMode, initialFirstMenuId, initialSecondMenuId);
}

@immutable
class DictationMenu {
  const DictationMenu({
    required this.id,
    required this.name,
    required this.children,
  });

  final String id;
  final String name;
  final List<DictationMenuChild> children;
}

@immutable
class DictationMenuChild {
  const DictationMenuChild({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class DictationLesson {
  const DictationLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.groupTitle,
    required this.vip,
  });

  final String id;
  final String title;
  final String subtitle;
  final String groupTitle;
  final bool vip;
}

@immutable
class DictationLessonGroup {
  const DictationLessonGroup({required this.title, required this.lessons});

  final String title;
  final List<DictationLesson> lessons;
}

@immutable
class DictationState {
  const DictationState({
    required this.bootstrapping,
    required this.loading,
    required this.schoolMode,
    required this.showVipBadge,
    required this.menus,
    required this.selectedMenuId,
    required this.selectedChildId,
    required this.lessonGroups,
    required this.errorMessage,
    required this.vipExpireDate,
  });

  final bool bootstrapping;
  final bool loading;
  final bool schoolMode;
  final bool showVipBadge;
  final List<DictationMenu> menus;
  final String? selectedMenuId;
  final String? selectedChildId;
  final List<DictationLessonGroup> lessonGroups;
  final String errorMessage;
  final DateTime? vipExpireDate;

  DictationMenu? get selectedMenu {
    for (final menu in menus) {
      if (menu.id == selectedMenuId) {
        return menu;
      }
    }
    return menus.isEmpty ? null : menus.first;
  }

  List<DictationMenuChild> get selectedChildren =>
      selectedMenu?.children ?? const <DictationMenuChild>[];

  List<DictationLesson> get flatLessons {
    final result = <DictationLesson>[];
    for (final group in lessonGroups) {
      result.addAll(group.lessons);
    }
    return result;
  }

  DictationState copyWith({
    bool? bootstrapping,
    bool? loading,
    bool? schoolMode,
    bool? showVipBadge,
    List<DictationMenu>? menus,
    String? selectedMenuId,
    bool clearSelectedMenuId = false,
    String? selectedChildId,
    bool clearSelectedChildId = false,
    List<DictationLessonGroup>? lessonGroups,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? vipExpireDate,
    bool clearVipExpireDate = false,
  }) {
    return DictationState(
      bootstrapping: bootstrapping ?? this.bootstrapping,
      loading: loading ?? this.loading,
      schoolMode: schoolMode ?? this.schoolMode,
      showVipBadge: showVipBadge ?? this.showVipBadge,
      menus: menus ?? this.menus,
      selectedMenuId: clearSelectedMenuId
          ? null
          : (selectedMenuId ?? this.selectedMenuId),
      selectedChildId: clearSelectedChildId
          ? null
          : (selectedChildId ?? this.selectedChildId),
      lessonGroups: lessonGroups ?? this.lessonGroups,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      vipExpireDate: clearVipExpireDate
          ? null
          : (vipExpireDate ?? this.vipExpireDate),
    );
  }

  static const DictationState initial = DictationState(
    bootstrapping: true,
    loading: false,
    schoolMode: false,
    showVipBadge: false,
    menus: <DictationMenu>[],
    selectedMenuId: null,
    selectedChildId: null,
    lessonGroups: <DictationLessonGroup>[],
    errorMessage: '',
    vipExpireDate: null,
  );
}
