import 'package:get/get.dart';
import 'package:nftools/router/router.dart';
import 'package:nftools/state/MainPageState.dart';

class MainPageController extends GetxController {
  final MainPagestate pageState = MainPagestate();

  void select(String value) {
    pageState.selected = value;
    for (var i = 0; i < MyRouterConfig.menuDatas.length; i++) {
      if (value == MyRouterConfig.menuDatas[i].router) {
        pageState.pageController.jumpToPage(i);
        update();
        return;
      }
    }
  }

  void openSetting() {
    pageState.selected = null;
    pageState.pageController.jumpToPage(MyRouterConfig.menuDatas.length);
    update();
  }
}
