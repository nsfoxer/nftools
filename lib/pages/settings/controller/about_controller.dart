import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/settings/api/about_api.dart' as $api;
import 'package:nftools/pages/settings/state/about_state.dart';

class AboutController extends GetxController {
  final state = AboutState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  void _init() async {
    state.version = await $api.version();
    state.newestVersion = await $api.newestVersion();
    state.record = await $api.getRecord();
    update();
  }

  void installNewest() async{
    if (state.isInstalling) {
      return;
    }
    state.isInstalling = true;
    update();
    try {
      await $api.installNewest();
    } finally{
      state.isInstalling = false;
      update();
    }
  }
}
