import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/media_url.dart';
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
const Color _kGreen = Color(0xFF0CAC40);
const Color _kBorder = Color(0xFFF3F2F3);
const Color _kHeadTeacherTagBg = Color(0xFFDBEE49);

// ============================================================================
// 数据模型
// ============================================================================

enum _TeacherStatus { onDuty, leave, maternity }

extension on _TeacherStatus {
  String get label {
    switch (this) {
      case _TeacherStatus.onDuty:
        return '在岗';
      case _TeacherStatus.leave:
        return '请假';
      case _TeacherStatus.maternity:
        return '产假';
    }
  }

  /// 右上角徽章背景：在岗用浅绿，其它两类共用浅灰。
  Color get tagBg {
    switch (this) {
      case _TeacherStatus.onDuty:
        return const Color(0xFFDFFCF0);
      case _TeacherStatus.leave:
      case _TeacherStatus.maternity:
        return const Color(0xFFF3F2F3);
    }
  }

  /// 圆点 / 文字色。
  Color get tagFg {
    switch (this) {
      case _TeacherStatus.onDuty:
        return _kGreen;
      case _TeacherStatus.leave:
      case _TeacherStatus.maternity:
        return _kTextHint;
    }
  }
}

_TeacherStatus _parseTeacherStatus(dynamic raw) {
  if (raw == null) return _TeacherStatus.onDuty;
  final s = raw.toString().toLowerCase();
  final cn = raw.toString();
  if (s == '1' || s == 'onduty' || s == 'normal' || cn.contains('在岗')) {
    return _TeacherStatus.onDuty;
  }
  if (s == '2' || s == 'leave' || cn.contains('请假')) {
    return _TeacherStatus.leave;
  }
  if (s == '3' || s == 'maternity' || cn.contains('产假')) {
    return _TeacherStatus.maternity;
  }
  return _TeacherStatus.onDuty;
}

class _Teacher {
  const _Teacher({
    required this.name,
    required this.teacherId,
    required this.subjectInfo,
    required this.roleInfo,
    required this.status,
    this.avatarUrl = '',
    this.nickname = '',
    this.gender = '',
    this.introduce = '',
    this.isHeadTeacher = false,
    this.department = '',
    this.subjects = '',
    this.headTeacherClass = '',
    this.phone = '',
    this.entryDate = '',
    this.remark = '',
  });

  final String name;

  /// 工号 / 教师编号。
  final String teacherId;

  /// 头像 URL。来自 `headUrl` 字段，已通过 [MediaUrl.resolve] 拼到完整地址；
  /// 空串表示后端未配置头像，UI 走「首字母占位」兜底。
  final String avatarUrl;

  /// 卡片中段「主任课方向」一句话：音乐专业部·乐理·视唱练耳·和声基础。
  /// 当后端没有部门 / 学科字段时回落到 [introduce]，再退到 "—"。
  final String subjectInfo;

  /// 卡片底部「角色 + 带班」一句话：任课·班主任·高三音乐实验班。
  /// 当前后端 teacherList 接口暂不下发角色集合，默认仅展示 "任课"。
  final String roleInfo;
  final _TeacherStatus status;

  /// 直接来自后端的字段，主要用于「教师档案」弹窗展示，未参与卡片渲染。
  final String nickname;
  final String gender;
  final String introduce;

  final bool isHeadTeacher;

  final String department;
  final String subjects;
  final String headTeacherClass;
  final String phone;
  final String entryDate;
  final String remark;

  factory _Teacher.fromJson(Map<String, dynamic> json) {
    // 后端实际返回 realname / nickname / no / teacherStatus / headUrl 等。
    // 命名取首位非空字段，提供少量历史别名兜底（旧接口曾出现 realName /
    // teacherNo 这类大小写不一致的形式）。所有 fallback 一律 ''，不填演示值。
    final name = _pickString(json, [
      'realname',
      'realName',
      'nickname',
      'nickName',
      'name',
      'teacherName',
    ], '未命名');
    final no = _pickString(json, [
      'no',
      'teacherNo',
      'teacherId',
      'code',
      'workNo',
      'employeeNo',
    ], '');
    final department = _pickString(json, [
      'department',
      'departmentName',
      'deptName',
      'dept',
      'majorDepartment',
    ], '');
    final subjects = _pickString(json, [
      'subjects',
      'subjectName',
      'subject',
      'teachSubject',
      'directionName',
      'directions',
    ], '');
    final headTeacherClass = _pickString(json, [
      'headTeacherClass',
      'classFullName',
      'className',
      'class',
    ], '');
    final extraRoles = _pickString(json, [
      'roleName',
      'roleText',
      'rolesText',
      'positionName',
    ], '');
    final introduce = _pickString(json, [
      'introduce',
      'intro',
      'bio',
      'description',
    ], '');
    final nickname = _pickString(json, ['nickname', 'nickName'], '');
    final gender = _pickString(json, ['gender', 'sex'], '');

    final rawHeadUrl = _pickString(json, [
      'headUrl',
      'avatarUrl',
      'avatar',
      'headImg',
      'photoUrl',
    ], '');
    final avatarUrl = rawHeadUrl.isEmpty ? '' : MediaUrl.resolve(rawHeadUrl);

    // 顶部主任课方向：把「部门」和「学科」拼接，分隔符 ·。
    // 都没有时退回 introduce，再退到 "—"；不再硬塞 "音乐专业部" 这类占位。
    final subjectInfoBuf = StringBuffer();
    if (department.isNotEmpty) subjectInfoBuf.write(department);
    if (subjects.isNotEmpty) {
      if (subjectInfoBuf.isNotEmpty) subjectInfoBuf.write('·');
      subjectInfoBuf.write(subjects);
    }
    final String subjectInfo;
    if (subjectInfoBuf.isNotEmpty) {
      subjectInfo = subjectInfoBuf.toString();
    } else if (introduce.isNotEmpty) {
      subjectInfo = introduce;
    } else {
      subjectInfo = '—';
    }

    final isHeadTeacher =
        json['isHeadTeacher'] == 1 ||
        json['isHeadTeacher'] == true ||
        json['isClassTeacher'] == 1 ||
        json['isClassTeacher'] == true ||
        headTeacherClass.isNotEmpty;

    // 底部角色行：默认 "任课"，命中班主任 / 教研角色 / 班级时按 · 追加。
    final roleParts = <String>['任课'];
    if (isHeadTeacher) {
      roleParts.add('班主任');
      if (headTeacherClass.isNotEmpty) roleParts.add(headTeacherClass);
    }
    if (extraRoles.isNotEmpty) {
      roleParts.add(extraRoles);
    }
    final roleInfo = roleParts.join('·');

    return _Teacher(
      name: name,
      teacherId: no,
      avatarUrl: avatarUrl,
      subjectInfo: subjectInfo,
      roleInfo: roleInfo,
      status: _parseTeacherStatus(
        json['teacherStatus'] ?? json['status'] ?? json['workStatus'],
      ),
      nickname: nickname,
      gender: gender,
      introduce: introduce,
      isHeadTeacher: isHeadTeacher,
      department: department,
      subjects: subjects,
      headTeacherClass: headTeacherClass,
      phone: _pickString(json, ['phone', 'mobile', 'tel'], ''),
      entryDate: _pickString(json, ['entryDate', 'hireDate', 'joinDate'], ''),
      remark: _pickString(json, ['remark', 'comment', 'note'], ''),
    );
  }
}

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
const _kBaseClassOptions = <String>[_kAllClasses];

// ============================================================================
// 入口视图
// ============================================================================

/// 管理员端「教师管理」总览页。
///
/// 自上而下：
/// 1. **顶部白色 banner**（970×62，白→#F9EDFF 微紫渐变 + 16 圆角）：
///    左 32 返回按钮 + 居中标题「教师管理」16/600 + 12 灰副标题。
/// 2. **5 张彩色渐变统计卡**（100 高 + 12 圆角）：
///    在岗 / 请假 / 产假 / 班主任 / 名册总数；分别紫 / 橙 / 绿 / 红 / 红
///    渐变 + 14/500 标题 + 32/Barlow/500 大数字。
/// 3. **筛选行**：[PopupSelectorField]「全部班级」+ 324×44 搜索框
///    （占位 "搜索姓名、工号、任课方向"），不带状态 tab。
/// 4. **结果条**：「当前结果 X 人」12 #0B081A。
/// 5. **教师卡 3 列网格**（315×78 白卡，12 gap）：左 40 头像 + 右上工号 +
///    名字 + 一句话部门·学科 + 灰色「任课·班主任·班级」/「任课」。
///    左下「班主任」黄色徽章 (#DBEE49)；右上 cut-corner 状态徽章
///    （在岗 #DFFCF0 + #0CAC40，请假/产假 #F3F2F3 + #B6B5BB），
///    徽章内有一个圆点 + 状态文字。
///
/// 卡片整体可点 → 「教师档案」`GradientHeaderDialog`：
/// 顶部 #D2C6FF→白渐变 + 头像 / 姓名 / 部门 / 工号；行政班、任课方向、
/// 教研角色、手机、入职日期、状态、备注；底部「导出档案 / 取消」
/// `AppDialogActionBar`。
///
/// 数据接入：进入页面立即并发拉
///   - `POST /app/school/v2/manager/classList`  → 「全部班级」dropdown
///   - `POST /app/school/v2/manager/teacherList` → 教师卡列表
/// 班级 / 关键字变化时只重新拉 `teacherList`；不再注入任何模拟教师 / 班级
/// 兜底数据：接口失败或返回空数组直接走「暂无符合条件的教师」空态。
class AdminTeacherManagementView extends ConsumerStatefulWidget {
  const AdminTeacherManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminTeacherManagementView> createState() =>
      _AdminTeacherManagementViewState();
}

class _AdminTeacherManagementViewState
    extends ConsumerState<AdminTeacherManagementView> {
  String _classFilter = _kAllClasses;
  String _searchKw = '';

  List<String> _classOptions = _kBaseClassOptions;

  /// 服务端拉到的教师列表；初始 `null` 表示「还没拉到结果」，与「拉到了
  /// 但是空数组」做区分（前者不渲染统计/卡片，后者落到「暂无教师」空态）。
  List<_Teacher>? _serverTeachers;

  bool _loadingTeachers = true;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
      _loadTeachers();
    });
  }

  Future<void> _loadClasses() async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList();
    if (!mounted) return;

    if (!resp.isSuccess || resp.data == null) return;

    final raw = resp.data;
    final list = raw is List
        ? raw
        : (raw is Map && raw['records'] is List
              ? raw['records'] as List
              : const []);

    final names = <String>[_kAllClasses];
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
      names.add(label);
    }

    if (names.length <= 1) return;
    setState(() {
      _classOptions = names;
      if (!_classOptions.contains(_classFilter)) {
        _classFilter = _kAllClasses;
      }
    });
  }

  Future<void> _loadTeachers() async {
    final token = ++_searchToken;
    setState(() => _loadingTeachers = true);

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.teacherList(
      keyword: _searchKw.trim().isEmpty ? null : _searchKw.trim(),
    );
    if (!mounted || token != _searchToken) return;

    if (!resp.isSuccess || resp.data == null) {
      setState(() {
        _serverTeachers = null;
        _loadingTeachers = false;
      });
      return;
    }

    final raw = resp.data;
    final list = raw is List
        ? raw
        : (raw is Map && raw['records'] is List
              ? raw['records'] as List
              : const []);
    final parsed = <_Teacher>[];
    for (final item in list) {
      if (item is Map) {
        try {
          parsed.add(_Teacher.fromJson(item.cast<String, dynamic>()));
        } catch (_) {}
      }
    }

    setState(() {
      _serverTeachers = parsed;
      _loadingTeachers = false;
    });
  }

  /// 当前生效的教师列表。`null` → 还没回包；空数组 → 接口返回 0 条。
  List<_Teacher> get _teachers => _serverTeachers ?? const <_Teacher>[];

  /// 班级过滤本地兜底（teacherList 接口暂不支持 classId 直接筛选，
  /// 通过 `roleInfo` / `headTeacherClass` 字面匹配实现前端过滤）。
  List<_Teacher> get _filtered {
    return _teachers.where((t) {
      if (_classFilter != _kAllClasses &&
          !t.roleInfo.contains(_classFilter) &&
          t.headTeacherClass != _classFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  void _openProfile(_Teacher t) {
    showScaledDialog<void>(
      context: context,
      builder: (ctx) => _TeacherProfileDialog(teacher: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = _filtered;
    final all = _teachers;

    final onDuty = all.where((t) => t.status == _TeacherStatus.onDuty).length;
    final onLeave = all.where((t) => t.status == _TeacherStatus.leave).length;
    final onMaternity = all
        .where((t) => t.status == _TeacherStatus.maternity)
        .length;
    final headTeachers = all.where((t) => t.isHeadTeacher).length;
    final total = all.length;

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
              onDuty: onDuty,
              onLeave: onLeave,
              onMaternity: onMaternity,
              headTeachers: headTeachers,
              total: total,
            ),
            SizedBox(height: ui(16)),
            _FilterRow(
              classFilter: _classFilter,
              classOptions: _classOptions,
              onClassChanged: (c) {
                setState(() => _classFilter = c);
                _loadTeachers();
              },
              onSearchChanged: (kw) {
                setState(() => _searchKw = kw);
                _loadTeachers();
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
                if (_loadingTeachers) ...[
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
            _TeacherGrid(teachers: list, onTap: _openProfile),
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
                  '教师管理',
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
                  '人事档案、部门归属、任课与角色；与教师端登录权限、班主任带班关系对齐',
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
// 5 列统计
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.onDuty,
    required this.onLeave,
    required this.onMaternity,
    required this.headTeachers,
    required this.total,
  });

  final int onDuty;
  final int onLeave;
  final int onMaternity;
  final int headTeachers;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cards = <_StatGradientCard>[
      _StatGradientCard(
        label: '在岗',
        value: onDuty,
        gradientStart: const Color(0xFFE7DCFF),
        icon: Icons.badge_outlined,
        iconColor: const Color(0xFFA985FF),
      ),
      _StatGradientCard(
        label: '请假',
        value: onLeave,
        gradientStart: const Color(0xFFFFF0DC),
        icon: Icons.event_busy_outlined,
        iconColor: const Color(0xFFFFB85C),
      ),
      _StatGradientCard(
        label: '产假',
        value: onMaternity,
        gradientStart: const Color(0xFFDCFFE7),
        icon: Icons.family_restroom_outlined,
        iconColor: const Color(0xFF52C49A),
      ),
      _StatGradientCard(
        label: '班主任',
        value: headTeachers,
        gradientStart: const Color(0xFFFFE2DC),
        icon: Icons.workspace_premium_outlined,
        iconColor: const Color(0xFFFF8A75),
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
// 筛选行：班级 dropdown + 搜索（无状态 tab）
// ============================================================================

class _FilterRow extends StatefulWidget {
  const _FilterRow({
    required this.classFilter,
    required this.classOptions,
    required this.onClassChanged,
    required this.onSearchChanged,
  });

  final String classFilter;
  final List<String> classOptions;
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        const Spacer(),
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
                    hintText: '搜索姓名、工号、任课方向',
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

// ============================================================================
// 教师卡 3 列网格
// ============================================================================

class _TeacherGrid extends StatelessWidget {
  const _TeacherGrid({required this.teachers, required this.onTap});

  final List<_Teacher> teachers;
  final ValueChanged<_Teacher> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (teachers.isEmpty) {
      return Container(
        height: ui(120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Text(
          '暂无符合条件的教师',
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
            for (final t in teachers)
              SizedBox(
                width: cardWidth,
                child: _TeacherCard(teacher: t, onTap: () => onTap(t)),
              ),
          ],
        );
      },
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher, required this.onTap});

  final _Teacher teacher;
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
              padding: EdgeInsets.fromLTRB(ui(12), ui(10), ui(54), ui(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: teacher.name, avatarUrl: teacher.avatarUrl),
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
                                teacher.name,
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
                            if (teacher.teacherId.isNotEmpty) ...[
                              SizedBox(width: ui(8)),
                              Text(
                                teacher.teacherId,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  height: 1.2,
                                  color: _kTextHint,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: ui(6)),
                        Text(
                          teacher.subjectInfo,
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
                          teacher.roleInfo,
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
            // 头像左下黄色「班主任」徽章
            if (teacher.isHeadTeacher)
              Positioned(
                left: ui(8),
                top: ui(38),
                child: Container(
                  height: ui(18),
                  padding: EdgeInsets.symmetric(horizontal: ui(7)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _kHeadTeacherTagBg,
                    borderRadius: BorderRadius.circular(ui(10)),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '班主任',
                    style: TextStyle(
                      fontSize: ui(11),
                      height: 1.0,
                      color: _kTextPrimary,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
              ),
            // 右上状态徽章
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                height: ui(22),
                padding: EdgeInsets.symmetric(horizontal: ui(8)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: teacher.status.tagBg,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(ui(12)),
                    bottomLeft: Radius.circular(ui(12)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: ui(6),
                      height: ui(6),
                      decoration: BoxDecoration(
                        color: teacher.status.tagFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: ui(4)),
                    Text(
                      teacher.status.label,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.0,
                        color: teacher.status.tagFg,
                        fontFamily: 'PingFang SC',
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl = '', this.size = 40});

  final String name;

  /// 后端 `headUrl` 经 [MediaUrl.resolve] 解析的完整地址。空串走首字母兜底。
  final String avatarUrl;

  /// 默认 40 配卡片缩略图；档案弹窗里用 56 / 64 等也可复用。
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isEmpty ? '·' : name.characters.first;
    final placeholder = Container(
      width: ui(size),
      height: ui(size),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDAD2FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(size * 0.4),
          height: 1.0,
          fontWeight: AppFont.w600,
          color: _kPurple,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
    if (avatarUrl.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: Image.network(
        avatarUrl,
        width: ui(size),
        height: ui(size),
        fit: BoxFit.cover,
        // 404 / CORS / 离线时退回首字母占位，避免出现"问号 / 黑块"。
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

// ============================================================================
// 教师档案 弹窗
// ============================================================================

class _TeacherProfileDialog extends StatelessWidget {
  const _TeacherProfileDialog({required this.teacher});

  final _Teacher teacher;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return GradientHeaderDialog(
      title: '教师档案',
      titleFontSize: 20,
      titleFontWeight: FontWeight.w500,
      titlePaddingTop: 28,
      width: 428,
      headerAsset: null,
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: '导出档案',
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
              _Avatar(
                name: teacher.name,
                avatarUrl: teacher.avatarUrl,
                size: 56,
              ),
              SizedBox(width: ui(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            teacher.name,
                            style: TextStyle(
                              fontSize: ui(16),
                              height: 1.2,
                              fontWeight: AppFont.w600,
                              color: Colors.black,
                              fontFamily: 'PingFang SC',
                            ),
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ui(6),
                            vertical: ui(2),
                          ),
                          decoration: BoxDecoration(
                            color: teacher.status.tagBg,
                            borderRadius: BorderRadius.circular(ui(4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: ui(5),
                                height: ui(5),
                                decoration: BoxDecoration(
                                  color: teacher.status.tagFg,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: ui(4)),
                              Text(
                                teacher.status.label,
                                style: TextStyle(
                                  fontSize: ui(11),
                                  height: 1.0,
                                  color: teacher.status.tagFg,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (teacher.nickname.isNotEmpty &&
                        teacher.nickname != teacher.name) ...[
                      SizedBox(height: ui(4)),
                      Text(
                        '昵称：${teacher.nickname}',
                        style: TextStyle(
                          fontSize: ui(12),
                          height: 1.2,
                          color: _kTextSub,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ],
                    if (teacher.teacherId.isNotEmpty) ...[
                      SizedBox(height: ui(2)),
                      Text(
                        '工号 ${teacher.teacherId}',
                        style: TextStyle(
                          fontSize: ui(12),
                          height: 1.2,
                          color: _kTextHint,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(20)),
          // 仅渲染后端 teacherList 实际下发的字段；其它字段（部门 / 联系
          // 电话 / 入职日期 / 备注）等后端补齐之后再放出来，目前不再用占位
          // 假数据糊。
          if (teacher.gender.isNotEmpty)
            _ProfileRow(label: '性别：', value: teacher.gender),
          if (teacher.teacherId.isNotEmpty)
            _ProfileRow(label: '工号：', value: teacher.teacherId),
          _ProfileRow(label: '状态：', value: teacher.status.label),
          if (teacher.department.isNotEmpty)
            _ProfileRow(label: '部门：', value: teacher.department),
          if (teacher.subjects.isNotEmpty)
            _ProfileRow(label: '任课方向：', value: teacher.subjects),
          if (teacher.headTeacherClass.isNotEmpty)
            _ProfileRow(label: '带班：', value: teacher.headTeacherClass),
          if (teacher.phone.isNotEmpty)
            _ProfileRow(label: '联系电话：', value: teacher.phone),
          if (teacher.entryDate.isNotEmpty)
            _ProfileRow(label: '入职日期：', value: teacher.entryDate),
          if (teacher.introduce.isNotEmpty)
            _ProfileRow(
              label: '个人简介：',
              value: teacher.introduce,
              multiline: true,
            ),
          if (teacher.remark.isNotEmpty)
            _ProfileRow(
              label: '备注：',
              value: teacher.remark,
              multiline: true,
            ),
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
