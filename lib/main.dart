import 'dart:io';
import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/api/api.dart';
import 'package:nftools/api/display_api.dart';
import 'package:nftools/api/utils.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/controller/GlobalController.dart';
import 'package:nftools/messages/generated.dart';
import 'package:nftools/router/router.dart';
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
    size: Size(800, 600),
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
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp>
    with WindowListener, TrayListener, WidgetsBindingObserver {
  late final AppLifecycleListener _listener;
  Color primaryColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    // 添加window——manager监听器
    windowManager.addListener(this);
    trayManager.addListener(this);
    // 等待后端服务退出
    _listener = AppLifecycleListener(
      onExitRequested: () async {
        finalizeRust(); // Shut down the `tokio` Rust runtime.
        return AppExitResponse.exit;
      },
    );
    WidgetsBinding.instance.addObserver(this);
    _initColor(false);
  }

  void _initColor(bool wait) async {
    primaryColor = await getSystemColor();
    setState(() {});
    if (!wait) {
      return;
    }
    // linux后端需要等待才能得到正确的值，否则会是上次的值
    final duration = Platform.isLinux ? const Duration(seconds: 6): const Duration(seconds: 2);
    await Future.delayed(duration);
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
  void onTrayIconMouseDown() {
    _displayApp();
    super.onTrayIconMouseDown();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
    super.onTrayIconRightMouseDown();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'display') {
      _displayApp();
    } else if (menuItem.key == 'exit') {
      windowManager.close();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _listener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _initColor(true);
    super.didChangePlatformBrightness();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Color> swatch = {
      "normal": primaryColor,
    };
    var fonts = Platform.isWindows ? "微软雅黑" : "Source Han Sans SC";

    var m = FluentThemeData(
        brightness: Brightness.light,
        fontFamily: fonts,
        tooltipTheme:
            const TooltipThemeData(waitDuration: Duration(milliseconds: 300)),
        accentColor: AccentColor.swatch(swatch));
    if (View.of(context).platformDispatcher.platformBrightness.isDark) {
      m = FluentThemeData(
          brightness: Brightness.dark,
          fontFamily: fonts,
          tooltipTheme:
              const TooltipThemeData(waitDuration: Duration(milliseconds: 300)),
          accentColor: AccentColor.swatch(swatch));
    }

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
      initialBinding: GlobalControllerBindings(),
      localizationsDelegates: FluentLocalizations.localizationsDelegates,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
      builder: (context, child) {
        return AnimatedFluentTheme(
          data: m,
          child: child!,
        );
      },
    );
  }
}

List<GoRoute> _generateRoute(List<MenuData> datas) {
  List<GoRoute> result = [];
  for (var value in datas) {
    result.add(GoRoute(
        path: value.url,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: value.body,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.ease;
              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        }));
  }

  return result;
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final router = GoRouter(navigatorKey: rootNavigatorKey, routes: [
  ShellRoute(
    navigatorKey: _shellNavigatorKey,
    builder: (context, state, child) {
      MyRouterConfig.currentUrl = state.fullPath ?? '/';
      MyRouterConfig.themeContext = _shellNavigatorKey.currentContext;
      return MainPage(
        buildContext: _shellNavigatorKey.currentContext,
        child: child,
      );
    },
    routes: () {
      var routers = _generateRoute(MyRouterConfig.menuDatas);
      routers.addAll(_generateRoute(MyRouterConfig.footerDatas));
      return routers;
    }(),
  )
]);

class MainPage extends StatelessWidget {
  final BuildContext? buildContext;
  final Widget child;

  const MainPage({super.key, this.buildContext, required this.child});

  static List<NavigationPaneItem> _buildPaneItem(
      List<MenuData> datas, BuildContext context) {
    List<NavigationPaneItem> children = [];
    for (var value in datas) {
      if (!value.isVisible) {
        continue;
      }
      children.add(PaneItem(
          icon: Icon(value.icon),
          title: Text(value.label),
          body: value.body,
          onTap: () {
            context.go(value.url);
          }));
    }
    return children;
  }

  int _calculateIndex(BuildContext context) {
    final local = GoRouterState.of(context).uri.toString();
    List<MenuData> tmp = [];
    tmp.addAll(MyRouterConfig.menuDatas.where((x) => x.isVisible).toList());
    tmp.addAll(MyRouterConfig.footerDatas);

    return tmp.indexWhere((x) => x.url == local);
  }

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    final bg = FluentTheme.of(context).navigationPaneTheme.backgroundColor;
    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        leading: () {
          final enabled = buildContext != null && router.canPop();
          final onPressed = enabled
              ? () {
                  if (router.canPop()) {
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
                color: bg,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(Constants.appName),
                ))),
        actions: Container(
            margin: const EdgeInsets.all(5),
            child: Center(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    icon: Icon(
                      FluentIcons.chrome_minimize,
                      size: typography.caption?.fontSize,
                    ),
                    onPressed: () {
                      windowManager.hide();
                      context.go("/");
                    }),
                IconButton(
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
                    }),
                IconButton(
                    icon: Icon(
                      FluentIcons.chrome_close,
                      size: typography.caption?.fontSize,
                    ),
                    style: ButtonStyle(
                        backgroundColor: WidgetStateColor.resolveWith((state) {
                      if (state.contains(WidgetState.hovered)) {
                        return Color.fromARGB(255, 192, 43, 28);
                      }
                      return bg ?? Colors.transparent;
                    })),
                    onPressed: () {
                      windowManager.close();
                    }),
              ],
            ))),
      ),
      pane: NavigationPane(
        selected: _calculateIndex(context),
        header: const Text("pane Header"),
        displayMode: PaneDisplayMode.compact,
        items: _buildPaneItem(MyRouterConfig.menuDatas, context),
        footerItems: _buildPaneItem(MyRouterConfig.footerDatas, context),
      ),
      paneBodyBuilder: (item, child) {
        return FocusTraversalGroup(child: this.child);
      },
    );
  }
}

// 初始化系统托盘
Future<void> initSystemTray() async {
  String path = Platform.isWindows ? 'assets/seafox.ico' : 'assets/seafox.png';

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
