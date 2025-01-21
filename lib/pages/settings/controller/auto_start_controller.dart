import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/settings/api/auto_start_api.dart' as $api;
import 'package:nftools/pages/settings/state/auto_start.dart';

class AutoStartController extends GetxController {
  final state = AutoStartState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  void _init() async {
    state.isAutoStart = await $api.getAutoStart();
    update();
  }

  void toggleAutostart(bool enable) async{
    state.isAutoStart = enable;
    await $api.setAutoStart(enable);
    update();
  }
}
