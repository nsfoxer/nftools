import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:nftools/pages/display_page.dart';
import 'package:nftools/pages/empty_page.dart';
import 'package:nftools/pages/home_page.dart';
import 'package:nftools/pages/settings/page/settings_page.dart';
import 'package:nftools/pages/sync_file_page.dart';
import 'package:nftools/pages/system_info.dart';

import '../pages/ai_page.dart';

class MyRouterConfig {
  static List<MenuData> menuDatas = [
    const MenuData("/", Icons.home, "主页", HomePage()),
    const MenuData("/display", Icons.display_settings, "显示",  DisplayPage()),
    const MenuData("/sync_file", FluentIcons.cloud_flow, "文件同步", SyncFilePage()),
    const MenuData("/systemInfo", Icons.area_chart, "系统监控", SystemInfoPage()),
    const MenuData("/ai", Icons.chat, "AI对话", AiPage()),
  ];

  static List<MenuData> footerDatas = [
    const MenuData("/settings", Icons.settings, "设置", SettingsPage()),
  ];

  // 当前路由
  static String currentUrl = "/";
  static String lastUrl = "/";
  // 可用主题上下文
  static BuildContext? themeContext;

  static Map<String, int> _routerIndex = {};

  // 查找router对应的索引
  static int findRouterIndex(String router) {
    if (_routerIndex.isEmpty) {
      int i = 0;
      for (final value in menuDatas) {
        _routerIndex[value.url] = i;
        i+=1;
      }
      for (final value in footerDatas) {
        _routerIndex[value.url] = i;
        i+=1;
      }
    }
    return _routerIndex[router]!;
  }

}

class MenuData {
  final String label;
  final String url;
  final IconData icon;
  final Widget body;
  final bool isVisible;

  const MenuData(this.url, this.icon, this.label, this.body, {this.isVisible=true});
}


