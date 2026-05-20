import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppAssetGraphic extends StatelessWidget {
  const AppAssetGraphic(
    this.asset, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.colorFilter,
    super.key,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ColorFilter? colorFilter;

  Widget _buildMissing() {
    return SizedBox(width: width, height: height);
  }

  Widget _buildRaster({required bool allowSvgFallback}) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: allowSvgFallback
          ? (context, error, stackTrace) =>
                _buildVector(allowRasterFallback: false)
          : (context, error, stackTrace) => _buildMissing(),
    );
  }

  Widget _buildVector({required bool allowRasterFallback}) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: colorFilter,
      errorBuilder: allowRasterFallback
          ? (context, error, stackTrace) =>
                _buildRaster(allowSvgFallback: false)
          : (context, error, stackTrace) => _buildMissing(),
    );
  }

  static bool isVectorAsset(String asset) {
    if (asset.endsWith('.svg')) {
      return true;
    }

    // 这几个 .png 是真二进制 PNG（Figma 直接导出的 raster），但和它们同
    // 目录下的图标多数其实是 svg 文本写在 .png 后缀里，所以一开始把整目录
    // 都当矢量。结果这些 raster 走 SvgPicture.asset → flutter_svg 解析失败
    // → 虽然 errorBuilder 会兜底回退到 Image.asset，但 vector_graphics
    // 的 compute 仍然会向外抛 `Uncaught (in promise) XmlParserException`
    // （Flutter web 调试模式下控制台会被刷屏，并且 dev 工具偶发卡顿）。
    // 在这里显式列出来，让它们走 raster 路径。
    const rasterPngOverrides = <String>{
      'assets/images/shell/topbar_v2/help.png',
      'assets/images/shell/topbar_v2/notice.png',
      'assets/images/shell/topbar_v2/search.png',
      'assets/images/shell/topbar_v2/setting.png',
      'assets/images/aichat/ai_v2_intro_logo.png',
    };
    if (rasterPngOverrides.contains(asset)) {
      return false;
    }

    if (asset.contains('/shell/nav_v2/') ||
        asset.contains('/shell/topbar_v2/')) {
      return true;
    }

    if (asset.contains('/home/v2/') && !asset.endsWith('/banner_guitar.png')) {
      return true;
    }

    if (asset.contains('/aichat/') &&
        asset.endsWith('.png') &&
        asset.contains('_v2_')) {
      return true;
    }

    const authVectorPngs = <String>{
      'assets/images/auth/v2_bg_shape.png',
      'assets/images/auth/v2_ellipse_big.png',
      'assets/images/auth/v2_ellipse_small.png',
      'assets/images/auth/v2_icon_password.png',
      'assets/images/auth/v2_icon_phone.png',
    };
    return authVectorPngs.contains(asset);
  }

  @override
  Widget build(BuildContext context) {
    if (isVectorAsset(asset)) {
      return _buildVector(allowRasterFallback: true);
    }
    return _buildRaster(allowSvgFallback: true);
  }
}
