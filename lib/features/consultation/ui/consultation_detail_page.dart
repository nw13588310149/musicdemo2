import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/consultation_detail_controller.dart';
import '../state/consultation_detail_state.dart';
import 'consultation_page.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class ConsultationDetailPage extends ConsumerStatefulWidget {
  const ConsultationDetailPage({super.key});

  @override
  ConsumerState<ConsultationDetailPage> createState() =>
      _ConsultationDetailPageState();
}

class _ConsultationDetailPageState
    extends ConsumerState<ConsultationDetailPage> {
  ConsultationDetailArgs? _args;
  bool _shareDialogShowing = false;

  ConsultationDetailArgs _resolveArgs(BuildContext context) {
    if (_args != null) return _args!;
    final raw = ModalRoute.of(context)?.settings.arguments;
    _args = ConsultationDetailArgs.fromRaw(raw);
    return _args!;
  }

  @override
  Widget build(BuildContext context) {
    final args = _resolveArgs(context);
    final provider = consultationDetailControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<ConsultationDetailState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isNotEmpty && msg != previous?.errorMessage) {
        AppToast.show(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.clearError();
        });
      }

      if (next.shareDialogVisible && !_shareDialogShowing) {
        _shareDialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(context, args);
        });
      }
    });

    final ui = DashboardScaleScope.of(context).ui;
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: state.loading && state.detail == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                    onShare: controller.openShareDialog,
                  ),
                  Expanded(
                    child: state.detail == null
                        ? const Center(child: Text('暂无资讯'))
                        : _DetailBody(detail: state.detail!),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showShareDialog(
    BuildContext context,
    ConsultationDetailArgs args,
  ) async {
    if (!mounted) return;
    final scale = DashboardScaleScope.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      barrierDismissible: true,
      barrierLabel: '关闭分享',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DashboardScaleScope(
          data: scale,
          child: _ShareDrawer(args: args),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
    );
    _shareDialogShowing = false;
    if (mounted) {
      ref
          .read(consultationDetailControllerProvider(args).notifier)
          .closeShareDialog();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// 顶部 56 header（左返回 + 右"分享"按钮）
// ─────────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(56),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: Row(
        children: [
          ConsultationBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                '资讯',
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontWeight: AppFont.w600,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
          _ShareButton(onTap: onShare),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(28),
        padding: EdgeInsets.fromLTRB(ui(12), ui(4), ui(13), ui(4)),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/home/dictation/10.png',
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(4)),
            Text(
              '分享',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 详情正文：标题 + 元信息 + 阅读数 + 封面 + HTML 正文
// ─────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ConsultationDetail detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 外层 vertical 12 padding 让滚动条不顶到 header 分割线和白卡底部；
    // 内层滚动 padding 上下各减 12，整体视觉与原间距一致。
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      child: Scrollbar(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      detail.title,
                      style: TextStyle(
                        color: const Color(0xFF0B081A),
                        fontSize: ui(16),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 24 / 16,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(12)),
                  _ViewCountText(count: detail.viewCount),
                ],
              ),
              SizedBox(height: ui(8)),
              Row(
                children: [
                  Text(
                    detail.source,
                    style: TextStyle(
                      color: const Color(0xFF6D6B75),
                      fontSize: ui(14),
                      fontFamily: 'PingFang SC',
                      height: 20 / 14,
                    ),
                  ),
                  SizedBox(width: ui(16)),
                  Text(
                    detail.updateTime,
                    style: TextStyle(
                      color: const Color(0xFF6D6B75),
                      fontSize: ui(14),
                      fontFamily: 'PingFang SC',
                      height: 20 / 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(20)),
              HtmlWidget(
                detail.htmlContent.isEmpty ? '<p>暂无内容</p>' : detail.htmlContent,
                textStyle: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  height: 24 / 13,
                ),
                // 拦截 <img>：默认 _core 包对 <img> 的处理会把整张大图按
                // 原始分辨率解码到 GPU，iPad 上快速 fling 时多张高清图同时
                // 解码 → Skia/Impeller OOM 闪退。这里改成 CachedNetworkImage
                // + 受限的 memCacheWidth，把解码后位图大小卡在屏幕物理像素
                // 内，并用 RepaintBoundary 隔离 raster cache。
                customWidgetBuilder: (element) {
                  if (element.localName != 'img') return null;
                  final src = element.attributes['src']?.trim() ?? '';
                  if (src.isEmpty) return null;
                  final designW = double.tryParse(
                    element.attributes['width'] ?? '',
                  );
                  final designH = double.tryParse(
                    element.attributes['height'] ?? '',
                  );
                  return _ConsultationHtmlImage(
                    url: src,
                    designWidth: designW,
                    designHeight: designH,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资讯正文中的 `<img>` 渲染器：把后端给的远程图片按容器最大宽度等比缩放，
/// 同时把解码后的位图尺寸（`memCacheWidth`）卡在屏幕物理像素 × 1 的范围里，
/// 避免一张几 MB 的大图被解到几十 MB 的位图，导致 iPad 在快速滚动时 OOM。
///
/// - 加 `RepaintBoundary` 隔离图层，滚动时不会让整篇正文都重新栅格化。
/// - 用 `CachedNetworkImage` 走磁盘缓存，避免重复下载/解码。
/// - 加载失败时退回灰色占位，正文不会因为单张图损坏而整页崩。
class _ConsultationHtmlImage extends StatelessWidget {
  const _ConsultationHtmlImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.maybeOf(context);
        final dpr = media?.devicePixelRatio ?? 1.0;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (media?.size.width ?? 1024.0);

        double width = designWidth ?? maxW;
        double? height = designHeight;
        if (width > maxW) {
          if (designWidth != null &&
              designHeight != null &&
              designWidth! > 0) {
            height = designHeight! * (maxW / designWidth!);
          } else {
            height = null;
          }
          width = maxW;
        }

        // memCacheWidth 上限：屏幕物理像素 × 1，最多 1600，避免设计师
        // 上传的 4K 大图在内存里占爆。
        final memCacheW = (width * dpr).clamp(1.0, 1600.0).toInt();

        return RepaintBoundary(
          child: CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: BoxFit.contain,
            memCacheWidth: memCacheW,
            fadeInDuration: const Duration(milliseconds: 120),
            fadeOutDuration: const Duration(milliseconds: 80),
            errorWidget: (context, error, stackTrace) => Container(
              width: width,
              height: height ?? 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.broken_image_rounded,
                color: Color(0xFFC9C6D8),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ViewCountText extends StatelessWidget {
  const _ViewCountText({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.visibility_outlined,
          size: ui(14),
          color: const Color(0xFF928FA0),
        ),
        SizedBox(width: ui(4)),
        Text(
          count.toString(),
          style: TextStyle(
            color: const Color(0xFFB6B5BB),
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 分享抽屉（左侧 600 宽，全高）
// ─────────────────────────────────────────────────────────────────────

class _ShareDrawer extends ConsumerWidget {
  const _ShareDrawer({required this.args});

  final ConsultationDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consultationDetailControllerProvider(args));
    final controller = ref.read(
      consultationDetailControllerProvider(args).notifier,
    );
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: ui(600),
          height: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerTitle(title: '分享课件'),
                SizedBox(height: ui(20)),
                const Divider(height: 1, color: Color(0xFFF3F2F3)),
                SizedBox(height: ui(24)),
                _ShareTargetCard(detail: state.detail),
                SizedBox(height: ui(28)),
                Text(
                  '您的班级群',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
                SizedBox(height: ui(16)),
                Expanded(
                  child: state.classLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.classList.isEmpty
                      ? const _ShareDrawerEmpty()
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: state.classList.length,
                          separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                          itemBuilder: (context, index) {
                            final cls = state.classList[index];
                            return _ClassRow(
                              cls: cls,
                              onTap: () => controller.toggleClass(cls.id),
                            );
                          },
                        ),
                ),
                SizedBox(height: ui(12)),
                _SendButton(
                  loading: state.sending,
                  onTap: () async {
                    final success = await controller.send();
                    if (!context.mounted) return;
                    if (success) {
                      AppToast.show(context, '消息已成功发送');
                      Navigator.of(context).maybePop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerTitle extends StatelessWidget {
  const _DrawerTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: const Color(0xFF8741FF),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
          ),
        ),
      ],
    );
  }
}

class _ShareTargetCard extends StatelessWidget {
  const _ShareTargetCard({required this.detail});

  final ConsultationDetail? detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(106),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(20)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '您将分享的资讯',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(10)),
                Text(
                  detail?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          Container(
            width: ui(75.76),
            height: ui(55.27),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1E8FD), Color(0xFFDDC4FF)],
              ),
              borderRadius: BorderRadius.circular(ui(6.82)),
            ),
            child: const Icon(Icons.feed_rounded, color: Color(0xFFA773FF)),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.cls, required this.onTap});

  final ConsultationClass cls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checked = cls.checked;
    return Material(
      color: const Color(0xFFF5F6FA),
      borderRadius: BorderRadius.circular(ui(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(16)),
        onTap: onTap,
        child: Container(
          height: ui(80),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          child: Row(
            children: [
              Container(
                width: ui(24),
                height: ui(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked
                        ? const Color(0xFF8741FF)
                        : const Color(0xFFCECED1),
                    width: 1,
                  ),
                ),
                child: checked
                    ? Icon(
                        Icons.check_rounded,
                        size: ui(16),
                        color: const Color(0xFF8741FF),
                      )
                    : null,
              ),
              SizedBox(width: ui(16)),
              Expanded(
                child: Text(
                  cls.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareDrawerEmpty extends StatelessWidget {
  const _ShareDrawerEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Text(
        '暂无班级群',
        style: TextStyle(
          color: const Color(0xFFB6B5BB),
          fontSize: ui(14),
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: loading
            ? SizedBox(
                width: ui(20),
                height: ui(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '发送',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 24 / 14,
                ),
              ),
      ),
    );
  }
}
