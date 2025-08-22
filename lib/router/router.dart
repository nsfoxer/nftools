import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:meta/meta.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/pages/display_page.dart';
import 'package:nftools/pages/home_page.dart';
import 'package:nftools/pages/tar_pdf/controller/tar_pdf_controller.dart';
import 'package:nftools/pages/utils/controller/image_split_controller.dart';
import 'package:nftools/pages/utils/page/image_split_page.dart';
import 'package:nftools/pages/settings/page/settings_page.dart';
import 'package:nftools/pages/sync_file_page.dart';
import 'package:nftools/pages/utils/page/qr_page.dart';
import 'package:nftools/pages/utils/page/text_diff_page.dart';
import 'package:nftools/pages/utils/page/text_tool_page.dart';
import 'package:nftools/pages/work/controller/pwd_expire_controller.dart';
import 'package:nftools/pages/work/controller/work_controller.dart';
import 'package:nftools/pages/work/page/pwd_expire_page.dart';
import 'package:nftools/pages/work/page/sms_limit_page.dart';
import 'package:nftools/pages/work/page/work_page.dart';

import '../controller/ai_controller.dart';
import '../controller/display_controller.dart';
import '../controller/display_mode_controller.dart';
import '../controller/main_page_controller.dart';
import '../controller/sync_file_controller.dart';
import '../controller/system_mode_controller.dart';
import '../pages/ai_page.dart';
import '../pages/settings/controller/about_controller.dart';
import '../pages/settings/controller/auto_start_controller.dart';
import '../pages/tar_pdf/page/tar_pdf_page.dart';
import '../pages/test/page/test_page.dart';
import '../pages/utils/controller/qr_controller.dart';
import '../pages/utils/controller/text_diff_controller.dart';
import '../pages/utils/controller/text_tool_controller.dart';
import '../pages/utils/page/utils_page.dart';
import '../pages/work/controller/sms_limit_controller.dart';
import '../pages/work/controller/user_code_controller.dart';
import '../pages/work/page/user_code_page.dart';

/// 路由定义
///
/// 使用 `Get.put(xxx)` 注册路由， 则该controller持久性存在
/// 使用 `Get.lazyPut(xxx)` 注册路由， 则该controller只在第一次使用时才会创建，且切换页面时会调用dispose
@Immutable()
class RouterServiceData {
  const RouterServiceData();

  static final Map<String, MenuData> menuData = {
    "/": MenuData("/", Icons.home, "主页", const WorkPage(), [ServiceNameConstant.displayMode, ServiceNameConstant.utils], () {
      Get.put<WorkController>(WorkController(), permanent: true);
    }),
    "/userCode": MenuData("/userCode", Icons.code, "获取验证码", const UserCodePage(), [ ServiceNameConstant.utils], () {
      Get.lazyPut<UserCodeController>(()=>UserCodeController(), fenix: true);
    }),
    "/smsLimit": MenuData("/smsLimit", Icons.sms, "去除短信限制", const SmsLimitPage(), [ ServiceNameConstant.utils], () {
      Get.lazyPut<SmsLimitController>(()=>SmsLimitController(), fenix: true);
    }),
    "/pwdExpireReset": MenuData("/pwdExpireReset", Icons.password, "密码过期重置", const PwdExpirePage(), [ ServiceNameConstant.utils], () {
      Get.lazyPut<PwdExpireController>(()=>PwdExpireController(), fenix: true);
    }),
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
