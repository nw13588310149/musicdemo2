// =============================================================================
// 智慧校园「校长信箱 / 需求反馈」页（学生 / 教师 / 班主任共用）
//
// 入口：`controller.openPrincipalMailbox()` → mainView == principalMailbox。
// 返回：左上角返回 → onBack → controller.backToDashboard()。
//
// 通过右上角分段切换 compose / feedback 两种表单，外白卡 970×731 占满父容器。
//
// 1) compose（校长信箱 · 写信）—— 严格对齐 Figma 绝对坐标（卡内为基准）：
//    · header 0-82：white→#F9EDFF 渐变，左 32 返回 / 中标题 / 右分段
//    · 消息类型：96-168（label 28 + gap 12 + 32 chips）
//    · 匿名：    180-244（label 28 + gap 12 + 24 自定义 44×24 开关）
//    · 正文：    272-452（label 28 + gap 12 + 140 灰底 textarea，宽 938）
//    · 上传文件：468-532 右侧（242×64 描边 #CECED1）
//    · 提交按钮：618-670 居中（240×52 紫渐变 + 阴影 + 发送图标）
//    · 卡底 731；提交按钮距底 61
//
// 2) feedback（需求反馈）—— 同卡内坐标：
//    · header 标题改「需求反馈」+ 副标题「可将需要的资料反馈，工作人员第一时间上传」
//    · 需求类型：96-168（声乐类 / 器乐类 / 视频类，默认器乐类选中）
//    · 正文：    192-372（占位「请描述具体需求...」）
//    · 提交按钮：618-670 居中（文案「提交给音乐之路」）
//
// chips 强制 Row（mainAxisSize.min）保持单行；开关使用本文件自定义
// _AnonymousSwitch（44×24，紫底 #8741FF）以匹配 Figma 视觉。
//
// 文件上传：复用 courseware 的 `pickCoursewareFiles` + `cloudDriveControllerProvider`
// 提供的 `uploadFilePathRaw`（native 路径）/`uploadFileRaw`（web 字节）双通道
// 上传，进度回调直接驱动 _UploadTile 内 LinearProgressIndicator；成功后保存
// 后端返回的可保存 path（_AttachmentSlot.uploadedPath），提交时一并带出。
// =============================================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../courseware/state/cloud_drive_controller.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../../courseware/ui/courseware_url_opener.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/principal_mailbox_repository.dart';
import '../state/smart_campus_controller.dart';
import '../state/smart_campus_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderDash = Color(0xFFCECED1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPlaceholder = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);

enum _MailboxMode { compose, submitted, feedback }

enum _MsgKind { report, suggestion, other }

/// 「我提交的校长信箱」状态：
/// - sent     已发送（待校长查看 / 处理）
/// - replied  已回复
/// - closed   已关闭
enum _MailboxStatus { sent, replied, closed }

extension _MailboxStatusX on _MailboxStatus {
  /// 与后端 `status` 字段一致：0 / 1 / 2。
  int get apiCode {
    switch (this) {
      case _MailboxStatus.sent:
        return 0;
      case _MailboxStatus.replied:
        return 1;
      case _MailboxStatus.closed:
        return 2;
    }
  }

  String get label {
    switch (this) {
      case _MailboxStatus.sent:
        return '已发送';
      case _MailboxStatus.replied:
        return '已回复';
      case _MailboxStatus.closed:
        return '已关闭';
    }
  }

  Color get color {
    switch (this) {
      case _MailboxStatus.sent:
        return const Color(0xFF8741FF);
      case _MailboxStatus.replied:
        return const Color(0xFF35BD7C);
      case _MailboxStatus.closed:
        return const Color(0xFFB6B5BB);
    }
  }
}

extension _MsgKindX on _MsgKind {
  /// 后端 `msgType` 字段：举报 / 建议 / 其他。
  String get apiLabel {
    switch (this) {
      case _MsgKind.report:
        return '举报';
      case _MsgKind.suggestion:
        return '建议';
      case _MsgKind.other:
        return '其他';
    }
  }
}

/// 「我提交的校长信箱」单条记录（前端模型，对齐
/// `/principalMailboxList` 返回结构里我们关心的字段）。
class _MailboxRecord {
  const _MailboxRecord({
    required this.id,
    required this.msgType,
    required this.content,
    required this.status,
    required this.createTime,
    required this.isAnonymous,
    required this.attachments,
    required this.replyContent,
    required this.replyTime,
  });

  final String id;
  final String msgType;
  final String content;
  final _MailboxStatus status;
  final String createTime;
  final bool isAnonymous;

  /// 多个附件 URL，已按英文逗号拆分。
  final List<String> attachments;

  /// 校长回复正文；状态非「已回复」时通常为空。
  final String replyContent;
  final String replyTime;
}

class PrincipalMailboxView extends ConsumerStatefulWidget {
  const PrincipalMailboxView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<PrincipalMailboxView> createState() =>
      _PrincipalMailboxViewState();
}

class _PrincipalMailboxViewState extends ConsumerState<PrincipalMailboxView> {
  _MailboxMode _mode = _MailboxMode.compose;

  // compose
  _MsgKind _kind = _MsgKind.suggestion;
  bool _anonymous = true;
  final _bodyCtrl = TextEditingController();
  _AttachmentSlot? _attachment;
  bool _submitting = false;

  // feedback
  final _feedbackCtrl = TextEditingController();
  bool _feedbackSubmitting = false;
  bool _loadingFeedback = false;
  List<_FeedbackRecord> _feedbacks = const <_FeedbackRecord>[];

  // submitted（我提交的）
  _MailboxStatus _listStatus = _MailboxStatus.sent;
  bool _loadingList = false;
  List<_MailboxRecord> _records = const <_MailboxRecord>[];

  late final PrincipalMailboxRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(principalMailboxRepositoryProvider);
    // 一次性消费 SmartCampusController.openPrincipalMailbox(initialMode:) 设进
    // 来的初始分段：个人中心「意见反馈」会传入 feedback，让本页打开即落到
    // 「需求反馈」分段并拉取列表；之后立即 reset 回 compose，保证下次从侧栏
    // 进入仍是默认「写信」分段。
    final initialMode = ref
        .read(smartCampusControllerProvider)
        .principalMailboxInitialMode;
    if (initialMode == PrincipalMailboxInitialMode.feedback) {
      _mode = _MailboxMode.feedback;
    }
    // 必须延后到首帧之后再修改 SmartCampusController 状态，否则 Riverpod
    // 会抛 “Tried to modify a provider while the widget tree was building”：
    // initState 中 controller 自身正在通知本页 listener，这一帧内若再
    // setState 会触发递归 notifyListeners。
    if (initialMode != PrincipalMailboxInitialMode.compose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(smartCampusControllerProvider.notifier)
            .consumePrincipalMailboxInitialMode();
        if (initialMode == PrincipalMailboxInitialMode.feedback) {
          unawaited(_loadFeedback());
        }
      });
    }
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    AppToast.show(context, msg);
  }

  /// 切换顶部分段：
  /// - `submitted` 时按当前 `_listStatus` 拉一次校长信箱列表；
  /// - `feedback`  时拉一次「我提交的意见反馈」列表。
  void _switchMode(_MailboxMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == _MailboxMode.submitted) {
      unawaited(_loadList());
    } else if (mode == _MailboxMode.feedback) {
      unawaited(_loadFeedback());
    }
  }

  /// 切换「我提交的」状态过滤（已发送 / 已回复 / 已关闭），并重新拉一次。
  void _switchListStatus(_MailboxStatus status) {
    if (_listStatus == status && !_loadingList) return;
    setState(() {
      _listStatus = status;
      _records = const <_MailboxRecord>[];
    });
    unawaited(_loadList());
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final resp = await _repo.principalMailboxList(
        current: 1,
        size: 50,
        status: _listStatus.apiCode,
      );
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.msg.isEmpty ? '加载失败' : resp.msg);
        setState(() => _loadingList = false);
        return;
      }
      final parsed = _parseRecords(resp.data);
      setState(() {
        _records = parsed;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingList = false);
      _toast('网络异常，请稍后再试');
    }
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      _toast('请先填写正文');
      return;
    }
    final att = _attachment;
    if (att != null && att.isUploading) {
      _toast('附件上传中，请稍候');
      return;
    }
    if (att != null && att.hasError) {
      _toast('附件上传失败，请重试或移除');
      return;
    }

    setState(() => _submitting = true);
    try {
      final attachments = att?.uploadedPath ?? '';
      final resp = await _repo.principalMailboxSubmit(
        content: body,
        msgType: _kind.apiLabel,
        isAnonymous: _anonymous ? 1 : 0,
        attachments: attachments,
      );
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.msg.isEmpty ? '提交失败' : resp.msg);
        setState(() => _submitting = false);
        return;
      }
      // 清空草稿并切到「已提交」分段，让用户看到自己的新条目。
      _bodyCtrl.clear();
      setState(() {
        _attachment = null;
        _kind = _MsgKind.suggestion;
        _submitting = false;
        _mode = _MailboxMode.submitted;
        _listStatus = _MailboxStatus.sent;
      });
      _toast('已提交，校长会尽快查看');
      unawaited(_loadList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('网络异常，请稍后再试');
    }
  }

  Future<void> _loadFeedback() async {
    setState(() => _loadingFeedback = true);
    try {
      final resp = await _repo.feedbackList(current: 1, size: 50);
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.msg.isEmpty ? '加载失败' : resp.msg);
        setState(() => _loadingFeedback = false);
        return;
      }
      final parsed = _parseFeedbacks(resp.data);
      setState(() {
        _feedbacks = parsed;
        _loadingFeedback = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFeedback = false);
      _toast('网络异常，请稍后再试');
    }
  }

  Future<void> _onSubmitFeedback() async {
    if (_feedbackSubmitting) return;
    final body = _feedbackCtrl.text.trim();
    if (body.isEmpty) {
      _toast('请先填写反馈内容');
      return;
    }
    setState(() => _feedbackSubmitting = true);
    try {
      final resp = await _repo.feedbackSave(content: body);
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.msg.isEmpty ? '提交失败' : resp.msg);
        setState(() => _feedbackSubmitting = false);
        return;
      }
      _feedbackCtrl.clear();
      setState(() => _feedbackSubmitting = false);
      _toast('已提交反馈，感谢你的建议');
      unawaited(_loadFeedback());
    } catch (e) {
      if (!mounted) return;
      setState(() => _feedbackSubmitting = false);
      _toast('网络异常，请稍后再试');
    }
  }

  /// 点击上传卡片：
  /// - 若当前已有附件且处于失败态 → 重试；
  /// - 否则唤起系统文件选择器（单文件，覆盖之前的附件）。
  Future<void> _onUploadTap() async {
    final cur = _attachment;
    if (cur != null && cur.isUploading) return;
    if (cur != null && cur.hasError) {
      _retryAttachment(cur);
      return;
    }
    final files = await pickCoursewareFiles(allowMultiple: false);
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    final slot = _AttachmentSlot(
      name: f.name,
      bytes: f.bytes,
      path: f.path,
      size: f.size,
    );
    if (!slot.canUpload) {
      _toast('无法读取所选文件');
      return;
    }
    setState(() => _attachment = slot);
    unawaited(_startUploadAttachment(slot));
  }

  Future<void> _startUploadAttachment(_AttachmentSlot slot) async {
    void progress(double p) {
      if (!mounted || !identical(slot, _attachment)) return;
      setState(() => slot.progress = p.clamp(0.0, 0.99));
    }

    final controller = ref.read(cloudDriveControllerProvider.notifier);
    final path = slot.path?.trim();
    final saved = path != null && path.isNotEmpty
        ? await controller.uploadFilePathRaw(
            filePath: path,
            filename: slot.name,
            onProgress: progress,
          )
        : await controller.uploadFileRaw(
            bytes: slot.bytes ?? Uint8List(0),
            filename: slot.name,
            onProgress: progress,
          );

    if (!mounted || !identical(slot, _attachment)) return;
    setState(() {
      if (saved != null && saved.isNotEmpty) {
        slot.uploadedPath = saved;
        slot.progress = 1.0;
        slot.error = null;
      } else {
        slot.error = '上传失败，点击重试';
        slot.progress = 0.0;
      }
    });
  }

  void _removeAttachment() {
    setState(() => _attachment = null);
  }

  void _retryAttachment(_AttachmentSlot slot) {
    setState(() {
      slot.error = null;
      slot.progress = 0.0;
      slot.uploadedPath = null;
    });
    unawaited(_startUploadAttachment(slot));
  }

  Widget _buildBody() {
    switch (_mode) {
      case _MailboxMode.compose:
        return _ComposeForm(
          kind: _kind,
          onKindChanged: (k) => setState(() => _kind = k),
          anonymous: _anonymous,
          onAnonymousChanged: (v) => setState(() => _anonymous = v),
          bodyCtrl: _bodyCtrl,
          attachment: _attachment,
          onUploadTap: _onUploadTap,
          onRemoveAttachment: _removeAttachment,
          onSubmit: _onSubmit,
          submitting: _submitting,
        );
      case _MailboxMode.submitted:
        return _SubmittedList(
          status: _listStatus,
          onStatusChanged: _switchListStatus,
          loading: _loadingList,
          records: _records,
          onWriteNew: () => _switchMode(_MailboxMode.compose),
        );
      case _MailboxMode.feedback:
        return _FeedbackForm(
          bodyCtrl: _feedbackCtrl,
          onSubmit: _onSubmitFeedback,
          submitting: _feedbackSubmitting,
          loading: _loadingFeedback,
          records: _feedbacks,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _kPageBg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: _kCardBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderGradientBar(
                onBack: widget.onBack,
                mode: _mode,
                onCompose: () => _switchMode(_MailboxMode.compose),
                onSubmitted: () => _switchMode(_MailboxMode.submitted),
                onFeedback: () => _switchMode(_MailboxMode.feedback),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderGradientBar extends StatelessWidget {
  const _HeaderGradientBar({
    required this.onBack,
    required this.mode,
    required this.onCompose,
    required this.onSubmitted,
    required this.onFeedback,
  });

  final VoidCallback onBack;
  final _MailboxMode mode;
  final VoidCallback onCompose;
  final VoidCallback onSubmitted;
  final VoidCallback onFeedback;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final String title;
    final String subtitle;
    switch (mode) {
      case _MailboxMode.compose:
        title = '校长信箱';
        subtitle = '支持匿名、文字与附件上传';
        break;
      case _MailboxMode.submitted:
        title = '校长信箱';
        subtitle = '我提交的信件，可在下方按状态筛选';
        break;
      case _MailboxMode.feedback:
        title = '需求反馈';
        subtitle = '可将需要的资料反馈，工作人员第一时间上传';
        break;
    }
    return SizedBox(
      height: ui(82),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Colors.white, Color(0xFFF9EDFF)],
                ),
              ),
            ),
          ),
          Positioned(
            left: ui(20),
            top: ui(20),
            child: _BackChip(onTap: onBack),
          ),
          Positioned(
            top: ui(20),
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: ui(20),
            top: ui(25),
            child: _WriteFeedbackSegment(
              mode: mode,
              onCompose: onCompose,
              onSubmitted: onSubmitted,
              onFeedback: onFeedback,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Icon(
          Icons.chevron_left_rounded,
          size: ui(20),
          color: const Color(0xFF1C274C),
        ),
      ),
    );
  }
}

class _WriteFeedbackSegment extends StatelessWidget {
  const _WriteFeedbackSegment({
    required this.mode,
    required this.onCompose,
    required this.onSubmitted,
    required this.onFeedback,
  });

  final _MailboxMode mode;
  final VoidCallback onCompose;
  final VoidCallback onSubmitted;
  final VoidCallback onFeedback;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(32),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentItem(
            label: '写信',
            selected: mode == _MailboxMode.compose,
            weight: FontWeight.w500,
            onTap: onCompose,
          ),
          _SegmentItem(
            label: '已提交',
            selected: mode == _MailboxMode.submitted,
            weight: FontWeight.w500,
            onTap: onSubmitted,
          ),
          _SegmentItem(
            label: '反馈',
            selected: mode == _MailboxMode.feedback,
            weight: FontWeight.w400,
            onTap: onFeedback,
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.weight,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final FontWeight weight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: selected ? Colors.white : _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: weight,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ComposeForm extends StatelessWidget {
  const _ComposeForm({
    required this.kind,
    required this.onKindChanged,
    required this.anonymous,
    required this.onAnonymousChanged,
    required this.bodyCtrl,
    required this.attachment,
    required this.onUploadTap,
    required this.onRemoveAttachment,
    required this.onSubmit,
    required this.submitting,
  });

  final _MsgKind kind;
  final ValueChanged<_MsgKind> onKindChanged;
  final bool anonymous;
  final ValueChanged<bool> onAnonymousChanged;
  final TextEditingController bodyCtrl;
  final _AttachmentSlot? attachment;
  final VoidCallback onUploadTap;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('消息类型'),
          SizedBox(height: ui(12)),
          _MsgKindRow(kind: kind, onChanged: onKindChanged),
          SizedBox(height: ui(20)),
          const _SectionTitle('匿名'),
          SizedBox(height: ui(12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AnonymousSwitch(value: anonymous, onChanged: onAnonymousChanged),
              SizedBox(width: ui(8)),
              Text(
                '开启后发送者将显示为「匿名」',
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 20 / 13,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(20)),
          const _SectionTitle('正文'),
          SizedBox(height: ui(12)),
          _BodyField(controller: bodyCtrl, hint: '写给校长的内容...(支持举报、建议或其他诉求)'),
          SizedBox(height: ui(16)),
          Align(
            alignment: Alignment.centerRight,
            child: _UploadTile(
              slot: attachment,
              onTap: onUploadTap,
              onRemove: onRemoveAttachment,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: ui(61)),
                child: _SubmitButton(
                  label: submitting ? '提交中…' : '提交给校长',
                  onTap: submitting ? null : onSubmit,
                  busy: submitting,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 反馈 tab：上方为「我的反馈」列表（按时间倒序展示自己提交过的内容），
/// 下方为「写新反馈」输入区与提交按钮。后端只接收 `content` 字段，所以
/// 不再有「需求类型」选择。
class _FeedbackForm extends StatelessWidget {
  const _FeedbackForm({
    required this.bodyCtrl,
    required this.onSubmit,
    required this.submitting,
    required this.loading,
    required this.records,
  });

  final TextEditingController bodyCtrl;
  final VoidCallback onSubmit;
  final bool submitting;
  final bool loading;
  final List<_FeedbackRecord> records;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _SectionTitle('我的反馈'),
              const Spacer(),
              if (records.isNotEmpty)
                Text(
                  '共 ${records.length} 条',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(12)),
          Expanded(
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(_kPurple),
                      ),
                    ),
                  )
                : (records.isEmpty
                      ? const _FeedbackEmptyHint()
                      : ListView.separated(
                          padding: EdgeInsets.only(bottom: ui(8)),
                          itemBuilder: (_, i) =>
                              _FeedbackTile(record: records[i]),
                          separatorBuilder: (_, _) => SizedBox(height: ui(10)),
                          itemCount: records.length,
                        )),
          ),
          SizedBox(height: ui(12)),
          const _SectionTitle('写新反馈'),
          SizedBox(height: ui(8)),
          _BodyField(
            controller: bodyCtrl,
            hint: '请描述你的意见或建议（如功能改进、体验优化等）',
          ),
          SizedBox(height: ui(12)),
          Align(
            alignment: Alignment.center,
            child: _SubmitButton(
              label: submitting ? '提交中…' : '提交给音乐之路',
              onTap: submitting ? null : onSubmit,
              busy: submitting,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(16),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 28 / 16,
      ),
    );
  }
}

class _BodyField extends StatelessWidget {
  const _BodyField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(140),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(14),
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 12,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: ui(12),
            color: _kPlaceholder,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 12,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(ui(16)),
        ),
      ),
    );
  }
}

class _MsgKindRow extends StatelessWidget {
  const _MsgKindRow({required this.kind, required this.onChanged});

  final _MsgKind kind;
  final ValueChanged<_MsgKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KindChip(
          label: '举报',
          selected: kind == _MsgKind.report,
          onTap: () => onChanged(_MsgKind.report),
        ),
        SizedBox(width: ui(12)),
        _KindChip(
          label: '建议',
          selected: kind == _MsgKind.suggestion,
          onTap: () => onChanged(_MsgKind.suggestion),
        ),
        SizedBox(width: ui(12)),
        _KindChip(
          label: '其他',
          selected: kind == _MsgKind.other,
          onTap: () => onChanged(_MsgKind.other),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(24)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kTextDark : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: selected ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _AnonymousSwitch extends StatelessWidget {
  const _AnonymousSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: ui(44),
        height: ui(24),
        padding: EdgeInsets.all(ui(2)),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? _kPurple : _kTextHint.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(ui(999)),
        ),
        child: Container(
          width: ui(20),
          height: ui(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// 单文件附件状态：与 courseware 上传对话框中的 `_UploadSlot` 等价的最小子集。
/// `bytes`（web）/ `path`（native）二选一，由 `pickCoursewareFiles` 决定。
class _AttachmentSlot {
  _AttachmentSlot({required this.name, this.bytes, this.path, this.size});

  final String name;
  final Uint8List? bytes;
  final String? path;
  final int? size;

  /// 0.0–1.0；上传完成后被设为 1.0。
  double progress = 0.0;

  /// 上传成功后服务器返回的可保存路径（提交校长信箱时一并带出）。
  String? uploadedPath;

  /// 失败文案；null 表示无错误。
  String? error;

  bool get isDone => uploadedPath != null;
  bool get hasError => error != null;
  bool get isUploading => !isDone && !hasError;
  bool get canUpload =>
      (bytes != null && bytes!.isNotEmpty) ||
      (path != null && path!.trim().isNotEmpty);
}

/// 上传卡片。空状态显示「上传文件」；有附件后切换为「文件名 + 状态行」并在
/// 右上角露出 × 移除按钮。点击行为：
/// - 空：打开文件选择器
/// - 失败：触发重试
/// - 上传中：忽略
/// - 已完成：再次选择则覆盖原附件
class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.slot,
    required this.onTap,
    required this.onRemove,
  });

  final _AttachmentSlot? slot;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final s = slot;
    return SizedBox(
      width: ui(242),
      height: ui(64),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ui(12)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(16),
                  vertical: ui(10),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(12)),
                  border: Border.all(color: _kBorderDash),
                ),
                child: s == null ? _buildEmpty(ui) : _buildFilled(ui, s),
              ),
            ),
          ),
          if (s != null)
            Positioned(
              right: ui(4),
              top: ui(4),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(ui(4)),
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(14),
                    color: _kTextHint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(double Function(num) ui) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.upload_file_rounded,
          size: ui(18),
          color: const Color(0xFF1C274C),
        ),
        SizedBox(width: ui(4)),
        Text(
          '上传文件',
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFilled(double Function(num) ui, _AttachmentSlot s) {
    final Widget statusIcon;
    if (s.isUploading) {
      statusIcon = SizedBox(
        width: ui(14),
        height: ui(14),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_kPurple),
        ),
      );
    } else if (s.isDone) {
      statusIcon = Icon(
        Icons.check_circle_rounded,
        size: ui(16),
        color: _kPurple,
      );
    } else {
      statusIcon = Icon(
        Icons.error_outline_rounded,
        size: ui(16),
        color: const Color(0xFFF04545),
      );
    }

    final String statusLabel;
    final Color statusColor;
    if (s.isUploading) {
      statusLabel = '上传中 ${(s.progress * 100).toStringAsFixed(0)}%';
      statusColor = _kTextHint;
    } else if (s.isDone) {
      statusLabel = '已上传，可点击重新选择';
      statusColor = _kTextHint;
    } else {
      statusLabel = s.error ?? '上传失败，点击重试';
      statusColor = const Color(0xFFF04545);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            statusIcon,
            SizedBox(width: ui(6)),
            Expanded(
              child: Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: ui(14)), // 给右上 × 让位
          ],
        ),
        SizedBox(height: ui(4)),
        if (s.isUploading)
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(2)),
            child: LinearProgressIndicator(
              value: s.progress,
              minHeight: ui(3),
              backgroundColor: _kInnerGray,
              valueColor: const AlwaysStoppedAnimation(_kPurple),
            ),
          )
        else
          Text(
            statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(11),
              color: statusColor,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null || busy;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Opacity(
        opacity: disabled ? 0.7 : 1.0,
        child: Container(
          width: ui(240),
          height: ui(52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
            ),
            borderRadius: BorderRadius.circular(ui(12)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x59AD80FF),
                blurRadius: ui(20),
                offset: Offset(0, ui(16)),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: ui(18),
                  height: ui(18),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else
                Icon(Icons.send_rounded, color: Colors.white, size: ui(22)),
              SizedBox(width: ui(8)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(16),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 28 / 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 「我提交的」列表
// ============================================================================

class _SubmittedList extends StatelessWidget {
  const _SubmittedList({
    required this.status,
    required this.onStatusChanged,
    required this.loading,
    required this.records,
    required this.onWriteNew,
  });

  final _MailboxStatus status;
  final ValueChanged<_MailboxStatus> onStatusChanged;
  final bool loading;
  final List<_MailboxRecord> records;
  final VoidCallback onWriteNew;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusFilterRow(current: status, onChanged: onStatusChanged),
          SizedBox(height: ui(12)),
          Expanded(
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(_kPurple),
                      ),
                    ),
                  )
                : (records.isEmpty
                      ? _EmptyHint(status: status, onWriteNew: onWriteNew)
                      : ListView.separated(
                          padding: EdgeInsets.only(bottom: ui(8)),
                          itemBuilder: (_, i) =>
                              _MailboxRecordTile(record: records[i]),
                          separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                          itemCount: records.length,
                        )),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.current, required this.onChanged});

  final _MailboxStatus current;
  final ValueChanged<_MailboxStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (final s in _MailboxStatus.values) ...[
          _StatusFilterChip(
            label: s.label,
            color: s.color,
            selected: current == s,
            onTap: () => onChanged(s),
          ),
          if (s != _MailboxStatus.values.last) SizedBox(width: ui(12)),
        ],
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(20)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(13),
            color: selected ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.status, required this.onWriteNew});

  final _MailboxStatus status;
  final VoidCallback onWriteNew;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final String hint;
    switch (status) {
      case _MailboxStatus.sent:
        hint = '暂无已发送的信件';
        break;
      case _MailboxStatus.replied:
        hint = '暂无已回复的信件';
        break;
      case _MailboxStatus.closed:
        hint = '暂无已关闭的信件';
        break;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: ui(48),
            color: _kPlaceholder,
          ),
          SizedBox(height: ui(12)),
          Text(
            hint,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(20)),
          InkWell(
            onTap: onWriteNew,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(20),
                vertical: ui(10),
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                ),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Text(
                '写一封新信',
                style: TextStyle(
                  fontSize: ui(13),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条「我提交的校长信」卡片：状态徽章 + 类型 + 时间 + 正文 + 附件 / 回复折叠区。
class _MailboxRecordTile extends StatelessWidget {
  const _MailboxRecordTile({required this.record});

  final _MailboxRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasReply = record.replyContent.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(ui(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: record.status),
              SizedBox(width: ui(8)),
              if (record.msgType.isNotEmpty)
                _KindBadge(label: record.msgType),
              if (record.isAnonymous) ...[
                SizedBox(width: ui(8)),
                _KindBadge(
                  label: '匿名',
                  color: const Color(0xFFFFEFE3),
                  textColor: const Color(0xFFEC7D2F),
                ),
              ],
              const Spacer(),
              if (record.createTime.isNotEmpty)
                Text(
                  record.createTime,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          Text(
            record.content,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 22 / 14,
            ),
          ),
          if (record.attachments.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            Wrap(
              spacing: ui(8),
              runSpacing: ui(8),
              children: [
                for (var i = 0; i < record.attachments.length; i++)
                  _AttachmentChip(
                    url: record.attachments[i],
                    onTap: () => _previewAttachment(
                      context,
                      attachments: record.attachments,
                      index: i,
                      heroTagPrefix: 'mailbox_${record.id}',
                    ),
                  ),
              ],
            ),
          ],
          if (hasReply) ...[
            SizedBox(height: ui(12)),
            Container(
              padding: EdgeInsets.all(ui(12)),
              decoration: BoxDecoration(
                color: _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: ui(14),
                        color: _kPurple,
                      ),
                      SizedBox(width: ui(4)),
                      Text(
                        '校长回复',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kPurple,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (record.replyTime.isNotEmpty)
                        Text(
                          record.replyTime,
                          style: TextStyle(
                            fontSize: ui(11),
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    record.replyContent,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _MailboxStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(11),
          color: status.color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1.4,
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({
    required this.label,
    this.color = const Color(0xFFEFEAFF),
    this.textColor = _kPurple,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(2)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(11),
          color: textColor,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1.4,
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final name = url.split('/').isNotEmpty ? url.split('/').last : url;
    final isImage = _isImageUrl(url);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(6)),
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(6)),
          border: Border.all(color: _kBorderDash),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImage
                  ? Icons.image_outlined
                  : Icons.attach_file_rounded,
              size: ui(14),
              color: _kTextHint,
            ),
            SizedBox(width: ui(4)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(160)),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: ui(4)),
              Icon(
                isImage
                    ? Icons.zoom_out_map_rounded
                    : Icons.open_in_new_rounded,
                size: ui(12),
                color: _kPurple,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单击附件 chip 时的预览逻辑：
/// - 图片：聚合该条记录的全部图片附件，按当前 chip 在「图片子集」内的
///   顺序打开 [showImageGallery]，支持左右滑动切换；
/// - 非图片（pdf / doc / 其它）：调用 [openCoursewareUrl] 在新浏览器
///   标签页打开（web 端），其它平台暂为 no-op，给出 toast 提示。
///
/// `attachments` 为该条记录的全部附件 URL（已按英文逗号拆分），
/// `index` 为被点击 chip 在该数组中的位置。
void _previewAttachment(
  BuildContext context, {
  required List<String> attachments,
  required int index,
  required String heroTagPrefix,
}) {
  if (index < 0 || index >= attachments.length) return;
  final raw = attachments[index].trim();
  if (raw.isEmpty) return;
  final resolved = MediaUrl.resolve(raw);
  if (_isImageUrl(raw)) {
    final imageUrls = <String>[];
    int initialIndex = 0;
    for (var i = 0; i < attachments.length; i++) {
      final a = attachments[i].trim();
      if (a.isEmpty || !_isImageUrl(a)) continue;
      if (i == index) initialIndex = imageUrls.length;
      imageUrls.add(MediaUrl.resolve(a));
    }
    if (imageUrls.isEmpty) {
      AppToast.show(context, '附件无法预览');
      return;
    }
    showImageGallery(
      context,
      images: imageUrls,
      initialIndex: initialIndex,
      heroTagPrefix: heroTagPrefix,
    );
    return;
  }

  if (resolved.isEmpty) {
    AppToast.show(context, '附件链接无效');
    return;
  }
  openCoursewareUrl(resolved);
}

/// 仅按扩展名（最后一个 `.` 后的字符串）粗略判断是否为图片。覆盖常见
/// 的 jpg / jpeg / png / gif / webp / bmp / svg / heic 几种格式；带 query
/// 参数（如 `foo.jpg?x=1`）也能正确识别。
bool _isImageUrl(String url) {
  final value = url.trim().toLowerCase();
  if (value.isEmpty) return false;
  final cleaned = value.split('?').first.split('#').first;
  final dot = cleaned.lastIndexOf('.');
  if (dot < 0 || dot == cleaned.length - 1) return false;
  final ext = cleaned.substring(dot + 1);
  return const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'heic',
    'heif',
  }.contains(ext);
}

// ============================================================================
// 列表数据解析
// ============================================================================

/// 把后端 `principalMailboxList` 的 `data` 字段（可能是分页对象 / 数组 /
/// 嵌套 `records` 字段）安全解析为前端 [_MailboxRecord] 列表。
List<_MailboxRecord> _parseRecords(dynamic data) {
  final list = _asList(data);
  return list
      .map((e) {
        if (e is! Map) return null;
        final m = Map<String, dynamic>.from(e);
        final statusInt = _asInt(m['status']);
        final _MailboxStatus status;
        switch (statusInt) {
          case 1:
            status = _MailboxStatus.replied;
            break;
          case 2:
            status = _MailboxStatus.closed;
            break;
          default:
            status = _MailboxStatus.sent;
        }
        final attachmentsRaw = _pickString(m, const [
          'attachments',
          'attachment',
        ]);
        final attachments = attachmentsRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return _MailboxRecord(
          id: _pickString(m, const ['id', 'msgId', 'mailboxId']),
          msgType: _pickString(m, const ['msgType', 'type']),
          content: _pickString(m, const ['content', 'body']),
          status: status,
          createTime: _pickString(m, const [
            'createTime',
            'submitTime',
            'createdAt',
          ]),
          isAnonymous: _asInt(m['isAnonymous']) == 1,
          attachments: attachments,
          replyContent: _pickString(m, const [
            'replyContent',
            'reply',
            'replyMsg',
          ]),
          replyTime: _pickString(m, const ['replyTime', 'replyAt']),
        );
      })
      .whereType<_MailboxRecord>()
      .toList();
}

/// 兼容三种常见容器形态：直接数组 / `{records: [...]}` / `{list: [...]}` /
/// `{data: [...]}`。其它形态返回空数组。
List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in const ['records', 'list', 'rows', 'data', 'items']) {
      final v = data[key];
      if (v is List) return v;
    }
  }
  return const <dynamic>[];
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is bool) return v ? 1 : 0;
  return 0;
}

String _pickString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

// ============================================================================
// 「我的反馈」列表
// ============================================================================

/// 「我提交的意见反馈」单条记录。后端 `feedbackList` 仅返回正文 + 时间，
/// 无状态字段；如有「客服回复」字段也会一并取出展示。
class _FeedbackRecord {
  const _FeedbackRecord({
    required this.id,
    required this.content,
    required this.createTime,
    required this.replyContent,
    required this.replyTime,
  });

  final String id;
  final String content;
  final String createTime;

  /// 客服回复正文；空串表示尚未回复。
  final String replyContent;
  final String replyTime;
}

class _FeedbackEmptyHint extends StatelessWidget {
  const _FeedbackEmptyHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: ui(48),
            color: _kPlaceholder,
          ),
          SizedBox(height: ui(12)),
          Text(
            '暂无历史反馈，欢迎在下方提一条',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
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

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.record});

  final _FeedbackRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasReply = record.replyContent.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(10)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: hasReply
                      ? const Color(0xFF35BD7C).withValues(alpha: 0.12)
                      : _kPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  hasReply ? '已回复' : '已提交',
                  style: TextStyle(
                    fontSize: ui(11),
                    color: hasReply ? const Color(0xFF35BD7C) : _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              if (record.createTime.isNotEmpty)
                Text(
                  record.createTime,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(8)),
          Text(
            record.content,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
          if (hasReply) ...[
            SizedBox(height: ui(10)),
            Container(
              padding: EdgeInsets.all(ui(10)),
              decoration: BoxDecoration(
                color: _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: ui(14),
                        color: _kPurple,
                      ),
                      SizedBox(width: ui(4)),
                      Text(
                        '官方回复',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kPurple,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (record.replyTime.isNotEmpty)
                        Text(
                          record.replyTime,
                          style: TextStyle(
                            fontSize: ui(11),
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    record.replyContent,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 把后端 `feedbackList` 的 `data` 字段安全解析为前端 [_FeedbackRecord] 列表。
List<_FeedbackRecord> _parseFeedbacks(dynamic data) {
  final list = _asList(data);
  return list
      .map((e) {
        if (e is! Map) return null;
        final m = Map<String, dynamic>.from(e);
        return _FeedbackRecord(
          id: _pickString(m, const ['id', 'feedbackId']),
          content: _pickString(m, const ['content', 'body', 'feedback']),
          createTime: _pickString(m, const [
            'createTime',
            'submitTime',
            'createdAt',
          ]),
          replyContent: _pickString(m, const [
            'replyContent',
            'reply',
            'replyMsg',
          ]),
          replyTime: _pickString(m, const ['replyTime', 'replyAt']),
        );
      })
      .whereType<_FeedbackRecord>()
      .toList();
}
