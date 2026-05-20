import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/state/shell_controller.dart';
import '../../smart_campus/state/smart_campus_controller.dart';
import '../../smart_campus/state/smart_campus_state.dart';
import '../data/qr_image_saver.dart';
import '../state/personal_center_controller.dart';
import '../state/personal_center_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 与 1.0 `pages/PersonalCenter/index.vue` 中 `APP_PROMO_URL` 一致。
const _kAppPromoUrl = 'https://apps.apple.com/cn/app/音乐之路/id6504698046';

/// 「联系客服」展示与 1.0 邮件入口一致的官方反馈邮箱。
const _kSupportEmail = 'yinyuezhilu@gmail.com';

class PersonalCenterPage extends ConsumerStatefulWidget {
  const PersonalCenterPage({super.key});

  @override
  ConsumerState<PersonalCenterPage> createState() => _PersonalCenterPageState();
}

class _PersonalCenterPageState extends ConsumerState<PersonalCenterPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personalCenterControllerProvider);
    final controller = ref.read(personalCenterControllerProvider.notifier);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileHero(
            state: state,
            controller: controller,
            onEditProfile: () => Navigator.pushNamed(context, RoutePaths.info),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _ActionListCard(
              checkStatusEnabled: state.checkStatusEnabled,
              onQr: () => _onMyQr(context, controller, state),
              onRecommend: () => _onRecommend(context),
              onFeedback: () => _onFeedback(context, ref),
              onService: () => _onContactService(context),
              onRedeem: state.checkStatusEnabled
                  ? () => _onRedeem(context, controller)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMyQr(
    BuildContext context,
    PersonalCenterController controller,
    PersonalCenterState state,
  ) async {
    final result = await controller.fetchQrImageUrl();
    if (!context.mounted) {
      return;
    }
    if (result.error != null) {
      AppToast.showError(context, result.error!);
      return;
    }
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => _MyQrCodeDialog(
        nickname: state.user['nickname']?.toString() ?? '用户',
        mobile: state.user['mobile']?.toString() ?? '',
        avatarUrl: state.user['headUrl']?.toString(),
        imageUrl: result.url!,
      ),
    );
  }

  void _onRecommend(BuildContext context) {
    showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => const _RecommendDialog(),
    );
  }

  /// 「意见反馈」入口：跳转到智慧校园并切换到「校长信箱」的需求反馈分段。
  /// 复用智慧校园 `PrincipalMailboxView` 的「需求反馈」表单 + 列表，避免在
  /// 个人中心再实现一套相同表单。
  void _onFeedback(BuildContext context, WidgetRef ref) {
    ref
        .read(smartCampusControllerProvider.notifier)
        .openPrincipalMailbox(initialMode: PrincipalMailboxInitialMode.feedback);
    Navigator.pushReplacementNamed(context, RoutePaths.smartCampus);
  }

  void _onContactService(BuildContext context) {
    showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => const _ContactServiceDialog(email: _kSupportEmail),
    );
  }

  Future<void> _onRedeem(
    BuildContext context,
    PersonalCenterController controller,
  ) async {
    final code = await showScaledDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => const _RedeemVipDialog(),
    );
    if (!context.mounted || code == null || code.isEmpty) {
      return;
    }
    final msg = await controller.redeemVip(code);
    if (!context.mounted) {
      return;
    }
    if (msg != null) {
      AppToast.showError(context, msg);
    } else {
      await ref.read(shellControllerProvider.notifier).refreshUserAndSchool();
      if (!context.mounted) {
        return;
      }
      AppToast.showSuccess(context, '兑换成功');
    }
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.state,
    required this.controller,
    required this.onEditProfile,
  });

  final PersonalCenterState state;
  final PersonalCenterController controller;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final nick = user['nickname']?.toString().trim() ?? '';
    final mobile = user['mobile']?.toString().trim() ?? '';
    final identity = user['identity']?.toString().trim() ?? '';
    final avatarUrl = user['headUrl']?.toString();

    final days = controller.vipDaysRemaining();
    final showAnnualBadge =
        state.checkStatusEnabled && days != null && days >= 1;
    final pkg0 = state.vipPackages.isNotEmpty ? state.vipPackages[0] : null;
    final pkg1 = state.vipPackages.length > 1 ? state.vipPackages[1] : null;

    // Figma 设计稿固定高度：970×239。VIP 不可见时收缩高度，仅保留头像+昵称区。
    final heroHeight = state.checkStatusEnabled ? 239.0 : 132.0;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 背景：渐变 + 装饰皇冠（沿用 info/bg.png）──
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    AppAssets.infoBg,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          const Color(0xFFFAF8FD).withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 昵称 / 手机号 列（左 122，上 45）──
          Positioned(
            left: 122,
            top: 45,
            child: _NicknameColumn(
              nickname: nick.isNotEmpty ? nick : '未命名',
              mobile: mobile,
              onEdit: onEditProfile,
            ),
          ),

          // ── 「年卡会员」徽章（左 215，上 45）──
          if (showAnnualBadge)
            const Positioned(
              left: 215,
              top: 45,
              child: _AnnualVipBadge(),
            ),

          // ── 三张信息卡片（左 16，上 123，每张 303×100，间距 13）。
          //    注意：卡片需放在头像之前绘制，避免遮挡头像。──
          if (state.checkStatusEnabled)
            Positioned(
              left: 16,
              top: 123,
              right: 16,
              height: 100,
              child: Row(
                children: [
                  Expanded(
                    child: _VipPriceCard(
                      annualLayout: true,
                      title: pkg0?.name ?? '年卡365天',
                      subtitle: pkg0?.description ?? '每月仅需116.5元',
                      price: pkg0?.price ?? '1,398',
                      trailingLabel: days != null && days > 3
                          ? '已开通'
                          : null,
                      showPrice: days == null || days <= 3,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: _VipPriceCard(
                      annualLayout: false,
                      title: pkg1?.name ?? '3天体验卡',
                      subtitle: pkg1?.description ?? '每天仅需6.6元',
                      price: pkg1?.price ?? '198',
                      trailingLabel: days != null && days >= 1
                          ? '已开通'
                          : null,
                      showPrice: days == null || days < 1,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: _WalletPointsCard(
                      wallet: state.walletText,
                      points: state.pointsText,
                    ),
                  ),
                ],
              ),
            ),

          // ── 头像（左 16，上 101.5，82×82，2px 白色描边）。
          //    放在卡片之后，确保浮于卡片上方。──
          Positioned(
            left: 16,
            top: 25,
            child: _Avatar(url: avatarUrl, size: 82),
          ),

          // ── 身份徽标（左 57，上 167.5）──
          if (identity.isNotEmpty)
            Positioned(
              left: 64,
              top: 90,
              child: _IdentityBadge(label: identity),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, this.size = 82});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    final network =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    const ring = 2.0;
    final inner = size - 2 * ring;
    final fallback = Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFD9D9D9),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: const Color(0xFF7E879C),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(ring),
      child: ClipOval(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: SizedBox(
          width: inner,
          height: inner,
          child: network
              ? Image.network(
                  trimmed,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

/// 头像下方的身份徽标：黄绿底 #DBEE49 + 白色 1px 描边 + 11/400 文案。
class _IdentityBadge extends StatelessWidget {
  const _IdentityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDBEE49),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          strutStyle: const StrutStyle(
            fontSize: 11,
            height: 1.1,
            forceStrutHeight: true,
          ),
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: 11,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// 昵称（16/500）+ 编辑笔，下接手机号（14/400 #6D6B75）。
class _NicknameColumn extends StatelessWidget {
  const _NicknameColumn({
    required this.nickname,
    required this.mobile,
    required this.onEdit,
  });

  final String nickname;
  final String mobile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: 16,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 16,
                height: 16,
                child: Image.asset(
                  AppAssets.infoPencilLine,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (mobile.isNotEmpty)
          Text(
            mobile,
            style: TextStyle(
              color: const Color(0xFF6D6B75),
              fontSize: 14,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}

/// 「年卡会员」角标。
///
/// 之前是用 [Stack] 把 24×24 V 标 + 73×22 紫渐变胶囊 + Alibaba PuHuiTi 700
/// 文字三块合成的。现在直接换成单张设计图 [AppAssets.infoAnnualVipBadge]：
/// - 容器宽高沿用之前的 `82×24` 占位坐标，避免父级 [Positioned] 的位置偏移；
/// - `BoxFit.contain` 让设计图按自身比例自适应，不被拉伸；
/// - V 标会被设计图自身的横向溢出贴在胶囊左侧（与原视觉一致）。
class _AnnualVipBadge extends StatelessWidget {
  const _AnnualVipBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 24,
      child: Image.asset(
        AppAssets.infoAnnualVipBadge,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _VipPriceCard extends StatelessWidget {
  const _VipPriceCard({
    required this.annualLayout,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.showPrice,
    this.trailingLabel,
  });

  final bool annualLayout;
  final String title;
  final String subtitle;
  final String price;
  final bool showPrice;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    if (annualLayout) {
      final priceText = price.startsWith('¥') || price.startsWith('\u00a5')
          ? price
          : '¥$price';
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 100,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                AppAssets.infoCard,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF170333),
                              fontFamily: 'Alimama ShuHeiTi',
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w400,
                              color: Color(0xFF6D6B75),
                              fontFamily: 'PingFang SC',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showPrice)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          priceText,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF170333),
                            fontFamily: 'Barlow',
                            height: 1,
                          ),
                        ),
                      ),
                    if (!showPrice && trailingLabel != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: _VipActivatedBadge(height: 22),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.72), Colors.white],
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF170333),
                  fontFamily: 'PingFang SC',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6D6B75),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
          if (showPrice)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  price.startsWith('¥') || price.startsWith('\u00a5')
                      ? price
                      : '¥$price',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF170333),
                    fontFamily: 'Barlow',
                  ),
                ),
              ),
            ),
          if (!showPrice && trailingLabel != null)
            const Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(child: _VipActivatedBadge(height: 24)),
            ),
        ],
      ),
    );
  }
}

/// 「已开通」徽章。
///
/// 之前是 `Container` + 紫色 [BoxDecoration] 胶囊 + 白字文本合成；现在直接
/// 渲染设计图 [AppAssets.infoVipActivated]（紫字、无背景、自带留白）。
/// - 通过 [height] 控制纵向占位（年卡 22、体验卡 24，沿用原始 padding 高度，
///   保持两侧卡片视觉对齐）；
/// - `BoxFit.contain` 让宽度按图片比例自适应，不被父级 [Row] 拉伸。
class _VipActivatedBadge extends StatelessWidget {
  const _VipActivatedBadge({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Image.asset(
        AppAssets.infoVipActivated,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      ),
    );
  }
}

/// 我的钱包 / 我的积分 卡片（设计稿绝对布局）：
///   · 303×100、半透明白渐变 + 1px 白边 + 12 圆角
///   · 左右两列居中：上方 22 Barlow 700 数字、下方 14 #6D6B75 标题
///   · 中央 1×58、#E6E9F1（30% opacity）分隔竖线
class _WalletPointsCard extends StatelessWidget {
  const _WalletPointsCard({required this.wallet, required this.points});

  final String wallet;
  final String points;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.55), Colors.white],
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _WalletColumn(value: wallet, label: '我的钱包')),
          const SizedBox(
            width: 1,
            height: 58,
            child: ColoredBox(color: Color(0x4DE6E9F1)),
          ),
          Expanded(child: _WalletColumn(value: points, label: '我的积分')),
        ],
      ),
    );
  }
}

class _WalletColumn extends StatelessWidget {
  const _WalletColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B081A),
            fontFamily: 'Barlow',
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _ActionListCard extends StatelessWidget {
  const _ActionListCard({
    required this.checkStatusEnabled,
    required this.onQr,
    required this.onRecommend,
    required this.onFeedback,
    required this.onService,
    this.onRedeem,
  });

  final bool checkStatusEnabled;
  final VoidCallback onQr;
  final VoidCallback onRecommend;
  final VoidCallback onFeedback;
  final VoidCallback onService;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                iconAsset: AppAssets.infoIconQr,
                label: '我的二维码',
                onTap: onQr,
                showDivider: true,
              ),
              if (checkStatusEnabled)
                _ActionTile(
                  iconAsset: AppAssets.infoIconRecommend,
                  label: '推荐音乐之路给好友',
                  onTap: onRecommend,
                  showDivider: true,
                ),
              _ActionTile(
                iconAsset: AppAssets.infoIconFeedback,
                label: '意见反馈',
                onTap: onFeedback,
                showDivider: true,
              ),
              _ActionTile(
                iconAsset: AppAssets.infoIconService,
                label: '联系客服',
                onTap: onService,
                showDivider: checkStatusEnabled && onRedeem != null,
              ),
              if (checkStatusEnabled && onRedeem != null)
                _ActionTile(
                  iconAsset: AppAssets.infoIconRedeem,
                  label: '兑换中心',
                  onTap: onRedeem!,
                  showDivider: false,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    required this.showDivider,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Image.asset(
                    iconAsset,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 22 / 14,
                        color: Color(0xFF0B081A),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                  Image.asset(
                    AppAssets.infoChevron,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          if (showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EB)),
        ],
      ),
    );
  }
}

// =============================================================================
// 我的二维码弹窗：紫白渐变头 + 头像/名称 + 浅紫框 二维码 + 双按钮（保存到相册 / 关闭）。
// 完全对齐 Figma 428×××（高度由内容撑起）布局：
//   · 顶部 180 高 D8CCFF→white 渐变（由 GradientHeaderDialog 提供）
//   · 标题「我的二维码」24/500 居中
//   · 380×294 #F5F6FA 二维码卡：上方 头像+名称+手机号 横排，中部紫渐变框 152×154
//     包二维码 122×122，下方两行说明文字
//   · 双按钮：取消（白）/ 主操作（紫渐变）
//
// 「保存到相册」走 `qr_image_saver`：
//   · web → 浏览器下载 PNG；
//   · 桌面 → 弹系统保存对话框写入文件；
//   · 移动暂不支持，提示用户截屏保存。
// =============================================================================
class _MyQrCodeDialog extends StatefulWidget {
  const _MyQrCodeDialog({
    required this.nickname,
    required this.mobile,
    required this.avatarUrl,
    required this.imageUrl,
  });

  final String nickname;
  final String mobile;
  final String? avatarUrl;
  final String imageUrl;

  @override
  State<_MyQrCodeDialog> createState() => _MyQrCodeDialogState();
}

class _MyQrCodeDialogState extends State<_MyQrCodeDialog> {
  late final Uint8List? _qrBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qrBytes = _QrImage.tryDecodeBase64(widget.imageUrl);
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final bytes = _qrBytes;
    if (bytes == null) {
      AppToast.showError(context, '二维码暂不支持保存，请截屏');
      return;
    }
    setState(() => _saving = true);
    final result = await saveQrImageBytes(
      bytes: bytes,
      suggestedName: _suggestedFileName(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.ok) {
      Navigator.of(context).pop();
      AppToast.showSuccess(
        context,
        kIsWeb ? '已开始下载二维码' : '已保存到 ${result.path}',
      );
      return;
    }
    if (result.cancelled) {
      return;
    }
    AppToast.showError(context, result.error ?? '保存失败');
  }

  String _suggestedFileName() {
    final raw = widget.nickname.trim();
    final safe = raw.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
    final name = safe.isEmpty ? 'qrcode' : '${safe}_qrcode';
    return '$name.png';
  }

  @override
  Widget build(BuildContext context) {
    return GradientHeaderDialog(
      title: '我的二维码',
      titleFontSize: 24,
      titleFontWeight: FontWeight.w500,
      titlePaddingTop: 40,
      width: 428,
      contentPadding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QrCodeCard(
            nickname: widget.nickname,
            mobile: widget.mobile,
            avatarUrl: widget.avatarUrl,
            imageUrl: widget.imageUrl,
          ),
          const SizedBox(height: 24),
          AppDialogActionBar(
            cancelLabel: '关闭',
            confirmLabel: _saving ? '保存中…' : '保存到相册',
            confirmEnabled: !_saving,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: _onSave,
          ),
        ],
      ),
    );
  }
}

class _QrCodeCard extends StatelessWidget {
  const _QrCodeCard({
    required this.nickname,
    required this.mobile,
    required this.avatarUrl,
    required this.imageUrl,
  });

  final String nickname;
  final String mobile;
  final String? avatarUrl;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniAvatar(url: avatarUrl, size: 44),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: const TextStyle(
                      color: Color(0xFF0B081A),
                      fontSize: 16,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mobile,
                    style: const TextStyle(
                      color: Color(0xFF6D6B75),
                      fontSize: 14,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 152,
            height: 154,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF2EAFF), Color(0x00F2EAFF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 15),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 122,
                height: 122,
                child: _QrImage(url: imageUrl),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '快来与我一起在音乐之路学习吧～',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0B081A),
              fontSize: 16,
              fontFamily: 'PingFang SC',
              height: 20 / 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '好友可直接通过扫描二维码下载音乐之路并添加你为好友',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFCECED1),
              fontSize: 12,
              fontFamily: 'PingFang SC',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 我的二维码可能是普通 http(s) 链接，也可能是 `/app/user/myQrcode` 直接
/// 返回的 `data:image/...;base64,xxx` 内联图。这里两种格式都兜住，再退化为
/// 占位 / 错误图。
class _QrImage extends StatelessWidget {
  const _QrImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _errorBox(),
      );
    }
    final bytes = tryDecodeBase64(trimmed);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _errorBox(),
      );
    }
    return _placeholderBox();
  }

  static Widget _placeholderBox() {
    return const ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(Icons.qr_code_2_rounded, color: Color(0xFF8741FF)),
      ),
    );
  }

  static Widget _errorBox() {
    return const ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Color(0xFFCECED1)),
      ),
    );
  }

  /// 兼容两种返回：
  /// - `data:image/png;base64,xxx` / `data:image/;base64,xxx`（接口实际格式）
  /// - 纯 base64 串（兜底）
  /// 解码失败时返回 null，由调用方退化到占位图。「保存到相册」会复用本方法
  /// 把同一份 bytes 写入文件，避免再 decode 一次。
  static Uint8List? tryDecodeBase64(String raw) {
    if (raw.isEmpty) return null;
    var payload = raw;
    if (payload.startsWith('data:')) {
      final commaIdx = payload.indexOf(',');
      if (commaIdx < 0) return null;
      payload = payload.substring(commaIdx + 1);
    }
    payload = payload.replaceAll(RegExp(r'\s'), '');
    if (payload.isEmpty) return null;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}

/// 圆形头像：先用 [ClipOval] + `antiAliasWithSaveLayer` 保证图片本身是真正的
/// 圆（避免 `Container(shape: circle)` + `Border` 在小尺寸下渲染成多边形），
/// 外面再叠一层 2px 白边圆环。
class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    final network =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    final inner = network
        ? Image.network(
            trimmed,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFEFEEF3),
              child: Icon(Icons.person_rounded, color: Color(0xFF7E879C)),
            ),
          )
        : const ColoredBox(
            color: Color(0xFFEFEEF3),
            child: Icon(Icons.person_rounded, color: Color(0xFF7E879C)),
          );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(clipBehavior: Clip.antiAliasWithSaveLayer, child: inner),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 兑换会员弹窗：紫白渐变头 + 单行兑换码输入框 + 取消/确认按钮。
// 点击「确认」后 pop(text) 由调用方走兑换接口；空字符串视为未输入。
// =============================================================================
class _RedeemVipDialog extends StatefulWidget {
  const _RedeemVipDialog();

  @override
  State<_RedeemVipDialog> createState() => _RedeemVipDialogState();
}

class _RedeemVipDialogState extends State<_RedeemVipDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientHeaderDialog(
      title: '兑换会员',
      titleFontSize: 24,
      titleFontWeight: FontWeight.w500,
      titlePaddingTop: 40,
      width: 428,
      contentPadding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogTextField(
            controller: _ctrl,
            hint: '请输入兑换码',
          ),
          const SizedBox(height: 24),
          AppDialogActionBar(
            cancelLabel: '取消',
            confirmLabel: '确认',
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(context).pop(_ctrl.text.trim()),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 联系客服弹窗：紫白渐变头 + 「联系邮箱」标签 + 只读邮箱框（带复制按钮）+ 关闭。
// 复制成功后 toast 提示，关闭按钮居中走 Pop。
// =============================================================================
class _ContactServiceDialog extends StatelessWidget {
  const _ContactServiceDialog({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return GradientHeaderDialog(
      title: '联系客服',
      titleFontSize: 24,
      titleFontWeight: FontWeight.w500,
      titlePaddingTop: 40,
      width: 428,
      contentPadding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '联系邮箱',
            style: TextStyle(
              color: Color(0xFF0B081A),
              fontSize: 14,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 8),
          _ReadonlyValueRow(
            value: email,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: email));
              if (!context.mounted) return;
              AppToast.showSuccess(context, '已复制邮箱');
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 380,
              child: _OutlineActionButton(
                label: '关闭',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 推荐给好友弹窗：紫白渐变头 + 推广链接展示 + 复制 / 关闭按钮。
// 链接来自 1.0 `APP_PROMO_URL`；点击复制写入剪贴板并 toast 提示。
// =============================================================================
class _RecommendDialog extends StatelessWidget {
  const _RecommendDialog();

  @override
  Widget build(BuildContext context) {
    return GradientHeaderDialog(
      title: '推荐给好友',
      titleFontSize: 24,
      titleFontWeight: FontWeight.w500,
      titlePaddingTop: 40,
      width: 428,
      contentPadding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '把音乐之路推荐给你的同学和朋友，一起在这里学习音乐～',
            style: TextStyle(
              color: Color(0xFF6D6B75),
              fontSize: 14,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '推广链接',
            style: TextStyle(
              color: Color(0xFF0B081A),
              fontSize: 14,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 8),
          _ReadonlyValueRow(
            value: _kAppPromoUrl,
            onCopy: () async {
              await Clipboard.setData(
                const ClipboardData(text: _kAppPromoUrl),
              );
              if (!context.mounted) return;
              AppToast.showSuccess(context, '链接已复制，快去发给好友吧');
            },
          ),
          const SizedBox(height: 24),
          AppDialogActionBar(
            cancelLabel: '关闭',
            confirmLabel: '复制链接',
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () async {
              await Clipboard.setData(
                const ClipboardData(text: _kAppPromoUrl),
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              AppToast.showSuccess(context, '链接已复制，快去发给好友吧');
            },
          ),
        ],
      ),
    );
  }
}

// 通用：单行文本输入框（兑换码 / 其他短输入）。
class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        autofocus: true,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: 16,
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF0B081A),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Color(0xFFCECED1),
            fontSize: 14,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF3F2F3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD9C7FF)),
          ),
        ),
      ),
    );
  }
}

// 通用：带复制按钮的只读行（用于显示邮箱 / 推广链接）。
class _ReadonlyValueRow extends StatelessWidget {
  const _ReadonlyValueRow({required this.value, required this.onCopy});

  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F2F3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF0B081A),
                fontSize: 14,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCopy,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: Color(0xFF8741FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 通用：白底 outline 单按钮（联系客服弹窗的「关闭」用）。
class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F2F3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59B5B5B5),
              blurRadius: 20,
              offset: Offset(0, 16),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Color(0xFF0B081A),
            fontSize: 16,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 12 / 16,
          ),
        ),
      ),
    );
  }
}
