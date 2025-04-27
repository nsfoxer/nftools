import 'dart:io';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/api/api.dart';
import 'package:nftools/api/display_api.dart';
import 'package:nftools/api/base.dart' as $base_api;
import 'package:nftools/common/constants.dart';
import 'package:nftools/controller/router_controller.dart';
import 'package:nftools/router/router.dart';
import 'package:nftools/src/bindings/bindings.dart';
import 'package:nftools/utils/utils.dart';
import 'package:rinf/rinf.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // 1. 初始化后端
  await initializeRust(assignRustSignal);
  initMsg();

  // 2，初始化 window manager
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 3. 初始化托盘
  initSystemTray();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp>
    with WindowListener, TrayListener, WidgetsBindingObserver {
  Color primaryColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    Get.put<RouterController>(RouterController(), permanent: true);
    // 添加window——manager监听器
    windowManager.addListener(this);
    trayManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  void _init() async {
    await windowManager.setPreventClose(true);
    // 等待后端服务启动
    await Future.delayed(const Duration(milliseconds: 500));
    primaryColor = await getSystemColor();
    setState(() {});
  }

  void _displayApp() async {
    if (!await windowManager.isVisible()) {
      windowManager.show();
    } else {
      windowManager.hide();
    }
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    _displayApp();
    super.onTrayIconMouseDown();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
    super.onTrayIconRightMouseDown();
  }

  void _appExit() async {
    // 等待后端服务退出
    await $base_api.closeRust();
    finalizeRust(); // Shut down the `tokio` Rust runtime.
    debugPrint("flutter stop");
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'display') {
      _displayApp();
    } else if (menuItem.key == 'exit') {
      _appExit();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _init();
    super.didChangePlatformBrightness();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Color> swatch = {
      "normal": primaryColor,
    };
    var fonts = "oppo_sans";

    var m = FluentThemeData(
        brightness: Brightness.light,
        fontFamily: fonts,
        tooltipTheme:
            const TooltipThemeData(waitDuration: Duration(milliseconds: 300)),
        accentColor: AccentColor.swatch(swatch));
    if (isDark(context)) {
      m = FluentThemeData(
          brightness: Brightness.dark,
          fontFamily: fonts,
          tooltipTheme:
              const TooltipThemeData(waitDuration: Duration(milliseconds: 300)),
          accentColor: AccentColor.swatch(swatch));
    }
    final routerLogic = Get.find<RouterController>();
    var bgColor = m.resources.solidBackgroundFillColorTertiary;
    return GetMaterialApp.router(
      themeMode: ThemeMode.dark,
      theme: FlexThemeData.light(
          primary: primaryColor,
          background: bgColor,
          surface: bgColor,
          fontFamily: fonts),
      darkTheme: FlexThemeData.dark(
          primary: primaryColor,
          background: bgColor,
          surface: bgColor,
          fontFamily: fonts),
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FluentLocalizations.localizationsDelegates,
      routeInformationParser:
          routerLogic.routerState.router.routeInformationParser,
      routerDelegate: routerLogic.routerState.router.routerDelegate,
      routeInformationProvider:
          routerLogic.routerState.router.routeInformationProvider,
      builder: (context, child) {
        return AnimatedFluentTheme(
          data: m,
          child: child!,
        );
      },
    );
  }
}

class MainPage extends StatelessWidget {
  final BuildContext? buildContext;
  final Widget child;

  const MainPage({super.key, this.buildContext, required this.child});

  static List<NavigationPaneItem> _buildPaneItem(
      List<MenuData> datas, BuildContext context) {
    List<NavigationPaneItem> children = [];
    for (var value in datas) {
      if (value.children == null || value.children!.isEmpty) {
        children.add(PaneItem(
            icon: Icon(value.icon),
            title: Text(value.label),
            body: value.body,
            onTap: () {
              if (MyRouterConfig.currentUrl != value.url) {
                context.push(value.url);
              }
            }));
        continue;
      }
      children.add(PaneItemExpander(
          icon: Icon(value.icon),
          title: Text(value.label),
          body: value.body,
          onTap: () {
            if (MyRouterConfig.currentUrl != value.url) {
              context.push(value.url);
            }
          },
          items: _buildPaneItem(value.children!.values.toList(), context)));
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    final bg = FluentTheme.of(context).navigationPaneTheme.backgroundColor;
    return GetBuilder<RouterController>(
        builder: (logic) => NavigationView(
              appBar: NavigationAppBar(
                automaticallyImplyLeading: false,
                leading: () {
                  final enabled =
                      buildContext != null && logic.routerState.router.canPop();
                  final onPressed = enabled
                      ? () {
                          if (logic.routerState.router.canPop()) {
                            context.pop();
                          }
                        }
                      : null;
                  return PaneItem(
                          icon: const Icon(FluentIcons.back),
                          enabled: enabled,
                          body: const SizedBox.shrink())
                      .build(context, false, onPressed,
                          displayMode: PaneDisplayMode.compact);
                }(),
                title: GestureDetector(
                    onTapDown: (_) {
                      windowManager.startDragging();
                    },
                    child: Container(
                        height: double.infinity,
                        width: double.infinity,
                        color: Colors.transparent,
                        child: const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(Constants.appName),
                        ))),
                actions: Container(
                    margin: const EdgeInsets.fromLTRB(5, 0, 0, 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 最小化按钮
                        SizedBox(
                            height: 30,
                            width: 45,
                            child: IconButton(
                                iconButtonMode: IconButtonMode.small,
                                icon: Icon(
                                  FluentIcons.chrome_minimize,
                                  size: typography.caption?.fontSize,
                                ),
                                onPressed: () {
                                  windowManager.minimize();
                                })),
                        // 最大化按钮
                        SizedBox(
                            height: 30,
                            width: 45,
                            child: IconButton(
                                iconButtonMode: IconButtonMode.small,
                                icon: Icon(
                                  FluentIcons.chrome_restore,
                                  size: typography.caption?.fontSize,
                                ),
                                onPressed: () async {
                                  if (await windowManager.isMaximized()) {
                                    windowManager.unmaximize();
                                  } else {
                                    windowManager.maximize();
                                  }
                                })),
                        // 关闭窗口按钮
                        SizedBox(
                            height: 30,
                            width: 45,
                            child: IconButton(
                                iconButtonMode: IconButtonMode.small,
                                icon: Icon(
                                  FluentIcons.chrome_close,
                                  size: typography.caption?.fontSize,
                                ),
                                style: ButtonStyle(backgroundColor:
                                    WidgetStateColor.resolveWith((state) {
                                  if (state.contains(WidgetState.hovered)) {
                                    return const Color.fromARGB(
                                        255, 192, 43, 28);
                                  }
                                  return bg ?? Colors.transparent;
                                })),
                                onPressed: () {
                                  windowManager.hide();
                                })),
                      ],
                    )),
              ),
              pane: NavigationPane(
                selected: logic.calculateIndex(context),
                displayMode: PaneDisplayMode.compact,
                items: _buildPaneItem(logic.routerState.menuData, context),
                footerItems:
                    _buildPaneItem(logic.routerState.footerData, context),
              ),
              paneBodyBuilder: (item, child) {
                return FocusTraversalGroup(child: this.child);
              },
            ));
  }
}

// 初始化系统托盘
Future<void> initSystemTray() async {
  String path =
      Platform.isWindows ? 'assets/img/nftools.ico' : 'assets/img/nftools.png';

  // We first init the systray menu
  await trayManager.setIcon(path);
  if (Platform.isWindows) {
    await trayManager.setToolTip(Constants.appName);
  }
  Menu menu = Menu(
    items: [
      MenuItem(
        key: 'display',
        label: '显示/隐藏',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit',
        label: '退出',
      ),
    ],
  );
  await trayManager.setContextMenu(menu);
}
