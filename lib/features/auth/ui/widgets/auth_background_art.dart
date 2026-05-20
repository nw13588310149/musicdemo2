import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';

class AuthBackgroundArt extends StatelessWidget {
  const AuthBackgroundArt({required this.scale, super.key});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: _s(537),
          height: _s(651),
          child: SvgPicture.asset(
            AppAssets.figmaLoginBgShape,
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          left: _s(222),
          top: _s(-9.65),
          width: _s(243.246),
          height: _s(234.108),
          child: Center(
            child: Transform.rotate(
              angle: -13.51 * math.pi / 180,
              alignment: Alignment.center,
              child: SizedBox(
                width: _s(204.104),
                height: _s(191.734),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _s(6.2),
                        sigmaY: _s(6.2),
                      ),
                      child: Image.asset(
                        AppAssets.figmaLoginPiano,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 0.5,
                      child: Image.asset(
                        AppAssets.figmaLoginPiano,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _s(282.33),
          top: _s(380.27),
          width: _s(276),
          height: _s(276),
          child: IgnorePointer(
            child: SvgPicture.asset(
              AppAssets.figmaLoginEllipseBig,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: _s(353.33),
          top: _s(464.27),
          width: _s(158),
          height: _s(158),
          child: IgnorePointer(
            child: SvgPicture.asset(
              AppAssets.figmaLoginEllipseSmall,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: _s(91),
          top: _s(133),
          width: _s(570.326),
          height: _s(553.691),
          child: Center(
            child: Transform.rotate(
              angle: 19.17 * math.pi / 180,
              alignment: Alignment.center,
              child: Image.asset(
                AppAssets.figmaLoginCastle,
                width: _s(455),
                height: _s(428),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          left: _s(486),
          top: _s(556),
          width: _s(34),
          height: _s(34),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFC89CB2).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(_s(17)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC89CB2).withValues(alpha: 0.55),
                    blurRadius: _s(15),
                    spreadRadius: _s(2),
                    offset: Offset(_s(2), _s(6)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: _s(72),
          top: _s(308),
          width: _s(150.477),
          height: _s(192.382),
          child: Center(
            child: Transform.rotate(
              angle: -16.45 * math.pi / 180,
              alignment: Alignment.center,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: _s(4.9), sigmaY: _s(4.9)),
                child: SizedBox(
                  width: _s(107),
                  height: _s(169),
                  child: Image.asset(
                    AppAssets.figmaLoginMic,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _s(130.87),
          top: _s(164.99),
          width: _s(97.637),
          height: _s(91.72),
          child: Transform.rotate(
            angle: 27.12 * math.pi / 180,
            alignment: Alignment.center,
            child: Image.asset(
              AppAssets.figmaLoginNoteLayer2,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  double _s(double value) => value * scale;
}
