import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'geo_locator_types.dart';

/// Web 实现：调用浏览器 `navigator.geolocation.getCurrentPosition` 获取
/// **WGS-84** 坐标 + 精度。
///
/// - 浏览器首次会弹权限提示，用户必须点击「允许」。
/// - 桌面端无 GPS 时通常返回 IP 级别精度（~500-5000m）；手机端 WiFi+GPS 下
///   可达 10-30m 内。
/// - `timeout` 默认 10s；过短会经常 `timeout`，过长会卡住"获取定位"按钮，
///   10s 是平衡值。
Future<GeoPosition> getCurrentLocation({
  Duration? timeout,
}) {
  final completer = Completer<GeoPosition>();
  final geolocation = web.window.navigator.geolocation;

  final t = (timeout ?? const Duration(seconds: 10)).inMilliseconds;

  void onSuccess(web.GeolocationPosition pos) {
    if (completer.isCompleted) return;
    completer.complete(
      GeoPosition(
        lat: pos.coords.latitude.toDouble(),
        lng: pos.coords.longitude.toDouble(),
        accuracyMeters: pos.coords.accuracy.toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(pos.timestamp.toInt()),
      ),
    );
  }

  void onError(web.GeolocationPositionError err) {
    if (completer.isCompleted) return;
    GeoErrorKind kind;
    switch (err.code) {
      case 1: // PERMISSION_DENIED
        kind = GeoErrorKind.permissionDenied;
        break;
      case 2: // POSITION_UNAVAILABLE
        kind = GeoErrorKind.positionUnavailable;
        break;
      case 3: // TIMEOUT
        kind = GeoErrorKind.timeout;
        break;
      default:
        kind = GeoErrorKind.unknown;
    }
    completer.completeError(GeoException(kind, err.message));
  }

  try {
    geolocation.getCurrentPosition(
      onSuccess.toJS,
      onError.toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: t,
        maximumAge: 0,
      ),
    );
  } catch (e) {
    completer.completeError(
      GeoException(GeoErrorKind.unsupported, e.toString()),
    );
  }
  return completer.future;
}
