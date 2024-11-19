
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/syncfile.pb.dart';

import 'api.dart';

const String _service = "SyncFileService";
const String _listDirs = "list_dirs";

Future<ListFileMsg> listDirs() async {
  var data = await sendRequest<EmptyMessage>(_service, _listDirs, null);
  var result = ListFileMsg.fromBuffer(data);
  return result;
}



