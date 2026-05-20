import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final personalCenterRepositoryProvider = Provider<PersonalCenterRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return PersonalCenterRepository(client: client);
});

/// 个人中心相关接口（对齐 1.0 `api/home.js`）。
class PersonalCenterRepository {
  PersonalCenterRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<ApiResponse> getMyInfo() => _client.post('/app/user/myInfo');

  Future<ApiResponse> vipList() =>
      _client.post('/app/user/vipList', data: const <String, dynamic>{});

  Future<ApiResponse> myQrcode() =>
      _client.post('/app/user/myQrcode', data: const <String, dynamic>{});

  Future<ApiResponse> vipCardRedeem(String cardNumber) => _client.post(
    '/app/user/vipCardRedeem',
    data: <String, dynamic>{'cardNumber': cardNumber},
  );

  /// 个人资料修改：传入需要更新的字段（昵称 / 性别 / 生日 / 学校 / 简介 / 头像 等）。
  Future<ApiResponse> editMyInfo(Map<String, dynamic> data) =>
      _client.post('/app/user/userinfoUpdate', data: data);

  /// 修改密码（明文老密码 + 新密码，与 1.0 `updatePassword` 一致）。
  Future<ApiResponse> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) => _client.post(
    '/app/user/updatePassword',
    data: <String, dynamic>{
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    },
  );

  /// 省份地区列表（对齐 1.0 `getCity`）。
  Future<ApiResponse> provinceCityList() => _client.post(
    '/app/common/provinceCityList',
    data: const <String, dynamic>{},
  );

  /// 头像 / 文件上传（对齐 1.0 `fileUpload`）。
  Future<ApiResponse> uploadFile({
    required Uint8List bytes,
    required String filename,
  }) {
    return _client.postFormData(
      '/app/common/v2/fileUpload',
      data: FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
  }
}
