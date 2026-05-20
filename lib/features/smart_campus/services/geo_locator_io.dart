import 'geo_locator_types.dart';

/// 非 web 平台占位实现：直接抛出 `unsupported`。
///
/// 后续若接入原生 SDK（Android/iOS Baidu Mobile SDK，或 `geolocator` 插件），
/// 把本文件改成实际 native 调用即可，调用方无需感知。
Future<GeoPosition> getCurrentLocation({Duration? timeout}) async {
  throw const GeoException(
    GeoErrorKind.unsupported,
    '当前平台暂未接入原生定位',
  );
}
