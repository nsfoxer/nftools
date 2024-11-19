import 'package:get/get.dart';
import 'package:nftools/api/syncfile.dart' as $api;
import 'package:nftools/state/sync_file_state.dart';
import 'package:nftools/utils/log.dart';

class SyncFileController extends GetxController {
  final state = SyncFileState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  // 初始化数据
  _init() async {
    try {
      if (!await $api.hasAccount()) {
        info("无登录信息，请先登录");
      } else {
        var result = await $api.listDirs();
        state.fileList = result.files;
      }
    } finally {
      state.isLoading = false;
      update();
    }
  }
}
