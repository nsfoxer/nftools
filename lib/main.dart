import 'dart:io';
import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  static List<NavigationPaneItem> _buildPaneItem(List<MenuData>? datas) {
    List<NavigationPaneItem> children = [];
    if (datas == null) {
      return children;
    }
    for (var value in datas) {
      if (value.children != null) {
        children.add(PaneItemExpander(icon: Icon(value.icon), title: Text(value.label), items: _buildPaneItem(value.children), body: value.body));
      } else {
        children.add(PaneItem(icon: Icon(value.icon), title: Text(value.label), body: value.body));
      }
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    var fonts = Platform.isWindows ? "微软雅黑" : null;
    var m = FluentThemeData(brightness: Brightness.light, fontFamily: fonts);
    if (View.of(context).platformDispatcher.platformBrightness.isDark) {
      m = FluentThemeData(brightness: Brightness.dark, fontFamily: fonts);
    }
    return AnimatedFluentTheme(
        data: m,
        child: GetMaterialApp(
          title: 'Flutter Demo',
          themeMode: mode,
          localizationsDelegates: FluentLocalizations.localizationsDelegates,
          initialBinding: GlobalControllerBindings(),
          home: GetBuilder<MainPageController>(builder: (logic) {
            return NavigationView(
              appBar: NavigationAppBar(title: Text("appbar")),
              pane: NavigationPane(
                  onChanged: (v) {
                    logic.selectPage(v);
                  },
                  selected: logic.pageState.selected,
                  header: Text("paneHeader"),
                  autoSuggestBox: AutoSuggestBox(
                    items: [AutoSuggestBoxItem(value: "value", label: "label")],
                  ),
                  autoSuggestBoxReplacement: Icon(Icons.search),
                  items: _buildPaneItem(MyRouterConfig.menuDatas),
                  footerItems: _buildPaneItem(MyRouterConfig.footerDatas),
              ),
            );
          }),
        ));
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
