import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_unauthorized_handler.dart';
import '../network/chat_socket_service.dart';
import '../storage/app_storage.dart';

final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('AppStorage provider must be overridden in main().');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(appStorageProvider);
  return ApiClient(storage: storage);
});

/// 在 [MyApp] 挂载后绑定一次，避免 [apiClientProvider] 与 shell 模块循环依赖。
void bindApiUnauthorizedSessionCleanup(WidgetRef ref) {
  ApiUnauthorizedHandler.instance.bindSessionCleared(() {
    ref.read(chatSocketServiceProvider).disconnect();
  });
}
