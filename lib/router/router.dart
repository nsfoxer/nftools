import 'package:flutter/material.dart';
import 'package:nftools/pages/display_page.dart';
import 'package:nftools/pages/main_page.dart';
import 'package:nftools/utils/page-cache.dart';

class MyRouterConfig {
  static List<MenuData> menuDatas = [
    const MenuData(Icons.home, "主页", null, MainPage()),
    const MenuData(Icons.display_settings, "显示", null, DisplayPage()),
    const MenuData(Icons.explore, "测试", null, Text("data2")),
  ];

  static List<MenuData> footerDatas = [
    const MenuData(Icons.settings, "设置", null, Text("setting")),
  ];
}

class MenuData {
  final String label;
  final IconData icon;
  final List<MenuData>? children;
  final Widget body;

  const MenuData(this.icon, this.label, this.children, this.body);
}
