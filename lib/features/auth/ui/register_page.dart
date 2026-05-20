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

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthScene.register));
    final controller = ref.read(
      authControllerProvider(AuthScene.register).notifier,
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
              top: _s(scale, 163),
              width: _s(scale, 399),
              height: _s(scale, 494),
              child: AuthFigmaCardFrame(
                scale: scale,
                title: '账号注册',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
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
                          width: 20,
                          height: 20,
                          leftPadding: 12,
                        ),
                        onChanged: controller.setMobile,
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 17),
                      top: _s(scale, 166),
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
                      top: _s(scale, 166),
                      width: _s(scale, 117),
                      height: _s(scale, 45),
                      child: AuthFigmaSmsButton(
                        scale: scale,
                        text: state.isSendingSms
                            ? '重新获取(${state.smsCountDown})'
                            : '获取验证码',
                        enabled: !state.isSendingSms,
                        onTap: () => _onSendSms(context, controller),
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 17),
                      top: _s(scale, 232),
                      width: _s(scale, 365),
                      height: _s(scale, 45),
                      child: AuthFigmaInputField(
                        scale: scale,
                        hintText: '请输入密码',
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
                      left: _s(scale, 312),
                      top: _s(scale, 288),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.pushNamed(context, RoutePaths.forget),
                        child: Text(
                          '忘记密码？',
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
                    ),
                    Positioned(
                      left: _s(scale, 20),
                      top: _s(scale, 323.01),
                      width: _s(scale, 365),
                      height: _s(scale, 45),
                      child: AuthFigmaPrimaryButton(
                        scale: scale,
                        text: '立即注册',
                        loading: state.isSubmitting,
                        onPressed: () =>
                            _onRegister(context, controller, state.agreeTerms),
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 92),
                      top: _s(scale, 398.01),
                      child: AuthFigmaAgreementRow(
                        scale: scale,
                        checked: state.agreeTerms,
                        onChanged: controller.setAgreeTerms,
                        onAgreementTap: () =>
                            Navigator.pushNamed(context, RoutePaths.xieyi2),
                      ),
                    ),
                    Positioned(
                      top: _s(scale, 449),
                      left: _s(scale, 126),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '已有账号？',
                            style: TextStyle(
                              color: const Color(0xFF0B081A),
                              fontSize: _s(scale, 14),
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: const ['Harmony'],
                              fontWeight: AppFont.w400,
                              height: 12 / 14,
                            ),
                          ),
                          SizedBox(width: _s(scale, 4)),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              RoutePaths.login,
                            ),
                            child: Text(
                              '立即登录！',
                              style: TextStyle(
                                color: const Color(0xFF8741FF),
                                fontSize: _s(scale, 14),
                                fontFamily: 'PingFang SC',
                                fontFamilyFallback: const ['Harmony'],
                                fontWeight: AppFont.w400,
                                height: 12 / 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _onRegister(
    BuildContext context,
    AuthController controller,
    bool agreeTerms,
  ) async {
    if (!agreeTerms) {
      _showMessage(context, '请先同意服务协议');
      return;
    }

    final result = await controller.submitRegister();
    if (!context.mounted) {
      return;
    }

    _showMessage(context, result.message);
    if (result.success) {
      Navigator.pushReplacementNamed(context, RoutePaths.login);
    }
  }

  void _showMessage(BuildContext context, String message) {
    AppToast.show(context, message);
  }

  static double _s(double scale, double value) => value * scale;
}
