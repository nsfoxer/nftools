import 'package:get/get.dart';
import 'package:nftools/state/main_page_state.dart';

class MainPageController extends GetxController {
  final MainPageState pageState = MainPageState();

  void selectPage(int v) {
    pageState.selected = v;
    update();
  }
}
