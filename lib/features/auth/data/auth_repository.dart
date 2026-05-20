import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(appStorageProvider);
  return AuthRepository(client: client, storage: storage);
});

class AuthRepository {
  AuthRepository({required this.client, required AppStorage storage})
    : _storage = storage;

  final ApiClient client;
  final AppStorage _storage;

  Future<ApiResponse> getCheck() {
    return client.get(
      '/app/common/dict/check',
      headers: const {'platform': 'ipad', 'ver': '1.0.1'},
      timeout: const Duration(seconds: 10),
    );
  }

  Future<ApiResponse> login({
    required String mobile,
    required String password,
  }) {
    return client.post(
      '/app/user/mobileLogin',
      data: <String, dynamic>{
        'deviceId': AppConstants.fallbackDeviceId,
        'deviceName': _buildDeviceName(),
        'deviceType': _buildDeviceType(),
        'mobile': mobile,
        'password': password,
      },
    );
  }

  Future<ApiResponse> sendSms({required String mobile, required int type}) {
    return client.post(
      '/app/user/sendSmsCode',
      data: <String, dynamic>{'mobile': mobile, 'type': type},
    );
  }

  Future<ApiResponse> register({
    required String mobile,
    required String password,
    required String smsCode,
  }) {
    return client.post(
      '/app/user/register',
      data: <String, dynamic>{
        'mobile': mobile,
        'password': password,
        'smsCode': smsCode,
      },
    );
  }

  Future<ApiResponse> resetPassword({
    required String mobile,
    required String password,
    required String smsCode,
  }) {
    return client.post(
      '/app/user/resetPassword',
      data: <String, dynamic>{
        'mobile': mobile,
        'password': password,
        'smsCode': smsCode,
      },
    );
  }

  Future<ApiResponse> reportCid(String cid) {
    return client.post(
      '/app/user/reportCid',
      data: <String, dynamic>{'cid': cid},
    );
  }

  Future<void> persistToken(String token) async {
    await _storage.saveToken(token);
    await _storage.saveSchoolId(0);
    await client.updateToken(token);
  }

  /// 登录 / 注册成功后保存当前账号手机号，供 ShellController 在
  /// `refreshUserAndSchool` 时判定演示用「白名单管理员」是否需要覆盖
  /// user.role 为 admin。
  Future<void> persistMobile(String mobile) async {
    await _storage.saveMobile(mobile);
  }

  Future<void> saveCheckStatus(dynamic value) async {
    await _storage.saveCheckStatus(value);
  }

  String get pushId => _storage.pushId;

  String _buildDeviceName() {
    if (kIsWeb) {
      return 'web';
    }
    return defaultTargetPlatform.name;
  }

  String _buildDeviceType() {
    if (kIsWeb) {
      return 'pc';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return 'phone';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return 'pc';
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }
}
