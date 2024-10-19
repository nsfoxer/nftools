import 'dart:async';

import 'package:get/get.dart';
import 'package:nftools/state/system_info_state.dart';
import 'package:nftools/api/system_info.dart' as $api;

class SystemInfoController extends GetxController {
  final SystemInfoState state = SystemInfoState();
  late Timer _timer;

  @override
  void onReady() {
    _timer = Timer.periodic(1.seconds, (timer) async {
      final cpu = await $api.getCpu();
      state.addCpuInfo(cpu.percent);
      final mem = await $api.getRam();
      state.addMemInfo(mem.percent);
      update();
    });

    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
    _timer.cancel();
  }

}