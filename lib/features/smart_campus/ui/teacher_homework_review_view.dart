// =============================================================================
// 任课老师 / 班主任端「作业批改」独立页面（"作业与批改"总览）
//
// 入口：教师 dashboard 快捷区「作业批改」按钮 → controller.openHomeworkReview()
//      → mainView == homeworkReview + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变；左 12 返回；居中 "作业与批改"
//      16/600；右上 "历史作业" + "发布作业" 两白底胶囊按钮（带紫色图标）。
//   2. 状态 tabs（44 高 4 tab）：白底圆角胶囊，命中黑底 #0B081A 白字。
//      tab：全部 / 待我批改 / 进行中 / 已截止/已收尾。
//   3. 统计面板（单白卡 12 圆角 16 内边）：
//      · 上行（spaceBetween）：左 120×44 「全部班级 ▾」白底 1px #F3F2F3 边
//        胶囊 → 点击 PopupSelectorField；右 累计/本学期/本月 toggle（黑底白字）。
//      · 下行：6 张 stat card 等宽 flex（灰底 #F5F6FA 12 圆角）：
//        待批改人次 / 发布作业数 / 已评阅人次 / 已评均分 / 最高分 / 最低分。
//   4. 主体双列：
//      · 左 340 白卡：标题 "作业列表" + 6 张 316×104 卡片（灰底/紫底 #F4F4FF
//        选中态），每张卡顶部右上 68×22 状态角标（已截止 / 待评(N)），主区
//        显示截止时间 / 班级 / 科目 tag / 标题。点击切换 active。
//      · 右 615 白卡：当前作业详情：
//          - 标题 + 截止时间（spaceBetween）
//          - 灰底卡：【建议提交：音频】+ 描述说明 12/24 行高
//          - 4 项数据指示（126×32 灰底胶囊：标签 + 数字 + 28×28 紫色渐变图标）
//          - 学生表格：表头 + N 行（32×32 头像 + 姓名 + 状态 tag + 科目 + 介质
//            + 上传时间 + 80×40 黑底操作按钮）
//
//   5. 三个右抽屉（showGeneralDialog + Align(centerRight) + SlideTransition）：
//      · 发布作业（600 宽）：作业标题输入 + 学科/期望提交格式双下拉 + 截止时间
//        picker + 发布对象（带紫色 checkbox 的班级列表）+ 作业要求 textarea
//        + 底部紫色渐变 "发布" CTA。
//      · 历史发布记录（344 宽）：标题 "历史发布记录 + 共12条" + 7+ 张 312×104
//        卡片，每张卡左下显示「N / 总数」提交比 + 截止时间 + 班级 + 科目 + 标题。
//      · 作业点评（600 宽）：标题 "作业点评" + 学生 profile（40 头像 + 姓名 +
//        课程 + 时间 + 待批改 tag）+ 附件卡（名称 + 大小 + 下载 + 在线预览）+
//        "批改与点评" 分组：分数/100 输入 + 评语 textarea + 底部紫色渐变
//        "发布批改" CTA。
//
// 颜色：白卡 / #F5F6FA 灰底 / #F4F4FF 选中态 / #F3F2F3 边 / #8741FF 主紫 /
//      #B68EFF→#8640FF 紫渐变 CTA / #FF6A00 待评橙 / #12CE51 已通过绿 /
//      #71717A 表头灰 / #B6B5BB 提示灰
// 字体：PingFang SC（10/11/12/13/14/16/600）+ Barlow（28 数值 + 16 分母）
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../courseware/ui/courseware_url_opener.dart';
import 'student_homework_submission_preview.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/teacher_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 日期时间（与后端约定 `yyyy-MM-dd HH:mm:ss`）----------------------------

DateTime? _tryParseFlexibleDateTime(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final normalized = t.contains('T') ? t : t.replaceFirst(RegExp(r'\s+'), 'T');
  return DateTime.tryParse(normalized);
}

/// 格式：`2026-05-19 17:11:00`
String _formatYmdHms(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}:'
      '${d.second.toString().padLeft(2, '0')}';
}

/// `expectedExt` → 展示用中文。
String _expectedExtDisplay(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'audio':
      return '音频';
    case 'video':
      return '视频';
    case 'doc':
    case 'document':
      return '文档';
    case 'image':
      return '图片';
    default:
      final t = raw.trim();
      return t.isEmpty ? '—' : t;
  }
}

/// 列表接口 `classInfo.name` 或兼容旧字段。
String _homeworkClassLabel(Map<dynamic, dynamic> m) {
  final ci = m['classInfo'];
  if (ci is Map) {
    final n = ci['name']?.toString();
    if (n != null && n.isNotEmpty) return n;
  }
  return m['className']?.toString() ?? m['classLabel']?.toString() ?? '';
}

/// 列表若返回 `subjectName` 则直接用；仅有 `subjectId` 时由页面拉取
/// [schoolRepositoryProvider.subjectList] 映射为名称。
String _homeworkSubjectLabel(Map<dynamic, dynamic> m) {
  final n = m['subjectName']?.toString();
  if (n != null && n.isNotEmpty) return n;
  return '';
}

/// 相对路径（如 `app/upload/...`）补全为可加载的绝对 URL。
String? _resolveMediaUrl(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  final u = MediaUrl.resolve(t);
  return u.isEmpty ? null : u;
}

/// 教师端 `studentHomeworkDetail`：合并 `homeworkStudent` / `homework` 嵌套，
/// 并把提交文件路径统一为 [MediaUrl.resolve] 后的 `fileUrl`。
Map<String, dynamic> _mergeStudentHomeworkDetailForReview(
  Map<dynamic, dynamic> raw,
) {
  final out = <String, dynamic>{
    for (final e in raw.entries) e.key.toString(): e.value,
  };
  void copyFromMap(Map<dynamic, dynamic> src) {
    for (final e in src.entries) {
      out.putIfAbsent(e.key.toString(), () => e.value);
    }
  }

  final hs = raw['homeworkStudent'];
  if (hs is Map) {
    copyFromMap(Map<dynamic, dynamic>.from(hs));
    final hid = hs['id']?.toString().trim();
    if (hid != null && hid.isNotEmpty) {
      out.putIfAbsent('homeworkStudentId', () => hid);
    }
  }
  final hw = raw['homework'];
  if (hw is Map) {
    copyFromMap(Map<dynamic, dynamic>.from(hw));
  }

  const fileKeys = <String>[
    'studentParam1',
    'submitFileUrl',
    'fileUrl',
    'attachUrl',
    'submitUrl',
    'url',
    'filePath',
  ];
  String? firstRawFile() {
    for (final k in fileKeys) {
      final v = out[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  final rawFile = firstRawFile();
  if (rawFile != null) {
    final resolved = MediaUrl.resolve(rawFile);
    out['fileUrl'] = resolved;
    out['submitFileUrl'] = resolved;
  }

  final p2 = out['studentParam2']?.toString().trim();
  if (p2 != null && p2.isNotEmpty) {
    out.putIfAbsent('submitAttachmentName', () => p2);
    out.putIfAbsent('fileName', () => p2);
  }
  final p3 = out['studentParam3']?.toString().trim();
  if (p3 != null && p3.isNotEmpty) {
    out.putIfAbsent('submitTypeTag', () => p3);
  }
  final p1s = out['studentParam1']?.toString().trim() ?? '';
  final desc = out['description']?.toString().trim() ?? '';
  if (p1s.isNotEmpty && desc.isNotEmpty) {
    out.putIfAbsent('studentSubmitDescription', () => desc);
  }
  return out;
}

/// 作业详情：`data` 内嵌 `homework` 时摊平为与列表项一致的字段布局。
Map<dynamic, dynamic> _flattenHomeworkPayload(Map<dynamic, dynamic> m) {
  final hw = m['homework'];
  if (hw is! Map) return m;
  final out = Map<dynamic, dynamic>.from(hw);
  for (final e in m.entries) {
    if (e.key == 'homework') continue;
    out.putIfAbsent(e.key, () => e.value);
  }
  return out;
}

// ---- 配色 -------------------------------------------------------------------
const Color _kCardBg = Colors.white;
const Color _kPageGrey = Color(0xFFF5F6FA);
const Color _kPickGrey = Color(0xFFF4F4FF);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextBlack = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextMuted = Color(0xFF71717A);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleEnd = Color(0xFFB68EFF);
const Color _kPurpleStart = Color(0xFF8640FF);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeBg = Color(0xFFFFEDD3);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenBg = Color(0xFFE4FFED);
const Color _kSubjectBg = Colors.white;
const Color _kPillIconColor = Color(0xFF1C274C);

// ---- 数据模型 ---------------------------------------------------------------

enum _SubmissionState { passed, pending, missing, reviewed }

class _Submission {
  const _Submission({
    required this.id,
    required this.studentName,
    required this.avatarSeed,
    required this.state,
    required this.subject,
    required this.medium,
    required this.uploadAt,
    required this.action,
    this.avatarUrl,
    this.fileUrl,
    this.fileName,
    this.score,
    this.feedback,
  });

  /// 学生作业记录 ID，用于调用 studentHomeworkDetail / teacherHomeworkCorrect。
  final String id;
  final String studentName;
  final int avatarSeed;
  final _SubmissionState state;
  final String subject;
  final String medium;
  final String uploadAt;
  final String action;
  final String? avatarUrl;
  final String? fileUrl;
  final String? fileName;
  final int? score;
  final String? feedback;

  factory _Submission.fromMap(
    Map<dynamic, dynamic> m, {
    String expectedExt = '',
    String subjectFallback = '',
  }) {
    final si = m['studentInfo'];
    Map<dynamic, dynamic>? siMap;
    if (si is Map) {
      siMap = Map<dynamic, dynamic>.from(si);
    }
    String fromSi(String k) => siMap?[k]?.toString().trim() ?? '';
    String fromTop(String k) => m[k]?.toString().trim() ?? '';

    final statusRaw = m['status'] ?? m['submitStatus'] ?? 0;
    final statusInt = statusRaw is int ? statusRaw : int.tryParse(statusRaw.toString()) ?? 0;
    final submitRaw = m['submitTime']?.toString().trim() ?? '';
    final hasSubmitTime = submitRaw.isNotEmpty;

    late final _SubmissionState state;
    late final String action;
    if (statusInt == 2) {
      state = _SubmissionState.reviewed;
      action = '查看';
    } else if (statusInt == 1 || (statusInt == 0 && hasSubmitTime)) {
      state = _SubmissionState.pending;
      action = '试听/评分';
    } else {
      state = _SubmissionState.missing;
      action = '催交/详情';
    }

    final real = fromSi('realname').isNotEmpty ? fromSi('realname') : fromTop('realname');
    final nick = fromSi('nickname').isNotEmpty ? fromSi('nickname') : fromTop('nickname');
    final name = (real.isNotEmpty ? real : null) ??
        (nick.isNotEmpty ? nick : null) ??
        (fromTop('studentName').isNotEmpty ? fromTop('studentName') : null) ??
        '—';

    final raw = submitRaw.isNotEmpty
        ? submitRaw
        : (m['createTime']?.toString() ?? '');
    final parsed = _tryParseFlexibleDateTime(raw);
    final uploadAt = parsed != null ? _formatYmdHms(parsed) : (raw.isNotEmpty ? raw : '—');

    final extForMedium = fromTop('expectedExt').isNotEmpty ? fromTop('expectedExt') : expectedExt;
    final mediumLabel = _expectedExtDisplay(extForMedium);
    final subj =
        fromTop('subjectName').isNotEmpty ? fromTop('subjectName') : fromTop('subject');
    final subject = subj.isNotEmpty ? subj : subjectFallback;

    final headRaw = fromSi('headUrl').isNotEmpty ? fromSi('headUrl') : fromTop('headUrl');

    return _Submission(
      id: m['id']?.toString().trim() ?? '',
      studentName: name,
      avatarSeed: (name.isNotEmpty ? name.codeUnitAt(0) % 3 : 0),
      state: state,
      subject: subject,
      medium: mediumLabel,
      uploadAt: uploadAt,
      action: action,
      avatarUrl: headRaw.isNotEmpty ? headRaw : null,
      fileUrl: m['fileUrl']?.toString() ??
          m['attachUrl']?.toString() ??
          m['studentParam1']?.toString(),
      fileName:
          m['fileName']?.toString() ?? m['attachName']?.toString() ?? m['studentParam2']?.toString(),
      score: int.tryParse(m['score']?.toString() ?? ''),
      feedback: m['feedback']?.toString() ?? m['teacherFeedback']?.toString(),
    );
  }
}

class _HomeworkItem {
  const _HomeworkItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.classLabel,
    required this.deadline,
    required this.suggested,
    required this.suggestedDesc,
    required this.cornerLabel,
    required this.cornerKind,
    required this.totalPeople,
    required this.unsubmitted,
    required this.pendingReview,
    required this.reviewed,
    required this.submissions,
    required this.publishedRatio,
    this.subjectId,
    this.classIds,
    this.expectedExtRaw = '',
  });

  /// 后端作业 ID（字符串，与列表 `id` 一致），用于 teacherHomeworkDetail / teacherHomeworkDelete。
  final String id;
  final String title;
  final String subject;
  final String classLabel;
  final String deadline;
  final String suggested;
  final String suggestedDesc;

  final String cornerLabel;
  final _CornerKind cornerKind;

  final int totalPeople;
  final int unsubmitted;
  final int pendingReview;
  final int reviewed;

  final List<_Submission> submissions;

  final ({int submitted, int total}) publishedRatio;

  final int? subjectId;
  final List<String>? classIds;

  /// 作业要求的介质编码（如 `audio`），供批改页预览推断类型。
  final String expectedExtRaw;

  String resolveSubjectDisplay(Map<int, String> subjectNameById) {
    final t = subject.trim();
    if (t.isNotEmpty) return t;
    final sid = subjectId;
    if (sid != null) {
      final n = subjectNameById[sid];
      if (n != null && n.isNotEmpty) return n;
    }
    return '—';
  }

  factory _HomeworkItem.fromMap(Map<dynamic, dynamic> m) {
    final src = _flattenHomeworkPayload(m);
    final idStr = src['id']?.toString().trim() ?? '';

    final hwStatusRaw = src['status'] ?? 0;
    final hwStatus = hwStatusRaw is int
        ? hwStatusRaw
        : int.tryParse(hwStatusRaw.toString()) ?? 0;

    late final int totalPeople;
    late final int unsubmitted;
    late final int pendingReview;
    late final int reviewed;
    late final int submitted;

    final hc = src['homeworkCount'];
    if (hc is Map) {
      unsubmitted = int.tryParse(hc['status0']?.toString() ?? '') ?? 0;
      pendingReview = int.tryParse(hc['status1']?.toString() ?? '') ?? 0;
      reviewed = int.tryParse(hc['status2']?.toString() ?? '') ?? 0;
      totalPeople = unsubmitted + pendingReview + reviewed;
      submitted = pendingReview + reviewed;
    } else {
      pendingReview = int.tryParse(
            src['pendingCount']?.toString() ?? src['pendingReview']?.toString() ?? '',
          ) ??
          0;
      reviewed =
          int.tryParse(src['reviewedCount']?.toString() ?? src['reviewed']?.toString() ?? '') ?? 0;
      totalPeople =
          int.tryParse(src['totalCount']?.toString() ?? src['totalPeople']?.toString() ?? '') ?? 0;
      submitted =
          int.tryParse(src['submitCount']?.toString() ?? src['submitted']?.toString() ?? '') ?? 0;
      unsubmitted = (totalPeople - submitted).clamp(0, 1 << 30);
    }

    final kind = hwStatus == 1 ? _CornerKind.closed : _CornerKind.pending;
    late final String cornerLabel;
    if (hwStatus == 1) {
      cornerLabel = '已完成';
    } else if (pendingReview > 0) {
      cornerLabel = '待评($pendingReview)';
    } else {
      cornerLabel = '进行中';
    }

    final endRaw = src['endTime']?.toString() ?? src['deadline']?.toString() ?? '';
    final parsedEnd = _tryParseFlexibleDateTime(endRaw);
    final deadline = parsedEnd != null ? _formatYmdHms(parsedEnd) : endRaw;

    final rawExt = src['expectedExt']?.toString() ?? '';
    final subjectLabel = _homeworkSubjectLabel(src);
    final studentListRaw =
        src['studentList'] ?? src['submissions'] ?? src['homeworkStudentList'] ?? src['list'];
    final List<_Submission> submissions = (studentListRaw is List)
        ? studentListRaw
            .whereType<Map>()
            .map(
              (row) => _Submission.fromMap(
                row,
                expectedExt: rawExt,
                subjectFallback: subjectLabel,
              ),
            )
            .toList()
        : <_Submission>[];

    final cid = src['classId']?.toString().trim() ?? '';
    List<String>? classIds;
    if (src['classIds'] is List) {
      final ids = (src['classIds'] as List)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) classIds = ids;
    }
    if (classIds == null) {
      if (cid.isNotEmpty) {
        classIds = [cid];
      } else {
        final ci = src['classInfo'];
        if (ci is Map) {
          final iid = ci['id']?.toString().trim() ?? '';
          if (iid.isNotEmpty) classIds = [iid];
        }
      }
    }

    return _HomeworkItem(
      id: idStr,
      title: src['title']?.toString() ?? '—',
      subject: subjectLabel,
      classLabel: _homeworkClassLabel(src),
      deadline: deadline,
      suggested: _expectedExtDisplay(rawExt),
      suggestedDesc: src['description']?.toString() ?? '',
      cornerLabel: cornerLabel,
      cornerKind: kind,
      totalPeople: totalPeople,
      unsubmitted: unsubmitted,
      pendingReview: pendingReview,
      reviewed: reviewed,
      submissions: submissions,
      publishedRatio: (submitted: submitted, total: totalPeople > 0 ? totalPeople : 1),
      subjectId: int.tryParse(src['subjectId']?.toString() ?? ''),
      classIds: classIds,
      expectedExtRaw: rawExt,
    );
  }
}

// ---- 统计汇总数据模型 --------------------------------------------------------

class _HomeworkStats {
  const _HomeworkStats({
    this.pendingCount = 0,
    this.publishCount = 0,
    this.reviewedCount = 0,
    this.avgScore = 0,
    this.maxScore = 0,
    this.minScore = 0,
  });

  final int pendingCount;
  final int publishCount;
  final int reviewedCount;
  final num avgScore;
  final num maxScore;
  final num minScore;

  factory _HomeworkStats.fromMap(Map<dynamic, dynamic> m) {
    return _HomeworkStats(
      pendingCount: int.tryParse(m['pendingCount']?.toString() ?? '') ?? 0,
      publishCount: int.tryParse(m['publishCount']?.toString() ?? m['totalCount']?.toString() ?? '') ?? 0,
      reviewedCount: int.tryParse(m['reviewedCount']?.toString() ?? '') ?? 0,
      avgScore: num.tryParse(m['avgScore']?.toString() ?? '') ?? 0,
      maxScore: num.tryParse(m['maxScore']?.toString() ?? '') ?? 0,
      minScore: num.tryParse(m['minScore']?.toString() ?? '') ?? 0,
    );
  }
}

enum _CornerKind { closed, pending }

const List<String> _kStatusTabs = ['全部', '待我批改', '进行中', '已截止/已收尾'];
const List<String> _kRangeTabs = ['累计', '本学期', '本月'];

// ---- 入口 view --------------------------------------------------------------

class TeacherHomeworkReviewView extends ConsumerStatefulWidget {
  const TeacherHomeworkReviewView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherHomeworkReviewView> createState() =>
      _TeacherHomeworkReviewViewState();
}

class _TeacherHomeworkReviewViewState
    extends ConsumerState<TeacherHomeworkReviewView> {
  int _statusTab = 0;
  int _rangeTab = 0;
  int _activeHomeworkIdx = 0;

  String _classId = '0';
  String _classFilter = '全部班级';
  List<Map> _classList = [];

  List<_HomeworkItem> _all = [];
  bool _loadingList = true;

  _HomeworkItem? _activeDetail;
  bool _loadingDetail = false;

  /// `subjectId` → 名称，来自 [SchoolRepository.subjectList]（按班级拉取）。
  final Map<int, String> _subjectNameById = <int, String>{};

  _HomeworkStats? _stats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadClassList();
    await Future.wait([_loadHomeworkList(), _loadStats()]);
  }

  Future<void> _loadClassList() async {
    final res = await ref.read(teacherRepositoryProvider).classList();
    if (!mounted) return;
    if (res.isSuccess && res.data is List) {
      final list = (res.data as List).whereType<Map>().toList();
      if (list.isNotEmpty) {
        final first = list.first;
        setState(() {
          _classList = list;
          _classId =
              first['id']?.toString() ??
              first['classId']?.toString() ??
              '0';
          _classFilter = first['name']?.toString() ?? '全部班级';
        });
      }
    }
  }

  Future<void> _loadSubjectNameCatalog(String rawClassId) async {
    final cid = rawClassId.trim();
    if (cid.isEmpty || cid == '0') return;
    final resp = await ref.read(schoolRepositoryProvider).subjectList(classId: cid);
    if (!mounted || !resp.isSuccess) return;
    final list = _parseHomeworkSubjectList(resp);
    if (list.isEmpty) return;
    setState(() {
      for (final e in list) {
        _subjectNameById[e.id] = e.name;
      }
    });
  }

  Future<void> _loadHomeworkList() async {
    if (!mounted) return;
    setState(() => _loadingList = true);
    await _loadSubjectNameCatalog(_classId);
    final Object statusParam = switch (_statusTab) {
      0 => '',
      1 => 2,
      2 => 0,
      3 => 1,
      _ => '',
    };
    final res = await ref.read(teacherRepositoryProvider).teacherHomeworkList(
      classId: _classId,
      status: statusParam,
    );
    if (!mounted) return;
    if (res.isSuccess) {
      final raw = res.data;
      final list = raw is Map ? (raw['records'] ?? raw['list'] ?? raw) : raw;
      if (list is List) {
        final items = list.whereType<Map>().map(_HomeworkItem.fromMap).toList();
        setState(() {
          _all = items;
          _activeHomeworkIdx = 0;
          _activeDetail = null;
          _loadingList = false;
        });
        if (_all.isNotEmpty) await _loadHomeworkDetail(_all[0].id);
        return;
      }
    }
    if (mounted) setState(() => _loadingList = false);
  }

  Future<void> _loadHomeworkDetail(String id) async {
    if (!mounted || id.isEmpty) return;
    setState(() => _loadingDetail = true);
    final res = await ref
        .read(teacherRepositoryProvider)
        .teacherHomeworkDetail(id: id);
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      final dataMap = res.data as Map<dynamic, dynamic>;
      final flat = _flattenHomeworkPayload(dataMap);
      final topClass = flat['classId']?.toString().trim() ?? '';
      String? nestedClassId;
      final ci = flat['classInfo'];
      if (ci is Map) {
        nestedClassId = ci['id']?.toString().trim();
      }
      final detailClassId =
          topClass.isNotEmpty ? topClass : (nestedClassId ?? '');
      if (detailClassId.isNotEmpty && detailClassId != _classId) {
        await _loadSubjectNameCatalog(detailClassId);
      }
      final detail = _HomeworkItem.fromMap(dataMap);
      setState(() {
        _activeDetail = detail;
        if (_activeHomeworkIdx < _all.length) {
          _all = List.of(_all)..[_activeHomeworkIdx] = detail;
        }
        _loadingDetail = false;
      });
    } else {
      setState(() => _loadingDetail = false);
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);
    final now = DateTime.now();
    DateTime begin;
    switch (_rangeTab) {
      case 1: // 本学期 (~5 months)
        begin = now.subtract(const Duration(days: 150));
      case 2: // 本月
        begin = DateTime(now.year, now.month, 1);
      default: // 累计 (2 years)
        begin = now.subtract(const Duration(days: 730));
    }
    final res = await ref.read(teacherRepositoryProvider).teacherHomeworkSum(
      classId: _classId,
      beginDate: _fmtDate(begin),
      endDate: _fmtDate(now),
    );
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(() {
        _stats = _HomeworkStats.fromMap(res.data as Map);
        _loadingStats = false;
      });
    } else {
      setState(() => _loadingStats = false);
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _deleteHomework(_HomeworkItem item) async {
    final res = await ref
        .read(teacherRepositoryProvider)
        .teacherHomeworkDelete(id: item.id);
    if (!mounted) return;
    if (res.isSuccess) {
      AppToast.show(context, '作业已删除');
      await _loadHomeworkList();
      await _loadStats();
    } else {
      AppToast.show(
        context,
        res.msg.isNotEmpty ? res.msg : '删除失败，请重试',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final active =
        _activeDetail ?? (_all.isNotEmpty ? _all[_activeHomeworkIdx] : null);

    final classNames = [
      '全部班级',
      ..._classList
          .map((m) => m['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewBanner(
            onBack: widget.onBack,
            onOpenHistory: () => _openHistoryDrawer(),
            onOpenPublish: () => _openPublishDrawer(),
          ),
          SizedBox(height: ui(16)),
          _StatusTabsRow(
            tabs: _kStatusTabs,
            activeIdx: _statusTab,
            onTap: (i) {
              setState(() => _statusTab = i);
              _loadHomeworkList();
            },
          ),
          SizedBox(height: ui(12)),
          _StatsPanel(
            classFilter: _classFilter,
            classOptions: classNames,
            onClassChanged: (v) {
              Map? found;
              for (final m in _classList) {
                if (m['name']?.toString() == v) {
                  found = m;
                  break;
                }
              }
              setState(() {
                _classFilter = v;
                _classId = found != null
                    ? (found['id']?.toString() ??
                        found['classId']?.toString() ??
                        '0')
                    : '0';
              });
              _loadHomeworkList();
              _loadStats();
            },
            rangeIdx: _rangeTab,
            onRangeChanged: (i) {
              setState(() => _rangeTab = i);
              _loadStats();
            },
            stats: _stats,
            loadingStats: _loadingStats,
          ),
          SizedBox(height: ui(16)),
          if (_loadingList)
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: ui(60)),
                child: CircularProgressIndicator(
                  color: _kPurple,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_all.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: ui(60)),
                child: Text(
                  '暂无作业数据',
                  style: TextStyle(
                    color: _kTextHint,
                    fontSize: ui(14),
                  ),
                ),
              ),
            )
          else
            _BodyRow(
              items: _all,
              activeIdx: _activeHomeworkIdx,
              onSelect: (i) {
                setState(() {
                  _activeHomeworkIdx = i;
                  _activeDetail = null;
                });
                _loadHomeworkDetail(_all[i].id);
              },
              active: active!,
              loadingDetail: _loadingDetail,
              subjectResolvedFor: (it) => it.resolveSubjectDisplay(_subjectNameById),
              onOpenReview: (s) => _openReviewDrawer(active, s),
              onDelete: (item) => _deleteHomework(item),
            ),
        ],
      ),
    );
  }

  void _openHistoryDrawer() {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭历史发布记录',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _HistoryDrawer(classId: _classId),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  void _openPublishDrawer() {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭发布作业',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _PublishDrawer(
              onPublished: () {
                Navigator.of(ctx).maybePop();
                _loadHomeworkList();
                _loadStats();
              },
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  void _openReviewDrawer(_HomeworkItem item, _Submission submission) {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭作业点评',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _ReviewDrawer(
              item: item,
              submission: submission,
              homeworkSubjectDisplay:
                  item.resolveSubjectDisplay(_subjectNameById),
              onReviewed: () {
                Navigator.of(ctx).maybePop();
                if (_all.isNotEmpty) _loadHomeworkDetail(_all[_activeHomeworkIdx].id);
                _loadStats();
              },
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}

// =============================================================================
// 顶部 banner（白→#F9EDFF 渐变；左返回 + 居中标题 + 右两按钮）
// =============================================================================

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({
    required this.onBack,
    required this.onOpenHistory,
    required this.onOpenPublish,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenPublish;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
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
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: _kPillIconColor,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '作业与批改',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(15),
            child: Row(
              children: [
                _BannerActionButton(
                  icon: Icons.notifications_none_rounded,
                  label: '历史作业',
                  onTap: onOpenHistory,
                ),
                SizedBox(width: ui(8)),
                _BannerActionButton(
                  icon: Icons.edit_note_rounded,
                  label: '发布作业',
                  onTap: onOpenPublish,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerActionButton extends StatelessWidget {
  const _BannerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(33),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ui(16), color: _kPurple),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 状态 tabs（4 项；命中黑底白字 6 圆角）
// =============================================================================

class _StatusTabsRow extends StatelessWidget {
  const _StatusTabsRow({
    required this.tabs,
    required this.activeIdx,
    required this.onTap,
  });

  final List<String> tabs;
  final int activeIdx;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: ui(8)),
            _SegmentChip(
              label: tabs[i],
              active: i == activeIdx,
              onTap: () => onTap(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  /// stats 面板里 toggle 用的紧凑型（更细 padding）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ui(compact ? 12 : 16),
          vertical: ui(10),
        ),
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

// =============================================================================
// 统计面板（班级筛选 + 累计/本学期/本月 + 6 张 stat 卡）
// =============================================================================

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.classFilter,
    required this.classOptions,
    required this.onClassChanged,
    required this.rangeIdx,
    required this.onRangeChanged,
    this.stats,
    this.loadingStats = false,
  });

  final String classFilter;
  final List<String> classOptions;
  final ValueChanged<String> onClassChanged;
  final int rangeIdx;
  final ValueChanged<int> onRangeChanged;
  final _HomeworkStats? stats;
  final bool loadingStats;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final s = stats;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: ui(180),
                child: PopupSelectorField<String>(
                  value: classFilter,
                  items: classOptions.isEmpty
                      ? [classFilter]
                      : classOptions,
                  itemLabel: (sv) => sv,
                  onChanged: onClassChanged,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.all(ui(4)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(12)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _kRangeTabs.length; i++) ...[
                      if (i > 0) SizedBox(width: ui(4)),
                      _SegmentChip(
                        label: _kRangeTabs[i],
                        active: i == rangeIdx,
                        onTap: () => onRangeChanged(i),
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          if (loadingStats)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: ui(8)),
                child: SizedBox(
                  width: ui(20),
                  height: ui(20),
                  child: CircularProgressIndicator(
                    color: _kPurple,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    value: '${s?.pendingCount ?? 0}',
                    label: '待批改人次',
                  ),
                ),
                _StatGap(),
                Expanded(
                  child: _StatCell(
                    value: '${s?.publishCount ?? 0}',
                    label: '发布作业数',
                  ),
                ),
                _StatGap(),
                Expanded(
                  child: _StatCell(
                    value: '${s?.reviewedCount ?? 0}',
                    label: '已评阅人次',
                  ),
                ),
                _StatGap(),
                Expanded(
                  child: _StatCell(
                    value: s != null ? s.avgScore.toStringAsFixed(1) : '—',
                    label: '已评均分',
                  ),
                ),
                _StatGap(),
                Expanded(
                  child: _StatCell(
                    value: s != null ? '${s.maxScore.toInt()}' : '—',
                    label: '最高分',
                  ),
                ),
                _StatGap(),
                Expanded(
                  child: _StatCell(
                    value: s != null ? '${s.minScore.toInt()}' : '—',
                    label: '最低分',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatGap extends StatelessWidget {
  const _StatGap();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(width: ui(16));
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(24),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 主体双列：左 340 作业列表 + 右 615 作业详情 / 提交表
// =============================================================================

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
    required this.active,
    required this.onOpenReview,
    required this.onDelete,
    required this.subjectResolvedFor,
    this.loadingDetail = false,
  });

  final List<_HomeworkItem> items;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final _HomeworkItem active;
  final ValueChanged<_Submission> onOpenReview;
  final ValueChanged<_HomeworkItem> onDelete;
  final String Function(_HomeworkItem) subjectResolvedFor;
  final bool loadingDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(340),
            child: _HomeworkListPanel(
              items: items,
              activeIdx: activeIdx,
              onSelect: onSelect,
              onDelete: onDelete,
              subjectResolvedFor: subjectResolvedFor,
            ),
          ),
          SizedBox(width: ui(16)),
          Expanded(
            child: loadingDetail
                ? Container(
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(ui(16)),
                    ),
                    padding: EdgeInsets.symmetric(vertical: ui(60)),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _kPurple,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _HomeworkDetailPanel(
                    item: active,
                    homeworkSubjectDisplay: subjectResolvedFor(active),
                    onOpenReview: onOpenReview,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---- 左侧作业列表 -----------------------------------------------------------

class _HomeworkListPanel extends StatelessWidget {
  const _HomeworkListPanel({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
    required this.onDelete,
    required this.subjectResolvedFor,
  });

  final List<_HomeworkItem> items;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final ValueChanged<_HomeworkItem> onDelete;
  final String Function(_HomeworkItem) subjectResolvedFor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: ui(4)),
            child: Text(
              '作业列表',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextBlack,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: ui(8)),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(8)),
            _HomeworkListCard(
              item: items[i],
              subjectDisplay: subjectResolvedFor(items[i]),
              active: i == activeIdx,
              onTap: () => onSelect(i),
              onDelete: () => onDelete(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeworkListCard extends StatelessWidget {
  const _HomeworkListCard({
    required this.item,
    required this.subjectDisplay,
    required this.active,
    required this.onTap,
    this.onDelete,
  });

  final _HomeworkItem item;
  final String subjectDisplay;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = active ? _kPickGrey : _kPageGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(minHeight: ui(104)),
            padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '截止 ${item.deadline}',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  item.classLabel,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(6)),
                Row(
                  children: [
                    _SubjectTag(label: subjectDisplay),
                    SizedBox(width: ui(4)),
                    if (item.pendingReview > 0)
                      _PendingReviewTag(count: item.pendingReview),
                  ],
                ),
                SizedBox(height: ui(8)),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextBlack,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _CornerLabel(label: item.cornerLabel, kind: item.cornerKind),
          ),
          if (onDelete != null)
            Positioned(
              right: ui(4),
              bottom: ui(4),
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(ui(6)),
                child: Container(
                  width: ui(22),
                  height: ui(22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(ui(6)),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: ui(14),
                    color: _kTextSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: _kSubjectBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _PendingReviewTag extends StatelessWidget {
  const _PendingReviewTag({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: _kOrangeBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        '待评($count)',
        style: TextStyle(
          fontSize: ui(12),
          color: _kOrange,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _CornerLabel extends StatelessWidget {
  const _CornerLabel({required this.label, required this.kind});

  final String label;
  final _CornerKind kind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = kind == _CornerKind.closed
        ? const Color(0xFFE6E9F1)
        : _kOrangeBg;
    final fg = kind == _CornerKind.closed ? _kTextHint : _kOrange;
    return Container(
      width: ui(68),
      height: ui(22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(ui(12)),
          bottomLeft: Radius.circular(ui(12)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1,
        ),
      ),
    );
  }
}

// ---- 右侧作业详情 + 4 项指标 + 学生表格 -------------------------------------

class _HomeworkDetailPanel extends StatelessWidget {
  const _HomeworkDetailPanel({
    required this.item,
    required this.homeworkSubjectDisplay,
    required this.onOpenReview,
  });

  final _HomeworkItem item;
  final String homeworkSubjectDisplay;
  final ValueChanged<_Submission> onOpenReview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextBlack,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: ui(12)),
              Text(
                '截止 ${item.deadline}',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _SuggestedBlock(
            suggested: item.suggested,
            description: item.suggestedDesc,
          ),
          SizedBox(height: ui(12)),
          _ProgressMetrics(item: item),
          SizedBox(height: ui(12)),
          _SubmissionsTable(
            submissions: item.submissions,
            homeworkSubjectDisplay: homeworkSubjectDisplay,
            onOpenReview: onOpenReview,
          ),
        ],
      ),
    );
  }
}

class _SuggestedBlock extends StatelessWidget {
  const _SuggestedBlock({required this.suggested, required this.description});

  final String suggested;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '【建议提交：$suggested】',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.6,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            description,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetrics extends StatelessWidget {
  const _ProgressMetrics({required this.item});

  final _HomeworkItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _ProgressMetricCell(
            label: '全班人数',
            value: '${item.totalPeople}',
            icon: Icons.people_alt_rounded,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '未交人数',
            value: '${item.unsubmitted}',
            icon: Icons.person_off_rounded,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '待批人数',
            value: '${item.pendingReview}',
            icon: Icons.fact_check_outlined,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '已批人数',
            value: '${item.reviewed}',
            icon: Icons.task_alt_rounded,
          ),
        ),
      ],
    );
  }
}

class _ProgressMetricCell extends StatelessWidget {
  const _ProgressMetricCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: ui(4)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(6)),
          Container(
            width: ui(28),
            height: ui(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kTextDark, _kPurple],
              ),
              borderRadius: BorderRadius.circular(ui(6)),
            ),
            child: Icon(icon, size: ui(16), color: _kPageGrey),
          ),
        ],
      ),
    );
  }
}

// ---- 学生提交表格 -----------------------------------------------------------

class _SubmissionsTable extends StatelessWidget {
  const _SubmissionsTable({
    required this.submissions,
    required this.homeworkSubjectDisplay,
    required this.onOpenReview,
  });

  final List<_Submission> submissions;
  final String homeworkSubjectDisplay;
  final ValueChanged<_Submission> onOpenReview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(8)),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            children: const [
              SizedBox(width: 90 + 4, child: _ColHeader('学生')),
              Expanded(child: _ColHeader('状态')),
              Expanded(child: _ColHeader('科目')),
              Expanded(child: _ColHeader('介质')),
              Expanded(child: _ColHeader('上传时间')),
              SizedBox(width: 80, child: _ColHeader('操作')),
            ],
          ),
        ),
        for (final s in submissions)
          _SubmissionRow(
            item: s,
            subjectCell: s.subject.trim().isNotEmpty ? s.subject : homeworkSubjectDisplay,
            onOpenReview: () => onOpenReview(s),
          ),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextMuted,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.4,
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({
    required this.item,
    required this.subjectCell,
    required this.onOpenReview,
  });

  final _Submission item;
  final String subjectCell;
  final VoidCallback onOpenReview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ui(94),
            child: Row(
              children: [
                _AvatarCircle(
                  name: item.studentName,
                  seed: item.avatarSeed,
                  imageUrl: item.avatarUrl,
                ),
                SizedBox(width: ui(4)),
                Flexible(
                  child: Text(
                    item.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(child: _StatusPill(state: item.state)),
          Expanded(child: _CellText(subjectCell)),
          Expanded(child: _CellText(item.medium)),
          Expanded(child: _CellText(item.uploadAt)),
          SizedBox(
            width: ui(90),
            child: item.state == _SubmissionState.missing
                ? const SizedBox.shrink()
                : InkWell(
                    onTap: onOpenReview,
                    borderRadius: BorderRadius.circular(ui(8)),
                    child: Container(
                      height: ui(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kTextDark,
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Text(
                        item.action,
                        style: TextStyle(
                          fontSize: ui(13),
                          color: Colors.white,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.text);

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
        height: 1.4,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final _SubmissionState state;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ({Color bg, Color fg, String text}) tone = switch (state) {
      _SubmissionState.passed => (bg: _kGreenBg, fg: _kGreen, text: '已通过'),
      _SubmissionState.pending => (bg: _kOrangeBg, fg: _kOrange, text: '待评'),
      _SubmissionState.missing => (
        bg: const Color(0xFFFFE5E5),
        fg: const Color(0xFFE54848),
        text: '未交',
      ),
      _SubmissionState.reviewed => (bg: _kGreenBg, fg: _kGreen, text: '已批改'),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(ui(4)),
        ),
        child: Text(
          tone.text,
          style: TextStyle(
            fontSize: ui(12),
            color: tone.fg,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.name,
    required this.seed,
    this.size = 32,
    this.imageUrl,
  });

  final String name;
  final int seed;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final resolved = _resolveMediaUrl(imageUrl);
    final palettes = const [
      [Color(0xFFB68EFF), Color(0xFF8741FF)],
      [Color(0xFFFFB68E), Color(0xFFFF8741)],
      [Color(0xFF8EE0FF), Color(0xFF418EFF)],
    ];
    final palette = palettes[seed.abs() % palettes.length];
    final initial = name.isNotEmpty ? name.characters.first : '?';
    if (resolved != null) {
      return ClipOval(
        child: Image.network(
          resolved,
          width: ui(size),
          height: ui(size),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: ui(size),
            height: ui(size),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: ui(13),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: ui(size),
      height: ui(size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(13),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 发布作业右抽屉（600 宽）
// =============================================================================

class _PublishDrawer extends ConsumerStatefulWidget {
  const _PublishDrawer({this.onPublished});

  final VoidCallback? onPublished;

  @override
  ConsumerState<_PublishDrawer> createState() => _PublishDrawerState();
}

class _PublishDrawerState extends ConsumerState<_PublishDrawer> {
  static const _mediumOptions = ['文档', '音频', '视频', '图片'];
  static const _mediumExtMap = {'文档': 'doc', '音频': 'audio', '视频': 'video', '图片': 'image'};

  /// 来自 `/app/school/v2/user/subjectList`（按当前勾选班级之一拉取）。
  List<({int id, String name})> _subjects = [];
  int? _selectedSubjectId;
  bool _loadingSubjects = false;
  String _medium = '音频';
  DateTime? _deadlineDate;
  final Set<int> _selectedClassIndices = {};
  List<Map> _classList = [];
  bool _loadingClasses = true;
  bool _publishing = false;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    final res = await ref.read(teacherRepositoryProvider).classList();
    if (!mounted) return;
    if (res.isSuccess && res.data is List) {
      final list = (res.data as List).whereType<Map>().toList();
      setState(() {
        _classList = list;
        if (list.isNotEmpty) _selectedClassIndices.add(0);
        _loadingClasses = false;
      });
    } else {
      setState(() => _loadingClasses = false);
    }
    await _loadSubjects();
  }

  /// 取勾选班级中「列表序号最小」的班级 id，与排课页一致：`subjectList` 需带 classId。
  String? _subjectListClassIdString() {
    if (_classList.isEmpty || _selectedClassIndices.isEmpty) return null;
    final idx = _selectedClassIndices.reduce((a, b) => a < b ? a : b);
    if (idx < 0 || idx >= _classList.length) return null;
    final id = _classList[idx]['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> _loadSubjects() async {
    if (!mounted) return;
    setState(() => _loadingSubjects = true);
    final cid = _subjectListClassIdString();
    final resp = await ref.read(schoolRepositoryProvider).subjectList(
          classId: cid,
        );
    if (!mounted) return;
    final parsed = _parseHomeworkSubjectList(resp);
    setState(() {
      _subjects = parsed;
      if (_selectedSubjectId == null ||
          !_subjects.any((s) => s.id == _selectedSubjectId)) {
        _selectedSubjectId = _subjects.isNotEmpty ? _subjects.first.id : null;
      }
      _loadingSubjects = false;
    });
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '请输入作业标题');
      return;
    }
    if (_deadlineDate == null) {
      AppToast.show(context, '请选择截止时间');
      return;
    }
    if (_selectedClassIndices.isEmpty) {
      AppToast.show(context, '请选择至少一个发布班级');
      return;
    }
    final classIds = <String>[];
    for (final i in _selectedClassIndices) {
      if (i < 0 || i >= _classList.length) continue;
      final raw = _classList[i]['id']?.toString().trim() ??
          _classList[i]['classId']?.toString().trim() ??
          '';
      if (raw.isNotEmpty) classIds.add(raw);
    }
    if (classIds.isEmpty) {
      AppToast.show(context, '班级数据错误，请重试');
      return;
    }
    final sid = _selectedSubjectId;
    if (sid == null || sid <= 0) {
      AppToast.show(context, '请先选择科目');
      return;
    }
    setState(() => _publishing = true);
    final res = await ref.read(teacherRepositoryProvider).teacherHomeworkSave(
      classIds: classIds,
      title: title,
      description: _descCtrl.text.trim(),
      endTime: _formatYmdHms(_deadlineDate!),
      subjectId: sid,
      expectedExt: _mediumExtMap[_medium] ?? '',
    );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (res.isSuccess) {
      AppToast.show(context, '作业已发布');
      widget.onPublished?.call();
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '发布失败，请重试');
    }
  }

  String get _deadlineDisplay {
    final d = _deadlineDate;
    if (d == null) return '请选择截止时间';
    return _formatYmdHms(d);
  }

  String get _selectedSubjectName {
    if (_subjects.isEmpty) return '—';
    final match = _subjects.where((s) => s.id == _selectedSubjectId);
    if (match.isNotEmpty) return match.first.name;
    return _subjects.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(600),
        height: double.infinity,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(80)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DrawerTitleBar(title: '发布作业'),
                    SizedBox(height: ui(20)),
                    Container(height: 1, color: _kBorderSoft),
                    SizedBox(height: ui(20)),
                    _FieldLabel('作业标题'),
                    SizedBox(height: ui(12)),
                    _PlainInputField(
                      hint: '请输入作业标题',
                      controller: _titleCtrl,
                    ),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('学科'),
                              SizedBox(height: ui(12)),
                              if (_loadingSubjects)
                                SizedBox(
                                  height: ui(48),
                                  child: Center(
                                    child: SizedBox(
                                      width: ui(22),
                                      height: ui(22),
                                      child: CircularProgressIndicator(
                                        color: _kPurple,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              else if (_subjects.isEmpty)
                                SizedBox(
                                  height: ui(48),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '暂无科目，请先勾选发布班级',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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
                                PopupSelectorField<String>(
                                  value: _selectedSubjectName,
                                  items: _subjects.map((s) => s.name).toList(),
                                  itemLabel: (v) => v,
                                  onChanged: (v) {
                                    for (final s in _subjects) {
                                      if (s.name == v) {
                                        setState(
                                          () => _selectedSubjectId = s.id,
                                        );
                                        break;
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: ui(32)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('期望提交格式'),
                              SizedBox(height: ui(12)),
                              PopupSelectorField<String>(
                                value: _medium,
                                items: _mediumOptions,
                                itemLabel: (v) => v,
                                onChanged: (v) => setState(() => _medium = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('截止时间'),
                    SizedBox(height: ui(12)),
                    _DeadlinePicker(
                      value: _deadlineDisplay,
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                          helpText: '选择日期',
                          cancelText: '取消',
                          confirmText: '确定',
                          builder: appPickerDialogTheme,
                        );
                        if (picked == null || !context.mounted) return;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          helpText: '选择时间',
                          cancelText: '取消',
                          confirmText: '确定',
                          builder: appPickerDialogTheme,
                        );
                        if (t == null) return;
                        setState(() {
                          _deadlineDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            t.hour,
                            t.minute,
                          );
                        });
                      },
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('发布对象'),
                    SizedBox(height: ui(12)),
                    if (_loadingClasses)
                      Center(
                        child: CircularProgressIndicator(
                          color: _kPurple,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      for (var i = 0; i < _classList.length; i++) ...[
                        if (i > 0) SizedBox(height: ui(8)),
                        _ClassCheckRow(
                          title: _classList[i]['name']?.toString() ?? '班级$i',
                          kind: _classList[i]['type']?.toString() == '1'
                              ? '小班'
                              : '行政班',
                          people:
                              '${_classList[i]['studentCount'] ?? ''}人',
                          tag: _classList[i]['type']?.toString() == '1'
                              ? '小课'
                              : '大课',
                          checked: _selectedClassIndices.contains(i),
                          onTap: () => setState(() {
                            if (_selectedClassIndices.contains(i)) {
                              _selectedClassIndices.remove(i);
                            } else {
                              _selectedClassIndices.add(i);
                            }
                          }),
                        ),
                      ],
                    SizedBox(height: ui(20)),
                    _FieldLabel('作业要求'),
                    SizedBox(height: ui(12)),
                    _PlainTextArea(
                      hint: '说明题目范围、命名规则、提交格式等',
                      height: ui(80),
                      controller: _descCtrl,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: ui(20),
              right: ui(20),
              bottom: ui(20),
              child: _PrimaryGradientButton(
                icon: Icons.send_rounded,
                label: _publishing ? '发布中…' : '发布',
                onTap: _publishing ? null : _publish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassCheckRow extends StatelessWidget {
  const _ClassCheckRow({
    required this.title,
    required this.kind,
    required this.people,
    required this.tag,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final String kind;
  final String people;
  final String tag;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kPageGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CheckBox(checked: checked),
                SizedBox(width: ui(10)),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.4,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(4),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(4)),
                    border: Border.all(color: _kBorderSoft, width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: ui(6),
                        height: ui(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFA773FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: ui(4)),
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextDark,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ui(4)),
            Padding(
              padding: EdgeInsets.only(left: ui(24)),
              child: Row(
                children: [
                  Text(
                    kind,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(10)),
                  Text(
                    people,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
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

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(14),
      height: ui(14),
      decoration: BoxDecoration(
        color: checked ? _kPurple : Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(color: _kPurple),
      ),
      alignment: Alignment.center,
      child: checked
          ? Icon(Icons.check, size: ui(10), color: Colors.white)
          : null,
    );
  }
}

class _DeadlinePicker extends StatelessWidget {
  const _DeadlinePicker({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kPageGrey),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ),
            Icon(Icons.calendar_today_rounded, size: ui(16), color: _kPurple),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 历史发布记录右抽屉（344 宽）
// =============================================================================

class _HistoryDrawer extends ConsumerStatefulWidget {
  const _HistoryDrawer({required this.classId});

  final String classId;

  @override
  ConsumerState<_HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends ConsumerState<_HistoryDrawer> {
  List<_HomeworkItem> _items = [];
  bool _loading = true;
  final Map<int, String> _subjectNames = <int, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = widget.classId.trim();
    if (cid.isNotEmpty && cid != '0') {
      final sr = await ref.read(schoolRepositoryProvider).subjectList(classId: cid);
      if (!mounted) return;
      final parsed = _parseHomeworkSubjectList(sr);
      setState(() {
        for (final e in parsed) {
          _subjectNames[e.id] = e.name;
        }
      });
    }
    final res = await ref
        .read(teacherRepositoryProvider)
        .teacherHomeworkList(classId: widget.classId, status: 1, size: 50);
    if (!mounted) return;
    if (res.isSuccess) {
      final raw = res.data;
      final list = raw is Map ? (raw['records'] ?? raw['list'] ?? raw) : raw;
      if (list is List) {
        setState(() {
          _items = list.whereType<Map>().map(_HomeworkItem.fromMap).toList();
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(344),
        height: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ui(16), ui(20), ui(16), ui(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: ui(3.25),
                    height: ui(14.85),
                    decoration: BoxDecoration(
                      color: _kPurple,
                      borderRadius: BorderRadius.circular(ui(6)),
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Text(
                    '历史发布记录',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Padding(
                    padding: EdgeInsets.only(top: ui(4)),
                    child: Text(
                      _loading ? '加载中…' : '共${_items.length}条',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(20)),
              Container(height: 1, color: _kBorderSoft),
              SizedBox(height: ui(12)),
              if (_loading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: ui(40)),
                    child: CircularProgressIndicator(
                      color: _kPurple,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_items.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: ui(40)),
                    child: Text(
                      '暂无历史记录',
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextHint,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, idx) => SizedBox(height: ui(12)),
                    itemBuilder: (ctx, i) => _HistoryCard(
                      item: _items[i],
                      subjectDisplay:
                          _items[i].resolveSubjectDisplay(_subjectNames),
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.subjectDisplay});

  final _HomeworkItem item;
  final String subjectDisplay;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ui(104)),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.publishedRatio.submitted}',
                style: TextStyle(
                  fontSize: ui(28),
                  color: _kTextDark,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              SizedBox(width: ui(2)),
              Padding(
                padding: EdgeInsets.only(bottom: ui(4)),
                child: Text(
                  '/${item.publishedRatio.total}',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextHint,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(2)),
          Text(
            '截止 ${item.deadline}',
            style: TextStyle(
              fontSize: ui(10),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            item.classLabel,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(6)),
          _SubjectTag(label: subjectDisplay),
          SizedBox(height: ui(6)),
          Text(
            item.title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextBlack,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 作业点评右抽屉（600 宽）
// =============================================================================

class _ReviewDrawer extends ConsumerStatefulWidget {
  const _ReviewDrawer({
    required this.item,
    required this.submission,
    required this.homeworkSubjectDisplay,
    this.onReviewed,
  });

  final _HomeworkItem item;
  final _Submission submission;
  final String homeworkSubjectDisplay;
  final VoidCallback? onReviewed;

  @override
  ConsumerState<_ReviewDrawer> createState() => _ReviewDrawerState();
}

class _ReviewDrawerState extends ConsumerState<_ReviewDrawer> {
  final _scoreCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  bool _loadingDetail = false;
  Map<String, dynamic> _detailExtra = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 预填已有分数/评语（如果已批改过）
    if (widget.submission.score != null) {
      _scoreCtrl.text = '${widget.submission.score}';
    }
    if (widget.submission.feedback != null) {
      _commentCtrl.text = widget.submission.feedback!;
    }
    if (widget.submission.id.isNotEmpty) _loadStudentDetail();
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentDetail() async {
    setState(() => _loadingDetail = true);
    final res = await ref
        .read(teacherRepositoryProvider)
        .studentHomeworkDetail(id: widget.submission.id);
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(
        () => _detailExtra = _mergeStudentHomeworkDetailForReview(
          res.data as Map<dynamic, dynamic>,
        ),
      );
    }
    setState(() => _loadingDetail = false);
  }

  Future<void> _submitReview() async {
    final scoreStr = _scoreCtrl.text.trim();
    final score = int.tryParse(scoreStr);
    if (score == null || score < 0 || score > 100) {
      AppToast.show(context, '请输入有效分数（0-100）');
      return;
    }
    setState(() => _submitting = true);
    final res = await ref
        .read(teacherRepositoryProvider)
        .teacherHomeworkCorrect(
          id: widget.submission.id,
          score: score,
          feedback: _commentCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.isSuccess) {
      AppToast.show(context, '批改已发布');
      widget.onReviewed?.call();
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '提交失败，请重试');
    }
  }

  String get _fileName {
    final f = _detailExtra['submitAttachmentName']?.toString() ??
        _detailExtra['studentParam2']?.toString() ??
        _detailExtra['fileName']?.toString() ??
        _detailExtra['attachName']?.toString() ??
        widget.submission.fileName;
    return f?.trim().isNotEmpty == true ? f!.trim() : '作业附件';
  }

  String get _resolvedSubmitUrl {
    const keys = <String>[
      'fileUrl',
      'attachUrl',
      'submitFileUrl',
      'submitUrl',
      'url',
      'studentParam1',
    ];
    for (final k in keys) {
      final v = _detailExtra[k]?.toString().trim();
      if (v != null && v.isNotEmpty) {
        return k == 'studentParam1' ? MediaUrl.resolve(v) : v;
      }
    }
    final raw = widget.submission.fileUrl?.trim() ?? '';
    return raw.isEmpty ? '' : MediaUrl.resolve(raw);
  }

  bool get _hasAttachment => _resolvedSubmitUrl.isNotEmpty;

  String get _studentSubmitNote {
    return _detailExtra['studentSubmitDescription']?.toString().trim() ?? '';
  }

  String get _submitTypeForPreview {
    final a = _detailExtra['submitTypeTag']?.toString().trim() ?? '';
    if (a.isNotEmpty) return a;
    return _detailExtra['studentParam3']?.toString().trim() ?? '';
  }

  String _attachmentBadgeLabel(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'PDF';
    if (RegExp(r'\.(mp3|wav|m4a|aac|flac|ogg)(\?|#|$)').hasMatch(lower)) {
      return '音频';
    }
    if (RegExp(r'\.(mp4|webm|mov|m4v|ogv)(\?|#|$)').hasMatch(lower)) {
      return '视频';
    }
    if (RegExp(r'\.(png|jpg|jpeg|gif|webp|bmp|svg)(\?|#|$)').hasMatch(lower)) {
      return '图片';
    }
    return '文件';
  }

  String get _fileSize {
    final s = _detailExtra['fileSize']?.toString() ??
        _detailExtra['size']?.toString() ?? '';
    if (s.isEmpty) return '';
    final bytes = int.tryParse(s);
    if (bytes == null) return s;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}M';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}K';
    }
    return '${bytes}B';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(600),
        height: double.infinity,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(80)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DrawerTitleBar(title: '作业点评'),
                    SizedBox(height: ui(20)),
                    Container(height: 1, color: _kBorderSoft),
                    SizedBox(height: ui(16)),
                    _ReviewProfileRow(
                      submission: widget.submission,
                      item: widget.item,
                      homeworkSubjectDisplay: widget.homeworkSubjectDisplay,
                    ),
                    SizedBox(height: ui(16)),
                    if (!_loadingDetail && _studentSubmitNote.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: ui(12)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(ui(10)),
                          decoration: BoxDecoration(
                            color: _kPageGrey,
                            borderRadius: BorderRadius.circular(ui(8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '学生提交说明',
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextMuted,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w400,
                                ),
                              ),
                              SizedBox(height: ui(4)),
                              Text(
                                _studentSubmitNote,
                                style: TextStyle(
                                  fontSize: ui(13),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w400,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_loadingDetail)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: ui(12)),
                          child: CircularProgressIndicator(
                            color: _kPurple,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (_hasAttachment)
                      _AttachmentCard(
                        filename: _fileName,
                        size: _fileSize,
                        badgeLabel: _attachmentBadgeLabel(_fileName),
                        onPreview: () => showStudentHomeworkSubmissionPreview(
                          context,
                          ref: ref,
                          fileUrl: _resolvedSubmitUrl,
                          title: _fileName,
                          typeTag:
                              '${widget.item.expectedExtRaw} $_submitTypeForPreview'
                                  .trim(),
                          mediumLabel: _submitTypeForPreview.isNotEmpty
                              ? _submitTypeForPreview
                              : widget.item.suggested,
                          attachmentName: _fileName,
                        ),
                        onDownload: () => openCoursewareUrl(_resolvedSubmitUrl),
                      ),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '批改与点评',
                          style: TextStyle(
                            fontSize: ui(16),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                            height: 1,
                          ),
                        ),
                        SizedBox(width: ui(12)),
                        Expanded(
                          child: Container(height: 1, color: _kBorderSoft),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(16)),
                    _FieldLabel('分数/100'),
                    SizedBox(height: ui(8)),
                    _ScoreInput(controller: _scoreCtrl),
                    SizedBox(height: ui(16)),
                    _FieldLabel('点评'),
                    SizedBox(height: ui(8)),
                    _PlainTextArea(
                      hint: '请输入对该次作业的点评内容…',
                      height: ui(100),
                      controller: _commentCtrl,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: ui(20),
              right: ui(20),
              bottom: ui(20),
              child: _PrimaryGradientButton(
                icon: Icons.check_circle_outline_rounded,
                label: _submitting ? '提交中…' : '发布批改',
                onTap: _submitting ? null : _submitReview,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewProfileRow extends StatelessWidget {
  const _ReviewProfileRow({
    required this.submission,
    required this.item,
    required this.homeworkSubjectDisplay,
  });

  final _Submission submission;
  final _HomeworkItem item;
  final String homeworkSubjectDisplay;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(40),
          height: ui(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: _AvatarCircle(
            name: submission.studentName,
            seed: submission.avatarSeed,
            size: 40,
            imageUrl: submission.avatarUrl,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      submission.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  _StatusPill(state: submission.state),
                ],
              ),
              SizedBox(height: ui(4)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$homeworkSubjectDisplay · ${item.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Text(
                    submission.uploadAt,
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
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.filename,
    required this.size,
    required this.badgeLabel,
    required this.onPreview,
    required this.onDownload,
  });

  final String filename;
  final String size;
  final String badgeLabel;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(40),
            height: ui(40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD7E2FF), Color(0xFFF9FBFF)],
              ),
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: const Color(0xFFE5EFFF)),
            ),
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5040),
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  size,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: Icons.file_download_outlined,
            label: '下载',
            onTap: onDownload,
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: Icons.remove_red_eye_outlined,
            label: '在线预览',
            onTap: onPreview,
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(33),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ui(14), color: _kPillIconColor),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreInput extends StatelessWidget {
  const _ScoreInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPageGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '请输入分数',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                ),
              ),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
          Text(
            ' / 100',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 抽屉里通用零件
// =============================================================================

class _DrawerTitleBar extends StatelessWidget {
  const _DrawerTitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: _kPurple,
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          title,
          style: TextStyle(
            fontSize: ui(16),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: Colors.black,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.4,
      ),
    );
  }
}

class _PlainInputField extends StatefulWidget {
  const _PlainInputField({required this.hint, this.controller});

  final String hint;
  final TextEditingController? controller;

  @override
  State<_PlainInputField> createState() => _PlainInputFieldState();
}

class _PlainInputFieldState extends State<_PlainInputField> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPageGrey),
      ),
      child: Center(
        child: TextField(
          controller: _ctrl,
          cursorColor: _kPurple,
          cursorWidth: 1.5,
          cursorHeight: ui(16),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          ),
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PlainTextArea extends StatefulWidget {
  const _PlainTextArea({
    required this.hint,
    required this.height,
    this.controller,
  });

  final String hint;
  final double height;
  final TextEditingController? controller;

  @override
  State<_PlainTextArea> createState() => _PlainTextAreaState();
}

class _PlainTextAreaState extends State<_PlainTextArea> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) {
      _ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPageGrey),
      ),
      child: TextField(
        controller: _ctrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [_kPurpleEnd, _kPurpleStart],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: ui(16), color: Colors.white),
            SizedBox(width: ui(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 解析 `POST /app/school/v2/user/subjectList` 返回的科目列表（兼容 data / records / list）。
List<({int id, String name})> _parseHomeworkSubjectList(ApiResponse resp) {
  if (!resp.isSuccess) return [];
  dynamic raw = resp.data;
  if (raw is Map) {
    if (raw.containsKey('data')) {
      final d = raw['data'];
      if (d is List) {
        raw = d;
      } else if (d is Map) {
        raw = d['records'] ?? d['list'] ?? const <dynamic>[];
      }
    } else if (raw['records'] is List) {
      raw = raw['records'];
    } else if (raw['list'] is List) {
      raw = raw['list'];
    }
  }
  if (raw is! List) return [];
  final out = <({int id, String name})>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final m = item;
    final idStr =
        m['id']?.toString() ?? m['subjectId']?.toString() ?? '';
    final name =
        m['name']?.toString() ?? m['subjectName']?.toString() ?? '';
    if (idStr.isEmpty || name.isEmpty) continue;
    final id = int.tryParse(idStr);
    if (id == null || id <= 0) continue;
    out.add((id: id, name: name));
  }
  return out;
}
