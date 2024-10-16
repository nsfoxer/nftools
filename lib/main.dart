import 'dart:io';
import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/api/api.dart';
import 'package:nftools/controller/GlobalController.dart';
import 'package:nftools/controller/MainPageController.dart';
import 'package:nftools/messages/generated.dart';
import 'package:nftools/router/router.dart';
import 'package:rinf/rinf.dart';

void main() async {
  // 初始化
  await initializeRust(assignRustSignal);
  initMsg();

  // 启动GUI
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode mode = ThemeMode.system;
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: () async {
        finalizeRust(); // Shut down the `tokio` Rust runtime.
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var fonts = Platform.isWindows ? "微软雅黑" : null;
    var m = FluentThemeData(brightness: Brightness.light, fontFamily: fonts);
    if (View.of(context).platformDispatcher.platformBrightness.isDark) {
      m = FluentThemeData(brightness: Brightness.dark, fontFamily: fonts);
    }
    return
         GetMaterialApp(
          title: 'Flutter Demo',
          initialBinding: GlobalControllerBindings(),
          defaultTransition: Transition.native,
           home:FluentApp.router(
            theme: m,
            title: "App Title",
            builder: (context, child) {
              debugPrint("build child <----");
              return child!;
            },
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
            routeInformationProvider: router.routeInformationProvider,
          ),
        );
  }
}

List<GoRoute> _generateRoute(List<MenuData> datas) {
  List<GoRoute> result = [];
  for (var value in datas) {
    result.add(GoRoute(path: value.url, builder: (context, state) => value.body));
  }

  return result;
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final router = GoRouter(navigatorKey: rootNavigatorKey, routes: [
  ShellRoute(navigatorKey: _shellNavigatorKey, builder: (context, state, child) {
    return MainPage(
      buildContext: _shellNavigatorKey.currentContext,
      child: child,
    );
  }, routes: () {
    var routers = _generateRoute(MyRouterConfig.menuDatas);
    routers.addAll(_generateRoute(MyRouterConfig.footerDatas));
    return routers;
  }(),
  )
]);

class MainPage extends StatelessWidget {
  final BuildContext? buildContext;
  final Widget child;

  const MainPage({super.key, this.buildContext, required this.child});

  static List<NavigationPaneItem> _buildPaneItem(List<MenuData> datas, BuildContext context) {
    List<NavigationPaneItem> children = [];
    for (var value in datas) {
      if (value.isParent) {
        List<NavigationPaneItem> items = [];
        for (var value2 in datas) {
          if (value2.parentUrl == value.url) {
            items.add(PaneItem(icon: Icon(value2.icon), title: Text(value2.label), body: value2.body, onTap: () {
              context.go(value2.url);
            }));
          }
        }
        children.add(PaneItemExpander(icon: Icon(value.icon), title: Text(value.label),
            items: items, body: value.body,
            onTap: () {
              context.go(value.url);
            }));
      } else if (value.parentUrl == null) {
        children.add(PaneItem(icon: Icon(value.icon), title: Text(value.label), body: value.body, onTap: () {
          context.go(value.url);
        }));
      }
    }
    return children;
  }

  int _calculateIndex(BuildContext context) {
    final local = GoRouterState.of(context).uri.toString();
    List<MenuData> tmp = [];
    tmp.addAll(MyRouterConfig.menuDatas);
    tmp.addAll(MyRouterConfig.footerDatas);

    return tmp.indexWhere((x) => x.url == local);
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        leading: () {
          final enabled = buildContext != null && router.canPop();
          final onPressed = enabled ? () {
            if (router.canPop()) {
              context.pop();
            }
          }: null;
          return PaneItem(icon: Icon(FluentIcons.back), enabled: enabled, body: SizedBox.shrink())
              .build(context, false, onPressed, displayMode: PaneDisplayMode.compact);
        }(),
        title: Text("titles"),
        actions: Text("actions"),
      ),
      pane: NavigationPane(
        selected: _calculateIndex(context),
        header: Text("pane Header"),
        indicator: StickyNavigationIndicator(),
        items: _buildPaneItem(MyRouterConfig.menuDatas, context),
        footerItems: _buildPaneItem(MyRouterConfig.footerDatas, context),
      ),
      paneBodyBuilder: (item, child) {
        debugPrint(item.toString());
        return FocusTraversalGroup(child: this.child);
      },
    );
  }

}




// class MenuBar extends StatelessWidget {
//   const MenuBar({super.key, required this.changeTheme});
//   final ValueChanged<bool> changeTheme;
//
//   @override
//   Widget build(BuildContext context) {
//     return GetBuilder<MainPageController>(builder: (logic) {
//       var pageState = logic.pageState;
//       var menus = MyRouterConfig.menuDatas
//           .map((x) => MenuMeta(label: x.label, icon: x.icon, router: x.router))
//           .toList();
//       return NavigationBar(
//         activeId: pageState.selected,
//         leading: (type) => Container(
//             margin: const EdgeInsets.all(6),
//             child: const CircleAvatar(
//               radius: 24,
//               child: Text("张"),
//             )),
//         tail: (type) => Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.only(bottom: 15),
//               child: TolyAction(
//                   child:
//                       Icon(Get.isDarkMode ? Icons.dark_mode : Icons.light_mode),
//                   onTap: () {
//                     changeTheme(!Get.isDarkMode);
//                   }),
//             ),
//             Padding(
//               padding: const EdgeInsets.only(bottom: 15),
//               child: GetBuilder<MainPageController>(
//                   builder: (logic) => TolyAction(
//                       child: const Icon(Icons.settings),
//                       onTap: () {
//                         logic.openSetting();
//                       })),
//             )
//           ],
//         ),
//       );
//     });
//   }
// }
//
// class PageBody extends StatelessWidget {
//   const PageBody({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return GetBuilder<MainPageController>(builder: (logic) {
//       var pageState = logic.pageState;
//       var pages = MyRouterConfig.pages;
//       pages.add(MyRouterConfig.settingData.page);
//       return PageView(
//         pageSnapping: false,
//         scrollDirection: Axis.vertical,
//         controller: pageState.pageController,
//         physics: const NeverScrollableScrollPhysics(),
//         children: pages,
//       );
//     });
//   }
// }
