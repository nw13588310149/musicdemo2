import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthInputField extends StatelessWidget {
  const AuthInputField({
    required this.hintText,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.textInputAction,
    this.inputFormatters,
    super.key,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: TextField(
        enabled: enabled,
        onChanged: onChanged,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: 16,
        style: const TextStyle(
          fontSize: 14,
          height: 1.2,
          color: Color(0xFF2A2338),
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFB6B5BB)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.96),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: _border,
          enabledBorder: _border,
          focusedBorder: _border.copyWith(
            borderSide: const BorderSide(color: Color(0xFFE5DFFE), width: 1),
          ),
          disabledBorder: _border,
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          prefixIcon: prefixIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                  child: prefixIcon,
                ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  static final OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFF3F2F3), width: 1),
  );
}
