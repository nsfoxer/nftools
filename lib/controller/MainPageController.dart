import 'package:get/get.dart';
import 'package:nftools/state/MainPageState.dart';

class MainPageController extends GetxController {
  final MainPagestate pageState = MainPagestate();

  void selectPage(int v) {
    pageState.selected = v;
    update();
  }
}
