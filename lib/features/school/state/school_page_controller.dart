import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/school_repository.dart';
import 'school_page_state.dart';

final schoolPageControllerProvider =
    StateNotifierProvider.autoDispose<SchoolPageController, SchoolPageState>((
      ref,
    ) {
      final repository = ref.watch(schoolRepositoryProvider);
      return SchoolPageController(repository: repository);
    });

class SchoolPageController extends StateNotifier<SchoolPageState> {
  SchoolPageController({required SchoolRepository repository})
    : _repository = repository,
      super(SchoolPageState(quickActions: buildSchoolQuickActions())) {
    unawaited(refresh());
  }

  final SchoolRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, errorMessage: '');

    final responses = await Future.wait([
      _repository.getSchoolInfo(),
      _repository.getLearningProgress(),
      _repository.getLatestInfo(),
    ]);

    final schoolResponse = responses[0];
    final progressResponse = responses[1];
    final latestResponse = responses[2];

    final schoolMap = _asMap(schoolResponse.data);
    final schoolId = _toInt(schoolMap['id']);
    final schoolName = schoolMap['name']?.toString() ?? '';

    final learningItems = _parseLearning(progressResponse.data);
    final newsItems = _parseNews(latestResponse.data);

    final hasAnyData =
        schoolName.isNotEmpty ||
        learningItems.isNotEmpty ||
        newsItems.isNotEmpty;

    state = state.copyWith(
      loading: false,
      schoolId: schoolId,
      schoolName: schoolName,
      learningItems: learningItems,
      newsItems: newsItems,
      errorMessage: hasAnyData ? '' : '暂无校园数据，请稍后重试',
    );
  }

  List<SchoolLearningItem> _parseLearning(dynamic data) {
    final map = _asMap(data);
    if (map.isEmpty) {
      return const [];
    }

    final dictation = _toInt(map['tx']).clamp(0, 100);
    final sightSinging = _toInt(map['sc']).clamp(0, 100);
    final theory = _toInt(map['yl']).clamp(0, 100);

    return [
      SchoolLearningItem(
        text: '听写',
        value: dictation,
        color: const Color(0xFFB184FF),
        background: const Color(0xFFF0EBFA),
      ),
      SchoolLearningItem(
        text: '视唱',
        value: sightSinging,
        color: const Color(0xFF13E8BE),
        background: const Color(0xFFF0EBFA),
      ),
      SchoolLearningItem(
        text: '乐理',
        value: theory,
        color: const Color(0xFFFF5681),
        background: const Color(0xFFF0EBFA),
      ),
    ];
  }

  List<SchoolNewsItem> _parseNews(dynamic data) {
    if (data is! List) {
      return const [];
    }

    final result = <SchoolNewsItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final normalizedTags = (item['shortText2']?.toString() ?? '').replaceAll(
        RegExp(r'[、；;|，]'),
        ',',
      );

      final tags = normalizedTags
          .split(RegExp(r'[,\s]+'))
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();

      result.add(
        SchoolNewsItem(
          id: _toInt(item['id']),
          title: item['title']?.toString() ?? '',
          shortTitle: item['shortText1']?.toString() ?? '最新资讯',
          tags: tags,
          viewCount: _toInt(item['viewCount']),
          createTime: DateTime.tryParse(item['createTime']?.toString() ?? ''),
        ),
      );
    }

    return result;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    // v2 `schoolList` 接口返回学校数组：取首项作为「当前学校」即可，
    // 与旧版 `mySchool`（单 Map）行为对齐。
    if (value is List && value.isNotEmpty) {
      return _asMap(value.first);
    }
    return const {};
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
