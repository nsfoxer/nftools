import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:nftools/messages/display.pb.dart';
import 'package:nftools/state/display_mode_state.dart';
import 'package:nftools/api/display_api.dart' as $api;

class DisplayModeController extends GetxController {
  final state = DisplayModeState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  void _init() async {
    state.isLight = (await $api.getCurrentMode()).isLight;
    var r1 = await $api.getWallpaper();
    state.lightWallpaper = r1.lightWallpaper;
    state.darkWallpaper = r1.darkWallpaper;
    update();
  }

  void getMode() {
    $api.getCurrentMode();
  }
  void setMode(bool light) {
    EasyThrottle.throttle("display-mode/set-mode", const Duration(seconds: 2), () {
      state.isLight = light;
      update();
      $api.setMode(DisplayMode(isLight: light)).catchError((e) {
        state.isLight = light;
        update();
      });
    });
  }
}
