import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:nftools/messages/display.pb.dart';
import 'package:nftools/api/display_api.dart' as $api;
import 'package:nftools/state/system_mode_state.dart';

class SystemModeController extends GetxController {
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
  void setSystemMode() {

  }
}
