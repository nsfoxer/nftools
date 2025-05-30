import 'package:get/get.dart';
import 'package:nftools/state/main_page_state.dart';

import '../utils/extension.dart';

class MainPageController extends GetxController with GetxUpdateMixin {
  final MainPageState pageState = MainPageState();

  void selectPage(int v) {
    pageState.selected = v;
    update();
  }
}
