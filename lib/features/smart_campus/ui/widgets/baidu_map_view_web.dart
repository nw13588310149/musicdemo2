import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web 端百度地图嵌入。原理：
///
/// 1. 注册一个唯一的 `viewType`，在工厂里创建 `<iframe>` 指向
///    `baidu_map.html?lat=XX&lng=YY&label=ZZ&zoom=NN`。
/// 2. iframe 内部由 `web/baidu_map.html` 处理 WGS-84 → BD-09 坐标转换、
///    地图渲染、Marker + 反编码地址。
/// 3. iframe 完成反编码后会 `window.parent.postMessage` 回传地址。
///    本 widget 监听 `window` 的 `message` 事件，回调 [onAddressResolved]。
///
/// 当 [lat] / [lng] 任一为空（首次加载 / 拒绝定位），iframe 仍会加载但显示
/// "暂无定位"占位。
class BaiduMapView extends StatefulWidget {
  const BaiduMapView({
    super.key,
    required this.lat,
    required this.lng,
    this.label,
    this.zoom = 17,
    this.onAddressResolved,
    this.borderRadius,
  });

  final double? lat;
  final double? lng;
  final String? label;
  final int zoom;
  final ValueChanged<String>? onAddressResolved;
  final BorderRadius? borderRadius;

  @override
  State<BaiduMapView> createState() => _BaiduMapViewState();
}

class _BaiduMapViewState extends State<BaiduMapView> {
  static int _seq = 0;
  late String _viewType;
  JSFunction? _messageListener;

  @override
  void initState() {
    super.initState();
    _registerView();
    _installMessageListener();
  }

  @override
  void didUpdateWidget(covariant BaiduMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat ||
        oldWidget.lng != widget.lng ||
        oldWidget.label != widget.label ||
        oldWidget.zoom != widget.zoom) {
      setState(_registerView);
    }
  }

  @override
  void dispose() {
    final l = _messageListener;
    if (l != null) {
      web.window.removeEventListener('message', l);
      _messageListener = null;
    }
    super.dispose();
  }

  void _installMessageListener() {
    void onMessage(web.MessageEvent ev) {
      final data = ev.data?.dartify();
      if (data is! Map) return;
      if (data['source'] != 'baidu_map') return;
      if (data['type'] != 'address') return;
      final address = data['address'];
      if (address is String && address.isNotEmpty) {
        widget.onAddressResolved?.call(address);
      }
    }

    final js = onMessage.toJS;
    _messageListener = js;
    web.window.addEventListener('message', js);
  }

  void _registerView() {
    _viewType = 'baidu-map-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final src = _buildSrc();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..allowFullscreen = false
        ..allow = 'geolocation'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#EFF3FC';
      return iframe;
    });
  }

  String _buildSrc() {
    final base = 'baidu_map.html';
    final lat = widget.lat;
    final lng = widget.lng;
    final params = <String, String>{
      if (lat != null && lat.isFinite) 'lat': lat.toString(),
      if (lng != null && lng.isFinite) 'lng': lng.toString(),
      if (widget.label != null && widget.label!.isNotEmpty)
        'label': widget.label!,
      'zoom': widget.zoom.toString(),
    };
    if (params.isEmpty) return base;
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$base?$query';
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius;
    final view = HtmlElementView(viewType: _viewType);
    if (radius == null) return view;
    return ClipRRect(borderRadius: radius, child: view);
  }
}
