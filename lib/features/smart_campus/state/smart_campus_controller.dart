import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/state/shell_controller.dart';
import '../data/teacher_repository.dart';
import 'smart_campus_state.dart';

/// SmartCampus 全局状态：刻意 **不** 用 `autoDispose`。
///
/// - 进入智慧校园 → 切到「班主任」→ 进入「班级工作台 / 学生名册 / 作业批改 /
///   考评管理」等子页 → 返回 dashboard 时，期望保持「班主任」视角。
/// - 如果加上 `autoDispose`，shell 顶部 tab 切到首页再切回来 / 某次 build 期
///   间没有 watcher，controller 就会被销毁；下次重建时 state 重置为默认
///   `selectedRole = student`，配合 `applyBackendRole` 又会推到 admin
///   首次默认（或继续保留 student），用户的「班主任」选择就丢了。
/// - 这里只持有几个 enum / bool，常驻成本极低，去掉 autoDispose 即可。
final smartCampusControllerProvider =
    StateNotifierProvider<SmartCampusController, SmartCampusState>((ref) {
      final teacherRepo = ref.watch(teacherRepositoryProvider);
      final controller = SmartCampusController(teacherRepo: teacherRepo);

      // 立即拿一次 shell user，并在变化时（仅 role/identity 变化触发）
      // 重新应用后端身份。这里用 select 避免每次 ShellState.copyWith 都触发，
      // 配合 record 的相等性比较，做到 idempotent。
      ref.listen<({String role, String identity})>(
        shellControllerProvider.select(
          (s) => (role: s.user.role, identity: s.user.identity),
        ),
        (prev, next) {
          controller.applyBackendRole(role: next.role, identity: next.identity);
        },
        fireImmediately: true,
      );

      return controller;
    });

class SmartCampusController extends StateNotifier<SmartCampusState> {
  SmartCampusController({required TeacherRepository teacherRepo})
    : _teacherRepo = teacherRepo,
      super(const SmartCampusState());

  final TeacherRepository _teacherRepo;

  /// 是否已经成功调用过 `/app/school/v2/teacher/teacherRole`。一次成功后
  /// 缓存命中即直接复用 [SmartCampusState.availableRoles]，避免每次进入
  /// 智慧校园都打一次接口。
  ///
  /// 由 [applyBackendRole] 在 shell 端 role 变化时（换号 / 登出登入）自动
  /// 重置；同时配合 [_teacherRolesLoading] 做并发去重。
  bool _teacherRolesLoaded = false;
  bool _teacherRolesLoading = false;

  /// 最近一次 [applyBackendRole] 命中的 shell role，作为缓存失效信号：
  /// 切号会导致 myInfo.role 变化，对应的「老师多重身份」缓存需要重新拉取。
  String _lastBackendRole = '';

  /// 管理员/校长可在所有身份间切换；其他角色只允许查看自己的视图。
  static const List<SmartCampusRole> _allRoles = [
    SmartCampusRole.student,
    SmartCampusRole.teacher,
    SmartCampusRole.headTeacher,
    SmartCampusRole.dormManager,
    SmartCampusRole.admin,
  ];

  /// 后端 `AppSchoolTeacher.roles` 字段（CSV）单 token 到本地
  /// [SmartCampusRole] 的映射。未识别 token 返回 `null` 直接丢弃，
  /// 避免后端新增枚举时把 UI 拖垮。
  ///
  /// 与 [mapBackendRoleToCampus] 区别：那个走 `myInfo.role` 路径
  /// （包含「principal / dormManager」等历史别名），这个只覆盖
  /// `teacherRole` 接口实际下发的 5 个枚举。
  static SmartCampusRole? _teacherRoleTokenToCampus(String token) {
    switch (token.trim().toLowerCase()) {
      case 'headmaster':
      case 'manager':
      case 'principal':
      case 'admin':
        return SmartCampusRole.admin;
      case 'head_teacher':
      case 'headteacher':
        return SmartCampusRole.headTeacher;
      case 'course_teacher':
      case 'courseteacher':
      case 'teacher':
        return SmartCampusRole.teacher;
      case 'dormitory':
      case 'dorm':
        return SmartCampusRole.dormManager;
      case 'student':
        return SmartCampusRole.student;
    }
    return null;
  }

  /// 展示优先级：admin > headTeacher > teacher > dormManager > student。
  /// 用作多身份默认落地视图（兼具最高权限 + 最常用的工作台）。
  static const List<SmartCampusRole> _rolePriority = [
    SmartCampusRole.admin,
    SmartCampusRole.headTeacher,
    SmartCampusRole.teacher,
    SmartCampusRole.dormManager,
    SmartCampusRole.student,
  ];

  /// 根据后端返回的 `role` / `identity` 重新计算当前可用身份与默认身份。
  ///
  /// - 管理员：
  ///   - `availableRoles` 锁定为 5 个身份；
  ///   - 用户**没**主动切过身份时，默认视图就是「管理员」（mapped），不再
  ///     用 `SmartCampusState` 的初始值 `student` 兜底；
  ///   - 用户已经主动切过身份（[hasUserSelectedRole] = true）时，保留当前选择，
  ///     避免 shell 触发 `applyBackendRole` 把已经切到的「班主任 / 任课老师」
  ///     等覆盖回 admin 默认。
  /// - 其他：`availableRoles` 锁定为唯一身份，强制 `selectedRole` 与之一致
  ///   （这种情况下 `hasUserSelectedRole` 仍保持 false，下一次后端推送依旧
  ///   会按 mapped 锁定）。
  void applyBackendRole({required String role, required String identity}) {
    // shell role 变化（换号 / 登出登入）→ 失效本地「老师多重身份」缓存，
    // 下次 ensureTeacherRolesLoaded 会重新调接口。
    if (_lastBackendRole != role) {
      _teacherRolesLoaded = false;
      _teacherRolesLoading = false;
      _lastBackendRole = role;
    }

    // 已经从 teacherRole 接口拿到了权威的多重身份集合时，不再让 myInfo
    // 的 30s 轮询通过 identity 字段的微小抖动把 availableRoles 打回单
    // 一 [teacher]——「roles 中有几个身份就显示几个入口」是源自 teacherRole
    // 的契约，myInfo 不应该覆盖它。
    if (_teacherRolesLoaded) {
      return;
    }

    final mapped = mapBackendRoleToCampus(role, identity);
    final isAdmin = mapped == SmartCampusRole.admin;
    final available = isAdmin ? _allRoles : <SmartCampusRole>[mapped];

    final SmartCampusRole nextSelected;
    if (isAdmin) {
      if (state.hasUserSelectedRole && available.contains(state.selectedRole)) {
        // 用户已主动选过身份，保留它。
        nextSelected = state.selectedRole;
      } else {
        // 首次进入或还没主动选过：默认 admin 视图。
        nextSelected = mapped;
      }
    } else {
      // 非管理员：必须强制锁定到唯一身份。
      nextSelected = mapped;
    }

    if (state.selectedRole == nextSelected &&
        _sameRoleList(state.availableRoles, available)) {
      return;
    }

    state = state.copyWith(
      selectedRole: nextSelected,
      availableRoles: available,
    );
  }

  /// 当 `myInfo.role == 'teacher'` 时，拉取
  /// `/app/school/v2/teacher/teacherRole` 解析该老师在校内的实际身份
  /// 集合（校长 / 教务管理员 / 宿管 / 班主任 / 任课老师），扩展
  /// [SmartCampusState.availableRoles]，让 dashboard 上的「身份切换」
  /// tab 能展示真正可用的端，并把默认视图升级到最高优先级身份。
  ///
  /// - 幂等：同一登录态内重复调用只发一次请求；并发调用会被
  ///   [_teacherRolesLoading] 直接丢弃后到的那次。
  /// - 失败容错：网络异常或 `code != 0` 时不更新本地状态、不标记
  ///   loaded，下一次进入智慧校园会自动重试。
  /// - 角色去重 + 排序：用 [_rolePriority] 顺序输出，保证默认 selected
  ///   始终是「权限最高、最常用」的那个（admin > headTeacher >
  ///   teacher > dormManager）。
  Future<void> ensureTeacherRolesLoaded() async {
    if (_teacherRolesLoaded || _teacherRolesLoading) {
      return;
    }
    _teacherRolesLoading = true;
    try {
      final response = await _teacherRepo.teacherRole();
      if (response.code != 0) {
        return;
      }
      final roles = _parseTeacherRoles(response.data);
      _teacherRolesLoaded = true;
      if (roles.isEmpty) {
        // 接口正常但返回空数组 = 该老师暂未配置任何 school 身份；保留
        // applyBackendRole 给出的默认（[teacher]）不动。
        return;
      }
      _applyTeacherRoles(roles);
    } catch (_) {
      // 网络异常等，保持未 loaded 状态，下次进入页面会重试。
    } finally {
      _teacherRolesLoading = false;
    }
  }

  /// 把后端 `AppSchoolTeacher` 列表中的 `roles` CSV 字段聚合 + 解析 +
  /// 排序成 [SmartCampusRole] 列表。容忍：data 不是 List、item 不是
  /// Map、roles 为空 / 非字符串、单条记录里有重复 token、跨校多条记录。
  List<SmartCampusRole> _parseTeacherRoles(dynamic data) {
    if (data is! List) {
      return const [];
    }
    final tokens = <String>{};
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final raw = item['roles'];
      if (raw is! String || raw.isEmpty) {
        continue;
      }
      for (final token in raw.split(',')) {
        final trimmed = token.trim();
        if (trimmed.isNotEmpty) {
          tokens.add(trimmed);
        }
      }
    }
    final mapped = <SmartCampusRole>{};
    for (final token in tokens) {
      final role = _teacherRoleTokenToCampus(token);
      if (role != null) {
        mapped.add(role);
      }
    }
    return [
      for (final role in _rolePriority)
        if (mapped.contains(role)) role,
    ];
  }

  /// 用 `teacherRole` 解析结果覆盖 [SmartCampusState.availableRoles]，
  /// 并按以下规则选择 `selectedRole`：
  /// - 用户已经主动在 dashboard tab 上切换过且当前选择仍在可用集合里
  ///   → 保留用户选择；
  /// - 否则取列表首个（即 [_rolePriority] 中最高优先级的那一个）。
  void _applyTeacherRoles(List<SmartCampusRole> roles) {
    final SmartCampusRole nextSelected;
    if (state.hasUserSelectedRole && roles.contains(state.selectedRole)) {
      nextSelected = state.selectedRole;
    } else {
      nextSelected = roles.first;
    }
    if (state.selectedRole == nextSelected &&
        _sameRoleList(state.availableRoles, roles)) {
      return;
    }
    state = state.copyWith(
      selectedRole: nextSelected,
      availableRoles: roles,
    );
  }

  /// 用户主动切换身份（`_RoleChip` / dashboard 内任课老师↔班主任 tab）。
  ///
  /// 关键点：合法切换会把 [SmartCampusState.hasUserSelectedRole] 标为 true，
  /// 之后 `applyBackendRole` 不会再覆盖 `selectedRole`，从而保证 admin 切到
  /// 「班主任」后进入子页再返回仍保持班主任视角。
  void selectRole(SmartCampusRole role) {
    if (!state.availableRoles.contains(role)) {
      // 未授权切换：直接忽略，避免普通用户被串改身份。
      return;
    }
    if (state.selectedRole == role && state.hasUserSelectedRole) {
      return;
    }
    state = state.copyWith(selectedRole: role, hasUserSelectedRole: true);
  }

  void openPrincipalMailbox({
    PrincipalMailboxInitialMode initialMode = PrincipalMailboxInitialMode.compose,
  }) {
    if (state.mainView == SmartCampusMainView.principalMailbox &&
        state.principalMailboxInitialMode == initialMode) {
      return;
    }
    state = state.copyWith(
      mainView: SmartCampusMainView.principalMailbox,
      principalMailboxInitialMode: initialMode,
    );
  }

  /// `PrincipalMailboxView.initState` 在拿到一次 [principalMailboxInitialMode]
  /// 后调用，立即把状态重置为默认 [PrincipalMailboxInitialMode.compose]，避免
  /// 下次从侧栏进入时仍然落在「需求反馈」分段。
  void consumePrincipalMailboxInitialMode() {
    if (state.principalMailboxInitialMode ==
        PrincipalMailboxInitialMode.compose) {
      return;
    }
    state = state.copyWith(
      principalMailboxInitialMode: PrincipalMailboxInitialMode.compose,
    );
  }

  void openMyClass() {
    if (state.mainView == SmartCampusMainView.myClass) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.myClass);
  }

  /// 班主任端「班级工作台」独立入口：不再复用学生「我的班级」的 mainView，
  /// 进入后强制走 [TeacherClassWorkbenchView]，与 selectedRole 解耦，避免
  /// admin / 测试账号切换到班主任视角后误落入学生 _MyClassView。
  void openClassWorkbench() {
    if (state.mainView == SmartCampusMainView.classWorkbench) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.classWorkbench);
  }

  void openMySchedule() {
    if (state.mainView == SmartCampusMainView.mySchedule) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.mySchedule);
  }

  /// 学生端「课堂签到」独立入口：打开课堂签到页（顶部 banner + 5 项统计
  /// + 今日课程 + 签到操作 + 最近课堂记录）。
  void openCheckIn() {
    if (state.mainView == SmartCampusMainView.checkIn) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.checkIn);
  }

  /// 学生端「我的作业」独立入口：打开作业总览页（顶部 banner + 3 项统计 +
  /// 均分柱形图 + 分数段分布 + 状态分类 tabs + 作业卡 2 列网格）。
  void openMyHomework() {
    if (state.mainView == SmartCampusMainView.myHomework) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.myHomework);
  }

  /// 学生端「我的成绩」独立入口：打开成绩与排名页（banner + 4 项统计 +
  /// 6 次考试折线趋势 + 场次均分分布 + 考试记录与各科成绩双列）。
  void openMyGrades() {
    if (state.mainView == SmartCampusMainView.myGrades) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.myGrades);
  }

  /// 「群聊」入口（学生 / 教师 / 班主任 共用）：进入两栏会话页面：
  ///   - 左 280 会话列表（搜索 + 6 条会话）
  ///   - 右 chat 区（紫色渐变 header + 群公告 + 系统提示 + 文本/图片/语音/文件
  ///     消息气泡 + 输入栏：附件 + 语音 + 表情 + 发送）
  void openGroupChat() {
    if (state.mainView == SmartCampusMainView.groupChat) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.groupChat);
  }

  /// 学生端「查寝管理」入口：进入个人查寝/补卡页面。
  ///   - 紫白渐变 header + 仅展示本人「<姓名>」的查寝记录提示
  ///   - 4 张统计卡（宿舍床位 / 正常打卡 / 异常 / 补卡待审）
  ///   - 我的查寝记录 + 全部/异常 tabs
  ///   - 三列卡片网格：晚查寝/晨查寝 + 状态徽章 + 规定/打卡时间 + 备注
  ///   - 右上角「申请补卡」按钮 → GradientHeaderDialog 表单（日期 + 场次 + 备注）
  void openDormCheck() {
    if (state.mainView == SmartCampusMainView.dormCheck) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.dormCheck);
  }

  /// 任课老师 / 班主任端「签课管理」独立入口：进入授课签到总览页（顶部
  /// banner + 5 项统计 + 总数据/本学期/本月 tabs + 最近签课记录 +
  /// 今日课程 + 双列签到操作面板：大课走班级学生网格 + 一键全班签到，
  /// 小课走单学生 + 教师上下课时间轴）。
  void openClassAttendance() {
    if (state.mainView == SmartCampusMainView.classAttendance) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.classAttendance);
  }

  /// 任课老师 / 班主任端「作业批改」独立入口：进入作业与批改总览页（4 状态
  /// tabs + 班级筛选 + 累计/本学期/本月 + 6 项统计 + 左作业列表 + 右作业详情
  /// 与学生提交表）。
  void openHomeworkReview() {
    if (state.mainView == SmartCampusMainView.homeworkReview) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.homeworkReview);
  }

  /// 任课老师 / 班主任端「考评管理」独立入口：进入"考评管理"总览页（5 状态
  /// tabs + 班级筛选 + 累计/本学期/本月 + 6 项统计 + 左考试列表 + 右考试详情
  /// 与学生提交表，且仅可查看与评分，不可新建考试）。
  void openExamReview() {
    if (state.mainView == SmartCampusMainView.examReview) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.examReview);
  }

  /// 任课老师 / 班主任端「学生名册」独立入口：进入学生名册总览页（banner +
  /// 班级筛选 + 搜索框 + 3 张统计卡（当前列表 / 男 / 女）+ 学生卡 3 列网格）。
  void openStudentRoster() {
    if (state.mainView == SmartCampusMainView.studentRoster) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.studentRoster);
  }

  /// 学生端「请假管理」入口：进入"请假补课"页面。
  ///   - 顶部紫白渐变 header + 标题 "请假补课" + 副标题流程说明
  ///   - 三色统计卡（待审批/已通过/已拒绝）
  ///   - 5 标签筛选（全部/审批中/已通过/已拒绝/已撤销）+ 紫色"发起申请"按钮
  ///   - 双列卡片网格：每条申请展示类型/时长/状态徽章/请假详情/审批 stepper/
  ///     备注；审批中的可"撤销申请"。
  void openLeaveManagement() {
    if (state.mainView == SmartCampusMainView.leaveManagement) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.leaveManagement);
  }

  /// 班主任端「查寝动态」入口：掌握本班住宿生归宿与晨检结果，协同处理
  /// 补卡与异常跟进。
  ///   - 顶部紫白渐变 banner + 副标题（现场刷脸由查寝老师/宿管在专用端
  ///     执行，本页不提供打卡入口）
  ///   - 4 张统计卡（住宿生 / 今晚已归寝口径 / 异常 / 补卡待审）
  ///   - 顶部 tabs 「本班查纪 / 补卡审核」+ 搜索框
  ///   - 「全部异常记录 N 条」+ 全部 / 异常 toggle
  ///   - 卡片网格 3 列：学生口径卡（头像 + 学号 + 状态徽章 + 宿舍 + 灰底
  ///     规定/打卡时间双列 + 备注）+ 宿舍口径卡（晨查寝/晚查寝 18 Barlow
  ///     标题 + 大色块状态徽章 正常/未打卡/迟到 + 灰底时间双列 + 备注）。
  void openDormDynamic() {
    if (state.mainView == SmartCampusMainView.dormDynamic) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.dormDynamic);
  }

  /// 班主任端「查寝历史」入口：按自然日查看本班住宿生晚查寝、晨查寝
  /// 打卡汇总。
  ///   - 顶部紫白渐变 banner + 副标题（数据与「查寝动态」演示同源）
  ///   - 14 天水平日期条（星期 + 日期数字 / 选中态紫底白字）+ 当日统计提示
  ///   - 4 张统计卡（晚查寝·已归寝口径 / 晚查寝·待关注 /
  ///     晨查寝·已到位口径 / 晨查寝·待关注）
  ///   - 晚查寝 / 晨查寝 二选一 tabs
  ///   - 卡片网格：宿舍口径 (晨/晚查寝标题) + 学生口径 (姓名/学号)。
  void openDormHistory() {
    if (state.mainView == SmartCampusMainView.dormHistory) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.dormHistory);
  }

  /// 班主任端「家校沟通」入口：与本班学生家长就请假、成绩、心理等进行
  /// 文字沟通；可查看短信送达演示状态。
  ///   - banner + 3 张统计卡（未读消息 / 待回复 / 会话总数）
  ///   - 全部 / 未读 / 待回复 tabs + 搜索框
  ///   - 家长对话卡 3 列网格（头像 / 学生姓名+学号 / 标签 / 家长发言预览
  ///     / 时间戳 / 未送达提示），点击卡片打开对话详情弹窗。
  void openHomeSchoolCommunication() {
    if (state.mainView == SmartCampusMainView.homeSchool) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.homeSchool);
  }

  /// 班主任端「请假审批」入口：进入审批本班学生请假申请的页面。
  ///   - 紫白渐变 banner + 标题 "请假审批" + 副标题流程说明
  ///   - 4 张统计卡（待审批 / 审批中 / 已通过 / 已拒绝）+ 提示与备案说明
  ///   - 6 状态 tabs（全部 / 待我审批 / 审批中 / 已通过 / 已拒绝 / 已撤销）
  ///     + 搜索框（姓名 / 学号 / 手机 / 宿舍 / 家长）
  ///   - 双列卡片网格：每条申请展示头像/学号/类型/时长/状态徽章 + 灰底信息
  ///     块（请假时间/事由/申请时间/路径/家长→班主任 stepper/备注）；
  ///     审批中卡片底部有"通过 / 驳回"按钮，"驳回"打开 GradientHeaderDialog
  ///     形式的"驳回申请"弹窗。
  void openLeaveApproval() {
    if (state.mainView == SmartCampusMainView.leaveApproval) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.leaveApproval);
  }

  /// 管理员端「学生管理」入口：进入全量在籍学生总览页（banner + 标题/副标题
  /// + 4 张彩色渐变统计卡（在籍 / 住校 / 异动 / 名册总数）+ 学籍状态 5 tabs
  /// (全部 / 在籍 / 休学 / 转学 / 毕业) + 全部班级 dropdown + 搜索框
  /// + 当前结果 N 人 + 学生卡 3 列网格；点击卡片打开「学籍档案」弹窗）。
  void openStudentManagement() {
    if (state.mainView == SmartCampusMainView.studentManagement) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.studentManagement);
  }

  /// 管理员端「教师管理」入口：进入全量在岗教师总览页（banner + 标题/副标题
  /// + 5 张彩色渐变统计卡（在岗 / 请假 / 产假 / 班主任 / 名册总数）+
  /// 全部班级 dropdown + 搜索框（姓名/工号/任课方向）+ 当前结果 N 人 +
  /// 教师卡 3 列网格；卡片左下黄色「班主任」徽章 + 右上彩点状态徽章；
  /// 点击卡片打开「教师档案」弹窗）。
  void openTeacherManagement() {
    if (state.mainView == SmartCampusMainView.teacherManagement) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.teacherManagement);
  }

  /// 管理员端「班级编组」入口：进入行政班一览页面（banner + 标题/副标题 +
  /// 顶部「创建班级 / 人员调班」两枚按钮 + 4 张统计卡（行政班数 / 在籍人数 /
  /// 可调班在籍 / 调班记录）+ 行政班一览（白色卡片 + F5F6FA 渐变 header +
  /// 大课/小课 pill + 班级元信息 + 共 N 人 + 折叠按钮；展开后 3 列学生
  /// 迷你卡 + 「在籍」紫色 cut-corner 徽章）；可打开「创建行政班」/
  /// 「人员调班」两个右侧抽屉。
  void openClassManagement() {
    if (state.mainView == SmartCampusMainView.classManagement) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.classManagement);
  }

  /// 管理员端「排课与课表」入口：进入双 tab 视图。
  ///   - tab 1「周课表与排课」：banner + 控制条（教学周第 N 周 + legend +
  ///     ◀本周▶ + 演示基本周 + YYYY/MM/DD 日历 pill）+ 7 天 × 5 时段课表
  ///     网格（4 主题课卡 + 编辑模式空格 / 第 1 行追加 "申请小课" pill），
  ///     左下 "全校统一课表" 班级 dropdown，右下 "查看 / 编辑" 分段。
  ///   - tab 2「小课申请审核」：双列卡片网格，每卡含申请人 + 状态徽章
  ///     （待审核 / 已通过 / 已驳回）+ 日期 / 节次 双列灰底块 + 备注 +
  ///     底部 "通过 / 驳回" 按钮（仅待审核态显示，"驳回"打开
  ///     GradientHeaderDialog 填理由）。
  void openScheduleManagement() {
    if (state.mainView == SmartCampusMainView.scheduleManagement) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.scheduleManagement);
  }

  /// 管理员端「宿管请假审批」入口：宿管人员在宿管端提交请假申请后，由管理员
  /// 在后勤审批台审批。与学生 / 班主任的"请假与补课 / 请假审批"互不混用。
  ///   - banner（白→#F9EDFF 渐变）+ 标题 "宿管请假审批" + 副标题
  ///   - 3 张统计卡（待审批 紫渐变 / 已通过 绿渐变 / 已拒绝 红渐变）
  ///   - 12/#B6B5BB 提示文案 + 4 状态 tabs (全部 / 待审批 / 已通过 / 已拒绝)
  ///   - 右侧 "审批中 N 条" + 紫渐变 "发起申请" 按钮
  ///   - 双列卡片网格（宿管头像 / 工号 / 假别 / 时长 + 状态徽章 + 灰底
  ///     信息块: 请假时间 / 事由 / 管理区域 / 申请时间 / 工作交接；待审批
  ///     卡片底部 "通过 / 驳回" 按钮，"驳回" 打开 GradientHeaderDialog 填理由）。
  void openDormLeaveApproval() {
    if (state.mainView == SmartCampusMainView.dormLeaveApproval) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.dormLeaveApproval);
  }

  /// 管理员端「人脸库」入口：进入人脸录入与底库管理双 tab 视图。
  ///   - banner（白→#F9EDFF 渐变）+ 标题 "人脸库" + 副标题
  ///     + 右上角 "人脸录入 / 底库记录" 分段
  ///   - 4 张统计卡（已生效 紫渐变 / 待审核 橙渐变 / 已驳回 绿渐变 /
  ///     记录总数 红渐变）
  ///   - "录入人脸" 区块：3 步骤进度条（选择在籍学生 / 上传或截取正脸 /
  ///     勾选规范确认提交）+ 行政班/学生 dropdown + 上传人脸（虚线圆形
  ///     占位 + "上传照片"/"打开摄像头" 按钮）+ 采集规范（3 张示例 +
  ///     文字规范）+ 勾选 + 紫渐变 "提交人脸录入" 按钮。
  void openFaceLibrary() {
    if (state.mainView == SmartCampusMainView.faceLibrary) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.faceLibrary);
  }

  /// 进入「通知管理」管理端独立视图（admin 首页快捷区第 7 个按钮）。
  ///
  /// 视图：
  ///   - banner（白→#F9EDFF 渐变）+ 标题 "通知管理" + 副标题
  ///     + 右上角 "新建通知" 按钮。
  ///   - 5 张统计卡（已发布 / 定时中 / 草稿 / 已撤回 / 全部）。
  ///   - 全部类型 / 全部状态 双下拉 + 搜索框。
  ///   - 970 宽白底 16 圆角表格：标题 / 类型 / 优先级（普通/重要/紧急）/
  ///     范围 / 状态（草稿/已通过/定时中/已撤回）/ 时间 / 操作。
  ///   - 点击「新建通知」/ 行内「编辑」均打开右侧 600 抽屉表单：
  ///     标题、内容、类型、优先级、推送范围（多选）、发布方式
  ///     （立即发布 / 定时发布 / 保存为草稿）。
  void openNotificationManagement() {
    if (state.mainView == SmartCampusMainView.notificationManagement) {
      return;
    }
    state = state.copyWith(
      mainView: SmartCampusMainView.notificationManagement,
    );
  }

  /// 宿管端「按宿舍查寝」入口：进入今晚 / 今晨的按宿舍打卡作业页面。
  ///   - banner（白→#F9EDFF 渐变）+ 标题 "按宿舍查寝" + 副标题
  ///   - 当前查寝截止时间（如 "2026-04-22 23:00前"）顶置
  ///   - 4 张统计卡（在册床位 / 正常口径 / 晚归 / 未打卡）
  ///   - 多张宿舍卡：宿舍号 + 公寓·楼层 + N人·查寝场次·截止时间 +
  ///     "一键打卡" 紫渐变按钮（全部已打则置灰）+ 3 列学生格子（头像 +
  ///     姓名 + 学号 + 已打卡/未打卡 下拉）
  ///   - 底部最近查寝历史 3 列卡片（紫白渐变 + 状态徽章 + 规定/打卡时间 + 备注）
  void openDormCheckByRoom() {
    if (state.mainView == SmartCampusMainView.dormCheckByRoom) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.dormCheckByRoom);
  }

  /// 宿管端「打卡管理」入口：宿管本人的到岗 / 下班打卡（GPS + 时间戳）。
  ///   - banner（白→#F9EDFF 渐变）+ 标题 "打卡管理" + 副标题
  ///   - 主面板（970×439 白卡）：左上小绿图标 + 「在责任区内 距考勤处约 850m」
  ///     #12CE51 状态 + 「获取当前定位」白底胶囊按钮 + 中央 160×160 紫渐变
  ///     圆形大按钮（"上班/下班打卡" + 实时时间 21:32:22）+ 背景柔和雷达圆
  ///   - "我的打卡记录" 18/500 + 477 宽双列卡片（紫白渐变 + 16/500 标题 +
  ///     绿色 "正常" 徽章 + 灰底块 "打卡时间 / 打卡位置"）
  void openDormCheckInManagement() {
    if (state.mainView == SmartCampusMainView.dormCheckInManagement) {
      return;
    }
    state = state.copyWith(
      mainView: SmartCampusMainView.dormCheckInManagement,
    );
  }

  /// 管理员端「签课管理」入口：查看大课 / 小课的签到状态，处理补签审核。
  ///
  /// 视图（两个 tab）：
  ///   - **大课管理**：按班级 + 日期查询课次列表；每节大课可展开查看学生签到
  ///     情况，支持管理员逐人修改状态（正常 / 迟到 / 早退 / 请假 / 缺勤）。
  ///   - **小课管理**：查看小课各阶段签到状态（老师上课签→学生上课签→老师
  ///     下课签→学生下课签→学生评价→管理员确认）；待确认的小课卡底部出现
  ///     "确认完成"按钮；如有补签申请则弹右侧抽屉审核（通过/驳回）。
  void openSignManagement() {
    if (state.mainView == SmartCampusMainView.signManagement) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.signManagement);
  }

  void backToDashboard() {
    if (state.mainView == SmartCampusMainView.dashboard) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.dashboard);
  }

  void selectMailboxMessageType(PrincipalMailboxMessageType type) {
    if (state.selectedMailboxMessageType == type) {
      return;
    }
    state = state.copyWith(selectedMailboxMessageType: type);
  }

  void toggleMailboxAnonymous() {
    state = state.copyWith(isMailboxAnonymous: !state.isMailboxAnonymous);
  }

  void setTeacherScheduleMode(TeacherScheduleMode mode) {
    if (state.teacherScheduleMode == mode) {
      return;
    }
    state = state.copyWith(teacherScheduleMode: mode);
  }

  bool _sameRoleList(List<SmartCampusRole> a, List<SmartCampusRole> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
