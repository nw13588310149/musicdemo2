import 'package:flutter/material.dart';

/// 非 web 平台占位：显示一块浅灰底 + 提示文本，告诉用户当前端尚未接入
/// 原生百度地图 SDK。
class BaiduMapView extends StatelessWidget {
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

  /// Web 端 baidu_map.html 反编码地址成功后会通过 `postMessage` 回传，
  /// 本回调透传给上层；原生占位用不到，保留只是签名一致。
  final ValueChanged<String>? onAddressResolved;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '当前平台暂未接入原生百度地图 SDK',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB6B5BB), fontSize: 13),
        ),
      ),
    );
  }
}
