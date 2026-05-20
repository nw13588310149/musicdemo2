import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.text,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String text;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF6B38F2), Color(0xFF8741FF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x146B38F2),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 12 / 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
        ),
      ),
    );
  }
}

class AuthAgreementRow extends StatelessWidget {
  const AuthAgreementRow({
    required this.checked,
    required this.onChanged,
    super.key,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: Checkbox(
            value: checked,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            side: const BorderSide(color: Color(0xFF8741FF), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF8741FF);
              }
              return Colors.white;
            }),
            onChanged: (value) => onChanged(value ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '同意并愿意遵守',
                style: TextStyle(
                  fontSize: 14,
                  height: 12 / 14,
                  color: Color(0xFF0B081A),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, RoutePaths.xieyi2),
                child: const Text(
                  '《音乐之路服务协议》',
                  style: TextStyle(
                    fontSize: 14,
                    height: 12 / 14,
                    color: Color(0xFF856FE2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthBottomActionLine extends StatelessWidget {
  const AuthBottomActionLine({
    required this.prefix,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFF1F1F4), thickness: 1, height: 1),
        ),
        const SizedBox(width: 14),
        Text(
          prefix,
          style: const TextStyle(
            fontSize: 14,
            height: 12 / 14,
            color: Color(0xFF0B081A),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 14,
              height: 12 / 14,
              color: Color(0xFF8741FF),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Divider(color: Color(0xFFF1F1F4), thickness: 1, height: 1),
        ),
      ],
    );
  }
}

class AuthSmsButton extends StatelessWidget {
  const AuthSmsButton({
    required this.text,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF6B38F2), Color(0xFF8741FF)],
        ),
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 14,
            height: 12 / 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
