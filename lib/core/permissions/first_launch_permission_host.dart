import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shell/ui/shell_layout.dart';
import '../providers/app_providers.dart';
import '../storage/app_storage.dart';
import '../widgets/scaled_dialog.dart';
import 'app_permission_service.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 首次启动时弹出说明并批量申请麦克风 / 相机 / 相册 / 通知等权限。
///
/// 挂在 [MaterialApp.builder] 最外层，保证任意登录态下只执行一次（由
/// [AppStorage.nativePermissionsPrimed] 持久化）。
class FirstLaunchPermissionHost extends ConsumerStatefulWidget {
  const FirstLaunchPermissionHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FirstLaunchPermissionHost> createState() =>
      _FirstLaunchPermissionHostState();
}

class _FirstLaunchPermissionHostState
    extends ConsumerState<FirstLaunchPermissionHost> {
  bool _started = false;
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        if (!_scheduled) {
          _scheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybePrime(layoutContext);
          });
        }
        final scale = DashboardScaleScope.fromSize(constraints.biggest);
        return DashboardScaleScope(
          data: scale,
          child: widget.child,
        );
      },
    );
  }

  Future<void> _maybePrime(BuildContext scopedContext) async {
    if (_started || !mounted) return;
    if (kIsWeb) return;
    final storage = ref.read(appStorageProvider);
    if (storage.nativePermissionsPrimed) return;
    _started = true;

    final proceed = await _showExplainerDialog(scopedContext);
    if (!mounted) return;

    if (proceed) {
      await const AppPermissionService().requestEssentialPermissions();
    }
    await storage.setNativePermissionsPrimed(true);
  }

  Future<bool> _showExplainerDialog(BuildContext scopedContext) async {
    final result = await showScaledDialog<bool>(
      context: scopedContext,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (dialogContext) {
        final ui = DashboardScaleScope.of(dialogContext).ui;
        return GradientHeaderDialog(
          title: '开启必要权限',
          titleFontSize: 24,
          titleFontWeight: FontWeight.w500,
          titlePaddingTop: 40,
          width: 428,
          contentPadding: EdgeInsets.fromLTRB(ui(40), ui(40), ui(40), ui(30)),
          actionBar: AppDialogActionBar(
            cancelLabel: '稍后再说',
            confirmLabel: '去开启',
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '为保障录音练习、课件上传、人脸采集、消息推送等功能正常使用，'
                '首次使用需授权以下系统权限：',
                style: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFF6D6B75),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.6,
                ),
              ),
              SizedBox(height: ui(16)),
              _PermissionBullet(
                ui: ui,
                icon: Icons.mic_rounded,
                text: '麦克风：录音、语音消息、调音与跟唱',
              ),
              SizedBox(height: ui(10)),
              _PermissionBullet(
                ui: ui,
                icon: Icons.photo_library_rounded,
                text: '相册：选择图片、课件与作业附件',
              ),
              SizedBox(height: ui(10)),
              _PermissionBullet(
                ui: ui,
                icon: Icons.photo_camera_rounded,
                text: '相机：拍摄人脸与现场照片',
              ),
              SizedBox(height: ui(10)),
              _PermissionBullet(
                ui: ui,
                icon: Icons.folder_open_rounded,
                text: '文件：从本地选择文档与音频上传',
              ),
              SizedBox(height: ui(10)),
              _PermissionBullet(
                ui: ui,
                icon: Icons.notifications_active_rounded,
                text: '通知：接收学校消息与审批提醒',
              ),
              SizedBox(height: ui(12)),
              Text(
                '点击「去开启」后，系统将依次弹出授权窗口，请按需允许。',
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFFB6B5BB),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }
}

class _PermissionBullet extends StatelessWidget {
  const _PermissionBullet({
    required this.ui,
    required this.icon,
    required this.text,
  });

  final double Function(double) ui;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: ui(28),
          height: ui(28),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F0FF),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: ui(16), color: const Color(0xFF8741FF)),
        ),
        SizedBox(width: ui(10)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: ui(4)),
            child: Text(
              text,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
