enum SmartCampusRole { student, teacher, headTeacher, dormManager, admin }

enum SmartCampusMainView {
  dashboard,
  principalMailbox,
  myClass,
  mySchedule,
  classWorkbench,
  checkIn,
  myHomework,
  myGrades,
  groupChat,
  leaveManagement,
  leaveApproval,
  dormCheck,
  dormDynamic,
  dormHistory,
  // 宿管端「按宿舍查寝」：banner + 日期 + 4 张统计卡 + 每个宿舍 1 张卡
  // （房号 + 一键打卡 + 学生格子）+ 底部最近查寝历史。
  dormCheckByRoom,
  // 宿管端「打卡管理」：banner + 大圆形上/下班打卡按钮 + 责任区/定位状态 +
  // 「我的打卡记录」2 列卡片网格（紫白渐变 + 状态徽章 + 打卡时间/位置）。
  dormCheckInManagement,
  homeSchool,
  classAttendance,
  studentRoster,
  homeworkReview,
  examReview,
  studentManagement,
  teacherManagement,
  classManagement,
  scheduleManagement,
  dormLeaveApproval,
  faceLibrary,
  notificationManagement,
  signManagement,
}

enum TeacherScheduleMode { view, edit }

enum PrincipalMailboxMessageType { report, suggestion, other }

/// 进入「校长信箱」时的默认分段：
/// - `compose`  写信（默认）
/// - `feedback` 需求反馈（个人中心「意见反馈」直达入口）
enum PrincipalMailboxInitialMode { compose, feedback }

extension SmartCampusRoleX on SmartCampusRole {
  String get label {
    switch (this) {
      case SmartCampusRole.student:
        return '学生端';
      case SmartCampusRole.teacher:
        return '任课老师';
      case SmartCampusRole.headTeacher:
        return '班主任';
      case SmartCampusRole.dormManager:
        return '宿管';
      case SmartCampusRole.admin:
        return '管理员';
    }
  }

  String get shortLabel {
    switch (this) {
      case SmartCampusRole.student:
        return '学生';
      case SmartCampusRole.teacher:
        return '任课';
      case SmartCampusRole.headTeacher:
        return '班主任';
      case SmartCampusRole.dormManager:
        return '宿管';
      case SmartCampusRole.admin:
        return '管理';
    }
  }
}

/// 把后端 `myInfo` 接口返回的 `role` / `identity` 字段映射到智慧校园
/// 当前支持的五种身份。`role` 为英文标识符（优先级更高），`identity`
/// 为中文身份名（用作兜底）。
///
/// 已知后端取值示例：
/// - role: `student` / `teacher` / `headTeacher` / `head_teacher` /
///   `class_teacher` / `dorm` / `dormManager` / `admin` / `principal` 等
/// - identity: 「学生 / 老师 / 班主任 / 宿管 / 管理员 / 校长」等
SmartCampusRole mapBackendRoleToCampus(String role, [String identity = '']) {
  final r = role.trim().toLowerCase();
  // 1. 通过 role 标识符精确匹配（去掉下划线/连字符方便对齐）
  final normalized = r.replaceAll(RegExp(r'[_\-]'), '');
  switch (normalized) {
    case 'student':
    case 'stu':
    case 'pupil':
      return SmartCampusRole.student;
    case 'headteacher':
    case 'classteacher':
    case 'classmaster':
    case 'banzhuren':
      return SmartCampusRole.headTeacher;
    case 'teacher':
    case 'subjectteacher':
    case 'instructor':
      return SmartCampusRole.teacher;
    case 'dormmanager':
    case 'dorm':
    case 'dormitory':
    case 'sushe':
      return SmartCampusRole.dormManager;
    case 'admin':
    case 'administrator':
    case 'manager':
    case 'principal':
    case 'headmaster':
    case 'super':
    case 'superadmin':
    case 'schooladmin':
      return SmartCampusRole.admin;
  }

  // 2. 中文 identity 兜底（注意：班主任要先于「老师」，校长/管理员要先于「教」）
  if (identity.contains('班主任')) {
    return SmartCampusRole.headTeacher;
  }
  if (identity.contains('校长') || identity.contains('管理')) {
    return SmartCampusRole.admin;
  }
  if (identity.contains('宿管') || identity.contains('宿舍')) {
    return SmartCampusRole.dormManager;
  }
  if (identity.contains('老师') || identity.contains('教师')) {
    return SmartCampusRole.teacher;
  }
  if (identity.contains('学生') || identity.contains('同学')) {
    return SmartCampusRole.student;
  }

  // 3. 兜底：未识别身份按学生处理（功能最完整、最安全的视图）
  return SmartCampusRole.student;
}

extension PrincipalMailboxMessageTypeX on PrincipalMailboxMessageType {
  String get label {
    switch (this) {
      case PrincipalMailboxMessageType.report:
        return '举报';
      case PrincipalMailboxMessageType.suggestion:
        return '建议';
      case PrincipalMailboxMessageType.other:
        return '其他';
    }
  }
}

class SmartCampusState {
  const SmartCampusState({
    this.selectedRole = SmartCampusRole.student,
    this.hasUserSelectedRole = false,
    this.mainView = SmartCampusMainView.dashboard,
    this.selectedMailboxMessageType = PrincipalMailboxMessageType.suggestion,
    this.isMailboxAnonymous = true,
    this.teacherScheduleMode = TeacherScheduleMode.view,
    this.principalMailboxInitialMode = PrincipalMailboxInitialMode.compose,
    this.availableRoles = const [
      SmartCampusRole.student,
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
      SmartCampusRole.dormManager,
      SmartCampusRole.admin,
    ],
  });

  final SmartCampusRole selectedRole;

  /// 用户是否手动通过 `selectRole` 切换过身份。
  ///
  /// - `false`：仅由后端 `applyBackendRole` 推下来的自动值。管理员重新进入
  ///   智慧校园时，每次都根据后端 `mapped` 角色（即 admin）作为默认视图。
  /// - `true`：用户已经在 dashboard 上选过身份（例如 admin 切到「班主任」）。
  ///   这之后 `applyBackendRole` 不会再覆盖 `selectedRole`，避免进入「班级
  ///   工作台 / 学生名册 / 作业批改 / 考评管理」等子页再返回时被打回默认。
  final bool hasUserSelectedRole;
  final SmartCampusMainView mainView;
  final PrincipalMailboxMessageType selectedMailboxMessageType;
  final bool isMailboxAnonymous;
  final TeacherScheduleMode teacherScheduleMode;

  /// 一次性配置：[PrincipalMailboxView] `initState` 时读取并立刻消费，
  /// 用于支持「个人中心 - 意见反馈」直接落到「需求反馈」分段。
  final PrincipalMailboxInitialMode principalMailboxInitialMode;
  final List<SmartCampusRole> availableRoles;

  SmartCampusState copyWith({
    SmartCampusRole? selectedRole,
    bool? hasUserSelectedRole,
    SmartCampusMainView? mainView,
    PrincipalMailboxMessageType? selectedMailboxMessageType,
    bool? isMailboxAnonymous,
    TeacherScheduleMode? teacherScheduleMode,
    PrincipalMailboxInitialMode? principalMailboxInitialMode,
    List<SmartCampusRole>? availableRoles,
  }) {
    return SmartCampusState(
      selectedRole: selectedRole ?? this.selectedRole,
      hasUserSelectedRole: hasUserSelectedRole ?? this.hasUserSelectedRole,
      mainView: mainView ?? this.mainView,
      selectedMailboxMessageType:
          selectedMailboxMessageType ?? this.selectedMailboxMessageType,
      isMailboxAnonymous: isMailboxAnonymous ?? this.isMailboxAnonymous,
      teacherScheduleMode: teacherScheduleMode ?? this.teacherScheduleMode,
      principalMailboxInitialMode:
          principalMailboxInitialMode ?? this.principalMailboxInitialMode,
      availableRoles: availableRoles ?? this.availableRoles,
    );
  }
}
