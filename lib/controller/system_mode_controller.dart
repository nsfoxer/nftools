import 'package:get/get.dart';
import 'package:nftools/api/display_api.dart' as $api;
import 'package:nftools/state/system_mode_state.dart';

import '../utils/extension.dart';

class SystemModeController extends GetxController with GetxUpdateMixin {
  final state = SystemModeState();

  @override
  void onReady() {
    getSystemMode();
    super.onReady();
  }


  void getSystemMode() async {
    final mode = await $api.getSystemMode();
    state.enabled = mode.enabled;
    state.keepScreen = mode.keepScreen;
    update();
  }

  void setSystemMode(bool enabled, bool keepScreen) async {
    state.enabled = enabled;
    state.keepScreen = keepScreen;

    await $api.setSystemMode(enabled, keepScreen);
    update();
  }
}
