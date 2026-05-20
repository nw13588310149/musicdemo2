import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../../voice/ui/voice_page.dart';
import '../state/study_catalog_controller.dart';
import '../state/study_catalog_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class StudyCatalogPage extends ConsumerWidget {
  const StudyCatalogPage({super.key, required this.defaultArgs});

  final StudyCatalogPageArgs defaultArgs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = _parseArgs(ModalRoute.of(context)?.settings.arguments);
    final state = ref.watch(studyCatalogControllerProvider(args));
    final controller = ref.read(studyCatalogControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(16)),
      child: ColoredBox(
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: ui(180),
              child: _SidebarPanel(
                state: state,
                onSelectMenu: controller.selectMenu,
              ),
            ),
            Expanded(
              child: _ContentPanel(
                state: state,
                onSelectChild: controller.selectChild,
                onRefresh: controller.refreshLessons,
              ),
            ),
          ],
        ),
      ),
    );
  }

  StudyCatalogPageArgs _parseArgs(dynamic raw) {
    if (raw is StudyCatalogPageArgs) {
      return raw;
    }
    if (raw is Map) {
      return StudyCatalogPageArgs(
        config: defaultArgs.config,
        // 与 1.0 `!history.state.school` 语义一致：任何 truthy 值（true / 非零 id /
        // 非空字符串）都视为 school 模式，二级页走 schoolTextbookList 接口。
        schoolMode: _isTruthy(raw['schoolMode']) || _isTruthy(raw['school']),
        initialFirstMenuId:
            raw['firstMenu']?.toString() ?? defaultArgs.initialFirstMenuId,
        initialSecondMenuId:
            raw['secondMenu']?.toString() ?? defaultArgs.initialSecondMenuId,
      );
    }
    return defaultArgs;
  }
}

/// 仿 JS `!!value` 语义：null/false/0/空串视为假，其他视为真。
bool _isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower != '0' && lower != 'false';
  }
  return true;
}

class SightSingingPage extends StatelessWidget {
  const SightSingingPage({super.key});

  @override
  Widget build(BuildContext context) => const StudyCatalogPage(
    defaultArgs: StudyCatalogPageArgs(
      config: StudyCatalogConfig.sightSinging,
      initialFirstMenuId: '1',
    ),
  );
}

class MusicTheoryPage extends StatelessWidget {
  const MusicTheoryPage({super.key});

  @override
  Widget build(BuildContext context) => const StudyCatalogPage(
    defaultArgs: StudyCatalogPageArgs(
      config: StudyCatalogConfig.musicTheory,
      initialFirstMenuId: '5',
    ),
  );
}

class AnswerQuestionsPage extends StatelessWidget {
  const AnswerQuestionsPage({super.key});

  @override
  Widget build(BuildContext context) => const StudyCatalogPage(
    defaultArgs: StudyCatalogPageArgs(
      config: StudyCatalogConfig.answerQuestions,
      initialFirstMenuId: '63',
      initialSecondMenuId: '65',
    ),
  );
}

class InstrumentalPage extends StatelessWidget {
  const InstrumentalPage({super.key});

  @override
  Widget build(BuildContext context) => const VoicePage(
    defaultArgs: StudyCatalogPageArgs(
      config: StudyCatalogConfig.instrumental,
      initialFirstMenuId: '20',
    ),
  );
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({required this.state, required this.onSelectMenu});

  final StudyCatalogState state;
  final ValueChanged<String> onSelectMenu;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(ui(8), ui(20), ui(8), ui(8)),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: state.menus.length,
        separatorBuilder: (context, index) => SizedBox(height: ui(8)),
        itemBuilder: (context, index) {
          final menu = state.menus[index];
          final active = menu.id == state.selectedMenuId;
          return _SidebarTile(
            title: menu.name,
            active: active,
            onTap: () => onSelectMenu(menu.id),
          );
        },
      ),
    );
  }
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel({
    required this.state,
    required this.onSelectChild,
    required this.onRefresh,
  });

  final StudyCatalogState state;
  final ValueChanged<String?> onSelectChild;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasChildren =
        state.config.allowSecondMenu && state.selectedChildren.isNotEmpty;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasChildren)
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(4)),
              child: _ChildSegmented(
                items: state.selectedChildren,
                selectedId: state.selectedChildId,
                onSelect: onSelectChild,
              ),
            ),
          Expanded(
            child: state.loading && state.lessonGroups.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : state.lessonGroups.isEmpty
                ? _EmptyState(
                    message: state.errorMessage.isEmpty
                        ? '暂无课程'
                        : state.errorMessage,
                    onRefresh: onRefresh,
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(vertical: ui(12)),
                    child: AppRefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          ui(20),
                          hasChildren ? ui(4) : ui(12),
                          ui(20),
                          ui(16),
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: state.lessonGroups.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: ui(16)),
                        itemBuilder: (context, index) {
                          final group = state.lessonGroups[index];
                          return _LessonSection(
                            title: group.title,
                            lessons: group.lessons,
                            artworkLabel: state.config.artworkLabel,
                            // 把当前选中菜单名一路透传给封面，供根据 tab 动态展示
                            currentMenuName: state.selectedMenu?.name ?? '',
                            onOpenLesson: (lesson) {
                              final blockMessage = _blockingMessage(
                                state,
                                lesson,
                              );
                              if (blockMessage != null) {
                                AppToast.show(context, blockMessage);
                                return;
                              }
                              final route = _targetRoute(state);
                              final routeArgs =
                                  state.config.targetArgsBuilder?.call(
                                    state,
                                    lesson,
                                  ) ??
                                  <String, dynamic>{'id': lesson.id};
                              Navigator.pushNamed(
                                context,
                                route,
                                arguments: routeArgs,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _targetRoute(StudyCatalogState state) {
    if (state.config.key == StudyCatalogConfig.answerQuestions.key) {
      // 试题模块的子分类：
      //  - 听写 / 乐理（id=63 / 64）原本就走 answerEnd2 → MusicPlayPage；
      //  - 视唱按用户要求一并切到 answerEnd2 → MusicPlayPage（拥有 prev/next
      //    切题能力，并复用父页的题目列表，不再走 answerEnd → TheoryPage）。
      final menuName = state.selectedMenu?.name.trim() ?? '';
      final isSightSingingTab = menuName.contains('视唱');
      if (state.selectedMenuId == '63' ||
          state.selectedMenuId == '64' ||
          isSightSingingTab) {
        return RoutePaths.answerEnd2;
      }
      return RoutePaths.answerEnd;
    }
    return state.config.targetRoute;
  }

  String? _blockingMessage(StudyCatalogState state, StudyCatalogLesson lesson) {
    if (!lesson.vip) {
      return null;
    }
    final expire = state.vipExpireDate;
    if (expire == null) {
      return '您还未开通会员';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vipDay = DateTime(expire.year, expire.month, expire.day);
    if (vipDay.isBefore(today)) {
      return '您的会员已过期，请续费';
    }
    return null;
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = active ? ui(8) : ui(16);

    // 设计要求：左侧 Tab 不展示任何点击/悬停动效（无水波纹、无按压高亮、无 hover）
    // 因此用 GestureDetector + Container 直接接管点击，不走 Material InkWell
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: ui(60),
        padding: EdgeInsets.symmetric(horizontal: ui(14)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEEEAFF) : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          children: [
            SizedBox(
              width: ui(36),
              height: ui(36),
              child: Image.asset(
                active
                    ? AppAssets.homeDictationNavIcon
                    : AppAssets.homeCategoryIdleIcon,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: TextStyle(
                  fontSize: ui(13),
                  fontWeight: AppFont.w500,
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildSegmented extends StatelessWidget {
  const _ChildSegmented({
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<StudyCatalogMenuChild> items;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Container(
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: ui(8)),
                _ChildSegmentedItem(
                  label: items[i].name,
                  active: items[i].id == selectedId,
                  onTap: () => onSelect(items[i].id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildSegmentedItem extends StatelessWidget {
  const _ChildSegmentedItem({
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
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: active
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59B5B5B5),
                    blurRadius: 20,
                    offset: Offset(0, 0),
                  ),
                ],
              )
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: active ? 1.0 : 0.7,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: TextStyle(
              fontSize: ui(14),
              color: active ? const Color(0xFF0B081A) : const Color(0xFF6D6B75),
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonSection extends StatelessWidget {
  const _LessonSection({
    required this.title,
    required this.lessons,
    required this.artworkLabel,
    required this.currentMenuName,
    required this.onOpenLesson,
  });

  final String title;
  final List<StudyCatalogLesson> lessons;
  final StudyCatalogArtworkLabel artworkLabel;

  /// 当前选中的菜单名（如 "升号视唱" / "章节讲义" / "听写试题"），
  /// 透传到封面用于根据 tab 切换显示文字。
  final String currentMenuName;
  final ValueChanged<StudyCatalogLesson> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(left: ui(2), bottom: ui(10)),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(14),
                fontWeight: AppFont.w600,
                color: const Color(0xFF171A20),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lessons.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: ui(260),
            mainAxisExtent: ui(100),
            crossAxisSpacing: ui(16),
            mainAxisSpacing: ui(16),
          ),
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return _LessonCard(
              lesson: lesson,
              artworkLabel: artworkLabel,
              currentMenuName: currentMenuName,
              onTap: () => onOpenLesson(lesson),
            );
          },
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.artworkLabel,
    required this.currentMenuName,
    required this.onTap,
  });

  final StudyCatalogLesson lesson;
  final StudyCatalogArtworkLabel artworkLabel;

  /// 当前选中的菜单名，用于副标题与封面文案的 fallback。
  final String currentMenuName;
  final VoidCallback onTap;

  /// 副标题文案：
  ///   1) 优先使用接口返回的 lesson.subtitle
  ///   2) 没有时退回到当前菜单名，避免不论选哪个 tab 都显示"标准课程内容"
  ///   3) 完全没有信息时显示空字符串（不渲染该行）
  String get _subtitle {
    if (lesson.subtitle.isNotEmpty) return lesson.subtitle;
    return currentMenuName;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final subtitle = _subtitle;

    return Container(
      padding: EdgeInsets.all(ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LessonArtwork(
            label: artworkLabel,
            title: lesson.title,
            currentMenuName: currentMenuName,
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: SizedBox(
              height: ui(80),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(13),
                            fontWeight: AppFont.w500,
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                            height: 1.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          SizedBox(height: ui(6)),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(11),
                              color: const Color(0xFFB6B5BB),
                              fontFamily: 'PingFang SC',
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: ui(65),
                        height: ui(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF292151),
                          borderRadius: BorderRadius.circular(ui(8)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '去学习',
                          style: TextStyle(
                            fontSize: ui(11),
                            color: Colors.white,
                            fontWeight: AppFont.w500,
                            fontFamily: 'PingFang SC',
                            height: 12 / 11,
                          ),
                        ),
                      ),
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
}

class _LessonArtwork extends StatelessWidget {
  const _LessonArtwork({
    required this.label,
    required this.title,
    required this.currentMenuName,
  });

  final StudyCatalogArtworkLabel label;
  final String title;

  /// 当前选中菜单名（如 "升号视唱"、"章节讲义"）。
  /// 当 lesson.title 不包含可识别关键词时，退回到 menu 名做匹配，
  /// 让封面文字与左侧选中的 tab 同步（不再固定显示某一类）。
  final String currentMenuName;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        width: ui(60),
        height: ui(80),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeDictationBookCover,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: ui(10),
              child: Text(
                _coverText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(12),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB16AFF),
                  fontFamily: 'Alimama ShuHeiTi',
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 封面最终展示文案。
  /// - 大多数学科采用"头部\n下半行"两行排版（如 "听写\n音组"、"视唱\n基础"）；
  /// - 乐理特殊：下半行本身已是完整词组（章节讲义 / 专项练习 / 音乐常识），
  ///   不再叠加"乐理"前缀；为了与其他封面保持两行视觉，再按"前半\n后半"等长拆分
  ///   （4 字 → 2+2，例如 "章节\n讲义"）。
  /// - 试题特殊：设计稿要求文案是"听写试题 / 视唱试题 / 乐理试题"——下半行是
  ///   学科（听写/视唱/乐理），上半行才是"试题"。这里把头尾倒置一下，其余学科
  ///   仍走"head\nbody"。
  String _coverText() {
    final head = _headLabel();
    final body = _artLabel();
    if (head.isEmpty) {
      return _splitToTwoLines(body);
    }
    if (label == StudyCatalogArtworkLabel.answer) {
      return '$body\n$head';
    }
    return '$head\n$body';
  }

  /// 把单行词组按字数等分为两行，让封面整体仍呈现两行排版。
  /// 偶数字数：均分；奇数字数：上行少一字，下行多一字（视觉更稳）。
  static String _splitToTwoLines(String text) {
    if (text.length < 2) return text;
    final mid = text.length ~/ 2;
    return '${text.substring(0, mid)}\n${text.substring(mid)}';
  }

  String _headLabel() {
    switch (label) {
      case StudyCatalogArtworkLabel.dictation:
        return '听写';
      case StudyCatalogArtworkLabel.sightSinging:
        return '视唱';
      case StudyCatalogArtworkLabel.musicTheory:
        return '';
      case StudyCatalogArtworkLabel.answer:
        return '试题';
      case StudyCatalogArtworkLabel.voice:
        return '声乐';
      case StudyCatalogArtworkLabel.instrumental:
        return '器乐';
    }
  }

  /// 各学科封面下半行文字。
  /// 匹配优先级：lesson.title → currentMenuName → 学科默认兜底。
  String _artLabel() {
    final keywords = _keywordsFor(label);
    for (final source in <String>[title, currentMenuName]) {
      if (source.isEmpty) continue;
      for (final kw in keywords) {
        if (source.contains(kw)) return kw;
      }
    }
    return _fallbackFor(label);
  }

  /// 各学科关键词集合（顺序即匹配优先级，先具体后通用）。
  static List<String> _keywordsFor(StudyCatalogArtworkLabel label) {
    switch (label) {
      case StudyCatalogArtworkLabel.dictation:
        return const ['音组', '音程', '和弦', '节奏', '旋律', '调式', '乐句', '单音'];
      case StudyCatalogArtworkLabel.sightSinging:
        // "视唱基础 / 视唱无调 / 视唱升号 / 视唱降号"
        return const ['基础', '无调', '升号', '降号'];
      case StudyCatalogArtworkLabel.musicTheory:
        // "乐理\n章节讲义 / 专项练习 / 音乐常识"
        return const ['章节讲义', '专项练习', '音乐常识', '章节讲义', '专项练习', '音乐常识'];
      case StudyCatalogArtworkLabel.answer:
        // 封面文案 "听写试题 / 视唱试题 / 乐理试题"——下半行学科匹配关键词。
        return const ['听写', '视唱', '乐理'];
      case StudyCatalogArtworkLabel.voice:
      case StudyCatalogArtworkLabel.instrumental:
        return const ['音组', '音程', '和弦', '节奏', '旋律', '调式', '乐句', '单音'];
    }
  }

  /// 没有匹配到任何关键词时的兜底（极端兜底，正常不会走到）。
  static String _fallbackFor(StudyCatalogArtworkLabel label) {
    switch (label) {
      case StudyCatalogArtworkLabel.dictation:
        return '单音';
      case StudyCatalogArtworkLabel.sightSinging:
        return '基础';
      case StudyCatalogArtworkLabel.musicTheory:
        return '讲义';
      case StudyCatalogArtworkLabel.answer:
        return '听写';
      case StudyCatalogArtworkLabel.voice:
      case StudyCatalogArtworkLabel.instrumental:
        return '单音';
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: ui(48),
            color: const Color(0xFFC5C7D0),
          ),
          SizedBox(height: ui(12)),
          Text(
            message,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF8E90A0),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          OutlinedButton(
            onPressed: () => onRefresh(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF292151),
              side: const BorderSide(color: Color(0xFFE0E3F0)),
            ),
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}
