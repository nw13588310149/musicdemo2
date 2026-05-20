import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import 'widgets/auth_background_art.dart';
import 'widgets/auth_design_canvas.dart';
import 'widgets/auth_figma_components.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

enum _ForgetStep { mobile, sms, password }

class ForgetPasswordPage extends ConsumerStatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  ConsumerState<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends ConsumerState<ForgetPasswordPage> {
  static final _mobileReg = RegExp(r'^\d{11}$');

  _ForgetStep _step = _ForgetStep.mobile;
  String _confirmPassword = '';
  String _maskedMobile = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthScene.forgetPassword));
    final controller = ref.read(
      authControllerProvider(AuthScene.forgetPassword).notifier,
    );

    return Scaffold(
      // 与登录页同理：键盘弹出时不要让 Scaffold 压缩 body 触发 canvas 重缩放。
      resizeToAvoidBottomInset: false,
      body: AuthDesignCanvas(
        builder: (scale) => Stack(
          clipBehavior: Clip.none,
          children: [
            AuthBackgroundArt(scale: scale),
            Positioned(
              left: _s(scale, 691),
              top: _s(scale, 194),
              width: _s(scale, 399),
              height: _s(scale, _cardHeight),
              child: AuthFigmaCardFrame(
                scale: scale,
                title: '找回密码',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...switch (_step) {
                      _ForgetStep.mobile => _buildMobileStep(
                        context,
                        scale,
                        state,
                        controller,
                      ),
                      _ForgetStep.sms => _buildSmsStep(
                        context,
                        scale,
                        state,
                        controller,
                      ),
                      _ForgetStep.password => _buildPasswordStep(
                        context,
                        scale,
                        state,
                        controller,
                      ),
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMobileStep(
    BuildContext context,
    double scale,
    AuthState state,
    AuthController controller,
  ) {
    return [
      Positioned(
        left: _s(scale, 17),
        top: _s(scale, 100),
        width: _s(scale, 365),
        height: _s(scale, 45),
        child: AuthFigmaInputField(
          scale: scale,
          hintText: '请输入手机号',
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          prefixIcon: AuthImageIcon(
            scale: scale,
            asset: AppAssets.figmaAuthIconPhoneSmall,
            width: 18,
            height: 18,
            leftPadding: 13,
          ),
          onChanged: controller.setMobile,
        ),
      ),
      Positioned(
        left: _s(scale, 20),
        top: _s(scale, 163),
        width: _s(scale, 365),
        height: _s(scale, 45),
        child: AuthFigmaPrimaryButton(
          scale: scale,
          text: '下一步',
          loading: state.isSubmitting,
          onPressed: () => _onPrimaryTap(context, state, controller),
          fontFamily: 'PingFang SC',
        ),
      ),
    ];
  }

  List<Widget> _buildSmsStep(
    BuildContext context,
    double scale,
    AuthState state,
    AuthController controller,
  ) {
    return [
      Positioned(
        left: _s(scale, 20),
        top: _s(scale, 101),
        width: _s(scale, 345),
        child: Text(
          '若您的手机号 $_maskedMobile 可接收短信，请点击获取验证码。',
          style: TextStyle(
            color: const Color(0xFFB6B5BB),
            fontSize: _s(scale, 14),
            fontFamily: 'PingFang SC',
            fontFamilyFallback: const ['Harmony'],
            fontWeight: AppFont.w400,
            height: 12 / 14,
          ),
        ),
      ),
      Positioned(
        left: _s(scale, 20),
        top: _s(scale, 138),
        width: _s(scale, 240),
        height: _s(scale, 45),
        child: AuthFigmaInputField(
          scale: scale,
          hintText: '请输入短信验证码',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          prefixIcon: AuthImageIcon(
            scale: scale,
            asset: AppAssets.figmaAuthIconSmsSmall,
            width: 18,
            height: 18,
            leftPadding: 13,
          ),
          onChanged: controller.setSmsCode,
        ),
      ),
      Positioned(
        left: _s(scale, 265),
        top: _s(scale, 138),
        width: _s(scale, 117),
        height: _s(scale, 45),
        child: AuthFigmaSmsButton(
          scale: scale,
          text: state.isSendingSms ? '重新获取(${state.smsCountDown})' : '获取验证码',
          enabled: !state.isSendingSms,
          onTap: () => _onSendSms(context, controller),
        ),
      ),
      Positioned(
        left: _s(scale, 20),
        top: _s(scale, 210),
        width: _s(scale, 365),
        height: _s(scale, 45),
        child: AuthFigmaPrimaryButton(
          scale: scale,
          text: '下一步',
          loading: state.isSubmitting,
          onPressed: () => _onPrimaryTap(context, state, controller),
          fontFamily: 'PingFang SC',
        ),
      ),
    ];
  }

  List<Widget> _buildPasswordStep(
    BuildContext context,
    double scale,
    AuthState state,
    AuthController controller,
  ) {
    return [
      Positioned(
        left: _s(scale, 20),
        top: _s(scale, 93),
        width: _s(scale, 365),
        height: _s(scale, 45),
        child: AuthFigmaInputField(
          scale: scale,
          hintText: '请输入新密码',
          obscureText: true,
          prefixIcon: AuthImageIcon(
            scale: scale,
            asset: AppAssets.figmaAuthIconPasswordSmall,
            width: 17,
            height: 17,
            leftPadding: 14,
          ),
          onChanged: controller.setPassword,
        ),
      ),
      Positioned(
        left: _s(scale, 20),
        top: _s(scale, 159),
        width: _s(scale, 365),
        height: _s(scale, 45),
        child: AuthFigmaInputField(
          scale: scale,
          hintText: '请确认密码',
          obscureText: true,
          prefixIcon: AuthImageIcon(
            scale: scale,
            asset: AppAssets.figmaAuthIconPasswordSmall,
            width: 17,
            height: 17,
            leftPadding: 14,
          ),
          onChanged: (value) => _confirmPassword = value,
        ),
      ),
      Positioned(
        left: _s(scale, 20),
        top: _s(scale, 231),
        width: _s(scale, 365),
        height: _s(scale, 45),
        child: AuthFigmaPrimaryButton(
          scale: scale,
          text: '确认修改',
          loading: state.isSubmitting,
          onPressed: () => _onPrimaryTap(context, state, controller),
          fontFamily: 'PingFang SC',
        ),
      ),
    ];
  }

  Future<void> _onPrimaryTap(
    BuildContext context,
    AuthState state,
    AuthController controller,
  ) async {
    switch (_step) {
      case _ForgetStep.mobile:
        if (state.mobile.isEmpty) {
          _showMessage(context, '请输入手机号');
          return;
        }
        if (!_mobileReg.hasMatch(state.mobile)) {
          _showMessage(context, '请输入11位手机号');
          return;
        }
        setState(() {
          _step = _ForgetStep.sms;
          _maskedMobile = _maskMobile(state.mobile);
        });
        return;
      case _ForgetStep.sms:
        if (state.smsCode.isEmpty) {
          _showMessage(context, '请输入短信验证码');
          return;
        }
        setState(() {
          _step = _ForgetStep.password;
        });
        return;
      case _ForgetStep.password:
        if (state.password.isEmpty || _confirmPassword.isEmpty) {
          _showMessage(context, '请输入并确认新密码');
          return;
        }
        if (state.password.length < 6) {
          _showMessage(context, '密码不少于6位');
          return;
        }
        if (state.password != _confirmPassword) {
          _showMessage(context, '两次输入的密码不一致');
          return;
        }
        final result = await controller.submitForgetPassword();
        if (!context.mounted) {
          return;
        }
        _showMessage(context, result.message);
        if (result.success) {
          Navigator.pushReplacementNamed(context, RoutePaths.login);
        }
        return;
    }
  }

  Future<void> _onSendSms(
    BuildContext context,
    AuthController controller,
  ) async {
    final result = await controller.sendSms();
    if (!context.mounted) {
      return;
    }
    _showMessage(context, result.message);
  }

  String _maskMobile(String mobile) {
    if (mobile.length < 8) {
      return mobile;
    }
    return '${mobile.substring(0, 3)}******${mobile.substring(mobile.length - 2)}';
  }

  double get _cardHeight {
    switch (_step) {
      case _ForgetStep.mobile:
        return 232;
      case _ForgetStep.sms:
        return 286;
      case _ForgetStep.password:
        return 307;
    }
  }

  void _showMessage(BuildContext context, String message) {
    AppToast.show(context, message);
  }

  static double _s(double scale, double value) => value * scale;
}
