import 'package:easy_debounce/easy_debounce.dart';
import 'package:get/get.dart';
import 'package:nftools/src/bindings/bindings.dart';
import 'package:nftools/state/display_state.dart';
import 'package:nftools/api/display_api.dart' as $api;

import '../utils/extension.dart';

class DisplayController extends GetxController with GetxUpdateMixin {
  final state = DisplayState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  @override
  void onClose() {
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
      $api.setLight(DisplayInfoMsg(screen: screen, value: light)).catchError((e) {
        state.displayLight[screen] = -1;
        update();
      });
    });
  }
}
