// 学生模型上的「专业 / 方向 / 行政班 / 住宿 / 电话 / 备注」均为带默认值的
// 命名参数，部分条目沿用默认值；analyzer 误报为 unused_element_parameter，整体忽略。
// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ============================================================================
// 颜色常量
// ============================================================================

const Color _kBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kTextPrimary = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextSub = Color(0xFF6D6B75);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoft = Color(0xFFDAD2FF);
const Color _kBorder = Color(0xFFF3F2F3);

// ============================================================================
// 数据模型 + 演示数据
// ============================================================================

enum _StudentStatus { enrolled, suspended, transferring, graduated }

/// 把后端 `status` 字段（数字 / 字符串 / 中文）兜底映射到本地枚举：
/// - 1 / 'enrolled' / '在籍' → enrolled
/// - 2 / 'suspended' / '休学' → suspended
/// - 3 / 'transferring' / '转学' → transferring
/// - 4 / 'graduated' / '毕业' → graduated
/// - 其它（含 null）→ enrolled（最常见，作为安全默认）
_StudentStatus _parseStudentStatus(dynamic raw) {
  if (raw == null) return _StudentStatus.enrolled;
  final s = raw.toString().toLowerCase();
  if (s == '1' || s == 'enrolled' || raw.toString().contains('在籍')) {
    return _StudentStatus.enrolled;
  }
  if (s == '2' || s == 'suspended' || raw.toString().contains('休学')) {
    return _StudentStatus.suspended;
  }
  if (s == '3' || s == 'transferring' || raw.toString().contains('转学')) {
    return _StudentStatus.transferring;
  }
  if (s == '4' || s == 'graduated' || raw.toString().contains('毕业')) {
    return _StudentStatus.graduated;
  }
  return _StudentStatus.enrolled;
}

extension on _StudentStatus {
  String get label {
    switch (this) {
      case _StudentStatus.enrolled:
        return '在籍';
      case _StudentStatus.suspended:
        return '休学';
      case _StudentStatus.transferring:
        return '转学中';
      case _StudentStatus.graduated:
        return '毕业';
    }
  }

  Color get bg {
    switch (this) {
      case _StudentStatus.enrolled:
        return _kPurpleSoft;
      case _StudentStatus.suspended:
        return const Color(0xFFFFE7C2);
      case _StudentStatus.transferring:
        return const Color(0xFFD2EAFF);
      case _StudentStatus.graduated:
        return const Color(0xFFE0E0E0);
    }
  }

  Color get fg {
    switch (this) {
      case _StudentStatus.enrolled:
        return _kPurple;
      case _StudentStatus.suspended:
        return const Color(0xFFE89B30);
      case _StudentStatus.transferring:
        return const Color(0xFF1F77E0);
      case _StudentStatus.graduated:
        return const Color(0xFF6D6B75);
    }
  }
}

class _Student {
  const _Student({
    required this.name,
    required this.studentId,
    required this.classInfo,
    required this.dormInfo,
    required this.status,
    this.major = '声乐',
    this.direction = '民族唱法',
    this.adminClass = '高三音乐实验班',
    this.dorm = '女生公寓 A-602',
    this.phone = '17656287947',
    this.parentPhone = '17656287947',
    this.recentChange = '无',
    this.remark = '专业主项稳定，文化科需跟进英语作文。',
  });

  final String name;
  final String studentId;
  final String classInfo;
  final String dormInfo;
  final _StudentStatus status;

  final String major;
  final String direction;
  final String adminClass;
  final String dorm;
  final String phone;
  final String parentPhone;
  final String recentChange;
  final String remark;

  /// 从后端 `studentList` 单条记录构造。
  ///
  /// 字段名做了若干兜底（`name` / `stuName` / `studentName`、
  /// `studentNo` / `studentId` / `stuNo` / `no`、`className` / `class` 等），
  /// 找不到时回退为占位串，避免空白卡片。
  factory _Student.fromJson(Map<String, dynamic> json) {
    // 后端实际返回 realname / nickname / no / studentStatus（小写驼峰）。
    final name = _pickString(json, [
      'realname',
      'realName',
      'nickname',
      'nickName',
      'name',
      'stuName',
      'studentName',
    ], '未命名');
    final studentNo = _pickString(json, [
      'no',
      'studentNo',
      'studentId',
      'stuNo',
      'stuId',
      'code',
      'studentCode',
    ], '');
    final className = _pickString(json, [
      'className',
      'class',
      'gradeName',
      'classFullName',
    ], '');
    final majorName = _pickString(json, [
      'majorName',
      'major',
      'subject',
      'subjectName',
    ], '声乐');
    final directionName = _pickString(json, [
      'directionName',
      'direction',
      'directionText',
      'majorDirection',
    ], '民族唱法');
    final dormName = _pickString(json, [
      'dorm',
      'dormName',
      'roomName',
      'apartment',
      'dormitory',
    ], '');
    final isLiving =
        json['isLiving'] == 1 ||
        json['isLiving'] == true ||
        json['liveSchool'] == 1 ||
        json['liveSchool'] == true ||
        dormName.isNotEmpty;
    final phone = _pickString(json, [
      'phone',
      'mobile',
      'studentPhone',
      'stuPhone',
      'tel',
    ], '');
    final parentPhone = _pickString(json, [
      'parentPhone',
      'parentMobile',
      'fatherPhone',
      'motherPhone',
      'guardianPhone',
    ], phone);
    final remark = _pickString(json, [
      'remark',
      'comment',
      'description',
      'note',
    ], '');

    // 拼接「行政班·主项·方向」一行；分隔符使用「·」。
    final classInfoBuf = StringBuffer();
    if (className.isNotEmpty) classInfoBuf.write(className);
    if (majorName.isNotEmpty) {
      if (classInfoBuf.isNotEmpty) classInfoBuf.write('·');
      classInfoBuf.write(majorName);
    }
    if (directionName.isNotEmpty) {
      if (classInfoBuf.isNotEmpty) classInfoBuf.write('·');
      classInfoBuf.write(directionName);
    }

    final dormInfo = isLiving
        ? (dormName.isEmpty ? '住校' : '住校·$dormName')
        : '走读';

    return _Student(
      name: name,
      studentId: studentNo,
      classInfo: classInfoBuf.isEmpty ? '—' : classInfoBuf.toString(),
      dormInfo: dormInfo,
      status: _parseStudentStatus(
        json['studentStatus'] ?? json['status'] ?? json['stuStatus'],
      ),
      major: majorName,
      direction: directionName,
      adminClass: className.isEmpty ? '—' : className,
      dorm: dormName.isEmpty ? '—' : dormName,
      phone: phone,
      parentPhone: parentPhone,
      recentChange: _pickString(json, [
        'lastChange',
        'recentChange',
        'changeDesc',
        'transferRemark',
      ], '无'),
      remark: remark.isEmpty ? '—' : remark,
    );
  }
}

/// 在 [json] 中按 [keys] 顺序找到第一个非空字符串值，否则返回 [fallback]。
String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

const _kAllClasses = '全部班级';
const _kFallbackClassOptions = <String>[_kAllClasses];

// ============================================================================
// 入口视图
// ============================================================================

/// 管理员端「学生管理」总览页。
///
/// 自上而下：
/// 1. **顶部白色 banner**（970×62，白→#F9EDFF 微紫渐变 + 16 圆角）：
///    左 32 返回按钮 + 居中标题「学生管理」16/600 + 12 灰副标题。
/// 2. **4 张彩色渐变统计卡**（100 高 + 12 圆角）：
///    在籍学生 / 住校人数 / 非在籍·异动 / 名册总数；分别紫 / 橙 / 绿 / 红
///    渐变 (#E7DCFF / #FFF0DC / #DCFFE7 / #FFE2DC) + 14/500 标题
///    + 32/Barlow/500 大数字。
/// 3. **筛选行**：左侧白色 pill 容器内 5 个状态 tab（全部 / 在籍 / 休学 /
///    转学 / 毕业，黑底白字 active）；右侧并排 [PopupSelectorField]
///    「全部班级」+ 324×44 搜索框（占位 "搜索姓名、学号、手机、宿舍、家长"）。
/// 4. **结果条**：「当前结果 X 人」12 #0B081A。
/// 5. **学生卡 3 列网格**（315×78 白卡，12 gap）：左 40 头像 + 右上学号 +
///    名字 + 一句话班级·专业 + 灰色住宿。右上角 38×22 紫色「在籍」徽章
///    （cut-corner 形状，根据状态着色）。
///
/// 卡片整体可点 → 「学籍档案」`GradientHeaderDialog`：
/// 顶部 #D2C6FF→白渐变 + 头像 / 姓名 / 专业 / 学号；7 行键值（行政班 /
/// 专业方向 / 住宿 / 本人手机 / 家长手机 / 最近异动 / 备注）；
/// 底部「导出学籍 / 取消」`AppDialogActionBar`。
///
/// 数据接入：进入页面立刻并发请求三条 v2 教务管理端接口
///   - `POST /app/school/v2/manager/classList`   → 「全部班级」dropdown
///   - `POST /app/school/v2/manager/studentSum`  → 顶部 4 张统计卡口径
///     (`normalCount` / `residentCount` / `abnormalCount` / `totalCount`)
///   - `POST /app/school/v2/manager/studentList` → 学生卡列表
///     (新签名：`archiveId` / `classId` / `current` / `keyword` / `size` /
///     `studentStatus`)
///
/// 班级筛选 / 关键字 / 状态变化时只重新拉 `studentList`（带 classId /
/// keyword / studentStatus 参数）；统计卡口径来自 `studentSum`，不会被
/// 列表筛选反复触发。所有 mock / 兜底数据已移除，接口未返回 / 报错时
/// 列表显示为空，统计卡显示 0。
class AdminStudentManagementView extends ConsumerStatefulWidget {
  const AdminStudentManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminStudentManagementView> createState() =>
      _AdminStudentManagementViewState();
}

class _AdminStudentManagementViewState
    extends ConsumerState<AdminStudentManagementView> {
  /// `null` = 全部状态
  _StudentStatus? _statusFilter;
  String _classFilter = _kAllClasses;
  String _searchKw = '';

  /// 班级 id 索引：label → 后端 id（全部班级映射为 null）。
  /// id 为雪花 long，必须以 String 形态保存，避免 web 端 JS number
  /// 精度截断改写后几位。
  Map<String, String?> _classIdMap = const <String, String?>{};
  List<String> _classOptions = _kFallbackClassOptions;

  /// `studentList` 拉到的学生（按当前 classId/status/keyword 过滤后的服务端
  /// 结果）。`null` = 还没拉到 / 接口失败 → 显示空态；空数组 = 接口成功但
  /// 当前条件下没有学生 → 也显示空态。不再使用任何本地 mock 兜底。
  List<_Student>? _serverStudents;

  /// `studentSum` 接口返回的整校口径统计：
  ///   normal / resident / abnormal / total。
  /// 任一值为 -1 表示尚未拉到 / 失败 → 顶部 4 卡回退到本地计算。
  int _sumNormal = -1;
  int _sumResident = -1;
  int _sumAbnormal = -1;
  int _sumTotal = -1;

  bool _loadingStudents = true;
  // 防抖：搜索框输入时用 token 控制最近一次请求；过期请求结果丢弃。
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    // 延后到 build 之后再触发，确保 ref 可读。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
      _loadSum();
      _loadStudents();
    });
  }

  Future<void> _loadClasses() async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList();
    if (!mounted) return;

    if (!resp.isSuccess || resp.data == null) {
      // 失败时保留兜底选项，不打断页面。
      return;
    }

    final raw = resp.data;
    final list = raw is List
        ? raw
        : (raw is Map && raw['records'] is List
              ? raw['records'] as List
              : const []);

    final map = <String, String?>{_kAllClasses: null};
    for (final item in list) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final label = _pickString(m, [
        'className',
        'class',
        'name',
        'fullName',
        'classFullName',
      ], '');
      if (label.isEmpty) continue;
      // 班级 id 是雪花 long → 全程 String，禁止 int.parse。
      final idRaw = m['id'] ?? m['classId'] ?? m['cId'];
      final id = idRaw == null ? null : '$idRaw';
      map[label] = (id != null && id.isNotEmpty) ? id : null;
    }

    if (map.length <= 1) return; // 接口为空，沿用 demo
    setState(() {
      _classIdMap = map;
      _classOptions = map.keys.toList();
      // 当前选中的班级如果不在新列表里，重置为「全部班级」。
      if (!_classOptions.contains(_classFilter)) {
        _classFilter = _kAllClasses;
      }
    });
  }

  /// 拉学生总览统计：4 张卡（在籍 / 住校 / 异动 / 总数）的口径来源。
  /// 与 [_loadStudents] 解耦，列表筛选不会触发它，避免无谓刷新。
  Future<void> _loadSum() async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.studentSum();
    if (!mounted) return;

    if (!resp.isSuccess || resp.data is! Map) return;
    final m = (resp.data as Map).cast<String, dynamic>();
    int? n(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    setState(() {
      _sumNormal = n(m['normalCount']) ?? 0;
      _sumResident = n(m['residentCount']) ?? 0;
      _sumAbnormal = n(m['abnormalCount']) ?? 0;
      _sumTotal = n(m['totalCount']) ?? 0;
    });
  }

  Future<void> _loadStudents() async {
    final token = ++_searchToken;
    setState(() => _loadingStudents = true);

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.studentList(
      classId: _classIdMap[_classFilter],
      keyword: _searchKw.trim().isEmpty ? null : _searchKw.trim(),
      // studentStatus 传中文：在籍 / 休学 / 转学 / 毕业（与 tab 文案一致）。
      studentStatus: _statusFilter?.label,
    );
    if (!mounted || token != _searchToken) return;

    if (!resp.isSuccess || resp.data == null) {
      setState(() {
        _serverStudents = null;
        _loadingStudents = false;
      });
      return;
    }

    final raw = resp.data;
    final list = raw is List
        ? raw
        : (raw is Map && raw['records'] is List
              ? raw['records'] as List
              : const []);
    final parsed = <_Student>[];
    for (final item in list) {
      if (item is Map) {
        try {
          parsed.add(_Student.fromJson(item.cast<String, dynamic>()));
        } catch (_) {
          // 单条解析失败跳过，整体继续。
        }
      }
    }

    setState(() {
      _serverStudents = parsed;
      _loadingStudents = false;
    });
  }

  /// 实际渲染用的学生列表：完全以服务端数据为准；服务端尚未返回时
  /// 显示为空。已经移除本地 mock 兜底。
  List<_Student> get _students => _serverStudents ?? const <_Student>[];

  /// 服务端已经按 classId / studentStatus / keyword 过滤过，直接渲染。
  List<_Student> get _filtered => _students;

  void _openProfile(_Student s) {
    showScaledDialog<void>(
      context: context,
      builder: (ctx) => _StudentProfileDialog(student: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = _filtered;

    // 4 个统计完全由 `studentSum` 接口给出；接口未返回 / 失败时显示 0。
    final enrolled = _sumNormal >= 0 ? _sumNormal : 0;
    final dormCount = _sumResident >= 0 ? _sumResident : 0;
    final inactive = _sumAbnormal >= 0 ? _sumAbnormal : 0;
    final total = _sumTotal >= 0 ? _sumTotal : 0;

    return Container(
      color: _kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: ui(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _StatsRow(
              enrolled: enrolled,
              dormCount: dormCount,
              inactive: inactive,
              total: total,
            ),
            SizedBox(height: ui(16)),
            _FilterRow(
              statusFilter: _statusFilter,
              classFilter: _classFilter,
              classOptions: _classOptions,
              onStatusChanged: (s) {
                setState(() => _statusFilter = s);
                _loadStudents();
              },
              onClassChanged: (c) {
                setState(() => _classFilter = c);
                _loadStudents();
              },
              onSearchChanged: (kw) {
                setState(() => _searchKw = kw);
                _loadStudents();
              },
            ),
            SizedBox(height: ui(20)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '当前结果 ${list.length}人',
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.2,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                if (_loadingStudents) ...[
                  SizedBox(width: ui(8)),
                  SizedBox(
                    width: ui(12),
                    height: ui(12),
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: ui(12)),
            _StudentGrid(students: list, onTap: _openProfile),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Banner
// ============================================================================

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Container(
                width: ui(32),
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorder, width: 1),
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: ui(20),
                  color: _kTextPrimary,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '学生管理',
                  style: TextStyle(
                    fontSize: ui(16),
                    height: 1.2,
                    fontWeight: AppFont.w600,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '全量在籍视图：行政班、学籍状态、住宿与联系方式；支持检索与导出。与学生端名册同源口径。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.2,
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4 统计卡
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.enrolled,
    required this.dormCount,
    required this.inactive,
    required this.total,
  });

  final int enrolled;
  final int dormCount;
  final int inactive;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cards = <_StatGradientCard>[
      _StatGradientCard(
        label: '在籍学生',
        value: enrolled,
        gradientStart: const Color(0xFFE7DCFF),
        icon: Icons.school_outlined,
        iconColor: const Color(0xFFA985FF),
      ),
      _StatGradientCard(
        label: '住校人数',
        value: dormCount,
        gradientStart: const Color(0xFFFFF0DC),
        icon: Icons.bed_outlined,
        iconColor: const Color(0xFFFFB85C),
      ),
      _StatGradientCard(
        label: '非在籍/异动',
        value: inactive,
        gradientStart: const Color(0xFFDCFFE7),
        icon: Icons.swap_horiz,
        iconColor: const Color(0xFF52C49A),
      ),
      _StatGradientCard(
        label: '名册总数',
        value: total,
        gradientStart: const Color(0xFFFFE2DC),
        icon: Icons.menu_book_outlined,
        iconColor: const Color(0xFFFF8A75),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) SizedBox(width: ui(12)),
        ],
      ],
    );
  }
}

class _StatGradientCard extends StatelessWidget {
  const _StatGradientCard({
    required this.label,
    required this.value,
    required this.gradientStart,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final int value;
  final Color gradientStart;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [gradientStart, Colors.white],
          stops: const [0, 0.73],
        ),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(12), ui(12)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  fontWeight: AppFont.w500,
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                ),
              ),
              SizedBox(height: ui(8)),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: ui(32),
                  height: 1.0,
                  fontWeight: FontWeight.w500,
                  color: _kTextPrimary,
                  fontFamily: 'Barlow',
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              icon,
              size: ui(54),
              color: iconColor.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 筛选行：状态 tabs + 班级 dropdown + 搜索
// ============================================================================

class _FilterRow extends StatefulWidget {
  const _FilterRow({
    required this.statusFilter,
    required this.classFilter,
    required this.classOptions,
    required this.onStatusChanged,
    required this.onClassChanged,
    required this.onSearchChanged,
  });

  final _StudentStatus? statusFilter;
  final String classFilter;
  final List<String> classOptions;
  final ValueChanged<_StudentStatus?> onStatusChanged;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final tabs = <(String, _StudentStatus?)>[
      ('全部', null),
      ..._StudentStatus.values.map((s) => (s.label, s)),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in tabs)
                _StatusPill(
                  label: t.$1,
                  active: t.$2 == widget.statusFilter,
                  onTap: () => widget.onStatusChanged(t.$2),
                ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: ui(140),
          child: PopupSelectorField<String>(
            value: widget.classOptions.contains(widget.classFilter)
                ? widget.classFilter
                : widget.classOptions.first,
            items: widget.classOptions,
            itemLabel: (s) => s,
            onChanged: widget.onClassChanged,
          ),
        ),
        SizedBox(width: ui(12)),
        Container(
          width: ui(324),
          height: ui(44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          child: Row(
            children: [
              Icon(Icons.search, size: ui(16), color: const Color(0xFFC6C6C6)),
              SizedBox(width: ui(10)),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: widget.onSearchChanged,
                  cursorColor: _kPurple,
                  cursorWidth: 1.5,
                  cursorHeight: ui(16),
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '搜索姓名、学号、手机、宿舍、家长',
                    hintStyle: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFFD1D1D1),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        margin: EdgeInsets.symmetric(horizontal: ui(2)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kTextPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            height: 1.2,
            fontWeight: AppFont.w500,
            color: active ? Colors.white : _kTextSub,
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 学生卡 3 列网格
// ============================================================================

class _StudentGrid extends StatelessWidget {
  const _StudentGrid({required this.students, required this.onTap});

  final List<_Student> students;
  final ValueChanged<_Student> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (students.isEmpty) {
      return Container(
        height: ui(120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Text(
          '暂无符合条件的学生',
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cols = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 600 ? 2 : 1);
        final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in students)
              SizedBox(
                width: cardWidth,
                child: _StudentCard(student: s, onTap: () => onTap(s)),
              ),
          ],
        );
      },
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});

  final _Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: ui(78)),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(12), ui(10), ui(46), ui(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: student.name),
                  SizedBox(width: ui(8)),
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
                                student.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  height: 1.2,
                                  fontWeight: AppFont.w500,
                                  color: _kTextPrimary,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ),
                            SizedBox(width: ui(8)),
                            Text(
                              student.studentId,
                              style: TextStyle(
                                fontSize: ui(12),
                                height: 1.2,
                                color: _kTextHint,
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ui(6)),
                        Text(
                          student.classInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.2,
                            color: _kTextPrimary,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        SizedBox(height: ui(4)),
                        Text(
                          student.dormInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.2,
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 右上角状态徽章：38×22，top-right 12 + bottom-left 12 圆角，
            // 左上 / 右下 直角，与卡片右上角圆角无缝贴合。
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                height: ui(22),
                padding: EdgeInsets.symmetric(horizontal: ui(8)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: student.status.bg,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(ui(12)),
                    bottomLeft: Radius.circular(ui(12)),
                  ),
                ),
                child: Text(
                  student.status.label,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.0,
                    color: student.status.fg,
                    fontFamily: 'PingFang SC',
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isEmpty ? '·' : name.characters.first;
    return Container(
      width: ui(40),
      height: ui(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kPurpleSoft,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(16),
          height: 1.0,
          fontWeight: AppFont.w600,
          color: _kPurple,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

// ============================================================================
// 学籍档案 弹窗
// ============================================================================

class _StudentProfileDialog extends StatelessWidget {
  const _StudentProfileDialog({required this.student});

  final _Student student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return GradientHeaderDialog(
      title: '学籍档案',
      titleFontSize: 20,
      titleFontWeight: FontWeight.w500,
      titlePaddingTop: 28,
      width: 428,
      headerAsset: null,
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: '导出学籍',
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(name: student.name),
              SizedBox(width: ui(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        fontSize: ui(16),
                        height: 1.2,
                        fontWeight: AppFont.w600,
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      '${student.major} · ${student.direction}',
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.2,
                        color: _kTextSub,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                    SizedBox(height: ui(2)),
                    Text(
                      student.studentId,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.2,
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(20)),
          _ProfileRow(label: '行政班：', value: student.adminClass),
          _ProfileRow(label: '专业方向：', value: student.direction),
          _ProfileRow(label: '住宿：', value: student.dorm),
          _ProfileRow(label: '本人手机：', value: student.phone),
          _ProfileRow(label: '家长手机：', value: student.parentPhone),
          _ProfileRow(label: '最近异动：', value: student.recentChange),
          _ProfileRow(label: '备注：', value: student.remark, multiline: true),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: ui(8)),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ui(80),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                height: 1.4,
                color: _kTextHint,
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ui(14),
                height: 1.4,
                color: _kTextPrimary,
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
