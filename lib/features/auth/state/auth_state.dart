enum AuthScene { login, register, forgetPassword }

class AuthState {
  const AuthState({
    this.mobile = '',
    this.password = '',
    this.smsCode = '',
    this.isSubmitting = false,
    this.isSendingSms = false,
    this.smsCountDown = 0,
    this.agreeTerms = true,
  });

  final String mobile;
  final String password;
  final String smsCode;
  final bool isSubmitting;
  final bool isSendingSms;
  final int smsCountDown;
  final bool agreeTerms;

  String get smsButtonText => smsCountDown > 0 ? '$smsCountDown秒后重发' : '获取验证码';

  AuthState copyWith({
    String? mobile,
    String? password,
    String? smsCode,
    bool? isSubmitting,
    bool? isSendingSms,
    int? smsCountDown,
    bool? agreeTerms,
  }) {
    return AuthState(
      mobile: mobile ?? this.mobile,
      password: password ?? this.password,
      smsCode: smsCode ?? this.smsCode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSendingSms: isSendingSms ?? this.isSendingSms,
      smsCountDown: smsCountDown ?? this.smsCountDown,
      agreeTerms: agreeTerms ?? this.agreeTerms,
    );
  }
}

class AuthActionResult {
  const AuthActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}
