import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:meta/meta.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/pages/display_page.dart';
import 'package:nftools/pages/home_page.dart';
import 'package:nftools/pages/settings/page/settings_page.dart';
import 'package:nftools/pages/sync_file_page.dart';
import 'package:nftools/pages/utils/controller/video_test_controller.dart';
import 'package:nftools/pages/utils/page/text_diff_page.dart';
import 'package:nftools/pages/utils/page/text_tool_page.dart';
import 'package:nftools/pages/utils/page/video_test_page.dart';

import '../controller/ai_controller.dart';
import '../controller/display_controller.dart';
import '../controller/display_mode_controller.dart';
import '../controller/main_page_controller.dart';
import '../controller/sync_file_controller.dart';
import '../controller/system_mode_controller.dart';
import '../pages/ai_page.dart';
import '../pages/settings/controller/about_controller.dart';
import '../pages/settings/controller/auto_start_controller.dart';
import '../pages/utils/controller/text_diff_controller.dart';
import '../pages/utils/controller/text_tool_controller.dart';
import '../pages/utils/page/utils_page.dart';

@Immutable()
class RouterServiceData {
  const RouterServiceData();

  static final Map<String, MenuData> menuData = {
    "/": MenuData("/", Icons.home, "主页", const HomePage(), [ServiceNameConstant.displayMode], () {
      Get.lazyPut<MainPageController>(() => MainPageController(), fenix: true);
    }),

    "/display": MenuData("/display", Icons.display_settings, "显示", const DisplayPage(), [
      ServiceNameConstant.displayMode, ServiceNameConstant.displayLight, ServiceNameConstant.utils
      ], () {
      Get.lazyPut<DisplayController>(() => DisplayController(), fenix: true);
      Get.lazyPut<DisplayModeController>(() => DisplayModeController(),  fenix: true);
      Get.lazyPut<SystemModeController>(() => SystemModeController(), fenix: true);
    }),

    "/sync_file": MenuData("/sync_file", FluentIcons.cloud_flow, "文件同步", const SyncFilePage(), [ServiceNameConstant.syncFile], () {
      Get.put<SyncFileController>(SyncFileController(), permanent: true);
    }),

    "/ai": MenuData("/ai", Icons.chat, "AI对话", const AiPage(), [ServiceNameConstant.ai], () {
      Get.put<AiController>(AiController(), permanent: true);
    }),

    "/utils": MenuData("/utils", FluentIcons.toolbox, "工具", const UtilsPage(), [], () {
    }, children: {
      "/utils/diffText": MenuData("/utils/diffText", FluentIcons.diff_side_by_side, "文本对比", const TextDiffPage(), [], () {
        Get.put<TextDiffController>(TextDiffController(), permanent: true);
      }),
      "/utils/textTool": MenuData("/utils/textTool", FluentIcons.text_box, "文本工具", const TextToolPage(), [], () {
        Get.put<TextToolController>(TextToolController(), permanent: true);
      }),
      "/utils/videoTest": MenuData("/utils/videoTest", FluentIcons.text_box, "video测试", VideoTestPage(), [], () {
        Get.put<VideoTestController>(VideoTestController(), permanent: true);
      })
    }),

    "/settings": MenuData("/settings", Icons.settings, "设置", const SettingsPage(), [ServiceNameConstant.about, ServiceNameConstant.utils, ServiceNameConstant.autoStart], () {
      Get.lazyPut<AutoStartController>(() => AutoStartController(), fenix: true);
      Get.put<AboutController>(AboutController(), permanent: true);
    }, isFooter: true),
  };
}

// 当前路由信息
class MyRouterConfig {
  // 当前路由
  static String currentUrl = "/";
  static String lastUrl = "/";

  // 可用主题上下文
  static BuildContext? themeContext;
}

// 路由数据
@Immutable()
class MenuData {
  // 页面名称
  final String label;
  // 页面地址
  final String url;
  // 页面图标
  final IconData icon;
  // 页面组件
  final Widget body;
  // 页面依赖的后台服务
  final List<String> services;
  // 页面依赖的控制器初始化
  final Function builderController;
  // 是否为父级
  final Map<String, MenuData>? children;
  // 是否为底部
  final bool isFooter;

  const MenuData(this.url, this.icon, this.label, this.body, this.services,
      this.builderController,
      {this.children, this.isFooter = false});

  @override
  String toString() {
    return 'MenuData{label: $label, url: $url, icon: $icon, body: $body, services: $services, builderController: $builderController, children: $children, isFooter: $isFooter}';
  }
}
