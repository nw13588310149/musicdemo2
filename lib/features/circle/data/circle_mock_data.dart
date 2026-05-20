import '../state/circle_state.dart';

/// 校圈页面的模拟数据。后端尚未提供接口，列表内容、头像、配图均使用稳定的 placeholder
/// 占位（来自 picsum.photos 与 i.pravatar.cc，受网络环境影响时由 errorBuilder 兜底）。
abstract final class CircleMockData {
  static const _avatarBase = 'https://i.pravatar.cc/120?img=';
  static const _imageBase = 'https://picsum.photos/seed/';

  static List<CirclePost> buildPosts() {
    final author1 = const CircleAuthor(
      id: 'u_xueshenghui',
      name: '校学生会',
      role: '校艺术部',
      avatarUrl: '${_avatarBase}12',
    );
    final author2 = const CircleAuthor(
      id: 'u_fuxuanyun',
      name: '傅轩云',
      role: '校艺术部',
      avatarUrl: '${_avatarBase}5',
    );
    final author3 = const CircleAuthor(
      id: 'u_linqiang',
      name: '林强',
      role: '校艺术部',
      avatarUrl: '${_avatarBase}33',
    );
    final author4 = const CircleAuthor(
      id: 'u_hejun',
      name: '何俊',
      role: '校艺术部',
      avatarUrl: '${_avatarBase}68',
    );
    final author5 = const CircleAuthor(
      id: 'u_lijiangzhi',
      name: '李江志',
      role: '校艺术部',
      avatarUrl: '${_avatarBase}21',
    );
    final author6 = const CircleAuthor(
      id: 'u_xuwei',
      name: '许伟',
      role: '校艺术部',
      avatarUrl: '${_avatarBase}45',
    );

    const longText =
        '校园艺术节节目征集正式开启!声乐(独唱/合唱)、器乐、舞蹈、音乐剧选段均可报名。'
        '初赛提交视频截止本周五18:00，决赛暨汇报演出定于下月艺术楼剧场。'
        '报名方式:各班文艺委员汇总后统一提交报名表。';
    const shortText = '校园艺术节节目征集正式开启!声乐(独唱）';

    final commentSeed = <CircleComment>[
      CircleComment(
        id: 'c1',
        author: author2,
        text: '准时报名！我们班合唱团已经在排练《同一首歌》。',
        timeLabel: '5 分钟前',
        likeCount: 132,
      ),
      CircleComment(
        id: 'c2',
        author: author3,
        text: '老师，器乐组可以提交两首作品作为初赛吗？',
        timeLabel: '12 分钟前',
        likeCount: 87,
        liked: true,
      ),
      CircleComment(
        id: 'c3',
        author: author5,
        text: '舞蹈队期待挑战，决赛见！',
        timeLabel: '半小时前',
        likeCount: 64,
      ),
      CircleComment(
        id: 'c4',
        author: author4,
        text: '剧本类作品需要伴奏带吗？提交格式麻烦同步一下～',
        timeLabel: '1 小时前',
        likeCount: 41,
      ),
      CircleComment(
        id: 'c5',
        author: author6,
        text: '我能上一台钢琴独奏！现在开始练 Liszt。',
        timeLabel: '2 小时前',
        likeCount: 22,
      ),
    ];

    return <CirclePost>[
      CirclePost(
        id: 'p1',
        author: author1,
        badges: const [CircleBadge.pinned, CircleBadge.hot],
        text: longText,
        timeLabel: '今天 10:20',
        imageUrl: '${_imageBase}circle1/1280/720',
        imageAspectRatio: 16 / 9,
        likeCount: 123000,
        commentCount: 12300,
        favoriteCount: 12300,
        liked: false,
        favorited: false,
        comments: commentSeed,
      ),
      CirclePost(
        id: 'p2',
        author: author2,
        badges: const [CircleBadge.hot],
        text: longText,
        timeLabel: '今天 10:20',
        imageUrl: '${_imageBase}circle2/1280/720',
        imageAspectRatio: 16 / 9,
        likeCount: 123000,
        commentCount: 12300,
        favoriteCount: 12300,
        liked: false,
        favorited: false,
        comments: commentSeed,
      ),
      CirclePost(
        id: 'p3',
        author: author3,
        badges: const [CircleBadge.hot],
        text: shortText,
        timeLabel: '今天 10:20',
        imageUrl: '${_imageBase}circle3/1280/720',
        imageAspectRatio: 16 / 9,
        likeCount: 12300,
        commentCount: 12300,
        favoriteCount: 12300,
        liked: false,
        favorited: false,
        comments: commentSeed,
      ),
      CirclePost(
        id: 'p4',
        author: author4,
        badges: const [CircleBadge.hot],
        text: longText,
        timeLabel: '今天 10:20',
        imageUrl: '${_imageBase}circle4/1080/1440',
        imageAspectRatio: 1 / 1,
        likeCount: 89000,
        commentCount: 4200,
        favoriteCount: 7600,
        liked: true,
        favorited: false,
        comments: commentSeed,
      ),
      CirclePost(
        id: 'p5',
        author: author5,
        badges: const [CircleBadge.hot],
        text: shortText,
        timeLabel: '今天 10:20',
        imageUrl: '${_imageBase}circle5/1280/720',
        imageAspectRatio: 16 / 9,
        likeCount: 32000,
        commentCount: 1280,
        favoriteCount: 5400,
        liked: false,
        favorited: true,
        comments: commentSeed,
      ),
      CirclePost(
        id: 'p6',
        author: author6,
        badges: const [CircleBadge.hot],
        text: shortText,
        timeLabel: '今天 10:20',
        imageUrl: '${_imageBase}circle6/1280/720',
        imageAspectRatio: 16 / 9,
        likeCount: 22000,
        commentCount: 980,
        favoriteCount: 3000,
        liked: false,
        favorited: false,
        comments: commentSeed,
      ),
    ];
  }
}
