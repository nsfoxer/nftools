import 'dart:async';

import 'package:get/get.dart';
import 'package:nftools/api/syncfile.dart' as $api;
import 'package:nftools/state/sync_file_state.dart';
import 'package:nftools/utils/log.dart';

import '../src/bindings/bindings.dart';
import '../utils/extension.dart';

class SyncFileController extends GetxController with GetxUpdateMixin {
  final state = SyncFileState();

  Timer? _timer;

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  @override
  void onClose() {
    state.dispose();
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  // 初始化数据
  _init() async {
    state.timer = await $api.getTimer();
    _setTimer(state.timer);
    try {
      if (!await $api.hasAccount()) {
        info("无登录信息或登录失败，请先登录");
      } else {
        var result = await $api.listDirs();
        state.fileList = result.files;
        state.isLogin = true;
      }
      var accountInfo = await $api.getAccount();
      state.urlController.text = accountInfo.url;
      state.userController.text = accountInfo.account;
      state.passwdController.text = accountInfo.passwd;
      state.accountInfoLock = true;
    } finally {
      state.isLoading = false;
      update();
    }
  }

  Future<bool> submitAccount() async {
    var account = WebDavConfigMsg(
        url: state.urlController.text,
        account: state.userController.text,
        passwd: state.passwdController.text);
    var result = true;
    try {
      result = await $api.setAccount(account);
    } on Exception catch (_) {
      result = false;
    }
    if (result) {
      state.isLogin = true;
    }
    return result;
  }

  void refreshList() async {
    state.isLoading = true;
    update();
    await _init();
  }

  // 列出所有文件夹
  Future<void> listFiles() async {
    var result = await $api.listDirs();
    state.fileList = result.files;
    update();
  }

  // 切换锁定账户编辑信息
  void changeAccountLogic() {
    state.accountInfoLock = !state.accountInfoLock;
    update();
  }

  // 添加同步文件夹
  void addSyncDir(String localDir, String tag) async {
    state.isLoading = true;
    update();
    try {
      final r = await $api.addSyncDir(localDir, tag);
      state.fileList.add(r);
    } finally {
      state.isLoading = false;
      update();
    }
  }

  // 同步一个文件夹
  Future<SyncFileDetailMsg> syncDir(String remoteId) async {
    state.isLoading = true;
    update();
    try {
      final result = await $api.syncDir(remoteId);
      for (int i = 0; i < state.fileList.length; i++) {
        if (state.fileList[i].remoteDir == remoteId) {
          state.fileList[i] = FileMsg(
            localDir: state.fileList[i].localDir,
            remoteDir: state.fileList[i].remoteDir,
            tag: state.fileList[i].tag,
            modify: 0,
            add: 0,
            del: 0,
            status: FileStatusEnumMsg.synced,
          );
        }
      }
      return result;
    } finally {
      state.isLoading = false;
      update();
    }
  }

  // 删除一个本地文件夹记录
  void deleteLocalDir(String localDir) {
    $api.deleteLocalDir(localDir);
    state.fileList.retainWhere((file) {
      return file.localDir != localDir;
    });
    update();
  }

  // 对缺失的远端同步文件夹添加本地空文件夹
  void addLocalDir(String dirPath, String remoteId) async {
    final fileMsg = await $api.addLocalDir(dirPath, remoteId);
    final i = state.fileList.indexWhere((file) => file.remoteDir == remoteId);
    state.fileList[i] = fileMsg;
    update();
  }

  // 删除远端同步文件夹，取消此条目的同步
  void deleteRemoteDir(String remoteDir) async {
    await $api.deleteRemoteDir(remoteDir);
    state.fileList.retainWhere((file) {
      return file.remoteDir != remoteDir;
    });
    update();
  }

  // === page ===

  // 设置定时器
  void setTimer(int? v) {
    if (v == null) {
      return;
    }
    state.timer = v;
    if (_timer != null) {
      _timer!.cancel();
    }

    $api.setTimer(v);
    _setTimer(v);

    update();
  }

  void _setTimer(int v) {
    if (v > 0) {
      _timer = Timer.periodic(Duration(minutes: v), (timer) async {
        if (!state.isLogin) {
          return;
        }
        info("开始同步");
        state.isLoading = true;
        update();
        await listFiles();
        for (var value in state.fileList) {
          if (value.localDir.isEmpty ||
              value.remoteDir.isEmpty ||
              value.status == FileStatusEnumMsg.synced) {
            continue;
          }
          await syncDir(value.remoteDir);
        }
        state.isLoading = false;
        update();
        info("同步完成");
      });
    }
  }
}
