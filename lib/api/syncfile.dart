import 'package:nftools/utils/log.dart';

import '../common/constants.dart';
import '../src/bindings/bindings.dart';
import 'api.dart';

const String _service = ServiceNameConstant.syncFile;
const String _listDirs = "list_dirs";
const String _hasAccount = "has_account";
const String _getAccount = "get_account";
const String _setAccount = "set_account";
const String _addSyncDir = "add_sync_dir";
const String _syncDir = "sync_dir";
const String _deleteLocalDir = "del_local_dir";
const String _addLocalDir = "add_local_file";
const String _deleteRemoteDir = "del_remote_dir";
const String _setTimer = "set_timer";
const String _getTimer = "get_timer";

Future<ListFileMsg> listDirs() async {
  var data = await sendRequest<EmptyMsg>(_service, _listDirs, null);
  var result = ListFileMsg.bincodeDeserialize(data);
  result.files.sort((a, b) {
    return (a.localDir + a.remoteDir)
        .compareTo(b.localDir + b.remoteDir);
  });
  return result;
}

// 是否有账户
Future<bool> hasAccount() async {
  try {
    var data = await sendRequest<EmptyMsg>(_service, _hasAccount, null);
    var result = BoolMsg.bincodeDeserialize(data);
    return result.value;
  } catch (e) {
    info("message ============");
    return false;
  }
}

Future<bool> setAccount(WebDavConfigMsg config) async {
  try {
    var data =
        await sendRequest<WebDavConfigMsg>(_service, _setAccount, config);
    var result = BoolMsg.bincodeDeserialize(data);
    return result.value;
  } catch (e) {
    return false;
  }
}

Future<WebDavConfigMsg> getAccount() async {
  var data = await sendRequest<EmptyMsg>(_service, _getAccount, null);
  var result = WebDavConfigMsg.bincodeDeserialize(data);
  return result;
}

Future<FileMsg> addSyncDir(String localDir, String tag) async {
  final data = await sendRequest(
      _service, _addSyncDir, AddSyncDirMsg(localDir: localDir, tag: tag));
  return FileMsg.bincodeDeserialize(data);
}

Future<SyncFileDetailMsg> syncDir(String remoteId) async {
  final data =
      await sendRequest(_service, _syncDir, StringMsg(value: remoteId));
  return SyncFileDetailMsg.bincodeDeserialize(data);
}

void deleteLocalDir(String localDir) async {
  await sendRequest(_service, _deleteLocalDir, StringMsg(value: localDir));
}

Future<FileMsg> addLocalDir(String localDir, String remoteId) async {
  final data = await sendRequest(_service, _addLocalDir,
      AddLocalForRemoteMsg(localDir: localDir, remoteDir: remoteId));
  return FileMsg.bincodeDeserialize(data);
}

Future<void> deleteRemoteDir(String remoteId) async {
  await sendRequest(_service, _deleteRemoteDir, StringMsg(value: remoteId));
}

// 设置定时同步值
void setTimer(int timer) async {
  await sendRequest(_service, _setTimer, UintFiveMsg(value: timer));
}

// 获取定时同步值
Future<int> getTimer() async {
  var data = await sendRequest<EmptyMsg>(_service, _getTimer, null);
  var result = UintFiveMsg.bincodeDeserialize(data);
  return result.value;
}
