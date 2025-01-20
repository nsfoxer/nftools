import 'package:nftools/api/api.dart';
import 'package:nftools/messages/about.pb.dart';
import 'package:nftools/messages/common.pb.dart';

const String _service = "AboutService";
const String _version = "version";
const String _newestVersion = "check_updates";
const String _history = "get_history";
const String _installBNewest = "install_newest";

// 获取当前版本号
Future<String> version() async {
  final data = await sendRequest<EmptyMessage>(_service, _version, null);
  return StringMessage.fromBuffer(data).value;
}

// 获取最新版本编号
Future<String> newestVersion() async {
  final data = await sendRequest<EmptyMessage>(_service, _newestVersion, null);
  return StringMessage.fromBuffer(data).value;
}

// 获取历史记录
Future<VersionHistoryListMsg> getHistory() async {
  final data = await sendRequest<EmptyMessage>(_service, _history, null);
  return VersionHistoryListMsg.fromBuffer(data);
}

// 下载并安装最新版
Future<void> installNewest() async {
  await sendRequest<EmptyMessage>(_service, _installBNewest, null);
}
