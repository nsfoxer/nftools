import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nftools/api/api.dart';
import 'package:nftools/controller/GlobalController.dart';
import 'package:nftools/controller/MainPageController.dart';
import 'package:nftools/messages/generated.dart';
import 'package:nftools/router/router.dart';
import 'package:rinf/rinf.dart';
import 'package:tolyui/tolyui.dart';

void main() async {
  // 初始化
  await initializeRust(assignRustSignal);
  initMsg();

  // 启动GUI
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var fonts = Platform.isWindows ? "微软雅黑" : null;
    return TolyMessage(
        child: GetMaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
          brightness: Brightness.light, useMaterial3: true, fontFamily: fonts),
      darkTheme: ThemeData(
          brightness: Brightness.dark, useMaterial3: true, fontFamily: fonts),
      initialBinding: GlobalControllerBindings(),
      home: const Scaffold(
        body: Row(
          children: [
            MenuBar(),
            Expanded(
              flex: 8,
              child: PageBody(),
            ),
          ],
        ),
      ),
    ));
  }
}

class MenuBar extends StatelessWidget {
  const MenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MainPageController>(builder: (logic) {
      var pageState = logic.pageState;
      var menus = MyRouterConfig.menuDatas
          .map((x) => MenuMeta(label: x.label, icon: x.icon, router: x.router))
          .toList();
      return TolyRailMenuBar(
        width: 72,
        maxWidth: 200,
        enableWidthChange: true,
        menus: menus,
        onSelected: logic.select,
        activeId: pageState.selected,
        leading: (type) => Container(
            margin: const EdgeInsets.all(6),
            child: const CircleAvatar(
              radius: 24,
              child: Text("张"),
            )),
        tail: (type) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: TolyAction(
                  child:
                      Icon(Get.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  onTap: () {
                    Get.changeThemeMode(
                        Get.isDarkMode ? ThemeMode.light : ThemeMode.dark);
                  }),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: GetBuilder<MainPageController>(
                  builder: (logic) => TolyAction(
                      child: const Icon(Icons.settings),
                      onTap: () {
                        logic.openSetting();
                      })),
            )
          ],
        ),
      );
    });
  }
}

class PageBody extends StatelessWidget {
  const PageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MainPageController>(builder: (logic) {
      var pageState = logic.pageState;
      var pages = MyRouterConfig.pages;
      pages.add(MyRouterConfig.settingData.page);
      return PageView(
        pageSnapping: false,
        scrollDirection: Axis.vertical,
        controller: pageState.pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      );
    });
  }
}
