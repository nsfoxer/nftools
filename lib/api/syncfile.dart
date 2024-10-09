
import 'package:nftools/messages/common.pb.dart';

import 'api.dart';

const String _service1 = "SyncFile";
const String _getFiles = "get_files";
const String _addFile = "add_file";
const String _delFile = "del_file";

Future<VecStringMessage> getFiles() async {
  var data = await sendRequest<EmptyMessage>(_service1, _getFiles, null);
  var result = VecStringMessage.fromBuffer(data);
  return result;
}

Future<void> addFile(String file) async {
  await sendRequest(_service1, _addFile, StringMessage(value: file));
}

Future<void> delFile(String file) async {
  await sendRequest(_service1, _delFile, StringMessage(value: file));
}
