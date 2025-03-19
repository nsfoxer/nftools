import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

import '../router/router.dart';

class RouterState {
  final List<MenuData> menuDatas = [];
  final List<MenuData> footerDatas = [];
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();
  GoRouter router = GoRouter(routes: []);
}