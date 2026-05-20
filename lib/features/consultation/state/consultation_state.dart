import 'package:flutter/foundation.dart';

@immutable
class ConsultationItem {
  const ConsultationItem({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.createTime,
    required this.viewCount,
  });

  final int id;
  final String title;
  final String coverUrl;

  /// 发布时间，原始 yyyy-MM-dd HH:mm:ss。
  final DateTime? createTime;

  final int viewCount;

  factory ConsultationItem.fromJson(Map raw) {
    return ConsultationItem(
      id: _toInt(raw['id']) ?? 0,
      title: raw['title']?.toString() ?? '',
      coverUrl: raw['shortText3']?.toString() ?? '',
      createTime: _toDate(raw['createTime']),
      viewCount: _toInt(raw['viewCount']) ?? 0,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str.replaceFirst(' ', 'T'));
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

@immutable
class ConsultationState {
  const ConsultationState({
    required this.loading,
    required this.items,
    required this.errorMessage,
  });

  final bool loading;
  final List<ConsultationItem> items;
  final String errorMessage;

  ConsultationState copyWith({
    bool? loading,
    List<ConsultationItem>? items,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ConsultationState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
    );
  }

  static const ConsultationState initial = ConsultationState(
    loading: true,
    items: <ConsultationItem>[],
    errorMessage: '',
  );
}

/// 与 1.0 `formatTime` 一致：刚刚/N分钟前/N小时前/N天前/N月前/yyyy-MM-dd。
String formatRelativeTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final diff = now.difference(time).inMilliseconds.abs();
  final minutes = diff ~/ (1000 * 60);
  final hours = minutes ~/ 60;
  final days = hours ~/ 24;
  final months = days ~/ 30;
  final years = months ~/ 12;

  if (minutes < 1) return '刚刚';
  if (minutes < 60) return '$minutes分钟前';
  if (hours < 24) return '$hours小时前';
  if (days < 30) return '$days天前';
  if (months < 12) return '$months月前';
  if (years >= 1) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
  return '';
}
