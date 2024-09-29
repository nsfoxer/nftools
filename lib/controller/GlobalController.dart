import 'package:get/get.dart';
import 'package:nftools/controller/MainPageController.dart';
import 'package:nftools/controller/display_controller.dart';

class GlobalControllerBindings implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainPageController>(() => MainPageController());
    Get.lazyPut<DisplayController>(() => DisplayController());
  }
}
