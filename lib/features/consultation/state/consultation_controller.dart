import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consultation_repository.dart';
import 'consultation_state.dart';

/// 资讯接口暂未联动用户省份，先按 1.0 默认值传「甘肃」。
const String _kDefaultProvince = '甘肃';

final consultationControllerProvider =
    StateNotifierProvider.autoDispose<
      ConsultationController,
      ConsultationState
    >((ref) {
      final repo = ref.watch(consultationRepositoryProvider);
      return ConsultationController(repository: repo);
    });

class ConsultationController extends StateNotifier<ConsultationState> {
  ConsultationController({required ConsultationRepository repository})
    : _repository = repository,
      super(ConsultationState.initial) {
    unawaited(refresh());
  }

  final ConsultationRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearErrorMessage: true);
    final response = await _repository.getList(province: _kDefaultProvince);
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        items: const <ConsultationItem>[],
        errorMessage: response.msg.isEmpty ? '资讯加载失败' : response.msg,
      );
      return;
    }
    final raw = response.data;
    if (raw is! List) {
      state = state.copyWith(loading: false, items: const <ConsultationItem>[]);
      return;
    }
    final items = <ConsultationItem>[];
    for (final node in raw) {
      if (node is Map) items.add(ConsultationItem.fromJson(node));
    }
    state = state.copyWith(loading: false, items: items);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }
}
