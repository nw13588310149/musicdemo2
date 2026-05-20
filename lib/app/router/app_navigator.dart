import 'package:flutter/material.dart';

/// 应用根 [Navigator]，供无 [BuildContext] 的场景（如全局 401）跳转路由。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
