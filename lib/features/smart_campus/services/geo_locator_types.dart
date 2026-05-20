/// 一次定位的结果。坐标系为 WGS-84（浏览器/GPS 原始坐标）。
///
/// 渲染到百度地图时需要先用 `BMap.Convertor`（COORDINATES_WGS84 → BD-09）
/// 转换，否则会出现 100~500m 的偏差。该转换在 `web/baidu_map.html` 内部
/// 完成，Flutter 层只需把 WGS-84 原值通过 URL 参数透传即可。
class GeoPosition {
  const GeoPosition({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double lat;
  final double lng;

  /// 该次定位的精度（米）。桌面端无 GPS 时通常 500~5000m，移动端有 GPS
  /// 时可低至 10m 以内。
  final double accuracyMeters;
  final DateTime timestamp;

  @override
  String toString() =>
      'GeoPosition(lat=$lat, lng=$lng, accuracy=${accuracyMeters.toStringAsFixed(1)}m)';
}

/// 定位失败原因。
enum GeoErrorKind {
  /// 当前平台/浏览器不支持 geolocation。
  unsupported,

  /// 用户拒绝了位置权限。
  permissionDenied,

  /// 设备未能取得位置（无 GPS、室内、网络异常等）。
  positionUnavailable,

  /// 获取超时。
  timeout,

  /// 其它未知错误。
  unknown,
}

class GeoException implements Exception {
  const GeoException(this.kind, [this.message]);
  final GeoErrorKind kind;
  final String? message;

  String get userMessage {
    switch (kind) {
      case GeoErrorKind.unsupported:
        return '当前环境不支持获取定位';
      case GeoErrorKind.permissionDenied:
        return '已拒绝定位权限，请在浏览器地址栏左侧开启';
      case GeoErrorKind.positionUnavailable:
        return '暂时无法获取位置，请检查网络与定位是否开启';
      case GeoErrorKind.timeout:
        return '获取定位超时，请重试';
      case GeoErrorKind.unknown:
        return message ?? '获取定位失败';
    }
  }

  @override
  String toString() => 'GeoException($kind, $message)';
}
