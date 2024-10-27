import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;
import 'package:get/get.dart';
import 'package:graphic/graphic.dart';
import 'package:intl/intl.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/system_info_controller.dart';
import 'package:nftools/state/system_info_state.dart';

import '../utils/log.dart';

DateFormat _timeFormat = DateFormat.Hms();

class SystemInfoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return GetBuilder<SystemInfoController>(builder: (logic) {
      return ScaffoldPage.scrollable(
          header: PageHeader(
              title: const Text("系统信息"),
              commandBar: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "时间跨度",
                    style: typography.body,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  ComboBox<String>(
                    items: logic.state.timeSpanCombo.keys
                        .map((x) => ComboBoxItem<String>(
                              value: x,
                              child: Text(x),
                            ))
                        .toList(growable: false),
                    value: logic.state.selected,
                    onChanged: (v) {
                      if (v != null) {
                        logic.setTimeSpan(v);
                      }
                    },
                  ),
                ],
              )),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tooltip(
                  message: "之前历史数据",
                  child: IconButton(
                      icon: Icon($me.Icons.navigate_before,
                          size: typography.title?.fontSize),
                      onPressed: () {
                        logic.displayBefore(context);
                      }),
                ),
                Row(
                  children: [
                    Tooltip(
                      message: "之后历史数据",
                      child: IconButton(
                          icon: Icon(
                            $me.Icons.navigate_next,
                            size: typography.title?.fontSize,
                          ),
                          onPressed: logic.state.isLive ? null : () {
                            logic.displayAfter(context);
                          }),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Tooltip(
                      message: "实时数据",
                      child: IconButton(
                          icon: Icon(
                            $me.Icons.keyboard_double_arrow_right,
                            size: typography.title?.fontSize,
                          ),
                          onPressed: logic.state.isLive ? null : () {
                            logic.playLive();
                          }),
                    ),
                  ],
                ),
              ],
            ),
            Center(
                child: Text(
              "CPU信息",
              style: typography.subtitle,
            )),
            CpuInfoPage(datas: logic.state.isLive ? logic.state.liveCpuInfos: logic.state.cpuInfos),
            NFLayout.vlineh1,
            Center(
                child: Text(
              "内存信息",
              style: typography.subtitle,
            )),
            CpuInfoPage(datas: logic.state.isLive ? logic.state.liveMemoryInfos: logic.state.memoryInfos),
          ]);
    });
  }
}

class CpuInfoPage extends StatelessWidget {
  final List<ValueInfo> datas;

  const CpuInfoPage({super.key, required this.datas});
  @override
  Widget build(BuildContext context) {
    info("图表构建");
    Widget r = () {
      var data = datas;
      if (data.length < 2) {
        return const SizedBox.shrink();
      }
      return Chart(
        changeData: true,
        data: data,
        variables: {
          'value': Variable(
            accessor: (ValueInfo info) => info.time,
            scale: TimeScale(
                formatter: (time) => _timeFormat.format(time),
                max: data.last.time,
                min: data.first.time),
          ),
          'percent': Variable(
            accessor: (ValueInfo info) =>
                double.parse(info.percent.toStringAsFixed(2)),
            scale: LinearScale(max: 100, min: 0),
          ),
        },
        marks: [
          AreaMark(
            shape: ShapeEncode(value: BasicAreaShape(smooth: true)),
            color: ColorEncode(
                value: FluentTheme.of(context).accentColor.withAlpha(80)),
          ),
          LineMark(
            shape: ShapeEncode(value: BasicLineShape(smooth: true)),
            size: SizeEncode(value: 0.3),
          ),
        ],
        axes: [
          Defaults.horizontalAxis..grid = Defaults.strokeStyle,
          Defaults.verticalAxis..line = Defaults.strokeStyle,
        ],
        selections: {
          'touchMove': PointSelection(
            on: {GestureType.hover},
          ),
        },
        tooltip: TooltipGuide(
          align: Alignment.topLeft,
          offset: const Offset(-20, -20),
        ),
      );
    }();

    return SizedBox(
      height: 300,
      child: r,
    );
  }
}
