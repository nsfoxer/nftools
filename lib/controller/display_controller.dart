import 'package:easy_debounce/easy_debounce.dart';
import 'package:get/get.dart';
import 'package:nftools/messages/display.pb.dart';
import 'package:nftools/state/display_state.dart';
import 'package:nftools/api/display_api.dart' as $api;

class DisplayController extends GetxController {
  final state = DisplayState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  // 初始化数据
  _init() async {
    var count = 0;
    for (var item in await $api.displaySupport()) {
      state.displayLight[item.screen] = item.value;
      count += item.value;
    }
    if (count == 0) {
      for (var item in await $api.displaySupport()) {
        state.displayLight[item.screen] = item.value;
      }
    }
    update();
  }

  setLight(String screen, int value) {
    state.displayLight[screen] = value;
    update();
    EasyDebounce.debounce("display/setLight", const Duration(milliseconds: 20),
        () async {
      var light = value;
      $api.setLight(DisplayInfo(screen: screen, value: light)).catchError((e) {
        state.displayLight[screen] = light;
        update();
      });
    });
  }
}
