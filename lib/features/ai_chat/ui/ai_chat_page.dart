import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/action_menu.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../theory/ui/widgets/theory_pdf_view.dart';
import '../data/ai_chat_attachment_picker.dart';
import '../state/ai_chat_controller.dart';
import '../state/ai_chat_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const _border = Color(0xFFF3F2F3);
const _panelFill = Color(0xFFF4F4FF);
const _textPrimary = Color(0xFF0B081A);
const _textSecondary = Color(0xFF707790);
const _textHint = Color(0xFFB6B5BB);
const _purple = Color(0xFF8741FF);
const _purpleSoft = Color(0x0D8741FF);

const _historyPaneWidth = 230.0;
const _mainHorizontalPadding = 64.0;
const _mainBottomPadding = 12.0;

// Figma 题项编号配色：1/2 红 #EB2F2F；3 橙 #FE7B3F；4/5/6 浅灰 #CECED1
// 注意：4/5/6 用的是 #CECED1（更淡），不是 #B6B5BB（_textHint），肉眼能看出差别。
const Color _theoryRankDim = Color(0xFFCECED1);

const _theoryPrompts = <_AiPromptQuestion>[
  _AiPromptQuestion('1', '大小调怎么快速区分？', Color(0xFFEB2F2F)),
  _AiPromptQuestion('2', '增四度和减五度为什么是三全音？', Color(0xFFEB2F2F)),
  _AiPromptQuestion('3', '属七为什么必须解决？', Color(0xFFFE7B3F)),
  _AiPromptQuestion('4', '4/4 和 6/8 区别在哪？', _theoryRankDim),
  _AiPromptQuestion('5', '同主音大小调区别？', _theoryRankDim),
  _AiPromptQuestion('6', '常用音乐术语（中英对照）', _theoryRankDim),
];

const _toolShortcuts = <_AiToolShortcut>[
  _AiToolShortcut(
    title: '分析乐谱',
    subtitle: 'AI 智能解析乐谱数据',
    prompt: '请帮我分析这份乐谱的结构、难点和练习重点。',
    asset: AppAssets.aiChatV2ToolAnalyze,
  ),
  _AiToolShortcut(
    title: '提供练习建议',
    subtitle: 'AI 科学规划练习内容',
    prompt: '请根据音乐艺考训练场景，帮我制定一份更高效的练习建议。',
    asset: AppAssets.aiChatV2ToolSuggest,
  ),
  _AiToolShortcut(
    title: '制定考试计划',
    subtitle: 'AI 定制备考方案',
    prompt: '请帮我制定一份音乐艺考备考计划，分阶段说明每日练习重点。',
  ),
];

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _messageSignature = '';

  /// 「贴底滚动」级联里下一帧的 timer。每次新触发滚动时先 cancel 上一个，
  /// 避免短时间内多次 selectSession / 流式推送堆叠出几十个 jumpTo —— 这会
  /// 在用户尝试滑动时把他的拖拽 activity 反复打断（表现为「需要划两次」）。
  Timer? _bottomScrollTimer;

  /// 用户手指当前是否压在消息列表上。压着的时候我们绝对不再触发任何
  /// `jumpTo` / `animateTo`，否则会把用户的 DragScrollActivity 替换成
  /// DrivenScrollActivity，第一次滑动直接被吃掉。
  bool _userTouchingList = false;

  /// 每个会话条目「⋯」按钮的 GlobalKey，用于把删除悬浮菜单
  /// （[showItemActionMenu]）锚定到正确的位置。按 sessionId 缓存一次创建，
  /// 这样同一个会话切换 active 状态后菜单仍能找到旧 RenderBox。
  /// 不做主动清理：用户一辈子的会话数量有限，几个 GlobalKey 的成本可以忽略。
  final Map<String, GlobalKey> _moreTriggerKeys = <String, GlobalKey>{};

  GlobalKey _moreTriggerKeyFor(String sessionId) =>
      _moreTriggerKeys.putIfAbsent(sessionId, GlobalKey.new);

  @override
  void dispose() {
    _bottomScrollTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatControllerProvider);
    final controller = ref.read(aiChatControllerProvider.notifier);
    _scheduleScrollIfNeeded(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
        color: state.isNewConversation ? null : Colors.white,
        // Figma: linear-gradient(180deg, #EFEEFD 0%, white 34%, white 100%)
        gradient: state.isNewConversation
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEFEEFD), Colors.white, Colors.white],
                stops: [0, 0.34, 1],
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            SizedBox(
              width: _historyPaneWidth,
              child: _buildHistoryPane(state, controller),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mainWidth =
                      constraints.maxWidth - _mainHorizontalPadding * 2;
                  final composerWidth = mainWidth > 0
                      ? mainWidth
                      : constraints.maxWidth;
                  final userBubbleWidth = (mainWidth * 0.62)
                      .clamp(220.0, 420.0)
                      .toDouble();
                  // AI 回复气泡占满对话主列宽度（最小 320 兜底）。
                  final aiBubbleWidth = mainWidth > 320 ? mainWidth : 320.0;

                  if (state.isNewConversation) {
                    return _buildLanding(
                      state: state,
                      controller: controller,
                      composerWidth: composerWidth,
                    );
                  }
                  return _buildConversation(
                    state: state,
                    controller: controller,
                    composerWidth: composerWidth,
                    userBubbleMaxWidth: userBubbleWidth,
                    aiBubbleMaxWidth: aiBubbleWidth,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPane(AiChatState state, AiChatController controller) {
    final groups = groupSessionsByTime(state.sessions);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // 取消左侧栏所有点击效果：用 GestureDetector + Container 替代
            // Material + InkWell，避免水波纹/高亮覆盖按钮原有视觉。
            child: GestureDetector(
              onTap: () {
                controller.startNewChat();
                _inputCtrl.clear();
                setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 199,
                height: 36,
                decoration: BoxDecoration(
                  color: _panelFill,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAssetGraphic(
                        AppAssets.aiChatV2NewChatPlus,
                        width: 16,
                        height: 16,
                      ),
                      SizedBox(width: 8),
                      // Figma: 14/500 / line-height 20 / #8741FF
                      Text(
                        '开启新对话',
                        style: TextStyle(
                          color: _purple,
                          fontSize: 14,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Figma: 开启新对话(36 高, top 24.74) → "全部"(top 76.74) = 16px gap
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Figma: 14/500 / line-height 20 / #0B081A
                Text(
                  '全部',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 14,
                  ),
                ),
                Spacer(),
                AppAssetGraphic(
                  AppAssets.aiChatV2HistoryFilter,
                  width: 16,
                  height: 16,
                ),
              ],
            ),
          ),
          // Figma: "全部" 文字底(96.74) → "历史对话" group 顶(184.74) ≈ 88px。
          // 这里实际上 88 ≈ 16(gap) + 72(顶部空) 或者拆分。当前显示就保持 16，
          // 后续历史对话 label 与列表内部的间距由 ListView 内部 SizedBox 决定。
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: state.sessionsLoading && state.sessions.isEmpty
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Figma: 历史对话 label  12/500 / line-height 18 / #B6B5BB
                        Text(
                          '历史对话',
                          style: TextStyle(
                            color: _textHint,
                            fontSize: 12,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 18 / 12,
                          ),
                        ),
                        // Figma: label → 第一个 tile gap = 6
                        const SizedBox(height: 6),
                        if (state.isNewConversation) ...[
                          _historyTile(
                            title: '新对话',
                            active: true,
                            showMore: true,
                            onTap: () {
                              controller.startNewChat();
                              _inputCtrl.clear();
                              setState(() {});
                            },
                          ),
                          // Figma: tile 之间 gap ≈ 2（sub-group 内紧排）
                          const SizedBox(height: 2),
                        ],
                        for (final group in groups)
                          if (group.items.isNotEmpty) ...[
                            // Figma: 上一组结束 → 下一组 group label gap = 6
                            const SizedBox(height: 6),
                            Padding(
                              // Figma: group label 在 group 内 left:12（相对 group 的 left:0）
                              padding: const EdgeInsets.only(left: 12),
                              // Figma: 12/500 / line-height 18 / #CECED1
                              child: Text(
                                group.label,
                                style: TextStyle(
                                  color: Color(0xFFCECED1),
                                  fontSize: 12,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w500,
                                  height: 18 / 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (var i = 0; i < group.items.length; i++) ...[
                              if (i > 0) const SizedBox(height: 2),
                              _historyTile(
                                title: group.items[i].title,
                                active:
                                    !state.isNewConversation &&
                                    state.activeSessionId == group.items[i].id,
                                showMore:
                                    !state.isNewConversation &&
                                    state.activeSessionId == group.items[i].id,
                                onTap: () async {
                                  final error = await controller.selectSession(
                                    group.items[i].id,
                                  );
                                  if (error != null && mounted) {
                                    _showInfo(error);
                                  }
                                },
                                moreTriggerKey: _moreTriggerKeyFor(
                                  group.items[i].id,
                                ),
                                onMoreTap: () => _showSessionMoreMenu(
                                  controller,
                                  group.items[i],
                                ),
                              ),
                            ],
                          ],
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile({
    required String title,
    required bool active,
    required VoidCallback onTap,
    bool showMore = false,
    VoidCallback? onMoreTap,
    GlobalKey? moreTriggerKey,
  }) {
    // 历史会话条目同样去掉点击水波纹/高亮：
    // 用 GestureDetector + Container 替代 Material + InkWell。
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 198,
        height: 40,
        decoration: BoxDecoration(
          color: active ? _panelFill : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                // Figma: 14/400 / line-height 20 / #0B081A
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 14,
                  ),
                ),
              ),
              if (showMore)
                GestureDetector(
                  // GlobalKey 必须挂在「实际可命中」的那个 GestureDetector
                  // 上，因为 showItemActionMenu 通过 currentContext.findRenderObject()
                  // 拿位置来锚定悬浮菜单。
                  key: moreTriggerKey,
                  onTap: onMoreTap,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: AppAssetGraphic(
                      AppAssets.aiChatV2HistoryMore,
                      width: 13.3,
                      height: 3.1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanding({
    required AiChatState state,
    required AiChatController controller,
    required double composerWidth,
  }) {
    // 严格对齐 Figma（content 区高 730，相对坐标）：
    //   top  94      LOGO 顶
    //   +    76      welcome row（LOGO 52 / 副标题 2 行 22*2 + 标题 28 + gap 4 = 76）
    //   +    11      welcome → cards
    //   +   265      cards 区
    //   +   110      cards → composer（Figma 实测，硬编码精准还原）
    //   +   104      composer
    //   +    13      composer → disclaimer
    //   +    16      disclaimer line-height
    //   +    41      bottom padding
    //   = 730       ✓
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _mainHorizontalPadding,
        94,
        _mainHorizontalPadding,
        41,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 11),
          SizedBox(
            height: 265,
            child: Row(
              children: [
                Expanded(child: _buildTheoryCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildToolCard()),
              ],
            ),
          ),
          // Figma: cards 底(content 446) → composer 顶(content 556) = 110
          const SizedBox(height: 110),
          _buildComposer(state, controller, composerWidth),
          const SizedBox(height: 13),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  // Welcome 头像视觉调节：
  // - logoSlot：布局占位尺寸，严格等于 Figma 的 52，保证周围排版不受影响。
  // - logoVisualSize：图片实际渲染尺寸。icon.png 自带阴影留白，
  //   主体在图内只占 ~60-75%，按 52 渲染时视觉 LOGO 偏小。
  //   把它放大到 logoVisualSize，靠 OverflowBox 让多出来的部分
  //   在 4 个方向均匀溢出而不撑大 Row 的布局空间。
  // - logoVerticalNudge：图片自带的阴影并非上下对称（阴影偏下方），
  //   居中渲染会让 LOGO 主体视觉偏上；用 Transform.translate 把图片单独
  //   下移指定像素，仅改变绘制位置，不影响布局占位。
  // 调整顺序：先调 _logoVisualSize 让 LOGO 大小满意，再调 _logoVerticalNudge
  // 让 LOGO 视觉中心对齐文字基线。
  static const double _logoSlot = 52;
  static const double _logoVisualSize = 90;
  static const double _logoVerticalNudge = 0;

  Widget _buildWelcomeSection() {
    // Figma: 整个 welcome row 高度 76（设计稿副标题 2 行 → 76）。
    // 由于副标题被强制单行（用户偏好），文字组实际只有 54 高；
    // 用 SizedBox 把 row 锁死到 76，副标题贴顶部显示、下方自然留 22 空隙，
    // 保证 cards 顶部位置仍然严格落在 Figma 设计的 content top:181。
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 布局占位 52×52（与 Figma 一致），但允许图片实际渲染尺寸大于占位、
          // 让 PNG 自带的阴影留白被"溢出"到布局之外，从而把 LOGO 主体视觉补回到 52；
          // 再用 Transform.translate 单独把图片下移 _logoVerticalNudge 像素，
          // 抵消 PNG 阴影偏下导致的视觉上移，但不影响 Row 的布局占位。
          SizedBox(
            width: _logoSlot,
            height: _logoSlot,
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: const Offset(0, _logoVerticalNudge),
                child: Image.asset(
                  AppAssets.aiChatXiaoYiIcon,
                  width: _logoVisualSize,
                  height: _logoVisualSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Figma: 20/500 / line-height 28 / #0B081A
                Text(
                  '我是小艺同学，很高兴见到你！',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 28 / 20,
                  ),
                ),
                SizedBox(height: 4),
                // Figma: 13/400 / line-height 22 / #707790；强制单行不换行。
                // 41 个字符 × 13px ≈ 533px，与 Expanded 宽度 ~544px 是临界点，
                // PingFang OTF 字宽稍大就会换行；softWrap:false 直接禁止换行。
                Text(
                  '专属音乐AI问答助手，秒解专业疑问，梳理艺考考点，全程陪伴学习，让音乐备考更轻松高效。',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 22 / 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTheoryCard() {
    return Container(
      height: 265,
      decoration: BoxDecoration(
        color: _panelFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Figma: 16/500 / line-height 22 / #0B081A
            Text(
              '音乐理论问题',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 22 / 16,
              ),
            ),
            // Figma: 副标题紧跟标题（line-height 内紧排），不再额外间距
            const SizedBox(height: 0),
            // Figma: 12/400 / line-height 22 / #B6B5BB
            Text(
              '让你的艺考之路更加顺畅~',
              style: TextStyle(
                color: _textHint,
                fontSize: 12,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 22 / 12,
              ),
            ),
            // Figma: 副标题底（top:295 + 22 line-height = 317） → 列表起点 326，差 ~9
            const SizedBox(height: 13),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _theoryPrompts.length,
                // 题项之间间距：Figma 6 → 改为 10 让上下两题之间更通透
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _theoryPrompts[index];
                  return InkWell(
                    onTap: () => _handlePromptTap(item.text),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      // 数字（16/Barlow italic）与文字（12/PingFang）字号不同，
                      // 顶部对齐时视觉上偏离基线；改为中线对齐让两者垂直居中。
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Figma: 16/600 italic / Barlow / line-height 22
                        Text(
                          item.indexLabel,
                          style: TextStyle(
                            color: item.indexColor,
                            fontSize: 16,
                            fontFamily: 'Barlow',
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            height: 22 / 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Figma: 12/400 / PingFang / line-height 22
                        Expanded(
                          child: Text(
                            item.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 12,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 22 / 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard() {
    // 效率工具卡使用背景图 aibg.png（已自带与原渐变一致的色调），
    // 用 ClipRRect 裁出 16px 圆角，再用 Image 作为底层 + 内容叠在上方。
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 265,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(AppAssets.aiChatToolCardBg, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题/副标题间距与左侧"音乐理论问题"卡保持一致，
                  // 确保第一行内容（"分析乐谱"按钮顶）与左卡第一题项顶严格对齐。
                  // Figma: 16/500 / line-height 22 / #0B081A
                  Text(
                    '效率工具',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 22 / 16,
                    ),
                  ),
                  // 与左卡一致：标题与副标题不额外加间距（line-height 内紧排）
                  const SizedBox(height: 0),
                  // Figma: 12/400 / line-height 22 / #B6B5BB
                  Text(
                    '音乐学习就用艺同学',
                    style: TextStyle(
                      color: _textHint,
                      fontSize: 12,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 22 / 12,
                    ),
                  ),
                  // 与左卡一致：副标题底 → 第一行内容 = 9
                  const SizedBox(height: 13),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _toolShortcuts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tool = _toolShortcuts[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _handlePromptTap(tool.prompt),
                            child: SizedBox(
                              height: 50,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    _buildToolIcon(tool),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tool.title,
                                            style: TextStyle(
                                              color: _textPrimary,
                                              fontSize: 12,
                                              fontFamily: 'PingFang SC',
                                              fontWeight: AppFont.w500,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            tool.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _textHint,
                                              fontSize: 10,
                                              fontFamily: 'PingFang SC',
                                              fontWeight: AppFont.w400,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolIcon(_AiToolShortcut tool) {
    if (tool.asset != null) {
      return AppAssetGraphic(tool.asset!, width: 30, height: 30);
    }

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFFBEE9), Color(0xFFFF73D0)],
        ),
      ),
      child: Center(
        child: Stack(
          children: const [
            AppAssetGraphic(
              AppAssets.aiChatV2ToolPlanVector1,
              width: 14,
              height: 14,
            ),
            Positioned(
              right: 1,
              top: 1,
              child: AppAssetGraphic(
                AppAssets.aiChatV2ToolPlanVector2,
                width: 10,
                height: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation({
    required AiChatState state,
    required AiChatController controller,
    required double composerWidth,
    required double userBubbleMaxWidth,
    required double aiBubbleMaxWidth,
  }) {
    final showWaitingAssistant =
        state.waitingAssistant &&
        !state.messages.any(
          (item) => item.type == AiChatMessageType.ai && item.streaming,
        );
    return Column(
      children: [
        Container(
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Text(
            _activeTitle(state),
            style: TextStyle(
              color: Color(0xFF14214E),
              fontSize: 15,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.45,
            ),
          ),
        ),
        Expanded(
          child: state.messagesLoading && state.messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Listener(
                  // 用户手指压下 / 抬起时同步 _userTouchingList。压下后立刻把
                  // 还没执行完的「贴底滚动」级联取消，避免它在用户拖拽过程中
                  // 抢走 ScrollPosition 的 activity。
                  onPointerDown: (_) {
                    _userTouchingList = true;
                    _bottomScrollTimer?.cancel();
                  },
                  onPointerUp: (_) => _userTouchingList = false,
                  onPointerCancel: (_) => _userTouchingList = false,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(
                      _mainHorizontalPadding,
                      28,
                      _mainHorizontalPadding,
                      20,
                    ),
                    itemCount:
                        state.messages.length + (showWaitingAssistant ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Text(
                            '小艺同学正在思考中…',
                            style: TextStyle(
                              color: _textHint,
                              fontSize: 13,
                              fontFamily: 'PingFang SC',
                              height: 1.5,
                            ),
                          ),
                        );
                      }
                      final message = state.messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: message.type == AiChatMessageType.user
                            ? _buildUserMessage(
                                message: message,
                                controller: controller,
                                maxWidth: userBubbleMaxWidth,
                              )
                            : _buildAiMessage(
                                message: message,
                                controller: controller,
                                maxWidth: aiBubbleMaxWidth,
                              ),
                      );
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _mainHorizontalPadding,
            0,
            _mainHorizontalPadding,
            _mainBottomPadding,
          ),
          child: _buildComposer(state, controller, composerWidth),
        ),
        _buildDisclaimer(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildUserMessage({
    required AiChatMessage message,
    required AiChatController controller,
    required double maxWidth,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _panelFill,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                    height: 1.55,
                  ),
                ),
              ),
            ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in message.attachments)
                    _AttachmentChip(
                      attachment: attachment,
                      compact: true,
                      onTap: () => _previewAttachment(attachment),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionIcon(
                  icon: Icons.content_copy_outlined,
                  onTap: () => _copyText(message.text),
                ),
                const SizedBox(width: 10),
                _actionIcon(
                  icon: Icons.edit_outlined,
                  onTap: () => _reuseText(message.text),
                ),
                if (message.status == AiChatMessageStatus.failed) ...[
                  const SizedBox(width: 10),
                  _actionIcon(
                    icon: Icons.refresh_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () async {
                      final error = await controller.resendMessage(message);
                      if (error != null && mounted) {
                        _showInfo(error);
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage({
    required AiChatMessage message,
    required AiChatController controller,
    required double maxWidth,
  }) {
    final showAnswer = message.text.isNotEmpty || !message.reasoningStreaming;
    final answerStreaming = message.streaming && !message.reasoningStreaming;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.reasoning.isNotEmpty || message.reasoningStreaming) ...[
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => controller.toggleReasoningExpanded(message.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppAssetGraphic(
                        AppAssets.aiChatThinkActive,
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.reasoningStreaming
                            ? '深度思考中'
                            : message.reasoningExpanded
                            ? '思考过程（点击收起）'
                            : '思考过程（点击展开）',
                        style: TextStyle(
                          color: message.reasoningStreaming
                              ? _purple
                              : _textPrimary,
                          fontSize: 13,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message.reasoningExpanded) ...[
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _panelFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: message.reasoningStreaming
                          ? const Color(0x338741FF)
                          : _border,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                    child: _MessageText(
                      message.reasoning,
                      streaming: message.reasoningStreaming,
                      placeholder: '正在思考',
                      muted: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (showAnswer)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: answerStreaming ? const Color(0x338741FF) : _border,
                  ),
                  boxShadow: answerStreaming
                      ? const [
                          BoxShadow(
                            color: Color(0x0F8741FF),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: _MessageText(
                    message.text,
                    streaming: answerStreaming,
                    placeholder: '正在回复',
                  ),
                ),
              ),
            const SizedBox(height: 4),
            if (message.text.isNotEmpty && !message.streaming)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionIcon(
                    icon: Icons.content_copy_outlined,
                    onTap: () => _copyText(message.text),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color color = const Color(0xFF99A1AF),
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildComposer(
    AiChatState state,
    AiChatController controller,
    double width,
  ) {
    final canSend =
        !state.sending &&
        !state.uploadingAttachment &&
        (_inputCtrl.text.trim().isNotEmpty ||
            state.pendingAttachments.isNotEmpty);
    final composerHeight = state.pendingAttachments.isEmpty ? 104.0 : 154.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Container(
        width: double.infinity,
        height: composerHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          // Figma 复合阴影：
          // 1) 0 0 1 rgba(11,8,26,0.02)         —— 最近的 1px 浮起
          // 2) 0 12 40 rgba(11,8,26,0.06)       —— 主投影
          // 3) 0 12 24 -16 rgba(11,8,26,0.02)   —— 收紧的轻阴影（Flutter 用 spread:-16 模拟）
          boxShadow: const [
            BoxShadow(color: Color(0x050B081A), blurRadius: 1),
            BoxShadow(
              color: Color(0x0F0B081A),
              blurRadius: 40,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0x050B081A),
              blurRadius: 24,
              spreadRadius: -16,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            if (state.pendingAttachments.isNotEmpty)
              SizedBox(
                height: 50,
                child: _buildAttachmentTray(state, controller),
              ),
            // 输入区改为多行 textarea：占满输入框中剩余的纵向空间，
            // 内容超出时内部可滚动。Enter 换行；通过右下角发送按钮提交。
            // padding：左/右 16，顶部 12（首行文字距顶 12px），底部 8 留白。
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _inputCtrl,
                  maxLines: null,
                  minLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: _purple,
                  cursorWidth: 1.5,
                  cursorHeight: 16,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '流行音乐中常见的和弦进行有哪些？',
                    hintStyle: TextStyle(
                      color: Color(0x7326244C),
                      fontSize: 14,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.6,
                    ),
                  ),
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            // 底部工具栏：固定 48 高度（padding 8+8 + 内容 32）。
            // 不再需要中间分隔线；textarea 与工具栏视觉上合并为一个白底盒子。
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    _featureChip(
                      icon: state.isDeepThinking
                          ? AppAssets.aiChatThinkActive
                          : AppAssets.aiChatThink,
                      label: '深度思考',
                      active: state.isDeepThinking,
                      onTap: controller.toggleDeepThinking,
                      activeTextColor: _purple,
                      activeBg: _purpleSoft,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 8),
                    _featureChip(
                      // 与「深度思考」一致：按 active 状态切图标资源。
                      // idle = aichat2.png（灰）/ active = aichat2_active.png（紫）。
                      icon: state.isWebSearching
                          ? AppAssets.aiChatSearchActive
                          : AppAssets.aiChatSearch,
                      label: '联网搜索',
                      active: state.isWebSearching,
                      onTap: controller.toggleWebSearching,
                      // 文字色 + 背景色与深度思考完全一致（紫色 #8741FF）。
                      activeTextColor: _purple,
                      activeBg: _purpleSoft,
                      iconSize: 15,
                      iconLabelGap: 4,
                    ),
                    const Spacer(),
                    _iconButton(
                      iconAsset: AppAssets.aiChatAttach,
                      onTap: state.uploadingAttachment
                          ? null
                          : () => _pickAndUploadAttachment(controller),
                      background: Colors.transparent,
                      borderColor: _border,
                      loading: state.uploadingAttachment,
                    ),
                    const SizedBox(width: 8),
                    _sendButton(
                      enabled: canSend,
                      onTap: canSend ? () => _handleSend(controller) : null,
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

  Widget _buildAttachmentTray(AiChatState state, AiChatController controller) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      scrollDirection: Axis.horizontal,
      itemCount: state.pendingAttachments.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final attachment = state.pendingAttachments[index];
        return _AttachmentChip(
          attachment: attachment,
          onTap: () => _previewAttachment(attachment),
          onRemove: () => controller.removePendingAttachment(attachment),
        );
      },
    );
  }

  Widget _featureChip({
    required String icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required Color activeTextColor,
    required Color activeBg,
    required double iconSize,
    /// 图标右边缘与文案左侧的间距（逻辑像素）。深度思考默认 2；
    /// 「联网搜索」设计稿为 5。
    double iconLabelGap = 2,
  }) {
    final textColor = active ? activeTextColor : _textHint;
    final bgColor = active ? activeBg : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAssetGraphic(icon, width: iconSize, height: iconSize),
              SizedBox(width: iconLabelGap),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required String iconAsset,
    required VoidCallback? onTap,
    required Color background,
    required Color borderColor,
    bool loading = false,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _purple,
                    ),
                  )
                : AppAssetGraphic(iconAsset, width: 20, height: 20),
          ),
        ),
      ),
    );
  }

  Widget _sendButton({required bool enabled, required VoidCallback? onTap}) {
    // 直接使用 aichat/Button*.png 当按钮本体：图自身已经包含背景色（紫
    // [aiChatSendButtonEnabled] / 浅灰 [aiChatSendButtonDisabled]）、圆角
    // 与上箭头，不需要再叠加 Container / Icon。disabled 时把 onTap 设为
    // null，InkWell 自带的禁用态命中行为已经足够（无 ripple、不可点）。
    final asset = enabled
        ? AppAssets.aiChatSendButtonEnabled
        : AppAssets.aiChatSendButtonDisabled;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AppAssetGraphic(asset, width: 32, height: 32),
    );
  }

  Widget _buildDisclaimer() {
    // Figma: 10/400 / line-height 16 / #99A1AF；single line。
    // 用 Center 包裹让 Text 取自身内在宽度，并在父容器中水平居中显示，
    // 避免 softWrap:false 时文字从左侧起绘导致视觉上不居中的问题。
    return Center(
      child: Text(
        '服务生成的所有内容均由人工智能模型生成，其生成内容的准确性和完整性无法保证，不代表我们的态度或观点',
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: Color(0xFF99A1AF),
          fontSize: 10,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 16 / 10,
        ),
      ),
    );
  }

  String _activeTitle(AiChatState state) {
    if (state.isNewConversation) {
      return '新对话';
    }
    final active = state.sessions
        .where((item) => item.id == state.activeSessionId)
        .firstOrNull;
    if (active == null || active.title.trim().isEmpty) {
      return '对话';
    }
    return active.title.trim();
  }

  void _handlePromptTap(String prompt) {
    _inputCtrl.text = prompt;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );
    setState(() {});
  }

  Future<void> _handleSend(AiChatController controller) async {
    final text = _inputCtrl.text.trim();
    final state = ref.read(aiChatControllerProvider);
    if (text.isEmpty && state.pendingAttachments.isEmpty) {
      return;
    }
    _inputCtrl.clear();
    setState(() {});

    final error = await controller.sendMessage(text);
    if (error != null && mounted) {
      _showInfo(error);
    }
  }

  Future<void> _pickAndUploadAttachment(AiChatController controller) async {
    final picked = await pickAiChatAttachmentFile();
    if (!mounted || picked == null) {
      return;
    }
    final error = await controller.uploadAttachment(
      bytes: picked.bytes,
      filename: picked.filename,
      size: picked.size,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showInfo(error);
    }
  }

  void _previewAttachment(AiChatAttachment attachment) {
    if (attachment.url.trim().isEmpty) {
      _showInfo('附件地址为空');
      return;
    }
    if (_isImageAttachment(attachment)) {
      showImageGallery(
        context,
        images: [attachment.url],
        heroTagPrefix: 'ai_chat_attachment',
      );
      return;
    }

    final token = ref.read(appStorageProvider).token;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (context) {
        return _AttachmentPreviewDialog(
          attachment: attachment,
          authToken: token,
        );
      },
    );
  }

  bool _isImageAttachment(AiChatAttachment attachment) {
    final ext = _attachmentExtension(attachment);
    return const <String>{
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    }.contains(ext);
  }

  String _attachmentExtension(AiChatAttachment attachment) {
    final source = attachment.name.trim().isNotEmpty
        ? attachment.name
        : Uri.tryParse(attachment.url)?.path ?? attachment.url;
    final normalized = source.split('?').first.split('#').first;
    final dot = normalized.lastIndexOf('.');
    if (dot < 0 || dot == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dot + 1).toLowerCase();
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showInfo('已复制');
  }

  void _reuseText(String text) {
    _inputCtrl.text = text;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );
    setState(() {});
  }

  /// 会话条目「⋯」弹出的悬浮菜单。视觉与「我的云盘」左侧类目卡片完全
  /// 一致——共用 [showItemActionMenu]（白底 / 12 圆角 / 1.11px 浅边 /
  /// 三层柔和阴影 / 36 高 row）。当前只暴露「删除」一项。
  Future<void> _showSessionMoreMenu(
    AiChatController controller,
    AiChatSession session,
  ) async {
    final triggerKey = _moreTriggerKeys[session.id];
    if (triggerKey == null) {
      return;
    }
    final action = await showItemActionMenu(
      context: context,
      triggerKey: triggerKey,
      actions: const <ItemMenuAction>[ItemMenuAction.delete],
    );
    if (!mounted) return;
    if (action != ItemMenuAction.delete) return;
    await _confirmDeleteSession(controller, session);
  }

  /// 「删除会话」二次确认弹窗。完全按 Figma 视觉还原：
  /// • 428 宽圆角 24 卡片，顶部 D8CCFF→白渐变 + 装饰图（共用
  ///   [GradientHeaderDialog]，与个人中心 / 智慧校园所有同款弹窗一致）。
  /// • 标题「删除会话」20/500 居中，#0B081A。
  /// • 提问行 16/400 / line-height 20 / #0B081A，左对齐放在 8 圆角的
  ///   透明容器里（图里那个看不见背景的 380×48 框就是 padding 容器）。
  /// • 底部 取消（白）/ 确认（紫渐变）双按钮，复用 [AppDialogActionBar]
  ///   即可拿到 figma 一致的阴影和颜色。
  Future<void> _confirmDeleteSession(
    AiChatController controller,
    AiChatSession session,
  ) async {
    final shouldDelete = await showScaledDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) {
        return GradientHeaderDialog(
          title: '删除会话',
          titleFontSize: 20,
          titleFontWeight: AppFont.w500,
          titlePaddingTop: 25,
          width: 428,
          actionBar: AppDialogActionBar(
            cancelLabel: '取消',
            confirmLabel: '确认',
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
          child: Padding(
            // Figma: 380×48 容器内 padding-left/right:16，padding-top/bottom:12。
            // GradientHeaderDialog 的 contentPadding 默认是 LRTB(20,25,20,20)，
            // 已经撑出 380 的可用宽度；这里只补内层 16/12 的内边距即可。
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '确定删除「${session.title}」吗？',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 16,
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    final error = await controller.deleteSession(session);
    if (error != null && mounted) {
      _showInfo(error);
    }
  }

  void _showInfo(String message) {
    AppToast.show(context, message);
  }

  void _scheduleScrollIfNeeded(AiChatState state) {
    final latest = state.messages.isEmpty
        ? ''
        : '${state.messages.last.id}-${state.messages.last.status.name}'
              '-${state.messages.last.text.length}'
              '-${state.messages.last.reasoning.length}'
              '-${state.messages.last.streaming}';
    final signature =
        '${state.activeSessionId}-${state.messages.length}'
        '-${state.waitingAssistant}-${state.messagesLoading}-$latest';
    if (_messageSignature == signature) {
      return;
    }
    _messageSignature = signature;

    _scheduleBottomScroll();
  }

  void _scheduleBottomScroll({int attempt = 0}) {
    // 新一轮调度先把上一轮排队的 timer 干掉：原实现是 5 个递归 callback
    // 各自独立 schedule，会在 ~280ms 内连续触发 1 次 jumpTo + 4 次 animateTo。
    // 切换会话或流式推送时，这串「贴底动画」会接管 ScrollPosition，把用户
    // 第一次滑动产生的 DragScrollActivity 直接替换成 DrivenScrollActivity，
    // 表现就是「切换会话后第一次上滑没反应、得划第二次」。
    if (attempt == 0) {
      _bottomScrollTimer?.cancel();
      _bottomScrollTimer = null;
    }

    // 用户手指压在列表上时，绝不再驱动滚动，把 ScrollPosition 留给手势。
    if (_userTouchingList) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients || _userTouchingList) {
        return;
      }
      final max = _scrollCtrl.position.maxScrollExtent;
      // 后续几次「补偿性滚动」也用 jumpTo：它是同步设值、不会留下持续运行的
      // DrivenScrollActivity，所以即使紧接着用户开始滑动也不会被打断。
      _scrollCtrl.jumpTo(max);

      if (attempt < 3) {
        // 一共 4 次（初始 + 3 次补偿），覆盖图片/PDF/HTML 异步布局完成后
        // maxScrollExtent 增长的情况；间隔比原来更短一些以更快收敛。
        _bottomScrollTimer = Timer(
          Duration(milliseconds: attempt == 0 ? 32 : 64),
          () => _scheduleBottomScroll(attempt: attempt + 1),
        );
      } else {
        _bottomScrollTimer = null;
      }
    });
  }
}

class _AiPromptQuestion {
  const _AiPromptQuestion(this.indexLabel, this.text, this.indexColor);

  final String indexLabel;
  final String text;
  final Color indexColor;
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    this.onTap,
    this.onRemove,
    this.compact = false,
  });

  final AiChatAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(maxWidth: compact ? 220 : 260),
      padding: EdgeInsets.fromLTRB(10, compact ? 5 : 5, 8, compact ? 5 : 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0x1A8741FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insert_drive_file_outlined,
              size: 14,
              color: _purple,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 11,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.1,
                  ),
                ),
                if (!compact && attachment.size > 0)
                  Text(
                    _formatFileSize(attachment.size),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textHint,
                      fontSize: 9,
                      fontFamily: 'PingFang SC',
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 14, color: _textHint),
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: compact ? Colors.white : const Color(0xFFF8F7FF),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8E4FF)),
          ),
          child: content,
        ),
      ),
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }
}

class _AttachmentPreviewDialog extends StatelessWidget {
  const _AttachmentPreviewDialog({
    required this.attachment,
    required this.authToken,
  });

  final AiChatAttachment attachment;
  final String authToken;

  @override
  Widget build(BuildContext context) {
    final ext = _extension(attachment);
    final canPreviewPdf = ext == 'pdf';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 760,
          maxHeight: 620,
          minHeight: 420,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0x1A8741FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      canPreviewPdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.insert_drive_file_outlined,
                      color: _purple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          attachment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                          ),
                        ),
                        if (attachment.size > 0)
                          Text(
                            _AttachmentChip._formatFileSize(attachment.size),
                            style: const TextStyle(
                              color: _textHint,
                              fontSize: 11,
                              fontFamily: 'PingFang SC',
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: canPreviewPdf
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                      child: TheoryPdfView(
                        url: attachment.url,
                        authToken: authToken,
                      ),
                    )
                  : _UnsupportedAttachmentPreview(attachment: attachment),
            ),
          ],
        ),
      ),
    );
  }

  static String _extension(AiChatAttachment attachment) {
    final source = attachment.name.trim().isNotEmpty
        ? attachment.name
        : Uri.tryParse(attachment.url)?.path ?? attachment.url;
    final normalized = source.split('?').first.split('#').first;
    final dot = normalized.lastIndexOf('.');
    if (dot < 0 || dot == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dot + 1).toLowerCase();
  }
}

class _UnsupportedAttachmentPreview extends StatelessWidget {
  const _UnsupportedAttachmentPreview({required this.attachment});

  final AiChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8E4FF)),
              ),
              child: const Icon(
                Icons.insert_drive_file_outlined,
                color: _purple,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              attachment.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '当前文件类型暂不支持在线预览',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontFamily: 'PingFang SC',
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              attachment.url,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _purple,
                fontSize: 11,
                fontFamily: 'Manrope',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: attachment.url)),
              icon: const Icon(Icons.content_copy_outlined, size: 16),
              label: const Text('复制文件地址'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiToolShortcut {
  const _AiToolShortcut({
    required this.title,
    required this.subtitle,
    required this.prompt,
    this.asset,
  });

  final String title;
  final String subtitle;
  final String prompt;
  final String? asset;
}

enum _MessageBlockKind { paragraph, heading, list, quote }

class _MessageBlock {
  const _MessageBlock._({
    required this.kind,
    this.text = '',
    this.items = const [],
  });

  const _MessageBlock.paragraph(String text)
    : this._(kind: _MessageBlockKind.paragraph, text: text);

  const _MessageBlock.heading(String text)
    : this._(kind: _MessageBlockKind.heading, text: text);

  const _MessageBlock.list(List<_MessageListItem> items)
    : this._(kind: _MessageBlockKind.list, items: items);

  const _MessageBlock.quote(String text)
    : this._(kind: _MessageBlockKind.quote, text: text);

  final _MessageBlockKind kind;
  final String text;
  final List<_MessageListItem> items;
}

class _MessageListItem {
  const _MessageListItem({required this.marker, required this.text});

  final String marker;
  final String text;
}

class _MessageText extends StatelessWidget {
  const _MessageText(
    this.text, {
    this.streaming = false,
    this.placeholder = '正在回复',
    this.muted = false,
  });

  final String text;
  final bool streaming;
  final String placeholder;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    final baseStyle = TextStyle(
      color: muted ? _textSecondary : _textPrimary,
      fontSize: 14,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: 1.7,
    );

    if (blocks.isEmpty) {
      if (!streaming) {
        return const SizedBox.shrink();
      }
      return _TypingPlaceholder(label: placeholder, muted: muted);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == blocks.length - 1 ? 0 : 8,
            ),
            child: _buildBlock(
              blocks[index],
              baseStyle,
              streaming && index == blocks.length - 1,
            ),
          ),
      ],
    );
  }

  Widget _buildBlock(
    _MessageBlock block,
    TextStyle baseStyle,
    bool showCursor,
  ) {
    switch (block.kind) {
      case _MessageBlockKind.heading:
        return _InlineMessageText(
          block.text,
          style: baseStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.55,
          ),
          streaming: showCursor,
        );
      case _MessageBlockKind.list:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < block.items.length; index++)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        block.items[index].marker,
                        style: baseStyle.copyWith(
                          color: _purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _InlineMessageText(
                        block.items[index].text,
                        style: baseStyle,
                        streaming:
                            showCursor && index == block.items.length - 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case _MessageBlockKind.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0x338741FF), width: 3),
            ),
          ),
          child: _InlineMessageText(
            block.text,
            style: baseStyle.copyWith(color: _textSecondary),
            streaming: showCursor,
          ),
        );
      case _MessageBlockKind.paragraph:
        return _InlineMessageText(
          block.text,
          style: baseStyle,
          streaming: showCursor,
        );
    }
  }

  List<_MessageBlock> _parseBlocks(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final blocks = <_MessageBlock>[];
    final paragraph = <String>[];
    final listItems = <_MessageListItem>[];
    final listRegExp = RegExp(r'^((?:[-*•])|(?:\d+[.)]))\s+(.+)$');
    final headingRegExp = RegExp(r'^(#{1,3})\s+(.+)$');

    void flushParagraph() {
      if (paragraph.isEmpty) {
        return;
      }
      final text = paragraph.join('\n').trim();
      if (text.isNotEmpty) {
        blocks.add(_MessageBlock.paragraph(text));
      }
      paragraph.clear();
    }

    void flushList() {
      if (listItems.isEmpty) {
        return;
      }
      blocks.add(_MessageBlock.list(List<_MessageListItem>.from(listItems)));
      listItems.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        flushList();
        continue;
      }

      final heading = headingRegExp.firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        flushList();
        blocks.add(_MessageBlock.heading((heading.group(2) ?? '').trim()));
        continue;
      }

      final list = listRegExp.firstMatch(trimmed);
      if (list != null) {
        flushParagraph();
        final marker = list.group(1) ?? '•';
        final body = (list.group(2) ?? '').trim();
        listItems.add(
          _MessageListItem(
            marker: marker == '-' || marker == '*' ? '•' : marker,
            text: body,
          ),
        );
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        flushList();
        blocks.add(_MessageBlock.quote(trimmed.substring(1).trim()));
        continue;
      }

      flushList();
      paragraph.add(line.trimLeft());
    }

    flushParagraph();
    flushList();
    return blocks;
  }
}

class _InlineMessageText extends StatelessWidget {
  const _InlineMessageText(
    this.text, {
    required this.style,
    this.streaming = false,
  });

  final String text;
  final TextStyle style;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          ..._buildInlineSpans(text),
          if (streaming)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 3),
                child: _StreamingCursor(),
              ),
            ),
        ],
      ),
      softWrap: true,
      style: style,
    );
  }

  List<InlineSpan> _buildInlineSpans(String source) {
    final spans = <InlineSpan>[];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final matches = RegExp(r'\*\*(.*?)\*\*').allMatches(line).toList();
      if (matches.isEmpty) {
        spans.add(TextSpan(text: line));
      } else {
        var cursor = 0;
        for (final match in matches) {
          if (match.start > cursor) {
            spans.add(TextSpan(text: line.substring(cursor, match.start)));
          }
          final boldText = match.group(1) ?? '';
          spans.add(
            TextSpan(
              text: boldText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
          cursor = match.end;
        }
        if (cursor < line.length) {
          spans.add(TextSpan(text: line.substring(cursor)));
        }
      }
      if (lineIndex != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }
}

class _TypingPlaceholder extends StatelessWidget {
  const _TypingPlaceholder({required this.label, required this.muted});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: muted ? _textSecondary : _textPrimary,
            fontSize: 14,
            fontFamily: 'PingFang SC',
            height: 1.7,
          ),
        ),
        const SizedBox(width: 6),
        const _TypingDots(),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++)
              Opacity(
                opacity: _dotOpacity(value, index),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _purple,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 4, height: 4),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _dotOpacity(double value, int index) {
    final shifted = (value + index * 0.18) % 1;
    if (shifted < 0.3) {
      return 0.35 + shifted / 0.3 * 0.65;
    }
    if (shifted < 0.6) {
      return 1 - (shifted - 0.3) / 0.3 * 0.55;
    }
    return 0.45;
  }
}

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 2,
        height: 17,
        decoration: BoxDecoration(
          color: _purple,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
