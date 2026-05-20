import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../features/shell/state/school_binding_controller.dart';
import '../../../features/shell/state/shell_controller.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import 'widgets/auth_background_art.dart';
import 'widgets/auth_design_canvas.dart';
import 'widgets/auth_figma_components.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthScene.login));
    final controller = ref.read(
      authControllerProvider(AuthScene.login).notifier,
    );

    return Scaffold(
      // 关键：登录页布局是按设计稿固定比例 (1180x820) 缩放的，键盘弹出后
      // 不能让 Scaffold 压缩 body 高度（否则整页背景会跟着重新缩放）。
      // 实际"输入框跟随键盘上移"的需求，由系统在键盘上方留出焦点空间即可。
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
              height: _s(scale, 434),
              child: AuthFigmaCardFrame(
                scale: scale,
                title: '账号登录',
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
                        prefixIcon: AuthSvgIcon(
                          scale: scale,
                          asset: AppAssets.figmaLoginPhoneIcon,
                        ),
                        onChanged: controller.setMobile,
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 17),
                      top: _s(scale, 165),
                      width: _s(scale, 365),
                      height: _s(scale, 45),
                      child: AuthFigmaInputField(
                        scale: scale,
                        hintText: '请输入密码',
                        obscureText: true,
                        prefixIcon: AuthSvgIcon(
                          scale: scale,
                          asset: AppAssets.figmaLoginPasswordIcon,
                        ),
                        onChanged: controller.setPassword,
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 312),
                      top: _s(scale, 228),
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
                      top: _s(scale, 263.01),
                      width: _s(scale, 365),
                      height: _s(scale, 45),
                      child: AuthFigmaPrimaryButton(
                        scale: scale,
                        text: '立即登录',
                        loading: state.isSubmitting,
                        onPressed: () =>
                            _onLogin(context, controller, state.agreeTerms),
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 92),
                      top: _s(scale, 338.01),
                      child: AuthFigmaAgreementRow(
                        scale: scale,
                        checked: state.agreeTerms,
                        onChanged: controller.setAgreeTerms,
                        onAgreementTap: () =>
                            Navigator.pushNamed(context, RoutePaths.xieyi2),
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 17),
                      top: _s(scale, 395),
                      width: _s(scale, 100),
                      height: _s(scale, 1),
                      child: SvgPicture.asset(
                        AppAssets.figmaLoginDivider,
                        fit: BoxFit.fill,
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 282),
                      top: _s(scale, 395),
                      width: _s(scale, 100),
                      height: _s(scale, 1),
                      child: SvgPicture.asset(
                        AppAssets.figmaLoginDivider,
                        fit: BoxFit.fill,
                      ),
                    ),
                    Positioned(
                      left: _s(scale, 134),
                      top: _s(scale, 389),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '没有账号？',
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
                            onTap: () => Navigator.pushNamed(
                              context,
                              RoutePaths.register,
                            ),
                            child: Text(
                              '立即注册！',
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

  Future<void> _onLogin(
    BuildContext context,
    AuthController controller,
    bool agreeTerms,
  ) async {
    if (!agreeTerms) {
      _showMessage(context, '请先同意服务协议');
      return;
    }

    final result = await controller.submitLogin();
    if (!context.mounted) {
      return;
    }

    _showMessage(context, result.message);
    if (result.success) {
      // 登录成功后立即预热 ShellController（触发 myInfo/mySchool 并行请求），
      // 使菜单和头像在导航动画期间就已在飞，进入主框架时第一时间呈现。
      ref.read(shellControllerProvider.notifier).refreshUserAndSchool();
      // 同步触发「绑定学校」轮询：构造控制器即开始 5s 一次的 schoolList
      // 检查，未绑定时 ShellScaffold 进场即可弹出强制绑定遮罩。
      ref.read(schoolBindingControllerProvider.notifier).refresh();
      Navigator.pushReplacementNamed(context, RoutePaths.home);
    }
  }

  void _showMessage(BuildContext context, String message) {
    AppToast.show(context, message);
  }

  static double _s(double scale, double value) => value * scale;
}
