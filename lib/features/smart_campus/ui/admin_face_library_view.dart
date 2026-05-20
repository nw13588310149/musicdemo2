// =============================================================================
// 管理员端「人脸库」独立页面
//
// 入口：admin 首页快捷区「人脸库」按钮 → controller.openFaceLibrary()
//      → mainView == faceLibrary + role == admin → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高，4deg #F9EDFF→white 渐变，圆角 16）：
//      - 左 12 返回按钮 32×32 白底 outline #F3F2F3。
//      - 居中标题 "人脸库" 16/600 + 副标题 12/#B6B5BB
//        「掌握本班住宿生归宿与晨检结果，协同处理补卡与异常跟进。」。
//      - 右上角分段控制 "人脸录入 / 底库记录"（32 高，#F5F6FA 容器，
//        激活段 #0B081A 黑底白字 12/500，未激活 #B6B5BB 12/400）。
//   2. 4 张统计卡（100 高，flex 1 1 0，间距 12，196deg 渐变白底，圆角 12）：
//      A. 「已生效」紫渐变 #E7DCFF→white 73%   值 12（人）。
//      B. 「待审核」橙渐变 #FFF0DC→white 73%   值 10。
//      C. 「已驳回」绿渐变 #DCFFE7→white 73%   值 2。
//      D. 「记录总数」红渐变 #FFE2DC→white 73% 值 1。
//      数值 32 Barlow / 标签 14/500 black。
//   3. 「录入人脸」分节标题 18/500。
//   4. 「人脸录入」tab：
//      a. 「录入人脸」分节标题 18/500。
//      b. 录入卡（顶部 21deg 白→#F9EDFF 渐变）：
//         · 3 步骤进度条（紫色圆形节点 + #F4F4FF 横线 + 文字标题）：
//           – 选择在籍学生  – 上传照片或使用摄像头截取正脸
//           – 勾选规范确认后提交，进入待审核状态
//         · 行政班 + 学生 双下拉（白底 #F5F6FA outline，下三角图标）。
//         · 双列：左 "上传人脸" 232 高占位（虚线圆 + 紫色描边人头 +
//           「上传证件式正面免冠照片」+ 上传照片 / 打开摄像头 双按钮）；
//           右 "采集规范" 232 高（3 张 86 高示例图，红角标 ❌×2 / 绿角标 ✅×1
//           + 底部黑半透明文字带 + 文字规范 14/400 行高 32）。
//         · 勾选行（12 方块复选 + 12/#B6B5BB 文案）。
//         · 48 高紫渐变 "提交人脸录入" 按钮。
//   5. 「底库记录」tab：
//      a. 顶部一行：左 4 段筛选 pill（白底 #F3F2F3 outline，激活段
//         #0B081A 黑底白字 14/500），右 324 宽搜索框（圆角 12，
//         占位「搜索姓名、学号、手机、宿舍、家长」）。
//      b. 970 宽白底 16 圆角表格：12 padding，946×40 灰底表头 +
//         60 高数据行（学生 / 班级 / 来源 / 状态 / 说明 / 操作）。
//         状态：已通过=#E4FFED/#12CE51；待审核=#FFEDD3/#FF6A00；
//         已驳回=#FEE4E8/#FF323C，padding 4×2 圆角 4。
//         操作：紫色 "通过" / 红色 "驳回"。
//         数据：`schoolUserFaceList` / `schoolUserFaceSum` / `schoolUserFaceDetail`
//         / `schoolUserFaceAudit`；录入：`schoolUserFaceSubmit` + 文件上传。
// =============================================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../courseware/state/cloud_drive_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import 'face_capture/face_image_picker.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kPanelBg = Color(0xFFF5F6FA);
const Color _kStepBg = Color(0xFFF4F4FF);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextBlack = Colors.black;
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kGreen = Color(0xFF12CE51);
const Color _kRed = Color(0xFFFF323C);
const Color _kBorderSoft = Color(0xFFF3F2F3);

// —— 行政班 / 学生 选项 ——————————————————————————————————————————
typedef _Option = ({String id, String name});

const _Option _kClassLoading = (id: '', name: '加载中…');
const _Option _kClassEmpty = (id: '', name: '暂无班级');
const _Option _kStudentLoading = (id: '', name: '加载中…');
const _Option _kStudentEmpty = (id: '', name: '暂无学生');

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
  }
  return fallback;
}

String? _pickNullableString(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
  }
  return null;
}

List<Map<String, dynamic>> _extractList(ApiResponse resp) {
  final raw = resp.data;
  final list = raw is List
      ? raw
      : (raw is Map && raw['records'] is List
            ? raw['records'] as List
            : (raw is Map && raw['list'] is List
                  ? raw['list'] as List
                  : (raw is Map && raw['data'] is List
                        ? raw['data'] as List
                        : const [])));
  return [
    for (final item in list)
      if (item is Map) item.cast<String, dynamic>(),
  ];
}

// —— 顶部分段 ————————————————————————————————————————————————————
enum _FaceTab { enroll, library }

extension _FaceTabX on _FaceTab {
  String get label => this == _FaceTab.enroll ? '人脸录入' : '底库记录';
}

// —— 底库记录：审核状态 ——————————————————————————————————————————
enum _LibraryStatus { effective, pending, rejected }

extension _LibraryStatusX on _LibraryStatus {
  String get label => switch (this) {
    _LibraryStatus.effective => '已通过',
    _LibraryStatus.pending => '待审核',
    _LibraryStatus.rejected => '已驳回',
  };

  /// 标签底色（取自 Figma）。
  Color get bg => switch (this) {
    _LibraryStatus.effective => const Color(0xFFE4FFED),
    _LibraryStatus.pending => const Color(0xFFFFEDD3),
    _LibraryStatus.rejected => const Color(0xFFFEE4E8),
  };

  /// 标签文字色 / 操作色。
  Color get fg => switch (this) {
    _LibraryStatus.effective => _kGreen,
    _LibraryStatus.pending => const Color(0xFFFF6A00),
    _LibraryStatus.rejected => _kRed,
  };
}

// —— 底库记录：筛选 ————————————————————————————————————————————
enum _LibraryFilter { all, effective, pending, rejected }

extension _LibraryFilterX on _LibraryFilter {
  String get label => switch (this) {
    _LibraryFilter.all => '全部',
    _LibraryFilter.effective => '已生效',
    _LibraryFilter.pending => '待审核',
    _LibraryFilter.rejected => '已驳回',
  };

  /// 对应 `schoolUserFaceList` 的 `status`：0 待审 / 1 通过 / 2 失败；全部不传。
  int? get apiStatus => switch (this) {
    _LibraryFilter.all => null,
    _LibraryFilter.pending => 0,
    _LibraryFilter.effective => 1,
    _LibraryFilter.rejected => 2,
  };
}

_LibraryStatus _parseFaceStatus(dynamic raw) {
  final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  return switch (n) {
    0 => _LibraryStatus.pending,
    1 => _LibraryStatus.effective,
    2 => _LibraryStatus.rejected,
    _ => _LibraryStatus.pending,
  };
}

String _formatApiDateTime(dynamic raw) {
  if (raw == null) return '—';
  final s = raw.toString().trim();
  if (s.isEmpty) return '—';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s.length > 16 ? s.substring(0, 16).replaceFirst('T', ' ') : s;
  String pad(int x) => x.toString().padLeft(2, '0');
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
      '${pad(dt.hour)}:${pad(dt.minute)}';
}

/// 学生名册缓存项，用于把 `userId` 解析为姓名 / 班级等展示字段。
class _StudentProfile {
  const _StudentProfile({
    required this.name,
    required this.studentNo,
    required this.className,
    required this.source,
    this.gender = '—',
    this.dorm = '—',
    this.parentContact = '—',
  });

  final String name;
  final String studentNo;
  final String className;
  final String source;
  final String gender;
  final String dorm;
  final String parentContact;

  factory _StudentProfile.fromJson(Map<String, dynamic> json) {
    final name = _pickString(json, [
      'realname',
      'realName',
      'nickname',
      'name',
      'studentName',
    ], '未命名');
    final studentNo = _pickString(json, [
      'no',
      'studentNo',
      'studentId',
      'stuNo',
      'code',
    ], '');
    final className = _pickString(json, [
      'className',
      'class',
      'gradeName',
      'classFullName',
    ], '—');
    final source = _pickString(json, [
      'majorName',
      'major',
      'subjectName',
      'subject',
    ], '—');
    final genderRaw = _pickString(json, ['gender', 'sex'], '');
    final gender = genderRaw == '1' || genderRaw == '男'
        ? '男'
        : (genderRaw == '2' || genderRaw == '女' ? '女' : (genderRaw.isEmpty ? '—' : genderRaw));
    final dorm = _pickString(json, [
      'dorm',
      'dormName',
      'roomName',
      'dormitory',
    ], '—');
    final parentContact = _pickString(json, [
      'parentPhone',
      'parentMobile',
      'guardianPhone',
      'phone',
      'mobile',
    ], '—');
    return _StudentProfile(
      name: name,
      studentNo: studentNo,
      className: className,
      source: source,
      gender: gender,
      dorm: dorm,
      parentContact: parentContact,
    );
  }
}

// —— 底库记录：单条记录 ————————————————————————————————————————
class _LibraryRecord {
  _LibraryRecord({
    required this.id,
    required this.userId,
    required this.name,
    required this.studentNo,
    required this.className,
    required this.source,
    required this.note,
    required this.status,
    this.gender = '—',
    this.dorm = '—',
    this.parentContact = '—',
    this.submittedAt = '—',
    this.auditedAt,
    this.auditedBy,
    this.headUrl = '',
    this.faceImgUrl = '',
  });

  final String id;
  final String userId;
  final String name;
  final String studentNo;
  final String className;

  /// 列表「来源」列：接口下发 `studentStatus`（在籍 / 休学…）。
  final String source;

  /// 说明（对应 Figma 「说明」列，审核意见 / reason）。
  final String note;
  final _LibraryStatus status;

  final String gender;
  final String dorm;
  final String parentContact;
  final String submittedAt;
  final String? auditedAt;
  final String? auditedBy;

  /// 学生档案头像 `headUrl`（列表缩略图用）。
  final String headUrl;

  /// 人脸采集照 `faceImg`（详情预览 / 放大用）。
  final String faceImgUrl;

  /// 详情接口字段较少时，用列表行数据补全展示字段（保留本条 status / reason 等）。
  _LibraryRecord enrichedWith(_LibraryRecord listRow) {
    String pick(String a, String b) => a.isNotEmpty && a != '—' ? a : b;
    return _LibraryRecord(
      id: id.isNotEmpty ? id : listRow.id,
      userId: userId.isNotEmpty ? userId : listRow.userId,
      name: pick(name, listRow.name),
      studentNo: pick(studentNo, listRow.studentNo),
      className: pick(className, listRow.className),
      source: pick(source, listRow.source),
      note: note.isNotEmpty && note != '—' ? note : listRow.note,
      status: status,
      gender: pick(gender, listRow.gender),
      dorm: pick(dorm, listRow.dorm),
      parentContact: pick(parentContact, listRow.parentContact),
      submittedAt: submittedAt != '—' ? submittedAt : listRow.submittedAt,
      auditedAt: auditedAt ?? listRow.auditedAt,
      auditedBy: auditedBy ?? listRow.auditedBy,
      headUrl: headUrl.isNotEmpty ? headUrl : listRow.headUrl,
      faceImgUrl: faceImgUrl.isNotEmpty ? faceImgUrl : listRow.faceImgUrl,
    );
  }

  factory _LibraryRecord.fromJson(
    Map<String, dynamic> json, {
    Map<String, _StudentProfile> profiles = const {},
  }) {
    final id = _pickString(json, ['id'], '');
    final userId = _pickString(json, ['userId'], '');
    final profile = profiles[userId];
    final faceImg = _pickString(json, ['faceImg'], '');
    final headUrl = _pickString(json, ['headUrl', 'headImg', 'avatar'], '');
    final reasonRaw = _pickNullableString(json, ['reason', 'remark', 'note']);
    final status = _parseFaceStatus(json['status']);
    final note = (reasonRaw == null || reasonRaw.isEmpty)
        ? switch (status) {
            _LibraryStatus.effective => '通过',
            _LibraryStatus.rejected => '已驳回',
            _ => '—',
          }
        : reasonRaw;
    final auditTime = json['auditTime'];
    final hasAudit =
        auditTime != null &&
        auditTime.toString().trim().isNotEmpty &&
        auditTime.toString().toLowerCase() != 'null';
    final realname = _pickNullableString(json, ['realname', 'realName']);
    final name = realname ??
        profile?.name ??
        _pickNullableString(json, ['nickname', 'name', 'studentName']) ??
        '未命名';
    final studentNo = _pickString(json, ['no', 'studentNo', 'stuNo'], profile?.studentNo ?? '');
    final className = _pickString(json, ['className', 'class'], profile?.className ?? '—');
    final studentStatus = _pickString(json, ['studentStatus', 'stuStatus'], '');
    final source = studentStatus.isNotEmpty
        ? studentStatus
        : (_pickString(json, ['majorName', 'major', 'source'], profile?.source ?? '—'));
    return _LibraryRecord(
      id: id,
      userId: userId,
      name: name,
      studentNo: studentNo.isNotEmpty ? studentNo : '—',
      className: className,
      source: source,
      note: note,
      status: status,
      gender: profile?.gender ?? '—',
      dorm: profile?.dorm ?? '—',
      parentContact: profile?.parentContact ?? '—',
      submittedAt: _formatApiDateTime(json['updateTime'] ?? json['createTime']),
      auditedAt: hasAudit ? _formatApiDateTime(auditTime) : null,
      auditedBy: hasAudit
          ? _pickString(json, ['auditUserName', 'auditUserId', 'auditUser'], '管理员')
          : null,
      headUrl: headUrl,
      faceImgUrl: faceImg,
    );
  }
}

// —— 顶级视图 ——————————————————————————————————————————————————————

class AdminFaceLibraryView extends ConsumerStatefulWidget {
  const AdminFaceLibraryView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminFaceLibraryView> createState() =>
      _AdminFaceLibraryViewState();
}

class _AdminFaceLibraryViewState extends ConsumerState<AdminFaceLibraryView> {
  _FaceTab _tab = _FaceTab.enroll;
  bool _confirmed = true;

  // —— 班级 ——————————————————————————————————————————————————————
  /// `null` = 加载中；空 List = 已加载但接口返回空。
  List<_Option>? _classes;
  _Option? _selectedClass;

  // —— 学生 ——————————————————————————————————————————————————————
  /// `null` = 尚未拉取（包含切换班级的 inflight 中间态）；空 List = 已拉取且空。
  List<_Option>? _students;
  _Option? _selectedStudent;
  int _studentLoadSeq = 0;

  // —— 已采集的人脸照片 ————————————————————————————————————————————
  Uint8List? _photoBytes;
  String? _photoName;
  bool _picking = false;

  bool _submitting = false;

  // —— 底库记录 tab —————————————————————————————————————————————
  _LibraryFilter _filter = _LibraryFilter.all;
  String _query = '';
  late final TextEditingController _searchCtrl = TextEditingController()
    ..addListener(_onSearchChanged);
  Timer? _searchDebounce;
  int _libraryLoadToken = 0;
  bool _loadingLibrary = false;
  List<_LibraryRecord> _libraryRecords = const [];

  // —— 统计卡 ————————————————————————————————————————————————————
  int _sumEffective = 0;
  int _sumPending = 0;
  int _sumRejected = 0;

  /// `userId` → 名册展示信息，列表 / 详情补全姓名班级用。
  Map<String, _StudentProfile> _studentProfiles = const {};

  int get _sumTotal => _sumEffective + _sumPending + _sumRejected;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    unawaited(_loadStudentProfiles());
    unawaited(_loadFaceSum());
    unawaited(_loadFaceList());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final v = _searchCtrl.text;
    if (v == _query) return;
    _query = v;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      unawaited(_loadFaceList());
    });
  }

  Future<void> _loadStudentProfiles() async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      final resp = await repo.studentList(size: 5000);
      if (!mounted || !resp.isSuccess) return;
      final list = _extractList(resp);
      final map = <String, _StudentProfile>{};
      for (final item in list) {
        final uid = _pickString(item, ['userId', 'id', 'studentId'], '');
        if (uid.isEmpty) continue;
        map[uid] = _StudentProfile.fromJson(item);
      }
      if (!mounted) return;
      setState(() => _studentProfiles = map);
    } catch (_) {
      // 名册补全失败不阻断主流程。
    }
  }

  Future<void> _loadFaceSum() async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      final resp = await repo.schoolUserFaceSum();
      if (!mounted || !resp.isSuccess || resp.data is! Map) return;
      final m = (resp.data as Map).cast<String, dynamic>();
      int n(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v?.toString() ?? '') ?? 0;
      }
      setState(() {
        _sumPending = n(m['status0Count']);
        _sumEffective = n(m['status1Count']);
        _sumRejected = n(m['status2Count']);
      });
    } catch (_) {
      // 统计失败保持 0。
    }
  }

  /// 提交 / 审核成功后刷新：统计卡（`schoolUserFaceSum`）+ 底库列表。
  Future<void> _refreshFacePageData() async {
    await Future.wait([_loadFaceSum(), _loadFaceList()]);
  }

  Future<void> _loadFaceList() async {
    final token = ++_libraryLoadToken;
    setState(() => _loadingLibrary = true);
    final repo = ref.read(adminRepositoryProvider);
    try {
      final resp = await repo.schoolUserFaceList(
        keyword: _query.trim().isEmpty ? null : _query.trim(),
        status: _filter.apiStatus,
        size: 500,
      );
      if (!mounted || token != _libraryLoadToken) return;
      if (!resp.isSuccess) {
        setState(() {
          _libraryRecords = const [];
          _loadingLibrary = false;
        });
        AppToast.show(context, '底库记录加载失败：${resp.msg}');
        return;
      }
      final list = _extractList(resp);
      final parsed = <_LibraryRecord>[];
      for (final item in list) {
        try {
          parsed.add(
            _LibraryRecord.fromJson(item, profiles: _studentProfiles),
          );
        } catch (_) {}
      }
      setState(() {
        _libraryRecords = parsed;
        _loadingLibrary = false;
      });
    } catch (e) {
      if (!mounted || token != _libraryLoadToken) return;
      setState(() {
        _libraryRecords = const [];
        _loadingLibrary = false;
      });
      AppToast.show(context, '底库记录加载失败：$e');
    }
  }

  Future<void> _onApproveRecord(_LibraryRecord r) async {
    if (r.status == _LibraryStatus.effective) {
      AppToast.show(context, '该记录已通过审核');
      return;
    }
    if (r.id.isEmpty) return;
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.schoolUserFaceAudit(
      id: r.id,
      status: 1,
      reason: '通过',
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, '审核失败：${resp.msg}');
      return;
    }
    AppToast.show(context, '已通过「${r.name}」的人脸录入');
    await _refreshFacePageData();
  }

  Future<void> _onRejectRecord(_LibraryRecord r) async {
    if (r.status == _LibraryStatus.rejected) {
      AppToast.show(context, '该记录已驳回');
      return;
    }
    if (r.id.isEmpty) return;
    final reason = await _promptRejectReason(context, r);
    if (!mounted || reason == null) return;
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.schoolUserFaceAudit(
      id: r.id,
      status: 2,
      reason: reason,
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, '驳回失败：${resp.msg}');
      return;
    }
    AppToast.show(context, '已驳回「${r.name}」的人脸录入');
    await _refreshFacePageData();
  }

  /// 驳回意见弹窗：与请假 / 课表审批等页面同款 [GradientHeaderDialog]。
  Future<String?> _promptRejectReason(
    BuildContext context,
    _LibraryRecord record,
  ) async {
    final controller = TextEditingController();
    final result = await showScaledDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (dialogContext) {
        final ui = DashboardScaleScope.of(dialogContext).ui;
        return GradientHeaderDialog(
          title: '驳回申请',
          titleFontSize: 24,
          titleFontWeight: FontWeight.w500,
          titlePaddingTop: 40,
          width: 428,
          contentPadding: EdgeInsets.fromLTRB(ui(40), ui(40), ui(40), ui(30)),
          actionBar: AppDialogActionBar(
            confirmLabel: '确认',
            cancelLabel: '取消',
            onCancel: () => Navigator.of(dialogContext).pop(),
            onConfirm: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                AppToast.show(dialogContext, '请填写驳回说明');
                return;
              }
              Navigator.of(dialogContext).pop(text);
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.name}（${record.studentNo}）· ${record.className}',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 20 / 16,
                ),
              ),
              SizedBox(height: ui(15)),
              Text(
                '驳回说明',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 20 / 14,
                ),
              ),
              SizedBox(height: ui(15)),
              Container(
                height: ui(80),
                padding: EdgeInsets.symmetric(
                  horizontal: ui(16),
                  vertical: ui(12),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: _kPurple,
                  cursorWidth: 1.5,
                  cursorHeight: ui(16),
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 14,
                  ),
                  decoration: InputDecoration(
                    hintText: '请输入驳回原因，如光线偏暗、非正脸等',
                    hintStyle: TextStyle(
                      fontSize: ui(14),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 14,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _showRecordDetail(_LibraryRecord r) async {
    if (r.id.isEmpty) {
      await showScaledDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.18),
        builder: (ctx) => GradientHeaderDialog(
          title: '人脸录入详情',
          width: 460,
          child: _RecordDetailBody(record: r),
        ),
      );
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    _LibraryRecord detail = r;
    try {
      final resp = await repo.schoolUserFaceDetail(r.id);
      if (resp.isSuccess && resp.data is Map) {
        detail = _LibraryRecord.fromJson(
          (resp.data as Map).cast<String, dynamic>(),
          profiles: _studentProfiles,
        ).enrichedWith(r);
      }
    } catch (_) {
      // 详情失败仍展示列表行数据。
    }
    if (!mounted) return;
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => GradientHeaderDialog(
        title: '人脸录入详情',
        width: 460,
        child: _RecordDetailBody(record: detail),
      ),
    );
  }

  Future<void> _loadClasses() async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      final resp = await repo.classList();
      if (!mounted) return;
      if (!resp.isSuccess) {
        setState(() => _classes = const []);
        AppToast.show(context, '班级加载失败：${resp.msg}');
        return;
      }
      final list = _extractList(resp);
      final options = <_Option>[
        for (var i = 0; i < list.length; i++)
          (
            id: _pickString(list[i], ['id', 'classId', 'cId'], 'srv-$i'),
            name: _pickString(list[i], [
              'className',
              'class',
              'name',
              'classFullName',
              'fullName',
            ], '未命名班级'),
          ),
      ];
      setState(() {
        _classes = options;
        if (options.isNotEmpty) {
          _selectedClass = options.first;
        } else {
          _selectedClass = null;
        }
      });
      if (_selectedClass != null) {
        unawaited(_loadStudents(_selectedClass!.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _classes = const []);
      AppToast.show(context, '班级加载失败：$e');
    }
  }

  Future<void> _loadStudents(String classId) async {
    final seq = ++_studentLoadSeq;
    setState(() {
      _students = null;
      _selectedStudent = null;
    });
    final repo = ref.read(adminRepositoryProvider);
    try {
      final resp = await repo.studentList(classId: classId);
      if (!mounted || seq != _studentLoadSeq) return;
      if (!resp.isSuccess) {
        setState(() => _students = const []);
        AppToast.show(context, '学生加载失败：${resp.msg}');
        return;
      }
      final list = _extractList(resp);
      final options = <_Option>[
        for (var i = 0; i < list.length; i++)
          (
            id: _pickString(list[i], ['userId', 'id', 'studentId'], 'srv-$i'),
            name: _pickString(list[i], [
              'realname',
              'realName',
              'nickname',
              'name',
              'studentName',
              'userName',
            ], '未命名学生'),
          ),
      ];
      setState(() {
        _students = options;
        _selectedStudent = options.isNotEmpty ? options.first : null;
      });
    } catch (e) {
      if (!mounted || seq != _studentLoadSeq) return;
      setState(() => _students = const []);
      AppToast.show(context, '学生加载失败：$e');
    }
  }

  void _onSelectClass(_Option v) {
    if (v.id.isEmpty) return;
    if (v.id == _selectedClass?.id) return;
    setState(() => _selectedClass = v);
    unawaited(_loadStudents(v.id));
  }

  void _onSelectStudent(_Option v) {
    if (v.id.isEmpty) return;
    setState(() => _selectedStudent = v);
  }

  Future<void> _onUploadPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await pickFacePhotoFromFile(context);
      if (!mounted) return;
      if (picked == null) return;
      setState(() {
        _photoBytes = picked.bytes;
        _photoName = picked.name;
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _onOpenCamera() async {
    if (_picking) return;
    if (!isCameraCaptureSupported) {
      AppToast.show(context, '当前平台暂不支持摄像头采集，请改用上传照片');
      return;
    }
    setState(() => _picking = true);
    try {
      final shot = await captureFacePhotoFromCamera(context);
      if (!mounted) return;
      if (shot == null) return;
      setState(() {
        _photoBytes = shot.bytes;
        _photoName = shot.name;
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _onClearPhoto() {
    setState(() {
      _photoBytes = null;
      _photoName = null;
    });
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
            _Banner(
              onBack: widget.onBack,
              currentTab: _tab,
              onSelectTab: (t) {
                setState(() => _tab = t);
                if (t == _FaceTab.library) {
                  unawaited(_loadFaceSum());
                  unawaited(_loadFaceList());
                }
              },
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              effective: _sumEffective,
              reviewing: _sumPending,
              rejected: _sumRejected,
              total: _sumTotal,
            ),
            SizedBox(height: ui(24)),
            if (_tab == _FaceTab.enroll) ...[
              Text(
                '录入人脸',
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              SizedBox(height: ui(12)),
              _EnrollCard(
                classOptions: _classes,
                selectedClass: _selectedClass,
                studentOptions: _students,
                selectedStudent: _selectedStudent,
                confirmed: _confirmed,
                submitting: _submitting,
                photoBytes: _photoBytes,
                photoName: _photoName,
                picking: _picking,
                onSelectClass: _onSelectClass,
                onSelectStudent: _onSelectStudent,
                onToggleConfirm: () =>
                    setState(() => _confirmed = !_confirmed),
                onUploadPhoto: _onUploadPhoto,
                onOpenCamera: _onOpenCamera,
                onClearPhoto: _onClearPhoto,
                onSubmit: _onSubmit,
              ),
            ] else ...[
              _LibraryControlBar(
                filter: _filter,
                onSelectFilter: (f) {
                  setState(() => _filter = f);
                  unawaited(_loadFaceList());
                },
                searchCtrl: _searchCtrl,
              ),
              SizedBox(height: ui(12)),
              _LibraryTable(
                records: _libraryRecords,
                loading: _loadingLibrary,
                onTapRecord: _showRecordDetail,
                onApprove: _onApproveRecord,
                onReject: _onRejectRecord,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (_selectedClass == null) {
      AppToast.show(context, '请先选择行政班');
      return;
    }
    if (_selectedStudent == null || _selectedStudent!.id.isEmpty) {
      AppToast.show(context, '请先选择学生');
      return;
    }
    if (_photoBytes == null) {
      AppToast.show(context, '请先上传或拍摄一张人脸照片');
      return;
    }
    if (!_confirmed) {
      AppToast.show(context, '请勾选采集规范确认后再提交');
      return;
    }
    setState(() => _submitting = true);
    try {
      final uploader = ref.read(cloudDriveControllerProvider.notifier);
      final faceImg = await uploader.uploadFileRaw(
        bytes: _photoBytes!,
        filename: _photoName ?? 'face.jpg',
      );
      if (!mounted) return;
      if (faceImg == null || faceImg.isEmpty) {
        AppToast.show(context, '人脸照片上传失败，请重试');
        return;
      }
      final repo = ref.read(adminRepositoryProvider);
      final resp = await repo.schoolUserFaceSubmit(
        faceImg: faceImg,
        userId: _selectedStudent!.id,
      );
      if (!mounted) return;
      if (!resp.isSuccess) {
        AppToast.show(context, '提交失败：${resp.msg}');
        return;
      }
      setState(() {
        _photoBytes = null;
        _photoName = null;
        _confirmed = true;
      });
      AppToast.show(
        context,
        '已提交「${_selectedStudent!.name}」的人脸录入，进入待审核',
      );
      await _refreshFacePageData();
    } catch (e) {
      if (mounted) AppToast.show(context, '提交失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// —— Banner（含右上角分段）————————————————————————————————————————————

class _Banner extends StatelessWidget {
  const _Banner({
    required this.onBack,
    required this.currentTab,
    required this.onSelectTab,
  });

  final VoidCallback onBack;
  final _FaceTab currentTab;
  final ValueChanged<_FaceTab> onSelectTab;

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
              padding: EdgeInsets.symmetric(horizontal: ui(180)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '人脸库',
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
                    '掌握本班住宿生归宿与晨检结果，协同处理补卡与异常跟进。',
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
          Positioned(
            right: ui(12),
            top: ui(15),
            child: _BannerSegment(
              currentTab: currentTab,
              onSelectTab: onSelectTab,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerSegment extends StatelessWidget {
  const _BannerSegment({required this.currentTab, required this.onSelectTab});

  final _FaceTab currentTab;
  final ValueChanged<_FaceTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      // minHeight 而不是 fixed height：避免中文字 height:1 被切顶。
      constraints: BoxConstraints(minHeight: ui(32)),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _FaceTab.values)
            InkWell(
              onTap: () => onSelectTab(t),
              borderRadius: BorderRadius.circular(ui(6)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(16),
                  vertical: ui(7),
                ),
                decoration: BoxDecoration(
                  color: t == currentTab ? _kTextDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
                child: Text(
                  t.label,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: t == currentTab ? Colors.white : _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: t == currentTab
                        ? AppFont.w500
                        : AppFont.w400,
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

// —— 4 张统计卡 ——————————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.effective,
    required this.reviewing,
    required this.rejected,
    required this.total,
  });

  final int effective;
  final int reviewing;
  final int rejected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '已生效',
            value: effective,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFE7DCFF), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.verified_rounded,
            iconColor: const Color(0xFF1CD097),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '待审核',
            value: reviewing,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFF0DC), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.history_toggle_off_rounded,
            iconColor: _kPurple,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '已驳回',
            value: rejected,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFDCFFE7), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.cancel_rounded,
            iconColor: _kPurple,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '记录总数',
            value: total,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFE2DC), Colors.white],
              stops: [0.0, 0.73],
            ),
            icon: Icons.assignment_rounded,
            iconColor: _kPurple,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.gradient,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final int value;
  final LinearGradient gradient;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: ui(12)),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: ui(32),
                    color: _kTextDark,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: ui(16),
            top: ui(34),
            child: Container(
              width: ui(32),
              height: ui(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: ui(20), color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}

// —— 录入人脸卡 ——————————————————————————————————————————————————————

class _EnrollCard extends StatelessWidget {
  const _EnrollCard({
    required this.classOptions,
    required this.selectedClass,
    required this.studentOptions,
    required this.selectedStudent,
    required this.confirmed,
    required this.submitting,
    required this.photoBytes,
    required this.photoName,
    required this.picking,
    required this.onSelectClass,
    required this.onSelectStudent,
    required this.onToggleConfirm,
    required this.onUploadPhoto,
    required this.onOpenCamera,
    required this.onClearPhoto,
    required this.onSubmit,
  });

  final List<_Option>? classOptions;
  final _Option? selectedClass;
  final List<_Option>? studentOptions;
  final _Option? selectedStudent;
  final bool confirmed;
  final bool submitting;
  final Uint8List? photoBytes;
  final String? photoName;
  final bool picking;
  final ValueChanged<_Option> onSelectClass;
  final ValueChanged<_Option> onSelectStudent;
  final VoidCallback onToggleConfirm;
  final VoidCallback onUploadPhoto;
  final VoidCallback onOpenCamera;
  final VoidCallback onClearPhoto;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepBar(),
          SizedBox(height: ui(8)),
          _PickerRow(
            classOptions: classOptions,
            selectedClass: selectedClass,
            studentOptions: studentOptions,
            selectedStudent: selectedStudent,
            onSelectClass: onSelectClass,
            onSelectStudent: onSelectStudent,
          ),
          SizedBox(height: ui(8)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _UploadPanel(
                    photoBytes: photoBytes,
                    photoName: photoName,
                    busy: picking,
                    onUploadPhoto: onUploadPhoto,
                    onOpenCamera: onOpenCamera,
                    onClearPhoto: onClearPhoto,
                  ),
                ),
                SizedBox(width: ui(8)),
                const Expanded(child: _StandardPanel()),
              ],
            ),
          ),
          SizedBox(height: ui(8)),
          _ConfirmRow(
            confirmed: confirmed,
            onToggle: onToggleConfirm,
          ),
          SizedBox(height: ui(8)),
          _SubmitButton(onTap: submitting ? null : onSubmit),
        ],
      ),
    );
  }
}

// —— 步骤进度条 ————————————————————————————————————————————————————

class _StepBar extends StatelessWidget {
  const _StepBar();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(60),
      child: Row(
        children: [
          Expanded(
            child: _StepCell(
              iconAsset: 'assets/images/face/1.png',
              label: '选择在籍学生',
              isFirst: true,
              isLast: false,
            ),
          ),
          Expanded(
            child: _StepCell(
              iconAsset: 'assets/images/face/2.png',
              label: '上传照片或使用摄像头截取正脸',
              isFirst: false,
              isLast: false,
            ),
          ),
          Expanded(
            child: _StepCell(
              iconAsset: 'assets/images/face/3.png',
              label: '勾选规范确认后提交，进入待审核状态',
              isFirst: false,
              isLast: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCell extends StatelessWidget {
  const _StepCell({
    required this.iconAsset,
    required this.label,
    required this.isFirst,
    required this.isLast,
  });

  final String iconAsset;
  final String label;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(top: ui(9)),
          child: Container(
            height: ui(12),
            decoration: BoxDecoration(
              color: _kStepBg,
              borderRadius: BorderRadius.horizontal(
                left: isFirst ? Radius.circular(ui(12)) : Radius.zero,
                right: isLast ? Radius.circular(ui(12)) : Radius.zero,
              ),
            ),
          ),
        ),
        Column(
          children: [
            Container(
              width: ui(28),
              height: ui(28),
              decoration: BoxDecoration(
                color: _kPurple,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                iconAsset,
                width: ui(16),
                height: ui(16),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: ui(4)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// —— 行政班 / 学生 双下拉 ——————————————————————————————————————————

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.classOptions,
    required this.selectedClass,
    required this.studentOptions,
    required this.selectedStudent,
    required this.onSelectClass,
    required this.onSelectStudent,
  });

  final List<_Option>? classOptions;
  final _Option? selectedClass;
  final List<_Option>? studentOptions;
  final _Option? selectedStudent;
  final ValueChanged<_Option> onSelectClass;
  final ValueChanged<_Option> onSelectStudent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PickerLabel(text: '行政班'),
        SizedBox(width: ui(8)),
        Expanded(
          child: _OptionPicker(
            options: classOptions,
            value: selectedClass,
            placeholderLoading: _kClassLoading,
            placeholderEmpty: _kClassEmpty,
            onChanged: onSelectClass,
          ),
        ),
        SizedBox(width: ui(8)),
        _PickerLabel(text: '学生'),
        SizedBox(width: ui(8)),
        Expanded(
          child: _SearchableOptionPicker(
            options: studentOptions,
            value: selectedStudent,
            placeholderLoading: _kStudentLoading,
            placeholderEmpty: _kStudentEmpty,
            searchHint: '搜索学生姓名',
            onChanged: onSelectStudent,
          ),
        ),
      ],
    );
  }
}

/// 围绕 [PopupSelectorField] 的薄封装：
/// - `options == null` → 显示「加载中…」灰态字段，禁用点击；
/// - `options!.isEmpty` → 显示「暂无…」灰态字段，禁用点击；
/// - 否则正常调起统一下拉浮层。
class _OptionPicker extends StatelessWidget {
  const _OptionPicker({
    required this.options,
    required this.value,
    required this.placeholderLoading,
    required this.placeholderEmpty,
    required this.onChanged,
  });

  final List<_Option>? options;
  final _Option? value;
  final _Option placeholderLoading;
  final _Option placeholderEmpty;
  final ValueChanged<_Option> onChanged;

  @override
  Widget build(BuildContext context) {
    final list = options;
    if (list == null) {
      return _DisabledPickerField(text: placeholderLoading.name);
    }
    if (list.isEmpty) {
      return _DisabledPickerField(text: placeholderEmpty.name);
    }
    final current = value ?? list.first;
    return PopupSelectorField<_Option>(
      value: current,
      items: list,
      itemLabel: (o) => o.name,
      onChanged: onChanged,
    );
  }
}

/// 带本地模糊搜索的下拉（学生名册）：触发器样式与 [_OptionPicker] 一致，
/// 弹层内顶部搜索框 + 过滤后的选项列表。
class _SearchableOptionPicker extends StatelessWidget {
  const _SearchableOptionPicker({
    required this.options,
    required this.value,
    required this.placeholderLoading,
    required this.placeholderEmpty,
    required this.searchHint,
    required this.onChanged,
  });

  final List<_Option>? options;
  final _Option? value;
  final _Option placeholderLoading;
  final _Option placeholderEmpty;
  final String searchHint;
  final ValueChanged<_Option> onChanged;

  Future<void> _openPicker(BuildContext context, List<_Option> list) async {
    final current = value ?? list.first;
    final picked = await showScaledDialog<_Option>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => _SearchableOptionPickerDialog(
        items: list,
        value: current,
        searchHint: searchHint,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final list = options;
    if (list == null) {
      return _DisabledPickerField(text: placeholderLoading.name);
    }
    if (list.isEmpty) {
      return _DisabledPickerField(text: placeholderEmpty.name);
    }
    final current = value ?? list.first;
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: () => _openPicker(context, list),
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kPanelBg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                current.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: ui(18),
              color: _kTextDark,
            ),
          ],
        ),
      ),
    );
  }
}

bool _optionMatchesQuery(_Option option, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return option.name.toLowerCase().contains(q) ||
      option.id.contains(q);
}

class _SearchableOptionPickerDialog extends StatefulWidget {
  const _SearchableOptionPickerDialog({
    required this.items,
    required this.value,
    required this.searchHint,
  });

  final List<_Option> items;
  final _Option value;
  final String searchHint;

  @override
  State<_SearchableOptionPickerDialog> createState() =>
      _SearchableOptionPickerDialogState();
}

class _SearchableOptionPickerDialogState
    extends State<_SearchableOptionPickerDialog> {
  late final TextEditingController _searchCtrl = TextEditingController()
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Option> get _filtered => widget.items
      .where((o) => _optionMatchesQuery(o, _searchCtrl.text))
      .toList();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filtered = _filtered;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: ui(32), vertical: ui(24)),
      child: Container(
        width: ui(420),
        constraints: BoxConstraints(maxHeight: ui(420)),
        padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(16)),
          border: Border.all(color: _kBorderSoft),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0F0B081A),
              blurRadius: ui(24),
              offset: Offset(0, ui(8)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: ui(44),
              padding: EdgeInsets.symmetric(horizontal: ui(12)),
              decoration: BoxDecoration(
                color: _kPanelBg,
                borderRadius: BorderRadius.circular(ui(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: ui(18),
                    color: const Color(0xFFC6C6C6),
                  ),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      cursorColor: _kPurple,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: widget.searchHint,
                        hintStyle: TextStyle(
                          fontSize: ui(14),
                          color: _kTextHint,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                        ),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchCtrl.clear(),
                      child: Icon(
                        Icons.cancel_rounded,
                        size: ui(16),
                        color: const Color(0xFFC6C6C6),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: ui(12)),
            if (filtered.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: ui(32)),
                child: Center(
                  child: Text(
                    '无匹配学生',
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in filtered)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(item),
                          child: Container(
                            height: ui(40),
                            padding: EdgeInsets.symmetric(horizontal: ui(8)),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: ui(14),
                                      color: item.id == widget.value.id
                                          ? _kPurple
                                          : _kTextDark,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: item.id == widget.value.id
                                          ? AppFont.w500
                                          : AppFont.w400,
                                      height: 20 / 14,
                                    ),
                                  ),
                                ),
                                if (item.id == widget.value.id)
                                  Icon(
                                    Icons.check_rounded,
                                    size: ui(16),
                                    color: _kPurple,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DisabledPickerField extends StatelessWidget {
  const _DisabledPickerField({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPanelBg, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 14,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: ui(16),
            color: _kTextHint,
          ),
        ],
      ),
    );
  }
}

class _PickerLabel extends StatelessWidget {
  const _PickerLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextBlack,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 20 / 14,
      ),
    );
  }
}

// —— 上传人脸面板 ——————————————————————————————————————————————————

class _UploadPanel extends StatelessWidget {
  const _UploadPanel({
    required this.photoBytes,
    required this.photoName,
    required this.busy,
    required this.onUploadPhoto,
    required this.onOpenCamera,
    required this.onClearPhoto,
  });

  final Uint8List? photoBytes;
  final String? photoName;
  final bool busy;
  final VoidCallback onUploadPhoto;
  final VoidCallback onOpenCamera;
  final VoidCallback onClearPhoto;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasPhoto = photoBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '上传人脸',
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextBlack,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
        SizedBox(height: ui(4)),
        Container(
          height: ui(232),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kPanelBg, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: ui(20)),
              hasPhoto
                  ? _PhotoPreview(
                      bytes: photoBytes!,
                      name: photoName,
                      onClear: busy ? null : onClearPhoto,
                    )
                  : Image.asset(
                      'assets/images/face/4.png',
                      width: ui(100),
                      height: ui(100),
                      fit: BoxFit.contain,
                    ),
              SizedBox(height: ui(8)),
              if (!hasPhoto)
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 20 / 12,
                    ),
                    children: const [
                      TextSpan(text: '上传证件式'),
                      TextSpan(
                        text: '正面免冠',
                        style: TextStyle(color: _kPurple),
                      ),
                      TextSpan(text: '照片'),
                    ],
                  ),
                )
              else
                Text(
                  busy ? '处理中…' : '已选择 ${_friendlyName(photoName)}',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: busy ? _kTextHint : _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 12,
                  ),
                ),
              SizedBox(height: ui(12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _UploadActionButton(
                    iconAsset: 'assets/images/face/5.png',
                    label: hasPhoto ? '重新上传' : '上传照片',
                    onTap: busy ? null : onUploadPhoto,
                  ),
                  SizedBox(width: ui(12)),
                  _UploadActionButton(
                    iconAsset: 'assets/images/face/6.png',
                    label: hasPhoto ? '重新拍摄' : '打开摄像头',
                    onTap: busy ? null : onOpenCamera,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _friendlyName(String? name) {
    if (name == null || name.isEmpty) return '已上传照片';
    if (name.length <= 20) return name;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot) : '';
    final head = (dot >= 0 ? name.substring(0, dot) : name);
    final cut = head.length > 16 ? '${head.substring(0, 16)}…' : head;
    return '$cut$ext';
  }
}

/// 已采集照片的预览缩略图：100x100 圆角，右上角带一个 ✕ 清除按钮。
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.bytes, this.name, this.onClear});

  final Uint8List bytes;
  final String? name;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(108),
      height: ui(108),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(8)),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          if (onClear != null)
            Positioned(
              top: ui(2),
              right: ui(2),
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  width: ui(20),
                  height: ui(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(14),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadActionButton extends StatelessWidget {
  const _UploadActionButton({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Container(
          width: ui(180),
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(10)),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                iconAsset,
                width: ui(16),
                height: ui(16),
                fit: BoxFit.contain,
              ),
              SizedBox(width: ui(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 24 / 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// —— 采集规范面板 ——————————————————————————————————————————————————

class _StandardPanel extends StatelessWidget {
  const _StandardPanel();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '采集规范',
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextBlack,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
        SizedBox(height: ui(4)),
        Container(
          height: ui(232),
          padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(14)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kPanelBg, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SampleThumb(
                      asset: 'assets/images/face/7.png',
                      caption: '背景过于复杂',
                      ok: false,
                    ),
                  ),
                  SizedBox(width: ui(10)),
                  Expanded(
                    child: _SampleThumb(
                      asset: 'assets/images/face/8.png',
                      caption: '光线不足/过曝',
                      ok: false,
                    ),
                  ),
                  SizedBox(width: ui(10)),
                  Expanded(
                    child: _SampleThumb(
                      asset: 'assets/images/face/9.png',
                      caption: '双眼平视，双耳可见',
                      ok: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(10)),
              Text(
                '背景尽量简洁，避免强逆光或过暗。\n双眼平视镜头，双耳可见为宜。\n手机拍摄建议与他人协助，保持手臂稳定。',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 32 / 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SampleThumb extends StatelessWidget {
  const _SampleThumb({
    required this.asset,
    required this.caption,
    required this.ok,
  });

  final String asset;
  final String caption;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        height: ui(86),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _kPanelBg),
            Image.asset(asset, fit: BoxFit.cover),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: ui(17),
                height: ui(16),
                decoration: BoxDecoration(
                  color: ok ? _kGreen : _kRed,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(ui(8)),
                    bottomLeft: Radius.circular(ui(4)),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  ok ? Icons.check_rounded : Icons.close_rounded,
                  size: ui(10),
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: ui(20),
                color: const Color(0x80000000),
                alignment: Alignment.center,
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
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
      ),
    );
  }
}

// —— 勾选行 ————————————————————————————————————————————————————————

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.confirmed, required this.onToggle});

  final bool confirmed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(ui(4)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ui(2)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ui(12),
              height: ui(12),
              decoration: BoxDecoration(
                color: confirmed ? _kPurple : Colors.white,
                borderRadius: BorderRadius.circular(ui(4)),
                border: Border.all(
                  color: confirmed ? _kPurple : _kBorderHair,
                  width: 1,
                ),
              ),
              child: confirmed
                  ? Icon(Icons.check_rounded, size: ui(8), color: Colors.white)
                  : null,
            ),
            SizedBox(width: ui(4)),
            Text(
              '确认照片为本人正脸，光线均匀，无墨镜、口罩等遮挡，且未过度美颜失真。',
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
    );
  }
}

// —— 提交按钮 ————————————————————————————————————————————————————

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          height: ui(48),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
            ),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          alignment: Alignment.center,
          child: Text(
            '提交人脸录入',
            style: TextStyle(
              fontSize: ui(14),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 24 / 14,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 底库记录 tab
// =============================================================================
//
// 视觉（Figma 970）：
//   1. 顶部一行：左侧 4 段筛选 pill（白底 #F3F2F3 outline，激活段 #0B081A
//      黑底白字 14/500，未激活 #6D6B75 14/500），右侧 324×44 白底搜索框
//      （圆角 12，搜索图标 + 14/#D1D1D1 占位文）。
//   2. 主体表格：970 宽白底 16 圆角，12 padding：
//      - 表头：946×40 #F9FAFB 灰底 + 8 圆角，列头 13/#71717A 行高 20。
//      - 行：60 高，1px #F3F2F3 下边线，列 flex 1 1 0（操作列 150 固定）：
//        · 学生：32 圆头像 + 名字 13/500 + 学号 11/#6D6B75
//        · 班级 / 来源 / 说明：13/400 #0B081A
//        · 状态：胶囊（已通过=#E4FFED/#12CE51；待审核=#FFEDD3/#FF6A00；
//          已驳回=#FEE4E8/#FF323C），padding 4×2，圆角 4，12/400。
//        · 操作：左 "通过" 紫色 #8741FF / 右 "驳回" 红色 #FF323C，13/400。
//      - 空集时显示居中提示。
//
// 数据：当前版本走本地 demo 数据。`/app/school/v2/manager/faceList` 接入后
// 改为 ConsumerState 内调用 `adminRepository.faceList(...)` 即可（参考
// `_loadStudents` 模式）。

class _LibraryControlBar extends StatelessWidget {
  const _LibraryControlBar({
    required this.filter,
    required this.onSelectFilter,
    required this.searchCtrl,
  });

  final _LibraryFilter filter;
  final ValueChanged<_LibraryFilter> onSelectFilter;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LibraryFilterPills(filter: filter, onSelect: onSelectFilter),
        const Spacer(),
        SizedBox(
          width: ui(324),
          child: _LibrarySearchInput(controller: searchCtrl),
        ),
      ],
    );
  }
}

class _LibraryFilterPills extends StatelessWidget {
  const _LibraryFilterPills({required this.filter, required this.onSelect});

  final _LibraryFilter filter;
  final ValueChanged<_LibraryFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in _LibraryFilter.values)
            Padding(
              padding: EdgeInsets.only(
                right: f == _LibraryFilter.values.last ? 0 : ui(4),
              ),
              child: _LibraryFilterPill(
                label: f.label,
                active: f == filter,
                onTap: () => onSelect(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryFilterPill extends StatelessWidget {
  const _LibraryFilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _LibrarySearchInput extends StatelessWidget {
  const _LibrarySearchInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: ui(18),
            color: const Color(0xFFC6C6C6),
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '搜索姓名、学号、手机、宿舍、家长',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFFD1D1D1),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
              },
              child: Icon(
                Icons.cancel_rounded,
                size: ui(16),
                color: const Color(0xFFC6C6C6),
              ),
            ),
        ],
      ),
    );
  }
}

// —— 表格 ————————————————————————————————————————————————————————

class _LibraryTable extends StatelessWidget {
  const _LibraryTable({
    required this.records,
    required this.loading,
    required this.onTapRecord,
    required this.onApprove,
    required this.onReject,
  });

  final List<_LibraryRecord> records;
  final bool loading;
  final ValueChanged<_LibraryRecord> onTapRecord;
  final ValueChanged<_LibraryRecord> onApprove;
  final ValueChanged<_LibraryRecord> onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LibraryTableHeader(),
          if (loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: ui(48)),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (records.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: ui(60)),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: ui(40),
                      color: _kTextHint,
                    ),
                    SizedBox(height: ui(8)),
                    Text(
                      '暂无符合条件的记录',
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
              ),
            )
          else
            for (final r in records)
              _LibraryRow(
                record: r,
                onTap: () => onTapRecord(r),
                onApprove: () => onApprove(r),
                onReject: () => onReject(r),
              ),
        ],
      ),
    );
  }
}

/// 列表学生头像：优先 `headUrl`，其次 `faceImg`。
Widget _buildFaceThumb({
  required double size,
  required String name,
  String headUrl = '',
  String faceImgUrl = '',
  double fontSize = 13,
  VoidCallback? onTap,
}) {
  final initial = name.isNotEmpty ? name.characters.first : '';
  final raw = headUrl.isNotEmpty ? headUrl : faceImgUrl;
  final url = raw.isEmpty ? '' : MediaUrl.resolve(raw);
  Widget child;
  if (url.isNotEmpty) {
    child = ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _faceInitialAvatar(size, initial, fontSize),
      ),
    );
  } else {
    child = _faceInitialAvatar(size, initial, fontSize);
  }
  if (onTap == null) return child;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: child,
  );
}

void _previewFaceImage(BuildContext context, String rawUrl, {String? heroTag}) {
  if (rawUrl.isEmpty) return;
  final url = MediaUrl.resolve(rawUrl);
  if (url.isEmpty) return;
  showImageGallery(
    context,
    images: [url],
    heroTagPrefix: heroTag ?? 'face_library',
  );
}

Widget _faceInitialAvatar(double size, String initial, double fontSize) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFEDE6FF),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        fontSize: fontSize,
        color: _kPurple,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.0,
      ),
    ),
  );
}

class _LibraryTableHeader extends StatelessWidget {
  const _LibraryTableHeader();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(child: _headerLabel(context, '学生')),
          Expanded(child: _headerLabel(context, '班级')),
          Expanded(child: _headerLabel(context, '来源')),
          Expanded(child: _headerLabel(context, '状态')),
          Expanded(child: _headerLabel(context, '说明')),
          SizedBox(width: ui(150), child: _headerLabel(context, '操作')),
        ],
      ),
    );
  }

  Widget _headerLabel(BuildContext context, String text) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: const Color(0xFF71717A),
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 13,
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.record,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  final _LibraryRecord record;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 整行可点开详情。`_ActionCell` 内部用 `HitTestBehavior.opaque` 把
    // 「通过 / 驳回」单独吃掉点击，保证两者互不影响。
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: ui(60)),
        padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(13)),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorderSoft, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _StudentCell(record: record)),
            Expanded(child: _TextCell(text: record.className)),
            Expanded(child: _TextCell(text: record.source)),
            Expanded(child: _StatusCell(status: record.status)),
            Expanded(child: _TextCell(text: record.note)),
            SizedBox(
              width: ui(150),
              child: _ActionCell(
                status: record.status,
                onApprove: onApprove,
                onReject: onReject,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCell extends StatelessWidget {
  const _StudentCell({required this.record});

  final _LibraryRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFaceThumb(
          size: ui(32),
          name: record.name,
          headUrl: record.headUrl,
          faceImgUrl: record.faceImgUrl,
          fontSize: ui(13),
          onTap: () => _previewFaceImage(
            context,
            record.headUrl.isNotEmpty ? record.headUrl : record.faceImgUrl,
            heroTag: 'face_list_${record.id}',
          ),
        ),
        SizedBox(width: ui(10)),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                record.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 20 / 13,
                ),
              ),
              Text(
                record.studentNo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 14 / 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 13,
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status});

  final _LibraryStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
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
            height: 15.24 / 12,
          ),
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  final _LibraryStatus status;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    switch (status) {
      case _LibraryStatus.effective:
        return Text(
          '已审核',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 13,
          ),
        );
      case _LibraryStatus.rejected:
        return Text(
          '已驳回',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 13,
          ),
        );
      case _LibraryStatus.pending:
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onApprove,
            child: Text(
              '通过',
              style: TextStyle(
                fontSize: ui(13),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReject,
            child: Text(
              '驳回',
              style: TextStyle(
                fontSize: ui(13),
                color: _kRed,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 录入详情弹窗
// =============================================================================
//
// 通过 [GradientHeaderDialog] 复用整套弹窗装饰（紫色顶部渐变 + 22 圆角 +
// 装饰位图）。无 actionBar，纯展示，点击背景遮罩关闭。
// 内容自上而下：
//   1. 顶部 banner：左侧 88×112 圆角紫底「人脸照片预览区」（接入接口前
//      用首字头像 + 紫色相机角标占位），右侧 学生姓名 18/600 + 学号
//      12/_kTextSecondary + 状态胶囊 + 班级 + 来源。
//   2. 6 行键值对：性别 / 宿舍 / 家长联系方式 / 提交时间 / 审核人 /
//      说明，左侧 13/_kTextSecondary 标签，右侧 13/_kTextDark 数据。
//   3. 行间用 1px `_kBorderSoft` 分隔。

class _RecordDetailBody extends StatelessWidget {
  const _RecordDetailBody({required this.record});

  final _LibraryRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final auditedAt = record.auditedAt;
    final auditedBy = record.auditedBy;
    final auditedLine = (auditedAt == null && auditedBy == null)
        ? '尚未审核'
        : [
            if (auditedBy != null && auditedBy.isNotEmpty) auditedBy,
            if (auditedAt != null && auditedAt.isNotEmpty) auditedAt,
          ].join('  ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecordDetailHeader(record: record),
        SizedBox(height: ui(16)),
        _DetailRow(label: '性别', value: record.gender),
        _DetailRow(label: '宿舍', value: record.dorm),
        _DetailRow(label: '家长联系方式', value: record.parentContact),
        _DetailRow(label: '提交时间', value: record.submittedAt),
        _DetailRow(label: '审核', value: auditedLine),
        _DetailRow(label: '说明', value: record.note, isLast: true),
      ],
    );
  }
}

class _RecordDetailHeader extends StatelessWidget {
  const _RecordDetailHeader({required this.record});

  final _LibraryRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 88×112 人脸采集照预览（详情固定用 faceImg，可点击放大）。
        GestureDetector(
          onTap: () => _previewFaceImage(
            context,
            record.faceImgUrl,
            heroTag: 'face_detail_${record.id}',
          ),
          child: Container(
            width: ui(88),
            height: ui(112),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE6FF),
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: record.faceImgUrl.isNotEmpty
                      ? Image.network(
                          MediaUrl.resolve(record.faceImgUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              record.name.characters.isEmpty
                                  ? ''
                                  : record.name.characters.first,
                              style: TextStyle(
                                fontSize: ui(40),
                                color: _kPurple,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w500,
                                height: 1.0,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            record.name.characters.isEmpty
                                ? ''
                                : record.name.characters.first,
                            style: TextStyle(
                              fontSize: ui(40),
                              color: _kPurple,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w500,
                              height: 1.0,
                            ),
                          ),
                        ),
                ),
                if (record.faceImgUrl.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: ui(4)),
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Text(
                        '点击放大',
                        style: TextStyle(
                          fontSize: ui(10),
                          color: Colors.white,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: ui(14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(18),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  _StatusCell(status: record.status),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                '学号 ${record.studentNo}',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
              SizedBox(height: ui(10)),
              _MetaLine(label: '班级', value: record.className),
              SizedBox(height: ui(4)),
              _MetaLine(label: '来源', value: record.source),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: ui(13),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.4,
        ),
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: _kTextSecondary),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: _kTextDark),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: _kBorderSoft, width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(96),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

