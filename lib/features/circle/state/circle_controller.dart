import 'dart:async' show Timer;
import 'dart:convert' show jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/state/shell_controller.dart';
import '../data/circle_api_mapper.dart';
import '../data/circle_repository.dart';
import 'circle_state.dart';

final circleControllerProvider =
    StateNotifierProvider.autoDispose<CircleController, CircleState>(
      (ref) => CircleController(ref),
    );

class CircleController extends StateNotifier<CircleState> {
  CircleController(this._ref) : super(CircleState.initial()) {
    Future.microtask(refreshPosts);
  }

  final Ref _ref;
  Timer? _searchDebounce;

  CircleRepository get _repo => _ref.read(circleRepositoryProvider);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── 模式切换 ────────────────────────────────────────────────────────
  void setMode(CircleMode mode) {
    if (state.mode == mode) return;
    state = state.copyWith(
      mode: mode,
      commentPanelOpen: mode == CircleMode.list ? false : state.commentPanelOpen,
    );
  }

  // ── 搜索框：300ms 防抖后向后端发起 keyword 查询 ───────────────────
  void setSearchKeyword(String keyword) {
    state = state.copyWith(searchKeyword: keyword);
    // 关键字立即变更后，先用本地过滤同步 visible / immersive 索引，
    // 让 UI 反馈不卡顿；真正的后端检索在防抖结束后再触发。
    final list = state.visiblePosts;
    if (list.isEmpty) {
      state = state.copyWith(immersiveIndex: 0);
    } else {
      final next = state.immersiveIndex.clamp(0, list.length - 1);
      state = state.copyWith(immersiveIndex: next);
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // 仅当关键字仍是当前值时再发请求；避免快速输入把过期请求覆盖。
      refreshPosts();
    });
  }

  /// 切换排序：0-最新发布 / 1-热门推荐 / 2-为你推荐。
  void setSortType(CircleSortType sortType) {
    if (state.sortType == sortType) return;
    state = state.copyWith(sortType: sortType);
    refreshPosts();
  }

  /// 切换内容类型过滤；传 `null` 表示不限。
  void setTypeFilter(CirclePostType? type) {
    if (state.typeFilter == type) return;
    state = state.copyWith(
      typeFilter: type,
      clearTypeFilter: type == null,
    );
    refreshPosts();
  }

  // ── 沉浸模式翻页 ───────────────────────────────────────────────────
  void setImmersiveIndex(int index) {
    final list = state.visiblePosts;
    if (list.isEmpty) return;
    final next = index.clamp(0, list.length - 1);
    if (next == state.immersiveIndex) return;
    state = state.copyWith(immersiveIndex: next);
  }

  // ── 列表加载 ──────────────────────────────────────────────────────
  Future<void> refreshPosts() async {
    state = state.copyWith(listLoading: true);
    try {
      final resp = await _repo.postsList(
        current: 1,
        size: 30,
        keyword: state.searchKeyword,
        sortType: state.sortType.apiCode,
        type: state.typeFilter?.apiCode,
      );
      if (!resp.isSuccess) {
        state = state.copyWith(listLoading: false);
        return;
      }
      final parsed = mapPostsListData(resp.data);
      state = state.copyWith(
        posts: parsed,
        listLoading: false,
      );
      final list = state.visiblePosts;
      final next = list.isEmpty
          ? 0
          : state.immersiveIndex.clamp(0, list.length - 1);
      state = state.copyWith(immersiveIndex: next);
    } catch (_) {
      state = state.copyWith(listLoading: false);
    }
  }

  // ── 点赞（帖子）──────────────────────────────────────────────────
  Future<bool> toggleLike(String postId) async {
    final post = _findPost(postId);
    if (post == null) return false;
    final liked = !post.liked;
    final delta = liked ? 1 : -1;
    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        return p.copyWith(
          liked: liked,
          likeCount: (p.likeCount + delta).clamp(0, 1 << 30),
        );
      }),
    );
    final resp = liked
        ? await _repo.postsLike(postsId: postId)
        : await _repo.postsUnlike(postsId: postId);
    if (resp.isSuccess) return true;
    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        return p.copyWith(
          liked: !liked,
          likeCount: (p.likeCount - delta).clamp(0, 1 << 30),
        );
      }),
    );
    return false;
  }

  /// 收藏：当前后端 openapi 未提供对应接口，仅本地切换 UI 状态。
  void toggleFavorite(String postId) {
    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        final favorited = !p.favorited;
        return p.copyWith(
          favorited: favorited,
          favoriteCount: (p.favoriteCount + (favorited ? 1 : -1)).clamp(
            0,
            1 << 30,
          ),
        );
      }),
    );
  }

  /// 发布一条新动态。`mediaUrl` 为已上传到 OSS 后的可保存 path。
  ///
  /// 严格对齐后端 `myPostsSave` 入参（参考 swagger 示例）：
  /// ```json
  /// {
  ///   "content": "正文",
  ///   "coverImg": "https://.../example1.jpg",
  ///   "description": "描述",
  ///   "medias": "[\"https://.../example1.jpg\"]",
  ///   "title": "标题",
  ///   "type": 1
  /// }
  /// ```
  ///
  /// 字段映射：
  /// - `title`：用户填写的「标题」（必填）
  /// - `content`：用户填写的「正文」（必填）
  /// - `description`：暂时与正文同源（仅做摘要兜底，没有单独输入框）
  /// - `coverImg`：
  ///     - 图片帖：直接复用 `mediaUrl` 当封面
  ///     - 视频 / 音频帖：调用方上传的封面图 path；没传就送空串
  /// - `medias`：JSON 字符串数组 `'["url"]'`
  /// - `type`：1 图片 / 2 视频 / 3 音频
  /// 上传成功后立即重新拉取列表。
  Future<bool> publishPost({
    required String title,
    required String content,
    required PostMediaKind kind,
    required String mediaUrl,
    String coverImg = '',
  }) async {
    final type = switch (kind) {
      PostMediaKind.image => 1,
      PostMediaKind.video => 2,
      PostMediaKind.audio => 3,
    };
    final body = <String, dynamic>{
      'title': title,
      'content': content,
      'description': content,
      'coverImg': kind == PostMediaKind.image ? mediaUrl : coverImg,
      'medias': jsonEncode(<String>[mediaUrl]),
      'type': type,
    };
    final resp = await _repo.myPostsSave(body);
    if (!resp.isSuccess) return false;
    await refreshPosts();
    return true;
  }

  // ── 评论面板 ──────────────────────────────────────────────────────
  Future<void> openCommentPanel(String postId) async {
    state = state.copyWith(
      commentPanelOpen: true,
      commentTargetPostId: postId,
    );
    await loadCommentsForPost(postId);
  }

  void closeCommentPanel() {
    state = state.copyWith(
      commentPanelOpen: false,
      clearCommentsLoading: true,
    );
  }

  Future<void> loadCommentsForPost(String postId) async {
    state = state.copyWith(commentsLoadingPostId: postId);
    try {
      final resp = await _repo.postsCommentList(
        postsId: postId,
        offsetId: '0',
        size: 100,
      );
      if (!resp.isSuccess) {
        state = state.copyWith(clearCommentsLoading: true);
        return;
      }
      final comments = mapCommentsListData(resp.data);
      final post = _findPost(postId);
      final count = comments.isNotEmpty
          ? comments.length
          : (post?.commentCount ?? 0);
      state = state.copyWith(
        posts: _mapPosts(postId, (p) {
          return p.copyWith(
            comments: comments,
            commentCount: count,
          );
        }),
        clearCommentsLoading: true,
      );
    } catch (_) {
      state = state.copyWith(clearCommentsLoading: true);
    }
  }

  Future<bool> toggleCommentLike(String postId, String commentId) async {
    final post = _findPost(postId);
    if (post == null) return false;
    CircleComment? target;
    for (final c in post.comments) {
      if (c.id == commentId) target = c;
    }
    if (target == null) return false;
    final liked = !target.liked;
    final delta = liked ? 1 : -1;

    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        final updated = <CircleComment>[
          for (final c in p.comments)
            if (c.id == commentId)
              c.copyWith(
                liked: liked,
                likeCount: (c.likeCount + delta).clamp(0, 1 << 30),
              )
            else
              c,
        ];
        return p.copyWith(comments: updated);
      }),
    );

    final resp = liked
        ? await _repo.postsCommentLike(commentId: commentId)
        : await _repo.postsCommentUnlike(commentId: commentId);
    if (resp.isSuccess) return true;

    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        final updated = <CircleComment>[
          for (final c in p.comments)
            if (c.id == commentId)
              c.copyWith(
                liked: !liked,
                likeCount: (c.likeCount - delta).clamp(0, 1 << 30),
              )
            else
              c,
        ];
        return p.copyWith(comments: updated);
      }),
    );
    return false;
  }

  Future<bool> addComment(String postId, String text, {String replyId = '0'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final resp = await _repo.postsCommentSave(
      postsId: postId,
      comment: trimmed,
      replyId: replyId,
    );
    if (!resp.isSuccess) return false;
    await loadCommentsForPost(postId);
    return true;
  }

  Future<bool> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final resp = await _repo.postsCommentDelete(commentId: commentId);
    if (!resp.isSuccess) return false;
    await loadCommentsForPost(postId);
    return true;
  }

  Future<bool> deletePost(String postId) async {
    final resp = await _repo.postsDelete(postsId: postId);
    if (!resp.isSuccess) return false;

    final oldVisible = state.visiblePosts;
    final delVisIndex = oldVisible.indexWhere((p) => p.id == postId);
    var newImmersive = state.immersiveIndex;
    if (delVisIndex >= 0 && delVisIndex < newImmersive) {
      newImmersive -= 1;
    }

    final newPosts = [for (final p in state.posts) if (p.id != postId) p];

    final newVisible = [for (final p in newPosts) if (_matchesSearch(p)) p];
    if (newVisible.isEmpty) {
      newImmersive = 0;
    } else {
      newImmersive = newImmersive.clamp(0, newVisible.length - 1);
    }

    final closePanel = state.commentTargetPostId == postId;

    state = state.copyWith(
      posts: newPosts,
      immersiveIndex: newImmersive,
      commentPanelOpen: closePanel ? false : state.commentPanelOpen,
      commentTargetPostId: closePanel ? '' : state.commentTargetPostId,
      clearCommentsLoading: closePanel,
    );
    return true;
  }

  bool _matchesSearch(CirclePost p) {
    final k = state.searchKeyword.trim();
    if (k.isEmpty) return true;
    return p.text.contains(k) ||
        p.author.name.contains(k) ||
        (p.author.role.isNotEmpty && p.author.role.contains(k));
  }

  CirclePost? _findPost(String postId) {
    for (final p in state.posts) {
      if (p.id == postId) return p;
    }
    return null;
  }

  List<CirclePost> _mapPosts(
    String postId,
    CirclePost Function(CirclePost) update,
  ) {
    return [
      for (final p in state.posts)
        if (p.id == postId) update(p) else p,
    ];
  }
}

/// 供 UI 读取当前登录用户，计算 [CirclePermissions]。
CirclePermissions circlePermissionsFromShell(WidgetRef ref) {
  final user = ref.watch(shellControllerProvider).user;
  return CirclePermissions(
    currentUserId: user.id,
    isAdmin: CirclePermissions.shellUserIsAdmin(
      role: user.role,
      identity: user.identity,
    ),
  );
}
