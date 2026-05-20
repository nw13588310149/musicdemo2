import 'package:flutter/foundation.dart';

@immutable
class TheoryPageArgs {
  const TheoryPageArgs({
    required this.id,
    this.type,
    this.answerEndMode = false,
  });

  final int id;
  final String? type;
  final bool answerEndMode;

  factory TheoryPageArgs.fromRaw(dynamic raw) {
    if (raw is TheoryPageArgs) {
      return raw;
    }
    if (raw is Map) {
      final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
      final typeRaw = raw['type']?.toString();
      final type = (typeRaw == null || typeRaw.isEmpty) ? null : typeRaw;
      return TheoryPageArgs(
        id: id,
        type: type,
        answerEndMode:
            _toBool(raw['answerEndMode']) ||
            raw['mode']?.toString() == 'answerEnd' ||
            raw['source']?.toString() == 'answerEnd',
      );
    }
    return const TheoryPageArgs(id: 0);
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }

  @override
  bool operator ==(Object other) {
    return other is TheoryPageArgs &&
        other.id == id &&
        other.type == type &&
        other.answerEndMode == answerEndMode;
  }

  @override
  int get hashCode => Object.hash(id, type, answerEndMode);
}

@immutable
class TheoryDetail {
  const TheoryDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.firstMenu,
    required this.vipOnly,
    required this.favorite,
    required this.htmlContent,
    required this.pdfUrl,
    required this.assignmentImages,
    required this.answerImages,
  });

  final int id;

  /// 教材类型，用于 `/app/user/favoriteSave` 的 type 参数（与 1.0 对齐）。
  final int type;
  final String title;
  final int firstMenu;
  final bool vipOnly;

  /// 当前是否已收藏，对应接口里的 `isFavorite` 字段。
  final bool favorite;
  final String htmlContent;
  final String pdfUrl;
  final List<String> assignmentImages;
  final List<String> answerImages;

  bool get hasPdf => pdfUrl.isNotEmpty;
  bool get hasAssignmentImages => assignmentImages.isNotEmpty;
  bool get hasAnswerImages => answerImages.isNotEmpty;
  bool get showsAssignmentButton => firstMenu != 6;
  bool get hasHtmlContent => htmlContent.trim().isNotEmpty;

  TheoryDetail copyWith({bool? favorite}) {
    return TheoryDetail(
      id: id,
      type: type,
      title: title,
      firstMenu: firstMenu,
      vipOnly: vipOnly,
      favorite: favorite ?? this.favorite,
      htmlContent: htmlContent,
      pdfUrl: pdfUrl,
      assignmentImages: assignmentImages,
      answerImages: answerImages,
    );
  }
}

@immutable
class TheoryShareClass {
  const TheoryShareClass({
    required this.id,
    required this.name,
    required this.checked,
  });

  final String id;
  final String name;
  final bool checked;

  TheoryShareClass copyWith({bool? checked}) =>
      TheoryShareClass(id: id, name: name, checked: checked ?? this.checked);

  factory TheoryShareClass.fromJson(Map raw) {
    return TheoryShareClass(
      id: raw['id']?.toString() ?? '',
      name: raw['name']?.toString() ?? '',
      checked: false,
    );
  }
}

@immutable
class TheoryState {
  const TheoryState({
    required this.args,
    required this.loading,
    required this.detail,
    required this.errorMessage,
    required this.shareDialogVisible,
    required this.classLoading,
    required this.sending,
    required this.classList,
  });

  final TheoryPageArgs args;
  final bool loading;
  final TheoryDetail? detail;
  final String errorMessage;
  final bool shareDialogVisible;
  final bool classLoading;
  final bool sending;
  final List<TheoryShareClass> classList;

  bool get hasDetail => detail != null;

  TheoryState copyWith({
    TheoryPageArgs? args,
    bool? loading,
    TheoryDetail? detail,
    bool clearDetail = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? shareDialogVisible,
    bool? classLoading,
    bool? sending,
    List<TheoryShareClass>? classList,
  }) {
    return TheoryState(
      args: args ?? this.args,
      loading: loading ?? this.loading,
      detail: clearDetail ? null : (detail ?? this.detail),
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      shareDialogVisible: shareDialogVisible ?? this.shareDialogVisible,
      classLoading: classLoading ?? this.classLoading,
      sending: sending ?? this.sending,
      classList: classList ?? this.classList,
    );
  }

  static TheoryState initial(TheoryPageArgs args) => TheoryState(
    args: args,
    loading: true,
    detail: null,
    errorMessage: '',
    shareDialogVisible: false,
    classLoading: false,
    sending: false,
    classList: const <TheoryShareClass>[],
  );
}
