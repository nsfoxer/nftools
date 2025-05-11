
import 'package:nftools/common/constants.dart';

import '../src/bindings/bindings.dart';
import 'api.dart';

const String _service = ServiceNameConstant.api;
const String _close = "close";

// 结束所有服务
Future<void> closeRust() async {
  await sendRequest<EmptyMsg>
    (_service, _close, null);
}

// 查询路由是否已启用
Future<bool> getRouterEnabled(String router) async {
  var data = await sendRequest<StringMsg>
    (_service, "getRouterEnabled", StringMsg(value: router));
  final r =  BoolMsg.bincodeDeserialize(data).value;
  return r;
}

// 设置路由是否启用
Future<void> setRouterEnabled(String router, bool enabled) async {
  await sendRequest<StringMsg>
    (_service, "setRouterEnabled", StringMsg(value: router));
}

// 启用服务
Future<void> enableService(String service) async {
  await sendRequest<StringMsg>
    (_service, "enableService", StringMsg(value: service));
}