import 'dart:io';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/api/api.dart';
import 'package:nftools/api/display_api.dart';
import 'package:nftools/controller/GlobalController.dart';
import 'package:nftools/messages/generated.dart';
import 'package:nftools/router/router.dart';
import 'package:nftools/utils/log.dart';
import 'package:rinf/rinf.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';


void main() async {
  // 1，初始化 window manager
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 2. 初始化托盘
  initSystemTray();

  // 2. 初始化后端
  await initializeRust(assignRustSignal);
  initMsg();

  // 启动GUI
  runApp(MainApp(primaryColor: await getSystemColor()));
}

class MainApp extends StatefulWidget {
  Color primaryColor;

  MainApp({super.key, required this.primaryColor});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WindowListener {
  ThemeMode mode = ThemeMode.system;
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    // 添加window——manager监听器
    windowManager.addListener(this);
    // 等待后端服务退出
    _listener = AppLifecycleListener(
      onExitRequested: () async {
        finalizeRust(); // Shut down the `tokio` Rust runtime.
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _listener.dispose();
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    info('[WindowManager] onWindowEvent: $eventName');
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Color> swatch = {
      "normal": widget.primaryColor,
    };
    var fonts = Platform.isWindows ? "微软雅黑" : "Source Han Sans SC";

    var m = FluentThemeData(
        brightness: Brightness.light,
        fontFamily: fonts,
        accentColor: AccentColor.swatch(swatch));
    if (View.of(context).platformDispatcher.platformBrightness.isDark) {
      m = FluentThemeData(
          brightness: Brightness.dark,
          fontFamily: fonts,
          accentColor: AccentColor.swatch(swatch));
    }

    return AnimatedFluentTheme(
        data: m,
        child: GetMaterialApp(
          title: 'nftools',
          debugShowCheckedModeBanner: false,
          initialBinding: GlobalControllerBindings(),
          home: FluentApp.router(
            debugShowCheckedModeBanner: false,
            theme: m,
            darkTheme: m,
            title: "App Title",
            localizationsDelegates: FluentLocalizations.localizationsDelegates,
            builder: (context, child) {
              return child!;
            },
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
            routeInformationProvider: router.routeInformationProvider,
          ),
        ));
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
    tmp.addAll(MyRouterConfig.menuDatas);
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
              info("message");
              windowManager.startDragging();
            },
            child: Container(
                height: double.infinity,
                width: double.infinity,
                color: bg,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("nftools"),
                ))),
        // const Text("nftools"),

        actions: Container(
            margin: const EdgeInsets.all(5),
            child: Center(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    icon:
                    Icon(
                      FluentIcons.chrome_minimize,
                      size: typography.caption?.fontSize,
                    ),
                    onPressed: () {
                      windowManager.hide();
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
  String path =
  Platform.isWindows ? 'assets/seafox.ico' : 'assets/seafox.png';

  final SystemTray systemTray = SystemTray();

  // We first init the systray menu
  await systemTray.initSystemTray(
    title: "nftools",
    iconPath: path,
  );

  // handle system tray event
  systemTray.registerSystemTrayEventHandler((eventName) async {
      if (!await windowManager.isVisible()) {
        windowManager.show();
      } else {
        windowManager.hide();
      }
  });
}
