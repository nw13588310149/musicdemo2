import 'package:flutter/material.dart';

class LegacyPlaceholderContent extends StatelessWidget {
  const LegacyPlaceholderContent({
    required this.routeName,
    required this.title,
    super.key,
  });

  final String routeName;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Color(0xFF171A20),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '页面迁移中',
              style: TextStyle(fontSize: 15, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 8),
            Text(
              routeName,
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}
