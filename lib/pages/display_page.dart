import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/display_controller.dart';
import 'package:tolyui/tolyui.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({Key? key}) : super(key: key);

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
          _DisplayLight(),
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
