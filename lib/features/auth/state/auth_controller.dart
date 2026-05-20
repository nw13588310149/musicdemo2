import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_repository.dart';
import '../../../core/network/api_unauthorized_handler.dart';
import '../../../core/network/chat_socket_service.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider.autoDispose
    .family<AuthController, AuthState, AuthScene>((ref, scene) {
      final repository = ref.watch(authRepositoryProvider);
      final appConfigRepository = ref.watch(appConfigRepositoryProvider);
      final chatSocket = ref.read(chatSocketServiceProvider);
      return AuthController(
        repository: repository,
        appConfigRepository: appConfigRepository,
        chatSocket: chatSocket,
        scene: scene,
      );
    });

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository repository,
    required AppConfigRepository appConfigRepository,
    required ChatSocketService chatSocket,
    required this.scene,
  }) : _repository = repository,
       _appConfigRepository = appConfigRepository,
       _chatSocket = chatSocket,
       super(const AuthState());

  final AuthRepository _repository;
  final AppConfigRepository _appConfigRepository;
  final ChatSocketService _chatSocket;
  final AuthScene scene;

  Timer? _timer;

  static final _mobileReg = RegExp(r'^\d{11}$');

  void setMobile(String value) {
    state = state.copyWith(mobile: value.trim());
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void setSmsCode(String value) {
    state = state.copyWith(smsCode: value.trim());
  }

  void setAgreeTerms(bool value) {
    state = state.copyWith(agreeTerms: value);
  }

  Future<AuthActionResult> sendSms() async {
    if (state.mobile.isEmpty) {
      return const AuthActionResult(success: false, message: '请输入手机号');
    }
    if (!_mobileReg.hasMatch(state.mobile)) {
      return const AuthActionResult(success: false, message: '请输入11位手机号');
    }
    if (state.isSendingSms) {
      return const AuthActionResult(success: false, message: '验证码已发送，请稍后重试');
    }

    final smsType = scene == AuthScene.forgetPassword ? 1 : 0;
    final response = await _repository.sendSms(
      mobile: state.mobile,
      type: smsType,
    );

    final success = _isSendSmsSuccess(response.code);
    if (!success) {
      return AuthActionResult(
        success: false,
        message: response.msg.isEmpty ? '验证码发送失败，请稍后再试' : response.msg,
      );
    }

    _startCountdown();
    return const AuthActionResult(success: true, message: '验证码已发送');
  }

  Future<AuthActionResult> submitLogin() async {
    if (state.mobile.isEmpty || state.password.isEmpty) {
      return const AuthActionResult(success: false, message: '请输入手机号和密码');
    }
    if (!_mobileReg.hasMatch(state.mobile)) {
      return const AuthActionResult(success: false, message: '请输入11位手机号');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      final checkFuture = _syncCheckStatus().catchError((_) {});

      final response = await _repository.login(
        mobile: state.mobile,
        password: state.password,
      );
      if (response.code != 0) {
        return AuthActionResult(
          success: false,
          message: response.msg.isEmpty ? '登录失败，请检查账号或密码' : response.msg,
        );
      }

      final token = _extractToken(response.data);
      if (token.isNotEmpty) {
        await _repository.persistToken(token);
      }
      // 持久化当前手机号，供 ShellController 在 refreshUserAndSchool 时
      // 判定白名单管理员（如 13588310149）是否覆盖 user.role 为 admin。
      await _repository.persistMobile(state.mobile);

      await checkFuture;
      unawaited(_reportCidIfNeeded());
      unawaited(_appConfigRepository.refreshFileBaseUrl());
      // 登录成功后用新 token 重新建立 WS 长连接，承担 AI / 系统 / 群聊消息推送。
      _chatSocket.reconnect();
      ApiUnauthorizedHandler.instance.reset();

      return const AuthActionResult(success: true, message: '登录成功');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<AuthActionResult> submitGuestLogin() async {
    await _repository.persistToken('youke');
    unawaited(_appConfigRepository.refreshFileBaseUrl());
    // 游客 token 也尝试连一次 WS，至少能收到系统级被踢 / 升级提示等下行事件。
    _chatSocket.reconnect();
    ApiUnauthorizedHandler.instance.reset();
    return const AuthActionResult(success: true, message: '已进入游客模式');
  }

  Future<AuthActionResult> submitRegister() async {
    if (state.mobile.isEmpty ||
        state.password.isEmpty ||
        state.smsCode.isEmpty) {
      return const AuthActionResult(success: false, message: '请完整填写注册信息');
    }
    if (!_mobileReg.hasMatch(state.mobile)) {
      return const AuthActionResult(success: false, message: '请输入11位手机号');
    }
    if (state.password.length < 6) {
      return const AuthActionResult(success: false, message: '密码不少于6位');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      final response = await _repository.register(
        mobile: state.mobile,
        password: state.password,
        smsCode: state.smsCode,
      );

      if (response.code != 0) {
        return AuthActionResult(
          success: false,
          message: response.msg.isEmpty ? '注册失败，请稍后重试' : response.msg,
        );
      }

      final token = _extractToken(response.data);
      if (token.isNotEmpty) {
        await _repository.persistToken(token);
      }
      // 注册成功也走自动登录流程，记下手机号供白名单管理员判定。
      await _repository.persistMobile(state.mobile);

      unawaited(_appConfigRepository.refreshFileBaseUrl());
      unawaited(_reportCidIfNeeded());
      _chatSocket.reconnect();

      return const AuthActionResult(success: true, message: '注册成功');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<AuthActionResult> submitForgetPassword() async {
    if (state.mobile.isEmpty ||
        state.password.isEmpty ||
        state.smsCode.isEmpty) {
      return const AuthActionResult(success: false, message: '请完整填写找回信息');
    }
    if (!_mobileReg.hasMatch(state.mobile)) {
      return const AuthActionResult(success: false, message: '请输入11位手机号');
    }
    if (state.password.length < 6) {
      return const AuthActionResult(success: false, message: '密码不少于6位');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      final response = await _repository.resetPassword(
        mobile: state.mobile,
        password: state.password,
        smsCode: state.smsCode,
      );

      if (response.code != 0) {
        return AuthActionResult(
          success: false,
          message: response.msg.isEmpty ? '重置失败，请稍后再试' : response.msg,
        );
      }

      return const AuthActionResult(success: true, message: '密码重置成功');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    state = state.copyWith(isSendingSms: true, smsCountDown: 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.smsCountDown - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(smsCountDown: 0, isSendingSms: false);
        return;
      }
      state = state.copyWith(smsCountDown: next);
    });
  }

  String _extractToken(dynamic data) {
    if (data is Map<String, dynamic>) {
      final token = data['token'];
      if (token != null) {
        return token.toString();
      }
    }
    return '';
  }

  bool _isSendSmsSuccess(int code) {
    if (scene == AuthScene.register) {
      return code == 200 || code == 0;
    }
    return code == 0 || code == 200;
  }

  Future<void> _syncCheckStatus() async {
    final checkResponse = await _repository.getCheck();
    if (checkResponse.code == 0) {
      await _repository.saveCheckStatus(checkResponse.data);
    }
  }

  Future<void> _reportCidIfNeeded() async {
    final pushId = _repository.pushId;
    if (pushId.isEmpty) {
      return;
    }
    await _repository.reportCid(pushId);
  }
}
