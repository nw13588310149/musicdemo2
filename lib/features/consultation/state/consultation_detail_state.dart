import 'package:flutter/foundation.dart';

@immutable
class ConsultationDetailArgs {
  const ConsultationDetailArgs({required this.id});

  final int id;

  factory ConsultationDetailArgs.fromRaw(dynamic raw) {
    if (raw is ConsultationDetailArgs) return raw;
    if (raw is int) return ConsultationDetailArgs(id: raw);
    if (raw is Map) {
      final id = raw['id'];
      if (id is int) return ConsultationDetailArgs(id: id);
      if (id is num) return ConsultationDetailArgs(id: id.toInt());
      final parsed = int.tryParse(id?.toString() ?? '');
      if (parsed != null) return ConsultationDetailArgs(id: parsed);
    }
    final parsed = int.tryParse(raw?.toString() ?? '');
    return ConsultationDetailArgs(id: parsed ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      other is ConsultationDetailArgs && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class ConsultationDetail {
  const ConsultationDetail({
    required this.id,
    required this.title,
    required this.source,
    required this.updateTime,
    required this.viewCount,
    required this.htmlContent,
    required this.coverUrl,
  });

  final int id;
  final String title;

  /// 1.0 中固定显示"音乐之路"，但接口可能也提供来源字段，留作扩展。
  final String source;

  /// yyyy-MM-dd HH:mm:ss 字符串，直接展示。
  final String updateTime;

  final int viewCount;
  final String htmlContent;

  /// 详情页头部封面图（接口字段 shortText3）。
  final String coverUrl;

  factory ConsultationDetail.fromJson(Map raw) {
    return ConsultationDetail(
      id: _toInt(raw['id']) ?? 0,
      title: raw['title']?.toString() ?? '',
      source: '音乐之路',
      updateTime: raw['updateTime']?.toString() ?? '',
      viewCount: _toInt(raw['viewCount']) ?? 0,
      htmlContent: raw['longText1']?.toString() ?? '',
      coverUrl: raw['shortText3']?.toString() ?? '',
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

@immutable
class ConsultationClass {
  const ConsultationClass({
    required this.id,
    required this.name,
    required this.checked,
  });

  /// 班级主键。后端使用 19 位 snowflake id（字符串），转成 int 在 Web 平台
  /// 的 JS Number（53 位精度）下会丢失末位精度，所以这里始终保持字符串。
  final String id;
  final String name;
  final bool checked;

  ConsultationClass copyWith({bool? checked}) =>
      ConsultationClass(id: id, name: name, checked: checked ?? this.checked);

  factory ConsultationClass.fromJson(Map raw) {
    return ConsultationClass(
      id: raw['id']?.toString() ?? '',
      name: raw['name']?.toString() ?? '',
      checked: false,
    );
  }
}

@immutable
class ConsultationDetailState {
  const ConsultationDetailState({
    required this.args,
    required this.loading,
    required this.detail,
    required this.classList,
    required this.shareDialogVisible,
    required this.classLoading,
    required this.sending,
    required this.errorMessage,
  });

  final ConsultationDetailArgs args;
  final bool loading;
  final ConsultationDetail? detail;
  final List<ConsultationClass> classList;
  final bool shareDialogVisible;
  final bool classLoading;
  final bool sending;
  final String errorMessage;

  bool get hasCheckedClass => classList.any((c) => c.checked);

  ConsultationDetailState copyWith({
    bool? loading,
    ConsultationDetail? detail,
    List<ConsultationClass>? classList,
    bool? shareDialogVisible,
    bool? classLoading,
    bool? sending,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ConsultationDetailState(
      args: args,
      loading: loading ?? this.loading,
      detail: detail ?? this.detail,
      classList: classList ?? this.classList,
      shareDialogVisible: shareDialogVisible ?? this.shareDialogVisible,
      classLoading: classLoading ?? this.classLoading,
      sending: sending ?? this.sending,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
    );
  }

  static ConsultationDetailState fromArgs(ConsultationDetailArgs args) =>
      ConsultationDetailState(
        args: args,
        loading: true,
        detail: null,
        classList: const <ConsultationClass>[],
        shareDialogVisible: false,
        classLoading: false,
        sending: false,
        errorMessage: '',
      );
}
