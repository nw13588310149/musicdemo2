import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.child,
    required this.cardHeight,
    super.key,
  });

  final String title;
  final Widget child;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: const Color(0xFFF2ECFF),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              if (compact) {
                return Column(
                  children: [
                    Expanded(flex: 48, child: _AuthLeftArtwork(compact: true)),
                    Expanded(
                      flex: 52,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: _AuthCard(
                            title: title,
                            cardHeight: cardHeight,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 57, child: _AuthLeftArtwork(compact: false)),
                  Expanded(
                    flex: 43,
                    child: Align(
                      alignment: const Alignment(0.08, -0.08),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 66),
                        child: _AuthCard(
                          title: title,
                          cardHeight: cardHeight,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.cardHeight,
    required this.child,
  });

  final String title;
  final double cardHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 399,
          constraints: BoxConstraints(minHeight: cardHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD8CCFF), Colors.white, Colors.white],
              stops: [0, 0.25, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 19,
                right: 0,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.12,
                    child: Image.asset(
                      AppAssets.authV2Castle,
                      width: 239,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 46, 16, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 36 / 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B081A),
                      ),
                    ),
                    const SizedBox(height: 31),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthLeftArtwork extends StatelessWidget {
  const _AuthLeftArtwork({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final panelWidth = compact ? width * 0.92 : width * 0.83;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: compact ? height * 0.02 : height * 0.01,
              child: ClipPath(
                clipper: _AuthLeftClipper(),
                child: Container(
                  width: panelWidth,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7A34F1),
                        Color(0xFF8E4AFF),
                        Color(0xFFD0B6FF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: compact ? width * 0.15 : width * 0.16,
              top: compact ? height * 0.25 : height * 0.205,
              child: const Icon(
                Icons.music_note_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
            Positioned(
              left: compact ? width * 0.37 : width * 0.38,
              top: compact ? -height * 0.02 : -height * 0.015,
              child: Transform.rotate(
                angle: -0.24,
                child: Image.asset(
                  AppAssets.authV2Piano,
                  width: compact ? width * 0.23 : width * 0.215,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: compact ? width * 0.16 : width * 0.16,
              top: compact ? height * 0.38 : height * 0.435,
              child: Transform.rotate(
                angle: -0.28,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 4.9, sigmaY: 4.9),
                  child: Image.asset(
                    AppAssets.authV2Mic,
                    width: compact ? width * 0.12 : width * 0.108,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              left: compact ? width * 0.16 : width * 0.17,
              top: compact ? height * 0.2 : height * 0.175,
              child: Transform.rotate(
                angle: 0.33,
                child: Image.asset(
                  AppAssets.authV2Castle,
                  width: compact ? width * 0.52 : width * 0.49,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuthLeftClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.79, 0)
      ..quadraticBezierTo(
        size.width * 1.03,
        size.height * 0.05,
        size.width * 0.9,
        size.height * 0.31,
      )
      ..lineTo(size.width * 0.84, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.87,
        size.width * 0.44,
        size.height * 0.98,
      )
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
