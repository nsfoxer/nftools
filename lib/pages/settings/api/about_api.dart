import 'package:nftools/api/api.dart';

import '../../../src/bindings/bindings.dart';

const String _service = "AboutService";
const String _version = "version";
const String _newestVersion = "check_updates";
const String _record = "record";
const String _installBNewest = "install_newest";

// 获取当前版本号
Future<String> version() async {
  final data = await sendRequest<EmptyMsg>(_service, _version, null);
  return StringMsg.bincodeDeserialize(data).value;
}

// 获取最新版本编号
Future<String> newestVersion() async {
  final data = await sendRequest<EmptyMsg>(_service, _newestVersion, null);
  return StringMsg.bincodeDeserialize(data).value;
}

// 获取历史记录
Future<String> getRecord() async {
  final data = await sendRequest<EmptyMsg>(_service, _record, null);
  return StringMsg.bincodeDeserialize(data).value;
}

// 下载并安装最新版
Future<void> installNewest() async {
  await sendRequest<EmptyMsg>(_service, _installBNewest, null);
}
