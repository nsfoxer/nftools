import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/state/system_info_state.dart';
import 'package:nftools/api/system_info.dart' as $api;

import '../utils/log.dart';

class SystemInfoController extends GetxController {
  final SystemInfoState state = SystemInfoState();
  late Timer _timer;

  @override
  void onReady() {
    _initTimer(1);
    super.onReady();
  }

  void _initTimer(int periodic) {
    _timer = Timer.periodic(periodic.seconds, (timer) async {
      final cpu = await $api.getCpu();
      state.addLiveCpuInfo(cpu.value.toDouble() / 100);
      final mem = await $api.getRam();
      state.addLiveMemInfo(mem.value.toDouble() / 100);

      if (state.isLive) {
        update();
      }
    });
  }

  // 设置选择时间跨度
  void setTimeSpan(String timeSpan) {
    state.selected = timeSpan;
    update();
  }

  // 点击向前跳转
  void displayBefore(BuildContext context) {
    if (state.isLive) {
      state.isLive = false;
      state.endTime = state.liveCpuInfos.first.time;
      state.startTime = state.endTime!
          .subtract(Duration(seconds: state.timeSpanCombo[state.selected]!));
    } else {
      final duration = Duration(seconds: state.timeSpanCombo[state.selected]!);
      final tmpStartTime = state.startTime!.subtract(duration);
      if (tmpStartTime
          .isBefore(DateTime.now().subtract(const Duration(days: 2)))) {
        info("已超过2天，无数据记录", context: context);
        return;
      } else {
        state.startTime = tmpStartTime;
        state.endTime = state.endTime!.subtract(duration);
      }
    }
    _updateHistoryDatas();
  }

  // 点击向后跳转
  void displayAfter(BuildContext context) {
    if (state.isLive) {
      info("已是最后一页");
      return;
    }

    final duration = Duration(seconds: state.timeSpanCombo[state.selected]!);
    final tmpEndTime = state.endTime!.add(duration);
    if (tmpEndTime.isAfter(state.liveCpuInfos.last.time)) {
      // 执行实时页面操作
      playLive();
      return;
    }
    state.startTime = state.startTime!.add(duration);
    state.endTime = tmpEndTime;

    _updateHistoryDatas();
  }

  // 跳转至实时页面
  void playLive() {
    state.isLive = true;
    update();
  }

  // 更新历史数据
  void _updateHistoryDatas() async {
    info("${state.startTime} -- ${state.endTime}");
    // 获取历史数据
    var datas = await $api.getCpus(state.startTime!, state.endTime!);
    if (datas.infos.isEmpty) {
      state.cpuInfos = [
        ValueInfo(state.startTime!, double.nan),
        ValueInfo(state.endTime!, double.nan),
      ];
    } else {
      state.cpuInfos = datas.infos.map((x) {
        return ValueInfo(
            DateTime.fromMillisecondsSinceEpoch(x.timestamp * 1000),
            x.value / 100);
      }).toList();
    }
    datas = await $api.getRams(state.startTime!, state.endTime!);
    if (datas.infos.isEmpty) {
      state.memoryInfos = [
        ValueInfo(state.startTime!, double.nan),
        ValueInfo(state.endTime!, double.nan),
      ];
    } else {
      state.memoryInfos = datas.infos.map((x) {
        return ValueInfo(
            DateTime.fromMillisecondsSinceEpoch(x.timestamp * 1000),
            x.value / 100);
      }).toList();
      state.startTime = DateTime.fromMillisecondsSinceEpoch(datas.infos.first.timestamp * 1000);
      state.endTime = DateTime.fromMillisecondsSinceEpoch(datas.infos.last.timestamp * 1000);
    }
    update();
  }

  @override
  void onClose() {
    super.onClose();
    _timer.cancel();
  }
}
