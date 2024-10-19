import 'dart:async';

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
      state.addCpuInfo(cpu.percent);
      final mem = await $api.getRam();
      state.addMemInfo(mem.percent);
      update();
    });
  }

  void setTimeSpan(String timeSpan) {
    var r = state.timeSpanCombo[timeSpan]!;
    state.setSize(r.$1);
    _timer.cancel();
    _initTimer(r.$2);
    info(r.toString());
    state.selected = timeSpan;
    update();
  }

  @override
  void onClose() {
    super.onClose();
    _timer.cancel();
  }

}