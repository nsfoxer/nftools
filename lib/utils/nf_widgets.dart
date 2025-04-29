import 'dart:convert';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/utils/utils.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/base16/github.dart';
import 'package:re_highlight/styles/github-dark.dart';

// card 内容体
class NFCardContent extends StatelessWidget {
  const NFCardContent(
      {super.key, required this.child, this.noMargin, this.color});

  final Widget child;
  final bool? noMargin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: (noMargin ?? false) ? null : const EdgeInsets.all(NFLayout.v2),
      padding: const EdgeInsets.all(NFLayout.v1),
      decoration: BoxDecoration(
          border:
              Border.all(color: FluentTheme.of(context).cardColor, width: 1),
          borderRadius: BorderRadius.circular(10.0),
          color: color ?? FluentTheme.of(context).cardColor),
      child: child,
    );
  }
}

class NFCard extends StatelessWidget {
  const NFCard({super.key, required this.title, required this.child});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: typography.subtitle),
        NFLayout.vlineh2,
        NFCardContent(child: child),
        NFLayout.vlineh1,
      ],
    );
  }
}

// 加载组件
class LoadingWidgets extends StatelessWidget {
  final Widget child;
  final bool loading;

  const LoadingWidgets({
    super.key,
    required this.child,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return child;
    }
    return IgnorePointer(
        child: Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: child,
        ),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ProgressRing(), NFLayout.vlineh1, Text("加载中...")],
        ),
      ],
    ));
  }
}

// 无尽旋转动画组件
class NFRotationWidget extends StatefulWidget {
  final Widget child;

  const NFRotationWidget({super.key, required this.child});

  @override
  State<StatefulWidget> createState() {
    return _NFRotationWidgetState();
  }
}

class _NFRotationWidgetState extends State<NFRotationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // 循环动画
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller, // 使用 AnimationController 控制旋转
      child: widget.child,
    );
  }
}

class NFPanelWidget extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;

  const NFPanelWidget({super.key, this.leading, this.trailing});

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    children.add(Padding(
        padding: const EdgeInsets.symmetric(
            vertical: NFLayout.v2, horizontal: NFLayout.v1),
        child: leading ?? Container()));
    children.add(Padding(
        padding: const EdgeInsets.all(NFLayout.v3),
        child: trailing ?? Container()));
    return Container(
        padding: const EdgeInsets.all(NFLayout.v1),
        decoration: BoxDecoration(
            // border:
            //     Border.all(color: FluentTheme.of(context).cardColor, width: 1),
            borderRadius: BorderRadius.circular(6.0),
            color: FluentTheme.of(context).cardColor),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        ));
  }
}

// 代码编辑器
class NFCodeEditor extends StatelessWidget {
  final CodeLineEditingController controller;
  final bool? readOnly;
  final RxBool isDisplay = false.obs;

  NFCodeEditor({super.key, required this.controller, this.readOnly});

  @override
  Widget build(BuildContext context) {
    final isDark = context.mediaQuery.platformBrightness.isDark;
    final typography = FluentTheme.of(context).typography;
    return NFCardContent(
        child: Stack(children: [
      CodeEditor(
        wordWrap: false,
        controller: controller,
        readOnly: readOnly ?? false,
        style: CodeEditorStyle(
          textColor: FluentTheme.of(context).typography.body?.color,
          codeTheme: CodeHighlightTheme(
            languages: {
              'json': CodeHighlightThemeMode(mode: langJson),
              'dart': CodeHighlightThemeMode(mode: langDart),
              'sql': CodeHighlightThemeMode(mode: langSql),
            },
            theme: isDark ? githubDarkTheme : githubTheme,
          ),
        ),
        indicatorBuilder:
            (context, editingController, chunkController, notifier) {
          return Row(
            children: [
              DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
                minNumberCount: 0,
              ),
              DefaultCodeChunkIndicator(
                  width: 5, controller: chunkController, notifier: notifier)
            ],
          );
        },
      ),
      Positioned(
          top: NFLayout.v4,
          right: NFLayout.v4,
          child: MouseRegion(
            onEnter: (event) {
              isDisplay.value = true;
            },
            onExit: (event) {
              isDisplay.value = false;
            },
            child: Obx(() => SizedBox(
                height: 30,
                width: 30,
                child: isDisplay.isFalse ? Container(): Tooltip(
                  message: "美化",
                  child: IconButton(
                      icon: Icon(FluentIcons.auto_enhance_on,
                          size: typography.caption?.fontSize),
                      onPressed: () {
                        bool success = true;
                        try {
                          final data = formatJson(controller.text);
                          controller.text = data;
                        } catch (ignored) {
                          // ignored
                          success = false;
                        }
                        if (!success) {
                          final data = formatSql(controller.text);
                          controller.text = data;
                        }

                      }),
                ))),
          )),
    ]));
  }
}
