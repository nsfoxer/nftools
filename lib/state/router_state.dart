import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/pages/init.dart';

import '../router/router.dart';

class RouterState {
  final List<MenuData> menuData = [];
  final List<MenuData> footerData = [];
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  // 所有已初始化的url列表 用于计算索引
  final List<String> urlData = [];

  // 页面路由 初始化值为 loading
  GoRouter router = GoRouter(routes: [
    GoRoute(path: "/", builder: (context, state) => const InitPage())
  ]);
}