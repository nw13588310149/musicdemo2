import 'package:flutter/material.dart';

/// 与资料页「生日」日期选择器（`info_page` → `_editBirthday`）一致的主题色。
const Color appPickerPrimary = Color(0xFF8741FF);
const Color appPickerOnSurface = Color(0xFF0B081A);

/// 供 `showDatePicker` / `showTimePicker` 的 [builder] 使用，统一紫色强调与按钮色。
ThemeData appPickerThemeFor(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: appPickerPrimary,
      onPrimary: Colors.white,
      onSurface: appPickerOnSurface,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: appPickerPrimary),
    ),
  );
}

/// `builder: appPickerDialogTheme` 传入 Material 日期/时间对话框。
Widget appPickerDialogTheme(BuildContext context, Widget? child) {
  return Theme(
    data: appPickerThemeFor(context),
    child: child ?? const SizedBox.shrink(),
  );
}
