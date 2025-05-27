import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:nftools/api/utils.dart';
import 'package:nftools/src/bindings/bindings.dart';
import 'package:nftools/state/display_mode_state.dart';
import 'package:nftools/api/display_api.dart' as $api;

import '../utils/log.dart';

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
    state.lightWallpaper = await _tryCompressImage(r1.lightWallpaper);
    state.darkWallpaper = await _tryCompressImage(r1.darkWallpaper);
    state.loadingWallpaper = false;
    update();
  }

  Future<String?> _tryCompressImage(String imageFile) async{
    try {
      final result = await compressLocalFile(imageFile, 300, 200);
      return result.localFile;
    } catch(ignore) {
      return imageFile;
    }
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
