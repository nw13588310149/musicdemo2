import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../courseware/state/cloud_drive_controller.dart';
import '../../../courseware/ui/courseware_file_picker.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPurple = Color(0xFF8741FF);
const Color _kBg = Color(0xFFF5F6FA);
const Color _kBorder = Color(0xFFCECED1);
const Color _kHint = Color(0xFFB6B5BB);
const Color _kText = Color(0xFF0B081A);

/// 弹出「发布动态」对话框。返回 `true` 表示发布成功；其它情况返回 false /
/// null（用户主动取消）。
Future<bool?> showCirclePublishDialog(BuildContext context) {
  return showScaledDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CirclePublishDialog(),
  );
}

class _CirclePublishDialog extends ConsumerStatefulWidget {
  const _CirclePublishDialog();

  @override
  ConsumerState<_CirclePublishDialog> createState() =>
      _CirclePublishDialogState();
}

class _CirclePublishDialogState extends ConsumerState<_CirclePublishDialog> {
  PostMediaKind _kind = PostMediaKind.image;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();

  String? _fileName;
  Uint8List? _fileBytes;
  String? _filePath;
  int? _fileSize;

  /// 上传后端 OSS 后返回的可保存 path；null 表示尚未上传 / 上传中。
  String? _uploadedPath;
  double _uploadProgress = 0;
  bool _uploading = false;
  String? _uploadError;
  bool _submitting = false;

  // ─── 视频 / 音频帖 可选的封面图（图片帖直接复用主资源当封面，不展示这块）。
  String? _coverFileName;
  Uint8List? _coverFileBytes;
  String? _coverFilePath;
  int? _coverFileSize;
  String? _coverUploadedPath;
  double _coverUploadProgress = 0;
  bool _coverUploading = false;
  String? _coverUploadError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  /// 标题非空。
  bool get _hasTitle => _titleCtrl.text.trim().isNotEmpty;

  /// 文本内容是否非空。
  bool get _hasText => _textCtrl.text.trim().isNotEmpty;
  bool get _hasUploaded => _uploadedPath != null && _uploadedPath!.isNotEmpty;

  /// 视频 / 音频帖才需要展示「封面图」槽位；图片帖封面直接复用主资源。
  bool get _needsCover =>
      _kind == PostMediaKind.video || _kind == PostMediaKind.audio;

  /// 提交按钮可用性：
  /// - 标题、正文必填
  /// - 主资源必须上传完成
  /// - 主资源上传中、封面上传中、提交中 → 全部禁用
  /// - 封面**本身可选**：用户可以不传，也可以上传完再发布；只是不能在
  ///   "封面正在上传"的中间态点发布。
  bool get _canSubmit =>
      _hasTitle &&
      _hasText &&
      _hasUploaded &&
      !_uploading &&
      !_submitting &&
      !_coverUploading;

  void _onSwitchKind(PostMediaKind k) {
    if (_kind == k) return;
    setState(() {
      _kind = k;
      // 切换类型清掉已选文件，避免 "图片"+视频 这种语义错位。
      _resetFile();
      _resetCover();
    });
  }

  void _resetFile() {
    _fileName = null;
    _fileBytes = null;
    _filePath = null;
    _fileSize = null;
    _uploadedPath = null;
    _uploadProgress = 0;
    _uploading = false;
    _uploadError = null;
  }

  void _resetCover() {
    _coverFileName = null;
    _coverFileBytes = null;
    _coverFilePath = null;
    _coverFileSize = null;
    _coverUploadedPath = null;
    _coverUploadProgress = 0;
    _coverUploading = false;
    _coverUploadError = null;
  }

  /// 当前媒体类型是否合法的扩展名集合。
  Set<String> get _allowedExt {
    switch (_kind) {
      case PostMediaKind.image:
        return const {
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
          'heic',
          'heif',
        };
      case PostMediaKind.video:
        return const {'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'};
      case PostMediaKind.audio:
        return const {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'amr'};
    }
  }

  String get _kindLabel {
    switch (_kind) {
      case PostMediaKind.image:
        return '图片';
      case PostMediaKind.video:
        return '视频';
      case PostMediaKind.audio:
        return '音频';
    }
  }

  String _extOf(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return '';
    return name.substring(i + 1).toLowerCase();
  }

  Future<void> _pickFile() async {
    if (_uploading) return;
    final files = await pickCoursewareFiles(allowMultiple: false);
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    final ext = _extOf(f.name);
    if (!_allowedExt.contains(ext)) {
      AppToast.show(
        context,
        '当前为「$_kindLabel」类型，请选择 ${_allowedExt.join(' / ')} 格式',
      );
      return;
    }
    setState(() {
      _resetFile();
      _fileName = f.name;
      _fileBytes = f.bytes;
      _filePath = f.path;
      _fileSize = f.size;
    });
    unawaited(_startUpload());
  }

  Future<void> _startUpload() async {
    if (_uploading) return;
    final name = _fileName;
    if (name == null) return;
    final controller = ref.read(cloudDriveControllerProvider.notifier);

    setState(() {
      _uploading = true;
      _uploadError = null;
      _uploadProgress = 0;
      _uploadedPath = null;
    });

    void onProgress(double p) {
      if (!mounted) return;
      setState(() => _uploadProgress = p.clamp(0.0, 0.99));
    }

    try {
      final saved = (_filePath != null && _filePath!.trim().isNotEmpty)
          ? await controller.uploadFilePathRaw(
              filePath: _filePath!,
              filename: name,
              onProgress: onProgress,
            )
          : await controller.uploadFileRaw(
              bytes: _fileBytes ?? Uint8List(0),
              filename: name,
              onProgress: onProgress,
            );
      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
          _uploadError = '上传失败，请点击重试';
        });
        return;
      }
      setState(() {
        _uploadedPath = saved;
        _uploadProgress = 1.0;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
        _uploadError = '上传失败，请点击重试';
      });
    }
  }

  void _removeFile() {
    setState(_resetFile);
  }

  // ─── 封面图：仅图片格式；上传走与主资源相同的 cloudDrive 通道。

  static const Set<String> _coverAllowedExt = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  Future<void> _pickCover() async {
    if (_coverUploading) return;
    // 校圈封面只允许图片：移动端会直接拉起相册，避免再走文件管理。
    final files = await pickCoursewareFiles(
      allowMultiple: false,
      type: CoursewarePickType.image,
    );
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    final ext = _extOf(f.name);
    if (!_coverAllowedExt.contains(ext)) {
      AppToast.show(
        context,
        '封面仅支持 ${_coverAllowedExt.join(' / ')} 等图片格式',
      );
      return;
    }
    setState(() {
      _resetCover();
      _coverFileName = f.name;
      _coverFileBytes = f.bytes;
      _coverFilePath = f.path;
      _coverFileSize = f.size;
    });
    unawaited(_startCoverUpload());
  }

  Future<void> _startCoverUpload() async {
    if (_coverUploading) return;
    final name = _coverFileName;
    if (name == null) return;
    final controller = ref.read(cloudDriveControllerProvider.notifier);

    setState(() {
      _coverUploading = true;
      _coverUploadError = null;
      _coverUploadProgress = 0;
      _coverUploadedPath = null;
    });

    void onProgress(double p) {
      if (!mounted) return;
      setState(() => _coverUploadProgress = p.clamp(0.0, 0.99));
    }

    try {
      final saved = (_coverFilePath != null && _coverFilePath!.trim().isNotEmpty)
          ? await controller.uploadFilePathRaw(
              filePath: _coverFilePath!,
              filename: name,
              onProgress: onProgress,
            )
          : await controller.uploadFileRaw(
              bytes: _coverFileBytes ?? Uint8List(0),
              filename: name,
              onProgress: onProgress,
            );
      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        setState(() {
          _coverUploading = false;
          _coverUploadProgress = 0;
          _coverUploadError = '封面上传失败，点击重试';
        });
        return;
      }
      setState(() {
        _coverUploadedPath = saved;
        _coverUploadProgress = 1.0;
        _coverUploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coverUploading = false;
        _coverUploadProgress = 0;
        _coverUploadError = '封面上传失败，点击重试';
      });
    }
  }

  void _removeCover() {
    setState(_resetCover);
  }

  Future<void> _onSubmit() async {
    if (_submitting || !_canSubmit) return;
    setState(() => _submitting = true);
    final controller = ref.read(circleControllerProvider.notifier);
    final ok = await controller.publishPost(
      title: _titleCtrl.text.trim(),
      content: _textCtrl.text.trim(),
      kind: _kind,
      mediaUrl: _uploadedPath!,
      coverImg: _coverUploadedPath ?? '',
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _submitting = false);
      AppToast.show(context, '发布失败，请稍后再试');
      return;
    }
    AppToast.show(context, '动态已发布');
    Navigator.of(context).pop(true);
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GradientHeaderDialog(
      title: '发布动态',
      width: 460,
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: _submitting ? '发布中…' : '发布',
        confirmEnabled: _canSubmit,
        onCancel: _onCancel,
        onConfirm: _onSubmit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _KindTabs(current: _kind, onChanged: _onSwitchKind),
          const SizedBox(height: 16),
          _TitleField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _TextArea(
            controller: _textCtrl,
            hint: '说点什么...（必填）',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _MediaArea(
            kind: _kind,
            fileName: _fileName,
            fileSize: _fileSize,
            fileBytes: _fileBytes,
            uploading: _uploading,
            uploadProgress: _uploadProgress,
            uploadedPath: _uploadedPath,
            uploadError: _uploadError,
            onPick: _pickFile,
            onRemove: _removeFile,
            onRetry: _startUpload,
          ),
          if (_needsCover) ...[
            const SizedBox(height: 16),
            _CoverArea(
              fileName: _coverFileName,
              fileSize: _coverFileSize,
              fileBytes: _coverFileBytes,
              uploading: _coverUploading,
              uploadProgress: _coverUploadProgress,
              uploadedPath: _coverUploadedPath,
              uploadError: _coverUploadError,
              onPick: _pickCover,
              onRemove: _removeCover,
              onRetry: _startCoverUpload,
            ),
          ],
        ],
      ),
    );
  }
}

class _KindTabs extends StatelessWidget {
  const _KindTabs({required this.current, required this.onChanged});

  final PostMediaKind current;
  final ValueChanged<PostMediaKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          for (final k in PostMediaKind.values)
            Expanded(
              child: _KindTabItem(
                kind: k,
                selected: current == k,
                onTap: () => onChanged(k),
              ),
            ),
        ],
      ),
    );
  }
}

class _KindTabItem extends StatelessWidget {
  const _KindTabItem({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final PostMediaKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final IconData icon;
    final String label;
    switch (kind) {
      case PostMediaKind.image:
        icon = Icons.image_outlined;
        label = '图片+文字';
        break;
      case PostMediaKind.video:
        icon = Icons.videocam_outlined;
        label = '视频+文字';
        break;
      case PostMediaKind.audio:
        icon = Icons.music_note_outlined;
        label = '音频+文字';
        break;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: ui(2)),
        decoration: BoxDecoration(
          color: selected ? _kPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: ui(16),
              color: selected ? Colors.white : _kHint,
            ),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: selected ? Colors.white : _kHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: 1,
        maxLength: 40,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: _kText,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: '请输入标题（必填）',
          counterText: '',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(horizontal: ui(14)),
        ),
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(110),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(15),
        style: TextStyle(
          fontSize: ui(13),
          color: _kText,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 13,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: ui(13),
            color: _kHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 13,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(ui(14)),
        ),
      ),
    );
  }
}

class _MediaArea extends StatelessWidget {
  const _MediaArea({
    required this.kind,
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadedPath,
    required this.uploadError,
    required this.onPick,
    required this.onRemove,
    required this.onRetry,
  });

  final PostMediaKind kind;
  final String? fileName;
  final int? fileSize;
  final Uint8List? fileBytes;
  final bool uploading;
  final double uploadProgress;
  final String? uploadedPath;
  final String? uploadError;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (fileName == null) {
      return _PickPlaceholder(kind: kind, onTap: onPick);
    }
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MediaThumbnail(
            kind: kind,
            bytes: fileBytes,
            uploaded: uploadedPath != null,
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kText,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: ui(4)),
                _UploadStatusLine(
                  fileSize: fileSize,
                  uploading: uploading,
                  uploadProgress: uploadProgress,
                  uploaded: uploadedPath != null,
                  uploadError: uploadError,
                  onRetry: onRetry,
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: ui(32),
              minHeight: ui(32),
            ),
            onPressed: uploading ? null : onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: ui(18),
              color: uploading ? _kHint.withValues(alpha: 0.4) : _kHint,
            ),
            tooltip: '移除',
          ),
        ],
      ),
    );
  }
}

class _PickPlaceholder extends StatelessWidget {
  const _PickPlaceholder({required this.kind, required this.onTap});

  final PostMediaKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final IconData icon;
    final String label;
    final String hint;
    switch (kind) {
      case PostMediaKind.image:
        icon = Icons.add_photo_alternate_outlined;
        label = '点击上传图片';
        hint = '支持 jpg / png / gif / webp 等格式';
        break;
      case PostMediaKind.video:
        icon = Icons.video_call_outlined;
        label = '点击上传视频';
        hint = '支持 mp4 / mov / webm 等格式';
        break;
      case PostMediaKind.audio:
        icon = Icons.library_music_outlined;
        label = '点击上传音频';
        hint = '支持 mp3 / m4a / wav 等格式';
        break;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(140),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(
            color: _kBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ui(38), color: _kPurple),
            SizedBox(height: ui(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: _kText,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(4)),
            Text(
              hint,
              style: TextStyle(
                fontSize: ui(12),
                color: _kHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 视频 / 音频帖的「封面图」槽位（可选）。布局比 `_MediaArea` 更紧凑：
/// - 未选：一个左 80×80 picker + 右侧文字提示的整行卡片
/// - 已选：左 80×80 缩略图 + 右侧文件名 / 进度 / 状态 + 关闭按钮
class _CoverArea extends StatelessWidget {
  const _CoverArea({
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadedPath,
    required this.uploadError,
    required this.onPick,
    required this.onRemove,
    required this.onRetry,
  });

  final String? fileName;
  final int? fileSize;
  final Uint8List? fileBytes;
  final bool uploading;
  final double uploadProgress;
  final String? uploadedPath;
  final String? uploadError;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '封面图',
              style: TextStyle(
                fontSize: ui(13),
                color: _kText,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
            SizedBox(width: ui(6)),
            Text(
              '（可选，仅支持图片）',
              style: TextStyle(
                fontSize: ui(12),
                color: _kHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
        SizedBox(height: ui(8)),
        if (fileName == null)
          _CoverPickPlaceholder(onTap: onPick)
        else
          _CoverFilledRow(
            fileName: fileName!,
            fileSize: fileSize,
            fileBytes: fileBytes,
            uploading: uploading,
            uploadProgress: uploadProgress,
            uploadedPath: uploadedPath,
            uploadError: uploadError,
            onRemove: onRemove,
            onRetry: onRetry,
            onPick: onPick,
          ),
      ],
    );
  }
}

class _CoverPickPlaceholder extends StatelessWidget {
  const _CoverPickPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        padding: EdgeInsets.all(ui(12)),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: ui(64),
              height: ui(64),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFEAFF),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: ui(28),
                color: _kPurple,
              ),
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '点击上传封面',
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kText,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    '建议比例 16:9 / 1:1，jpg / png / webp 等',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFilledRow extends StatelessWidget {
  const _CoverFilledRow({
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadedPath,
    required this.uploadError,
    required this.onRemove,
    required this.onRetry,
    required this.onPick,
  });

  final String fileName;
  final int? fileSize;
  final Uint8List? fileBytes;
  final bool uploading;
  final double uploadProgress;
  final String? uploadedPath;
  final String? uploadError;
  final VoidCallback onRemove;
  final VoidCallback onRetry;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 封面是图片，所以总用 PostMediaKind.image 做缩略图。
          _MediaThumbnail(
            kind: PostMediaKind.image,
            bytes: fileBytes,
            uploaded: uploadedPath != null,
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kText,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: ui(4)),
                _UploadStatusLine(
                  fileSize: fileSize,
                  uploading: uploading,
                  uploadProgress: uploadProgress,
                  uploaded: uploadedPath != null,
                  uploadError: uploadError,
                  onRetry: onRetry,
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          // 已上传完时多给一个「重新选择」入口，方便用户换封面。
          if (uploadedPath != null && !uploading)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: ui(32),
                minHeight: ui(32),
              ),
              onPressed: onPick,
              icon: Icon(
                Icons.swap_horiz_rounded,
                size: ui(18),
                color: _kPurple,
              ),
              tooltip: '重新选择',
            ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: ui(32),
              minHeight: ui(32),
            ),
            onPressed: uploading ? null : onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: ui(18),
              color: uploading ? _kHint.withValues(alpha: 0.4) : _kHint,
            ),
            tooltip: '移除',
          ),
        ],
      ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    required this.kind,
    required this.bytes,
    required this.uploaded,
  });

  final PostMediaKind kind;
  final Uint8List? bytes;
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final size = ui(56);
    Widget child;
    if (kind == PostMediaKind.image && bytes != null && bytes!.isNotEmpty) {
      child = Image.memory(
        bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else {
      final IconData icon;
      switch (kind) {
        case PostMediaKind.image:
          icon = Icons.image_outlined;
          break;
        case PostMediaKind.video:
          icon = Icons.movie_creation_outlined;
          break;
        case PostMediaKind.audio:
          icon = Icons.audiotrack_outlined;
          break;
      }
      child = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: const Color(0xFFEFEAFF),
        child: Icon(icon, size: ui(28), color: _kPurple),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: child,
    );
  }
}

class _UploadStatusLine extends StatelessWidget {
  const _UploadStatusLine({
    required this.fileSize,
    required this.uploading,
    required this.uploadProgress,
    required this.uploaded,
    required this.uploadError,
    required this.onRetry,
  });

  final int? fileSize;
  final bool uploading;
  final double uploadProgress;
  final bool uploaded;
  final String? uploadError;
  final VoidCallback onRetry;

  String _humanSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (uploading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '上传中 ${(uploadProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: ui(12),
              color: _kHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(4)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(2)),
            child: LinearProgressIndicator(
              value: uploadProgress,
              minHeight: ui(3),
              backgroundColor: _kBg,
              valueColor: const AlwaysStoppedAnimation(_kPurple),
            ),
          ),
        ],
      );
    }
    if (uploadError != null) {
      return Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: ui(14),
            color: const Color(0xFFF04545),
          ),
          SizedBox(width: ui(4)),
          Expanded(
            child: Text(
              uploadError!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFFF04545),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(ui(4)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui(6),
                vertical: ui(2),
              ),
              child: Text(
                '重试',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kPurple,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (uploaded) {
      return Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: ui(14),
            color: _kPurple,
          ),
          SizedBox(width: ui(4)),
          Text(
            '已上传${_humanSize(fileSize).isEmpty ? '' : ' · '}${_humanSize(fileSize)}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ],
      );
    }
    return Text(
      _humanSize(fileSize),
      style: TextStyle(
        fontSize: ui(12),
        color: _kHint,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.2,
      ),
    );
  }
}
