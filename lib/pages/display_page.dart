import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/display_controller.dart';
import 'package:nftools/controller/display_mode_controller.dart';
import 'package:nftools/controller/system_mode_controller.dart';
import 'package:nftools/utils/nf_widgets.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(
        title: Text("显示工具"),
      ),
      children: const [
        NFCard(title: "显示器亮度", child: _DisplayLight()),
        NFCard(title: "主题", child: _DisplayMode()),
        NFCard(title: "系统休眠", child: _SystemMode()),
      ],
    );
  }
}

class _DisplayLight extends StatelessWidget {
  const _DisplayLight({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DisplayController>(builder: (logic) {
      var state = logic.state;
      Typography typography = FluentTheme.of(context).typography;

      List<Widget> displays = [];
      for (var item in state.displayLight.entries) {
        if (item.value == -1) {
          continue;
        }
        displays.add(SizedBox(
            height: 25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                    flex: 1,
                    child: Text(item.key,
                        style: typography.body,
                        overflow: TextOverflow.ellipsis)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: Text("${item.value.toInt()}%")),
                Expanded(
                    flex: 4,
                    child: Slider(
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: "${item.value}%",
                        value: item.value.toDouble(),
                        onChanged: (v) async =>
                            await logic.setLight(item.key, v.toInt()))),
              ],
            )));
      }
      return Column(
        children: displays,
      );
    });
  }
}

class _DisplayMode extends StatelessWidget {
  const _DisplayMode();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DisplayModeController>(builder: (logic) {
      var state = logic.state;
      return LoadingWidgets(
          loading: logic.state.loadingWallpaper,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Container(),
              MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => logic.setMode(true),
                    child: _Mode(
                      display: const Text(
                        "亮色模式",
                        style: NFTextStyle.p3,
                      ),
                      isSelect: state.isLight ?? false,
                      picFile: state.lightWallpaper,
                    ),
                  )),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => logic.setMode(false),
                  child: _Mode(
                    display: const Text(
                      "暗色模式",
                      style: NFTextStyle.p3,
                    ),
                    isSelect: !(state.isLight ?? true),
                    picFile: state.darkWallpaper,
                  ),
                ),
              ),
              Container(),
            ],
          ));
    });
  }
}

class _Mode extends StatelessWidget {
  final Widget display;
  final bool isSelect;
  final String? picFile;

  const _Mode({
    super.key,
    required this.display,
    required this.isSelect,
    this.picFile,
  });

  @override
  Widget build(BuildContext context) {
    List<BoxShadow>? boxShadow;
    var color = FluentTheme.of(context).accentColor.normal;
    if (isSelect) {
      boxShadow = [
        BoxShadow(
            color: color.withValues(alpha: 0.5), spreadRadius: 5, blurRadius: 20)
      ];
    }
    return Column(children: [
      const SizedBox(
        height: 15,
      ),
      Container(
        height: 150,
        width: 267,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8), boxShadow: boxShadow),
        child: picFile == null ? null : Image.file(File(picFile!)),
      ),
      display,
      const SizedBox(
        height: 10,
      ),
    ]);
  }
}

class _SystemMode extends StatelessWidget {
  const _SystemMode();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SystemModeController>(builder: (logic) {
      var typography = FluentTheme.of(context).typography;
      final enabled = logic.state.enabled;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ToggleSwitch(
              content: Text(
                "阻止系统休眠",
                style: typography.caption,
              ),
              checked: enabled,
              onChanged: (v) {
                logic.setSystemMode(v, logic.state.keepScreen);
              }),
          Checkbox(
              content: Text(
                "保持亮屏",
                style: typography.caption,
              ),
              checked: logic.state.keepScreen,
              onChanged: enabled
                  ? (v) {
                      logic.setSystemMode(enabled, v ?? false);
                    }
                  : null),
        ],
      );
    });
  }
}
