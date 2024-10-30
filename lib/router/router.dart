import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:nftools/pages/display_page.dart';
import 'package:nftools/pages/system_info.dart';

class MyRouterConfig {
  static List<MenuData> menuDatas = [
    const MenuData("/", Icons.home, "主页",Text("main")),
    const MenuData("/display", Icons.display_settings, "显示",  DisplayPage()),
    const MenuData("/test", Icons.explore, "测试", Text("data2")),
    MenuData("/systemInfo", Icons.area_chart, "系统监控", SystemInfoPage()),
  ];

  static List<MenuData> footerDatas = [
    const MenuData("/settings", Icons.settings, "设置", Text("setting")),
  ];

}

class MenuData {
  final String label;
  final String url;
  final IconData icon;
  final Widget body;

  const MenuData(this.url, this.icon, this.label, this.body);
}


