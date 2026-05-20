// =============================================================================
// 宿管端「按宿舍查寝」独立页面
//
// 入口：宿管 dashboard 快捷区「按宿舍查寝」按钮 →
//      controller.openDormCheckByRoom() → mainView == dormCheckByRoom +
//      role == dormManager → SmartCampusPage 路由到本视图。
//      返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高 + 4deg #F9EDFF→white 渐变 + 圆角 16 + 顶部居中
//      "按宿舍查寝" 16/600 + 副标题 12/#B6B5BB 操作说明；左 12 返回 32×32
//      白底 outline #F3F2F3）。
//   2. 顶部当前查寝截止时间 16/500（如 "2026-04-22 23:00前"）。
//      按需求**去掉**了 Figma 右侧 "晨查寝 / 晚查寝" 分段切换。
//   3. 4 张统计卡（100 高，196° 彩色渐变 + 右上 32×32 白底图标）：
//      A. 在册床位 12 — 橙渐变 + 绿色 home icon
//      B. 正常口径 10 — 绿渐变 + 同图标
//      C. 晚归 2     — 红渐变 + 紫色 alert
//      D. 未打卡 1   — 红渐变 + 紫色 alert
//   4. 多张宿舍卡（白底 16 圆角 + 12 padding）：
//      Header：紫色方块 icon + 「宿舍 A-901」14/500 + 「女生公寓A座·6层」
//             12/400 + 「N人·晚查寝·22:30前」12/#B6B5BB +
//             右侧 220×40「一键打卡」按钮（紫渐变 #B68EFF→#8640FF 或置灰
//             #CECED1）。
//      Body：3 列学生格子（#F5F6FA 12 圆角，padding 12）：40×40 头像 +
//            姓名 14/500 + 学号 12/#B6B5BB + 右侧状态 dropdown
//            (已打卡 / 未打卡 / 晚归 / 请假免检)。
//   5. 底部 3 列查寝历史卡（width 312，padding 12，207° #FAF0FF→white
//      渐变，圆角 16）：
//      · Barlow 18/600「晨查寝 / 晚查寝」+ 状态徽章
//        （正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF）
//      · 「女生宿舍3号楼 612」13/#6D6B75 + 日期 12/#B6B5BB
//      · 灰底块 50 高：规定时间 / 打卡时间 两列居中
//      · 底部 "备注：…" 12/#B6B5BB。
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE5E7EB);
const Color _kBorderLine = Color(0xFFCECED1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextDarker = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSolid = Color(0xFFA773FF);
const Color _kPurpleSoftBg = Color(0xFFE7D9FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kBlue = Color(0xFF325BFF);
const Color _kGreen = Color(0xFF1CD097);

// —— 学生打卡状态 ——————————————————————————————————————————————————
enum _StudentCheckStatus {
  checked('已打卡'),
  unchecked('未打卡'),
  lateReturn('晚归'),
  leaveExempt('请假免检');

  const _StudentCheckStatus(this.label);
  final String label;
}

// —— 历史查寝状态（实色徽章）—————————————————————————————————————
enum _HistoryStatus {
  normal('正常', _kPurpleSolid),
  absent('未打卡', _kRed),
  late_('迟到', _kBlue);

  const _HistoryStatus(this.label, this.bg);
  final String label;
  final Color bg;
}

// —— 数据模型 ——————————————————————————————————————————————————

class _RoomStudent {
  _RoomStudent({
    required this.name,
    required this.studentNo,
    required this.avatarUrl,
    required this.status,
  });

  final String name;
  final String studentNo;
  final String avatarUrl;
  _StudentCheckStatus status;
}

class _DormRoom {
  _DormRoom({
    required this.roomName,
    required this.buildingDesc,
    required this.session,
    required this.deadline,
    required this.students,
  });

  final String roomName;
  final String buildingDesc;
  final String session;
  final String deadline;
  final List<_RoomStudent> students;

  /// 该宿舍所有学生是否都已完成「已打卡」之外的非「未打卡」状态。
  /// 这里只要每个人都不是 "未打卡" 就算"打卡完成"，「一键打卡」按钮置灰。
  bool get allDone =>
      students.every((s) => s.status != _StudentCheckStatus.unchecked);
}

class _HistoryRecord {
  const _HistoryRecord({
    required this.title,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final String title; // 晨查寝 / 晚查寝
  final _HistoryStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;
}

// =============================================================================
// 顶级视图
// =============================================================================

class DormManagerCheckByRoomView extends StatefulWidget {
  const DormManagerCheckByRoomView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<DormManagerCheckByRoomView> createState() =>
      _DormManagerCheckByRoomViewState();
}

class _DormManagerCheckByRoomViewState
    extends State<DormManagerCheckByRoomView> {
  late List<_DormRoom> _rooms;
  late List<_HistoryRecord> _history;

  static const String _deadlineText = '2026-04-22 23:00前';

  @override
  void initState() {
    super.initState();
    _rooms = _demoRooms();
    _history = _demoHistory();
  }

  /// 4 张统计卡数据。
  ///
  /// - 在册床位：所有宿舍学生数之和。
  /// - 正常口径：已打卡 + 请假免检（不属于异常）。
  /// - 晚归：状态 = lateReturn。
  /// - 未打卡：状态 = unchecked。
  ({int beds, int normal, int late_, int absent}) _stats() {
    var beds = 0;
    var normal = 0;
    var late_ = 0;
    var absent = 0;
    for (final r in _rooms) {
      for (final s in r.students) {
        beds++;
        switch (s.status) {
          case _StudentCheckStatus.checked:
          case _StudentCheckStatus.leaveExempt:
            normal++;
            break;
          case _StudentCheckStatus.lateReturn:
            late_++;
            break;
          case _StudentCheckStatus.unchecked:
            absent++;
            break;
        }
      }
    }
    return (beds: beds, normal: normal, late_: late_, absent: absent);
  }

  void _checkInAll(_DormRoom room) {
    setState(() {
      for (final s in room.students) {
        if (s.status == _StudentCheckStatus.unchecked) {
          s.status = _StudentCheckStatus.checked;
        }
      }
    });
    AppToast.show(context, '${room.roomName} 已全员打卡（演示）');
  }

  void _updateStudentStatus(
    _RoomStudent student,
    _StudentCheckStatus next,
  ) {
    setState(() {
      student.status = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final stats = _stats();
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            // 截止时间 16/500（去掉了 Figma 右侧的晨/晚查寝分段切换）。
            Padding(
              padding: EdgeInsets.only(left: ui(4)),
              child: Text(
                _deadlineText,
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              beds: stats.beds,
              normal: stats.normal,
              lateReturn: stats.late_,
              absent: stats.absent,
            ),
            SizedBox(height: ui(16)),
            for (var i = 0; i < _rooms.length; i++) ...[
              if (i > 0) SizedBox(height: ui(16)),
              _RoomCard(
                room: _rooms[i],
                onCheckInAll: () => _checkInAll(_rooms[i]),
                onChangeStatus: _updateStudentStatus,
              ),
            ],
            SizedBox(height: ui(20)),
            _HistoryRow(records: _history),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner
// =============================================================================

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '按宿舍查寝',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '进入每个宿舍后先可一键打卡（全员记为正常），再针对个人修改为晚归、未打卡、请假免检等；与年级闸机数据对接后在此提交即可同步备案。',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// =============================================================================
// 4 张统计卡
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.beds,
    required this.normal,
    required this.lateReturn,
    required this.absent,
  });

  final int beds;
  final int normal;
  final int lateReturn;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '在册床位',
            value: beds,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x29FFA846), Color(0x00FFFFFF)],
            ),
            iconColor: _kGreen,
            iconKind: _StatIconKind.home,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '正常口径',
            value: normal,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1746FF77), Color(0x00FFFFFF)],
            ),
            iconColor: _kGreen,
            iconKind: _StatIconKind.home,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '晚归',
            value: lateReturn,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1CFF4646), Color(0x00FFFFFF)],
            ),
            iconColor: _kPurple,
            iconKind: _StatIconKind.alert,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '未打卡',
            value: absent,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1CFF4646), Color(0x00FFFFFF)],
            ),
            iconColor: _kPurple,
            iconKind: _StatIconKind.alert,
          ),
        ),
      ],
    );
  }
}

enum _StatIconKind { home, alert }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.gradient,
    required this.iconColor,
    required this.iconKind,
  });

  final String label;
  final int value;
  final LinearGradient gradient;
  final Color iconColor;
  final _StatIconKind iconKind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            right: ui(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ui(12)),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: ui(32),
                    color: _kTextDark,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: ui(16),
            top: ui(34),
            child: Container(
              width: ui(32),
              height: ui(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderHair, width: 0.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                iconKind == _StatIconKind.home
                    ? Icons.home_rounded
                    : Icons.error_outline_rounded,
                size: ui(16),
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 单个宿舍卡：header（房号 + 一键打卡）+ 学生格子网格
// =============================================================================

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.onCheckInAll,
    required this.onChangeStatus,
  });

  final _DormRoom room;
  final VoidCallback onCheckInAll;
  final void Function(_RoomStudent student, _StudentCheckStatus next)
      onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoomHeader(
            room: room,
            onCheckInAll: room.allDone ? null : onCheckInAll,
          ),
          SizedBox(height: ui(12)),
          _RoomStudentGrid(
            students: room.students,
            onChangeStatus: onChangeStatus,
          ),
        ],
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room, required this.onCheckInAll});

  final _DormRoom room;

  /// 为 `null` 时按钮置灰（已完成全员打卡时）。
  final VoidCallback? onCheckInAll;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(65),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 紫色方块 icon（用 home icon 表示宿舍）。
          Container(
            width: ui(36),
            height: ui(36),
            decoration: BoxDecoration(
              color: _kPurpleSoftBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.home_rounded,
              size: ui(22),
              color: _kPurple,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      room.roomName,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(width: ui(12)),
                    Text(
                      room.buildingDesc,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(4)),
                Text(
                  '${room.students.length}人·${room.session}·${room.deadline}',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
          _CheckInAllButton(onTap: onCheckInAll),
        ],
      ),
    );
  }
}

class _CheckInAllButton extends StatelessWidget {
  const _CheckInAllButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(220),
        height: ui(40),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                ),
          color: disabled ? _kBorderLine : null,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: ui(18),
              color: Colors.white,
            ),
            SizedBox(width: ui(6)),
            Text(
              '一键打卡',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 学生格子网格（固定 3 列）。
///
/// 宿舍卡 padding 12 → 内宽 970 − 24 = 946；3 列 + 2 * 10 gap →
/// 每格 (946 − 20) / 3 ≈ 308.6，与 Figma 308 一致，所以这里直接写 308。
class _RoomStudentGrid extends StatelessWidget {
  const _RoomStudentGrid({
    required this.students,
    required this.onChangeStatus,
  });

  final List<_RoomStudent> students;
  final void Function(_RoomStudent student, _StudentCheckStatus next)
      onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      spacing: ui(10),
      runSpacing: ui(10),
      children: [
        for (final s in students)
          SizedBox(
            width: ui(308),
            child: _RoomStudentTile(
              student: s,
              onChangeStatus: (n) => onChangeStatus(s, n),
            ),
          ),
      ],
    );
  }
}

class _RoomStudentTile extends StatelessWidget {
  const _RoomStudentTile({
    required this.student,
    required this.onChangeStatus,
  });

  final _RoomStudent student;
  final ValueChanged<_StudentCheckStatus> onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(name: student.name, url: student.avatarUrl),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  student.studentNo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          _StatusDropdown(
            current: student.status,
            onChange: onChangeStatus,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isEmpty ? '·' : name.characters.first;
    return Container(
      width: ui(40),
      height: ui(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        image: url.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: url.isNotEmpty
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontSize: ui(16),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.0,
              ),
            ),
    );
  }
}

/// 学生状态触发器（36 高紫边胶囊，匹配 Figma）。点击后弹出**全局通用**的
/// [PopupSelectorPanel] 样式弹层（白底 12 圆角 + 多层柔和阴影 + 紫色高亮 +
/// check icon），与请假申请 / 申请小课等表单的下拉视觉保持一致。
///
/// 触发器宽度自适应文案，弹层宽度固定为 120（保证「请假免检」4 字 + check
/// icon 不被裁切）。
class _StatusDropdown extends StatefulWidget {
  const _StatusDropdown({required this.current, required this.onChange});

  final _StudentCheckStatus current;
  final ValueChanged<_StudentCheckStatus> onChange;

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    final ctx = _fieldKey.currentContext;
    if (ctx == null) return;
    final ui = DashboardScaleScope.of(context).ui;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<_StudentCheckStatus>(
      anchorContext: ctx,
      items: _StudentCheckStatus.values,
      value: widget.current,
      itemLabel: (s) => s.label,
      width: ui(120),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null && selected != widget.current) {
      widget.onChange(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      borderRadius: BorderRadius.circular(ui(8)),
      onTap: _openMenu,
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderLine, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.current.label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
            SizedBox(width: ui(4)),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(16),
                color: _kTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 底部历史卡 3 列
// =============================================================================

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.records});

  final List<_HistoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < records.length; i++) ...[
          if (i > 0) SizedBox(width: ui(16)),
          Expanded(child: _HistoryCard(record: records[i])),
        ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final _HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFAF0FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                record.title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: _kTextDarker,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              _StatusBadge(status: record.status),
            ],
          ),
          SizedBox(height: ui(4)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  record.dormName,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(width: ui(4)),
              Text(
                record.date,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: ui(12),
              vertical: ui(11),
            ),
            decoration: BoxDecoration(
              color: _kCardGreyBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TimePair(
                    label: '规定时间',
                    value: record.requiredTime,
                  ),
                ),
                Expanded(
                  child: _TimePair(
                    label: '打卡时间',
                    value: record.punchTime,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _HistoryStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.27,
        ),
      ),
    );
  }
}

class _TimePair extends StatelessWidget {
  const _TimePair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.0,
          ),
        ),
        SizedBox(height: ui(5)),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 演示数据
// =============================================================================

List<_DormRoom> _demoRooms() {
  // 头像统一用 placehold，后续接 myInfo/headUrl 时按真实头像替换即可。
  _RoomStudent s(String name, String no, {_StudentCheckStatus? st}) =>
      _RoomStudent(
        name: name,
        studentNo: no,
        avatarUrl: 'https://placehold.co/40x40',
        status: st ?? _StudentCheckStatus.unchecked,
      );

  return [
    _DormRoom(
      roomName: '宿舍 A-901',
      buildingDesc: '女生公寓A座·6层',
      session: '晚查寝',
      deadline: '22:30前',
      students: [
        s('王晴', 'G3030201'),
      ],
    ),
    _DormRoom(
      roomName: '宿舍 A-902',
      buildingDesc: '女生公寓A座·6层',
      session: '晚查寝',
      deadline: '22:30前',
      students: [
        s('王晴', 'G3030202', st: _StudentCheckStatus.checked),
        s('李欣', 'G3030203', st: _StudentCheckStatus.checked),
        s('赵子', 'G3030204', st: _StudentCheckStatus.checked),
      ],
    ),
    _DormRoom(
      roomName: '宿舍 A-903',
      buildingDesc: '女生公寓A座·6层',
      session: '晚查寝',
      deadline: '22:30前',
      students: [
        s('王晴', 'G3030205', st: _StudentCheckStatus.checked),
        s('陈雨', 'G3030206', st: _StudentCheckStatus.checked),
        s('刘悦', 'G3030207', st: _StudentCheckStatus.checked),
      ],
    ),
  ];
}

List<_HistoryRecord> _demoHistory() {
  return const [
    _HistoryRecord(
      title: '晨查寝',
      status: _HistoryStatus.normal,
      dormName: '女生宿舍3号楼 612',
      date: '2026-04-02',
      requiredTime: '07:20前',
      punchTime: '07:18',
      note: '无',
    ),
    _HistoryRecord(
      title: '晨查寝',
      status: _HistoryStatus.absent,
      dormName: '女生宿舍3号楼 612',
      date: '2026-04-02',
      requiredTime: '07:20前',
      punchTime: '07:18',
      note: '无',
    ),
    _HistoryRecord(
      title: '晚查寝',
      status: _HistoryStatus.late_,
      dormName: '女生宿舍3号楼 612',
      date: '2026-04-02',
      requiredTime: '21:20前',
      punchTime: '21:23',
      note: '教师拖堂',
    ),
  ];
}
