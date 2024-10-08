import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/display_controller.dart';
import 'package:nftools/controller/display_mode_controller.dart';
import 'package:nftools/utils/nf-widgets.dart';
import 'package:tolyui/tolyui.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
        child: Padding(
      padding: EdgeInsets.all(NFLayout.v1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "显示工具",
            style: NFTextStyle.h1,
          ),
          NFLayout.vlineh1,
          Text(
            "显示器亮度",
            style: NFTextStyle.h2,
          ),
          NFLayout.vlineh2,
          NFCard(child: _DisplayLight()),
          NFLayout.vlineh1,
          Text("主题", style: NFTextStyle.h2),
          NFLayout.vlineh2,
          NFCard(child: _DisplayMode()),
        ],
      ),
    ));
  }
}

class _DisplayLight extends StatelessWidget {
  const _DisplayLight({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DisplayController>(builder: (logic) {
      var state = logic.state;

      List<Widget> displays = [];
      for (var item in state.displayLight.entries) {
        displays.add(SizedBox(
            height: 25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                    flex: 1,
                    child: TolyTooltip(
                        message: item.key,
                        child:
                            Text(item.key, overflow: TextOverflow.ellipsis))),
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
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: NFLayout.v1 * 2),
          child: Column(
            children: displays,
          ));
    });
  }
}

class _DisplayMode extends StatelessWidget {
  const _DisplayMode();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DisplayModeController>(builder: (logic) {
      var state = logic.state;
      return Row(
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
      );
    });
  }
}

class _Mode extends StatelessWidget {
  final Widget display;
  final bool isSelect;
  final String? picFile;

  const _Mode({
    Key? key,
    required this.display,
    required this.isSelect,
    this.picFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<BoxShadow>? boxShadow;
    if (isSelect) {
      boxShadow = [
        BoxShadow(
            color: Colors.blue.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 20)
      ];
    }
    return Column(children: [
      const SizedBox(height: 15,),
      Container(
        height: 150,
        width: 267,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8), boxShadow: boxShadow),
        child: picFile == null ? null : Image.file(File(picFile!)),
      ),
      display,
      const SizedBox(height: 10,),
    ]);
  }
}
