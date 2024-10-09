import 'package:get/get.dart';
import 'package:nftools/controller/MainPageController.dart';
import 'package:nftools/controller/display_controller.dart';
import 'package:nftools/controller/display_mode_controller.dart';
import 'package:nftools/controller/sync_file_controller.dart';

class GlobalControllerBindings implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainPageController>(() => MainPageController());
    Get.lazyPut<DisplayController>(() => DisplayController());
    Get.lazyPut<DisplayModeController>(() => DisplayModeController());
    Get.lazyPut<SyncFileController>(() => SyncFileController());
  }
}
