
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/syncfile.pb.dart';

import 'api.dart';

const String _service = "SyncFileService";
const String _listDirs = "list_dirs";
const String _hasAccount = "has_account";
const String _getAccount = "get_account";
const String _setAccount = "set_account";
const String _addSyncDir = "add_sync_dir";
const String _syncDir = "sync_dir";
const String _deleteLocalDir = "del_local_dir";
const String _addLocalDir = "add_local_file";

Future<ListFileMsg> listDirs() async {
  var data = await sendRequest<EmptyMessage>(_service, _listDirs, null);
  var result = ListFileMsg.fromBuffer(data);
  return result;
}

Future<bool> hasAccount() async {
  var data = await sendRequest<EmptyMessage>(_service, _hasAccount, null);
  var result = BoolMessage.fromBuffer(data);
  return result.value;
}

Future<bool> setAccount(WebDavConfigMsg config) async {
  var data = await sendRequest<WebDavConfigMsg>(_service, _setAccount, config);
  var result = BoolMessage.fromBuffer(data);
  return result.value;
}

Future<WebDavConfigMsg> getAccount() async {
  var data = await sendRequest<EmptyMessage>(_service, _getAccount, null);
  var result = WebDavConfigMsg.fromBuffer(data);
  return result;
}


Future<void> addSyncDir(String localDir) async {
   await sendRequest(_service, _addSyncDir, StringMessage(value: localDir));
}

Future<SyncFileDetailMsg> syncDir(String remoteId) async {
  final data = await sendRequest(_service, _syncDir, StringMessage(value: remoteId));
  return SyncFileDetailMsg.fromBuffer(data);
}

void deleteLocalDir(String localDir) async {
  await sendRequest(_service, _deleteLocalDir, StringMessage(value: localDir));
}

Future<void> addLocalDir(String localDir, String remoteId) async {
  await sendRequest(_service, _addLocalDir, AddLocal4RemoteMsg(localDir: localDir, remoteDir: remoteId));
}
