import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:graphic/graphic.dart';
import 'package:intl/intl.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/system_info_controller.dart';
import 'package:nftools/state/system_info_state.dart';

DateFormat _timeFormat = DateFormat.Hms();

class SystemInfoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return GetBuilder<SystemInfoController>(builder: (logic) {
      return ScaffoldPage.scrollable(
          header: const PageHeader(
            title: Text("系统信息"),
          ),
          children: [
            Center(
                child: Text(
              "Cpu信息",
              style: typography.subtitle,
            )),
            CpuInfoPage(datas: logic.state.cpuInfos),
            NFLayout.vlineh1,
            Center(
                child: Text(
              "内存信息",
              style: typography.subtitle,
            )),
            CpuInfoPage(datas: logic.state.memoryInfos),
          ]);
    });
  }
}

class CpuInfoPage extends StatelessWidget {
  final List<ValueInfo> datas;

  const CpuInfoPage({super.key, required this.datas});
  @override
  Widget build(BuildContext context) {
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
