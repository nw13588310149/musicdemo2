import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.routeName,
    required this.title,
    super.key,
  });

  final String routeName;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('页面迁移中', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text('当前路由: $routeName'),
            ],
          ),
        ),
      ),
    );
  }
}
