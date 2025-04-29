import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:nftools/api/utils.dart';
import 'package:nftools/src/bindings/bindings.dart';
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
    state.loadingWallpaper = true;
    update();
    _setWallpaper();
  }

  void _setWallpaper() async {
    var r1 = await $api.getWallpaper();
    state.lightWallpaper = await compressLocalFile(r1.lightWallpaper, 300, 200);
    state.darkWallpaper = await compressLocalFile(r1.darkWallpaper, 300, 200);
    state.loadingWallpaper = false;
    update();
  }

  void getMode() {
    $api.getCurrentMode();
  }
  void setMode(bool light) {
    EasyThrottle.throttle("display-mode/set-mode", const Duration(seconds: 2), () {
      state.isLight = light;
      update();
      $api.setMode(DisplayModeMsg(isLight: light)).catchError((e) {
        state.isLight = light;
        update();
      });
    });
  }
}
