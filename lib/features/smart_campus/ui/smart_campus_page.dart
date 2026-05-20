import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/smart_campus_controller.dart';
import '../state/smart_campus_state.dart';
import 'admin_class_management_view.dart';
import 'admin_dorm_leave_approval_view.dart';
import 'admin_face_library_view.dart';
import 'admin_home_view.dart';
import 'admin_notification_management_view.dart';
import 'admin_schedule_management_view.dart';
import 'admin_sign_management_view.dart';
import 'admin_student_management_view.dart';
import 'admin_teacher_management_view.dart';
import 'dorm_manager_check_by_room_view.dart';
import 'dorm_manager_check_history_view.dart';
import 'dorm_manager_check_in_view.dart';
import 'dorm_manager_home_view.dart';
import 'group_chat_view.dart';
import 'principal_mailbox_view.dart';
import 'student_check_in_view.dart';
import 'student_dorm_check_view.dart';
import 'student_leave_management_view.dart';
import 'student_my_class_view.dart';
import 'student_my_grades_view.dart';
import 'student_my_homework_view.dart';
import 'student_my_schedule_view.dart';
import 'teacher_class_attendance_view.dart';
import 'teacher_class_workbench.dart';
import 'teacher_dashboard.dart';
import 'teacher_exam_review_view.dart';
import 'teacher_homework_review_view.dart';
import 'teacher_dorm_dynamic_view.dart';
import 'teacher_dorm_history_view.dart';
import 'teacher_home_school_view.dart';
import 'teacher_leave_approval_view.dart';
import 'teacher_lesson_schedule_view.dart';
import 'teacher_student_roster_view.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 智慧校园入口页：根据当前 [SmartCampusRole] + [SmartCampusMainView] 路由到
/// 对应的子视图。
///
/// - `teacher` / `headTeacher`：
///   - `mainView == classWorkbench` → [TeacherClassWorkbenchView]
///   - `mainView == principalMailbox` → [PrincipalMailboxView]（校长信箱：写信/编辑
///     分段、消息类型、匿名开关、正文、上传、提交）
///   - `mainView == mySchedule` → [TeacherLessonScheduleView]（独立"授课课表"页：
///     居中标题 + 副标题 + 查看/编辑分段；下方控制条带教学周/legend/切周/日期；
///     编辑模式空格可申请小课，第一行小课卡下追加申请按钮，大课不可编辑）
///   - 其他 mainView → [TeacherDashboardLayout]
///
/// - `student`：
///   - `mainView == principalMailbox` → [PrincipalMailboxView]（与教师端共用）
///   - `mainView == myClass` → [StudentMyClassView]（独立"我的班级"页：
///     班级信息卡 + 班级公告 + 师资三段 + 同班同学 7 列网格）
///   - `mainView == mySchedule` → [StudentMyScheduleView]（独立"我的课表"页：
///     教学周 banner + 时间冻结列 + 横滚 7 天序 + 4 种课卡）
///   - `mainView == checkIn` → [StudentCheckInView]（独立"课堂签到"页：
///     banner + 5 项统计 + 今日课程 + 签到操作 + 最近课堂记录 6 卡）
///   - `mainView == myHomework` → [StudentMyHomeworkView]（独立"我的作业"页：
///     banner + 学期均分/班级名次/年级名次 3 卡 + 均分柱形/分数段分布
///     + 状态 tabs + 作业卡 6 张网格）
///   - `mainView == myGrades` → [StudentMyGradesView]（独立"我的成绩"页：
///     成绩与排名 banner + 学期 tabs + 4 项统计卡 + 6 次考试折线趋势
///     + 场次均分分布 + 考试记录与各科成绩双列 6 卡）
///   - 其他 mainView → [StudentDashboardLayout]（学生端首页：6 stats +
///     10 功能矩阵 + 当前课程/今日课表 + 个人侧栏 + 通知）
///
///   - `mainView == leaveManagement` → [StudentLeaveManagementView]（独立"请假补课"页：
///     紫白渐变 header + 三色统计卡 + 5 状态 tabs + 紫色"发起申请"+
///     双列卡片（请假详情 + 家长 → 班主任 stepper + 撤销）)
///   - `mainView == dormCheck` → [StudentDormCheckView]（独立"查寝管理"页：
///     紫白渐变 header + 4 张统计卡（宿舍/正常/异常/补卡待审）+ 全部/异常
///     tabs + 三列卡片网格 + 「申请补卡」GradientHeaderDialog 表单弹窗）
///
/// - 五端共用：
///   - `mainView == groupChat` → [GroupChatView]（双栏会话页：左 280
///     会话列表 + 右紫色渐变 header + 群公告 + 系统提示 + 文本/图片/
///     语音/文件 消息气泡 + 输入栏。消息模型对齐 1.0 chat.vue：
///     type 0=系统、1=文本、2=图片、3=富内容(视频/课件/资讯/课程/语音)。）
///   - 「校圈」label → 直接走 [Navigator.pushNamed] 到 [RoutePaths.circle]，
///     与首页"校圈"快捷入口共用同一全屏 [CirclePage]。
///
/// - `dormManager` / `admin`（含其他 mainView）：
///   仍走 [_SmartCampusPlaceholder] 骨架占位页，待后续按 Figma 重建。
///
/// 入口参数（shellDisplayName、avatarUrl）来自 [shellControllerProvider]，
/// 进入「校长信箱 / 我的班级 / 我的课表 / 班级工作台」全部走
/// [SmartCampusController] 的 open* 方法，从 dashboard 返回时调
/// `controller.backToDashboard()`。
class SmartCampusPage extends ConsumerWidget {
  const SmartCampusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smartCampusControllerProvider);
    final controller = ref.read(smartCampusControllerProvider.notifier);
    final shellState = ref.watch(shellControllerProvider);

    // 「老师」身份用户进入智慧校园后，按需调用 /app/school/v2/teacher/teacherRole
    // 取回其在校内的实际身份集合（校长 / 教务管理员 / 宿管 / 班主任 /
    // 任课老师），由 controller 内部去重 + 排序后扩展 availableRoles，
    // dashboard 上的身份切换 tab 才会出现真正可用的多端入口。
    //
    // 这里直接在 build 中触发：shellControllerProvider 上方已经 watch，
    // myInfo 回包导致 role 变化时本 widget 会自然重 build；
    // [SmartCampusController.ensureTeacherRolesLoaded] 自身用 loaded /
    // loading 双标记做去重，重复 build 也只会发一次请求。
    if (shellState.user.role.trim().toLowerCase() == 'teacher') {
      controller.ensureTeacherRolesLoaded();
    }

    final isTeacherOrHead =
        state.selectedRole == SmartCampusRole.teacher ||
        state.selectedRole == SmartCampusRole.headTeacher;

    // "校圈"快捷入口跨身份共享：跳转到首页同名 CirclePage，避免在智慧校园
    // 内部又重复实现一份社区列表。Navigator.pushNamed 是以本 widget 的
    // BuildContext 作 anchor，rootNavigator 默认即可。
    void openSchoolCircle() {
      Navigator.of(context).pushNamed(RoutePaths.circle);
    }

    // 管理员智慧校园首页：8 统计卡 + 10 项快捷入口 + 数据看板 + 四端职能 +
    // 工作提醒 + 右侧档案/校级通知。三个共享入口直接复用全站对应页面：
    //   - 群聊 → controller.openGroupChat → GroupChatView
    //   - 校长信箱 → controller.openPrincipalMailbox → PrincipalMailboxView
    //   - 校圈治理 → Navigator.pushNamed(circle) → CirclePage
    // 从子页 backToDashboard 后会自动落回 AdminHomeView。
    if (state.selectedRole == SmartCampusRole.admin) {
      if (state.mainView == SmartCampusMainView.principalMailbox) {
        return PrincipalMailboxView(onBack: controller.backToDashboard);
      }
      if (state.mainView == SmartCampusMainView.groupChat) {
        return GroupChatView(
          onBack: controller.backToDashboard,
          currentUserId: shellState.user.id,
          currentUserName: shellState.user.displayName,
          currentUserAvatarUrl: shellState.user.avatarUrl,
        );
      }
      // 管理员端「学生管理」独立视图：banner + 4 张渐变统计卡 + 5 状态 tabs +
      // 班级 dropdown + 搜索 + 当前结果 + 学生卡 3 列网格；点击卡片打开
      // 「学籍档案」GradientHeaderDialog（导出学籍 / 取消）。
      if (state.mainView == SmartCampusMainView.studentManagement) {
        return AdminStudentManagementView(onBack: controller.backToDashboard);
      }
      // 管理员端「教师管理」独立视图：banner + 5 张彩色渐变统计卡（在岗 /
      // 请假 / 产假 / 班主任 / 名册总数）+ 班级 dropdown + 搜索（姓名/工号/
      // 任课方向）+ 当前结果 + 教师卡 3 列网格（左下"班主任"黄标 + 右上彩点
      // 状态徽章）；点击卡片打开「教师档案」GradientHeaderDialog
      // （导出档案 / 取消）。
      if (state.mainView == SmartCampusMainView.teacherManagement) {
        return AdminTeacherManagementView(onBack: controller.backToDashboard);
      }
      // 管理员端「班级编组」独立视图：banner（创建班级 / 人员调班）+ 4 张
      // 彩色渐变统计卡（行政班数 / 在籍人数 / 可调班在籍 / 调班记录）+
      // 「行政班一览」分节标题 + 行政班卡片堆叠（每张含 header 折叠条 +
      // 展开时 3 列学生迷你卡，右上"在籍"紫色 cut-corner 徽章）；
      // banner 上的两枚按钮分别打开「创建行政班」和「人员调班」右抽屉
      // （穿梭框 + 表单 + 取消/创建按钮）。
      if (state.mainView == SmartCampusMainView.classManagement) {
        return AdminClassManagementView(onBack: controller.backToDashboard);
      }
      // 管理员端「排课与课表」独立视图：白卡 banner（左返回 + 居中标题 +
      // 右 tab 分段：周课表与排课 / 小课申请审核 + 红角标）；tab 1 是
      // 「全校统一课表」班级 dropdown + 查看 / 编辑 分段 + 控制条 + 7 天 ×
      // 5 时段网格（4 主题课卡，编辑模式空格 / 第 1 行追加 "申请小课" pill
      // 打开右侧编辑抽屉）；tab 2 是 "小课排班申请" 双列卡片网格，
      // 待审核态显示 通过/驳回 按钮，驳回弹 GradientHeaderDialog 填理由。
      if (state.mainView == SmartCampusMainView.scheduleManagement) {
        return AdminScheduleManagementView(onBack: controller.backToDashboard);
      }
      // 管理员端「宿管请假审批」独立视图：banner + 3 张统计卡（待审批/已通过/
      // 已拒绝）+ 提示文案 + 4 状态 tabs（全部/待审批/已通过/已拒绝）+
      // 「审批中 N 条」+ 紫渐变「发起申请」+ 双列卡片网格；待审批卡片底部
      // 「通过/驳回」按钮，「驳回」打开 GradientHeaderDialog 填理由。
      if (state.mainView == SmartCampusMainView.dormLeaveApproval) {
        return AdminDormLeaveApprovalView(onBack: controller.backToDashboard);
      }
      // 管理员端「人脸库」独立视图：banner（含 "人脸录入 / 底库记录" 分段）
      // + 4 张统计卡（已生效 / 待审核 / 已驳回 / 记录总数）+ 录入流程
      // 步骤条 + 行政班/学生 双下拉 + 上传人脸（虚线圆形 + 上传/摄像头）
      // + 采集规范（3 张示例 ❌❌✅）+ 勾选确认 + 紫渐变提交按钮。
      if (state.mainView == SmartCampusMainView.faceLibrary) {
        return AdminFaceLibraryView(onBack: controller.backToDashboard);
      }
      // 管理员端「通知管理」独立视图：banner（含右上角 "新建通知"）+
      // 5 张统计卡（已发布 / 定时中 / 草稿 / 已撤回 / 全部）+
      // 类型/状态 双下拉 + 搜索框 + 970 宽白底 16 圆角表格
      // （标题/类型/优先级/范围/状态/时间/操作）+ 右侧 600 抽屉式
      // 「新建通知 / 编辑通知」表单（标题、内容、类型、优先级、推送
      // 范围、发布方式：立即发布/定时发布/保存为草稿）。
      if (state.mainView == SmartCampusMainView.notificationManagement) {
        return AdminNotificationManagementView(
          onBack: controller.backToDashboard,
        );
      }
      if (state.mainView == SmartCampusMainView.signManagement) {
        return AdminSignManagementView(onBack: controller.backToDashboard);
      }
      if (state.mainView == SmartCampusMainView.dashboard) {
        return AdminHomeView(
          shellDisplayName: shellState.user.displayName,
          avatarUrl: shellState.user.avatarUrl,
          // 右侧栏「身份切换」按钮：让多端管理员 / 跨端教师可以从 admin
          // 视图直接切到任课老师 / 班主任 / 宿管 / 学生 dashboard，
          // 与教师 dashboard 的按钮组对齐。
          availableRoles: state.availableRoles,
          selectedRole: state.selectedRole,
          onSelectRole: controller.selectRole,
          onOpenGroupChat: controller.openGroupChat,
          onOpenPrincipalMailbox: controller.openPrincipalMailbox,
          onOpenSchoolCircle: openSchoolCircle,
          onOpenStudentManagement: controller.openStudentManagement,
          onOpenTeacherManagement: controller.openTeacherManagement,
          onOpenClassManagement: controller.openClassManagement,
          onOpenScheduleManagement: controller.openScheduleManagement,
          onOpenDormLeaveApproval: controller.openDormLeaveApproval,
          onOpenFaceLibrary: controller.openFaceLibrary,
          onOpenNotificationManagement: controller.openNotificationManagement,
          onOpenSignManagement: controller.openSignManagement,
        );
      }
    }

    if (isTeacherOrHead) {
      if (state.mainView == SmartCampusMainView.classWorkbench) {
        return TeacherClassWorkbenchView(onBack: controller.backToDashboard);
      }
      if (state.mainView == SmartCampusMainView.principalMailbox) {
        return PrincipalMailboxView(onBack: controller.backToDashboard);
      }
      // 教师/班主任端"授课课表"独立视图：与学生"我的课表"共用 mainView=mySchedule，
      // 但渲染 [TeacherLessonScheduleView]（多了 查看/编辑 切换 + legend +
      // 编辑模式空格可申请小课）。
      if (state.mainView == SmartCampusMainView.mySchedule) {
        return TeacherLessonScheduleView(onBack: controller.backToDashboard);
      }
      // 教师/班主任端"签课管理"独立视图：banner + 5 项统计 + 总数据/本学期/
      // 本月 tabs + 最近签课记录 + 双列(今日课程 + 大课/小课签到操作面板)。
      if (state.mainView == SmartCampusMainView.classAttendance) {
        return TeacherClassAttendanceView(onBack: controller.backToDashboard);
      }
      // 教师/班主任端"学生名册"独立视图：banner + 班级 dropdown + 搜索 +
      // 当前列表/男/女 三色统计 + 学生卡 3 列网格。
      if (state.mainView == SmartCampusMainView.studentRoster) {
        return TeacherStudentRosterView(onBack: controller.backToDashboard);
      }
      // 教师/班主任端"作业批改"独立视图：banner + 4 状态 tabs + 班级筛选 +
      // 累计/本学期/本月 toggle + 6 项统计 + 左作业列表 + 右作业详情与
      // 学生提交表，支持 "发布作业 / 历史发布记录 / 作业点评" 3 个右抽屉。
      if (state.mainView == SmartCampusMainView.homeworkReview) {
        return TeacherHomeworkReviewView(onBack: controller.backToDashboard);
      }
      // 教师/班主任端"考评管理"独立视图：与作业批改同款双列布局，但只读
      // (不可新建考试) + 5 状态 tabs(全部/审批中/已通过/已拒绝/已撤销) +
      // banner 副标题 + 6 项统计(待评分/关联考试/已评/均分/最高/最低) +
      // 列表卡含 N/M 提交比 + 右栏紫色月考同步说明 + 评分 / 历史月考 2 个抽屉。
      if (state.mainView == SmartCampusMainView.examReview) {
        return TeacherExamReviewView(onBack: controller.backToDashboard);
      }
      // 班主任端"请假审批"独立视图：banner + 4 张统计卡 + 提示与备案说明 +
      // 6 状态 tabs(全部/待我审批/审批中/已通过/已拒绝/已撤销) + 搜索框 +
      // 双列卡片网格(头像/学号/类型/时长/状态徽章 + 灰底信息块: 请假时间/
      // 事由/申请时间/路径/家长→班主任 stepper/备注；审批中卡片底部"通过 /
      // 驳回"按钮，"驳回"打开 GradientHeaderDialog 弹窗)。
      if (state.mainView == SmartCampusMainView.leaveApproval) {
        return TeacherLeaveApprovalView(onBack: controller.backToDashboard);
      }
      // 班主任端"查寝动态"独立视图：banner + 4 张统计卡(住宿生 / 今晚已归寝
      // 口径 / 异常 / 补卡待审) + 提示文案 + 「本班查纪 / 补卡审核」tabs +
      // 搜索框 + 「全部异常记录 N 条」+ 全部 / 异常 toggle + 学生口径卡片
      // (头像/学号/状态徽章/宿舍/规定打卡时间双列/备注) 与宿舍口径卡片
      // (晨查寝/晚查寝 18 Barlow 标题 + 大色块状态徽章) 网格。
      if (state.mainView == SmartCampusMainView.dormDynamic) {
        return TeacherDormDynamicView(onBack: controller.backToDashboard);
      }
      // 班主任端"查寝历史"独立视图：banner + 14 天日期条 + 4 张统计卡 +
      // 晚查寝 / 晨查寝 tabs + 宿舍口径 (晨/晚查寝大标题) 与学生口径
      // (头像/学号/状态徽章) 卡片混合 3 列网格；从 dashboard 进入后切走，
      // 由 banner 上的返回按钮调 controller.backToDashboard() 回到首页。
      if (state.mainView == SmartCampusMainView.dormHistory) {
        return TeacherDormHistoryView(onBack: controller.backToDashboard);
      }
      // 班主任端"家校沟通"独立视图：banner + 3 张统计卡（未读消息 / 待回复
      // / 会话总数）+ 全部 / 未读 / 待回复 tabs + 搜索 + 家长对话卡 3 列
      // 网格（头像 + 学生姓名 / 学号 + 家长称谓 + 标签 + 灰底家长发言预览
      // + 时间戳 + 可选"短信未送达"红字）；点击卡片打开对话详情弹窗
      // （紫白渐变头 + 老师/家长气泡 + 输入栏 + 退出）。
      if (state.mainView == SmartCampusMainView.homeSchool) {
        return TeacherHomeSchoolView(onBack: controller.backToDashboard);
      }
      // 五端共用「群聊」：教师/班主任也使用同一聊天主界面（学生身份的
      // displayName/avatar 改成传入的 shell 用户名 + 头像即可）。
      if (state.mainView == SmartCampusMainView.groupChat) {
        return GroupChatView(
          onBack: controller.backToDashboard,
          currentUserId: shellState.user.id,
          currentUserName: shellState.user.displayName,
          currentUserAvatarUrl: shellState.user.avatarUrl,
        );
      }
      return TeacherDashboardLayout(
        selectedRole: state.selectedRole,
        // 跨端老师（teacherRole 返回多个角色）/ admin 切到任课/班主任视图
        // 时，把全量可切身份传下去，右侧栏的「身份切换」按钮组按它渲染，
        // 让用户能从教师 dashboard 直接跳回 admin / 宿管 / 学生 端。
        availableRoles: state.availableRoles,
        shellDisplayName: shellState.user.displayName,
        avatarUrl: shellState.user.avatarUrl,
        onOpenPrincipalMailbox: controller.openPrincipalMailbox,
        onOpenMyClass: controller.openMyClass,
        onOpenClassWorkbench: controller.openClassWorkbench,
        onOpenMySchedule: controller.openMySchedule,
        onOpenGroupChat: controller.openGroupChat,
        onOpenSchoolCircle: openSchoolCircle,
        onOpenClassAttendance: controller.openClassAttendance,
        onOpenStudentRoster: controller.openStudentRoster,
        onOpenHomeworkReview: controller.openHomeworkReview,
        onOpenExamReview: controller.openExamReview,
        onOpenLeaveApproval: controller.openLeaveApproval,
        onOpenDormDynamic: controller.openDormDynamic,
        onOpenDormHistory: controller.openDormHistory,
        onOpenHomeSchool: controller.openHomeSchoolCommunication,
        // 把任课老师 / 班主任 tab 切换持久化到 controller：
        // admin 切到「班主任」后进子页再返回仍保持班主任视图；普通教师
        // 因为 availableRoles 锁死，selectRole 会被 ignore，不影响。
        onSelectRole: controller.selectRole,
      );
    }

    if (state.selectedRole == SmartCampusRole.student) {
      if (state.mainView == SmartCampusMainView.principalMailbox) {
        return PrincipalMailboxView(onBack: controller.backToDashboard);
      }
      // 学生端"我的班级"独立视图：从 dashboard 进入后切走，由 banner 上的
      // 返回按钮调 controller.backToDashboard() 回到首页。
      if (state.mainView == SmartCampusMainView.myClass) {
        return StudentMyClassView(onBack: controller.backToDashboard);
      }
      // 学生端"我的课表"独立视图：周切换内部 setState，不影响外层 mainView。
      if (state.mainView == SmartCampusMainView.mySchedule) {
        return StudentMyScheduleView(onBack: controller.backToDashboard);
      }
      // 学生端"课堂签到"独立视图：banner 返回 → controller.backToDashboard。
      if (state.mainView == SmartCampusMainView.checkIn) {
        return StudentCheckInView(onBack: controller.backToDashboard);
      }
      // 学生端"我的作业"独立视图：banner 返回 → controller.backToDashboard。
      if (state.mainView == SmartCampusMainView.myHomework) {
        return StudentMyHomeworkView(onBack: controller.backToDashboard);
      }
      // 学生端"我的成绩"独立视图：banner 返回 → controller.backToDashboard。
      if (state.mainView == SmartCampusMainView.myGrades) {
        return StudentMyGradesView(onBack: controller.backToDashboard);
      }
      // 学生端"群聊"独立视图（与教师端共享同一 GroupChatView）。
      if (state.mainView == SmartCampusMainView.groupChat) {
        return GroupChatView(
          onBack: controller.backToDashboard,
          currentUserId: shellState.user.id,
          currentUserName: shellState.user.displayName,
          currentUserAvatarUrl: shellState.user.avatarUrl,
        );
      }
      // 学生端"请假管理"独立视图：banner 返回 → controller.backToDashboard。
      if (state.mainView == SmartCampusMainView.leaveManagement) {
        return StudentLeaveManagementView(onBack: controller.backToDashboard);
      }
      // 学生端"查寝管理"独立视图：banner 返回 → controller.backToDashboard。
      if (state.mainView == SmartCampusMainView.dormCheck) {
        return StudentDormCheckView(
          onBack: controller.backToDashboard,
          studentName: shellState.user.displayName,
        );
      }
      return StudentDashboardLayout(
        shellDisplayName: shellState.user.displayName,
        avatarUrl: shellState.user.avatarUrl,
        onOpenPrincipalMailbox: controller.openPrincipalMailbox,
        onOpenMyClass: controller.openMyClass,
        onOpenMySchedule: controller.openMySchedule,
        onOpenCheckIn: controller.openCheckIn,
        onOpenMyHomework: controller.openMyHomework,
        onOpenMyGrades: controller.openMyGrades,
        onOpenGroupChat: controller.openGroupChat,
        onOpenSchoolCircle: openSchoolCircle,
        onOpenLeaveManagement: controller.openLeaveManagement,
        onOpenDormCheck: controller.openDormCheck,
      );
    }

    // 宿管端：复用 admin / 教师端的「群聊 / 校长信箱 / 校圈」全站入口，
    // 「按宿舍查寝 / 查寝历史 / 打卡管理」已接入独立视图，其余 1 项
    // 「宿管请假」目前先保留占位回调，待对应独立视图就位后再接入。
    if (state.selectedRole == SmartCampusRole.dormManager) {
      if (state.mainView == SmartCampusMainView.principalMailbox) {
        return PrincipalMailboxView(onBack: controller.backToDashboard);
      }
      if (state.mainView == SmartCampusMainView.groupChat) {
        return GroupChatView(
          onBack: controller.backToDashboard,
          currentUserId: shellState.user.id,
          currentUserName: shellState.user.displayName,
          currentUserAvatarUrl: shellState.user.avatarUrl,
        );
      }
      if (state.mainView == SmartCampusMainView.dormCheckByRoom) {
        return DormManagerCheckByRoomView(
          onBack: controller.backToDashboard,
        );
      }
      if (state.mainView == SmartCampusMainView.dormHistory) {
        return DormManagerCheckHistoryView(
          onBack: controller.backToDashboard,
        );
      }
      if (state.mainView == SmartCampusMainView.dormCheckInManagement) {
        return DormManagerCheckInView(
          onBack: controller.backToDashboard,
        );
      }
      if (state.mainView == SmartCampusMainView.dashboard) {
        return DormManagerHomeView(
          shellDisplayName: shellState.user.displayName,
          avatarUrl: shellState.user.avatarUrl,
          availableRoles: state.availableRoles,
          selectedRole: state.selectedRole,
          onSelectRole: controller.selectRole,
          onOpenGroupChat: controller.openGroupChat,
          onOpenPrincipalMailbox: controller.openPrincipalMailbox,
          onOpenSchoolCircle: openSchoolCircle,
          onOpenDormCheckByRoom: controller.openDormCheckByRoom,
          onOpenDormCheckHistory: controller.openDormHistory,
          onOpenCheckInManagement: controller.openDormCheckInManagement,
        );
      }
    }

    return _SmartCampusPlaceholder(state: state, controller: controller);
  }
}

/// 学生端 / 宿管端 / 管理员端的占位页：保留 1.0 时期的稳定骨架，
/// 让路由可进入、可切角色，便于后续逐端按 Figma 重建。
class _SmartCampusPlaceholder extends StatelessWidget {
  const _SmartCampusPlaceholder({
    required this.state,
    required this.controller,
  });

  final SmartCampusState state;
  final SmartCampusController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.all(ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '智慧校园',
            style: TextStyle(
              fontSize: ui(28),
              fontWeight: AppFont.w600,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          Text(
            '当前角色暂未接入完整视图，先保留角色切换和基础入口，避免影响其他页面开发。',
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
              height: 1.5,
            ),
          ),
          SizedBox(height: ui(24)),
          Wrap(
            spacing: ui(12),
            runSpacing: ui(12),
            children: [
              for (final role in state.availableRoles)
                _RoleChip(
                  label: role.label,
                  active: role == state.selectedRole,
                  onTap: () => controller.selectRole(role),
                  ui: ui,
                ),
            ],
          ),
          SizedBox(height: ui(24)),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(ui(16)),
                border: Border.all(color: const Color(0xFFE8EBF3)),
              ),
              padding: EdgeInsets.all(ui(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: '当前角色',
                    value: state.selectedRole.label,
                    ui: ui,
                  ),
                  SizedBox(height: ui(12)),
                  _InfoRow(
                    label: '当前视图',
                    value: _viewLabel(state.mainView),
                    ui: ui,
                  ),
                  SizedBox(height: ui(24)),
                  Text(
                    '说明',
                    style: TextStyle(
                      fontSize: ui(18),
                      fontWeight: AppFont.w600,
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  SizedBox(height: ui(10)),
                  Text(
                    '老师 / 班主任端首页与「班级工作台」已接入完整视图；学生 / 宿管 / 管理员端仍为骨架占位，按 Figma 节点重建后再上线。',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFF5F6B7B),
                      fontFamily: 'PingFang SC',
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _viewLabel(SmartCampusMainView view) {
    switch (view) {
      case SmartCampusMainView.dashboard:
        return '首页看板';
      case SmartCampusMainView.principalMailbox:
        return '校长信箱';
      case SmartCampusMainView.myClass:
        return '我的班级';
      case SmartCampusMainView.mySchedule:
        return '我的课表';
      case SmartCampusMainView.classWorkbench:
        return '班级工作台';
      case SmartCampusMainView.checkIn:
        return '课堂签到';
      case SmartCampusMainView.myHomework:
        return '我的作业';
      case SmartCampusMainView.myGrades:
        return '我的成绩';
      case SmartCampusMainView.groupChat:
        return '群聊';
      case SmartCampusMainView.leaveManagement:
        return '请假管理';
      case SmartCampusMainView.leaveApproval:
        return '请假审批';
      case SmartCampusMainView.dormCheck:
        return '查寝管理';
      case SmartCampusMainView.dormDynamic:
        return '查寝动态';
      case SmartCampusMainView.dormHistory:
        return '查寝历史';
      case SmartCampusMainView.dormCheckByRoom:
        return '按宿舍查寝';
      case SmartCampusMainView.dormCheckInManagement:
        return '打卡管理';
      case SmartCampusMainView.homeSchool:
        return '家校沟通';
      case SmartCampusMainView.classAttendance:
        return '签课管理';
      case SmartCampusMainView.studentRoster:
        return '学生名册';
      case SmartCampusMainView.homeworkReview:
        return '作业批改';
      case SmartCampusMainView.examReview:
        return '考评管理';
      case SmartCampusMainView.studentManagement:
        return '学生管理';
      case SmartCampusMainView.teacherManagement:
        return '教师管理';
      case SmartCampusMainView.classManagement:
        return '班级编组';
      case SmartCampusMainView.scheduleManagement:
        return '排课与课表';
      case SmartCampusMainView.dormLeaveApproval:
        return '宿管请假审批';
      case SmartCampusMainView.faceLibrary:
        return '人脸库';
      case SmartCampusMainView.notificationManagement:
        return '通知管理';
      case SmartCampusMainView.signManagement:
        return '签课管理';
    }
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.ui,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double Function(num) ui;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A1630) : const Color(0xFFF1F3F8),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            fontWeight: AppFont.w500,
            color: active ? Colors.white : const Color(0xFF5F6B7B),
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.ui});

  final String label;
  final String value;
  final double Function(num) ui;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: ui(84),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(15),
            color: const Color(0xFF0B081A),
            fontWeight: AppFont.w500,
            fontFamily: 'PingFang SC',
          ),
        ),
      ],
    );
  }
}
