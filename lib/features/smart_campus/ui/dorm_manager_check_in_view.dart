// =============================================================================
// 宿管端「打卡管理」独立页面
//
// 入口：宿管 dashboard 快捷区「打卡管理」按钮 → controller
//      .openDormCheckInManagement() → mainView == dormCheckInManagement +
//      role == dormManager → SmartCampusPage 路由到本视图。
//      返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高 + 4deg #F9EDFF→white 渐变 + 圆角 16 + 顶部居中
//      「打卡管理」16/600 + 副标题 12/#B6B5BB 操作说明）。
//   2. 主面板（970×439 白卡 + 16 圆角）：
//      - 左上小绿图标（顶部小标识）+ 「在责任区内 距考勤处约 850m」14/#12CE51
//        电子围栏状态。
//      - 「获取当前定位」白底胶囊按钮（外描 1px #CECED1，点击 toast 模拟刷新）。
//      - 中央 160×160 紫渐变圆形大按钮（"上班打卡 / 下班打卡" 16/600 白字 +
//        实时时间 21:32:22 20/600 白字）。圆心外加一圈浅紫光晕模拟 inset 阴影。
//      - 背景：柔和雷达圆（径向渐变 #D9D9D9→透明）做空间感，无需地图占位图。
//   3. 「我的打卡记录」18/500 大标题（左对齐）。
//   4. 477 宽双列卡片 Wrap（左右各 1，垂直 gap 12 + 横向 16）：
//      - 卡片 210° #F9EEFF→white 渐变 + 12 圆角 + 1px white outline。
//      - 头：16/500 黑标题（"早晨上班卡 / 中午下班卡" 等）+ 右侧 "正常" 徽章
//        （#E4FFED bg / #12CE51 字 / 4 圆角 / 12/400）。
//      - 体：#F5F6FA 12 圆角块 padding 16，两行 12 文字 "打卡时间：YYYY-MM-DD
//        HH:MM" + "打卡位置：教学楼A区"（label #B6B5BB / value #0B081A）。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../services/geo_locator.dart';
import 'widgets/baidu_map_view.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderLine = Color(0xFFCECED1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextDarker = Color(0xFF1A1A1A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFB68BFF);
const Color _kPurpleGlow = Color(0xFFD7D2FF);

/// 顶部状态文案的"语义颜色"种类。
enum _LocationStatusKind { loading, success, error }

Color _statusColor(_LocationStatusKind k) {
  switch (k) {
    case _LocationStatusKind.loading:
      return _kTextHint;
    case _LocationStatusKind.success:
      return _kGreen;
    case _LocationStatusKind.error:
      return const Color(0xFFFF323C);
  }
}

// —— 打卡记录类型与状态 ——————————————————————————————————————————————
enum _PunchKind {
  morningOn('早晨上班卡'),
  noonOff('中午下班卡'),
  afternoonOn('下午上班卡'),
  eveningOff('下班打卡');

  const _PunchKind(this.label);
  final String label;
}

enum _PunchStatus {
  normal('正常', _kGreen, _kGreenSoftBg);

  const _PunchStatus(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

class _PunchRecord {
  const _PunchRecord({
    required this.kind,
    required this.status,
    required this.time,
    required this.location,
    this.lat,
    this.lng,
    this.accuracyMeters,
  });

  final _PunchKind kind;
  final _PunchStatus status;
  final String time;

  /// 人类可读地址（由百度地图反编码得到的 "XX 路 X 号" 文案），
  /// 没有反编码结果时则回退到 "纬度 N° / 经度 E°" 的原始坐标文案。
  final String location;

  /// WGS-84 经纬度（浏览器 geolocation 原始坐标），可用于打卡留痕审计。
  /// 历史演示数据没有，所以是可选的。
  final double? lat;
  final double? lng;
  final double? accuracyMeters;
}

// =============================================================================
// 顶级视图
// =============================================================================

class DormManagerCheckInView extends StatefulWidget {
  const DormManagerCheckInView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<DormManagerCheckInView> createState() => _DormManagerCheckInViewState();
}

class _DormManagerCheckInViewState extends State<DormManagerCheckInView> {
  Timer? _ticker;
  late DateTime _now;
  late List<_PunchRecord> _records;

  /// 最近一次定位结果（WGS-84），用于：
  ///   - 在 [BaiduMapView] 上落点
  ///   - 打卡时写入 [_PunchRecord.lat/lng]
  /// 首次进入页面会自动尝试一次定位；用户也可点击「获取当前定位」重新拉。
  GeoPosition? _position;

  /// 定位 / 地址解析过程中的状态文案。绿字 = 已完成；灰字 = 进行中；
  /// 红字 = 失败。颜色由 [_locationStatusColor] 决定。
  String _locationStatus = '正在获取定位…';
  _LocationStatusKind _locationStatusKind = _LocationStatusKind.loading;

  /// 百度地图反编码得到的地址；空时回退到 "纬度 / 经度" 数字文案。
  String? _resolvedAddress;

  /// 标记一次 "正在定位" 请求，避免按钮重入。
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _records = _demoRecords();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    // 进入页面后异步发起一次定位；用户没授权时 UI 会停在 "正在获取定位…"，
    // 由用户主动点击 "获取当前定位" 触发权限弹窗。
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLocation());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationStatus = '正在获取定位…';
      _locationStatusKind = _LocationStatusKind.loading;
    });
    try {
      final pos = await getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _position = pos;
        _resolvedAddress = null; // 等地图反编码回填
        _locationStatus =
            '已定位 · 精度 ${pos.accuracyMeters.toStringAsFixed(0)}m';
        _locationStatusKind = _LocationStatusKind.success;
      });
    } on GeoException catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = e.userMessage;
        _locationStatusKind = _LocationStatusKind.error;
      });
      AppToast.show(context, e.userMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = '获取定位失败：$e';
        _locationStatusKind = _LocationStatusKind.error;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onMapAddressResolved(String address) {
    if (!mounted) return;
    setState(() {
      _resolvedAddress = address;
      if (_locationStatusKind == _LocationStatusKind.success) {
        _locationStatus = address;
      }
    });
  }

  /// 当前应展示的"打卡地点"文本：优先使用地图反编码地址，否则用经纬度数字。
  String get _currentLocationDisplay {
    if (_resolvedAddress != null && _resolvedAddress!.isNotEmpty) {
      return _resolvedAddress!;
    }
    final p = _position;
    if (p != null) {
      return '纬度 ${p.lat.toStringAsFixed(5)} / 经度 ${p.lng.toStringAsFixed(5)}';
    }
    return '暂无定位';
  }

  /// 当前应为「上班打卡」还是「下班打卡」（仅用于大圆按钮文案）：
  /// - 0:00-12:00 → 上班打卡
  /// - 12:00-13:00 → 中午下班卡
  /// - 13:00-18:00 → 下午上班卡
  /// - 18:00- → 下班打卡
  String get _punchLabel {
    final h = _now.hour;
    if (h < 12) return '上班打卡';
    if (h < 13) return '中午下班卡';
    if (h < 18) return '下午上班卡';
    return '下班打卡';
  }

  _PunchKind get _currentPunchKind {
    final h = _now.hour;
    if (h < 12) return _PunchKind.morningOn;
    if (h < 13) return _PunchKind.noonOff;
    if (h < 18) return _PunchKind.afternoonOn;
    return _PunchKind.eveningOff;
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  String _formatRecord(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  void _onPunch() {
    final p = _position;
    if (p == null) {
      AppToast.show(context, '请先获取定位再打卡');
      // 顺手再拉一次
      _fetchLocation();
      return;
    }
    final now = DateTime.now();
    setState(() {
      _records = [
        _PunchRecord(
          kind: _currentPunchKind,
          status: _PunchStatus.normal,
          time: _formatRecord(now),
          location: _currentLocationDisplay,
          lat: p.lat,
          lng: p.lng,
          accuracyMeters: p.accuracyMeters,
        ),
        ..._records,
      ];
    });
    AppToast.show(
      context,
      '${_currentPunchKind.label}打卡成功 · 精度 ${p.accuracyMeters.toStringAsFixed(0)}m',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _PunchPanel(
              clock: _formatTime(_now),
              punchLabel: _punchLabel,
              locationStatus: _locationStatus,
              locationStatusColor: _statusColor(_locationStatusKind),
              position: _position,
              locating: _locating,
              onRefreshLocation: _fetchLocation,
              onPunch: _onPunch,
              onAddressResolved: _onMapAddressResolved,
            ),
            SizedBox(height: ui(16)),
            Text(
              '我的打卡记录',
              style: TextStyle(
                fontSize: ui(18),
                color: _kTextDarker,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(16)),
            _RecordsGrid(records: _records),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner
// =============================================================================

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '打卡管理',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '到岗打卡采用服务器时间戳+GPS坐标留痕；下方可查看本人历史。演示数据存于本机浏览器，生产环境应对接考勤服务与电子围栏。',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 大圆形打卡主面板
// =============================================================================

class _PunchPanel extends StatelessWidget {
  const _PunchPanel({
    required this.clock,
    required this.punchLabel,
    required this.locationStatus,
    required this.locationStatusColor,
    required this.position,
    required this.locating,
    required this.onRefreshLocation,
    required this.onPunch,
    required this.onAddressResolved,
  });

  final String clock;
  final String punchLabel;
  final String locationStatus;
  final Color locationStatusColor;
  final GeoPosition? position;
  final bool locating;
  final VoidCallback onRefreshLocation;
  final VoidCallback onPunch;
  final ValueChanged<String> onAddressResolved;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = BorderRadius.circular(ui(16));
    return Container(
      width: double.infinity,
      height: ui(439),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景：百度地图。Web 端通过 iframe 加载 baidu_map.html；非 web
          // 端展示占位。地图整体作为面板背景，圆形打卡按钮叠在中心。
          Positioned.fill(
            child: BaiduMapView(
              lat: position?.lat,
              lng: position?.lng,
              label: '当前位置',
              onAddressResolved: onAddressResolved,
            ),
          ),
          // 顶部覆盖层（白底半透明），让状态文字 / 按钮在地图上仍可读。
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.only(top: ui(20), bottom: ui(16)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.96),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: ui(36),
                    color: locationStatusColor,
                  ),
                  SizedBox(height: ui(8)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: ui(24)),
                    child: Text(
                      locationStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: locationStatusColor,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: ui(16)),
                  _RefreshLocationButton(
                    onTap: onRefreshLocation,
                    busy: locating,
                  ),
                ],
              ),
            ),
          ),
          // 中央大圆形打卡按钮。
          Center(
            child: _BigPunchButton(
              label: punchLabel,
              clock: clock,
              onTap: onPunch,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshLocationButton extends StatelessWidget {
  const _RefreshLocationButton({required this.onTap, this.busy = false});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      borderRadius: BorderRadius.circular(ui(12)),
      onTap: busy ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ui(12),
          vertical: ui(4),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderLine, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: ui(14),
                height: ui(14),
                child: const CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Color(0xFF1C274C),
                ),
              )
            else
              Icon(
                Icons.my_location_rounded,
                size: ui(14),
                color: const Color(0xFF1C274C),
              ),
            SizedBox(width: ui(4)),
            Text(
              busy ? '定位中…' : '获取当前定位',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 中央 160 圆形大按钮，精确还原 Figma：
///
/// ```css
/// width: 160; height: 160;
/// background: linear-gradient(180deg, #8741FF 14%, #B68BFF 100%);
/// box-shadow: 0px 0px 20px #D7D2FF inset;
/// border-radius: 9999px;
/// ```
///
/// 文字（PingFang SC / 600 / white）：
/// - 标题 16，居中（Figma `left:48 top:54`, 与 160 居中等价）。
/// - 时钟 20，居中（Figma `left:40 top:84`）。
/// - 标题 baseline 与时钟 baseline 之间约 30px（top:54 → top:84）。
///   以 `height:1.0` + `SizedBox ui(11)` 间距精确还原。
///
/// Flutter 没有原生的 `box-shadow inset`。这里用 `Stack` 在 LinearGradient
/// 底圆之上叠一层 `RadialGradient`（透明 → 半透明 `#D7D2FF`，stops 0.6→1.0）
/// 模拟"边缘 20px 内嵌的浅紫光晕"。透明度 0.55 让 D7D2FF 与底色融合，
/// 而非整体洗白外圈。
///
/// **没有外侧阴影** —— Figma 只指定了 inset 一种阴影，这里也保持一致。
class _BigPunchButton extends StatelessWidget {
  const _BigPunchButton({
    required this.label,
    required this.clock,
    required this.onTap,
  });

  final String label;
  final String clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: ui(160),
          height: ui(160),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1) 底圆：180° 线性渐变 #8741FF (14%) → #B68BFF。
              Container(
                width: ui(160),
                height: ui(160),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kPurple, _kPurpleLight],
                    stops: [0.14, 1.0],
                  ),
                ),
              ),
              // 2) Inset 光晕：边缘 ~20px 范围内的浅紫色 D7D2FF 柔光，
              //    模拟 CSS `box-shadow: 0 0 20px #D7D2FF inset`。
              //    20/80(半径) ≈ 25%，所以 stops 从 0.6 透明 → 1.0 半透明。
              IgnorePointer(
                child: Container(
                  width: ui(160),
                  height: ui(160),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        _kPurpleGlow.withValues(alpha: 0.55),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // 3) 文字。Column 居中，line-height 1.0 + ui(11) 间距
              //    精准还原 Figma top:54 / top:84 的 30px 间距。
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: ui(11)),
                  Text(
                    clock,
                    style: TextStyle(
                      fontSize: ui(20),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 我的打卡记录 双列卡片网格
// =============================================================================

class _RecordsGrid extends StatelessWidget {
  const _RecordsGrid({required this.records});

  final List<_PunchRecord> records;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            '暂无打卡记录',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        // 970 主区 - 16 列间距，左右各 1 → 单卡宽 (W - 16) / 2。
        final cardW = (c.maxWidth - ui(16)) / 2;
        return Wrap(
          spacing: ui(16),
          runSpacing: ui(12),
          children: [
            for (final r in records)
              SizedBox(width: cardW, child: _RecordCard(record: r)),
          ],
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final _PunchRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF9EEFF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                record.kind.label,
                style: TextStyle(
                  fontSize: ui(16),
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              _StatusBadge(status: record.status),
            ],
          ),
          SizedBox(height: ui(8)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(16)),
            decoration: BoxDecoration(
              color: _kCardGreyBg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RecordKeyValue(label: '打卡时间：', value: record.time),
                SizedBox(height: ui(6)),
                _RecordKeyValue(label: '打卡位置：', value: record.location),
                if (record.lat != null && record.lng != null) ...[
                  SizedBox(height: ui(6)),
                  _RecordKeyValue(
                    label: 'GPS 坐标：',
                    value: '${record.lat!.toStringAsFixed(6)}, '
                        '${record.lng!.toStringAsFixed(6)}'
                        '${record.accuracyMeters != null
                            ? ' (±${record.accuracyMeters!.toStringAsFixed(0)}m)'
                            : ''}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _PunchStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui(4),
        vertical: ui(2),
      ),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: status.fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.27,
        ),
      ),
    );
  }
}

class _RecordKeyValue extends StatelessWidget {
  const _RecordKeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 演示数据
// =============================================================================

List<_PunchRecord> _demoRecords() {
  return const [
    _PunchRecord(
      kind: _PunchKind.morningOn,
      status: _PunchStatus.normal,
      time: '2026-04-02 08:00',
      location: '教学楼A区',
    ),
    _PunchRecord(
      kind: _PunchKind.noonOff,
      status: _PunchStatus.normal,
      time: '2026-04-02 12:00',
      location: '教学楼A区',
    ),
    _PunchRecord(
      kind: _PunchKind.afternoonOn,
      status: _PunchStatus.normal,
      time: '2026-04-02 13:30',
      location: '教学楼A区',
    ),
    _PunchRecord(
      kind: _PunchKind.eveningOff,
      status: _PunchStatus.normal,
      time: '2026-04-02 21:00',
      location: '教学楼A区',
    ),
  ];
}
