import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SeamlessBannerCarousel extends StatefulWidget {
  const SeamlessBannerCarousel({
    super.key,
    required this.imageUrls,
    required this.placeholder,
    this.empty,
    this.fit = BoxFit.cover,
    this.autoPlay = true,
    this.interval = const Duration(seconds: 4),
    this.animationDuration = const Duration(milliseconds: 360),
    this.animationCurve = Curves.easeOutCubic,
    this.onPageChanged,
  });

  final List<String> imageUrls;
  final Widget placeholder;
  final Widget? empty;
  final BoxFit fit;
  final bool autoPlay;
  final Duration interval;
  final Duration animationDuration;
  final Curve animationCurve;
  final ValueChanged<int>? onPageChanged;

  @override
  State<SeamlessBannerCarousel> createState() => _SeamlessBannerCarouselState();
}

class _SeamlessBannerCarouselState extends State<SeamlessBannerCarousel> {
  static const int _initialPageSeed = 10000;

  late PageController _controller;
  Timer? _timer;
  List<_BannerSlideData> _slides = const <_BannerSlideData>[];
  List<String> _pendingUrls = const <String>[];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendingUrls.isEmpty && _slides.isEmpty) {
      _syncImages(force: true);
    }
  }

  @override
  void didUpdateWidget(covariant SeamlessBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.imageUrls, widget.imageUrls) ||
        oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.interval != widget.interval) {
      _syncImages(force: !listEquals(oldWidget.imageUrls, widget.imageUrls));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncImages({required bool force}) {
    final urls = widget.imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    if (!force && listEquals(urls, _pendingUrls)) {
      _restartTimer();
      return;
    }

    _timer?.cancel();
    _pendingUrls = urls;
    if (urls.isEmpty) {
      setState(() {
        _slides = const <_BannerSlideData>[];
      });
      _notifyPageChanged(0);
      return;
    }

    final slides = urls
        .map(
          (url) => _BannerSlideData(url: url, provider: _imageProviderFor(url)),
        )
        .toList(growable: false);
    final page = _initialPageFor(slides.length);
    final oldController = _controller;
    _controller = PageController(initialPage: page);
    _currentPage = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
    });
    setState(() {
      _slides = slides;
    });
    _notifyPageChanged(0);
    _restartTimer();
  }

  void _notifyPageChanged(int index) {
    final callback = widget.onPageChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(index);
    });
  }

  ImageProvider _imageProviderFor(String url) {
    if (url.startsWith('http')) {
      return CachedNetworkImageProvider(url);
    }
    return AssetImage(url);
  }

  int _initialPageFor(int count) {
    if (count <= 1) return 0;
    return _initialPageSeed - (_initialPageSeed % count);
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!widget.autoPlay || _slides.length <= 1) {
      return;
    }
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients || _slides.length <= 1) {
        return;
      }
      final nextPage = (_controller.page?.round() ?? _currentPage) + 1;
      _currentPage = nextPage;
      _controller.animateToPage(
        nextPage,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingUrls.isEmpty) {
      return widget.empty ?? widget.placeholder;
    }
    if (_slides.isEmpty) {
      return widget.placeholder;
    }
    if (_slides.length == 1) {
      return _BannerImage(slide: _slides.single, fit: widget.fit);
    }

    return PageView.builder(
      controller: _controller,
      allowImplicitScrolling: true,
      physics: const ClampingScrollPhysics(),
      onPageChanged: (page) {
        _currentPage = page;
        _notifyPageChanged(page % _slides.length);
      },
      itemBuilder: (context, page) {
        final slide = _slides[page % _slides.length];
        return _BannerImage(slide: slide, fit: widget.fit);
      },
    );
  }
}

class _BannerSlideData {
  const _BannerSlideData({required this.url, required this.provider});

  final String url;
  final ImageProvider provider;
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.slide, required this.fit});

  final _BannerSlideData slide;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final imageProvider = ResizeImage.resizeIfNeeded(
          _cacheExtent(constraints.maxWidth, dpr, 1800),
          _cacheExtent(constraints.maxHeight, dpr, 1000),
          slide.provider,
        );
        return Image(
          image: imageProvider,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: Color(0xFFF5F6FA)),
        );
      },
    );
  }
}

int? _cacheExtent(
  double logicalExtent,
  double devicePixelRatio,
  int maxPixels,
) {
  if (!logicalExtent.isFinite || logicalExtent <= 0) {
    return maxPixels;
  }
  return (logicalExtent * devicePixelRatio).ceil().clamp(1, maxPixels).toInt();
}
