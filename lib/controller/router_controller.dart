import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/state/router_state.dart';

import '../api/base.dart' as $api;
import '../main.dart';
import '../router/router.dart';
import '../utils/log.dart';

class RouterController extends GetxController {
  final routerState = RouterState();

  // 已初始化过的服务
  final Set<String> _alreadyInitService = {};

  @override
  void onInit() async {
    super.onInit();
    await _init();
  }

  Future<void> _init() async {
    for (final value in RouterServiceData.menuDatas.values) {
      // 是否已启用
      final isEnable = await $api.getRouterEnabled(value.url);
      if (!isEnable) {
        continue;
      }

      // 设置值
      if (!value.isFooter) {
        routerState.menuDatas.add(value);
      } else {
        routerState.footerDatas.add(value);
      }
      // 启用服务
      for (final service in value.services) {
        if (_alreadyInitService.contains(service)) {
          continue;
        }
        _alreadyInitService.add(service);
        await $api.enableService(service);
      }
    }
    // 初始化控制器
    final services = <Function>[];
    services.addAll(routerState.menuDatas.map((x) => x.builderController));
    services.addAll(routerState.footerDatas.map((x) => x.builderController));
    for (final value in services) {
      value.call();
    }
    info(" --------------- ${services.length} <------------");

    routerState.router = _generateRouter();
    update();
  }

  // 生成路由
  GoRouter _generateRouter() {
    final router =
        GoRouter(navigatorKey: routerState.rootNavigatorKey, routes: [
      ShellRoute(
        navigatorKey: routerState.shellNavigatorKey,
        builder: (context, state, child) {
          MyRouterConfig.lastUrl = MyRouterConfig.currentUrl;
          MyRouterConfig.currentUrl = state.fullPath ?? '/';
          MyRouterConfig.themeContext =
              routerState.shellNavigatorKey.currentContext;
          return MainPage(
            buildContext: routerState.shellNavigatorKey.currentContext,
            child: child,
          );
        },
        routes: () {
          var routers = _generateRoute(routerState.menuDatas);
          routers.addAll(_generateRoute(routerState.footerDatas));
          return routers;
        }(),
      )
    ]);
    return router;
  }

  List<GoRoute> _generateRoute(List<MenuData> datas) {
    List<GoRoute> result = [];
    final tween1 =
        Tween(begin: const Offset(0.0, 0.2), end: const Offset(0.0, 0.0))
            .chain(CurveTween(curve: Curves.easeIn));
    final tween2 =
        Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn));
    for (var value in datas) {
      result.add(GoRoute(
          path: value.url,
          pageBuilder: (context, state) {
            // 计算页面动画
            return CustomTransitionPage(
              key: state.pageKey,
              child: value.body,
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: animation.drive(tween1),
                  child: FadeTransition(
                    opacity: secondaryAnimation.drive(tween2),
                    child: child,
                  ),
                );
              },
            );
          }));
    }
    return result;
  }

  // 计算当前索引
  int calculateIndex(BuildContext context) {
    final local = GoRouterState.of(context).uri.toString();
    List<MenuData> tmp = [];
    tmp.addAll(routerState.menuDatas);
    tmp.addAll(routerState.footerDatas);

    return tmp.indexWhere((x) => x.url == local);
  }

  Bindings generateBindings() {
    // return BindingsBuilder(() {
    //   for (final value in routerState.menuDatas) {
    //     value.builderController.call();
    //   }
    //   for (final value in routerState.footerDatas) {
    //     value.builderController.call();
    //   }
    // });
    final services = <Function>[];
    services.addAll(routerState.menuDatas.map((x) => x.builderController));
    services.addAll(routerState.footerDatas.map((x) => x.builderController));
    info("${services.length} <------------");
    return RouterServiceBindings(services);
  }
}

class RouterServiceBindings implements Bindings {
  List<Function> services = [];

  RouterServiceBindings(this.services);

  @override
  void dependencies() {
    for (final value in services) {
      value.call();
    }
  }
}
