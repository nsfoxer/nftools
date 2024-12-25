import 'package:nftools/messages/ai.pb.dart';

import '../messages/common.pb.dart';
import 'api.dart';

const String _service = "BaiduAiService";
const String _question = "question";
const String _get_kv = "get_kv";
const String _refresh = "refresh_token";

// ai 测试
Stream<BaiduAiRspMsg> quest(String msg) {
  var stream =
      sendRequestStream(_service, _question, StringMessage(value: msg));
  return stream.map((x) => BaiduAiRspMsg.fromBuffer(x));
}

// 获取kv
Future<BaiduAiKeyReqMsg> getKV() async {
  var data = await sendRequest<EmptyMessage>(_service, _get_kv, null);
  return BaiduAiKeyReqMsg.fromBuffer(data);
}

// set kv
Future<void> setKV(String appId, String secret) async {
  final data = BaiduAiKeyReqMsg(apiKey: appId, secret: secret);
  await sendRequest<BaiduAiKeyReqMsg>(_service, _refresh, data);
}

// 刷新token
Future<void> refreshToken() async {
  await sendRequest<EmptyMessage>(_service, _refresh, null);
}

