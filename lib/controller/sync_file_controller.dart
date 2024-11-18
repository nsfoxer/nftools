import 'package:get/get.dart';
import 'package:nftools/api/syncfile.dart' as $api;
import 'package:nftools/state/sync_file_state.dart';

class SyncFileController extends GetxController {
  final state = SyncFileState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  // 初始化数据
  _init() async {
  }

}