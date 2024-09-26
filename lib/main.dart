import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nftools/controller/GlobalController.dart';
import 'package:nftools/controller/MainPageController.dart';
import 'package:nftools/router/router.dart';
import 'package:nftools/state/MainPageState.dart';
import 'package:nftools/utils/page-cache.dart';
import 'package:tolyui/tolyui.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var fonts = Platform.isWindows ? "微软雅黑" : null;
    return GetMaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
          brightness: Brightness.light, useMaterial3: true, fontFamily: fonts),
      darkTheme: ThemeData(
          brightness: Brightness.dark, useMaterial3: true, fontFamily: fonts),
      initialBinding: GlobalControllerBindings(),
      home: Scaffold(
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
    );
  }
}

class MenuBar extends StatelessWidget {
  MenuBar({Key? key}) : super(key: key);

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
        tail: (type) => const Padding(
          padding: EdgeInsets.only(bottom: 15),
          child: Icon(Icons.settings),
        ),
      );
    });
  }
}

class MyPage extends StatefulWidget {
  const MyPage({Key? key, required this.desc}) : super(key: key);
  final String desc;

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    print(widget.desc);
    return Center(
      child: Text("页面:" + widget.desc),
    );
  }
}

class PageBody extends StatelessWidget {
  PageBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MainPageController>(builder: (logic) {
      var pageState = logic.pageState;
      return PageView(
        scrollDirection: Axis.vertical,
        controller: pageState.pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: MyRouterConfig.pages,
      );
    });
  }
}
