import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final circleRepositoryProvider = Provider<CircleRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return CircleRepository(client: client);
});

/// 校圈（帖子）接口：`POST /app/school/v2/posts/*`。
///
/// 请求头 `app-token` / `schoolId` 由 [ApiClient] 注入。帖子与评论的雪花
/// id 一律以 **字符串** 传输，避免 web 端 number 精度丢失。
///
/// 字段命名约定（与后端 swagger 对齐）：
/// - 单条帖子的"详情 / 删除" → body 用 `id`
/// - 单条帖子的"点赞 / 取消点赞" → body 用 `postsId`
/// - 单条评论的"删除" → body 用 `id`
/// - 单条评论的"点赞 / 取消点赞" → body 用 `commentId`
/// - 评论与帖子的外键关系（评论列表 / 新建评论） → body 用 `postsId`
class CircleRepository {
  CircleRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/posts';

  Future<ApiResponse> myPostsDetail({required String id}) {
    return client.post('$_base/myPostsDetail', data: <String, dynamic>{'id': id});
  }

  Future<ApiResponse> myPostsList({int current = 1, int size = 10}) {
    return client.post(
      '$_base/myPostsList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  Future<ApiResponse> myPostsSave(Map<String, dynamic> body) {
    return client.post('$_base/myPostsSave', data: body);
  }

  Future<ApiResponse> postsCommentDelete({required String commentId}) {
    return client.post(
      '$_base/postsCommentDelete',
      data: <String, dynamic>{'id': commentId},
    );
  }

  Future<ApiResponse> postsCommentLike({required String commentId}) {
    return client.post(
      '$_base/postsCommentLike',
      data: <String, dynamic>{'commentId': commentId},
    );
  }

  /// 帖子评论列表 `POST /app/school/v2/posts/postsCommentList`。
  ///
  /// 严格对齐 swagger：
  /// ```json
  /// { "offsetId": 0, "postsId": 1, "size": 10 }
  /// ```
  /// - [offsetId]：从该评论 id「之前」开始拉；首屏 / 刷新传 `'0'`。
  /// - [size]：每页评论条数，默认 20。
  Future<ApiResponse> postsCommentList({
    required String postsId,
    String offsetId = '0',
    int size = 20,
  }) {
    return client.post(
      '$_base/postsCommentList',
      data: <String, dynamic>{
        'postsId': postsId,
        'offsetId': offsetId,
        'size': size,
      },
    );
  }

  /// 发布评论 `POST /app/school/v2/posts/postsCommentSave`。
  ///
  /// 严格对齐 swagger：
  /// ```json
  /// { "comment": "评论内容", "postsId": 1, "replyId": 0 }
  /// ```
  /// - [comment]：评论正文（注意字段名是 `comment`，不是 `content`）。
  /// - [replyId]：回复哪条评论，默认 `'0'` 表示直接回复帖子；楼中楼/at 回复
  ///   时把对应评论的 id 传进来。
  Future<ApiResponse> postsCommentSave({
    required String postsId,
    required String comment,
    String replyId = '0',
  }) {
    return client.post(
      '$_base/postsCommentSave',
      data: <String, dynamic>{
        'postsId': postsId,
        'comment': comment,
        'replyId': replyId,
      },
    );
  }

  Future<ApiResponse> postsCommentUnlike({required String commentId}) {
    return client.post(
      '$_base/postsCommentUnlike',
      data: <String, dynamic>{'commentId': commentId},
    );
  }

  Future<ApiResponse> postsDelete({required String postsId}) {
    return client.post(
      '$_base/postsDelete',
      data: <String, dynamic>{'id': postsId},
    );
  }

  Future<ApiResponse> postsDetail({required String postsId}) {
    return client.post(
      '$_base/postsDetail',
      data: <String, dynamic>{'id': postsId},
    );
  }

  Future<ApiResponse> postsLike({required String postsId}) {
    return client.post(
      '$_base/postsLike',
      data: <String, dynamic>{'postsId': postsId},
    );
  }

  /// 校圈帖子列表 `POST /app/school/v2/posts/postsList`。
  ///
  /// 请求体严格对齐 swagger `PostsListReq`：
  /// ```json
  /// { "current": 1, "size": 10, "keyword": "", "sortType": 0, "type": 0 }
  /// ```
  /// - [sortType]：0-最新发布 / 1-热门推荐 / 2-为你推荐
  /// - [type]：0-文章 / 1-图片 / 2-视频 / 3-音乐；传 `null` 表示不限类型
  /// - [keyword]：去掉首尾空白后才下发；空字符串不带，避免后端按空串严格匹配
  Future<ApiResponse> postsList({
    int current = 1,
    int size = 20,
    String keyword = '',
    int sortType = 0,
    int? type,
  }) {
    final body = <String, dynamic>{
      'current': current,
      'size': size,
      'sortType': sortType,
    };
    final trimmed = keyword.trim();
    if (trimmed.isNotEmpty) body['keyword'] = trimmed;
    if (type != null) body['type'] = type;
    return client.post('$_base/postsList', data: body);
  }

  Future<ApiResponse> postsUnlike({required String postsId}) {
    return client.post(
      '$_base/postsUnlike',
      data: <String, dynamic>{'postsId': postsId},
    );
  }
}
