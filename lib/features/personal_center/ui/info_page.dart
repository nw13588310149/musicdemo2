import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/avatar_picker.dart';
import '../state/personal_center_controller.dart';
import '../state/personal_center_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 个人信息页（迭代自 1.0 `pages/PersonalCenter/info.vue`）。
///
/// 视觉对齐 2.0 Figma：外层 #EFF3FC、白卡 padding 20、卡片内部头一行
/// 是返回按钮 + 居中"个人信息"标题，下面是字段列表（行高 64）。
/// 头像点击弹出 iOS 风格底部 ActionSheet，提供"从相册中选择 / 使用相机
/// 拍摄 / 取消"三个动作。
class InfoPage extends ConsumerWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalCenterControllerProvider);
    final controller = ref.read(personalCenterControllerProvider.notifier);

    return ShellPageSurface(
      padding: EdgeInsets.zero,
      color: const Color(0xFFEFF3FC),
      child: state.loading && state.user.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _InfoCard(state: state, controller: controller),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 返回按钮的目的地解析
// ─────────────────────────────────────────────────────────────────────

/// 个人信息页返回按钮的统一处理。
///
/// 入口有两条：
///   1. `personal_center` 页面里点"编辑资料"——通过 `Navigator.pushNamed`
///      进入 /info，此时栈里有上一页，[Navigator.canPop] 为 true，maybePop
///      就能回去。
///   2. 顶栏右上角的设置图标 / 头像下拉的"资料修改"——shell 走的是
///      `Navigator.pushReplacementNamed`，会把 /info 直接替换成当前唯一
///      路由，栈里没有上一页，maybePop 是 no-op，导致返回按钮"按了没反应"。
///
/// 解决：先试着 pop；pop 不动（场景 2）就把路由替换成
/// [RoutePaths.personalCenter]，把"资料修改 → 个人信息"这条入口路径的"返回"
/// 落到个人中心页，而不是留在原地。
void _backToPrev(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  navigator.pushReplacementNamed(RoutePaths.personalCenter);
}

// ─────────────────────────────────────────────────────────────────────
// 整张白卡：内含返回头 + 字段列表。
// ─────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.state, required this.controller});

  final PersonalCenterState state;
  final PersonalCenterController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 白卡占满 ShellPageSurface 整块容器：顶部 header 固定，下方列表可滚动。
    return Container(
      padding: EdgeInsets.all(ui(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(onBack: () => _backToPrev(context)),
          SizedBox(height: ui(10)),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: _InfoRows(state: state, controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Stack 让返回按钮"贴左 0"，标题"绝对居中"，与设计稿一致
    // （设计中标题 left 433 在 970 宽度内基本就是水平居中）。
    return SizedBox(
      height: ui(32),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _BackButton(onTap: onBack),
          ),
          Center(
            child: Text(
              '个人信息',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        child: Icon(
          Icons.chevron_left,
          size: ui(20),
          color: const Color(0xFF0B081A),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 字段行列表
// ─────────────────────────────────────────────────────────────────────

class _InfoRows extends StatelessWidget {
  const _InfoRows({required this.state, required this.controller});

  final PersonalCenterState state;
  final PersonalCenterController controller;

  @override
  Widget build(BuildContext context) {
    final user = state.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AvatarRow(
          avatarUrl: user['headUrl']?.toString(),
          onTap: () => _editAvatar(context, controller),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '昵称',
          value: user['nickname']?.toString() ?? '',
          onTap: () => _editNickname(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '姓名',
          value: user['realname']?.toString() ?? '',
          showChevron: false,
        ),
        const _RowDivider(),
        _InfoRow(
          title: '性别',
          value: user['gender']?.toString() ?? '',
          onTap: () => _editGender(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '生日',
          value: user['birthday']?.toString() ?? '',
          onTap: () => _editBirthday(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '身份',
          value: user['identity']?.toString() ?? '',
          showChevron: false,
        ),
        // 「实名认证」行临时隐藏：当前阶段没有正式的认证流程对接，整行连同
        // 跳转 [RoutePaths.verifie] 的入口一起去掉，后续接入审核流时再恢复。
        const _RowDivider(),
        _InfoRow(
          title: '所在地区',
          value: user['province']?.toString() ?? '',
          onTap: () => _editProvince(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '所在学校',
          value: user['school']?.toString() ?? '',
          onTap: () => _editSchool(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '个人简介',
          value: user['introduce']?.toString() ?? '',
          onTap: () => _editIntroduce(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '修改密码',
          value: '',
          onTap: () => _editPassword(context, controller),
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFF3F2F3));
}

// ─────────────────────────────────────────────────────────────────────
// 单条信息行：左标题 + 右值 + chevron
// ─────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: ui(64),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.0,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(16)),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF6D6B75),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: ui(20),
                color: const Color(0xFF0B081A),
              )
            else
              SizedBox(width: ui(20)),
          ],
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.avatarUrl, required this.onTap});

  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: ui(64),
        child: Row(
          children: <Widget>[
            Text(
              '头像',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.0,
              ),
            ),
            const Spacer(),
            _AvatarImage(url: avatarUrl, size: ui(44)),
            SizedBox(width: ui(8)),
            Icon(
              Icons.chevron_right,
              size: ui(20),
              color: const Color(0xFF0B081A),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    final isNetwork =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: Container(
          color: const Color(0xFFEFEEF3),
          alignment: Alignment.center,
          child: isNetwork
              ? Image.network(
                  trimmed,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person_rounded,
                    size: size * 0.6,
                    color: const Color(0xFF7E879C),
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: size * 0.6,
                  color: const Color(0xFF7E879C),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 编辑动作：每个字段一个；除了头像和密码外都是简单弹窗。
// ─────────────────────────────────────────────────────────────────────

Future<void> _editNickname(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改昵称',
    hintText: '请输入新昵称',
    initialValue: user['nickname']?.toString() ?? '',
    maxLength: 30,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'nickname': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editSchool(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改学校',
    hintText: '请输入学校名称',
    initialValue: user['school']?.toString() ?? '',
    maxLength: 60,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'school': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editIntroduce(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改个人简介',
    hintText: '请输入个人简介',
    initialValue: user['introduce']?.toString() ?? '',
    maxLength: 200,
    multiline: true,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'introduce': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editGender(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final selected = await showOptionsDialog(
    context: context,
    title: '请选择性别',
    options: const <String>['男', '女'],
    selected: user['gender']?.toString(),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'gender': selected,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editProvince(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final provinces = await controller.ensureProvinces();
  if (!context.mounted) return;
  if (provinces.isEmpty) {
    _toast(context, '加载省份失败，请稍后重试');
    return;
  }
  final selected = await showOptionsDialog(
    context: context,
    title: '请选择所在地区',
    options: provinces,
    selected: user['province']?.toString(),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'province': selected,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editBirthday(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final initial =
      _parseDate(user['birthday']?.toString()) ?? DateTime(2010, 1, 1);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1950, 1, 1),
    lastDate: DateTime(2014, 12, 31),
    helpText: '选择日期',
    cancelText: '取消',
    confirmText: '确定',
    builder: appPickerDialogTheme,
  );
  if (picked == null || !context.mounted) {
    return;
  }
  final formatted =
      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  final err = await controller.updateProfileFields(<String, dynamic>{
    'birthday': formatted,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final parts = raw.split('-');
    if (parts.length != 3) return DateTime.tryParse(raw);
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  } catch (_) {
    return DateTime.tryParse(raw);
  }
}

// ─────────────────────────────────────────────────────────────────────
// 头像编辑：iOS 风底部 ActionSheet → picker → upload → 写回 headUrl
// ─────────────────────────────────────────────────────────────────────

/// 头像来源，与 ActionSheet 上的两个选项一一对应。
enum _AvatarSource { gallery, camera }

Future<void> _editAvatar(
  BuildContext context,
  PersonalCenterController controller,
) async {
  final source = await _showAvatarSourceSheet(context);
  if (source == null || !context.mounted) return;

  final picked = await pickAvatarFile(useCamera: source == _AvatarSource.camera);
  if (!context.mounted) return;
  if (picked == null) {
    // 用户取消、相机权限被拒、或当前桌面 IO 不支持选择 — 都给一个友好提示。
    if (source == _AvatarSource.camera) {
      _toast(context, '当前平台暂不支持调用相机，请选择"从相册中选择"');
    }
    return;
  }

  // 上传 → 直接更新 headUrl，无需中间预览/确认弹窗。
  final upload = await controller.uploadAvatar(
    bytes: picked.bytes,
    filename: picked.filename,
  );
  if (!context.mounted) return;
  if (upload.error != null) {
    _toast(context, upload.error!);
    return;
  }
  final path = upload.path;
  if (path == null || path.isEmpty) {
    _toast(context, '上传失败');
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'headUrl': path,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

/// 显示 iOS 风格的"选择头像来源"底部 ActionSheet：
/// 主卡片包含标题 + 两个选项，下方独立一个"取消"卡片。
///
/// `showModalBottomSheet` 走 root navigator 的 overlay，构建出来的
/// widget 树不在 dashboard 的 [DashboardScaleScope] 里，直接 `of(ctx)`
/// 会触发 assert。这里在调用方先抓一份 scale data，再在 builder 里
/// 用 [DashboardScaleScope] 透传，sheet 内的 `ui(...)` 才能正常工作。
Future<_AvatarSource?> _showAvatarSourceSheet(BuildContext context) {
  final scale = DashboardScaleScope.of(context);
  return showModalBottomSheet<_AvatarSource>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    isScrollControlled: true,
    builder: (ctx) => DashboardScaleScope(
      data: scale,
      child: const _AvatarSourceSheet(),
    ),
  );
}

class _AvatarSourceSheet extends StatelessWidget {
  const _AvatarSourceSheet();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ui(20),
          ui(0),
          ui(20),
          ui(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // 主卡：标题 + 2 个动作
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: ui(8)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: ui(48),
                      child: Center(
                        child: Text(
                          '选择头像来源',
                          style: TextStyle(
                            color: const Color(0xFF0B081A),
                            fontSize: ui(14),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                            height: 16 / 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ui(12)),
                    _SheetItem(
                      label: '从相册中选择',
                      onTap: () => Navigator.of(context).pop<_AvatarSource>(
                        _AvatarSource.gallery,
                      ),
                    ),
                    const _SheetDivider(),
                    _SheetItem(
                      label: '使用相机拍摄',
                      onTap: () => Navigator.of(context).pop<_AvatarSource>(
                        _AvatarSource.camera,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ui(8)),
            // 取消卡：独立的一块
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: ui(56),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(16)),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: const Color(0xFF0B081A),
                      fontSize: ui(20),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 24 / 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: ui(56),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: ui(20),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 24 / 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0x33000000));
  }
}

// ─────────────────────────────────────────────────────────────────────
// 修改密码弹窗
// ─────────────────────────────────────────────────────────────────────

Future<void> _editPassword(
  BuildContext context,
  PersonalCenterController controller,
) async {
  await showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => _PasswordEditDialog(controller: controller),
  );
}

class _PasswordEditDialog extends StatefulWidget {
  const _PasswordEditDialog({required this.controller});

  final PersonalCenterController controller;

  @override
  State<_PasswordEditDialog> createState() => _PasswordEditDialogState();
}

class _PasswordEditDialogState extends State<_PasswordEditDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    final oldPwd = _oldCtrl.text.trim();
    final newPwd = _newCtrl.text.trim();
    final confirmPwd = _confirmCtrl.text.trim();
    if (oldPwd.isEmpty) {
      _toast(context, '请输入原密码');
      return;
    }
    if (newPwd.isEmpty) {
      _toast(context, '请输入新密码');
      return;
    }
    if (newPwd != confirmPwd) {
      _toast(context, '两次新密码不一致');
      return;
    }
    if (newPwd == oldPwd) {
      _toast(context, '新密码不能与旧密码相同');
      return;
    }
    setState(() => _submitting = true);
    final err = await widget.controller.changePassword(
      oldPassword: oldPwd,
      newPassword: newPwd,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      _toast(context, err);
      return;
    }
    Navigator.of(context).pop();
    _toast(context, '修改成功');
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: ui(32), vertical: ui(24)),
      child: Container(
        width: ui(420),
        padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '修改密码',
              style: TextStyle(
                fontSize: ui(18),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
              ),
            ),
            SizedBox(height: ui(20)),
            _PasswordField(controller: _oldCtrl, hint: '请输入原密码'),
            SizedBox(height: ui(12)),
            _PasswordField(controller: _newCtrl, hint: '请输入新密码'),
            SizedBox(height: ui(12)),
            _PasswordField(controller: _confirmCtrl, hint: '请再次输入新密码'),
            SizedBox(height: ui(24)),
            AppDialogActionBar(
              cancelLabel: '取消',
              confirmLabel: '确认',
              confirmEnabled: !_submitting,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(45),
      child: TextField(
        controller: controller,
        obscureText: true,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: const Color(0xFF0B081A),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 12 / 14,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(13),
            vertical: ui(12),
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFD9C7FF),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 工具：toast
// ─────────────────────────────────────────────────────────────────────

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  AppToast.show(context, message);
}
