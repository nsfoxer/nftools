import 'package:flutter/material.dart';
import 'package:nftools/pages/display_page.dart';
import 'package:nftools/pages/main_page.dart';

class MyRouterConfig {
  static List<MenuData> menuDatas = [
    const MenuData("/", Icons.home, "主页",Text("main"), null, false),
    const MenuData("/display", Icons.display_settings, "显示",  DisplayPage(), null, false),
    const MenuData("/test", Icons.explore, "测试", Text("data2"), null, true),
    const MenuData("/test/A", Icons.explore, "测试1", Text("data3"), "/test", false),
    const MenuData("/test/B", Icons.explore, "测试2", Text("data4"), "/test", false),
  ];

  static List<MenuData> footerDatas = [
    const MenuData("/settings", Icons.settings, "设置", Text("setting"), null, false),
  ];

}

class MenuData {
  final String label;
  final String url;
  final IconData icon;
  final String? parentUrl;
  final Widget body;
  final bool isParent;

  const MenuData(this.url, this.icon, this.label, this.body, this.parentUrl, this.isParent);
}


