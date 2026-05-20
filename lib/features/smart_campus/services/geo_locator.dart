// 通用浏览器/原生定位服务入口（基于 `navigator.geolocation` API）。
//
// Web 端真正调用浏览器 geolocation；非 web 平台目前返回 `null` 占位，
// 后续接入原生 SDK（Android/iOS）时只需替换 io 实现即可。
//
// 共用的 `GeoPosition / GeoException` 类型在 `geo_locator_types.dart`；
// 平台特定的 `getCurrentLocation()` 函数通过条件导入选择实现。
export 'geo_locator_types.dart';
export 'geo_locator_io.dart' if (dart.library.html) 'geo_locator_web.dart';
