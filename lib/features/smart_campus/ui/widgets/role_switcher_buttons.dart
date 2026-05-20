import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../state/smart_campus_state.dart';

/// 智慧校园右侧栏「身份切换」按钮组。
///
/// 按 [availableRoles] 顺序为每个身份渲染一颗按钮，命中 [selectedRole]
/// 的那颗紫底白字，其它白底深色字 + 1px `#F3F2F3` 边框。视觉与教师
/// dashboard 原先的「任课老师 / 班主任」tab (`_TeacherRoleTabButton`)
/// 保持一致，确保 admin / 班主任 / 任课老师 等多端右栏的视觉语言统一。
///
/// `Wrap` 布局：256 宽的 sidebar 里 4-5 颗按钮会自然换到第二行，无需提
/// 前判断行数。`label` 走 [SmartCampusRoleX.label]（学生端 / 任课老师 /
/// 班主任 / 宿管 / 管理员），让数据完全由 controller / 后端
/// `/teacher/teacherRole` 决定。
///
/// `onSelectRole` 应该指向 `SmartCampusController.selectRole`：tap 之
/// 后 state 变更 → SmartCampusPage 重 build → 路由到目标身份对应的
/// 大 dashboard（admin → AdminHomeView，teacher/headTeacher →
/// TeacherDashboardLayout，student → StudentDashboardLayout）。
class RoleSwitcherButtons extends StatelessWidget {
  const RoleSwitcherButtons({
    super.key,
    required this.availableRoles,
    required this.selectedRole,
    required this.onSelectRole,
  });

  final List<SmartCampusRole> availableRoles;
  final SmartCampusRole selectedRole;
  final ValueChanged<SmartCampusRole> onSelectRole;

  @override
  Widget build(BuildContext context) {
    if (availableRoles.isEmpty) {
      return const SizedBox.shrink();
    }
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      spacing: ui(8),
      runSpacing: ui(8),
      children: [
        for (final role in availableRoles)
          _RoleSwitcherButton(
            label: role.label,
            active: role == selectedRole,
            onTap: () => onSelectRole(role),
          ),
      ],
    );
  }
}

class _RoleSwitcherButton extends StatelessWidget {
  const _RoleSwitcherButton({
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
    return InkWell(
      borderRadius: BorderRadius.circular(ui(8)),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8741FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: active ? Colors.white : const Color(0xFF0B081A),
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}
