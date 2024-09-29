import 'package:flutter/material.dart';
import 'package:nftools/pages/display_page.dart';
import 'package:nftools/pages/main_page.dart';
import 'package:nftools/utils/page-cache.dart';

class MyRouterConfig {
  static List<_MenuData> menuDatas = [
    const _MenuData(Icons.home, "/", "主页", KeepAliveWrapper(child: MainPage())),
    const _MenuData(Icons.display_settings, "/display", "显示",
        KeepAliveWrapper(child: DisplayPage())),
    const _MenuData(
        Icons.explore,
        "/test",
        "测试",
        KeepAliveWrapper(
          child: Text("data2"),
        )),
  ];

  static _MenuData settingData = const _MenuData(
      Icons.settings,
      "/setting",
      "设置",
      KeepAliveWrapper(
        child: Text("setting"),
      ));

  static List<Widget> pages = menuDatas.map((x) => x.page).toList();
}

class _MenuData {
  final String label;
  final IconData icon;
  final String router;
  final Widget page;

  const _MenuData(this.icon, this.router, this.label, this.page);
}
