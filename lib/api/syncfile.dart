
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/syncfile.pb.dart';

import 'api.dart';

const String _service = "SyncFileService";
const String _listDirs = "list_dirs";
const String _hasAccount = "has_account";
const String _getAccount = "get_account";
const String _addAccount = "add_account";

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
  var data = await sendRequest<WebDavConfigMsg>(_service, _addAccount, config);
  var result = BoolMessage.fromBuffer(data);
  return result.value;
}

Future<WebDavConfigMsg> getAccount() async {
  var data = await sendRequest<EmptyMessage>(_service, _getAccount, null);
  var result = WebDavConfigMsg.fromBuffer(data);
  return result;
}


