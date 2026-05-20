import 'package:flutter/foundation.dart';

import '../../../app/router/route_paths.dart';

enum StudyCatalogGroupField { none, shortText1, shortText2 }

enum StudyCatalogSubtitleField { none, shortText1, shortText2 }

enum StudyCatalogArtworkLabel {
  dictation,
  sightSinging,
  musicTheory,
  answer,
  voice,
  instrumental,
}

@immutable
class StudyCatalogConfig {
  const StudyCatalogConfig({
    required this.key,
    required this.title,
    required this.type,
    required this.defaultFirstMenuId,
    required this.groupField,
    required this.subtitleField,
    required this.artworkLabel,
    required this.targetRoute,
    this.allowSecondMenu = false,
    this.targetArgsBuilder,
  });

  final String key;
  final String title;
  final int type;
  final String defaultFirstMenuId;
  final bool allowSecondMenu;
  final StudyCatalogGroupField groupField;
  final StudyCatalogSubtitleField subtitleField;
  final StudyCatalogArtworkLabel artworkLabel;
  final String targetRoute;
  final Map<String, dynamic> Function(
    StudyCatalogState state,
    StudyCatalogLesson lesson,
  )?
  targetArgsBuilder;

  static const dictation = StudyCatalogConfig(
    key: 'dictation',
    title: '听写',
    type: 3,
    defaultFirstMenuId: '8',
    allowSecondMenu: true,
    groupField: StudyCatalogGroupField.shortText1,
    subtitleField: StudyCatalogSubtitleField.shortText2,
    artworkLabel: StudyCatalogArtworkLabel.dictation,
    targetRoute: RoutePaths.musicPlay,
  );

  static const sightSinging = StudyCatalogConfig(
    key: 'sightSinging',
    title: '视唱',
    type: 1,
    defaultFirstMenuId: '1',
    groupField: StudyCatalogGroupField.shortText2,
    subtitleField: StudyCatalogSubtitleField.shortText1,
    artworkLabel: StudyCatalogArtworkLabel.sightSinging,
    targetRoute: RoutePaths.musicPlay,
    targetArgsBuilder: _buildSightSingingArgs,
  );

  static const musicTheory = StudyCatalogConfig(
    key: 'musicTheory',
    title: '乐理',
    type: 2,
    defaultFirstMenuId: '5',
    allowSecondMenu: true,
    groupField: StudyCatalogGroupField.none,
    subtitleField: StudyCatalogSubtitleField.none,
    artworkLabel: StudyCatalogArtworkLabel.musicTheory,
    targetRoute: RoutePaths.theory,
    targetArgsBuilder: _buildMusicTheoryArgs,
  );

  static const answerQuestions = StudyCatalogConfig(
    key: 'answerQuestions',
    title: '试题',
    type: 10,
    defaultFirstMenuId: '63',
    allowSecondMenu: true,
    groupField: StudyCatalogGroupField.shortText1,
    subtitleField: StudyCatalogSubtitleField.shortText2,
    artworkLabel: StudyCatalogArtworkLabel.answer,
    targetRoute: RoutePaths.answerEnd,
    targetArgsBuilder: _buildAnswerArgs,
  );

  static const voice = StudyCatalogConfig(
    key: 'voice',
    title: '声乐',
    type: 4,
    defaultFirstMenuId: '16',
    groupField: StudyCatalogGroupField.none,
    subtitleField: StudyCatalogSubtitleField.shortText2,
    artworkLabel: StudyCatalogArtworkLabel.voice,
    targetRoute: RoutePaths.musicPlay,
    targetArgsBuilder: _buildVoiceInstrumentArgs,
  );

  static const instrumental = StudyCatalogConfig(
    key: 'instrumental',
    title: '器乐',
    type: 5,
    defaultFirstMenuId: '20',
    groupField: StudyCatalogGroupField.none,
    subtitleField: StudyCatalogSubtitleField.none,
    artworkLabel: StudyCatalogArtworkLabel.instrumental,
    targetRoute: RoutePaths.musicPlay,
    targetArgsBuilder: _buildVoiceInstrumentArgs,
  );
}

@immutable
class StudyCatalogPageArgs {
  const StudyCatalogPageArgs({
    required this.config,
    this.schoolMode = false,
    this.initialFirstMenuId,
    this.initialSecondMenuId,
  });

  final StudyCatalogConfig config;
  final bool schoolMode;
  final String? initialFirstMenuId;
  final String? initialSecondMenuId;

  @override
  bool operator ==(Object other) {
    return other is StudyCatalogPageArgs &&
        other.config.key == config.key &&
        other.schoolMode == schoolMode &&
        other.initialFirstMenuId == initialFirstMenuId &&
        other.initialSecondMenuId == initialSecondMenuId;
  }

  @override
  int get hashCode => Object.hash(
    config.key,
    schoolMode,
    initialFirstMenuId,
    initialSecondMenuId,
  );
}

@immutable
class StudyCatalogMenu {
  const StudyCatalogMenu({
    required this.id,
    required this.name,
    required this.children,
  });

  final String id;
  final String name;
  final List<StudyCatalogMenuChild> children;
}

@immutable
class StudyCatalogMenuChild {
  const StudyCatalogMenuChild({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class StudyCatalogLesson {
  const StudyCatalogLesson({
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
class StudyCatalogLessonGroup {
  const StudyCatalogLessonGroup({required this.title, required this.lessons});

  final String title;
  final List<StudyCatalogLesson> lessons;
}

@immutable
class StudyCatalogState {
  const StudyCatalogState({
    required this.bootstrapping,
    required this.loading,
    required this.schoolMode,
    required this.showVipBadge,
    required this.province,
    required this.config,
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
  final String province;
  final StudyCatalogConfig config;
  final List<StudyCatalogMenu> menus;
  final String? selectedMenuId;
  final String? selectedChildId;
  final List<StudyCatalogLessonGroup> lessonGroups;
  final String errorMessage;
  final DateTime? vipExpireDate;

  StudyCatalogMenu? get selectedMenu {
    for (final menu in menus) {
      if (menu.id == selectedMenuId) {
        return menu;
      }
    }
    return menus.isEmpty ? null : menus.first;
  }

  List<StudyCatalogMenuChild> get selectedChildren =>
      selectedMenu?.children ?? const <StudyCatalogMenuChild>[];

  List<StudyCatalogLesson> get flatLessons {
    final result = <StudyCatalogLesson>[];
    for (final group in lessonGroups) {
      result.addAll(group.lessons);
    }
    return result;
  }

  StudyCatalogState copyWith({
    bool? bootstrapping,
    bool? loading,
    bool? schoolMode,
    bool? showVipBadge,
    String? province,
    StudyCatalogConfig? config,
    List<StudyCatalogMenu>? menus,
    String? selectedMenuId,
    bool clearSelectedMenuId = false,
    String? selectedChildId,
    bool clearSelectedChildId = false,
    List<StudyCatalogLessonGroup>? lessonGroups,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? vipExpireDate,
    bool clearVipExpireDate = false,
  }) {
    return StudyCatalogState(
      bootstrapping: bootstrapping ?? this.bootstrapping,
      loading: loading ?? this.loading,
      schoolMode: schoolMode ?? this.schoolMode,
      showVipBadge: showVipBadge ?? this.showVipBadge,
      province: province ?? this.province,
      config: config ?? this.config,
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

  static StudyCatalogState initial(StudyCatalogConfig config) =>
      StudyCatalogState(
        bootstrapping: true,
        loading: false,
        schoolMode: false,
        showVipBadge: false,
        province: '甘肃',
        config: config,
        menus: const <StudyCatalogMenu>[],
        selectedMenuId: null,
        selectedChildId: null,
        lessonGroups: const <StudyCatalogLessonGroup>[],
        errorMessage: '',
        vipExpireDate: null,
      );
}

Map<String, dynamic> _buildSightSingingArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  return <String, dynamic>{
    'id': lesson.id,
    'type': 3,
    'all': state.flatLessons.map((item) => item.id).toList(growable: false),
  };
}

Map<String, dynamic> _buildMusicTheoryArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  final needsType = state.selectedMenuId == '6';
  return <String, dynamic>{'id': lesson.id, if (needsType) 'type': '1'};
}

Map<String, dynamic> _buildAnswerArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  // 试题 → answerEnd2：听写 / 乐理默认收起答案（题面）；「视唱」分类默认展开答案。
  // 「视唱」也走 answerEnd2（即 MusicPlayPage），并且需要把同分类下所有题目的 id
  // 列表透传过去（'all'），子页才能在「上一首 / 下一首」按钮里复用父页的数据，
  // 不再重新调一遍列表接口。
  final menuName = state.selectedMenu?.name.trim() ?? '';
  final isSightSingingTab = menuName.contains('视唱');
  final usesAnswerEnd2 =
      state.selectedMenuId == '63' ||
      state.selectedMenuId == '64' ||
      isSightSingingTab;

  return <String, dynamic>{
    'id': lesson.id,
    if (!usesAnswerEnd2) 'answerEndMode': true,
    if (usesAnswerEnd2 && !isSightSingingTab) 'closedByDefault': true,
    // 仅「视唱」分类需要 prev / next 切歌（type=3 与 sightSinging 主入口一致）。
    if (isSightSingingTab) 'type': 3,
    if (isSightSingingTab)
      'all': state.flatLessons.map((item) => item.id).toList(growable: false),
  };
}

Map<String, dynamic> _buildVoiceInstrumentArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  // 声乐 / 器乐 的子菜单包括：音组、音程、和弦、节奏、旋律、调式、乐句、单音。
  // 跟「听写」入口保持一致：仅「节奏」「旋律」类目播完自动接下一首；其余
  // 类目（音程 / 和弦 / 单音 …）维持播完即停的默认行为。
  final menuName = state.selectedMenu?.name ?? '';
  final isAutoPlayCategory =
      menuName.contains('节奏') || menuName.contains('旋律');
  return <String, dynamic>{
    'id': lesson.id,
    'type': 2,
    if (isAutoPlayCategory) 'autoPlayNext': true,
  };
}
