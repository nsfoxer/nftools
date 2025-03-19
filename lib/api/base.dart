
import 'package:nftools/common/constants.dart';
import 'package:nftools/messages/common.pb.dart';

import 'api.dart';

const String _service = ServiceName.api;
const String _close = "close";

// 结束所有服务
Future<String> closeRust() async {
  var data = await sendRequest<EmptyMessage>
    (_service, _close, null);
  return StringMessage.fromBuffer(data).value;
}

// 查询路由是否已启用
Future<bool> getRouterEnabled(String router) async {
  var data = await sendRequest<StringMessage>
    (_service, "getRouterEnabled", StringMessage(value: router));
  final r =  BoolMessage.fromBuffer(data).value;
  return r;
}

// 设置路由是否启用
Future<void> setRouterEnabled(String router, bool enabled) async {
  await sendRequest<StringMessage>
    (_service, "setRouterEnabled", StringMessage(value: router));
}

// 启用服务
Future<void> enableService(String service) async {
  await sendRequest<StringMessage>
    (_service, "enableService", StringMessage(value: service));
}