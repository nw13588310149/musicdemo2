import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../../study_catalog/state/study_catalog_controller.dart';
import '../../study_catalog/state/study_catalog_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 声乐二级页：脱离 StudyCatalogPage 共享模板，独立按设计稿还原。
/// 数据仍复用 [studyCatalogControllerProvider]（config = voice），保证接口零回归。
class VoicePage extends ConsumerStatefulWidget {
  const VoicePage({
    super.key,
    this.defaultArgs = const StudyCatalogPageArgs(
      config: StudyCatalogConfig.voice,
      initialFirstMenuId: '16',
    ),
  });

  final StudyCatalogPageArgs defaultArgs;

  @override
  ConsumerState<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends ConsumerState<VoicePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = _parseArgs(ModalRoute.of(context)?.settings.arguments);
    final state = ref.watch(studyCatalogControllerProvider(args));
    final controller = ref.read(studyCatalogControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    final filteredLessons = _filterLessons(state.flatLessons, _query);

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(16)),
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VoiceHeader(
              menus: state.menus,
              selectedId: state.selectedMenuId,
              onSelect: (id) {
                if (id == state.selectedMenuId) return;
                _resetSearch();
                controller.selectMenu(id);
              },
              searchController: _searchController,
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onClearQuery: _resetSearch,
            ),
            Expanded(
              child: _VoiceBody(
                loading: state.loading,
                hasAnyLessons: state.flatLessons.isNotEmpty,
                lessons: filteredLessons,
                query: _query,
                errorMessage: state.errorMessage,
                onOpenLesson: (lesson) => _openLesson(state, lesson),
                onRefresh: controller.refreshLessons,
                // 同一个 widget 同时承载「声乐」与「器乐」两个二级页：
                // [InstrumentalPage] 内部就是 const VoicePage(config: instrumental)。
                // 因此卡片封面要按 config.key 分流：
                //   voice        → fm.png  「VOCAL MUSIC / 声乐」
                //   instrumental → fm2.png 「INSTRUMENTAL MUSIC / 器乐」
                // 其它 key 不会经过此页面，留 fm.png 兜底，避免未来加新 config
                // 时漏改导致空白。
                coverAsset: state.config.key == 'instrumental'
                    ? AppAssets.homeFm2Cover
                    : AppAssets.homeFmCover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  StudyCatalogPageArgs _parseArgs(dynamic raw) {
    final defaultArgs = widget.defaultArgs;
    if (raw is StudyCatalogPageArgs) {
      return raw;
    }
    if (raw is Map) {
      return StudyCatalogPageArgs(
        config: defaultArgs.config,
        schoolMode: _isTruthy(raw['schoolMode']) || _isTruthy(raw['school']),
        initialFirstMenuId:
            raw['firstMenu']?.toString() ?? defaultArgs.initialFirstMenuId,
        initialSecondMenuId:
            raw['secondMenu']?.toString() ?? defaultArgs.initialSecondMenuId,
      );
    }
    return defaultArgs;
  }

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty &&
          normalized != 'false' &&
          normalized != '0' &&
          normalized != 'null';
    }
    return true;
  }

  void _resetSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    if (_query.isNotEmpty) {
      setState(() => _query = '');
    }
  }

  List<StudyCatalogLesson> _filterLessons(
    List<StudyCatalogLesson> lessons,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return lessons;
    return lessons
        .where(
          (lesson) =>
              lesson.title.toLowerCase().contains(query) ||
              lesson.subtitle.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _openLesson(StudyCatalogState state, StudyCatalogLesson lesson) {
    final blockMessage = _blockingMessage(state, lesson);
    if (blockMessage != null) {
      AppToast.show(context, blockMessage);
      return;
    }
    final routeArgs =
        state.config.targetArgsBuilder?.call(state, lesson) ??
        <String, dynamic>{'id': lesson.id};
    Navigator.pushNamed(
      context,
      state.config.targetRoute,
      arguments: routeArgs,
    );
  }

  String? _blockingMessage(StudyCatalogState state, StudyCatalogLesson lesson) {
    if (!lesson.vip) return null;
    final expire = state.vipExpireDate;
    if (expire == null) return '您还未开通会员';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vipDay = DateTime(expire.year, expire.month, expire.day);
    if (vipDay.isBefore(today)) return '您的会员已过期，请续费';
    return null;
  }
}

/// 顶部 tab 区域（左：分类切换；右：搜索框）。
class _VoiceHeader extends StatelessWidget {
  const _VoiceHeader({
    required this.menus,
    required this.selectedId,
    required this.onSelect,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onClearQuery,
  });

  final List<StudyCatalogMenu> menus;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Container(
      height: ui(72),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < menus.length; i++) ...[
                    // 严格设定间距为 32
                    if (i > 0) SizedBox(width: ui(32)),
                    _VoiceTabItem(
                      label: menus[i].name,
                      active: menus[i].id == selectedId,
                      isFirst: i == 0,
                      onTap: () => onSelect(menus[i].id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: ui(16)),
          _VoiceSearchPill(
            controller: searchController,
            hasQuery: query.isNotEmpty,
            onChanged: onQueryChanged,
            onClear: onClearQuery,
          ),
        ],
      ),
    );
  }
}

/// Tab 区域：底层使用 14 号字撑开布局防推挤，顶层使用 OverflowBox 实现溢出放大。
class _VoiceTabItem extends StatelessWidget {
  const _VoiceTabItem({
    required this.label,
    required this.active,
    required this.isFirst,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    // 决定溢出放大的方向：第一个向右放大（靠左对齐），其他的向两侧均等放大（居中对齐）
    final alignment = isFirst ? Alignment.centerLeft : Alignment.center;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // 只保留上下 padding 提供足够大的点击热区，左右完全归零，由 SizedBox 控制
        padding: EdgeInsets.symmetric(vertical: ui(10)),
        child: Stack(
          alignment: alignment,
          clipBehavior: Clip.none, // 允许选中时的 18号大字溢出底层盒子
          children: [
            // 【底层盒子】：永远使用 14 号字（透明）撑开布局。
            // 这确保了 Row 计算宽度时只看 14 号字的宽度，后续永远不会被推挤。
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PingFang SC',
                fontSize: ui(14),
                fontWeight: AppFont.w500,
                height: 1.2,
                color: Colors.transparent,
              ),
            ),
            // 【表层文字】：实际显示的文字。
            // OverflowBox 允许子组件尺寸大于父组件（即大于 14 号字盒子）而不改变布局大小。
            Positioned.fill(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: alignment,
                child: Opacity(
                  opacity: active ? 1 : 0.7,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: active ? ui(18) : ui(14),
                      fontWeight: AppFont.w500,
                      height: 1.2,
                      color: const Color(0xFF0B081A),
                    ),
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

class _VoiceSearchPill extends StatelessWidget {
  const _VoiceSearchPill({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fontSize = ui(14);
    final iconSize = ui(15);
    // 与 courseware「我的云盘」搜索框写法保持一致：
    // - 外层 SizedBox 提供胶囊高度（这里 30）；
    // - TextField 用 prefixIcon + prefixIconConstraints(minWidth) 占位图标；
    // - contentPadding 置零、不开 isDense / isCollapsed，让 Material 自带的
    //   `textAlignVertical=center` 接管文字垂直居中。
    //
    // 之前用 Row + forceStrutHeight 自己控制居中，会在 iOS（PingFang OTF 行高
    // metrics 与 Skia 计算的 strut top padding 不一致）下把文字推向顶部，
    // 表现为「视觉略偏上」。让 InputDecorator 自己计算居中后，iOS / iPadOS /
    // Android 表现一致。

    return SizedBox(
      width: ui(254),
      height: ui(30),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: 1,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(15),
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: fontSize,
          fontWeight: AppFont.w400,
          color: const Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: '传统音乐',
          hintStyle: TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: fontSize,
            fontWeight: AppFont.w400,
            color: const Color(0xFFD1D1D1),
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: ui(12), right: ui(6)),
            child: Image.asset(
              AppAssets.homeSearchIcon,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: ui(33)),
          suffixIcon: hasQuery
              ? GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(right: ui(10)),
                    child: Icon(
                      Icons.cancel,
                      size: iconSize,
                      color: const Color(0xFFC6C6C6),
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: BoxConstraints(minWidth: ui(28)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFE3E3E3),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }
}

/// 网格区域：5 列卡片，根据本地过滤后的 lessons 渲染。
class _VoiceBody extends StatelessWidget {
  const _VoiceBody({
    required this.loading,
    required this.hasAnyLessons,
    required this.lessons,
    required this.query,
    required this.errorMessage,
    required this.onOpenLesson,
    required this.onRefresh,
    required this.coverAsset,
  });

  final bool loading;
  final bool hasAnyLessons;
  final List<StudyCatalogLesson> lessons;
  final String query;
  final String errorMessage;
  final ValueChanged<StudyCatalogLesson> onOpenLesson;
  final Future<void> Function() onRefresh;
  /// 卡片封面图（声乐用 fm.png / 器乐用 fm2.png），由顶层按 config 决定。
  final String coverAsset;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    if (loading && !hasAnyLessons) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (!hasAnyLessons) {
      return _VoiceListEmptyPlaceholder(
        message: errorMessage.isEmpty ? '暂无课程' : errorMessage,
      );
    }
    if (lessons.isEmpty) {
      return _VoiceListEmptyPlaceholder(message: '没有匹配 “${query.trim()}” 的作品');
    }

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(ui(21), ui(0), ui(21), ui(20)),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 173 / 182,
          crossAxisSpacing: ui(16),
          mainAxisSpacing: ui(14),
        ),
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          return _VoiceSongCard(
            lesson: lesson,
            coverAsset: coverAsset,
            onTap: () => onOpenLesson(lesson),
          );
        },
      ),
    );
  }
}

/// 单首作品卡片：封面 + 标题 + 调号占位（设计稿尺寸 173×182）。
class _VoiceSongCard extends StatelessWidget {
  const _VoiceSongCard({
    required this.lesson,
    required this.onTap,
    required this.coverAsset,
  });

  final StudyCatalogLesson lesson;
  final VoidCallback onTap;
  /// 由 [_VoiceBody] 透传：声乐列表 = fm.png；器乐列表 = fm2.png。
  final String coverAsset;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final subtitle = lesson.subtitle.isEmpty ? '1=bA' : lesson.subtitle;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.all(ui(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ui(8)),
                child: Image.asset(
                  coverAsset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              lesson.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PingFang SC',
                fontSize: ui(14),
                fontWeight: AppFont.w500,
                color: const Color(0xFF0B081A),
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(7)),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PingFang SC',
                fontSize: ui(12),
                fontWeight: AppFont.w400,
                color: const Color(0xFFB6B5BB),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表为空占位：163×163 插图 + 居中文案（Inter 16 / 400 / black），无按钮。
class _VoiceListEmptyPlaceholder extends StatelessWidget {
  const _VoiceListEmptyPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.emptyCoursePlaceholder,
            width: ui(163),
            height: ui(163),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(4)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: ui(16),
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.25,
              fontVariations: const [FontVariation('wght', 400)],
            ),
          ),
        ],
      ),
    );
  }
}
