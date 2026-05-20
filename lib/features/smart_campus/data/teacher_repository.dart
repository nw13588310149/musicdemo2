import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

/// 任课老师端相关接口的 Repository。
///
/// 全部为 `POST /app/school/v2/teacher/*`，对应后端 Swagger 中的
/// **v2 智慧校园-任课老师端 (App School V2 Teacher Controller)**。
/// 头部 `app-token` / `schoolId` 由 [ApiClient] 注入。
///
/// 与教师视图相关的几个核心接口：
///   - [classList]                       我教的班级列表（可按 type 过滤）
///   - [courseList]                      我的课表（按 begin/end 日期过滤）
///   - [schoolSmallCourseApplySave]      提交"申请小课"
///   - [schoolSmallCourseApplyList]      我的小课申请列表
///   - [schoolSmallCourseApplyDetail]    我的小课申请详情
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return TeacherRepository(client: client);
});

class TeacherRepository {
  TeacherRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/teacher';

  // ============== 教师身份 ==============

  /// 教师在校内的多重身份记录（`AppSchoolTeacher` 列表）。
  ///
  /// 后端字段示意：
  /// ```json
  /// {
  ///   "code": 0,
  ///   "data": [{
  ///     "campusId": 1,
  ///     "roles": "head_teacher,course_teacher",  // CSV
  ///     "schoolId": 1, "teacherId": "...", ...
  ///   }]
  /// }
  /// ```
  /// `roles` 取值集合：`headmaster` 校长 / `manager` 教务管理员 /
  /// `dormitory` 宿管 / `head_teacher` 班主任 / `course_teacher` 任课老师。
  ///
  /// 当 `myInfo.role == 'teacher'` 时，智慧校园 dashboard 用本接口结果决定
  /// 同一位教师可切换的身份集合（管理员看 5 端，普通老师看自己拥有的）。
  Future<ApiResponse> teacherRole() {
    return client.post('$_base/teacherRole');
  }

  // ============== 班级 / 课表 ==============

  /// 任课老师"我教的班级"列表。后端基于 token 自动过滤为当前老师任教
  /// 或担任班主任的班级。
  ///
  /// - `type`: 班级类型过滤，`0 = 大班`，`1 = 小班`；不传 = 全量（大 + 小）。
  ///   主要场景：申请小课时传 `type: 1` 只展示「我的小班」。
  /// - `campusId` / `keyword`: 与 admin classList 同义，按校区或关键字过滤。
  Future<ApiResponse> classList({int? type, int? campusId, String? keyword}) {
    final body = <String, dynamic>{};
    if (type != null) body['type'] = type;
    if (campusId != null) body['campusId'] = campusId;
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    return client.post('$_base/classList', data: body);
  }

  /// 任课老师"我的课表"。后端会基于 token 自动定位到当前老师的全部排课。
  /// `beginDate` / `endDate` 为 `yyyy-MM-dd` 字符串（与 admin courseList 一致），
  /// 不传时返回全量。
  Future<ApiResponse> courseList({String? beginDate, String? endDate}) {
    final body = <String, dynamic>{};
    if (beginDate != null && beginDate.isNotEmpty) {
      body['beginDate'] = beginDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      body['endDate'] = endDate;
    }
    return client.post('$_base/courseList', data: body);
  }

  // ============== 小班课申请 ==============

  /// 提交"申请小课"。
  ///
  /// 期望字段（与后端 swagger 对齐，调用方需自行组装）：
  /// ```json
  /// {
  ///   "classId": "1788178798952914945",
  ///   "classroomId": 1,
  ///   "color": "#ff0000",
  ///   "courseList": [
  ///     {
  ///       "classId": "1798658711795392514",
  ///       "classroomId": 1,
  ///       "color": "#ff0000",
  ///       "date": "2026-05-30",
  ///       "lineNum": 1,
  ///       "subjectId": 1,
  ///       "teacherId": "1788178798952914945"  // 当前任课老师 id（雪花，String）
  ///     }
  ///   ],
  ///   "endDate": "2026-05-08",
  ///   "lineNum": 1,
  ///   "startDate": "2026-05-08",
  ///   "subjectId": 1
  /// }
  /// ```
  ///
  /// 雪花 long（`classId` / `teacherId`）必须以字符串形式提交，避免在 web 端
  /// 因 JS Number 53bit 精度丢失。日期字段统一使用 `yyyy-MM-dd`。
  Future<ApiResponse> schoolSmallCourseApplySave(Map<String, dynamic> body) {
    return client.post('$_base/schoolSmallCourseApplySave', data: body);
  }

  /// 我的小班课申请列表。`current` / `size` 默认 1 / 10，与 swagger 一致。
  Future<ApiResponse> schoolSmallCourseApplyList({
    int current = 1,
    int size = 10,
  }) {
    return client.post(
      '$_base/schoolSmallCourseApplyList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 我的小班课申请详情。`id` 直接用后端原始字符串，兼容雪花 long。
  Future<ApiResponse> schoolSmallCourseApplyDetail(String id) {
    return client.post(
      '$_base/schoolSmallCourseApplyDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  // ============== 班级通知（班主任端） ==============

  /// 班级通知列表。分页，默认第 1 页、每页 10 条。
  Future<ApiResponse> schoolClassNoticeList({
    required String classId,
    int current = 1,
    int size = 10,
  }) {
    return client.post(
      '$_base/schoolClassNoticeList',
      data: <String, dynamic>{
        'classId': classId,
        'current': current,
        'size': size,
      },
    );
  }

  /// 新增班级通知。`title` 为通知标题，`content` 为正文。
  Future<ApiResponse> schoolClassNoticeSave({
    required String classId,
    required String title,
    required String content,
  }) {
    return client.post(
      '$_base/schoolClassNoticeSave',
      data: <String, dynamic>{
        'classId': classId,
        'title': title,
        'content': content,
      },
    );
  }

  // ============== 学生管理（班主任端） ==============

  /// 班级学生列表（分页）。`classId` 为 `"0"` 表示全部班级；具体班级传雪花 **字符串**。
  ///
  /// 请求体：`archiveId`、`classId`（全部时为数字 `0`，与后端示例一致）、`current`、
  /// `keyword`、`size`、`studentStatus`、`type`。
  Future<ApiResponse> studentList({
    String classId = '0',
    int current = 1,
    int size = 10,
    String keyword = '',
    String studentStatus = '',
    int type = 0,
    int archiveId = 0,
  }) {
    final Object classIdBody =
        classId == '0' || classId.isEmpty ? 0 : classId;
    final body = <String, dynamic>{
      'archiveId': archiveId,
      'classId': classIdBody,
      'current': current,
      'keyword': keyword,
      'size': size,
      'studentStatus': studentStatus,
      'type': type,
    };
    return client.post('$_base/studentList', data: body);
  }

  /// 编辑学生信息。仅允许班主任修改 `remark`（备注）和 `tags`（标签，逗号分隔）。
  Future<ApiResponse> studentUpdate({
    required int studentId,
    String remark = '',
    String tags = '',
  }) {
    return client.post(
      '$_base/studentUpdate',
      data: <String, dynamic>{
        'studentId': studentId,
        'remark': remark,
        'tags': tags,
      },
    );
  }

  /// 学生详情。`id` 为学生主键（雪花 long 请用 String 传入，避免 Web 端精度丢失）。
  Future<ApiResponse> studentDetail({required Object id}) {
    final sid = id is String ? id : id.toString();
    return client.post(
      '$_base/studentDetail',
      data: <String, dynamic>{'id': sid},
    );
  }

  // ============== 作业管理（任课老师端） ==============

  /// 作业数据汇总。返回待批改人次、发布数、均分、最高/最低分等聚合指标。
  ///
  /// `beginDate` / `endDate` 格式 `yyyy-MM-dd`；`classId` 为 `"0"` 表示全部班级。
  /// 班级 id 须用 **字符串**（雪花 id），勿用 int 以免 Web/JSON 精度丢失。
  Future<ApiResponse> teacherHomeworkSum({
    required String classId,
    required String beginDate,
    required String endDate,
  }) {
    return client.post(
      '$_base/teacherHomeworkSum',
      data: <String, dynamic>{
        'classId': classId,
        'beginDate': beginDate,
        'endDate': endDate,
      },
    );
  }

  /// 作业列表（分页）。
  ///
  /// `status`：`0` 进行中、`1` 已完成、`2` 待我批改；**空字符串 `''` 表示全部**
  ///（与后端约定：全部时传入 `""`，勿省略字段）。
  Future<ApiResponse> teacherHomeworkList({
    String classId = '0',
    int current = 1,
    int size = 20,
    String keyword = '',
    Object? status,
  }) {
    final body = <String, dynamic>{
      'classId': classId,
      'current': current,
      'size': size,
      'status': status ?? '',
    };
    if (keyword.isNotEmpty) body['keyword'] = keyword;
    return client.post('$_base/teacherHomeworkList', data: body);
  }

  /// 发布作业。`classIds` 为目标班级 ID 列表，`endTime` 格式 `yyyy-MM-dd HH:mm:ss`
  ///（例 `2026-05-19 17:11:00`），`expectedExt` 为期望格式标识（如 "audio"/"video"/"doc"/"image"）。
  /// `classIds` 每项为字符串雪花 id，勿用 int。
  Future<ApiResponse> teacherHomeworkSave({
    required List<String> classIds,
    required String title,
    required String description,
    required String endTime,
    required int subjectId,
    String expectedExt = '',
  }) {
    return client.post(
      '$_base/teacherHomeworkSave',
      data: <String, dynamic>{
        'classIds': classIds,
        'title': title,
        'description': description,
        'endTime': endTime,
        'subjectId': subjectId,
        if (expectedExt.isNotEmpty) 'expectedExt': expectedExt,
      },
    );
  }

  /// 作业详情（包含学生提交列表）。
  Future<ApiResponse> teacherHomeworkDetail({required String id}) {
    return client.post(
      '$_base/teacherHomeworkDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 批改作业。`id` 为学生作业记录 ID（studentHomeworkDetail 返回的 id），
  /// `score` 为分数（0-100），`feedback` 为文字评语。
  Future<ApiResponse> teacherHomeworkCorrect({
    required String id,
    required int score,
    String feedback = '',
    String teacherParam1 = '',
    String teacherParam2 = '',
    String teacherParam3 = '',
  }) {
    return client.post(
      '$_base/teacherHomeworkCorrect',
      data: <String, dynamic>{
        'id': id,
        'score': score,
        'feedback': feedback,
        if (teacherParam1.isNotEmpty) 'teacherParam1': teacherParam1,
        if (teacherParam2.isNotEmpty) 'teacherParam2': teacherParam2,
        if (teacherParam3.isNotEmpty) 'teacherParam3': teacherParam3,
      },
    );
  }

  /// 删除作业。
  Future<ApiResponse> teacherHomeworkDelete({required String id}) {
    return client.post(
      '$_base/teacherHomeworkDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 某个学生的作业详情（提交内容、文件、状态等）。
  Future<ApiResponse> studentHomeworkDetail({required String id}) {
    return client.post(
      '$_base/studentHomeworkDetail',
      data: <String, dynamic>{'id': id},
    );
  }
}
