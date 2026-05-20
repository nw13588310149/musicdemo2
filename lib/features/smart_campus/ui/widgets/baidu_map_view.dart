// 百度地图嵌入 widget 入口。Web 端以 iframe 加载 `web/baidu_map.html`；
// 非 web 平台返回友好占位（后续可接入移动端原生 BMap SDK）。
//
// 用法：
// ```dart
// BaiduMapView(
//   lat: 39.9087,
//   lng: 116.3975,
//   label: '教学楼A区',
// )
// ```
//
// 配置：在 `web/baidu_map.html` 顶部替换 `__BAIDU_MAP_AK__` 为你在
// `https://lbsyun.baidu.com/apiconsole/key` 申请到的浏览器端 AK，
// 并把当前域名加入白名单。
export 'baidu_map_view_io.dart'
    if (dart.library.html) 'baidu_map_view_web.dart';
