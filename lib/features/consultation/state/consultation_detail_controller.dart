import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consultation_repository.dart';
import 'consultation_detail_state.dart';

final consultationDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<
      ConsultationDetailController,
      ConsultationDetailState,
      ConsultationDetailArgs
    >((ref, args) {
      final repo = ref.watch(consultationRepositoryProvider);
      return ConsultationDetailController(repository: repo, args: args);
    });

class ConsultationDetailController
    extends StateNotifier<ConsultationDetailState> {
  ConsultationDetailController({
    required ConsultationRepository repository,
    required ConsultationDetailArgs args,
  }) : _repository = repository,
       super(ConsultationDetailState.fromArgs(args)) {
    unawaited(_load());
  }

  final ConsultationRepository _repository;

  Future<void> _load() async {
    final id = state.args.id;
    if (id <= 0) {
      state = state.copyWith(loading: false, errorMessage: '资讯不存在');
      return;
    }
    final response = await _repository.getDetail(id);
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: response.msg.isEmpty ? '加载失败' : response.msg,
      );
      return;
    }
    final data = response.data;
    if (data is! Map) {
      state = state.copyWith(loading: false, errorMessage: '数据异常');
      return;
    }
    state = state.copyWith(
      loading: false,
      detail: ConsultationDetail.fromJson(data),
    );
  }

  Future<void> openShareDialog() async {
    state = state.copyWith(
      shareDialogVisible: true,
      classLoading: state.classList.isEmpty,
      clearErrorMessage: true,
    );
    final response = await _repository.getClassList();
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        classLoading: false,
        errorMessage: response.msg.isEmpty ? '获取班级群失败' : response.msg,
      );
      return;
    }
    final raw = response.data;
    final list = <ConsultationClass>[];
    if (raw is List) {
      for (final node in raw) {
        if (node is Map) list.add(ConsultationClass.fromJson(node));
      }
    }
    state = state.copyWith(classList: list, classLoading: false);
  }

  void closeShareDialog() {
    state = state.copyWith(shareDialogVisible: false);
  }

  void toggleClass(String classId) {
    final list = <ConsultationClass>[
      for (final c in state.classList)
        if (c.id == classId) c.copyWith(checked: !c.checked) else c,
    ];
    state = state.copyWith(classList: list);
  }

  /// 发送分享：根据已勾选的班级群依次发起 sendMsg。
  Future<bool> send() async {
    final detail = state.detail;
    if (detail == null) return false;
    final selected = state.classList
        .where((c) => c.checked && c.id.isNotEmpty)
        .toList();
    if (selected.isEmpty) {
      final hasChecked = state.classList.any((c) => c.checked);
      state = state.copyWith(
        errorMessage: hasChecked ? '所选班级数据异常，请刷新后重试' : '请先选择要分享的班级群',
      );
      return false;
    }
    state = state.copyWith(sending: true, clearErrorMessage: true);
    final content = jsonEncode(<String, dynamic>{
      'id': detail.id,
      'title': detail.title,
      'shortText3': detail.coverUrl,
      'updateTime': detail.updateTime,
    });

    var sentCount = 0;
    for (final cls in selected) {
      final response = await _repository.sendMsg(
        classId: cls.id,
        content: content,
      );
      if (!mounted) return false;
      if (response.isSuccess) {
        sentCount += 1;
      } else {
        state = state.copyWith(
          sending: false,
          errorMessage: response.msg.isEmpty ? '发送失败' : response.msg,
        );
        return false;
      }
    }

    final allSent = sentCount == selected.length;
    state = state.copyWith(
      sending: false,
      shareDialogVisible: !allSent,
      errorMessage: allSent ? '消息已成功发送' : state.errorMessage,
    );
    return allSent;
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }
}
