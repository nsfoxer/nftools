import 'dart:async';

import 'package:get/get_state_manager/src/simple/get_controllers.dart';


class CommonController extends GetxController {
  bool isConnected = false;
  Timer? _timer;

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  _init() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final result = await $api.networkStatus();
      if (result != isConnected) {
        isConnected = result;
        update();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
