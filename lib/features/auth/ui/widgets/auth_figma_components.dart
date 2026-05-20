import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class AuthFigmaCardFrame extends StatelessWidget {
  const AuthFigmaCardFrame({
    required this.scale,
    required this.title,
    required this.child,
    super.key,
  });

  final double scale;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_s(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _s(10), sigmaY: _s(10)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_s(24)),
            border: Border.all(color: Colors.white, width: _s(2)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD8CCFF), Colors.white, Colors.white],
              stops: [0, 0.25, 1],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _s(158),
                top: _s(2),
                width: _s(239),
                height: _s(136),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_s(14)),
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, Color(0xFF5E5E5E)],
                      ).createShader(bounds);
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: -_s(19),
                          width: _s(288),
                          height: _s(164),
                          child: IgnorePointer(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  AppAssets.figmaLoginCardLayer1,
                                  fit: BoxFit.cover,
                                ),
                                Image.asset(
                                  AppAssets.figmaLoginCardLayer2,
                                  fit: BoxFit.cover,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _s(178),
                top: _s(104),
                width: _s(241),
                height: _s(68),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_s(14)),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: _s(9.15),
                      sigmaY: _s(9.15),
                    ),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: _s(152),
                top: _s(33),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF0B081A), Color(0xFF8670E2)],
                    ).createShader(bounds);
                  },
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _s(24),
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: const ['Harmony'],
                      fontWeight: AppFont.w600,
                      height: 36 / 24,
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }

  double _s(double value) => value * scale;
}

class AuthFigmaInputField extends StatelessWidget {
  const AuthFigmaInputField({
    required this.scale,
    required this.hintText,
    required this.onChanged,
    required this.prefixIcon,
    super.key,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.inputFormatters,
  });

  final double scale;
  final String hintText;
  final ValueChanged<String> onChanged;
  final Widget prefixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      inputFormatters: inputFormatters,
      cursorColor: const Color(0xFF8741FF),
      cursorHeight: _s(16),
      style: TextStyle(
        color: const Color(0xFF0B081A),
        fontSize: _s(14),
        fontFamily: 'PingFang SC',
        fontFamilyFallback: const ['Harmony'],
        fontWeight: AppFont.w400,
        height: 12 / 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: TextStyle(
          color: const Color(0xFFB6B5BB),
          fontSize: _s(14),
          fontFamily: 'PingFang SC',
          fontFamilyFallback: const ['Harmony'],
          fontWeight: AppFont.w400,
          height: 12 / 14,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.fromLTRB(_s(0), _s(17), _s(14), _s(16)),
        prefixIconConstraints: BoxConstraints(
          minWidth: _s(42),
          maxWidth: _s(42),
          minHeight: _s(45),
          maxHeight: _s(45),
        ),
        prefixIcon: SizedBox(
          width: _s(42),
          height: _s(45),
          child: Align(alignment: Alignment.centerLeft, child: prefixIcon),
        ),
        border: _border,
        enabledBorder: _border,
        focusedBorder: _border,
      ),
      onChanged: onChanged,
    );
  }

  OutlineInputBorder get _border => OutlineInputBorder(
    borderRadius: BorderRadius.circular(_s(12)),
    borderSide: BorderSide(color: const Color(0xFFF3F2F3), width: _s(1)),
  );

  double _s(double value) => value * scale;
}

class AuthSvgIcon extends StatelessWidget {
  const AuthSvgIcon({
    required this.scale,
    required this.asset,
    super.key,
    this.width = 24,
    this.height = 24,
    this.leftPadding = 12,
  });

  final double scale;
  final String asset;
  final double width;
  final double height;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding * scale),
      child: SvgPicture.asset(
        asset,
        width: width * scale,
        height: height * scale,
        fit: BoxFit.contain,
      ),
    );
  }
}

class AuthImageIcon extends StatelessWidget {
  const AuthImageIcon({
    required this.scale,
    required this.asset,
    required this.width,
    required this.height,
    required this.leftPadding,
    super.key,
  });

  final double scale;
  final String asset;
  final double width;
  final double height;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding * scale),
      child: Image.asset(
        asset,
        width: width * scale,
        height: height * scale,
        fit: BoxFit.contain,
      ),
    );
  }
}

class AuthFigmaPrimaryButton extends StatelessWidget {
  const AuthFigmaPrimaryButton({
    required this.scale,
    required this.text,
    required this.loading,
    required this.onPressed,
    super.key,
    this.fontFamily = 'Inter',
  });

  final double scale;
  final String text;
  final bool loading;
  final VoidCallback onPressed;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_s(12)),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF8640FF), Color(0xFFB68EFF)],
        ),
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_s(12)),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                width: _s(16),
                height: _s(16),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _s(14),
                  fontFamily: fontFamily,
                  fontFamilyFallback: const ['Harmony'],
                  fontWeight: FontWeight.w400,
                  height: 12 / 14,
                ),
              ),
      ),
    );
  }

  double _s(double value) => value * scale;
}

class AuthFigmaSmsButton extends StatelessWidget {
  const AuthFigmaSmsButton({
    required this.scale,
    required this.text,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final double scale;
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled
        ? const Color(0xFF0D1535)
        : const Color(0xFF0D1535).withValues(alpha: 0.4);
    final foregroundColor = enabled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.4);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_s(12)),
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_s(12)),
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foregroundColor,
            fontSize: _s(14),
            fontFamily: 'PingFang SC',
            fontFamilyFallback: const ['Harmony'],
            fontWeight: AppFont.w400,
            height: 12 / 14,
          ),
        ),
      ),
    );
  }

  double _s(double value) => value * scale;
}

class AuthFigmaAgreementRow extends StatelessWidget {
  const AuthFigmaAgreementRow({
    required this.scale,
    required this.checked,
    required this.onChanged,
    required this.onAgreementTap,
    super.key,
  });

  final double scale;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onAgreementTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _s(14),
          height: _s(14),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!checked),
            child: Center(
              child: checked
                  ? SvgPicture.asset(
                      AppAssets.figmaLoginCheckboxChecked,
                      width: _s(12),
                      height: _s(12),
                      fit: BoxFit.contain,
                    )
                  : Container(
                      width: _s(12),
                      height: _s(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_s(2)),
                        border: Border.all(
                          color: const Color(0xFF8741FF),
                          width: _s(1),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(width: _s(4)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!checked),
          child: Text(
            '同意并愿意遵守',
            style: TextStyle(
              color: Colors.black,
              fontSize: _s(14),
              fontFamily: 'PingFang SC',
              fontFamilyFallback: const ['Harmony'],
              fontWeight: AppFont.w400,
              height: 12 / 14,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            onChanged(!checked);
            onAgreementTap();
          },
          child: Text(
            '《音乐之路服务协议》',
            style: TextStyle(
              color: const Color(0xFF856FE2),
              fontSize: _s(14),
              fontFamily: 'PingFang SC',
              fontFamilyFallback: const ['Harmony'],
              fontWeight: AppFont.w400,
              height: 12 / 14,
            ),
          ),
        ),
      ],
    );
  }

  double _s(double value) => value * scale;
}
