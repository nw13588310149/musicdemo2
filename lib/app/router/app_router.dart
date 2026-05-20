import 'package:flutter/material.dart';

import '../../features/auth/ui/forget_password_page.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/ui/register_page.dart';
import '../../features/common/ui/feature_default_pages.dart';
import '../../features/common/ui/legacy_placeholder_content.dart';
import '../../features/common/ui/terms_page.dart';
import '../../features/courseware/ui/courseware_page.dart';
import '../../features/dictation/ui/dictation_page.dart';
import '../../features/home/ui/home_page.dart';
import '../../features/my_collection/ui/my_collection_page.dart'
    as my_collection;
import '../../features/my_notes/ui/my_notes_page.dart' as my_notes;
import '../../features/music_companion/ui/music_companion_page.dart';
import '../../features/music_play/ui/music_play_page.dart';
import '../../features/consultation/ui/consultation_detail_page.dart';
import '../../features/consultation/ui/consultation_page.dart';
import '../../features/personal_center/ui/info_page.dart';
import '../../features/personal_center/ui/personal_center_page.dart';
import '../../features/primary/ui/primary_pages.dart' as primary_pages;
import '../../features/circle/ui/circle_page.dart';
import '../../features/quiz_practice/ui/quiz_practice_page.dart';
import '../../features/quiz_practice/ui/quiz_session_page.dart';
import '../../features/recording_system/ui/recording_system_page.dart'
    as recording_system;
import '../../features/school/ui/school_courseware_page.dart';
import '../../features/school/ui/school_quiz_practice_page.dart';
import '../../features/school/ui/school_video_tutorial_page.dart';
import '../../features/shell/ui/shell_scaffold.dart';
import '../../features/smart_campus/ui/smart_campus_page.dart';
import '../../features/smart_dictation/ui/smart_dictation_page.dart';
import '../../features/study_catalog/ui/study_catalog_page.dart';
import '../../features/theory/ui/theory_page.dart';
import '../../features/video_tutorial/ui/video_tutorial_page.dart';
import '../../features/voice/ui/voice_page.dart';
import 'route_paths.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? RoutePaths.home;

    if (_isPublicRoute(routeName)) {
      return _buildPublicRoute(routeName, settings);
    }

    return _buildProtectedRoute(
      ShellScaffold(
        currentRoute: routeName,
        child: _buildProtectedContent(routeName),
      ),
      settings,
    );
  }

  static bool _isPublicRoute(String routeName) {
    return routeName == RoutePaths.login ||
        routeName == RoutePaths.register ||
        routeName == RoutePaths.forget ||
        routeName == RoutePaths.xieyi2;
  }

  static Route<dynamic> _buildPublicRoute(
    String routeName,
    RouteSettings settings,
  ) {
    switch (routeName) {
      case RoutePaths.login:
        return _buildRoute(const LoginPage(), settings);
      case RoutePaths.register:
        return _buildRoute(const RegisterPage(), settings);
      case RoutePaths.forget:
        return _buildRoute(const ForgetPasswordPage(), settings);
      case RoutePaths.xieyi2:
        return _buildRoute(const TermsPage(), settings);
      default:
        return _buildRoute(const LoginPage(), settings);
    }
  }

  static Widget _buildProtectedContent(String routeName) {
    switch (routeName) {
      case RoutePaths.home:
        return const HomePage();
      case RoutePaths.personalAi:
        return const primary_pages.PersonalAiPage();
      case RoutePaths.school:
        return const SchoolCoursewareV2Page();
      case RoutePaths.circle:
        return const CirclePage();
      case RoutePaths.courseware:
        return const MyCloudDrivePage();
      case RoutePaths.videoTutorial:
        return const VideoTutorialV2Page();
      case RoutePaths.smartDictation:
        return const SmartDictationV2Page();
      case RoutePaths.music:
        return const MusicCompanionV2Page();
      case RoutePaths.smartCampus:
        return const SmartCampusPage();
      case RoutePaths.myNotes:
        return const my_notes.MyNotesPage();
      case RoutePaths.recording:
        return const recording_system.RecordingSystemPage();
      case RoutePaths.myCollection:
        return const my_collection.MyCollectionPage();
      case RoutePaths.personalCenter:
        return const PersonalCenterPage();
      case RoutePaths.info:
        return const InfoPage();
      case RoutePaths.fankui:
      case RoutePaths.helpFeedback:
        return const primary_pages.FeedbackPage();
      // 鈹€鈹€ 棣栭〉涔濆鏍煎姛鑳介粯璁ら〉 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
      case RoutePaths.dictation:
        return const DictationPage();
      case RoutePaths.sightSinging:
        return const SightSingingPage();
      case RoutePaths.musicTheory:
        return const MusicTheoryPage();
      case RoutePaths.mock:
        return const MockExamDefaultPage();
      case RoutePaths.camp:
        return const QuizPracticePage();
      // 校园专属刷题 / 视频页（独立于公开资料，后续接入校园接口）。
      case RoutePaths.schoolCamp:
        return const SchoolQuizPracticePage();
      case RoutePaths.schoolVideo:
        return const SchoolVideoTutorialPage();
      // 刷题三级页：做题界面，由 /camp 入口跳入。
      case RoutePaths.campAnswer:
        return const QuizSessionPage();
      // 1.0 的 camp_over 路由：进入即弹出完成统计弹窗。
      case RoutePaths.campOver:
        return const QuizSessionPage(openCompletion: true);
      case RoutePaths.answerQuestions:
        return const AnswerQuestionsPage();
      case RoutePaths.consultation:
        return const ConsultationPage();
      case RoutePaths.consultationDetail:
        return const ConsultationDetailPage();
      case RoutePaths.aiSong:
        return const StoreDefaultPage();
      case RoutePaths.voice:
        return const VoicePage();
      case RoutePaths.instrumental:
        return const InstrumentalPage();
      case RoutePaths.musicPlay:
        return const MusicPlayPage();
      case RoutePaths.answerEnd:
        return const TheoryPage();
      case RoutePaths.answerEnd2:
        return const MusicPlayPage();
      case RoutePaths.theory:
        return const TheoryPage();
      default:
        return LegacyPlaceholderContent(
          routeName: routeName,
          title: _legacyPageTitle(routeName),
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
  }

  static PageRouteBuilder<dynamic> _buildProtectedRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page,
    );
  }

  static String _legacyPageTitle(String routeName) {
    const legacyRoutes = <String, String>{
      RoutePaths.school: '鏍″洯棣栭〉',
      RoutePaths.music: '闊充箰妯″潡',
      RoutePaths.courseware: '鎴戠殑浜戠洏',
      RoutePaths.videoTutorial: '瑙嗛涓績',
      RoutePaths.smartDictation: '鏅鸿兘鍚啓',
      RoutePaths.smartCampus: '鏅烘収鏍″洯',
      RoutePaths.smartCampusSignRecords: '绛惧埌璁板綍',
      RoutePaths.smartCampusSignApprovals: '绛惧埌瀹℃壒',
      RoutePaths.smartSinging: '鏅鸿兘澹颁箰',
      RoutePaths.myNotes: '鎴戠殑绗旇',
      RoutePaths.myCollection: '鎴戠殑鏀惰棌',
      RoutePaths.personalCenter: '涓汉涓績',
      RoutePaths.helpFeedback: '帮助与反馈',
      RoutePaths.noteBg: '绗旇鑳屾櫙',
      RoutePaths.answerQuestions: '绛旈鍏ュ彛',
      RoutePaths.camp: '闂叧缁冧範',
      RoutePaths.consultation: '瀛︿範璧勮',
      RoutePaths.dictation: '鍚啓缁冧範',
      RoutePaths.mock: '妯℃嫙鑰冭瘯',
      RoutePaths.musicTheory: '涔愮悊缁冧範',
      RoutePaths.sightSinging: '瑙嗗敱缁冧範',
      RoutePaths.store: '鍟嗗煄',
      RoutePaths.musicPlay: '涔愯氨鎾斁',
      RoutePaths.recording: '褰曢煶浣滃搧',
      RoutePaths.voice: '澹颁箰璁粌',
      RoutePaths.instrumental: '鍣ㄤ箰璁粌',
      RoutePaths.theory: '涔愮悊璇︽儏',
      RoutePaths.answer: '鍚啓绛旈',
      RoutePaths.answer2: '鍚啓绛旈2',
      RoutePaths.answer3: '鍚啓绛旈3',
      RoutePaths.over: '鍚啓缁撴灉',
      RoutePaths.detail: '璇句欢璇︽儏',
      RoutePaths.detail2: '璇句欢璇︽儏2',
      RoutePaths.info: '涓汉璧勬枡',
      RoutePaths.fankui: '鎰忚鍙嶉',
      RoutePaths.qrcode: '我的二维码',
      RoutePaths.campAnswer: '闂叧浣滅瓟',
      RoutePaths.campOver: '闂叧缁撶畻',
      RoutePaths.chat: '鐝骇鑱婂ぉ',
      RoutePaths.consultationDetail: '璧勮璇︽儏',
      RoutePaths.noteDetail: '绗旇璇︽儏',
      RoutePaths.answerEnd: '绛旈缁撴潫',
      RoutePaths.answerEnd2: '绛旈缁撴潫2',
      RoutePaths.verifie: '瀹炲悕璁よ瘉',
      RoutePaths.set: '璁剧疆',
      RoutePaths.xieyi: '鏈嶅姟鍗忚',
      RoutePaths.personalAi: 'AI 闂瓟',
      RoutePaths.email: '閭缁戝畾',
      RoutePaths.aiSong: 'AI 浣滄洸',
      RoutePaths.circle: '校圈',
    };
    return legacyRoutes[routeName] ?? '待迁移页面';
  }
}
