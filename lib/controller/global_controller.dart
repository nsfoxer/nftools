import 'package:get/get.dart';
import 'package:nftools/controller/main_page_controller.dart';
import 'package:nftools/controller/ai_controller.dart';
import 'package:nftools/controller/display_controller.dart';
import 'package:nftools/controller/display_mode_controller.dart';
import 'package:nftools/controller/sync_file_controller.dart';
import 'package:nftools/controller/system_info_controller.dart';
import 'package:nftools/controller/system_mode_controller.dart';

class GlobalControllerBindings implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainPageController>(() => MainPageController(), fenix: true);
    Get.lazyPut<DisplayController>(() => DisplayController(), fenix: true);
    Get.lazyPut<DisplayModeController>(() => DisplayModeController(), fenix: true);
    Get.lazyPut<SyncFileController>(() => SyncFileController(), fenix: true);
    Get.lazyPut<SystemModeController>(() => SystemModeController(), fenix: true);
    Get.put<SystemInfoController>(SystemInfoController(), permanent: true);
    Get.put<SyncFileController>(SyncFileController(), permanent: true);
    Get.lazyPut<AiController>(() => AiController(), fenix: true);
  }
}
