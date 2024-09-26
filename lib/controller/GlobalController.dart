import 'package:get/get.dart';
import 'package:nftools/controller/MainPageController.dart';

class GlobalControllerBindings implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainPageController>(() => MainPageController());
  }
}
