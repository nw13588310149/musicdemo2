import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../data/home_repository.dart';
import 'home_dashboard_state.dart';

final homeDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      HomeDashboardController,
      HomeDashboardState
    >((ref) {
      final repository = ref.watch(homeRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      final controller = HomeDashboardController(
        repository: repository,
        storage: storage,
      );
      return controller;
    });

class HomeDashboardController extends StateNotifier<HomeDashboardState> {
  HomeDashboardController({
    required HomeRepository repository,
    required AppStorage storage,
  }) : _repository = repository,
       _storage = storage,
       super(
         HomeDashboardState(
           quickActions: buildQuickActions(storage.hasCheckStatus),
         ),
       ) {
    unawaited(refresh());
  }

  final HomeRepository _repository;
  final AppStorage _storage;

  Future<void> refresh() async {
    try {
      state = state.copyWith(
        loading: true,
        quickActions: buildQuickActions(_storage.hasCheckStatus),
        errorMessage: '',
      );

      final responses = await Future.wait<ApiResponse>([
        _safeRequest(_repository.getMyInfo),
        _safeRequest(_repository.getBannerList),
        _safeRequest(_repository.getLatestInfo),
        _safeRequest(_repository.getNextSchoolCourse),
      ]);

      final myInfoResponse = responses[0];
      final bannerResponse = responses[1];
      final latestResponse = responses[2];
      final nextCourseResponse = responses[3];

      final weekItems = await _buildWeekItems(myInfoResponse.data);
      final banners = _parseBanners(bannerResponse.data);
      final newsItems = _parseNews(latestResponse.data);
      final notices = _parseCourseNotices(nextCourseResponse.data);

      final hasAnyData =
          banners.isNotEmpty ||
          newsItems.isNotEmpty ||
          weekItems.isNotEmpty ||
          notices.isNotEmpty;

      state = state.copyWith(
        loading: false,
        bannerItems: banners,
        newsItems: newsItems,
        weekItems: weekItems,
        courseNotices: notices,
        errorMessage: hasAnyData ? '' : '暂无数据，请稍后重试',
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        weekItems: state.weekItems.isEmpty
            ? _emptyWeekItems()
            : state.weekItems,
        errorMessage: '首页加载失败，请稍后重试',
      );
    }
  }

  Future<ApiResponse> _safeRequest(Future<ApiResponse> Function() request) {
    return request()
        .timeout(const Duration(seconds: 8))
        .catchError((_) => const ApiResponse(code: -1, msg: '', data: null));
  }

  List<HomeBannerItem> _parseBanners(dynamic data) {
    if (data is! List) {
      return const [];
    }

    final result = <HomeBannerItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final image = item['img']?.toString() ?? '';
      if (image.isEmpty) {
        continue;
      }
      result.add(HomeBannerItem(imageUrl: image));
    }
    return result;
  }

  List<HomeNewsItem> _parseNews(dynamic data) {
    // 兼容两种接口结构：
    //   直接数组：data = [{...}, ...]
    //   嵌套对象：data = {list: [...]} 或 {records: [...]} 或 {data: [...]}
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      final inner =
          data['list'] ?? data['records'] ?? data['data'] ?? data['rows'];
      if (inner is List) {
        list = inner;
      } else {
        return const [];
      }
    } else {
      return const [];
    }

    final result = <HomeNewsItem>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final rawTags = item['shortText2']?.toString() ?? '';
      final normalized = rawTags
          .replaceAll('\uFF0C', ',')
          .replaceAll('\u3001', ',')
          .replaceAll('\uFF1B', ',')
          .replaceAll(';', ',');
      final tags = normalized
          .split(RegExp(r'[\s,]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final created = DateTime.tryParse(item['createTime']?.toString() ?? '');

      result.add(
        HomeNewsItem(
          id: _toInt(item['id']),
          title: item['title']?.toString() ?? '',
          shortTitle:
              item['shortText1']?.toString() ?? '\u6700\u65b0\u8d44\u8baf',
          tags: tags,
          viewCount: _toInt(item['viewCount']),
          createTime: created,
        ),
      );
    }
    return result;
  }

  List<HomeCourseNotice> _parseCourseNotices(dynamic data) {
    if (data is! List || data.isEmpty) {
      return const [];
    }

    final result = <HomeCourseNotice>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final subject = _extractMap(item['subject']);
      final teacher = _extractMap(item['teacher']);
      final beginTime = _toTimeText(item['timeBegin']?.toString() ?? '');
      final endTime = _toTimeText(item['timeEnd']?.toString() ?? '');
      final subjectName = subject['name']?.toString() ?? '';
      final teacherName =
          teacher['realname']?.toString().trim().isNotEmpty == true
          ? teacher['realname'].toString().trim()
          : teacher['nickname']?.toString().trim() ?? '';

      if (subjectName.isEmpty || teacherName.isEmpty) {
        continue;
      }

      // 从 timeBegin/timeEnd 计算真实课时时长
      final durationMinutes = _calcDurationMinutes(
        item['timeBegin']?.toString() ?? '',
        item['timeEnd']?.toString() ?? '',
      );
      final durationText = durationMinutes > 0
          ? '$durationMinutes分钟·音乐体验课'
          : '45分钟·音乐体验课';

      // 接口 color 字段作为卡片彩色标记（如 "#fed7aa"）
      final colorHex = item['color']?.toString();

      result.add(
        HomeCourseNotice(
          startTime: beginTime,
          endTime: endTime,
          subjectName: subjectName,
          teacherName: teacherName,
          teacherAvatar: teacher['headUrl']?.toString() ?? '',
          description: durationText,
          status: _isEnded(item)
              ? HomeCourseStatus.ended
              : HomeCourseStatus.upcoming,
          cardColorHex:
              (colorHex != null &&
                  colorHex.isNotEmpty &&
                  colorHex != '#ffffff' &&
                  colorHex != '#FFFFFF')
              ? colorHex
              : null,
        ),
      );
    }

    if (result.isEmpty) {
      return const [];
    }

    return result.take(3).toList();
  }

  bool _isEnded(Map<String, dynamic> item) {
    final date = item['date']?.toString() ?? '';
    final endTime = item['timeEnd']?.toString() ?? '';
    final dateTime = DateTime.tryParse('$date ${_toTimeText(endTime)}:00');
    if (dateTime == null) {
      return false;
    }
    return dateTime.isBefore(DateTime.now());
  }

  String _toTimeText(String value) {
    if (value.length >= 5) {
      return value.substring(0, 5);
    }
    return value;
  }

  Future<List<HomeWeekDayItem>> _buildWeekItems(dynamic myInfoData) async {
    final userMap = _extractUser(myInfoData);
    final userId = _toInt(userMap['id']);
    final role = userMap['role']?.toString() ?? '';
    final isTeacher = role == 'teacher';

    int classOrTeacherId = userId;
    if (!isTeacher) {
      final classResponse = await _safeRequest(_repository.getClassList);
      if (classResponse.code == 0 && classResponse.data is List) {
        final classList = classResponse.data as List;
        if (classList.isNotEmpty && classList.first is Map<String, dynamic>) {
          classOrTeacherId = _toInt(
            (classList.first as Map<String, dynamic>)['id'],
          );
        }
      }
    }

    if (classOrTeacherId <= 0) {
      return _emptyWeekItems();
    }

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final beginDate = _formatDate(monday);
    final endDate = _formatDate(sunday);

    final courseResponse = await _safeRequest(
      () => _repository.getCourseList(
        beginDate: beginDate,
        endDate: endDate,
        id: classOrTeacherId,
        isTeacher: isTeacher,
      ),
    );

    if (courseResponse.code != 0 ||
        courseResponse.data is! Map<String, dynamic>) {
      return _emptyWeekItems();
    }

    final courseMap = courseResponse.data as Map<String, dynamic>;
    const weeks = [
      '\u5468\u4e00',
      '\u5468\u4e8c',
      '\u5468\u4e09',
      '\u5468\u56db',
      '\u5468\u4e94',
      '\u5468\u516d',
      '\u5468\u65e5',
    ];
    final items = <HomeWeekDayItem>[];
    for (var i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateText = _formatDate(date);
      final dayCourses = courseMap[dateText];
      final count = dayCourses is List ? dayCourses.length : 0;

      items.add(
        HomeWeekDayItem(
          weekText: weeks[i],
          dayText: '${date.day}',
          dateText: dateText,
          courseCount: count,
          isToday:
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day,
        ),
      );
    }
    return items;
  }

  List<HomeWeekDayItem> _emptyWeekItems() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const weeks = [
      '\u5468\u4e00',
      '\u5468\u4e8c',
      '\u5468\u4e09',
      '\u5468\u56db',
      '\u5468\u4e94',
      '\u5468\u516d',
      '\u5468\u65e5',
    ];

    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return HomeWeekDayItem(
        weekText: weeks[index],
        dayText: '${date.day}',
        dateText: _formatDate(date),
        courseCount: 0,
        isToday:
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day,
      );
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, dynamic> _extractUser(dynamic data) {
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }
    return const {};
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    return const {};
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// 从 "HH:MM:SS" 或 "HH:MM" 格式计算两个时间点之间的分钟数
  int _calcDurationMinutes(String begin, String end) {
    try {
      final bParts = begin.split(':').map(int.parse).toList();
      final eParts = end.split(':').map(int.parse).toList();
      final bMin = bParts[0] * 60 + bParts[1];
      final eMin = eParts[0] * 60 + eParts[1];
      return (eMin - bMin).clamp(0, 480);
    } catch (_) {
      return 0;
    }
  }
}
