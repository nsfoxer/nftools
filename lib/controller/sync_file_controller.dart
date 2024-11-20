import 'package:get/get.dart';
import 'package:nftools/api/syncfile.dart' as $api;
import 'package:nftools/messages/syncfile.pb.dart';
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
        var accountInfo = await $api.getAccount();
        state.urlController.text = accountInfo.url;
        state.userController.text = accountInfo.account;
        state.passwdController.text = accountInfo.passwd;
        state.accountInfoLock = true;
        var result = await $api.listDirs();
        info(result.toString());
        state.fileList = result.files;
      }
    } finally {
      state.isLoading = false;
      update();
    }
  }

  Future<bool> submitAccount() async {
    var account = WebDavConfigMsg(url: state.urlController.text, account: state.userController.text, passwd: state.passwdController.text);
    var result;
    try {
      result = await $api.setAccount(account);
    } on Exception catch (_) {
      result = false;
    }
    return result;
  }

  // 切换锁定账户编辑信息
  void changeAccountLogic() {
    state.accountInfoLock = !state.accountInfoLock;
    update();
  }
}
