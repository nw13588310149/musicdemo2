import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 通用默认功能页脚手架
/// 各功能模块在正式开发前使用此占位页，保持路由畅通。
class _FeatureDefaultPage extends StatelessWidget {
  const _FeatureDefaultPage({
    required this.title,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: accentColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: AppFont.w600,
              color: Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '功能开发中，敬请期待',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

// ── 听写 ─────────────────────────────────────────────────────────────────────
class DictationDefaultPage extends StatelessWidget {
  const DictationDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '听写练习',
    icon: Icons.headphones_outlined,
    accentColor: Color(0xFF00C9A4),
  );
}

// ── 视唱 ─────────────────────────────────────────────────────────────────────
class SightSingingDefaultPage extends StatelessWidget {
  const SightSingingDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '视唱练习',
    icon: Icons.music_note_outlined,
    accentColor: Color(0xFF8741FF),
  );
}

// ── 乐理 ─────────────────────────────────────────────────────────────────────
class MusicTheoryDefaultPage extends StatelessWidget {
  const MusicTheoryDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '乐理练习',
    icon: Icons.library_music_outlined,
    accentColor: Color(0xFFFF386B),
  );
}

// ── 模考 ─────────────────────────────────────────────────────────────────────
class MockExamDefaultPage extends StatelessWidget {
  const MockExamDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '模拟考试',
    icon: Icons.assignment_outlined,
    accentColor: Color(0xFFFF7043),
  );
}

// ── 刷题 ─────────────────────────────────────────────────────────────────────
class CampDefaultPage extends StatelessWidget {
  const CampDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '刷题练习',
    icon: Icons.quiz_outlined,
    accentColor: Color(0xFF1976D2),
  );
}

// ── 试题 ─────────────────────────────────────────────────────────────────────
class AnswerQuestionsDefaultPage extends StatelessWidget {
  const AnswerQuestionsDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '答题中心',
    icon: Icons.checklist_outlined,
    accentColor: Color(0xFF0CAC40),
  );
}

// ── 资讯 ─────────────────────────────────────────────────────────────────────
class ConsultationDefaultPage extends StatelessWidget {
  const ConsultationDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '学习资讯',
    icon: Icons.article_outlined,
    accentColor: Color(0xFF039BE5),
  );
}

// ── 商城 ─────────────────────────────────────────────────────────────────────
class StoreDefaultPage extends StatelessWidget {
  const StoreDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '商城',
    icon: Icons.storefront_outlined,
    accentColor: Color(0xFFE91E63),
  );
}
