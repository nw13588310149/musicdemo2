import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import 'home_state.dart';

final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>(
  (ref) {
    final storage = ref.watch(appStorageProvider);
    return HomeController(storage: storage);
  },
);

class HomeController extends StateNotifier<HomeState> {
  HomeController({required AppStorage storage})
    : _storage = storage,
      super(HomeState(token: storage.token));

  final AppStorage _storage;

  Future<void> logout() async {
    await _storage.clearToken();
    state = state.copyWith(token: '');
  }
}
