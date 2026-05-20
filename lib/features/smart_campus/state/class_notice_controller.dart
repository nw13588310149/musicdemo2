// =============================================================================
// 班级通知（班级公告）共享状态
//
// 用途：
//   - 学生端「我的班级」页面 _AnnouncementSection 读取展示；
//   - 班主任端「班级工作台 → 概况」页面以同一份列表展示，并在班主任视角下
//     提供"发布通知 / 删除通知"操作。两个视图通过本 provider 同步，
//     班主任删除/发布后回到学生视图能立刻看到结果。
//
// 注意：刻意 **不** 用 `autoDispose`——视图来回切换 / 路由销毁时如果
// 重新构造 controller，演示数据会被重置，操作记录无法持续可见。
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClassNotice {
  const ClassNotice({
    required this.id,
    required this.text,
    required this.date,
    this.highlighted = false,
  });

  /// 唯一标识，用于发布 / 删除时定位列表项；演示用毫秒时间戳即可。
  final String id;
  final String text;
  final String date;

  /// 第一条带紫色小图标。班主任发布时默认 highlighted=true（最新通知突出
  /// 显示），随后再发布时上一条会被降级为 false。
  final bool highlighted;

  ClassNotice copyWith({String? text, String? date, bool? highlighted}) {
    return ClassNotice(
      id: id,
      text: text ?? this.text,
      date: date ?? this.date,
      highlighted: highlighted ?? this.highlighted,
    );
  }
}

final classNoticeControllerProvider =
    StateNotifierProvider<ClassNoticeController, List<ClassNotice>>(
      (ref) => ClassNoticeController(),
    );

class ClassNoticeController extends StateNotifier<List<ClassNotice>> {
  ClassNoticeController() : super(_seedNotices());

  /// 班主任发布新通知。新通知插到最前并 highlighted=true，原有所有通知降级。
  void publish({required String text, String? date}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    final autoDate = date ?? _formatDate(now);
    final notice = ClassNotice(
      id: '${now.microsecondsSinceEpoch}',
      text: trimmed,
      date: autoDate,
      highlighted: true,
    );
    state = [
      notice,
      // 旧的全部降级；同时保持顺序
      for (final n in state) n.copyWith(highlighted: false),
    ];
  }

  /// 班主任删除通知。
  void remove(String id) {
    state = [
      for (final n in state)
        if (n.id != id) n,
    ];
  }

  static String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm-$dd';
  }
}

List<ClassNotice> _seedNotices() => const [
  ClassNotice(
    id: 'seed-1',
    text: '本周五16:30合唱排练，地点音乐厅A201，穿统一排练服。',
    date: '04-02',
    highlighted: true,
  ),
  ClassNotice(id: 'seed-2', text: '乐理单元测验改至周四第1节，座位表已发班群。', date: '04-02'),
];
